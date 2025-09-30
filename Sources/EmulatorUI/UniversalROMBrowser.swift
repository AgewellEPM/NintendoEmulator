import SwiftUI
import EmulatorKit
import CoreInterface
import UniformTypeIdentifiers

/// Universal ROM Browser that shows actual game library
public struct UniversalROMBrowser: View {
    @StateObject private var romManager = ROMManager()
    @State private var selectedSystem: String = "Nintendo 64"
    @State private var searchText = ""
    @State private var selectedGame: ROMMetadata?
    @State private var showingImporter = false

    // Sample N64 games for testing
    let sampleGames = [
        ("Duke Nukem: Zero Hour", "Action/Shooter", "1999"),
        ("Super Mario 64", "Platform", "1996"),
        ("GoldenEye 007", "FPS", "1997"),
        ("The Legend of Zelda: Ocarina of Time", "Adventure", "1998"),
        ("Mario Kart 64", "Racing", "1996"),
        ("Star Fox 64", "Shooter", "1997"),
        ("Perfect Dark", "FPS", "2000"),
        ("Banjo-Kazooie", "Platform", "1998"),
        ("F-Zero X", "Racing", "1998"),
        ("Super Smash Bros.", "Fighting", "1999")
    ]

    public init() {}

    public var body: some View {
        HSplitView {
            // Left sidebar with game list
            VStack(spacing: 0) {
                // System selector and search
                VStack(spacing: DesignSystem.Spacing.md) {
                    Menu {
                        Button("Nintendo 64") { selectedSystem = "Nintendo 64" }
                        Button("GameCube") { selectedSystem = "GameCube" }
                        Button("SNES") { selectedSystem = "SNES" }
                        Button("NES") { selectedSystem = "NES" }
                    } label: {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                            Text(selectedSystem)
                            Spacer()
                            Image(systemName: "chevron.down")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(DesignSystem.Radius.lg)
                    }

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
                }
                .padding()

                Divider()

                // Game list
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(filteredGames, id: \.0) { game in
                            GameRowView(
                                title: game.0,
                                genre: game.1,
                                year: game.2,
                                isSelected: selectedGame?.title == game.0
                            )
                            .onTapGesture {
                                selectedGame = ROMMetadata(
                                    path: URL(fileURLWithPath: "/Games/\(game.0).n64"),
                                    system: .n64,
                                    title: game.0,
                                    region: "USA",
                                    checksum: "",
                                    size: 32000000,
                                    header: nil
                                )
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                Divider()

                // Bottom toolbar
                HStack {
                    Button(action: { showingImporter = true }) {
                        Label("Import", systemImage: "plus.circle")
                    }
                    .buttonStyle(BorderlessButtonStyle())

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(minWidth: 280, idealWidth: 320)

            // Right side - game details
            if let game = selectedGame {
                GameDetailView(game: game)
            } else {
                VStack {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.quaternary)
                    Text("Select a game to view details")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(NSColor.controlBackgroundColor))
            }
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [.item],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
    }

    var filteredGames: [(String, String, String)] {
        if searchText.isEmpty {
            return sampleGames
        }
        return sampleGames.filter { $0.0.localizedCaseInsensitiveContains(searchText) }
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(_):
            Task {
                await romManager.loadROMs()
            }
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }
}

struct GameRowView: View {
    let title: String
    let genre: String
    let year: String
    let isSelected: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Game icon placeholder
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.accentColor.opacity(0.2))
                .frame(width: 40, height: 40)
                .overlay(
                    Image(systemName: "gamecontroller.fill")
                        .foregroundStyle(Color.accentColor)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Text("\(genre) • \(year)")
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
}

struct GameDetailView: View {
    let game: ROMMetadata

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                // Game header
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                    // Cover art placeholder
                    RoundedRectangle(cornerRadius: 10)
                        .fill(LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                        .frame(width: 200, height: 280)
                        .overlay(
                            VStack {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 50))
                                    .foregroundStyle(.white.opacity(0.8))
                                Text(game.title)
                                    .font(.caption)
                                    .foregroundStyle(.white)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                            }
                        )

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        Text(game.title)
                            .font(.largeTitle)
                            .fontWeight(.bold)

                        HStack(spacing: DesignSystem.Spacing.lg) {
                            Label("Nintendo 64", systemImage: "gamecontroller")
                            Label("Action", systemImage: "flag.fill")
                        }
                        .font(.callout)
                        .foregroundStyle(.secondary)

                        // Action buttons
                        HStack(spacing: DesignSystem.Spacing.md) {
                            Button(action: {
                                NotificationCenter.default.post(
                                    name: .startGameWithROM,
                                    object: game
                                )
                            }) {
                                Label("Play", systemImage: "play.fill")
                                    .frame(width: 100)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            Button(action: {}) {
                                Image(systemName: "heart")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)

                            Button(action: {}) {
                                Image(systemName: "ellipsis")
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                        }

                        Spacer()
                    }

                    Spacer()
                }
                .padding()

                // Game info sections
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    Section("About") {
                        Text(gameDescription(for: game.title))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }

                    Section("Details") {
                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: DesignSystem.Spacing.lg) {
                            DetailRow(label: "Developer", value: "Eurocom")
                            DetailRow(label: "Publisher", value: "GT Interactive")
                            DetailRow(label: "Release Date", value: "1999")
                            DetailRow(label: "Players", value: "1-4")
                            DetailRow(label: "Rating", value: "T for Teen")
                            DetailRow(label: "File Size", value: "32 MB")
                        }
                    }
                }
                .padding()
            }
        }
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func gameDescription(for title: String) -> String {
        if title.contains("Duke Nukem") {
            return "Duke Nukem: Zero Hour is a third-person shooter that brings the Duke to Nintendo 64. Battle through different time periods to stop alien invaders from altering history."
        } else if title.contains("Mario 64") {
            return "Super Mario 64 is a groundbreaking 3D platformer. Explore Princess Peach's castle and jump into paintings to collect Power Stars."
        } else if title.contains("GoldenEye") {
            return "GoldenEye 007 is a first-person shooter based on the James Bond film. Features revolutionary split-screen multiplayer."
        } else if title.contains("Zelda") {
            return "The Legend of Zelda: Ocarina of Time is an action-adventure masterpiece. Journey through time to save Hyrule from Ganondorf."
        }
        return "A classic Nintendo 64 game ready to play."
    }
}

struct DetailRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
    }
}

// Using existing notification name from StreamingDashboard