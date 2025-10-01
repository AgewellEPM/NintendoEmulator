import SwiftUI
import EmulatorKit
import CoreInterface
import UniformTypeIdentifiers

/// Universal ROM Browser that shows actual game library
public struct UniversalROMBrowser: View {
    @StateObject private var romManager = ROMManager()
    @State private var selectedSystem: EmulatorSystem? = .n64
    @State private var searchText = ""
    @State private var selectedGame: ROMMetadata?
    @State private var showingImporter = false
    @State private var isDraggingOver = false

    public init() {}

    public var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                // Left sidebar with game list
                VStack(spacing: 0) {
                // System selector and search
                VStack(spacing: DesignSystem.Spacing.md) {
                    Menu {
                        Button("All Systems") { selectedSystem = nil }
                        ForEach(EmulatorSystem.allCases, id: \.self) { system in
                            Button(system.displayName) { selectedSystem = system }
                        }
                    } label: {
                        HStack {
                            Image(systemName: "gamecontroller.fill")
                            Text(selectedSystem?.displayName ?? "All Systems")
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

                // Game list - show actual ROMs
                ScrollView {
                    VStack(spacing: 2) {
                        if romManager.isLoading {
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.5)
                                Text("Loading ROMs...")
                                    .font(.headline)
                                Text("Found \(romManager.roms.count) so far...")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        } else if filteredROMs.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "gamecontroller")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.secondary)
                                Text("No ROMs Found")
                                    .font(.headline)
                                Text("Drag & drop ROMs here or click Import")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(40)
                        } else {
                            ForEach(filteredROMs, id: \.path) { rom in
                                GameRowView(
                                    title: rom.title,
                                    genre: rom.system.displayName,
                                    year: rom.region ?? "Unknown",
                                    isSelected: selectedGame?.path == rom.path
                                )
                                .onTapGesture {
                                    selectedGame = rom
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
                .overlay(
                    // Drag and drop overlay
                    isDraggingOver ?
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(Color.blue, lineWidth: 3, antialiased: true)
                        .background(
                            Color.blue.opacity(0.1)
                                .cornerRadius(8)
                        )
                        .overlay(
                            VStack(spacing: 12) {
                                Image(systemName: "arrow.down.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.blue)
                                Text("Drop ROM files to import")
                                    .font(.headline)
                                    .foregroundColor(.blue)
                            }
                        )
                        .padding(8)
                    : nil
                )
                .onDrop(of: [.fileURL], isTargeted: $isDraggingOver) { providers in
                    handleDrop(providers: providers)
                }

                Divider()

                // Bottom toolbar
                HStack {
                    Menu {
                        Button(action: { showingImporter = true }) {
                            Label("Open Folder", systemImage: "folder")
                        }

                        Button(action: {
                            if let url = URL(string: "https://romhustler.org/") {
                                NSWorkspace.shared.open(url)
                            }
                        }) {
                            Label("Visit romhustler.org", systemImage: "safari")
                        }
                    } label: {
                        Label("Import", systemImage: "plus.circle")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                    .menuStyle(BorderlessButtonMenuStyle())

                    Spacer()

                    Button(action: {}) {
                        Image(systemName: "slider.horizontal.3")
                    }
                    .buttonStyle(BorderlessButtonStyle())
                }
                .padding(10)
                .background(Color(NSColor.controlBackgroundColor))
            }
            .frame(width: 320)

            Divider()

            // Right side - game details
            if let game = selectedGame {
                GameDetailsView(game: game)
                    .environmentObject(romManager)
                    .id(game.path) // Force view recreation when game changes
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
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
        }
        .fileImporter(
            isPresented: $showingImporter,
            allowedContentTypes: [
                UTType(filenameExtension: "n64")!,
                UTType(filenameExtension: "z64")!,
                UTType(filenameExtension: "v64")!,
                .item
            ],
            allowsMultipleSelection: true
        ) { result in
            handleFileImport(result)
        }
        .onAppear {
            // Load ROMs in background, don't block UI
            Task(priority: .background) {
                await romManager.loadROMs()
            }
        }
    }

    var filteredROMs: [ROMMetadata] {
        var roms = romManager.roms

        // Filter by system if selected
        if let system = selectedSystem {
            roms = roms.filter { $0.system == system }
        }

        // Filter by search text
        if !searchText.isEmpty {
            roms = roms.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }

        return roms
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                await romManager.addROMs(from: urls)
            }
        case .failure(let error):
            print("Import failed: \(error)")
        }
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var urls: [URL] = []
        let group = DispatchGroup()

        for provider in providers {
            group.enter()
            _ = provider.loadObject(ofClass: URL.self) { url, error in
                defer { group.leave() }
                if let url = url {
                    // Check if it's a ROM file (.n64, .z64, .v64)
                    let ext = url.pathExtension.lowercased()
                    if ["n64", "z64", "v64"].contains(ext) {
                        urls.append(url)
                    }
                }
            }
        }

        group.notify(queue: .main) {
            if !urls.isEmpty {
                Task {
                    await romManager.addROMs(from: urls)
                }
            }
        }

        return true
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
    @StateObject private var fetcher = GameMetadataFetcher()
    @State private var metadata: GameMetadataFetcher.GameMetadata?
    @StateObject private var storageManager = ImageStorageManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                // Game header
                HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                    // Cover art - show real box art or fallback
                    if let boxArt = metadata?.boxArtImage ?? storageManager.loadImage(gameTitle: game.title, imageType: .libraryThumbnail) {
                        Image(nsImage: boxArt)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 280)
                            .cornerRadius(10)
                            .shadow(radius: 5)
                    } else {
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
                    }

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
        .task {
            metadata = fetcher.getCachedMetadata(for: game.title)
        }
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