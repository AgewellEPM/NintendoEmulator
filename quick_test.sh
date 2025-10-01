#!/bin/bash
echo "🚀 Quick Test Launch"
echo "==================="
echo ""
echo "Starting minimal app instance..."

cd ~/NintendoEmulator

# Run executable directly (skips bundle overhead)
.build/release/NintendoEmulator 2>&1 | grep -E "error|Error|ERROR|warning|Warning|Controller|Switch" &

APP_PID=$!

echo "App PID: $APP_PID"
echo ""
echo "Waiting 5 seconds to load..."
sleep 5

# Check if still running
if ps -p $APP_PID > /dev/null; then
    echo "✅ App is running!"
    echo ""
    echo "Check your screen - window should be visible"
    echo ""
    echo "Press Ctrl+C to stop"
    wait $APP_PID
else
    echo "❌ App crashed or exited"
    echo ""
    echo "Check the output above for errors"
fi
