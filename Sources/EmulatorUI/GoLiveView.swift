import SwiftUI
import AppKit
import EmulatorKit
import CoreInterface
import N64MupenAdapter

/// NN/g Compliant Go Live View - Clean, Focused Interface
public struct GoLiveView: View {
    @ObservedObject var emulatorManager: EmulatorManager
    @StateObject private var streamingManager = StreamingManager()
    @StateObject private var webcamManager = StreamingWebcamManager()
    @StateObject private var gameWindowCapture = GameWindowCaptureManager()
    @StateObject private var gameWindowCapture2 = GameWindowCaptureManager()
    @State private var selectedROM: ROMMetadata?
    @State private var showingStreamSetup = false
    @State private var showingROMBrowser = false
    @State private var streamEntireDesktop = true
    @State private var showPermissionWizard = false
    @State private var srAuthorized = false
    @State private var axAuthorized = false
    @State private var gameWindowSize: GameWindowSize = .medium
    @EnvironmentObject private var romManager: ROMManager

    public init(emulatorManager: EmulatorManager) {
        self.emulatorManager = emulatorManager
    }

    public var body: some View {
        VStack(spacing: 0) {
            // NN/g: Clear navigation header
            navigationHeader

            // Permission banner if needed
            if (!srAuthorized) || (!axAuthorized) {
                permissionBanner
            }

            Divider()
                .background(Color.gray.opacity(0.3))

            // Main content with proper visual hierarchy
            HStack(spacing: 24) {
                // Primary content area (70% width)
                VStack(alignment: .leading, spacing: 20) {
                    // NN/g: Clear page title and purpose
                    pageHeader

                    // Game selection area
                    gameSelectionSection

                    // Game display area
                    gameDisplayArea

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .padding(.leading, 24)

                // Secondary sidebar (30% width)
                streamingSidebar
                    .frame(width: 320)
                    .background(Color.gray.opacity(0.05))
            }
            .padding(.top, 20)

            // Bottom action bar
            bottomActionBar
        }
        .background(Color(NSColor.windowBackgroundColor))
        .onAppear {
            initializeGhostBridge()
            // Set the current ROM if one is loaded in the emulator
            if let currentROM = emulatorManager.currentROM {
                selectedROM = currentROM
            }
            // Ensure ROM library is loaded so the selector shows games
            Task { @MainActor in
                await romManager.loadROMs()
            }
            // Default to streaming entire desktop at 90 FPS on launch
            streamingManager.configureCapture(mode: .fullScreen, fps: 90)
            // Start a local screen-capture preview immediately so the preview is not black
            streamingManager.startLocalPreview()
            // If permission is not granted, surface the wizard immediately
            if !GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized() {
                NotificationCenter.default.post(name: .showPermissionWizard, object: nil)
            }
            // Track permission states for banner
            if #available(macOS 10.15, *) {
                srAuthorized = GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized()
            } else {
                srAuthorized = true
            }
            axAuthorized = GhostBridgeHelper.isAccessibilityEffectivelyTrusted()
        }
        .onDisappear {
            // Stop preview if user leaves the view and we're not actively streaming
            streamingManager.stopLocalPreview()
        }
        // Auto-recheck permission status while banner is visible
        .onReceive(Timer.publish(every: 1.0, on: .main, in: .common).autoconnect()) { _ in
            if #available(macOS 10.15, *) {
                srAuthorized = GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized()
            } else {
                srAuthorized = true
            }
            axAuthorized = GhostBridgeHelper.isAccessibilityEffectivelyTrusted()
        }
        .sheet(isPresented: $showingROMBrowser) {
            SimpleROMSelector(selectedGame: $selectedROM)
                .environmentObject(romManager)
        }
        .onChange(of: selectedROM?.id) { newROMId in
            if newROMId != nil {
                showingROMBrowser = false
            }
        }
        .sheet(isPresented: $showingStreamSetup) {
            GhostBridgeStreamingSettings(streamingManager: streamingManager, webcamManager: webcamManager)
        }
        .sheet(isPresented: $showPermissionWizard) {
            PermissionWizardView()
        }
    }

    // MARK: - Header Components

    private var navigationHeader: some View {
        HStack {
            Button("← Back to Dashboard") {
                // Navigate back to streaming dashboard
                NotificationCenter.default.post(name: .navigateToDashboard, object: nil)
            }
            .buttonStyle(.plain)
            .foregroundColor(.blue)

            Spacer()

            Text("Go Live")
                .font(.title2)
                .fontWeight(.semibold)

            Spacer()

            // Status + Health + Diagnostics
            HStack(spacing: 12) {
                // Live status
                HStack(spacing: 6) {
                    Circle()
                        .fill(streamingManager.isStreaming ? .green : .gray)
                        .frame(width: 8, height: 8)
                    Text(streamingManager.isStreaming ? "Live" : "Preview")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Health icons (Screen Recording, Accessibility, Capture session)
                HStack(spacing: 6) {
                    Image(systemName: "record.circle.fill").foregroundColor(srAuthorized ? .green : .orange)
                        .help("Screen Recording permission")
                    Image(systemName: "accessibility").foregroundColor(axAuthorized ? .green : .orange)
                        .help("Accessibility permission")
                    Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(streamingManager.hasCaptureSession ? .green : .orange)
                        .help("Capture session running")
                }
                .imageScale(.small)

                // Copy diagnostics
                Button {
                    copyDiagnostics()
                } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy streaming diagnostics to clipboard")

                // Refresh caches
                Button {
                    refreshCaches()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.borderless)
                .help("Refresh caches (permissions, window list, capture)")
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private var pageHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Start Your Gaming Stream")
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(.primary)

            Text("Select a game and configure your streaming settings")
                .font(.body)
                .foregroundColor(.secondary)
        }
    }

    // Compose and copy diagnostics snapshot to pasteboard
    private func copyDiagnostics() {
        let bundleID = Bundle.main.bundleIdentifier ?? "(unknown)"
        let appPath = Bundle.main.bundleURL.path
        let diag = """
        BundleID: \(bundleID)
        AppPath: \(appPath)
        ScreenRecording: \(srAuthorized)
        Accessibility: \(axAuthorized)
        CaptureMode: \(streamingManager.captureMode.rawValue)
        FPS: \(streamingManager.desiredFrameRate)
        LastWindowOwner: \(streamingManager.lastWindowOwner ?? "-")
        LastWindowTitle: \(streamingManager.lastWindowTitle ?? "-")
        CropRect: \(String(describing: streamingManager.lastCropRect))
        HasCaptureSession: \(streamingManager.hasCaptureSession)
        IsStreaming: \(streamingManager.isStreaming)
        """
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(diag, forType: .string)
    }

    private func refreshCaches() {
        Task { @MainActor in
            await streamingManager.refreshCaches()
            if #available(macOS 10.15, *) {
                srAuthorized = GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized()
            } else {
                srAuthorized = true
            }
            axAuthorized = GhostBridgeHelper.isAccessibilityEffectivelyTrusted()
            NotificationCenter.default.post(name: .showToastMessage, object: "Caches refreshed")
        }
    }

    private var permissionBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: (!srAuthorized || !axAuthorized) ? "exclamationmark.triangle.fill" : "checkmark.seal.fill")
                .foregroundColor((!srAuthorized || !axAuthorized) ? .orange : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Permissions Needed for Live Preview")
                    .font(.subheadline).bold()
                HStack(spacing: 8) {
                    if !srAuthorized { Label("Screen Recording", systemImage: "record.circle") }
                    if !axAuthorized { Label("Accessibility", systemImage: "accessibility") }
                }
                .font(.caption)
                .foregroundColor(.secondary)
            }
            Spacer()
            Button("Open Wizard") { showPermissionWizard = true }
                .buttonStyle(.borderedProminent)
            Menu("More…") {
                if !srAuthorized {
                    Button("Open Screen Recording Settings") { GhostBridgeHelper.openSystemSettingsToScreenRecording() }
                }
                if !axAuthorized {
                    Button("Prompt Accessibility") { GhostBridgeHelper.promptAccessibility(always: true) }
                    Button("Open Accessibility Settings") { GhostBridgeHelper.openSystemSettingsToAccessibility() }
                }
                Button("Recheck Status") {
                    if #available(macOS 10.15, *) { srAuthorized = GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized() } else { srAuthorized = true }
                    axAuthorized = GhostBridgeHelper.isAccessibilityEffectivelyTrusted()
                }
            }
            .menuStyle(.borderlessButton)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.orange.opacity(0.1))
    }

    // MARK: - Game Selection

    private var gameSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose Your Game")
                .font(.headline)
                .fontWeight(.semibold)

            if let rom = selectedROM {
                // Selected game card
                HStack {
                    // No box art available in ROMMetadata, use placeholder
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.3))
                        .overlay(
                            Image(systemName: "gamecontroller")
                                .foregroundColor(.gray)
                        )
                    .frame(width: 60, height: 80)
                    .cornerRadius(8)

                    VStack(alignment: .leading, spacing: 4) {
                        Text(rom.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(rom.system.displayName)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Ready to stream")
                            .font(.caption)
                            .foregroundColor(.green)
                    }

                    Spacer()

                    Button("Change Game") {
                        showingROMBrowser = true
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.blue.opacity(0.3), lineWidth: 1)
                )
            } else {
                // Game selection prompt
                Button(action: {
                    showingROMBrowser = true
                }) {
                    HStack {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading) {
                            Text("Select a Game to Stream")
                                .font(.headline)
                            Text("Choose from your ROM library")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .foregroundColor(.blue)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(12)
                }
                .buttonStyle(.plain)

                // Direct open fallback
                Button(action: openROMFilePicker) {
                    HStack {
                        Image(systemName: "folder.fill")
                            .foregroundColor(.blue)
                        Text("Open ROM File…")
                        Spacer()
                    }
                    .padding(10)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Game Display

    private var gameDisplayArea: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Stream Previews")
                .font(.headline)
                .fontWeight(.semibold)

            // 3 Viewport Layout
            HStack(spacing: 12) {
                // Viewport 1: Desktop Capture
                viewportDesktopCapture

                // Viewport 2: Game + Terminal (middle)
                viewportGameWithTerminal

                // Viewport 3: Game Window Only
                viewportGameOnly
            }
        }
    }

    // Viewport 1: Full Desktop Capture
    private var viewportDesktopCapture: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Desktop Capture")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ZStack {
                if let session = streamingManager.captureSession {
                    ScreenCapturePreview(session: session)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                } else if emulatorManager.isRunning {
                    PIPEnhancedEmulatorDisplay(emulatorManager: emulatorManager)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "display")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                Text("Desktop")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }

                if webcamManager.isWebcamEnabled {
                    VStack {
                        HStack {
                            Spacer()
                            webcamPreview
                                .padding(.top, 8)
                                .padding(.trailing, 8)
                        }
                        Spacer()
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
            )
        }
    }

    // Viewport 2: Game + Terminal Overlay
    private var viewportGameWithTerminal: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game + Terminal")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ZStack {
                if gameWindowCapture2.isCapturing {
                    WindowCapturePreview(manager: gameWindowCapture2)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                } else if emulatorManager.isRunning {
                    PIPEnhancedEmulatorDisplay(emulatorManager: emulatorManager)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "terminal")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                Text("Game + Terminal")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }

                // Terminal overlay
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        terminalOverlay
                            .padding(.trailing, 12)
                            .padding(.bottom, 12)
                    }
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.purple.opacity(0.3), lineWidth: 2)
            )
        }
    }

    // Viewport 3: Game Window Only
    private var viewportGameOnly: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Game Only")
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            ZStack {
                if gameWindowCapture.isCapturing {
                    WindowCapturePreview(manager: gameWindowCapture)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                } else if emulatorManager.isRunning {
                    PIPEnhancedEmulatorDisplay(emulatorManager: emulatorManager)
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(8)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.black)
                        .aspectRatio(16/9, contentMode: .fit)
                        .overlay(
                            VStack(spacing: 8) {
                                Image(systemName: "gamecontroller")
                                    .font(.system(size: 24))
                                    .foregroundColor(.gray)
                                Text("Game Window")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                        )
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.green.opacity(0.3), lineWidth: 2)
            )
        }
    }

    // Terminal overlay window
    private var terminalOverlay: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "terminal.fill")
                    .font(.system(size: 10))
                    .foregroundColor(.green)
                Text("Terminal")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.top, 6)

            VStack(alignment: .leading, spacing: 2) {
                Text("$ ./start-emulator")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.green)
                Text("Emulator running...")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.white)
                Text("FPS: 60 | Audio: OK")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundColor(.gray)
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .frame(width: 150, height: 80)
        .background(Color.black.opacity(0.85))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.green.opacity(0.5), lineWidth: 1)
        )
    }

    private var webcamPreview: some View {
        RoundedRectangle(cornerRadius: 8)
            .fill(Color.gray.opacity(0.8))
            .frame(width: 120, height: 90)
            .overlay(
                Group {
                    if let image = webcamManager.webcamImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "person.crop.circle")
                                .foregroundColor(.white)
                            Text("Webcam")
                                .font(.caption2)
                                .foregroundColor(.white)
                        }
                    }
                }
            )
            .cornerRadius(8)
    }

    // MARK: - Streaming Sidebar

    private var streamingSidebar: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Stream Settings")
                .font(.headline)
                .fontWeight(.semibold)
                .padding(.horizontal, 16)
                .padding(.top, 20)

            ScrollView {
                VStack(spacing: 16) {
                    // Quick streaming toggle
                    streamingToggleCard

                    // Desktop capture mode (GhostBridge)
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "display")
                                .foregroundColor(.blue)
                            Text("Capture Mode")
                                .font(.subheadline)
                                .fontWeight(.medium)
                        }
                        Toggle("Stream Entire Desktop (GhostBridge)", isOn: $streamEntireDesktop)
                            .toggleStyle(SwitchToggleStyle())
                            .onChange(of: streamEntireDesktop) { on in
                                streamingManager.configureCapture(mode: on ? .fullScreen : .window, fps: on ? 90 : 60)
                            }
                        if streamEntireDesktop {
                            Text("Captures the full screen at high FPS. Use when the game runs in a terminal or external window.")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                    .background(
                        Color.black.opacity(0.7)
                            .overlay(
                                Color.white.opacity(0.05)
                            )
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.1), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                    // Game Window Size
                    gameWindowSizeCard

                    // Webcam settings
                    webcamSettingsCard

                    // Stream info
                    streamInfoCard
                }
                .padding(.horizontal, 16)
            }

            Spacer()
        }
    }

    private var streamingToggleCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "video.circle.fill")
                    .foregroundColor(.blue)
                Text("Streaming")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Toggle("Enable Streaming", isOn: .constant(streamingManager.isStreaming))
                .toggleStyle(SwitchToggleStyle())
                .onChange(of: streamingManager.isStreaming) { _ in
                    // Toggle handled by the Go Live button below
                }

            if streamingManager.isStreaming {
                HStack {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .foregroundColor(.green)
                    Text("Live on Twitch")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(
            Color.black.opacity(0.7)
                .overlay(
                    Color.white.opacity(0.05)
                )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    private var webcamSettingsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "camera.circle.fill")
                    .foregroundColor(.blue)
                Text("Webcam")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Toggle("Show Webcam", isOn: $webcamManager.isWebcamEnabled)
                .toggleStyle(SwitchToggleStyle())

            if webcamManager.isWebcamEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Position: \(webcamManager.webcamPosition.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Size: \(webcamManager.webcamSize.rawValue)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            Color.black.opacity(0.7)
                .overlay(
                    Color.white.opacity(0.05)
                )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    private var streamInfoCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("Stream Info")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            VStack(alignment: .leading, spacing: 8) {
                if streamingManager.isStreaming {
                    Label("Live for 0:45", systemImage: "clock")
                        .font(.caption)
                    Label("12 viewers", systemImage: "person.2")
                        .font(.caption)
                    Label("1080p 60fps", systemImage: "video")
                        .font(.caption)
                } else {
                    Text("Not streaming")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            Color.black.opacity(0.7)
                .overlay(
                    Color.white.opacity(0.05)
                )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    // MARK: - Bottom Action Bar

    private var bottomActionBar: some View {
        HStack {
            // Game controls
            HStack(spacing: 12) {
                if selectedROM != nil {
                    Button(action: startGame) {
                        HStack {
                            Image(systemName: emulatorManager.isRunning ? "pause.fill" : "play.fill")
                            Text(emulatorManager.isRunning ? "Pause" : "Start Game")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    if emulatorManager.isRunning || emulatorManager.isPaused {
                        Button("Stop") {
                            Task {
                                await emulatorManager.stop()
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.large)
                    }
                }
            }

            Spacer()

            // Stream controls
            HStack(spacing: 12) {
                Button("Advanced Settings") {
                    showingStreamSetup = true
                }
                .buttonStyle(.bordered)

                if selectedROM != nil {
                    Button(action: toggleStreaming) {
                        HStack {
                            Image(systemName: streamingManager.isStreaming ? "stop.circle.fill" : "video.circle.fill")
                            Text(streamingManager.isStreaming ? "Stop Stream" : "Go Live")
                        }
                        .frame(minWidth: 100)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .foregroundColor(streamingManager.isStreaming ? .red : .white)
                }
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 16)
        .background(Color(NSColor.controlBackgroundColor))
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(Color.gray.opacity(0.3)),
            alignment: .top
        )
    }

    // MARK: - Actions

    private func startGame() {
        guard let rom = selectedROM else { return }
        Task {
            do {
                if emulatorManager.isRunning && !emulatorManager.isPaused {
                    // Currently running - pause it
                    await emulatorManager.pause()
                    NSLog("🎮 Game paused")
                } else if emulatorManager.isPaused {
                    // Currently paused - resume it
                    try await emulatorManager.resume()
                    NSLog("🎮 Game resumed")
                } else {
                    // Not running - start it
                    NSLog("🎮 Loading ROM: \(rom.title)")

                    // Apply window size settings
                    if let res = gameWindowSize.resolution {
                        N64MupenAdapter.windowResolution = "\(res.width)x\(res.height)"
                        N64MupenAdapter.isFullscreen = false
                    } else {
                        N64MupenAdapter.isFullscreen = true
                    }

                    try await emulatorManager.openROM(at: rom.path)
                    try await emulatorManager.start()
                    NSLog("🎮 Game started")

                    // Start window captures after game launches
                    try await Task.sleep(nanoseconds: 1_500_000_000)
                    await MainActor.run {
                        gameWindowCapture.start()
                        gameWindowCapture2.start()
                        NSLog("🎥 Started game window captures")
                    }
                }
            } catch {
                NSLog("❌ Game control error: \(error)")
            }
        }
    }

    private func toggleStreaming() {
        Task {
            do {
                if streamingManager.isStreaming {
                    NSLog("🛑 Stopping stream...")
                    await streamingManager.stopStream()
                    NSLog("🛑 Stream stopped")
                    // Resume local preview so the pane is not blank
                    streamingManager.startLocalPreview()
                } else {
                    let title = selectedROM?.title ?? "Gaming Stream"
                    NSLog("🚀 Starting stream for: \(title)")
                    NSLog("🔧 GhostBridge ready: \(streamingManager.ghostBridgeReady)")
                    NSLog("🔧 Permissions granted: \(streamingManager.permissionsGranted)")
                    if !streamingManager.permissionsGranted {
                        // Surface the permissions wizard to the user
                        NotificationCenter.default.post(name: .showPermissionWizard, object: nil)
                    }
                    // Honor the capture mode selection before starting
                    if streamEntireDesktop { streamingManager.configureCapture(mode: .fullScreen, fps: 90) }
                    try await streamingManager.startGhostBridgeStream(
                        title: title,
                        category: "Gaming"
                    )

                    NSLog("✅ Stream started successfully - Status: \(streamingManager.streamStatus)")
                    NSLog("✅ Is streaming: \(streamingManager.isStreaming)")
                }
            } catch {
                NSLog("❌ Stream error: \(error.localizedDescription)")
                NSLog("❌ Error details: \(String(describing: error))")
            }
        }
    }

    // MARK: - ROM Picker Fallback
    private func openROMFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [
            .rom, .n64, .z64, .v64, .nes, .smc, .sfc, .nds, .dsi, .gcm, .iso, .wbfs
        ].compactMap { $0 }
        panel.prompt = "Open ROM"

        if panel.runModal() == .OK, let url = panel.url {
            Task { @MainActor in
                do {
                    // Load into emulator immediately and set selection
                    try await emulatorManager.openROM(at: url)
                    selectedROM = emulatorManager.currentROM
                    try await emulatorManager.start()
                } catch {
                    NSLog("❌ Failed to open ROM via picker: \(error.localizedDescription)")
                }
            }
        }
    }

    private func initializeGhostBridge() {
        Task {
            await streamingManager.initializeGhostBridge()
        }
    }

    private var gameWindowSizeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "rectangle.expand.vertical")
                    .foregroundColor(.blue)
                Text("Game Window Size")
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Picker("Window Size", selection: $gameWindowSize) {
                ForEach(GameWindowSize.allCases, id: \.self) { size in
                    Text(size.displayName).tag(size)
                }
            }
            .pickerStyle(.menu)

            Text(gameWindowSize.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            Color.black.opacity(0.7)
                .overlay(
                    Color.white.opacity(0.05)
                )
        )
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

enum GameWindowSize: String, CaseIterable {
    case tiny = "320x240"
    case small = "640x480"
    case medium = "800x600"
    case large = "1024x768"
    case xlarge = "1280x960"
    case fullscreen = "fullscreen"

    var displayName: String {
        switch self {
        case .tiny: return "Tiny (320×240)"
        case .small: return "Small (640×480)"
        case .medium: return "Medium (800×600)"
        case .large: return "Large (1024×768)"
        case .xlarge: return "X-Large (1280×960)"
        case .fullscreen: return "Fullscreen"
        }
    }

    var description: String {
        switch self {
        case .tiny: return "Smallest window - great for retro feel"
        case .small: return "Classic N64 resolution"
        case .medium: return "Balanced size for streaming"
        case .large: return "Larger window - better visibility"
        case .xlarge: return "Maximum windowed size"
        case .fullscreen: return "Takes over entire screen"
        }
    }

    var resolution: (width: Int, height: Int)? {
        switch self {
        case .tiny: return (320, 240)
        case .small: return (640, 480)
        case .medium: return (800, 600)
        case .large: return (1024, 768)
        case .xlarge: return (1280, 960)
        case .fullscreen: return nil
        }
    }
}

// MARK: - Simple ROM Selector for Go Live

struct SimpleROMSelector: View {
    @EnvironmentObject private var romManager: ROMManager
    @Binding var selectedGame: ROMMetadata?
    @State private var searchText = ""
    @Environment(\.dismiss) private var dismiss

    private var filteredROMs: [ROMMetadata] {
        if searchText.isEmpty {
            return romManager.roms
        } else {
            return romManager.roms.filter { rom in
                rom.title.localizedCaseInsensitiveContains(searchText) ||
                rom.system.displayName.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose a Game")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Select a ROM from your library to stream")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Search
            if !romManager.roms.isEmpty {
                HStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)

                    TextField("Search games...", text: $searchText)
                        .textFieldStyle(.roundedBorder)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
            }

            // Games Grid
            if romManager.roms.isEmpty {
                VStack(spacing: 24) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary.opacity(0.6))

                    VStack(spacing: 8) {
                        Text("No Games Found")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text("Add some ROMs to get started streaming")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVGrid(columns: [
                        GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 12)
                    ], spacing: 12) {
                        ForEach(filteredROMs, id: \.id) { rom in
                            SimpleROMCard(rom: rom, isSelected: selectedGame?.id == rom.id) {
                                selectedGame = rom
                                dismiss()
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 20)
                }
                .frame(maxHeight: 400)
            }
        }
        .frame(width: 600, height: 500)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

struct SimpleROMCard: View {
    let rom: ROMMetadata
    let isSelected: Bool
    let onTap: () -> Void
    @StateObject private var fetcher = GameMetadataFetcher()
    @State private var metadata: GameMetadataFetcher.GameMetadata?

    var body: some View {
        VStack(spacing: 0) {
            // Thumbnail
            ZStack {
                if let boxArt = metadata?.boxArtImage {
                    Image(nsImage: boxArt)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 80)
                } else {
                    systemIconView
                }

                // System badge
                VStack {
                    HStack {
                        Spacer()
                        Text(rom.system.rawValue.uppercased())
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.black.opacity(0.7))
                            .cornerRadius(4)
                    }
                    Spacer()
                }
                .padding(6)
            }
            .frame(height: 80)
            .background(Color.gray.opacity(0.1))

            // Game info
            VStack(alignment: .leading, spacing: 6) {
                Text(rom.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                    .foregroundColor(.primary)

                HStack {
                    Text(rom.system.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    if let metadata = metadata, metadata.rating > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 8))
                                .foregroundColor(.yellow)
                            Text(String(format: "%.1f", metadata.rating))
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .padding(8)
            .frame(height: 50)
        }
        .background(isSelected ? Color.blue.opacity(0.1) : Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
        )
        .shadow(color: isSelected ? .blue.opacity(0.3) : .black.opacity(0.1),
                radius: isSelected ? 8 : 2, x: 0, y: isSelected ? 4 : 1)
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .onTapGesture {
            onTap()
        }
        .task {
            metadata = fetcher.getCachedMetadata(for: rom.title)
        }
    }

    private var systemIconView: some View {
        VStack {
            Image(systemName: systemIcon(for: rom.system))
                .font(.system(size: 28))
                .foregroundColor(systemColor(for: rom.system))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [systemColor(for: rom.system).opacity(0.2), .clear],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func systemIcon(for system: EmulatorSystem) -> String {
        switch system {
        case .gb, .gbc, .gba: return "gamecontroller"
        case .nes: return "rectangle.fill"
        case .snes: return "rectangle.portrait.fill"
        case .n64: return "cube.fill"
        case .gamecube: return "cube.transparent.fill"
        case .wii, .wiiu: return "wand.and.rays"
        case .ds: return "laptopcomputer"
        case .threeds: return "laptopcomputer.and.iphone"
        case .switchConsole: return "gamecontroller.fill"
        }
    }

    private func systemColor(for system: EmulatorSystem) -> Color {
        switch system {
        case .gb, .gbc, .gba: return .yellow
        case .nes: return .red
        case .snes: return .purple
        case .n64: return .blue
        case .gamecube: return .indigo
        case .wii, .wiiu: return .cyan
        case .ds: return .green
        case .threeds: return .mint
        case .switchConsole: return .orange
        }
    }
}

// MARK: - Additional Notifications

extension Notification.Name {
    static let navigateToDashboard = Notification.Name("navigateToDashboard")
    static let navigateToROMBrowser = Notification.Name("navigateToROMBrowser")
}

// MARK: - Preview

#if DEBUG
struct GoLiveView_Previews: PreviewProvider {
    static var previews: some View {
        GoLiveView(emulatorManager: EmulatorManager())
            .frame(width: 1200, height: 800)
    }
}
#endif
