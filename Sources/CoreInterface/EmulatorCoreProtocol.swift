import Foundation
import Combine
import CoreGraphics

/// Primary protocol that all emulator cores must implement
public protocol EmulatorCoreProtocol: AnyObject {

    // MARK: - Initialization

    /// Initialize the core - must be implemented by conforming types
    init() throws

    // MARK: - Core Information

    /// Unique identifier for this core
    var coreIdentifier: String { get }

    /// Version string for the core
    var coreVersion: String { get }

    /// Systems this core can emulate
    var supportedSystems: [EmulatorSystem] { get }

    /// Current state of the emulator
    var currentState: EmulatorState { get }

    /// Currently loaded ROM metadata
    var loadedROM: ROMMetadata? { get }

    // MARK: - Lifecycle Management

    /// Initialize the core with configuration
    func initialize(configuration: EmulatorConfiguration) async throws

    /// Shutdown and cleanup resources
    func shutdown() async

    /// Reset the emulator to initial state
    func reset() async throws

    // MARK: - ROM Management

    /// Load a ROM file
    func loadROM(data: Data, metadata: ROMMetadata) async throws

    /// Unload the current ROM
    func unloadROM() async

    /// Validate if ROM data is valid for this core
    func validateROM(data: Data) -> ROMValidationResult

    // MARK: - Execution Control

    /// Run a single frame
    func runFrame() async throws

    /// Start continuous execution
    func start() async throws

    /// Pause execution
    func pause() async

    /// Resume from pause
    func resume() async throws

    /// Step through one instruction (for debugging)
    func step() async throws

    // MARK: - State Management

    /// Create a save state
    func createSaveState() async throws -> Data

    /// Load a save state
    func loadSaveState(data: Data) async throws

    /// Quick save to slot
    func quickSave(slot: Int) async throws

    /// Quick load from slot
    func quickLoad(slot: Int) async throws

    // MARK: - Publishers

    /// Publisher for video frames
    var framePublisher: AnyPublisher<FrameData, Never> { get }

    /// Publisher for audio buffers
    var audioPublisher: AnyPublisher<AudioBuffer, Never> { get }

    /// Publisher for state changes
    var statePublisher: AnyPublisher<EmulatorState, Never> { get }

    /// Publisher for performance metrics
    var metricsPublisher: AnyPublisher<PerformanceMetrics, Never> { get }
}

// MARK: - Configuration Protocol

public protocol EmulatorConfiguration {
    /// CPU clock rate override (0 = default)
    var cpuClockRate: Int { get set }

    /// Enable audio synchronization
    var enableAudioSync: Bool { get set }

    /// Frame skip setting (0 = no skip)
    var frameskip: Int { get set }

    /// Render scale multiplier
    var renderScale: Float { get set }

    /// Enable JIT compilation if available
    var enableJIT: Bool { get set }

    /// Memory limit in bytes
    var memoryLimit: Int { get set }

    /// Thread count for parallel execution
    var threadCount: Int { get set }
}

// MARK: - Default Configuration

public struct DefaultEmulatorConfiguration: EmulatorConfiguration {
    public var cpuClockRate: Int = 0
    public var enableAudioSync: Bool = true
    public var frameskip: Int = 0
    public var renderScale: Float = 1.0
    public var enableJIT: Bool = true
    public var memoryLimit: Int = 512 * 1024 * 1024 // 512MB
    public var threadCount: Int = ProcessInfo.processInfo.processorCount

    public init() {}
}

// MARK: - Performance Metrics

public struct PerformanceMetrics: Codable {
    public let fps: Double
    public let frameTime: TimeInterval
    public let cpuUsage: Double
    public let memoryUsage: Int64
    public let audioLatency: TimeInterval
    public let inputLatency: TimeInterval

    public init(fps: Double, frameTime: TimeInterval, cpuUsage: Double,
                memoryUsage: Int64, audioLatency: TimeInterval, inputLatency: TimeInterval) {
        self.fps = fps
        self.frameTime = frameTime
        self.cpuUsage = cpuUsage
        self.memoryUsage = memoryUsage
        self.audioLatency = audioLatency
        self.inputLatency = inputLatency
    }
}

// MARK: - Memory Access Protocol

public protocol EmulatorMemoryProtocol {
    /// Read memory at address
    func readMemory(address: UInt32, size: Int) -> Data

    /// Write memory at address
    func writeMemory(address: UInt32, data: Data) throws

    /// Get memory map information
    func getMemoryMap() -> [MemoryRegion]

    /// Search for pattern in memory
    func searchMemory(pattern: Data, range: Range<UInt32>?) -> [UInt32]
}

// MARK: - Debug Protocol

public protocol EmulatorDebugProtocol {
    /// Set a breakpoint at address
    func setBreakpoint(address: UInt32)

    /// Remove a breakpoint
    func removeBreakpoint(address: UInt32)

    /// Get all breakpoints
    func getBreakpoints() -> [UInt32]

    /// Get CPU registers
    func getRegisters() -> [String: Any]

    /// Set CPU register value
    func setRegister(name: String, value: Any) throws

    /// Disassemble instructions
    func disassemble(address: UInt32, count: Int) -> [DisassemblyLine]

    /// Get call stack
    func getCallStack() -> [UInt32]

    /// Enable/disable instruction tracing
    func setTracing(enabled: Bool)
}

// MARK: - Rendering Protocol

public protocol EmulatorRenderingProtocol {
    /// Current frame dimensions
    var frameSize: CGSize { get }

    /// Native pixel format
    var pixelFormat: FrameData.PixelFormat { get }

    /// Direct framebuffer access
    var framebuffer: UnsafeMutableRawPointer? { get }

    /// Prepare for frame rendering
    func prepareFrame()

    /// Present completed frame
    func presentFrame()

    /// Set render scale
    func setRenderScale(scale: Float)

    /// Enable post-processing effects
    func setPostProcessingEffects(_ effects: [PostProcessEffect])

    /// Take a screenshot
    func captureScreenshot() -> Data?
}

// MARK: - Audio Protocol

public protocol EmulatorAudioProtocol {
    /// Audio sample rate
    var sampleRate: Int { get }

    /// Number of audio channels
    var channelCount: Int { get }

    /// Audio buffer size in frames
    var bufferSize: Int { get }

    /// Get audio buffer pointer
    func getAudioBuffer() -> UnsafeMutablePointer<Float>?

    /// Submit audio samples
    func submitAudioSamples(count: Int)

    /// Set master volume
    func setVolume(_ volume: Float)

    /// Set channel volume
    func setChannelVolume(channel: Int, volume: Float)

    /// Enable audio effects
    func setAudioEffects(_ effects: [AudioEffect])

    /// Mute/unmute
    func setMuted(_ muted: Bool)
}

// MARK: - Input Protocol

public protocol EmulatorInputProtocol {
    /// Set button state
    func setButtonState(player: Int, button: EmulatorButton, pressed: Bool)

    /// Set analog stick position
    func setAnalogState(player: Int, stick: AnalogStick, x: Float, y: Float)

    /// Set trigger pressure
    func setTriggerState(player: Int, trigger: Trigger, value: Float)

    /// Trigger rumble/haptic feedback
    func rumble(player: Int, intensity: Float, duration: TimeInterval)

    /// Set touch input (for DS/3DS)
    func setTouchState(x: Int, y: Int, pressed: Bool)

    /// Set accelerometer data (for Wii/Switch)
    func setAccelerometer(x: Float, y: Float, z: Float)

    /// Set gyroscope data
    func setGyroscope(pitch: Float, roll: Float, yaw: Float)

    /// Get current input state
    func getInputState(player: Int) -> InputState
}

// MARK: - Input State

public struct InputState: Codable {
    public let buttons: Set<EmulatorButton>
    public let leftStick: CGPoint
    public let rightStick: CGPoint
    public let leftTrigger: Float
    public let rightTrigger: Float
    public let touchPosition: CGPoint?
    public let accelerometer: SIMD3<Float>?
    public let gyroscope: SIMD3<Float>?

    public init(buttons: Set<EmulatorButton> = [], leftStick: CGPoint = .zero,
                rightStick: CGPoint = .zero, leftTrigger: Float = 0,
                rightTrigger: Float = 0, touchPosition: CGPoint? = nil,
                accelerometer: SIMD3<Float>? = nil, gyroscope: SIMD3<Float>? = nil) {
        self.buttons = buttons
        self.leftStick = leftStick
        self.rightStick = rightStick
        self.leftTrigger = leftTrigger
        self.rightTrigger = rightTrigger
        self.touchPosition = touchPosition
        self.accelerometer = accelerometer
        self.gyroscope = gyroscope
    }
}