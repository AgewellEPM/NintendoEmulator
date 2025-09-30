import SwiftUI

// MARK: - Calendar View Components
struct DayViewCalendar: View {
    @Binding var selectedDate: Date
    let posts: [SocialMediaPost]
    let onPostTap: (SocialMediaPost) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Time slots from 6 AM to 11 PM
                ForEach(6..<24) { hour in
                    HStack(alignment: .top) {
                        // Time label
                        Text("\(hour):00")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .frame(width: 50, alignment: .trailing)
                            .padding(.trailing, 8)

                        // Posts for this hour
                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                            ForEach(postsForHour(hour)) { post in
                                PostCard(post: post, onTap: { onPostTap(post) })
                            }

                            if postsForHour(hour).isEmpty {
                                Rectangle()
                                    .fill(Color.gray.opacity(0.1))
                                    .frame(height: 40)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.vertical, 2)

                    Divider()
                }
            }
            .padding()
        }
    }

    private func postsForHour(_ hour: Int) -> [SocialMediaPost] {
        posts.filter { post in
            Calendar.current.component(.hour, from: post.scheduledDate) == hour
        }
    }
}

struct WeekViewCalendar: View {
    @Binding var selectedDate: Date
    let posts: [SocialMediaPost]
    let onPostTap: (SocialMediaPost) -> Void

    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    var body: some View {
        VStack(spacing: 0) {
            // Day headers
            HStack(spacing: 0) {
                Text("Time")
                    .font(.caption)
                    .fontWeight(.medium)
                    .frame(width: 60)

                ForEach(daysOfWeek, id: \.self) { day in
                    Text(day)
                        .font(.caption)
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding()
            .background(Color.gray.opacity(0.1))

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(6..<24) { hour in
                        HStack(spacing: 0) {
                            Text("\(hour):00")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .frame(width: 60)

                            ForEach(0..<7) { dayOffset in
                                let date = Calendar.current.date(byAdding: .day, value: dayOffset, to: startOfWeek) ?? Date()
                                let dayPosts = postsForDateTime(date, hour: hour)

                                VStack(spacing: 2) {
                                    ForEach(dayPosts) { post in
                                        MiniPostCard(post: post, onTap: { onPostTap(post) })
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 40)
                                .background(Color.gray.opacity(0.02))
                                .border(Color.gray.opacity(0.1), width: 0.5)
                            }
                        }
                    }
                }
            }
        }
    }

    private var startOfWeek: Date {
        Calendar.current.dateInterval(of: .weekOfYear, for: selectedDate)?.start ?? selectedDate
    }

    private func postsForDateTime(_ date: Date, hour: Int) -> [SocialMediaPost] {
        posts.filter { post in
            Calendar.current.isDate(post.scheduledDate, inSameDayAs: date) &&
            Calendar.current.component(.hour, from: post.scheduledDate) == hour
        }
    }
}

struct MonthViewCalendar: View {
    @Binding var selectedDate: Date
    let posts: [SocialMediaPost]
    let onPostTap: (SocialMediaPost) -> Void
    let onDateDrop: (SocialMediaPost, Date) -> Void

    var body: some View {
        VStack(spacing: 0) {
            // Calendar grid
            CalendarMonthGrid(
                selectedDate: $selectedDate,
                posts: posts,
                onPostTap: onPostTap,
                onDateDrop: onDateDrop
            )
        }
    }
}

struct CalendarMonthGrid: View {
    @Binding var selectedDate: Date
    let posts: [SocialMediaPost]
    let onPostTap: (SocialMediaPost) -> Void
    let onDateDrop: (SocialMediaPost, Date) -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 1), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 1) {
            ForEach(monthDays(), id: \.self) { date in
                CalendarDayView(
                    date: date,
                    posts: postsForDate(date),
                    isSelected: Calendar.current.isDate(date, inSameDayAs: selectedDate),
                    isCurrentMonth: Calendar.current.isDate(date, equalTo: selectedDate, toGranularity: .month),
                    onPostTap: onPostTap,
                    onDrop: { post in onDateDrop(post, date) }
                )
            }
        }
        .padding()
    }

    private func monthDays() -> [Date] {
        let calendar = Calendar.current
        let startOfMonth = calendar.dateInterval(of: .month, for: selectedDate)?.start ?? Date()
        let range = calendar.range(of: .day, in: .month, for: startOfMonth)!

        return (1..<range.count + 1).compactMap { day in
            calendar.date(byAdding: .day, value: day - 1, to: startOfMonth)
        }
    }

    private func postsForDate(_ date: Date) -> [SocialMediaPost] {
        posts.filter { Calendar.current.isDate($0.scheduledDate, inSameDayAs: date) }
    }
}

struct CalendarDayView: View {
    let date: Date
    let posts: [SocialMediaPost]
    let isSelected: Bool
    let isCurrentMonth: Bool
    let onPostTap: (SocialMediaPost) -> Void
    let onDrop: (SocialMediaPost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
            // Day number
            Text("\(Calendar.current.component(.day, from: date))")
                .font(.caption)
                .fontWeight(Calendar.current.isDateInToday(date) ? .bold : .regular)
                .foregroundColor(isCurrentMonth ? .primary : .secondary)

            // Post pills
            ForEach(posts.prefix(3)) { post in
                PostPill(post: post, onTap: { onPostTap(post) })
            }

            if posts.count > 3 {
                Text("+\(posts.count - 3)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()
        }
        .padding(DesignSystem.Spacing.xs)
        .frame(height: 100)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Calendar.current.isDateInToday(date) ? Color.blue : Color.gray.opacity(0.2))
        )
        .onDrop(of: ["public.data"], isTargeted: nil) { providers in
            // Handle drop
            return true
        }
    }
}

struct PostPill: View {
    let post: SocialMediaPost
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Array(post.platforms.prefix(2)), id: \.self) { platform in
                Image(systemName: platform.icon)
                    .font(.system(size: 8))
            }

            Text(post.title)
                .font(.system(size: 10))
                .lineLimit(1)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 2)
        .background(Color.blue.opacity(0.2))
        .cornerRadius(DesignSystem.Radius.sm)
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Content Library Components
struct AssetCard: View {
    let asset: ContentAsset
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading) {
            // Thumbnail
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.2))
                .aspectRatio(16/9, contentMode: .fit)
                .overlay(
                    Image(systemName: asset.type.icon)
                        .font(.title)
                        .foregroundColor(.gray)
                )
                .overlay(
                    // Selection indicator
                    ZStack {
                        if isSelected {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.blue, lineWidth: 2)

                            Circle()
                                .fill(Color.blue)
                                .frame(width: 24, height: 24)
                                .overlay(
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.white)
                                        .font(.caption)
                                )
                                .padding(DesignSystem.Spacing.sm)
                        }
                    },
                    alignment: .topTrailing
                )

            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(asset.name)
                    .font(.caption)
                    .lineLimit(1)

                HStack {
                    Text(asset.type.rawValue)
                        .font(.caption2)
                        .foregroundColor(.secondary)

                    Spacer()

                    Text(formatFileSize(asset.size))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .onTapGesture(perform: onTap)
    }

    private func formatFileSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

struct AssetUploader: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedFiles: [URL] = []
    @State private var uploadProgress: Double = 0
    @State private var isUploading = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Upload Assets")
                    .font(.title2)
                    .fontWeight(.semibold)

                Spacer()

                Button("Cancel") { dismiss() }
                    .disabled(isUploading)

                Button("Upload") {
                    startUpload()
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedFiles.isEmpty || isUploading)
            }
            .padding()

            Divider()

            // Drop zone
            VStack {
                Image(systemName: "square.and.arrow.up")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)

                Text("Drop files here or click to browse")
                    .font(.headline)

                Text("Supports images, videos, and documents")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button("Choose Files") {
                    // File picker
                }
                .buttonStyle(.bordered)
                .padding(.top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(DesignSystem.Radius.xxl)
            .padding()

            if isUploading {
                ProgressView(value: uploadProgress)
                    .padding()
            }
        }
        .frame(width: 600, height: 400)
    }

    private func startUpload() {
        isUploading = true
        // Upload logic
    }
}

// MARK: - Automation Components
struct WorkflowTemplate: View {
    let title: String
    let description: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.blue)

            Text(title)
                .font(.headline)

            Text(description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            Button("Use Template") {
                // Create workflow from template
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
        .padding()
        .frame(width: 200, height: 150)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.xxl)
    }
}

struct WorkflowCard: View {
    let workflow: AutomationWorkflow
    let onToggle: () -> Void
    let onEdit: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(workflow.name)
                    .font(.headline)

                Text(workflow.description)
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Label("\(workflow.triggers.count) triggers", systemImage: "bolt")
                    Label("\(workflow.actions.count) actions", systemImage: "play")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: .constant(workflow.isActive))
                .toggleStyle(SwitchToggleStyle())
                .onTapGesture(perform: onToggle)

            Button("Edit") { onEdit() }
                .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct WorkflowBuilder: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        Text("Workflow Builder")
            .frame(width: 800, height: 600)
    }
}

struct WorkflowEditor: View {
    let workflow: AutomationWorkflow
    @ObservedObject var manager: ContentCreatorHubManager

    var body: some View {
        Text("Edit: \(workflow.name)")
            .frame(width: 800, height: 600)
    }
}

// MARK: - Supporting Components
struct PostCard: View {
    let post: SocialMediaPost
    let onTap: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(post.title)
                    .font(.subheadline)
                    .lineLimit(1)

                HStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(Array(post.platforms), id: \.self) { platform in
                        Image(systemName: platform.icon)
                            .font(.caption)
                            .foregroundColor(platform.color)
                    }
                }
            }

            Spacer()

            Text(post.scheduledDate, style: .time)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.md)
        .onTapGesture(perform: onTap)
    }
}

struct MiniPostCard: View {
    let post: SocialMediaPost
    let onTap: () -> Void

    var body: some View {
        Text(post.title)
            .font(.system(size: 10))
            .lineLimit(1)
            .padding(2)
            .background(Color.blue.opacity(0.2))
            .cornerRadius(2)
            .onTapGesture(perform: onTap)
    }
}

struct PostDetailView: View {
    let post: SocialMediaPost
    @ObservedObject var manager: ContentCreatorHubManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Post Details: \(post.title)")
            Button("Close") { dismiss() }
        }
        .frame(width: 600, height: 500)
    }
}

struct PostComposer: View {
    @ObservedObject var manager: ContentCreatorHubManager
    let initialDate: Date
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Compose New Post")
            Button("Cancel") { dismiss() }
        }
        .frame(width: 700, height: 600)
    }
}

struct PlatformFilterButton: View {
    let platform: SocialPlatform
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: platform.icon)
                .foregroundColor(isActive ? platform.color : .gray)
        }
        .buttonStyle(.borderless)
    }
}

struct PlatformTab: View {
    let platform: SocialPlatform
    let isSelected: Bool
    let unreadCount: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: platform.icon)
                Text(platform.rawValue)

                if unreadCount > 0 {
                    Text("\(unreadCount)")
                        .font(.caption)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.red)
                        .foregroundColor(.white)
                        .cornerRadius(DesignSystem.Radius.xl)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? platform.color.opacity(0.2) : Color.clear)
            .cornerRadius(DesignSystem.Radius.md)
        }
        .buttonStyle(.plain)
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "person.crop.circle")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                HStack {
                    Text(conversation.participantName)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if conversation.unreadCount > 0 {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(conversation.messages.last?.content ?? "")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: DesignSystem.Spacing.xs) {
                Text(conversation.messages.last?.timestamp ?? Date(), style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)

                if conversation.unreadCount > 0 {
                    Text("\(conversation.unreadCount)")
                        .font(.caption)
                        .padding(DesignSystem.Spacing.xs)
                        .background(Color.blue)
                        .foregroundColor(.white)
                        .cornerRadius(DesignSystem.Radius.xl)
                }
            }
        }
        .padding()
        .background(isSelected ? Color.gray.opacity(0.1) : Color.clear)
        .onTapGesture(perform: onTap)
    }
}

struct MessageBubble: View {
    let message: Message

    var body: some View {
        HStack {
            if message.isFromMe { Spacer() }

            VStack(alignment: message.isFromMe ? .trailing : .leading, spacing: DesignSystem.Spacing.xs) {
                Text(message.content)
                    .padding(DesignSystem.Spacing.md)
                    .background(message.isFromMe ? Color.blue : Color.gray.opacity(0.2))
                    .foregroundColor(message.isFromMe ? .white : .primary)
                    .cornerRadius(16)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            if !message.isFromMe { Spacer() }
        }
    }
}

struct CollaborationProjectCard: View {
    let project: CollaborationProject
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Text(project.name)
                    .font(.headline)

                Spacer()

                if let deadline = project.deadline {
                    Label(deadline.formatted(.dateTime.day().month()), systemImage: "calendar")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Text(project.description)
                .font(.caption)
                .foregroundColor(.secondary)
                .lineLimit(2)

            // Member avatars
            HStack {
                ForEach(project.members.prefix(3)) { member in
                    Circle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(member.name.prefix(1))
                                .font(.caption)
                        )
                }

                if project.members.count > 3 {
                    Text("+\(project.members.count - 3)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .frame(height: 200)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.xxl)
        .onTapGesture(perform: onTap)
    }
}

struct InviteCollaboratorView: View {
    @ObservedObject var manager: ContentCreatorHubManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack {
            Text("Invite Collaborator")
            Button("Cancel") { dismiss() }
        }
        .frame(width: 500, height: 400)
    }
}

struct ProjectDetailView: View {
    let project: CollaborationProject
    @ObservedObject var manager: ContentCreatorHubManager

    var body: some View {
        Text("Project: \(project.name)")
            .frame(width: 800, height: 600)
    }
}

struct RevenueCard: View {
    let title: String
    let amount: Double
    let change: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Text("$\(amount, specifier: "%.2f")")
                .font(.title2)
                .fontWeight(.semibold)

            Text(change)
                .font(.caption)
                .foregroundColor(.green)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.gray.opacity(0.05))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

struct CampaignRow: View {
    let campaign: MarketingCampaign

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text(campaign.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(campaign.brand)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Text("$\(campaign.revenue, specifier: "%.2f")")
                .font(.subheadline)
                .fontWeight(.medium)

            Text(campaign.status)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Color.green.opacity(0.2))
                .foregroundColor(.green)
                .cornerRadius(DesignSystem.Radius.sm)
        }
    }
}

struct HeatmapView: View {
    let data: [[Double]]

    var body: some View {
        // Simplified heatmap visualization
        Rectangle()
            .fill(LinearGradient(
                colors: [.blue, .green, .yellow, .orange, .red],
                startPoint: .leading,
                endPoint: .trailing
            ))
            .overlay(
                Text("Best times visualization")
                    .foregroundColor(.white)
            )
    }
}

// MARK: - AssetType Extension
extension AssetType {
    var icon: String {
        switch self {
        case .image: return "photo"
        case .video: return "video"
        case .audio: return "waveform"
        case .document: return "doc"
        case .template: return "doc.text"
        }
    }
}