#!/bin/bash
set -e

BUNDLE_ID="com.trancy.inputmethod.TrancyIM"
APP_PATH="/Library/Input Methods/TrancyKeyboardMacOs.app"
PROCESS_NAME="TrancyKeyboardMacOs"

echo "🛑 Step 1: Terminating $PROCESS_NAME..."
killall "$PROCESS_NAME" 2>/dev/null || true

echo "🗑 Step 2: Removing application from $APP_PATH..."
if [ -d "$APP_PATH" ]; then
    sudo rm -rf "$APP_PATH"
else
    echo "  ! Application folder not found, skipping."
fi

# 移除调试残留
sudo rm -rf "$APP_PATH.dSYM" 2>/dev/null || true
sudo rm -rf "$APP_PATH.swiftmodule" 2>/dev/null || true

echo "🧹 Step 3: Forgetting PKG installation record..."
sudo pkgutil --forget "$BUNDLE_ID" 2>/dev/null || true

echo "🔄 Step 4: Unregistering from LaunchServices..."
/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -u "$APP_PATH" 2>/dev/null || true

echo "♻️ Step 5: Refreshing System UI Server..."
killall -HUP SystemUIServer 2>/dev/null || true

echo ""
echo "✅ Uninstallation completed successfully."
echo "--------------------------------------------------"
