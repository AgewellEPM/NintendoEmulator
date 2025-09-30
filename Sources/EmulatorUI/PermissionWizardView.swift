import SwiftUI
import EmulatorKit

/// Guided wizard to obtain macOS permissions needed for mirroring/streaming.
public struct PermissionWizardView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Step = .screenRecording
    @State private var screenAuthorized = false
    @State private var axAuthorized = false
    @State private var automationAuthorized: Bool? = nil

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Permissions Wizard")
                        .font(.title2).bold()
                    Text("Enable system permissions for live mirroring and streaming")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    IdentityRow()
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button("Install to Applications (Recommended)") {
                            AppInstaller.installToApplicationsAndRelaunch()
                        }
                        .buttonStyle(.bordered)
                        Text("Creates a stable identity so macOS remembers permissions.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                Spacer()
                Button("Close") { dismiss() }
            }
            .padding(DesignSystem.Spacing.lg)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Progress
            WizardProgress(step: step)
                .padding(.horizontal, 16)
                .padding(.top, 12)

            // Step content
            Group {
                switch step {
                case .screenRecording:
                    ScreenRecordingStep(screenAuthorized: $screenAuthorized)
                case .accessibility:
                    AccessibilityStep(axAuthorized: $axAuthorized)
                case .automation:
                    AutomationStep(automationAuthorized: $automationAuthorized)
                case .finish:
                    FinishStep()
                }
            }
            .padding(DesignSystem.Spacing.lg)

            Spacer()

            // Footer actions
            HStack {
                Button("Back") { step = step.previous }
                    .disabled(step == .screenRecording)

                Spacer()

                if step == .finish {
                    Button("Relaunch App") { GhostBridgeHelper.relaunchApp() }
                        .buttonStyle(.borderedProminent)
                } else {
                    Button("Continue") { step = step.next }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canContinue)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .frame(width: 560, height: 440)
        .onAppear { refreshStatuses() }
    }

    private var canContinue: Bool {
        switch step {
        case .screenRecording: return screenAuthorized
        case .accessibility:   return axAuthorized
        case .automation:      return true // optional
        case .finish:          return true
        }
    }

    private func refreshStatuses() {
        if #available(macOS 10.15, *) {
            screenAuthorized = GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized()
        } else {
            screenAuthorized = true
        }
        axAuthorized = GhostBridgeHelper.isAccessibilityEffectivelyTrusted()
        automationAuthorized = GhostBridgeHelper.testAutomationPermission()
    }
}

// MARK: - Steps

private enum Step: Int, CaseIterable {
    case screenRecording, accessibility, automation, finish

    var title: String {
        switch self {
        case .screenRecording: return "Screen Recording"
        case .accessibility:   return "Accessibility"
        case .automation:      return "Automation (Optional)"
        case .finish:          return "All Set"
        }
    }

    var next: Step { Step(rawValue: rawValue + 1) ?? .finish }
    var previous: Step { Step(rawValue: rawValue - 1) ?? .screenRecording }
}

// MARK: - Progress View

private struct WizardProgress: View {
    let step: Step

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.sm) {
            ForEach(Step.allCases, id: \.self) { s in
                HStack(spacing: DesignSystem.Spacing.sm) {
                    Circle()
                        .fill(color(for: s))
                        .frame(width: 10, height: 10)
                    Text(s.title)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                if s != .finish {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 24, height: 2)
                }
            }
        }
    }

    private func color(for s: Step) -> Color {
        if s.rawValue < step.rawValue { return .green }
        if s == step { return .blue }
        return .gray
    }
}

// MARK: - Step Views

private struct ScreenRecordingStep: View {
    @Binding var screenAuthorized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("Screen Recording Permission", systemImage: screenAuthorized ? "checkmark.circle.fill" : "record.circle")
                .foregroundColor(screenAuthorized ? .green : .orange)
                .font(.headline)

            Text("Required to mirror the emulator window in the app and stream your gameplay.")
                .foregroundColor(.secondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Request Access") {
                    if #available(macOS 10.15, *) {
                        GhostBridgeHelper.requestScreenRecordingIfNeeded(prompt: true)
                    }
                }
                Button("Open System Settings") { GhostBridgeHelper.openSystemSettingsToScreenRecording() }
                Button("Recheck") { refresh() }
            }

            if !screenAuthorized {
                Text("After enabling in System Settings, press ‘Relaunch’ when prompted, then click Recheck.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private func refresh() {
        if #available(macOS 10.15, *) {
            screenAuthorized = GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized()
        } else {
            screenAuthorized = true
        }
    }
}

private struct AccessibilityStep: View {
    @Binding var axAuthorized: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("Accessibility Permission", systemImage: axAuthorized ? "checkmark.circle.fill" : "accessibility")
                .foregroundColor(axAuthorized ? .green : .orange)
                .font(.headline)

            Text("Allows the app to control and read UI state for better capture and controls.")
                .foregroundColor(.secondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Prompt") { GhostBridgeHelper.promptAccessibility(always: true) }
                Button("Open System Settings") { GhostBridgeHelper.openSystemSettingsToAccessibility() }
                Button("Recheck") { axAuthorized = GhostBridgeHelper.isAccessibilityEffectivelyTrusted() }
            }

            if !axAuthorized {
                Text("Enable ‘NintendoEmulator’ in System Settings → Accessibility → Allow these apps.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

private struct AutomationStep: View {
    @Binding var automationAuthorized: Bool?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            let ok = automationAuthorized ?? false
            Label("Automation Permission (Optional)", systemImage: ok ? "checkmark.circle.fill" : "gear")
                .foregroundColor(ok ? .green : .blue)
                .font(.headline)

            Text("Used for auxiliary features like controlling other apps.")
                .foregroundColor(.secondary)

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Register") { GhostBridgeHelper.forceRegisterAutomation() }
                Button("Open System Settings") { GhostBridgeHelper.openSystemSettingsToAutomation() }
                Button("Test") { automationAuthorized = GhostBridgeHelper.testAutomationPermission() }
            }

            Text("This step is optional. You can continue without it.")
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

private struct FinishStep: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Label("All Set!", systemImage: "checkmark.seal.fill")
                .foregroundColor(.green)
                .font(.title3).bold()

            Text("You’ve granted all required permissions. You can start mirroring and streaming now.")
                .foregroundColor(.secondary)
        }
    }
}
// MARK: - Identity Row
private struct IdentityRow: View {
    var body: some View {
        let bundleID = Bundle.main.bundleIdentifier ?? "(unknown bundle id)"
        let appPath = Bundle.main.bundleURL.path
        return HStack(spacing: DesignSystem.Spacing.sm) {
            Text("Bundle ID:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(bundleID)
                .font(.caption)
                .textSelection(.enabled)
            Divider().frame(height: 12)
            Text("App Path:")
                .font(.caption)
                .foregroundColor(.secondary)
            Text(appPath)
                .font(.caption)
                .lineLimit(1)
                .truncationMode(.middle)
                .textSelection(.enabled)
            Spacer()
            Button("Reveal in Finder") {
                NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
            }
            .buttonStyle(.bordered)
        }
    }
}
