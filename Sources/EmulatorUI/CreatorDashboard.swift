import SwiftUI
import Charts

// MARK: - Creator Dashboard
struct CreatorDashboard: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var timeRange = TimeRange.week

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xxl) {
                // Welcome Header
                HStack {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text("Welcome back!")
                            .font(.title)
                            .fontWeight(.bold)

                        Text("Here's what's happening with your content")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    // Quick Actions
                    HStack(spacing: DesignSystem.Spacing.md) {
                        QuickActionButton(
                            title: "Go Live",
                            icon: "video.fill",
                            color: .red
                        ) {
                            manager.startLiveStream()
                        }

                        QuickActionButton(
                            title: "Create Story",
                            icon: "camera.fill",
                            color: .purple
                        ) {
                            manager.createStory()
                        }

                        QuickActionButton(
                            title: "Schedule Post",
                            icon: "calendar.badge.plus",
                            color: .blue
                        ) {
                            manager.scheduleNewPost()
                        }
                    }
                }
                .padding(.horizontal)

                // Today's Schedule
                TodayScheduleWidget(manager: manager)
                    .padding(.horizontal)

                // Performance Overview
                PerformanceOverviewWidget(manager: manager, timeRange: $timeRange)
                    .padding(.horizontal)

                // Content Calendar Preview
                CalendarPreviewWidget(manager: manager)
                    .padding(.horizontal)

                // Recent Activity
                RecentActivityWidget(manager: manager)
                    .padding(.horizontal)

                // AI Insights
                AIInsightsWidget(manager: manager)
                    .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Today's Schedule Widget
struct TodayScheduleWidget: View {
    @ObservedObject var manager: ContentCreatorHubManager

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Label("Today's Schedule", systemImage: "clock")
                        .font(.headline)
                    Spacer()
                    Text(Date(), style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if manager.todaysPosts.isEmpty {
                    HStack {
                        Image(systemName: "calendar.badge.exclamationmark")
                            .font(.title2)
                            .foregroundColor(.orange)

                        VStack(alignment: .leading) {
                            Text("No posts scheduled today")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Text("Create content to keep your audience engaged")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Button("Schedule Now") {
                            manager.scheduleNewPost()
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(DesignSystem.Radius.lg)
                } else {
                    VStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(manager.todaysPosts) { post in
                            ScheduledPostRow(post: post)
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Performance Overview Widget
struct PerformanceOverviewWidget: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @Binding var timeRange: TimeRange

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Label("Performance", systemImage: "chart.line.uptrend.xyaxis")
                        .font(.headline)

                    Spacer()

                    Picker("Range", selection: $timeRange) {
                        Text("24h").tag(TimeRange.day)
                        Text("7d").tag(TimeRange.week)
                        Text("30d").tag(TimeRange.month)
                    }
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 150)
                }

                // Metrics Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())]) {
                    PerformanceMetric(
                        title: "Views",
                        value: manager.getViews(for: timeRange),
                        trend: .up(12.5),
                        icon: "eye",
                        color: .blue
                    )

                    PerformanceMetric(
                        title: "Engagement",
                        value: manager.getEngagement(for: timeRange),
                        trend: .up(8.2),
                        icon: "heart",
                        color: .pink
                    )

                    PerformanceMetric(
                        title: "Followers",
                        value: manager.getFollowerGrowth(for: timeRange),
                        trend: .up(3.7),
                        icon: "person.badge.plus",
                        color: .green
                    )
                }

                // Chart
                Chart(manager.getPerformanceData(for: timeRange)) { dataPoint in
                    LineMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue.gradient)

                    AreaMark(
                        x: .value("Time", dataPoint.timestamp),
                        y: .value("Value", dataPoint.value)
                    )
                    .foregroundStyle(.blue.opacity(0.1).gradient)
                }
                .frame(height: 200)
            }
            .padding()
        }
    }
}

// MARK: - Calendar Preview Widget
struct CalendarPreviewWidget: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var selectedWeek = 0

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Label("Upcoming Week", systemImage: "calendar")
                        .font(.headline)

                    Spacer()

                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Button(action: { selectedWeek -= 1 }) {
                            Image(systemName: "chevron.left")
                        }
                        .buttonStyle(.borderless)
                        .disabled(selectedWeek <= 0)

                        Text(manager.getWeekRange(offset: selectedWeek))
                            .font(.caption)
                            .frame(width: 150)

                        Button(action: { selectedWeek += 1 }) {
                            Image(systemName: "chevron.right")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                // Week Grid
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7)) {
                    ForEach(manager.getWeekDays(offset: selectedWeek), id: \.self) { day in
                        DayPreviewCell(
                            date: day,
                            posts: manager.getPostsForDate(day)
                        )
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Recent Activity Widget
struct RecentActivityWidget: View {
    @ObservedObject var manager: ContentCreatorHubManager

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Label("Recent Activity", systemImage: "clock.arrow.circlepath")
                        .font(.headline)

                    Spacer()

                    Button("View All") {
                        // Show full activity feed
                    }
                    .buttonStyle(.borderless)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ForEach(manager.recentActivities.prefix(5)) { activity in
                        ActivityRow(activity: activity)

                        if activity != manager.recentActivities.prefix(5).last {
                            Divider()
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - AI Insights Widget
struct AIInsightsWidget: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @State private var expandedInsight: AIInsight?

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                HStack {
                    Label("AI Insights", systemImage: "cpu")
                        .font(.headline)

                    Spacer()

                    Button("Generate New") {
                        manager.generateAIInsights()
                    }
                    .buttonStyle(.bordered)
                }

                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                    ForEach(manager.aiInsights) { insight in
                        AIInsightCard(
                            insight: insight,
                            isExpanded: expandedInsight?.id == insight.id
                        ) {
                            withAnimation {
                                expandedInsight = expandedInsight?.id == insight.id ? nil : insight
                            }
                        }
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Supporting Components
struct QuickActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)

                Text(title)
                    .font(.caption)
                    .foregroundColor(.primary)
            }
            .frame(width: 80, height: 80)
            .background(color.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.xxl)
        }
        .buttonStyle(.plain)
    }
}

struct ScheduledPostRow: View {
    let post: SocialMediaPost

    var body: some View {
        HStack {
            // Time
            Text(post.scheduledDate, style: .time)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 60)

            // Platforms
            HStack(spacing: DesignSystem.Spacing.xs) {
                ForEach(Array(post.platforms), id: \.self) { platform in
                    Image(systemName: platform.icon)
                        .font(.caption)
                        .foregroundColor(platform.color)
                }
            }

            // Title
            Text(post.title)
                .lineLimit(1)

            Spacer()

            // Status
            PostStatusBadge(status: post.status)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.md)
    }
}

struct PostStatusBadge: View {
    let status: PostStatus

    var body: some View {
        Text(status.rawValue)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 2)
            .background(status.color.opacity(0.2))
            .foregroundColor(status.color)
            .cornerRadius(DesignSystem.Radius.sm)
    }
}

struct PerformanceMetric: View {
    let title: String
    let value: String
    let trend: Trend
    let icon: String
    let color: Color

    enum Trend {
        case up(Double)
        case down(Double)
        case neutral

        var color: Color {
            switch self {
            case .up: return .green
            case .down: return .red
            case .neutral: return .gray
            }
        }

        var icon: String {
            switch self {
            case .up: return "arrow.up.right"
            case .down: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }

        var value: String {
            switch self {
            case .up(let val), .down(let val):
                return "\(val)%"
            case .neutral:
                return "0%"
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.semibold)

            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: trend.icon)
                    .font(.caption)
                Text(trend.value)
                    .font(.caption)
            }
            .foregroundColor(trend.color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct DayPreviewCell: View {
    let date: Date
    let posts: [SocialMediaPost]

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter
    }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Text(dayFormatter.string(from: date))
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(dateFormatter.string(from: date))
                .font(.headline)

            // Post indicators
            HStack(spacing: 2) {
                ForEach(0..<min(posts.count, 3), id: \.self) { _ in
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 6, height: 6)
                }

                if posts.count > 3 {
                    Text("+\(posts.count - 3)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(height: 12)
        }
        .frame(height: 80)
        .frame(maxWidth: .infinity)
        .background(
            Calendar.current.isDateInToday(date) ?
            Color.blue.opacity(0.1) :
            Color.gray.opacity(0.05)
        )
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct ActivityRow: View {
    let activity: Activity

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: activity.icon)
                .font(.title3)
                .foregroundColor(activity.color)
                .frame(width: 32, height: 32)
                .background(activity.color.opacity(0.1))
                .cornerRadius(DesignSystem.Radius.lg)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(activity.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Timestamp
            Text(activity.timestamp, style: .relative)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct AIInsightCard: View {
    let insight: AIInsight
    let isExpanded: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                // Priority Indicator
                Circle()
                    .fill(insight.priority.color)
                    .frame(width: 8, height: 8)

                Text(insight.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Spacer()

                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if isExpanded {
                Text(insight.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.leading, 12)

                if !insight.actions.isEmpty {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ForEach(insight.actions, id: \.self) { action in
                            Button(action) {
                                // Perform action
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    .padding(.leading, 12)
                    .padding(.top, 4)
                }
            }
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Additional Models
struct Activity: Identifiable, Equatable {
    let id = UUID()
    let title: String
    let description: String
    let icon: String
    let color: Color
    let timestamp: Date

    static func == (lhs: Activity, rhs: Activity) -> Bool {
        lhs.id == rhs.id
    }
}

struct AIInsight: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: Priority
    let actions: [String]

    enum Priority {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .green
            }
        }
    }
}

enum TimeRange {
    case day, week, month
}

// MARK: - Extensions for Manager
extension ContentCreatorHubManager {
    var todaysPosts: [SocialMediaPost] {
        getPostsForDate(Date())
    }

    var recentActivities: [Activity] {
        // Mock data - replace with real implementation
        [
            Activity(
                title: "New follower milestone",
                description: "You reached 10K followers on Instagram",
                icon: "star.fill",
                color: .yellow,
                timestamp: Date().addingTimeInterval(-3600)
            ),
            Activity(
                title: "Post published",
                description: "Your scheduled post went live on TikTok",
                icon: "checkmark.circle",
                color: .green,
                timestamp: Date().addingTimeInterval(-7200)
            )
        ]
    }

    var aiInsights: [AIInsight] {
        [
            AIInsight(
                title: "Best time to post",
                description: "Your audience is most active between 7-9 PM EST. Consider scheduling your next post during this window.",
                priority: .high,
                actions: ["Schedule Post", "View Analytics"]
            ),
            AIInsight(
                title: "Trending hashtag",
                description: "#CreatorLife is trending in your niche. Use it to increase visibility.",
                priority: .medium,
                actions: ["Add to Draft"]
            )
        ]
    }

    func startLiveStream() {}
    func createStory() {}
    func scheduleNewPost() {}
    func generateAIInsights() {}

    func getViews(for range: TimeRange) -> String { "125.3K" }
    func getEngagement(for range: TimeRange) -> String { "8.2K" }
    func getFollowerGrowth(for range: TimeRange) -> String { "+892" }

    func getPerformanceData(for range: TimeRange) -> [PerformanceDataPoint] {
        // Generate mock data
        (0..<30).map { i in
            PerformanceDataPoint(
                timestamp: Date().addingTimeInterval(Double(-i * 86400)),
                value: Double.random(in: 100...500)
            )
        }
    }

    func getWeekRange(offset: Int) -> String {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: today) ?? today
        let weekEnd = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart

        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        return "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEnd))"
    }

    func getWeekDays(offset: Int) -> [Date] {
        let calendar = Calendar.current
        let today = Date()
        let weekStart = calendar.date(byAdding: .weekOfYear, value: offset, to: today) ?? today

        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekStart)
        }
    }
}

struct PerformanceDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

// MARK: - PostStatus Extension
extension PostStatus {
    var color: Color {
        switch self {
        case .draft: return .gray
        case .scheduled: return .blue
        case .published: return .green
        case .failed: return .red
        }
    }
}