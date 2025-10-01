#!/bin/bash

# Complete Build & Package Script
# Builds app with icon and creates distributable package

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo ""
echo -e "${BLUE}╔═══════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   📦 BUILD & PACKAGE NINTENDO EMU    ║${NC}"
echo -e "${BLUE}╚═══════════════════════════════════════╝${NC}"
echo ""

# Change to project directory
cd ~/NintendoEmulator

# Step 1: Build
echo -e "${BLUE}⚙️  Building release version...${NC}"
swift build --configuration release
echo -e "${GREEN}✅ Build complete${NC}"
echo ""

# Step 2: Create app bundle
echo -e "${BLUE}📦 Creating app bundle...${NC}"
APP_BUNDLE=".build/release/NintendoEmulator.app"
rm -rf "$APP_BUNDLE"

mkdir -p "$APP_BUNDLE/Contents/MacOS"
mkdir -p "$APP_BUNDLE/Contents/Resources"

cp .build/release/NintendoEmulator "$APP_BUNDLE/Contents/MacOS/"
chmod +x "$APP_BUNDLE/Contents/MacOS/NintendoEmulator"

cp Resources/Info.plist "$APP_BUNDLE/Contents/"
cp Resources/AppIcon.icns "$APP_BUNDLE/Contents/Resources/"

# Fix all permissions
chmod -R 755 "$APP_BUNDLE"
chmod +x "$APP_BUNDLE/Contents/MacOS/NintendoEmulator"

# Remove quarantine attributes
xattr -cr "$APP_BUNDLE" 2>/dev/null || true

echo -e "${GREEN}✅ App bundle created with correct permissions${NC}"
echo ""

# Step 3: Test locally
echo -e "${BLUE}🧪 Testing app...${NC}"
if "$APP_BUNDLE/Contents/MacOS/NintendoEmulator" --version 2>/dev/null; then
    echo -e "${GREEN}✅ App launches successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Could not verify app (this is ok)${NC}"
fi
echo ""

# Step 4: Create distributable zip
echo -e "${BLUE}📦 Creating distributable package...${NC}"
cd .build/release
rm -f ~/Desktop/NintendoEmulator.zip
zip -rq ~/Desktop/NintendoEmulator.zip NintendoEmulator.app
cd ~/NintendoEmulator
echo -e "${GREEN}✅ Package created${NC}"
echo ""

# Get file info
ZIP_SIZE=$(ls -lh ~/Desktop/NintendoEmulator.zip | awk '{print $5}')

echo -e "${GREEN}╔═══════════════════════════════════════╗${NC}"
echo -e "${GREEN}║          🎉 SUCCESS!                  ║${NC}"
echo -e "${GREEN}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "📦 ${BLUE}Package:${NC} ~/Desktop/NintendoEmulator.zip"
echo -e "📏 ${BLUE}Size:${NC} $ZIP_SIZE"
echo ""
echo -e "${YELLOW}🚀 Next Steps:${NC}"
echo ""
echo "  ${BLUE}Test locally:${NC}"
echo "    open $APP_BUNDLE"
echo ""
echo "  ${BLUE}Transfer to other Mac:${NC}"
echo "    # Option 1: AirDrop the zip file"
echo "    open ~/Desktop"
echo ""
echo "    # Option 2: SCP"
echo "    scp ~/Desktop/NintendoEmulator.zip user@othermac:~/Downloads/"
echo ""
echo "    # Option 3: USB drive"
echo "    cp ~/Desktop/NintendoEmulator.zip /Volumes/USBDrive/"
echo ""
echo "  ${BLUE}On other Mac:${NC}"
echo "    unzip ~/Downloads/NintendoEmulator.zip -d ~/Applications/"
echo "    open ~/Applications/NintendoEmulator.app"
echo ""
echo -e "${GREEN}✨ Enjoy your retro gaming with AI! ✨${NC}"
echo ""
