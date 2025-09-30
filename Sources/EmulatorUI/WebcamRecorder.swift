import SwiftUI
import AVFoundation
import CoreImage

/// Webcam recorder for capturing user facecam during gameplay
@MainActor
public class WebcamRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPreviewVisible = false
    @Published var hasPermission = false
    @Published var availableCameras: [AVCaptureDevice] = []
    @Published var selectedCamera: AVCaptureDevice?
    @Published var previewImage: NSImage?

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var videoDelegate: WebcamVideoDelegate?
    private var assetWriter: AVAssetWriter?
    private var videoInput: AVAssetWriterInput?
    private var audioInput: AVAssetWriterInput?
    private var pixelBufferAdaptor: AVAssetWriterInputPixelBufferAdaptor?
    private var recordingURL: URL?
    private var startTime: CMTime = .invalid

    private let videoSettings: [String: Any] = [
        AVVideoCodecKey: AVVideoCodecType.h264,
        AVVideoWidthKey: 1280,
        AVVideoHeightKey: 720,
        AVVideoCompressionPropertiesKey: [
            AVVideoAverageBitRateKey: 2_500_000,
            AVVideoProfileLevelKey: AVVideoProfileLevelH264HighAutoLevel,
            AVVideoMaxKeyFrameIntervalKey: 60
        ]
    ]

    private let audioSettings: [String: Any] = [
        AVFormatIDKey: kAudioFormatMPEG4AAC,
        AVNumberOfChannelsKey: 2,
        AVSampleRateKey: 44100,
        AVEncoderBitRateKey: 128000
    ]

    override init() {
        super.init()
        Task {
            await checkPermissions()
            await refreshCameraList()
        }
    }

    /// Check and request camera permissions
    public func checkPermissions() async {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            hasPermission = true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            hasPermission = granted
        case .denied, .restricted:
            hasPermission = false
            print("Camera permission denied")
        @unknown default:
            hasPermission = false
        }
    }

    /// Refresh the list of available cameras
    public func refreshCameraList() async {
        guard hasPermission else { return }

        let discoverySession = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .externalUnknown],
            mediaType: .video,
            position: .unspecified
        )

        availableCameras = discoverySession.devices

        // Auto-select first camera if none selected
        if selectedCamera == nil, let firstCamera = availableCameras.first {
            selectedCamera = firstCamera
            await setupCaptureSession()
        }
    }

    /// Setup capture session for preview
    private func setupCaptureSession() async {
        guard let camera = selectedCamera else { return }

        captureSession = AVCaptureSession()
        captureSession?.beginConfiguration()

        // Set quality
        if captureSession?.canSetSessionPreset(.high) == true {
            captureSession?.sessionPreset = .high
        }

        // Add video input
        do {
            let videoInput = try AVCaptureDeviceInput(device: camera)
            if captureSession?.canAddInput(videoInput) == true {
                captureSession?.addInput(videoInput)
            }
        } catch {
            print("Failed to add video input: \(error)")
            return
        }

        // Add video output for preview
        videoOutput = AVCaptureVideoDataOutput()
        let delegate = WebcamVideoDelegate(owner: self)
        videoDelegate = delegate
        videoOutput?.setSampleBufferDelegate(delegate, queue: DispatchQueue(label: "webcam.preview"))
        videoOutput?.alwaysDiscardsLateVideoFrames = true

        if let videoOutput = videoOutput,
           captureSession?.canAddOutput(videoOutput) == true {
            captureSession?.addOutput(videoOutput)
        }

        captureSession?.commitConfiguration()

        // Start session for preview
        if isPreviewVisible {
            captureSession?.startRunning()
        }
    }

    /// Toggle webcam preview
    public func togglePreview() {
        isPreviewVisible.toggle()

        if isPreviewVisible {
            captureSession?.startRunning()
        } else {
            if !isRecording {
                captureSession?.stopRunning()
            }
        }
    }

    // MARK: - MainActor updaters (for delegate)
    public func handlePreviewImage(_ cgImage: CGImage) {
        guard isPreviewVisible else { return }
        previewImage = NSImage(cgImage: cgImage, size: NSSize(width: 320, height: 180))
    }

    public func handleSampleBuffer(_ sampleBuffer: CMSampleBuffer) {
        guard isRecording else { return }
        if startTime == .invalid { startTime = CMSampleBufferGetPresentationTimeStamp(sampleBuffer) }
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let time = CMSampleBufferGetPresentationTimeStamp(sampleBuffer)
            let adjustedTime = CMTimeSubtract(time, startTime)
            if pixelBufferAdaptor?.assetWriterInput.isReadyForMoreMediaData == true {
                pixelBufferAdaptor?.append(pixelBuffer, withPresentationTime: adjustedTime)
            }
        }
    }

    /// Start recording webcam
    public func startRecording() async throws {
        guard hasPermission else {
            throw RecordingError.noPermission
        }

        guard selectedCamera != nil else {
            throw RecordingError.noCameraSelected
        }

        // Setup output file
        let documentsPath = FileManager.default.urls(for: .moviesDirectory, in: .userDomainMask)[0]
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let filename = "WebcamRecording_\(dateFormatter.string(from: Date())).mp4"
        recordingURL = documentsPath.appendingPathComponent(filename)

        guard let recordingURL = recordingURL else { return }

        // Create asset writer
        assetWriter = try AVAssetWriter(outputURL: recordingURL, fileType: .mp4)

        // Setup video input
        videoInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        videoInput?.expectsMediaDataInRealTime = true

        // Setup pixel buffer adaptor
        let sourcePixelBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 1280,
            kCVPixelBufferHeightKey as String: 720
        ]

        pixelBufferAdaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: videoInput!,
            sourcePixelBufferAttributes: sourcePixelBufferAttributes
        )

        // Add audio input if microphone available
        if await checkMicrophonePermission() {
            audioInput = AVAssetWriterInput(mediaType: .audio, outputSettings: audioSettings)
            audioInput?.expectsMediaDataInRealTime = true
            assetWriter?.add(audioInput!)
        }

        if let videoInput = videoInput {
            assetWriter?.add(videoInput)
        }

        // Start capture session if not running
        if captureSession?.isRunning == false {
            captureSession?.startRunning()
        }

        // Start writing
        assetWriter?.startWriting()
        assetWriter?.startSession(atSourceTime: .zero)

        isRecording = true
        startTime = .invalid
    }

    /// Stop recording
    public func stopRecording() async {
        guard isRecording else { return }

        isRecording = false

        // Stop capture session if preview not visible
        if !isPreviewVisible {
            captureSession?.stopRunning()
        }

        // Finalize video file
        videoInput?.markAsFinished()
        audioInput?.markAsFinished()

        await assetWriter?.finishWriting()

        // Show recording saved notification
        if let url = recordingURL {
            print("Webcam recording saved to: \(url.path)")
        }
    }

    /// Check microphone permission
    private func checkMicrophonePermission() async -> Bool {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            return true
        case .notDetermined:
            return await AVCaptureDevice.requestAccess(for: .audio)
        default:
            return false
        }
    }

    enum RecordingError: Error {
        case noCameraSelected
        case noPermission
        case writingFailed
    }
}

// MARK: - Video Capture Delegate (off-main to satisfy Swift 6 isolation)
final class WebcamVideoDelegate: NSObject, AVCaptureVideoDataOutputSampleBufferDelegate {
    weak var owner: WebcamRecorder?
    init(owner: WebcamRecorder) { self.owner = owner }

    func captureOutput(_ output: AVCaptureOutput,
                       didOutput sampleBuffer: CMSampleBuffer,
                       from connection: AVCaptureConnection) {
        guard let owner = owner else { return }

        if let imageBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let ciImage = CIImage(cvImageBuffer: imageBuffer)
            let context = CIContext()
            if let cgImage = context.createCGImage(ciImage, from: ciImage.extent) {
                Task { @MainActor in owner.handlePreviewImage(cgImage) }
            }
        }
        Task { @MainActor in owner.handleSampleBuffer(sampleBuffer) }
    }
}

/// Webcam preview and controls view
public struct WebcamView: View {
    @StateObject private var webcam = WebcamRecorder()
    @State private var showSettings = false

    public init() {}

    public var body: some View {
        VStack(spacing: 0) {
            // Preview window
            if webcam.isPreviewVisible {
                ZStack {
                    if let image = webcam.previewImage {
                        Image(nsImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                    } else {
                        Rectangle()
                            .fill(Color.black)
                            .overlay(
                                Text("Loading camera...")
                                    .foregroundColor(.white)
                            )
                    }

                    // Recording indicator
                    if webcam.isRecording {
                        HStack {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 10, height: 10)
                            Text("REC")
                                .font(.caption)
                                .foregroundColor(.white)
                        }
                        .padding(DesignSystem.Spacing.sm)
                        .background(Color.black.opacity(0.5))
                        .cornerRadius(DesignSystem.Radius.sm)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                        .padding(DesignSystem.Spacing.sm)
                    }
                }
                .frame(width: 320, height: 180)
                .background(Color.black)
                .cornerRadius(DesignSystem.Radius.lg)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                )
            }

            // Controls
            HStack(spacing: DesignSystem.Spacing.md) {
                // Camera selector
                Menu {
                    ForEach(webcam.availableCameras, id: \.uniqueID) { camera in
                        Button(action: {
                            webcam.selectedCamera = camera
                            Task { await webcam.refreshCameraList() }
                        }) {
                            HStack {
                                Text(camera.localizedName)
                                if webcam.selectedCamera?.uniqueID == camera.uniqueID {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "camera")
                        Text(webcam.selectedCamera?.localizedName ?? "Select Camera")
                            .lineLimit(1)
                    }
                }
                .menuStyle(.borderlessButton)

                // Preview toggle
                Button(action: { webcam.togglePreview() }) {
                    Image(systemName: webcam.isPreviewVisible ? "eye.slash" : "eye")
                }
                .help(webcam.isPreviewVisible ? "Hide Preview" : "Show Preview")

                // Record button
                Button(action: toggleRecording) {
                    Image(systemName: webcam.isRecording ? "stop.circle.fill" : "record.circle")
                        .foregroundColor(webcam.isRecording ? .red : .primary)
                }
                .help(webcam.isRecording ? "Stop Recording" : "Start Recording")

                // Settings
                Button(action: { showSettings.toggle() }) {
                    Image(systemName: "gear")
                }
            }
            .padding(DesignSystem.Spacing.sm)

            // Permission status
            if !webcam.hasPermission {
                Button("Grant Camera Permission") {
                    Task { await webcam.checkPermissions() }
                }
                .buttonStyle(.bordered)
                .foregroundColor(.orange)
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
        .cornerRadius(DesignSystem.Radius.xxl)
    }

    private func toggleRecording() {
        Task {
            if webcam.isRecording {
                await webcam.stopRecording()
            } else {
                do {
                    try await webcam.startRecording()
                } catch {
                    print("Failed to start webcam recording: \(error)")
                }
            }
        }
    }
}

/// Simple webcam button for toolbar
public struct WebcamButton: View {
    @StateObject private var webcam = WebcamRecorder()
    @State private var showWebcamPopover = false
    @State private var showPermissionAlert = false

    public init() {}

    public var body: some View {
        Button(action: handleWebcamClick) {
            Image(systemName: webcam.isRecording ? "video.fill" : "video")
                .foregroundColor(webcam.isRecording ? .red : .primary)
        }
        .help("Webcam")
        .popover(isPresented: $showWebcamPopover) {
            WebcamView()
                .frame(width: 360, height: 300)
        }
        .alert("Camera Permission Required", isPresented: $showPermissionAlert) {
            Button("Open System Preferences") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please grant camera permission to Nintendo Emulator in System Preferences > Security & Privacy > Camera")
        }
        .task {
            await webcam.checkPermissions()
            await webcam.refreshCameraList()
        }
    }

    private func handleWebcamClick() {
        Task {
            await webcam.checkPermissions()
            if !webcam.hasPermission {
                showPermissionAlert = true
            } else {
                showWebcamPopover.toggle()
            }
        }
    }
}
