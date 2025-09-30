# Universal Emulator Makefile
# Makes building and running much easier

.PHONY: run build app clean help verify

# Default target - build and run
run: build
	@echo "🚀 Launching Universal Emulator..."
	@pkill -f NintendoEmulator 2>/dev/null || true
	@sleep 0.5
	@.build/debug/NintendoEmulator &
	@echo "✅ App launched! Use 'make stop' to quit."

# Build with preflight verification
build: verify
	@echo "🔨 Building Universal Emulator..."
	@swift build

# Verify code quality and build
verify:
	@bash scripts/preflight.sh

# Create proper .app bundle and launch
app:
	@echo "📦 Creating app bundle..."
	@./create-app-bundle.sh

# Stop running app
stop:
	@echo "🛑 Stopping Universal Emulator..."
	@pkill -f NintendoEmulator 2>/dev/null || true
	@echo "✅ App stopped."

# Clean build artifacts
clean:
	@echo "🧹 Cleaning build artifacts..."
	@swift package clean
	@rm -rf *.app
	@rm -f .preflight.xcodebuild.log
	@echo "✅ Clean complete."

# Development build with auto-launch
dev: clean verify run

# Quick build without full verification (for rapid iteration)
quick:
	@echo "⚡ Quick build (skipping preflight)..."
	@swift build

# Run just the preflight checks without building
check:
	@bash scripts/preflight.sh

# Help
help:
	@echo "Universal Emulator (Content Creator Toolkit) Build Commands:"
	@echo ""
	@echo "  make run     - Verify, build and launch the app"
	@echo "  make build   - Verify and build (no launch)"
	@echo "  make verify  - Run preflight checks and build verification"
	@echo "  make check   - Run just the preflight checks"
	@echo "  make app     - Create .app bundle and launch"
	@echo "  make stop    - Stop running app"
	@echo "  make clean   - Clean build artifacts"
	@echo "  make dev     - Clean, verify, build, and launch"
	@echo "  make quick   - Quick build without verification"
	@echo "  make help    - Show this help"
	@echo ""
	@echo "🎯 Content Creator Focus:"
	@echo "  - 'make verify' ensures code quality before commits"
	@echo "  - 'make dev' for full development cycle"
	@echo "  - 'make quick' for rapid iteration"
	@echo ""
	@echo "Quick start: just run 'make' or 'make run'"