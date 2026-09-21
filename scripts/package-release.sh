#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
dist_dir="$project_dir/dist"
bundle_dir="$dist_dir/草稿本.app"
info_plist="$project_dir/Resources/Info.plist"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist")
notary_profile="${NOTARY_PROFILE:-DraftBook-Notary}"
signing_identity="${CODESIGN_IDENTITY:-}"
preview_build="${PREVIEW_BUILD:-0}"

if [[ "$preview_build" == "1" ]]; then
  signing_identity="-"
  dmg_path="$dist_dir/草稿本-${version}-本机预览-未公证.dmg"
else
  dmg_path="$dist_dir/草稿本-${version}-内测版.dmg"
fi

if [[ "$preview_build" != "1" && -z "$signing_identity" ]]; then
  signing_identity=$(security find-identity -v -p codesigning | sed -n 's/.*"\(Developer ID Application:.*\)"/\1/p' | head -n 1)
fi

if [[ "$preview_build" != "1" && -z "$signing_identity" ]]; then
  print -u2 "没有找到 Developer ID Application 证书。请先完成开发者账号和证书配置。"
  exit 1
fi

export CODESIGN_IDENTITY="$signing_identity"
export UNIVERSAL_BUILD=1
"$project_dir/scripts/build-app.sh"

release_stage=$(mktemp -d "${TMPDIR:-/tmp}/DraftBook-release.XXXXXX")
trap 'rm -rf "$release_stage"' EXIT

cp -R "$bundle_dir" "$release_stage/草稿本.app"
ln -s /Applications "$release_stage/Applications"

rm -f "$dmg_path"
hdiutil create \
  -volname "草稿本" \
  -srcfolder "$release_stage" \
  -ov \
  -format UDZO \
  "$dmg_path"

if [[ "$preview_build" != "1" ]]; then
  codesign --force --sign "$signing_identity" --timestamp "$dmg_path"
  codesign --verify --verbose=2 "$dmg_path"
fi

if [[ "$preview_build" != "1" && "${SKIP_NOTARIZATION:-0}" != "1" ]]; then
  xcrun notarytool submit "$dmg_path" \
    --keychain-profile "$notary_profile" \
    --wait
  xcrun stapler staple "$dmg_path"
  xcrun stapler validate "$dmg_path"
fi

if [[ "$preview_build" != "1" ]]; then
  spctl --assess --type execute --verbose=2 "$bundle_dir"
  spctl --assess --type open --context context:primary-signature --verbose=2 "$dmg_path"
fi

echo "$dmg_path"
