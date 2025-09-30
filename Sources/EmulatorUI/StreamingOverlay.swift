import SwiftUI

/// NN/g Enhanced Go Live Streaming Interface with Creator Tools
struct StreamingActivationOverlay: View {
    @State private var isHovering = false
    @State private var showingStreamSetup = false
    @State private var streamingStatus = StreamingStatus.offline
    @AppStorage("streamingMode") private var streamingMode = false
    @EnvironmentObject private var appState: AppState
    @State private var selectedPlatforms: Set<String> = []
    @State private var showingCreatorHub = false
    @State private var streamMetrics = StreamMetrics()

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                // Enhanced Status with Analytics (NN/g: Visibility of system status)
                EnhancedStatusCard(
                    status: streamingStatus,
                    streamingMode: streamingMode,
                    metrics: streamMetrics
                )

                // Primary Action with Inline Metrics (NN/g: Recognition over recall)
                StreamingActionSection(
                    streamingMode: streamingMode,
                    isHovering: isHovering,
                    onHover: { hovering in
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isHovering = hovering
                        }
                    },
                    onGoLive: streamingMode ? stopStreaming : showStreamSetup,
                    onCreatorHub: { showingCreatorHub = true },
                    metrics: streamMetrics
                )

                // Contextual Controls (NN/g: Efficiency of use)
                if !streamingMode {
                    StreamSetupSection(
                        selectedPlatforms: $selectedPlatforms,
                        onQuickStart: startQuickStream
                    )
                } else {
                    LiveStreamingControls(appState: appState, metrics: $streamMetrics)
                }
            }
        }
        .padding(.horizontal, 32)
        .padding(.vertical, 24)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(streamingMode ? Color.green.opacity(0.3) : Color.blue.opacity(0.2), lineWidth: 1)
                )
        )
        .sheet(isPresented: $showingStreamSetup) {
            EnhancedStreamSetupSheet(
                selectedPlatforms: $selectedPlatforms,
                onStartStream: { platforms in
                    startStreamWithPlatforms(platforms)
                }
            )
        }
        .sheet(isPresented: $showingCreatorHub) {
            CreatorHubSheet()
        }
    }

    private func showStreamSetup() {
        showingStreamSetup = true
    }

    private func startQuickStream() {
        if selectedPlatforms.isEmpty {
            selectedPlatforms = ["Twitch"] // Default platform
        }
        startStreamWithPlatforms(Array(selectedPlatforms))
    }

    private func startStreamWithPlatforms(_ platforms: [String]) {
        withAnimation(.spring(response: 0.8, dampingFraction: 0.7)) {
            streamingStatus = .preparing
        }

        // Simulate stream startup sequence
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.spring()) {
                streamingMode = true
                streamingStatus = .live
                appState.showStreamChat = true
                // Initialize metrics
                streamMetrics.startTime = Date()
                streamMetrics.viewers = Int.random(in: 5...25)
            }
        }
        showingStreamSetup = false
    }

    private func stopStreaming() {
        withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
            streamingMode = false
            streamingStatus = .offline
            appState.showStreamChat = false
            // Reset metrics
            streamMetrics = StreamMetrics()
        }
    }
}

/// Quick control button
struct StreamQuickButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void
    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                Text(label)
                    .font(.caption2)
                    .foregroundColor(.gray)
            }
            .frame(width: 60, height: 60)
            .background(Color.white.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.xxl)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(.plain)
        .onLongPressGesture(
            minimumDuration: 0,
            maximumDistance: .infinity,
            pressing: { pressing in
                withAnimation(.easeInOut(duration: 0.1)) {
                    isPressed = pressing
                }
            },
            perform: {}
        )
    }
}

/// Enhanced Streaming Controls Panel
public struct StreamingControlsPanel: View {
    @StateObject private var effectsProcessor = WebcamEffectsProcessor()
    @StateObject private var puppeteer = AIPuppeteer()
    @State private var expandedSection: String? = nil

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Webcam Effects Section
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedSection == "effects" },
                        set: { if $0 { expandedSection = "effects" } else { expandedSection = nil } }
                    )
                ) {
                    WebcamEffectsControl()
                        .padding(.top, 8)
                } label: {
                    Label("Webcam Effects & Filters", systemImage: "camera.filters")
                        .font(.headline)
                }

                Divider()

                // AI Puppeteer Section
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedSection == "puppeteer" },
                        set: { if $0 { expandedSection = "puppeteer" } else { expandedSection = nil } }
                    )
                ) {
                    AIPuppeteerControl()
                        .padding(.top, 8)
                } label: {
                    Label("AI Puppeteer Control", systemImage: "cpu.fill")
                        .font(.headline)
                }

                Divider()

                // AI Stream Assistant Section
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedSection == "assistant" },
                        set: { if $0 { expandedSection = "assistant" } else { expandedSection = nil } }
                    )
                ) {
                    AIControlPanel()
                        .padding(.top, 8)
                } label: {
                    Label("AI Stream Assistant", systemImage: "brain")
                        .font(.headline)
                }

                Divider()

                // Recording Settings
                DisclosureGroup(
                    isExpanded: Binding(
                        get: { expandedSection == "recording" },
                        set: { if $0 { expandedSection = "recording" } else { expandedSection = nil } }
                    )
                ) {
                    RecordingSettings()
                        .padding(.top, 8)
                } label: {
                    Label("Recording Settings", systemImage: "record.circle")
                        .font(.headline)
                }
            }
            .padding()
        }
        .frame(width: 320)
        .background(Color.black.opacity(0.9))
    }
}

/// Recording settings view
struct RecordingSettings: View {
    @AppStorage("removeBackground") private var removeBackground = false
    @AppStorage("removeBackgroundNoise") private var removeNoise = false
    @AppStorage("streamLayerOnly") private var streamLayerOnly = false
    @AppStorage("recordingQuality") private var quality = "high"

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Layer Settings")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Toggle("Stream Layer Only", isOn: $streamLayerOnly)
                .help("Records only the game and overlay, removing desktop and other windows")

            Toggle("Remove Background", isOn: $removeBackground)
                .help("Removes webcam background using AI")

            Toggle("Noise Suppression", isOn: $removeNoise)
                .help("Removes background noise from audio")

            Divider()

            Text("Quality")
                .font(.subheadline)
                .foregroundColor(.secondary)

            Picker("Recording Quality", selection: $quality) {
                Text("Low (720p)").tag("low")
                Text("Medium (1080p)").tag("medium")
                Text("High (1440p)").tag("high")
                Text("Ultra (4K)").tag("ultra")
            }
            .pickerStyle(SegmentedPickerStyle())
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - NN/g Compliant Components

/// Clear status indication following NN/g visibility principles
struct StatusIndicator: View {
    let status: StreamingStatus
    let streamingMode: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Status dot with clear visual indication
            Circle()
                .fill(status.color)
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(status.color.opacity(0.3), lineWidth: 6)
                        .scaleEffect(streamingMode ? 1.5 : 1.0)
                        .opacity(streamingMode ? 0.7 : 0.0)
                        .animation(
                            streamingMode ? .easeInOut(duration: 1.5).repeatForever(autoreverses: true) : .default,
                            value: streamingMode
                        )
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(status.title)
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Text(status.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Clear viewer count for live streams
            if streamingMode {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "eye")
                        .font(.caption)
                    Text("1,234")
                        .font(.caption.monospacedDigit())
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.green.opacity(0.1))
                .foregroundColor(.green)
                .cornerRadius(DesignSystem.Radius.lg)
            }
        }
        .padding()
        .background(.regularMaterial)
        .cornerRadius(DesignSystem.Radius.xxl)
    }
}

/// Primary action button with clear visual hierarchy
struct MainStreamingButton: View {
    let streamingMode: Bool
    let isHovering: Bool
    let onHover: (Bool) -> Void
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Clear iconography
                Image(systemName: streamingMode ? "stop.circle.fill" : "video.circle.fill")
                    .font(.system(size: 24, weight: .medium))

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(streamingMode ? "End Stream" : "Go Live")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Text(streamingMode ? "Stop broadcasting to all platforms" : "Start broadcasting your gameplay")
                        .font(.caption)
                        .opacity(0.8)
                }

                Spacer()

                // Visual affordance for action
                Image(systemName: "arrow.right.circle")
                    .font(.title3)
                    .opacity(0.6)
            }
            .padding(DesignSystem.Spacing.xl)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(streamingMode ? Color.red : Color.blue)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(.white.opacity(0.2), lineWidth: 1)
                )
        )
        .foregroundColor(.white)
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover(perform: onHover)
    }
}

/// Clear instructional text following NN/g help principles
struct InstructionalText: View {
    let streamingMode: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            if streamingMode {
                Text("Stream is live and broadcasting")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("Manage your stream settings and view analytics in real-time")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Ready to start streaming?")
                    .font(.subheadline)
                    .foregroundColor(.primary)

                Text("Select platforms and configure your stream settings below, or use Quick Start for default settings")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }
}

/// Platform selection grid with clear affordances
struct QuickSetupGrid: View {
    @Binding var selectedPlatforms: Set<String>
    let onQuickStart: () -> Void

    private let platforms = [
        PlatformOption(name: "Twitch", icon: "tv", color: .purple, isPopular: true),
        PlatformOption(name: "YouTube", icon: "play.rectangle", color: .red, isPopular: true),
        PlatformOption(name: "Facebook", icon: "person.2", color: .blue, isPopular: false),
        PlatformOption(name: "TikTok", icon: "music.note", color: .pink, isPopular: true)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("Select Platforms")
                    .font(.headline)
                    .fontWeight(.medium)
                Spacer()
                Button("Quick Start") {
                    onQuickStart()
                }
                .buttonStyle(.bordered)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                ForEach(platforms, id: \.name) { platform in
                    PlatformSelectionCard(
                        platform: platform,
                        isSelected: selectedPlatforms.contains(platform.name)
                    ) {
                        if selectedPlatforms.contains(platform.name) {
                            selectedPlatforms.remove(platform.name)
                        } else {
                            selectedPlatforms.insert(platform.name)
                        }
                    }
                }
            }
        }
    }
}

/// Live controls with clear functionality
struct LiveControlsGrid: View {
    @ObservedObject var appState: AppState
    @State private var webcamEnabled = true
    @State private var audioEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Live Controls")
                .font(.headline)
                .fontWeight(.medium)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                LiveControlCard(
                    title: "Webcam",
                    icon: "camera.fill",
                    isEnabled: webcamEnabled,
                    color: .blue
                ) {
                    webcamEnabled.toggle()
                }

                LiveControlCard(
                    title: "Audio",
                    icon: "mic.fill",
                    isEnabled: audioEnabled,
                    color: .green
                ) {
                    audioEnabled.toggle()
                }

                LiveControlCard(
                    title: "Chat",
                    icon: "message.fill",
                    isEnabled: appState.showStreamChat,
                    color: .purple
                ) {
                    appState.showStreamChat.toggle()
                }

                LiveControlCard(
                    title: "Record",
                    icon: "record.circle",
                    isEnabled: false,
                    color: .red
                ) {
                    // Toggle recording
                }
            }
        }
    }
}

/// Platform selection card with clear visual state
struct PlatformSelectionCard: View {
    let platform: PlatformOption
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: platform.icon)
                    .font(.title2)
                    .foregroundColor(platform.color)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    Text(platform.name)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if platform.isPopular {
                        Text("Popular")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Clear selection indicator
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
                    .font(.title3)
            }
            .padding(DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? platform.color.opacity(0.1) : Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isSelected ? platform.color : Color.clear, lineWidth: 2)
                )
        )
    }
}

/// Live control card with clear state indication
struct LiveControlCard: View {
    let title: String
    let icon: String
    let isEnabled: Bool
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? color : .secondary)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(isEnabled ? .primary : .secondary)

                Text(isEnabled ? "On" : "Off")
                    .font(.caption2)
                    .foregroundColor(isEnabled ? color : .secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isEnabled ? color.opacity(0.1) : Color(.controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? color : Color.clear, lineWidth: 1)
                )
        )
    }
}

/// Stream setup sheet with progressive disclosure
struct StreamSetupSheet: View {
    @Binding var selectedPlatforms: Set<String>
    let onStartStream: ([String]) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var streamTitle = ""
    @State private var streamDescription = ""
    @State private var selectedGame = "Nintendo Emulator"
    @State private var selectedCategory = "Gaming"

    var body: some View {
        NavigationView {
            Form {
                Section("Stream Details") {
                    TextField("Stream Title", text: $streamTitle)
                    TextField("Description (Optional)", text: $streamDescription, axis: .vertical)
                        .lineLimit(3...6)
                }

                Section("Game & Category") {
                    TextField("Game", text: $selectedGame)
                    TextField("Category", text: $selectedCategory)
                }

                Section("Platforms") {
                    ForEach(["Twitch", "YouTube", "Facebook", "TikTok"], id: \.self) { platform in
                        Toggle(platform, isOn: Binding(
                            get: { selectedPlatforms.contains(platform) },
                            set: { isSelected in
                                if isSelected {
                                    selectedPlatforms.insert(platform)
                                } else {
                                    selectedPlatforms.remove(platform)
                                }
                            }
                        ))
                    }
                }
            }
            .navigationTitle("Stream Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start Stream") {
                        onStartStream(Array(selectedPlatforms))
                    }
                    .disabled(selectedPlatforms.isEmpty || streamTitle.isEmpty)
                }
            }
        }
        .frame(width: 500, height: 600)
    }
}

// MARK: - Supporting Types

enum StreamingStatus {
    case offline
    case preparing
    case live

    var title: String {
        switch self {
        case .offline: return "Ready to Stream"
        case .preparing: return "Preparing Stream"
        case .live: return "Live Stream Active"
        }
    }

    var description: String {
        switch self {
        case .offline: return "Configure your stream settings and go live"
        case .preparing: return "Setting up connections and starting broadcast"
        case .live: return "Broadcasting live to selected platforms"
        }
    }

    var color: Color {
        switch self {
        case .offline: return .gray
        case .preparing: return .orange
        case .live: return .green
        }
    }
}

struct PlatformOption {
    let name: String
    let icon: String
    let color: Color
    let isPopular: Bool
}

// MARK: - Enhanced NN/g Creator Components

/// Stream metrics for real-time feedback
struct StreamMetrics {
    var viewers: Int = 0
    var likes: Int = 0
    var followers: Int = 0
    var streamDuration: TimeInterval = 0
    var startTime: Date?

    var formattedDuration: String {
        if let startTime = startTime {
            let duration = Date().timeIntervalSince(startTime)
            let hours = Int(duration) / 3600
            let minutes = (Int(duration) % 3600) / 60
            let seconds = Int(duration) % 60

            if hours > 0 {
                return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
            } else {
                return String(format: "%02d:%02d", minutes, seconds)
            }
        }
        return "00:00"
    }
}

/// Enhanced status card with streaming analytics
struct EnhancedStatusCard: View {
    let status: StreamingStatus
    let streamingMode: Bool
    let metrics: StreamMetrics

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Primary status row
            HStack(spacing: DesignSystem.Spacing.md) {
                // Status indicator with pulse animation
                Circle()
                    .fill(status.color)
                    .frame(width: 14, height: 14)
                    .overlay(
                        Circle()
                            .stroke(status.color.opacity(0.4), lineWidth: 8)
                            .scaleEffect(streamingMode ? 1.8 : 1.0)
                            .opacity(streamingMode ? 0.6 : 0.0)
                            .animation(
                                streamingMode ? .easeInOut(duration: 2.0).repeatForever(autoreverses: true) : .default,
                                value: streamingMode
                            )
                    )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(status.title)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text(status.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // Stream duration when live
            if streamingMode {
                Divider()

                HStack {
                    Label("Duration", systemImage: "clock")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(metrics.formattedDuration)
                        .font(.caption.monospacedDigit())
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}

/// Live metrics display with real-time updates
struct LiveMetricsDisplay: View {
    let metrics: StreamMetrics

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            MetricItem(
                icon: "eye.fill",
                value: "\(metrics.viewers)",
                label: "Viewers",
                color: .green
            )

            MetricItem(
                icon: "heart.fill",
                value: "\(metrics.likes)",
                label: "Likes",
                color: .red
            )

            MetricItem(
                icon: "person.badge.plus",
                value: "+\(metrics.followers)",
                label: "New",
                color: .blue
            )
        }
    }
}

struct MetricItem: View {
    let icon: String
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.caption2)
                    .foregroundColor(color)
                Text(value)
                    .font(.caption.monospacedDigit())
                    .fontWeight(.semibold)
            }
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

/// Enhanced streaming action section with inline metrics
struct StreamingActionSection: View {
    let streamingMode: Bool
    let isHovering: Bool
    let onHover: (Bool) -> Void
    let onGoLive: () -> Void
    let onCreatorHub: () -> Void
    let metrics: StreamMetrics

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Primary Go Live button
            MainStreamingButton(
                streamingMode: streamingMode,
                isHovering: isHovering,
                onHover: onHover,
                action: onGoLive
            )

            // Live metrics next to button when streaming
            if streamingMode {
                LiveMetricsDisplay(metrics: metrics)
            }
        }
    }
}

struct CreatorQuickAction: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(color.opacity(0.3), lineWidth: 1)
                )
        )
    }
}

/// Enhanced stream setup section
struct StreamSetupSection: View {
    @Binding var selectedPlatforms: Set<String>
    let onQuickStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            // Section header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Ready to Stream?")
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)

                    Text("Select platforms and configure your stream")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Quick Start") {
                    onQuickStart()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Platform selection
            QuickSetupGrid(
                selectedPlatforms: $selectedPlatforms,
                onQuickStart: onQuickStart
            )
        }
        .padding(DesignSystem.Spacing.xl)
        .background(.regularMaterial)
        .cornerRadius(16)
    }
}

/// Enhanced live streaming controls
struct LiveStreamingControls: View {
    @ObservedObject var appState: AppState
    @Binding var metrics: StreamMetrics
    @State private var webcamEnabled = true
    @State private var audioEnabled = true
    @State private var isRecording = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
            // Controls header
            HStack {
                Text("Live Controls")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)

                Spacer()

                // Quick stats
                HStack(spacing: DesignSystem.Spacing.md) {
                    StreamStatBadge(value: "\(metrics.viewers)", label: "Viewers", color: .green)
                    StreamStatBadge(value: metrics.formattedDuration, label: "Live", color: .blue)
                }
            }

            // Control grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                EnhancedControlCard(
                    title: "Camera",
                    icon: "camera.fill",
                    isEnabled: webcamEnabled,
                    color: .blue,
                    status: webcamEnabled ? "On" : "Off"
                ) {
                    webcamEnabled.toggle()
                }

                EnhancedControlCard(
                    title: "Audio",
                    icon: "mic.fill",
                    isEnabled: audioEnabled,
                    color: .green,
                    status: audioEnabled ? "Live" : "Muted"
                ) {
                    audioEnabled.toggle()
                }

                EnhancedControlCard(
                    title: "Record",
                    icon: "record.circle.fill",
                    isEnabled: isRecording,
                    color: .red,
                    status: isRecording ? "Recording" : "Standby"
                ) {
                    isRecording.toggle()
                }

                EnhancedControlCard(
                    title: "Chat",
                    icon: "message.fill",
                    isEnabled: appState.showStreamChat,
                    color: .purple,
                    status: appState.showStreamChat ? "Visible" : "Hidden"
                ) {
                    appState.showStreamChat.toggle()
                }

                EnhancedControlCard(
                    title: "Overlay",
                    icon: "rectangle.stack",
                    isEnabled: false,
                    color: .orange,
                    status: "Off"
                ) {
                    // Toggle overlay
                }

                EnhancedControlCard(
                    title: "Alerts",
                    icon: "bell.fill",
                    isEnabled: true,
                    color: .yellow,
                    status: "Active"
                ) {
                    // Toggle alerts
                }
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(.regularMaterial)
        .cornerRadius(16)
        .onReceive(Timer.publish(every: 5.0, on: .main, in: .common).autoconnect()) { _ in
            // Simulate live metrics updates
            withAnimation(.easeInOut) {
                metrics.viewers += Int.random(in: -2...5)
                metrics.viewers = max(0, metrics.viewers)

                if Int.random(in: 0...10) == 0 {
                    metrics.followers += 1
                }

                if Int.random(in: 0...5) == 0 {
                    metrics.likes += Int.random(in: 1...3)
                }
            }
        }
    }
}

struct StreamStatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.monospacedDigit())
                .fontWeight(.bold)
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.md)
    }
}

struct EnhancedControlCard: View {
    let title: String
    let icon: String
    let isEnabled: Bool
    let color: Color
    let status: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isEnabled ? color : .secondary)

                VStack(spacing: 2) {
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)

                    Text(status)
                        .font(.caption2)
                        .foregroundColor(isEnabled ? color : .secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(.regularMaterial)
                .opacity(isEnabled ? 1.0 : 0.7)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(isEnabled ? color.opacity(0.5) : Color.clear, lineWidth: 1.5)
                )
        )
    }
}

/// Enhanced stream setup sheet with better workflow
struct EnhancedStreamSetupSheet: View {
    @Binding var selectedPlatforms: Set<String>
    let onStartStream: ([String]) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var streamTitle = ""
    @State private var streamDescription = ""
    @State private var selectedGame = "Nintendo Emulator"
    @State private var selectedCategory = "Gaming"
    @State private var enableWebcam = true
    @State private var enableAudio = true
    @State private var streamQuality = "1080p"

    private let platforms = [
        ("Twitch", "tv", Color.purple),
        ("YouTube", "play.rectangle", Color.red),
        ("Facebook", "person.2", Color.blue),
        ("TikTok", "music.note", Color.pink)
    ]

    var body: some View {
        NavigationView {
            Form {
                Section("Stream Information") {
                    TextField("Stream Title", text: $streamTitle)
                        .textFieldStyle(.roundedBorder)

                    TextField("Description (Optional)", text: $streamDescription, axis: .vertical)
                        .lineLimit(2...4)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Game & Category") {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                            .foregroundColor(.blue)
                        TextField("Game", text: $selectedGame)
                            .textFieldStyle(.roundedBorder)
                    }

                    HStack {
                        Image(systemName: "tag.fill")
                            .foregroundColor(.orange)
                        TextField("Category", text: $selectedCategory)
                            .textFieldStyle(.roundedBorder)
                    }
                }

                Section("Streaming Platforms") {
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: DesignSystem.Spacing.md) {
                        ForEach(platforms, id: \.0) { platform in
                            PlatformToggleCard(
                                name: platform.0,
                                icon: platform.1,
                                color: platform.2,
                                isSelected: selectedPlatforms.contains(platform.0)
                            ) {
                                if selectedPlatforms.contains(platform.0) {
                                    selectedPlatforms.remove(platform.0)
                                } else {
                                    selectedPlatforms.insert(platform.0)
                                }
                            }
                        }
                    }
                }

                Section("Stream Settings") {
                    Toggle("Enable Webcam", isOn: $enableWebcam)
                    Toggle("Enable Audio", isOn: $enableAudio)

                    Picker("Stream Quality", selection: $streamQuality) {
                        Text("720p").tag("720p")
                        Text("1080p").tag("1080p")
                        Text("1440p").tag("1440p")
                    }
                    .pickerStyle(.segmented)
                }
            }
            .navigationTitle("Stream Setup")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Go Live") {
                        onStartStream(Array(selectedPlatforms))
                    }
                    .disabled(selectedPlatforms.isEmpty || streamTitle.isEmpty)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .frame(width: 600, height: 700)
    }
}

struct PlatformToggleCard: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(color)
                    .frame(width: 20)

                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .blue : .secondary)
            }
            .padding(DesignSystem.Spacing.md)
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(.regularMaterial)
                .opacity(isSelected ? 1.0 : 0.8)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1.5)
                )
        )
    }
}

/// Creator Hub sheet for advanced features
struct CreatorHubSheet: View {
    @Environment(\.dismiss) var dismiss
    @State private var selectedTab = 0

    var body: some View {
        NavigationView {
            TabView(selection: $selectedTab) {
                CreatorAnalytics()
                    .tabItem {
                        Label("Analytics", systemImage: "chart.bar")
                    }
                    .tag(0)

                CreatorTools()
                    .tabItem {
                        Label("Tools", systemImage: "wrench.and.screwdriver")
                    }
                    .tag(1)

                CreatorCommunity()
                    .tabItem {
                        Label("Community", systemImage: "person.2")
                    }
                    .tag(2)
            }
            .navigationTitle("Creator Hub")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 800, height: 600)
    }
}

struct CreatorAnalytics: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                Text("Stream Analytics")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Coming soon: Detailed analytics and insights for your streams")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct CreatorTools: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                Text("Creator Tools")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Coming soon: Advanced tools for content creation and stream management")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}

struct CreatorCommunity: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                Text("Community Management")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("Coming soon: Tools for managing your streaming community and audience")
                    .foregroundColor(.secondary)
            }
            .padding()
        }
    }
}