#!/bin/bash
# 构建 NetSpeed.app（菜单栏应用，仅本机使用）
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

APP_NAME="NetSpeed"
BUILD_DIR="$ROOT/.build"
APP_BUNDLE="$ROOT/dist/$APP_NAME.app"

echo "==> 编译 Swift 包"
swift build -c release --disable-sandbox

BIN="$(swift build -c release --show-bin-path)/$APP_NAME"
[ -f "$BIN" ] || { echo "找不到可执行文件: $BIN"; exit 1; }

echo "==> 组装 App Bundle"
rm -rf "$APP_BUNDLE"
mkdir -p "$APP_BUNDLE/Contents/MacOS" "$APP_BUNDLE/Contents/Resources"
cp "$BIN" "$APP_BUNDLE/Contents/MacOS/$APP_NAME"

# 图标（不存在则先生成）
if [ ! -f "$ROOT/Resources/NetSpeed.icns" ]; then
  echo "==> 生成图标"
  swift "$ROOT/Scripts/make-icon.swift" "$ROOT/Resources/NetSpeed.icns"
fi
cp "$ROOT/Resources/NetSpeed.icns" "$APP_BUNDLE/Contents/Resources/NetSpeed.icns"

cat > "$APP_BUNDLE/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>NetSpeed</string>
    <key>CFBundleDisplayName</key>
    <string>NetSpeed</string>
    <key>CFBundleIdentifier</key>
    <string>local.netspeed.menubar</string>
    <key>CFBundleExecutable</key>
    <string>NetSpeed</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleIconFile</key>
    <string>NetSpeed</string>
    <key>CFBundleIconName</key>
    <string>NetSpeed</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "==> 临时签名（ad-hoc）"
codesign --force --sign - "$APP_BUNDLE" >/dev/null 2>&1 || echo "  (codesign 跳过)"

echo "==> 完成: $APP_BUNDLE"
echo "    打开方式: open \"$APP_BUNDLE\""
echo "    安装到「应用程序」: cp -R \"$APP_BUNDLE\" /Applications/"
