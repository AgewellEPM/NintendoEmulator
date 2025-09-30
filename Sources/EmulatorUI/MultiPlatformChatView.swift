import SwiftUI

// MARK: - Multi-Platform Chat View
public struct MultiPlatformChatView: View {
    @StateObject private var chatManager = MultiPlatformChatManager()
    @ObservedObject private var theme = UIThemeManager.shared
    @State private var selectedPlatform: ChatPlatform? = nil // nil means "All"
    @State private var messageText = ""
    @State private var searchText = ""
    @State private var showModTools = false
    @State private var selectedMessage: UnifiedChatMessage?

    public init() {}

    public var body: some View {
        HSplitView {
            // Left: Platform selector and stats
            PlatformSelectorSidebar(
                platforms: chatManager.platforms,
                selectedPlatform: $selectedPlatform,
                totalViewers: chatManager.totalViewers,
                totalMessages: chatManager.totalMessages
            )
            .frame(width: 250)

            // Center: Main chat view
            VStack(spacing: 0) {
                // Chat Header
                ChatHeaderBar(
                    selectedPlatform: selectedPlatform,
                    searchText: $searchText,
                    showModTools: $showModTools,
                    onRefresh: { chatManager.refreshChats() }
                )

                Divider()

                // Chat Messages
                ChatMessagesView(
                    messages: filteredMessages,
                    selectedMessage: $selectedMessage,
                    onReply: { message in
                        messageText = "@\(message.username) "
                    },
                    onModerate: { message in
                        selectedMessage = message
                        showModTools = true
                    }
                )

                Divider()

                // Message Input
                MessageInputBar(
                    messageText: $messageText,
                    selectedPlatform: selectedPlatform,
                    onSend: { platform in
                        chatManager.sendMessage(messageText, to: platform)
                        messageText = ""
                    }
                )
                .padding()
            }

            // Right: Viewer list and moderation
            if showModTools {
                ModerationPanel(
                    selectedMessage: $selectedMessage,
                    viewers: chatManager.activeViewers,
                    onBan: { user in chatManager.banUser(user) },
                    onTimeout: { user, duration in chatManager.timeoutUser(user, duration: duration) },
                    onDelete: { message in chatManager.deleteMessage(message) }
                )
                .frame(width: 300)
            }
        }
        .background(theme.mainWindowColor.opacity(theme.mainWindowOpacity))
        .onAppear {
            chatManager.connectToAllPlatforms()
        }
    }

    private var filteredMessages: [UnifiedChatMessage] {
        var messages = chatManager.messages

        // Filter by platform
        if let platform = selectedPlatform {
            messages = messages.filter { $0.platform == platform }
        }

        // Filter by search
        if !searchText.isEmpty {
            messages = messages.filter { message in
                message.content.localizedCaseInsensitiveContains(searchText) ||
                message.username.localizedCaseInsensitiveContains(searchText)
            }
        }

        return messages
    }
}

// MARK: - Platform Selector Sidebar
struct PlatformSelectorSidebar: View {
    @ObservedObject private var theme = UIThemeManager.shared
    let platforms: [PlatformChatInfo]
    @Binding var selectedPlatform: ChatPlatform?
    let totalViewers: Int
    let totalMessages: Int

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Chat Platforms")
                    .font(.headline)
                    .foregroundColor(.white)

                HStack {
                    Label("\(totalViewers)", systemImage: "eye")
                        .font(.caption)
                    Spacer()
                    Label("\(totalMessages)", systemImage: "message")
                        .font(.caption)
                }
                .foregroundColor(.white.opacity(0.7))
            }
            .padding()
            .background(theme.chatColor.opacity(theme.chatOpacity * 0.7))

            Divider()

            // All Platforms option
            PlatformRow(
                name: "All Platforms",
                icon: "square.grid.2x2",
                color: .blue,
                viewerCount: totalViewers,
                messageCount: totalMessages,
                isSelected: selectedPlatform == nil,
                isConnected: true
            )
            .onTapGesture {
                selectedPlatform = nil
            }

            Divider()

            // Individual platforms
            ScrollView {
                VStack(spacing: 2) {
                    ForEach(platforms) { platform in
                        PlatformRow(
                            name: platform.name,
                            icon: platform.icon,
                            color: platform.color,
                            viewerCount: platform.viewerCount,
                            messageCount: platform.messageCount,
                            isSelected: selectedPlatform == platform.type,
                            isConnected: platform.isConnected
                        )
                        .onTapGesture {
                            selectedPlatform = platform.type
                        }
                    }
                }
            }

            Spacer()

            // Connection Status
            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(platforms.filter { !$0.isConnected }) { platform in
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.yellow)
                            .font(.caption)
                        Text("\(platform.name) disconnected")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            .padding()
        }
        .background(theme.sidebarColor.opacity(theme.sidebarOpacity))
    }
}

// MARK: - Platform Row
struct PlatformRow: View {
    let name: String
    let icon: String
    let color: Color
    let viewerCount: Int
    let messageCount: Int
    let isSelected: Bool
    let isConnected: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Platform Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isConnected ? color : .gray)
                .frame(width: 24)

            // Platform Name
            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white.opacity(isConnected ? 1 : 0.5))

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Label("\(viewerCount)", systemImage: "eye")
                        .font(.caption2)
                    Label("\(messageCount)", systemImage: "message")
                        .font(.caption2)
                }
                .foregroundColor(.white.opacity(0.5))
            }

            Spacer()

            // Connection indicator
            if isConnected {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.white.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Chat Header Bar
struct ChatHeaderBar: View {
    @ObservedObject private var theme = UIThemeManager.shared
    let selectedPlatform: ChatPlatform?
    @Binding var searchText: String
    @Binding var showModTools: Bool
    let onRefresh: () -> Void

    var body: some View {
        HStack {
            // Title
            Text(selectedPlatform?.rawValue ?? "All Platforms")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            Spacer()

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.white.opacity(0.5))
                TextField("Search messages...", text: $searchText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.md)
            .frame(width: 200)

            // Actions
            Button(action: { showModTools.toggle() }) {
                Image(systemName: showModTools ? "shield.fill" : "shield")
                    .foregroundColor(.orange)
            }
            .buttonStyle(.plain)
            .help("Moderation Tools")

            Button(action: onRefresh) {
                Image(systemName: "arrow.clockwise")
                    .foregroundColor(.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .help("Refresh")
        }
        .padding()
        .background(Color.white.opacity(0.05))
    }
}

// MARK: - Chat Messages View
struct ChatMessagesView: View {
    @ObservedObject private var theme = UIThemeManager.shared
    let messages: [UnifiedChatMessage]
    @Binding var selectedMessage: UnifiedChatMessage?
    let onReply: (UnifiedChatMessage) -> Void
    let onModerate: (UnifiedChatMessage) -> Void

    @State private var hoveredMessageId: UUID?

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ForEach(messages) { message in
                        ChatMessageRow(
                            message: message,
                            isHovered: hoveredMessageId == message.id,
                            isSelected: selectedMessage?.id == message.id,
                            onReply: { onReply(message) },
                            onModerate: { onModerate(message) }
                        )
                        .id(message.id)
                        .onHover { isHovered in
                            hoveredMessageId = isHovered ? message.id : nil
                        }
                        .onTapGesture {
                            selectedMessage = selectedMessage?.id == message.id ? nil : message
                        }
                    }
                }
                .padding()
            }
            .background(theme.mainWindowColor.opacity(theme.mainWindowOpacity))
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    withAnimation {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
    }
}

// MARK: - Chat Message Row
struct ChatMessageRow: View {
    let message: UnifiedChatMessage
    let isHovered: Bool
    let isSelected: Bool
    let onReply: () -> Void
    let onModerate: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // Platform indicator
            Image(systemName: message.platform.icon)
                .font(.caption)
                .foregroundColor(message.platform.color)
                .frame(width: 16)

            // Avatar
            Circle()
                .fill(LinearGradient(
                    colors: [message.userColor, message.userColor.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 32, height: 32)
                .overlay(
                    Text(String(message.username.prefix(1).uppercased()))
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                )

            // Message Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    // Username
                    Text(message.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(message.userColor)

                    // Badges
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(message.badges, id: \.self) { badge in
                            BadgeView(badge: badge)
                        }
                    }

                    // Timestamp
                    Text(message.timestamp.formatted(.dateTime.hour().minute()))
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }

                // Message text
                Text(message.content)
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.9))
                    .textSelection(.enabled)

                // Emotes/Media
                if !message.emotes.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        ForEach(message.emotes, id: \.self) { emote in
                            Text(emote)
                                .font(.title3)
                        }
                    }
                }
            }

            Spacer()

            // Actions (visible on hover)
            if isHovered || isSelected {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button(action: onReply) {
                        Image(systemName: "arrowshape.turn.up.left")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.6))

                    Button(action: onModerate) {
                        Image(systemName: "flag")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.white.opacity(0.6))
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColorFor(message, isHovered: isHovered, isSelected: isSelected))
        )
    }

    private func backgroundColorFor(_ message: UnifiedChatMessage, isHovered: Bool, isSelected: Bool) -> Color {
        if isSelected {
            return Color.white.opacity(0.15)
        } else if isHovered {
            return Color.white.opacity(0.08)
        } else if message.isHighlighted {
            return message.platform.color.opacity(0.1)
        } else {
            return Color.white.opacity(0.02)
        }
    }
}

// MARK: - Badge View
struct BadgeView: View {
    let badge: ChatBadge

    var body: some View {
        Text(badge.label)
            .font(.system(size: 10))
            .fontWeight(.bold)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badge.color)
            .foregroundColor(.white)
            .cornerRadius(DesignSystem.Radius.sm)
    }
}

// MARK: - Message Input Bar
struct MessageInputBar: View {
    @ObservedObject private var theme = UIThemeManager.shared
    @Binding var messageText: String
    let selectedPlatform: ChatPlatform?
    let onSend: (ChatPlatform?) -> Void

    @State private var selectedEmote: String?
    @State private var showEmotePicker = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Platform selector for sending
            Menu {
                Button("Send to All") {
                    onSend(nil)
                }

                Divider()

                ForEach(ChatPlatform.allCases, id: \.self) { platform in
                    Button("Send to \(platform.rawValue)") {
                        onSend(platform)
                    }
                }
            } label: {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: selectedPlatform?.icon ?? "square.grid.2x2")
                    Text(selectedPlatform?.rawValue ?? "All")
                        .font(.caption)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(theme.chatMessageBg.opacity(0.5))
                .cornerRadius(DesignSystem.Radius.md)
            }
            .menuStyle(.borderlessButton)

            // Message input
            HStack {
                TextField("Type a message...", text: $messageText)
                    .textFieldStyle(.plain)
                    .foregroundColor(.white)
                    .onSubmit {
                        if !messageText.isEmpty {
                            onSend(selectedPlatform)
                        }
                    }

                Button(action: { showEmotePicker.toggle() }) {
                    Image(systemName: "face.smiling")
                        .foregroundColor(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showEmotePicker) {
                    EmotePickerView(onSelect: { emote in
                        messageText += " \(emote) "
                        showEmotePicker = false
                    })
                    .frame(width: 300, height: 400)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color.white.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.lg)

            // Send button
            Button(action: { onSend(selectedPlatform) }) {
                Image(systemName: "paperplane.fill")
                    .foregroundColor(.white)
            }
            .buttonStyle(.borderedProminent)
            .disabled(messageText.isEmpty)
        }
    }
}

// MARK: - Moderation Panel
struct ModerationPanel: View {
    @ObservedObject private var theme = UIThemeManager.shared
    @Binding var selectedMessage: UnifiedChatMessage?
    let viewers: [ChatViewer]
    let onBan: (ChatViewer) -> Void
    let onTimeout: (ChatViewer, Int) -> Void
    let onDelete: (UnifiedChatMessage) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack {
                Text("Moderation")
                    .font(.headline)
                    .foregroundColor(.white)
                Spacer()
            }
            .padding()
            .background(Color.orange.opacity(0.2))

            if let message = selectedMessage {
                // Selected message actions
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    Text("Selected Message")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text(message.username)
                            .fontWeight(.semibold)
                            .foregroundColor(message.userColor)
                        Text(message.content)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding()
                    .background(theme.chatColor.opacity(theme.chatOpacity * 0.7))
                    .cornerRadius(DesignSystem.Radius.lg)

                    // Moderation actions
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        Button(action: { onDelete(message) }) {
                            Label("Delete Message", systemImage: "trash")
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.borderless)
                        .foregroundColor(.red)

                        if let viewer = viewers.first(where: { $0.username == message.username }) {
                            Button(action: { onTimeout(viewer, 300) }) {
                                Label("Timeout 5 min", systemImage: "clock")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.orange)

                            Button(action: { onBan(viewer) }) {
                                Label("Ban User", systemImage: "person.fill.xmark")
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.borderless)
                            .foregroundColor(.red)
                        }
                    }
                }
                .padding()
            }

            Divider()

            // Active viewers list
            Text("Active Viewers (\(viewers.count))")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
                .padding(.horizontal)
                .padding(.top)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    ForEach(viewers) { viewer in
                        HStack {
                            Circle()
                                .fill(viewer.platform.color)
                                .frame(width: 8, height: 8)

                            Text(viewer.username)
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.8))

                            Spacer()

                            if viewer.isModerator {
                                Image(systemName: "shield.fill")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.vertical, 4)
                    }
                }
            }

            Spacer()
        }
        .background(theme.sidebarColor.opacity(theme.sidebarOpacity))
    }
}

// MARK: - Emote Picker
struct EmotePickerView: View {
    let onSelect: (String) -> Void

    let emotes = ["😀", "😂", "😍", "🤔", "😎", "🔥", "💯", "👍", "👎", "❤️",
                  "💜", "💚", "💙", "🎮", "🎯", "🎨", "🎵", "🎬", "📺", "💬"]

    var body: some View {
        VStack {
            Text("Emotes")
                .font(.headline)
                .padding()

            LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 5), spacing: DesignSystem.Spacing.sm) {
                ForEach(emotes, id: \.self) { emote in
                    Button(emote) {
                        onSelect(emote)
                    }
                    .font(.title)
                    .buttonStyle(.plain)
                }
            }
            .padding()

            Spacer()
        }
    }
}

// MARK: - Data Models
public enum ChatPlatform: String, CaseIterable {
    case twitch = "Twitch"
    case youtube = "YouTube"
    case tiktok = "TikTok"
    case kick = "Kick"
    case discord = "Discord"
    case facebook = "Facebook"
    case instagram = "Instagram"

    var icon: String {
        switch self {
        case .twitch: return "tv"
        case .youtube: return "play.rectangle"
        case .tiktok: return "music.note"
        case .kick: return "bolt.fill"
        case .discord: return "bubble.left.and.bubble.right"
        case .facebook: return "person.2"
        case .instagram: return "camera"
        }
    }

    var color: Color {
        switch self {
        case .twitch: return .purple
        case .youtube: return .red
        case .tiktok: return .pink
        case .kick: return .green
        case .discord: return Color(red: 0.33, green: 0.36, blue: 0.95)
        case .facebook: return .blue
        case .instagram: return .orange
        }
    }
}

struct PlatformChatInfo: Identifiable {
    let id = UUID()
    let type: ChatPlatform
    let name: String
    let icon: String
    let color: Color
    let viewerCount: Int
    let messageCount: Int
    let isConnected: Bool
}

struct UnifiedChatMessage: Identifiable {
    let id = UUID()
    let platform: ChatPlatform
    let username: String
    let content: String
    let timestamp: Date
    let userColor: Color
    let badges: [ChatBadge]
    let emotes: [String]
    let isHighlighted: Bool
}

struct ChatBadge: Hashable {
    let label: String
    let color: Color

    func hash(into hasher: inout Hasher) {
        hasher.combine(label)
    }

    static func == (lhs: ChatBadge, rhs: ChatBadge) -> Bool {
        lhs.label == rhs.label
    }
}

struct ChatViewer: Identifiable {
    let id = UUID()
    let username: String
    let platform: ChatPlatform
    let isModerator: Bool
    let isSubscriber: Bool
}

// MARK: - Chat Manager
@MainActor
class MultiPlatformChatManager: ObservableObject {
    @Published var messages: [UnifiedChatMessage] = []
    @Published var platforms: [PlatformChatInfo] = []
    @Published var activeViewers: [ChatViewer] = []
    @Published var totalViewers = 0
    @Published var totalMessages = 0

    init() {
        loadSampleData()
    }

    func connectToAllPlatforms() {
        // Connect to all platforms
    }

    func sendMessage(_ text: String, to platform: ChatPlatform?) {
        // Send message to platform(s)
    }

    func refreshChats() {
        // Refresh all chats
    }

    func banUser(_ user: ChatViewer) {
        // Ban user
    }

    func timeoutUser(_ user: ChatViewer, duration: Int) {
        // Timeout user
    }

    func deleteMessage(_ message: UnifiedChatMessage) {
        messages.removeAll { $0.id == message.id }
    }

    private func loadSampleData() {
        // Sample platforms
        platforms = [
            PlatformChatInfo(type: .twitch, name: "Twitch", icon: "tv", color: .purple, viewerCount: 3241, messageCount: 892, isConnected: true),
            PlatformChatInfo(type: .youtube, name: "YouTube", icon: "play.rectangle", color: .red, viewerCount: 2156, messageCount: 456, isConnected: true),
            PlatformChatInfo(type: .tiktok, name: "TikTok", icon: "music.note", color: .pink, viewerCount: 8924, messageCount: 2341, isConnected: true),
            PlatformChatInfo(type: .kick, name: "Kick", icon: "bolt.fill", color: .green, viewerCount: 892, messageCount: 234, isConnected: false),
            PlatformChatInfo(type: .discord, name: "Discord", icon: "bubble.left.and.bubble.right", color: Color(red: 0.33, green: 0.36, blue: 0.95), viewerCount: 342, messageCount: 1234, isConnected: true),
            PlatformChatInfo(type: .facebook, name: "Facebook", icon: "person.2", color: .blue, viewerCount: 1234, messageCount: 123, isConnected: true),
            PlatformChatInfo(type: .instagram, name: "Instagram", icon: "camera", color: .orange, viewerCount: 4562, messageCount: 567, isConnected: true)
        ]

        // Sample messages
        messages = [
            UnifiedChatMessage(platform: .twitch, username: "GamerPro2024", content: "This speedrun is insane!", timestamp: Date(), userColor: .purple, badges: [ChatBadge(label: "SUB", color: .purple)], emotes: ["🔥"], isHighlighted: false),
            UnifiedChatMessage(platform: .youtube, username: "TechNinja", content: "First time watching, love the content!", timestamp: Date().addingTimeInterval(-30), userColor: .red, badges: [], emotes: ["❤️"], isHighlighted: false),
            UnifiedChatMessage(platform: .tiktok, username: "ViralKing", content: "POG POG POG", timestamp: Date().addingTimeInterval(-60), userColor: .pink, badges: [ChatBadge(label: "VIP", color: .gold)], emotes: ["😎", "💯"], isHighlighted: true),
            UnifiedChatMessage(platform: .discord, username: "ModeratorMike", content: "Remember to follow the chat rules everyone!", timestamp: Date().addingTimeInterval(-90), userColor: .green, badges: [ChatBadge(label: "MOD", color: .green)], emotes: [], isHighlighted: false),
            UnifiedChatMessage(platform: .twitch, username: "SpeedRunner", content: "What's your PB for this game?", timestamp: Date().addingTimeInterval(-120), userColor: .blue, badges: [], emotes: [], isHighlighted: false),
        ]

        // Calculate totals
        totalViewers = platforms.reduce(0) { $0 + $1.viewerCount }
        totalMessages = platforms.reduce(0) { $0 + $1.messageCount }

        // Sample viewers
        activeViewers = [
            ChatViewer(username: "ModeratorMike", platform: .discord, isModerator: true, isSubscriber: true),
            ChatViewer(username: "GamerPro2024", platform: .twitch, isModerator: false, isSubscriber: true),
            ChatViewer(username: "TechNinja", platform: .youtube, isModerator: false, isSubscriber: false),
        ]
    }
}

extension Color {
    static let gold = Color(red: 1, green: 0.84, blue: 0)
}