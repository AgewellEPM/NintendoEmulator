import SwiftUI
import Foundation
import CoreInterface
import EmulatorKit
import Combine
import UniformTypeIdentifiers

/// Comprehensive game details panel with AI chat integration
public struct GameDetailsView: View {
    let game: ROMMetadata
    @StateObject private var fetcher = GameMetadataFetcher()
    @StateObject private var chatManager = GameChatManager()
    @ObservedObject private var theme = UIThemeManager.shared
    @State private var metadata: GameMetadataFetcher.GameMetadata?
    @State private var selectedTab: DetailTab = .overview
    @State private var scrollOffset: CGFloat = 0
    @State private var showChatSidebar = false

    enum DetailTab: String, CaseIterable {
        case overview = "Overview"
        case media = "Media"
        case chat = "AI Chat"
        case specs = "Technical"

        var icon: String {
            switch self {
            case .overview: return "info.circle"
            case .media: return "photo.stack"
            case .chat: return "message.circle"
            case .specs: return "cpu"
            }
        }
    }

    public init(game: ROMMetadata) {
        self.game = game
    }

    public var body: some View {
        ZStack {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0) {
                        // Hero section with cover art
                        heroSection
                            .id("hero")

                        // Content based on selected tab
                        contentSection
                            .padding()
                            .padding(.top, 40)
                            .padding(.horizontal, 40)
                    }
                }
                .background(
                    // Background image with blur effect
                    Group {
                        if let boxArt = metadata?.boxArtImage {
                            Image(nsImage: boxArt)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .blur(radius: 20)
                            .opacity(0.1)
                    } else {
                        LinearGradient(
                            colors: [.blue.opacity(0.3), .purple.opacity(0.3)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .ignoresSafeArea()
            )
        }

        // Chat Sidebar Overlay
        if showChatSidebar {
            HStack {
                Spacer()

                ChatSidebarView(
                    chatManager: chatManager,
                    game: game,
                    isShowing: $showChatSidebar
                )
                .frame(width: 400)
                .background(theme.chatColor.opacity(theme.chatOpacity * (1.0 - theme.chatTransparency)))
                .transition(AnyTransition.move(edge: .trailing).combined(with: .opacity))
            }
            .ignoresSafeArea()
        }
    }
        .task {
            await loadGameData()
        }
        .animation(.easeInOut(duration: 0.3), value: showChatSidebar)
    }

    private var heroSection: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            HStack(spacing: DesignSystem.Spacing.section) {
                // Large cover art
                if let boxArt = metadata?.boxArtImage {
                    Image(nsImage: boxArt)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 240, height: 320)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                } else {
                    // Placeholder with N64 styling
                    RoundedRectangle(cornerRadius: 16)
                        .fill(
                            LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 240, height: 320)
                        .overlay(
                            VStack {
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.8))
                                Text("N64")
                                    .font(.title.bold())
                                    .foregroundColor(.white)
                            }
                        )
                        .shadow(color: .black.opacity(0.3), radius: 20, x: 0, y: 10)
                }

                // Game info
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    // Title and system
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(metadata?.title ?? game.title)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundStyle(.primary)

                        HStack {
                            Label(game.system.displayName, systemImage: "cube.fill")
                                .font(.title3)
                                .foregroundColor(.blue)

                            if let region = game.region {
                                Text("• \(region)")
                                    .font(.title3)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    // Quick stats
                    if let metadata = metadata {
                        HStack(spacing: DesignSystem.Spacing.xl) {
                            StatBadge(
                                icon: "star.fill",
                                value: String(format: "%.1f", metadata.rating),
                                color: .yellow
                            )

                            StatBadge(
                                icon: "calendar",
                                value: metadata.releaseYear,
                                color: .blue
                            )

                            StatBadge(
                                icon: "tag.fill",
                                value: metadata.genre,
                                color: .purple
                            )
                        }
                    }

                    // Description preview
                    if let description = metadata?.description {
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }

                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, 40)
            .padding(.top, 40)
            .padding(.bottom, 20)

            // Big Play Button at bottom
            Button(action: {
                NotificationCenter.default.post(name: .emulatorOpenROM, object: game.path)
            }) {
                HStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                    Text("PLAY GAME")
                        .font(.title2.bold())
                        .foregroundColor(.white)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [.green, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .green.opacity(0.4), radius: 8, x: 0, y: 4)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 40)
            .padding(.bottom, 20)
        }
        .frame(height: 400)
    }

    private var tabNavigation: some View {
        HStack(spacing: 0) {
            ForEach(DetailTab.allCases, id: \.self) { tab in
                Button(action: {
                    selectedTab = tab
                }) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 14))
                        Text(tab.rawValue)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 12)
                    .background(
                        selectedTab == tab ?
                        Color.blue.opacity(0.2) :
                        Color.clear
                    )
                    .foregroundColor(
                        selectedTab == tab ?
                        .blue :
                        .secondary
                    )
                }
                .buttonStyle(.plain)

                if tab != DetailTab.allCases.last {
                    Divider()
                        .frame(height: 24)
                }
            }
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private var contentSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
            // Show content based on selected tab
            switch selectedTab {
            case .overview:
                // Show About This Game section for overview
                if let metadata = metadata {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                        Text("About This Game")
                            .font(.title2.bold())

                        Text(metadata.description)
                            .font(.body)
                            .lineSpacing(4)
                    }
                }

                // Show Game Information blocks only for overview
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                    Text("Game Information")
                        .font(.title2.bold())

                    VStack(spacing: DesignSystem.Spacing.lg) {
                        // First row - 3 cards
                        HStack(spacing: DesignSystem.Spacing.lg) {
                            if let metadata = metadata {
                                InfoCard(title: "Developer", value: metadata.developer, icon: "hammer.fill")
                                InfoCard(title: "Publisher", value: metadata.publisher, icon: "building.2.fill")
                                InfoCard(title: "Release Year", value: metadata.releaseYear, icon: "calendar")
                            }
                        }

                        // Second row - 3 cards
                        HStack(spacing: DesignSystem.Spacing.lg) {
                            if let metadata = metadata {
                                InfoCard(title: "Genre", value: metadata.genre, icon: "tag.fill")
                            }
                            InfoCard(title: "File Size", value: formatFileSize(game.size), icon: "doc.fill")
                            InfoCard(title: "System", value: game.system.displayName, icon: "gamecontroller.fill")
                        }
                    }
                }
            case .media:
                ModernMediaGallery(metadata: metadata, game: game)
            case .chat:
                // Chat opens in sidebar - show message
                VStack(spacing: DesignSystem.Spacing.lg) {
                    Image(systemName: "message.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    Text("Chat panel opened on the right →")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(40)
                .onAppear {
                    showChatSidebar = true
                }
                .onDisappear {
                    showChatSidebar = false
                }
            case .specs:
                TechnicalTab(game: game)
            }

            // Tab navigation below the content
            tabNavigation
                .padding(.top, 16)

            Spacer(minLength: 100)
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    private func loadGameData() async {
        metadata = fetcher.getCachedMetadata(for: game.title)

        if metadata == nil {
            if let fetchedMetadata = await fetcher.fetchGameMetadata(for: game) {
                metadata = fetchedMetadata
            }
        }

        // Initialize chat with game context
        await chatManager.initializeWithGame(game, metadata: metadata)
    }
}


// MARK: - Media Tab

struct MediaTab: View {
    let metadata: GameMetadataFetcher.GameMetadata?
    let game: ROMMetadata
    @State private var screenshots: [NSImage] = []
    @State private var boxArtImage: NSImage?
    @State private var libraryThumbnail: NSImage?
    @State private var showingImagePicker = false
    @State private var imagePickerType: ImagePickerType = .boxArt
    @StateObject private var storageManager = ImageStorageManager.shared

    enum ImagePickerType {
        case boxArt
        case libraryThumbnail
        case screenshot(index: Int)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
            Text("Media Gallery")
                .font(.title2.bold())

            // Box Art section with upload
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("Box Art")
                        .font(.headline)

                    Button(action: {
                        imagePickerType = .boxArt
                        showingImagePicker = true
                    }) {
                        Label("Upload", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                ZStack {
                    if let boxArt = boxArtImage ?? metadata?.boxArtImage {
                        Image(nsImage: boxArt)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(maxWidth: 400)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .shadow(radius: 8)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(LinearGradient(
                                colors: [.blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 300, height: 400)
                            .shadow(radius: 8)
                    }

                    // N64 overlay logo
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("N64")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                                .padding(DesignSystem.Spacing.sm)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(DesignSystem.Radius.md)
                                .padding(DesignSystem.Spacing.md)
                        }
                    }
                }
            }

            // ROM Library Thumbnail section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("ROM Library Thumbnail")
                        .font(.headline)

                    Button(action: {
                        imagePickerType = .libraryThumbnail
                        showingImagePicker = true
                    }) {
                        Label("Upload", systemImage: "square.and.arrow.up")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                }

                ZStack {
                    if let thumbnail = libraryThumbnail {
                        Image(nsImage: thumbnail)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    } else {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.gray.opacity(0.2))
                            .frame(width: 200, height: 200)
                            .overlay(
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(.blue)
                            )
                    }

                    // N64 overlay for thumbnail
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("N64")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .padding(DesignSystem.Spacing.xs)
                                .background(Color.black.opacity(0.3))
                                .cornerRadius(DesignSystem.Radius.sm)
                                .padding(6)
                        }
                    }
                }
            }

            // Screenshots section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Screenshots")
                    .font(.headline)

                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: DesignSystem.Spacing.md) {
                    ForEach(0..<6, id: \.self) { index in
                        ZStack {
                            if index < screenshots.count {
                                Image(nsImage: screenshots[index])
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(height: 120)
                                    .clipped()
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            } else {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.gray.opacity(0.2))
                                    .aspectRatio(4/3, contentMode: .fit)
                                    .overlay(
                                        Button(action: {
                                            imagePickerType = .screenshot(index: index)
                                            showingImagePicker = true
                                        }) {
                                            VStack {
                                                Image(systemName: "photo.badge.plus")
                                                    .font(.title2)
                                                    .foregroundColor(.blue)
                                                Text("Add Screenshot")
                                                    .font(.caption)
                                                    .foregroundColor(.secondary)
                                            }
                                        }
                                        .buttonStyle(.plain)
                                    )
                            }

                            // N64 overlay for screenshots
                            if index < screenshots.count {
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Text("N64")
                                            .font(.system(size: 10, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(2)
                                            .background(Color.black.opacity(0.3))
                                            .cornerRadius(3)
                                            .padding(DesignSystem.Spacing.xs)
                                    }
                                }
                            }
                        }
                    }
                }
            }

            Spacer(minLength: 100)
        }
        .fileImporter(
            isPresented: $showingImagePicker,
            allowedContentTypes: [.jpeg, .png, .gif, .bmp],
            onCompletion: handleImageSelection
        )
        .onAppear {
            loadSavedImages()
        }
    }

    private func handleImageSelection(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            guard url.startAccessingSecurityScopedResource() else {
                print("Failed to access security scoped resource")
                return
            }
            defer { url.stopAccessingSecurityScopedResource() }

            print("Loading image from: \(url.path)")

            if let imageData = try? Data(contentsOf: url),
               let image = NSImage(data: imageData) {

                print("Successfully loaded image, size: \(image.size)")

                DispatchQueue.main.async {
                    switch self.imagePickerType {
                    case .boxArt:
                        print("Setting box art image")
                        self.boxArtImage = image
                        self.storageManager.saveImage(image, gameTitle: self.game.title, imageType: .boxArt)
                    case .libraryThumbnail:
                        print("Setting library thumbnail image")
                        self.libraryThumbnail = image
                        self.storageManager.saveImage(image, gameTitle: self.game.title, imageType: .libraryThumbnail)
                    case .screenshot(let index):
                        print("Setting screenshot at index: \(index)")
                        while self.screenshots.count <= index {
                            self.screenshots.append(NSImage())
                        }
                        self.screenshots[index] = image
                        self.storageManager.saveImage(image, gameTitle: self.game.title, imageType: .screenshot(index: index))
                    }
                }
            } else {
                print("Failed to load image data or create NSImage")
            }
        case .failure(let error):
            print("Failed to load image: \(error)")
        }
    }

    private func loadSavedImages() {
        // Load box art
        if boxArtImage == nil {
            boxArtImage = storageManager.loadImage(gameTitle: game.title, imageType: .boxArt)
        }

        // Load library thumbnail
        if libraryThumbnail == nil {
            libraryThumbnail = storageManager.loadImage(gameTitle: game.title, imageType: .libraryThumbnail)
        }

        // Load screenshots
        if screenshots.isEmpty {
            screenshots = storageManager.loadScreenshots(gameTitle: game.title)
        }
    }
}

// MARK: - Chat Tab

struct ChatTab: View {
    @ObservedObject var chatManager: GameChatManager
    @ObservedObject private var theme = UIThemeManager.shared
    let game: ROMMetadata
    @State private var messageInput = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("AI Game Discussion")
                .font(.title2.bold())
                .padding(.bottom, 16)

            // Chat messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        ForEach(chatManager.messages) { message in
                            GameChatMessageView(message: message)
                                .id(message.id)
                        }

                        if chatManager.isLoading {
                            HStack {
                                ProgressView()
                                    .controlSize(.small)
                                Text("AI is thinking...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding()
                        }
                    }
                    .padding()
                }
                .frame(height: 400)
                .background(
                    theme.chatTransparency >= 1.0 ?
                    AnyView(Color.clear) :
                    (theme.chatBlur ?
                    AnyView(ZStack {
                        theme.chatColor
                            .opacity(theme.chatOpacity * (1.0 - theme.chatTransparency))
                        VisualEffectView(material: .contentBackground, blendingMode: .behindWindow)
                            .opacity(0.3 * (1.0 - theme.chatTransparency))
                    }) :
                    AnyView(theme.chatColor
                        .opacity(theme.chatOpacity * (1.0 - theme.chatTransparency))))
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .onChange(of: chatManager.messages.count) { _ in
                    if let lastMessage = chatManager.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            // Message input
            HStack {
                TextField("Ask about \(game.title)...", text: $messageInput)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendMessage()
                    }

                Button("Send") {
                    sendMessage()
                }
                .buttonStyle(.borderedProminent)
                .disabled(messageInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || chatManager.isLoading)
            }
            .padding(.top, 12)

            // Quick questions
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    QuickQuestionButton(text: "What makes this game special?", action: askQuickQuestion)
                    QuickQuestionButton(text: "Tell me about the gameplay", action: askQuickQuestion)
                    QuickQuestionButton(text: "What's the story about?", action: askQuickQuestion)
                    QuickQuestionButton(text: "Any tips for beginners?", action: askQuickQuestion)
                    QuickQuestionButton(text: "Historical significance?", action: askQuickQuestion)
                }
                .padding(.horizontal)
            }
            .padding(.top, 8)

            Spacer(minLength: 50)
        }
    }

    private func sendMessage() {
        let message = messageInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !message.isEmpty else { return }

        messageInput = ""
        Task {
            await chatManager.sendMessage(message)
        }
    }

    private func askQuickQuestion(_ question: String) {
        messageInput = question
        sendMessage()
    }
}

// MARK: - Technical Tab

struct TechnicalTab: View {
    let game: ROMMetadata

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
            Text("Technical Specifications")
                .font(.title2.bold())

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.lg) {
                InfoCard(title: "File Format", value: game.path.pathExtension.uppercased(), icon: "doc.text.fill")
                InfoCard(title: "File Size", value: formatFileSize(game.size), icon: "externaldrive.fill")
                InfoCard(title: "Checksum", value: String(game.checksum.prefix(8)), icon: "number.circle.fill")

                if let region = game.region {
                    InfoCard(title: "Region", value: region, icon: "globe")
                }

                InfoCard(title: "System", value: game.system.displayName, icon: "gamecontroller.fill")
                InfoCard(title: "Architecture", value: "MIPS R4300i", icon: "cpu")
            }

            // ROM Header info if available
            if let headerData = game.header {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("ROM Header")
                        .font(.headline)

                    Text("First 16 bytes:")
                        .font(.subheadline)
                        .foregroundColor(.secondary)

                    Text(headerData.prefix(16).map { String(format: "%02X", $0) }.joined(separator: " "))
                        .font(.system(.caption, design: .monospaced))
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }

            Spacer(minLength: 100)
        }
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Supporting Views

struct StatBadge: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.caption)
            Text(value)
                .font(.caption.bold())
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(color.opacity(0.2))
        .foregroundColor(color)
        .clipShape(Capsule())
    }
}

struct InfoCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.blue)
                    .font(.caption)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.subheadline.bold())
                .multilineTextAlignment(.leading)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct GameChatMessageView: View {
    let message: GameChatMessage
    @ObservedObject private var theme = UIThemeManager.shared

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Avatar
            Circle()
                .fill(message.isUser ? Color.blue : Color.green)
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: message.isUser ? "person.fill" : "brain.head.profile")
                        .font(.system(size: 16))
                        .foregroundColor(.white)
                )

            // Message content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(message.isUser ? "You" : "AI Assistant")
                    .font(.caption.bold())
                    .foregroundColor(.secondary)

                Text(message.content)
                    .font(.body)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        message.isUser ?
                        theme.chatColor.opacity(0.2) :
                        theme.chatColor.opacity(0.1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct QuickQuestionButton: View {
    let text: String
    let action: (String) -> Void

    var body: some View {
        Button(action: {
            action(text)
        }) {
            Text(text)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.blue.opacity(0.1))
                .foregroundColor(.blue)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Extensions

extension View {
    func sticky() -> some View {
        // Simple sticky implementation for macOS
        self
    }
}