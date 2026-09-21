#!/bin/zsh

set -u

print "Xcode: $(xcodebuild -version | tr '\n' ' ')"
print "开发工具路径: $(xcode-select -p)"
print "公证工具: $(xcrun notarytool --version)"
print ""
print "可用的 Developer ID Application 证书："

identities=$(security find-identity -v -p codesigning | sed -n '/Developer ID Application/p')
if [[ -n "$identities" ]]; then
  print "$identities"
  print ""
  print "签名条件已满足。"
else
  print "未找到。"
  print ""
  print "请先加入 Apple Developer Program，并在钥匙串中安装 Developer ID Application 证书。"
fi
