import Foundation
import Combine
import CoreInterface

@objcMembers
public final class SNESCore: NSObject, EmulatorCoreProtocol {

    // MARK: - Core Info
    public let coreIdentifier = "com.emulator.snes"
    public let coreVersion = "0.1.0"
    public let supportedSystems: [EmulatorSystem] = [.snes]
    public private(set) var loadedROM: ROMMetadata?

    // MARK: - Publishers
    private let frameSubject = PassthroughSubject<FrameData, Never>()
    private let audioSubject = PassthroughSubject<AudioBuffer, Never>()
    private let stateSubject = CurrentValueSubject<EmulatorState, Never>(.uninitialized)
    private let metricsSubject = PassthroughSubject<PerformanceMetrics, Never>()

    public var framePublisher: AnyPublisher<FrameData, Never> { frameSubject.eraseToAnyPublisher() }
    public var audioPublisher: AnyPublisher<AudioBuffer, Never> { audioSubject.eraseToAnyPublisher() }
    public var statePublisher: AnyPublisher<EmulatorState, Never> { stateSubject.eraseToAnyPublisher() }
    public var metricsPublisher: AnyPublisher<PerformanceMetrics, Never> { metricsSubject.eraseToAnyPublisher() }
    public var currentState: EmulatorState { stateSubject.value }

    // MARK: - Lifecycle
    public override init() {
        super.init()
    }

    public func initialize(configuration: EmulatorConfiguration) async throws {
        stateSubject.send(.initialized)
    }

    public func shutdown() async {
        loadedROM = nil
        stateSubject.send(.uninitialized)
    }

    // MARK: - ROM Management
    public func loadROM(data: Data, metadata: ROMMetadata) async throws {
        loadedROM = metadata
        stateSubject.send(.romLoaded)
    }

    public func unloadROM() async {
        loadedROM = nil
        stateSubject.send(.initialized)
    }

    public func validateROM(data: Data) -> ROMValidationResult {
        ROMValidationResult(isValid: true, system: .snes)
    }

    // MARK: - Execution
    public func runFrame() async throws {
        // Placeholder: emit no-op metrics
        metricsSubject.send(PerformanceMetrics(
            fps: 60, frameTime: 1.0/60.0, cpuUsage: 0.1, memoryUsage: 0,
            audioLatency: 0, inputLatency: 0
        ))
    }

    public func start() async throws { stateSubject.send(.running) }
    public func pause() async { stateSubject.send(.paused) }
    public func resume() async throws { stateSubject.send(.running) }
    public func reset() async throws { stateSubject.send(.initialized) }
    public func step() async throws { try await runFrame() }

    // MARK: - Save States
    public func createSaveState() async throws -> Data { Data() }
    public func loadSaveState(data: Data) async throws {}
    public func quickSave(slot: Int) async throws {}
    public func quickLoad(slot: Int) async throws {}
}
