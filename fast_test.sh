#!/bin/bash
set -e

# Configuration
XCODE_PROJECT="./TrancyKeyboardMac.xcodeproj"
SCHEME="TrancyKeyboardMacOs 1"

DEST_APP="/Library/Input Methods/TrancyKeyboardMacOs.app"

xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -configuration Release -destination 'platform=macOS' build > build_log.txt 2>&1

# 2. 获取构建出的 .app 路径
BUILD_DIR=$(xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -configuration Release -destination 'platform=macOS' -showBuildSettings | grep TARGET_BUILD_DIR | awk -F " = " '{print $2}')
BUILT_APP="$BUILD_DIR/TrancyKeyboardMacOs.app"

if [ ! -d "$BUILT_APP" ]; then
    echo "❌ Build failed. Please check build_log.txt"
    exit 1
fi

# 3. 替换二进制 (需要 sudo 权限)
sudo rm -rf "$DEST_APP"
sudo cp -R "$BUILT_APP" "/Library/Input Methods/"
sudo chown -R root:wheel "$DEST_APP"

# 4. 优雅重启输入法进程
"$DEST_APP/Contents/MacOS/TrancyKeyboardMacOs" --quit || sudo killall TrancyKeyboardMacOs 2>/dev/null || true

echo "Done! 新代码已生效。"
