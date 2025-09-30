import SwiftUI
import Charts

// MARK: - Notification Extensions
extension Notification.Name {
    static let navigateToStreamCategory = Notification.Name("navigateToStreamCategory")
    static let navigateToGoLive = Notification.Name("navigateToGoLive")
    static let startGameWithROM = Notification.Name("startGameWithROM")
    static let navigateToAnalytics = Notification.Name("navigateToAnalytics")
    static let navigateToIncome = Notification.Name("navigateToIncome")
    static let navigateToAlerts = Notification.Name("navigateToAlerts")
    static let showSocialWizard = Notification.Name("showSocialWizard")
    static let showViewsAnalytics = Notification.Name("showViewsAnalytics")
    static let showWatchTimeAnalytics = Notification.Name("showWatchTimeAnalytics")
    static let showFollowersAnalytics = Notification.Name("showFollowersAnalytics")
}

// MARK: - Main Streaming Dashboard
public struct StreamingDashboard: View {
    @StateObject private var dashboardManager = StreamingDashboardManager()
    @State private var selectedTimeRange = DashboardTimeRange.today
    @State private var showingQuickStart = false
    @State private var dashboardMode = DashboardMode.focused

    public init() {}

    public var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.05, blue: 0.08),
                    Color(red: 0.02, green: 0.02, blue: 0.03)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            // Main Content
            VStack(spacing: 0) {
                // Primary Header with Status
                PrimaryHeaderView(
                    streamStatus: dashboardManager.streamStatus,
                    onQuickAction: handleQuickAction
                )

                // Main Dashboard Content
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.xxl) {
                        // Priority 1: Current Status & Quick Actions
                        if dashboardManager.isLive {
                            LiveStreamStatusCard(manager: dashboardManager)
                                .transition(.scale.combined(with: .opacity))
                        } else {
                            QuickStartCard(
                                nextStream: dashboardManager.nextScheduledStream,
                                onStartStream: {
                                    // Navigate to Go Live (emulator) view
                                    NotificationCenter.default.post(
                                        name: .navigateToGoLive,
                                        object: nil
                                    )
                                }
                            )
                        }

                        // Priority 2: Key Metrics (Maximum 4)
                        KeyMetricsRow(
                            metrics: dashboardManager.keyMetrics,
                            timeRange: selectedTimeRange,
                            onMetricTap: handleMetricTap
                        )

                        // Platform-specific Metrics
                        PlatformMetricsSection(
                            platforms: dashboardManager.platformMetrics
                        )

                        // Priority 3: Today's Focus
                        TodaysFocusSection(
                            schedule: dashboardManager.todaysSchedule,
                            recommendations: dashboardManager.aiRecommendations
                        )

                        // Priority 4: Performance Insights (Progressive Disclosure)
                        if dashboardMode == .detailed {
                            DetailedAnalyticsSection(
                                analytics: dashboardManager.detailedAnalytics,
                                timeRange: selectedTimeRange
                            )
                            .transition(.asymmetric(
                                insertion: .move(edge: .top).combined(with: .opacity),
                                removal: .move(edge: .top).combined(with: .opacity)
                            ))
                        }
                    }
                    .padding(.horizontal, DesignSystem.Spacing.xxl)
                    .padding(.bottom, DesignSystem.Spacing.section)
                }
            }

            // Floating Action Button (Material Design)
            VStack {
                Spacer()
                HStack {
                    Spacer()

                    FloatingActionButton(
                        isExpanded: dashboardManager.isLive
                    ) {
                        if dashboardManager.isLive {
                            dashboardManager.endStream()
                        } else {
                            // Navigate to Go Live (emulator) view
                            NotificationCenter.default.post(
                                name: .navigateToGoLive,
                                object: nil
                            )
                        }
                    }
                    .padding(.trailing, DesignSystem.Spacing.xxl)
                    .padding(.bottom, DesignSystem.Spacing.xxl)
                }
            }
        }
        .sheet(isPresented: $showingQuickStart) {
            QuickStreamSetup(manager: dashboardManager)
        }
        .onAppear {
            dashboardManager.loadDashboard()
        }
    }

    private func handleQuickAction(_ action: QuickAction) {
        switch action {
        case .goLive:
            // Navigate to Go Live (emulator) view
            NotificationCenter.default.post(
                name: .navigateToGoLive,
                object: nil
            )
        case .schedule:
            // Navigate to scheduler
            break
        case .viewAnalytics:
            withAnimation(.spring()) {
                dashboardMode = dashboardMode == .focused ? .detailed : .focused
            }
        case .engagement:
            // Show engagement panel or navigate to engagement view
            break
        }
    }

    private func handleMetricTap(_ metric: KeyMetric) {
        switch metric.label.lowercased() {
        case "total views", "views":
            // Navigate to Analytics tab with views focus
            NotificationCenter.default.post(
                name: .navigateToAnalytics,
                object: "views"
            )
        case "watch time", "hours watched":
            // Navigate to Analytics tab with watch time focus
            NotificationCenter.default.post(
                name: .navigateToAnalytics,
                object: "watch_time"
            )
        case "followers", "new followers":
            // Navigate to Analytics tab with followers focus
            NotificationCenter.default.post(
                name: .navigateToAnalytics,
                object: "followers"
            )
        case "revenue", "income", "earnings":
            // Navigate to Income tab
            NotificationCenter.default.post(
                name: .navigateToIncome,
                object: nil
            )
        default:
            // Navigate to general Analytics tab
            NotificationCenter.default.post(
                name: .navigateToAnalytics,
                object: nil
            )
        }
    }
}

// MARK: - Primary Header
struct PrimaryHeaderView: View {
    let streamStatus: DashboardStreamStatus
    let onQuickAction: (QuickAction) -> Void

    var body: some View {
        // Empty view - header removed
        EmptyView()
    }
}

// MARK: - Live Stream Status Card
struct LiveStreamStatusCard: View {
    @ObservedObject var manager: StreamingDashboardManager
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            // Header
            HStack {
                // Live Badge
                LiveBadge()

                Spacer()

                // Duration
                Text(manager.streamDuration.formatted())
                    .font(.system(.title3, design: .monospaced))
                    .foregroundColor(.white)

                // Expand/Collapse
                Button(action: { withAnimation { isExpanded.toggle() } }) {
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            // Real-time Metrics
            HStack(spacing: DesignSystem.Spacing.xl) {
                LiveMetric(
                    value: "\(manager.currentViewers)",
                    label: "Viewers",
                    trend: .up(12),
                    color: .green
                )

                LiveMetric(
                    value: manager.engagementRate,
                    label: "Engagement",
                    trend: .stable,
                    color: .blue
                )

                LiveMetric(
                    value: "\(manager.newFollowers)",
                    label: "New Followers",
                    trend: .up(5),
                    color: .purple
                )

                LiveMetric(
                    value: manager.avgWatchTime,
                    label: "Avg Watch Time",
                    trend: .up(8),
                    color: .orange
                )
            }

            // Expanded Details
            if isExpanded {
                VStack(spacing: DesignSystem.Spacing.md) {
                    Divider()
                        .background(Color.white.opacity(0.2))

                    // Platform Status
                    HStack(spacing: DesignSystem.Spacing.lg) {
                        ForEach(manager.activePlatforms) { platform in
                            PlatformStatusBadge(platform: platform)
                        }
                    }

                    // Quick Actions
                    HStack(spacing: DesignSystem.Spacing.md) {
                        Button(action: { manager.toggleChat() }) {
                            Label("Chat", systemImage: "message")
                        }
                        .buttonStyle(StreamActionButton())

                        Button(action: { manager.toggleRecording() }) {
                            Label(
                                manager.isRecording ? "Stop Recording" : "Record",
                                systemImage: manager.isRecording ? "record.circle.fill" : "record.circle"
                            )
                        }
                        .buttonStyle(StreamActionButton(isActive: manager.isRecording))

                        Button(action: { manager.createClip() }) {
                            Label("Clip", systemImage: "scissors")
                        }
                        .buttonStyle(StreamActionButton())
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(
            LinearGradient(
                colors: [
                    Color.red.opacity(0.3),
                    Color.red.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.red.opacity(0.5), lineWidth: 1)
        )
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - Quick Start Card
struct QuickStartCard: View {
    let nextStream: ScheduledStream?
    let onStartStream: () -> Void
    @State private var selectedCategory: StreamCategory = .gaming

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("Ready to Stream?")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)

                    if let next = nextStream {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "calendar.clock")
                                .font(.caption)
                            Text("Next scheduled: \(next.startTime.formatted(.relative(presentation: .named)))")
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.7))
                    } else {
                        Text("No streams scheduled today")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Primary CTA
                Button(action: onStartStream) {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Image(systemName: "video.fill")
                        Text("Go Live")
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(DesignSystem.Radius.xxl)
                }
                .buttonStyle(ScaleButtonStyle())
            }

            // Quick Setup Options
            HStack(spacing: DesignSystem.Spacing.md) {
                Button(action: {
                    selectedCategory = .gaming
                    navigateToCategory(.gaming)
                }) {
                    QuickSetupOption(
                        icon: "gamecontroller",
                        label: "Gaming",
                        isSelected: selectedCategory == .gaming
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    selectedCategory = .justChatting
                    navigateToCategory(.justChatting)
                }) {
                    QuickSetupOption(
                        icon: "bubble.left.and.bubble.right",
                        label: "Just Chatting",
                        isSelected: selectedCategory == .justChatting
                    )
                }
                .buttonStyle(.plain)

                Button(action: {
                    selectedCategory = .creative
                    navigateToCategory(.creative)
                }) {
                    QuickSetupOption(
                        icon: "paintbrush",
                        label: "Creative",
                        isSelected: selectedCategory == .creative
                    )
                }
                .buttonStyle(.plain)

                // Alerts/Notifications button
                Button(action: {
                    // Navigate to Alerts tab
                    NotificationCenter.default.post(
                        name: .navigateToAlerts,
                        object: nil
                    )
                }) {
                    ZStack(alignment: .topTrailing) {
                        QuickSetupOption(
                            icon: "bell",
                            label: "Alerts",
                            isSelected: false
                        )

                        // Badge for notification count
                        Circle()
                            .fill(Color.red)
                            .frame(width: 16, height: 16)
                            .overlay(
                                Text("3")
                                    .font(.system(size: 10))
                                    .foregroundColor(.white)
                            )
                            .offset(x: -8, y: 8)
                    }
                }
                .buttonStyle(.plain)

                // Account Setup Wizard button
                Button(action: {
                    // Show social account wizard
                    NotificationCenter.default.post(
                        name: .showSocialWizard,
                        object: nil
                    )
                }) {
                    QuickSetupOption(
                        icon: "person.badge.plus",
                        label: "Setup",
                        isSelected: false
                    )
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(Color.white.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }

    private func navigateToCategory(_ category: StreamCategory) {
        // Post notification to navigate to the appropriate view
        NotificationCenter.default.post(
            name: .navigateToStreamCategory,
            object: category
        )
    }
}

// MARK: - Key Metrics Row
struct KeyMetricsRow: View {
    let metrics: [KeyMetric]
    let timeRange: DashboardTimeRange
    let onMetricTap: (KeyMetric) -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            ForEach(metrics.prefix(4)) { metric in
                MetricCard(metric: metric, timeRange: timeRange, onTap: {
                    onMetricTap(metric)
                })
            }
        }
    }
}

// MARK: - Platform Metrics Section
struct PlatformMetricsSection: View {
    let platforms: [PlatformMetric]
    @State private var selectedPlatform: String?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Section Header
            HStack {
                Text("Platform Performance")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                Text("Last 24 hours")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }

            // Platform Cards Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                ForEach(platforms) { platform in
                    PlatformMetricCard(
                        platform: platform,
                        isSelected: selectedPlatform == platform.name
                    )
                    .onTapGesture {
                        withAnimation {
                            selectedPlatform = selectedPlatform == platform.name ? nil : platform.name
                        }
                    }
                }
            }

            // Detailed view for selected platform
            if let selected = selectedPlatform,
               let platform = platforms.first(where: { $0.name == selected }) {
                PlatformDetailView(platform: platform)
                    .transition(.asymmetric(
                        insertion: .opacity.combined(with: .move(edge: .top)),
                        removal: .opacity
                    ))
            }
        }
        .padding(DesignSystem.Spacing.xl)
        .background(Color.white.opacity(0.03))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct PlatformMetricCard: View {
    let platform: PlatformMetric
    let isSelected: Bool
    @State private var isHovering = false

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.md) {
            // Platform Header
            HStack {
                Image(systemName: platform.icon)
                    .font(.title2)
                    .foregroundColor(platform.color)

                Spacer()

                // Live indicator if streaming
                if platform.isLive {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 4)
                                .scaleEffect(1.5)
                                .opacity(0.5)
                        )
                }
            }

            // Platform Name
            Text(platform.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.8))
                .frame(maxWidth: .infinity, alignment: .leading)

            // New Viewers
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("+\(platform.newViewers)")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Image(systemName: platform.viewerTrend > 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.caption2)
                        .foregroundColor(platform.viewerTrend > 0 ? .green : .red)

                    Text("\(abs(platform.viewerTrend))%")
                        .font(.caption2)
                        .foregroundColor(platform.viewerTrend > 0 ? .green : .red)

                    Text("vs yesterday")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.4))
                }
            }

            // Engagement Rate
            HStack {
                Image(systemName: "heart.fill")
                    .font(.caption2)
                    .foregroundColor(.pink)

                Text(String(format: "%.1f%%", platform.engagementRate))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))

                Spacer()
            }
        }
        .padding(DesignSystem.Spacing.lg)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? platform.color.opacity(0.15) : (isHovering ? Color.white.opacity(0.08) : Color.white.opacity(0.05)))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? platform.color : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

struct PlatformDetailView: View {
    let platform: PlatformMetric

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("\(platform.name) Details")
                .font(.headline)
                .foregroundColor(.white)

            HStack(spacing: DesignSystem.Spacing.xl) {
                DetailMetric(label: "Peak Viewers", value: "\(platform.peakViewers)")
                DetailMetric(label: "Avg Watch Time", value: platform.avgWatchTime)
                DetailMetric(label: "Chat Messages", value: "\(platform.chatMessages)")
                DetailMetric(label: "New Followers", value: "+\(platform.newFollowers)")
                DetailMetric(label: "Revenue", value: String(format: "$%.2f", platform.revenue))
            }
        }
        .padding()
        .background(Color.white.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct DetailMetric: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.white)
        }
    }
}

struct MetricCard: View {
    let metric: KeyMetric
    let timeRange: DashboardTimeRange
    let onTap: () -> Void
    @State private var isHovering = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: metric.icon)
                    .foregroundColor(metric.color)
                    .font(.title3)

                Spacer()

                if let trend = metric.trend {
                    TrendIndicator(trend: trend)
                }
            }

            // Value
            Text(metric.formattedValue)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .foregroundColor(.white)

            // Label
            Text(metric.label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))

            // Comparison
            if let comparison = metric.comparison {
                Text(comparison)
                    .font(.caption2)
                    .foregroundColor(metric.trend?.isPositive ?? false ? .green : .white.opacity(0.5))
            }
        }
        .frame(maxWidth: .infinity)
        .padding(DesignSystem.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(isHovering ? 0.08 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
        .onTapGesture {
            onTap()
        }
    }
}

// MARK: - Today's Focus Section
struct TodaysFocusSection: View {
    let schedule: [ScheduledActivity]
    let recommendations: [AIRecommendation]
    @State private var selectedTab = 0

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Section Header
            HStack {
                Text("Today's Focus")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Spacer()

                // Tab Selector
                Picker("", selection: $selectedTab) {
                    Text("Schedule").tag(0)
                    Text("AI Tips").tag(1)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 200)
            }

            // Content
            Group {
                if selectedTab == 0 {
                    // Schedule Timeline
                    if schedule.isEmpty {
                        DashboardEmptyStateView(
                            icon: "calendar",
                            title: "No activities scheduled",
                            subtitle: "Add streams or content to your calendar",
                            actionLabel: "Schedule Now",
                            action: { }
                        )
                    } else {
                        VStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(schedule) { activity in
                                ActivityTimelineRow(activity: activity)
                            }
                        }
                    }
                } else {
                    // AI Recommendations
                    VStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(recommendations) { recommendation in
                            AIRecommendationCard(recommendation: recommendation)
                        }
                    }
                }
            }
            .animation(.easeInOut, value: selectedTab)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(Color.white.opacity(0.03))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - Supporting Components

struct LiveBadge: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Circle()
                .fill(Color.red)
                .frame(width: 8, height: 8)
                .scaleEffect(isAnimating ? 1.2 : 1.0)
                .animation(
                    Animation.easeInOut(duration: 1)
                        .repeatForever(autoreverses: true),
                    value: isAnimating
                )

            Text("LIVE")
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(.red)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.red.opacity(0.15))
        .cornerRadius(20)
        .onAppear { isAnimating = true }
    }
}

struct StreamStatusIndicator: View {
    let status: DashboardStreamStatus

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(status.color)
                .frame(width: 10, height: 10)

            Text(status.label)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(status.color)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(status.color.opacity(0.15))
        .cornerRadius(20)
    }
}

struct LiveMetric: View {
    let value: String
    let label: String
    let trend: Trend
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Text(value)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                if case .up(_) = trend {
                    Image(systemName: "arrow.up")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            Text(label)
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct TrendIndicator: View {
    let trend: Trend

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: trend.icon)
                .font(.caption)

            if let value = trend.value {
                Text("\(value)%")
                    .font(.caption)
            }
        }
        .foregroundColor(trend.color)
    }
}

struct FloatingActionButton: View {
    let isExpanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.sm) {
                Image(systemName: isExpanded ? "stop.fill" : "video.fill")
                    .font(.title2)

                if isExpanded {
                    Text("End Stream")
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, isExpanded ? 24 : 20)
            .padding(.vertical, isExpanded ? 16 : 20)
            .background(isExpanded ? Color.red : Color.blue)
            .clipShape(Capsule())
            .shadow(radius: 8, y: 4)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}

struct DashboardQuickActionButton: View {
    let icon: String
    let label: String
    var badge: Int? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.white.opacity(0.8))
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(DesignSystem.Radius.lg)

                if let badge = badge, badge > 0 {
                    Text("\(badge)")
                        .font(.system(size: 10))
                        .foregroundColor(.white)
                        .frame(width: 16, height: 16)
                        .background(Color.red)
                        .clipShape(Circle())
                        .offset(x: 4, y: -4)
                }
            }
        }
        .buttonStyle(.plain)
        .help(label)
    }
}

struct ActivityTimelineRow: View {
    let activity: ScheduledActivity

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Time
            Text(activity.time.formatted(.dateTime.hour().minute()))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.white.opacity(0.6))
                .frame(width: 50, alignment: .leading)

            // Status Indicator
            Circle()
                .fill(activity.isPast ? Color.gray : activity.color)
                .frame(width: 8, height: 8)

            // Activity Info
            VStack(alignment: .leading, spacing: 2) {
                Text(activity.title)
                    .font(.subheadline)
                    .foregroundColor(activity.isPast ? .white.opacity(0.5) : .white)

                if let subtitle = activity.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.5))
                }
            }

            Spacer()

            // Platform Icons
            if !activity.platforms.isEmpty {
                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(activity.platforms, id: \.self) { platform in
                        Image(systemName: platform.icon)
                            .font(.caption)
                            .foregroundColor(platform.color.opacity(0.8))
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.white.opacity(activity.isPast ? 0.02 : 0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct AIRecommendationCard: View {
    let recommendation: AIRecommendation
    @State private var isDismissed = false

    var body: some View {
        if !isDismissed {
            HStack(spacing: DesignSystem.Spacing.md) {
                // Priority Indicator
                Circle()
                    .fill(recommendation.priority.color)
                    .frame(width: 4, height: 40)

                // Icon
                Image(systemName: recommendation.icon)
                    .font(.title3)
                    .foregroundColor(recommendation.priority.color)
                    .frame(width: 32)

                // Content
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text(recommendation.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)

                    Text(recommendation.description)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                        .lineLimit(2)
                }

                Spacer()

                // Actions
                if let actionLabel = recommendation.actionLabel {
                    Button(actionLabel) {
                        recommendation.action?()
                    }
                    .font(.caption)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(recommendation.priority.color.opacity(0.2))
                    .foregroundColor(recommendation.priority.color)
                    .cornerRadius(DesignSystem.Radius.md)
                }

                // Dismiss
                Button(action: { withAnimation { isDismissed = true } }) {
                    Image(systemName: "xmark")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
            .padding(DesignSystem.Spacing.md)
            .background(Color.white.opacity(0.05))
            .cornerRadius(DesignSystem.Radius.lg)
            .transition(.asymmetric(
                insertion: .slide,
                removal: .scale.combined(with: .opacity)
            ))
        }
    }
}

struct DashboardEmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionLabel: String
    let action: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 48))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.white.opacity(0.8))

                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.5))
            }

            Button(action: action) {
                Text(actionLabel)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }
}

struct PlatformStatusBadge: View {
    let platform: StreamPlatformStatus

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: platform.icon)
                .font(.caption)

            Text(platform.name)
                .font(.caption)

            if platform.isConnected {
                Circle()
                    .fill(Color.green)
                    .frame(width: 6, height: 6)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(platform.color.opacity(0.2))
        .foregroundColor(platform.color)
        .cornerRadius(DesignSystem.Radius.xxl)
    }
}

struct QuickSetupOption: View {
    let icon: String
    let label: String
    let isSelected: Bool

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .white.opacity(0.5))

            Text(label)
                .font(.caption)
                .foregroundColor(isSelected ? .blue : .white.opacity(0.5))
        }
        .frame(width: 80, height: 60)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.15) : Color.white.opacity(0.03))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 1)
                )
        )
    }
}

struct DetailedAnalyticsSection: View {
    let analytics: DetailedAnalytics
    let timeRange: DashboardTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            Text("Performance Details")
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundColor(.white)

            // Charts and detailed metrics would go here
            Text("Detailed analytics visualization")
                .foregroundColor(.white.opacity(0.5))
                .frame(height: 200)
                .frame(maxWidth: .infinity)
                .background(Color.white.opacity(0.03))
                .cornerRadius(DesignSystem.Radius.xxl)
        }
        .padding(DesignSystem.Spacing.xl)
        .background(Color.white.opacity(0.03))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - Button Styles

struct StreamActionButton: ButtonStyle {
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .fontWeight(.medium)
            .foregroundColor(isActive ? .black : .white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(isActive ? Color.yellow : Color.white.opacity(0.15))
            .cornerRadius(DesignSystem.Radius.md)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Data Models

public enum StreamCategory {
    case gaming
    case justChatting
    case creative
}

enum DashboardStreamStatus {
    case offline
    case preparing
    case live
    case ending

    var label: String {
        switch self {
        case .offline: return "Offline"
        case .preparing: return "Preparing"
        case .live: return "Live"
        case .ending: return "Ending"
        }
    }

    var color: Color {
        switch self {
        case .offline: return .gray
        case .preparing: return .orange
        case .live: return .red
        case .ending: return .yellow
        }
    }
}

enum QuickAction {
    case goLive
    case schedule
    case viewAnalytics
    case engagement
}

enum DashboardMode {
    case focused
    case detailed
}

enum DashboardTimeRange {
    case today
    case week
    case month

    var label: String {
        switch self {
        case .today: return "Today"
        case .week: return "This Week"
        case .month: return "This Month"
        }
    }
}

enum Trend {
    case up(Int)
    case down(Int)
    case stable

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .stable: return "minus"
        }
    }

    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .stable: return .gray
        }
    }

    var value: Int? {
        switch self {
        case .up(let val), .down(let val): return val
        case .stable: return nil
        }
    }

    var isPositive: Bool {
        switch self {
        case .up: return true
        case .down: return false
        case .stable: return true
        }
    }
}

struct KeyMetric: Identifiable {
    let id = UUID()
    let label: String
    let value: Double
    let formattedValue: String
    let icon: String
    let color: Color
    let trend: Trend?
    let comparison: String?
}

struct ScheduledStream: Identifiable {
    let id = UUID()
    let title: String
    let startTime: Date
    let platforms: [StreamPlatformStatus]
}

struct ScheduledActivity: Identifiable {
    let id = UUID()
    let time: Date
    let title: String
    let subtitle: String?
    let platforms: [StreamPlatformStatus]
    let color: Color

    var isPast: Bool {
        time < Date()
    }
}

struct AIRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let description: String
    let priority: Priority
    let icon: String
    let actionLabel: String?
    let action: (() -> Void)?

    enum Priority {
        case high, medium, low

        var color: Color {
            switch self {
            case .high: return .red
            case .medium: return .orange
            case .low: return .blue
            }
        }
    }
}

struct StreamPlatformStatus: Hashable, Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let isConnected: Bool
}

struct PlatformMetric: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
    let isLive: Bool
    let newViewers: Int
    let viewerTrend: Int // percentage change
    let engagementRate: Double
    let peakViewers: Int
    let avgWatchTime: String
    let chatMessages: Int
    let newFollowers: Int
    let revenue: Double
}

struct DetailedAnalytics {
    // Placeholder for detailed analytics data
}

// MARK: - Dashboard Manager

@MainActor
class StreamingDashboardManager: ObservableObject {
    @Published var streamStatus = DashboardStreamStatus.offline
    @Published var isLive = false
    @Published var streamDuration = Duration.seconds(0)
    @Published var currentViewers = 0
    @Published var engagementRate = "4.2%"
    @Published var newFollowers = 23
    @Published var avgWatchTime = "12:34"
    @Published var isRecording = false
    @Published var isChatOpen = true

    @Published var activePlatforms: [StreamPlatformStatus] = [
        StreamPlatformStatus(name: "Twitch", icon: "tv", color: .purple, isConnected: true),
        StreamPlatformStatus(name: "YouTube", icon: "play.rectangle", color: .red, isConnected: true)
    ]

    @Published var keyMetrics: [KeyMetric] = []
    @Published var platformMetrics: [PlatformMetric] = []
    @Published var todaysSchedule: [ScheduledActivity] = []
    @Published var aiRecommendations: [AIRecommendation] = []
    @Published var nextScheduledStream: ScheduledStream?
    @Published var detailedAnalytics = DetailedAnalytics()

    func loadDashboard() {
        // Load initial data
        loadKeyMetrics()
        loadPlatformMetrics()
        loadSchedule()
        loadRecommendations()
    }

    private func loadKeyMetrics() {
        keyMetrics = [
            KeyMetric(
                label: "Total Views",
                value: 15234,
                formattedValue: "15.2K",
                icon: "eye",
                color: .blue,
                trend: .up(12),
                comparison: "vs last week"
            ),
            KeyMetric(
                label: "Watch Time",
                value: 4523,
                formattedValue: "75.4h",
                icon: "clock",
                color: .green,
                trend: .up(8),
                comparison: "+6h from average"
            ),
            KeyMetric(
                label: "Followers",
                value: 892,
                formattedValue: "+892",
                icon: "person.badge.plus",
                color: .purple,
                trend: .up(23),
                comparison: "this week"
            ),
            KeyMetric(
                label: "Revenue",
                value: 1234.50,
                formattedValue: "$1,234",
                icon: "dollarsign.circle",
                color: .green,
                trend: .up(15),
                comparison: "vs last month"
            )
        ]
    }

    private func loadPlatformMetrics() {
        platformMetrics = [
            PlatformMetric(
                name: "Twitch",
                icon: "tv",
                color: .purple,
                isLive: true,
                newViewers: 3241,
                viewerTrend: 18,
                engagementRate: 8.7,
                peakViewers: 5621,
                avgWatchTime: "42:15",
                chatMessages: 892,
                newFollowers: 127,
                revenue: 284.50
            ),
            PlatformMetric(
                name: "YouTube",
                icon: "play.rectangle",
                color: .red,
                isLive: true,
                newViewers: 2156,
                viewerTrend: 12,
                engagementRate: 6.4,
                peakViewers: 3842,
                avgWatchTime: "38:22",
                chatMessages: 456,
                newFollowers: 89,
                revenue: 198.25
            ),
            PlatformMetric(
                name: "TikTok",
                icon: "music.note",
                color: .pink,
                isLive: false,
                newViewers: 8924,
                viewerTrend: 45,
                engagementRate: 12.3,
                peakViewers: 12450,
                avgWatchTime: "02:45",
                chatMessages: 2341,
                newFollowers: 412,
                revenue: 156.75
            ),
            PlatformMetric(
                name: "Kick",
                icon: "bolt.fill",
                color: .green,
                isLive: false,
                newViewers: 892,
                viewerTrend: -5,
                engagementRate: 5.2,
                peakViewers: 1250,
                avgWatchTime: "28:10",
                chatMessages: 234,
                newFollowers: 34,
                revenue: 67.00
            ),
            PlatformMetric(
                name: "Instagram",
                icon: "camera",
                color: .orange,
                isLive: false,
                newViewers: 4562,
                viewerTrend: 22,
                engagementRate: 9.8,
                peakViewers: 6782,
                avgWatchTime: "05:30",
                chatMessages: 567,
                newFollowers: 234,
                revenue: 0
            ),
            PlatformMetric(
                name: "Facebook",
                icon: "person.2",
                color: .blue,
                isLive: false,
                newViewers: 1234,
                viewerTrend: 3,
                engagementRate: 4.1,
                peakViewers: 2341,
                avgWatchTime: "18:45",
                chatMessages: 123,
                newFollowers: 45,
                revenue: 45.00
            ),
            PlatformMetric(
                name: "X",
                icon: "dot.radiowaves.left.and.right",
                color: .white,
                isLive: false,
                newViewers: 782,
                viewerTrend: 8,
                engagementRate: 3.2,
                peakViewers: 1023,
                avgWatchTime: "03:20",
                chatMessages: 89,
                newFollowers: 23,
                revenue: 0
            ),
            PlatformMetric(
                name: "Discord",
                icon: "bubble.left.and.bubble.right",
                color: Color(red: 0.33, green: 0.36, blue: 0.95),
                isLive: true,
                newViewers: 342,
                viewerTrend: 15,
                engagementRate: 18.5,
                peakViewers: 450,
                avgWatchTime: "58:30",
                chatMessages: 1234,
                newFollowers: 67,
                revenue: 0
            )
        ]
    }

    private func loadSchedule() {
        let now = Date()
        todaysSchedule = [
            ScheduledActivity(
                time: now.addingTimeInterval(-7200),
                title: "Morning Stream",
                subtitle: "Completed • 2.3K viewers",
                platforms: [StreamPlatformStatus(name: "Twitch", icon: "tv", color: .purple, isConnected: true)],
                color: .gray
            ),
            ScheduledActivity(
                time: now.addingTimeInterval(3600),
                title: "Speedrun Practice",
                subtitle: "In 1 hour",
                platforms: [
                    StreamPlatformStatus(name: "Twitch", icon: "tv", color: .purple, isConnected: true),
                    StreamPlatformStatus(name: "YouTube", icon: "play.rectangle", color: .red, isConnected: true)
                ],
                color: .blue
            ),
            ScheduledActivity(
                time: now.addingTimeInterval(14400),
                title: "Evening Stream",
                subtitle: "Prime time slot",
                platforms: [StreamPlatformStatus(name: "Twitch", icon: "tv", color: .purple, isConnected: true)],
                color: .purple
            )
        ]
    }

    private func loadRecommendations() {
        aiRecommendations = [
            AIRecommendation(
                title: "Optimal Stream Time",
                description: "Your audience is most active at 7-9 PM EST. Schedule your next stream then.",
                priority: .high,
                icon: "clock.badge.exclamationmark",
                actionLabel: "Schedule",
                action: { }
            ),
            AIRecommendation(
                title: "Trending Topic",
                description: "Zelda speedruns are trending. Consider this for your next stream.",
                priority: .medium,
                icon: "chart.line.uptrend.xyaxis",
                actionLabel: "Plan Content",
                action: { }
            ),
            AIRecommendation(
                title: "Engagement Tip",
                description: "Add a countdown timer to build anticipation for your stream.",
                priority: .low,
                icon: "lightbulb",
                actionLabel: nil,
                action: nil
            )
        ]
    }

    func endStream() {
        isLive = false
        streamStatus = .offline
    }

    func toggleChat() {
        isChatOpen.toggle()
    }

    func toggleRecording() {
        isRecording.toggle()
    }

    func createClip() {
        // Create clip logic
    }
}

// MARK: - Quick Stream Setup Sheet
struct QuickStreamSetup: View {
    @ObservedObject var manager: StreamingDashboardManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Quick Stream Setup")
                    .font(.title)

                // Stream setup UI would go here

                Button("Start Streaming") {
                    manager.isLive = true
                    manager.streamStatus = .live
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}