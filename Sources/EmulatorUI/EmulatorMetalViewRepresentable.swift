import SwiftUI
import MetalKit
import Combine
import EmulatorKit
import RenderingEngine

/// SwiftUI wrapper for the Metal-based emulator view.
/// Subscribes to `EmulatorManager.framePublisher` and updates the underlying `EmulatorMetalView`.
struct EmulatorMetalViewRepresentable: NSViewRepresentable {
    @ObservedObject var emulatorManager: EmulatorManager
    private let metalView = EmulatorMetalView()

    func makeNSView(context: Context) -> EmulatorMetalView {
        metalView.delegate = context.coordinator
        metalView.enableSetNeedsDisplay = false
        metalView.isPaused = false

        // Subscribe to frame updates
        context.coordinator.setupSubscriptions()

        return metalView
    }

    func updateNSView(_ nsView: EmulatorMetalView, context: Context) {
        // No-op; view updates are driven by frame publisher
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(emulatorManager: emulatorManager, metalView: metalView)
    }

    @MainActor
    class Coordinator: NSObject, MTKViewDelegate {
        let emulatorManager: EmulatorManager
        let metalView: EmulatorMetalView
        var cancellables = Set<AnyCancellable>()

        init(emulatorManager: EmulatorManager, metalView: EmulatorMetalView) {
            self.emulatorManager = emulatorManager
            self.metalView = metalView
            super.init()
        }

        func setupSubscriptions() {
            emulatorManager.framePublisher
                .receive(on: DispatchQueue.main)
                .sink { [weak self] frameData in
                    self?.metalView.updateFrame(frameData)
                }
                .store(in: &cancellables)
        }

        // MTKViewDelegate
        func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
            // No-op
        }

        func draw(in view: MTKView) {
            // Drawing handled by EmulatorMetalView
        }
    }
}

