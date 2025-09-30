import Foundation
import AppKit

public enum AppInstaller {
    /// Copies the current app bundle to /Applications/NintendoEmulator.app, optionally overwriting.
    /// Attempts ad-hoc codesign for a stable identity, then relaunches the installed app and quits.
    public static func installToApplicationsAndRelaunch() {
        let fm = FileManager.default
        let sourceURL = Bundle.main.bundleURL
        let appName = sourceURL.lastPathComponent
        let destURL = URL(fileURLWithPath: "/Applications").appendingPathComponent(appName)

        // Validate destination resolves under /Applications (no symlink escape)
        let resolvedDestParent = destURL.deletingLastPathComponent()
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let applicationsURL = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        guard resolvedDestParent.path == applicationsURL.path else {
            let alert = NSAlert()
            alert.messageText = "Invalid Destination"
            alert.informativeText = "The destination path is not inside /Applications. Aborting install."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            return
        }

        do {
            if fm.fileExists(atPath: destURL.path) {
                // Ask for confirmation before replacing existing app
                let alert = NSAlert()
                alert.messageText = "Replace Existing App?"
                alert.informativeText = "An app already exists at \(destURL.path). It will be moved to Trash and replaced with this build."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Replace")
                alert.addButton(withTitle: "Cancel")
                let result = alert.runModal()
                if result != .alertFirstButtonReturn { return }

                // Move to Trash instead of hard delete
                var trashedURL: NSURL?
                try fm.trashItem(at: destURL, resultingItemURL: &trashedURL)
            }
            try fm.copyItem(at: sourceURL, to: destURL)

            // Try ad-hoc codesign for stable TCC identity (best-effort)
            let codeSign = Process()
            codeSign.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
            codeSign.arguments = ["-s", "-", "--force", "--deep", destURL.path]
            try? codeSign.run()
            codeSign.waitUntilExit()
        } catch {
            NSLog("[Installer] Failed to install to /Applications: \(error.localizedDescription)")
        }

        // Relaunch installed app and quit current instance
        NSWorkspace.shared.open(destURL)
        NSApp.terminate(nil)
    }
}
