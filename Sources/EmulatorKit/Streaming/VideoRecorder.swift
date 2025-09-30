import Foundation
import AVFoundation
import AppKit
import CoreMedia
import os.log

/// Simple video recorder for capturing gameplay
@MainActor
public class VideoRecorder: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isRecording = false
    @Published public private(set) var recordingDuration: TimeInterval = 0
    @Published public private(set) var outputURL: URL?

    // MARK: - Private Properties

    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var startTime: Date?
    private var recordingTimer: Timer?
    private let logger = Logger(subsystem: "com.emulator", category: "VideoRecorder")

    // MARK: - Configuration

    public var videoSize = CGSize(width: 1920, height: 1080)
    public var frameRate: Int32 = 60
    public var videoBitrate: Int = 8_000_000 // 8 Mbps

    // MARK: - Initialization

    public init() {}

    // MARK: - Recording Controls

    /// Start recording gameplay
    public func startRecording(windowName: String = "NintendoEmulator") async throws {
        guard !isRecording else {
            logger.warning("Already recording")
            return
        }

        // Create output file
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let recordingsDir = documentsPath.appendingPathComponent("Recordings")
        try? FileManager.default.createDirectory(at: recordingsDir, withIntermediateDirectories: true)

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = dateFormatter.string(from: Date())
        let fileName = "Gameplay_\(timestamp).mp4"
        outputURL = recordingsDir.appendingPathComponent(fileName)

        guard let outputURL = outputURL else {
            throw RecordingError.failedToCreateFile
        }

        // Remove existing file if present
        try? FileManager.default.removeItem(at: outputURL)

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)

        // Configure video settings
        let videoSettings: [String: Any] = [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: videoSize.width,
            AVVideoHeightKey: videoSize.height,
            AVVideoCompressionPropertiesKey: [
                AVVideoAverageBitRateKey: videoBitrate,
                AVVideoMaxKeyFrameIntervalKey: frameRate * 2,
                AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel
            ]
        ]

        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        guard let videoInput = videoInput,
              let assetWriter = assetWriter,
              assetWriter.canAdd(videoInput) else {
            throw RecordingError.failedToConfigureWriter
        }

        assetWriter.add(videoInput)

        // Start writing
        guard assetWriter.startWriting() else {
            throw RecordingError.failedToStartWriting(assetWriter.error?.localizedDescription ?? "Unknown error")
        }

        assetWriter.startSession(atSourceTime: .zero)

        // Update state
        isRecording = true
        startTime = Date()
        recordingDuration = 0

        // Start screen capture
        try await startScreenCapture()

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                if let startTime = self?.startTime {
                    self?.recordingDuration = Date().timeIntervalSince(startTime)
                }
            }
        }

        logger.info("✅ Recording started: \(fileName)")
        NSLog("🎥 Recording started: \(fileName)")
    }

    /// Stop recording and finalize video file
    public func stopRecording() async throws -> URL? {
        guard isRecording else {
            logger.warning("Not currently recording")
            return nil
        }

        isRecording = false
        recordingTimer?.invalidate()
        recordingTimer = nil

        // Stop capture
        await stopScreenCapture()

        // Finalize video input
        videoInput?.markAsFinished()

        // Finalize asset writer
        guard let assetWriter = assetWriter else {
            throw RecordingError.writerNotInitialized
        }

        await assetWriter.finishWriting()

        let finalURL = outputURL

        // Cleanup
        self.assetWriter = nil
        self.videoInput = nil
        self.startTime = nil

        logger.info("✅ Recording stopped: \(finalURL?.lastPathComponent ?? "unknown")")
        NSLog("🎥 Recording saved: \(finalURL?.path ?? "unknown")")

        // Reveal in Finder
        if let url = finalURL {
            NSWorkspace.shared.activateFileViewerSelecting([url])
        }

        return finalURL
    }

    // MARK: - Screen Capture

    private var displayStream: CGDisplayStream?
    private var frameCount: Int64 = 0

    private func startScreenCapture() async throws {
        // Get main display
        let displayID = CGMainDisplayID()

        // Create display stream
        let stream = CGDisplayStream(
            dispatchQueueDisplay: displayID,
            outputWidth: Int(videoSize.width),
            outputHeight: Int(videoSize.height),
            pixelFormat: Int32(kCVPixelFormatType_32BGRA),
            properties: [:] as CFDictionary,
            queue: DispatchQueue.global(qos: .userInitiated)
        ) { [weak self] status, displayTime, frameSurface, updateRef in
            guard status == .frameComplete,
                  let surface = frameSurface else { return }

            Task { @MainActor [weak self] in
                await self?.processFrame(surface: surface, displayTime: displayTime)
            }
        }

        guard let stream = stream else {
            throw RecordingError.failedToCreateDisplayStream
        }

        displayStream = stream

        // Start capture
        let result = stream.start()
        guard case .success = result else {
            throw RecordingError.failedToStartCapture
        }

        logger.info("Screen capture started")
    }

    private func stopScreenCapture() async {
        displayStream?.stop()
        displayStream = nil
        logger.info("Screen capture stopped")
    }

    private func processFrame(surface: IOSurface, displayTime: UInt64) async {
        guard isRecording,
              let videoInput = videoInput,
              videoInput.isReadyForMoreMediaData else { return }

        // Create pixel buffer from surface
        var unmanagedPixelBuffer: Unmanaged<CVPixelBuffer>?
        let status = CVPixelBufferCreateWithIOSurface(
            kCFAllocatorDefault,
            surface,
            nil,
            &unmanagedPixelBuffer
        )

        guard status == kCVReturnSuccess,
              let pixelBuffer = unmanagedPixelBuffer?.takeRetainedValue() else { return }

        let buffer = pixelBuffer

        // Create sample buffer
        let presentationTime = CMTime(value: frameCount, timescale: frameRate)
        frameCount += 1

        var timingInfo = CMSampleTimingInfo(
            duration: CMTime(value: 1, timescale: frameRate),
            presentationTimeStamp: presentationTime,
            decodeTimeStamp: .invalid
        )

        var formatDescription: CMFormatDescription?
        CMVideoFormatDescriptionCreateForImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescriptionOut: &formatDescription
        )

        guard let formatDesc = formatDescription else { return }

        var sampleBuffer: CMSampleBuffer?
        CMSampleBufferCreateReadyWithImageBuffer(
            allocator: kCFAllocatorDefault,
            imageBuffer: buffer,
            formatDescription: formatDesc,
            sampleTiming: &timingInfo,
            sampleBufferOut: &sampleBuffer
        )

        guard let sample = sampleBuffer else { return }

        // Append to video input
        videoInput.append(sample)
    }

    // MARK: - Public Helpers

    public func toggleRecording() async throws -> Bool {
        if isRecording {
            _ = try await stopRecording()
            return false
        } else {
            try await startRecording()
            return true
        }
    }

    public var recordingTimeFormatted: String {
        let minutes = Int(recordingDuration) / 60
        let seconds = Int(recordingDuration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Supporting Types

public enum RecordingError: LocalizedError {
    case failedToCreateFile
    case failedToConfigureWriter
    case failedToStartWriting(String)
    case writerNotInitialized
    case failedToCreateDisplayStream
    case failedToStartCapture

    public var errorDescription: String? {
        switch self {
        case .failedToCreateFile:
            return "Failed to create recording file"
        case .failedToConfigureWriter:
            return "Failed to configure video writer"
        case .failedToStartWriting(let reason):
            return "Failed to start writing: \(reason)"
        case .writerNotInitialized:
            return "Video writer not initialized"
        case .failedToCreateDisplayStream:
            return "Failed to create display stream"
        case .failedToStartCapture:
            return "Failed to start screen capture"
        }
    }
}