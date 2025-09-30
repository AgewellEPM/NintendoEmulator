import AppKit
import Foundation
import AVFoundation
import ApplicationServices

/// GhostBridge integration for advanced streaming and remote control capabilities
/// Handles macOS permissions and screen capture for professional streaming setup
public enum GhostBridgeHelper {
    // Single-session prompt guard (allows explicit override)
    private static var promptedOnce = false
    private static var srPromptedOnce = false

    public static func ensureAccessibilityPermission(prompt: Bool = true) {
        // Avoid re-triggering prompts if already trusted
        if isAccessibilityEffectivelyTrusted() { return }
        if prompt { promptAccessibility(always: false) }
        else { _ = AXIsProcessTrusted() }
    }

    /// Triggers the Accessibility permission prompt. When `always` is true, bypasses the in-session
    /// prompt guard so a user can re-trigger the prompt after removing the app from the list.
    public static func promptAccessibility(always: Bool) {
        if !always && promptedOnce { return }
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(opts)
        promptedOnce = true
    }

    public static func isTrusted() -> Bool { AXIsProcessTrusted() }

    /// More robust check for Accessibility. If the basic trust flag is false,
    /// attempt a harmless AX query that only succeeds when permission is active.
    public static func isAccessibilityEffectivelyTrusted() -> Bool {
        if AXIsProcessTrusted() { return true }
        // Re-evaluate via AXIsProcessTrustedWithOptions without prompting (helps refresh cache)
        let opts = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: false] as CFDictionary
        if AXIsProcessTrustedWithOptions(opts) { return true }
        // Fallback benign AX call
        let sys = AXUIElementCreateSystemWide()
        var focused: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(sys, kAXFocusedApplicationAttribute as CFString, &focused)
        if err == .success { return true }
        // Last resort: attempt to read Finder windows via AX (requires permission)
        if probeAXFinderWindows() { return true }
        return false
    }

    @available(macOS 10.15, *)
    public static func requestScreenRecordingIfNeeded(prompt: Bool = true) {
        if CGPreflightScreenCaptureAccess() { return }
        if prompt && !srPromptedOnce {
            _ = CGRequestScreenCaptureAccess()
            srPromptedOnce = true
        }
    }

    public static func openSystemSettingsToAccessibility() {
        if openSecurityPrivacyURL(anchor: "Privacy_Accessibility") { return }
        // Fallback to AppleScript reveal (Ventura+ uses System Settings; older uses System Preferences)
        if !revealSecurityPrivacyPane(anchor: "Privacy_Accessibility") {
            openSystemSettingsPrivacy()
        }
    }

    /// Attempts AX operations that cause macOS to register this bundle in Accessibility list
    /// even if the prompt did not appear (e.g., after manual removal).
    public static func forceRegisterAccessibility() {
        // Try to create an AX observer for the system wide element; this touches AX APIs
        // and should register the bundle with TCC.
        var obs: AXObserver?
        let pid = getpid()
        if AXObserverCreate(pid, { (_: AXObserver, _: AXUIElement, _: CFString, _: UnsafeMutableRawPointer?) in }, &obs) == .success {
            // Attach to system-wide element briefly
            let sys = AXUIElementCreateSystemWide()
            if let observer = obs {
                AXObserverAddNotification(observer, sys, kAXFocusedUIElementChangedNotification as CFString, nil)
            }
        }
        _ = isAccessibilityEffectivelyTrusted()
    }

    public static func openSystemSettingsToScreenRecording() {
        if openSecurityPrivacyURL(anchor: "Privacy_ScreenCapture") { return }
        if !revealSecurityPrivacyPane(anchor: "Privacy_ScreenCapture") {
            openSystemSettingsPrivacy()
        }
    }

    public static func openSystemSettingsToAutomation() {
        if openSecurityPrivacyURL(anchor: "Privacy_Automation") { return }
        if !revealSecurityPrivacyPane(anchor: "Privacy_Automation") {
            openSystemSettingsPrivacy()
        }
    }

    // MARK: - Streaming Integration

    /// Prepares all permissions needed for advanced streaming
    public static func prepareForStreaming() async -> Bool {
        // Ensure screen recording permission
        if #available(macOS 10.15, *) {
            // Touch capture APIs so macOS registers this app in the Screen Recording list
            forceRegisterScreenRecording()
            requestScreenRecordingIfNeeded()
            if !isScreenRecordingEffectivelyAuthorized() {
                return false
            }
        }

        // Ensure accessibility for stream controls
        ensureAccessibilityPermission()
        if !isAccessibilityEffectivelyTrusted() {
            return false
        }

        return true
    }

    /// Captures the current emulator window for streaming
    public static func captureEmulatorWindow(windowID: CGWindowID) -> CGImage? {
        // Preferred: let CoreGraphics choose the window bounds (avoids cropping/blank frames)
        let imageOptions: CGWindowImageOption = [.bestResolution, .boundsIgnoreFraming]

        if let img = CGWindowListCreateImage(.null, .optionIncludingWindow, windowID, imageOptions) {
            return img
        }

        // Fallback: query the window bounds and capture that rect
        if let info = CGWindowListCopyWindowInfo([.optionIncludingWindow, .excludeDesktopElements], windowID) as? [[String: Any]],
           let bounds = info.first?[kCGWindowBounds as String] as? [String: CGFloat] {
            let rect = CGRect(x: bounds["X"] ?? 0,
                              y: bounds["Y"] ?? 0,
                              width: bounds["Width"] ?? 0,
                              height: bounds["Height"] ?? 0)
            return CGWindowListCreateImage(rect, .optionOnScreenOnly, windowID, imageOptions)
        }

        return nil
    }

    /// Save a one-off capture of the target window to disk (PNG) for diagnostics
    public static func saveWindowCapture(windowID: CGWindowID, url: URL) -> Bool {
        guard let cg = captureEmulatorWindow(windowID: windowID) else { return false }
        let rep = NSBitmapImageRep(cgImage: cg)
        guard let data = rep.representation(using: .png, properties: [:]) else { return false }
        do { try data.write(to: url); return true } catch { return false }
    }

    /// Capture the full screen (primary display) as a CGImage.
    public static func captureFullScreen() -> CGImage? {
        let rect = CGDisplayBounds(CGMainDisplayID())
        return CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, [.bestResolution])
    }

    /// Start streaming with webcam overlay
    public static func startStreamingWithWebcam() {
        Task {
            if await prepareForStreaming() {
                // Trigger streaming pipeline
                NotificationCenter.default.post(name: .ghostBridgeStreamingReady, object: nil)
            }
        }
    }

    // MARK: - Helpers
    @discardableResult
    private static func openSecurityPrivacyURL(anchor: String) -> Bool {
        let urls = [
            URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)"),
            URL(string: "x-apple.systempreferences:com.apple.preference.security"),
        ].compactMap { $0 }
        for u in urls { if NSWorkspace.shared.open(u) { return true } }
        return false
    }

    @discardableResult
    private static func revealSecurityPrivacyPane(anchor: String) -> Bool {
        let scripts = [
            // macOS 13+ (System Settings)
            """
            tell application "System Settings"
              activate
              try
                reveal anchor "\(anchor)" of pane id "com.apple.preference.security"
              end try
            end tell
            """,
            // Older macOS (System Preferences)
            """
            tell application "System Preferences"
              activate
              try
                reveal anchor "\(anchor)" of pane id "com.apple.preference.security"
              end try
            end tell
            """,
        ]
        for src in scripts {
            if runAppleScript(source: src) { return true }
        }
        return false
    }

    @discardableResult
    private static func runAppleScript(source: String) -> Bool {
        var error: NSDictionary?
        if let script = NSAppleScript(source: source) {
            _ = script.executeAndReturnError(&error)
            return error == nil
        }
        return false
    }

    public static func openSystemSettingsPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security") {
            _ = NSWorkspace.shared.open(url)
        }
    }

    @available(macOS 10.15, *)
    public static func forceRegisterScreenRecording() {
        let rect = CGRect(x: 0, y: 0, width: 1, height: 1)
        _ = CGWindowListCreateImage(rect, .optionOnScreenOnly, kCGNullWindowID, .bestResolution)
    }

    /// Robust check for Screen Recording permission. Falls back to probing a transient capture
    /// session to avoid stale TCC cache states where preflight returns false until the app
    /// touches capture APIs or relaunches.
    public static func isScreenRecordingEffectivelyAuthorized() -> Bool {
        if #available(macOS 10.15, *) {
            if CGPreflightScreenCaptureAccess() { return true }
            return probeScreenRecordingWithAVCapture()
        }
        return true
    }

    // Convenience: guide user through all three permissions quickly
    public static func openAllPermissions() {
        // Accessibility: trigger prompt if needed and open pane
        ensureAccessibilityPermission()
        openSystemSettingsToAccessibility()

        // Screen Recording: request access (shows system prompt), force-register so the app appears immediately, then open pane
        if #available(macOS 10.15, *) {
            if !CGPreflightScreenCaptureAccess() {
                requestScreenRecordingIfNeeded()
                forceRegisterScreenRecording()
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            openSystemSettingsToScreenRecording()
        }

        // Automation: trigger a harmless Apple Event to register, then open pane
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
            forceRegisterAutomation()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                openSystemSettingsToAutomation()
            }
        }
    }

    /// Attempts a benign Apple Event so macOS registers this app under Automation.
    /// macOS only lists apps here after first use; this triggers the one‑time prompt.
    public static func forceRegisterAutomation() {
        let scripts = [
            // Prefer System Events (standard automation target)
            """
            tell application "System Events"
              try
                get name of every process
              end try
            end tell
            """,
            // Fallback to Finder if System Events fails silently
            """
            tell application "Finder"
              try
                get name of startup disk
              end try
            end tell
            """,
        ]
        for src in scripts { if runAppleScript(source: src) { break } }
    }

    /// Attempts to run a harmless AppleScript against System Events to infer Automation status.
    /// Returns true if the call succeeded (app is registered and allowed), false otherwise.
    public static func testAutomationPermission() -> Bool {
        let src = """
        tell application "System Events"
          try
            get name of every process
            return true
          on error
            return false
          end try
        end tell
        """
        var error: NSDictionary?
        guard let script = NSAppleScript(source: src) else { return false }
        let result = script.executeAndReturnError(&error)
        if error != nil { return false }
        // If the script returned a boolean false, treat as not allowed
        if result.booleanValue == false { return false }
        return true
    }

    // Relaunch the current app (used after granting certain TCC permissions)
    public static func relaunchApp() {
        let path = Bundle.main.bundlePath
        let url = URL(fileURLWithPath: path)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            NSWorkspace.shared.open(url)
            NSApp.terminate(nil)
        }
    }
}

// MARK: - Private capture probe
private extension GhostBridgeHelper {
    static func probeScreenRecordingWithAVCapture() -> Bool {
        if #available(macOS 10.15, *) {
            let session = AVCaptureSession()
            session.sessionPreset = .low
            guard let input = AVCaptureScreenInput(displayID: CGMainDisplayID()) else { return false }
            guard session.canAddInput(input) else { return false }
            session.addInput(input)
            session.startRunning()
            let ok = session.isRunning
            session.stopRunning()
            return ok
        }
        return true
    }

    static func probeAXFinderWindows() -> Bool {
        guard let finder = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.finder" }), let pid = finder.processIdentifier as pid_t? else { return false }
        let appElem = AXUIElementCreateApplication(pid)
        var value: CFTypeRef?
        let err = AXUIElementCopyAttributeValue(appElem, kAXWindowsAttribute as CFString, &value)
        return err == .success
    }
}

// MARK: - Notification Names
public extension Notification.Name {
    static let ghostBridgeStreamingReady = Notification.Name("GhostBridgeStreamingReady")
    static let ghostBridgePermissionNeeded = Notification.Name("GhostBridgePermissionNeeded")
}

// Public helpers for window selection
public extension GhostBridgeHelper {
    struct WindowInfo: Identifiable {
        public let id: CGWindowID
        public let ownerName: String
        public let windowName: String
        public let layer: Int
        public let alpha: Double
    }

    static func listOnScreenWindows() -> [WindowInfo] {
        let list = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        return list.compactMap { w in
            guard let id = w[kCGWindowNumber as String] as? CGWindowID else { return nil }
            let owner = w[kCGWindowOwnerName as String] as? String ?? ""
            let name = w[kCGWindowName as String] as? String ?? ""
            let layer = w[kCGWindowLayer as String] as? Int ?? 0
            let alpha = w[kCGWindowAlpha as String] as? Double ?? 1.0
            return WindowInfo(id: id, ownerName: owner, windowName: name, layer: layer, alpha: alpha)
        }
    }
}
