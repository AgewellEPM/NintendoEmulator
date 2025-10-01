#!/bin/bash

# Auto-Start AI Agent Test
# Launches emulator with built-in ROM, then starts AI
# Usage: ./auto_start_ai.sh [player_number]
#   player_number: 1-4 (default: 1)

set -e

# Parse player number (default P1)
PLAYER=${1:-1}
if ! [[ "$PLAYER" =~ ^[1-4]$ ]]; then
    echo "Usage: $0 [player_number]"
    echo "  player_number: 1-4 (default: 1)"
    exit 1
fi

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

echo ""
echo -e "${MAGENTA}╔═══════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║    🤖 AI AGENT AUTO-START 🎮         ║${NC}"
echo -e "${MAGENTA}║       (Playing as Player $PLAYER)          ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"
echo ""

# Cleanup function
cleanup() {
    echo ""
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    pkill -f mupen64plus 2>/dev/null || true
    pkill -f NintendoEmulator 2>/dev/null || true
    sleep 1
}

trap cleanup EXIT

# Clean up any old processes
cleanup

# Step 1: Build
echo -e "${CYAN}⚙️  Building NintendoEmulator...${NC}"
if swift build --configuration release 2>&1 | grep -q "Build complete"; then
    echo -e "${GREEN}✅ Build complete${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
echo ""

# Step 2: Check for mupen64plus
echo -e "${CYAN}🔍 Checking mupen64plus...${NC}"
if ! command -v mupen64plus &> /dev/null; then
    echo -e "${RED}❌ mupen64plus not found!${NC}"
    echo "Install: brew install mupen64plus"
    exit 1
fi
echo -e "${GREEN}✅ mupen64plus found${NC}"
echo ""

# Step 3: Find a ROM (any ROM)
echo -e "${CYAN}📀 Looking for N64 ROMs...${NC}"

ROM_DIRS=(
    "$HOME/Documents/ROMs"
    "$HOME/Downloads"
    "$HOME/ROMs"
    "$HOME/Desktop"
    "./roms"
    "."
)

ROM_PATH=""
for dir in "${ROM_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        # Find first .z64, .n64, or .v64 file
        ROM_PATH=$(find "$dir" -maxdepth 2 -type f \( -name "*.z64" -o -name "*.n64" -o -name "*.v64" \) 2>/dev/null | head -1)
        if [ -n "$ROM_PATH" ]; then
            break
        fi
    fi
done

if [ -z "$ROM_PATH" ]; then
    echo -e "${YELLOW}⚠️  No ROM found automatically${NC}"
    echo ""
    echo "Please start mupen64plus manually:"
    echo -e "${CYAN}  mupen64plus --windowed --resolution 640x480 your_rom.z64${NC}"
    echo ""
    echo "Then press ENTER to continue..."
    read

    # Check if mupen64plus is running
    if ! pgrep -f mupen64plus > /dev/null; then
        echo -e "${RED}❌ mupen64plus not running${NC}"
        exit 1
    fi

    EMULATOR_PID=$(pgrep -f mupen64plus | head -1)
    echo -e "${GREEN}✅ Found running emulator (PID: $EMULATOR_PID)${NC}"
else
    echo -e "${GREEN}✅ Found ROM:${NC} $(basename "$ROM_PATH")"
    echo ""

    # Step 4: Start emulator
    echo -e "${CYAN}🎮 Starting emulator...${NC}"
    mupen64plus \
        --windowed \
        --resolution 640x480 \
        --gfx mupen64plus-video-glide64mk2 \
        --audio mupen64plus-audio-sdl \
        --input mupen64plus-input-sdl \
        --rsp mupen64plus-rsp-hle \
        "$ROM_PATH" > /tmp/mupen64plus.log 2>&1 &

    sleep 3

    EMULATOR_PID=$(pgrep -f mupen64plus | head -1)
    if [ -z "$EMULATOR_PID" ]; then
        echo -e "${RED}❌ Emulator failed to start${NC}"
        tail -20 /tmp/mupen64plus.log
        exit 1
    fi

    echo -e "${GREEN}✅ Emulator running (PID: $EMULATOR_PID)${NC}"
fi

echo ""
echo -e "${YELLOW}⏳ Waiting for game to load (5 seconds)...${NC}"
sleep 5
echo ""

# Step 5: Start AI app
echo -e "${CYAN}🤖 Launching AI Agent...${NC}"
.build/release/NintendoEmulator > /tmp/ai_agent.log 2>&1 &
APP_PID=$!

sleep 3

if ! ps -p $APP_PID > /dev/null; then
    echo -e "${RED}❌ App failed to start${NC}"
    tail -20 /tmp/ai_agent.log
    exit 1
fi

echo -e "${GREEN}✅ AI Agent running (PID: $APP_PID)${NC}"
echo ""

# Step 6: Instructions
echo -e "${MAGENTA}╔═══════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║        🎯 NEXT STEPS                  ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "Both windows are now open!"
echo ""
echo "In the ${CYAN}NintendoEmulator${NC} window:"
echo ""
echo "  ${GREEN}1.${NC} Click the ${MAGENTA}AI${NC} button (top right)"
echo "  ${GREEN}2.${NC} Click ${CYAN}Open AI Agent Panel${NC}"
echo "  ${GREEN}3.${NC} Select ${CYAN}Player $PLAYER${NC} (P$PLAYER button)"
echo "  ${GREEN}4.${NC} Click ${CYAN}Auto-Detect Emulator${NC}"
echo "      ${YELLOW}→ Should find PID: $EMULATOR_PID${NC}"
echo "  ${GREEN}5.${NC} Enter game name (or leave detected)"
echo "  ${GREEN}6.${NC} Click ${CYAN}Connect${NC}"
echo "  ${GREEN}7.${NC} Select mode: ${CYAN}Balanced${NC}"
echo "  ${GREEN}8.${NC} Click ${CYAN}Start AI Agent${NC}"
echo ""
echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}🎮 Watch Mario play himself!${NC}"
echo ""
echo "Monitoring logs (Ctrl+C to stop)..."
echo ""
echo "─────────────────────────────────────"
echo ""

# Monitor both logs
tail -f /tmp/ai_agent.log 2>/dev/null | while read line; do
    case "$line" in
        *"✅"*|*"Connected"*|*"Started"*|*"Found"*)
            echo -e "${GREEN}[AI] $line${NC}"
            ;;
        *"⚠️"*|*"Warning"*)
            echo -e "${YELLOW}[AI] $line${NC}"
            ;;
        *"❌"*|*"Error"*|*"error"*)
            echo -e "${RED}[AI] $line${NC}"
            ;;
        *"Button"*|*"Analog"*|*"Inject"*)
            echo -e "${CYAN}[AI] $line${NC}"
            ;;
        *)
            echo "[AI] $line"
            ;;
    esac
done &

# Wait
wait $APP_PID
