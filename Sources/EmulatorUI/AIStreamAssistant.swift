import SwiftUI
import Foundation
import ScreenCaptureKit
import Vision
import AppKit

/// AI Stream Assistant for chat moderation and game commentary
@MainActor
public class AIStreamAssistant: ObservableObject {
    @Published var isAIEnabled = false
    @Published var isCommentaryMode = false
    @Published var aiStatus = "AI Offline"
    @Published var lastAIResponse = ""
    @Published var gameContext = ""
    @Published var isAnalyzing = false

    private var openAIKey: String = ""
    private var captureTimer: Timer?
    private let apiEndpoint = "https://api.openai.com/v1/chat/completions"
    private let visionEndpoint = "https://api.openai.com/v1/chat/completions"

    // Game state tracking for better recommendations
    private var gameHistory: [String] = []
    private var currentGame = ""

    public init() {
        loadAPIKey()
    }

    /// Load API key from UserDefaults or environment
    private func loadAPIKey() {
        if let key = UserDefaults.standard.string(forKey: "OpenAIAPIKey") {
            openAIKey = key
        } else if let key = ProcessInfo.processInfo.environment["OPENAI_API_KEY"] {
            openAIKey = key
        }
    }

    /// Save API key
    public func setAPIKey(_ key: String) {
        openAIKey = key
        UserDefaults.standard.set(key, forKey: "OpenAIAPIKey")
    }

    /// Toggle AI assistance
    public func toggleAI() {
        isAIEnabled.toggle()
        if isAIEnabled {
            aiStatus = "AI Online"
            startGameAnalysis()
        } else {
            aiStatus = "AI Offline"
            stopGameAnalysis()
        }
    }

    /// Toggle commentary mode
    public func toggleCommentary() {
        isCommentaryMode.toggle()
        if isCommentaryMode {
            startCommentary()
        } else {
            stopCommentary()
        }
    }

    /// Process chat message with AI
    public func processChat(_ message: String, username: String) async -> String? {
        guard isAIEnabled, !openAIKey.isEmpty else { return nil }

        // Check if message is a question or needs response
        if shouldRespond(to: message) {
            return await generateAIResponse(message: message, username: username)
        }

        return nil
    }

    /// Determine if AI should respond to a message
    private func shouldRespond(to message: String) -> Bool {
        let triggers = ["?", "how", "what", "why", "when", "where", "help", "ai", "bot", "tip", "advice"]
        let lowercased = message.lowercased()
        return triggers.contains { lowercased.contains($0) }
    }

    /// Generate AI response for chat
    private func generateAIResponse(message: String, username: String) async -> String {
        let systemPrompt = """
        You are a friendly and knowledgeable gaming stream assistant. You're watching a Nintendo 64 game stream.
        Current game context: \(gameContext)
        Keep responses brief (1-2 sentences), friendly, and helpful.
        Include gaming tips when relevant.
        Use casual gamer language and occasionally use emotes like :D or ^_^
        """

        let userPrompt = "\(username) asks: \(message)"

        do {
            let response = try await callOpenAI(system: systemPrompt, user: userPrompt)
            lastAIResponse = response
            return response
        } catch {
            print("AI response error: \(error)")
            return "Sorry, I couldn't process that! Try again? :)"
        }
    }

    /// Start analyzing gameplay
    private func startGameAnalysis() {
        captureTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: true) { _ in
            Task {
                await self.analyzeCurrentGameplay()
            }
        }
    }

    /// Stop analyzing gameplay
    private func stopGameAnalysis() {
        captureTimer?.invalidate()
        captureTimer = nil
    }

    /// Capture and analyze current gameplay
    private func analyzeCurrentGameplay() async {
        guard isAIEnabled else { return }

        isAnalyzing = true
        defer { isAnalyzing = false }

        // Capture game window screenshot
        if let screenshot = await captureGameWindow() {
            let analysis = await analyzeGameImage(screenshot)
            gameContext = analysis

            // Generate commentary if enabled
            if isCommentaryMode {
                await generateCommentary(context: analysis)
            }
        }
    }

    /// Capture the current emulator window for streaming/analysis
    private func captureGameWindow() async -> NSImage? {
        if #available(macOS 14.0, *) {
            do {
                let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

                // Prefer our own app window first (integrated Metal view)
                let bundleID = Bundle.main.bundleIdentifier
                let ownWindows = content.windows.filter { window in
                    guard let owning = window.owningApplication else { return false }
                    if let bundleID = bundleID, owning.bundleIdentifier == bundleID { return true }
                    let appName = owning.applicationName
                    return appName.localizedCaseInsensitiveContains("Nintendo Emulator") ||
                           appName.localizedCaseInsensitiveContains("NintendoEmulator")
                }

                // Fallback: external mupen64plus window (if cores run out-of-process)
                let externalWindows = content.windows.filter { window in
                    let title = window.title ?? ""
                    let appName = window.owningApplication?.applicationName ?? ""
                    return title.localizedCaseInsensitiveContains("Mupen64Plus") ||
                           appName.localizedCaseInsensitiveContains("mupen64plus")
                }

                // Choose the largest visible window among candidates
                let candidate = (ownWindows + externalWindows)
                    .max(by: { lhs, rhs in
                        (lhs.frame.width * lhs.frame.height) < (rhs.frame.width * rhs.frame.height)
                    })

                if let gameWindow = candidate {
                    let filter = SCContentFilter(desktopIndependentWindow: gameWindow)
                    let config = SCStreamConfiguration()
                    config.width = Int(gameWindow.frame.width)
                    config.height = Int(gameWindow.frame.height)

                    let cgImage = try await SCScreenshotManager.captureImage(
                        contentFilter: filter,
                        configuration: config
                    )

                    return NSImage(
                        cgImage: cgImage,
                        size: NSSize(width: cgImage.width, height: cgImage.height)
                    )
                }
            } catch {
                print("Screenshot capture error: \(error)")
            }
        }

        return nil
    }

    /// Analyze game image with Vision API
    private func analyzeGameImage(_ image: NSImage) async -> String {
        guard !openAIKey.isEmpty else { return "No API key configured" }

        // Convert image to base64
        guard let imageData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: imageData),
              let jpegData = bitmap.representation(using: .jpeg, properties: [:]) else {
            return "Unable to process image"
        }

        let base64Image = jpegData.base64EncodedString()

        let systemPrompt = """
        You are a gaming expert analyzing Nintendo 64 gameplay.
        Identify what's happening in the game, the current objective, and provide brief strategic advice.
        Keep analysis to 2-3 sentences.
        Focus on: current game state, player position, enemies/obstacles, and recommended next action.
        """

        do {
            let response = try await callVisionAPI(system: systemPrompt, imageBase64: base64Image)
            return response
        } catch {
            print("Vision API error: \(error)")
            return "Analyzing gameplay..."
        }
    }

    /// Generate live commentary
    private func generateCommentary(context: String) async {
        let prompt = """
        You are an enthusiastic esports commentator for a Nintendo 64 stream.
        Based on this game situation: \(context)
        Generate exciting, brief commentary (1-2 sentences).
        Be energetic, use gaming terminology, and hype up the action!
        """

        do {
            let commentary = try await callOpenAI(system: prompt, user: "Generate commentary")

            // Post commentary to chat
            await MainActor.run {
                NotificationCenter.default.post(
                    name: Notification.Name("AICommentary"),
                    object: commentary
                )
            }
        } catch {
            print("Commentary generation error: \(error)")
        }
    }

    /// Call OpenAI API
    private func callOpenAI(system: String, user: String) async throws -> String {
        var request = URLRequest(url: URL(string: apiEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-4-turbo-preview",
            "messages": [
                ["role": "system", "content": system],
                ["role": "user", "content": user]
            ],
            "max_tokens": 100,
            "temperature": 0.7
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw NSError(domain: "AIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
    }

    /// Call Vision API
    private func callVisionAPI(system: String, imageBase64: String) async throws -> String {
        var request = URLRequest(url: URL(string: visionEndpoint)!)
        request.httpMethod = "POST"
        request.setValue("Bearer \(openAIKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let requestBody: [String: Any] = [
            "model": "gpt-4-vision-preview",
            "messages": [
                [
                    "role": "user",
                    "content": [
                        ["type": "text", "text": system],
                        ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(imageBase64)"]]
                    ]
                ]
            ],
            "max_tokens": 150
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (data, _) = try await URLSession.shared.data(for: request)
        let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        if let choices = json["choices"] as? [[String: Any]],
           let message = choices.first?["message"] as? [String: Any],
           let content = message["content"] as? String {
            return content.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        throw NSError(domain: "AIError", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid vision response"])
    }

    /// Start commentary timer
    private func startCommentary() {
        // Commentary every 10 seconds
        Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.isCommentaryMode && self.isAIEnabled {
                    await self.analyzeCurrentGameplay()
                }
            }
        }
    }

    /// Stop commentary
    private func stopCommentary() {
        // Timer will stop when isCommentaryMode is false
    }
}

/// AI Control Panel View
public struct AIControlPanel: View {
    @StateObject private var ai = AIStreamAssistant()
    @State private var apiKey = ""
    @State private var showAPIKeyInput = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            // Header
            HStack {
                Image(systemName: "brain")
                    .foregroundColor(.purple)
                Text("AI Stream Assistant")
                    .font(.headline)
                Spacer()
                Circle()
                    .fill(ai.isAIEnabled ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)
            }

            // AI Toggle
            Toggle("Enable AI Assistant", isOn: $ai.isAIEnabled)
                .onChange(of: ai.isAIEnabled) { _ in
                    ai.toggleAI()
                }

            // Commentary Mode
            Toggle("AI Commentary Mode", isOn: $ai.isCommentaryMode)
                .onChange(of: ai.isCommentaryMode) { _ in
                    ai.toggleCommentary()
                }

            // Status
            HStack {
                Text("Status:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(ai.aiStatus)
                    .font(.caption)
                    .foregroundColor(ai.isAIEnabled ? .green : .gray)
            }

            // Game Context
            if !ai.gameContext.isEmpty {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Game Analysis:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(ai.gameContext)
                        .font(.caption)
                        .lineLimit(3)
                }
                .padding(DesignSystem.Spacing.sm)
                .background(Color.purple.opacity(0.1))
                .cornerRadius(DesignSystem.Radius.md)
            }

            // API Key Setup
            if showAPIKeyInput {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                    Text("OpenAI API Key:")
                        .font(.caption)
                    SecureField("sk-...", text: $apiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                    HStack {
                        Button("Save") {
                            ai.setAPIKey(apiKey)
                            showAPIKeyInput = false
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                        Button("Cancel") {
                            showAPIKeyInput = false
                        }
                        .buttonStyle(.plain)
                        .controlSize(.small)
                    }
                }
            } else {
                Button("Configure API Key") {
                    showAPIKeyInput = true
                }
                .buttonStyle(.link)
                .font(.caption)
            }
        }
        .padding()
        .background(Color.black.opacity(0.8))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}
