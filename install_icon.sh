#!/bin/bash

# Install Icon Script for NintendoEmulator
# Creates a Blockbuster-style blue icon

set -e

echo "🎨 Installing app icon..."

# Colors
BLUE='\033[0;34m'
GREEN='\033[0;32m'
NC='\033[0m'

# Create Resources directory if it doesn't exist
RESOURCES_DIR="$HOME/NintendoEmulator/Resources"
mkdir -p "$RESOURCES_DIR"

# Create AppIcon.icns using sips (built-in macOS tool)
echo -e "${BLUE}Creating icon from image...${NC}"

# First, let's create a simple icon or use an existing image
# Check if you have an icon file
ICON_SOURCE=""

# Look for any icon files you might have
for file in "$HOME/NintendoEmulator"/*.{png,jpg,jpeg,icns} "$HOME/Desktop"/*.{png,jpg,jpeg,icns} "$HOME/Downloads"/*.{png,jpg,jpeg,icns}; do
    if [ -f "$file" ]; then
        filename=$(basename "$file")
        if [[ "$filename" =~ (blockbuster|icon|logo) ]]; then
            ICON_SOURCE="$file"
            echo -e "${GREEN}Found icon: $filename${NC}"
            break
        fi
    fi
done

if [ -z "$ICON_SOURCE" ]; then
    echo ""
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo "📥 No icon file found automatically."
    echo ""
    echo "Please do ONE of the following:"
    echo ""
    echo "Option 1: Download the Blockbuster image you showed me"
    echo "  1. Save it to ~/Downloads/blockbuster.png"
    echo "  2. Run this script again"
    echo ""
    echo "Option 2: Use any PNG/JPG image:"
    echo "  1. Save your icon image as ~/Downloads/icon.png"
    echo "  2. Run this script again"
    echo ""
    echo "Option 3: Enter path now:"
    read -p "Path to icon image (or press Enter to skip): " ICON_SOURCE
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
    echo ""
fi

if [ -n "$ICON_SOURCE" ] && [ -f "$ICON_SOURCE" ]; then
    echo -e "${BLUE}Converting to .icns format...${NC}"

    # Create iconset directory
    ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
    mkdir -p "$ICONSET_DIR"

    # Generate all required icon sizes
    sips -z 16 16     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16.png" 2>/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_16x16@2x.png" 2>/dev/null
    sips -z 32 32     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32.png" 2>/dev/null
    sips -z 64 64     "$ICON_SOURCE" --out "$ICONSET_DIR/icon_32x32@2x.png" 2>/dev/null
    sips -z 128 128   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128.png" 2>/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_128x128@2x.png" 2>/dev/null
    sips -z 256 256   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256.png" 2>/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_256x256@2x.png" 2>/dev/null
    sips -z 512 512   "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512.png" 2>/dev/null
    sips -z 1024 1024 "$ICON_SOURCE" --out "$ICONSET_DIR/icon_512x512@2x.png" 2>/dev/null

    # Convert to .icns
    iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

    # Clean up iconset directory
    rm -rf "$ICONSET_DIR"

    echo -e "${GREEN}✅ Icon created: $RESOURCES_DIR/AppIcon.icns${NC}"
else
    echo -e "${BLUE}Creating generic placeholder icon...${NC}"

    # Create a simple blue icon using ImageMagick if available, or just a note
    if command -v convert &> /dev/null; then
        convert -size 1024x1024 xc:"#003087" -gravity center \
                -pointsize 120 -fill yellow -annotate +0+0 "N64" \
                "$RESOURCES_DIR/icon_temp.png"

        # Convert to .icns
        ICONSET_DIR="$RESOURCES_DIR/AppIcon.iconset"
        mkdir -p "$ICONSET_DIR"

        for size in 16 32 128 256 512 1024; do
            sips -z $size $size "$RESOURCES_DIR/icon_temp.png" --out "$ICONSET_DIR/icon_${size}x${size}.png" 2>/dev/null
        done

        iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"
        rm -rf "$ICONSET_DIR" "$RESOURCES_DIR/icon_temp.png"

        echo -e "${GREEN}✅ Placeholder icon created${NC}"
    else
        echo -e "${BLUE}⚠️  Skipping icon creation (no image provided)${NC}"
        echo "You can add an icon later by:"
        echo "  1. Creating Resources/AppIcon.icns"
        echo "  2. Rebuilding the app"
        exit 0
    fi
fi

# Create Info.plist for the app bundle
echo -e "${BLUE}Creating Info.plist...${NC}"

cat > "$RESOURCES_DIR/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleExecutable</key>
    <string>NintendoEmulator</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleIdentifier</key>
    <string>com.local.NintendoEmulator</string>
    <key>CFBundleInfoDictionaryVersion</key>
    <string>6.0</string>
    <key>CFBundleName</key>
    <string>NintendoEmulator</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
EOF

echo -e "${GREEN}✅ Info.plist created${NC}"

# Build the app with icon
echo ""
echo -e "${BLUE}Building app with icon...${NC}"

cd ~/NintendoEmulator

# Build release version
swift build --configuration release

# Create app bundle
APP_BUNDLE="$HOME/NintendoEmulator/.build/release/NintendoEmulator.app"
echo -e "${BLUE}Creating app bundle...${NC}"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

# Copy executable
cp .build/release/NintendoEmulator "$APP_BUNDLE/Contents/MacOS/"

# Copy resources
cp "$RESOURCES_DIR/Info.plist" "$APP_BUNDLE/Contents/"
if [ -f "$RESOURCES_DIR/AppIcon.icns" ]; then
    cp "$RESOURCES_DIR/AppIcon.icns" "$APP_BUNDLE/Contents/Resources/"
fi

echo ""
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${GREEN}✅ SUCCESS! App bundle created with icon!${NC}"
echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""
echo "📦 Location: $APP_BUNDLE"
echo ""
echo "🚀 To test on your other Mac:"
echo ""
echo "  1. Copy the app bundle:"
echo "     scp -r \"$APP_BUNDLE\" username@othermac:~/Desktop/"
echo ""
echo "  2. Or zip it:"
echo "     cd .build/release"
echo "     zip -r ~/Desktop/NintendoEmulator.zip NintendoEmulator.app"
echo ""
echo "  3. Or open it now:"
echo "     open \"$APP_BUNDLE\""
echo ""
echo "🎨 To update the icon later:"
echo "  1. Save new icon to ~/Downloads/icon.png"
echo "  2. Run: ./install_icon.sh"
echo ""
