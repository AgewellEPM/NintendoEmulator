import Foundation
import CoreGraphics

/// Simple rule-based AI agent that can play N64 games
/// Uses basic logic and game state to make decisions
@MainActor
public class SimpleAgent: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var isRunning = false
    @Published public private(set) var status: String = "Idle"
    @Published public private(set) var decisionsMade: Int = 0

    private let controller: ControllerInjector
    private let memory: MemoryReader
    private var agentTask: Task<Void, Never>?

    // Agent configuration
    public var aggressiveness: Float = 0.5  // 0.0 = defensive, 1.0 = aggressive
    public var explorationRate: Float = 0.3  // Chance to try random actions
    public var reactionTime: TimeInterval = 0.2  // Delay between decisions

    // State tracking
    private var lastHealth: Int = 100
    private var lastScore: Int = 0
    private var stuckCounter: Int = 0
    private var lastPosition: (Float, Float, Float) = (0, 0, 0)
    private var consecutiveFailures: Int = 0

    // MARK: - Initialization

    public init(controller: ControllerInjector, memory: MemoryReader) {
        self.controller = controller
        self.memory = memory
    }

    // MARK: - Control

    /// Start the agent
    public func start() {
        guard !isRunning else { return }

        isRunning = true
        status = "Starting..."
        decisionsMade = 0
        consecutiveFailures = 0

        agentTask = Task {
            await runAgentLoop()
        }

        print("🤖 [SimpleAgent] Started")
    }

    /// Stop the agent
    public func stop() {
        guard isRunning else { return }

        isRunning = false
        status = "Stopping..."
        agentTask?.cancel()
        agentTask = nil
        controller.releaseAllButtons()

        print("🤖 [SimpleAgent] Stopped")
    }

    // MARK: - Main Agent Loop

    private func runAgentLoop() async {
        while !Task.isCancelled && isRunning {
            // Read game state
            let gameState = memory.getGameState()

            // Check if game over
            if gameState.isGameOver {
                status = "Game Over - Restarting..."
                await handleGameOver()
                continue
            }

            // Check if paused
            if gameState.isPaused {
                status = "Game Paused"
                try? await Task.sleep(nanoseconds: 500_000_000)
                continue
            }

            // Make decision
            await makeDecision(gameState: gameState)

            // Update status
            status = "Health: \(gameState.health) | Score: \(gameState.score) | Decisions: \(decisionsMade)"

            // Wait before next decision (reaction time)
            try? await Task.sleep(nanoseconds: UInt64(reactionTime * 1_000_000_000))
        }

        status = "Stopped"
    }

    // MARK: - Decision Making

    private func makeDecision(gameState: MemoryReader.GameState) async {
        decisionsMade += 1

        // 1. Check for danger (low health)
        if gameState.health < 30 {
            await handleLowHealth(gameState: gameState)
            return
        }

        // 2. Check if stuck (not moving)
        if isStuck(gameState: gameState) {
            await handleStuck()
            return
        }

        // 3. Detect health loss (taking damage)
        if gameState.health < lastHealth {
            await handleDamage(gameState: gameState)
        }

        // 4. Detect score gain (positive feedback)
        if gameState.score > lastScore {
            await handleScoreGain()
        }

        // 5. Random exploration
        if shouldExplore() {
            await explore()
            return
        }

        // 6. Default behavior (based on game type)
        await defaultBehavior(gameState: gameState)

        // Update last state
        lastHealth = gameState.health
        lastScore = gameState.score
        lastPosition = (gameState.playerX, gameState.playerY, gameState.playerZ)
    }

    // MARK: - Behavior Strategies

    /// Handle low health situation
    private func handleLowHealth(gameState: MemoryReader.GameState) async {
        status = "⚠️ Low Health - Retreating"

        // Run away backwards
        controller.setAnalogStick(.down)
        try? await Task.sleep(nanoseconds: 500_000_000)

        // Jump while retreating
        await controller.jump()

        controller.setAnalogStick(.center)
    }

    /// Handle being stuck
    private func handleStuck() async {
        status = "🔄 Stuck - Trying to escape"
        stuckCounter = 0

        // Try: Jump
        await controller.jump()
        try? await Task.sleep(nanoseconds: 200_000_000)

        // Try: Turn around
        await controller.turn(direction: .right, amount: 1.0)
        try? await Task.sleep(nanoseconds: 300_000_000)

        // Try: Move forward
        controller.setAnalogStick(.up)
        try? await Task.sleep(nanoseconds: 500_000_000)
        controller.setAnalogStick(.center)
    }

    /// Handle taking damage
    private func handleDamage(gameState: MemoryReader.GameState) async {
        status = "💥 Took Damage"

        if aggressiveness < 0.5 {
            // Defensive: Retreat
            controller.setAnalogStick(.down)
            try? await Task.sleep(nanoseconds: 300_000_000)
            controller.setAnalogStick(.center)
        } else {
            // Aggressive: Counter-attack
            await controller.attack()
            try? await Task.sleep(nanoseconds: 100_000_000)
            await controller.attack()
        }
    }

    /// Handle score gain (positive reinforcement)
    private func handleScoreGain() async {
        status = "✨ Score Gained"

        // Continue current strategy (it's working!)
        consecutiveFailures = 0
    }

    /// Explore randomly
    private func explore() async {
        status = "🔍 Exploring"

        let action = Int.random(in: 0...5)

        switch action {
        case 0:
            // Move forward
            await controller.runForward(duration: 0.5)
        case 1:
            // Jump
            await controller.jump()
        case 2:
            // Turn
            await controller.turn(direction: .random ? .left : .right)
        case 3:
            // Attack
            await controller.attack()
        case 4:
            // Strafe
            await controller.strafe(direction: .random ? .left : .right, duration: 0.3)
        case 5:
            // Combo: Jump + Move
            controller.setAnalogStick(.up)
            await controller.jump()
            try? await Task.sleep(nanoseconds: 500_000_000)
            controller.setAnalogStick(.center)
        default:
            break
        }
    }

    /// Default behavior (general gameplay)
    private func defaultBehavior(gameState: MemoryReader.GameState) async {
        status = "🎮 Playing"

        // Basic gameplay loop for platformers/action games
        if aggressiveness > 0.6 {
            // Aggressive: Move forward and attack
            controller.setAnalogStick(.up)
            try? await Task.sleep(nanoseconds: 200_000_000)

            if Bool.random() {
                await controller.attack()
            }

            controller.setAnalogStick(.center)
        } else {
            // Defensive: Move cautiously
            controller.setAnalogStick(ControllerInjector.AnalogPosition(x: 0, y: 64)) // Half speed
            try? await Task.sleep(nanoseconds: 300_000_000)
            controller.setAnalogStick(.center)

            // Look around
            await controller.turn(direction: .random ? .left : .right, amount: 0.3)
        }

        // Occasionally jump over obstacles
        if Bool.random() && Double.random(in: 0...1) > 0.7 {
            await controller.jump()
        }
    }

    /// Handle game over
    private func handleGameOver() async {
        status = "💀 Game Over"

        // Wait
        try? await Task.sleep(nanoseconds: 2_000_000_000)

        // Press Start to restart (if supported)
        await controller.pressButton(.start, duration: 0.2)
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Press A to confirm
        await controller.tapButton(.a)

        // Reset counters
        decisionsMade = 0
        consecutiveFailures = 0
    }

    // MARK: - Helper Methods

    /// Check if agent is stuck (not moving for several frames)
    private func isStuck(gameState: MemoryReader.GameState) -> Bool {
        let currentPos = (gameState.playerX, gameState.playerY, gameState.playerZ)
        let distance = sqrt(
            pow(currentPos.0 - lastPosition.0, 2) +
            pow(currentPos.1 - lastPosition.1, 2) +
            pow(currentPos.2 - lastPosition.2, 2)
        )

        if distance < 1.0 {
            stuckCounter += 1
        } else {
            stuckCounter = 0
        }

        return stuckCounter > 10  // Stuck for 10 frames
    }

    /// Decide if agent should explore
    private func shouldExplore() -> Bool {
        return Float.random(in: 0...1) < explorationRate
    }

    // MARK: - Configuration

    /// Set agent to aggressive mode
    public func setAggressive() {
        aggressiveness = 0.8
        explorationRate = 0.4
        print("🤖 [SimpleAgent] Mode: Aggressive")
    }

    /// Set agent to defensive mode
    public func setDefensive() {
        aggressiveness = 0.2
        explorationRate = 0.2
        print("🤖 [SimpleAgent] Mode: Defensive")
    }

    /// Set agent to balanced mode
    public func setBalanced() {
        aggressiveness = 0.5
        explorationRate = 0.3
        print("🤖 [SimpleAgent] Mode: Balanced")
    }

    /// Set agent to explorer mode
    public func setExplorer() {
        aggressiveness = 0.4
        explorationRate = 0.7
        print("🤖 [SimpleAgent] Mode: Explorer")
    }
}

// MARK: - Extensions

extension Bool {
    static var random: Bool {
        return Int.random(in: 0...1) == 1
    }
}