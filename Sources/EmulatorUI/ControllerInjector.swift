import Foundation
import CoreInterface
import InputSystem

/// Injects virtual controller inputs into the emulator
/// This allows AI agents to "press buttons" programmatically
@MainActor
public class ControllerInjector {

    // MARK: - Types

    /// N64 button state
    public struct N64ButtonState {
        var a: Bool = false
        var b: Bool = false
        var start: Bool = false
        var l: Bool = false
        var r: Bool = false
        var z: Bool = false
        var cUp: Bool = false
        var cDown: Bool = false
        var cLeft: Bool = false
        var cRight: Bool = false
        var dpadUp: Bool = false
        var dpadDown: Bool = false
        var dpadLeft: Bool = false
        var dpadRight: Bool = false

        public init() {}
    }

    /// Analog stick position (-128 to 127 for N64)
    public struct AnalogPosition {
        var x: Int8 = 0  // -128 (left) to 127 (right)
        var y: Int8 = 0  // -128 (down) to 127 (up)

        public init(x: Int8 = 0, y: Int8 = 0) {
            self.x = x
            self.y = y
        }

        public static let center = AnalogPosition(x: 0, y: 0)
        public static let up = AnalogPosition(x: 0, y: 127)
        public static let down = AnalogPosition(x: 0, y: -128)
        public static let left = AnalogPosition(x: -128, y: 0)
        public static let right = AnalogPosition(x: 127, y: 0)
    }

    // MARK: - Properties

    private var currentButtons = N64ButtonState()
    private var currentAnalog = AnalogPosition()
    private var controllerManager: ControllerManager?
    private let player: Int = 0  // AI always controls player 1

    // MARK: - Initialization

    public init() {}

    // MARK: - Setup

    /// Connect to emulator input system via ControllerManager
    public func connect(controllerManager: ControllerManager) {
        self.controllerManager = controllerManager
        print("🎮 [ControllerInjector] Connected to ControllerManager")
    }

    /// Legacy connect for direct input delegate
    public func connect(inputDelegate: EmulatorInputProtocol?) {
        // Fallback: use ControllerManager.shared
        self.controllerManager = ControllerManager.shared
        print("🎮 [ControllerInjector] Connected to emulator input system (legacy)")
    }

    public func disconnect() {
        releaseAllButtons()
        controllerManager = nil
        print("🎮 [ControllerInjector] Disconnected")
    }

    // MARK: - Button Control

    /// Press a button
    public func pressButton(_ button: EmulatorButton) {
        updateButtonState(button, pressed: true)
        controllerManager?.injectVirtualInput(player: player, button: button, pressed: true)
        print("🎮 [AI] Pressed \(button)")
    }

    /// Release a button
    public func releaseButton(_ button: EmulatorButton) {
        updateButtonState(button, pressed: false)
        controllerManager?.injectVirtualInput(player: player, button: button, pressed: false)
        print("🎮 [AI] Released \(button)")
    }

    /// Press and hold a button for a duration
    public func pressButton(_ button: EmulatorButton, duration: TimeInterval) async {
        pressButton(button)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        releaseButton(button)
    }

    /// Release all buttons
    public func releaseAllButtons() {
        let allButtons: [EmulatorButton] = [.a, .b, .start, .l, .r, .x, .y, .up, .down, .left, .right, .select, .home]
        for button in allButtons {
            controllerManager?.injectVirtualInput(player: player, button: button, pressed: false)
        }
        currentButtons = N64ButtonState()
        currentAnalog = .center
    }

    // MARK: - Analog Stick Control

    /// Set analog stick position
    public func setAnalogStick(_ position: AnalogPosition) {
        currentAnalog = position

        // Convert Int8 (-128 to 127) to Float (-1.0 to 1.0)
        let x = Float(position.x) / 127.0
        let y = Float(position.y) / 127.0

        controllerManager?.injectVirtualAnalog(player: player, stick: .left, x: x, y: y)
    }

    /// Move analog stick smoothly to a position over time
    public func moveAnalogStick(to target: AnalogPosition, duration: TimeInterval) async {
        let startX = currentAnalog.x
        let startY = currentAnalog.y
        let steps = Int(duration * 60) // 60 FPS

        for step in 0...steps {
            let progress = Float(step) / Float(steps)
            let x = Int8(Float(startX) + (Float(target.x) - Float(startX)) * progress)
            let y = Int8(Float(startY) + (Float(target.y) - Float(startY)) * progress)

            setAnalogStick(AnalogPosition(x: x, y: y))
            try? await Task.sleep(nanoseconds: 16_666_666) // ~60 FPS
        }
    }

    // MARK: - Combo Actions

    /// Tap a button quickly
    public func tapButton(_ button: EmulatorButton) async {
        await pressButton(button, duration: 0.1)
    }

    /// Double tap a button
    public func doubleTapButton(_ button: EmulatorButton) async {
        await tapButton(button)
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        await tapButton(button)
    }

    /// Press multiple buttons simultaneously
    public func pressButtons(_ buttons: [EmulatorButton], duration: TimeInterval) async {
        for button in buttons {
            pressButton(button)
        }
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        for button in buttons {
            releaseButton(button)
        }
    }

    // MARK: - Common N64 Actions

    /// Jump (A button)
    public func jump() async {
        await tapButton(.a)
    }

    /// Attack (B button)
    public func attack() async {
        await tapButton(.b)
    }

    /// Run forward for duration
    public func runForward(duration: TimeInterval) async {
        setAnalogStick(.up)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        setAnalogStick(.center)
    }

    /// Turn left/right (rotate camera/character)
    public func turn(direction: TurnDirection, amount: Float = 0.5) async {
        let xValue = direction == .left ? -Int8(127 * amount) : Int8(127 * amount)
        setAnalogStick(AnalogPosition(x: xValue, y: 0))
        try? await Task.sleep(nanoseconds: 100_000_000) // 0.1s
        setAnalogStick(.center)
    }

    public enum TurnDirection {
        case left, right
    }

    /// Strafe (move sideways)
    public func strafe(direction: StrafeDirection, duration: TimeInterval) async {
        let position: AnalogPosition
        switch direction {
        case .left:
            position = .left
        case .right:
            position = .right
        }

        setAnalogStick(position)
        try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
        setAnalogStick(.center)
    }

    public enum StrafeDirection {
        case left, right
    }

    // MARK: - State Queries

    /// Get current button state
    public func getButtonState() -> N64ButtonState {
        return currentButtons
    }

    /// Get current analog position
    public func getAnalogPosition() -> AnalogPosition {
        return currentAnalog
    }

    // MARK: - Private Helpers

    private func updateButtonState(_ button: EmulatorButton, pressed: Bool) {
        switch button {
        case .a: currentButtons.a = pressed
        case .b: currentButtons.b = pressed
        case .start: currentButtons.start = pressed
        case .l: currentButtons.l = pressed
        case .r: currentButtons.r = pressed
        case .x: currentButtons.z = pressed  // Map X to Z button
        case .y: currentButtons.cUp = pressed
        case .up: currentButtons.dpadUp = pressed
        case .down: currentButtons.dpadDown = pressed
        case .left: currentButtons.dpadLeft = pressed
        case .right: currentButtons.dpadRight = pressed
        default: break
        }
    }
}