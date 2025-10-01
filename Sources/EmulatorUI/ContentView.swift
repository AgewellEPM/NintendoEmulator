import SwiftUI
import Foundation
import AppKit
import EmulatorKit
import RenderingEngine
import CoreInterface

public struct ContentView: View {
    @StateObject private var emulatorManager = EmulatorManager()
    @StateObject private var romManager = ROMManager()
    @StateObject private var authManager = AuthenticationManager()
    @ObservedObject private var theme = UIThemeManager.shared
    @ObservedObject private var externalControl = ExternalAppControl.shared
    @EnvironmentObject private var appState: AppState
    @State private var showingSidebar = true
    @State private var selectedROM: ROMMetadata?
    @State private var currentView: ContentViewTab = .streamingDashboard
    @State private var toastMessage: String?
    @State private var showingAuthSheet = false
    @State private var showingSocialWizard = false
    @State private var showingCustomization = false
    @State private var showingAIAssistant = false
    @State private var showingAIAgent = false

    public init() {}

    public var body: some View {
        ZStack {
            // Main window background - always solid
            Color(NSColor.windowBackgroundColor)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Simple navigation bar
                navigationBar

                Divider()

            // Content
            switch currentView {
            case .streamingDashboard:
                StreamingDashboard()

            case .romBrowser:
                UniversalROMBrowser()
                    .environmentObject(romManager)

            case .emulator:
                // NN/g Compliant Go Live View
                GoLiveView(emulatorManager: emulatorManager)
                    .environmentObject(romManager)

            case .chat:
                MultiPlatformChatView()
            case .alerts:
                AlertsView()
            case .settings:
                SettingsView(currentTab: $currentView)
                    .environmentObject(emulatorManager)
            case .analytics:
                AnalyticsView()
            case .calendar:
                ContentSchedulerView()
            case .income:
                IncomeTrackerView()
            }
        }
        .frame(minWidth: 1000, minHeight: 600)
        .sheet(isPresented: $appState.showInstallPrompt) {
            StableInstallPromptView()
                .environmentObject(appState)
        }
        .sheet(isPresented: $appState.showPermissionWizard) {
            PermissionWizardView()
        }
        .sheet(isPresented: $showingSocialWizard) {
            SocialAccountWizard()
        }
        .sheet(isPresented: $showingCustomization) {
            FullCustomizationView()
                .frame(minWidth: 900, minHeight: 700)
        }
        .sheet(isPresented: $showingAIAssistant) {
            AIAssistantPanel()
                .frame(minWidth: 600, minHeight: 500)
        }
        .onReceive(NotificationCenter.default.publisher(for: .emulatorStart)) { _ in
            Task { try? await emulatorManager.start() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .emulatorPause)) { _ in
            Task { await emulatorManager.pause() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .emulatorStop)) { _ in
            Task {
                await emulatorManager.stop()
                NotificationCenter.default.post(name: .gameStopped, object: nil)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .emulatorOpenROM)) { note in
            if let url = note.object as? URL {
                Task {
                    do {
                        try await emulatorManager.openROM(at: url)
                        currentView = .emulator
                        try? await emulatorManager.start()
                    } catch {
                        print("Failed to open ROM via menu: \(error)")
                    }
                }
            }
        }
        .onReceive(emulatorManager.$lastError) { newError in
            guard let newError else { return }
            toastMessage = friendlyMessage(from: newError)
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToGoLive)) { _ in
            currentView = .emulator
        }
        .onReceive(NotificationCenter.default.publisher(for: .showPermissionWizard)) { _ in
            appState.showPermissionWizard = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .startGameWithROM)) { note in
            if let rom = note.object as? ROMMetadata {
                selectedROM = rom
                Task {
                    await loadROM(rom)
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToStreamCategory)) { note in
            if let category = note.object as? StreamCategory {
                // Navigate based on category
                switch category {
                case .gaming:
                    // Navigate to Games for gaming
                    currentView = .romBrowser
                case .justChatting:
                    // Navigate to chat view
                    currentView = .chat
                case .creative:
                    // Navigate to creative tools or analytics
                    currentView = .analytics
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToAnalytics)) { note in
            currentView = .analytics
            // You could add specific analytics focus based on note.object here
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToIncome)) { _ in
            currentView = .income
        }
        .onReceive(NotificationCenter.default.publisher(for: .showToastMessage)) { note in
            let msg = note.object as? String ?? "Done"
            toastMessage = msg
        }
        .onReceive(NotificationCenter.default.publisher(for: .navigateToAlerts)) { _ in
            currentView = .alerts
        }
        .onReceive(NotificationCenter.default.publisher(for: .showSocialWizard)) { _ in
            showingSocialWizard = true
        }
        .overlay(alignment: .bottom) {
            if let message = toastMessage {
                ToastView(message: message)
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .animation(.easeInOut(duration: 0.3), value: toastMessage != nil)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            withAnimation { toastMessage = nil }
                        }
                    }
            }
        }
        .sheet(isPresented: $showingAuthSheet) {
            AuthenticationView()
                .environmentObject(authManager)
        }
        .onAppear {
            checkFirstLaunch()
        }
        }
    }

    private func checkFirstLaunch() {
        let hasCompletedWizard = UserDefaults.standard.bool(forKey: "SocialWizardCompleted")
        if !hasCompletedWizard {
            showingSocialWizard = true
        }
    }


    @ViewBuilder
    private var navigationBar: some View {
        HStack {
            // Full streaming platform navigation
            TabButton(title: "Dashboard", tab: .streamingDashboard, currentTab: $currentView)
            TabButton(title: "Games", tab: .romBrowser, currentTab: $currentView)
            TabButton(title: "Go Live", tab: .emulator, currentTab: $currentView)
            TabButton(title: "Chat", tab: .chat, currentTab: $currentView)
            TabButton(title: "Analytics", tab: .analytics, currentTab: $currentView)
            TabButton(title: "Calendar", tab: .calendar, currentTab: $currentView)
            TabButton(title: "Income", tab: .income, currentTab: $currentView)
            TabButton(title: "Settings", tab: .settings, currentTab: $currentView)

            Spacer()

            // Alerts button
            Button(action: { currentView = .alerts }) {
                ZStack {
                    Image(systemName: "bell.fill")
                        .font(.system(size: 16))
                    // Show alert badge if needed
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            // Social wizard button
            Button(action: { showingSocialWizard = true }) {
                Image(systemName: "person.2.circle.fill")
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            // AI Assistant button
            Button(action: {
                showingAIAssistant = true
            }) {
                HStack(spacing: 4) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 14))
                    Text("AI")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(
                    LinearGradient(
                        colors: [.purple, .pink],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            // Customization gear icon
            Button(action: { showingCustomization = true }) {
                Image(systemName: "gearshape.fill")
                    .font(.system(size: 16))
                    .foregroundColor(theme.accentColor)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)

            // Simple auth status
            Button("Sign In") {
                showingAuthSheet = true
            }
            .buttonStyle(.link)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
    }


    private func loadROM(_ rom: ROMMetadata) async {
        NSLog("🎮 ContentView: loadROM called for %@", rom.title)
        do {
            NSLog("🎮 ContentView: Opening ROM at %@", rom.path.path)
            try await emulatorManager.openROM(at: rom.path)
            NSLog("🎮 ContentView: Starting emulator")
            try await emulatorManager.start()

            // Post notification for window title update
            await MainActor.run {
                NotificationCenter.default.post(name: .gameStarted, object: rom.title)
            }
        } catch {
            let msg = "Failed to load ROM: \(String(describing: error))"
            NSLog("%@", msg)
            toastMessage = msg
        }
    }

    private func friendlyMessage(from error: EmulatorError) -> String {
        switch error {
        case .coreNotFound(let system):
            return "No core available for \(system.displayName)."
        case .invalidROM(let reason):
            return "Invalid ROM: \(reason)"
        case .initializationFailed(let reason):
            return "Initialization failed: \(reason)"
        case .romLoadFailed(let reason):
            return "ROM load failed: \(reason)"
        case .noCoreLoaded:
            return "No core loaded"
        case .executionError(let reason):
            return "Execution error: \(reason)"
        case .saveStateFailed(let reason):
            return "Save state failed: \(reason)"
        case .loadStateFailed(let reason):
            return "Load state failed: \(reason)"
        case .memoryError(let reason):
            return "Memory error: \(reason)"
        case .graphicsError(let reason):
            return "Graphics error: \(reason)"
        case .audioError(let reason):
            return "Audio error: \(reason)"
        case .inputError(let reason):
            return "Input error: \(reason)"
        case .networkError(let reason):
            return "Network error: \(reason)"
        }
    }

    // MARK: - External Emulator Controls

    private func saveGameState() async {
        do {
            let saveData = try await emulatorManager.createSaveState()
            toastMessage = "Game state saved (\(saveData.count) bytes)"
        } catch {
            toastMessage = "Failed to save state: \(error.localizedDescription)"
        }
    }

    private func loadGameState() async {
        // Placeholder: implement save state management
        toastMessage = "Load state feature coming soon"
    }

    private func resetGame() async {
        do {
            try await emulatorManager.reset()
            toastMessage = "Game reset"
        } catch {
            toastMessage = "Failed to reset game: \(error.localizedDescription)"
        }
    }

}

// MARK: - Supporting Views

struct UISettingsButton: View {
    @State private var showSettings = false
    @AppStorage("uiAccentColor") private var accentColorHex = "#007AFF"
    @AppStorage("uiBackgroundOpacity") private var backgroundOpacity = 0.8
    @AppStorage("uiThemeMode") private var themeMode = "auto"

    var body: some View {
        Button(action: {
            // Open as a separate floating window
            openFloatingSettingsWindow()
        }) {
            Image(systemName: "gearshape.fill")
                .font(.system(size: 16))
        }
        .buttonStyle(.borderless)
        .help("UI Settings")
    }

    private func openFloatingSettingsWindow() {
        // Create a new window for settings
        let settingsWindow = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 450, height: 600),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        settingsWindow.title = "UI Theme Settings"
        settingsWindow.center()
        settingsWindow.setFrameAutosaveName("UIThemeSettings")
        settingsWindow.isReleasedWhenClosed = false
        settingsWindow.level = .floating // Makes it float above other windows
        settingsWindow.isMovableByWindowBackground = true

        // Allow window to be transparent
        settingsWindow.isOpaque = false
        settingsWindow.backgroundColor = NSColor.clear
        settingsWindow.hasShadow = true

        // Create the SwiftUI view
        let contentView = FloatingSettingsView {
            settingsWindow.close()
        }

        settingsWindow.contentView = NSHostingView(rootView: contentView)
        settingsWindow.makeKeyAndOrderFront(nil)

        // Window will stay open because isReleasedWhenClosed is false
    }
}

struct FloatingSettingsView: View {
    let onClose: () -> Void
    @ObservedObject private var theme = UIThemeManager.shared
    @State private var windowPosition: CGPoint = .zero
    @State private var isDragging = false
    @State private var showFullCustomization = false

    var body: some View {
        VStack(spacing: 0) {
            // Draggable header
            HStack {
                Image(systemName: "hand.point.up.left.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("Drag anywhere")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // Full Customization Button
                Button(action: { showFullCustomization = true }) {
                    Label("Advanced", systemImage: "slider.horizontal.3")
                        .font(.caption)
                }
                .buttonStyle(.bordered)

                Button(action: onClose) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))

            // Settings content
            EnhancedUICustomizationView()
        }
        .background(
            theme.mainWindowColor
                .opacity(theme.mainWindowOpacity * (1.0 - theme.mainWindowTransparency))
        )
        .cornerRadius(12)
        .sheet(isPresented: $showFullCustomization) {
            FullCustomizationView()
        }
    }
}

struct UICustomizationView: View {
    @AppStorage("uiAccentColor") private var accentColorHex = "#007AFF"
    @AppStorage("uiBackgroundOpacity") private var backgroundOpacity = 0.8
    @AppStorage("uiBlurIntensity") private var blurIntensity = 0.5
    @AppStorage("uiThemeMode") private var themeMode = "auto"
    @AppStorage("uiCornerRadius") private var cornerRadius = 12.0
    @AppStorage("uiShadowRadius") private var shadowRadius = 5.0
    @AppStorage("uiAnimationSpeed") private var animationSpeed = 1.0
    @AppStorage("uiCompactMode") private var compactMode = false

    @State private var selectedColor = Color.blue

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Label("UI Customization", systemImage: "paintbrush.fill")
                    .font(.headline)
                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Theme Mode Section
                    GroupBox(label: Label("Theme", systemImage: "moon.circle.fill")) {
                        Picker("Appearance", selection: $themeMode) {
                            Text("Auto").tag("auto")
                            Text("Light").tag("light")
                            Text("Dark").tag("dark")
                        }
                        .pickerStyle(SegmentedPickerStyle())
                    }

                    // Color Section
                    GroupBox(label: Label("Colors", systemImage: "paintpalette.fill")) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Accent Color")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack(spacing: 8) {
                                ColorButton(color: .blue, isSelected: accentColorHex == "#007AFF") {
                                    accentColorHex = "#007AFF"
                                }
                                ColorButton(color: .purple, isSelected: accentColorHex == "#AF52DE") {
                                    accentColorHex = "#AF52DE"
                                }
                                ColorButton(color: .pink, isSelected: accentColorHex == "#FF2D55") {
                                    accentColorHex = "#FF2D55"
                                }
                                ColorButton(color: .red, isSelected: accentColorHex == "#FF3B30") {
                                    accentColorHex = "#FF3B30"
                                }
                                ColorButton(color: .orange, isSelected: accentColorHex == "#FF9500") {
                                    accentColorHex = "#FF9500"
                                }
                                ColorButton(color: .green, isSelected: accentColorHex == "#34C759") {
                                    accentColorHex = "#34C759"
                                }
                                ColorButton(color: .teal, isSelected: accentColorHex == "#5AC8FA") {
                                    accentColorHex = "#5AC8FA"
                                }
                                ColorButton(color: .indigo, isSelected: accentColorHex == "#5856D6") {
                                    accentColorHex = "#5856D6"
                                }
                            }
                        }
                    }

                    // Transparency Section
                    GroupBox(label: Label("Transparency", systemImage: "square.on.square")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Background Opacity")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(backgroundOpacity * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $backgroundOpacity, in: 0.1...1.0)

                            HStack {
                                Text("Blur Intensity")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(blurIntensity * 100))%")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $blurIntensity, in: 0.0...1.0)
                        }
                    }

                    // Design Section
                    GroupBox(label: Label("Design", systemImage: "square.grid.3x1.below.line.grid.1x2")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Corner Radius")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(cornerRadius))px")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $cornerRadius, in: 0...20)

                            HStack {
                                Text("Shadow Radius")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(shadowRadius))px")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $shadowRadius, in: 0...20)

                            Toggle("Compact Mode", isOn: $compactMode)
                                .font(.caption)
                        }
                    }

                    // Animation Section
                    GroupBox(label: Label("Animation", systemImage: "wand.and.rays")) {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Text("Animation Speed")
                                    .font(.caption)
                                Spacer()
                                Text("\(animationSpeed, specifier: "%.1f")x")
                                    .font(.caption.monospacedDigit())
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $animationSpeed, in: 0.5...2.0, step: 0.1)
                        }
                    }

                    // Reset Button
                    Button(action: resetToDefaults) {
                        Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
        }
    }

    private func resetToDefaults() {
        accentColorHex = "#007AFF"
        backgroundOpacity = 0.8
        blurIntensity = 0.5
        themeMode = "auto"
        cornerRadius = 12.0
        shadowRadius = 5.0
        animationSpeed = 1.0
        compactMode = false
    }
}

struct ColorButton: View {
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(color)
                .frame(width: 30, height: 30)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: isSelected ? 3 : 0)
                )
                .overlay(
                    Circle()
                        .stroke(Color.black.opacity(0.2), lineWidth: 1)
                )
                .scaleEffect(isSelected ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
}

struct StreamingControlButtons: View {
    @State private var showWebcamEffects = false
    @State private var showAIPuppeteer = false
    @State private var showAIAssistant = false
    @State private var showRecording = false
    @EnvironmentObject private var appState: AppState

    var body: some View {
        HStack(spacing: 12) {
            // Webcam Effects button
            Button(action: { showWebcamEffects.toggle() }) {
                Label("Webcam Effects", systemImage: "camera.filters")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Webcam Effects & Filters")
            .popover(isPresented: $showWebcamEffects) {
                WebcamEffectsControl()
                    .frame(width: 300, height: 400)
                    .padding()
            }

            // AI Puppeteer button
            Button(action: { showAIPuppeteer.toggle() }) {
                Label("AI Puppeteer", systemImage: "cpu.fill")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("AI Puppeteer Control")
            .popover(isPresented: $showAIPuppeteer) {
                AIPuppeteerControl()
                    .frame(width: 300, height: 400)
                    .padding()
            }

            // AI Stream Assistant button
            Button(action: { showAIAssistant.toggle() }) {
                Label("AI Assistant", systemImage: "brain")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("AI Stream Assistant")
            .popover(isPresented: $showAIAssistant) {
                AIControlPanel()
                    .frame(width: 300, height: 400)
                    .padding()
            }

            // Recording Settings button
            Button(action: { showRecording.toggle() }) {
                Label("Recording", systemImage: "record.circle")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.borderless)
            .help("Recording Settings")
            .popover(isPresented: $showRecording) {
                RecordingSettings()
                    .frame(width: 300, height: 300)
                    .padding()
            }

            Divider()
                .frame(height: 20)

            // Chat toggle button
            Button(action: { appState.showStreamChat.toggle() }) {
                Label("Chat", systemImage: appState.showStreamChat ? "message.fill" : "message")
                    .labelStyle(.iconOnly)
                    .foregroundColor(appState.showStreamChat ? .blue : .primary)
            }
            .buttonStyle(.borderless)
            .help("Toggle Stream Chat")
        }
    }
}

enum ContentViewTab: String, CaseIterable {
    case streamingDashboard = "Dashboard"
    case romBrowser = "Games"
    case emulator = "Go Live"
    case chat = "Chat"
    case alerts = "Alerts"
    case settings = "Settings"
    case analytics = "Analytics"
    case calendar = "Calendar"
    case income = "Income"
}

struct TabButton: View {
    let title: String
    let tab: ContentViewTab
    @Binding var currentTab: ContentViewTab

    var body: some View {
        Button(action: {
            currentTab = tab
        }) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    currentTab == tab ?
                    Color.blue.opacity(0.2) :
                    Color.clear
                )
                .foregroundColor(
                    currentTab == tab ?
                    .blue :
                    .primary
                )
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

struct ToastView: View {
    let message: String

    var body: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
            Text(message)
                .font(.body)
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
        .shadow(radius: 5)
    }
}

// No longer needed - simplified UI

struct AIAssistantPanel: View {
    @State private var operatorMode = false
    @State private var isActive = false
    @State private var showingAIAgent = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "brain.head.profile")
                    .font(.title)
                    .foregroundColor(.purple)

                VStack(alignment: .leading) {
                    Text("AI Assistant")
                        .font(.title2.bold())
                    Text(operatorMode ? "Operator Mode: Watching Gameplay" : "General Assistant")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }
            .padding()
            .background(Color.purple.opacity(0.1))

            Divider()

            ScrollView {
                VStack(spacing: 20) {
                    // Operator Mode Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Toggle(isOn: $operatorMode) {
                                HStack {
                                    Image(systemName: "eye.circle.fill")
                                        .foregroundColor(.purple)
                                    Text("AI Operator Mode")
                                        .font(.headline)
                                }
                            }

                            Text("AI watches your streaming video and narrates helpful gameplay tips in real-time")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            if operatorMode {
                                Button(action: { isActive.toggle() }) {
                                    HStack {
                                        Image(systemName: isActive ? "stop.circle.fill" : "play.circle.fill")
                                        Text(isActive ? "Stop AI Narration" : "Start AI Narration")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        LinearGradient(
                                            colors: isActive ? [.red, .orange] : [.purple, .pink],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    } label: {
                        Label("Operator Mode", systemImage: "eye.fill")
                    }

                    // AI Agent Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "brain.head.profile")
                                    .foregroundColor(.blue)
                                Text("AI Game Agent")
                                    .font(.headline)
                            }

                            Text("AI learns to play games by watching you, then can play autonomously or mimic your style")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Button(action: { showingAIAgent = true }) {
                                HStack {
                                    Image(systemName: "play.circle.fill")
                                    Text("Open AI Agent Panel")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.blue, .purple],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundColor(.white)
                                .cornerRadius(10)
                            }
                            .buttonStyle(.plain)
                        }
                    } label: {
                        Label("AI Agent", systemImage: "brain.head.profile")
                    }

                    // General AI Section
                    GroupBox {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Ask AI anything about:")
                                .font(.headline)

                            VStack(alignment: .leading, spacing: 8) {
                                Label("Game strategies and tips", systemImage: "gamecontroller.fill")
                                Label("Level walkthroughs", systemImage: "map.fill")
                                Label("Secret locations", systemImage: "lock.fill")
                                Label("Speedrun techniques", systemImage: "timer")
                            }
                            .font(.caption)
                            .foregroundColor(.secondary)
                        }
                    } label: {
                        Label("AI Capabilities", systemImage: "sparkles")
                    }

                    // Status
                    GroupBox {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Circle()
                                    .fill(isActive ? Color.green : Color.gray)
                                    .frame(width: 8, height: 8)
                                Text(isActive ? "AI is active" : "AI is idle")
                                    .font(.caption)
                            }

                            if operatorMode && isActive {
                                Text("🔴 Analyzing gameplay frames")
                                    .font(.caption)
                                    .foregroundColor(.red)
                            }
                        }
                    } label: {
                        Label("Status", systemImage: "info.circle")
                    }
                }
                .padding()
            }
        }
        .showSetupWizardIfNeeded()
        .sheet(isPresented: $showingAIAgent) {
            AIAgentControlPanel()
        }
    }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
#endif
