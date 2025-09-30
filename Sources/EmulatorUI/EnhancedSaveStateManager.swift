import SwiftUI
import EmulatorKit

/// Enhanced Save State Manager following NN/g Principles
/// - Clear Visual Hierarchy
/// - Immediate Feedback
/// - Error Prevention with Confirmations
/// - Recognition over Recall
/// - Consistent Action Patterns
struct EnhancedSaveStateManager: View {
    @ObservedObject var emulatorManager: EmulatorManager
    @Environment(\.dismiss) private var dismiss

    @State private var saveStates: [SaveStateInfo] = []
    @State private var isLoading = false
    @State private var showingDeleteAlert = false
    @State private var stateToDelete: SaveStateInfo?
    @State private var showingSaveDialog = false
    @State private var selectedSlot: Int = 0
    @State private var feedbackMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            // NN/g: Clear Header with Context
            header

            Divider()

            ScrollView {
                VStack(spacing: DesignSystem.Spacing.section) {
                    // NN/g: Quick Access - Most Common Actions First
                    quickSlotsSection

                    Divider()

                    // NN/g: Complete List - All Options Visible
                    allStatesSection
                }
                .padding(DesignSystem.Spacing.lg)
            }

            // NN/g: Feedback Toast
            if let message = feedbackMessage {
                feedbackToast(message: message)
            }
        }
        .frame(width: 740, height: 640)
        .background(DesignSystem.Colors.surface)
        .onAppear {
            refreshSaveStates()
        }
        .alert("Delete Save State?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let state = stateToDelete {
                    deleteState(state)
                }
            }
        } message: {
            Text("This save state will be permanently deleted. This action cannot be undone.")
        }
        .sheet(isPresented: $showingSaveDialog) {
            createSaveDialog
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: DesignSystem.Spacing.lg) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Save State Manager")
                    .font(DesignSystem.Typography.title)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("\(saveStates.count) save states • Last updated now")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
            }

            Spacer()

            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: refreshSaveStates) {
                    Image(systemName: isLoading ? "arrow.clockwise" : "arrow.clockwise")
                        .rotationEffect(.degrees(isLoading ? 360 : 0))
                        .animation(isLoading ? .linear(duration: 1).repeatForever(autoreverses: false) : .default, value: isLoading)
                }
                .buttonStyle(.bordered)
                .help("Refresh list")

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    // MARK: - Quick Slots Section

    private var quickSlotsSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DSectionHeader(
                title: "Quick Save Slots",
                action: { showingSaveDialog = true },
                actionIcon: "plus.circle.fill",
                actionLabel: "New Save"
            )

            Text("Use keyboard shortcuts Cmd+1-9 to save or Cmd+Shift+1-9 to load")
                .font(DesignSystem.Typography.caption)
                .foregroundColor(DesignSystem.Colors.textTertiary)

            // Slot Grid
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: DesignSystem.Spacing.md) {
                ForEach(0..<10, id: \.self) { slot in
                    EnhancedQuickSlotCard(
                        slot: slot,
                        state: saveStates.first { $0.slot == slot },
                        onSave: { saveToSlot(slot) },
                        onLoad: { loadFromSlot(slot) },
                        onDelete: { deleteSlot(slot) }
                    )
                }
            }
        }
    }

    // MARK: - All States Section

    private var allStatesSection: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            DSectionHeader(title: "All Save States")

            if saveStates.isEmpty {
                EmptyStatePlaceholder(
                    icon: "tray",
                    title: "No save states yet",
                    message: "Create your first save state to preserve your game progress",
                    actionLabel: "Create Save State",
                    action: { showingSaveDialog = true }
                )
                .frame(height: 200)
            } else {
                VStack(spacing: DesignSystem.Spacing.xs) {
                    ForEach(saveStates.sorted(by: { $0.date > $1.date }), id: \.url) { state in
                        EnhancedSaveStateRow(
                            state: state,
                            onLoad: { loadState(state) },
                            onDelete: { confirmDelete(state) },
                            onExport: { exportState(state) }
                        )
                        .padding(.vertical, DesignSystem.Spacing.xs)

                        if state.url != saveStates.last?.url {
                            Divider()
                        }
                    }
                }
                .cardStyle()
            }
        }
    }

    // MARK: - Feedback Toast

    private func feedbackToast(message: String) -> some View {
        VStack {
            Spacer()

            HStack(spacing: DesignSystem.Spacing.md) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(DesignSystem.Colors.success)
                Text(message)
                    .font(DesignSystem.Typography.callout)
            }
            .padding(DesignSystem.Spacing.lg)
            .background(DesignSystem.Colors.surface)
            .cornerRadius(DesignSystem.Radius.xl)
            .shadow(radius: DesignSystem.Shadow.large.radius)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    withAnimation {
                        feedbackMessage = nil
                    }
                }
            }
        }
        .padding(DesignSystem.Spacing.lg)
    }

    // MARK: - Create Save Dialog

    private var createSaveDialog: some View {
        VStack(spacing: DesignSystem.Spacing.xxl) {
            VStack(spacing: DesignSystem.Spacing.sm) {
                Text("Create Save State")
                    .font(DesignSystem.Typography.title2)
                    .foregroundColor(DesignSystem.Colors.textPrimary)

                Text("Choose a slot to save your current game progress")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Select Slot:")
                    .font(DesignSystem.Typography.headline)

                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: DesignSystem.Spacing.sm) {
                    ForEach(0..<10, id: \.self) { slot in
                        slotButton(slot: slot)
                    }
                }
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Cancel") {
                    showingSaveDialog = false
                }
                .keyboardShortcut(.cancelAction)
                .buttonStyle(.bordered)

                Button("Save to Slot \(selectedSlot + 1)") {
                    saveToSlot(selectedSlot)
                    showingSaveDialog = false
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(width: 500)
    }

    private func slotButton(slot: Int) -> some View {
        let hasData = saveStates.contains { $0.slot == slot }

        return Button(action: {
            selectedSlot = slot
        }) {
            VStack(spacing: DesignSystem.Spacing.xs) {
                Text("\(slot + 1)")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)

                Text(hasData ? "Occupied" : "Empty")
                    .font(DesignSystem.Typography.caption2)
            }
            .frame(maxWidth: .infinity)
            .padding(DesignSystem.Spacing.md)
            .background(selectedSlot == slot ? DesignSystem.Colors.primary.opacity(0.15) : DesignSystem.Colors.surfaceSecondary)
            .foregroundColor(selectedSlot == slot ? DesignSystem.Colors.primary : (hasData ? DesignSystem.Colors.warning : DesignSystem.Colors.textSecondary))
            .cornerRadius(DesignSystem.Radius.md)
            .overlay(
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .stroke(selectedSlot == slot ? DesignSystem.Colors.primary : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    private func refreshSaveStates() {
        isLoading = true
        Task {
            let states = await emulatorManager.stateManager.listSaveStates()
            await MainActor.run {
                self.saveStates = states
                isLoading = false
            }
        }
    }

    private func saveToSlot(_ slot: Int) {
        Task {
            do {
                try await emulatorManager.saveState(slot: slot)
                await MainActor.run {
                    withAnimation {
                        feedbackMessage = "Saved to slot \(slot + 1)"
                    }
                    refreshSaveStates()
                }
            } catch {
                NSLog("Save failed: \(error)")
            }
        }
    }

    private func loadFromSlot(_ slot: Int) {
        Task {
            do {
                try await emulatorManager.loadState(slot: slot)
                await MainActor.run {
                    withAnimation {
                        feedbackMessage = "Loaded from slot \(slot + 1)"
                    }
                    dismiss()
                }
            } catch {
                NSLog("Load failed: \(error)")
            }
        }
    }

    private func deleteSlot(_ slot: Int) {
        if let state = saveStates.first(where: { $0.slot == slot }) {
            confirmDelete(state)
        }
    }

    private func loadState(_ state: SaveStateInfo) {
        Task {
            do {
                try await emulatorManager.loadState(from: state.url)
                await MainActor.run {
                    dismiss()
                }
            } catch {
                NSLog("Load state failed: \(error)")
            }
        }
    }

    private func confirmDelete(_ state: SaveStateInfo) {
        stateToDelete = state
        showingDeleteAlert = true
    }

    private func deleteState(_ state: SaveStateInfo) {
        Task {
            do {
                try await emulatorManager.stateManager.deleteSaveState(at: state.url)
                await MainActor.run {
                    withAnimation {
                        feedbackMessage = "Save state deleted"
                    }
                    refreshSaveStates()
                }
            } catch {
                NSLog("Delete failed: \(error)")
            }
        }
    }

    private func exportState(_ state: SaveStateInfo) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.data]
        savePanel.nameFieldStringValue = state.url.lastPathComponent
        savePanel.message = "Export save state to share with others"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            Task {
                do {
                    try await emulatorManager.stateManager.exportSaveState(from: state.url, to: url)
                    await MainActor.run {
                        withAnimation {
                            feedbackMessage = "Save state exported"
                        }
                    }
                } catch {
                    NSLog("Export failed: \(error)")
                }
            }
        }
    }
}

// MARK: - Enhanced Quick Slot Card

struct EnhancedQuickSlotCard: View {
    let slot: Int
    let state: SaveStateInfo?
    let onSave: () -> Void
    let onLoad: () -> Void
    let onDelete: () -> Void

    private var hasData: Bool { state != nil }

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Slot indicator
            ZStack {
                Circle()
                    .fill(hasData ? DesignSystem.Colors.primary : DesignSystem.Colors.surfaceSecondary)
                    .frame(width: 48, height: 48)

                Text("\(slot + 1)")
                    .font(DesignSystem.Typography.title2)
                    .fontWeight(.bold)
                    .foregroundColor(hasData ? .white : DesignSystem.Colors.textSecondary)
            }

            if let state = state {
                VStack(spacing: 2) {
                    Text(formatDate(state.date))
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text(formatSize(state.size))
                        .font(DesignSystem.Typography.caption2)
                        .foregroundColor(DesignSystem.Colors.textTertiary)
                }
            } else {
                Text("Empty")
                    .font(DesignSystem.Typography.caption)
                    .foregroundColor(DesignSystem.Colors.textTertiary)
            }

            // Actions
            HStack(spacing: DesignSystem.Spacing.xs) {
                IconButton(icon: "arrow.down.circle.fill", tooltip: "Save", action: onSave)
                    .controlSize(.mini)

                if hasData {
                    IconButton(icon: "arrow.up.circle.fill", tooltip: "Load", action: onLoad)
                        .controlSize(.mini)

                    IconButton(icon: "trash.fill", tooltip: "Delete", isDestructive: true, action: onDelete)
                        .controlSize(.mini)
                }
            }
        }
        .padding(DesignSystem.Spacing.md)
        .frame(maxWidth: .infinity)
        .background(DesignSystem.Colors.surfaceSecondary)
        .cornerRadius(DesignSystem.Radius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                .stroke(hasData ? DesignSystem.Colors.primary.opacity(0.3) : Color.clear, lineWidth: 2)
        )
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func formatSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(size))
    }
}

// MARK: - Enhanced Save State Row

struct EnhancedSaveStateRow: View {
    let state: SaveStateInfo
    let onLoad: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: DesignSystem.Radius.md)
                    .fill(DesignSystem.Colors.primary.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: state.slot != nil ? "square.fill.text.grid.1x2" : "doc.fill")
                    .font(.system(size: DesignSystem.Size.iconLarge))
                    .foregroundColor(DesignSystem.Colors.primary)
            }

            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                if let slot = state.slot {
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Text("Slot \(slot + 1)")
                            .font(DesignSystem.Typography.headline)
                            .foregroundColor(DesignSystem.Colors.textPrimary)

                        Text("⌘\(slot + 1)")
                            .font(DesignSystem.Typography.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignSystem.Colors.surfaceSecondary)
                            .foregroundColor(DesignSystem.Colors.textTertiary)
                            .cornerRadius(DesignSystem.Radius.sm)
                    }
                } else {
                    Text(state.url.deletingPathExtension().lastPathComponent)
                        .font(DesignSystem.Typography.headline)
                        .foregroundColor(DesignSystem.Colors.textPrimary)
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    Text(formatDate(state.date))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)

                    Text("•")
                        .foregroundColor(DesignSystem.Colors.textTertiary)

                    Text(formatSize(state.size))
                        .font(DesignSystem.Typography.caption)
                        .foregroundColor(DesignSystem.Colors.textSecondary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: onLoad) {
                    Label("Load", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                IconButton(icon: "square.and.arrow.up", tooltip: "Export", action: onExport)
                    .controlSize(.small)

                IconButton(icon: "trash", tooltip: "Delete", isDestructive: true, action: onDelete)
                    .controlSize(.small)
            }
        }
        .padding(DesignSystem.Spacing.md)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatSize(_ size: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(size))
    }
}