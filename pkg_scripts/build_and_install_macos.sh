#!/bin/bash
set -e

# Configuration
PROJECT_DIR=".."
XCODE_PROJECT="$PROJECT_DIR/TrancyKeyboardMac.xcodeproj"
SCHEME="TrancyKeyboardMacOs 1"
BUNDLE_ID="com.trancy.inputmethod.TrancyIM"
INSTALL_LOCATION="/Library/Input Methods"

echo "🛠 Step 1: Building Release..."
xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -configuration Release -destination 'platform=macOS' clean build > build_log.txt 2>&1

# 获取构建目录
BUILD_DIR=$(xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -configuration Release -destination 'platform=macOS' -showBuildSettings | grep TARGET_BUILD_DIR | awk -F " = " '{print $2}')
APP_NAME="TrancyKeyboardMacOs.app"

echo "🚚 Step 2: Preparing Staging Directory..."
STAGING_DIR="../build/staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 仅拷贝必要的 .app 文件
echo "Step 3: Copying $APP_NAME to Staging..."
cp -R "$BUILD_DIR/$APP_NAME" "$STAGING_DIR/"

# 安全清理：删除符号文件以恢复原本的小体积
echo "🛡 Step 3.1: Cleanup unnecessary files from bundle..."
find "$STAGING_DIR" -name "*.dSYM" -exec rm -rf {} + 2>/dev/null || true
find "$STAGING_DIR" -name "Config.xcconfig" -delete
find "$STAGING_DIR" -name "RealSettings.swift" -delete

echo "📦 Step 3: Packaging (pkgbuild)..."
# 使用 STAGING_DIR 作为根目录，直接生成最终包
pkgbuild --root "$STAGING_DIR" \
         --component-plist Trancy-component.plist \
         --scripts . \
         --identifier "$BUNDLE_ID" \
         --version "1.0" \
         --install-location "$INSTALL_LOCATION" \
         "../build/TrancyKeyboard.pkg"

# 清理中间目录
rm -rf "$STAGING_DIR"

echo ""
echo "✅ PKG 构建成功: ./build/TrancyKeyboard.pkg"
