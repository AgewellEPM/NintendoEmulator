import SwiftUI
import Foundation
import AppKit
import EmulatorKit
import CoreInterface

/// AI-powered game metadata fetcher
@MainActor
public class GameMetadataFetcher: ObservableObject {
    @Published var isFetching = false
    @Published var fetchProgress: Double = 0
    @Published var currentGameFetching = ""
    @Published var fetchedCount = 0
    @Published var totalGames = 0
    @Published var hasOptimized = false

    private let openAIKey: String
    private let igdbClientID: String?
    private let igdbAccessToken: String?
    private let gamesDatabase = "https://api.igdb.com/v4/games"
    private let coverDatabase = "https://api.igdb.com/v4/covers"

    // Cache for fetched metadata
    private var metadataCache: [String: GameMetadata] = [:]

    public init() {
        // Load API key from UserDefaults or environment
        if let key = UserDefaults.standard.string(forKey: "OpenAIAPIKey") {
            openAIKey = key
        } else if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            openAIKey = key
        } else {
            openAIKey = ""
        }

        // Optional IGDB credentials (via Twitch dev portal)
        igdbClientID = ProcessInfo.processInfo.environment["IGDB_CLIENT_ID"]
        igdbAccessToken = ProcessInfo.processInfo.environment["IGDB_ACCESS_TOKEN"]

        loadCache()
    }

    /// Game metadata structure
    public struct GameMetadata: Codable {
        let title: String
        let cleanedTitle: String
        let description: String
        let genre: String
        let releaseYear: String
        let developer: String
        let publisher: String
        let rating: Double
        let boxArtURL: String?
        let boxArtData: Data?

        var boxArtImage: NSImage? {
            guard let data = boxArtData else { return nil }
            return NSImage(data: data)
        }
    }

    /// Optimize all games in library
    public func optimizeLibrary(games: [CoreInterface.ROMMetadata]) async {
        guard !isFetching else { return }

        isFetching = true
        fetchedCount = 0
        totalGames = games.count

        for (index, game) in games.enumerated() {
            currentGameFetching = game.title
            fetchProgress = Double(index) / Double(totalGames)

            if let metadata = await fetchGameMetadata(for: game) {
                await applyMetadataToGame(game: game, metadata: metadata)
                metadataCache[game.title] = metadata
                fetchedCount += 1
            }

            // Small delay to avoid rate limiting
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        }

        saveCache()
        hasOptimized = true
        isFetching = false
        fetchProgress = 1.0
    }

    /// Fetch metadata for a single game
    public func fetchGameMetadata(for rom: CoreInterface.ROMMetadata) async -> GameMetadata? {
        // Check cache first
        if let cached = metadataCache[rom.title] {
            return cached
        }

        let gameName = cleanGameName(rom.title)

        // Try multiple sources
        var metadata: GameMetadata?

        // 1. Try IGDB-style database (simulated)
        metadata = await fetchFromGameDatabase(gameName: gameName)

        // 2. If that fails, use AI to generate metadata
        if metadata == nil {
            metadata = await generateWithAI(gameName: gameName)
        }

        // 3. Try to fetch box art
        if var gameMetadata = metadata {
            if let boxArt = await fetchBoxArt(for: gameName) {
                gameMetadata = GameMetadata(
                    title: gameMetadata.title,
                    cleanedTitle: gameMetadata.cleanedTitle,
                    description: gameMetadata.description,
                    genre: gameMetadata.genre,
                    releaseYear: gameMetadata.releaseYear,
                    developer: gameMetadata.developer,
                    publisher: gameMetadata.publisher,
                    rating: gameMetadata.rating,
                    boxArtURL: nil,
                    boxArtData: boxArt
                )
            }
            return gameMetadata
        }

        return nil
    }

    /// Clean game name for better searching
    private func cleanGameName(_ name: String) -> String {
        var cleaned = name

        // Remove file extension
        if let dotIndex = cleaned.lastIndex(of: ".") {
            cleaned = String(cleaned[..<dotIndex])
        }

        // Remove region codes
        let regionPatterns = ["(USA)", "(U)", "(E)", "(J)", "(Europe)", "[!]", "[h]", "[t]"]
        for pattern in regionPatterns {
            cleaned = cleaned.replacingOccurrences(of: pattern, with: "")
        }

        // Remove extra spaces
        cleaned = cleaned.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "  ", with: " ")

        return cleaned
    }

    /// Fetch from game database (simulated for N64 games)
    private func fetchFromGameDatabase(gameName: String) async -> GameMetadata? {
        // Hardcoded popular N64 games metadata
        let n64Database: [String: GameMetadata] = [
            "GoldenEye 007": GameMetadata(
                title: "GoldenEye 007",
                cleanedTitle: "GoldenEye 007",
                description: "James Bond's legendary first-person shooter that revolutionized console FPS games. Features stealth action and multiplayer combat.",
                genre: "First-Person Shooter",
                releaseYear: "1997",
                developer: "Rare",
                publisher: "Nintendo",
                rating: 9.6,
                boxArtURL: "goldeneye",
                boxArtData: nil
            ),
            "Duke Nukem Zero Hour": GameMetadata(
                title: "Duke Nukem: Zero Hour",
                cleanedTitle: "Duke Nukem Zero Hour",
                description: "Third-person action game featuring Duke Nukem traveling through time to stop alien invasions across different eras.",
                genre: "Action/Shooter",
                releaseYear: "1999",
                developer: "Eurocom",
                publisher: "GT Interactive",
                rating: 7.8,
                boxArtURL: "dukenukem",
                boxArtData: loadCustomBoxArt(imageName: "DukeNukemZeroHour_BoxArt.jpg")
            ),
            "Super Mario 64": GameMetadata(
                title: "Super Mario 64",
                cleanedTitle: "Super Mario 64",
                description: "Revolutionary 3D platformer that defined a generation. Mario explores Princess Peach's castle collecting Power Stars.",
                genre: "3D Platformer",
                releaseYear: "1996",
                developer: "Nintendo EAD",
                publisher: "Nintendo",
                rating: 9.8,
                boxArtURL: "mario64",
                boxArtData: nil
            ),
            "The Legend of Zelda Ocarina of Time": GameMetadata(
                title: "The Legend of Zelda: Ocarina of Time",
                cleanedTitle: "Zelda Ocarina of Time",
                description: "Epic action-adventure where Link travels through time to save Hyrule from Ganondorf. Widely considered one of the greatest games ever made.",
                genre: "Action-Adventure",
                releaseYear: "1998",
                developer: "Nintendo EAD",
                publisher: "Nintendo",
                rating: 10.0,
                boxArtURL: "zelda_oot",
                boxArtData: nil
            ),
            "Mario Kart 64": GameMetadata(
                title: "Mario Kart 64",
                cleanedTitle: "Mario Kart 64",
                description: "The ultimate multiplayer racing experience with Mario characters. Features 16 tracks and intense 4-player battles.",
                genre: "Racing",
                releaseYear: "1996",
                developer: "Nintendo EAD",
                publisher: "Nintendo",
                rating: 9.3,
                boxArtURL: "mariokart",
                boxArtData: nil
            )
        ]

        // Find best match
        for (key, metadata) in n64Database {
            if gameName.lowercased().contains(key.lowercased()) ||
               key.lowercased().contains(gameName.lowercased()) {
                return metadata
            }
        }

        return nil
    }

    /// Generate metadata using AI
    private func generateWithAI(gameName: String) async -> GameMetadata? {
        guard !openAIKey.isEmpty else { return nil }

        let prompt = """
        Generate game metadata for the Nintendo 64 game "\(gameName)".
        Provide a JSON response with these exact fields:
        {
            "title": "Full game title",
            "description": "Brief 2-3 sentence description",
            "genre": "Game genre",
            "releaseYear": "Year",
            "developer": "Developer company",
            "publisher": "Publisher company",
            "rating": 8.5
        }
        """

        do {
            var request = URLRequest(url: URL(string: "https://api.openai.com/v1/chat/completions")!)
            request.httpMethod = "POST"
            request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")

            let requestBody: [String: Any] = [
                "model": "gpt-4-turbo-preview",
                "messages": [
                    ["role": "system", "content": "You are a video game database assistant. Provide accurate game information in JSON format."],
                    ["role": "user", "content": prompt]
                ],
                "max_tokens": 300,
                "temperature": 0.3
            ]

            request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

            let (data, _) = try await URLSession.shared.data(for: request)
            let response = try JSONSerialization.jsonObject(with: data) as! [String: Any]

            if let choices = response["choices"] as? [[String: Any]],
               let message = choices.first?["message"] as? [String: Any],
               let content = message["content"] as? String {

                // Parse JSON from response
                if let jsonData = content.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] {

                    return GameMetadata(
                        title: json["title"] as? String ?? gameName,
                        cleanedTitle: gameName,
                        description: json["description"] as? String ?? "Classic Nintendo 64 game",
                        genre: json["genre"] as? String ?? "Action",
                        releaseYear: json["releaseYear"] as? String ?? "199X",
                        developer: json["developer"] as? String ?? "Unknown",
                        publisher: json["publisher"] as? String ?? "Unknown",
                        rating: json["rating"] as? Double ?? 7.5,
                        boxArtURL: nil,
                        boxArtData: nil
                    )
                }
            }
        } catch {
            print("AI metadata generation error: \(error)")
        }

        // Fallback metadata
        return GameMetadata(
            title: gameName,
            cleanedTitle: gameName,
            description: "A Nintendo 64 game",
            genre: "Unknown",
            releaseYear: "199X",
            developer: "Unknown",
            publisher: "Unknown",
            rating: 7.0,
            boxArtURL: nil,
            boxArtData: nil
        )
    }

    /// Fetch box art image
    private func fetchBoxArt(for gameName: String) async -> Data? {
        // Prefer IGDB if credentials are provided
        if let clientID = igdbClientID, let token = igdbAccessToken, !clientID.isEmpty, !token.isEmpty {
            if let data = await fetchIGDBCover(gameName: gameName, clientID: clientID, token: token) {
                return data
            }
        }

        // Fallback: generate placeholder locally
        return await generateBoxArt(for: gameName)
    }

    /// Query IGDB for cover art if credentials are available
    private func fetchIGDBCover(gameName: String, clientID: String, token: String) async -> Data? {
        // 1) Search game to get cover id
        guard let gameURL = URL(string: gamesDatabase) else { return nil }
        var gameRequest = URLRequest(url: gameURL)
        gameRequest.httpMethod = "POST"
        gameRequest.setValue(clientID, forHTTPHeaderField: "Client-ID")
        gameRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        gameRequest.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        let query = "search \"\(gameName)\"; fields id,name,cover; limit 1;"
        gameRequest.httpBody = query.data(using: .utf8)

        do {
            let (gameData, _) = try await URLSession.shared.data(for: gameRequest)
            guard let arr = try JSONSerialization.jsonObject(with: gameData) as? [[String: Any]],
                  let first = arr.first,
                  let coverId = first["cover"] as? Int else {
                return nil
            }

            // 2) Fetch cover info
            guard let coverURL = URL(string: coverDatabase) else { return nil }
            var coverRequest = URLRequest(url: coverURL)
            coverRequest.httpMethod = "POST"
            coverRequest.setValue(clientID, forHTTPHeaderField: "Client-ID")
            coverRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            coverRequest.setValue("text/plain", forHTTPHeaderField: "Content-Type")
            coverRequest.httpBody = "fields image_id,url; where id = \(coverId); limit 1;".data(using: .utf8)

            let (coverData, _) = try await URLSession.shared.data(for: coverRequest)
            guard let coverArr = try JSONSerialization.jsonObject(with: coverData) as? [[String: Any]],
                  let cover = coverArr.first,
                  let imageId = cover["image_id"] as? String else {
                return nil
            }

            // 3) Build CDN URL and fetch image
            let cdn = "https://images.igdb.com/igdb/image/upload/t_cover_big/\(imageId).jpg"
            guard let imgURL = URL(string: cdn) else { return nil }
            let (imgData, _) = try await URLSession.shared.data(from: imgURL)
            return imgData
        } catch {
            print("IGDB fetch error: \(error)")
            return nil
        }
    }

    /// Generate box art placeholder
    private func generateBoxArt(for gameName: String) async -> Data? {
        // Create a nice gradient box art placeholder
        let size = CGSize(width: 300, height: 400)
        let image = NSImage(size: size)

        image.lockFocus()

        // Draw gradient background
        let gradient = NSGradient(colors: [
            NSColor.systemPurple,
            NSColor.systemBlue
        ])
        gradient?.draw(in: NSRect(origin: .zero, size: size), angle: -45)

        // Add N64 logo
        let n64Text = "N64"
        let n64Attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 36),
            .foregroundColor: NSColor.white
        ]
        let n64Size = n64Text.size(withAttributes: n64Attrs)
        let n64Point = NSPoint(x: size.width - n64Size.width - 20, y: 20)
        n64Text.draw(at: n64Point, withAttributes: n64Attrs)

        // Add game title
        let titleAttrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.white,
            .paragraphStyle: {
                let style = NSMutableParagraphStyle()
                style.alignment = .center
                return style
            }()
        ]

        let titleRect = NSRect(x: 20, y: size.height/2 - 30, width: size.width - 40, height: 60)
        gameName.draw(in: titleRect, withAttributes: titleAttrs)

        image.unlockFocus()

        return image.tiffRepresentation
    }

    /// Apply metadata to game
    private func applyMetadataToGame(game: CoreInterface.ROMMetadata, metadata: GameMetadata) async {
        // Update the game's display information
        await MainActor.run {
            // This would update the ROM metadata with the fetched info
            // Store in UserDefaults or local database
            let key = "game_metadata_\(game.title)"
            if let encoded = try? JSONEncoder().encode(metadata) {
                UserDefaults.standard.set(encoded, forKey: key)
            }
        }
    }

    /// Save metadata cache
    private func saveCache() {
        if let encoded = try? JSONEncoder().encode(metadataCache) {
            UserDefaults.standard.set(encoded, forKey: "game_metadata_cache")
        }
    }

    /// Load metadata cache
    private func loadCache() {
        if let data = UserDefaults.standard.data(forKey: "game_metadata_cache"),
           let cache = try? JSONDecoder().decode([String: GameMetadata].self, from: data) {
            metadataCache = cache
        }
    }

    /// Load custom box art from Resources directory
    private func loadCustomBoxArt(imageName: String) -> Data? {
        guard let bundlePath = Bundle.main.resourcePath else { return nil }
        let imagePath = "\(bundlePath)/\(imageName)"
        let url = URL(fileURLWithPath: imagePath)
        return try? Data(contentsOf: url)
    }

    /// Get cached metadata for a game
    public func getCachedMetadata(for gameName: String) -> GameMetadata? {
        let cleanName = cleanGameName(gameName)

        // Check memory cache
        if let cached = metadataCache[cleanName] {
            return cached
        }

        // Check UserDefaults
        let key = "game_metadata_\(gameName)"
        if let data = UserDefaults.standard.data(forKey: key),
           let metadata = try? JSONDecoder().decode(GameMetadata.self, from: data) {
            metadataCache[cleanName] = metadata
            return metadata
        }

        return nil
    }
}

/// Optimize button view
public struct OptimizeLibraryButton: View {
    @StateObject private var fetcher = GameMetadataFetcher()
    @EnvironmentObject var romManager: EmulatorKit.ROMManager
    @State private var showProgress = false

    public init() {}

    public var body: some View {
        Button(action: optimizeLibrary) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: fetcher.isFetching ? "sparkles" : "sparkles.rectangle.stack")
                    .font(.system(size: 14))
                    .rotationEffect(.degrees(fetcher.isFetching ? 360 : 0))
                    .animation(fetcher.isFetching ? Animation.linear(duration: 2).repeatForever(autoreverses: false) : .default, value: fetcher.isFetching)

                Text(fetcher.hasOptimized ? "Optimized" : "Optimize")
                    .font(.system(size: 12, weight: .medium))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                fetcher.hasOptimized ?
                Color.green.opacity(0.2) :
                Color.blue.opacity(0.2)
            )
            .foregroundColor(
                fetcher.hasOptimized ?
                Color.green :
                Color.blue
            )
            .cornerRadius(DesignSystem.Radius.lg)
        }
        .disabled(fetcher.isFetching)
        .popover(isPresented: $showProgress) {
            OptimizationProgressView(fetcher: fetcher)
        }
        .onChange(of: fetcher.isFetching) { isFetching in
            showProgress = isFetching
        }
    }

    private func optimizeLibrary() {
        Task {
            await fetcher.optimizeLibrary(games: romManager.games)
            // Refresh ROM display
            await MainActor.run {
                romManager.refreshDisplay()
            }
        }
    }
}

/// Optimization progress view
struct OptimizationProgressView: View {
    @ObservedObject var fetcher: GameMetadataFetcher

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Text("Optimizing Game Library")
                .font(.headline)

            if !fetcher.currentGameFetching.isEmpty {
                Text("Fetching: \(fetcher.currentGameFetching)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: fetcher.fetchProgress)
                .progressViewStyle(.linear)
                .frame(width: 200)

            HStack {
                Text("\(fetcher.fetchedCount) / \(fetcher.totalGames)")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(Int(fetcher.fetchProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(width: 200)
        }
        .padding()
        .frame(width: 250, height: 150)
    }
}
