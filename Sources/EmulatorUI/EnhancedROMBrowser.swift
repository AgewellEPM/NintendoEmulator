import SwiftUI
import EmulatorKit
import CoreInterface
import UniformTypeIdentifiers

/// NN/g-Compliant ROM Browser with Clear Navigation
/// Following principles: Visibility, Clarity, User Control, Consistency
public struct EnhancedROMBrowser: View {
    @StateObject private var romManager = ROMManager()
    @State private var selectedGame: URL?
    @State private var searchText = ""
    @State private var availableROMs: [URL] = []
    @State private var showingLaunchError: String?

    let romsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Nintendo Emulator/ROMs")

    public init() {}

    public var body: some View {
        HSplitView {
            // Left sidebar with game library
            sidebar

            // Right side - game details or empty state
            if let game = selectedGame {
                gameDetailPanel(for: game)
            } else {
                emptyState
            }
        }
        .onAppear {
            loadROMs()
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // Header with clear title
            VStack(spacing: DesignSystem.Spacing.md) {
                HStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: DesignSystem.Size.iconLarge))
                    Text("Game Library")
                        .font(DesignSystem.Typography.title2)
                    Spacer()
                }
                .padding(.horizontal, DesignSystem.Spacing.lg)

                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Search games...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                }
                .padding(.horizontal, DesignSystem.Spacing.md)
                .padding(.vertical, DesignSystem.Spacing.sm)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(DesignSystem.Radius.md)
                .padding(.horizontal, DesignSystem.Spacing.lg)
            }
            .padding(.vertical, DesignSystem.Spacing.lg)

            Divider()

            // Game list
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(filteredROMs, id: \.self) { romURL in
                        EnhancedROMRow(
                            romURL: romURL,
                            isSelected: selectedGame == romURL
                        )
                        .onTapGesture {
                            selectedGame = romURL
                        }
                    }
                }
                .padding(.vertical, DesignSystem.Spacing.sm)
            }

            Divider()

            // Footer with actions
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: { loadROMs() }) {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .font(DesignSystem.Typography.callout)
                }
                .buttonStyle(BorderlessButtonStyle())

                Spacer()

                // NN/g: Visibility of system status
                Text("\(availableROMs.count) games")
                    .font(DesignSystem.Typography.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(minWidth: 280, idealWidth: 320)
    }

    // MARK: - Game Detail Panel

    private func gameDetailPanel(for romURL: URL) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.section) {
                // Hero section
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xxl) {
                    // Cover art with gradient
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.xl)
                        .fill(coverGradient(for: romURL))
                        .frame(width: 200, height: 280)
                        .overlay(
                            VStack(spacing: DesignSystem.Spacing.md) {
                                Image(systemName: iconName(for: romURL))
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(cleanGameName(from: romURL))
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal, DesignSystem.Spacing.md)
                            }
                        )
                        .shadow(radius: DesignSystem.Shadow.large.radius)

                    // Game info and actions
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        // Title
                        Text(cleanGameName(from: romURL))
                            .font(DesignSystem.Typography.largeTitle)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        // Platform and genre tags
                        HStack(spacing: DesignSystem.Spacing.md) {
                            StatusBadge(
                                text: "Nintendo 64",
                                color: .blue,
                                icon: "gamecontroller"
                            )
                            StatusBadge(
                                text: genre(for: romURL),
                                color: .purple,
                                icon: "flag.fill"
                            )
                        }

                        // NN/g: Primary action prominently placed
                        Button(action: { playGame(romURL) }) {
                            HStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "play.fill")
                                Text("Play Game")
                            }
                            .frame(minWidth: 140)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                        }
                        .buttonStyle(BorderedProminentButtonStyle())
                        .controlSize(.large)

                        // File information
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            Text("File: \(romURL.lastPathComponent)")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)

                            if let fileSize = try? FileManager.default.attributesOfItem(atPath: romURL.path)[.size] as? Int {
                                Text("Size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))")
                                    .font(DesignSystem.Typography.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Text("Format: \(romURL.pathExtension.uppercased())")
                                .font(DesignSystem.Typography.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, DesignSystem.Spacing.md)

                        Spacer()
                    }
                    .padding(.top, DesignSystem.Spacing.sm)

                    Spacer()
                }
                .padding(DesignSystem.Spacing.xxl)

                // Game description
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("About")
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)

                    Text(gameDescription(for: romURL))
                        .font(DesignSystem.Typography.body)
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                }
                .padding(.horizontal, DesignSystem.Spacing.xxl)
                .padding(.bottom, DesignSystem.Spacing.section)
            }
        }
        .background(DesignSystem.Colors.background)
        .alert("Launch Error", isPresented: .constant(showingLaunchError != nil)) {
            Button("OK") { showingLaunchError = nil }
        } message: {
            if let error = showingLaunchError {
                Text(error)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStatePlaceholder(
            icon: "gamecontroller.fill",
            title: "Select a game to play",
            message: "Choose a game from your library to see details and start playing"
        )
    }

    // MARK: - Helpers

    var filteredROMs: [URL] {
        if searchText.isEmpty {
            return availableROMs
        }
        return availableROMs.filter {
            $0.lastPathComponent.localizedCaseInsensitiveContains(searchText)
        }
    }

    private func loadROMs() {
        do {
            // Ensure ROMs directory exists
            try? FileManager.default.createDirectory(at: romsDirectory, withIntermediateDirectories: true)

            let contents = try FileManager.default.contentsOfDirectory(
                at: romsDirectory,
                includingPropertiesForKeys: nil
            )

            availableROMs = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["n64", "z64", "v64", "rom"].contains(ext)
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            NSLog("Failed to load ROMs: \(error)")
            availableROMs = []
        }
    }

    private func playGame(_ romURL: URL) {
        // NN/g: Clear action - notify emulator to load and play
        NSLog("🎮 Enhanced ROM Browser: Playing game at \(romURL.path)")
        NotificationCenter.default.post(
            name: .emulatorOpenROM,
            object: romURL
        )
    }

    // MARK: - Game Metadata

    private func cleanGameName(from url: URL) -> String {
        var name = url.deletingPathExtension().lastPathComponent
        // Remove common ROM tags
        name = name.replacingOccurrences(of: " (USA)", with: "")
        name = name.replacingOccurrences(of: " (E)", with: "")
        name = name.replacingOccurrences(of: " [!]", with: "")
        name = name.replacingOccurrences(of: " (Europe)", with: "")
        name = name.replacingOccurrences(of: " (Japan)", with: "")
        return name
    }

    private func genre(for url: URL) -> String {
        let name = cleanGameName(from: url)
        if name.contains("Duke Nukem") { return "Shooter" }
        if name.contains("GoldenEye") { return "FPS" }
        if name.contains("Conker") { return "Platform" }
        if name.contains("Mario") { return "Platform" }
        if name.contains("Zelda") { return "Adventure" }
        return "Action"
    }

    private func iconName(for url: URL) -> String {
        let name = cleanGameName(from: url)
        if name.contains("Duke Nukem") { return "figure.walk.motion" }
        if name.contains("GoldenEye") { return "scope" }
        if name.contains("Conker") { return "hare.fill" }
        if name.contains("Mario") { return "star.fill" }
        if name.contains("Zelda") { return "sparkles" }
        return "gamecontroller.fill"
    }

    private func coverGradient(for url: URL) -> LinearGradient {
        let name = cleanGameName(from: url)
        if name.contains("Duke Nukem") {
            return LinearGradient(
                colors: [.red, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        if name.contains("GoldenEye") {
            return LinearGradient(
                colors: [.yellow, .orange],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        if name.contains("Conker") {
            return LinearGradient(
                colors: [.purple, .pink],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
        return LinearGradient(
            colors: [.blue, .purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func gameDescription(for url: URL) -> String {
        let name = cleanGameName(from: url)

        if name.contains("Duke Nukem") {
            return "Duke Nukem: Zero Hour is a third-person shooter where Duke battles through different time periods to stop alien invaders from altering history. Features intense combat and Duke's signature one-liners. Use your Switch controller or keyboard to navigate levels and defeat enemies."
        }
        if name.contains("GoldenEye") {
            return "GoldenEye 007 revolutionized console FPS gaming. Play as James Bond in this faithful adaptation of the movie, featuring stealth missions and legendary split-screen multiplayer. Experience the iconic levels and weapons that defined a generation of gaming."
        }
        if name.contains("Conker") {
            return "Conker's Bad Fur Day is a mature-rated platformer featuring a foul-mouthed squirrel. Known for its adult humor, pop culture parodies, and innovative gameplay. This Rare gem pushes the N64 to its limits with stunning visuals and voice acting."
        }

        return "A classic Nintendo 64 game ready to play. Select 'Play Game' to launch the emulator and start your adventure. Your controller and save states are ready to go."
    }
}

// MARK: - Enhanced ROM Row

struct EnhancedROMRow: View {
    let romURL: URL
    let isSelected: Bool

    var cleanGameName: String {
        var name = romURL.deletingPathExtension().lastPathComponent
        name = name.replacingOccurrences(of: " (USA)", with: "")
        name = name.replacingOccurrences(of: " (E)", with: "")
        name = name.replacingOccurrences(of: " [!]", with: "")
        return name
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Game icon with themed color
            RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                .fill(iconColor.opacity(0.2))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: iconName)
                        .font(.system(size: DesignSystem.Size.iconMedium))
                        .foregroundStyle(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(cleanGameName)
                    .font(DesignSystem.Typography.callout)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .lineLimit(1)
                    .foregroundColor(isSelected ? DesignSystem.Colors.primary : DesignSystem.Colors.textPrimary)

                Text(romURL.pathExtension.uppercased())
                    .font(DesignSystem.Typography.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.primary)
            }
        }
        .padding(.horizontal, DesignSystem.Spacing.md)
        .padding(.vertical, DesignSystem.Spacing.sm)
        .background(isSelected ? DesignSystem.Colors.primary.opacity(0.1) : Color.clear)
        .cornerRadius(DesignSystem.Radius.sm)
        .contentShape(Rectangle())
    }

    var iconColor: Color {
        if cleanGameName.contains("Duke Nukem") { return .red }
        if cleanGameName.contains("GoldenEye") { return .orange }
        if cleanGameName.contains("Conker") { return .purple }
        if cleanGameName.contains("Mario") { return .red }
        if cleanGameName.contains("Zelda") { return .green }
        return .blue
    }

    var iconName: String {
        if cleanGameName.contains("Duke Nukem") { return "figure.walk.motion" }
        if cleanGameName.contains("GoldenEye") { return "scope" }
        if cleanGameName.contains("Conker") { return "hare.fill" }
        if cleanGameName.contains("Mario") { return "star.fill" }
        if cleanGameName.contains("Zelda") { return "sparkles" }
        return "gamecontroller.fill"
    }
}