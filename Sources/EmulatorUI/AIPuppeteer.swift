import SwiftUI
import Foundation
import Vision
import CoreML
import ScreenCaptureKit

/// AI Puppeteer for automated game playing
@MainActor
public class AIPuppeteer: ObservableObject {
    @Published var isEnabled = false
    @Published var isPlaying = false
    @Published var currentModel: LocalAIModel = .llamaGame
    @Published var playStyle: PlayStyle = .casual
    @Published var status = "AI Puppeteer Offline"
    @Published var lastAction = ""
    @Published var confidence: Double = 0
    @Published var gameState = ""

    private var gameplayTimer: Timer?
    private var visionModel: VNCoreMLModel?
    private let actionQueue = DispatchQueue(label: "ai.puppeteer.actions")

    // Virtual controller state
    private var controllerState = VirtualControllerState()

    public init() {
        setupAIModel()
    }

    /// Local AI models for game control
    enum LocalAIModel: String, CaseIterable {
        case llamaGame = "Llama Game AI"
        case mistral = "Mistral Gaming"
        case stableLM = "StableLM Player"
        case tinyllama = "TinyLlama Speed"
        case customOLLAMA = "Custom OLLAMA Model"

        var endpoint: String {
            switch self {
            case .llamaGame, .mistral, .stableLM, .tinyllama, .customOLLAMA:
                return "http://localhost:11434/api/generate" // OLLAMA endpoint
            }
        }

        var modelName: String {
            switch self {
            case .llamaGame: return "llama2"
            case .mistral: return "mistral"
            case .stableLM: return "stablelm2"
            case .tinyllama: return "tinyllama"
            case .customOLLAMA: return "custom"
            }
        }
    }

    /// Playing styles
    enum PlayStyle: String, CaseIterable {
        case casual = "Casual"
        case speedrun = "Speedrun"
        case exploration = "Exploration"
        case aggressive = "Aggressive"
        case defensive = "Defensive"
        case puzzle = "Puzzle Solver"
    }

    /// Virtual controller state
    struct VirtualControllerState {
        var leftStickX: Float = 0
        var leftStickY: Float = 0
        var rightStickX: Float = 0
        var rightStickY: Float = 0
        var aButton = false
        var bButton = false
        var xButton = false
        var yButton = false
        var leftBumper = false
        var rightBumper = false
        var leftTrigger: Float = 0
        var rightTrigger: Float = 0
        var startButton = false
        var selectButton = false
    }

    /// Setup AI model
    private func setupAIModel() {
        // Setup vision model for game state analysis
        let config = MLModelConfiguration()
        config.computeUnits = .cpuAndNeuralEngine
        // In production, load an actual game-playing ML model
        // For now, we'll use Vision for basic analysis
    }

    /// Toggle AI puppeteer
    public func togglePuppeteer() {
        isEnabled.toggle()
        if isEnabled {
            startAutomatedPlay()
            status = "AI Puppeteer Active"
        } else {
            stopAutomatedPlay()
            status = "AI Puppeteer Offline"
        }
    }

    /// Start automated gameplay
    public func startAutomatedPlay() {
        isPlaying = true

        // Main gameplay loop - analyze and act every 100ms
        gameplayTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            Task {
                await self.performGameplayLoop()
            }
        }
    }

    /// Stop automated gameplay
    public func stopAutomatedPlay() {
        isPlaying = false
        gameplayTimer?.invalidate()
        gameplayTimer = nil
        resetController()
    }

    /// Main gameplay loop
    private func performGameplayLoop() async {
        // Capture current game screen
        guard let screenshot = await captureGameScreen() else { return }

        // Analyze game state
        let analysis = await analyzeGameState(screenshot)
        gameState = analysis.description

        // Determine next action using local AI
        let action = await determineAction(analysis)
        lastAction = action.description
        confidence = action.confidence

        // Execute action
        await executeAction(action)
    }

    /// Capture game screen
    private func captureGameScreen() async -> NSImage? {
        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            // Find mupen64plus window
            if content.windows.contains(where: { window in
                let title = window.title ?? ""
                let appName = window.owningApplication?.applicationName ?? ""
                return title.contains("Mupen64Plus") || appName.contains("mupen64plus")
            }) {
                // Simple screenshot capture for analysis
                return nil // Simplified for now
            }
        } catch {
            print("Screen capture error: \(error)")
        }
        return nil
    }

    /// Analyze game state using Vision
    private func analyzeGameState(_ image: NSImage) async -> GameStateAnalysis {
        var analysis = GameStateAnalysis()

        // Convert to CIImage for Vision processing
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let ciImage = CIImage(bitmapImageRep: bitmap) else {
            return analysis
        }

        // Use Vision to detect game elements
        let request = VNRecognizeTextRequest { request, error in
            if let observations = request.results as? [VNRecognizedTextObservation] {
                // Extract text (score, lives, etc.)
                for observation in observations {
                    if let text = observation.topCandidates(1).first?.string {
                        analysis.detectedText.append(text)
                    }
                }
            }
        }

        // Object detection for game entities
        let objectRequest = VNDetectRectanglesRequest { request, error in
            if let observations = request.results as? [VNRectangleObservation] {
                analysis.detectedObjects = observations.count
            }
        }

        // Process requests
        let handler = VNImageRequestHandler(ciImage: ciImage, options: [:])
        try? handler.perform([request, objectRequest])

        // Analyze colors for game state (health, danger zones, etc.)
        analysis.dominantColors = analyzeDominantColors(ciImage)

        // Determine game phase
        analysis.gamePhase = determineGamePhase(from: analysis)

        return analysis
    }

    /// Determine action using local AI model
    private func determineAction(_ gameState: GameStateAnalysis) async -> GameAction {
        // Call local OLLAMA model
        let prompt = buildActionPrompt(gameState)

        do {
            let response = try await callLocalAI(prompt: prompt)
            return parseAIResponse(response, gameState: gameState)
        } catch {
            print("Local AI error: \(error)")
            // Fallback to rule-based action
            return createFallbackAction(gameState)
        }
    }

    /// Build prompt for AI
    private func buildActionPrompt(_ state: GameStateAnalysis) -> String {
        """
        You are playing a Nintendo 64 game. Current game state:
        - Detected objects: \(state.detectedObjects)
        - Game phase: \(state.gamePhase)
        - Detected text: \(state.detectedText.joined(separator: ", "))
        - Play style: \(playStyle.rawValue)

        Based on this state, what controller input should be performed next?
        Respond with a single action in format: ACTION:BUTTON or MOVE:DIRECTION
        """
    }

    /// Call local AI model
    private func callLocalAI(prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: currentModel.endpoint)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": currentModel.modelName,
            "prompt": prompt,
            "stream": false,
            "options": [
                "temperature": 0.3,
                "top_p": 0.9,
                "max_tokens": 50
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let response = json["response"] as? String {
            return response
        }

        throw NSError(domain: "AIPuppeteer", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid AI response"])
    }

    /// Parse AI response into action
    private func parseAIResponse(_ response: String, gameState: GameStateAnalysis) -> GameAction {
        var action = GameAction()
        action.confidence = 0.75 // Base confidence

        // Parse response for action commands
        if response.contains("JUMP") || response.contains("A:") {
            action.type = .button(.a)
            action.description = "Jump"
        } else if response.contains("SHOOT") || response.contains("B:") {
            action.type = .button(.b)
            action.description = "Shoot/Attack"
        } else if response.contains("MOVE:LEFT") {
            action.type = .movement(x: -1, y: 0)
            action.description = "Move Left"
        } else if response.contains("MOVE:RIGHT") {
            action.type = .movement(x: 1, y: 0)
            action.description = "Move Right"
        } else if response.contains("MOVE:UP") {
            action.type = .movement(x: 0, y: 1)
            action.description = "Move Up"
        } else if response.contains("MOVE:DOWN") {
            action.type = .movement(x: 0, y: -1)
            action.description = "Move Down"
        } else {
            // Default exploration movement
            action.type = .movement(x: Float.random(in: -1...1), y: Float.random(in: -1...1))
            action.description = "Exploring"
            action.confidence = 0.5
        }

        return action
    }

    /// Create fallback action when AI fails
    private func createFallbackAction(_ state: GameStateAnalysis) -> GameAction {
        var action = GameAction()

        switch playStyle {
        case .aggressive:
            action.type = .button(.b) // Attack
            action.description = "Aggressive Attack"
        case .defensive:
            action.type = .movement(x: 0, y: -1) // Move back
            action.description = "Defensive Retreat"
        case .exploration:
            action.type = .movement(x: Float.random(in: -1...1), y: Float.random(in: -1...1))
            action.description = "Exploring Area"
        case .speedrun:
            action.type = .movement(x: 1, y: 0) // Move forward fast
            action.description = "Speed Forward"
        case .puzzle:
            action.type = .button(.a) // Interact
            action.description = "Puzzle Interact"
        case .casual:
            // Mix of movements and actions
            if Bool.random() {
                action.type = .movement(x: Float.random(in: -0.5...0.5), y: Float.random(in: -0.5...0.5))
                action.description = "Casual Movement"
            } else {
                action.type = .button(Bool.random() ? .a : .b)
                action.description = "Casual Action"
            }
        }

        action.confidence = 0.3 // Low confidence for fallback
        return action
    }

    /// Execute controller action
    private func executeAction(_ action: GameAction) async {
        // Send virtual controller input to emulator
        switch action.type {
        case .movement(let x, let y):
            controllerState.leftStickX = x
            controllerState.leftStickY = y
        case .button(let button):
            switch button {
            case .a:
                controllerState.aButton = true
            case .b:
                controllerState.bButton = true
            case .x:
                controllerState.xButton = true
            case .y:
                controllerState.yButton = true
            }
        case .camera(let x, let y):
            controllerState.rightStickX = x
            controllerState.rightStickY = y
        case .trigger(let left, let right):
            controllerState.leftTrigger = left
            controllerState.rightTrigger = right
        }

        // Send input to emulator
        await sendControllerInput()

        // Reset button after press
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.resetButtons()
        }
    }

    /// Send controller input to emulator
    private func sendControllerInput() async {
        // This would integrate with the emulator's input system
        // For now, post a notification with the controller state
        NotificationCenter.default.post(
            name: Notification.Name("AIPuppeteerInput"),
            object: controllerState
        )
    }

    /// Reset controller buttons
    private func resetButtons() {
        controllerState.aButton = false
        controllerState.bButton = false
        controllerState.xButton = false
        controllerState.yButton = false
    }

    /// Reset entire controller
    private func resetController() {
        controllerState = VirtualControllerState()
    }

    /// Analyze dominant colors
    private func analyzeDominantColors(_ image: CIImage) -> [String] {
        // Simplified color analysis
        return ["red", "blue", "green"]
    }

    /// Determine game phase
    private func determineGamePhase(from analysis: GameStateAnalysis) -> String {
        if analysis.detectedText.contains(where: { $0.lowercased().contains("game over") }) {
            return "Game Over"
        } else if analysis.detectedText.contains(where: { $0.lowercased().contains("pause") }) {
            return "Paused"
        } else if analysis.detectedObjects > 5 {
            return "Combat"
        } else {
            return "Exploration"
        }
    }
}

/// Game state analysis result
struct GameStateAnalysis {
    var detectedObjects = 0
    var detectedText: [String] = []
    var dominantColors: [String] = []
    var gamePhase = "Unknown"

    var description: String {
        "Phase: \(gamePhase), Objects: \(detectedObjects)"
    }
}

/// Game action
struct GameAction {
    enum ActionType {
        case movement(x: Float, y: Float)
        case button(ButtonType)
        case camera(x: Float, y: Float)
        case trigger(left: Float, right: Float)
    }

    enum ButtonType {
        case a, b, x, y
    }

    var type: ActionType = .movement(x: 0, y: 0)
    var description = ""
    var confidence: Double = 0
}

/// AI Puppeteer Control View
public struct AIPuppeteerControl: View {
    @StateObject private var puppeteer = AIPuppeteer()
    @State private var showModelPicker = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "cpu.fill")
                    .foregroundColor(.purple)
                Text("AI Puppeteer")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(puppeteer.isEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            // Enable toggle
            Toggle("Enable AI Control", isOn: $puppeteer.isEnabled)
                .onChange(of: puppeteer.isEnabled) { _ in
                    puppeteer.togglePuppeteer()
                }

            // Model selection
            HStack {
                Text("AI Model:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $puppeteer.currentModel) {
                    ForEach(AIPuppeteer.LocalAIModel.allCases, id: \.self) { model in
                        Text(model.rawValue).tag(model)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
            }

            // Play style
            HStack {
                Text("Style:")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Picker("", selection: $puppeteer.playStyle) {
                    ForEach(AIPuppeteer.PlayStyle.allCases, id: \.self) { style in
                        Text(style.rawValue).tag(style)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
            }

            Divider()

            // Status display
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                HStack {
                    Text("Status:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(puppeteer.status)
                        .font(.caption)
                        .foregroundColor(puppeteer.isEnabled ? .green : .gray)
                }

                if puppeteer.isPlaying {
                    HStack {
                        Text("Action:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(puppeteer.lastAction)
                            .font(.caption)
                            .lineLimit(1)
                    }

                    HStack {
                        Text("Confidence:")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        ProgressView(value: puppeteer.confidence)
                            .progressViewStyle(.linear)
                            .frame(width: 100)
                        Text("\(Int(puppeteer.confidence * 100))%")
                            .font(.caption2)
                    }

                    Text(puppeteer.gameState)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }
            }

            // Control buttons
            if puppeteer.isEnabled {
                HStack {
                    Button("Pause AI") {
                        puppeteer.isPlaying.toggle()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                    Button("Reset") {
                        puppeteer.stopAutomatedPlay()
                        puppeteer.startAutomatedPlay()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}