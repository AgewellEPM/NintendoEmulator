import SwiftUI
import AppKit
import AVFoundation
import ScreenCaptureKit

/// Live preview of a specific application window using ScreenCaptureKit.
/// Shows the content inside an AVSampleBufferDisplayLayer for smooth playback.
public struct WindowCapturePreview: NSViewRepresentable {
    public typealias NSViewType = SampleBufferLayerView

    @ObservedObject var manager: GameWindowCaptureManager

    public init(manager: GameWindowCaptureManager) {
        self.manager = manager
    }

    public func makeNSView(context: Context) -> SampleBufferLayerView {
        let v = SampleBufferLayerView()
        v.attach(to: manager)
        return v
    }

    public func updateNSView(_ nsView: SampleBufferLayerView, context: Context) {
        nsView.attach(to: manager)
    }
}

/// Simple NSView hosting an AVSampleBufferDisplayLayer.
public final class SampleBufferLayerView: NSView {
    private let displayLayer = AVSampleBufferDisplayLayer()

    public override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer = CALayer()
        displayLayer.videoGravity = .resizeAspect
        layer?.addSublayer(displayLayer)
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
        layer = CALayer()
        displayLayer.videoGravity = .resizeAspect
        layer?.addSublayer(displayLayer)
    }

    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        displayLayer.frame = bounds
        CATransaction.commit()
    }

    public func attach(to manager: GameWindowCaptureManager) {
        manager.attach(displayLayer: displayLayer)
    }
}

/// Manager that discovers the Mupen64Plus (or emulator) window and streams it to a display layer.
@MainActor
public final class GameWindowCaptureManager: ObservableObject {
    @Published public private(set) var isCapturing: Bool = false
    @Published public private(set) var hasPermission: Bool = false
    @Published public private(set) var selectedWindowTitle: String?
    @Published public private(set) var selectedAppName: String?

    private var stream: SCStream?
    private var output: StreamOutput?
    private weak var targetLayer: AVSampleBufferDisplayLayer?

    /// Attach a display layer to receive frames.
    public func attach(displayLayer: AVSampleBufferDisplayLayer) {
        targetLayer = displayLayer
        output?.targetLayer = displayLayer
    }

    /// Start capturing the best matching game window.
    public func start() {
        Task { @MainActor in
            await startInternal()
        }
    }

    /// Stop capturing.
    public func stop() {
        Task { @MainActor in
            await stopInternal()
        }
    }

    private func startInternal() async {
        // Already running?
        if isCapturing { return }

        // Check permission via querying shareable content
        do {
            _ = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            hasPermission = true
        } catch {
            hasPermission = false
            NSLog("[WindowCapture] Screen recording permission missing: \(error.localizedDescription)")
            return
        }

        do {
            guard let window = try await pickBestGameWindow() else {
                NSLog("[WindowCapture] No candidate game window found")
                return
            }

            selectedWindowTitle = window.title
            selectedAppName = window.owningApplication?.applicationName

            let filter = SCContentFilter(desktopIndependentWindow: window)
            let config = SCStreamConfiguration()
            // Use window size; SC will scale as needed by the layer
            config.width = Int(window.frame.width)
            config.height = Int(window.frame.height)
            config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS target
            config.queueDepth = 5
            config.showsCursor = false
            config.capturesAudio = false

            // Hide window frame/title bar - capture content only
            if #available(macOS 14.2, *) {
                config.includeChildWindows = false
            }
            if #available(macOS 14.0, *) {
                config.shouldBeOpaque = true
            }

            let stream = SCStream(filter: filter, configuration: config, delegate: nil)
            let output = StreamOutput()
            output.targetLayer = targetLayer

            try stream.addStreamOutput(output, type: .screen, sampleHandlerQueue: DispatchQueue(label: "game.window.capture"))
            try await stream.startCapture()

            self.stream = stream
            self.output = output
            self.isCapturing = true

            NSLog("[WindowCapture] ✅ Started capturing: \(selectedAppName ?? "?") — \(selectedWindowTitle ?? "?")")
        } catch {
            NSLog("[WindowCapture] Failed to start capture: \(error.localizedDescription)")
        }
    }

    private func stopInternal() async {
        if let s = stream {
            do { try await s.stopCapture() } catch { NSLog("[WindowCapture] stop error: \(error)") }
        }
        stream = nil
        output = nil
        isCapturing = false
    }

    /// Heuristics to select the best game window (Mupen64Plus/GLideN64, or the app's own emulator window).
    private func pickBestGameWindow() async throws -> SCWindow? {
        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

        // Prefer our own app's emulator window first
        let bundleID = Bundle.main.bundleIdentifier ?? ""

        let ownWindows = content.windows.filter { w in
            if let owning = w.owningApplication, owning.bundleIdentifier == bundleID { return true }
            let title = (w.title ?? "").lowercased()
            return title.contains("nintendo emulator") || title.contains("emulator")
        }

        // External Mupen64Plus/GLide windows - ONLY match by exact app name
        let external = content.windows.filter { w in
            let appName = w.owningApplication?.applicationName.lowercased() ?? ""
            let title = (w.title ?? "").lowercased()

            // ONLY match if the application name is exactly "mupen64plus"
            // Do NOT match by window title to avoid false positives (Terminal windows, etc.)
            let isMatch = appName == "mupen64plus"

            // Debug log to see what windows we're checking
            if appName.contains("mupen") || title.contains("mupen") || title.contains("glide") {
                NSLog("[WindowCapture] Checking mupen-related window: app='\(appName)' title='\(title)' match=\(isMatch)")
            }
            return isMatch
        }

        NSLog("[WindowCapture] Found \(ownWindows.count) own windows, \(external.count) external game windows")

        // Prefer external game windows (Mupen64Plus) first, then own windows
        // Select by highest window ID (most recently created)
        let candidate: SCWindow?
        if !external.isEmpty {
            candidate = external.max(by: { lhs, rhs in
                lhs.windowID < rhs.windowID
            })
        } else if !ownWindows.isEmpty {
            candidate = ownWindows.max(by: { lhs, rhs in
                lhs.windowID < rhs.windowID
            })
        } else {
            candidate = nil
        }

        if let c = candidate {
            NSLog("[WindowCapture] Selected candidate: \(c.owningApplication?.applicationName ?? "?") - \(c.title ?? "?")")
            return c
        }

        // Fallback: find largest window that isn't a backstop/desktop
        let fallback = content.windows.filter { w in
            let title = (w.title ?? "").lowercased()
            return !title.contains("backstop") && !title.isEmpty && w.frame.width > 100 && w.frame.height > 100
        }.max(by: { lhs, rhs in
            (lhs.frame.width * lhs.frame.height) < (rhs.frame.width * rhs.frame.height)
        })

        if let f = fallback {
            NSLog("[WindowCapture] Fallback selected: \(f.owningApplication?.applicationName ?? "?") - \(f.title ?? "?")")
        }

        return fallback
    }

    // MARK: - Output handler
    private final class StreamOutput: NSObject, SCStreamOutput {
        weak var targetLayer: AVSampleBufferDisplayLayer?
        private var firstPTS: CMTime = .invalid

        func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
            guard sampleBuffer.isValid, type == .screen else { return }

            var buffer = sampleBuffer
            // Normalize timestamps for smoother playback
            if firstPTS == .invalid {
                firstPTS = buffer.presentationTimeStamp
            } else {
                var timing = CMSampleTimingInfo(
                    duration: buffer.duration,
                    presentationTimeStamp: buffer.presentationTimeStamp - firstPTS,
                    decodeTimeStamp: .invalid
                )
                var adjusted: CMSampleBuffer?
                CMSampleBufferCreateCopyWithNewTiming(
                    allocator: kCFAllocatorDefault,
                    sampleBuffer: buffer,
                    sampleTimingEntryCount: 1,
                    sampleTimingArray: &timing,
                    sampleBufferOut: &adjusted
                )
                if let adj = adjusted { buffer = adj }
            }

            // Enqueue directly on the sample handler queue; AVSampleBufferDisplayLayer is thread-safe for enqueue.
            targetLayer?.enqueue(buffer)
        }
    }
}
