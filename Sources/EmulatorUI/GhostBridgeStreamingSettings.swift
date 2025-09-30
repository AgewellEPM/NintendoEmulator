import SwiftUI
import EmulatorKit

/// Advanced streaming settings with GhostBridge integration
public struct GhostBridgeStreamingSettings: View {
    @ObservedObject public var streamingManager: StreamingManager
    @ObservedObject public var webcamManager: StreamingWebcamManager
    @Environment(\.dismiss) private var dismiss

    @State private var streamTitle = ""
    @State private var streamCategory = "Gaming"
    @State private var selectedPlatforms: Set<StreamingPlatform> = []
    @State private var showingPermissionAlert = false
    @State private var permissionStatus = ""
    @State private var showingWizard = false

    public init(streamingManager: StreamingManager, webcamManager: StreamingWebcamManager) {
        self.streamingManager = streamingManager
        self.webcamManager = webcamManager
    }

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                    // Header
                    headerSection

                    Divider()

                    // Stream Settings
                    streamSettingsSection

                    Divider()

                    // Platform Selection
                    platformSection

                    Divider()

                    // GhostBridge Status
                    ghostBridgeSection

                    Divider()

                    // Webcam Settings
                    webcamSection

                    Divider()

                    // Action Buttons
                    actionButtons
                }
                .padding()
            }
            .navigationTitle("Advanced Streaming")
            // .navigationBarTitleDisplayMode not available on macOS
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .frame(width: 600, height: 700)
        .onAppear {
            loadCurrentSettings()
        }
    }

    // MARK: - Sections

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: "tv.and.hifispeaker.fill")
                    .foregroundColor(.blue)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("GhostBridge Streaming")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text("Professional streaming with advanced features")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var streamSettingsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Stream Information")
                .font(.headline)

            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Title:")
                        .frame(width: 80, alignment: .leading)
                    TextField("Enter stream title", text: $streamTitle)
                        .textFieldStyle(.roundedBorder)
                }

                HStack {
                    Text("Category:")
                        .frame(width: 80, alignment: .leading)
                    TextField("Gaming", text: $streamCategory)
                        .textFieldStyle(.roundedBorder)
                }
            }
        }
    }

    private var platformSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Streaming Platforms")
                .font(.headline)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                PlatformToggle(
                    platform: .twitch,
                    isSelected: selectedPlatforms.contains(.twitch),
                    isConnected: streamingManager.connectedPlatforms.contains(.twitch)
                ) { selected in
                    if selected {
                        selectedPlatforms.insert(.twitch)
                    } else {
                        selectedPlatforms.remove(.twitch)
                    }
                }

                PlatformToggle(
                    platform: .youtube,
                    isSelected: selectedPlatforms.contains(.youtube),
                    isConnected: streamingManager.connectedPlatforms.contains(.youtube)
                ) { selected in
                    if selected {
                        selectedPlatforms.insert(.youtube)
                    } else {
                        selectedPlatforms.remove(.youtube)
                    }
                }

                if !streamingManager.connectedPlatforms.isEmpty {
                    Text("Note: Connect to platforms in the main streaming dashboard")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.top, 4)
                }
            }
        }
    }

    private var ghostBridgeSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("GhostBridge Status")
                .font(.headline)

            VStack(spacing: DesignSystem.Spacing.sm) {
                StatusRow(
                    title: "GhostBridge Ready",
                    status: streamingManager.ghostBridgeReady,
                    icon: "checkmark.shield"
                )

                StatusRow(
                    title: "Permissions Granted",
                    status: streamingManager.permissionsGranted,
                    icon: "lock.shield"
                )

                StatusRow(
                    title: "Screen Recording",
                    status: GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized(),
                    icon: "record.circle"
                )

                StatusRow(
                    title: "Accessibility",
                    status: GhostBridgeHelper.isAccessibilityEffectivelyTrusted(),
                    icon: "accessibility"
                )

                if !streamingManager.ghostBridgeReady {
                    Button("Grant Permissions") {
                        GhostBridgeHelper.openAllPermissions()
                    }
                    .buttonStyle(.borderedProminent)
                    .padding(.top, 8)

                    Button("Open Permissions Wizard") {
                        showingWizard = true
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .sheet(isPresented: $showingWizard) {
            PermissionWizardView()
        }
    }

    private var webcamSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Webcam Settings")
                .font(.headline)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Toggle("Enable Webcam Overlay", isOn: $webcamManager.isWebcamEnabled)
                    .onChange(of: webcamManager.isWebcamEnabled) { enabled in
                        if enabled {
                            webcamManager.startWebcam()
                        } else {
                            webcamManager.stopWebcam()
                        }
                    }

                if webcamManager.isWebcamEnabled {
                    HStack {
                        Text("Position:")
                        Picker("Position", selection: $webcamManager.webcamPosition) {
                            ForEach(StreamingWebcamManager.WebcamPosition.allCases, id: \.self) { position in
                                Text(position.rawValue).tag(position)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(width: 120)
                    }

                    HStack {
                        Text("Size:")
                        Picker("Size", selection: $webcamManager.webcamSize) {
                            ForEach(StreamingWebcamManager.WebcamSize.allCases, id: \.self) { size in
                                Text(size.rawValue).tag(size)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    private var actionButtons: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Start Enhanced Streaming
            Button(action: startEnhancedStreaming) {
                HStack {
                    Image(systemName: streamingManager.isStreaming ? "stop.fill" : "play.fill")
                    Text(streamingManager.isStreaming ? "Stop Enhanced Stream" : "Start Enhanced Stream")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(streamingManager.isStreaming ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(DesignSystem.Radius.lg)
            }
            .disabled(!streamingManager.ghostBridgeReady || streamTitle.isEmpty)

            // Quick webcam test
            Button("Test Webcam") {
                webcamManager.toggleWebcam()
            }
            .buttonStyle(.bordered)
            .disabled(!GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized())
        }
    }

    // MARK: - Actions

    private func loadCurrentSettings() {
        streamTitle = streamingManager.streamTitle
        streamCategory = streamingManager.streamCategory
        selectedPlatforms = streamingManager.connectedPlatforms
    }

    private func startEnhancedStreaming() {
        Task {
            do {
                if streamingManager.isStreaming {
                    await streamingManager.stopStream()
                } else {
                    try await streamingManager.startGhostBridgeStream(
                        title: streamTitle,
                        category: streamCategory
                    )
                }
            } catch {
                permissionStatus = error.localizedDescription
                showingPermissionAlert = true
            }
        }
    }
}

// MARK: - Supporting Views

struct PlatformToggle: View {
    let platform: StreamingPlatform
    let isSelected: Bool
    let isConnected: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Toggle("", isOn: .constant(isSelected))
                .onChange(of: isSelected) { newValue in
                    onToggle(newValue)
                }
                .disabled(!isConnected)

            Image(systemName: platform.iconName)
                .foregroundColor(platform.color)

            Text(platform.displayName)
                .foregroundColor(isConnected ? .primary : .secondary)

            Spacer()

            if isConnected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Text("Not Connected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

struct StatusRow: View {
    let title: String
    let status: Bool
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(status ? .green : .orange)

            Text(title)

            Spacer()

            Text(status ? "Ready" : "Needs Setup")
                .font(.caption)
                .foregroundColor(status ? .green : .orange)
        }
    }
}

// MARK: - Extensions

extension StreamingPlatform {
    var iconName: String {
        switch self {
        case .twitch: return "tv"
        case .youtube: return "play.rectangle"
        case .facebook: return "person.2"
        // .discord case removed as it's not in the enum
        case .custom: return "antenna.radiowaves.left.and.right"
        }
    }

    var color: Color {
        switch self {
        case .twitch: return .purple
        case .youtube: return .red
        case .facebook: return .blue
        // .discord case removed as it's not in the enum
        case .custom: return .gray
        }
    }

    var displayName: String {
        switch self {
        case .twitch: return "Twitch"
        case .youtube: return "YouTube"
        case .facebook: return "Facebook Gaming"
        // .discord case removed as it's not in the enum
        case .custom: return "Custom RTMP"
        }
    }
}
