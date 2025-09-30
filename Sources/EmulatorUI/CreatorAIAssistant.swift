import SwiftUI

// MARK: - Creator AI Assistant
struct CreatorAIAssistant: View {
    @ObservedObject var calendarManager: ContentCalendarManager
    @Binding var selectedDate: Date
    @Binding var selectedEvent: ScheduledContent?
    @Binding var showingEventSheet: Bool

    @StateObject private var aiChat = CreatorAIChatManager()
    @State private var messageText = ""
    @State private var showingSuggestions = true
    @State private var isThinking = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "cpu.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                    .scaleEffect(isThinking ? 1.1 : 1.0)
                    .animation(isThinking ? Animation.easeInOut(duration: 1).repeatForever(autoreverses: true) : .default, value: isThinking)

                VStack(alignment: .leading, spacing: 2) {
                    Text("AI Creator Assistant")
                        .font(.headline)
                    Text(aiChat.currentMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Mode Selector
                Menu {
                    ForEach(AIAssistantMode.allCases, id: \.self) { mode in
                        Button(action: { aiChat.currentMode = mode }) {
                            Label(mode.rawValue, systemImage: mode.icon)
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            .padding()
            .background(Color.blue.opacity(0.05))

            Divider()

            // Chat Messages
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        // Welcome Message
                        if aiChat.messages.isEmpty {
                            WelcomeMessageView(mode: aiChat.currentMode)
                                .transition(.opacity)
                        }

                        // Chat Messages
                        ForEach(aiChat.messages) { message in
                            MessageBubbleView(message: message)
                                .id(message.id)
                        }

                        // Typing Indicator
                        if isThinking {
                            TypingIndicatorView()
                                .transition(.opacity)
                        }

                        // Spacer for scroll
                        Color.clear
                            .frame(height: 1)
                            .id("bottom")
                    }
                    .padding()
                    .onChange(of: aiChat.messages.count) { _ in
                        withAnimation {
                            proxy.scrollTo("bottom", anchor: .bottom)
                        }
                    }
                }
            }

            // Quick Suggestions
            if showingSuggestions {
                QuickSuggestionsView(
                    suggestions: aiChat.getCurrentSuggestions(),
                    onSelect: { suggestion in
                        messageText = suggestion
                        sendMessage()
                    }
                )
                .padding(.horizontal)
                .transition(.move(edge: .bottom))
            }

            Divider()

            // Context Info Bar
            ContextInfoBar(
                selectedDate: selectedDate,
                upcomingCount: calendarManager.upcomingEvents.count,
                weeklyStreams: calendarManager.weeklyStreamCount
            )

            Divider()

            // Input Area
            HStack(spacing: DesignSystem.Spacing.md) {
                // Attachment Button
                Menu {
                    Button(action: { aiChat.attachCalendarContext(from: calendarManager) }) {
                        Label("Attach Calendar Data", systemImage: "calendar")
                    }
                    Button(action: { aiChat.attachAnalytics() }) {
                        Label("Attach Analytics", systemImage: "chart.line.uptrend.xyaxis")
                    }
                    Button(action: { aiChat.attachContentIdeas() }) {
                        Label("Attach Content Ideas", systemImage: "lightbulb")
                    }
                } label: {
                    Image(systemName: "paperclip.circle.fill")
                        .font(.title2)
                        .foregroundColor(.blue)
                }

                // Text Input
                TextField("Ask anything about content creation...", text: $messageText, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...3)
                    .onSubmit {
                        sendMessage()
                    }

                // Send Button
                Button(action: sendMessage) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(messageText.isEmpty ? .gray : .blue)
                }
                .disabled(messageText.isEmpty || isThinking)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
        }
        .onAppear {
            aiChat.initializeWithContext(calendarManager)
        }
    }

    private func sendMessage() {
        guard !messageText.isEmpty else { return }

        let userMessage = messageText
        messageText = ""

        Task {
            isThinking = true
            await aiChat.processMessage(userMessage, context: calendarManager)
            isThinking = false

            // Check if AI suggested creating an event
            if let suggestedEvent = aiChat.suggestedEvent {
                selectedEvent = suggestedEvent
                showingEventSheet = true
                aiChat.suggestedEvent = nil
            }
        }
    }
}

// MARK: - AI Chat Manager
@MainActor
class CreatorAIChatManager: ObservableObject {
    @Published var messages: [AIMessage] = []
    @Published var currentMode = AIAssistantMode.scheduling
    @Published var suggestedEvent: ScheduledContent?

    func initializeWithContext(_ manager: ContentCalendarManager) {
        // Add initial greeting
        let greeting = AIMessage(
            content: "👋 Hi! I'm your AI content assistant. I can help you schedule posts, analyze performance, generate content ideas, and optimize your social media strategy. What would you like to work on today?",
            isUser: false,
            type: .greeting
        )
        messages.append(greeting)
    }

    func processMessage(_ message: String, context: ContentCalendarManager) async {
        // Add user message
        let userMessage = AIMessage(content: message, isUser: true, type: .text)
        messages.append(userMessage)

        // Generate AI response based on mode and context
        let response = await generateResponse(for: message, context: context)
        messages.append(response)
    }

    private func generateResponse(for message: String, context: ContentCalendarManager) async -> AIMessage {
        // Simulate AI processing delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        let lowercased = message.lowercased()

        // Context-aware responses
        if lowercased.contains("schedule") || lowercased.contains("post") {
            return AIMessage(
                content: "I can help you schedule a post! Based on your analytics, the best time to post would be between 7-9 PM EST. Your audience is most active then. Would you like me to:\n\n1. Create a new scheduled post\n2. Suggest content ideas for today\n3. Review your posting schedule\n\nJust let me know what you'd prefer!",
                isUser: false,
                type: .suggestion,
                actions: [
                    AIAction(title: "Create Post", type: .createPost),
                    AIAction(title: "Content Ideas", type: .contentIdeas),
                    AIAction(title: "View Schedule", type: .viewSchedule)
                ]
            )
        } else if lowercased.contains("idea") || lowercased.contains("content") {
            return AIMessage(
                content: "Here are some trending content ideas for your niche:\n\n🎮 **Gaming Content:**\n• \"Day in the life\" speedrun attempts\n• Reacting to viewer gameplay clips\n• Nostalgic game retrospectives\n\n📈 **Trending Formats:**\n• Short-form tutorials (Reels/TikTok)\n• Behind-the-scenes content\n• Community challenges\n\n💡 **This Week's Opportunity:**\nThe #RetroGaming hashtag is trending - perfect for your N64 content!",
                isUser: false,
                type: .contentIdeas
            )
        } else if lowercased.contains("analytic") || lowercased.contains("performance") {
            return AIMessage(
                content: "📊 **Performance Analysis:**\n\n**Last 7 Days:**\n• Total Reach: 125.3K (+12.5%)\n• Engagement Rate: 4.7% (above average!)\n• Best Performing: Tuesday's speedrun clip\n\n**Key Insights:**\n• Your Zelda content gets 3x more engagement\n• Videos under 60 seconds perform best\n• Weekend streams have highest viewer retention\n\n**Recommendation:**\nFocus on short-form Zelda content this week, and schedule a weekend stream for maximum impact.",
                isUser: false,
                type: .analytics
            )
        } else if lowercased.contains("help") {
            return AIMessage(
                content: "I'm here to help! I can assist with:\n\n📅 **Scheduling:** Optimal posting times, content calendar management\n💡 **Content Ideas:** Trending topics, hashtags, formats\n📊 **Analytics:** Performance insights, growth strategies\n🎯 **Strategy:** Audience targeting, platform optimization\n🤝 **Collaborations:** Finding partners, campaign ideas\n💰 **Monetization:** Sponsorship tips, revenue optimization\n\nWhat area would you like to focus on?",
                isUser: false,
                type: .help
            )
        } else {
            return AIMessage(
                content: "I understand you're asking about \"\(message)\". Let me help you with that!\n\nBased on your content calendar and recent performance, here's my suggestion:\n\nConsider creating content around this topic during your peak engagement hours (7-9 PM EST). Your audience responds well to authentic, educational content.\n\nWould you like me to help you create a content plan around this topic?",
                isUser: false,
                type: .general
            )
        }
    }

    func getCurrentSuggestions() -> [String] {
        switch currentMode {
        case .scheduling:
            return [
                "What's the best time to post today?",
                "Schedule a gaming stream",
                "Review this week's calendar",
                "Find content gaps"
            ]
        case .contentIdeas:
            return [
                "Give me trending topics",
                "Suggest hashtags for N64 content",
                "What should I post about?",
                "Create a content series"
            ]
        case .analytics:
            return [
                "How did last week perform?",
                "What content works best?",
                "Show engagement trends",
                "Compare platform performance"
            ]
        case .strategy:
            return [
                "How to grow my audience?",
                "Optimize posting schedule",
                "Improve engagement rate",
                "Platform-specific tips"
            ]
        case .automation:
            return [
                "Set up auto-posting",
                "Create engagement rules",
                "Schedule recurring content",
                "Automate responses"
            ]
        }
    }

    func attachCalendarContext(from manager: ContentCalendarManager) {
        let contextMessage = AIMessage(
            content: "📅 I've analyzed your calendar. You have \(manager.upcomingEvents.count) upcoming posts and \(manager.weeklyStreamCount) streams scheduled this week. Let me help you optimize your schedule!",
            isUser: false,
            type: .context
        )
        messages.append(contextMessage)
    }

    func attachAnalytics() {
        let analyticsMessage = AIMessage(
            content: "📊 Analytics attached! I can see your performance trends, best-performing content, and audience insights. Ask me anything about your metrics!",
            isUser: false,
            type: .context
        )
        messages.append(analyticsMessage)
    }

    func attachContentIdeas() {
        let ideasMessage = AIMessage(
            content: "💡 I've loaded trending topics and content ideas for your niche. Ready to brainstorm some viral content!",
            isUser: false,
            type: .context
        )
        messages.append(ideasMessage)
    }
}

// MARK: - Supporting Views
struct WelcomeMessageView: View {
    let mode: AIAssistantMode

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Mode-specific welcome
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                HStack {
                    Image(systemName: mode.icon)
                        .font(.title2)
                        .foregroundColor(.blue)

                    Text(mode.welcomeTitle)
                        .font(.headline)
                }

                Text(mode.welcomeMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.05))
            .cornerRadius(DesignSystem.Radius.xxl)

            // Quick Start Options
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Quick Start:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                ForEach(mode.quickStartOptions, id: \.self) { option in
                    HStack {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.caption)
                            .foregroundColor(.blue)
                        Text(option)
                            .font(.caption)
                    }
                }
            }
        }
    }
}

struct MessageBubbleView: View {
    let message: AIMessage

    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }

            VStack(alignment: message.isUser ? .trailing : .leading, spacing: DesignSystem.Spacing.sm) {
                // Message Content
                Text(message.content)
                    .padding(DesignSystem.Spacing.md)
                    .background(message.isUser ? Color.blue : Color.gray.opacity(0.15))
                    .foregroundColor(message.isUser ? .white : .primary)
                    .cornerRadius(16)

                // Action Buttons
                if let actions = message.actions {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(actions) { action in
                            Button(action.title) {
                                action.execute()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }

                // Timestamp
                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: 280, alignment: message.isUser ? .trailing : .leading)

            if !message.isUser {
                Spacer()
            }
        }
    }
}

struct TypingIndicatorView: View {
    @State private var animationPhase = 0

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(Color.gray)
                    .frame(width: 8, height: 8)
                    .scaleEffect(animationPhase == index ? 1.2 : 0.8)
                    .animation(
                        Animation.easeInOut(duration: 0.6)
                            .repeatForever()
                            .delay(Double(index) * 0.2),
                        value: animationPhase
                    )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.15))
        .cornerRadius(DesignSystem.Radius.xxl)
        .onAppear {
            animationPhase = 1
        }
    }
}

struct QuickSuggestionsView: View {
    let suggestions: [String]
    let onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button(action: { onSelect(suggestion) }) {
                        Text(suggestion)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.blue.opacity(0.1))
                            .foregroundColor(.blue)
                            .cornerRadius(DesignSystem.Radius.xxl)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(height: 32)
    }
}

struct ContextInfoBar: View {
    let selectedDate: Date
    let upcomingCount: Int
    let weeklyStreams: Int

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            // Date Context
            Label(selectedDate.formatted(.dateTime.weekday(.wide).day()), systemImage: "calendar")
                .font(.caption)

            Divider()
                .frame(height: 16)

            // Upcoming Events
            Label("\(upcomingCount) upcoming", systemImage: "clock")
                .font(.caption)

            Divider()
                .frame(height: 16)

            // Weekly Stats
            Label("\(weeklyStreams) this week", systemImage: "chart.bar")
                .font(.caption)

            Spacer()
        }
        .foregroundColor(.secondary)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Data Models
struct AIMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    let type: MessageType
    let timestamp = Date()
    var actions: [AIAction]?

    enum MessageType {
        case text, greeting, suggestion, analytics, contentIdeas, help, context, general
    }
}

struct AIAction: Identifiable {
    let id = UUID()
    let title: String
    let type: ActionType
    var handler: (() -> Void)?

    enum ActionType {
        case createPost, contentIdeas, viewSchedule, analytics, optimize
    }

    func execute() {
        handler?()
    }
}

enum AIAssistantMode: String, CaseIterable {
    case scheduling = "Scheduling Assistant"
    case contentIdeas = "Content Ideas"
    case analytics = "Analytics Insights"
    case strategy = "Growth Strategy"
    case automation = "Automation Helper"

    var icon: String {
        switch self {
        case .scheduling: return "calendar.badge.plus"
        case .contentIdeas: return "lightbulb.fill"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .strategy: return "target"
        case .automation: return "gearshape.2.fill"
        }
    }

    var description: String {
        switch self {
        case .scheduling: return "Optimize your posting schedule"
        case .contentIdeas: return "Get trending content suggestions"
        case .analytics: return "Analyze your performance"
        case .strategy: return "Grow your audience"
        case .automation: return "Set up automated workflows"
        }
    }

    var welcomeTitle: String {
        switch self {
        case .scheduling: return "Scheduling Mode"
        case .contentIdeas: return "Creative Mode"
        case .analytics: return "Analytics Mode"
        case .strategy: return "Strategy Mode"
        case .automation: return "Automation Mode"
        }
    }

    var welcomeMessage: String {
        switch self {
        case .scheduling:
            return "I'll help you find the perfect times to post and manage your content calendar efficiently."
        case .contentIdeas:
            return "Let's brainstorm viral content ideas and trending topics for your audience."
        case .analytics:
            return "I'll analyze your performance metrics and provide actionable insights."
        case .strategy:
            return "Together we'll develop strategies to grow your audience and increase engagement."
        case .automation:
            return "I'll help you set up time-saving automation workflows for your content."
        }
    }

    var quickStartOptions: [String] {
        switch self {
        case .scheduling:
            return ["Schedule for peak hours", "Weekly calendar review", "Batch scheduling"]
        case .contentIdeas:
            return ["Trending hashtags", "Content pillars", "Viral formats"]
        case .analytics:
            return ["Performance report", "Best content", "Growth trends"]
        case .strategy:
            return ["Audience analysis", "Competition research", "Growth tactics"]
        case .automation:
            return ["Auto-posting", "Response templates", "Content recycling"]
        }
    }
}