import SwiftUI
import AVFoundation
import ScreenCaptureKit
import Combine

/// Game window recorder for capturing mupen64plus gameplay
@MainActor
public class GameRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPaused = false
    @Published var recordingDuration: TimeInterval = 0
    @Published var hasPermission = false
    @Published var availableWindows: [SCWindow] = []
    @Published var selectedWindow: SCWindow?
    @Published var recordingURL: URL?

    private var stream: SCStream?
    private var streamOutput: StreamOutput?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var startTime: Date?
    private var timer: Timer?

    private let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 1920,
        AVVideoHeightKey: 1080,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 6_000_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: 60
        ]
    ]

    private let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 48000,
        AVEncoderBitRateKey: 128000
    ]

    override init() {
        super.init()
        Task {
            await checkPermissions()
            await refreshWindowList()
        }
    }

    /// Check and request screen recording permissions
    public func checkPermissions() async {
        do {
            try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)
            hasPermission = true
        } catch {
            hasPermission = false
            print("Screen recording permission denied: \(error)")
        }
    }

    /// Refresh the list of available windows
    public func refreshWindowList() async {
        guard hasPermission else { return }

        do {
            let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: true)

            // Filter for game windows (mupen64plus or Glide64)
            let gameWindows = content.windows.filter { window in
                let appName = window.owningApplication?.applicationName ?? ""
                let title = window.title ?? ""
                return appName.contains("mupen64plus") ||
                       appName.contains("Glide64") ||
                       title.contains("Mupen64Plus") ||
                       title.contains("Glide64")
            }

            await MainActor.run {
                self.availableWindows = gameWindows.isEmpty ? content.windows : gameWindows

                // Auto-select game window if found
                if selectedWindow == nil, let gameWindow = gameWindows.first {
                    self.selectedWindow = gameWindow
                }
            }
        } catch {
            print("Failed to get windows: \(error)")
        }
    }

    /// Start recording the selected window
    public func startRecording() async throws {
        guard let window = selectedWindow else {
            throw RecordingError.noWindowSelected
        }

        guard hasPermission else {
            throw RecordingError.noPermission
        }

        // Setup output file
        let documentsPath = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "GameRecording_\(dateFormatter.string(from: Date())).mp4"
        recordingURL = documentsPath.appendingPathComponent(filename)

        guard let recordingURL = recordingURL else { return }

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: recordingURL, fileType: .mp4)

        // Setup video input
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        // Setup audio input
        audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
        audioInput?.expectsMediaDataInRealTime = true

        if let videoInput = videoInput, let audioInput = audioInput {
            assetWriter?.add(videoInput)
            assetWriter?.add(audioInput)
        }

        // Configure stream
        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()

        // Set quality settings
        config.width = Int(window.frame.width) * 2  // Retina resolution
        config.height = Int(window.frame.height) * 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 60) // 60 FPS
        config.queueDepth = 5
        config.showsCursor = true
        config.capturesAudio = true
        config.sampleRate = 48000
        config.channelCount = 2

        // Create stream
        stream = SCStream(filter: filter, configuration: config, delegate: nil)

        // Setup output handler
        streamOutput = StreamOutput(videoInput: videoInput, audioInput: audioInput)

        if let stream = stream, let streamOutput = streamOutput {
            try stream.addStreamOutput(streamOutput, type: .screen, sampleHandlerQueue: DispatchQueue(label: "recording.queue"))

            // Start recording
            assetWriter?.startWriting()
            assetWriter?.startSession(atSourceTime: .zero)

            try await stream.startCapture()

            isRecording = true
            startTime = Date()

            // Start duration timer
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
                Task { @MainActor in
                    guard let self = self, let startTime = self.startTime else { return }
                    self.recordingDuration = Date().timeIntervalSince(startTime)
                }
            }
        }
    }

    /// Stop recording
    public func stopRecording() async {
        guard isRecording else { return }

        timer?.invalidate()
        timer = nil

        if let stream = stream {
            do {
                try await stream.stopCapture()
            } catch {
                print("Error stopping capture: \(error)")
            }
        }

        // Finalize video file
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter?.finishWriting()

        isRecording = false
        recordingDuration = 0

        // Show recording saved notification
        if let url = recordingURL {
            print("Recording saved to: \(url.path)")
        }
    }

    /// Pause/resume recording
    public func togglePause() {
        isPaused.toggle()
        // Implementation for pause/resume
    }

    enum RecordingError: Error {
        case noWindowSelected
        case noPermission
        case writingFailed
    }
}

/// Stream output handler
private class StreamOutput: NSObject, SCStreamOutput {
    private let videoInput: AVAssetWriterInput?
    private let audioInput: AVAssetWriterInput?
    private var firstSampleTime: CMTime = .invalid

    init(videoInput: AVAssetWriterInput?, audioInput: AVAssetWriterInput?) {
        self.videoInput = videoInput
        self.audioInput = audioInput
    }

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard sampleBuffer.isValid else { return }

        // Record first sample time for synchronization
        if firstSampleTime == .invalid {
            firstSampleTime = sampleBuffer.presentationTimeStamp
        }

        // Adjust timestamps
        let adjustedBuffer = adjustTimestamp(sampleBuffer: sampleBuffer)

        switch type {
        case .screen:
            if let videoInput = videoInput, videoInput.isReadyForMoreMediaData {
                videoInput.append(adjustedBuffer)
            }
        case .audio, .microphone:
            if let audioInput = audioInput, audioInput.isReadyForMoreMediaData {
                audioInput.append(adjustedBuffer)
            }
        @unknown default:
            break
        }
    }

    private func adjustTimestamp(sampleBuffer: CMSampleBuffer) -> CMSampleBuffer {
        // Adjust timestamps to start from zero
        guard firstSampleTime != .invalid else { return sampleBuffer }

        var timingInfo = CMSampleTimingInfo()
        timingInfo.duration = sampleBuffer.duration
        timingInfo.presentationTimeStamp = sampleBuffer.presentationTimeStamp - firstSampleTime
        timingInfo.decodeTimeStamp = .invalid

        var adjustedBuffer: CMSampleBuffer?
        CMSampleBufferCreateCopyWithNewTiming(
            allocator: nil,
            sampleBuffer: sampleBuffer,
            sampleTimingEntryCount: 1,
            sampleTimingArray: &timingInfo,
            sampleBufferOut: &adjustedBuffer
        )

        return adjustedBuffer ?? sampleBuffer
    }
}

/// Recording controls view
public struct RecordingControlsView: View {
    @StateObject private var recorder = GameRecorder()
    @State private var showWindowPicker = false

    public init() {}

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.md) {
            // Record button
            Button(action: toggleRecording) {
                Image(systemName: recorder.isRecording ? "stop.circle.fill" : "record.circle")
                    .foregroundColor(recorder.isRecording ? .red : .white)
                    .font(.title2)
            }
            .buttonStyle(.plain)
            .help(recorder.isRecording ? "Stop Recording" : "Start Recording")

            if recorder.isRecording {
                // Recording indicator
                HStack(spacing: DesignSystem.Spacing.xs) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 8, height: 8)
                        .opacity(recorder.isRecording ? 1.0 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(), value: recorder.isRecording)

                    Text("REC")
                        .font(.caption)
                        .foregroundColor(.red)

                    Text(timeString(recorder.recordingDuration))
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                }

                // Pause button
                Button(action: { recorder.togglePause() }) {
                    Image(systemName: recorder.isPaused ? "play.fill" : "pause.fill")
                        .foregroundColor(.white)
                }
                .buttonStyle(.plain)
            } else {
                // Window selector
                Menu {
                    Button("Refresh Windows") {
                        Task { await recorder.refreshWindowList() }
                    }

                    Divider()

                    ForEach(recorder.availableWindows, id: \.windowID) { window in
                        Button(action: { recorder.selectedWindow = window }) {
                            HStack {
                                Text(window.title ?? "Unknown Window")
                                if recorder.selectedWindow?.windowID == window.windowID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "macwindow")
                        Text(recorder.selectedWindow?.title ?? "Select Window")
                            .lineLimit(1)
                    }
                    .foregroundColor(.white)
                }
                .menuStyle(.borderlessButton)
            }

            // Permission status
            if !recorder.hasPermission {
                Button("Grant Permission") {
                    Task { await recorder.checkPermissions() }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.black.opacity(0.8))
        .cornerRadius(DesignSystem.Radius.lg)
        .task {
            await recorder.checkPermissions()
            await recorder.refreshWindowList()
        }
    }

    private func toggleRecording() {
        Task {
            if recorder.isRecording {
                await recorder.stopRecording()
            } else {
                do {
                    try await recorder.startRecording()
                } catch {
                    print("Failed to start recording: \(error)")
                }
            }
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let hours = Int(time) / 3600
        let minutes = Int(time) / 60 % 60
        let seconds = Int(time) % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
        }
    }
}