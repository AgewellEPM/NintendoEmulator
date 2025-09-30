import SwiftUI
import AVFoundation
import AppKit
import EmulatorKit

/// Picture-in-Picture webcam overlay manager
@MainActor
public class PiPManager: NSObject, ObservableObject {
    @Published var isPiPEnabled = false
    @Published var pipPosition: PiPPosition = .topLeft
    @Published var pipSize: PiPSize = .small
    @Published var pipOpacity: Double = 1.0
    @Published var isFullscreen = false
    @Published var webcamImage: NSImage?

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private var updateTimer: Timer?

    enum PiPPosition: String, CaseIterable {
        case topLeft = "Top Left"
        case topRight = "Top Right"
        case bottomLeft = "Bottom Left"
        case bottomRight = "Bottom Right"

        var alignment: Alignment {
            switch self {
            case .topLeft: return .topLeading
            case .topRight: return .topTrailing
            case .bottomLeft: return .bottomLeading
            case .bottomRight: return .bottomTrailing
            }
        }

        var offset: CGSize {
            switch self {
            case .topLeft: return CGSize(width: 20, height: 20)
            case .topRight: return CGSize(width: -20, height: 20)
            case .bottomLeft: return CGSize(width: 20, height: -20)
            case .bottomRight: return CGSize(width: -20, height: -20)
            }
        }
    }

    enum PiPSize: String, CaseIterable {
        case tiny = "Tiny"
        case small = "Small"
        case medium = "Medium"
        case large = "Large"

        var dimensions: CGSize {
            switch self {
            case .tiny: return CGSize(width: 120, height: 90)
            case .small: return CGSize(width: 180, height: 135)
            case .medium: return CGSize(width: 240, height: 180)
            case .large: return CGSize(width: 320, height: 240)
            }
        }
    }

    public override init() {
        super.init()
    }

    /// Toggle PiP mode
    public func togglePiP() {
        isPiPEnabled.toggle()
        if isPiPEnabled {
            startWebcamCapture()
        } else {
            stopWebcamCapture()
        }
    }

    /// Toggle fullscreen mode
    public func toggleFullscreen() {
        isFullscreen.toggle()

        if isFullscreen {
            // Enter fullscreen
            if let window = NSApp.keyWindow {
                window.toggleFullScreen(nil)
            }
        } else {
            // Exit fullscreen
            if let window = NSApp.keyWindow {
                window.toggleFullScreen(nil)
            }
        }
    }

    /// Start webcam capture
    private func startWebcamCapture() {
        captureSession = AVCaptureSession()
        captureSession?.sessionPreset = .medium

        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera,
                                                   for: .video,
                                                   position: .front) else {
            print("No camera available")
            return
        }

        do {
            let input = try AVCaptureDeviceInput(device: camera)
            captureSession?.addInput(input)

            videoOutput = AVCaptureVideoDataOutput()
            videoOutput?.setSampleBufferDelegate(self, queue: DispatchQueue(label: "pip.webcam"))

            if let output = videoOutput {
                captureSession?.addOutput(output)
            }

            captureSession?.startRunning()
        } catch {
            print("Failed to setup camera: \(error)")
        }
    }

    /// Stop webcam capture
    private func stopWebcamCapture() {
        captureSession?.stopRunning()
        captureSession = nil
        videoOutput = nil
        webcamImage = nil
    }
}

// MARK: - Video Capture Delegate
extension PiPManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    public nonisolated func captureOutput(_ output: AVCaptureOutput,
                                         didOutput sampleBuffer: CMSampleBuffer,
                                         from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        let context = CIContext()

        guard let cgImage = context.createCGImage(ciImage, from: ciImage.extent) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.webcamImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
    }
}

/// Picture-in-Picture overlay view
public struct PiPOverlay: View {
    @ObservedObject var pipManager: PiPManager
    @StateObject private var effectsProcessor = WebcamEffectsProcessor()
    @State private var isDragging = false
    @State private var dragOffset = CGSize.zero

    public init(pipManager: PiPManager) {
        self.pipManager = pipManager
    }

    public var body: some View {
        if pipManager.isPiPEnabled, let image = pipManager.webcamImage {
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(
                    width: pipManager.pipSize.dimensions.width,
                    height: pipManager.pipSize.dimensions.height
                )
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.3), lineWidth: 2)
                )
                .shadow(radius: 10)
                .opacity(pipManager.pipOpacity)
                .offset(dragOffset)
                .scaleEffect(isDragging ? 1.1 : 1.0)
                .animation(.easeInOut(duration: 0.2), value: isDragging)
                .onDrag {
                    isDragging = true
                    return NSItemProvider()
                }
                .onDrop(of: [.text], delegate: PiPDropDelegate(dragOffset: $dragOffset, isDragging: $isDragging))
        }
    }
}

/// Drop delegate for PiP dragging
struct PiPDropDelegate: DropDelegate {
    @Binding var dragOffset: CGSize
    @Binding var isDragging: Bool

    func performDrop(info: DropInfo) -> Bool {
        isDragging = false
        return true
    }

    func dropEntered(info: DropInfo) {

    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        dragOffset = CGSize(
            width: info.location.x - 90,
            height: info.location.y - 67.5
        )
        return DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {
        isDragging = false
    }
}

/// PiP Control Panel
public struct PiPControlPanel: View {
    @ObservedObject var pipManager: PiPManager

    public init(pipManager: PiPManager) {
        self.pipManager = pipManager
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
            Text("Picture-in-Picture Settings")
                .font(.headline)

            Divider()

            // Position control
            HStack {
                Text("Position:")
                    .font(.caption)
                Picker("", selection: $pipManager.pipPosition) {
                    ForEach(PiPManager.PiPPosition.allCases, id: \.self) { position in
                        Text(position.rawValue).tag(position)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 120)
            }

            // Size control
            HStack {
                Text("Size:")
                    .font(.caption)
                Picker("", selection: $pipManager.pipSize) {
                    ForEach(PiPManager.PiPSize.allCases, id: \.self) { size in
                        Text(size.rawValue).tag(size)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
            }

            // Opacity control
            VStack(alignment: .leading) {
                Text("Opacity: \(Int(pipManager.pipOpacity * 100))%")
                    .font(.caption)
                Slider(value: $pipManager.pipOpacity, in: 0.3...1.0)
                    .controlSize(.small)
            }
        }
        .padding()
        .frame(width: 250)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(DesignSystem.Radius.lg)
    }
}

/// PiP Toolbar Button
public struct PiPToolbarButton: View {
    @StateObject private var pipManager = PiPManager()
    @State private var showSettings = false
    @State private var isHovering = false

    public init() {}

    public var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            // Main PiP toggle button
            Button(action: {
                pipManager.togglePiP()
            }) {
                Image(systemName: pipManager.isPiPEnabled ? "pip.fill" : "pip")
                    .font(.system(size: 14))
                    .foregroundColor(pipManager.isPiPEnabled ? .blue : .primary)
            }
            .buttonStyle(.plain)
            .help("Toggle Picture-in-Picture webcam")

            // Settings dropdown
            Button(action: {
                showSettings.toggle()
            }) {
                Image(systemName: "chevron.down")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showSettings) {
                PiPControlPanel(pipManager: pipManager)
            }

            // Fullscreen button
            if pipManager.isPiPEnabled {
                Divider()
                    .frame(height: 16)

                Button(action: {
                    pipManager.toggleFullscreen()
                }) {
                    Image(systemName: pipManager.isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right")
                        .font(.system(size: 14))
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                .help("Toggle fullscreen")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color.gray.opacity(isHovering ? 0.2 : 0.1))
        )
        .onHover { hovering in
            isHovering = hovering
        }
        .environmentObject(pipManager)
    }
}

/// Enhanced Emulator View with PiP
public struct PIPEnhancedEmulatorDisplay: View {
    @ObservedObject var emulatorManager: EmulatorManager
    @StateObject private var pipManager = PiPManager()

    public init(emulatorManager: EmulatorManager) {
        self.emulatorManager = emulatorManager
    }

    public var body: some View {
        ZStack {
            // Main emulator display - render actual emulator frames via Metal
            EmulatorMetalViewRepresentable(emulatorManager: emulatorManager)
                .aspectRatio(4/3, contentMode: .fit)
                .background(Color.black)

            // PiP webcam overlay
            if pipManager.isPiPEnabled {
                VStack {
                    HStack {
                        if pipManager.pipPosition == .topLeft {
                            PiPOverlay(pipManager: pipManager)
                                .padding(pipManager.pipPosition.offset.width)
                        }
                        Spacer()
                        if pipManager.pipPosition == .topRight {
                            PiPOverlay(pipManager: pipManager)
                                .padding(abs(pipManager.pipPosition.offset.width))
                        }
                    }
                    Spacer()
                    HStack {
                        if pipManager.pipPosition == .bottomLeft {
                            PiPOverlay(pipManager: pipManager)
                                .padding(pipManager.pipPosition.offset.width)
                        }
                        Spacer()
                        if pipManager.pipPosition == .bottomRight {
                            PiPOverlay(pipManager: pipManager)
                                .padding(abs(pipManager.pipPosition.offset.width))
                        }
                    }
                }
                .padding()
            }
        }
    }
}
