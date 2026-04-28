#!/bin/bash
set -e

APP_NAME="QuickTranslate"
VERSION="1.0"
DMG_NAME="${APP_NAME}-${VERSION}.dmg"
TMP_DIR=$(mktemp -d)

echo "▶ 先编译打包..."
bash build.sh

echo "▶ 准备 DMG 内容..."
cp -r "${APP_NAME}.app" "$TMP_DIR/"
# 添加 Applications 快捷方式，方便用户拖拽安装
ln -s /Applications "$TMP_DIR/Applications"

echo "▶ 生成 DMG..."
rm -f "$DMG_NAME"
hdiutil create \
  -volname "$APP_NAME" \
  -srcfolder "$TMP_DIR" \
  -ov \
  -format UDZO \
  "$DMG_NAME"

rm -rf "$TMP_DIR"
echo "✅ 完成：$DMG_NAME"
open .
