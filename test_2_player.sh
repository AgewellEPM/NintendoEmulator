#!/bin/bash

# 2-Player Test Script
# You play as Player 1, AI plays as Player 2!

set -e

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
echo -e "${MAGENTA}║    👤 YOU vs 🤖 AI - 2 PLAYER TEST  ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"
echo ""

# Cleanup
cleanup() {
    echo ""
    echo -e "${YELLOW}🧹 Cleaning up...${NC}"
    pkill -f mupen64plus 2>/dev/null || true
    pkill -f NintendoEmulator 2>/dev/null || true
    sleep 1
}

trap cleanup EXIT
cleanup

# Build
echo -e "${CYAN}⚙️  Building...${NC}"
if swift build --configuration release 2>&1 | grep -q "Build complete"; then
    echo -e "${GREEN}✅ Build complete${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
echo ""

# Check for mupen64plus
if ! command -v mupen64plus &> /dev/null; then
    echo -e "${RED}❌ mupen64plus not found!${NC}"
    echo "Install: brew install mupen64plus"
    exit 1
fi

# Find a 2-player ROM
echo -e "${CYAN}📀 Looking for 2-player ROMs...${NC}"

ROM_DIRS=(
    "$HOME/Documents/ROMs"
    "$HOME/Downloads"
    "$HOME/ROMs"
    "$HOME/Desktop"
    "./roms"
    "."
)

# Prefer multiplayer games
MULTIPLAYER_GAMES=(
    "Mario Kart"
    "Super Smash"
    "GoldenEye"
    "Mario Tennis"
    "Mario Party"
    "Perfect Dark"
    "Diddy Kong"
    "Pokemon Stadium"
)

ROM_PATH=""
for dir in "${ROM_DIRS[@]}"; do
    if [ -d "$dir" ]; then
        # Try to find multiplayer game first
        for game in "${MULTIPLAYER_GAMES[@]}"; do
            ROM_PATH=$(find "$dir" -maxdepth 2 -type f -iname "*${game}*.z64" 2>/dev/null | head -1)
            if [ -n "$ROM_PATH" ]; then
                break 2
            fi
        done

        # Otherwise any ROM will do
        ROM_PATH=$(find "$dir" -maxdepth 2 -type f \( -name "*.z64" -o -name "*.n64" -o -name "*.v64" \) 2>/dev/null | head -1)
        if [ -n "$ROM_PATH" ]; then
            break
        fi
    fi
done

if [ -z "$ROM_PATH" ]; then
    echo -e "${RED}❌ No ROM found${NC}"
    echo "Place a multiplayer N64 ROM in one of these locations:"
    for dir in "${ROM_DIRS[@]}"; do
        echo "  - $dir"
    done
    exit 1
fi

GAME_NAME=$(basename "$ROM_PATH" | sed 's/\.[^.]*$//')
echo -e "${GREEN}✅ Found: ${NC}$GAME_NAME"
echo ""

# Start emulator
echo -e "${CYAN}🎮 Starting emulator...${NC}"
mupen64plus \
    --windowed \
    --resolution 800x600 \
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
echo ""

# Instructions
echo -e "${MAGENTA}╔═══════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║          🎯 SETUP STEPS               ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "${YELLOW}In the EMULATOR window:${NC}"
echo "  1. Navigate to 2-player or VS mode"
echo "  2. Start a match"
echo ""
echo "Then press ENTER to launch AI as Player 2..."
read

# Launch AI
echo ""
echo -e "${CYAN}🤖 Launching AI as Player 2...${NC}"
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

# Final instructions
echo -e "${MAGENTA}╔═══════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║       🎮 FINAL STEPS - AI APP        ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"
echo ""
echo "  ${GREEN}1.${NC} Click the ${MAGENTA}AI${NC} button"
echo "  ${GREEN}2.${NC} Click ${CYAN}Open AI Agent Panel${NC}"
echo "  ${GREEN}3.${NC} Click ${BLUE}P2${NC} button (IMPORTANT!)"
echo "  ${GREEN}4.${NC} Click ${CYAN}Auto-Detect Emulator${NC}"
echo "  ${GREEN}5.${NC} Click ${CYAN}Connect${NC}"
echo "  ${GREEN}6.${NC} Click ${CYAN}Start AI Agent${NC}"
echo ""
echo -e "${MAGENTA}╔═══════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║          🏁 READY TO PLAY!            ║${NC}"
echo -e "${MAGENTA}╚═══════════════════════════════════════╝${NC}"
echo ""
echo -e "  ${CYAN}👤 YOU:${NC} Player 1 (your controller)"
echo -e "  ${MAGENTA}🤖 AI:${NC}  Player 2 (auto-controlled)"
echo ""
echo -e "${GREEN}🎮 Let the battle begin!${NC}"
echo ""
echo "Press Ctrl+C to stop everything..."
echo ""

# Monitor
tail -f /tmp/ai_agent.log 2>/dev/null | grep --line-buffered -E "Button|Analog|Connect|Player|AI" | while read line; do
    case "$line" in
        *"Player 2"*)
            echo -e "${MAGENTA}[AI P2] $line${NC}"
            ;;
        *"Button"*|*"Analog"*)
            echo -e "${CYAN}[AI P2] $line${NC}"
            ;;
        *)
            echo "[AI P2] $line"
            ;;
    esac
done &

wait $APP_PID
