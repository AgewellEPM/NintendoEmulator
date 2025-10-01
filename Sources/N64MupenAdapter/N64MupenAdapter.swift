import Foundation
import CoreInterface
import Combine
import os.log
import N64VidExtBridge
import InputSystem

// Minimal dynamic loader for mupen64plus core; video/audio/input wiring to follow.
@objc(N64MupenAdapter)
public final class N64MupenAdapter: NSObject, EmulatorCoreProtocol, EmulatorRenderingProtocol {
    public let coreIdentifier = "com.emulator.n64.mupen64plus"
    public let coreVersion = "0.1.0"
    public let supportedSystems: [EmulatorSystem] = [.n64]
    public private(set) var loadedROM: ROMMetadata?
    public var currentState: EmulatorState { stateSubject.value }

    // Window configuration
    public static var windowResolution: String = "640x480"
    public static var isFullscreen: Bool = false

    private let frameSubject = PassthroughSubject<FrameData, Never>()
    private let audioSubject = PassthroughSubject<AudioBuffer, Never>()
    private let stateSubject = CurrentValueSubject<EmulatorState, Never>(.uninitialized)
    private let metricsSubject = PassthroughSubject<PerformanceMetrics, Never>()

    public var framePublisher: AnyPublisher<FrameData, Never> { frameSubject.eraseToAnyPublisher() }
    public var audioPublisher: AnyPublisher<AudioBuffer, Never> { audioSubject.eraseToAnyPublisher() }
    public var statePublisher: AnyPublisher<EmulatorState, Never> { stateSubject.eraseToAnyPublisher() }
    public var metricsPublisher: AnyPublisher<PerformanceMetrics, Never> { metricsSubject.eraseToAnyPublisher() }

    private let logger = Logger(subsystem: "com.emulator", category: "N64MupenAdapter")

    // Hybrid approach - use CLI for actual emulation
    private var coreHandle: UnsafeMutableRawPointer?
    private var romData: Data?
    private var mupenProcess: Process?
    private var romPath: String?

    // Direct memory input injection
    private var inputInjectionCallback: ((EmulatorButton, Bool) -> Void)?
    private var analogInjectionCallback: ((Float, Float) -> Void)?

    // Core API function pointers (subset)
    typealias CoreStartupFn = @convention(c) (UInt32, UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafePointer<Int8>?, UnsafeMutablePointer<UnsafeMutablePointer<Int8>?>?) -> Int32
    typealias CoreShutdownFn = @convention(c) () -> Int32
    typealias CoreDoCommandFn = @convention(c) (Int32, Int32, UnsafeMutableRawPointer?) -> Int32
    typealias CoreAttachPluginFn = @convention(c) (Int32, UnsafeMutableRawPointer?) -> Int32
    typealias CoreDetachPluginFn = @convention(c) (Int32) -> Int32

    private var CoreStartup: CoreStartupFn?
    private var CoreShutdown: CoreShutdownFn?
    private var CoreDoCommand: CoreDoCommandFn?
    private var CoreAttachPlugin: CoreAttachPluginFn?
    private var CoreDetachPlugin: CoreDetachPluginFn?
    private var pluginsAttached = false

    // Mupen command and plugin constants (from m64p_types.h)
    // Note: M64CMD_ROM_LOAD doesn't exist - ROM_OPEN should work with file path
    private static let M64CMD_ROM_OPEN: Int32 = 1
    private static let M64CMD_ROM_CLOSE: Int32 = 2
    private static let M64CMD_ROM_GET_HEADER: Int32 = 3
    private static let M64CMD_ROM_GET_SETTINGS: Int32 = 4
    private static let M64CMD_EXECUTE: Int32 = 5
    private static let M64CMD_STOP: Int32 = 6
    private static let M64CMD_PAUSE: Int32 = 7
    private static let M64CMD_RESUME: Int32 = 8

    private static let M64PLUGIN_RSP: Int32 = 1
    private static let M64PLUGIN_GFX: Int32 = 2
    private static let M64PLUGIN_AUDIO: Int32 = 3
    private static let M64PLUGIN_INPUT: Int32 = 4

    typealias CoreVideoSetVidExtFn = @convention(c) (UnsafePointer<m64p_video_extension_functions>) -> Int32
    private var CoreVideo_SetVidExt: CoreVideoSetVidExtFn?

    public override init() {
        super.init()

        // Register as input delegate for player 0
        ControllerManager.shared.setInputDelegate(self, for: 0)
        NSLog("[N64MupenAdapter] ✅ Registered as input delegate for AI controller injection")
    }

    /// Set direct memory input injection callbacks
    public func setInputInjectionCallbacks(
        buttonCallback: @escaping (EmulatorButton, Bool) -> Void,
        analogCallback: @escaping (Float, Float) -> Void
    ) {
        self.inputInjectionCallback = buttonCallback
        self.analogInjectionCallback = analogCallback
        NSLog("[N64MupenAdapter] ✅ Input injection callbacks registered")
    }

    // Alternative throwing initializer for EmulatorCoreProtocol compatibility
    @objc public class func createInstance() throws -> N64MupenAdapter {
        return N64MupenAdapter()
    }

    // MARK: - EmulatorRenderingProtocol
    public var frameSize: CGSize {
        let w = Int(VidExt_GetWidth())
        let h = Int(VidExt_GetHeight())
        return CGSize(width: max(w, 0), height: max(h, 0))
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

    public func initialize(configuration: EmulatorConfiguration) async throws {
        NSLog("[N64MupenAdapter] Initializing mupen64plus")
        // Verify mupen64plus CLI is available in common locations
        guard let mupenPath = findMupenExecutable() else {
            throw EmulatorError.initializationFailed("mupen64plus CLI not found in standard locations")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: mupenPath)
        process.arguments = ["--help"]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""

            if output.contains("Mupen64Plus") || output.contains("mupen64plus") || process.terminationStatus == 0 {
                NSLog("[N64MupenAdapter] ✅ mupen64plus CLI available")
                stateSubject.send(.initialized)
            } else {
                throw EmulatorError.initializationFailed("mupen64plus CLI not available")
            }
        } catch {
            throw EmulatorError.initializationFailed("Failed to verify mupen64plus: \(error)")
        }
    }

    public func shutdown() async {
        NSLog("[N64MupenAdapter] Shutting down")

        // Terminate CLI process if running
        if let process = mupenProcess, process.isRunning {
            process.terminate()
            process.waitUntilExit()
            mupenProcess = nil
        }

        romData = nil
        romPath = nil
        stateSubject.send(.uninitialized)
        NSLog("[N64MupenAdapter] ✅ Shutdown complete")
    }

    public func loadROM(data: Data, metadata: ROMMetadata) async throws {
        NSLog("[N64MupenAdapter] Loading ROM: %@", metadata.title)

        // Check ROM header and perform byte swapping if needed
        let header = data.prefix(4)
        NSLog("[N64MupenAdapter] ROM header bytes: %@", header.map { String(format: "%02X", $0) }.joined(separator: " "))

        var processedData = data
        let headerBytes = Array(header)

        // N64 ROM should start with 0x80 0x37 0x12 0x40 (big-endian)
        // If it starts with 0x37 0x80 0x40 0x12, it's little-endian and needs swapping
        if headerBytes.count >= 4 && headerBytes[0] == 0x37 && headerBytes[1] == 0x80 && headerBytes[2] == 0x40 && headerBytes[3] == 0x12 {
            NSLog("[N64MupenAdapter] Detected little-endian ROM, performing byte swap...")
            processedData = Data()
            // Swap bytes in pairs: ABCD -> BADC (37 80 40 12 -> 80 37 12 40)
            for i in stride(from: 0, to: data.count, by: 4) {
                let remaining = min(4, data.count - i)
                if remaining >= 4 {
                    let a = data[i]
                    let b = data[i+1]
                    let c = data[i+2]
                    let d = data[i+3]
                    processedData.append(contentsOf: [b, a, d, c])  // BADC swap
                } else {
                    // Handle remaining bytes
                    for j in 0..<remaining {
                        processedData.append(data[i+j])
                    }
                }
            }
            NSLog("[N64MupenAdapter] After byte swap: %@", processedData.prefix(4).map { String(format: "%02X", $0) }.joined(separator: " "))
        }

        // Store ROM data
        self.romData = processedData

        // Write ROM to temp file for CLI
        let tempDir = FileManager.default.temporaryDirectory
        let tempROMPath = tempDir.appendingPathComponent("\(metadata.title.replacingOccurrences(of: " ", with: "_")).n64")
        try processedData.write(to: tempROMPath)
        self.romPath = tempROMPath.path
        NSLog("[N64MupenAdapter] Wrote ROM to: %@", self.romPath!)

        loadedROM = metadata
        stateSubject.send(.romLoaded)
        NSLog("[N64MupenAdapter] ✅ ROM ready for CLI execution")
    }

    public func unloadROM() async {
        loadedROM = nil
        stateSubject.send(.initialized)
    }

    public func validateROM(data: Data) -> ROMValidationResult {
        // Basic size check; real validation via header would be better
        return ROMValidationResult(isValid: data.count > 0x1000, system: .n64)
    }

    public func runFrame() async throws {
        // If core supports continuous execution, just return; start() will run loop
        // Emit latest captured frame if available
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
        metricsSubject.send(PerformanceMetrics(fps: 0, frameTime: 0, cpuUsage: 0, memoryUsage: 0, audioLatency: 0, inputLatency: 0))
    }

    public func start() async throws {
        NSLog("[N64MupenAdapter] Starting mupen64plus CLI process")

        guard let romPath = romPath else {
            throw EmulatorError.romLoadFailed("No ROM loaded")
        }

        // Terminate any existing process
        if let existingProcess = mupenProcess, existingProcess.isRunning {
            existingProcess.terminate()
            existingProcess.waitUntilExit()
        }

        // Create new process
        let process = Process()
        if let mupenPath = findMupenExecutable() {
            process.executableURL = URL(fileURLWithPath: mupenPath)
        } else {
            // Fallback: try PATH lookup via /usr/bin/env
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        }

        // CLI arguments for better performance
        var args: [String] = []
        if process.executableURL?.lastPathComponent == "env" {
            args.append("mupen64plus")
        }
        // Apply window settings
        if N64MupenAdapter.isFullscreen {
            args.append("--fullscreen")
        } else {
            args.append("--windowed")
            args.append("--resolution")
            args.append(N64MupenAdapter.windowResolution)
        }
        args.append(contentsOf: [
            "--gfx", "mupen64plus-video-glide64mk2",  // Use glide64mk2 for better compatibility
            "--audio", "mupen64plus-audio-sdl", // SDL audio
            "--input", "mupen64plus-input-sdl", // SDL input
            "--rsp", "mupen64plus-rsp-hle",     // HLE RSP
            "--emumode", "2",          // DynaRec for maximum speed
            romPath                    // ROM file
        ])
        process.arguments = args

        NSLog("[N64MupenAdapter] Launching: %@ %@", process.executableURL!.path, process.arguments!.joined(separator: " "))

        do {
            try process.run()
            mupenProcess = process
            stateSubject.send(.running)

            NSLog("[N64MupenAdapter] ✅ mupen64plus CLI process launched! PID: %d", process.processIdentifier)

            // Monitor process in background
            DispatchQueue.global(qos: .background).async { [weak self] in
                process.waitUntilExit()
                DispatchQueue.main.async {
                    NSLog("[N64MupenAdapter] mupen64plus process ended with status: %d", process.terminationStatus)
                    self?.stateSubject.send(.stopped)
                    self?.mupenProcess = nil
                }
            }

        } catch {
            NSLog("[N64MupenAdapter] ERROR: Failed to launch mupen64plus: %@", error.localizedDescription)
            throw EmulatorError.executionError("Failed to start mupen64plus: \(error)")
        }
    }

    // MARK: - Executable discovery
    private func findMupenExecutable() -> String? {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/mupen64plus",
            "/usr/local/bin/mupen64plus",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/NintendoEmulator/build/mupen64/bin/mupen64plus"
        ]
        for path in candidates {
            if fm.fileExists(atPath: path) { return path }
        }
        // Try PATH via /usr/bin/which
        let which = Process()
        which.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        which.arguments = ["mupen64plus"]
        let pipe = Pipe()
        which.standardOutput = pipe
        which.standardError = Pipe()
        do {
            try which.run()
            which.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !path.isEmpty, fm.fileExists(atPath: path) {
                return path
            }
        } catch { }
        return nil
    }

    public func stop() async {
        NSLog("[N64MupenAdapter] Stopping mupen64plus")

        if let process = mupenProcess, process.isRunning {
            // First try graceful termination
            process.terminate()

            // Wait up to 2 seconds for graceful shutdown
            let startTime = Date()
            while process.isRunning && Date().timeIntervalSince(startTime) < 2.0 {
                usleep(100_000) // 100ms
            }

            // If still running, force kill
            if process.isRunning {
                NSLog("[N64MupenAdapter] Force killing mupen64plus (PID: %d)", process.processIdentifier)
                kill(process.processIdentifier, SIGKILL)
                process.waitUntilExit()
            }

            mupenProcess = nil
            NSLog("[N64MupenAdapter] ✅ mupen64plus process terminated")
        }

        // Also kill any orphaned mupen64plus processes
        let killOrphanedProcesses = Process()
        killOrphanedProcesses.executableURL = URL(fileURLWithPath: "/usr/bin/pkill")
        killOrphanedProcesses.arguments = ["-f", "mupen64plus"]

        do {
            try killOrphanedProcesses.run()
            killOrphanedProcesses.waitUntilExit()
            NSLog("[N64MupenAdapter] Cleaned up any orphaned mupen64plus processes")
        } catch {
            NSLog("[N64MupenAdapter] Warning: Could not clean orphaned processes: %@", error.localizedDescription)
        }

        stateSubject.send(.stopped)
    }
    public func pause() async {
        // Actually suspend the mupen64plus process
        if let process = mupenProcess, process.isRunning {
            kill(process.processIdentifier, SIGSTOP)
            NSLog("[N64MupenAdapter] ⏸️ Process suspended (PID: %d)", process.processIdentifier)
        }
        stateSubject.send(.paused)
    }

    public func resume() async throws {
        // Actually resume the mupen64plus process
        if let process = mupenProcess, process.isRunning {
            kill(process.processIdentifier, SIGCONT)
            NSLog("[N64MupenAdapter] ▶️ Process resumed (PID: %d)", process.processIdentifier)
        }
        stateSubject.send(.running)
    }
    public func reset() async throws { stateSubject.send(.initialized) }
    public func step() async throws { try await runFrame() }

    public func createSaveState() async throws -> Data { Data() }
    public func loadSaveState(data: Data) async throws {}
    public func quickSave(slot: Int) async throws {}
    public func quickLoad(slot: Int) async throws {}

    private func loadCore() throws {
        if coreHandle != nil { return }

        // Common search locations
        let home = FileManager.default.homeDirectoryForCurrentUser.path
        var candidates: [String] = [
            "\(home)/NintendoEmulator/build/mupen64/lib/libmupen64plus.dylib",
            "/usr/local/lib/libmupen64plus.dylib",
            "/opt/homebrew/lib/libmupen64plus.dylib",
        ]
        if let fw = Bundle.main.privateFrameworksPath {
            candidates.append("\(fw)/libmupen64plus.dylib")
            candidates.append("\(fw)/Cores/libmupen64plus.dylib")
        }
        let bundleURL = Bundle.main.bundleURL
        candidates.append(bundleURL.appendingPathComponent("Contents/Frameworks/libmupen64plus.dylib").path)
        candidates.append(bundleURL.appendingPathComponent("Contents/Frameworks/Cores/libmupen64plus.dylib").path)
        candidates.append(bundleURL.appendingPathComponent("Contents/Resources/Cores/libmupen64plus.dylib").path)

        var handle: UnsafeMutableRawPointer?
        for path in candidates {
            handle = dlopen(path, RTLD_NOW | RTLD_LOCAL)
            if handle != nil { logger.info("Loaded core: \(path)"); break }
        }

        guard let h = handle else {
            logger.error("mupen64plus core not found. Build via Scripts/build_n64_core.sh")
            throw EmulatorError.coreNotFound(.n64)
        }

        coreHandle = h
        CoreStartup = unsafeBitCast(dlsym(h, "CoreStartup"), to: CoreStartupFn?.self)
        CoreShutdown = unsafeBitCast(dlsym(h, "CoreShutdown"), to: CoreShutdownFn?.self)
        CoreDoCommand = unsafeBitCast(dlsym(h, "CoreDoCommand"), to: CoreDoCommandFn?.self)
        CoreAttachPlugin = unsafeBitCast(dlsym(h, "CoreAttachPlugin"), to: CoreAttachPluginFn?.self)
        // Try both common symbol names
        if let sym = dlsym(h, "CoreVideo_SetVidExtFunctions") {
            CoreVideo_SetVidExt = unsafeBitCast(sym, to: CoreVideoSetVidExtFn?.self)
        } else if let sym2 = dlsym(h, "CoreVideo_SetVidExt") {
            CoreVideo_SetVidExt = unsafeBitCast(sym2, to: CoreVideoSetVidExtFn?.self)
        }
        CoreDetachPlugin = unsafeBitCast(dlsym(h, "CoreDetachPlugin"), to: CoreDetachPluginFn?.self)

        guard CoreStartup != nil, CoreShutdown != nil, CoreDoCommand != nil else {
            logger.error("Failed to resolve core symbols")
            throw EmulatorError.initializationFailed("mupen64plus symbols not found")
        }

        // Initialize the core with proper data directory path
        let dataDir = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("NintendoEmulator/build/mupen64/share/mupen64plus").path
        var errPtr: UnsafeMutablePointer<Int8>? = nil
        let rc = dataDir.withCString { dataDirPtr in
            return CoreStartup!(0x020001, nil, dataDirPtr, nil, nil, &errPtr)
        }
        if rc != 0 {
            let msg = errPtr.flatMap { String(cString: $0) } ?? "unknown"
            logger.error("CoreStartup failed: \(msg)")
            throw EmulatorError.initializationFailed("CoreStartup failed: \(msg)")
        }

        // Register video extension callbacks
        if let CoreVideo_SetVidExt = CoreVideo_SetVidExt {
            if let funcs = VidExt_GetFunctionTable() {
                let rc2 = CoreVideo_SetVidExt(funcs)
                if rc2 != 0 { logger.warning("CoreVideo_SetVidExtFunctions rc=\(rc2)") }
            }
        }
    }

    private func attachAvailablePlugins() throws {
        guard let CoreAttachPlugin = CoreAttachPlugin else { return }
        // Discover plugin dylibs
        let searchDirs: [String] = {
            var dirs: [String] = []
            if let fw = Bundle.main.privateFrameworksPath { dirs.append(fw) ; dirs.append("\(fw)/Cores") }
            let app = Bundle.main.bundleURL
            dirs.append(app.appendingPathComponent("Contents/Frameworks").path)
            dirs.append(app.appendingPathComponent("Contents/Frameworks/Cores").path)
            dirs.append(app.appendingPathComponent("Contents/Resources/Cores").path)
            dirs.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("NintendoEmulator/build/mupen64/lib").path)
            dirs.append(FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("NintendoEmulator/build/mupen64/lib/mupen64plus").path)
            return dirs
        }()

        func find(_ pattern: String) -> String? {
            for dir in searchDirs {
                let path = (dir as NSString).appendingPathComponent(pattern)
                if FileManager.default.fileExists(atPath: path) { return path }
            }
            return nil
        }

        // Try preferred GFX plugins in order; fall back to Rice if available
        let gfx = find("mupen64plus-video-GLideN64.dylib")
            ?? find("mupen64plus-video-glide64mk2.dylib")
            ?? find("mupen64plus-video-rice.dylib")
        let rsp = find("mupen64plus-rsp-hle.dylib")
        let audio = find("mupen64plus-audio-sdl.dylib")
        let input = find("mupen64plus-input-sdl.dylib")

        func attach(_ type: Int32, path: String?) {
            guard let path else { return }
            if let handle = dlopen(path, RTLD_NOW | RTLD_LOCAL) {
                let rc = CoreAttachPlugin(type, handle)
                if rc != 0 { logger.error("Attach plugin failed for \(path): rc=\(rc)") }
                else { logger.info("Attached plugin: \(path)") }
            } else {
                logger.error("dlopen failed for \(path)")
            }
        }

        attach(N64MupenAdapter.M64PLUGIN_RSP, path: rsp)
        attach(N64MupenAdapter.M64PLUGIN_AUDIO, path: audio)
        attach(N64MupenAdapter.M64PLUGIN_INPUT, path: input)
        attach(N64MupenAdapter.M64PLUGIN_GFX, path: gfx)
    }
}


extension N64MupenAdapter: @unchecked Sendable {}

// MARK: - EmulatorInputProtocol Implementation

extension N64MupenAdapter: EmulatorInputProtocol {
    public func setButtonState(player: Int, button: EmulatorButton, pressed: Bool) {
        NSLog("[N64MupenAdapter] Button \(button) \(pressed ? "pressed" : "released") for player \(player)")

        // Use direct memory injection callback if available
        if let callback = inputInjectionCallback {
            callback(button, pressed)
        } else {
            NSLog("[N64MupenAdapter] ⚠️ No input injection callback registered")
        }
    }

    public func setAnalogState(player: Int, stick: AnalogStick, x: Float, y: Float) {
        NSLog("[N64MupenAdapter] Analog stick \(stick): (\(x), \(y)) for player \(player)")

        // Use direct memory injection callback if available
        if let callback = analogInjectionCallback {
            callback(x, y)
        } else {
            NSLog("[N64MupenAdapter] ⚠️ No analog injection callback registered")
        }
    }

    public func setTriggerState(player: Int, trigger: Trigger, value: Float) {
        // N64 has Z button (digital) and L/R triggers
        // Map trigger to Z button if > 0.5
        if value > 0.5 {
            setButtonState(player: player, button: .zl, pressed: true)
        } else {
            setButtonState(player: player, button: .zl, pressed: false)
        }
    }

    public func rumble(player: Int, intensity: Float, duration: TimeInterval) {
        // Rumble pak support (optional - TODO)
        NSLog("[N64MupenAdapter] Rumble: \(intensity) for \(duration)s")
    }

    public func setTouchState(x: Int, y: Int, pressed: Bool) {
        // N64 has no touch screen
    }

    public func setAccelerometer(x: Float, y: Float, z: Float) {
        // N64 has no accelerometer
    }

    public func setGyroscope(pitch: Float, roll: Float, yaw: Float) {
        // N64 has no gyroscope
    }

    public func getInputState(player: Int) -> InputState {
        // Return empty state - input is handled by mupen64plus SDL plugin
        return InputState()
    }
}
