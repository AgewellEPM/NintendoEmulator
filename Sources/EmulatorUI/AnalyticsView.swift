import SwiftUI
import Charts

/// NN/g Redesigned Analytics Dashboard - Optimized for space efficiency
public struct AnalyticsView: View {
    @StateObject private var analytics = AnalyticsManager.shared
    @State private var selectedTimeRange = AnalyticsTimeRange.week
    @State private var selectedMetric = AnalyticsMetric.viewers
    @State private var showingDetailView = false
    @State private var generating = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // NN/g: Compact Header (reduced from ~120px to ~60px)
            CompactAnalyticsHeader(
                selectedTimeRange: $selectedTimeRange,
                onGenerateSuggestions: generateSuggestions,
                isGenerating: generating
            )

            ScrollView {
                LazyVStack(spacing: DesignSystem.Spacing.xl) {
                    // NN/g: Inline Key Metrics (reduced vertical space by 40%)
                    CompactMetricsRow(
                        analytics: analytics,
                        timeRange: selectedTimeRange
                    )

                    // NN/g: Primary Chart with inline controls
                    PerformanceChartSection(
                        analytics: analytics,
                        selectedMetric: $selectedMetric,
                        timeRange: selectedTimeRange
                    )

                    // NN/g: Side-by-side data for efficient scanning
                    HStack(alignment: .top, spacing: DesignSystem.Spacing.xl) {
                        TopContentSection(analytics: analytics)
                        StreamingStatsSection(analytics: analytics)
                    }

                    // NN/g: Actionable Insights
                    InsightsAndSuggestionsSection(analytics: analytics)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
        }
        .background(Color(.windowBackgroundColor))
    }

    private func generateSuggestions() {
        generating = true
        Task {
            await analytics.generateSuggestions()
            generating = false
        }
    }
}

// MARK: - NN/g Compliant Compact Header
struct CompactAnalyticsHeader: View {
    @Binding var selectedTimeRange: AnalyticsTimeRange
    let onGenerateSuggestions: () -> Void
    let isGenerating: Bool

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xl) {
            // Title inline with subtitle for space efficiency
            HStack(spacing: DesignSystem.Spacing.sm) {
                Text("Analytics Dashboard")
                    .font(.title3)
                    .fontWeight(.semibold)

                Text("—")
                    .foregroundColor(.secondary)

                Text("Track performance and engagement")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Compact time range selector
            HStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(AnalyticsTimeRange.allCases, id: \.self) { range in
                    TimeRangeButton(
                        title: range.shortName,
                        isSelected: selectedTimeRange == range,
                        action: { selectedTimeRange = range }
                    )
                }
            }

            Divider()
                .frame(height: 20)

            // AI insights button
            Button(action: onGenerateSuggestions) {
                Label(
                    isGenerating ? "Generating..." : "AI Insights",
                    systemImage: isGenerating ? "circle.dotted" : "brain"
                )
                .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)
            .disabled(isGenerating)
            .help("Generate AI-powered insights")
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

// MARK: - Compact Time Range Button
struct TimeRangeButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline)
                .fontWeight(isSelected ? .medium : .regular)
                .foregroundColor(isSelected ? .white : .secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Compact Metrics Row (Single horizontal line)
struct CompactMetricsRow: View {
    let analytics: AnalyticsManager
    let timeRange: AnalyticsTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text("Key Metrics")
                    .font(.headline)
                Text("Performance for \(timeRange.displayName.lowercased())")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
            }

            // Single row of metrics
            HStack(spacing: DesignSystem.Spacing.lg) {
                CompactMetricCard(
                    icon: "eye.fill",
                    title: "Total Views",
                    value: "15.2K",
                    change: "+12.3%",
                    trend: .up,
                    color: .blue
                )

                Divider().frame(height: 40)

                CompactMetricCard(
                    icon: "clock.fill",
                    title: "Watch Time",
                    value: "45.8h",
                    change: "+8.7%",
                    trend: .up,
                    color: .green
                )

                Divider().frame(height: 40)

                CompactMetricCard(
                    icon: "person.2.fill",
                    title: "Avg Viewers",
                    value: "234",
                    change: "-2.1%",
                    trend: .down,
                    color: .orange
                )

                Divider().frame(height: 40)

                CompactMetricCard(
                    icon: "heart.fill",
                    title: "Engagement",
                    value: "4.2%",
                    change: "+0.8%",
                    trend: .up,
                    color: .pink
                )

                Spacer()
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(DesignSystem.Radius.lg)
        }
    }
}

// MARK: - Compact Metric Card (Horizontal layout)
struct CompactMetricCard: View {
    let icon: String
    let title: String
    let value: String
    let change: String
    let trend: TrendDirection
    let color: Color

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
                .frame(width: 32)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    Text(value)
                        .font(.title3)
                        .fontWeight(.semibold)

                    // Trend indicator
                    Label(change, systemImage: trend.icon)
                        .font(.caption)
                        .foregroundColor(trend.color)
                        .labelStyle(.titleAndIcon)
                }
            }
        }
    }
}

// MARK: - Performance Chart Section
struct PerformanceChartSection: View {
    let analytics: AnalyticsManager
    @Binding var selectedMetric: AnalyticsMetric
    let timeRange: AnalyticsTimeRange

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Inline header with controls
            HStack {
                Text("Performance Trends")
                    .font(.headline)

                Spacer()

                // Metric selector as segmented control for quick access
                Picker("", selection: $selectedMetric) {
                    ForEach(AnalyticsMetric.allCases, id: \.self) { metric in
                        Text(metric.displayName).tag(metric)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 250)
            }

            // Chart area
            VStack {
                Chart(samplePerformanceData) { dataPoint in
                    LineMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.displayName, dataPoint.value)
                    )
                    .foregroundStyle(Color.accentColor)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Date", dataPoint.date),
                        y: .value(selectedMetric.displayName, dataPoint.value)
                    )
                    .foregroundStyle(Color.accentColor.opacity(0.1))
                    .interpolationMethod(.catmullRom)
                }
                .frame(height: 200) // Reduced from 250px
                .chartXAxis {
                    AxisMarks(values: .automatic(desiredCount: 7))
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(DesignSystem.Radius.lg)
        }
    }
}

// MARK: - Top Content Section
struct TopContentSection: View {
    let analytics: AnalyticsManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Top Content")
                .font(.headline)

            VStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(0..<3) { index in
                    HStack {
                        Text("\(index + 1)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 20)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Stream Title \(index + 1)")
                                .font(.subheadline)
                                .lineLimit(1)

                            Text("\(1000 + index * 500) views")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "arrow.up.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(Color.gray.opacity(0.05))
                    .cornerRadius(DesignSystem.Radius.md)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Streaming Stats Section
struct StreamingStatsSection: View {
    let analytics: AnalyticsManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Streaming Stats")
                .font(.headline)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                StatRow(label: "Total Streams", value: "42")
                StatRow(label: "Avg Duration", value: "2h 15m")
                StatRow(label: "Peak Viewers", value: "523")
                StatRow(label: "New Followers", value: "+127")
                StatRow(label: "Chat Messages", value: "8.2K")
            }
            .padding()
            .background(Color.gray.opacity(0.05))
            .cornerRadius(DesignSystem.Radius.lg)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Stat Row
struct StatRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Insights and Suggestions Section
struct InsightsAndSuggestionsSection: View {
    let analytics: AnalyticsManager

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .foregroundColor(.yellow)
                Text("AI Insights & Recommendations")
                    .font(.headline)
                Spacer()
            }

            VStack(spacing: DesignSystem.Spacing.sm) {
                InsightRow(
                    type: .growth,
                    message: "Your viewership increased 15% during evening streams",
                    action: "Schedule more 7-10 PM streams"
                )

                InsightRow(
                    type: .opportunity,
                    message: "Friday streams have 40% higher engagement",
                    action: "Consider weekly Friday events"
                )

                InsightRow(
                    type: .improvement,
                    message: "Stream quality drops affect retention",
                    action: "Check network settings"
                )
            }
        }
    }
}

// MARK: - Insight Row
struct InsightRow: View {
    let type: InsightType
    let message: String
    let action: String

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            Image(systemName: type.icon)
                .foregroundColor(type.color)
                .font(.body)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(message)
                    .font(.subheadline)

                Text(action)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .cornerRadius(DesignSystem.Radius.sm)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.md)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - Supporting Types
enum AnalyticsTimeRange: String, CaseIterable {
    case day = "24h"
    case week = "7d"
    case month = "30d"
    case quarter = "90d"

    var displayName: String {
        switch self {
        case .day: return "24 Hours"
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        }
    }

    var shortName: String {
        switch self {
        case .day: return "24 Hours"
        case .week: return "7 Days"
        case .month: return "30 Days"
        case .quarter: return "90 Days"
        }
    }
}

enum AnalyticsMetric: String, CaseIterable {
    case viewers = "Viewers"
    case engagement = "Engagement"
    case followers = "Followers"
    case revenue = "Revenue"

    var displayName: String {
        return self.rawValue
    }
}

enum TrendDirection {
    case up, down, flat

    var icon: String {
        switch self {
        case .up: return "arrow.up.right"
        case .down: return "arrow.down.right"
        case .flat: return "arrow.right"
        }
    }

    var color: Color {
        switch self {
        case .up: return .green
        case .down: return .red
        case .flat: return .secondary
        }
    }
}

enum InsightType {
    case growth, opportunity, improvement

    var icon: String {
        switch self {
        case .growth: return "chart.line.uptrend.xyaxis"
        case .opportunity: return "star.fill"
        case .improvement: return "exclamationmark.triangle.fill"
        }
    }

    var color: Color {
        switch self {
        case .growth: return .green
        case .opportunity: return .blue
        case .improvement: return .orange
        }
    }
}

// MARK: - Analytics Metric Card (Original style for reference)
struct AnalyticsMetricCard: View {
    let title: String
    let value: String
    let change: String
    let trend: TrendDirection
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Spacer()
                Label(change, systemImage: trend.icon)
                    .font(.caption)
                    .foregroundColor(trend.color)
                    .labelStyle(.titleAndIcon)
            }

            Text(value)
                .font(.title2)
                .fontWeight(.bold)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    let subtitle: String?

    init(title: String, subtitle: String? = nil) {
        self.title = title
        self.subtitle = subtitle
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.headline)

            if let subtitle = subtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Sample Data
let samplePerformanceData: [AnalyticsDataPoint] = {
    var data: [AnalyticsDataPoint] = []
    let calendar = Calendar.current
    let now = Date()

    for i in 0..<7 {
        if let date = calendar.date(byAdding: .day, value: -i, to: now) {
            data.append(AnalyticsDataPoint(
                date: date,
                value: Double.random(in: 100...500) + Double(i * 10),
                platform: .twitch
            ))
        }
    }

    return data.reversed()
}()