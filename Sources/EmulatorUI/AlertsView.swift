import SwiftUI
import Foundation

// MARK: - Alerts View (Nielsen Norman Group Compliant)
struct AlertsView: View {
    @State private var selectedFilter: AlertFilter = .all
    @State private var alerts: [StreamAlert] = StreamAlert.sampleAlerts
    @State private var showingAlertSettings = false
    @State private var searchText = ""
    @State private var sortOrder: SortOrder = .newest
    @State private var selectedAlerts: Set<UUID> = []
    @State private var isProcessingBulkAction = false
    @State private var lastActionFeedback: String?
    @State private var showingUndoNotification = false
    @State private var lastDeletedAlerts: [StreamAlert] = []

    private var filteredAndSortedAlerts: [StreamAlert] {
        let filtered = alerts.filter { alert in
            // Apply filter
            let matchesFilter: Bool
            switch selectedFilter {
            case .all:
                matchesFilter = true
            case .unread:
                matchesFilter = !alert.isRead
            case .followers:
                matchesFilter = alert.type == .follower
            case .donations:
                matchesFilter = alert.type == .donation || alert.type == .subscription
            case .achievements:
                matchesFilter = alert.type == .achievement || alert.type == .milestone
            case .system:
                matchesFilter = alert.type == .system
            }

            // Apply search
            let matchesSearch = searchText.isEmpty ||
                alert.title.localizedCaseInsensitiveContains(searchText) ||
                alert.message.localizedCaseInsensitiveContains(searchText)

            return matchesFilter && matchesSearch
        }

        // Apply sort
        return filtered.sorted { first, second in
            switch sortOrder {
            case .newest:
                return first.timestamp > second.timestamp
            case .oldest:
                return first.timestamp < second.timestamp
            case .priority:
                return first.priority > second.priority
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with System Status (NN: Visibility of system status)
            headerSection

            // Main Content
            if filteredAndSortedAlerts.isEmpty {
                emptyStateView
            } else {
                alertsListView
            }

            // Floating Action Feedback (NN: Visibility of system status)
            if isProcessingBulkAction {
                processingOverlay
            }
        }
        .background(backgroundGradient)
        .sheet(isPresented: $showingAlertSettings) {
            AlertSettingsView()
        }
        .overlay(alignment: .bottom) {
            if showingUndoNotification {
                undoNotification
            }
        }
    }

    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 0) {
            // Primary Header
            HStack(alignment: .center, spacing: DesignSystem.Spacing.lg) {
                // Title with clear hierarchy
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Notifications")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white)

                    // System status indicator
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("Live • \(alerts.filter { !$0.isRead }.count) unread")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }

                Spacer()

                // Bulk actions (NN: User control and freedom)
                if !selectedAlerts.isEmpty {
                    bulkActionsMenu
                }

                // Settings (NN: User control and freedom)
                Button(action: { showingAlertSettings = true }) {
                    Label("Settings", systemImage: "gear")
                        .labelStyle(.iconOnly)
                        .font(.title2)
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
                .help("Notification Settings") // Tooltip for clarity
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // Search and Filters (NN: Recognition rather than recall)
            VStack(spacing: DesignSystem.Spacing.md) {
                // Search Bar with clear affordances
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.5))

                    TextField("Search notifications...", text: $searchText)
                        .textFieldStyle(.plain)
                        .foregroundColor(.white)

                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.white.opacity(0.5))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(DesignSystem.Spacing.md)
                .background(Color.white.opacity(0.1))
                .cornerRadius(DesignSystem.Radius.lg)

                // Filter and Sort Controls
                HStack(spacing: DesignSystem.Spacing.md) {
                    // Filter Pills (NN: Recognition rather than recall)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(AlertFilter.allCases, id: \.self) { filter in
                                FilterPill(
                                    filter: filter,
                                    isSelected: selectedFilter == filter,
                                    count: alertCount(for: filter),
                                    action: { selectedFilter = filter }
                                )
                            }
                        }
                    }

                    Spacer()

                    // Sort Control (NN: User control and freedom)
                    Menu {
                        ForEach(SortOrder.allCases, id: \.self) { order in
                            Button(action: { sortOrder = order }) {
                                Label(order.label, systemImage: order.icon)
                                if sortOrder == order {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "arrow.up.arrow.down")
                            Text(sortOrder.label)
                                .font(.caption)
                        }
                        .foregroundColor(.white.opacity(0.8))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .cornerRadius(DesignSystem.Radius.md)
                    }
                    .menuStyle(.borderlessButton)
                }

                // Results count (NN: Visibility of system status)
                if !searchText.isEmpty {
                    HStack {
                        Text("\(filteredAndSortedAlerts.count) results found")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 12)

            Divider()
                .background(Color.white.opacity(0.1))
        }
        .background(Color.black.opacity(0.3))
    }

    // MARK: - Alerts List
    private var alertsListView: some View {
        ScrollView {
            LazyVStack(spacing: DesignSystem.Spacing.sm) {
                ForEach(filteredAndSortedAlerts) { alert in
                    AlertCard(
                        alert: alert,
                        isSelected: selectedAlerts.contains(alert.id),
                        onSelect: { toggleSelection(alert.id) },
                        onAction: { action in handleAlertAction(action, for: alert) },
                        onMarkRead: { markAsRead(alert) },
                        onDelete: { deleteAlert(alert) }
                    )
                    .transition(.asymmetric(
                        insertion: .slide.combined(with: .opacity),
                        removal: .scale.combined(with: .opacity)
                    ))
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
    }

    // MARK: - Empty State (NN: Help users recognize, diagnose, and recover)
    private var emptyStateView: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            Spacer()

            Image(systemName: selectedFilter == .all ? "bell.slash" : "magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.white.opacity(0.3))

            VStack(spacing: DesignSystem.Spacing.sm) {
                Text(emptyStateTitle)
                    .font(.title2)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)

                Text(emptyStateMessage)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.6))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 400)
            }

            if selectedFilter != .all || !searchText.isEmpty {
                Button(action: {
                    selectedFilter = .all
                    searchText = ""
                }) {
                    Text("Clear filters")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(Color.blue)
                        .cornerRadius(DesignSystem.Radius.lg)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyStateTitle: String {
        if !searchText.isEmpty {
            return "No results found"
        }
        switch selectedFilter {
        case .all:
            return "No notifications"
        case .unread:
            return "All caught up!"
        case .followers:
            return "No follower alerts"
        case .donations:
            return "No donation alerts"
        case .achievements:
            return "No achievements yet"
        case .system:
            return "No system messages"
        }
    }

    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms or filters"
        }
        switch selectedFilter {
        case .all:
            return "New notifications will appear here"
        case .unread:
            return "You've read all your notifications"
        case .followers:
            return "Follower notifications will show up here"
        case .donations:
            return "Donation and subscription alerts will appear here"
        case .achievements:
            return "Unlock achievements to see them here"
        case .system:
            return "System notifications will appear here"
        }
    }

    // MARK: - Bulk Actions Menu
    private var bulkActionsMenu: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            Text("\(selectedAlerts.count) selected")
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))

            Button(action: markSelectedAsRead) {
                Label("Mark as read", systemImage: "envelope.open")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)

            Button(action: deleteSelected) {
                Label("Delete", systemImage: "trash")
                    .labelStyle(.iconOnly)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .tint(.red)

            Button(action: { selectedAlerts.removeAll() }) {
                Text("Cancel")
                    .font(.caption)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Undo Notification (NN: Help users recognize and recover from errors)
    private var undoNotification: some View {
        HStack {
            Text("Deleted \(lastDeletedAlerts.count) notification\(lastDeletedAlerts.count == 1 ? "" : "s")")
                .foregroundColor(.white)

            Button(action: undoDelete) {
                Text("Undo")
                    .fontWeight(.semibold)
                    .foregroundColor(.yellow)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color.black.opacity(0.9))
        .cornerRadius(DesignSystem.Radius.lg)
        .padding()
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
                withAnimation {
                    showingUndoNotification = false
                    lastDeletedAlerts = []
                }
            }
        }
    }

    private var processingOverlay: some View {
        VStack(spacing: DesignSystem.Spacing.lg) {
            ProgressView()
                .scaleEffect(1.5)
                .progressViewStyle(CircularProgressViewStyle(tint: .white))

            Text("Processing...")
                .font(.headline)
                .foregroundColor(.white)
        }
        .frame(width: 200, height: 150)
        .background(Color.black.opacity(0.8))
        .cornerRadius(DesignSystem.Radius.xxl)
        .transition(.opacity)
    }

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                Color(red: 0.05, green: 0.05, blue: 0.08),
                Color(red: 0.02, green: 0.02, blue: 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Actions
    private func toggleSelection(_ id: UUID) {
        if selectedAlerts.contains(id) {
            selectedAlerts.remove(id)
        } else {
            selectedAlerts.insert(id)
        }
    }

    private func handleAlertAction(_ action: String, for alert: StreamAlert) {
        // Handle specific alert actions
        withAnimation {
            lastActionFeedback = "Action '\(action)' performed"
        }
    }

    private func markAsRead(_ alert: StreamAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            withAnimation {
                alerts[index].isRead = true
            }
        }
    }

    private func deleteAlert(_ alert: StreamAlert) {
        if let index = alerts.firstIndex(where: { $0.id == alert.id }) {
            withAnimation {
                lastDeletedAlerts = [alerts[index]]
                alerts.remove(at: index)
                showingUndoNotification = true
            }
        }
    }

    private func markSelectedAsRead() {
        withAnimation {
            for id in selectedAlerts {
                if let index = alerts.firstIndex(where: { $0.id == id }) {
                    alerts[index].isRead = true
                }
            }
            selectedAlerts.removeAll()
        }
    }

    private func deleteSelected() {
        withAnimation {
            lastDeletedAlerts = alerts.filter { selectedAlerts.contains($0.id) }
            alerts.removeAll { selectedAlerts.contains($0.id) }
            selectedAlerts.removeAll()
            showingUndoNotification = true
        }
    }

    private func undoDelete() {
        withAnimation {
            alerts.append(contentsOf: lastDeletedAlerts)
            lastDeletedAlerts = []
            showingUndoNotification = false
        }
    }

    private func alertCount(for filter: AlertFilter) -> Int {
        switch filter {
        case .all:
            return alerts.count
        case .unread:
            return alerts.filter { !$0.isRead }.count
        case .followers:
            return alerts.filter { $0.type == .follower }.count
        case .donations:
            return alerts.filter { $0.type == .donation || $0.type == .subscription }.count
        case .achievements:
            return alerts.filter { $0.type == .achievement || $0.type == .milestone }.count
        case .system:
            return alerts.filter { $0.type == .system }.count
        }
    }
}

// MARK: - Alert Card (NN: Aesthetic and minimalist design)
struct AlertCard: View {
    let alert: StreamAlert
    let isSelected: Bool
    let onSelect: () -> Void
    let onAction: (String) -> Void
    let onMarkRead: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @State private var isExpanded = false

    var body: some View {
        HStack(alignment: .top, spacing: DesignSystem.Spacing.md) {
            // Selection checkbox (NN: Direct manipulation)
            Button(action: onSelect) {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .foregroundColor(isSelected ? .blue : .white.opacity(0.5))
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .opacity(isHovered || isSelected ? 1 : 0)
            .animation(.easeInOut(duration: 0.2), value: isHovered)

            // Alert Icon with status
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(alert.type.color.opacity(0.2))
                    .frame(width: 40, height: 40)

                Image(systemName: alert.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(alert.type.color)

                if !alert.isRead {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 10, height: 10)
                        .offset(x: 4, y: -4)
                }
            }

            // Content
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                // Header
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                        Text(alert.title)
                            .font(.headline)
                            .foregroundColor(.white)
                            .fontWeight(alert.isRead ? .regular : .semibold)

                        Text(alert.timestamp.formatted(.relative(presentation: .named)))
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.6))
                    }

                    Spacer()

                    // Quick actions (visible on hover)
                    if isHovered {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            if !alert.isRead {
                                Button(action: onMarkRead) {
                                    Image(systemName: "envelope.open")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.6))
                                }
                                .buttonStyle(.plain)
                                .help("Mark as read")
                            }

                            Button(action: onDelete) {
                                Image(systemName: "trash")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.6))
                            }
                            .buttonStyle(.plain)
                            .help("Delete")
                        }
                        .transition(.opacity)
                    }
                }

                // Message
                Text(alert.message)
                    .font(.subheadline)
                    .foregroundColor(.white.opacity(0.8))
                    .lineLimit(isExpanded ? nil : 2)
                    .animation(.easeInOut, value: isExpanded)

                // Metadata and Actions
                if isExpanded {
                    if let metadata = alert.metadata {
                        HStack(spacing: DesignSystem.Spacing.lg) {
                            ForEach(metadata, id: \.key) { key, value in
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Text("\(key):")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.5))
                                    Text(value)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(alert.type.color)
                                }
                            }
                        }
                        .padding(.top, 4)
                    }

                    if let actions = alert.actions, !actions.isEmpty {
                        HStack(spacing: DesignSystem.Spacing.sm) {
                            ForEach(actions.prefix(3), id: \.self) { action in
                                Button(action: { onAction(action) }) {
                                    Text(action)
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 6)
                                        .background(alert.type.color)
                                        .cornerRadius(DesignSystem.Radius.md)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 8)
                    }
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(isHovered ? 0.08 : 0.05))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 2)
        )
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
    }
}

// MARK: - Filter Pill
struct FilterPill: View {
    let filter: AlertFilter
    let isSelected: Bool
    let count: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                if let icon = filter.icon {
                    Image(systemName: icon)
                        .font(.caption)
                }

                Text(filter.title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if count > 0 {
                    Text("\(count)")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(isSelected ? .black : .white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? Color.white : Color.white.opacity(0.2))
                        )
                }
            }
            .foregroundColor(isSelected ? .black : .white.opacity(0.8))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.1))
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Alert Settings View
struct AlertSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var settings = AlertSettings()
    @State private var hasUnsavedChanges = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Notification Settings")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                if hasUnsavedChanges {
                    Text("Unsaved changes")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button("Save") {
                    saveSettings()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!hasUnsavedChanges)
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.xxl) {
                    settingsSection(
                        title: "Alert Types",
                        description: "Choose which types of notifications you want to receive"
                    ) {
                        Toggle("New Followers", isOn: $settings.enableFollowerAlerts)
                            .onChange(of: settings.enableFollowerAlerts) { _ in hasUnsavedChanges = true }

                        Toggle("Donations & Tips", isOn: $settings.enableDonationAlerts)
                            .onChange(of: settings.enableDonationAlerts) { _ in hasUnsavedChanges = true }

                        Toggle("Subscriptions", isOn: $settings.enableSubscriptionAlerts)
                            .onChange(of: settings.enableSubscriptionAlerts) { _ in hasUnsavedChanges = true }

                        Toggle("Achievements & Milestones", isOn: $settings.enableAchievementAlerts)
                            .onChange(of: settings.enableAchievementAlerts) { _ in hasUnsavedChanges = true }

                        Toggle("System Messages", isOn: $settings.enableSystemAlerts)
                            .onChange(of: settings.enableSystemAlerts) { _ in hasUnsavedChanges = true }
                    }

                    settingsSection(
                        title: "Sound & Notifications",
                        description: "Configure how you're notified about new alerts"
                    ) {
                        Toggle("Play Sound", isOn: $settings.soundEnabled)
                            .onChange(of: settings.soundEnabled) { _ in hasUnsavedChanges = true }

                        if settings.soundEnabled {
                            HStack {
                                Text("Alert Sound")
                                Spacer()
                                Button("Test") {
                                    NSSound.beep()
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }

                        Toggle("Show OS Notifications", isOn: $settings.osNotifications)
                            .onChange(of: settings.osNotifications) { _ in hasUnsavedChanges = true }
                    }

                    settingsSection(
                        title: "Donation Settings",
                        description: "Configure donation alert thresholds"
                    ) {
                        HStack {
                            Text("Minimum Amount")
                            Spacer()
                            Text("$\(settings.minimumDonationAmount, specifier: "%.2f")")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $settings.minimumDonationAmount, in: 1...100, step: 1)
                            .onChange(of: settings.minimumDonationAmount) { _ in hasUnsavedChanges = true }

                        Text("Only show donation alerts for amounts above this threshold")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .frame(width: 600, height: 700)
    }

    private func settingsSection<Content: View>(
        title: String,
        description: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                content()
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.lg)
        }
    }

    private func saveSettings() {
        // Save settings
        hasUnsavedChanges = false
    }
}

// MARK: - Data Models
struct StreamAlert: Identifiable {
    let id = UUID()
    let type: AlertType
    let title: String
    let message: String
    let timestamp: Date
    var isRead: Bool
    let priority: Int
    let metadata: [(key: String, value: String)]?
    let actions: [String]?

    static let sampleAlerts: [StreamAlert] = [
        StreamAlert(
            type: .follower,
            title: "New Follower!",
            message: "GamerPro123 just followed your channel",
            timestamp: Date().addingTimeInterval(-60),
            isRead: false,
            priority: 3,
            metadata: [("Platform", "Twitch")],
            actions: ["Thank", "View Profile"]
        ),
        StreamAlert(
            type: .donation,
            title: "Donation Received!",
            message: "SuperFan donated $10.00: 'Keep up the great streams!'",
            timestamp: Date().addingTimeInterval(-300),
            isRead: false,
            priority: 5,
            metadata: [("Amount", "$10.00"), ("Platform", "YouTube")],
            actions: ["Thank", "Highlight", "Add to Wall"]
        ),
        StreamAlert(
            type: .subscription,
            title: "New Subscriber!",
            message: "NinjaGamer subscribed for 3 months",
            timestamp: Date().addingTimeInterval(-600),
            isRead: true,
            priority: 4,
            metadata: [("Tier", "Tier 2"), ("Months", "3")],
            actions: ["Thank", "Add to Wall"]
        ),
        StreamAlert(
            type: .achievement,
            title: "Achievement Unlocked!",
            message: "You've reached 1,000 total followers!",
            timestamp: Date().addingTimeInterval(-3600),
            isRead: true,
            priority: 5,
            metadata: [("Milestone", "1,000 followers"), ("Reward", "New Badge")],
            actions: ["Share", "View Badge"]
        ),
        StreamAlert(
            type: .milestone,
            title: "Stream Milestone!",
            message: "Your stream hit 500 concurrent viewers!",
            timestamp: Date().addingTimeInterval(-7200),
            isRead: true,
            priority: 4,
            metadata: [("Peak Viewers", "523"), ("Duration", "2h 15m")],
            actions: ["Celebrate", "Share"]
        ),
        StreamAlert(
            type: .system,
            title: "Stream Quality Notice",
            message: "Your stream quality has been automatically adjusted due to network conditions",
            timestamp: Date().addingTimeInterval(-10800),
            isRead: true,
            priority: 2,
            metadata: [("Quality", "720p"), ("Bitrate", "2500 kbps")],
            actions: ["Settings", "Dismiss"]
        )
    ]
}

struct AlertSettings {
    var enableFollowerAlerts = true
    var enableDonationAlerts = true
    var enableSubscriptionAlerts = true
    var enableAchievementAlerts = true
    var enableSystemAlerts = true
    var soundEnabled = true
    var osNotifications = true
    var minimumDonationAmount = 5.0
}

enum AlertType {
    case follower
    case donation
    case subscription
    case achievement
    case milestone
    case system

    var icon: String {
        switch self {
        case .follower: return "person.badge.plus"
        case .donation: return "dollarsign.circle.fill"
        case .subscription: return "star.circle.fill"
        case .achievement: return "trophy.fill"
        case .milestone: return "flag.checkered"
        case .system: return "gear"
        }
    }

    var color: Color {
        switch self {
        case .follower: return .blue
        case .donation: return .green
        case .subscription: return .purple
        case .achievement: return .orange
        case .milestone: return .yellow
        case .system: return .gray
        }
    }
}

enum AlertFilter: String, CaseIterable {
    case all
    case unread
    case followers
    case donations
    case achievements
    case system

    var title: String {
        switch self {
        case .all: return "All"
        case .unread: return "Unread"
        case .followers: return "Followers"
        case .donations: return "Donations"
        case .achievements: return "Achievements"
        case .system: return "System"
        }
    }

    var icon: String? {
        switch self {
        case .all: return nil
        case .unread: return "envelope.badge"
        case .followers: return "person.2"
        case .donations: return "dollarsign.circle"
        case .achievements: return "trophy"
        case .system: return "gear"
        }
    }
}

enum SortOrder: String, CaseIterable {
    case newest
    case oldest
    case priority

    var label: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .priority: return "Priority"
        }
    }

    var icon: String {
        switch self {
        case .newest: return "arrow.down"
        case .oldest: return "arrow.up"
        case .priority: return "star"
        }
    }
}