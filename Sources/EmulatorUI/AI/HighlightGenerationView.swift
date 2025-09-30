import SwiftUI
import EmulatorKit
import AVKit

/// Sprint 2 - CREATOR-001: AI Highlight Generation Interface
/// NN/g compliant UI for managing AI-generated gameplay highlights
public struct HighlightGenerationView: View {
    @StateObject private var highlightService = HighlightGenerationService()
    @State private var selectedVideoURL: URL?
    @State private var selectedGameType = GameType.n64
    @State private var generationOptions = HighlightGenerationOptions()
    @State private var showingFilePicker = false
    @State private var showingSettings = false
    @State private var showingHighlightDetail: GameplayHighlight?

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.xxl) {
                // NN/g: Clear Header with Context
                HighlightGenerationHeader()

                if highlightService.isGenerating {
                    // Generation in Progress
                    GenerationProgressSection(
                        progress: highlightService.generationProgress,
                        status: highlightService.generationStatus
                    )
                } else {
                    // Setup Section
                    VideoSelectionSection(
                        selectedVideoURL: $selectedVideoURL,
                        onSelectVideo: { showingFilePicker = true }
                    )

                    GameTypeSelectionSection(selectedGameType: $selectedGameType)

                    // Generate Button
                    GenerateHighlightsButton(
                        isEnabled: selectedVideoURL != nil && !highlightService.isGenerating,
                        onGenerate: generateHighlights
                    )
                }

                // Generated Highlights
                if !highlightService.detectedHighlights.isEmpty {
                    GeneratedHighlightsSection(
                        highlights: highlightService.detectedHighlights,
                        onHighlightTap: { showingHighlightDetail = $0 }
                    )
                }

                // Real-Time Detection Toggle
                RealTimeDetectionSection(
                    isActive: highlightService.isGenerating,
                    onToggle: toggleRealTimeDetection
                )
            }
            .padding(DesignSystem.Spacing.xxl)
        }
        .background(Color(.windowBackgroundColor))
        .navigationTitle("AI Highlights")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Settings") {
                    showingSettings = true
                }
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.movie],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                selectedVideoURL = urls.first
            case .failure(let error):
                NSLog("File selection error: \(error)")
            }
        }
        .sheet(isPresented: $showingSettings) {
            HighlightSettingsSheet(options: $generationOptions)
        }
        .sheet(item: $showingHighlightDetail) { highlight in
            HighlightDetailSheet(highlight: highlight, highlightService: highlightService)
        }
    }

    // MARK: - Actions

    private func generateHighlights() {
        guard let videoURL = selectedVideoURL else { return }

        Task {
            do {
                _ = try await highlightService.generateHighlights(
                    from: videoURL,
                    gameType: selectedGameType,
                    options: generationOptions
                )
            } catch {
                NSLog("Error generating highlights: \(error)")
            }
        }
    }

    private func toggleRealTimeDetection() {
        Task {
            do {
                if highlightService.isGenerating {
                    await highlightService.stopRealTimeHighlightDetection()
                } else {
                    try await highlightService.startRealTimeHighlightDetection(gameType: selectedGameType)
                }
            } catch {
                NSLog("Error toggling real-time detection: \(error)")
            }
        }
    }
}

// MARK: - Component Views

struct HighlightGenerationHeader: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack(spacing: DesignSystem.Spacing.lg) {
                // AI branding
                RoundedRectangle(cornerRadius: 12)
                    .fill(.purple.gradient)
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "brain")
                            .font(.title2)
                            .foregroundColor(.white)
                    )

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("AI Highlight Generation")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Automatically find the best moments in your gameplay")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Spacer()
            }

            // NN/g: Informational context
            Text("Our AI analyzes video and audio to identify exciting moments, achievements, and skillful plays. Generated highlights are perfect for sharing on social media.")
                .font(.callout)
                .foregroundColor(.secondary)
                .padding(.leading, 64)
        }
    }
}

struct VideoSelectionSection: View {
    @Binding var selectedVideoURL: URL?
    let onSelectVideo: () -> Void

    var body: some View {
        GroupBox("Video Selection") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if let videoURL = selectedVideoURL {
                    // Selected video info
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Image(systemName: "video.fill")
                            .font(.title3)
                            .foregroundColor(.blue)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(videoURL.lastPathComponent)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .lineLimit(1)

                            Text(videoURL.path)
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Button("Change") {
                            onSelectVideo()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                } else {
                    // Video selection placeholder
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "video.badge.plus")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            Text("Select Gameplay Video")
                                .font(.headline)
                                .fontWeight(.semibold)

                            Text("Choose a video file to analyze for highlights")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }

                        Button("Choose Video File") {
                            onSelectVideo()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 32)
                }
            }
            .padding()
        }
    }
}

struct GameTypeSelectionSection: View {
    @Binding var selectedGameType: GameType

    var body: some View {
        GroupBox("Game Type") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                Text("Select the type of game for optimized analysis")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Picker("Game Type", selection: $selectedGameType) {
                    ForEach(GameType.allCases, id: \.self) { gameType in
                        HStack {
                            Image(systemName: gameType.iconName)
                            Text(gameType.displayName)
                        }
                        .tag(gameType)
                    }
                }
                .pickerStyle(.segmented)
            }
            .padding()
        }
    }
}

struct GenerationProgressSection: View {
    let progress: Double
    let status: String

    var body: some View {
        GroupBox("Generating Highlights") {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Progress indicator
                VStack(spacing: DesignSystem.Spacing.md) {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)

                    HStack {
                        Text("\(Int(progress * 100))%")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        Spacer()

                        Text("Processing...")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }

                // Status message
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ProgressView()
                        .scaleEffect(0.8)

                    Text(status)
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Spacer()
                }
            }
            .padding()
        }
    }
}

struct GenerateHighlightsButton: View {
    let isEnabled: Bool
    let onGenerate: () -> Void

    var body: some View {
        Button(action: onGenerate) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "sparkles")
                    .font(.title3)

                Text("Generate Highlights")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding()
            .background(isEnabled ? .purple : .gray)
            .cornerRadius(DesignSystem.Radius.xxl)
        }
        .disabled(!isEnabled)
        .buttonStyle(.plain)
    }
}

struct GeneratedHighlightsSection: View {
    let highlights: [GameplayHighlight]
    let onHighlightTap: (GameplayHighlight) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            HStack {
                Text("Generated Highlights")
                    .font(.title3)
                    .fontWeight(.semibold)

                Spacer()

                Text("\(highlights.count) found")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.lg) {
                ForEach(highlights) { highlight in
                    HighlightCard(highlight: highlight) {
                        onHighlightTap(highlight)
                    }
                }
            }
        }
    }
}

struct HighlightCard: View {
    let highlight: GameplayHighlight
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                // Thumbnail
                AsyncImage(url: highlight.thumbnailURL) { image in
                    image
                        .resizable()
                        .aspectRatio(16/9, contentMode: .fill)
                        .clipped()
                } placeholder: {
                    Rectangle()
                        .fill(.regularMaterial)
                        .aspectRatio(16/9, contentMode: .fill)
                        .overlay(
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundColor(.secondary)
                        )
                }
                .cornerRadius(DesignSystem.Radius.lg)

                // Info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(highlight.title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)

                    HStack {
                        Label(formatDuration(highlight.duration), systemImage: "clock")
                        Spacer()
                        ConfidenceBadge(confidence: highlight.confidence)
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(.regularMaterial)
            .cornerRadius(DesignSystem.Radius.xxl)
        }
        .buttonStyle(.plain)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct ConfidenceBadge: View {
    let confidence: Double

    var body: some View {
        Text("\(Int(confidence * 100))%")
            .font(.caption2)
            .fontWeight(.semibold)
            .foregroundColor(badgeTextColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeBackgroundColor)
            .cornerRadius(DesignSystem.Radius.sm)
    }

    private var badgeBackgroundColor: Color {
        if confidence >= 0.8 {
            return .green.opacity(0.2)
        } else if confidence >= 0.6 {
            return .orange.opacity(0.2)
        } else {
            return .gray.opacity(0.2)
        }
    }

    private var badgeTextColor: Color {
        if confidence >= 0.8 {
            return .green
        } else if confidence >= 0.6 {
            return .orange
        } else {
            return .gray
        }
    }
}

struct RealTimeDetectionSection: View {
    let isActive: Bool
    let onToggle: () -> Void

    var body: some View {
        GroupBox("Real-Time Detection") {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Live Highlight Detection")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Automatically detect highlights while playing")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Toggle("", isOn: .constant(isActive))
                        .labelsHidden()
                        .onChange(of: isActive) { _ in
                            onToggle()
                        }
                }

                if isActive {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(.red)
                            .frame(width: 8, height: 8)

                        Text("Real-time detection active")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Spacer()
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Sheet Views

struct HighlightSettingsSheet: View {
    @Binding var options: HighlightGenerationOptions
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                    // General Settings
                    SettingsSection(title: "General") {
                        ToggleRow(
                            title: "Auto-save highlights",
                            description: "Automatically save generated highlights",
                            isOn: $options.autoSave
                        )

                        ToggleRow(
                            title: "Generate thumbnails",
                            description: "Create preview thumbnails for highlights",
                            isOn: $options.generateThumbnails
                        )

                        ToggleRow(
                            title: "Include audio analysis",
                            description: "Use audio cues to improve detection",
                            isOn: $options.includeAudioAnalysis
                        )
                    }

                    // Quality Settings
                    SettingsSection(title: "Quality") {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Video Quality")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Picker("Quality", selection: $options.qualityPreset) {
                                ForEach(VideoQuality.allCases, id: \.self) { quality in
                                    Text(quality.displayName).tag(quality)
                                }
                            }
                            .pickerStyle(.segmented)
                        }

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("Max Highlights: \(options.maxHighlights)")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Slider(value: Binding(
                                get: { Double(options.maxHighlights) },
                                set: { options.maxHighlights = Int($0) }
                            ), in: 1...20, step: 1)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Highlight Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)

            VStack(spacing: DesignSystem.Spacing.lg) {
                content()
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: $isOn)
                .labelsHidden()
        }
    }
}

struct HighlightDetailSheet: View {
    let highlight: GameplayHighlight
    let highlightService: HighlightGenerationService
    @Environment(\.dismiss) private var dismiss
    @State private var isExporting = false
    @State private var selectedExportFormat = HighlightExportFormat.mp4

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    // Video Player
                    VideoPlayer(player: AVPlayer(url: highlight.videoURL))
                        .aspectRatio(16/9, contentMode: .fit)
                        .cornerRadius(DesignSystem.Radius.xxl)

                    // Highlight Info
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        Text(highlight.title)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text(highlight.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        // Stats
                        HStack {
                            StatItem(label: "Duration", value: formatDuration(highlight.duration))
                            Divider()
                            StatItem(label: "Confidence", value: "\(Int(highlight.confidence * 100))%")
                            Divider()
                            StatItem(label: "Type", value: highlight.eventType.rawValue.capitalized)
                        }
                        .frame(height: 44)

                        // Tags
                        if !highlight.tags.isEmpty {
                            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                                Text("Tags")
                                    .font(.subheadline)
                                    .fontWeight(.medium)

                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.sm) {
                                    ForEach(highlight.tags, id: \.self) { tag in
                                        Text(tag)
                                            .font(.caption)
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 4)
                                            .background(.regularMaterial)
                                            .cornerRadius(DesignSystem.Radius.md)
                                    }
                                }
                            }
                        }
                    }

                    // Export Section
                    GroupBox("Export Options") {
                        VStack(spacing: DesignSystem.Spacing.lg) {
                            Picker("Format", selection: $selectedExportFormat) {
                                ForEach(HighlightExportFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue.uppercased()).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)

                            Button(action: exportHighlight) {
                                HStack {
                                    if isExporting {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    } else {
                                        Image(systemName: "square.and.arrow.up")
                                    }

                                    Text(isExporting ? "Exporting..." : "Export Highlight")
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(isExporting)
                        }
                        .padding()
                    }
                }
                .padding()
            }
            .navigationTitle("Highlight Details")
            #if !os(macOS)
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func exportHighlight() {
        isExporting = true

        Task {
            do {
                let exportedURL = try await highlightService.exportHighlight(
                    highlight,
                    format: selectedExportFormat
                )

                await MainActor.run {
                    isExporting = false
                    // Show save panel or share sheet
                    NSWorkspace.shared.activateFileViewerSelecting([exportedURL])
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    NSLog("Export error: \(error)")
                }
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)

            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Extensions

extension GameType {
    var displayName: String {
        switch self {
        case .n64: return "Nintendo 64"
        case .snes: return "Super Nintendo"
        case .generic: return "Generic Game"
        }
    }

    var iconName: String {
        switch self {
        case .n64: return "gamecontroller"
        case .snes: return "gamecontroller.fill"
        case .generic: return "desktopcomputer"
        }
    }
}

extension VideoQuality {
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .ultra: return "Ultra"
        }
    }
}

#if DEBUG
struct HighlightGenerationView_Previews: PreviewProvider {
    static var previews: some View {
        HighlightGenerationView()
    }
}
#endif
