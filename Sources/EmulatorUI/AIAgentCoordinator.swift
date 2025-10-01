import Foundation
import CoreInterface
import InputSystem

/// Coordinates AI agent with emulator, memory reading, and controller injection
/// This is the main integration point that connects all AI components
@MainActor
public class AIAgentCoordinator: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var isActive = false
    @Published public private(set) var status: String = "Idle"
    @Published public private(set) var currentGame: String?
    @Published public var playerNumber: Int = 0  // 0=Player 1, 1=Player 2, etc.

    private var controllerInjector: ControllerInjector
    private var memoryReader: MemoryReader
    private var simpleAgent: SimpleAgent

    // Game-specific adapters
    private var sm64Adapter: SuperMario64Adapter?
    private var zeldaAdapter: ZeldaOOTAdapter?

    // Emulator connection
    private var emulatorPID: pid_t = 0
    private var controllerManager: ControllerManager

    // Direct memory input injection
    private var inputInjector: N64InputMemoryInjector?

    // MARK: - Initialization

    public init() {
        self.controllerInjector = ControllerInjector()
        self.memoryReader = MemoryReader()
        self.controllerManager = ControllerManager.shared
        self.simpleAgent = SimpleAgent(controller: controllerInjector, memory: memoryReader)
    }

    // MARK: - Connection

    /// Connect to running emulator
    public func connectToEmulator(pid: pid_t, gameName: String) -> Bool {
        print("🤖 [AIAgentCoordinator] Connecting to emulator PID: \(pid)")

        self.emulatorPID = pid
        self.currentGame = gameName

        // Configure memory reader for game
        memoryReader.configureForGame(gameName)

        // Connect to emulator memory
        guard memoryReader.connectToEmulator(pid: pid) else {
            print("⚠️ [AIAgentCoordinator] Failed to connect to emulator memory")
            status = "Failed to connect"
            return false
        }

        // Connect controller injector to ControllerManager
        controllerInjector.connect(controllerManager: controllerManager)

        // Setup direct memory input injection
        setupMemoryInputInjection(pid: pid)

        status = "Connected to \(gameName)"
        print("✅ [AIAgentCoordinator] Connected successfully")
        return true
    }

    /// Setup direct memory input injection (Expert mode - Option C)
    private func setupMemoryInputInjection(pid: pid_t) {
        print("🔧 [AIAgentCoordinator] Setting up direct memory input injection for Player \(playerNumber + 1)...")

        // Create memory injector for selected player
        guard let machVM = memoryReader.getMachVM() else {
            print("⚠️ [AIAgentCoordinator] Cannot get MachVM instance")
            return
        }

        let injector = N64InputMemoryInjector(memory: machVM, player: playerNumber)

        // Try to connect to controller state
        if injector.connect() {
            self.inputInjector = injector
            print("✅ [AIAgentCoordinator] Direct memory injection connected as Player \(playerNumber + 1)!")

            // Register callbacks with N64MupenAdapter
            // TODO: Need to get adapter instance
            // For now, hook up through controllerInjector

        } else {
            print("⚠️ [AIAgentCoordinator] Direct memory injection failed - falling back to SDL method")
        }
    }

    /// Change player number (must be done before connecting)
    public func setPlayerNumber(_ player: Int) {
        guard !isActive else {
            print("⚠️ [AIAgentCoordinator] Cannot change player while agent is active")
            return
        }

        playerNumber = min(max(player, 0), 3)  // Clamp to 0-3
        print("🎮 [AIAgentCoordinator] Player set to \(playerNumber + 1)")
    }

    /// Disconnect from emulator
    public func disconnect() {
        stopAgent()
        controllerInjector.disconnect()
        memoryReader.disconnect()
        emulatorPID = 0
        currentGame = nil
        status = "Disconnected"
        print("🤖 [AIAgentCoordinator] Disconnected")
    }

    // MARK: - Agent Control

    /// Start the AI agent
    public func startAgent(mode: AgentMode = .balanced) {
        guard !isActive else { return }

        // Set agent mode
        switch mode {
        case .aggressive:
            simpleAgent.setAggressive()
        case .defensive:
            simpleAgent.setDefensive()
        case .balanced:
            simpleAgent.setBalanced()
        case .explorer:
            simpleAgent.setExplorer()
        }

        // Start agent
        simpleAgent.start()
        isActive = true
        status = "AI Playing (\(mode.rawValue))"

        print("🤖 [AIAgentCoordinator] AI Agent started in \(mode.rawValue) mode")
    }

    /// Stop the AI agent
    public func stopAgent() {
        guard isActive else { return }

        simpleAgent.stop()
        controllerInjector.releaseAllButtons()
        isActive = false
        status = "Stopped"

        print("🤖 [AIAgentCoordinator] AI Agent stopped")
    }

    /// Change agent mode on the fly
    public func setAgentMode(_ mode: AgentMode) {
        switch mode {
        case .aggressive:
            simpleAgent.setAggressive()
        case .defensive:
            simpleAgent.setDefensive()
        case .balanced:
            simpleAgent.setBalanced()
        case .explorer:
            simpleAgent.setExplorer()
        }

        status = "AI Playing (\(mode.rawValue))"
        print("🤖 [AIAgentCoordinator] Mode changed to \(mode.rawValue)")
    }

    // MARK: - Game-Specific State

    /// Get Super Mario 64 game state (if applicable)
    public func getSM64State() -> SuperMario64Adapter.GameState? {
        return sm64Adapter?.readGameState()
    }

    /// Get Zelda OOT game state (if applicable)
    public func getZeldaState() -> ZeldaOOTAdapter.GameState? {
        return zeldaAdapter?.readGameState()
    }

    /// Get generic game state
    public func getGameState() -> MemoryReader.GameState {
        return memoryReader.getGameState()
    }

    // MARK: - Stats

    /// Get AI statistics
    public func getStats() -> Stats {
        return Stats(
            isActive: isActive,
            decisionsMade: simpleAgent.decisionsMade,
            agentStatus: simpleAgent.status,
            currentGame: currentGame ?? "Unknown",
            emulatorConnected: emulatorPID > 0
        )
    }

    public struct Stats {
        public let isActive: Bool
        public let decisionsMade: Int
        public let agentStatus: String
        public let currentGame: String
        public let emulatorConnected: Bool
    }

    // MARK: - Agent Modes

    public enum AgentMode: String {
        case aggressive = "Aggressive"
        case defensive = "Defensive"
        case balanced = "Balanced"
        case explorer = "Explorer"
    }

    // MARK: - Helper Methods

    /// Find mupen64plus process PID
    public static func findEmulatorProcess() -> pid_t? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/pgrep")
        process.arguments = ["-f", "mupen64plus"]

        let pipe = Pipe()
        process.standardOutput = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
               let pid = pid_t(output) {
                return pid
            }
        } catch {
            print("⚠️ Failed to find emulator process: \(error)")
        }

        return nil
    }

    /// Auto-detect game from ROM name
    public static func detectGame(fromROMName name: String) -> String {
        let lowercased = name.lowercased()

        if lowercased.contains("mario") || lowercased.contains("sm64") {
            return "Super Mario 64"
        } else if lowercased.contains("zelda") || lowercased.contains("oot") || lowercased.contains("ocarina") {
            return "The Legend of Zelda: Ocarina of Time"
        } else if lowercased.contains("banjo") {
            return "Banjo-Kazooie"
        } else if lowercased.contains("donkey") || lowercased.contains("dk64") {
            return "Donkey Kong 64"
        } else if lowercased.contains("goldeneye") {
            return "GoldenEye 007"
        } else if lowercased.contains("perfect") || lowercased.contains("dark") {
            return "Perfect Dark"
        }

        return name
    }
}