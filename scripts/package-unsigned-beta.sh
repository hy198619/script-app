#!/bin/zsh

set -euo pipefail

project_dir="${0:A:h:h}"
dist_dir="$project_dir/dist"
bundle_dir="$dist_dir/草稿本.app"
info_plist="$project_dir/Resources/Info.plist"
version=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$info_plist")
dmg_name="Script-App-DraftBook-v${version}-macOS-unsigned.dmg"
dmg_path="$dist_dir/$dmg_name"
checksums_path="$dist_dir/SHA256SUMS.txt"

export CODESIGN_IDENTITY="-"
export UNIVERSAL_BUILD=1
"$project_dir/scripts/build-app.sh"

release_stage=$(mktemp -d "${TMPDIR:-/tmp}/DraftBook-public-beta.XXXXXX")
trap 'rm -rf "$release_stage"' EXIT

cp -R "$bundle_dir" "$release_stage/草稿本.app"
cp "$project_dir/distribution/首次打开说明.txt" "$release_stage/首次打开说明.txt"
ln -s /Applications "$release_stage/Applications"

rm -f "$dmg_path" "$checksums_path"
hdiutil create \
  -volname "草稿本 ${version} 测试版" \
  -srcfolder "$release_stage" \
  -ov \
  -format UDZO \
  "$dmg_path"

hdiutil verify "$dmg_path"
(
  cd "$dist_dir"
  shasum -a 256 "$dmg_name" > "$checksums_path"
)

echo "$dmg_path"
echo "$checksums_path"
