import SwiftUI
import EmulatorUI
import EmulatorKit
import AppKit

@main
struct NintendoEmulatorApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        WindowGroup("Universal Emulator") {
            ContentView()
                .environmentObject(appState)
                .onReceive(NotificationCenter.default.publisher(for: .gameStarted)) { notification in
                    if let gameName = notification.object as? String {
                        updateWindowTitle(gameName)
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .gameStopped)) { _ in
                    updateWindowTitle("Universal Emulator")
                }
                .onAppear {
                    configureWindow()
                    // Encourage stable identity only when appropriate
                    if shouldSuggestStableInstall() {
                        appState.showInstallPrompt = true
                    }
                    // Do not auto-prompt for permissions on launch. Use explicit user actions.
                    // If you want to auto-open the Wizard during development, set AutoPermissionWizard = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        let autoWizard = UserDefaults.standard.bool(forKey: "AutoPermissionWizard")
                        if autoWizard { appState.showPermissionWizard = true }
                    }
                }
        }
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        .commands {
            EmulatorCommands()
        }

        // Settings window omitted in this build; can be re-enabled when exported
    }

    // Suggest installing to Applications only for non-DEBUG builds,
    // when the app is not already under /Applications or ~/Applications,
    // and the user hasn't opted out. Handles /Applications symlink.
    private func shouldSuggestStableInstall() -> Bool {
        #if DEBUG
        return false
        #else
        // Allow build-time suppression via Info.plist flag
        if let suppress = Bundle.main.object(forInfoDictionaryKey: "EmulatorSuppressInstallPrompt") as? Bool, suppress {
            return false
        }
        if UserDefaults.standard.bool(forKey: "SuppressInstallPrompt") { return false }

        let appURL = Bundle.main.bundleURL
            .resolvingSymlinksInPath()
            .standardizedFileURL

        let systemApplications = URL(fileURLWithPath: "/Applications", isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        let userApplications = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Applications", isDirectory: true)
            .resolvingSymlinksInPath()
            .standardizedFileURL

        let path = appURL.path
        let sysPath = systemApplications.path
        let userPath = userApplications.path

        let isInSystemApps = path.hasPrefix(sysPath + "/")
        let isInUserApps = path.hasPrefix(userPath + "/")
        return !(isInSystemApps || isInUserApps)
        #endif
    }
    private func configureWindow() {
        // Ensure app is properly set up as a regular app
        NSApp.setActivationPolicy(.regular)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSApp.activate(ignoringOtherApps: true)

            if let window = NSApp.windows.first {
                // Configure window to behave like a proper macOS app
                window.title = "Universal Emulator"
                window.isOpaque = true
                window.backgroundColor = NSColor.windowBackgroundColor
                window.hasShadow = true
                window.alphaValue = 1.0

                // Standard window style for proper app behavior
                window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
                window.titlebarAppearsTransparent = true

                // Set proper window level and behavior
                window.level = .normal
                window.hidesOnDeactivate = false
                window.canHide = true

                // Size and position
                window.setContentSize(NSSize(width: 1200, height: 800))
                window.minSize = NSSize(width: 800, height: 600)
                window.center()

                // Make window key and front
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()

                // Configure content view
                if let contentView = window.contentView {
                    contentView.wantsLayer = true
                    contentView.layer?.isOpaque = true
                }
            }

            // Final activation to ensure focus
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }

    private func updateWindowTitle(_ title: String) {
        DispatchQueue.main.async {
            if let window = NSApp.keyWindow {
                window.title = title
            }
        }
    }
}

// Ensure activation/foreground behavior consistently
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Set up app as a proper regular application
        NSApp.setActivationPolicy(.regular)

        // Load Blockbuster-style app icon
        if let iconURL = Bundle.main.url(forResource: "Resources/AppIcon", withExtension: "icns"),
           let icon = NSImage(contentsOf: iconURL) {
            NSApp.applicationIconImage = icon
        } else {
            // Fallback: try named asset
            NSApp.applicationIconImage = NSImage(named: "AppIcon")
        }

        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag, let window = sender.windows.first {
            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()
        }
        NSApp.activate(ignoringOtherApps: true)
        return true
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        // Ensure window stays visible when app becomes active
        if let window = NSApp.keyWindow {
            window.makeKeyAndOrderFront(nil)
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return true
    }
}

// AppState is now provided by EmulatorUI module

// Custom menu commands
struct EmulatorCommands: Commands {
    @FocusedBinding(\.selectedROM) var selectedROM: URL?

    var body: some Commands {
        // File menu additions
        CommandGroup(after: .newItem) {
            Button("Open ROM...") {
                openROM()
            }
            .keyboardShortcut("O", modifiers: .command)

            Button("Open Recent") {
                // Open recent ROM
            }
            .disabled(true)

            Divider()
        }

        // Emulation menu
        CommandMenu("Emulation") {
            Button("Start") {
                NotificationCenter.default.post(name: .emulatorStart, object: nil)
            }
            .keyboardShortcut("R", modifiers: .command)

            Button("Pause") {
                NotificationCenter.default.post(name: .emulatorPause, object: nil)
            }
            .keyboardShortcut("P", modifiers: .command)

            Button("Reset") {
                NotificationCenter.default.post(name: .emulatorStop, object: nil)
            }
            .keyboardShortcut("R", modifiers: [.command, .shift])

            Divider()

            Button("Fast Forward") {
                // Toggle fast forward
            }
            .keyboardShortcut(KeyEquivalent.space, modifiers: .shift)

            Divider()

            Menu("Save State") {
                ForEach(0..<10) { slot in
                    Button("Slot \(slot)") { }
                }
            }

            Menu("Load State") {
                ForEach(0..<10) { slot in
                    Button("Slot \(slot)") { }
                }
            }

            Divider()

            Button("Permissions Wizard…") {
                NotificationCenter.default.post(name: .showPermissionWizard, object: nil)
            }
        }

        // View menu
        CommandGroup(after: .toolbar) {
            Button("Enter Fullscreen") {
                // Toggle fullscreen
            }
            .keyboardShortcut("F", modifiers: [.command, .control])

            Divider()

            Button("Show Games") {
                // Show games
            }
            .keyboardShortcut("L", modifiers: [.command, .shift])

            Button("Show Debugger") {
                // Show debugger
            }
            .keyboardShortcut("D", modifiers: [.command, .option])
        }

        // Debug menu
        CommandMenu("Debug") {
            Button("Install N64 Core…") {
                installN64Core()
            }

            Button("CPU Debugger") {
                // Open CPU debugger
            }

            Button("Memory Viewer") {
                // Open memory viewer
            }

            Button("Graphics Debugger") {
                // Open graphics debugger
            }

            Divider()

            Button("Performance Monitor") {
                // Show performance
            }

            Button("Frame Profiler") {
                // Show frame profiler
            }
        }
    }

    private func openROM() {
        let panel = NSOpenPanel()
        panel.title = "Select ROM File"
        panel.message = "Choose a Nintendo ROM file to open"
        panel.showsResizeIndicator = true
        panel.showsHiddenFiles = false
        panel.canChooseDirectories = false
        panel.canCreateDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.z64, .v64, .n64, .rom]

        if panel.runModal() == .OK, let url = panel.url {
            NotificationCenter.default.post(name: .emulatorOpenROM, object: url)
        }
    }

    private func installN64Core() {
        // Runs the bundled build script to fetch/build mupen64plus core and plugins.
        // This requires Homebrew and network access.
        let fm = FileManager.default
        // Locate script in repo layout for dev builds
        let projectRootCandidates: [URL] = [
            URL(fileURLWithPath: FileManager.default.homeDirectoryForCurrentUser.path)
                .appendingPathComponent("NintendoEmulator"),
            Bundle.main.bundleURL
        ]

        var scriptURL: URL?
        for base in projectRootCandidates {
            let candidate = base.appendingPathComponent("Scripts/build_n64_core.sh")
            if fm.fileExists(atPath: candidate.path) { scriptURL = candidate; break }
        }

        guard let url = scriptURL else {
            print("Install script not found. Please run Scripts/build_n64_core.sh manually.")
            return
        }

        DispatchQueue.global(qos: .userInitiated).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            proc.arguments = [url.path]

            let pipe = Pipe()
            proc.standardOutput = pipe
            proc.standardError = pipe

            do {
                try proc.run()
                proc.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                if let out = String(data: data, encoding: .utf8) {
                    print(out)
                }
                if proc.terminationStatus == 0 {
                    print("✅ N64 core installed. Restart app to pick up libraries.")
                } else {
                    print("❌ N64 core install failed with status \(proc.terminationStatus)")
                }
            } catch {
                print("❌ Failed to run installer: \(error)")
            }
        }
    }
}

// Focus values for menu commands
struct SelectedROMKey: FocusedValueKey {
    typealias Value = Binding<URL>
}

extension FocusedValues {
    var selectedROM: Binding<URL>? {
        get { self[SelectedROMKey.self] }
        set { self[SelectedROMKey.self] = newValue }
    }
}
