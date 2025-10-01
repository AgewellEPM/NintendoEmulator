import Foundation
import CoreInterface
import Combine
import os.log
import N64VidExtBridge
import InputSystem
// import CMupen64Plus  // Conflicts with N64VidExtBridge types

/// Native N64 emulator using mupen64plus library directly (no CLI process)
@objc(NativeN64Core)
public final class NativeN64Core: NSObject, EmulatorCoreProtocol, EmulatorRenderingProtocol {
    public let coreIdentifier = "com.emulator.n64.native"
    public let coreVersion = "2.6.0"
    public let supportedSystems: [EmulatorSystem] = [.n64]
    public private(set) var loadedROM: ROMMetadata?
    public var currentState: EmulatorState { stateSubject.value }

    private let frameSubject = PassthroughSubject<FrameData, Never>()
    private let audioSubject = PassthroughSubject<AudioBuffer, Never>()
    private let stateSubject = CurrentValueSubject<EmulatorState, Never>(.uninitialized)
    private let metricsSubject = PassthroughSubject<PerformanceMetrics, Never>()

    public var framePublisher: AnyPublisher<FrameData, Never> { frameSubject.eraseToAnyPublisher() }
    public var audioPublisher: AnyPublisher<AudioBuffer, Never> { audioSubject.eraseToAnyPublisher() }
    public var statePublisher: AnyPublisher<EmulatorState, Never> { stateSubject.eraseToAnyPublisher() }
    public var metricsPublisher: AnyPublisher<PerformanceMetrics, Never> { metricsSubject.eraseToAnyPublisher() }

    private let logger = Logger(subsystem: "com.emulator", category: "NativeN64")

    // Native library handle
    private var coreLibrary: UnsafeMutableRawPointer?
    private var romData: Data?
    private var isRunning = false
    private var emulatorThread: Thread?

    // Direct input injection
    private var inputInjectionCallback: ((EmulatorButton, Bool) -> Void)?
    private var analogInjectionCallback: ((Float, Float) -> Void)?

    // MARK: - Initialization

    public override init() {
        super.init()
        ControllerManager.shared.setInputDelegate(self, for: 0)
        logger.info("✅ Native N64 Core initialized")
    }

    deinit {
        // Synchronous cleanup in deinit
        if let handle = coreLibrary, let shutdownFn = dlsym(handle, "CoreShutdown") {
            let CoreShutdown = unsafeBitCast(shutdownFn, to: (@convention(c) () -> Int32).self)
            _ = CoreShutdown()
        }
        if let handle = coreLibrary {
            dlclose(handle)
        }
    }

    public class func createInstance() throws -> NativeN64Core {
        return NativeN64Core()
    }

    public func setInputInjectionCallbacks(
        buttonCallback: @escaping (EmulatorButton, Bool) -> Void,
        analogCallback: @escaping (Float, Float) -> Void
    ) {
        self.inputInjectionCallback = buttonCallback
        self.analogInjectionCallback = analogCallback
        logger.info("✅ Input injection callbacks registered")
    }

    // MARK: - EmulatorRenderingProtocol

    public var frameSize: CGSize {
        let w = Int(VidExt_GetWidth())
        let h = Int(VidExt_GetHeight())
        return CGSize(width: max(w, 640), height: max(h, 480))
    }

    public var pixelFormat: FrameData.PixelFormat { .rgba8888 }

    public var framebuffer: UnsafeMutableRawPointer? {
        guard let ptr = VidExt_GetFrameBuffer() else { return nil }
        return UnsafeMutableRawPointer(mutating: ptr)
    }

    public func prepareFrame() { }
    public func presentFrame() { }
    public func setRenderScale(scale: Float) { }
    public func setPostProcessingEffects(_ effects: [PostProcessEffect]) { }
    public func captureScreenshot() -> Data? { nil }

    // MARK: - Core Lifecycle

    public func initialize(configuration: EmulatorConfiguration) async throws {
        logger.info("🎮 Initializing native mupen64plus core")

        // Load the library
        guard let libPath = findLibraryPath() else {
            throw EmulatorError.initializationFailed("libmupen64plus.dylib not found")
        }

        logger.info("📚 Loading library from: \(libPath)")
        guard let handle = dlopen(libPath, RTLD_NOW | RTLD_LOCAL) else {
            let error = String(cString: dlerror())
            throw EmulatorError.initializationFailed("Failed to load library: \(error)")
        }

        coreLibrary = handle

        // Initialize the core
        guard let startupFn = dlsym(handle, "CoreStartup") else {
            throw EmulatorError.initializationFailed("CoreStartup symbol not found")
        }

        let CoreStartup = unsafeBitCast(startupFn, to: (@convention(c) (Int32, UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?, Int32, UnsafePointer<Int8>?) -> Void)?, UnsafeMutableRawPointer?, (@convention(c) (UnsafeMutableRawPointer?, Int32, Int32) -> Void)?) -> Int32).self)

        let apiVersion: Int32 = 0x020001 // Version 2.0.1
        let result = CoreStartup(apiVersion, nil, nil, nil, nil, nil, nil)

        if result != 0 {
            throw EmulatorError.initializationFailed("CoreStartup failed with code \(result)")
        }

        // TODO: Set up video extension
        // Video extension will be configured separately
        logger.info("📺 Video extension setup deferred")

        stateSubject.send(.initialized)
        logger.info("✅ Native core initialized successfully")
    }

    public func shutdown() async {
        logger.info("🛑 Shutting down native core")

        if isRunning {
            await stop()
        }

        if let handle = coreLibrary, let shutdownFn = dlsym(handle, "CoreShutdown") {
            let CoreShutdown = unsafeBitCast(shutdownFn, to: (@convention(c) () -> Int32).self)
            _ = CoreShutdown()
        }

        if let handle = coreLibrary {
            dlclose(handle)
            coreLibrary = nil
        }

        romData = nil
        stateSubject.send(.uninitialized)
        logger.info("✅ Shutdown complete")
    }

    // MARK: - ROM Management

    public func loadROM(data: Data, metadata: ROMMetadata) async throws {
        logger.info("📀 Loading ROM: \(metadata.title)")

        guard let handle = coreLibrary else {
            throw EmulatorError.initializationFailed("Core not initialized")
        }

        // Check and swap ROM if needed
        var processedData = data
        let header = data.prefix(4)
        let headerBytes = Array(header)

        // N64 ROM should be big-endian: 0x80 0x37 0x12 0x40
        if headerBytes.count >= 4 && headerBytes[0] == 0x37 && headerBytes[1] == 0x80 {
            logger.info("🔄 Swapping ROM from little-endian to big-endian")
            processedData = Data()
            for i in stride(from: 0, to: data.count, by: 4) {
                let remaining = min(4, data.count - i)
                if remaining >= 4 {
                    processedData.append(contentsOf: [data[i+1], data[i], data[i+3], data[i+2]])
                } else {
                    for j in 0..<remaining {
                        processedData.append(data[i+j])
                    }
                }
            }
        }

        self.romData = processedData
        self.loadedROM = metadata

        // Open ROM in core
        guard let doCommandFn = dlsym(handle, "CoreDoCommand") else {
            throw EmulatorError.romLoadFailed("CoreDoCommand not found")
        }

        let CoreDoCommand = unsafeBitCast(doCommandFn, to: (@convention(c) (Int32, Int32, UnsafeMutableRawPointer?) -> Int32).self)

        let romSize = Int32(processedData.count)
        let result = processedData.withUnsafeBytes { bytes in
            return CoreDoCommand(1, romSize, UnsafeMutableRawPointer(mutating: bytes.baseAddress))  // M64CMD_ROM_OPEN = 1
        }

        if result != 0 {
            throw EmulatorError.romLoadFailed("Failed to open ROM: \(result)")
        }

        stateSubject.send(.romLoaded)
        logger.info("✅ ROM loaded successfully")
    }

    public func unloadROM() async {
        guard let handle = coreLibrary, let doCommandFn = dlsym(handle, "CoreDoCommand") else {
            return
        }

        let CoreDoCommand = unsafeBitCast(doCommandFn, to: (@convention(c) (Int32, Int32, UnsafeMutableRawPointer?) -> Int32).self)
        _ = CoreDoCommand(2, 0, nil)  // M64CMD_ROM_CLOSE = 2

        loadedROM = nil
        romData = nil
        stateSubject.send(.initialized)
    }

    public func validateROM(data: Data) -> ROMValidationResult {
        return ROMValidationResult(isValid: data.count > 0x1000, system: .n64)
    }

    // MARK: - Emulation Control

    public func start() async throws {
        logger.info("▶️ Starting emulation")

        guard let handle = coreLibrary, let doCommandFn = dlsym(handle, "CoreDoCommand") else {
            throw EmulatorError.executionError("Core not initialized")
        }

        let CoreDoCommand = unsafeBitCast(doCommandFn, to: (@convention(c) (Int32, Int32, UnsafeMutableRawPointer?) -> Int32).self)

        // Start execution in background thread
        isRunning = true
        stateSubject.send(.running)

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            guard let self = self else { return }

            let result = CoreDoCommand(5, 0, nil)  // M64CMD_EXECUTE = 5

            DispatchQueue.main.async {
                self.isRunning = false
                self.stateSubject.send(.stopped)
                if result != 0 {
                    self.logger.error("Execution failed: \(result)")
                }
            }
        }

        logger.info("✅ Emulation started")
    }

    public func stop() async {
        logger.info("⏹️ Stopping emulation")

        guard let handle = coreLibrary, let doCommandFn = dlsym(handle, "CoreDoCommand") else {
            return
        }

        let CoreDoCommand = unsafeBitCast(doCommandFn, to: (@convention(c) (Int32, Int32, UnsafeMutableRawPointer?) -> Int32).self)
        _ = CoreDoCommand(6, 0, nil)  // M64CMD_STOP = 6

        isRunning = false
        stateSubject.send(.stopped)
        logger.info("✅ Emulation stopped")
    }

    public func pause() async {
        logger.info("⏸️ Pausing emulation")

        guard let handle = coreLibrary, let doCommandFn = dlsym(handle, "CoreDoCommand") else {
            return
        }

        let CoreDoCommand = unsafeBitCast(doCommandFn, to: (@convention(c) (Int32, Int32, UnsafeMutableRawPointer?) -> Int32).self)
        _ = CoreDoCommand(7, 0, nil)  // M64CMD_PAUSE = 7

        stateSubject.send(.paused)
        logger.info("⏸️ Paused")
    }

    public func resume() async throws {
        logger.info("▶️ Resuming emulation")

        guard let handle = coreLibrary, let doCommandFn = dlsym(handle, "CoreDoCommand") else {
            throw EmulatorError.executionError("Core not initialized")
        }

        let CoreDoCommand = unsafeBitCast(doCommandFn, to: (@convention(c) (Int32, Int32, UnsafeMutableRawPointer?) -> Int32).self)
        _ = CoreDoCommand(8, 0, nil)  // M64CMD_RESUME = 8

        stateSubject.send(.running)
        logger.info("▶️ Resumed")
    }

    public func reset() async throws {
        logger.info("🔄 Resetting emulation")
        await stop()
        try await start()
    }

    public func runFrame() async throws {
        // Frame is run continuously by the core
        let w = Int(VidExt_GetWidth())
        let h = Int(VidExt_GetHeight())
        if w > 0 && h > 0, let ptr = VidExt_GetFrameBuffer() {
            let frame = FrameData(
                pixelData: UnsafeMutableRawPointer(mutating: ptr),
                width: w,
                height: h,
                bytesPerRow: Int(VidExt_GetBytesPerRow()),
                pixelFormat: .rgba8888,
                timestamp: Date().timeIntervalSince1970
            )
            frameSubject.send(frame)
        }
        metricsSubject.send(PerformanceMetrics(fps: 60, frameTime: 16.67, cpuUsage: 0, memoryUsage: 0, audioLatency: 0, inputLatency: 0))
    }

    public func step() async throws {
        try await runFrame()
    }

    // MARK: - Save States

    public func createSaveState() async throws -> Data {
        // TODO: Implement save state
        return Data()
    }

    public func loadSaveState(data: Data) async throws {
        // TODO: Implement save state loading
    }

    public func quickSave(slot: Int) async throws {
        logger.info("💾 Quick save slot \(slot)")
    }

    public func quickLoad(slot: Int) async throws {
        logger.info("📂 Quick load slot \(slot)")
    }

    // MARK: - Helper Methods

    private func findLibraryPath() -> String? {
        let candidates = [
            "Frameworks/libmupen64plus.dylib",
            "../Frameworks/libmupen64plus.dylib",
            Bundle.main.bundleURL.appendingPathComponent("Contents/Frameworks/libmupen64plus.dylib").path,
            "/opt/homebrew/lib/libmupen64plus.dylib"
        ]

        for path in candidates {
            let fullPath = path.hasPrefix("/") ? path : FileManager.default.currentDirectoryPath + "/" + path
            if FileManager.default.fileExists(atPath: fullPath) {
                return fullPath
            }
        }

        return nil
    }
}

// MARK: - Sendable Conformance
extension NativeN64Core: @unchecked Sendable {}

// MARK: - Input Protocol
extension NativeN64Core: EmulatorInputProtocol {
    public func setButtonState(player: Int, button: EmulatorButton, pressed: Bool) {
        if let callback = inputInjectionCallback {
            callback(button, pressed)
        }
    }

    public func setAnalogState(player: Int, stick: AnalogStick, x: Float, y: Float) {
        if let callback = analogInjectionCallback {
            callback(x, y)
        }
    }

    public func setTriggerState(player: Int, trigger: Trigger, value: Float) {
        if value > 0.5 {
            setButtonState(player: player, button: .zl, pressed: true)
        } else {
            setButtonState(player: player, button: .zl, pressed: false)
        }
    }

    public func rumble(player: Int, intensity: Float, duration: TimeInterval) {
        logger.info("🎮 Rumble: \(intensity)")
    }

    public func setTouchState(x: Int, y: Int, pressed: Bool) { }
    public func setAccelerometer(x: Float, y: Float, z: Float) { }
    public func setGyroscope(pitch: Float, roll: Float, yaw: Float) { }

    public func getInputState(player: Int) -> InputState {
        return InputState()
    }
}
