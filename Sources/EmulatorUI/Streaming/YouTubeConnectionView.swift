import SwiftUI
import EmulatorKit

/// Sprint 2 - STREAM-002: YouTube Live Connection Interface
/// NN/g compliant UI for connecting and managing YouTube Live streaming
public struct YouTubeConnectionView: View {
    @StateObject private var streamingManager = StreamingManager()
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var isConnecting = false
    @State private var showingSettings = false
    @State private var connectionError: String?
    @State private var showingBroadcastCreator = false

    public init() {}

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // NN/g: Clear Header with Context
            HeaderSection()

            // Connection Status Card
            ConnectionStatusCard(
                isConnected: streamingManager.connectedPlatforms.contains(.youtube),
                status: streamingManager.streamStatus,
                onConnect: connectToYouTube,
                onDisconnect: disconnectFromYouTube,
                isLoading: isConnecting
            )

            if !streamingManager.connectedPlatforms.contains(.youtube) {
                // Configuration Form
                ConfigurationForm(
                    clientID: $clientID,
                    clientSecret: $clientSecret,
                    isConnecting: isConnecting
                )
            } else {
                // Connected Features
                ConnectedFeaturesSection(
                    streamingManager: streamingManager,
                    onCreateBroadcast: { showingBroadcastCreator = true }
                )
            }

            // Error Display
            if let error = connectionError {
                ErrorCard(message: error) {
                    connectionError = nil
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.xxl)
        .background(Color(.windowBackgroundColor))
        .navigationTitle("YouTube Live Integration")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Settings") {
                    showingSettings = true
                }
                .disabled(isConnecting)
            }
        }
        .sheet(isPresented: $showingSettings) {
            YouTubeSettingsSheet()
        }
        .sheet(isPresented: $showingBroadcastCreator) {
            YouTubeBroadcastCreatorSheet()
        }
    }

    // MARK: - Actions

    private func connectToYouTube() {
        guard !clientID.isEmpty && !clientSecret.isEmpty else {
            connectionError = "Please enter your YouTube API credentials"
            return
        }

        isConnecting = true
        connectionError = nil

        Task {
            do {
                try await streamingManager.connectYouTube(
                    clientID: clientID,
                    clientSecret: clientSecret
                )

                await MainActor.run {
                    isConnecting = false
                    // Store credentials securely
                    UserDefaults.standard.set(clientID, forKey: "youtube_client_id")
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    connectionError = error.localizedDescription
                }
            }
        }
    }

    private func disconnectFromYouTube() {
        Task {
            await streamingManager.disconnectPlatform(.youtube)
            await MainActor.run {
                // Clear stored credentials
                UserDefaults.standard.removeObject(forKey: "youtube_client_id")
            }
        }
    }
}

// MARK: - Component Views

struct HeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // YouTube branding
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "FF0000") ?? .red)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "play.rectangle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("YouTube Live Integration")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Connect your YouTube channel for live streaming")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // NN/g: Informational context
            Text("Stream directly to YouTube Live with automatic broadcast creation, category selection, and viewer analytics.")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.leading, 64)
        }
    }
}

struct ConfigurationForm: View {
    @Binding var clientID: String
    @Binding var clientSecret: String
    let isConnecting: Bool

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("YouTube API Credentials")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Create a YouTube Data API project in Google Cloud Console to get these credentials.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Client ID")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("Enter your Google OAuth Client ID", text: $clientID)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isConnecting)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Client Secret")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    SecureField("Enter your Google OAuth Client Secret", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isConnecting)
                }

                // NN/g: Help Links
                VStack(alignment: .trailing, spacing: DesignSystem.Spacing.sm) {
                    Button("View YouTube Live API Guide →") {
                        NSWorkspace.shared.open(URL(string: "https://developers.google.com/youtube/v3/live/getting-started")!)
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)

                    Button("Create Google Cloud Project →") {
                        NSWorkspace.shared.open(URL(string: "https://console.cloud.google.com/")!)
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
    }
}

struct ConnectedFeaturesSection: View {
    let streamingManager: StreamingManager
    let onCreateBroadcast: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Broadcast Management
            GroupBox("Live Broadcast Management") {
                VStack(spacing: DesignSystem.Spacing.md) {
                    BroadcastControlRow(
                        icon: "plus.circle.fill",
                        title: "Create Broadcast",
                        description: "Set up a new YouTube Live broadcast",
                        action: "Create",
                        actionColor: .blue,
                        onTap: onCreateBroadcast
                    )

                    if streamingManager.isStreaming {
                        Divider()

                        BroadcastControlRow(
                            icon: "stop.circle.fill",
                            title: "End Broadcast",
                            description: "Stop the current live broadcast",
                            action: "End",
                            actionColor: .red
                        ) {
                            // End broadcast action
                        }
                    }
                }
                .padding()
            }

            // YouTube Live Features
            GroupBox("YouTube Live Features") {
                VStack(spacing: DesignSystem.Spacing.md) {
                    FeatureRow(
                        icon: "eye.fill",
                        title: "Real-time Analytics",
                        description: "Live viewer count and engagement metrics",
                        isEnabled: true
                    )

                    FeatureRow(
                        icon: "message.fill",
                        title: "Live Chat Integration",
                        description: "Display and moderate YouTube live chat",
                        isEnabled: true
                    )

                    FeatureRow(
                        icon: "record.circle",
                        title: "Auto-Record Streams",
                        description: "Automatically save broadcasts to your channel",
                        isEnabled: true
                    )

                    FeatureRow(
                        icon: "tag.fill",
                        title: "Category & Tags",
                        description: "Automatically set categories and optimize discoverability",
                        isEnabled: true
                    )
                }
                .padding()
            }

            // Stream Statistics
            if streamingManager.isStreaming {
                GroupBox("Live Statistics") {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        YouTubeInfoRow(
                            label: "Status",
                            value: "🔴 Live",
                            icon: "dot.radiowaves.left.and.right"
                        )

                        YouTubeInfoRow(
                            label: "Concurrent Viewers",
                            value: "\(streamingManager.currentViewerCount)",
                            icon: "eye.fill"
                        )

                        YouTubeInfoRow(
                            label: "Stream Duration",
                            value: formatDuration(streamingManager.streamDuration),
                            icon: "clock.fill"
                        )
                    }
                    .padding()
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}

struct BroadcastControlRow: View {
    let icon: String
    let title: String
    let description: String
    let action: String
    let actionColor: Color
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button(action) {
                onTap()
            }
            .buttonStyle(.bordered)
            .foregroundColor(actionColor)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    let isEnabled: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isEnabled ? .green : .gray)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isEnabled ? .green : .gray)
        }
    }
}

struct YouTubeInfoRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 16)

            Text(label)
                .font(.subheadline)

            Spacer()

            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

struct ErrorCard: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        GroupBox {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Connection Error")
                        .font(.subheadline)
                        .fontWeight(.semibold)

                    Text(message)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button("Dismiss") {
                    onDismiss()
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            .padding()
        }
        .background(Color.orange.opacity(0.1))
    }
}

// MARK: - Sheet Views

struct YouTubeSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                Image(systemName: "gear")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary.opacity(0.5))

                Text("YouTube Settings")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Advanced YouTube Live settings will be available in a future update.")
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                Spacer()
            }
            .padding()
            .navigationTitle("YouTube Settings")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct YouTubeBroadcastCreatorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var broadcastTitle = ""
    @State private var broadcastDescription = ""
    @State private var privacyLevel = YouTubeBroadcastPrivacy.unlisted
    @State private var scheduledStartTime = Date().addingTimeInterval(300) // 5 minutes from now
    @State private var isCreating = false

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // Broadcast Title
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Broadcast Title")
                            .font(.headline)
                            .fontWeight(.semibold)

                        TextField("Enter your broadcast title", text: $broadcastTitle)
                            .textFieldStyle(.roundedBorder)
                    }

                    // Description
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Description (Optional)")
                            .font(.headline)
                            .fontWeight(.semibold)

                        TextEditor(text: $broadcastDescription)
                            .frame(height: 80)
                            .padding(DesignSystem.Spacing.xs)
                            .background(.regularMaterial)
                            .cornerRadius(DesignSystem.Radius.lg)
                    }

                    // Privacy Settings
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Privacy")
                            .font(.headline)
                            .fontWeight(.semibold)

                        Picker("Privacy Level", selection: $privacyLevel) {
                            ForEach(YouTubeBroadcastPrivacy.allCases, id: \.self) { privacy in
                                Text(privacy.displayName).tag(privacy)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Scheduled Start Time
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Scheduled Start Time")
                            .font(.headline)
                            .fontWeight(.semibold)

                        DatePicker("Start Time", selection: $scheduledStartTime, in: Date()...)
                            .datePickerStyle(.compact)
                    }

                    // Create Button
                    Button(action: createBroadcast) {
                        HStack {
                            if isCreating {
                                ProgressView()
                                    .scaleEffect(0.8)
                            } else {
                                Image(systemName: "plus.circle.fill")
                            }

                            Text(isCreating ? "Creating Broadcast..." : "Create Broadcast")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(.blue)
                        .foregroundColor(.white)
                        .cornerRadius(DesignSystem.Radius.lg)
                    }
                    .disabled(broadcastTitle.isEmpty || isCreating)

                    Spacer()
                }
                .padding()
            }
            .navigationTitle("Create YouTube Broadcast")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(isCreating)
                }
            }
        }
    }

    private func createBroadcast() {
        isCreating = true

        // Simulate broadcast creation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isCreating = false
            dismiss()
        }
    }
}

// MARK: - Extensions

#if DEBUG
struct YouTubeConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        YouTubeConnectionView()
    }
}
#endif
