import SwiftUI
import AVFoundation
import AppKit

/// Lightweight preview for an AVCaptureSession (e.g., screen capture), with proper resizing.
public struct ScreenCapturePreview: NSViewRepresentable {
    public let session: AVCaptureSession?

    public init(session: AVCaptureSession?) {
        self.session = session
    }

    public func makeNSView(context: Context) -> PreviewContainerView {
        let view = PreviewContainerView()
        view.autoresizingMask = [.width, .height]
        view.update(with: session)
        return view
    }

    public func updateNSView(_ nsView: PreviewContainerView, context: Context) {
        nsView.update(with: session)
    }
}

public final class PreviewContainerView: NSView {
    private var previewLayer: AVCaptureVideoPreviewLayer?

    public override var wantsUpdateLayer: Bool { true }

    public func update(with session: AVCaptureSession?) {
        if let layer = previewLayer {
            layer.session = session
            layer.videoGravity = .resizeAspect
        } else if let session {
            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspect
            self.layer = CALayer()
            self.layer?.addSublayer(layer)
            self.previewLayer = layer
        } else {
            self.layer = CALayer()
            self.previewLayer = nil
        }
        needsLayout = true
    }

    public override func layout() {
        super.layout()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        previewLayer?.frame = bounds
        CATransaction.commit()
    }
}
