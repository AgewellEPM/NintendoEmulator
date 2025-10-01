#!/bin/bash
# Bundle the app with icon

APP_BUNDLE=".build/release/NintendoEmulator.app"
RESOURCES="Resources"

echo "📦 Creating app bundle with icon..."

# Create bundle structure
mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp .build/release/NintendoEmulator "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/NintendoEmulator"

# Copy resources
cp "$RESOURCES/Info.plist" "$APP_BUNDLE/Contents/"
cp "$RESOURCES/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"

echo "✅ App bundle created!"
echo ""
echo "📍 Location: ~/NintendoEmulator/$APP_BUNDLE"
echo ""
echo "🚀 To test:"
echo "   open ~/NintendoEmulator/$APP_BUNDLE"
echo ""
echo "📦 To copy to other Mac:"
echo "   zip -r ~/Desktop/NintendoEmulator.zip ~/NintendoEmulator/$APP_BUNDLE"
echo ""
