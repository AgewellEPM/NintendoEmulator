import SwiftUI
import EmulatorKit
import CoreInterface
import UniformTypeIdentifiers

/// ROM Browser that shows actual ROM files from disk
public struct RealROMBrowser: View {
    @StateObject private var romManager = ROMManager()
    @State private var selectedGame: URL?
    @State private var searchText = ""
    @State private var showingImporter = false
    @State private var availableROMs: [URL] = []

    let romsDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Documents/Nintendo Emulator/ROMs")

    public init() {}

    public var body: some View {
        HSplitView {
            // Left sidebar with actual game list
            VStack(spacing: 0) {
                // Header
                VStack(spacing: DesignSystem.Spacing.md) {
                    HStack {
                        Image(systemName: "gamecontroller.fill")
                        Text("Nintendo 64 Games")
                        Spacer()
                    }
                    .font(.headline)
                    .padding(.horizontal)

                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("Search games...", text: $searchText)
                            .textFieldStyle(PlainTextFieldStyle())
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(DesignSystem.Radius.lg)
                    .padding(.horizontal)
                }
                .padding(.vertical)

                Divider()

                // Actual ROM list
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(filteredROMs, id: \.self) { romURL in
                            ROMFileRowView(
                                romURL: romURL,
                                isSelected: selectedGame == romURL
                            )
                            .onTapGesture {
                                selectedGame = romURL
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Divider()

                // Bottom toolbar
                HStack {
                    Button(action: { loadROMs() }) {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Spacer()

                    Text("\(availableROMs.count) games")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 280, idealWidth: 320)
            .onAppear { loadROMs() }

            // Right side - game details
            if let game = selectedGame {
                ActualGameDetailView(romURL: game)
            } else {
                VStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.quaternary)
                    Text("Select a game to play")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
    }

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
            let contents = try FileManager.default.contentsOfDirectory(
                at: romsDirectory,
                includingPropertiesForKeys: nil
            )

            availableROMs = contents.filter { url in
                let ext = url.pathExtension.lowercased()
                return ["n64", "z64", "v64", "rom"].contains(ext)
            }.sorted { $0.lastPathComponent < $1.lastPathComponent }
        } catch {
            print("Failed to load ROMs: \(error)")
            availableROMs = []
        }
    }
}

struct ROMFileRowView: View {
    let romURL: URL
    let isSelected: Bool

    var cleanGameName: String {
        var name = romURL.deletingPathExtension().lastPathComponent
        // Remove common ROM tags
        name = name.replacingOccurrences(of: " (USA)", with: "")
        name = name.replacingOccurrences(of: " (E)", with: "")
        name = name.replacingOccurrences(of: " [!]", with: "")
        return name
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Game icon
            RoundedRectangle(cornerRadius: 6)
                .fill(iconColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: iconName)
                        .foregroundStyle(iconColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(cleanGameName)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text(romURL.pathExtension.uppercased())
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }

    var iconColor: Color {
        if cleanGameName.contains("Duke Nukem") { return .red }
        if cleanGameName.contains("GoldenEye") { return .orange }
        if cleanGameName.contains("Conker") { return .purple }
        return .blue
    }

    var iconName: String {
        if cleanGameName.contains("Duke Nukem") { return "figure.walk.motion" }
        if cleanGameName.contains("GoldenEye") { return "scope" }
        if cleanGameName.contains("Conker") { return "hare.fill" }
        return "gamecontroller.fill"
    }
}

struct ActualGameDetailView: View {
    let romURL: URL

    var cleanGameName: String {
        var name = romURL.deletingPathExtension().lastPathComponent
        name = name.replacingOccurrences(of: " (USA)", with: "")
        name = name.replacingOccurrences(of: " (E)", with: "")
        name = name.replacingOccurrences(of: " [!]", with: "")
        return name
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                // Game header
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                    // Cover art
                    RoundedRectangle(cornerRadius: 10)
                        .fill(coverGradient)
                        .frame(width: 200, height: 280)
                        .overlay(
                            VStack {
                                Image(systemName: iconName)
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(cleanGameName)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        )

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        Text(cleanGameName)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        HStack(spacing: DesignSystem.Spacing.lg) {
                            Label("Nintendo 64", systemImage: "gamecontroller")
                            Label(genre, systemImage: "flag.fill")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)

                        // Play button
                        Button(action: playGame) {
                            Label("Play Game", systemImage: "play.fill")
                                .frame(width: 120)
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)

                        // File info
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("File: \(romURL.lastPathComponent)")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            if let fileSize = try? FileManager.default.attributesOfItem(atPath: romURL.path)[.size] as? Int {
                                Text("Size: \(ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer()
                    }

                    Spacer()
                }
                .padding()

                // Game description
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    Text("About")
                        .font(.headline)

                    Text(gameDescription)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func playGame() {
        // Launch the game using mupen64plus
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/opt/homebrew/bin/mupen64plus")
        process.arguments = [
            "--windowed",
            "--resolution", "800x600",
            "--gfx", "mupen64plus-video-glide64mk2",
            "--audio", "mupen64plus-audio-sdl",
            "--input", "mupen64plus-input-sdl",
            "--rsp", "mupen64plus-rsp-hle",
            romURL.path
        ]

        process.standardOutput = Pipe()
        process.standardError = Pipe()

        do {
            try process.run()
            print("Launched game: \(cleanGameName)")
        } catch {
            print("Failed to launch game: \(error)")
            // Try simpler launch
            let simpleProcess = Process()
            simpleProcess.launchPath = "/opt/homebrew/bin/mupen64plus"
            simpleProcess.arguments = [romURL.path]
            simpleProcess.launch()
        }
    }

    var genre: String {
        if cleanGameName.contains("Duke Nukem") { return "Shooter" }
        if cleanGameName.contains("GoldenEye") { return "FPS" }
        if cleanGameName.contains("Conker") { return "Platform" }
        return "Action"
    }

    var iconName: String {
        if cleanGameName.contains("Duke Nukem") { return "figure.walk.motion" }
        if cleanGameName.contains("GoldenEye") { return "scope" }
        if cleanGameName.contains("Conker") { return "hare.fill" }
        return "gamecontroller.fill"
    }

    var coverGradient: LinearGradient {
        if cleanGameName.contains("Duke Nukem") {
            return LinearGradient(colors: [.red, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if cleanGameName.contains("GoldenEye") {
            return LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        if cleanGameName.contains("Conker") {
            return LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing)
        }
        return LinearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var gameDescription: String {
        if cleanGameName.contains("Duke Nukem") {
            return "Duke Nukem: Zero Hour is a third-person shooter where Duke battles through different time periods to stop alien invaders from altering history. Features intense combat and Duke's signature one-liners."
        }
        if cleanGameName.contains("GoldenEye") {
            return "GoldenEye 007 revolutionized console FPS gaming. Play as James Bond in this faithful adaptation of the movie, featuring stealth missions and legendary split-screen multiplayer."
        }
        if cleanGameName.contains("Conker") {
            return "Conker's Bad Fur Day is a mature-rated platformer featuring a foul-mouthed squirrel. Known for its adult humor, pop culture parodies, and innovative gameplay."
        }
        return "A classic Nintendo 64 game ready to play."
    }
}