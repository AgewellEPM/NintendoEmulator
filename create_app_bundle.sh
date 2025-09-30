#!/bin/bash
# Create macOS app bundle for NintendoEmulator

set -e

APP_NAME="NintendoEmulator"
BUILD_DIR=".build/release"
BUNDLE_DIR="${APP_NAME}.app"
CONTENTS_DIR="${BUNDLE_DIR}/Contents"
MACOS_DIR="${CONTENTS_DIR}/MacOS"
RESOURCES_DIR="${CONTENTS_DIR}/Resources"

echo "🎮 Creating ${APP_NAME} app bundle..."

# Clean up old bundle
rm -rf "${BUNDLE_DIR}"

# Create bundle structure
mkdir -p "${MACOS_DIR}"
mkdir -p "${RESOURCES_DIR}"

# Copy executable
echo "📦 Copying executable..."
cp "${BUILD_DIR}/${APP_NAME}" "${MACOS_DIR}/"
chmod +x "${MACOS_DIR}/${APP_NAME}"

# Copy icon
echo "🎨 Copying Blockbuster icon..."
cp Resources/AppIcon.icns "${RESOURCES_DIR}/"

# Copy all resources
echo "📂 Copying resources..."
if [ -d "Resources/AppIcon.appiconset" ]; then
    cp -r Resources/AppIcon.appiconset "${RESOURCES_DIR}/"
fi

# Create Info.plist
echo "📝 Creating Info.plist..."
cat > "${CONTENTS_DIR}/Info.plist" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>${APP_NAME}</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.emulator.n64</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>${APP_NAME}</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
    <key>NSSupportsAutomaticGraphicsSwitching</key>
    <true/>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.games</string>
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © 2025. All rights reserved.</string>
</dict>
</plist>
PLIST

# Create PkgInfo
echo "APPL????" > "${CONTENTS_DIR}/PkgInfo"

echo "✅ App bundle created at: ${BUNDLE_DIR}"
echo "🚀 To run: open ${BUNDLE_DIR}"
echo "📦 To install: cp -r ${BUNDLE_DIR} /Applications/"
