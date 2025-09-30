import Foundation
import CoreInterface
import os.log

/// Controls emulation execution and frame timing
actor ExecutionController {

    // MARK: - Properties

    private var emulationTask: Task<Void, Error>?
    private let frameTimer = ContinuousClock()
    private var isPaused = false
    private var shouldStop = false
    private let logger = Logger(subsystem: "com.emulator", category: "ExecutionController")

    // Frame timing
    private let targetFrameTime = Duration.milliseconds(16.67) // 60 FPS
    private var frameSkip = 0
    private var currentFrameSkip = 0

    // Statistics
    private var frameCount: UInt64 = 0
    private var totalFrameTime: Duration = .zero
    private var lastFPSUpdate = Date()
    private var fpsFrameCount = 0

    // MARK: - Public Methods

    /// Start emulation execution
    func start(core: EmulatorCoreProtocol, frameCallback: @escaping (FrameData) -> Void) async throws {
        guard emulationTask == nil else {
            logger.warning("Emulation already running")
            NSLog("[ExecutionController] start: already running")
            return
        }

        shouldStop = false
        isPaused = false

        emulationTask = Task {
            logger.info("Starting emulation loop")
            NSLog("[ExecutionController] Emulation loop started")

            while !Task.isCancelled && !shouldStop {
                if isPaused {
                    try await Task.sleep(for: .milliseconds(16))
                    continue
                }

                let frameStart = frameTimer.now

                // Execute frame
                try await executeFrame(core: core, frameCallback: frameCallback)

                // Frame timing
                let frameEnd = frameTimer.now
                let frameDuration = frameEnd - frameStart
                totalFrameTime += frameDuration

                // Calculate sleep time
                if frameDuration < targetFrameTime {
                    let sleepTime = targetFrameTime - frameDuration
                    try await Task.sleep(for: sleepTime)
                }

                // Update statistics
                updateStatistics()
            }

            logger.info("Emulation loop ended")
            NSLog("[ExecutionController] Emulation loop ended")
        }

        try await emulationTask?.value
    }

    /// Pause execution
    func pause() {
        isPaused = true
        logger.info("Emulation paused")
        NSLog("[ExecutionController] pause()")
    }

    /// Resume execution
    func resume() throws {
        guard emulationTask != nil else {
            throw EmulatorError.executionError("No emulation task running")
        }
        isPaused = false
        logger.info("Emulation resumed")
        NSLog("[ExecutionController] resume()")
    }

    /// Stop execution
    func stop() {
        shouldStop = true
        emulationTask?.cancel()
        emulationTask = nil
        logger.info("Emulation stopped")
        NSLog("[ExecutionController] stop()")
    }

    /// Set frame skip
    func setFrameSkip(_ skip: Int) {
        frameSkip = max(0, min(skip, 10))
        logger.info("Frame skip set to \(self.frameSkip)")
    }

    /// Get current FPS
    func getCurrentFPS() -> Double {
        let elapsed = Date().timeIntervalSince(lastFPSUpdate)
        guard elapsed > 0 else { return 0 }
        return Double(fpsFrameCount) / elapsed
    }

    // MARK: - Private Methods

    private func executeFrame(
        core: EmulatorCoreProtocol,
        frameCallback: @escaping (FrameData) -> Void
    ) async throws {
        // Handle frame skipping
        if currentFrameSkip > 0 {
            currentFrameSkip -= 1
            try await core.runFrame()
            return
        }

        // Run frame and get video data
        try await core.runFrame()

        // Emit frame if not skipping
        if let renderCore = core as? EmulatorRenderingProtocol,
           let framebuffer = renderCore.framebuffer {
            let frame = FrameData(
                pixelData: framebuffer,
                width: Int(renderCore.frameSize.width),
                height: Int(renderCore.frameSize.height),
                bytesPerRow: Int(renderCore.frameSize.width) * 4,
                pixelFormat: renderCore.pixelFormat,
                timestamp: Date().timeIntervalSince1970
            )
            frameCallback(frame)
        }

        // Reset frame skip counter
        currentFrameSkip = frameSkip

        frameCount += 1
    }

    private func updateStatistics() {
        fpsFrameCount += 1

        // Update FPS every second
        let now = Date()
        if now.timeIntervalSince(lastFPSUpdate) >= 1.0 {
            lastFPSUpdate = now
            fpsFrameCount = 0
        }
    }
}

// MARK: - Frame Limiter

actor FrameLimiter {
    private let targetFPS: Double
    private let frameTime: Duration
    private var lastFrameTime: ContinuousClock.Instant?
    private let clock = ContinuousClock()

    init(targetFPS: Double = 60.0) {
        self.targetFPS = targetFPS
        self.frameTime = .milliseconds(1000.0 / targetFPS)
    }

    func waitForNextFrame() async throws {
        guard let last = lastFrameTime else {
            lastFrameTime = clock.now
            return
        }

        let elapsed = clock.now - last
        if elapsed < frameTime {
            try await Task.sleep(for: frameTime - elapsed)
        }

        lastFrameTime = clock.now
    }

    func reset() {
        lastFrameTime = nil
    }
}
