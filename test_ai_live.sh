#!/bin/bash

# AI Agent Live Test Script
# Fully automated - starts emulator and AI, then watches it play!

set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║  🤖 N64 AI AGENT - LIVE TEST 🎮      ║${NC}"
echo -e "${MAGENTA}╔════════════════════════════════════════╗${NC}"
echo ""

# Function to cleanup on exit
cleanup() {
    echo ""
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    pkill -f mupen64plus 2>/dev/null || true
    pkill -f NintendoEmulator 2>/dev/null || true
    sleep 1
    echo -e "${GREEN}✅ Cleanup complete${NC}"
}

trap cleanup EXIT

# Step 1: Find ROM
echo -e "${CYAN}📀 Step 1: Finding ROM...${NC}"
echo ""

ROM_PATHS=(
    "$HOME/Documents/ROMs/Super Mario 64.z64"
    "$HOME/Downloads/Super Mario 64.z64"
    "$HOME/ROMs/Super Mario 64.z64"
    "$HOME/Desktop/Super Mario 64.z64"
    "./Super Mario 64.z64"
    "./roms/Super Mario 64.z64"
)

ROM_PATH=""
for path in "${ROM_PATHS[@]}"; do
    if [ -f "$path" ]; then
        ROM_PATH="$path"
        break
    fi
done

if [ -z "$ROM_PATH" ]; then
    echo -e "${YELLOW}⚠️  Super Mario 64 ROM not found in standard locations${NC}"
    echo ""
    echo "Please enter ROM path:"
    read -p "> " ROM_PATH

    if [ ! -f "$ROM_PATH" ]; then
        echo -e "${RED}❌ ROM file not found: $ROM_PATH${NC}"
        exit 1
    fi
fi

echo -e "${GREEN}✅ Found ROM:${NC} $ROM_PATH"
echo ""

# Step 2: Check mupen64plus
echo -e "${CYAN}🔍 Step 2: Checking mupen64plus...${NC}"
echo ""

if ! command -v mupen64plus &> /dev/null; then
    echo -e "${RED}❌ mupen64plus not found!${NC}"
    echo ""
    echo "Install with:"
    echo "  brew install mupen64plus"
    exit 1
fi

echo -e "${GREEN}✅ mupen64plus found:${NC} $(which mupen64plus)"
echo ""

# Step 3: Build app
echo -e "${CYAN}⚙️  Step 3: Building NintendoEmulator...${NC}"
echo ""

if [ ! -f ".build/release/NintendoEmulator" ]; then
    echo "Building in release mode..."
    swift build --configuration release 2>&1 | tail -5
fi

if [ ! -f ".build/release/NintendoEmulator" ]; then
    echo -e "${RED}❌ Build failed!${NC}"
    exit 1
fi

echo -e "${GREEN}✅ Build complete${NC}"
echo ""

# Step 4: Kill existing processes
echo -e "${CYAN}🧹 Step 4: Cleaning up old processes...${NC}"
echo ""

pkill -f mupen64plus 2>/dev/null || true
pkill -f NintendoEmulator 2>/dev/null || true
sleep 2

echo -e "${GREEN}✅ Ready to start${NC}"
echo ""

# Step 5: Start emulator
echo -e "${CYAN}🎮 Step 5: Starting mupen64plus...${NC}"
echo ""

echo "Command:"
echo "  mupen64plus --windowed --resolution 640x480 \"$ROM_PATH\""
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
echo -e "${GREEN}✅ Emulator started (PID: $MUPEN_PID)${NC}"
echo ""

# Wait for emulator to load
echo -e "${YELLOW}⏳ Waiting for game to load...${NC}"
sleep 5

# Find actual mupen64plus process
ACTUAL_PID=$(pgrep -f "mupen64plus.*Mario" | head -1)
if [ -z "$ACTUAL_PID" ]; then
    ACTUAL_PID=$MUPEN_PID
fi

echo -e "${GREEN}✅ Emulator PID: $ACTUAL_PID${NC}"
echo ""

# Check if emulator is still running
if ! ps -p $ACTUAL_PID > /dev/null; then
    echo -e "${RED}❌ Emulator failed to start!${NC}"
    exit 1
fi

# Step 6: Launch app in background
echo -e "${CYAN}🚀 Step 6: Launching NintendoEmulator app...${NC}"
echo ""

# Create AppleScript to control the app
cat > /tmp/ai_agent_automation.applescript <<'APPLESCRIPT'
on run argv
    set emulatorPID to item 1 of argv

    tell application "System Events"
        -- Wait for NintendoEmulator window
        repeat 20 times
            try
                if exists (first window of (first application process whose name contains "NintendoEmulator")) then
                    exit repeat
                end if
            end try
            delay 0.5
        end repeat

        -- Give app time to initialize
        delay 2

        -- Look for NintendoEmulator process
        tell application process "NintendoEmulator"
            -- Click AI button (top right area)
            -- Try to find by accessibility
            try
                set aiButtons to buttons whose description contains "AI"
                if (count of aiButtons) > 0 then
                    click first item of aiButtons
                    delay 1
                end if
            end try

            -- Alternative: keyboard shortcut if available
            -- keystroke "a" using {command down, shift down}

            delay 1

            -- Look for "Open AI Agent Panel" button
            try
                set panelButtons to buttons whose description contains "Open AI Agent Panel"
                if (count of panelButtons) > 0 then
                    click first item of panelButtons
                    delay 2
                end if
            end try

            -- Look for "Auto-Detect" button
            try
                set detectButtons to buttons whose description contains "Auto-Detect"
                if (count of detectButtons) > 0 then
                    click first item of detectButtons
                    delay 2
                end if
            end try

            -- Look for "Connect" button
            try
                set connectButtons to buttons whose description contains "Connect"
                if (count of connectButtons) > 0 then
                    click first item of connectButtons
                    delay 3
                end if
            end try

            -- Look for "Start AI Agent" button
            try
                set startButtons to buttons whose description contains "Start AI Agent"
                if (count of startButtons) > 0 then
                    click first item of startButtons
                    delay 1
                end if
            end try
        end tell
    end tell

    return "Automation complete"
end run
APPLESCRIPT

# Launch app
.build/release/NintendoEmulator > /tmp/nintendoemulator.log 2>&1 &
APP_PID=$!

echo -e "${GREEN}✅ App launched (PID: $APP_PID)${NC}"
echo ""

# Wait for app to start
echo -e "${YELLOW}⏳ Waiting for app to initialize...${NC}"
sleep 3

# Check if app is running
if ! ps -p $APP_PID > /dev/null; then
    echo -e "${RED}❌ App failed to start!${NC}"
    echo ""
    echo "Check logs:"
    tail -20 /tmp/nintendoemulator.log
    exit 1
fi

# Step 7: Automate UI interaction
echo -e "${CYAN}🤖 Step 7: Automating AI agent connection...${NC}"
echo ""

echo "Attempting to automate UI clicks..."
osascript /tmp/ai_agent_automation.applescript "$ACTUAL_PID" 2>/dev/null || {
    echo -e "${YELLOW}⚠️  Automation failed - using manual instructions${NC}"
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════${NC}"
    echo -e "${MAGENTA}  📋 MANUAL INSTRUCTIONS${NC}"
    echo -e "${MAGENTA}═══════════════════════════════════════${NC}"
    echo ""
    echo "In the NintendoEmulator window:"
    echo ""
    echo "  1. Click the purple ${CYAN}🤖 AI${NC} button (top right)"
    echo "  2. Click ${CYAN}Open AI Agent Panel${NC}"
    echo "  3. Click ${CYAN}Auto-Detect Emulator${NC}"
    echo "     (Should find PID: $ACTUAL_PID)"
    echo "  4. Click ${CYAN}Connect${NC}"
    echo "  5. Select AI Mode: ${CYAN}Balanced${NC}"
    echo "  6. Click ${CYAN}Start AI Agent${NC}"
    echo ""
    echo -e "${MAGENTA}═══════════════════════════════════════${NC}"
    echo ""
}

# Step 8: Monitor logs
echo ""
echo -e "${CYAN}🔍 Step 8: Monitoring AI agent...${NC}"
echo ""

echo -e "${MAGENTA}═══════════════════════════════════════${NC}"
echo -e "${MAGENTA}  📊 LIVE LOG STREAM${NC}"
echo -e "${MAGENTA}═══════════════════════════════════════${NC}"
echo ""

echo "Watching for AI activity..."
echo ""
echo "Expected logs:"
echo "  ✅ [AIAgentCoordinator] Connecting to emulator"
echo "  ✅ [N64InputInjector] Scanning for controller state"
echo "  ✅ [N64InputInjector] Found controller state at: 0x..."
echo "  ✅ [SimpleAgent] Started"
echo "  ✅ [N64MupenAdapter] Button pressed"
echo ""
echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
echo ""
echo "─────────────────────────────────────────────────────"
echo ""

# Tail logs with color highlighting
tail -f /tmp/nintendoemulator.log 2>/dev/null | while read line; do
    case "$line" in
        *"✅"*|*"Connected"*|*"Started"*|*"Found"*)
            echo -e "${GREEN}$line${NC}"
            ;;
        *"⚠️"*|*"Warning"*|*"Failed"*)
            echo -e "${YELLOW}$line${NC}"
            ;;
        *"❌"*|*"Error"*|*"error"*)
            echo -e "${RED}$line${NC}"
            ;;
        *"Button"*|*"Analog"*|*"AI"*)
            echo -e "${CYAN}$line${NC}"
            ;;
        *)
            echo "$line"
            ;;
    esac
done

# Keep running until interrupted
wait $APP_PID
