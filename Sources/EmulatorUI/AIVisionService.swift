import Foundation
import AppKit
import CoreImage
import Vision

/// AI Vision Service for real-time gameplay analysis
@MainActor
public class AIVisionService: ObservableObject {
    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var lastAnalysis: String?
    @Published public private(set) var analysisTimestamp: Date?

    private var analysisTask: Task<Void, Never>?

    public init() {}

    /// Start analyzing frames from the emulator stream
    public func startAnalysis(frameProvider: @escaping () -> CGImage?) async {
        guard !isAnalyzing else { return }

        isAnalyzing = true

        analysisTask = Task {
            while !Task.isCancelled && isAnalyzing {
                // Capture frame
                guard let frame = frameProvider() else {
                    try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s
                    continue
                }

                // Analyze the frame
                if let analysis = await analyzeFrame(frame) {
                    await MainActor.run {
                        self.lastAnalysis = analysis
                        self.analysisTimestamp = Date()
                    }
                }

                // Wait 3 seconds between analyses (to avoid overwhelming the AI)
                try? await Task.sleep(nanoseconds: 3_000_000_000)
            }
        }
    }

    /// Stop analyzing frames
    public func stopAnalysis() {
        isAnalyzing = false
        analysisTask?.cancel()
        analysisTask = nil
    }

    /// Analyze a single frame using Vision framework and local AI model
    private func analyzeFrame(_ image: CGImage) async -> String? {
        // For now, we'll use Vision framework for basic scene analysis
        // In production, this would call a local LLaVA or similar vision model

        let request = VNRecognizeTextRequest()
        let handler = VNImageRequestHandler(cgImage: image, options: [:])

        do {
            try handler.perform([request])

            // Get text observations
            guard let observations = request.results else {
                return await generateGameplayNarration(hasText: false)
            }

            let detectedText = observations.compactMap { $0.topCandidates(1).first?.string }.joined(separator: " ")

            // Generate contextual narration based on what we see
            return await generateGameplayNarration(hasText: !detectedText.isEmpty, detectedText: detectedText)
        } catch {
            print("❌ Vision analysis failed: \(error)")
            return nil
        }
    }

    /// Generate gameplay narration based on visual analysis
    /// In production, this would call a local AI vision model with the frame
    private func generateGameplayNarration(hasText: Bool, detectedText: String = "") async -> String {
        // TODO: Replace with actual LLaVA or similar local model call
        // For now, provide intelligent simulated narration

        // Check for common game UI elements
        if detectedText.lowercased().contains("pause") {
            return "⏸️ Game is paused. Resume when you're ready!"
        } else if detectedText.lowercased().contains("game over") {
            return "💀 Game Over detected. Don't give up - try again!"
        } else if detectedText.lowercased().contains("start") {
            return "🎮 Ready to start! Press the button to begin your adventure."
        } else if detectedText.contains("HP") || detectedText.contains("HEALTH") {
            return "❤️ Keep an eye on your health meter!"
        } else if detectedText.contains("TIME") || detectedText.contains("TIMER") {
            return "⏱️ Watch the timer - move quickly!"
        }

        // Generate contextual gameplay tips
        let narrations = [
            "💡 Looking good! Keep exploring the area.",
            "🎯 Nice movement! Try checking for hidden items.",
            "⚠️ Be careful - stay alert for enemies.",
            "✨ Great progress! You're getting the hang of it.",
            "🏃 You're moving well through this section.",
            "🔑 Look for items or power-ups in this area.",
            "💪 Solid gameplay! Keep that momentum going.",
            "🎵 Remember to explore every corner for secrets!",
            "👀 Watch your surroundings carefully.",
            "🌟 You're doing great! Trust your instincts."
        ]

        return narrations.randomElement() ?? "Keep playing!"
    }

    /// Call a local AI vision model (placeholder for future LLaVA integration)
    private func callLocalVisionModel(image: CGImage) async -> String? {
        // TODO: Integrate with local LLaVA model
        // This would:
        // 1. Convert CGImage to format the model expects
        // 2. Run inference on the local model
        // 3. Get gameplay advice/narration back
        //
        // Example pseudo-code:
        // let prompt = "You are watching gameplay. Provide a helpful tip based on what you see."
        // let response = await LLaVAModel.shared.analyze(image: image, prompt: prompt)
        // return response

        return nil
    }
}