import SwiftUI
import EventKit
import EmulatorKit

public struct ContentSchedulerView: View {
    @StateObject private var calendarManager = ContentCalendarManager()
    @State private var selectedDate = Date()
    @State private var showingEventSheet = false
    @State private var selectedEvent: ScheduledContent?
    @State private var viewMode: CalendarViewMode = .week  // Default to week view - better for streaming

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // NN/g: Clear header with primary action prominently placed
            StreamSchedulerHeader(
                selectedDate: $selectedDate,
                viewMode: $viewMode,
                upcomingStreams: calendarManager.upcomingEvents.count,
                onNewStream: { showingEventSheet = true }
            )

            Divider()

            // NN/g: Split view with clear hierarchy
            HSplitView {
                // Main calendar area - primary content
                VStack(spacing: 0) {
                    // Quick stats bar for at-a-glance info
                    StreamStatsBar(manager: calendarManager)

                    Divider()

                    // Calendar view based on mode
                    Group {
                        switch viewMode {
                        case .day:
                            DayScheduleView(
                                selectedDate: $selectedDate,
                                events: calendarManager.eventsForDate(selectedDate),
                                onEventTap: { event in
                                    selectedEvent = event
                                    showingEventSheet = true
                                }
                            )
                        case .week:
                            WeekScheduleView(
                                selectedDate: $selectedDate,
                                events: calendarManager.events,
                                onEventTap: { event in
                                    selectedEvent = event
                                    showingEventSheet = true
                                }
                            )
                        case .month:
                            CalendarGridView(
                                selectedDate: $selectedDate,
                                events: calendarManager.events,
                                onEventTap: { event in
                                    selectedEvent = event
                                    showingEventSheet = true
                                }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // NN/g: Secondary content in sidebar - streamlined
                StreamSidebar(
                    calendarManager: calendarManager,
                    selectedDate: $selectedDate,
                    onQuickSchedule: {
                        selectedEvent = nil
                        showingEventSheet = true
                    }
                )
                .frame(width: 320)
            }
        }
        .sheet(isPresented: $showingEventSheet) {
            StreamSchedulingSheet(
                event: $selectedEvent,
                selectedDate: selectedDate,
                isPresented: $showingEventSheet,
                onSave: { event in
                    calendarManager.saveEvent(event)
                }
            )
        }
    }
}

// MARK: - NN/g Stream Scheduler Header
struct StreamSchedulerHeader: View {
    @Binding var selectedDate: Date
    @Binding var viewMode: CalendarViewMode
    let upcomingStreams: Int
    let onNewStream: () -> Void

    var body: some View {
        HStack(alignment: .center) {
            // NN/g: Primary task - scheduling streams
            VStack(alignment: .leading, spacing: 2) {
                Text("Stream Schedule")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("\(upcomingStreams) upcoming streams")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // NN/g: Secondary controls grouped logically
            HStack(spacing: DesignSystem.Spacing.md) {
                // Date navigation
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Button(action: previousPeriod) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .help("Previous \(viewMode.rawValue.lowercased())")

                    Text(dateDisplayText)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                        .frame(minWidth: 120)

                    Button(action: nextPeriod) {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 14, weight: .medium))
                    }
                    .buttonStyle(.borderless)
                    .help("Next \(viewMode.rawValue.lowercased())")

                    Button("Today") {
                        selectedDate = Date()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                Divider()
                    .frame(height: 20)

                // View mode picker - NN/g: clear labels
                Picker("View", selection: $viewMode) {
                    Text("Day").tag(CalendarViewMode.day)
                    Text("Week").tag(CalendarViewMode.week)
                    Text("Month").tag(CalendarViewMode.month)
                }
                .pickerStyle(SegmentedPickerStyle())
                .frame(width: 180)

                Divider()
                    .frame(height: 20)

                // NN/g: Primary action - highly visible
                Button(action: onNewStream) {
                    Label("Schedule Stream", systemImage: "plus.circle.fill")
                        .font(.system(size: 14, weight: .medium))
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(Color(.controlBackgroundColor))
    }

    private var dateDisplayText: String {
        switch viewMode {
        case .day:
            return selectedDate.formatted(.dateTime.weekday(.wide).month(.wide).day())
        case .week:
            let calendar = Calendar.current
            guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else {
                return selectedDate.formatted(.dateTime.month(.wide).year())
            }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            return "\(formatter.string(from: weekInterval.start)) - \(formatter.string(from: weekInterval.end))"
        case .month:
            return selectedDate.formatted(.dateTime.month(.wide).year())
        }
    }

    private func previousPeriod() {
        let component: Calendar.Component = {
            switch viewMode {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()
        selectedDate = Calendar.current.date(byAdding: component, value: -1, to: selectedDate) ?? selectedDate
    }

    private func nextPeriod() {
        let component: Calendar.Component = {
            switch viewMode {
            case .day: return .day
            case .week: return .weekOfYear
            case .month: return .month
            }
        }()
        selectedDate = Calendar.current.date(byAdding: component, value: 1, to: selectedDate) ?? selectedDate
    }
}

// MARK: - Calendar Grid
struct CalendarGridView: View {
    @Binding var selectedDate: Date
    let events: [ScheduledContent]
    let onEventTap: (ScheduledContent) -> Void

    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                }
            }
            .background(Color.gray.opacity(0.1))

            Divider()

            // Calendar days grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 0) {
                ForEach(calendarDays(), id: \.self) { date in
                    CalendarDayCell(
                        date: date,
                        events: eventsForDate(date),
                        isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                        isToday: Calendar.current.isDateInToday(date),
                        isCurrentMonth: Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month),
                        onTap: { selectedDate = date },
                        onEventTap: onEventTap
                    )
                }
            }
            .padding()
        }
    }

    private func calendarDays() -> [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? Date()
        let startOfWeek = calendar.dateInterval(of: .weekOfMonth, for: startOfMonth)?.start ?? Date()

        return (0..<42).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: startOfWeek)
        }
    }

    private func eventsForDate(_ date: Date) -> [ScheduledContent] {
        events.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }
    }
}

// MARK: - NN/g Stream Stats Bar
struct StreamStatsBar: View {
    let manager: ContentCalendarManager

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xxl) {
            StreamStatItem(
                icon: "calendar.badge.plus",
                title: "This Week",
                value: "\(manager.weeklyStreamCount)",
                subtitle: "streams"
            )

            Divider()
                .frame(height: 20)

            StreamStatItem(
                icon: "clock",
                title: "Total Hours",
                value: "\(manager.totalHoursScheduled)",
                subtitle: "scheduled"
            )

            Divider()
                .frame(height: 20)

            StreamStatItem(
                icon: "gamecontroller",
                title: "Games",
                value: "\(manager.uniqueGamesCount)",
                subtitle: "planned"
            )

            Spacer()

            // NN/g: Status indicator for current streaming state
            HStack(spacing: DesignSystem.Spacing.xs) {
                Circle()
                    .fill(manager.isCurrentlyStreaming ? .green : .gray)
                    .frame(width: 6, height: 6)

                Text(manager.isCurrentlyStreaming ? "Live Now" : "Offline")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(Color(.controlBackgroundColor).opacity(0.5))
    }
}

struct StreamStatItem: View {
    let icon: String
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 14))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(size: 16, weight: .semibold))

                    Text(subtitle)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - NN/g Week Schedule View
struct WeekScheduleView: View {
    @Binding var selectedDate: Date
    let events: [ScheduledContent]
    let onEventTap: (ScheduledContent) -> Void

    private var weekDates: [Date] {
        let calendar = Calendar.current
        guard let weekInterval = calendar.dateInterval(of: .weekOfYear, for: selectedDate) else { return [] }

        return (0..<7).compactMap { dayOffset in
            calendar.date(byAdding: .day, value: dayOffset, to: weekInterval.start)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                ForEach(weekDates, id: \.self) { date in
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Text(date.formatted(.dateTime.weekday(.wide)))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)

                        Text("\(Calendar.current.component(.day, from: date))")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(Calendar.current.isDateInToday(date) ? .blue : .primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Calendar.current.isDateInToday(date) ? Color.blue.opacity(0.1) : Color.clear)
                }
            }
            .background(Color(.controlBackgroundColor).opacity(0.3))

            Divider()

            // Week timeline
            ScrollView {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 7), spacing: 1) {
                    ForEach(weekDates, id: \.self) { date in
                        DayColumn(
                            date: date,
                            events: eventsForDate(date),
                            onEventTap: onEventTap
                        )
                    }
                }
                .padding()
            }
        }
    }

    private func eventsForDate(_ date: Date) -> [ScheduledContent] {
        events.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }
    }
}

// MARK: - NN/g Day Column for Week View
struct DayColumn: View {
    let date: Date
    let events: [ScheduledContent]
    let onEventTap: (ScheduledContent) -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xs) {
            ForEach(events.sorted { $0.startTime < $1.startTime }) { event in
                StreamEventCard(event: event, onTap: { onEventTap(event) })
            }

            // NN/g: Empty state with clear action
            if events.isEmpty {
                Button(action: { }) {
                    VStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "plus.circle.dotted")
                            .font(.title2)
                            .foregroundColor(.blue)

                        Text("Add Stream")
                            .font(.caption)
                            .foregroundColor(.blue)
                    }
                }
                .buttonStyle(.plain)
                .frame(maxWidth: .infinity, minHeight: 60)
                .background(Color.blue.opacity(0.05))
                .cornerRadius(DesignSystem.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.blue.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [5]))
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .padding(.horizontal, 4)
    }
}

// MARK: - NN/g Day Schedule View
struct DayScheduleView: View {
    @Binding var selectedDate: Date
    let events: [ScheduledContent]
    let onEventTap: (ScheduledContent) -> Void

    private let hourHeight: CGFloat = 80

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                // Day header
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(selectedDate.formatted(.dateTime.weekday(.wide)))
                            .font(.title3)
                            .fontWeight(.semibold)

                        Text(selectedDate.formatted(.dateTime.month(.wide).day().year()))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Text("\(events.count) streams scheduled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color(.controlBackgroundColor).opacity(0.3))

                // Timeline
                ZStack(alignment: .topLeading) {
                    // Hour lines
                    VStack(spacing: 0) {
                        ForEach(0..<24, id: \.self) { hour in
                            HStack {
                                Text("\(hour):00")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .frame(width: 50, alignment: .trailing)

                                Divider()
                            }
                            .frame(height: hourHeight)
                        }
                    }

                    // Events
                    ForEach(events.sorted { $0.startTime < $1.startTime }) { event in
                        let hour = Calendar.current.component(.hour, from: event.startTime)
                        let minute = Calendar.current.component(.minute, from: event.startTime)
                        let topOffset = CGFloat(hour) * hourHeight + CGFloat(minute) / 60 * hourHeight
                        let duration = event.duration ?? 3600
                        let height = CGFloat(duration / 3600) * hourHeight

                        StreamEventCard(event: event, onTap: { onEventTap(event) })
                            .frame(height: max(height, 40))
                            .offset(x: 60, y: topOffset)
                            .padding(.trailing, 20)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
    }
}

// MARK: - Calendar Day Cell
struct CalendarDayCell: View {
    let date: Date
    let events: [ScheduledContent]
    let isSelected: Bool
    let isToday: Bool
    let isCurrentMonth: Bool
    let onTap: () -> Void
    let onEventTap: (ScheduledContent) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            // Day number
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.system(size: 14, weight: isToday ? .bold : .regular))
                .foregroundColor(isCurrentMonth ? (isToday ? .blue : .primary) : .secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
                .padding(.top, 4)

            // Events
            VStack(spacing: 2) {
                ForEach(events.prefix(3)) { event in
                    EventPill(event: event) {
                        onEventTap(event)
                    }
                }

                if events.count > 3 {
                    Text("+\(events.count - 3) more")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 4)
                }
            }

            Spacer()
        }
        .frame(height: 100)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isToday ? Color.blue : Color.gray.opacity(0.2), lineWidth: isToday ? 2 : 1)
                )
        )
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Event Pill
struct EventPill: View {
    let event: ScheduledContent
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            Circle()
                .fill(event.categoryColor)
                .frame(width: 6, height: 6)

            Text(event.title)
                .font(.caption2)
                .lineLimit(1)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(event.categoryColor.opacity(0.2))
        .cornerRadius(DesignSystem.Radius.sm)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Upcoming Event Row
struct UpcomingEventRow: View {
    let event: ScheduledContent
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            HStack {
                Circle()
                    .fill(event.categoryColor)
                    .frame(width: 8, height: 8)

                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)

                Spacer()

                Text(event.startTime, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "gamecontroller")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(event.gameTitle ?? "No game selected")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if let duration = event.duration {
                Text("\(Int(duration / 60))h \(Int(duration.truncatingRemainder(dividingBy: 60)))m")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - NN/g Stream Event Card
struct StreamEventCard: View {
    let event: ScheduledContent
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Header with time and platforms
            HStack {
                Text(event.startTime, style: .time)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()

                // Platform indicators
                HStack(spacing: 2) {
                    ForEach(Array(event.platforms.prefix(2)), id: \.self) { platform in
                        Image(systemName: platform.iconName)
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    if event.platforms.count > 2 {
                        Text("+\(event.platforms.count - 2)")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Title and game
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)

                if let gameTitle = event.gameTitle {
                    Text(gameTitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            // Duration bar
            if let duration = event.duration {
                HStack {
                    Rectangle()
                        .fill(event.categoryColor)
                        .frame(height: 2)
                        .cornerRadius(1)

                    Text("\(Int(duration / 3600))h \(Int(duration.truncatingRemainder(dividingBy: 60)))m")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(DesignSystem.Spacing.sm)
        .background(event.categoryColor.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(event.categoryColor.opacity(0.3), lineWidth: 1)
        )
        .onTapGesture(perform: onTap)
    }
}

// MARK: - NN/g Stream Sidebar
struct StreamSidebar: View {
    @ObservedObject var calendarManager: ContentCalendarManager
    @Binding var selectedDate: Date
    let onQuickSchedule: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Quick actions header
            HStack {
                Text("Quick Actions")
                    .font(.headline)
                    .fontWeight(.semibold)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.controlBackgroundColor))

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // NN/g: Common streaming templates
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("Stream Templates")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(spacing: DesignSystem.Spacing.xs) {
                            TemplateButton(
                                icon: "gamecontroller.fill",
                                title: "Gaming Stream",
                                subtitle: "2h • Gaming Category",
                                color: .blue,
                                action: onQuickSchedule
                            )

                            TemplateButton(
                                icon: "message.fill",
                                title: "Just Chatting",
                                subtitle: "1h • Chat Category",
                                color: .purple,
                                action: onQuickSchedule
                            )

                            TemplateButton(
                                icon: "paintbrush.fill",
                                title: "Creative Work",
                                subtitle: "3h • Creative Category",
                                color: .orange,
                                action: onQuickSchedule
                            )
                        }
                    }

                    Divider()

                    // NN/g: Upcoming streams with clear priority
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Next Streams")
                                .font(.subheadline)
                                .fontWeight(.medium)

                            Spacer()

                            Text("(\(calendarManager.upcomingEvents.count))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        if calendarManager.upcomingEvents.isEmpty {
                            VStack(spacing: DesignSystem.Spacing.sm) {
                                Image(systemName: "calendar.badge.plus")
                                    .font(.title2)
                                    .foregroundColor(.secondary)

                                Text("No streams scheduled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                Button("Schedule First Stream") {
                                    onQuickSchedule()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                        } else {
                            ForEach(calendarManager.upcomingEvents.prefix(5), id: \.id) { event in
                                CompactStreamRow(event: event)
                            }
                        }
                    }

                    Divider()

                    // NN/g: Performance metrics
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("This Week")
                            .font(.subheadline)
                            .fontWeight(.medium)

                        VStack(spacing: DesignSystem.Spacing.sm) {
                            StreamMetricRow(
                                icon: "calendar",
                                title: "Streams",
                                value: "\(calendarManager.weeklyStreamCount)"
                            )

                            StreamMetricRow(
                                icon: "clock",
                                title: "Hours",
                                value: "\(calendarManager.totalHoursScheduled)"
                            )

                            StreamMetricRow(
                                icon: "gamecontroller",
                                title: "Games",
                                value: "\(calendarManager.uniqueGamesCount)"
                            )
                        }
                    }
                }
                .padding(DesignSystem.Spacing.lg)
            }
        }
        .background(Color(.controlBackgroundColor).opacity(0.3))
    }
}

struct TemplateButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.primary)

                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Image(systemName: "plus.circle")
                    .foregroundColor(color)
                    .font(.system(size: 14))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(color.opacity(0.08))
            .cornerRadius(DesignSystem.Radius.lg)
        }
        .buttonStyle(.plain)
    }
}

struct CompactStreamRow: View {
    let event: ScheduledContent

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            Circle()
                .fill(event.categoryColor)
                .frame(width: 6, height: 6)

            VStack(alignment: .leading, spacing: 1) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(1)

                Text(event.startTime, style: .relative)
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

struct StreamMetricRow: View {
    let icon: String
    let title: String
    let value: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(.blue)
                .font(.system(size: 12))
                .frame(width: 16)

            Text(title)
                .font(.system(size: 12))

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .medium))
        }
    }
}

// MARK: - NN/g Stream Scheduling Sheet
struct StreamSchedulingSheet: View {
    @Binding var event: ScheduledContent?
    let selectedDate: Date
    @Binding var isPresented: Bool
    let onSave: (ScheduledContent) -> Void

    @State private var title = ""
    @State private var gameTitle = ""
    @State private var startTime = Date()
    @State private var duration: TimeInterval = 7200 // 2 hours default
    @State private var category = ContentCategory.gaming
    @State private var notes = ""
    @State private var platforms: Set<StreamingPlatform> = [.twitch]
    @State private var recurring = false
    @State private var recurringFrequency = RecurringFrequency.weekly

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text(event == nil ? "New Stream" : "Edit Stream")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Cancel") {
                    isPresented = false
                }
                .buttonStyle(.borderless)

                Button("Save") {
                    saveEvent()
                }
                .buttonStyle(.borderedProminent)
                .disabled(title.isEmpty)
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            // Form
            Form {
                Section("Stream Details") {
                    TextField("Stream Title", text: $title)
                    TextField("Game Title", text: $gameTitle)

                    Picker("Category", selection: $category) {
                        ForEach(ContentCategory.allCases, id: \.self) { cat in
                            Label(cat.rawValue, systemImage: cat.icon)
                                .tag(cat)
                        }
                    }
                }

                Section("Schedule") {
                    DatePicker("Start Time", selection: $startTime)

                    HStack {
                        Text("Duration")
                        Spacer()
                        Picker("", selection: $duration) {
                            Text("30 min").tag(TimeInterval(1800))
                            Text("1 hour").tag(TimeInterval(3600))
                            Text("2 hours").tag(TimeInterval(7200))
                            Text("3 hours").tag(TimeInterval(10800))
                            Text("4 hours").tag(TimeInterval(14400))
                        }
                        .labelsHidden()
                    }

                    Toggle("Recurring", isOn: $recurring)

                    if recurring {
                        Picker("Frequency", selection: $recurringFrequency) {
                            Text("Daily").tag(RecurringFrequency.daily)
                            Text("Weekly").tag(RecurringFrequency.weekly)
                            Text("Bi-weekly").tag(RecurringFrequency.biweekly)
                            Text("Monthly").tag(RecurringFrequency.monthly)
                        }
                    }
                }

                Section("Platforms") {
                    ForEach(StreamingPlatform.allCases, id: \.self) { platform in
                        Toggle(platform.rawValue, isOn: Binding(
                            get: { platforms.contains(platform) },
                            set: { isOn in
                                if isOn {
                                    platforms.insert(platform)
                                } else {
                                    platforms.remove(platform)
                                }
                            }
                        ))
                    }
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 100)
                }
            }
            .formStyle(.grouped)
        }
        .frame(width: 500, height: 600)
        .onAppear {
            if let event = event {
                title = event.title
                gameTitle = event.gameTitle ?? ""
                startTime = event.startTime
                duration = event.duration ?? 7200
                category = event.category
                notes = event.notes ?? ""
                platforms = event.platforms
            }
        }
    }

    private func saveEvent() {
        let newEvent = ScheduledContent(
            id: event?.id ?? UUID(),
            title: title,
            gameTitle: gameTitle.isEmpty ? nil : gameTitle,
            startTime: startTime,
            duration: duration,
            category: category,
            notes: notes.isEmpty ? nil : notes,
            platforms: platforms
        )

        onSave(newEvent)
        isPresented = false
    }
}

// MARK: - Data Models
struct ScheduledContent: Identifiable, Codable {
    let id: UUID
    var title: String
    var gameTitle: String?
    var startTime: Date
    var duration: TimeInterval?
    var category: ContentCategory
    var notes: String?
    var platforms: Set<StreamingPlatform>

    var endTime: Date? {
        guard let duration = duration else { return nil }
        return startTime.addingTimeInterval(duration)
    }

    var categoryColor: Color {
        switch category {
        case .gaming: return .blue
        case .justChatting: return .purple
        case .creative: return .orange
        case .music: return .green
        case .irl: return .pink
        case .special: return .red
        }
    }
}

enum ContentCategory: String, CaseIterable, Codable {
    case gaming = "Gaming"
    case justChatting = "Just Chatting"
    case creative = "Creative"
    case music = "Music"
    case irl = "IRL"
    case special = "Special Event"

    var icon: String {
        switch self {
        case .gaming: return "gamecontroller"
        case .justChatting: return "bubble.left.and.bubble.right"
        case .creative: return "paintbrush"
        case .music: return "music.note"
        case .irl: return "camera"
        case .special: return "star"
        }
    }
}


enum CalendarViewMode: String, CaseIterable {
    case day = "Day"
    case week = "Week"
    case month = "Month"
}

enum RecurringFrequency: String, CaseIterable {
    case daily = "Daily"
    case weekly = "Weekly"
    case biweekly = "Bi-weekly"
    case monthly = "Monthly"
}

// MARK: - Calendar Manager
class ContentCalendarManager: ObservableObject {
    @Published var events: [ScheduledContent] = []

    var upcomingEvents: [ScheduledContent] {
        events
            .filter { $0.startTime > Date() }
            .sorted { $0.startTime < $1.startTime }
            .prefix(10)
            .map { $0 }
    }

    var weeklyStreamCount: Int {
        let calendar = Calendar.current
        let weekStart = calendar.dateInterval(of: .weekOfYear, for: Date())?.start ?? Date()
        let weekEnd = calendar.date(byAdding: .weekOfYear, value: 1, to: weekStart) ?? Date()

        return events.filter {
            $0.startTime >= weekStart && $0.startTime < weekEnd
        }.count
    }

    var totalHoursScheduled: Int {
        let totalSeconds = events.compactMap { $0.duration }.reduce(0, +)
        return Int(totalSeconds / 3600)
    }

    var uniqueGamesCount: Int {
        Set(events.compactMap { $0.gameTitle }).count
    }

    var isCurrentlyStreaming: Bool {
        let now = Date()
        return events.contains { event in
            guard let endTime = event.endTime else { return false }
            return event.startTime <= now && now <= endTime
        }
    }

    init() {
        loadEvents()
    }

    func eventsForDate(_ date: Date) -> [ScheduledContent] {
        events.filter { Calendar.current.isDate($0.startTime, inSameDayAs: date) }
    }

    func saveEvent(_ event: ScheduledContent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
        }
        persistEvents()
    }

    func deleteEvent(_ event: ScheduledContent) {
        events.removeAll { $0.id == event.id }
        persistEvents()
    }

    private func loadEvents() {
        // Load from UserDefaults or persistent storage
        if let data = UserDefaults.standard.data(forKey: "scheduled_content"),
           let decoded = try? JSONDecoder().decode([ScheduledContent].self, from: data) {
            events = decoded
        }
    }

    private func persistEvents() {
        // Save to UserDefaults or persistent storage
        if let encoded = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(encoded, forKey: "scheduled_content")
        }
    }
}