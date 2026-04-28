#!/bin/bash
set -e

APP_NAME="QuickTranslate"
SRC_DIR="QuickTranslate"
APP_BUNDLE="$APP_NAME.app"
BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"
SDK=$(xcrun --sdk macosx --show-sdk-path)

echo "▶ 编译..."
swiftc \
  -sdk "$SDK" \
  -target arm64-apple-macos13.0 \
  -strict-concurrency=minimal \
  -O \
  -framework Carbon \
  -framework AppKit \
  -framework AVFoundation \
  -framework SwiftUI \
  -framework Combine \
  -framework Vision \
  $(find "$SRC_DIR" -name "*.swift" | sort) \
  -o /tmp/"$APP_NAME"_bin

echo "▶ 生成图标..."
swift make_icon.swift
iconutil -c icns /tmp/AppIcon.iconset -o /tmp/AppIcon.icns

echo "▶ 打包 .app bundle..."
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp /tmp/"$APP_NAME"_bin "$BINARY"
cp "$SRC_DIR/Resources/Info.plist" "$APP_BUNDLE/Contents/Info.plist"
cp /tmp/AppIcon.icns "$APP_BUNDLE/Contents/Resources/AppIcon.icns"

echo "▶ Ad-hoc 签名..."
codesign --force --deep --sign - "$APP_BUNDLE"

echo "✅ 打包完成：$APP_BUNDLE"
echo "▶ 启动..."
open "$APP_BUNDLE"
