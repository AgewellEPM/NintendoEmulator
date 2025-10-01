import Foundation
import AppKit
import CoreGraphics
import Vision
import InputSystem
import CoreInterface

/// AI Agent that learns to play games by watching and then plays autonomously
@MainActor
public class AIGameAgent: ObservableObject {
    @Published public private(set) var isLearning = false
    @Published public private(set) var isPlaying = false
    @Published public private(set) var agentMode: AgentMode = .observe
    @Published public private(set) var learningProgress: Double = 0
    @Published public private(set) var confidence: Double = 0
    @Published public private(set) var actionsLearned: Int = 0

    private var learningTask: Task<Void, Never>?
    private var playingTask: Task<Void, Never>?
    private var learnedBehaviors: [GameState: [ControllerInput]] = [:]
    private var recentStates: [GameState] = []
    private let maxMemory = 1000

    // Simple agent integration
    private var simpleAgent: SimpleAgent?
    private var controllerInjector: ControllerInjector?
    private var memoryReader: MemoryReader?

    public enum AgentMode {
        case observe       // Just watch
        case learn         // Watch and learn from user
        case assist        // Help user (suggest moves)
        case autoplay      // Full autonomous play
        case mimic         // Copy user's playstyle
    }

    struct GameState: Hashable {
        let screenHash: Int
        let objectPositions: [CGPoint]
        let healthLevel: Int
        let scoreLevel: Int

        init(frame: CGImage) {
            // Simple hash of the frame for state identification
            self.screenHash = frame.hashValue
            // TODO: Use Vision to detect objects/enemies
            self.objectPositions = []
            self.healthLevel = 100 // TODO: OCR to read health
            self.scoreLevel = 0    // TODO: OCR to read score
        }
    }

    struct ControllerInput {
        let button: String  // A, B, Start, etc.
        let analogX: Float  // -1.0 to 1.0
        let analogY: Float
        let timestamp: Date
        let success: Bool   // Did this action lead to progress?
    }

    public init() {
        // Initialize controller injector and memory reader
        self.controllerInjector = ControllerInjector()
        self.memoryReader = MemoryReader()

        // Create simple agent
        if let injector = controllerInjector, let reader = memoryReader {
            self.simpleAgent = SimpleAgent(controller: injector, memory: reader)
        }
    }

    /// Connect to emulator input system
    public func connectToEmulator(inputDelegate: EmulatorInputProtocol?, gameName: String?) {
        controllerInjector?.connect(inputDelegate: inputDelegate)
        if let gameName = gameName {
            memoryReader?.configureForGame(gameName)
        }
        print("🎮 [AIGameAgent] Connected to emulator")
    }

    // MARK: - Main Control

    /// Start the AI agent in specified mode
    public func startAgent(mode: AgentMode, frameProvider: @escaping () -> CGImage?) async {
        stopAgent()

        agentMode = mode

        switch mode {
        case .observe:
            await startObserving(frameProvider: frameProvider)
        case .learn:
            await startLearning(frameProvider: frameProvider)
        case .assist:
            await startAssisting(frameProvider: frameProvider)
        case .autoplay:
            await startAutoplaying(frameProvider: frameProvider)
        case .mimic:
            await startMimicking(frameProvider: frameProvider)
        }
    }

    /// Stop the AI agent
    public func stopAgent() {
        isLearning = false
        isPlaying = false
        learningTask?.cancel()
        playingTask?.cancel()
        simpleAgent?.stop()
        controllerInjector?.releaseAllButtons()
    }

    // MARK: - Observe Mode

    private func startObserving(frameProvider: @escaping () -> CGImage?) async {
        isLearning = true

        learningTask = Task {
            while !Task.isCancelled && isLearning {
                guard let frame = frameProvider() else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }

                // Analyze frame
                let state = GameState(frame: frame)
                await analyzeGameState(state)

                // Wait for next frame (60 FPS = ~16ms)
                try? await Task.sleep(nanoseconds: 16_666_666)
            }
        }
    }

    // MARK: - Learn Mode

    private func startLearning(frameProvider: @escaping () -> CGImage?) async {
        isLearning = true

        learningTask = Task {
            while !Task.isCancelled && isLearning {
                guard let frame = frameProvider() else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }

                // Capture game state
                let state = GameState(frame: frame)

                // Record current user input
                let input = await captureUserInput()

                // Associate state with action
                if learnedBehaviors[state] == nil {
                    learnedBehaviors[state] = []
                }
                learnedBehaviors[state]?.append(input)

                // Update learning progress
                await MainActor.run {
                    actionsLearned = learnedBehaviors.values.flatMap { $0 }.count
                    learningProgress = min(Double(actionsLearned) / 10000.0, 1.0)
                    confidence = calculateConfidence()
                }

                // Store state history
                recentStates.append(state)
                if recentStates.count > maxMemory {
                    recentStates.removeFirst()
                }

                try? await Task.sleep(nanoseconds: 16_666_666)
            }
        }
    }

    // MARK: - Assist Mode

    private func startAssisting(frameProvider: @escaping () -> CGImage?) async {
        isLearning = true

        learningTask = Task {
            while !Task.isCancelled && isLearning {
                guard let frame = frameProvider() else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }

                let state = GameState(frame: frame)

                // Suggest actions based on learned behaviors
                if let suggestion = suggestAction(for: state) {
                    await MainActor.run {
                        // Post notification with suggestion
                        NotificationCenter.default.post(
                            name: .aiAgentSuggestion,
                            object: suggestion
                        )
                    }
                }

                try? await Task.sleep(nanoseconds: 500_000_000) // Suggest every 0.5s
            }
        }
    }

    // MARK: - Autoplay Mode

    private func startAutoplaying(frameProvider: @escaping () -> CGImage?) async {
        isPlaying = true

        // Use SimpleAgent if available, otherwise fall back to learned behaviors
        if let agent = simpleAgent {
            // Start simple agent (rule-based AI)
            agent.start()

            playingTask = Task {
                while !Task.isCancelled && isPlaying {
                    // Simple agent runs its own loop
                    // We just monitor and update UI
                    await MainActor.run {
                        actionsLearned = agent.decisionsMade
                        confidence = agent.isRunning ? 0.8 : 0.0
                    }
                    try? await Task.sleep(nanoseconds: 500_000_000)
                }
            }
        } else {
            // Fall back to learned behavior mode
            playingTask = Task {
                while !Task.isCancelled && isPlaying {
                    guard let frame = frameProvider() else {
                        try? await Task.sleep(nanoseconds: 100_000_000)
                        continue
                    }

                    let state = GameState(frame: frame)

                    // Decide action based on learned behaviors
                    if let action = decideAction(for: state) {
                        await executeAction(action)
                    }

                    try? await Task.sleep(nanoseconds: 16_666_666)
                }
            }
        }
    }

    // MARK: - Mimic Mode

    private func startMimicking(frameProvider: @escaping () -> CGImage?) async {
        isPlaying = true
        isLearning = true

        // Learn and play simultaneously, mimicking user style
        playingTask = Task {
            while !Task.isCancelled && isPlaying {
                guard let frame = frameProvider() else {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    continue
                }

                let state = GameState(frame: frame)

                // Check if user is currently playing
                let userInput = await captureUserInput()

                if userInput.button.isEmpty {
                    // User is idle, AI takes over mimicking learned style
                    if let mimicAction = mimicUserStyle(for: state) {
                        await executeAction(mimicAction)
                    }
                } else {
                    // User is playing, learn from them
                    if learnedBehaviors[state] == nil {
                        learnedBehaviors[state] = []
                    }
                    learnedBehaviors[state]?.append(userInput)
                }

                try? await Task.sleep(nanoseconds: 16_666_666)
            }
        }
    }

    // MARK: - Helper Methods

    private func analyzeGameState(_ state: GameState) async {
        // Use Vision framework to analyze game elements
        // TODO: Implement object detection, text recognition
        print("📊 Analyzing game state: \(state.screenHash)")
    }

    private func captureUserInput() async -> ControllerInput {
        // TODO: Hook into ControllerManager to capture actual inputs
        // For now, return empty input
        return ControllerInput(
            button: "",
            analogX: 0,
            analogY: 0,
            timestamp: Date(),
            success: false
        )
    }

    private func suggestAction(for state: GameState) -> ControllerInput? {
        // Look up learned actions for similar state
        guard let actions = learnedBehaviors[state], !actions.isEmpty else {
            return nil
        }

        // Return most successful action
        return actions.max(by: { a, b in
            let aScore = a.success ? 1 : 0
            let bScore = b.success ? 1 : 0
            return aScore < bScore
        })
    }

    private func decideAction(for state: GameState) -> ControllerInput? {
        // Use learned behaviors to decide action
        if let exactMatch = learnedBehaviors[state]?.randomElement() {
            return exactMatch
        }

        // Find similar state
        let similarState = findSimilarState(to: state)
        return learnedBehaviors[similarState]?.randomElement()
    }

    private func mimicUserStyle(for state: GameState) -> ControllerInput? {
        // Analyze user's recent playstyle patterns
        // Return action that matches user's typical response
        return decideAction(for: state)
    }

    private func executeAction(_ action: ControllerInput) async {
        // TODO: Send controller input to emulator
        // This would use ControllerManager to simulate button presses
        print("🎮 AI executing: \(action.button) analog(\(action.analogX), \(action.analogY))")

        // Post notification to controller system
        NotificationCenter.default.post(
            name: .aiAgentAction,
            object: action
        )
    }

    private func findSimilarState(to targetState: GameState) -> GameState {
        // Find most similar state in memory
        // Use simple hash distance for now
        return recentStates.min(by: { state1, state2 in
            let dist1 = abs(state1.screenHash - targetState.screenHash)
            let dist2 = abs(state2.screenHash - targetState.screenHash)
            return dist1 < dist2
        }) ?? targetState
    }

    private func calculateConfidence() -> Double {
        // Calculate confidence based on learned behaviors
        let totalStates = learnedBehaviors.count
        let avgActionsPerState = Double(actionsLearned) / max(Double(totalStates), 1)

        // Higher confidence with more states and more actions per state
        return min((Double(totalStates) / 100.0) * (avgActionsPerState / 10.0), 1.0)
    }

    // MARK: - Export/Import

    /// Export learned behaviors to file
    public func exportBehaviors(to url: URL) throws {
        // TODO: Serialize and save learned behaviors
        print("💾 Exporting AI behaviors to: \(url.path)")
    }

    /// Import learned behaviors from file
    public func importBehaviors(from url: URL) throws {
        // TODO: Load and deserialize behaviors
        print("📂 Importing AI behaviors from: \(url.path)")
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let aiAgentSuggestion = Notification.Name("aiAgentSuggestion")
    static let aiAgentAction = Notification.Name("aiAgentAction")
}