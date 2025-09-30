import Foundation
import CoreInterface
import RenderingEngine
import EmulatorKit
import Combine
import os.log

@objcMembers
public final class N64Core: NSObject, EmulatorCoreProtocol {

    // MARK: - Properties

    public let coreIdentifier = "com.emulator.n64"
    public let coreVersion = "1.0.0"
    public let supportedSystems: [EmulatorSystem] = [.n64]

    private let logger = Logger(subsystem: "com.emulator", category: "N64Core")

    // Core state
    private var cpu: N64CPU
    private var memory: N64Memory
    private var rsp: N64RSP
    private var rdp: N64RDP
    private var cartridge: N64Cartridge?
    private var controllerBridge: N64ControllerBridge?

    // Execution state
    private var isRunning = false
    private var frameCount = 0
    private var cycleCount: UInt64 = 0

    // Publishers
    private let frameSubject = PassthroughSubject<FrameData, Never>()
    private let audioSubject = PassthroughSubject<AudioBuffer, Never>()
    private let stateSubject = CurrentValueSubject<EmulatorState, Never>(.uninitialized)
    private let metricsSubject = PassthroughSubject<PerformanceMetrics, Never>()

    public var framePublisher: AnyPublisher<FrameData, Never> {
        frameSubject.eraseToAnyPublisher()
    }

    public var audioPublisher: AnyPublisher<AudioBuffer, Never> {
        audioSubject.eraseToAnyPublisher()
    }

    public var statePublisher: AnyPublisher<EmulatorState, Never> {
        stateSubject.eraseToAnyPublisher()
    }

    public var metricsPublisher: AnyPublisher<PerformanceMetrics, Never> {
        metricsSubject.eraseToAnyPublisher()
    }

    public var currentState: EmulatorState {
        stateSubject.value
    }

    public private(set) var loadedROM: ROMMetadata?

    // MARK: - Initialization

    public override init() {
        // Initialize core components
        self.memory = N64Memory()
        self.cpu = N64CPU(memory: memory)
        self.rsp = N64RSP(memory: memory)
        self.rdp = N64RDP(memory: memory)
        super.init()
        logger.info("N64 Core initialized")
        stateSubject.send(.initialized)
    }

    // MARK: - EmulatorCoreProtocol Lifecycle

    public func initialize(configuration: EmulatorConfiguration) async throws {
        // Apply basic configuration if needed
        // For now, no-op; components are initialized in init()
        // Initialize controller bridge on main actor
        await MainActor.run {
            self.controllerBridge = N64ControllerBridge()
        }
        stateSubject.send(.initialized)
    }

    public func shutdown() async {
        isRunning = false
        loadedROM = nil
        stateSubject.send(.uninitialized)
    }

    // MARK: - ROM Management

    public func loadROM(data: Data, metadata: ROMMetadata) async throws {
        logger.info("Loading N64 ROM: \(metadata.title)")

        // Validate ROM format
        let validation = validateROM(data: data)
        guard validation.isValid else {
            throw EmulatorError.romLoadFailed("Invalid ROM: \(validation.errors.joined(separator: ", "))")
        }

        // Create cartridge
        cartridge = try N64Cartridge(romData: data, metadata: metadata)

        // Map cartridge to memory
        memory.mapCartridge(cartridge!)

        // Reset CPU state
        cpu.reset()

        self.loadedROM = metadata
        stateSubject.send(.romLoaded)

        logger.info("N64 ROM loaded successfully")
    }

    public func validateROM(data: Data) -> ROMValidationResult {
        guard data.count >= 0x40 else {
            return ROMValidationResult(isValid: false, errors: ["ROM too small for N64"])
        }

        // Check N64 magic bytes
        let header = Array(data.prefix(4))
        let validHeaders: [[UInt8]] = [
            [0x80, 0x37, 0x12, 0x40], // Big endian
            [0x37, 0x80, 0x40, 0x12], // Little endian
            [0x40, 0x12, 0x37, 0x80], // Byte swapped
        ]

        if validHeaders.contains(header) {
            return ROMValidationResult(isValid: true, system: .n64)
        }

        return ROMValidationResult(isValid: false, errors: ["Invalid N64 magic bytes"])
    }

    public func unloadROM() async {
        cartridge = nil
        memory.unmapCartridge()
        cpu.reset()
        loadedROM = nil
        stateSubject.send(.initialized)
    }

    // MARK: - Execution Control

    public func runFrame() async throws {
        guard cartridge != nil else {
            throw EmulatorError.noCoreLoaded
        }

        let cyclesPerFrame = 1562500 // ~93.75MHz / 60Hz
        var frameCycles = 0

        while frameCycles < cyclesPerFrame && isRunning {
            // Execute CPU instruction
            let cycles = cpu.executeInstruction()
            frameCycles += cycles
            cycleCount += UInt64(cycles)

            // Update RSP if needed
            if rsp.needsUpdate {
                rsp.executeFrame()
            }

            // Update RDP for graphics
            if rdp.needsUpdate {
                rdp.processCommands()
            }

            // Handle interrupts
            handleInterrupts()
        }

        // Generate frame data
        await generateFrame()

        frameCount += 1
    }

    public func start() async throws {
        guard cartridge != nil else {
            throw EmulatorError.noCoreLoaded
        }

        isRunning = true
        stateSubject.send(.running)
        logger.info("N64 emulation started")
    }

    public func pause() async {
        isRunning = false
        stateSubject.send(.paused)
        logger.info("N64 emulation paused")
    }

    public func resume() async throws {
        isRunning = true
        stateSubject.send(.running)
        logger.info("N64 emulation resumed")
    }

    public func reset() async throws {
        cpu.reset()
        rsp.reset()
        rdp.reset()
        memory.reset()
        frameCount = 0
        cycleCount = 0

        stateSubject.send(.initialized)
        logger.info("N64 core reset")
    }

    public func step() async throws {
        try await runFrame()
    }

    // MARK: - Save States

    public func createSaveState() async throws -> Data {
        let state = N64SaveState(
            cpu: cpu.getState(),
            memory: memory.getState(),
            rsp: rsp.getState(),
            rdp: rdp.getState(),
            frameCount: frameCount,
            cycleCount: cycleCount
        )

        return try JSONEncoder().encode(state)
    }

    public func loadSaveState(data: Data) async throws {
        let state = try JSONDecoder().decode(N64SaveState.self, from: data)

        cpu.setState(state.cpu)
        memory.setState(state.memory)
        rsp.setState(state.rsp)
        rdp.setState(state.rdp)
        frameCount = state.frameCount
        cycleCount = state.cycleCount

        logger.info("Save state loaded")
    }

    // Quick save/load slots (in-memory)
    private var quickSlots: [Int: Data] = [:]

    public func quickSave(slot: Int) async throws {
        let data = try await createSaveState()
        quickSlots[slot] = data
    }

    public func quickLoad(slot: Int) async throws {
        guard let data = quickSlots[slot] else { return }
        try await loadSaveState(data: data)
    }

    // MARK: - Private Methods

    private func handleInterrupts() {
        // Handle VI (Video Interface) interrupt for frame timing
        if cycleCount % 1562500 == 0 {
            cpu.setInterrupt(.vi)
        }

        // Handle SI (Serial Interface) interrupt for controller
        if cycleCount % 100000 == 0 {
            cpu.setInterrupt(.si)
        }
    }

    private func generateFrame() async {
        // Get framebuffer from RDP
        let framebuffer = rdp.getFramebuffer()
        let frameSize = rdp.getFrameSize()

        let frameData = FrameData(
            pixelData: framebuffer,
            width: frameSize.width,
            height: frameSize.height,
            bytesPerRow: frameSize.width * 4,
            pixelFormat: .rgba8888,
            timestamp: Date().timeIntervalSince1970
        )

        frameSubject.send(frameData)

        // Generate audio if available
        if let audioBuffer = rdp.getAudioBuffer() {
            audioSubject.send(audioBuffer)
        }

        // Update performance metrics
        updateMetrics()
    }

    private func updateMetrics() {
        let actualFPS = Double(frameCount) // Simplified

        let metrics = PerformanceMetrics(
            fps: actualFPS,
            frameTime: 1.0 / actualFPS,
            cpuUsage: Double(cpu.getUsage()),
            memoryUsage: Int64(Double(memory.getUsage()) * Double(8 * 1024 * 1024)),
            audioLatency: 0.020,
            inputLatency: 0.008
        )

        metricsSubject.send(metrics)
    }
}

// MARK: - Input Protocol
extension N64Core: EmulatorInputProtocol {
    public func setButtonState(player: Int, button: EmulatorButton, pressed: Bool) {
        memory.setControllerButton(player: player, button: button, pressed: pressed)
    }

    public func setAnalogState(player: Int, stick: AnalogStick, x: Float, y: Float) {
        if stick == .left {
            memory.setControllerAnalog(player: player, x: x, y: y)
        }
    }

    public func setTriggerState(player: Int, trigger: Trigger, value: Float) {
        // N64 doesn't have analog triggers
    }

    public func rumble(player: Int, intensity: Float, duration: TimeInterval) {
        // TODO: Implement rumble pak support
    }

    public func setTouchState(x: Int, y: Int, pressed: Bool) {
        // N64 doesn't support touch
    }

    public func setAccelerometer(x: Float, y: Float, z: Float) {
        // N64 doesn't have accelerometer
    }

    public func setGyroscope(pitch: Float, roll: Float, yaw: Float) {
        // N64 doesn't have gyroscope
    }

    public func getInputState(player: Int) -> InputState {
        return memory.getControllerState(player: player)
    }
}

// MARK: - Supporting Types

public struct N64SaveState: Codable {
    let cpu: CPUState
    let memory: MemoryState
    let rsp: RSPState
    let rdp: RDPState
    let frameCount: Int
    let cycleCount: UInt64
}

public struct CPUState: Codable {
    let pc: UInt32
    let registers: [UInt64]
    let hi: UInt64
    let lo: UInt64
}

public struct MemoryState: Codable {
    let rdram: Data
    let cartridgeRam: Data?
}

public struct RSPState: Codable {
    let pc: UInt32
    let registers: [UInt32]
    let dmem: Data
    let imem: Data
}

public struct RDPState: Codable {
    let commands: [UInt32]
    let colorBuffer: Data
    let depthBuffer: Data
}
