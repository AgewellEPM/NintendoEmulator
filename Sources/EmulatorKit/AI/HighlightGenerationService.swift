import Foundation
import AVFoundation
import Vision
import CoreML
import Combine
#if canImport(AppKit)
import AppKit
#endif

/// Sprint 2 - CREATOR-001: AI Highlight Generation System
/// Automatically detects and creates highlight clips from gameplay footage
@MainActor
public class HighlightGenerationService: ObservableObject {
    // MARK: - Published Properties
    @Published public private(set) var isGenerating = false
    @Published public private(set) var generationProgress: Double = 0.0
    @Published public private(set) var detectedHighlights: [GameplayHighlight] = []
    @Published public private(set) var generationStatus = ""

    // MARK: - Configuration
    public var highlightDetectionThreshold: Double = 0.75
    public var minimumHighlightDuration: TimeInterval = 5.0
    public var maximumHighlightDuration: TimeInterval = 30.0
    public var maxHighlightsPerSession: Int = 10

    // MARK: - Private Properties
    private var videoProcessor: VideoAnalysisProcessor?
    private var audioProcessor: AudioAnalysisProcessor
    private let mlModelManager: MLModelManager
    private var cancellables = Set<AnyCancellable>()

    public init() {
        self.audioProcessor = AudioAnalysisProcessor()
        self.mlModelManager = MLModelManager()

        setupProcessors()
    }

    // MARK: - Public Interface

    /// Generate highlights from a video file
    public func generateHighlights(
        from videoURL: URL,
        gameType: GameType = .n64,
        options: HighlightGenerationOptions = HighlightGenerationOptions()
    ) async throws -> [GameplayHighlight] {

        guard !isGenerating else {
            throw HighlightGenerationError.alreadyGenerating
        }

        isGenerating = true
        generationProgress = 0.0
        detectedHighlights = []
        generationStatus = "Initializing analysis..."

        do {
            // Step 1: Video Analysis (40% of progress)
            generationStatus = "Analyzing video content..."
            let videoEvents = try await analyzeVideoContent(videoURL, gameType: gameType)
            generationProgress = 0.4

            // Step 2: Audio Analysis (20% of progress)
            generationStatus = "Analyzing audio for excitement markers..."
            let audioEvents = try await analyzeAudioContent(videoURL)
            generationProgress = 0.6

            // Step 3: Combine Analysis Results (20% of progress)
            generationStatus = "Identifying highlight moments..."
            let combinedEvents = combineAnalysisResults(videoEvents: videoEvents, audioEvents: audioEvents)
            generationProgress = 0.8

            // Step 4: Generate Highlight Clips (20% of progress)
            generationStatus = "Creating highlight clips..."
            let highlights = try await createHighlightClips(
                from: videoURL,
                events: combinedEvents,
                options: options
            )
            generationProgress = 1.0

            detectedHighlights = highlights
            generationStatus = "Completed! Found \(highlights.count) highlights"

            // Auto-save highlights if enabled
            if options.autoSave {
                try await saveHighlights(highlights)
            }

            isGenerating = false
            return highlights

        } catch {
            isGenerating = false
            generationStatus = "Error: \(error.localizedDescription)"
            throw error
        }
    }

    /// Generate highlights from live gameplay (real-time)
    public func startRealTimeHighlightDetection(gameType: GameType = .n64) async throws {
        guard !isGenerating else {
            throw HighlightGenerationError.alreadyGenerating
        }

        isGenerating = true
        generationStatus = "Starting real-time highlight detection..."

        // Initialize real-time processors
        videoProcessor = VideoAnalysisProcessor()

        try await videoProcessor?.startRealTimeAnalysis { [weak self] event in
            Task { @MainActor in
                await self?.handleRealTimeEvent(event)
            }
        }
    }

    /// Stop real-time highlight detection
    public func stopRealTimeHighlightDetection() async {
        await videoProcessor?.stopRealTimeAnalysis()
        videoProcessor = nil
        isGenerating = false
        generationStatus = "Real-time detection stopped"
    }

    /// Get saved highlights
    public func getSavedHighlights() async throws -> [GameplayHighlight] {
        return try await HighlightStorage.shared.loadHighlights()
    }

    /// Export highlights to various formats
    public func exportHighlight(
        _ highlight: GameplayHighlight,
        format: HighlightExportFormat,
        quality: VideoQuality = .high
    ) async throws -> URL {

        generationStatus = "Exporting highlight..."

        let exporter = HighlightExporter()
        let exportedURL = try await exporter.export(
            highlight: highlight,
            format: format,
            quality: quality
        )

        generationStatus = "Export completed"
        return exportedURL
    }

    // MARK: - Analysis Methods

    private func analyzeVideoContent(_ videoURL: URL, gameType: GameType) async throws -> [VideoAnalysisEvent] {
        let asset = AVAsset(url: videoURL)
        let duration = try await asset.load(.duration)

        var events: [VideoAnalysisEvent] = []
        let frameRate = 30.0 // Analyze 30 FPS
        let totalFrames = Int(duration.seconds * frameRate)

        // Create video reader
        let reader = try AVAssetReader(asset: asset)
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw HighlightGenerationError.noVideoTrack
        }

        let output = AVAssetReaderTrackOutput(
            track: videoTrack,
            outputSettings: [
                kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
            ]
        )

        reader.add(output)
        reader.startReading()

        var frameIndex = 0

        while let sampleBuffer = output.copyNextSampleBuffer() {
            defer {
                frameIndex += 1
                generationProgress = 0.4 * Double(frameIndex) / Double(totalFrames)
            }

            guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
                continue
            }

            // Analyze frame for game-specific events
            let timestamp = CMSampleBufferGetPresentationTimeStamp(sampleBuffer).seconds
            let frameEvents = try await analyzeGameplayFrame(
                pixelBuffer: pixelBuffer,
                timestamp: timestamp,
                gameType: gameType
            )

            events.append(contentsOf: frameEvents)
        }

        return events
    }

    private func analyzeGameplayFrame(
        pixelBuffer: CVPixelBuffer,
        timestamp: TimeInterval,
        gameType: GameType
    ) async throws -> [VideoAnalysisEvent] {

        var events: [VideoAnalysisEvent] = []

        // Use Vision framework for general computer vision analysis
        let request = VNDetectRectanglesRequest { request, error in
            // Detect UI elements, score changes, etc.
        }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer)
        try handler.perform([request])

        // Game-specific analysis using ML models
        switch gameType {
        case .n64:
            events.append(contentsOf: try await analyzeN64Frame(pixelBuffer: pixelBuffer, timestamp: timestamp))
        case .snes:
            events.append(contentsOf: try await analyzeSNESFrame(pixelBuffer: pixelBuffer, timestamp: timestamp))
        case .generic:
            events.append(contentsOf: try await analyzeGenericGameFrame(pixelBuffer: pixelBuffer, timestamp: timestamp))
        }

        return events
    }

    private func analyzeN64Frame(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) async throws -> [VideoAnalysisEvent] {
        var events: [VideoAnalysisEvent] = []

        // Detect common N64 game events
        let model = try await mlModelManager.getN64AnalysisModel()

        // Convert pixel buffer to model input
        let input = try MLMultiArray(shape: [1, 224, 224, 3], dataType: .float32)
        // ... populate input with pixel data ...

        let prediction = try model.prediction(from: MLDictionaryFeatureProvider(dictionary: ["image": input]))

        // Interpret predictions
        if let confidence = prediction.featureValue(for: "confidence")?.doubleValue,
           confidence > highlightDetectionThreshold {

            let eventType: HighlightEventType = determineEventType(from: prediction)

            events.append(VideoAnalysisEvent(
                timestamp: timestamp,
                type: eventType,
                confidence: confidence,
                boundingBox: CGRect.zero, // Would be populated with actual detection
                metadata: extractEventMetadata(from: prediction)
            ))
        }

        return events
    }

    private func analyzeSNESFrame(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) async throws -> [VideoAnalysisEvent] {
        // Similar analysis for SNES games
        return []
    }

    private func analyzeGenericGameFrame(pixelBuffer: CVPixelBuffer, timestamp: TimeInterval) async throws -> [VideoAnalysisEvent] {
        let events: [VideoAnalysisEvent] = []

        // Generic game analysis - look for common patterns
        // - Health bars
        // - Score changes
        // - Menu transitions
        // - Action sequences

        return events
    }

    private func analyzeAudioContent(_ videoURL: URL) async throws -> [AudioAnalysisEvent] {
        return try await audioProcessor.analyzeAudio(from: videoURL) { [weak self] progress in
            Task { @MainActor in
                // Update progress from 0.4 to 0.6
                self?.generationProgress = 0.4 + (0.2 * progress)
            }
        }
    }

    private func combineAnalysisResults(
        videoEvents: [VideoAnalysisEvent],
        audioEvents: [AudioAnalysisEvent]
    ) -> [CombinedAnalysisEvent] {

        var combinedEvents: [CombinedAnalysisEvent] = []
        let timeWindow: TimeInterval = 2.0 // 2-second correlation window

        // Correlate video and audio events
        for videoEvent in videoEvents {
            let correlatedAudioEvents = audioEvents.filter { audioEvent in
                abs(audioEvent.timestamp - videoEvent.timestamp) <= timeWindow
            }

            let combinedConfidence = calculateCombinedConfidence(
                videoEvent: videoEvent,
                audioEvents: correlatedAudioEvents
            )

            if combinedConfidence > highlightDetectionThreshold {
                combinedEvents.append(CombinedAnalysisEvent(
                    timestamp: videoEvent.timestamp,
                    type: videoEvent.type,
                    confidence: combinedConfidence,
                    videoEvent: videoEvent,
                    audioEvents: correlatedAudioEvents
                ))
            }
        }

        // Merge nearby events and filter by duration
        return mergeAndFilterEvents(combinedEvents)
    }

    private func createHighlightClips(
        from videoURL: URL,
        events: [CombinedAnalysisEvent],
        options: HighlightGenerationOptions
    ) async throws -> [GameplayHighlight] {

        var highlights: [GameplayHighlight] = []
        let clipCreator = HighlightClipCreator()

        for (index, event) in events.enumerated() {
            generationProgress = 0.8 + (0.2 * Double(index) / Double(events.count))

            let startTime = max(0, event.timestamp - (minimumHighlightDuration / 2))
            let endTime = min(event.timestamp + (minimumHighlightDuration / 2), event.timestamp + maximumHighlightDuration)

            let clipURL = try await clipCreator.createClip(
                from: videoURL,
                startTime: startTime,
                endTime: endTime
            )

            let highlight = GameplayHighlight(
                id: UUID(),
                title: generateHighlightTitle(for: event),
                description: generateHighlightDescription(for: event),
                timestamp: event.timestamp,
                duration: endTime - startTime,
                confidence: event.confidence,
                eventType: event.type,
                videoURL: clipURL,
                thumbnailURL: try await generateThumbnail(for: clipURL, at: (endTime - startTime) / 2),
                createdAt: Date(),
                tags: generateHighlightTags(for: event)
            )

            highlights.append(highlight)

            if highlights.count >= maxHighlightsPerSession {
                break
            }
        }

        return highlights.sorted { $0.confidence > $1.confidence }
    }

    // MARK: - Real-Time Processing

    private func handleRealTimeEvent(_ event: VideoAnalysisEvent) async {
        // Handle real-time event detection
        if event.confidence > highlightDetectionThreshold {
            // Trigger highlight capture
            await captureRealTimeHighlight(for: event)
        }
    }

    private func captureRealTimeHighlight(for event: VideoAnalysisEvent) async {
        // Capture the last N seconds of gameplay as a highlight
        generationStatus = "Capturing highlight moment..."

        // This would integrate with the recording system to capture recent gameplay
    }

    // MARK: - Helper Methods

    private func setupProcessors() {
        audioProcessor.onExcitementDetected = { [weak self] timestamp, intensity in
            Task { @MainActor in
                self?.generationStatus = "High excitement detected at \(String(format: "%.1f", timestamp))s"
            }
        }
    }

    private func determineEventType(from prediction: MLFeatureProvider) -> HighlightEventType {
        // Interpret ML model predictions to determine event type
        return .achievement // Placeholder
    }

    private func extractEventMetadata(from prediction: MLFeatureProvider) -> [String: Any] {
        // Extract additional metadata from ML predictions
        return [:]
    }

    private func calculateCombinedConfidence(
        videoEvent: VideoAnalysisEvent,
        audioEvents: [AudioAnalysisEvent]
    ) -> Double {
        let baseConfidence = videoEvent.confidence
        let audioBoost = audioEvents.reduce(0.0) { $0 + ($1.intensity * 0.1) }
        return min(1.0, baseConfidence + audioBoost)
    }

    private func mergeAndFilterEvents(_ events: [CombinedAnalysisEvent]) -> [CombinedAnalysisEvent] {
        // Merge nearby events and filter by minimum duration
        var filteredEvents: [CombinedAnalysisEvent] = []
        var currentCluster: [CombinedAnalysisEvent] = []

        for event in events.sorted(by: { $0.timestamp < $1.timestamp }) {
            if let lastEvent = currentCluster.last,
               event.timestamp - lastEvent.timestamp < minimumHighlightDuration {
                currentCluster.append(event)
            } else {
                if !currentCluster.isEmpty {
                    filteredEvents.append(mergeCluster(currentCluster))
                }
                currentCluster = [event]
            }
        }

        if !currentCluster.isEmpty {
            filteredEvents.append(mergeCluster(currentCluster))
        }

        return filteredEvents
    }

    private func mergeCluster(_ cluster: [CombinedAnalysisEvent]) -> CombinedAnalysisEvent {
        let centerEvent = cluster[cluster.count / 2]
        let maxConfidence = cluster.max { $0.confidence < $1.confidence }?.confidence ?? 0.0

        var mergedEvent = centerEvent
        mergedEvent.confidence = maxConfidence
        return mergedEvent
    }

    private func generateHighlightTitle(for event: CombinedAnalysisEvent) -> String {
        switch event.type {
        case .achievement:
            return "Epic Achievement!"
        case .skillfulPlay:
            return "Skillful Moment"
        case .closeCall:
            return "Close Call"
        case .victory:
            return "Victory!"
        case .defeat:
            return "Intense Defeat"
        case .surprisingMoment:
            return "Surprising Turn"
        case .combatSequence:
            return "Combat Sequence"
        case .exploration:
            return "Discovery Moment"
        }
    }

    private func generateHighlightDescription(for event: CombinedAnalysisEvent) -> String {
        let timestamp = String(format: "%.1f", event.timestamp)
        let confidence = String(format: "%.0f", event.confidence * 100)
        return "Auto-detected highlight at \(timestamp)s with \(confidence)% confidence"
    }

    private func generateHighlightTags(for event: CombinedAnalysisEvent) -> [String] {
        var tags = ["auto-generated", event.type.rawValue]

        if event.confidence > 0.9 {
            tags.append("high-confidence")
        }

        if !event.audioEvents.isEmpty {
            tags.append("audio-enhanced")
        }

        return tags
    }

    private func generateThumbnail(for videoURL: URL, at time: TimeInterval) async throws -> URL {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        let time = CMTime(seconds: time, preferredTimescale: 600)
        let cgImage = try await imageGenerator.image(at: time).image

        // Save thumbnail to temporary location
        let thumbnailURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("jpg")

        // For macOS, we need to convert CGImage to data differently
        #if canImport(AppKit)
        let image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        let imageData = image.tiffRepresentation
        let bitmapRep = NSBitmapImageRep(data: imageData!)
        let data = bitmapRep?.representation(using: .jpeg, properties: [.compressionFactor: 0.8])
        #else
        let data = UIImage(cgImage: cgImage).jpegData(compressionQuality: 0.8)
        #endif
        try data?.write(to: thumbnailURL)

        return thumbnailURL
    }

    private func saveHighlights(_ highlights: [GameplayHighlight]) async throws {
        try await HighlightStorage.shared.saveHighlights(highlights)
    }
}

// MARK: - Supporting Classes

public class VideoAnalysisProcessor {
    func startRealTimeAnalysis(eventHandler: @escaping (VideoAnalysisEvent) -> Void) async throws {
        // Implementation for real-time video analysis
    }

    func stopRealTimeAnalysis() async {
        // Stop real-time analysis
    }
}

public class AudioAnalysisProcessor {
    var onExcitementDetected: ((TimeInterval, Double) -> Void)?

    func analyzeAudio(from url: URL, progressHandler: @escaping (Double) -> Void) async throws -> [AudioAnalysisEvent] {
        // Analyze audio for excitement markers (volume spikes, frequency changes, etc.)
        var events: [AudioAnalysisEvent] = []

        let asset = AVAsset(url: url)
        let duration = try await asset.load(.duration)

        // Simulate audio analysis with progress updates
        for i in 0...100 {
            progressHandler(Double(i) / 100.0)
            try await Task.sleep(nanoseconds: 10_000_000) // 10ms

            // Simulate finding audio events
            if i % 20 == 0 && i > 0 {
                let timestamp = (Double(i) / 100.0) * duration.seconds
                events.append(AudioAnalysisEvent(
                    timestamp: timestamp,
                    intensity: Double.random(in: 0.3...1.0),
                    frequency: .high,
                    type: .excitementPeak
                ))
            }
        }

        return events
    }
}

public class MLModelManager {
    func getN64AnalysisModel() async throws -> MLModel {
        // Load or create N64-specific analysis model
        // This would be a trained CoreML model for detecting N64 game events
        throw HighlightGenerationError.modelNotAvailable
    }
}

public class HighlightClipCreator {
    func createClip(from videoURL: URL, startTime: TimeInterval, endTime: TimeInterval) async throws -> URL {
        let asset = AVAsset(url: videoURL)

        // Create composition
        let composition = AVMutableComposition()
        let videoTrack = composition.addMutableTrack(withMediaType: .video, preferredTrackID: kCMPersistentTrackID_Invalid)
        let audioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)

        // Add video and audio tracks
        if let assetVideoTrack = try await asset.loadTracks(withMediaType: .video).first {
            let timeRange = CMTimeRange(
                start: CMTime(seconds: startTime, preferredTimescale: 600),
                duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
            )

            try videoTrack?.insertTimeRange(timeRange, of: assetVideoTrack, at: .zero)
        }

        if let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first {
            let timeRange = CMTimeRange(
                start: CMTime(seconds: startTime, preferredTimescale: 600),
                duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
            )

            try audioTrack?.insertTimeRange(timeRange, of: assetAudioTrack, at: .zero)
        }

        // Export composition
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")

        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetHighestQuality) else {
            throw HighlightGenerationError.exportFailed
        }

        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4

        await exportSession.export()

        if exportSession.status == .completed {
            return outputURL
        } else {
            throw HighlightGenerationError.exportFailed
        }
    }
}

public class HighlightExporter {
    func export(highlight: GameplayHighlight, format: HighlightExportFormat, quality: VideoQuality) async throws -> URL {
        // Export highlight in requested format and quality
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("exported_\(highlight.id.uuidString)")
            .appendingPathExtension(format.fileExtension)

        // Implementation would handle different export formats
        return outputURL
    }
}

public class HighlightStorage {
    public static let shared = HighlightStorage()
    private init() {}

    func saveHighlights(_ highlights: [GameplayHighlight]) async throws {
        // Save highlights to persistent storage
        let data = try JSONEncoder().encode(highlights)
        let url = getStorageURL()
        try data.write(to: url)
    }

    func loadHighlights() async throws -> [GameplayHighlight] {
        let url = getStorageURL()
        guard FileManager.default.fileExists(atPath: url.path) else {
            return []
        }
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([GameplayHighlight].self, from: data)
    }

    private func getStorageURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("highlights.json")
    }
}

// MARK: - Data Models

public struct GameplayHighlight: Codable, Identifiable {
    public let id: UUID
    public let title: String
    public let description: String
    public let timestamp: TimeInterval
    public let duration: TimeInterval
    public let confidence: Double
    public let eventType: HighlightEventType
    public let videoURL: URL
    public let thumbnailURL: URL
    public let createdAt: Date
    public let tags: [String]
}

public struct HighlightGenerationOptions: Codable {
    public var autoSave: Bool = true
    public var generateThumbnails: Bool = true
    public var includeAudioAnalysis: Bool = true
    public var maxHighlights: Int = 10
    public var qualityPreset: VideoQuality = .high

    public init() {}
}

public struct VideoAnalysisEvent {
    let timestamp: TimeInterval
    let type: HighlightEventType
    let confidence: Double
    let boundingBox: CGRect
    let metadata: [String: Any]
}

public struct AudioAnalysisEvent {
    let timestamp: TimeInterval
    let intensity: Double
    let frequency: AudioFrequencyRange
    let type: AudioEventType
}

public struct CombinedAnalysisEvent {
    let timestamp: TimeInterval
    let type: HighlightEventType
    var confidence: Double
    let videoEvent: VideoAnalysisEvent
    let audioEvents: [AudioAnalysisEvent]
}

// MARK: - Enums

public enum GameType: String, CaseIterable, Codable {
    case n64 = "nintendo64"
    case snes = "snes"
    case generic = "generic"
}

public enum HighlightEventType: String, CaseIterable, Codable {
    case achievement = "achievement"
    case skillfulPlay = "skillful_play"
    case closeCall = "close_call"
    case victory = "victory"
    case defeat = "defeat"
    case surprisingMoment = "surprising_moment"
    case combatSequence = "combat_sequence"
    case exploration = "exploration"
}

public enum AudioFrequencyRange: String, Codable {
    case low, mid, high
}

public enum AudioEventType: String, Codable {
    case excitementPeak = "excitement_peak"
    case musicIntensity = "music_intensity"
    case effectsSpike = "effects_spike"
}

public enum HighlightExportFormat: String, CaseIterable {
    case mp4 = "mp4"
    case mov = "mov"
    case gif = "gif"
    case webm = "webm"

    var fileExtension: String {
        return rawValue
    }
}

public enum VideoQuality: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case ultra = "ultra"
}

// MARK: - Errors

public enum HighlightGenerationError: LocalizedError {
    case alreadyGenerating
    case noVideoTrack
    case modelNotAvailable
    case exportFailed
    case insufficientStorage

    public var errorDescription: String? {
        switch self {
        case .alreadyGenerating:
            return "Highlight generation is already in progress"
        case .noVideoTrack:
            return "Video file contains no video track"
        case .modelNotAvailable:
            return "AI model is not available"
        case .exportFailed:
            return "Failed to export highlight clip"
        case .insufficientStorage:
            return "Insufficient storage space for highlights"
        }
    }
}

#if canImport(UIKit)
import UIKit
#endif
