import SwiftUI
import AppKit

struct StableInstallPromptView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            HStack {
                Image(systemName: "shield")
                    .foregroundColor(.blue)
                Text("Use a Stable App Location")
                    .font(.title3).bold()
            }

            Text("To make macOS remember permissions (Screen Recording, Accessibility), install and run the app from /Applications. This avoids stale entries and identity drift.")
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                Text("Current Bundle ID: \(Bundle.main.bundleIdentifier ?? "?")")
                    .font(.caption)
                Text("Current Path: \(Bundle.main.bundleURL.path)")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            HStack(spacing: DesignSystem.Spacing.md) {
                Button("Install to Applications (Recommended)") {
                    AppInstaller.installToApplicationsAndRelaunch()
                }
                .buttonStyle(.borderedProminent)

                Button("Reveal Current App") {
                    NSWorkspace.shared.activateFileViewerSelecting([Bundle.main.bundleURL])
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Not Now") {
                    appState.showInstallPrompt = false
                }
                .buttonStyle(.borderless)

                Button("Quit App") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderless)
            }

            Text("After relaunch: grant permissions for the /Applications version only in System Settings.")
                .font(.caption)
                .foregroundColor(.secondary)

            Button("Don’t show again") {
                UserDefaults.standard.set(true, forKey: "SuppressInstallPrompt")
                appState.showInstallPrompt = false
            }
            .buttonStyle(.link)
        }
        .padding(DesignSystem.Spacing.xl)
        .frame(width: 560)
    }
}
