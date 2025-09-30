import SwiftUI
import AVFoundation
import AppKit
import EmulatorKit

/// Professional streaming webcam overlay with GhostBridge integration
/// Provides picture-in-picture webcam view for streamers
@MainActor
public class StreamingWebcamManager: NSObject, ObservableObject {
    @Published public var isWebcamEnabled = false
    @Published public var webcamPosition: WebcamPosition = .bottomRight
    @Published public var webcamSize: WebcamSize = .medium
    @Published public var webcamOpacity: Double = 1.0
    @Published public var showBorder: Bool = true
    @Published public var borderColor: Color = .white
    @Published public var cornerRadius: CGFloat = 12
    @Published public var webcamImage: NSImage?
    @Published public var isRecording = false

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var updateTimer: Timer?
    private let videoQueue = DispatchQueue(label: "webcam.video.queue")

    public enum WebcamPosition: String, CaseIterable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"
        case center = "Center"

        var alignment: Alignment {
            switch self {
            case .topLeft: return .topLeading
            case .topRight: return .topTrailing
            case .bottomLeft: return .bottomLeading
            case .bottomRight: return .bottomTrailing
            case .center: return .center
            }
        }

        var offset: CGPoint {
            switch self {
            case .topLeft: return CGPoint(x: 20, y: 20)
            case .topRight: return CGPoint(x: -20, y: 20)
            case .bottomLeft: return CGPoint(x: 20, y: -20)
            case .bottomRight: return CGPoint(x: -20, y: -20)
            case .center: return CGPoint(x: 0, y: 0)
            }
        }
    }

    public enum WebcamSize: String, CaseIterable {
        case small = "Small"
        case medium = "Medium"
        case large = "Large"
        case extraLarge = "Extra Large"

        var dimensions: CGSize {
            switch self {
            case .small: return CGSize(width: 120, height: 90)
            case .medium: return CGSize(width: 180, height: 135)
            case .large: return CGSize(width: 240, height: 180)
            case .extraLarge: return CGSize(width: 320, height: 240)
            }
        }
    }

    public override init() {
        super.init()
        setupWebcam()
    }

    deinit {
        // Clean up capture session on deinit
        captureSession?.stopRunning()
        captureSession = nil
    }

    // MARK: - Webcam Control

    public func toggleWebcam() {
        isWebcamEnabled.toggle()
        if isWebcamEnabled {
            startWebcam()
        } else {
            stopWebcam()
        }
    }

    public func startWebcam() {
        guard !isWebcamEnabled else { return }

        // Check camera permission first
        checkCameraPermission { [weak self] granted in
            DispatchQueue.main.async {
                if granted {
                    self?.setupCaptureSession()
                    self?.isWebcamEnabled = true
                } else {
                    // Show permission alert
                    self?.showCameraPermissionAlert()
                }
            }
        }
    }

    public func stopWebcam() {
        isWebcamEnabled = false
        captureSession?.stopRunning()
        updateTimer?.invalidate()
        updateTimer = nil
    }

    public func startStreamingMode() {
        // Enhanced mode for streaming with GhostBridge integration
        Task {
            if await GhostBridgeHelper.prepareForStreaming() {
                isRecording = true
                startWebcam()
                // Notify that streaming is ready
                NotificationCenter.default.post(name: .streamingWebcamReady, object: nil)
            } else {
                // Show permissions needed
                GhostBridgeHelper.openAllPermissions()
            }
        }
    }

    // MARK: - Private Methods

    private func setupWebcam() {
        // Initial setup
    }

    private func checkCameraPermission(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { granted in
                completion(granted)
            }
        case .denied, .restricted:
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    private func setupCaptureSession() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium

        guard let videoDevice = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            print("No front camera available")
            return
        }

        do {
            let videoInput = try AVCaptureDeviceInput(device: videoDevice)
            guard captureSession?.canAddInput(videoInput) == true else { return }
            captureSession?.addInput(videoInput)

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: videoQueue)

            guard captureSession?.canAddOutput(videoOutput!) == true else { return }
            captureSession?.addOutput(videoOutput!)

            captureSession?.startRunning()

        } catch {
            print("Error setting up camera: \(error)")
        }
    }

    private func showCameraPermissionAlert() {
        let alert = NSAlert()
        alert.messageText = "Camera Permission Required"
        alert.informativeText = "Please allow camera access in System Preferences > Privacy & Security > Camera to use webcam overlay for streaming."
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "Cancel")

        if alert.runModal() == .alertFirstButtonReturn {
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera")!)
        }
    }
}

// MARK: - Video Capture Delegate
extension StreamingWebcamManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        Task { @MainActor in
            self.webcamImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
}

// MARK: - SwiftUI Views

/// Professional webcam overlay for streaming
public struct StreamingWebcamOverlay: View {
    @ObservedObject public var webcamManager: StreamingWebcamManager
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero

    public init(webcamManager: StreamingWebcamManager) {
        self.webcamManager = webcamManager
    }

    public var body: some View {
        if webcamManager.isWebcamEnabled, let webcamImage = webcamManager.webcamImage {
            webcamView(image: webcamImage)
                .frame(
                    width: webcamManager.webcamSize.dimensions.width,
                    height: webcamManager.webcamSize.dimensions.height
                )
                .position(
                    x: webcamManager.webcamPosition.offset.x + dragOffset.width,
                    y: webcamManager.webcamPosition.offset.y + dragOffset.height
                )
                .opacity(webcamManager.webcamOpacity)
                .scaleEffect(isDragging ? 1.05 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
                .gesture(dragGesture)
        }
    }

    private func webcamView(image: NSImage) -> some View {
        Image(nsImage: image)
            .resizable()
            .aspectRatio(contentMode: .fill)
            .clipShape(RoundedRectangle(cornerRadius: webcamManager.cornerRadius))
            .overlay(
                RoundedRectangle(cornerRadius: webcamManager.cornerRadius)
                    .stroke(webcamManager.showBorder ? webcamManager.borderColor : Color.clear, lineWidth: 2)
            )
            .overlay(
                // Recording indicator
                Group {
                    if webcamManager.isRecording {
                        Circle()
                            .fill(Color.red)
                            .frame(width: 12, height: 12)
                            .overlay(
                                Circle()
                                    .stroke(Color.white, lineWidth: 1)
                            )
                            .position(x: 20, y: 20)
                            .opacity(0.8)
                    }
                }
            )
            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                isDragging = true
                dragOffset = value.translation
            }
            .onEnded { _ in
                isDragging = false
                // Snap to nearest corner
                withAnimation(.spring()) {
                    dragOffset = .zero
                }
            }
    }
}

/// Webcam controls panel for streaming setup
public struct WebcamControlPanel: View {
    @ObservedObject public var webcamManager: StreamingWebcamManager

    public init(webcamManager: StreamingWebcamManager) {
        self.webcamManager = webcamManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
            // Header with streaming indicator
            HStack {
                Image(systemName: webcamManager.isRecording ? "record.circle.fill" : "video.circle")
                    .foregroundColor(webcamManager.isRecording ? .red : .secondary)
                    .font(.title2)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Webcam Overlay")
                        .font(.headline)

                    Text(webcamManager.isRecording ? "LIVE" : "Ready")
                        .font(.caption)
                        .foregroundColor(webcamManager.isRecording ? .red : .secondary)
                }

                Spacer()

                // Main toggle
                Button(action: webcamManager.toggleWebcam) {
                    Image(systemName: webcamManager.isWebcamEnabled ? "video.fill" : "video.slash")
                        .font(.title2)
                }
                .buttonStyle(.borderless)
            }

            if webcamManager.isWebcamEnabled {
                Divider()

                // Position control
                HStack {
                    Text("Position:")
                        .font(.subheadline)
                    Picker("", selection: $webcamManager.webcamPosition) {
                        ForEach(StreamingWebcamManager.WebcamPosition.allCases, id: \.self) { position in
                            Text(position.rawValue).tag(position)
                        }
                    }
                    .pickerStyle(.menu)
                }

                // Size control
                HStack {
                    Text("Size:")
                        .font(.subheadline)
                    Picker("", selection: $webcamManager.webcamSize) {
                        ForEach(StreamingWebcamManager.WebcamSize.allCases, id: \.self) { size in
                            Text(size.rawValue).tag(size)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                // Opacity control
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Opacity: \(Int(webcamManager.webcamOpacity * 100))%")
                        .font(.subheadline)
                    Slider(value: $webcamManager.webcamOpacity, in: 0.3...1.0)
                        .controlSize(.small)
                }

                // Style controls
                HStack {
                    Toggle("Border", isOn: $webcamManager.showBorder)
                        .controlSize(.small)

                    if webcamManager.showBorder {
                        ColorPicker("", selection: $webcamManager.borderColor)
                            .frame(width: 30)
                    }
                }

                Divider()

                // Streaming controls
                HStack {
                    Button("Start Streaming Mode") {
                        webcamManager.startStreamingMode()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(webcamManager.isRecording)

                    Spacer()

                    if webcamManager.isRecording {
                        Button("Stop") {
                            webcamManager.isRecording = false
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding()
        .frame(maxWidth: 300)
    }
}

// MARK: - Notification Names
public extension Notification.Name {
    static let streamingWebcamReady = Notification.Name("StreamingWebcamReady")
    static let streamingWebcamStopped = Notification.Name("StreamingWebcamStopped")
}