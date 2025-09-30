import Foundation
import Combine
import AVFoundation
import AppKit

/// Sprint 2 - Unified Streaming Management System
/// Coordinates streaming across multiple platforms (Twitch, YouTube, etc.)
@MainActor
public class StreamingManager: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var isStreaming = false
    @Published public private(set) var streamStatus: StreamStatus = .disconnected
    @Published public private(set) var connectedPlatforms: Set<StreamingPlatform> = []
    @Published public private(set) var currentViewerCount = 0
    @Published public private(set) var streamDuration: TimeInterval = 0
    @Published public private(set) var streamTitle = ""
    @Published public private(set) var streamCategory = ""

    // MARK: - Platform Services
    private let twitchService: TwitchAPIService
    private let youtubeService: YouTubeAPIService

    // MARK: - Streaming Infrastructure
    private var streamingSession: AVCaptureSession?
    private var screenInputRef: AVCaptureScreenInput?
    private var streamTimer: Timer?
    private var streamStartTime: Date?

    // Expose session for local preview rendering
    @Published public private(set) var captureSession: AVCaptureSession?

    // MARK: - Preview-only control
    private var isPreviewOnly: Bool { !isStreaming && captureSession != nil }

    // MARK: - GhostBridge Integration
    @Published public private(set) var ghostBridgeReady = false
    @Published public private(set) var permissionsGranted = false
    private var emulatorWindowID: CGWindowID?

    // MARK: - Capture Configuration
    public enum CaptureMode: String, CaseIterable { case window, fullScreen }
    @Published public var captureMode: CaptureMode = .window
    @Published public var desiredFrameRate: Int = 60

    // Expose minimal capture state for UI
    public var hasWindowSelection: Bool { emulatorWindowID != nil }
    public var hasCaptureSession: Bool { captureSession != nil }

    // MARK: - Diagnostics
    @Published public private(set) var lastCropRect: CGRect?
    @Published public private(set) var lastWindowOwner: String?
    @Published public private(set) var lastWindowTitle: String?

    // MARK: - Cancellables
    private var cancellables = Set<AnyCancellable>()

    public init(
        twitchService: TwitchAPIService = TwitchAPIService(),
        youtubeService: YouTubeAPIService = YouTubeAPIService()
    ) {
        self.twitchService = twitchService
        self.youtubeService = youtubeService

        setupObservers()
    }

    // MARK: - Platform Connection Management

    /// Connect to Twitch platform
    public func connectTwitch(clientID: String, clientSecret: String) async throws {
        let service = TwitchAPIService(clientID: clientID, clientSecret: clientSecret)

        // Generate OAuth URL for user authentication
        let redirectURI = "com.nintendoemulator://auth/twitch"
        let authURL = service.generateAuthorizationURL(redirectURI: redirectURI)

        // This would typically open a web browser for OAuth
        NSLog("🔗 Twitch OAuth URL: \(authURL.absoluteString)")

        // For now, simulate successful connection
        connectedPlatforms.insert(.twitch)
        await updateConnectionStatus()
    }

    /// Connect to YouTube platform
    public func connectYouTube(clientID: String, clientSecret: String) async throws {
        let service = YouTubeAPIService(clientID: clientID, clientSecret: clientSecret)

        // Generate OAuth URL for user authentication
        let redirectURI = "com.nintendoemulator://auth/youtube"
        let authURL = service.generateAuthorizationURL(redirectURI: redirectURI)

        // This would typically open a web browser for OAuth
        NSLog("🔗 YouTube OAuth URL: \(authURL.absoluteString)")

        // For now, simulate successful connection
        connectedPlatforms.insert(.youtube)
        await updateConnectionStatus()
    }

    /// Disconnect from a platform
    public func disconnectPlatform(_ platform: StreamingPlatform) async {
        switch platform {
        case .twitch:
            await twitchService.disconnect()
        case .youtube:
            await youtubeService.disconnect()
        case .facebook, .custom:
            break // Not implemented yet
        }

        connectedPlatforms.remove(platform)
        await updateConnectionStatus()
    }

    // MARK: - Stream Management

    /// Start streaming to connected platforms
    public func startStream(title: String, category: String) async throws {
        NSLog("🎥 Starting stream setup...")

        streamTitle = title
        streamCategory = category

        // Update stream info on connected platforms if any are connected
        if !connectedPlatforms.isEmpty {
            NSLog("🎥 Updating stream info for \(connectedPlatforms.count) connected platforms...")
            for platform in connectedPlatforms {
                try await updateStreamInfo(platform: platform, title: title, category: category)
            }
        } else {
            NSLog("🎥 No platforms connected - running in demo mode")
        }

        // Initialize streaming session
        NSLog("🎥 Setting up streaming session...")
        do {
            try await setupStreamingSession()
            NSLog("🎥 Streaming session setup completed")
        } catch {
            NSLog("❌ Streaming session setup failed: \(error)")
            throw error
        }

        // Start the stream
        NSLog("🎥 Starting capture session...")
        streamingSession?.startRunning()
        isStreaming = true
        streamStatus = .live
        streamStartTime = Date()

        // Start duration timer
        startStreamTimer()

        let platformInfo = connectedPlatforms.isEmpty ? "Demo Mode" : "\(connectedPlatforms.count) platform(s)"
        NSLog("🎥 ✅ Stream started: \"\(title)\" in \(category) [\(platformInfo)]")
    }

    /// Stop streaming
    public func stopStream() async {
        streamingSession?.stopRunning()
        stopStreamTimer()

        isStreaming = false
        streamStatus = connectedPlatforms.isEmpty ? .disconnected : .connected
        streamDuration = 0
        streamStartTime = nil

        // Release preview session
        captureSession = nil

        NSLog("🎥 Stream stopped")
    }

    // MARK: - GhostBridge Integration

    /// Initialize GhostBridge for advanced streaming capabilities
    public func initializeGhostBridge() async -> Bool {
        do {
            // Check and request all necessary permissions
            ghostBridgeReady = await GhostBridgeHelper.prepareForStreaming()
            permissionsGranted = ghostBridgeReady

            if ghostBridgeReady {
                // Find the emulator window for targeted capture
                await findEmulatorWindow()

                // Setup GhostBridge observers
                setupGhostBridgeObservers()

                NSLog("👻 GhostBridge initialized successfully")
                return true
            } else {
                NSLog("👻 GhostBridge requires additional permissions")
                return false
            }
        }
    }

    /// Start streaming with GhostBridge enhanced capture
    public func startGhostBridgeStream(title: String, category: String) async throws {
        // Start normal streaming first (works in demo mode even without platforms)
        try await startStream(title: title, category: category)

        // Try to enable GhostBridge enhanced features if available
        if ghostBridgeReady {
            GhostBridgeHelper.startStreamingWithWebcam()
            NSLog("👻 Enhanced streaming started with GhostBridge")
        } else {
            NSLog("🎥 Demo streaming started (GhostBridge not ready)")
        }
    }

    /// Capture emulator window using GhostBridge
    public func captureEmulatorFrame() -> CGImage? {
        switch captureMode {
        case .window:
            guard let windowID = emulatorWindowID else { return nil }
            return GhostBridgeHelper.captureEmulatorWindow(windowID: windowID)
        case .fullScreen:
            return GhostBridgeHelper.captureFullScreen()
        }
    }

    /// Find the Nintendo Emulator window for targeted capture
    private func findEmulatorWindow() async {
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []

        NSLog("👻 Searching for emulator window among \(windowList.count) windows:")

        // Pass 1: Prefer obvious matches, any layer
        if let match = windowList.first(where: { w in
            let windowName = (w[kCGWindowName as String] as? String)?.uppercased() ?? ""
            let ownerName = (w[kCGWindowOwnerName as String] as? String)?.uppercased() ?? ""
            return windowName.contains("NINTENDO EMULATOR") ||
                   windowName.contains("N64") ||
                   windowName.contains("MUPEN64PLUS") ||
                   windowName.contains("GLIDEN64") ||
                   windowName.contains("GLIDE64") ||
                   windowName.contains("RICE") ||
                   ownerName.contains("MUPEN64PLUS") ||
                   ownerName.contains("NINTENDOEMULATOR") ||
                   ownerName.contains("TERMINAL") ||
                   ownerName.contains("ITERM") ||
                   ownerName.contains("ALACRITTY") ||
                   ownerName.contains("KITTY")
        }) {
            let id = match[kCGWindowNumber as String] as? CGWindowID ?? 0
            let wn = match[kCGWindowName as String] as? String ?? ""
            let on = match[kCGWindowOwnerName as String] as? String ?? ""
            if id > 0 {
                emulatorWindowID = id
                lastWindowTitle = wn
                lastWindowOwner = on
                NSLog("👻 ✅ Found emulator window: '\(wn)' owned by '\(on)' (ID: \(id)) [pass1]")
                return
            }
        }

        // Pass 2: Fallback, allow any window for mupen owner
        if let match = windowList.first(where: { w in
            let ownerName = (w[kCGWindowOwnerName as String] as? String)?.lowercased() ?? ""
            return ownerName.contains("mupen64plus") || ownerName.contains("terminal") || ownerName.contains("iterm")
        }) {
            let id = match[kCGWindowNumber as String] as? CGWindowID ?? 0
            let wn = match[kCGWindowName as String] as? String ?? ""
            let on = match[kCGWindowOwnerName as String] as? String ?? ""
            if id > 0 {
                emulatorWindowID = id
                lastWindowTitle = wn
                lastWindowOwner = on
                NSLog("👻 ✅ Found emulator window by owner: '\(wn)' owned by '\(on)' (ID: \(id)) [pass2]")
                return
            }
        }

        NSLog("👻 ❌ No emulator window found")
    }

    /// Allow manual override from UI when auto-detect fails
    public func setEmulatorWindowID(_ id: CGWindowID) {
        emulatorWindowID = id
        NSLog("👻 🔧 Emulator window set manually: ID=\(id)")
        refreshCaptureCrop()
    }

    /// Refresh the crop rect of the screen input based on current window selection.
    public func refreshCaptureCrop() {
        guard #available(macOS 10.15, *), let screenInputRef,
              let session = streamingSession else { return }
        let displayID = CGMainDisplayID()
        if captureMode == .window, let rect = windowCropRectFor(windowID: emulatorWindowID, displayID: displayID) {
            screenInputRef.cropRect = rect
            if session.isRunning {
                NSLog("🎥 Updated cropRect to \(rect)")
            }
        } else {
            screenInputRef.cropRect = .null
        }
    }

    /// Compute crop rect for AVCaptureScreenInput given a window bounds; converts CG window bounds to top-left origin coordinates.
    private func windowCropRectFor(windowID: CGWindowID?, displayID: CGDirectDisplayID) -> CGRect? {
        guard let windowID,
              let info = CGWindowListCopyWindowInfo([.optionIncludingWindow], windowID) as? [[String: Any]],
              let b = info.first?[kCGWindowBounds as String] as? [String: CGFloat] else { return nil }
        let wbPoints = CGRect(x: b["X"] ?? 0, y: b["Y"] ?? 0, width: b["Width"] ?? 0, height: b["Height"] ?? 0)
        let displayBoundsPoints = CGDisplayBounds(displayID)
        // Determine scaling (Retina) so we can convert points -> pixels expected by AVCaptureScreenInput
        let pixelsHigh = CGFloat(CGDisplayPixelsHigh(displayID))
        let scale = max(1.0, pixelsHigh / max(1.0, displayBoundsPoints.height))
        // Convert from bottom-left origin (CGWindow) to top-left origin (AVCaptureScreenInput) and to pixels
        let flippedYPoints = displayBoundsPoints.height - wbPoints.origin.y - wbPoints.height
        let rectPixels = CGRect(
            x: wbPoints.origin.x * scale,
            y: flippedYPoints * scale,
            width: wbPoints.width * scale,
            height: wbPoints.height * scale
        )
        NSLog("🎥 cropRect points=\(wbPoints) scale=\(scale) pixels=\(rectPixels)")
        return rectPixels
    }

    /// Setup GhostBridge notification observers
    private func setupGhostBridgeObservers() {
        NotificationCenter.default.addObserver(
            forName: .ghostBridgeStreamingReady,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.ghostBridgeReady = true
                NSLog("👻 GhostBridge streaming ready")
            }
        }

        NotificationCenter.default.addObserver(
            forName: .ghostBridgePermissionNeeded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.permissionsGranted = false
                GhostBridgeHelper.openAllPermissions()
            }
        }
    }

    /// Update stream information
    public func updateStreamInfo(title: String? = nil, category: String? = nil) async throws {
        if let title = title {
            streamTitle = title
        }
        if let category = category {
            streamCategory = category
        }

        // Update on all connected platforms
        for platform in connectedPlatforms {
            try await updateStreamInfo(platform: platform, title: title, category: category)
        }
    }

    // MARK: - Stream Analytics

    /// Get combined viewer count from all platforms
    public func refreshViewerCount() async {
        var totalViewers = 0

        for platform in connectedPlatforms {
            let viewers = await getViewerCount(for: platform)
            totalViewers += viewers
        }

        currentViewerCount = totalViewers
    }

    /// Get stream statistics
    public func getStreamStatistics() -> StreamStatistics {
        return StreamStatistics(
            viewerCount: currentViewerCount,
            duration: streamDuration,
            platforms: Array(connectedPlatforms),
            peakViewers: currentViewerCount // This would be tracked over time
        )
    }

    // MARK: - Platform Configuration

    /// Get available streaming categories for a platform
    public func getAvailableCategories(platform: StreamingPlatform, query: String = "") async throws -> [StreamCategory] {
        switch platform {
        case .twitch:
            let twitchCategories = try await twitchService.searchCategories(query: query)
            return twitchCategories.map { category in
                StreamCategory(
                    id: category.id,
                    name: category.name,
                    platform: .twitch,
                    thumbnailURL: category.box_art_url
                )
            }
        case .youtube:
            let youtubeCategories = try await youtubeService.searchCategories(query: query)
            return youtubeCategories.map { category in
                StreamCategory(
                    id: category.id,
                    name: category.snippet.title,
                    platform: .youtube,
                    thumbnailURL: nil
                )
            }
        case .facebook, .custom:
            return []
        }
    }

    /// Test connection to a platform
    public func testConnection(platform: StreamingPlatform) async throws -> Bool {
        switch platform {
        case .twitch:
            return try await twitchService.testConnection()
        case .youtube:
            return try await youtubeService.testConnection()
        case .facebook, .custom:
            return false
        }
    }

    // MARK: - Private Methods

    private func setupObservers() {
        // Monitor platform connection changes
        twitchService.$isConnected
            .sink { [weak self] isConnected in
                Task { @MainActor in
                    if isConnected {
                        self?.connectedPlatforms.insert(.twitch)
                    } else {
                        self?.connectedPlatforms.remove(.twitch)
                    }
                    await self?.updateConnectionStatus()
                }
            }
            .store(in: &cancellables)
    }

    private func updateConnectionStatus() async {
        if connectedPlatforms.isEmpty {
            streamStatus = .disconnected
        } else if isStreaming {
            streamStatus = .live
        } else {
            streamStatus = .connected
        }
    }

    private func updateStreamInfo(platform: StreamingPlatform, title: String?, category: String?) async throws {
        switch platform {
        case .twitch:
            // Get category ID if category name is provided
            var categoryID: String?
            if let category = category {
                let categories = try await twitchService.searchCategories(query: category)
                categoryID = categories.first?.id
            }
            try await twitchService.updateStreamInfo(title: title, categoryID: categoryID)
        case .youtube:
            // Will be implemented in STREAM-002
            break
        case .facebook, .custom:
            break
        }
    }

    private func getViewerCount(for platform: StreamingPlatform) async -> Int {
        switch platform {
        case .twitch:
            do {
                let stream = try await twitchService.getCurrentStream()
                return stream?.viewer_count ?? 0
            } catch {
                return 0
            }
        case .youtube:
            do {
                if let broadcast = youtubeService.activeBroadcast {
                    let statistics = try await youtubeService.getBroadcastStatistics(broadcastId: broadcast.id)
                    return Int(statistics.concurrentViewers ?? "0") ?? 0
                }
                return 0
            } catch {
                return 0
            }
        case .facebook, .custom:
            return 0
        }
    }

    private func setupStreamingSession() async throws {
        let session = AVCaptureSession()

        // Configure for high quality streaming
        session.sessionPreset = .high

        // Add video input (screen capture) - capture main display, optionally cropped to emulator window
        if #available(macOS 10.15, *) {
            let displayID = CGMainDisplayID()
            if let screenInput = AVCaptureScreenInput(displayID: displayID) {
                // Configure requested frame rate (best effort, clamped)
                let fps = max(15, min(desiredFrameRate, 120))
                screenInput.minFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
                screenInput.capturesMouseClicks = false
                screenInput.capturesCursor = false

                // Crop to window only when in window mode
                if captureMode == .window {
                    if let rect = windowCropRectFor(windowID: emulatorWindowID, displayID: displayID) { screenInput.cropRect = rect }
                } else {
                    screenInput.cropRect = .null // full screen
                }

                if session.canAddInput(screenInput) {
                    session.addInput(screenInput)
                }
                self.screenInputRef = screenInput
            }
        }

        // Add audio input
        guard let audioDevice = AVCaptureDevice.default(for: .audio) else {
            throw StreamingError.invalidConfiguration
        }

        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
        if session.canAddInput(audioInput) {
            session.addInput(audioInput)
        }

        streamingSession = session
        captureSession = session
    }

    /// Update streaming capture configuration (mode and FPS).
    /// Applies changes live to the current `AVCaptureScreenInput` when possible.
    public func configureCapture(mode: CaptureMode, fps: Int) {
        captureMode = mode
        desiredFrameRate = fps

        // Apply live updates if a screen input already exists
        if #available(macOS 10.15, *), let input = screenInputRef {
            // Update FPS (best effort, clamped to reasonable bounds)
            let clampedFPS = max(15, min(fps, 120))
            input.minFrameDuration = CMTime(value: 1, timescale: CMTimeScale(clampedFPS))

            // Update cropping based on capture mode
            let displayID = CGMainDisplayID()
            if mode == .window, let rect = windowCropRectFor(windowID: emulatorWindowID, displayID: displayID) {
                input.cropRect = rect
            } else {
                input.cropRect = .null // full screen
            }
        }

        NSLog("🎥 Capture configured: mode=\(mode.rawValue) fps=\(fps)")
    }

    private func startStreamTimer() {
        streamTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self,
                      let startTime = self.streamStartTime else { return }

                self.streamDuration = Date().timeIntervalSince(startTime)

                // Refresh viewer count every 30 seconds
                if Int(self.streamDuration) % 30 == 0 {
                    await self.refreshViewerCount()
                }
            }
        }
    }

    private func stopStreamTimer() {
        streamTimer?.invalidate()
        streamTimer = nil
    }

    // MARK: - Local Preview (no platform streaming)

    /// Starts a local screen-capture preview (video only, no audio), so the UI can show live frames
    /// even when not streaming to any platform.
    public func startLocalPreview() {
        guard captureSession == nil else { return }
        // Require Screen Recording to start a preview session
        if #available(macOS 10.15, *), !GhostBridgeHelper.isScreenRecordingEffectivelyAuthorized() {
            return
        }
        if #available(macOS 10.15, *) {
            let session = AVCaptureSession()
            session.sessionPreset = .high
            let displayID = CGMainDisplayID()
            guard let screenInput = AVCaptureScreenInput(displayID: displayID) else { return }

            // Configure FPS and cropping
            let fps = max(15, min(desiredFrameRate, 120))
            screenInput.minFrameDuration = CMTime(value: 1, timescale: CMTimeScale(fps))
            screenInput.capturesMouseClicks = false
            screenInput.capturesCursor = false
            if captureMode == .window, let rect = windowCropRectFor(windowID: emulatorWindowID, displayID: displayID) {
                screenInput.cropRect = rect
            } else {
                screenInput.cropRect = .null
            }

            guard session.canAddInput(screenInput) else { return }
            session.addInput(screenInput)
            self.screenInputRef = screenInput

            self.captureSession = session
            session.startRunning()
        }
    }

    /// Stops the local preview if it is running and not currently streaming.
    public func stopLocalPreview() {
        guard !isStreaming, let session = captureSession else { return }
        session.stopRunning()
        if session == streamingSession { streamingSession = nil }
        captureSession = nil
        screenInputRef = nil
    }

    // MARK: - Cache/State Refresh
    /// Attempts to refresh system/state caches that commonly get stale (TCC permissions, window list,
    /// capture session parameters). Safe to call anytime.
    public func refreshCaches() async {
        // Nudge system permissions registries
        if #available(macOS 10.15, *) { GhostBridgeHelper.forceRegisterScreenRecording() }
        GhostBridgeHelper.forceRegisterAccessibility()

        // Re-scan window and update crop
        await findEmulatorWindow()
        refreshCaptureCrop()

        // Soft-restart any active capture session to pick up permission changes
        if let session = captureSession {
            session.stopRunning()
            session.startRunning()
        }
    }
}

// MARK: - Supporting Types

public enum StreamingPlatform: String, CaseIterable, Identifiable, Codable {
    case twitch = "twitch"
    case youtube = "youtube"
    case facebook = "facebook"
    case custom = "custom"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .twitch: return "Twitch"
        case .youtube: return "YouTube"
        case .facebook: return "Facebook Gaming"
        case .custom: return "Custom RTMP"
        }
    }

    public var iconName: String {
        switch self {
        case .twitch: return "tv"
        case .youtube: return "play.rectangle"
        case .facebook: return "person.3"
        case .custom: return "server.rack"
        }
    }

    public var primaryColor: String {
        switch self {
        case .twitch: return "#9146FF"
        case .youtube: return "#FF0000"
        case .facebook: return "#1877F2"
        case .custom: return "#007AFF"
        }
    }
}

public enum StreamStatus: String, CaseIterable {
    case disconnected
    case connected
    case live
    case error

    public var displayName: String {
        switch self {
        case .disconnected: return "Disconnected"
        case .connected: return "Connected"
        case .live: return "Live"
        case .error: return "Error"
        }
    }

    public var iconName: String {
        switch self {
        case .disconnected: return "wifi.slash"
        case .connected: return "wifi"
        case .live: return "dot.radiowaves.left.and.right"
        case .error: return "exclamationmark.triangle"
        }
    }
}

public struct StreamCategory: Identifiable, Codable {
    public let id: String
    public let name: String
    public let platform: StreamingPlatform
    public let thumbnailURL: String?

    public init(id: String, name: String, platform: StreamingPlatform, thumbnailURL: String? = nil) {
        self.id = id
        self.name = name
        self.platform = platform
        self.thumbnailURL = thumbnailURL
    }
}

public struct StreamStatistics {
    public let viewerCount: Int
    public let duration: TimeInterval
    public let platforms: [StreamingPlatform]
    public let peakViewers: Int

    public var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
