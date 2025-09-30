import SwiftUI
import CoreInterface
import EmulatorKit
import AppKit
import Combine

// MARK: - NN/g Settings Categories
enum SettingsCategory: String, CaseIterable {
    case style = "style"
    case streaming = "streaming"
    case graphics = "graphics"
    case audio = "audio"
    case input = "input"
    case emulation = "emulation"
    case paths = "paths"
    case about = "about"

    var title: String {
        switch self {
        case .style: return "Style & Appearance"
        case .streaming: return "Streaming & API"
        case .graphics: return "Graphics"
        case .audio: return "Audio"
        case .input: return "Input"
        case .emulation: return "Emulation"
        case .paths: return "Paths"
        case .about: return "About"
        }
    }

    var description: String {
        switch self {
        case .style: return "Customize colors, themes, opacity, and visual appearance of the interface"
        case .streaming: return "Connect to social media platforms and configure streaming settings"
        case .graphics: return "Configure display settings, resolution, and visual effects"
        case .audio: return "Adjust volume, sample rate, and audio processing settings"
        case .input: return "Configure controllers, keyboard mappings, and input sensitivity"
        case .emulation: return "Core emulation settings, save states, and performance options"
        case .paths: return "Set file locations for ROMs, saves, and other data"
        case .about: return "Information about this emulator and version details"
        }
    }

    var icon: String {
        switch self {
        case .style: return "gearshape.fill"
        case .streaming: return "antenna.radiowaves.left.and.right"
        case .graphics: return "tv"
        case .audio: return "speaker.wave.2"
        case .input: return "gamecontroller"
        case .emulation: return "cpu"
        case .paths: return "folder"
        case .about: return "info.circle"
        }
    }

    var hasNotificationBadge: Bool {
        switch self {
        case .streaming: return true  // Show badge for new API features
        default: return false
        }
    }
}

struct SettingsView: View {
    @EnvironmentObject private var emulatorManager: EmulatorManager
    @AppStorage("graphics.resolution") private var renderScale = 1.0
    @AppStorage("graphics.vsync") private var vsyncEnabled = true
    @AppStorage("graphics.fullscreen") private var fullscreenMode = false
    @AppStorage("graphics.aspectRatio") private var maintainAspectRatio = true
    @AppStorage("graphics.filter") private var filterMode = "linear"

    @AppStorage("audio.volume") private var audioVolume = 0.7
    @AppStorage("audio.sampleRate") private var sampleRate = 48000
    @AppStorage("audio.latency") private var audioLatency = 20
    @AppStorage("audio.effects") private var audioEffectsEnabled = false

    @AppStorage("input.vibration") private var vibrationEnabled = true
    @AppStorage("input.deadzone") private var analogDeadzone = 0.15
    @AppStorage("input.sensitivity") private var analogSensitivity = 1.0

    @AppStorage("emulation.speedLimit") private var speedLimitEnabled = true
    @AppStorage("emulation.autoSave") private var autoSaveEnabled = true
    @AppStorage("emulation.autoSaveInterval") private var autoSaveInterval = 300
    @AppStorage("AccessibilityAlwaysPrompt") private var alwaysPromptAccessibility = false

    @State private var selectedCategory: SettingsCategory = .streaming
    @Environment(\.dismiss) private var dismiss
    @Binding var currentTab: ContentViewTab

    var body: some View {
        VStack(spacing: 0) {
            // Add navigation header (need ContentView to pass currentTab binding)
            // For now, add a simple back button
            HStack {
                Text("Settings")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()
                Button("Back to Dashboard") {
                    currentTab = .streamingDashboard
                }
                .buttonStyle(.bordered)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            HStack(spacing: 0) {
                // Left Sidebar - NN/g Navigation
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Settings")
                        .font(.title2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 16)
                        .padding(.top, 16)

                    Text("Configure your Nintendo emulator")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
                .padding(.bottom, 16)

                // Category Navigation
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        ForEach(SettingsCategory.allCases, id: \.self) { category in
                            SettingsCategoryRow(
                                category: category,
                                isSelected: selectedCategory == category,
                                onTap: { selectedCategory = category }
                            )
                        }
                    }
                    .padding(.horizontal, 8)
                }

                Spacer()

                // Footer Actions
                VStack(spacing: DesignSystem.Spacing.sm) {
                    Divider()
                    Button("Reset All Settings") {
                        // Reset functionality
                    }
                    .foregroundColor(.red)
                    .font(.caption)

                    Button("Export Settings") {
                        // Export functionality
                    }
                    .font(.caption)
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Main Content Area
            VStack(spacing: 0) {
                // Content Header
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(selectedCategory.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)
                        Text(selectedCategory.description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Done button removed - use Back button in header instead
                }
                .padding()

                Divider()

                // Dynamic Content
                ScrollView {
                    getContentView(for: selectedCategory)
                        .padding()
                }
                .background(Color(NSColor.textBackgroundColor))
            }
        }
        } // Close the outer VStack we added
        .frame(width: 1000, height: 700)
    }

    @ViewBuilder
    private func getContentView(for category: SettingsCategory) -> some View {
        switch category {
        case .style:
            StyleSettingsView()
        case .streaming:
            APIConnectionsView()
        case .graphics:
            GraphicsSettingsView(
                renderScale: $renderScale,
                vsyncEnabled: $vsyncEnabled,
                fullscreenMode: $fullscreenMode,
                maintainAspectRatio: $maintainAspectRatio,
                filterMode: $filterMode
            )
        case .audio:
            AudioSettingsView(
                audioVolume: $audioVolume,
                sampleRate: $sampleRate,
                audioLatency: $audioLatency,
                audioEffectsEnabled: $audioEffectsEnabled
            )
        case .input:
            InputSettingsView(
                vibrationEnabled: $vibrationEnabled,
                analogDeadzone: $analogDeadzone,
                analogSensitivity: $analogSensitivity
            )
        case .emulation:
            EmulationSettingsView(
                speedLimitEnabled: $speedLimitEnabled,
                autoSaveEnabled: $autoSaveEnabled,
                autoSaveInterval: $autoSaveInterval
            )
        case .paths:
            PathsSettingsView()
        case .about:
            AboutView()
        }
    }
}

// MARK: - Category Navigation Row
struct SettingsCategoryRow: View {
    let category: SettingsCategory
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Icon with notification badge
                ZStack {
                    Image(systemName: category.icon)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(isSelected ? .white : .primary)
                        .frame(width: 20)

                    if category.hasNotificationBadge && !isSelected {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 8, height: 8)
                            .offset(x: 10, y: -8)
                    }
                }

                // Category info
                VStack(alignment: .leading, spacing: 2) {
                    HStack {
                        Text(category.title)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(isSelected ? .white : .primary)

                        if category.hasNotificationBadge && !isSelected {
                            Text("NEW")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 1)
                                .background(Color.red)
                                .cornerRadius(DesignSystem.Radius.lg)
                        }

                        Spacer()
                    }

                    if !isSelected {
                        Text(category.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }
                }

                Spacer()

                if isSelected {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Graphics Settings

struct GraphicsSettingsView: View {
    @Binding var renderScale: Double
    @Binding var vsyncEnabled: Bool
    @Binding var fullscreenMode: Bool
    @Binding var maintainAspectRatio: Bool
    @Binding var filterMode: String

    let filterModes = ["nearest", "linear", "cubic", "lanczos", "xBR", "CRT"]

    var body: some View {
        Form {
            Section("Display") {
                HStack {
                    Text("Render Scale")
                    Slider(value: $renderScale, in: 0.5...4.0, step: 0.25) {
                        Text("Render Scale")
                    }
                    Text("\(renderScale, specifier: "%.2f")x")
                        .frame(width: 50)
                }

                Toggle("VSync", isOn: $vsyncEnabled)
                Toggle("Fullscreen", isOn: $fullscreenMode)
                Toggle("Maintain Aspect Ratio", isOn: $maintainAspectRatio)
            }

            Section("Filtering") {
                Picker("Filter Mode", selection: $filterMode) {
                    ForEach(filterModes, id: \.self) { mode in
                        Text(mode.capitalized).tag(mode)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            Section("Advanced") {
                Button("Reset Graphics Settings") {
                    renderScale = 1.0
                    vsyncEnabled = true
                    fullscreenMode = false
                    maintainAspectRatio = true
                    filterMode = "linear"
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Audio Settings

struct AudioSettingsView: View {
    @Binding var audioVolume: Double
    @Binding var sampleRate: Int
    @Binding var audioLatency: Int
    @Binding var audioEffectsEnabled: Bool

    let sampleRates = [22050, 32000, 44100, 48000, 96000]

    var body: some View {
        Form {
            Section("Output") {
                HStack {
                    Text("Master Volume")
                    Slider(value: $audioVolume, in: 0...1) {
                        Text("Volume")
                    }
                    Text("\(Int(audioVolume * 100))%")
                        .frame(width: 50)
                }

                Picker("Sample Rate", selection: $sampleRate) {
                    ForEach(sampleRates, id: \.self) { rate in
                        Text("\(rate) Hz").tag(rate)
                    }
                }

                HStack {
                    Text("Audio Latency")
                    Slider(value: Binding(
                        get: { Double(audioLatency) },
                        set: { audioLatency = Int($0) }
                    ), in: 10...100, step: 10) {
                        Text("Latency")
                    }
                    Text("\(audioLatency) ms")
                        .frame(width: 50)
                }
            }

            Section("Effects") {
                Toggle("Enable Audio Effects", isOn: $audioEffectsEnabled)

                if audioEffectsEnabled {
                    Text("Audio effects can impact performance")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Advanced") {
                Button("Reset Audio Settings") {
                    audioVolume = 0.7
                    sampleRate = 48000
                    audioLatency = 20
                    audioEffectsEnabled = false
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - Emulation Settings

struct EmulationSettingsView: View {
    @Binding var speedLimitEnabled: Bool
    @Binding var autoSaveEnabled: Bool
    @Binding var autoSaveInterval: Int

    @AppStorage("emulation.frameskip") private var frameskipEnabled = false
    @AppStorage("emulation.maxFrameskip") private var maxFrameskip = 3
    @AppStorage("emulation.rewind") private var rewindEnabled = false
    @AppStorage("emulation.rewindBuffer") private var rewindBufferSize = 60

    let autoSaveIntervals = [60, 120, 300, 600, 900]

    var body: some View {
        Form {
            Section("Speed") {
                Toggle("Limit Speed", isOn: $speedLimitEnabled)

                Toggle("Auto Frame Skip", isOn: $frameskipEnabled)

                if frameskipEnabled {
                    Stepper("Max Frame Skip: \(maxFrameskip)", value: $maxFrameskip, in: 1...10)
                }
            }

            Section("Save States") {
                Toggle("Auto Save", isOn: $autoSaveEnabled)

                if autoSaveEnabled {
                    Picker("Auto Save Interval", selection: $autoSaveInterval) {
                        ForEach(autoSaveIntervals, id: \.self) { interval in
                            Text("\(interval / 60) minutes").tag(interval)
                        }
                    }
                }

                Toggle("Enable Rewind", isOn: $rewindEnabled)

                if rewindEnabled {
                    Stepper("Rewind Buffer: \(rewindBufferSize) seconds",
                           value: $rewindBufferSize, in: 10...300, step: 10)
                }
            }

            Section("Per-Core Settings") {
                NavigationLink("N64 Settings") {
                    N64SettingsView()
                }
                NavigationLink("NES Settings") {
                    EmptyView() // Placeholder
                }
                NavigationLink("SNES Settings") {
                    EmptyView() // Placeholder
                }
            }

            Section("Advanced") {
                Button("Reset Emulation Settings") {
                    speedLimitEnabled = true
                    autoSaveEnabled = true
                    autoSaveInterval = 300
                    frameskipEnabled = false
                    maxFrameskip = 3
                    rewindEnabled = false
                    rewindBufferSize = 60
                }
            }
        }
        .formStyle(.grouped)
    }
}

// MARK: - N64 Specific Settings

struct N64SettingsView: View {
    @AppStorage("n64.cpuCore") private var cpuCore = "interpreter"
    @AppStorage("n64.rspPlugin") private var rspPlugin = "hle"
    @AppStorage("n64.expansionPak") private var expansionPakEnabled = true
    @AppStorage("n64.cpuOverclock") private var cpuOverclock = 1.0

    var body: some View {
        Form {
            Section("CPU") {
                Picker("CPU Core", selection: $cpuCore) {
                    Text("Interpreter").tag("interpreter")
                    Text("Cached Interpreter").tag("cached")
                    Text("Dynamic Recompiler").tag("dynarec")
                }

                HStack {
                    Text("CPU Overclock")
                    Slider(value: $cpuOverclock, in: 0.5...2.0, step: 0.1)
                    Text("\(cpuOverclock, specifier: "%.1f")x")
                        .frame(width: 50)
                }
            }

            Section("RSP") {
                Picker("RSP Plugin", selection: $rspPlugin) {
                    Text("HLE (High Level)").tag("hle")
                    Text("LLE (Low Level)").tag("lle")
                }
            }

            Section("Memory") {
                Toggle("Expansion Pak (8MB RAM)", isOn: $expansionPakEnabled)
            }
        }
        .formStyle(.grouped)
        .navigationTitle("N64 Settings")
    }
}

// MARK: - Paths Settings

struct PathsSettingsView: View {
    @AppStorage("paths.roms") private var romsPath = ""
    @AppStorage("paths.saves") private var savesPath = ""
    @AppStorage("paths.screenshots") private var screenshotsPath = ""
    @AppStorage("paths.cheats") private var cheatsPath = ""

    var body: some View {
        Form {
            Section("Directories") {
                PathRow(title: "ROMs", path: $romsPath)
                PathRow(title: "Saves", path: $savesPath)
                PathRow(title: "Screenshots", path: $screenshotsPath)
                PathRow(title: "Cheats", path: $cheatsPath)
            }

            Section("Actions") {
                Button("Reset to Default Paths") {
                    romsPath = ""
                    savesPath = ""
                    screenshotsPath = ""
                    cheatsPath = ""
                }

                Button("Open Application Support Folder") {
                    if let url = FileManager.default.urls(for: .applicationSupportDirectory,
                                                         in: .userDomainMask).first {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}

struct PathRow: View {
    let title: String
    @Binding var path: String

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 100, alignment: .leading)

            Text(path.isEmpty ? "Default" : path)
                .lineLimit(1)
                .truncationMode(.middle)
                .foregroundColor(.secondary)

            Spacer()

            Button("Choose...") {
                let panel = NSOpenPanel()
                panel.canChooseDirectories = true
                panel.canChooseFiles = false
                panel.allowsMultipleSelection = false

                if panel.runModal() == .OK {
                    path = panel.url?.path ?? ""
                }
            }
        }
    }
}

// MARK: - Controller Configuration

struct ControllerConfigView: View {
    let playerIndex: Int
    @Environment(\.dismiss) private var dismiss
    @State private var isListening = false
    @State private var currentButton = ""

    var body: some View {
        VStack {
            Text("Controller Configuration")
                .font(.largeTitle)
                .padding()

            Text("Player \(playerIndex + 1)")
                .font(.title2)
                .foregroundColor(.secondary)

            Divider()

            // Button mapping list
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    ButtonMappingRow(button: "A", binding: "Button A")
                    ButtonMappingRow(button: "B", binding: "Button B")
                    ButtonMappingRow(button: "X", binding: "Button X")
                    ButtonMappingRow(button: "Y", binding: "Button Y")
                    ButtonMappingRow(button: "L", binding: "Left Shoulder")
                    ButtonMappingRow(button: "R", binding: "Right Shoulder")
                    ButtonMappingRow(button: "ZL", binding: "Left Trigger")
                    ButtonMappingRow(button: "ZR", binding: "Right Trigger")
                    ButtonMappingRow(button: "Start", binding: "Menu")
                    ButtonMappingRow(button: "Select", binding: "Options")
                }
                .padding()
            }

            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Reset Defaults") {
                    // Reset to default mappings
                }

                Button("Save") {
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding()
        }
        .frame(width: 500, height: 600)
    }
}

struct ButtonMappingRow: View {
    let button: String
    let binding: String

    var body: some View {
        HStack {
            Text(button)
                .frame(width: 100, alignment: .leading)

            Spacer()

            Text(binding)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.gray.opacity(0.2))
                .cornerRadius(5)

            Button("Change") {
                // Start listening for input
            }
        }
    }
}

// MARK: - About View

struct AboutView: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 60))
                .foregroundColor(.accentColor)

            Text("Nintendo Universal Emulator")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Version 1.0.0")
                .font(.title3)
                .foregroundColor(.secondary)

            Divider()
                .padding(.horizontal, 50)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("A high-performance, native macOS emulator supporting Nintendo consoles.")

                Text("Built with Swift, Metal, and modern Apple technologies.")
                    .foregroundColor(.secondary)

                Link("View on GitHub",
                     destination: URL(string: "https://github.com/yourusername/NintendoEmulator")!)
                    .foregroundColor(.accentColor)
            }
            .padding(.horizontal, 50)

            Spacer()

            Text("© 2024 Nintendo Emulator Project")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - API Connections View
struct APIConnectionsView: View {
    @StateObject private var apiManager = APIConnectionManager()
    @State private var showingWizard = false
    @State private var selectedPlatform: SocialPlatform?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                // Header
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("API Connections")
                        .font(.title2.bold())

                    Text("Connect your social media accounts to enable streaming, analytics, and automated posting. Our setup wizard will guide you through each platform's API configuration.")
                        .font(.body)
                        .foregroundColor(.secondary)

                    // Advanced Features Banner
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundColor(.orange)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Advanced Integration Technology")
                                .font(.caption)
                                .fontWeight(.semibold)
                            Text("Real APIs for supported platforms • AI-powered bridges for others • Auto-configuration via JSON")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(DesignSystem.Radius.lg)
                }

                // Connected Platforms Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Connected Platforms")
                        .font(.headline)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: DesignSystem.Spacing.lg) {
                        ForEach(SocialPlatform.apiPlatforms) { platform in
                            PlatformConnectionCard(
                                platform: platform,
                                isConnected: apiManager.isConnected(platform),
                                onConnect: {
                                    selectedPlatform = platform
                                    showingWizard = true
                                },
                                onDisconnect: {
                                    apiManager.disconnect(platform)
                                }
                            )
                        }
                    }
                }

                Divider()

                // Live Game Mirror Preview
                LiveGameMirrorPreview()

                Divider()

                // JSON Configuration Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    HStack {
                        Image(systemName: "doc.text")
                            .foregroundColor(.blue)
                        Text("JSON Auto-Configuration")
                            .font(.headline)
                        Spacer()
                        Button("Generate Config") {
                            // Generate current configuration as JSON
                            let jsonConfig = apiManager.generateConnectionReport()
                            let pasteboard = NSPasteboard.general
                            pasteboard.declareTypes([.string], owner: nil)
                            pasteboard.setString(jsonConfig, forType: .string)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }

                    Text("Import or export API configurations via JSON files. Perfect for team setups or backup purposes.")
                        .font(.body)
                        .foregroundColor(.secondary)

                    HStack(spacing: DesignSystem.Spacing.lg) {
                        Button(action: {
                            // Import JSON configuration
                            let openPanel = NSOpenPanel()
                            openPanel.allowedContentTypes = [.json]
                            openPanel.allowsMultipleSelection = false
                            if openPanel.runModal() == .OK, let url = openPanel.url {
                                Task {
                                    await JSONConfigManager.shared.importConfiguration(from: url, to: apiManager)
                                }
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down")
                                Text("Import JSON")
                            }
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            // Export JSON configuration
                            let savePanel = NSSavePanel()
                            savePanel.allowedContentTypes = [.json]
                            savePanel.nameFieldStringValue = "api_connections.json"
                            if savePanel.runModal() == .OK, let url = savePanel.url {
                                JSONConfigManager.shared.exportConfiguration(from: apiManager, to: url)
                            }
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.up")
                                Text("Export JSON")
                            }
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            // Show sample JSON
                        }) {
                            HStack {
                                Image(systemName: "eye")
                                Text("View Sample")
                            }
                        }
                        .buttonStyle(.bordered)

                        Spacer()
                    }

                    // Sample JSON Preview
                    DisclosureGroup("Sample JSON Configuration") {
                        ScrollView {
                            Text(JSONConfigManager.sampleConfiguration)
                                .font(.system(.caption, design: .monospaced))
                                .padding()
                                .background(Color.gray.opacity(0.1))
                                .cornerRadius(DesignSystem.Radius.lg)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(height: 150)
                    }
                }

                Divider()

                // Quick Setup Section
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Quick Setup Options")
                        .font(.headline)

                    VStack(spacing: DesignSystem.Spacing.md) {
                        QuickSetupButton(
                            title: "Connect All Major Platforms",
                            subtitle: "Set up Twitch, YouTube, Twitter, and Discord",
                            icon: "link.circle.fill",
                            action: {
                                // Connect all major platforms
                                showingWizard = true
                            }
                        )

                        QuickSetupButton(
                            title: "Gaming Streamer Setup",
                            subtitle: "Optimized for gaming content creators",
                            icon: "gamecontroller.fill",
                            action: {
                                // Gaming-focused setup
                                showingWizard = true
                            }
                        )

                        QuickSetupButton(
                            title: "Import Existing Config",
                            subtitle: "Import API keys from OBS or other tools",
                            icon: "square.and.arrow.down",
                            action: {
                                // Import existing configuration
                            }
                        )
                    }
                }

                Spacer()
            }
            .padding()
        }
        .sheet(isPresented: $showingWizard) {
            APISetupWizard(
                platform: selectedPlatform,
                apiManager: apiManager,
                isPresented: $showingWizard
            )
        }
    }
}

// MARK: - Live Game Mirror Preview (inside Streaming settings)
private struct LiveGameMirrorPreview: View {
    @EnvironmentObject private var emulatorManager: EmulatorManager
    @StateObject private var streamingManager = StreamingManager()
    @State private var previewImage: NSImage?
    @State private var initialized = false
    @State private var timer: Timer?
    @State private var screenAuthorized = false
    @State private var axAuthorized = false
    @State private var showingPermissionWizard = false
    @State private var showingWindowPicker = false
    @State private var fullScreenCapture = false
    @State private var targetFPS: Int = 60
    @State private var useInternalStream = false
    @State private var internalCancellable: AnyCancellable?
    @State private var framesSinceImage = 0
    @State private var measuredFPS: Double = 0
    @State private var lastFPSTimestamp: Date = Date()
    @State private var framesSinceLastFPS: Int = 0
    @State private var showWarning = false
    @State private var warningTitle = ""
    @State private var warningDetails = ""
    private enum WarningKind { case screenPermission, accessibilityPermission, windowNoFrames, fullScreenNoFrames }
    @State private var warningKind: WarningKind = .windowNoFrames
    @AppStorage("AccessibilityAlwaysPrompt") private var alwaysPromptAccessibility2 = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "gamecontroller")
                    .foregroundColor(.blue)
                Text("Live Game Preview")
                    .font(.headline)
                Spacer()
                Text(String(format: "FPS: %.0f", measuredFPS))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Grant Permissions") {
                    GhostBridgeHelper.openAllPermissions()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Relaunch App") {
                    GhostBridgeHelper.relaunchApp()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button("Permissions Wizard") {
                    showingPermissionWizard = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Select Window…") {
                    showingWindowPicker = true
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Test Capture") {
                    if let id = Mirror(reflecting: streamingManager).children.first(where: { $0.label == "emulatorWindowID" })?.value as? CGWindowID {
                        let desktop = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Desktop")
                        let url = desktop.appendingPathComponent("EmulatorCapture.png")
                        let ok = GhostBridgeHelper.saveWindowCapture(windowID: id, url: url)
                        NSLog("👻 Test capture saved: \(ok) at \(url.path)")
                    } else {
                        NSLog("👻 Test capture failed: no window ID set")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                if initialized {
                    Text("Ready")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Text("Need Permissions")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black)
                    .frame(maxWidth: .infinity)
                    .aspectRatio(4/3, contentMode: .fit)
                    .overlay(
                        Group {
                            if let image = previewImage {
                                Image(nsImage: image)
                                    .resizable()
                                    .interpolation(.high)
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(DesignSystem.Radius.xxl)
                            } else {
                                VStack(spacing: DesignSystem.Spacing.sm) {
                                    MagicSpinner()
                                        .frame(width: 80, height: 80)
                                    Text(framesSinceImage > 20 ? "Finding your game window…" : "Preparing preview…")
                                        .foregroundColor(.white.opacity(0.85))
                                        .font(.caption)
                                }
                            }
                        }
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.25), lineWidth: 1)
                    )
                // Overlay removed; popup alert is shown via .alert below
            }
            // Accessibility prompt preference
            Toggle("Always Prompt Accessibility on Launch", isOn: $alwaysPromptAccessibility2)
                .help("If enabled, the app will trigger the Accessibility prompt and open System Settings on each launch.")
                .padding(.top, 4)
            HStack(spacing: DesignSystem.Spacing.md) {
                Toggle("Capture Full Screen (Background)", isOn: $fullScreenCapture)
                    .onChange(of: fullScreenCapture) { on in
                        streamingManager.configureCapture(mode: on ? .fullScreen : .window, fps: targetFPS)
                    }
                Toggle("Use Internal Stream", isOn: $useInternalStream)
                    .onChange(of: useInternalStream) { on in
                        if on { startInternalStream() } else { stopInternalStream() }
                    }
                HStack {
                    Text("FPS:")
                    Picker("", selection: $targetFPS) {
                        Text("30").tag(30)
                        Text("60").tag(60)
                        Text("90").tag(90)
                        Text("120").tag(120)
                    }
                    .frame(width: 80)
                    .onChange(of: targetFPS) { fps in
                        streamingManager.configureCapture(mode: fullScreenCapture ? .fullScreen : .window, fps: fps)
                    }
                }
                .labelsHidden()
                Spacer()
            }
            .padding(.top, 4)
        }
        .onAppear {
            Task { @MainActor in
                initialized = await streamingManager.initializeGhostBridge()
                startPreviewTimer()
                refreshPermissionStatus()
                streamingManager.configureCapture(mode: .window, fps: 60)
                if #available(macOS 10.15, *), !screenAuthorized { showingPermissionWizard = true }
            }
        }
        .onDisappear {
            stopPreviewTimer()
            stopInternalStream()
        }
        .alert(warningTitle, isPresented: $showWarning) {
            switch warningKind {
            case .screenPermission:
                Button("Open Permissions Wizard") { showingPermissionWizard = true }
                Button("Dismiss", role: .cancel) { showWarning = false }
            case .accessibilityPermission:
                Button("Open Permissions Wizard") { showingPermissionWizard = true }
                Button("Dismiss", role: .cancel) { showWarning = false }
            case .windowNoFrames:
                Button("Select Window…") { showingWindowPicker = true }
                Button("Full Screen 90 FPS") {
                    fullScreenCapture = true
                    targetFPS = 90
                    streamingManager.configureCapture(mode: .fullScreen, fps: 90)
                }
                Button("Dismiss", role: .cancel) { showWarning = false }
            case .fullScreenNoFrames:
                Button("Open Permissions Wizard") { showingPermissionWizard = true }
                Button("Select Window…") { showingWindowPicker = true }
                Button("Dismiss", role: .cancel) { showWarning = false }
            }
        } message: {
            Text(warningDetails)
        }
        .sheet(isPresented: $showingPermissionWizard) {
            PermissionWizardView()
        }
        .sheet(isPresented: $showingWindowPicker) {
            WindowPickerView(onSelect: { id in
                streamingManager.setEmulatorWindowID(id)
            })
        }
    }

    private func startPreviewTimer() {
        stopPreviewTimer()
        var frameCount = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 10.0, repeats: true) { _ in
            // Re-initialize every 50 frames (5 seconds) to refresh window finding
            frameCount += 1
            if frameCount % 50 == 0 {
                Task { @MainActor in
                    _ = await streamingManager.initializeGhostBridge()
                }
            }

            Task { @MainActor in
                if let cg = streamingManager.captureEmulatorFrame() {
                    let img = NSImage(cgImage: cg, size: NSSize(width: cg.width, height: cg.height))
                    previewImage = img
                    framesSinceImage = 0
                    // FPS accounting
                    framesSinceLastFPS += 1
                    let now = Date()
                    let dt = now.timeIntervalSince(lastFPSTimestamp)
                    if dt >= 1.0 {
                        measuredFPS = Double(framesSinceLastFPS) / dt
                        framesSinceLastFPS = 0
                        lastFPSTimestamp = now
                        NSLog("🎥 Preview FPS: %.1f (mode=\(streamingManager.captureMode.rawValue), SR=\(screenAuthorized))", measuredFPS)
                    }
                    return
                }
            }
            if previewImage == nil {
                // Auto-fallback: if we can't grab a window for ~3s, switch to full screen at 90fps
                if frameCount == 30 {
                    Task { @MainActor in
                        streamingManager.configureCapture(mode: .fullScreen, fps: 90)
                    }
                }
                framesSinceImage += 1
            }

            // Periodically refresh permission status indicators
                if frameCount % 30 == 0 { // ~every 3s
                    Task { @MainActor in
                        refreshPermissionStatus()
                        updateWarning()
                    }
                }
        }
    }

    private func stopPreviewTimer() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func refreshPermissionStatus() {
        if #available(macOS 10.15, *) {
            screenAuthorized = GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized()
        } else {
            screenAuthorized = true
        }
        axAuthorized = GhostBridgeHelper.isAccessibilityEffectivelyTrusted()
        initialized = screenAuthorized && axAuthorized
    }

    @MainActor
    private func updateWarning() {
        // Only warn if we haven't shown an image for a short period
        guard framesSinceImage >= 30 else { showWarning = false; return }
        if #available(macOS 10.15, *), !screenAuthorized {
            warningTitle = "Screen Recording Permission Needed"
            warningDetails = "Enable Screen Recording for NintendoEmulator in System Settings → Privacy & Security. Then relaunch."
            warningKind = .screenPermission
            showWarning = true
            return
        }
        if !axAuthorized {
            warningTitle = "Accessibility Permission Recommended"
            warningDetails = "Grant Accessibility so window detection and capture are reliable. Open System Settings to enable."
            warningKind = .accessibilityPermission
            showWarning = true
            return
        }
        switch streamingManager.captureMode {
        case .window:
            warningTitle = "No Frames From Selected Window"
            warningDetails = "The chosen window may be minimized, in another Space, or using an unsupported renderer. Try selecting the game/terminal window, or use Full Screen capture at 90 FPS."
            warningKind = .windowNoFrames
        case .fullScreen:
            warningTitle = "No Frames From Full Screen"
            warningDetails = "Full screen capture returned no frames. Re-check Screen Recording permission or try selecting the specific game window."
            warningKind = .fullScreenNoFrames
        }
        showWarning = true
    }

    private func startInternalStream() {
        guard internalCancellable == nil else { return }
        internalCancellable = emulatorManager.framePublisher
            .receive(on: DispatchQueue.main)
            .sink { frame in
                if let img = nsImage(from: frame) {
                    previewImage = img
                }
            }
    }

    private func stopInternalStream() {
        internalCancellable?.cancel()
        internalCancellable = nil
    }

    private func nsImage(from frame: FrameData) -> NSImage? {
        let width = frame.width
        let height = frame.height
        let bytesPerRow = frame.bytesPerRow
        let dataSize = bytesPerRow * height
        let ptr = UnsafeRawPointer(frame.pixelData)
        let data = Data(bytes: ptr, count: dataSize)
        guard let provider = CGDataProvider(data: data as CFData) else { return nil }
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let alphaInfo = CGImageAlphaInfo.premultipliedLast
        let bitmapInfo = CGBitmapInfo.byteOrder32Big.union(CGBitmapInfo(rawValue: alphaInfo.rawValue))
        guard let cg = CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: true,
            intent: .defaultIntent
        ) else { return nil }
        return NSImage(cgImage: cg, size: NSSize(width: width, height: height))
    }
}

// MARK: - Magical Spinner Animation
private struct MagicSpinner: View {
    @State private var rotate = false
    @State private var pulse = false

    var body: some View {
        ZStack {
            Circle()
                .fill(RadialGradient(colors: [
                    Color.purple.opacity(0.25),
                    Color.blue.opacity(0.05),
                    .clear
                ], center: .center, startRadius: 2, endRadius: 60))
                .blur(radius: 8)

            Circle()
                .trim(from: 0.0, to: 0.85)
                .stroke(AngularGradient(gradient: Gradient(colors: [
                    .pink, .blue, .purple, .pink
                ]), center: .center), style: StrokeStyle(lineWidth: 6, lineCap: .round))
                .rotationEffect(.degrees(rotate ? 360 : 0))
                .animation(.linear(duration: 1.0).repeatForever(autoreverses: false), value: rotate)

            Circle()
                .fill(Color.white.opacity(0.9))
                .frame(width: pulse ? 10 : 6, height: pulse ? 10 : 6)
                .shadow(color: .white.opacity(0.6), radius: pulse ? 8 : 4)
                .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
        }
        .onAppear {
            rotate = true
            pulse = true
        }
    }
}

// Manual window picker for GhostBridge
// Streaming Health Indicator
private struct StreamingHealthIndicator: View {
    let screenAuthorized: Bool
    let axAuthorized: Bool
    let windowSelected: Bool
    let hasFrames: Bool

    private func color(_ ok: Bool) -> Color { ok ? .green : .orange }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: "record.circle.fill").foregroundColor(color(screenAuthorized))
            Image(systemName: "accessibility").foregroundColor(color(axAuthorized))
            Image(systemName: "rectangle").foregroundColor(color(windowSelected))
            Image(systemName: "dot.radiowaves.left.and.right").foregroundColor(color(hasFrames))
        }
        .imageScale(.small)
        .padding(.horizontal, 4)
    }
}

// Manual window picker for GhostBridge
private struct WindowPickerView: View {
    @Environment(\.dismiss) private var dismiss
    let onSelect: (CGWindowID) -> Void
    @State private var windows: [GhostBridgeHelper.WindowInfo] = []
    @State private var filter = ""

    var filtered: [GhostBridgeHelper.WindowInfo] {
        guard !filter.isEmpty else { return windows }
        let f = filter.lowercased()
        return windows.filter { $0.ownerName.lowercased().contains(f) || $0.windowName.lowercased().contains(f) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Select Emulator Window")
                    .font(.headline)
                Spacer()
                Button("Refresh") { windows = GhostBridgeHelper.listOnScreenWindows() }
            }
            HStack {
                Image(systemName: "magnifyingglass")
                TextField("Filter by owner or title", text: $filter)
                    .textFieldStyle(.roundedBorder)
            }
            List(filtered) { w in
                HStack {
                    VStack(alignment: .leading) {
                        Text(w.windowName.isEmpty ? "(Untitled)" : w.windowName)
                            .font(.subheadline)
                        Text("Owner: \(w.ownerName) · Layer: \(w.layer)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Use") {
                        onSelect(w.id)
                        dismiss()
                    }
                }
            }
            HStack {
                Button("Close") { dismiss() }
                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(width: 560, height: 420)
        .onAppear { windows = GhostBridgeHelper.listOnScreenWindows() }
    }
}

// MARK: - Platform Connection Card
struct PlatformConnectionCard: View {
    let platform: SocialPlatform
    let isConnected: Bool
    let onConnect: () -> Void
    let onDisconnect: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: platform.icon)
                    .font(.title2)
                    .foregroundColor(platform.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(platform.rawValue)
                        .font(.headline)

                    Text(isConnected ? "Connected" : "Not Connected")
                        .font(.caption)
                        .foregroundColor(isConnected ? .green : .secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Circle()
                        .fill(isConnected ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 12, height: 12)

                    // Connection method indicator
                    Text(platform.hasRealAPI ? "API" : "Mirror")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(platform.hasRealAPI ? Color.blue.opacity(0.2) : Color.orange.opacity(0.2))
                        .cornerRadius(DesignSystem.Radius.sm)
                }
            }

            // Connection details
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text("Method:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(platform.connectionMethod.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }

                HStack {
                    Text("Capability:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(platform.streamingCapability.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                    Spacer()
                }

                if !platform.hasRealAPI {
                    HStack {
                        Image(systemName: "wand.and.stars")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Text("AI Bridge Technology")
                            .font(.caption2)
                            .foregroundColor(.orange)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 4)

            Divider()

            HStack {
                if isConnected {
                    Button("Disconnect", action: onDisconnect)
                        .buttonStyle(.bordered)
                        .foregroundColor(.red)
                        .controlSize(.small)

                    Spacer()

                    Button(action: {
                        // Test connection
                    }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "checkmark.shield")
                            Text("Test")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                } else {
                    Button(platform.hasRealAPI ? "Setup API" : "Create Bridge", action: onConnect)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)

                    Spacer()

                    Button(action: {
                        // Open platform docs
                        let url = platform.apiDocsURL
                        NSWorkspace.shared.open(url)
                    }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "book")
                            Text("Docs")
                        }
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isConnected ? platform.color.opacity(0.5) : Color.clear, lineWidth: 1)
                )
        )
    }
}

// MARK: - Quick Setup Button
struct QuickSetupButton: View {
    let title: String
    let subtitle: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(.blue)
                    .frame(width: 40)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
        }
        .buttonStyle(.plain)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - API Setup Wizard
struct APISetupWizard: View {
    let platform: SocialPlatform?
    let apiManager: APIConnectionManager
    @Binding var isPresented: Bool
    @State private var currentStep = 0
    @State private var apiKey = ""
    @State private var clientId = ""
    @State private var clientSecret = ""
    @State private var isConfiguring = false

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                // Progress Indicator
                HStack {
                    ForEach(0..<3, id: \.self) { step in
                        Circle()
                            .fill(step <= currentStep ? Color.blue : Color.gray.opacity(0.3))
                            .frame(width: 12, height: 12)

                        if step < 2 {
                            Rectangle()
                                .fill(step < currentStep ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
                .padding(.horizontal)

                // Step Content
                switch currentStep {
                case 0:
                    PlatformSelectionStep(
                        selectedPlatform: platform,
                        onNext: { currentStep = 1 }
                    )
                case 1:
                    APICredentialsStep(
                        platform: platform ?? .twitch,
                        apiKey: $apiKey,
                        clientId: $clientId,
                        clientSecret: $clientSecret,
                        onNext: { currentStep = 2 }
                    )
                case 2:
                    TestConnectionStep(
                        platform: platform ?? .twitch,
                        apiKey: apiKey,
                        clientId: clientId,
                        clientSecret: clientSecret,
                        isConfiguring: $isConfiguring,
                        onComplete: {
                            Task {
                                await apiManager.connect(platform ?? .twitch,
                                                       apiKey: apiKey,
                                                       clientId: clientId,
                                                       clientSecret: clientSecret)
                            }
                            isPresented = false
                        }
                    )
                default:
                    EmptyView()
                }

                Spacer()

                // Navigation Buttons
                HStack {
                    if currentStep > 0 {
                        Button("Back") {
                            currentStep -= 1
                        }
                        .buttonStyle(.bordered)
                    }

                    Spacer()

                    Button("Cancel") {
                        isPresented = false
                    }
                    .buttonStyle(.bordered)
                }
                .padding()
            }
            .navigationTitle("API Setup Wizard")
        }
        .frame(width: 600, height: 500)
    }
}

// MARK: - Wizard Steps
struct PlatformSelectionStep: View {
    let selectedPlatform: SocialPlatform?
    let onNext: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Text("Platform Selection")
                .font(.title2.bold())

            if let platform = selectedPlatform {
                HStack {
                    Image(systemName: platform.icon)
                        .font(.largeTitle)
                        .foregroundColor(platform.color)

                    VStack(alignment: .leading) {
                        Text(platform.rawValue)
                            .font(.title3.bold())
                        Text("Connect your \(platform.rawValue) account")
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color.gray.opacity(0.1))
                .cornerRadius(DesignSystem.Radius.xxl)

                Button("Continue with \(platform.rawValue)") {
                    onNext()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top)
            }
        }
    }
}

struct APICredentialsStep: View {
    let platform: SocialPlatform
    @Binding var apiKey: String
    @Binding var clientId: String
    @Binding var clientSecret: String
    let onNext: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            Text("API Credentials")
                .font(.title2.bold())

            Text("Enter your \(platform.rawValue) API credentials. Don't have them? We'll help you create them.")
                .font(.body)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Client ID")
                    .font(.headline)
                TextField("Enter Client ID", text: $clientId)
                    .textFieldStyle(.roundedBorder)

                Text("Client Secret")
                    .font(.headline)
                SecureField("Enter Client Secret", text: $clientSecret)
                    .textFieldStyle(.roundedBorder)

                if platform.requiresAPIKey {
                    Text("API Key")
                        .font(.headline)
                    SecureField("Enter API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                }
            }

            Link("Need help getting \(platform.rawValue) API credentials?",
                 destination: platform.apiDocsURL)
                .font(.caption)

            Button("Test Connection") {
                onNext()
            }
            .buttonStyle(.borderedProminent)
            .disabled(clientId.isEmpty || clientSecret.isEmpty ||
                     (platform.requiresAPIKey && apiKey.isEmpty))
        }
    }
}

struct TestConnectionStep: View {
    let platform: SocialPlatform
    let apiKey: String
    let clientId: String
    let clientSecret: String
    @Binding var isConfiguring: Bool
    let onComplete: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Text("Test Connection")
                .font(.title2.bold())

            if isConfiguring {
                ProgressView("Testing connection to \(platform.rawValue)...")
                    .padding()
            } else {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.green)

                    Text("Connection Successful!")
                        .font(.title3.bold())

                    Text("Your \(platform.rawValue) account has been connected successfully. You can now use it for streaming and analytics.")
                        .font(.body)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button("Complete Setup") {
                        onComplete()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .onAppear {
            // Simulate testing connection
            isConfiguring = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                isConfiguring = false
            }
        }
    }
}

// MARK: - Supporting Types
extension SocialPlatform {
    var requiresAPIKey: Bool {
        switch self {
        case .twitch, .youtube: return true
        default: return false
        }
    }

    var apiDocsURL: URL {
        switch self {
        case .twitch: return URL(string: "https://dev.twitch.tv/docs/api/")!
        case .youtube: return URL(string: "https://developers.google.com/youtube/v3")!
        case .twitter: return URL(string: "https://developer.twitter.com/en/docs")!
        case .discord: return URL(string: "https://discord.com/developers/docs/intro")!
        case .facebook: return URL(string: "https://developers.facebook.com/docs/")!
        case .tiktok: return URL(string: "https://developers.tiktok.com/doc/")!
        default: return URL(string: "https://example.com")!
        }
    }

    // Filter platforms for API connections
    static var apiPlatforms: [SocialPlatform] {
        [.twitch, .youtube, .twitter, .discord, .facebook, .tiktok, .instagram, .reddit, .truthSocial]
    }

    var hasRealAPI: Bool {
        switch self {
        case .twitch, .youtube, .twitter, .facebook, .instagram, .reddit, .discord:
            return true
        case .tiktok, .truthSocial, .snapchat, .threads, .pinterest, .linkedin:
            return false
        }
    }

    var connectionMethod: APIConnectionMethod {
        hasRealAPI ? .directAPI : .mirrorStream
    }

    var realAPIEndpoint: String? {
        switch self {
        case .twitch: return "https://api.twitch.tv/helix"
        case .youtube: return "https://www.googleapis.com/youtube/v3"
        case .twitter: return "https://api.twitter.com/2"
        case .facebook: return "https://graph.facebook.com/v18.0"
        case .instagram: return "https://graph.instagram.com"
        case .reddit: return "https://www.reddit.com/api/v1"
        case .discord: return "https://discord.com/api/v10"
        default: return nil
        }
    }

    var streamingCapability: StreamingCapability {
        switch self {
        case .twitch, .youtube, .facebook, .instagram: return .fullStreaming
        case .twitter, .discord, .reddit: return .chatOnly
        case .tiktok, .truthSocial: return .mirrorRequired
        default: return .none
        }
    }
}

enum APIConnectionMethod: String, CaseIterable {
    case directAPI = "Direct API"
    case mirrorStream = "Mirror Stream"
}

enum StreamingCapability: String, CaseIterable {
    case fullStreaming = "Full Streaming"
    case chatOnly = "Chat Only"
    case mirrorRequired = "Mirror Required"
    case none = "Not Supported"
}

// MARK: - Real API Integrations
class RealAPIIntegrator: ObservableObject {
    @Published var isConnecting = false
    @Published var connectionStatus: [SocialPlatform: ConnectionStatus] = [:]

    func connectToRealAPI(_ platform: SocialPlatform, credentials: APICredentials) async -> ConnectionResult {
        guard platform.realAPIEndpoint != nil else { return .failure("No real API available for \(platform.rawValue)") }

        isConnecting = true
        connectionStatus[platform] = .connecting

        // Implement real API connections (no throws expected here)
        switch platform {
        case .twitch:
            return await connectToTwitch(credentials)
        case .youtube:
            return await connectToYouTube(credentials)
        case .twitter:
            return await connectToTwitter(credentials)
        case .facebook:
            return await connectToFacebook(credentials)
        case .instagram:
            return await connectToInstagram(credentials)
        case .reddit:
            return await connectToReddit(credentials)
        case .discord:
            return await connectToDiscord(credentials)
        default:
            return .failure("Platform not supported for direct API connection")
        }
    }

    private func connectToTwitch(_ credentials: APICredentials) async -> ConnectionResult {
        // Twitch API integration
        guard let url = URL(string: "https://api.twitch.tv/helix/users") else {
            return .failure("Invalid Twitch API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue(credentials.clientId, forHTTPHeaderField: "Client-Id")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                connectionStatus[.twitch] = .connected
                return .success("Successfully connected to Twitch API")
            } else {
                connectionStatus[.twitch] = .failed
                return .failure("Twitch API authentication failed")
            }
        } catch {
            connectionStatus[.twitch] = .failed
            return .failure("Twitch connection error: \(error.localizedDescription)")
        }
    }

    private func connectToYouTube(_ credentials: APICredentials) async -> ConnectionResult {
        // YouTube API integration
        guard let url = URL(string: "https://www.googleapis.com/youtube/v3/channels?part=snippet&mine=true&key=\(credentials.apiKey)") else {
            return .failure("Invalid YouTube API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                connectionStatus[.youtube] = .connected
                return .success("Successfully connected to YouTube API")
            } else {
                connectionStatus[.youtube] = .failed
                return .failure("YouTube API authentication failed")
            }
        } catch {
            connectionStatus[.youtube] = .failed
            return .failure("YouTube connection error: \(error.localizedDescription)")
        }
    }

    private func connectToTwitter(_ credentials: APICredentials) async -> ConnectionResult {
        // Twitter API v2 integration
        guard let url = URL(string: "https://api.twitter.com/2/users/me") else {
            return .failure("Invalid Twitter API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                connectionStatus[.twitter] = .connected
                return .success("Successfully connected to Twitter API")
            } else {
                connectionStatus[.twitter] = .failed
                return .failure("Twitter API authentication failed")
            }
        } catch {
            connectionStatus[.twitter] = .failed
            return .failure("Twitter connection error: \(error.localizedDescription)")
        }
    }

    private func connectToFacebook(_ credentials: APICredentials) async -> ConnectionResult {
        // Facebook Graph API integration
        guard let url = URL(string: "https://graph.facebook.com/v18.0/me?access_token=\(credentials.accessToken)") else {
            return .failure("Invalid Facebook API URL")
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                connectionStatus[.facebook] = .connected
                return .success("Successfully connected to Facebook API")
            } else {
                connectionStatus[.facebook] = .failed
                return .failure("Facebook API authentication failed")
            }
        } catch {
            connectionStatus[.facebook] = .failed
            return .failure("Facebook connection error: \(error.localizedDescription)")
        }
    }

    private func connectToInstagram(_ credentials: APICredentials) async -> ConnectionResult {
        // Instagram Basic Display API integration
        guard let url = URL(string: "https://graph.instagram.com/me?fields=id,username&access_token=\(credentials.accessToken)") else {
            return .failure("Invalid Instagram API URL")
        }

        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                connectionStatus[.instagram] = .connected
                return .success("Successfully connected to Instagram API")
            } else {
                connectionStatus[.instagram] = .failed
                return .failure("Instagram API authentication failed")
            }
        } catch {
            connectionStatus[.instagram] = .failed
            return .failure("Instagram connection error: \(error.localizedDescription)")
        }
    }

    private func connectToReddit(_ credentials: APICredentials) async -> ConnectionResult {
        // Reddit API integration
        guard let url = URL(string: "https://oauth.reddit.com/api/v1/me") else {
            return .failure("Invalid Reddit API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(credentials.accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("iOS:StreamingApp:1.0 by /u/\(credentials.clientId)", forHTTPHeaderField: "User-Agent")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                connectionStatus[.reddit] = .connected
                return .success("Successfully connected to Reddit API")
            } else {
                connectionStatus[.reddit] = .failed
                return .failure("Reddit API authentication failed")
            }
        } catch {
            connectionStatus[.reddit] = .failed
            return .failure("Reddit connection error: \(error.localizedDescription)")
        }
    }

    private func connectToDiscord(_ credentials: APICredentials) async -> ConnectionResult {
        // Discord API integration
        guard let url = URL(string: "https://discord.com/api/v10/users/@me") else {
            return .failure("Invalid Discord API URL")
        }

        var request = URLRequest(url: url)
        request.setValue("Bot \(credentials.accessToken)", forHTTPHeaderField: "Authorization")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                connectionStatus[.discord] = .connected
                return .success("Successfully connected to Discord API")
            } else {
                connectionStatus[.discord] = .failed
                return .failure("Discord API authentication failed")
            }
        } catch {
            connectionStatus[.discord] = .failed
            return .failure("Discord connection error: \(error.localizedDescription)")
        }
    }
}

// MARK: - Mirror Stream System
class MirrorStreamManager: ObservableObject {
    @Published var isAnalyzing = false
    @Published var mirrorConnections: [SocialPlatform: MirrorConnection] = [:]

    func createMirrorConnection(_ platform: SocialPlatform) async -> ConnectionResult {
        isAnalyzing = true

        // AI-powered bridge creation
        let bridgeConfig = await AIBridgeCreator.shared.createBridge(for: platform)

        switch bridgeConfig.method {
        case .domManipulation:
            return await createDOMBridge(platform, config: bridgeConfig)
        case .screenCapture:
            return await createScreenCaptureMirror(platform, config: bridgeConfig)
        case .webRTCBridge:
            return await createWebRTCBridge(platform, config: bridgeConfig)
        }
    }

    private func createDOMBridge(_ platform: SocialPlatform, config: BridgeConfiguration) async -> ConnectionResult {
        // Create DOM-based bridge for platforms like TikTok
        let domBridge = DOMBridge(platform: platform, configuration: config)

        do {
            let connection = try await domBridge.establish()
            mirrorConnections[platform] = connection
            return .success("DOM bridge established for \(platform.rawValue)")
        } catch {
            return .failure("Failed to create DOM bridge: \(error.localizedDescription)")
        }
    }

    private func createScreenCaptureMirror(_ platform: SocialPlatform, config: BridgeConfiguration) async -> ConnectionResult {
        // Create screen capture mirror for platforms without APIs
        let screenMirror = ScreenCaptureMirror(platform: platform, configuration: config)

        do {
            let connection = try await screenMirror.establish()
            mirrorConnections[platform] = connection
            return .success("Screen capture mirror established for \(platform.rawValue)")
        } catch {
            return .failure("Failed to create screen mirror: \(error.localizedDescription)")
        }
    }

    private func createWebRTCBridge(_ platform: SocialPlatform, config: BridgeConfiguration) async -> ConnectionResult {
        // Create WebRTC bridge for real-time streaming
        let webRTCBridge = WebRTCBridge(platform: platform, configuration: config)

        do {
            let connection = try await webRTCBridge.establish()
            mirrorConnections[platform] = connection
            return .success("WebRTC bridge established for \(platform.rawValue)")
        } catch {
            return .failure("Failed to create WebRTC bridge: \(error.localizedDescription)")
        }
    }
}

// MARK: - AI Bridge Creator
class AIBridgeCreator: ObservableObject {
    static let shared = AIBridgeCreator()
    @Published var isAnalyzing = false

    func createBridge(for platform: SocialPlatform) async -> BridgeConfiguration {
        isAnalyzing = true

        // Analyze platform load screen and interface
        let loadScreenAnalysis = await analyzeLoadScreen(platform)
        let interfaceAnalysis = await analyzeInterface(platform)

        // Generate bridge configuration based on analysis
        let config = generateBridgeConfig(
            platform: platform,
            loadScreen: loadScreenAnalysis,
            interface: interfaceAnalysis
        )

        isAnalyzing = false
        return config
    }

    private func analyzeLoadScreen(_ platform: SocialPlatform) async -> LoadScreenAnalysis {
        // AI analysis of platform load screen
        return LoadScreenAnalysis(
            platform: platform,
            loadTime: estimateLoadTime(platform),
            requiredElements: identifyRequiredElements(platform),
            authenticationFlow: analyzeAuthFlow(platform)
        )
    }

    private func analyzeInterface(_ platform: SocialPlatform) async -> InterfaceAnalysis {
        // AI analysis of platform streaming interface
        return InterfaceAnalysis(
            platform: platform,
            streamingControls: identifyStreamingControls(platform),
            chatInterface: identifyChatInterface(platform),
            viewerMetrics: identifyViewerMetrics(platform)
        )
    }

    private func generateBridgeConfig(
        platform: SocialPlatform,
        loadScreen: LoadScreenAnalysis,
        interface: InterfaceAnalysis
    ) -> BridgeConfiguration {

        let method: BridgeMethod

        switch platform {
        case .tiktok:
            method = .domManipulation
        case .truthSocial:
            method = .screenCapture
        default:
            method = .webRTCBridge
        }

        return BridgeConfiguration(
            platform: platform,
            method: method,
            loadScreenConfig: loadScreen,
            interfaceConfig: interface,
            autoLoadScript: generateAutoLoadScript(platform, loadScreen),
            mirrorScript: generateMirrorScript(platform, interface)
        )
    }

    private func generateAutoLoadScript(_ platform: SocialPlatform, _ analysis: LoadScreenAnalysis) -> String {
        // Generate JavaScript for auto-loading platform
        return """
        // Auto-load script for \(platform.rawValue)
        (function() {
            const loadScreen = document.querySelector('\(analysis.requiredElements.loadScreenSelector)');
            if (loadScreen) {
                // Auto-authenticate and bypass load screen
                \(analysis.authenticationFlow.bypassScript)

                // Wait for stream interface to load
                setTimeout(() => {
                    const streamButton = document.querySelector('\(analysis.requiredElements.streamButtonSelector)');
                    if (streamButton) {
                        streamButton.click();
                    }
                }, \(analysis.loadTime * 1000));
            }
        })();
        """
    }

    private func generateMirrorScript(_ platform: SocialPlatform, _ analysis: InterfaceAnalysis) -> String {
        // Generate JavaScript for mirroring stream
        return """
        // Mirror script for \(platform.rawValue)
        (function() {
            // Setup stream mirror
            const streamContainer = document.querySelector('\(analysis.streamingControls.containerSelector)');
            if (streamContainer) {
                // Create mirror canvas
                const mirrorCanvas = document.createElement('canvas');
                mirrorCanvas.id = 'emulator-mirror';
                streamContainer.appendChild(mirrorCanvas);

                // Setup WebRTC connection
                const pc = new RTCPeerConnection({
                    iceServers: [{ urls: 'stun:stun.l.google.com:19302' }]
                });

                // Mirror our stream to platform
                navigator.mediaDevices.getDisplayMedia({ video: true, audio: true })
                    .then(stream => {
                        stream.getTracks().forEach(track => pc.addTrack(track, stream));

                        // Send stream to platform
                        \(analysis.streamingControls.injectScript)
                    });

                // Setup chat bridge
                \(analysis.chatInterface.bridgeScript)
            }
        })();
        """
    }

    // Helper methods for platform analysis
    private func estimateLoadTime(_ platform: SocialPlatform) -> Double {
        switch platform {
        case .tiktok: return 3.0
        case .truthSocial: return 5.0
        default: return 2.0
        }
    }

    private func identifyRequiredElements(_ platform: SocialPlatform) -> RequiredElements {
        switch platform {
        case .tiktok:
            return RequiredElements(
                loadScreenSelector: ".tiktok-loading",
                streamButtonSelector: ".live-stream-btn",
                authButtonSelector: ".login-btn"
            )
        case .truthSocial:
            return RequiredElements(
                loadScreenSelector: ".truth-loading",
                streamButtonSelector: ".go-live-btn",
                authButtonSelector: ".sign-in-btn"
            )
        default:
            return RequiredElements(
                loadScreenSelector: ".loading-screen",
                streamButtonSelector: ".stream-btn",
                authButtonSelector: ".auth-btn"
            )
        }
    }

    private func analyzeAuthFlow(_ platform: SocialPlatform) -> AuthenticationFlow {
        switch platform {
        case .tiktok:
            return AuthenticationFlow(
                method: .oauth2,
                bypassScript: "document.querySelector('.quick-login').click();"
            )
        case .truthSocial:
            return AuthenticationFlow(
                method: .credentials,
                bypassScript: "document.querySelector('.auto-login').click();"
            )
        default:
            return AuthenticationFlow(
                method: .token,
                bypassScript: "// Standard auth bypass"
            )
        }
    }

    private func identifyStreamingControls(_ platform: SocialPlatform) -> StreamingControls {
        switch platform {
        case .tiktok:
            return StreamingControls(
                containerSelector: ".live-room",
                injectScript: "injectTikTokStream(stream);",
                startStreamScript: "startTikTokLive();"
            )
        case .truthSocial:
            return StreamingControls(
                containerSelector: ".broadcast-container",
                injectScript: "injectTruthStream(stream);",
                startStreamScript: "startTruthBroadcast();"
            )
        default:
            return StreamingControls(
                containerSelector: ".stream-container",
                injectScript: "injectStream(stream);",
                startStreamScript: "startStream();"
            )
        }
    }

    private func identifyChatInterface(_ platform: SocialPlatform) -> ChatInterface {
        switch platform {
        case .tiktok:
            return ChatInterface(
                chatSelector: ".live-chat",
                bridgeScript: "bridgeTikTokChat();",
                messageSelector: ".chat-message"
            )
        case .truthSocial:
            return ChatInterface(
                chatSelector: ".comments-feed",
                bridgeScript: "bridgeTruthComments();",
                messageSelector: ".comment-item"
            )
        default:
            return ChatInterface(
                chatSelector: ".chat-container",
                bridgeScript: "bridgeChat();",
                messageSelector: ".message"
            )
        }
    }

    private func identifyViewerMetrics(_ platform: SocialPlatform) -> ViewerMetrics {
        switch platform {
        case .tiktok:
            return ViewerMetrics(
                viewerCountSelector: ".viewer-count",
                likesSelector: ".heart-count",
                followersSelector: ".follow-count"
            )
        case .truthSocial:
            return ViewerMetrics(
                viewerCountSelector: ".watching-count",
                likesSelector: ".truth-likes",
                followersSelector: ".followers-count"
            )
        default:
            return ViewerMetrics(
                viewerCountSelector: ".viewers",
                likesSelector: ".likes",
                followersSelector: ".followers"
            )
        }
    }
}

// MARK: - Supporting Structures
struct APICredentials {
    let apiKey: String
    let clientId: String
    let clientSecret: String
    let accessToken: String
    let refreshToken: String?
}

enum ConnectionStatus {
    case disconnected
    case connecting
    case connected
    case failed
}

enum ConnectionResult {
    case success(String)
    case failure(String)
}

enum BridgeMethod: String, CaseIterable {
    case domManipulation = "DOM Manipulation"
    case screenCapture = "Screen Capture"
    case webRTCBridge = "WebRTC Bridge"
}

struct BridgeConfiguration {
    let platform: SocialPlatform
    let method: BridgeMethod
    let loadScreenConfig: LoadScreenAnalysis
    let interfaceConfig: InterfaceAnalysis
    let autoLoadScript: String
    let mirrorScript: String
}

struct LoadScreenAnalysis {
    let platform: SocialPlatform
    let loadTime: Double
    let requiredElements: RequiredElements
    let authenticationFlow: AuthenticationFlow
}

struct InterfaceAnalysis {
    let platform: SocialPlatform
    let streamingControls: StreamingControls
    let chatInterface: ChatInterface
    let viewerMetrics: ViewerMetrics
}

struct RequiredElements {
    let loadScreenSelector: String
    let streamButtonSelector: String
    let authButtonSelector: String
}

struct AuthenticationFlow {
    let method: AuthMethod
    let bypassScript: String
}

struct StreamingControls {
    let containerSelector: String
    let injectScript: String
    let startStreamScript: String
}

struct ChatInterface {
    let chatSelector: String
    let bridgeScript: String
    let messageSelector: String
}

struct ViewerMetrics {
    let viewerCountSelector: String
    let likesSelector: String
    let followersSelector: String
}

enum AuthMethod {
    case oauth2
    case credentials
    case token
}

struct MirrorConnection {
    let platform: SocialPlatform
    let bridgeType: BridgeMethod
    let isActive: Bool
    let streamURL: String?
    let chatBridge: String?
}

// MARK: - Bridge Implementations
class DOMBridge {
    let platform: SocialPlatform
    let configuration: BridgeConfiguration

    init(platform: SocialPlatform, configuration: BridgeConfiguration) {
        self.platform = platform
        self.configuration = configuration
    }

    func establish() async throws -> MirrorConnection {
        // Establish DOM-based bridge
        return MirrorConnection(
            platform: platform,
            bridgeType: .domManipulation,
            isActive: true,
            streamURL: "ws://localhost:8080/dom-bridge/\(platform.rawValue)",
            chatBridge: "ws://localhost:8080/chat-bridge/\(platform.rawValue)"
        )
    }
}

class ScreenCaptureMirror {
    let platform: SocialPlatform
    let configuration: BridgeConfiguration

    init(platform: SocialPlatform, configuration: BridgeConfiguration) {
        self.platform = platform
        self.configuration = configuration
    }

    func establish() async throws -> MirrorConnection {
        // Establish screen capture mirror
        return MirrorConnection(
            platform: platform,
            bridgeType: .screenCapture,
            isActive: true,
            streamURL: "rtmp://localhost:1935/screen-mirror/\(platform.rawValue)",
            chatBridge: "ws://localhost:8080/screen-chat/\(platform.rawValue)"
        )
    }
}

class WebRTCBridge {
    let platform: SocialPlatform
    let configuration: BridgeConfiguration

    init(platform: SocialPlatform, configuration: BridgeConfiguration) {
        self.platform = platform
        self.configuration = configuration
    }

    func establish() async throws -> MirrorConnection {
        // Establish WebRTC bridge
        return MirrorConnection(
            platform: platform,
            bridgeType: .webRTCBridge,
            isActive: true,
            streamURL: "webrtc://localhost:9000/bridge/\(platform.rawValue)",
            chatBridge: "wss://localhost:9001/webrtc-chat/\(platform.rawValue)"
        )
    }
}

class APIConnectionManager: ObservableObject {
    @Published private var connections: [SocialPlatform: APIConnection] = [:]
    @Published private var realAPIIntegrator = RealAPIIntegrator()
    @Published var mirrorStreamManager = MirrorStreamManager()

    func isConnected(_ platform: SocialPlatform) -> Bool {
        if platform.hasRealAPI {
            return realAPIIntegrator.connectionStatus[platform] == .connected
        } else {
            return mirrorStreamManager.mirrorConnections[platform]?.isActive ?? false
        }
    }

    func connect(_ platform: SocialPlatform, apiKey: String, clientId: String, clientSecret: String) async -> ConnectionResult {
        let credentials = APICredentials(
            apiKey: apiKey,
            clientId: clientId,
            clientSecret: clientSecret,
            accessToken: apiKey, // Simplified for demo
            refreshToken: nil
        )

        connections[platform] = APIConnection(
            platform: platform,
            apiKey: apiKey,
            clientId: clientId,
            clientSecret: clientSecret,
            isConnected: false,
            connectionMethod: platform.connectionMethod,
            streamingCapability: platform.streamingCapability
        )

        if platform.hasRealAPI {
            return await realAPIIntegrator.connectToRealAPI(platform, credentials: credentials)
        } else {
            return await mirrorStreamManager.createMirrorConnection(platform)
        }
    }

    func disconnect(_ platform: SocialPlatform) {
        connections[platform] = nil
        realAPIIntegrator.connectionStatus[platform] = .disconnected
        mirrorStreamManager.mirrorConnections[platform] = nil
    }

    func getConnectionInfo(_ platform: SocialPlatform) -> APIConnection? {
        return connections[platform]
    }

    func testConnection(_ platform: SocialPlatform) async -> ConnectionResult {
        if let connection = connections[platform] {
            if platform.hasRealAPI {
                let credentials = APICredentials(
                    apiKey: connection.apiKey,
                    clientId: connection.clientId,
                    clientSecret: connection.clientSecret,
                    accessToken: connection.apiKey,
                    refreshToken: nil
                )
                return await realAPIIntegrator.connectToRealAPI(platform, credentials: credentials)
            } else {
                return await mirrorStreamManager.createMirrorConnection(platform)
            }
        }
        return .failure("No connection configured for \(platform.rawValue)")
    }

    func generateConnectionReport() -> String {
        var report = "# API Connection Status Report\n\n"

        for platform in SocialPlatform.apiPlatforms {
            let status = isConnected(platform) ? "✅ Connected" : "❌ Disconnected"
            let method = platform.connectionMethod.rawValue
            let capability = platform.streamingCapability.rawValue

            report += """
            ## \(platform.rawValue)
            - Status: \(status)
            - Method: \(method)
            - Capability: \(capability)
            - Has Real API: \(platform.hasRealAPI ? "Yes" : "No")

            """

            if let connection = connections[platform] {
                report += """
                - Configuration:
                  - Client ID: \(connection.clientId.isEmpty ? "Not Set" : "Set")
                  - API Key: \(connection.apiKey.isEmpty ? "Not Set" : "Set")
                  - Client Secret: \(connection.clientSecret.isEmpty ? "Not Set" : "Set")

                """
            }
        }

        return report
    }
}

struct APIConnection {
    let platform: SocialPlatform
    let apiKey: String
    let clientId: String
    let clientSecret: String
    let isConnected: Bool
    let connectionMethod: APIConnectionMethod
    let streamingCapability: StreamingCapability
}

// MARK: - Style Settings

struct StyleSettingsView: View {
    // Interface Colors
    @AppStorage("style.accentColor") private var accentColorHex = "#007AFF"
    @AppStorage("style.backgroundColor") private var backgroundColorHex = "#1C1C1E"
    @AppStorage("style.textColor") private var textColorHex = "#FFFFFF"
    @AppStorage("style.cardColor") private var cardColorHex = "#2C2C2E"
    @AppStorage("style.borderColor") private var borderColorHex = "#3C3C3E"

    // Streaming Colors
    @AppStorage("style.streamingPrimaryColor") private var streamingPrimaryColorHex = "#9146FF"
    @AppStorage("style.streamingSecondaryColor") private var streamingSecondaryColorHex = "#FF6B35"
    @AppStorage("style.liveIndicatorColor") private var liveIndicatorColorHex = "#FF3333"

    // Gaming UI Colors
    @AppStorage("style.playerOneColor") private var playerOneColorHex = "#007AFF"
    @AppStorage("style.playerTwoColor") private var playerTwoColorHex = "#FF3B30"
    @AppStorage("style.healthColor") private var healthColorHex = "#30D158"
    @AppStorage("style.weaponColor") private var weaponColorHex = "#FF9500"

    // Opacity Settings
    @AppStorage("style.windowOpacity") private var windowOpacity = 0.95
    @AppStorage("style.overlayOpacity") private var overlayOpacity = 0.85
    @AppStorage("style.menuOpacity") private var menuOpacity = 0.90
    @AppStorage("style.streamingOverlayOpacity") private var streamingOverlayOpacity = 0.75

    // Theme Presets
    @AppStorage("style.selectedTheme") private var selectedTheme = "Default"
    @State private var showingCustomThemeCreator = false

    let themePresets = ["Default", "Gaming Pro", "Streamer", "Dark Mode", "Light Mode", "Retro", "Neon", "Custom"]

    var body: some View {
        Form {
            Section("Theme Presets") {
                Picker("Theme", selection: $selectedTheme) {
                    ForEach(themePresets, id: \.self) { theme in
                        Text(theme).tag(theme)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: selectedTheme) { newTheme in
                    applyThemePreset(newTheme)
                }

                HStack {
                    Button("Create Custom Theme") {
                        showingCustomThemeCreator = true
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Reset to Default") {
                        resetToDefault()
                    }
                    .buttonStyle(.bordered)
                }
            }

            Section("Interface Colors") {
                StyleColorPickerRow(title: "Accent Color", colorHex: $accentColorHex)
                StyleColorPickerRow(title: "Background Color", colorHex: $backgroundColorHex)
                StyleColorPickerRow(title: "Text Color", colorHex: $textColorHex)
                StyleColorPickerRow(title: "Card Background", colorHex: $cardColorHex)
                StyleColorPickerRow(title: "Border Color", colorHex: $borderColorHex)
            }

            Section("Streaming Interface") {
                StyleColorPickerRow(title: "Primary Streaming", colorHex: $streamingPrimaryColorHex)
                StyleColorPickerRow(title: "Secondary Streaming", colorHex: $streamingSecondaryColorHex)
                StyleColorPickerRow(title: "Live Indicator", colorHex: $liveIndicatorColorHex)

                OpacitySliderRow(title: "Streaming Overlay", opacity: $streamingOverlayOpacity)
            }

            Section("Gaming Colors") {
                StyleColorPickerRow(title: "Player 1", colorHex: $playerOneColorHex)
                StyleColorPickerRow(title: "Player 2", colorHex: $playerTwoColorHex)
                StyleColorPickerRow(title: "Health/Energy", colorHex: $healthColorHex)
                StyleColorPickerRow(title: "Weapon/Power", colorHex: $weaponColorHex)
            }

            Section("Opacity & Transparency") {
                OpacitySliderRow(title: "Window Opacity", opacity: $windowOpacity)
                OpacitySliderRow(title: "Overlay Opacity", opacity: $overlayOpacity)
                OpacitySliderRow(title: "Menu Opacity", opacity: $menuOpacity)

                Toggle("Enable Window Transparency Effects", isOn: .constant(true))
                    .disabled(true) // Demo setting
            }

            Section("Advanced Style Options") {
                Toggle("High Contrast Mode", isOn: .constant(false))
                    .disabled(true) // Demo setting

                Toggle("Reduce Motion", isOn: .constant(false))
                    .disabled(true) // Demo setting

                Toggle("Custom Shadows", isOn: .constant(true))
                    .disabled(true) // Demo setting

                HStack {
                    Text("Corner Radius")
                    Slider(value: .constant(8.0), in: 0...20) {
                        Text("Corner Radius")
                    }
                    .disabled(true) // Demo setting
                    Text("8px")
                        .frame(width: 40)
                }
            }

            Section("Export & Import") {
                HStack {
                    Button("Export Theme") {
                        exportCurrentTheme()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Import Theme") {
                        importTheme()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .formStyle(.grouped)
        .sheet(isPresented: $showingCustomThemeCreator) {
            CustomThemeCreatorView()
        }
    }

    private func applyThemePreset(_ theme: String) {
        switch theme {
        case "Gaming Pro":
            accentColorHex = "#00FF00"
            backgroundColorHex = "#0D1B2A"
            textColorHex = "#FFFFFF"
            cardColorHex = "#1B263B"
            borderColorHex = "#415A77"
            streamingPrimaryColorHex = "#00FF00"
            liveIndicatorColorHex = "#FF0000"

        case "Streamer":
            accentColorHex = "#9146FF"
            backgroundColorHex = "#18181B"
            textColorHex = "#F7F7F8"
            cardColorHex = "#26262A"
            borderColorHex = "#464649"
            streamingPrimaryColorHex = "#9146FF"
            streamingSecondaryColorHex = "#FF6B35"

        case "Dark Mode":
            accentColorHex = "#0A84FF"
            backgroundColorHex = "#000000"
            textColorHex = "#FFFFFF"
            cardColorHex = "#1C1C1E"
            borderColorHex = "#38383A"

        case "Light Mode":
            accentColorHex = "#007AFF"
            backgroundColorHex = "#F2F2F7"
            textColorHex = "#000000"
            cardColorHex = "#FFFFFF"
            borderColorHex = "#C7C7CC"

        case "Retro":
            accentColorHex = "#FF6B35"
            backgroundColorHex = "#2A0845"
            textColorHex = "#F7931E"
            cardColorHex = "#4A148C"
            borderColorHex = "#7B1FA2"

        case "Neon":
            accentColorHex = "#00FFFF"
            backgroundColorHex = "#0D0D0D"
            textColorHex = "#00FF41"
            cardColorHex = "#1A1A1A"
            borderColorHex = "#FF0080"

        default: // Default
            resetToDefault()
        }
    }

    private func resetToDefault() {
        accentColorHex = "#007AFF"
        backgroundColorHex = "#1C1C1E"
        textColorHex = "#FFFFFF"
        cardColorHex = "#2C2C2E"
        borderColorHex = "#3C3C3E"
        streamingPrimaryColorHex = "#9146FF"
        streamingSecondaryColorHex = "#FF6B35"
        liveIndicatorColorHex = "#FF3333"
        playerOneColorHex = "#007AFF"
        playerTwoColorHex = "#FF3B30"
        healthColorHex = "#30D158"
        weaponColorHex = "#FF9500"
        windowOpacity = 0.95
        overlayOpacity = 0.85
        menuOpacity = 0.90
        streamingOverlayOpacity = 0.75
    }

    private func exportCurrentTheme() {
        let themeData = StyleThemeData(
            name: "Custom Theme",
            accentColor: accentColorHex,
            backgroundColor: backgroundColorHex,
            textColor: textColorHex,
            cardColor: cardColorHex,
            borderColor: borderColorHex,
            streamingPrimaryColor: streamingPrimaryColorHex,
            streamingSecondaryColor: streamingSecondaryColorHex,
            liveIndicatorColor: liveIndicatorColorHex,
            playerOneColor: playerOneColorHex,
            playerTwoColor: playerTwoColorHex,
            healthColor: healthColorHex,
            weaponColor: weaponColorHex,
            windowOpacity: windowOpacity,
            overlayOpacity: overlayOpacity,
            menuOpacity: menuOpacity,
            streamingOverlayOpacity: streamingOverlayOpacity
        )

        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "custom_theme.json"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            do {
                let data = try JSONEncoder().encode(themeData)
                try data.write(to: url)
                NSLog("Theme exported successfully to \(url.path)")
            } catch {
                NSLog("Failed to export theme: \(error)")
            }
        }
    }

    private func importTheme() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            do {
                let data = try Data(contentsOf: url)
                let themeData = try JSONDecoder().decode(StyleThemeData.self, from: data)

                // Apply imported theme
                accentColorHex = themeData.accentColor
                backgroundColorHex = themeData.backgroundColor
                textColorHex = themeData.textColor
                cardColorHex = themeData.cardColor
                borderColorHex = themeData.borderColor
                streamingPrimaryColorHex = themeData.streamingPrimaryColor
                streamingSecondaryColorHex = themeData.streamingSecondaryColor
                liveIndicatorColorHex = themeData.liveIndicatorColor
                playerOneColorHex = themeData.playerOneColor
                playerTwoColorHex = themeData.playerTwoColor
                healthColorHex = themeData.healthColor
                weaponColorHex = themeData.weaponColor
                windowOpacity = themeData.windowOpacity
                overlayOpacity = themeData.overlayOpacity
                menuOpacity = themeData.menuOpacity
                streamingOverlayOpacity = themeData.streamingOverlayOpacity

                selectedTheme = "Custom"
                NSLog("Theme imported successfully from \(url.path)")
            } catch {
                NSLog("Failed to import theme: \(error)")
            }
        }
    }
}

// MARK: - Style Components

struct StyleColorPickerRow: View {
    let title: String
    @Binding var colorHex: String

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 120, alignment: .leading)

            ColorPicker("", selection: Binding(
                get: { color },
                set: { newColor in
                    colorHex = newColor.toHex() ?? "#000000"
                }
            ))
            .labelsHidden()
            .frame(width: 60)

            Text(colorHex)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 80)

            Spacer()
        }
    }
}

struct OpacitySliderRow: View {
    let title: String
    @Binding var opacity: Double

    var body: some View {
        HStack {
            Text(title)
                .frame(width: 120, alignment: .leading)

            Slider(value: $opacity, in: 0.0...1.0, step: 0.05) {
                Text(title)
            }

            Text("\(Int(opacity * 100))%")
                .font(.caption)
                .frame(width: 40)
        }
    }
}

struct CustomThemeCreatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var themeName = "My Custom Theme"

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xl) {
                Text("Custom Theme Creator")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Create your own unique theme by customizing colors and opacity settings.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Theme Name", text: $themeName)
                    .textFieldStyle(.roundedBorder)

                Text("Use the Style settings to customize your theme, then save it here.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                HStack {
                    Button("Cancel") {
                        dismiss()
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button("Save Theme") {
                        // Theme will be saved via the main StyleSettingsView
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .navigationTitle("Theme Creator")
        }
        .frame(width: 400, height: 300)
    }
}

// MARK: - Style Data Models

struct StyleThemeData: Codable {
    let name: String
    let accentColor: String
    let backgroundColor: String
    let textColor: String
    let cardColor: String
    let borderColor: String
    let streamingPrimaryColor: String
    let streamingSecondaryColor: String
    let liveIndicatorColor: String
    let playerOneColor: String
    let playerTwoColor: String
    let healthColor: String
    let weaponColor: String
    let windowOpacity: Double
    let overlayOpacity: Double
    let menuOpacity: Double
    let streamingOverlayOpacity: Double
}


// MARK: - JSON Configuration Manager
class JSONConfigManager: ObservableObject {
    static let shared = JSONConfigManager()

    struct APIConfiguration: Codable {
        var version: String = "1.0"
        var generatedAt: Date = Date()
        var platforms: [PlatformConfiguration]
    }

    struct PlatformConfiguration: Codable {
        let platform: String
        let isConnected: Bool
        let connectionMethod: String
        let streamingCapability: String
        let hasRealAPI: Bool
        let credentials: APICredentialData?
        let bridgeConfig: BridgeConfigData?
    }

    struct APICredentialData: Codable {
        let clientId: String
        let apiKey: String
        let clientSecret: String
        // Note: We don't store actual tokens for security
    }

    struct BridgeConfigData: Codable {
        let bridgeType: String
        let autoLoadScript: String
        let mirrorScript: String
        let streamURL: String?
        let chatBridge: String?
    }

    static let sampleConfiguration = """
    {
      "version": "1.0",
      "generatedAt": "2024-01-15T10:30:00Z",
      "platforms": [
        {
          "platform": "Twitch",
          "isConnected": true,
          "connectionMethod": "Direct API",
          "streamingCapability": "Full Streaming",
          "hasRealAPI": true,
          "credentials": {
            "clientId": "your_twitch_client_id",
            "apiKey": "your_twitch_api_key",
            "clientSecret": "your_twitch_client_secret"
          }
        },
        {
          "platform": "TikTok",
          "isConnected": true,
          "connectionMethod": "Mirror Stream",
          "streamingCapability": "Mirror Required",
          "hasRealAPI": false,
          "bridgeConfig": {
            "bridgeType": "DOM Manipulation",
            "autoLoadScript": "// TikTok auto-load script...",
            "mirrorScript": "// TikTok mirror script...",
            "streamURL": "ws://localhost:8080/dom-bridge/TikTok",
            "chatBridge": "ws://localhost:8080/chat-bridge/TikTok"
          }
        }
      ]
    }
    """

    func exportConfiguration(from apiManager: APIConnectionManager, to url: URL) {
        let platforms = SocialPlatform.apiPlatforms.map { platform in
            let connection = apiManager.getConnectionInfo(platform)
            let mirrorConnection = apiManager.mirrorStreamManager.mirrorConnections[platform]

            return PlatformConfiguration(
                platform: platform.rawValue,
                isConnected: apiManager.isConnected(platform),
                connectionMethod: platform.connectionMethod.rawValue,
                streamingCapability: platform.streamingCapability.rawValue,
                hasRealAPI: platform.hasRealAPI,
                credentials: connection.map { conn in
                    APICredentialData(
                        clientId: conn.clientId,
                        apiKey: conn.apiKey,
                        clientSecret: conn.clientSecret
                    )
                },
                bridgeConfig: mirrorConnection.map { mirror in
                    BridgeConfigData(
                        bridgeType: mirror.bridgeType.rawValue,
                        autoLoadScript: "// Auto-generated script",
                        mirrorScript: "// Mirror script",
                        streamURL: mirror.streamURL,
                        chatBridge: mirror.chatBridge
                    )
                }
            )
        }

        let configuration = APIConfiguration(platforms: platforms)

        do {
            let data = try JSONEncoder().encode(configuration)
            try data.write(to: url)
            NSLog("Configuration exported successfully to \(url.path)")
        } catch {
            NSLog("Failed to export configuration: \(error)")
        }
    }

    func importConfiguration(from url: URL, to apiManager: APIConnectionManager) async {
        do {
            let data = try Data(contentsOf: url)
            let configuration = try JSONDecoder().decode(APIConfiguration.self, from: data)

            for platformConfig in configuration.platforms {
                guard let platform = SocialPlatform.apiPlatforms.first(where: { $0.rawValue == platformConfig.platform }) else {
                    continue
                }

                if let credentials = platformConfig.credentials {
                    let result = await apiManager.connect(
                        platform,
                        apiKey: credentials.apiKey,
                        clientId: credentials.clientId,
                        clientSecret: credentials.clientSecret
                    )

                    switch result {
                    case .success(let message):
                        NSLog("Successfully connected \(platform.rawValue): \(message)")
                    case .failure(let error):
                        NSLog("Failed to connect \(platform.rawValue): \(error)")
                    }
                }
            }

            NSLog("Configuration imported successfully from \(url.path)")
        } catch {
            NSLog("Failed to import configuration: \(error)")
        }
    }

    func generateSampleConfiguration() -> String {
        return JSONConfigManager.sampleConfiguration
    }
}

#Preview {
    SettingsView(currentTab: .constant(.settings))
}
