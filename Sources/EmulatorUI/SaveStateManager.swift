import SwiftUI
import EmulatorKit

/// Enhanced Save State Manager UI
struct SaveStateManagerView: View {
    @ObservedObject var emulatorManager: EmulatorManager
    @Environment(\.dismiss) private var dismiss

    @State private var saveStates: [SaveStateInfo] = []
    @State private var isLoading = false
    @State private var showingDeleteAlert = false
    @State private var stateToDelete: SaveStateInfo?
    @State private var showingSaveDialog = false
    @State private var selectedSlot: Int = 0
    @State private var saveStateName = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Save State Manager")
                    .font(.title)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
            }
            .padding()

            Divider()

            // Quick Save/Load Section
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("Quick Save Slots")
                    .font(.headline)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: DesignSystem.Spacing.md) {
                        ForEach(0..<10, id: \.self) { slot in
                            QuickSlotCard(
                                slot: slot,
                                hasData: saveStates.contains { $0.slot == slot },
                                onSave: { saveToSlot(slot) },
                                onLoad: { loadFromSlot(slot) },
                                onDelete: { deleteSlot(slot) }
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .frame(height: 140)
            }
            .padding()

            Divider()

            // All Save States
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                HStack {
                    Text("All Save States")
                        .font(.headline)

                    Spacer()

                    Button(action: { showingSaveDialog = true }) {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "plus.circle.fill")
                            Text("New Save")
                        }
                    }
                    .buttonStyle(.borderedProminent)

                    Button(action: refreshSaveStates) {
                        Image(systemName: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                }

                if saveStates.isEmpty {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)

                        Text("No save states yet")
                            .font(.title3)
                            .foregroundColor(.secondary)

                        Text("Save your progress to continue later")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
                } else {
                    List {
                        ForEach(saveStates, id: \.url) { state in
                            SaveStateRow(
                                state: state,
                                onLoad: { loadState(state) },
                                onDelete: { confirmDelete(state) },
                                onExport: { exportState(state) }
                            )
                        }
                    }
                }
            }
            .padding()
        }
        .frame(width: 700, height: 600)
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
            Text("This action cannot be undone.")
        }
        .sheet(isPresented: $showingSaveDialog) {
            NewSaveStateDialog(
                selectedSlot: $selectedSlot,
                name: $saveStateName,
                onSave: { slot in
                    saveToSlot(slot)
                    showingSaveDialog = false
                }
            )
        }
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
            try? await emulatorManager.saveState(slot: slot)
            refreshSaveStates()
        }
    }

    private func loadFromSlot(_ slot: Int) {
        Task {
            try? await emulatorManager.loadState(slot: slot)
        }
    }

    private func deleteSlot(_ slot: Int) {
        if let state = saveStates.first(where: { $0.slot == slot }) {
            confirmDelete(state)
        }
    }

    private func loadState(_ state: SaveStateInfo) {
        Task {
            try? await emulatorManager.loadState(from: state.url)
            dismiss()
        }
    }

    private func confirmDelete(_ state: SaveStateInfo) {
        stateToDelete = state
        showingDeleteAlert = true
    }

    private func deleteState(_ state: SaveStateInfo) {
        Task {
            try? await emulatorManager.stateManager.deleteSaveState(at: state.url)
            refreshSaveStates()
        }
    }

    private func exportState(_ state: SaveStateInfo) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.data]
        savePanel.nameFieldStringValue = state.url.lastPathComponent

        if savePanel.runModal() == .OK, let url = savePanel.url {
            Task {
                try? await emulatorManager.stateManager.exportSaveState(from: state.url, to: url)
            }
        }
    }
}

// MARK: - Quick Slot Card

struct QuickSlotCard: View {
    let slot: Int
    let hasData: Bool
    let onSave: () -> Void
    let onLoad: () -> Void
    let onDelete: () -> Void

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.sm) {
            // Slot number
            ZStack {
                Circle()
                    .fill(hasData ? Color.blue : Color.gray.opacity(0.3))
                    .frame(width: 44, height: 44)

                Text("\(slot + 1)")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
            }

            // Actions
            HStack(spacing: DesignSystem.Spacing.xs) {
                Button(action: onSave) {
                    Image(systemName: "arrow.down.circle")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .help("Save to slot \(slot + 1)")

                if hasData {
                    Button(action: onLoad) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)
                    .help("Load from slot \(slot + 1)")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .foregroundColor(.red)
                    .help("Delete slot \(slot + 1)")
                }
            }

            Text(hasData ? "Slot \(slot + 1)" : "Empty")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(DesignSystem.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.1))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(hasData ? Color.blue : Color.clear, lineWidth: 2)
        )
        .frame(width: 100)
    }
}

// MARK: - Save State Row

struct SaveStateRow: View {
    let state: SaveStateInfo
    let onLoad: () -> Void
    let onDelete: () -> Void
    let onExport: () -> Void

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: state.date)
    }

    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(state.size))
    }

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Icon
            Image(systemName: state.slot != nil ? "square.fill.text.grid.1x2" : "doc.fill")
                .font(.title2)
                .foregroundColor(.blue)
                .frame(width: 40)

            // Info
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                if let slot = state.slot {
                    Text("Quick Save Slot \(slot + 1)")
                        .font(.headline)
                } else {
                    Text(state.url.deletingPathExtension().lastPathComponent)
                        .font(.headline)
                }

                HStack(spacing: DesignSystem.Spacing.md) {
                    Text(formattedDate)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text(formattedSize)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Actions
            HStack(spacing: DesignSystem.Spacing.sm) {
                Button(action: onLoad) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "play.fill")
                        Text("Load")
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(action: onExport) {
                    Image(systemName: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Export save state")

                Button(action: onDelete) {
                    Image(systemName: "trash")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .foregroundColor(.red)
                .help("Delete save state")
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - New Save Dialog

struct NewSaveStateDialog: View {
    @Binding var selectedSlot: Int
    @Binding var name: String
    let onSave: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: DesignSystem.Spacing.xl) {
            Text("Create New Save State")
                .font(.title2)
                .fontWeight(.bold)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                Text("Save to slot:")
                    .font(.headline)

                Picker("Slot", selection: $selectedSlot) {
                    ForEach(0..<10, id: \.self) { slot in
                        Text("Slot \(slot + 1)").tag(slot)
                    }
                }
                .pickerStyle(.segmented)
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    onSave(selectedSlot)
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(DesignSystem.Spacing.xxl)
        .frame(width: 400)
    }
}