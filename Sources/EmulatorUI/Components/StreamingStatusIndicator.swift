import SwiftUI
import EmulatorKit

/// Lightweight status pill for streaming state
struct StreamingStatusIndicator: View {
    @StateObject private var streamingManager = StreamingManager()

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(statusColor)
                .frame(width: 8, height: 8)

            Text(statusText)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.md)
        .accessibilityLabel("Streaming Status: \(statusText)")
    }

    private var statusText: String {
        switch streamingManager.streamStatus {
        case .live: return "Live"
        case .connected: return "Connected"
        case .disconnected: return "Offline"
        case .error: return "Error"
        }
    }

    private var statusColor: Color {
        switch streamingManager.streamStatus {
        case .live: return .red
        case .connected: return .green
        case .disconnected: return .gray
        case .error: return .orange
        }
    }
}
