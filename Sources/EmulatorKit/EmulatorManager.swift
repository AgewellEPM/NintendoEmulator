import Foundation
import Combine
import CoreInterface
import os.log
import Foundation

/// Main orchestration manager for emulator cores
@MainActor
public final class EmulatorManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var currentCore: EmulatorCoreProtocol?
    @Published public private(set) var currentSystem: EmulatorSystem?
    @Published public private(set) var isRunning = false
    @Published public private(set) var isPaused = false
    @Published public private(set) var currentROM: ROMMetadata?
    @Published public private(set) var performance = PerformanceMetrics(
        fps: 0, frameTime: 0, cpuUsage: 0, memoryUsage: 0,
        audioLatency: 0, inputLatency: 0
    )
    @Published public private(set) var lastError: EmulatorError?

    // MARK: - Core Management

    private let coreRegistry: CoreRegistry
    private let executionController: ExecutionController
    public let stateManager: StateManager
    private let performanceMonitor: PerformanceMonitor

    // MARK: - Combine

    private var cancellables = Set<AnyCancellable>()
    private let logger = Logger(subsystem: "com.emulator", category: "EmulatorManager")

    // MARK: - Publishers

    public let frameSubject = PassthroughSubject<FrameData, Never>()
    public let audioSubject = PassthroughSubject<AudioBuffer, Never>()
    public let stateSubject = PassthroughSubject<EmulatorState, Never>()

    public var framePublisher: AnyPublisher<FrameData, Never> {
        frameSubject.eraseToAnyPublisher()
    }

    public var audioPublisher: AnyPublisher<AudioBuffer, Never> {
        audioSubject.eraseToAnyPublisher()
    }

    // MARK: - Initialization

    public init() {
        self.coreRegistry = CoreRegistry()
        self.executionController = ExecutionController()
        self.stateManager = StateManager()
        self.performanceMonitor = PerformanceMonitor()

        setupBindings()
        logger.info("EmulatorManager initialized")
    }

    // MARK: - Public API

    /// Load an emulator core for the specified system
    public func loadCore(for system: EmulatorSystem) async throws {
        logger.info("Loading core for system: \(system.rawValue)")
        NSLog("[EmulatorManager] loadCore(for: %@)", system.rawValue)

        // Clean up existing core
        if let currentCore = currentCore {
            await currentCore.shutdown()
            self.currentCore = nil
        }

        // Get core class from registry
        guard let coreClass = coreRegistry.coreClass(for: system) else {
            let error = EmulatorError.coreNotFound(system)
            self.lastError = error
            throw error
        }

        // Initialize new core
        let core = try coreClass.init()

        let configuration = makeConfiguration(for: system)
        try await core.initialize(configuration: configuration)

        // Set up core publishers
        setupCorePublishers(core)

        self.currentCore = core
        self.currentSystem = system

        stateSubject.send(.initialized)
        logger.info("Core loaded successfully for \(system.rawValue)")
        NSLog("[EmulatorManager] Core loaded: %@", String(describing: coreClass))
    }

    /// Load a ROM file
    public func loadROM(at url: URL) async throws {
        guard let core = currentCore else {
            let error = EmulatorError.noCoreLoaded
            self.lastError = error
            throw error
        }

        logger.info("Loading ROM from: \(url.path)")
        NSLog("[EmulatorManager] loadROM at %@", url.path)

        // Use EnhancedROMLoader for robust preprocessing (byte swap, headers)
        let loader = EnhancedROMLoader()
        let loaded = try await loader.loadROM(from: url)
        let data = loaded.data
        let metadata = loaded.metadata

        // Validate ROM with core
        let validation = core.validateROM(data: data)
        guard validation.isValid else {
            let error = EmulatorError.invalidROM(validation.errors.joined(separator: ", "))
            self.lastError = error
            throw error
        }

        try await core.loadROM(data: data, metadata: metadata)
        self.currentROM = metadata

        stateSubject.send(.romLoaded)
        logger.info("ROM loaded: \(metadata.title)")
        NSLog("[EmulatorManager] ROM loaded: %@ (%@)", metadata.title, metadata.system.displayName)
    }

    /// Universal open: detect system, load matching core, then load ROM.
    public func openROM(at url: URL) async throws {
        NSLog("[EmulatorManager] openROM at %@", url.path)
        // Prefer robust loader for detection and byte-swapping
        let loader = EnhancedROMLoader()
        let loaded = try await loader.loadROM(from: url)
        NSLog("[EmulatorManager] Detected system: %@", loaded.metadata.system.displayName)
        try await loadCore(for: loaded.metadata.system)
        guard let core = currentCore else { throw EmulatorError.noCoreLoaded }
        try await core.loadROM(data: loaded.data, metadata: loaded.metadata)
        self.currentROM = loaded.metadata
        NSLog("[EmulatorManager] openROM done")
    }

    /// Start emulation
    public func start() async throws {
        guard let core = currentCore else {
            let error = EmulatorError.noCoreLoaded
            self.lastError = error
            throw error
        }

        guard currentROM != nil else {
            let error = EmulatorError.romLoadFailed("No ROM loaded")
            self.lastError = error
            throw error
        }

        logger.info("Starting emulation")
        NSLog("[EmulatorManager] start()")

        isRunning = true
        isPaused = false

        // Ensure core is started if it requires internal execution (e.g., Mupen)
        do {
            NSLog("[EmulatorManager] Calling core.start()")
            try await core.start()
        } catch {
            self.lastError = .executionError("core.start failed: \(error)")
            NSLog("[EmulatorManager] core.start failed: %@", String(describing: error))
            throw error
        }

        // Start execution loop on a background task to avoid blocking the main actor/UI
        Task {
            try await executionController.start(core: core) { [weak self] in
                self?.frameSubject.send($0)
            }
        }

        performanceMonitor.startMonitoring()
        stateSubject.send(.running)
    }

    /// Pause emulation
    public func pause() async {
        guard isRunning else { return }

        logger.info("Pausing emulation")
        NSLog("[EmulatorManager] pause()")

        await executionController.pause()
        isPaused = true
        stateSubject.send(.paused)
    }

    /// Resume emulation
    public func resume() async throws {
        guard isPaused else { return }

        logger.info("Resuming emulation")
        NSLog("[EmulatorManager] resume()")

        try await executionController.resume()
        isPaused = false
        stateSubject.send(.running)
    }

    /// Stop emulation
    public func stop() async {
        logger.info("Stopping emulation")
        NSLog("[EmulatorManager] stop()")

        await executionController.stop()
        performanceMonitor.stopMonitoring()

        isRunning = false
        isPaused = false
        stateSubject.send(.stopped)
    }

    /// Reset the emulator
    public func reset() async throws {
        guard let core = currentCore else {
            let error = EmulatorError.noCoreLoaded
            self.lastError = error
            throw error
        }

        logger.info("Resetting emulator")

        try await core.reset()
        stateSubject.send(.initialized)
    }

    // MARK: - Save States

    /// Create a save state
    public func createSaveState() async throws -> Data {
        guard let core = currentCore else {
            throw EmulatorError.executionError("No core loaded")
        }

        return try await core.createSaveState()
    }

    /// Load a save state
    public func loadSaveState(data: Data) async throws {
        guard let core = currentCore else {
            throw EmulatorError.executionError("No core loaded")
        }

        try await core.loadSaveState(data: data)
    }

    /// Quick save to slot
    public func quickSave(slot: Int = 0) async throws {
        guard let core = currentCore else {
            throw EmulatorError.executionError("No core loaded")
        }

        try await core.quickSave(slot: slot)
        logger.info("Quick saved to slot \(slot)")
    }

    /// Quick load from slot
    public func quickLoad(slot: Int = 0) async throws {
        guard let core = currentCore else {
            throw EmulatorError.executionError("No core loaded")
        }

        try await core.quickLoad(slot: slot)
        logger.info("Quick loaded from slot \(slot)")
    }

    /// Save state to specific slot
    public func saveState(slot: Int) async throws {
        guard let core = currentCore else {
            throw EmulatorError.executionError("No core loaded")
        }

        try await core.quickSave(slot: slot)
        logger.info("Saved state to slot \(slot)")
    }

    /// Load state from URL
    public func loadState(from url: URL) async throws {
        guard let core = currentCore else {
            throw EmulatorError.executionError("No core loaded")
        }

        let data = try await stateManager.loadState(from: url)
        try await core.loadSaveState(data: data)
        logger.info("Loaded state from: \(url.lastPathComponent)")
    }

    /// Load state from specific slot
    public func loadState(slot: Int) async throws {
        guard let core = currentCore else {
            throw EmulatorError.executionError("No core loaded")
        }

        try await core.quickLoad(slot: slot)
        logger.info("Loaded state from slot \(slot)")
    }

    // MARK: - Private Methods

    private func setupBindings() {
        // Monitor performance metrics
        performanceMonitor.metricsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$performance)
    }

    private func setupCorePublishers(_ core: EmulatorCoreProtocol) {
        // Forward frame data
        core.framePublisher
            .sink { [weak self] frame in
                self?.frameSubject.send(frame)
            }
            .store(in: &cancellables)

        // Forward audio data
        core.audioPublisher
            .sink { [weak self] audio in
                self?.audioSubject.send(audio)
            }
            .store(in: &cancellables)

        // Forward state changes
        core.statePublisher
            .sink { [weak self] state in
                self?.stateSubject.send(state)
            }
            .store(in: &cancellables)

        // Forward performance metrics
        core.metricsPublisher
            .receive(on: DispatchQueue.main)
            .assign(to: &$performance)
    }

    private func makeConfiguration(for system: EmulatorSystem) -> DefaultEmulatorConfiguration {
        var config = DefaultEmulatorConfiguration()

        // System-specific configurations
        switch system {
        case .n64:
            config.cpuClockRate = 93_750_000 // 93.75 MHz
            config.memoryLimit = 8 * 1024 * 1024 // 8MB RAM (4MB + expansion)

        case .gamecube:
            config.cpuClockRate = 486_000_000 // 486 MHz
            config.memoryLimit = 43 * 1024 * 1024 // 43MB total

        case .nes:
            config.cpuClockRate = 1_789_773 // 1.79 MHz
            config.memoryLimit = 2 * 1024 // 2KB RAM

        case .snes:
            config.cpuClockRate = 3_580_000 // 3.58 MHz
            config.memoryLimit = 128 * 1024 // 128KB RAM

        default:
            break
        }

        return config
    }
}

// MARK: - Input Forwarding

extension EmulatorManager: EmulatorInputProtocol {
    nonisolated public func setButtonState(player: Int, button: EmulatorButton, pressed: Bool) {
        Task { @MainActor [weak self] in
            (self?.currentCore as? EmulatorInputProtocol)?.setButtonState(
                player: player, button: button, pressed: pressed
            )
        }
    }

    nonisolated public func setAnalogState(player: Int, stick: AnalogStick, x: Float, y: Float) {
        Task { @MainActor [weak self] in
            (self?.currentCore as? EmulatorInputProtocol)?.setAnalogState(
                player: player, stick: stick, x: x, y: y
            )
        }
    }

    nonisolated public func setTriggerState(player: Int, trigger: Trigger, value: Float) {
        Task { @MainActor [weak self] in
            (self?.currentCore as? EmulatorInputProtocol)?.setTriggerState(
                player: player, trigger: trigger, value: value
            )
        }
    }

    nonisolated public func rumble(player: Int, intensity: Float, duration: TimeInterval) {
        Task { @MainActor [weak self] in
            (self?.currentCore as? EmulatorInputProtocol)?.rumble(
                player: player, intensity: intensity, duration: duration
            )
        }
    }

    nonisolated public func setTouchState(x: Int, y: Int, pressed: Bool) {
        Task { @MainActor [weak self] in
            (self?.currentCore as? EmulatorInputProtocol)?.setTouchState(x: x, y: y, pressed: pressed)
        }
    }

    nonisolated public func setAccelerometer(x: Float, y: Float, z: Float) {
        Task { @MainActor [weak self] in
            (self?.currentCore as? EmulatorInputProtocol)?.setAccelerometer(x: x, y: y, z: z)
        }
    }

    nonisolated public func setGyroscope(pitch: Float, roll: Float, yaw: Float) {
        Task { @MainActor [weak self] in
            (self?.currentCore as? EmulatorInputProtocol)?.setGyroscope(pitch: pitch, roll: roll, yaw: yaw)
        }
    }

    nonisolated public func getInputState(player: Int) -> InputState {
        // Provide a best-effort default; actual core state is queried on the main actor elsewhere.
        InputState()
    }
}
