import SwiftUI
import EmulatorKit

/// Sprint 2 - STREAM-001: Twitch Connection Interface
/// NN/g compliant UI for connecting and managing Twitch streaming
public struct TwitchConnectionView: View {
    @StateObject private var streamingManager = StreamingManager()
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var isConnecting = false
    @State private var showingSettings = false
    @State private var connectionError: String?

    public init() {}

    public var body: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            // NN/g: Clear Header with Context
            TwitchHeaderSection()

            // Connection Status Card
            ConnectionStatusCard(
                isConnected: streamingManager.connectedPlatforms.contains(.twitch),
                status: streamingManager.streamStatus,
                onConnect: connectToTwitch,
                onDisconnect: disconnectFromTwitch,
                isLoading: isConnecting
            )

            if !streamingManager.connectedPlatforms.contains(.twitch) {
                // Configuration Form
                TwitchConfigurationForm(
                    clientID: $clientID,
                    clientSecret: $clientSecret,
                    isConnecting: isConnecting
                )
            } else {
                // Connected Features
                TwitchConnectedFeaturesSection(streamingManager: streamingManager)
            }

            // Error Display
            if let error = connectionError {
                TwitchErrorCard(message: error) {
                    connectionError = nil
                }
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.xxl)
        .background(Color(.windowBackgroundColor))
        .navigationTitle("Twitch Integration")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Settings") {
                    showingSettings = true
                }
                .disabled(isConnecting)
            }
        }
        .sheet(isPresented: $showingSettings) {
            TwitchSettingsSheet()
        }
    }

    // MARK: - Actions

    private func connectToTwitch() {
        guard !clientID.isEmpty && !clientSecret.isEmpty else {
            connectionError = "Please enter your Twitch Client ID and Client Secret"
            return
        }

        isConnecting = true
        connectionError = nil

        Task {
            do {
                try await streamingManager.connectTwitch(
                    clientID: clientID,
                    clientSecret: clientSecret
                )

                await MainActor.run {
                    isConnecting = false
                    // Store credentials securely
                    UserDefaults.standard.set(clientID, forKey: "twitch_client_id")
                }
            } catch {
                await MainActor.run {
                    isConnecting = false
                    connectionError = error.localizedDescription
                }
            }
        }
    }

    private func disconnectFromTwitch() {
        Task {
            await streamingManager.disconnectPlatform(.twitch)
            await MainActor.run {
                // Clear stored credentials
                UserDefaults.standard.removeObject(forKey: "twitch_client_id")
            }
        }
    }
}

// MARK: - Component Views

struct TwitchHeaderSection: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Twitch branding
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(hex: "9146FF") ?? Color.purple)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "tv.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Twitch Integration")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Connect your Twitch account for direct streaming")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // NN/g: Informational context
            Text("Stream directly to your Twitch channel with automatic title updates, category selection, and viewer count tracking.")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.leading, 64)
        }
    }
}

struct ConnectionStatusCard: View {
    let isConnected: Bool
    let status: StreamStatus
    let onConnect: () -> Void
    let onDisconnect: () -> Void
    let isLoading: Bool

    var body: some View {
        GroupBox {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // Status Indicator
                TwitchStatusIndicator(
                    isConnected: isConnected,
                    status: status,
                    isLoading: isLoading
                )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text(isConnected ? "Connected to Twitch" : "Not Connected")
                        .font(.headline)
                        .fontWeight(.semibold)

                    Text(statusDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Action Button
                Button(action: isConnected ? onDisconnect : onConnect) {
                    Text(isConnected ? "Disconnect" : "Connect")
                        .fontWeight(.medium)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isLoading)
            }
            .padding()
        }
    }

    private var statusDescription: String {
        if isLoading {
            return "Connecting to Twitch..."
        } else if isConnected {
            return "Ready to stream to your Twitch channel"
        } else {
            return "Configure your credentials below to connect"
        }
    }
}

struct TwitchStatusIndicator: View {
    let isConnected: Bool
    let status: StreamStatus
    let isLoading: Bool

    var body: some View {
        ZStack {
            Circle()
                .fill(indicatorColor.opacity(0.2))
                .frame(width: 48, height: 48)

            if isLoading {
                ProgressView()
                    .scaleEffect(0.8)
            } else {
                Image(systemName: indicatorIcon)
                    .font(.title3)
                    .foregroundColor(indicatorColor)
            }
        }
    }

    private var indicatorColor: Color {
        if isLoading {
            return .blue
        } else if isConnected {
            return status == .live ? .red : .green
        } else {
            return .gray
        }
    }

    private var indicatorIcon: String {
        if isConnected {
            return status == .live ? "dot.radiowaves.left.and.right" : "checkmark.circle.fill"
        } else {
            return "wifi.slash"
        }
    }
}

struct TwitchConfigurationForm: View {
    @Binding var clientID: String
    @Binding var clientSecret: String
    let isConnecting: Bool

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Twitch Application Credentials")
                    .font(.headline)
                    .fontWeight(.semibold)

                Text("Create a Twitch application at dev.twitch.tv to get these credentials.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Client ID")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    TextField("Enter your Twitch Client ID", text: $clientID)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isConnecting)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Client Secret")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    SecureField("Enter your Twitch Client Secret", text: $clientSecret)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isConnecting)
                }

                // NN/g: Help Link
                HStack {
                    Spacer()
                    Button("Need help? View Twitch Developer Guide →") {
                        NSWorkspace.shared.open(URL(string: "https://dev.twitch.tv/docs/api/")!)
                    }
                    .font(.caption)
                    .foregroundColor(.accentColor)
                }
            }
            .padding()
        }
    }
}

struct TwitchConnectedFeaturesSection: View {
    let streamingManager: StreamingManager

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Stream Controls
            GroupBox("Stream Controls") {
                VStack(spacing: DesignSystem.Spacing.md) {
                    StreamControlRow(
                        icon: "play.circle.fill",
                        title: "Start Stream",
                        description: "Begin streaming to Twitch",
                        action: "Start",
                        actionColor: .green
                    ) {
                        // Start stream action
                    }

                    Divider()

                    StreamControlRow(
                        icon: "square.fill",
                        title: "Stop Stream",
                        description: "End current stream",
                        action: "Stop",
                        actionColor: .red
                    ) {
                        // Stop stream action
                    }
                }
                .padding()
            }

            // Stream Info
            GroupBox("Stream Information") {
                VStack(spacing: DesignSystem.Spacing.md) {
                    TwitchInfoRow(
                        label: "Status",
                        value: streamingManager.streamStatus.displayName,
                        icon: streamingManager.streamStatus.iconName
                    )

                    TwitchInfoRow(
                        label: "Viewers",
                        value: "\(streamingManager.currentViewerCount)",
                        icon: "eye.fill"
                    )

                    if streamingManager.isStreaming {
                        TwitchInfoRow(
                            label: "Duration",
                            value: formatDuration(streamingManager.streamDuration),
                            icon: "clock.fill"
                        )
                    }
                }
                .padding()
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

struct StreamControlRow: View {
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

struct TwitchInfoRow: View {
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

struct TwitchErrorCard: View {
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

// MARK: - Settings Sheet

struct TwitchSettingsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                Text("Coming Soon")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Advanced Twitch settings will be available in a future update.")
                    .foregroundColor(.secondary)

                Spacer()
            }
            .padding()
            .navigationTitle("Twitch Settings")
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


#if DEBUG
struct TwitchConnectionView_Previews: PreviewProvider {
    static var previews: some View {
        TwitchConnectionView()
    }
}
#endif