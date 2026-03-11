#!/bin/bash
set -e

# Configuration
PROJECT_DIR=".."
XCODE_PROJECT="$PROJECT_DIR/TrancyKeyboardMac.xcodeproj"
SCHEME="TrancyKeyboardMacOs 1"
BUNDLE_ID="com.trancy.inputmethod.TrancyIM"
INSTALL_LOCATION="/Library/Input Methods"

echo "🛠 Step 1: Building Release with Auto-Signing..."
xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -configuration Release -destination 'platform=macOS' clean build > build_log.txt 2>&1

# 获取构建目录
BUILD_DIR=$(xcodebuild -project "$XCODE_PROJECT" -scheme "$SCHEME" -configuration Release -destination 'platform=macOS' -showBuildSettings | grep TARGET_BUILD_DIR | awk -F " = " '{print $2}')
APP_NAME="TrancyKeyboardMacOs.app"

echo "🚚 Step 2: Preparing Staging Directory (Cleanup)..."
STAGING_DIR="../build/staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# 仅拷贝必要的 .app 文件，不包含 dSYM 和 swiftmodule
echo "Step 3: Copying $APP_NAME to Staging..."
cp -R "$BUILD_DIR/$APP_NAME" "$STAGING_DIR/"

# 安全清理：确保敏感源代码配置文件不会包含在安装包中
echo "🛡 Step 3.1: Removing sensitive source/config files from bundle..."
find "$STAGING_DIR/$APP_NAME" -name "Config.xcconfig" -delete
find "$STAGING_DIR/$APP_NAME" -name "RealSettings.swift" -delete

echo "Step 4: Packaging (Clean)..."
# 使用 STAGING_DIR 作为根目录
pkgbuild --root "$STAGING_DIR" \
         --component-plist Trancy-component.plist \
         --scripts . \
         --identifier "$BUNDLE_ID" \
         --version "1.0" \
         --install-location "$INSTALL_LOCATION" \
         "../build/TrancyKeyboard.pkg"

echo ""
echo " PKG 构建成功: ./build/TrancyKeyboard.pkg"

