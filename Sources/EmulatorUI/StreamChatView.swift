import SwiftUI
import Combine
import EmulatorKit

/// NN/g Redesigned Stream Chat Interface
public struct StreamChatView: View {
    @StateObject private var chatManager = StreamChatManager()
    @State private var messageText = ""
    @State private var isExpanded = true
    @State private var showingChatSettings = false
    @State private var selectedMessageFilter = MessageFilter.all
    @AppStorage("chatFontSize") private var fontSizeIndex = 1 // 0=small, 1=medium, 2=large
    @AppStorage("chatNotifications") private var notificationsEnabled = true
    @AppStorage("streamingPlatform") private var platform = "twitch"
    @AppStorage("streamingChannel") private var channelName = ""

    private let fontSizes: [CGFloat] = [11, 13, 16]

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // NN/g: Clear Status Header with Visual Hierarchy
            ChatHeaderView(
                isConnected: chatManager.isConnected,
                viewerCount: chatManager.viewerCount,
                platform: platform,
                isExpanded: $isExpanded,
                onSettingsTap: { showingChatSettings = true }
            )

            if isExpanded {
                // NN/g: Filter Controls for User Control
                ChatFilterBar(selectedFilter: $selectedMessageFilter)

                // NN/g: Accessible Message Area with Clear Visual Design
                ChatMessagesArea(
                    messages: filteredMessages,
                    fontSize: fontSizes[fontSizeIndex],
                    isEmpty: chatManager.messages.isEmpty
                )

                // NN/g: Clear Message Input with Visual Affordances
                MessageInputArea(
                    messageText: $messageText,
                    isConnected: chatManager.isConnected,
                    onSend: sendMessage,
                    onQuickReaction: { reaction in
                        sendQuickReaction(reaction)
                    }
                )

                // NN/g: Essential Actions Only in Footer
                ChatActionsFooter(
                    isConnected: chatManager.isConnected,
                    onReconnect: { chatManager.toggleConnection() },
                    onClear: { showClearConfirmation() },
                    onSettings: { showingChatSettings = true }
                )
            }
        }
        .frame(width: isExpanded ? 320 : 48) // Increased width for better readability
        .frame(maxHeight: .infinity)
        .background(.ultraThinMaterial)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .sheet(isPresented: $showingChatSettings) {
            ChatSettingsSheet(
                fontSizeIndex: $fontSizeIndex,
                notificationsEnabled: $notificationsEnabled,
                chatManager: chatManager
            )
        }
        .onAppear { chatManager.startIfEnabled() }
    }

    // NN/g: Filter messages for better user control
    private var filteredMessages: [ChatMessage] {
        switch selectedMessageFilter {
        case .all:
            return chatManager.messages
        case .mentions:
            return chatManager.messages.filter { $0.isHighlighted }
        case .moderators:
            return chatManager.messages.filter { $0.userBadge?.contains("star") == true }
        case .recent:
            return Array(chatManager.messages.suffix(50))
        }
    }

    private func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        chatManager.sendMessage(messageText)
        AnalyticsManager.shared.recordChatMessage()
        messageText = ""
    }

    private func sendQuickReaction(_ reaction: String) {
        chatManager.sendMessage(reaction)
        AnalyticsManager.shared.recordChatMessage()
    }

    private func showClearConfirmation() {
        // Show confirmation dialog for destructive action (NN/g: Error prevention)
        let alert = NSAlert()
        alert.messageText = "Clear Chat History"
        alert.informativeText = "This will remove all messages from the chat. This action cannot be undone."
        alert.addButton(withTitle: "Clear")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        if alert.runModal() == .alertFirstButtonReturn {
            chatManager.clearChat()
        }
    }
}

/// Individual chat message view
struct ChatMessageView: View {
    let message: ChatMessage

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.xs) {
            // User badge/icon
            if let badge = message.userBadge {
                Image(systemName: badge)
                    .font(.system(size: 10))
                    .foregroundColor(message.userColor ?? .purple)
            }

            VStack(alignment: .leading, spacing: 2) {
                // Username
                Text(message.username)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(message.userColor ?? .purple)

                // Message text
                Text(message.text)
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()

            // Timestamp
            Text(message.timestamp.formatted(date: .omitted, time: .shortened))
                .font(.system(size: 9))
                .foregroundColor(.gray)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(message.isHighlighted ? Color.purple.opacity(0.1) : Color.clear)
        .cornerRadius(DesignSystem.Radius.sm)
    }
}

/// Chat message model
struct ChatMessage: Identifiable {
    let id = UUID()
    let username: String
    let text: String
    let timestamp: Date
    let userColor: Color?
    let userBadge: String?
    let isHighlighted: Bool

    init(username: String, text: String, userColor: Color? = nil, userBadge: String? = nil, isHighlighted: Bool = false) {
        self.username = username
        self.text = text
        self.timestamp = Date()
        self.userColor = userColor
        self.userBadge = userBadge
        self.isHighlighted = isHighlighted
    }
}

/// Stream Chat Manager
@MainActor
class StreamChatManager: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var isConnected = false
    @Published var viewerCount = 0

    // Streaming configuration
    @AppStorage("streamingEnabled") private var streamingEnabled = false
    @AppStorage("streamingPlatform") private var platform = "twitch"
    @AppStorage("streamingChannel") private var channelName = ""
    @AppStorage("twitchClientID") private var twitchClientID = ""
    @AppStorage("streamingUsername") private var username = ""
    private let keychain = KeychainManager()

    // AI Assistant
    private let aiAssistant = AIStreamAssistant()

    private var twitch: TwitchChatClient?
    private var viewerTimer: Timer?

    init() {
        setupAINotifications()
        // Show initial system hint
        messages.append(ChatMessage(
            username: "StreamBot",
            text: "Stream chat initialized. Configure streaming in Settings to connect.",
            userColor: .purple,
            userBadge: "sparkles"
        ))
    }

    func sendMessage(_ text: String) {
        let message = ChatMessage(
            username: "You",
            text: text,
            userColor: .blue,
            userBadge: "person.fill"
        )
        messages.append(message)
    }

    func clearChat() {
        messages.removeAll()
    }

    func toggleConnection() {
        if isConnected {
            disconnect()
        } else {
            startIfEnabled()
        }
    }

    func startIfEnabled() {
        guard streamingEnabled else { return }
        guard platform == "twitch", !channelName.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let client = TwitchChatClient()
        self.twitch = client
        let token = keychain.getSecret(for: "streaming_oauth_token")
        client.connect(oauthToken: (token?.isEmpty == false) ? token : nil,
                       username: username.isEmpty ? nil : username,
                       channel: channelName) { [weak self] up in
            Task { @MainActor in self?.isConnected = up }
        } onMessage: { [weak self] msg in
            Task { @MainActor in
                let color = Color.from(hex: msg.colorHex) ?? .purple
                let message = ChatMessage(
                    username: msg.username,
                    text: msg.text,
                    userColor: color,
                    userBadge: "bubble.left",
                    isHighlighted: false
                )
                self?.messages.append(message)
                AnalyticsManager.shared.recordChatMessage()
                // Send some messages to AI
                if msg.text.contains("?") || msg.text.lowercased().contains("how") {
                    self?.processMessageWithAI(message)
                }
            }
        }

        messages.append(ChatMessage(
            username: "System",
            text: "Connecting to Twitch chat…",
            userColor: .gray,
            userBadge: "bolt.horizontal"
        ))

        startViewerPollingIfPossible()
        // Annotate active analytics session with platform/channel
        AnalyticsManager.shared.updateCurrentSession(platform: "twitch", channel: channelName)
    }

    func disconnect() {
        twitch?.disconnect()
        twitch = nil
        isConnected = false
        stopViewerPolling()
        messages.append(ChatMessage(
            username: "System",
            text: "Disconnected from stream chat",
            userColor: .red,
            userBadge: "xmark.circle.fill"
        ))
    }

    // Setup AI notifications
    private func setupAINotifications() {
        NotificationCenter.default.addObserver(
            forName: Notification.Name("AICommentary"),
            object: nil,
            queue: .main
        ) { notification in
            if let commentary = notification.object as? String {
                let message = ChatMessage(
                    username: "AI Commentator",
                    text: commentary,
                    userColor: .cyan,
                    userBadge: "brain",
                    isHighlighted: true
                )
                Task { @MainActor in
                    self.messages.append(message)
                }
            }
        }
    }

    // Process message through AI
    private func processMessageWithAI(_ message: ChatMessage) {
        Task { @MainActor in
            if let aiResponse = await aiAssistant.processChat(message.text, username: message.username) {
                let aiMessage = ChatMessage(
                    username: "AI Assistant",
                    text: aiResponse,
                    userColor: .purple,
                    userBadge: "brain",
                    isHighlighted: true
                )
                self.messages.append(aiMessage)
                AnalyticsManager.shared.recordChatMessage()
            }
        }
    }

    // No-op deinit; connection is managed explicitly
}

// MARK: - Viewer Count Polling & Analytics
extension StreamChatManager {
    private func startViewerPollingIfPossible() {
        stopViewerPolling()
        let token = keychain.getSecret(for: "streaming_oauth_token") ?? ""
        guard !twitchClientID.isEmpty, !token.isEmpty, !channelName.isEmpty else { return }
        viewerTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                if let count = await TwitchHelixService.fetchViewerCount(channel: self.channelName, clientID: self.twitchClientID, oauthToken: token) {
                    self.viewerCount = count
                    AnalyticsManager.shared.recordViewerCount(count)
                }
            }
        }
        // Fire immediately too
        Task { @MainActor in
            if let count = await TwitchHelixService.fetchViewerCount(channel: self.channelName, clientID: self.twitchClientID, oauthToken: token) {
                self.viewerCount = count
                AnalyticsManager.shared.recordViewerCount(count)
            }
        }
    }

    private func stopViewerPolling() {
        viewerTimer?.invalidate()
        viewerTimer = nil
    }
}

// MARK: - Streaming Settings View
public struct StreamingSettingsView: View {
    @AppStorage("streamingEnabled") private var streamingEnabled = false
    @AppStorage("streamingPlatform") private var platform = "twitch"
    @AppStorage("streamingChannel") private var channelName = ""
    @AppStorage("streamingUsername") private var username = ""
    @AppStorage("twitchClientID") private var twitchClientID = ""
    @State private var apiKey: String = ""
    @State private var oauthToken: String = ""
    @State private var testResult: String = "Not Connected"
    @State private var isTesting = false
    private let keychain = KeychainManager()

    public var body: some View {
        Form {
            Section("Streaming Integration") {
                Toggle("Enable Streaming Features", isOn: $streamingEnabled)

                if streamingEnabled {
                    Picker("Platform", selection: $platform) {
                        Text("Twitch").tag("twitch")
                        Text("YouTube").tag("youtube")
                        Text("Facebook Gaming").tag("facebook")
                        Text("Custom RTMP").tag("custom")
                    }

                    TextField("Channel Name", text: $channelName)
                        .textFieldStyle(.roundedBorder)

                    TextField("Username (Twitch)", text: $username)
                        .textFieldStyle(.roundedBorder)

                    SecureField("API Key", text: $apiKey)
                        .textFieldStyle(.roundedBorder)

                    SecureField("OAuth Token", text: $oauthToken)
                        .textFieldStyle(.roundedBorder)

                    TextField("Twitch Client ID (for viewer count)", text: $twitchClientID)
                        .textFieldStyle(.roundedBorder)

                    HStack {
                        Button(isTesting ? "Testing…" : "Test Connection") {
                            guard platform == "twitch" else { return }
                            isTesting = true
                            Task {
                                let ok = await TwitchConnectionTester.test(oauthToken: oauthToken, username: username, channel: channelName)
                                await MainActor.run {
                                    isTesting = false
                                    testResult = ok ? "Connected" : "Failed"
                                }
                            }
                        }
                        .buttonStyle(.bordered)

                        Button("Save Credentials") {
                            _ = keychain.setSecret(apiKey, for: "streaming_api_key")
                            _ = keychain.setSecret(oauthToken, for: "streaming_oauth_token")
                        }
                        .buttonStyle(.borderedProminent)

                        Spacer()

                        Text(testResult)
                            .font(.caption)
                            .foregroundColor(testResult == "Connected" ? .green : .gray)
                    }
                }
            }

            Section("Chat Settings") {
                Toggle("Show Chat", isOn: .constant(true))
                Toggle("Show Viewer Count", isOn: .constant(true))
                Toggle("Enable Chat Sounds", isOn: .constant(false))
                Toggle("Highlight Mentions", isOn: .constant(true))
            }
        }
        .formStyle(.grouped)
        .onAppear {
            apiKey = keychain.getSecret(for: "streaming_api_key") ?? ""
            oauthToken = keychain.getSecret(for: "streaming_oauth_token") ?? ""
        }
    }
}

// MARK: - NN/g Compliant Chat Components

/// Clear chat header with system status visibility
struct ChatHeaderView: View {
    let isConnected: Bool
    let viewerCount: Int
    let platform: String
    @Binding var isExpanded: Bool
    let onSettingsTap: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Platform indicator with clear branding
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: platformIcon)
                    .font(.caption)
                    .foregroundColor(platformColor)

                Text(platform.capitalized)
                    .font(.caption.weight(.medium))
                    .foregroundColor(.primary)
            }

            Spacer()

            // Clear connection status (NN/g: Visibility of system status)
            ConnectionStatusIndicator(isConnected: isConnected)

            // Viewer count when connected
            if isConnected && viewerCount > 0 {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: "eye.fill")
                        .font(.caption2)
                    Text("\(viewerCount)")
                        .font(.caption.monospacedDigit())
                        .fontWeight(.medium)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(.regularMaterial)
                .cornerRadius(DesignSystem.Radius.lg)
            }

            // Settings access
            Button(action: onSettingsTap) {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Chat Settings")

            // Collapse/Expand toggle
            Button(action: { isExpanded.toggle() }) {
                Image(systemName: isExpanded ? "sidebar.trailing" : "sidebar.left")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help(isExpanded ? "Hide Chat" : "Show Chat")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    private var platformIcon: String {
        switch platform.lowercased() {
        case "twitch": return "tv"
        case "youtube": return "play.rectangle"
        case "facebook": return "person.2"
        default: return "tv"
        }
    }

    private var platformColor: Color {
        switch platform.lowercased() {
        case "twitch": return .purple
        case "youtube": return .red
        case "facebook": return .blue
        default: return .purple
        }
    }
}

/// Connection status with clear visual feedback
struct ConnectionStatusIndicator: View {
    let isConnected: Bool
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(isConnected ? Color.green : Color.gray)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating && isConnected ? 1.2 : 1.0)
                .animation(
                    isConnected ? .easeInOut(duration: 1).repeatForever(autoreverses: true) : .default,
                    value: isAnimating
                )

            Text(isConnected ? "Live" : "Offline")
                .font(.caption2.weight(.medium))
                .foregroundColor(isConnected ? .green : .secondary)
        }
        .onAppear { isAnimating = true }
    }
}

/// Message filter bar for user control
struct ChatFilterBar: View {
    @Binding var selectedFilter: MessageFilter

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(MessageFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.displayName,
                        isSelected: selectedFilter == filter
                    ) {
                        selectedFilter = filter
                    }
                }
                Spacer(minLength: 12)
            }
            .padding(.horizontal, 12)
        }
        .frame(height: 32)
        .background(Color(.controlBackgroundColor))
    }
}

/// Filter button with clear selection state
struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.caption.weight(.medium))
                .foregroundColor(isSelected ? .white : .secondary)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : Color.clear)
        )
    }
}

/// Accessible messages area with improved readability
struct ChatMessagesArea: View {
    let messages: [ChatMessage]
    let fontSize: CGFloat
    let isEmpty: Bool

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    if isEmpty {
                        EmptyChatState()
                    } else {
                        ForEach(messages) { message in
                            AccessibleChatMessageView(
                                message: message,
                                fontSize: fontSize
                            )
                            .id(message.id)
                        }
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .onChange(of: messages.count) { _ in
                if let lastMessage = messages.last {
                    withAnimation(.easeOut(duration: 0.3)) {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.textBackgroundColor))
    }
}

/// Empty state with helpful guidance
struct EmptyChatState: View {
    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 32))
                .foregroundColor(.secondary.opacity(0.5))

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("Chat is Ready")
                    .font(.headline)
                    .fontWeight(.medium)

                Text("Messages will appear here when your stream is live")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
}

/// Accessible chat message with improved visual design
struct AccessibleChatMessageView: View {
    let message: ChatMessage
    let fontSize: CGFloat

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.sm) {
            // User indicator with clear visual hierarchy
            UserBadgeView(
                badge: message.userBadge,
                color: message.userColor ?? .purple
            )

            VStack(alignment: .leading, spacing: 2) {
                // Username with clear contrast
                Text(message.username)
                    .font(.system(size: fontSize * 0.85, weight: .semibold))
                    .foregroundColor(message.userColor ?? .purple)

                // Message text with improved readability
                Text(message.text)
                    .font(.system(size: fontSize))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled) // NN/g: User control
            }

            Spacer()

            // Clear timestamp
            Text(message.timestamp.formatted(.dateTime.hour().minute()))
                .font(.system(size: fontSize * 0.7, design: .monospaced))
                .foregroundColor(Color.secondary.opacity(0.6))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(message.isHighlighted ? Color.accentColor.opacity(0.1) : Color.clear)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.username) says \(message.text)")
    }
}

/// Clear user badge with consistent visual design
struct UserBadgeView: View {
    let badge: String?
    let color: Color

    var body: some View {
        Group {
            if let badge = badge {
                Image(systemName: badge)
                    .font(.system(size: 10))
                    .foregroundColor(color)
                    .frame(width: 12, height: 12)
            } else {
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
            }
        }
        .padding(.top, 2)
    }
}

/// Message input with clear affordances and accessibility
struct MessageInputArea: View {
    @Binding var messageText: String
    let isConnected: Bool
    let onSend: () -> Void
    let onQuickReaction: (String) -> Void

    private let quickReactions = ["👍", "❤️", "😂", "😮", "😢", "👏"]

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Quick reactions (NN/g: Efficiency of use)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(quickReactions, id: \.self) { reaction in
                        Button(action: { onQuickReaction(reaction) }) {
                            Text(reaction)
                                .font(.title2)
                        }
                        .buttonStyle(.borderless)
                        .disabled(!isConnected)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(height: 32)

            // Message input field
            HStack(spacing: DesignSystem.Spacing.sm) {
                TextField("Type your message...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .disabled(!isConnected)
                    .onSubmit {
                        onSend()
                    }

                Button(action: onSend) {
                    Image(systemName: "paperplane.fill")
                        .foregroundColor(canSend ? .accentColor : .secondary)
                }
                .buttonStyle(.borderless)
                .disabled(!canSend)
                .help("Send Message")
            }
            .padding(.horizontal, 12)
        }
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }

    private var canSend: Bool {
        isConnected && !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// Essential actions footer with clear functionality
struct ChatActionsFooter: View {
    let isConnected: Bool
    let onReconnect: () -> Void
    let onClear: () -> Void
    let onSettings: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Connection control
            Button(action: onReconnect) {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: isConnected ? "wifi" : "wifi.slash")
                        .font(.caption)
                    Text(isConnected ? "Connected" : "Reconnect")
                        .font(.caption.weight(.medium))
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Spacer()

            // Clear chat (with confirmation)
            Button(action: onClear) {
                Image(systemName: "trash")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Clear Chat History")

            // Settings access
            Button(action: onSettings) {
                Image(systemName: "gear")
                    .font(.caption)
            }
            .buttonStyle(.borderless)
            .help("Chat Settings")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
    }
}

/// Chat settings sheet with accessibility options
struct ChatSettingsSheet: View {
    @Binding var fontSizeIndex: Int
    @Binding var notificationsEnabled: Bool
    let chatManager: StreamChatManager
    @Environment(\.dismiss) var dismiss

    private let fontSizeLabels = ["Small", "Medium", "Large"]

    var body: some View {
        NavigationView {
            Form {
                Section("Display") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Font Size")
                            .font(.headline)

                        Picker("Font Size", selection: $fontSizeIndex) {
                            ForEach(0..<fontSizeLabels.count, id: \.self) { index in
                                Text(fontSizeLabels[index]).tag(index)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                }

                Section("Notifications") {
                    Toggle("Enable Chat Notifications", isOn: $notificationsEnabled)
                    Toggle("Sound Effects", isOn: .constant(false)) // Placeholder
                }

                Section("Connection") {
                    HStack {
                        Text("Status")
                        Spacer()
                        Text(chatManager.isConnected ? "Connected" : "Disconnected")
                            .foregroundColor(chatManager.isConnected ? .green : .secondary)
                    }

                    if chatManager.viewerCount > 0 {
                        HStack {
                            Text("Viewers")
                            Spacer()
                            Text("\(chatManager.viewerCount)")
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("Chat Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .frame(width: 400, height: 500)
    }
}

// MARK: - Supporting Types

enum MessageFilter: CaseIterable {
    case all, mentions, moderators, recent

    var displayName: String {
        switch self {
        case .all: return "All"
        case .mentions: return "Mentions"
        case .moderators: return "Mods"
        case .recent: return "Recent"
        }
    }
}
