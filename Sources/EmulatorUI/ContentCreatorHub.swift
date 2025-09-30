import SwiftUI
import Charts
import PhotosUI

// MARK: - Main Content Creator Hub
struct ContentCreatorHub: View {
    @StateObject private var hubManager = ContentCreatorHubManager()
    @State private var selectedTab = CreatorHubTab.dashboard
    @State private var showingQuickPost = false

    var body: some View {
        HSplitView {
            // Left Sidebar Navigation
            CreatorHubSidebar(selectedTab: $selectedTab)
                .frame(width: 200)

            // Main Content Area
            VStack(spacing: 0) {
                // Top Action Bar
                CreatorHubActionBar(
                    showingQuickPost: $showingQuickPost,
                    hubManager: hubManager
                )
                .padding()
                .background(Color.gray.opacity(0.05))

                Divider()

                // Content View based on selected tab
                Group {
                    switch selectedTab {
                    case .dashboard:
                        CreatorDashboard(manager: hubManager)
                    case .calendar:
                        EnhancedContentCalendar(manager: hubManager)
                    case .content:
                        ContentLibrary(manager: hubManager)
                    case .analytics:
                        AnalyticsDashboard(manager: hubManager)
                    case .inbox:
                        UnifiedInbox(manager: hubManager)
                    case .automation:
                        AutomationStudio(manager: hubManager)
                    case .collaborations:
                        CollaborationCenter(manager: hubManager)
                    case .monetization:
                        MonetizationDashboard(manager: hubManager)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .sheet(isPresented: $showingQuickPost) {
            QuickPostComposer(manager: hubManager)
        }
    }
}

// MARK: - Sidebar Navigation
struct CreatorHubSidebar: View {
    @Binding var selectedTab: CreatorHubTab

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Profile Section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Image(systemName: "person.crop.circle.fill")
                    .font(.system(size: 48))
                    .foregroundColor(.blue)

                Text("Creator Studio")
                    .font(.headline)

                Text("Professional")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Navigation Items
            ScrollView {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(CreatorHubTab.allCases, id: \.self) { tab in
                        SidebarButton(
                            title: tab.title,
                            icon: tab.icon,
                            isSelected: selectedTab == tab
                        ) {
                            selectedTab = tab
                        }
                    }
                }
                .padding(.vertical, 8)
            }

            Spacer()

            // Quick Stats
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Label("12.5K followers", systemImage: "person.2")
                Label("89% engagement", systemImage: "chart.line.uptrend.xyaxis")
                Label("5 scheduled", systemImage: "calendar")
            }
            .font(.caption)
            .padding()
            .background(Color.blue.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.lg)
            .padding()
        }
        .background(Color.gray.opacity(0.05))
    }
}

// MARK: - Enhanced Calendar View
struct EnhancedContentCalendar: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var selectedDate = Date()
    @State private var viewMode = CalendarViewMode.month
    @State private var showingPostComposer = false
    @State private var selectedPost: SocialMediaPost?
    @State private var draggedPost: SocialMediaPost?

    var body: some View {
        VStack(spacing: 0) {
            // Calendar Controls
            HStack {
                // View Mode Selector
                Picker("View Mode", selection: $viewMode) {
                    Label("Day", systemImage: "calendar.day.timeline.left").tag(CalendarViewMode.day)
                    Label("Week", systemImage: "calendar.week").tag(CalendarViewMode.week)
                    Label("Month", systemImage: "calendar.month").tag(CalendarViewMode.month)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 300)

                Spacer()

                // Platform Filters
                HStack(spacing: DesignSystem.Spacing.sm) {
                    ForEach(SocialPlatform.allCases, id: \.self) { platform in
                        PlatformFilterButton(
                            platform: platform,
                            isActive: manager.activePlatformFilters.contains(platform)
                        ) {
                            manager.togglePlatformFilter(platform)
                        }
                    }
                }

                Spacer()

                // Quick Actions
                Button(action: { showingPostComposer = true }) {
                    Label("New Post", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)

                Menu {
                    Button("Import from CSV") { manager.importFromCSV() }
                    Button("Sync with Google Calendar") { manager.syncWithGoogle() }
                    Button("Export Schedule") { manager.exportSchedule() }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
            .padding()

            Divider()

            // Calendar Grid
            GeometryReader { geometry in
                switch viewMode {
                case .day:
                    DayViewCalendar(
                        selectedDate: $selectedDate,
                        posts: manager.getPostsForDate(selectedDate),
                        onPostTap: { post in selectedPost = post }
                    )
                case .week:
                    WeekViewCalendar(
                        selectedDate: $selectedDate,
                        posts: manager.scheduledPosts,
                        onPostTap: { post in selectedPost = post }
                    )
                case .month:
                    MonthViewCalendar(
                        selectedDate: $selectedDate,
                        posts: manager.scheduledPosts,
                        onPostTap: { post in selectedPost = post },
                        onDateDrop: { post, date in
                            manager.reschedulePost(post, to: date)
                        }
                    )
                }
            }
            .sheet(isPresented: $showingPostComposer) {
                PostComposer(manager: manager, initialDate: selectedDate)
            }
            .sheet(item: $selectedPost) { post in
                PostDetailView(post: post, manager: manager)
            }
        }
    }
}

// MARK: - Content Library
struct ContentLibrary: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var searchText = ""
    @State private var selectedCategory = ContentAssetCategory.all
    @State private var showingUpload = false
    @State private var selectedAssets: Set<ContentAsset> = []

    var body: some View {
        VStack(spacing: 0) {
            // Library Header
            HStack {
                // Search
                HStack {
                    Image(systemName: "magnifyingglass")
                    TextField("Search assets...", text: $searchText)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(DesignSystem.Radius.lg)
                .frame(maxWidth: 300)

                // Category Filter
                Picker("Category", selection: $selectedCategory) {
                    ForEach(ContentAssetCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }

                Spacer()

                // Bulk Actions
                if !selectedAssets.isEmpty {
                    HStack {
                        Button("Create Post") {
                            manager.createPostFromAssets(Array(selectedAssets))
                        }

                        Button("Add to Collection") {
                            manager.addToCollection(Array(selectedAssets))
                        }

                        Button(role: .destructive, action: {
                            manager.deleteAssets(Array(selectedAssets))
                        }) {
                            Text("Delete")
                        }
                    }
                }

                // Upload Button
                Button(action: { showingUpload = true }) {
                    Label("Upload", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Asset Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 200))], spacing: DesignSystem.Spacing.lg) {
                    ForEach(manager.filteredAssets(searchText: searchText, category: selectedCategory)) { asset in
                        AssetCard(
                            asset: asset,
                            isSelected: selectedAssets.contains(asset),
                            onTap: {
                                if selectedAssets.contains(asset) {
                                    selectedAssets.remove(asset)
                                } else {
                                    selectedAssets.insert(asset)
                                }
                            }
                        )
                    }
                }
                .padding()
            }

            // Storage Info Bar
            HStack {
                Label("\(manager.assetCount) items", systemImage: "photo.on.rectangle.angled")
                Spacer()
                Text("Storage: \(manager.storageUsedGB)GB / \(manager.storageLimitGB)GB")
                    .font(.caption)
                ProgressView(value: manager.storageUsedGB, total: manager.storageLimitGB)
                    .frame(width: 100)
            }
            .padding()
            .background(Color.gray.opacity(0.05))
        }
        .sheet(isPresented: $showingUpload) {
            AssetUploader(manager: manager)
        }
    }
}

// MARK: - Analytics Dashboard
struct AnalyticsDashboard: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var selectedPeriod = AnalyticsPeriod.week
    @State private var selectedMetric = "engagement"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Period Selector
                HStack {
                    Text("Analytics Overview")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Picker("Period", selection: $selectedPeriod) {
                        Text("24 Hours").tag(AnalyticsPeriod.day)
                        Text("7 Days").tag(AnalyticsPeriod.week)
                        Text("30 Days").tag(AnalyticsPeriod.month)
                        Text("90 Days").tag(AnalyticsPeriod.quarter)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                }
                .padding(.horizontal)

                // Key Metrics Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                    RevenueCard(
                        title: "Total Reach",
                        amount: 125300,
                        change: "+12.5%",
                        icon: "eye",
                        color: .blue
                    )

                    RevenueCard(
                        title: "Engagement Rate",
                        amount: manager.engagementRate,
                        change: "+3.2%",
                        icon: "heart",
                        color: .pink
                    )

                    RevenueCard(
                        title: "Followers",
                        amount: 45200,
                        change: "+892",
                        icon: "person.2",
                        color: .green
                    )

                    RevenueCard(
                        title: "Conversions",
                        amount: Double(manager.conversions),
                        change: "+45",
                        icon: "cart",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // Performance Chart
                GroupBox {
                    VStack(alignment: .leading) {
                        Text("Performance Trends")
                            .font(.headline)

                        Chart(manager.analyticsData) { dataPoint in
                            LineMark(
                                x: .value("Date", dataPoint.date),
                                y: .value("Value", dataPoint.value)
                            )
                            .foregroundStyle(by: .value("Platform", dataPoint.platform.rawValue))
                        }
                        .frame(height: 300)
                    }
                    .padding()
                }
                .padding(.horizontal)

                // Platform Breakdown
                HStack(spacing: DesignSystem.Spacing.xl) {
                    // Best Performing Platform
                    GroupBox {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Top Platform")
                                .font(.headline)

                            ForEach(manager.platformPerformance) { performance in
                                HStack {
                                    Image(systemName: performance.platform.icon)
                                        .foregroundColor(performance.platform.color)
                                    Text(performance.platform.rawValue)
                                    Spacer()
                                    Text("\(performance.engagementRate, specifier: "%.1f")%")
                                        .fontWeight(.medium)
                                }
                            }
                        }
                        .padding()
                    }

                    // Content Type Performance
                    GroupBox {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            Text("Content Performance")
                                .font(.headline)

                            ForEach(manager.contentTypePerformance) { performance in
                                HStack {
                                    Text(performance.type.rawValue)
                                    Spacer()
                                    ProgressView(value: performance.score, total: 100)
                                        .frame(width: 100)
                                    Text("\(Int(performance.score))%")
                                        .font(.caption)
                                }
                            }
                        }
                        .padding()
                    }
                }
                .padding(.horizontal)

                // Best Times to Post
                GroupBox {
                    VStack(alignment: .leading) {
                        Text("Optimal Posting Times")
                            .font(.headline)

                        HeatmapView(data: manager.postingHeatmap)
                            .frame(height: 200)
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Automation Studio
struct AutomationStudio: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var showingWorkflowBuilder = false
    @State private var selectedWorkflow: AutomationWorkflow?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Automation Workflows")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingWorkflowBuilder = true }) {
                    Label("Create Workflow", systemImage: "plus.circle.fill")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Workflow Templates
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                    // Quick Templates
                    Text("Templates")
                        .font(.headline)
                        .padding(.horizontal)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.lg) {
                            WorkflowTemplate(
                                title: "Auto-Repost",
                                description: "Automatically repost top performing content",
                                icon: "arrow.triangle.2.circlepath"
                            )

                            WorkflowTemplate(
                                title: "Cross-Post",
                                description: "Post to multiple platforms simultaneously",
                                icon: "square.on.square"
                            )

                            WorkflowTemplate(
                                title: "Engagement Reply",
                                description: "Auto-reply to comments and mentions",
                                icon: "bubble.left.and.bubble.right"
                            )

                            WorkflowTemplate(
                                title: "Content Recycler",
                                description: "Repurpose old content automatically",
                                icon: "arrow.rectanglepath"
                            )
                        }
                        .padding(.horizontal)
                    }

                    // Active Workflows
                    Text("Active Workflows")
                        .font(.headline)
                        .padding(.horizontal)

                    ForEach(manager.activeWorkflows) { workflow in
                        WorkflowCard(
                            workflow: workflow,
                            onToggle: { manager.toggleWorkflow(workflow) },
                            onEdit: { selectedWorkflow = workflow }
                        )
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
        }
        .sheet(isPresented: $showingWorkflowBuilder) {
            WorkflowBuilder(manager: manager)
        }
        .sheet(item: $selectedWorkflow) { workflow in
            WorkflowEditor(workflow: workflow, manager: manager)
        }
    }
}

// MARK: - Unified Inbox
struct UnifiedInbox: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var selectedPlatform: SocialPlatform?
    @State private var selectedConversation: Conversation?
    @State private var messageText = ""

    var body: some View {
        HSplitView {
            // Conversation List
            VStack(alignment: .leading, spacing: 0) {
                // Platform Tabs
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack {
                        ForEach(SocialPlatform.allCases, id: \.self) { platform in
                            PlatformTab(
                                platform: platform,
                                isSelected: selectedPlatform == platform,
                                unreadCount: manager.getUnreadCount(for: platform)
                            ) {
                                selectedPlatform = platform
                            }
                        }
                    }
                    .padding()
                }

                Divider()

                // Conversation List
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(manager.getConversations(for: selectedPlatform)) { conversation in
                            ConversationRow(
                                conversation: conversation,
                                isSelected: selectedConversation?.id == conversation.id
                            ) {
                                selectedConversation = conversation
                            }
                        }
                    }
                }
            }
            .frame(width: 300)

            // Message Thread
            if let conversation = selectedConversation {
                VStack(spacing: 0) {
                    // Conversation Header
                    HStack {
                        Image(systemName: "person.crop.circle")
                            .font(.title2)

                        VStack(alignment: .leading) {
                            Text(conversation.participantName)
                                .font(.headline)
                            Text(conversation.platform.rawValue)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button(action: { manager.markAsImportant(conversation) }) {
                            Image(systemName: conversation.isImportant ? "star.fill" : "star")
                                .foregroundColor(.yellow)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))

                    Divider()

                    // Messages
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                            ForEach(conversation.messages) { message in
                                MessageBubble(message: message)
                            }
                        }
                        .padding()
                    }

                    // Reply Box
                    HStack {
                        // Quick Replies
                        Menu {
                            ForEach(manager.quickReplies, id: \.self) { reply in
                                Button(reply) {
                                    messageText = reply
                                }
                            }
                        } label: {
                            Image(systemName: "text.bubble")
                        }

                        TextField("Type a message...", text: $messageText)
                            .textFieldStyle(.roundedBorder)

                        Button("Send") {
                            manager.sendMessage(messageText, in: conversation)
                            messageText = ""
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(messageText.isEmpty)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.05))
                }
            } else {
                // Empty State
                VStack {
                    Image(systemName: "bubble.left.and.bubble.right")
                        .font(.system(size: 64))
                        .foregroundColor(.secondary)

                    Text("Select a conversation")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Collaboration Center
struct CollaborationCenter: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var showingInvite = false
    @State private var selectedProject: CollaborationProject?

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Collaborations")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button(action: { showingInvite = true }) {
                    Label("Invite Collaborator", systemImage: "person.badge.plus")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()

            Divider()

            // Projects Grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: DesignSystem.Spacing.lg) {
                    ForEach(manager.collaborationProjects) { project in
                        CollaborationProjectCard(
                            project: project,
                            onTap: { selectedProject = project }
                        )
                    }

                    // Create New Project
                    Button(action: { manager.createNewProject() }) {
                        VStack {
                            Image(systemName: "plus.circle")
                                .font(.system(size: 48))
                            Text("New Project")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(DesignSystem.Radius.xxl)
                    }
                    .buttonStyle(.plain)
                }
                .padding()
            }
        }
        .sheet(isPresented: $showingInvite) {
            InviteCollaboratorView(manager: manager)
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project, manager: manager)
        }
    }
}

// MARK: - Monetization Dashboard
struct MonetizationDashboard: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var selectedPeriod = MonetizationPeriod.month

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xl) {
                // Revenue Overview
                HStack {
                    Text("Monetization")
                        .font(.title2)
                        .fontWeight(.semibold)

                    Spacer()

                    Picker("Period", selection: $selectedPeriod) {
                        Text("This Month").tag(MonetizationPeriod.month)
                        Text("This Quarter").tag(MonetizationPeriod.quarter)
                        Text("This Year").tag(MonetizationPeriod.year)
                    }
                }
                .padding(.horizontal)

                // Revenue Cards
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                    RevenueCard(
                        title: "Total Revenue",
                        amount: manager.totalRevenue,
                        change: "+22%",
                        icon: "dollarsign.circle",
                        color: .green
                    )

                    RevenueCard(
                        title: "Sponsorships",
                        amount: manager.sponsorshipRevenue,
                        change: "+15%",
                        icon: "star.circle",
                        color: .purple
                    )

                    RevenueCard(
                        title: "Affiliate",
                        amount: manager.affiliateRevenue,
                        change: "+8%",
                        icon: "link.circle",
                        color: .orange
                    )
                }
                .padding(.horizontal)

                // Revenue Streams
                GroupBox {
                    VStack(alignment: .leading) {
                        Text("Revenue Streams")
                            .font(.headline)

                        ForEach(manager.revenueStreams) { stream in
                            HStack {
                                Label(stream.name, systemImage: stream.icon)
                                Spacer()
                                Text("$\(stream.amount, specifier: "%.2f")")
                                    .fontWeight(.medium)
                            }
                            .padding(.vertical, 4)

                            if stream != manager.revenueStreams.last {
                                Divider()
                            }
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)

                // Active Campaigns
                GroupBox {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        HStack {
                            Text("Active Campaigns")
                                .font(.headline)
                            Spacer()
                            Button("View All") {
                                // Show all campaigns
                            }
                            .buttonStyle(.borderless)
                        }

                        ForEach(manager.activeCampaigns) { campaign in
                            CampaignRow(campaign: campaign)
                        }
                    }
                    .padding()
                }
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Supporting Views and Models
struct SidebarButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13))
                Spacer()
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isSelected ? Color.blue.opacity(0.2) : Color.clear)
            .foregroundColor(isSelected ? .blue : .primary)
            .cornerRadius(DesignSystem.Radius.md)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Data Models
enum CreatorHubTab: String, CaseIterable {
    case dashboard = "Dashboard"
    case calendar = "Calendar"
    case content = "Content"
    case analytics = "Analytics"
    case inbox = "Inbox"
    case automation = "Automation"
    case collaborations = "Collaborations"
    case monetization = "Monetization"

    var title: String { rawValue }

    var icon: String {
        switch self {
        case .dashboard: return "square.grid.2x2"
        case .calendar: return "calendar"
        case .content: return "photo.on.rectangle.angled"
        case .analytics: return "chart.line.uptrend.xyaxis"
        case .inbox: return "tray"
        case .automation: return "gearshape.2"
        case .collaborations: return "person.2"
        case .monetization: return "dollarsign.circle"
        }
    }
}

enum SocialPlatform: String, CaseIterable, Codable, Identifiable {
    case instagram = "Instagram"
    case tiktok = "TikTok"
    case youtube = "YouTube"
    case twitter = "Twitter"
    case facebook = "Facebook"
    case linkedin = "LinkedIn"
    case twitch = "Twitch"
    case pinterest = "Pinterest"
    case snapchat = "Snapchat"
    case threads = "Threads"
    case discord = "Discord"
    case reddit = "Reddit"
    case truthSocial = "Truth Social"

    var id: String { self.rawValue }

    var icon: String {
        switch self {
        case .instagram: return "camera"
        case .tiktok: return "music.note"
        case .youtube: return "play.rectangle"
        case .twitter: return "bird"
        case .facebook: return "f.square"
        case .linkedin: return "briefcase"
        case .twitch: return "tv"
        case .pinterest: return "pin"
        case .snapchat: return "camera.filters"
        case .threads: return "at"
        case .discord: return "message.circle"
        case .reddit: return "text.bubble"
        case .truthSocial: return "megaphone"
        }
    }

    var color: Color {
        switch self {
        case .instagram: return .purple
        case .tiktok: return .black
        case .youtube: return .red
        case .twitter: return .blue
        case .facebook: return .blue
        case .linkedin: return .blue
        case .twitch: return .purple
        case .pinterest: return .red
        case .snapchat: return .yellow
        case .threads: return .black
        case .discord: return .indigo
        case .reddit: return .orange
        case .truthSocial: return .red
        }
    }
}

struct SocialMediaPost: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var platforms: Set<SocialPlatform>
    var scheduledDate: Date
    var mediaAssets: [ContentAsset]
    var hashtags: [String]
    var mentions: [String]
    var status: PostStatus
    var analytics: PostAnalytics?
}

struct ContentAsset: Identifiable, Codable, Hashable {
    var id = UUID()
    var name: String
    var type: AssetType
    var url: URL
    var thumbnail: URL?
    var size: Int64
    var dimensions: CGSize?
    var duration: TimeInterval?
    var tags: [String]
}

enum AssetType: String, Codable {
    case image = "Image"
    case video = "Video"
    case audio = "Audio"
    case document = "Document"
    case template = "Template"
}

enum PostStatus: String, Codable {
    case draft = "Draft"
    case scheduled = "Scheduled"
    case published = "Published"
    case failed = "Failed"
}

struct PostAnalytics: Codable {
    var impressions: Int
    var engagement: Int
    var clicks: Int
    var shares: Int
    var saves: Int
}

enum ContentAssetCategory: String, CaseIterable {
    case all = "All"
    case images = "Images"
    case videos = "Videos"
    case templates = "Templates"
    case graphics = "Graphics"
}

// MARK: - Manager
class ContentCreatorHubManager: ObservableObject {
    @Published var scheduledPosts: [SocialMediaPost] = []
    @Published var contentAssets: [ContentAsset] = []
    @Published var activePlatformFilters: Set<SocialPlatform> = []
    @Published var activeWorkflows: [AutomationWorkflow] = []
    @Published var collaborationProjects: [CollaborationProject] = []
    @Published var conversations: [Conversation] = []
    @Published var revenueStreams: [RevenueStream] = []
    @Published var activeCampaigns: [MarketingCampaign] = []

    // Analytics Properties
    var formattedReach: String { "125.3K" }
    var engagementRate: Double { 4.7 }
    var formattedFollowers: String { "45.2K" }
    var conversions: Int { 234 }
    var analyticsData: [AnalyticsDataPoint] { [] }
    var platformPerformance: [PlatformPerformance] { [] }
    var contentTypePerformance: [ContentTypePerformance] { [] }
    var postingHeatmap: [[Double]] { [[]] }

    // Content Library
    var assetCount: Int { contentAssets.count }
    var storageUsedGB: Double { 12.5 }
    var storageLimitGB: Double { 100.0 }

    // Monetization
    var totalRevenue: Double { 15234.50 }
    var sponsorshipRevenue: Double { 8500.00 }
    var affiliateRevenue: Double { 3234.50 }

    // Inbox
    var quickReplies = [
        "Thanks for reaching out!",
        "I'll get back to you soon.",
        "Great question! Let me check.",
        "Appreciate your support!"
    ]

    func getPostsForDate(_ date: Date) -> [SocialMediaPost] {
        scheduledPosts.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
    }

    func togglePlatformFilter(_ platform: SocialPlatform) {
        if activePlatformFilters.contains(platform) {
            activePlatformFilters.remove(platform)
        } else {
            activePlatformFilters.insert(platform)
        }
    }

    func filteredAssets(searchText: String, category: ContentAssetCategory) -> [ContentAsset] {
        contentAssets
    }

    func reschedulePost(_ post: SocialMediaPost, to date: Date) {
        // Reschedule logic
    }

    func importFromCSV() {}
    func syncWithGoogle() {}
    func exportSchedule() {}
    func createPostFromAssets(_ assets: [ContentAsset]) {}
    func addToCollection(_ assets: [ContentAsset]) {}
    func deleteAssets(_ assets: [ContentAsset]) {}
    func toggleWorkflow(_ workflow: AutomationWorkflow) {}
    func createNewProject() {}
    func getUnreadCount(for platform: SocialPlatform?) -> Int { 5 }
    func getConversations(for platform: SocialPlatform?) -> [Conversation] { conversations }
    func markAsImportant(_ conversation: Conversation) {}
    func sendMessage(_ text: String, in conversation: Conversation) {}
}

// Additional model structs
struct AutomationWorkflow: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var isActive: Bool
    var triggers: [WorkflowTrigger]
    var actions: [WorkflowAction]
}

struct WorkflowTrigger: Identifiable {
    let id = UUID()
    var type: String
    var conditions: [String: Any]
}

struct WorkflowAction: Identifiable {
    let id = UUID()
    var type: String
    var parameters: [String: Any]
}

struct CollaborationProject: Identifiable {
    let id = UUID()
    var name: String
    var description: String
    var members: [TeamMember]
    var deadline: Date?
}

struct TeamMember: Identifiable {
    let id = UUID()
    var name: String
    var role: String
    var avatarURL: URL?
}

struct Conversation: Identifiable {
    let id = UUID()
    var participantName: String
    var platform: SocialPlatform
    var messages: [Message]
    var isImportant: Bool
    var unreadCount: Int
}

struct Message: Identifiable {
    let id = UUID()
    var content: String
    var isFromMe: Bool
    var timestamp: Date
}

struct RevenueStream: Identifiable, Equatable {
    let id = UUID()
    var name: String
    var amount: Double
    var icon: String
}

struct MarketingCampaign: Identifiable {
    let id = UUID()
    var name: String
    var brand: String
    var status: String
    var revenue: Double
}

struct AnalyticsDataPoint: Identifiable {
    let id = UUID()
    var date: Date
    var value: Double
    var platform: SocialPlatform
}

struct PlatformPerformance: Identifiable {
    let id = UUID()
    var platform: SocialPlatform
    var engagementRate: Double
}

struct ContentTypePerformance: Identifiable {
    let id = UUID()
    var type: ContentType
    var score: Double
}

enum ContentType: String {
    case photo = "Photo"
    case video = "Video"
    case reel = "Reel"
    case story = "Story"
    case live = "Live"
}

enum AnalyticsPeriod {
    case day, week, month, quarter
}

enum MonetizationPeriod {
    case month, quarter, year
}

// MARK: - Additional Supporting Views
struct CreatorHubActionBar: View {
    @Binding var showingQuickPost: Bool
    @ObservedObject var hubManager: ContentCreatorHubManager

    var body: some View {
        HStack {
            // Quick Post
            Button(action: { showingQuickPost = true }) {
                Label("Quick Post", systemImage: "square.and.pencil")
            }
            .buttonStyle(.borderedProminent)

            // AI Assistant
            Button(action: { /* Show AI assistant */ }) {
                Label("AI Assistant", systemImage: "cpu")
            }

            // Templates
            Menu {
                Button("Story Template") {}
                Button("Reel Template") {}
                Button("Post Template") {}
            } label: {
                Label("Templates", systemImage: "doc.text")
            }

            Spacer()

            // Notifications
            Button(action: {}) {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell")
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .offset(x: 4, y: -4)
                }
            }

            // Help
            Button(action: {}) {
                Image(systemName: "questionmark.circle")
            }
        }
    }
}

struct QuickPostComposer: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @Environment(\.dismiss) var dismiss

    @State private var content = ""
    @State private var selectedPlatforms: Set<SocialPlatform> = []
    @State private var scheduleDate = Date()
    @State private var postNow = true

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Quick Post")
                    .font(.title2)
                    .fontWeight(.semibold)
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Post") {
                    // Create and schedule post
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(content.isEmpty || selectedPlatforms.isEmpty)
            }
            .padding()

            Divider()

            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                // Platform Selection
                Text("Select Platforms")
                    .font(.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))]) {
                    ForEach(SocialPlatform.allCases, id: \.self) { platform in
                        PlatformSelectionButton(
                            platform: platform,
                            isSelected: selectedPlatforms.contains(platform)
                        ) {
                            if selectedPlatforms.contains(platform) {
                                selectedPlatforms.remove(platform)
                            } else {
                                selectedPlatforms.insert(platform)
                            }
                        }
                    }
                }

                // Content Input
                Text("Content")
                    .font(.headline)

                TextEditor(text: $content)
                    .frame(minHeight: 150)
                    .padding(DesignSystem.Spacing.sm)
                    .background(Color.gray.opacity(0.1))
                    .cornerRadius(DesignSystem.Radius.lg)

                // Schedule Options
                Toggle("Post Now", isOn: $postNow)

                if !postNow {
                    DatePicker("Schedule for", selection: $scheduleDate)
                }
            }
            .padding()
        }
        .frame(width: 600, height: 500)
    }
}

struct PlatformSelectionButton: View {
    let platform: SocialPlatform
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack {
                Image(systemName: platform.icon)
                    .font(.title2)
                Text(platform.rawValue)
                    .font(.caption)
            }
            .frame(width: 80, height: 80)
            .background(isSelected ? platform.color.opacity(0.2) : Color.gray.opacity(0.1))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? platform.color : Color.clear, lineWidth: 2)
            )
            .cornerRadius(DesignSystem.Radius.lg)
        }
        .buttonStyle(.plain)
    }
}
