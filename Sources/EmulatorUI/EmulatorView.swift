import SwiftUI
import MetalKit
import EmulatorKit
import RenderingEngine
import CoreInterface
import Combine
import InputSystem

/// NN/g Enhanced Emulator View - Redesigned for Better Usability
public struct EmulatorView: View {
    @ObservedObject var emulatorManager: EmulatorManager
    @EnvironmentObject private var appState: AppState
    @StateObject private var streamingManager = StreamingManager()
    @StateObject private var webcamManager = StreamingWebcamManager()
    @StateObject private var videoRecorder = VideoRecorder()
    @State private var isShowingControls = false
    @State private var currentFPS: Double = 0
    @State private var showPerformanceOverlay = false
    @State private var showingGameMenu = false
    @State private var showingControlsSettings = false
    @State private var showingQuickSave = false
    @State private var showingStreamingSettings = false
    @State private var ghostBridgeInitialized = false
    @State private var isFullscreen = false
    @State private var videoScale: CGFloat = 1.0
    @State private var showingSaveStateManager = false

    public init(emulatorManager: EmulatorManager) {
        self.emulatorManager = emulatorManager
    }

    // Map EmulatorManager state to our expected state
    private var emulatorState: EmulatorState {
        if emulatorManager.isRunning {
            return .running
        } else if emulatorManager.isPaused {
            return .paused
        } else if emulatorManager.currentCore != nil {
            return .romLoaded
        } else {
            return .stopped
        }
    }

    public var body: some View {
        VStack(spacing: 0) {
            // NN/g: Prominent Game Header - Clear Visual Hierarchy
            GameSessionHeader(
                gameTitle: emulatorManager.currentROM?.title ?? "No Game Loaded",
                emulatorState: emulatorState,
                fps: emulatorManager.performance.fps,
                streamStatus: streamingManager.streamStatus,
                onGameMenu: { showingGameMenu = true },
                onStreamSettings: { /* Handle stream settings */ }
            )

            // Main content area with proper proportions
            HStack(spacing: 0) {
                // Primary emulator area - optimized layout
                ZStack {
                    // Game display
                    // Enhanced emulator display with PiP support
                    PIPEnhancedEmulatorDisplay(emulatorManager: emulatorManager)
                        .scaleEffect(videoScale)
                        .onAppear {
                            setupEmulator()
                        }
                        .overlay(
                            // Game state overlays with clear messaging
                            Group {
                                switch emulatorState {
                                case .uninitialized, .initialized:
                                    LoadingGameOverlay()
                                case .stopped:
                                    if emulatorManager.currentCore == nil {
                                        GameSelectionPrompt()
                                    }
                                case .paused:
                                    PauseOverlay(onResume: { resumeGame() })
                                case .running, .romLoaded:
                                    EmptyView()
                                case .error:
                                    ErrorOverlay(message: "Emulator error occurred", onRetry: { retryGame() })
                                }
                            }
                        )

                    // Performance overlay
                    if showPerformanceOverlay {
                        PerformanceInfoCard(
                            metrics: emulatorManager.performance,
                            onDismiss: { showPerformanceOverlay = false }
                        )
                    }

                    // Touch controls overlay (mobile-friendly)
                    if isShowingControls {
                        TouchControlsOverlay()
                    }

                    // Webcam overlay for streaming
                    StreamingWebcamOverlay(webcamManager: webcamManager)

                    // Quick save notification
                    if showingQuickSave {
                        QuickActionNotification(message: "State Saved")
                            .onAppear {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                    showingQuickSave = false
                                }
                            }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.black)
                .focusable(true)
                .gesture(
                    MagnificationGesture()
                        .onChanged { value in
                            videoScale = max(0.5, min(3.0, value))
                        }
                )
                .if14Plus(content: { view in
                    if #available(macOS 14.0, *) {
                        view.onKeyPress(phases: [.down]) { keyPress in
                            return handleKeyPress(keyPress)
                        }
                    } else {
                        view
                    }
                })

                // Stream chat sidebar with AI controls
                if appState.showStreamChat {
                    VStack(spacing: 0) {
                        StreamChatView()
                            .frame(maxHeight: .infinity)

                        Divider()

                        // Streaming controls panel with all features
                        StreamingControlsPanel()
                            .frame(height: 250)

                        Divider()

                        // Webcam controls for streaming
                        WebcamControlPanel(webcamManager: webcamManager)
                            .frame(height: 200)
                    }
                    .frame(width: 320)
                }
            }

            // NN/g: Accessible Control Panel - Always Visible (unless fullscreen)
            if !isFullscreen {
                GameControlPanel(
                    emulatorManager: emulatorManager,
                    isShowingControls: $isShowingControls,
                    showingControlsSettings: $showingControlsSettings,
                    showPerformanceOverlay: $showPerformanceOverlay,
                    videoScale: $videoScale,
                    isFullscreen: $isFullscreen,
                    showingSaveStateManager: $showingSaveStateManager,
                    videoRecorder: videoRecorder,
                    onQuickSave: performQuickSave,
                    onQuickLoad: performQuickLoad,
                    onToggleStream: toggleStreamChat,
                    onSyncControllers: { syncControllersToEmulator() }
                )
            }
        }
        .sheet(isPresented: $showingGameMenu) {
            SettingsView(currentTab: .constant(.settings))
        }
        .sheet(isPresented: $showingControlsSettings) {
            InputSettingsView(
                vibrationEnabled: .constant(true),
                analogDeadzone: .constant(0.1),
                analogSensitivity: .constant(1.0)
            )
        }
        .sheet(isPresented: $showingStreamingSettings) {
            GhostBridgeStreamingSettings(
                streamingManager: streamingManager,
                webcamManager: webcamManager
            )
        }
        .sheet(isPresented: $showingSaveStateManager) {
            SaveStateManagerView(emulatorManager: emulatorManager)
        }
        .onAppear {
            initializeGhostBridge()
        }
    }

    // MARK: - Actions
    private func setupEmulator() {
        // Wire input systems to the running emulator instance
        // ControllerManager forwards GameController input via EmulatorInputProtocol
        for player in 0..<4 {
            ControllerManager.shared.setInputDelegate(emulatorManager, for: player)
            KeyboardHandler.shared.setInputDelegate(emulatorManager, for: player)
        }

        // Best-effort: auto-assign currently connected controllers to player slots
        let controllers = ControllerManager.shared.controllers
        for (idx, controller) in controllers.enumerated() where idx < 4 {
            ControllerManager.shared.assignController(controller, to: idx)
        }
    }

    @available(macOS 14.0, *)
    private func handleKeyPress(_ keyPress: KeyPress) -> KeyPress.Result {
        switch keyPress.key {
        case .space:
            if emulatorState == .running {
                pauseGame()
            } else if emulatorState == .paused {
                resumeGame()
            }
            return .handled
        case .escape:
            if isFullscreen {
                isFullscreen = false
            } else if emulatorState != .stopped {
                showingGameMenu = true
            }
            return .handled
        case KeyEquivalent("f"):
            if keyPress.modifiers.contains(.command) {
                isFullscreen.toggle()
                return .handled
            }
            return .ignored
        case KeyEquivalent("="), KeyEquivalent("+"):
            if keyPress.modifiers.contains(.command) {
                videoScale = min(3.0, videoScale + 0.1)
                return .handled
            }
            return .ignored
        case KeyEquivalent("-"):
            if keyPress.modifiers.contains(.command) {
                videoScale = max(0.5, videoScale - 0.1)
                return .handled
            }
            return .ignored
        case KeyEquivalent("0"):
            if keyPress.modifiers.contains(.command) {
                videoScale = 1.0
                return .handled
            }
            return .ignored
        case KeyEquivalent("s"):
            if keyPress.modifiers.contains(.command) && keyPress.modifiers.contains(.shift) {
                showingSaveStateManager = true
                return .handled
            } else if keyPress.modifiers.contains(.command) {
                performQuickSave()
                return .handled
            }
            return .ignored
        case KeyEquivalent("l"):
            if keyPress.modifiers.contains(.command) {
                performQuickLoad()
                return .handled
            }
            return .ignored
        case KeyEquivalent("1"), KeyEquivalent("2"), KeyEquivalent("3"),
             KeyEquivalent("4"), KeyEquivalent("5"), KeyEquivalent("6"),
             KeyEquivalent("7"), KeyEquivalent("8"), KeyEquivalent("9"):
            // Quick save/load to numbered slots (Cmd+number to save, Cmd+Shift+number to load)
            if let digit = Int(String(keyPress.characters.first ?? "0")) {
                let slot = digit - 1
                if keyPress.modifiers.contains(.command) && keyPress.modifiers.contains(.shift) {
                    Task { try? await emulatorManager.loadState(slot: slot) }
                    return .handled
                } else if keyPress.modifiers.contains(.command) {
                    Task { try? await emulatorManager.saveState(slot: slot) }
                    return .handled
                }
            }
            return .ignored
        default:
            return .ignored
        }
    }

    private func pauseGame() {
        Task { await emulatorManager.pause() }
    }

    private func resumeGame() {
        Task { try? await emulatorManager.resume() }
    }

    private func retryGame() {
        setupEmulator()
    }

    private func performQuickSave() {
        showingQuickSave = true
        Task { try? await emulatorManager.quickSave() }
    }

    private func performQuickLoad() {
        Task { try? await emulatorManager.quickLoad() }
    }

    private func syncControllersToEmulator() {
        // Re-wire delegates and refresh assignments on demand
        for player in 0..<4 {
            ControllerManager.shared.setInputDelegate(emulatorManager, for: player)
            KeyboardHandler.shared.setInputDelegate(emulatorManager, for: player)
        }
        let controllers = ControllerManager.shared.controllers
        for (idx, controller) in controllers.enumerated() where idx < 4 {
            ControllerManager.shared.assignController(controller, to: idx)
        }
    }

    private func toggleStreamChat() {
        appState.showStreamChat.toggle()
    }

    private func initializeGhostBridge() {
        guard !ghostBridgeInitialized else { return }

        Task {
            ghostBridgeInitialized = await streamingManager.initializeGhostBridge()
            if ghostBridgeInitialized {
                NSLog("👻 GhostBridge ready for advanced streaming")
            }
        }
    }
}

// MARK: - NN/g Enhanced Components

/// Prominent game session header with clear information hierarchy
struct GameSessionHeader: View {
    let gameTitle: String
    let emulatorState: EmulatorState
    let fps: Double
    let streamStatus: StreamStatus
    let onGameMenu: () -> Void
    let onStreamSettings: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            // Game info - most important information
            HStack(spacing: DesignSystem.Spacing.md) {
                // Game status indicator
                StatusIndicatorDot(state: emulatorState)

                VStack(alignment: .leading, spacing: 2) {
                    Text(gameTitle)
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    HStack(spacing: DesignSystem.Spacing.lg) {
                        Text(emulatorState.displayText)
                            .font(.subheadline)
                            .foregroundColor(emulatorState.displayColor)

                        if emulatorState == .running {
                            Text("\(Int(fps)) FPS")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }

            Spacer()

            // Stream status and controls
            StreamStatusBadge(status: streamStatus)

            // Quick actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: onGameMenu) {
                    Image(systemName: "ellipsis.circle")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Game Menu")

                Button(action: onStreamSettings) {
                    Image(systemName: "gear")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Stream Settings")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }
}

/// Redesigned game control panel with better organization
struct GameControlPanel: View {
    let emulatorManager: EmulatorManager
    @Binding var isShowingControls: Bool
    @Binding var showingControlsSettings: Bool
    @Binding var showPerformanceOverlay: Bool
    @Binding var videoScale: CGFloat
    @Binding var isFullscreen: Bool
    @Binding var showingSaveStateManager: Bool
    @ObservedObject var videoRecorder: VideoRecorder
    let onQuickSave: () -> Void
    let onQuickLoad: () -> Void
    let onToggleStream: () -> Void
    var onSyncControllers: (() -> Void)? = nil

    private var emulatorState: EmulatorState {
        if emulatorManager.isRunning {
            return .running
        } else if emulatorManager.isPaused {
            return .paused
        } else if emulatorManager.currentCore != nil {
            return .romLoaded
        } else {
            return .stopped
        }
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Primary game controls - most important actions
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Main game control
                Button(action: {
                    Task {
                        switch emulatorState {
                        case .running:
                            await emulatorManager.pause()
                        case .paused:
                            try? await emulatorManager.resume()
                        case .romLoaded, .initialized, .uninitialized, .stopped:
                            try? await emulatorManager.start()
                        case .error:
                            break
                        }
                    }
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: emulatorState == .running ? "pause.fill" : "play.fill")
                            .font(.title3)
                        Text({
                            switch emulatorState {
                            case .running: return "Pause"
                            case .paused: return "Resume"
                            default: return "Play"
                            }
                        }())
                            .font(.headline)
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(emulatorState == .running ? Color.orange : Color.blue)
                    )
                }
                .buttonStyle(.plain)

                // Stop button
                Button(action: {
                    Task {
                        await emulatorManager.stop()
                    }
                }) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "stop.fill")
                        Text("Stop")
                    }
                    .foregroundColor(.white)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.red)
                    )
                }
                .buttonStyle(.plain)

                Spacer()

                // Secondary controls
                HStack(spacing: DesignSystem.Spacing.md) {
                    ControlButton(icon: "externaldrive", label: "Quick Save", action: onQuickSave)
                    ControlButton(icon: "folder", label: "Quick Load", action: onQuickLoad)
                    ControlButton(icon: "square.grid.3x3.fill", label: "Save Manager",
                                  action: { showingSaveStateManager = true })
                    ControlButton(
                        icon: videoRecorder.isRecording ? "record.circle.fill" : "record.circle",
                        label: videoRecorder.isRecording ? "Stop Recording" : "Record",
                        isActive: videoRecorder.isRecording,
                        action: { Task { try? await videoRecorder.toggleRecording() } }
                    )
                    ControlButton(icon: "arrow.up.left.and.arrow.down.right",
                                  label: "Fullscreen",
                                  isActive: isFullscreen,
                                  action: { isFullscreen.toggle() })
                    ControlButton(icon: "gamecontroller", label: "Controls",
                                  isActive: isShowingControls,
                                  action: { isShowingControls.toggle() })
                    ControlButton(icon: "message", label: "Chat", action: onToggleStream)
                    if let onSyncControllers {
                        ControlButton(icon: "arrow.triangle.2.circlepath", label: "Sync Controllers", action: onSyncControllers)
                    }
                }
            }

            // Secondary controls row
            HStack(spacing: DesignSystem.Spacing.lg) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Toggle("Performance Info", isOn: $showPerformanceOverlay)
                        .toggleStyle(.switch)
                        .controlSize(.mini)

                    Toggle("Touch Controls", isOn: $isShowingControls)
                        .toggleStyle(.switch)
                        .controlSize(.mini)
                }

                // Zoom controls
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text("Zoom:")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Button("-") {
                        videoScale = max(0.5, videoScale - 0.1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Text("\(Int(videoScale * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 45)

                    Button("+") {
                        videoScale = min(3.0, videoScale + 0.1)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)

                    Button("Reset") {
                        videoScale = 1.0
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }

                Spacer()

                Button("Controller Settings") {
                    showingControlsSettings = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }
}

/// Reusable control button component
struct ControlButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(isActive ? .blue : .secondary)

                Text(label)
                    .font(.caption2)
                    .foregroundColor(isActive ? .blue : .secondary)
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

/// Status indicator dot with clear visual feedback
struct StatusIndicatorDot: View {
    let state: EmulatorState

    var body: some View {
        Circle()
            .fill(state.indicatorColor)
            .frame(width: 12, height: 12)
            .overlay(
                Circle()
                    .stroke(state.indicatorColor.opacity(0.3), lineWidth: 4)
                    .scaleEffect(state == .running ? 1.5 : 1.0)
                    .opacity(state == .running ? 0 : 1)
                    .animation(.easeInOut(duration: 1).repeatForever(autoreverses: false),
                               value: state == .running)
            )
    }
}

/// Stream status badge
struct StreamStatusBadge: View {
    let status: StreamStatus

    private var isLive: Bool {
        status == .live
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(isLive ? Color.red : Color.gray)
                .frame(width: 8, height: 8)

            Text(isLive ? "LIVE" : "OFFLINE")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(isLive ? .red : .secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.1))
        )
    }
}

// StreamingSidePanel moved to use existing working components

/// Loading game overlay
struct LoadingGameOverlay: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

            Text("Loading Game...")
                .font(.title2)
                .foregroundColor(.white)
        }
        .padding(40)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}

/// Game selection prompt
struct GameSelectionPrompt: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "gamecontroller")
                .font(.system(size: 80))
                .foregroundColor(.white.opacity(0.6))

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Ready to Stream")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text("Select a game from your library to start streaming")
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Button("Browse Games") {
                NotificationCenter.default.post(name: .switchToGamesTab, object: nil)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
    }
}

/// Pause overlay
struct PauseOverlay: View {
    let onResume: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "pause.circle.fill")
                .font(.system(size: 80))
                .foregroundColor(.white)

            Text("Game Paused")
                .font(.title)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Button("Resume") {
                onResume()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}

/// Error overlay
struct ErrorOverlay: View {
    let message: String
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 80))
                .foregroundColor(.red)

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Error")
                    .font(.title)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
            }

            Button("Retry") {
                onRetry()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
        }
        .padding(40)
        .background(Color.black.opacity(0.8))
        .cornerRadius(16)
    }
}

/// Performance info card
struct PerformanceInfoCard: View {
    let metrics: PerformanceMetrics
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Text("Performance")
                    .font(.headline)
                    .foregroundColor(.white)

                Spacer()

                Button(action: onDismiss) {
                    Image(systemName: "xmark")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("FPS: \(Int(metrics.fps))")
                    .foregroundColor(.white)
                Text("Frame Time: \(String(format: "%.1f", metrics.frameTime))ms")
                    .foregroundColor(.white)
                Text("CPU: \(Int(metrics.cpuUsage))%")
                    .foregroundColor(.white)
            }
            .font(.caption)
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.black.opacity(0.8))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

/// Touch controls overlay
struct TouchControlsOverlay: View {
    var body: some View {
        // Placeholder for touch controls
        Text("Touch Controls")
            .foregroundColor(.white.opacity(0.5))
    }
}

/// Quick action notification
struct QuickActionNotification: View {
    let message: String

    var body: some View {
        Text(message)
            .font(.headline)
            .foregroundColor(.white)
            .padding()
            .background(Color.green)
            .cornerRadius(DesignSystem.Radius.lg)
            .transition(.scale.combined(with: .opacity))
    }
}

/// Recording indicator
struct RecordingIndicator: View {
    let duration: String
    @State private var pulse = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .scaleEffect(pulse ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: pulse)
                .onAppear { pulse = true }

            Text("REC")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)

            Text(duration)
                .font(.system(.body, design: .monospaced))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.black.opacity(0.8))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(Color.red, lineWidth: 2)
        )
    }
}

// MARK: - Supporting Types and Extensions

extension EmulatorState {
    var displayText: String {
        switch self {
        case .uninitialized: return "Initializing..."
        case .initialized: return "Ready"
        case .romLoaded: return "ROM Loaded"
        case .stopped: return "Stopped"
        case .running: return "Running"
        case .paused: return "Paused"
        case .error: return "Error"
        }
    }

    var displayColor: Color {
        switch self {
        case .uninitialized: return .blue
        case .initialized: return .secondary
        case .romLoaded: return .yellow
        case .stopped: return .secondary
        case .running: return .green
        case .paused: return .orange
        case .error: return .red
        }
    }

    var indicatorColor: Color {
        switch self {
        case .uninitialized: return .blue
        case .initialized: return .gray
        case .romLoaded: return .yellow
        case .stopped: return .gray
        case .running: return .green
        case .paused: return .orange
        case .error: return .red
        }
    }
}

// StreamStatus is now handled by the StreamingManager enum

extension View {
    @ViewBuilder
    func if14Plus<Content: View>(@ViewBuilder transform: (Self) -> Content) -> some View {
        if #available(macOS 14.0, *) {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Notification Names
extension Notification.Name {
    static let switchToGamesTab = Notification.Name("switchToGamesTab")
}
