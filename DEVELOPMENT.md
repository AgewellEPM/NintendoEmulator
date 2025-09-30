# Universal Emulator Development Guide

## 🛠 Build System

This project uses a comprehensive build verification system to ensure code quality and prevent broken commits.

### Quick Start

```bash
# Build and run with full verification
make run

# Development workflow (clean + verify + build + launch)
make dev

# Quick iteration without verification
make quick

# Just run verification checks
make verify
```

### Available Commands

| Command | Description | Use Case |
|---------|-------------|----------|
| `make run` | Verify, build, and launch | Normal development |
| `make build` | Verify and build only | CI/Testing |
| `make verify` | Run preflight checks | Code quality check |
| `make dev` | Full dev cycle | Starting work session |
| `make quick` | Fast build, skip checks | Rapid iteration |
| `make app` | Create .app bundle | Distribution testing |
| `make clean` | Clean artifacts | Fresh start |
| `make stop` | Stop running app | End session |

### 🔍 Preflight Verification

The `scripts/preflight.sh` script automatically:

1. **Detects Project Type**: Xcode, SwiftPM, Node, Python, or Rust
2. **Runs Appropriate Build**: Uses the right build system
3. **Validates Code Quality**: Swift compile errors, modularity rules
4. **Security Checks**: Prevents hardcoded secrets, tokens
5. **Architecture Guards**: Enforces separation of concerns

### 🎯 Content Creator Toolkit Rules

Special modularity guards for this project:

- ✅ **Social UI** stays separate from **Emulation Core**
- ✅ **API credentials** only in `SocialAPIConfig.swift` placeholders
- ✅ **Streaming logic** belongs in `EmulatorUI/Social/`
- ✅ **Emulation logic** belongs in `EmulatorKit/`
- ❌ **No hardcoded passwords, tokens, or secrets**

### 🚫 Git Hooks Protection

Automatic verification runs before:
- **Commits** (`.githooks/pre-commit`)
- **Pushes** (`.githooks/pre-push`)

If verification fails, the commit/push is blocked until fixed.

### 🏗 Manual Build Types

```bash
# SwiftPM build
swift build

# Xcode build (if .xcodeproj exists)
xcodebuild -project NintendoEmulator.xcodeproj -scheme NintendoEmulator build

# Full verification
./scripts/preflight.sh
```

### 🎮 Content Creator Focus

This project prioritizes:
1. **Social platform integrations** over pure emulation
2. **Streaming workflow tools** for content creators
3. **Cross-platform posting** capabilities
4. **Retro gaming community** features

Build system enforces this architecture through modularity guards.

### 🐛 Troubleshooting

**Build fails with "No Xcode scheme found":**
```bash
export XCODE_SCHEME="NintendoEmulator"
make verify
```

**Want to skip verification temporarily:**
```bash
make quick  # Fast build without checks
```

**Git hooks not working:**
```bash
git config core.hooksPath .githooks
chmod +x .githooks/pre-commit .githooks/pre-push
```

**Modularity guard failures:**
- Check the error message for specific forbidden patterns
- Fix the architectural violation before committing
- Use `make verify` to test fixes

### 📊 Build Logs

Detailed build logs saved to:
- `.preflight.xcodebuild.log` (Xcode builds)
- Console output (SwiftPM builds)

---

**Remember**: The build system is designed to catch problems early and maintain the content creator toolkit's architectural integrity! 🎯