#!/bin/bash

# AI Agent Test Script
# This script tests the AI agent connection to mupen64plus

set -e

echo "🤖 AI Agent Test Script"
echo "======================="
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Check if ROM file exists
ROM_PATH="$HOME/Documents/ROMs/Super Mario 64.z64"
if [ ! -f "$ROM_PATH" ]; then
    echo -e "${YELLOW}⚠️  Super Mario 64 ROM not found at:${NC}"
    echo "   $ROM_PATH"
    echo ""
    echo -e "${YELLOW}Please provide a ROM path:${NC}"
    read -p "ROM Path: " ROM_PATH

    if [ ! -f "$ROM_PATH" ]; then
        echo -e "${RED}❌ ROM file not found!${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ ROM found:${NC} $ROM_PATH"
echo ""

# Check if mupen64plus is installed
if ! command -v mupen64plus &> /dev/null; then
    echo -e "${RED}❌ mupen64plus not found!${NC}"
    echo ""
    echo "Install via: brew install mupen64plus"
    exit 1
fi

echo -e "${GREEN}✅ mupen64plus installed:${NC} $(which mupen64plus)"
echo ""

# Check if NintendoEmulator is built
if [ ! -f ".build/release/NintendoEmulator" ]; then
    echo -e "${YELLOW}⚙️  Building NintendoEmulator (release mode)...${NC}"
    swift build --configuration release
    echo -e "${GREEN}✅ Build complete${NC}"
    echo ""
fi

# Kill any existing mupen64plus processes
echo "🧹 Cleaning up any existing emulator processes..."
pkill -f mupen64plus || true
sleep 1

echo ""
echo "📋 Test Plan:"
echo "============="
echo ""
echo "1. Start mupen64plus in background (windowed, 640x480)"
echo "2. Find emulator PID"
echo "3. Launch NintendoEmulator app"
echo "4. You will need to:"
echo "   - Click 'AI' button in top right"
echo "   - Click 'Open AI Agent Panel'"
echo "   - Click 'Auto-Detect Emulator'"
echo "   - Select game: 'Super Mario 64'"
echo "   - Click 'Connect'"
echo "   - Select mode: 'Balanced'"
echo "   - Click 'Start AI Agent'"
echo "   - Watch Mario play itself!"
echo ""

read -p "Press ENTER to start test..."

# Start mupen64plus in background
echo ""
echo "🎮 Starting mupen64plus..."
echo "Command: mupen64plus --windowed --resolution 640x480 \"$ROM_PATH\""
echo ""

mupen64plus \
    --windowed \
    --resolution 640x480 \
    --gfx mupen64plus-video-glide64mk2 \
    --audio mupen64plus-audio-sdl \
    --input mupen64plus-input-sdl \
    --rsp mupen64plus-rsp-hle \
    "$ROM_PATH" &

MUPEN_PID=$!
sleep 3

# Check if mupen64plus is running
if ! ps -p $MUPEN_PID > /dev/null; then
    echo -e "${RED}❌ mupen64plus failed to start!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ mupen64plus running (PID: $MUPEN_PID)${NC}"
echo ""

# Find the actual mupen64plus process (might be different from shell PID)
ACTUAL_PID=$(pgrep -f "mupen64plus.*Super Mario 64" || echo $MUPEN_PID)
echo -e "${GREEN}✅ Emulator PID: $ACTUAL_PID${NC}"
echo ""

echo "🚀 Launching NintendoEmulator app..."
echo ""

# Launch app
if [ -f ".build/release/NintendoEmulator" ]; then
    .build/release/NintendoEmulator &
    APP_PID=$!
else
    echo -e "${RED}❌ NintendoEmulator not found!${NC}"
    kill $MUPEN_PID
    exit 1
fi

echo ""
echo "✅ Both processes running:"
echo "   - Emulator PID: $ACTUAL_PID"
echo "   - App PID: $APP_PID"
echo ""
echo "📝 Next Steps:"
echo "=============="
echo ""
echo "In the NintendoEmulator window:"
echo ""
echo "  1. Click the purple 'AI' button (top right)"
echo "  2. Click 'Open AI Agent Panel'"
echo "  3. Click 'Auto-Detect Emulator' (should find PID: $ACTUAL_PID)"
echo "  4. If not detected, manually enter:"
echo "     - PID: $ACTUAL_PID"
echo "     - Game: Super Mario 64"
echo "  5. Click 'Connect'"
echo "  6. Select AI Mode (Balanced recommended)"
echo "  7. Click 'Start AI Agent'"
echo ""
echo "🎮 Watch Mario play itself!"
echo ""
echo "🔍 Monitoring logs..."
echo "===================="
echo ""
echo "Press Ctrl+C to stop all processes"
echo ""

# Monitor the app output
wait $APP_PID

# Cleanup
echo ""
echo "🧹 Cleaning up..."
kill $MUPEN_PID 2>/dev/null || true
pkill -f mupen64plus || true

echo ""
echo -e "${GREEN}✅ Test complete!${NC}"
