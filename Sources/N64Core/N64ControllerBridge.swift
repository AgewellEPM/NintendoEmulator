import Foundation
import GameController
import EmulatorKit

@MainActor
public class N64ControllerBridge {
    private let controllerManager = GameControllerManager.shared
    private var inputHandlerID: UUID?
    private var n64CorePtr: UnsafeMutableRawPointer?

    // N64 button masks
    private struct N64Buttons {
        static let A: UInt16 = 0x8000
        static let B: UInt16 = 0x4000
        static let Z: UInt16 = 0x2000
        static let START: UInt16 = 0x1000
        static let DUP: UInt16 = 0x0800
        static let DDOWN: UInt16 = 0x0400
        static let DLEFT: UInt16 = 0x0200
        static let DRIGHT: UInt16 = 0x0100
        static let L: UInt16 = 0x0020
        static let R: UInt16 = 0x0010
        static let CUP: UInt16 = 0x0008
        static let CDOWN: UInt16 = 0x0004
        static let CLEFT: UInt16 = 0x0002
        static let CRIGHT: UInt16 = 0x0001
    }

    private var buttonState: UInt16 = 0
    private var analogX: Int8 = 0
    private var analogY: Int8 = 0

    public init() {
        setupControllerInput()
    }

    public func disconnect() {
        if let id = inputHandlerID {
            controllerManager.unregisterInputHandler(id)
            inputHandlerID = nil
        }
    }

    private func setupControllerInput() {
        inputHandlerID = controllerManager.registerInputHandler { [weak self] input in
            self?.handleControllerInput(input)
        }
    }

    private func handleControllerInput(_ input: GameControllerManager.ControllerInput) {
        switch input {
        case .buttonA(let pressed):
            updateButton(N64Buttons.A, pressed: pressed)

        case .buttonB(let pressed):
            updateButton(N64Buttons.B, pressed: pressed)

        case .buttonX(let pressed):
            // X maps to B on N64
            updateButton(N64Buttons.B, pressed: pressed)

        case .buttonY(let pressed):
            // Y maps to A on N64
            updateButton(N64Buttons.A, pressed: pressed)

        case .leftShoulder(let pressed):
            updateButton(N64Buttons.L, pressed: pressed)

        case .rightShoulder(let pressed):
            updateButton(N64Buttons.R, pressed: pressed)

        case .leftTrigger(let value):
            // Map left trigger to Z button
            updateButton(N64Buttons.Z, pressed: value > 0.5)

        case .rightTrigger(let value):
            // Map right trigger to Z button as well (for convenience)
            if value > 0.5 {
                updateButton(N64Buttons.Z, pressed: true)
            }

        case .menu(let pressed):
            updateButton(N64Buttons.START, pressed: pressed)

        case .options(_):
            // No direct mapping for Select on N64
            break

        case .dpad(let x, let y):
            updateButton(N64Buttons.DLEFT, pressed: x < -0.5)
            updateButton(N64Buttons.DRIGHT, pressed: x > 0.5)
            updateButton(N64Buttons.DUP, pressed: y > 0.5)
            updateButton(N64Buttons.DDOWN, pressed: y < -0.5)

        case .leftThumbstick(let x, let y):
            // Update analog stick values (-128 to 127)
            analogX = Int8(max(-127, min(127, Int(x * 127))))
            analogY = Int8(max(-127, min(127, Int(y * 127))))
            updateN64ControllerState()

        case .rightThumbstick(let x, let y):
            // Map right stick to C buttons
            updateButton(N64Buttons.CLEFT, pressed: x < -0.5)
            updateButton(N64Buttons.CRIGHT, pressed: x > 0.5)
            updateButton(N64Buttons.CUP, pressed: y > 0.5)
            updateButton(N64Buttons.CDOWN, pressed: y < -0.5)

        case .cButtons(let x, let y):
            // Direct C button mapping
            updateButton(N64Buttons.CLEFT, pressed: x < -0.5)
            updateButton(N64Buttons.CRIGHT, pressed: x > 0.5)
            updateButton(N64Buttons.CUP, pressed: y > 0.5)
            updateButton(N64Buttons.CDOWN, pressed: y < -0.5)

        case .zButton(let pressed):
            updateButton(N64Buttons.Z, pressed: pressed)

        case .home(_):
            // No mapping for home button
            break
        }
    }

    private func updateButton(_ mask: UInt16, pressed: Bool) {
        if pressed {
            buttonState |= mask
        } else {
            buttonState &= ~mask
        }
        updateN64ControllerState()
    }

    private func updateN64ControllerState() {
        // Send the controller state to the N64 core
        if n64CorePtr != nil {
            // This would call into the actual Mupen64Plus API
            // For now, we'll prepare the data structure
            var controllerData = N64ControllerData(
                buttons: buttonState,
                analogX: analogX,
                analogY: analogY
            )

            // Send to core (implementation depends on Mupen64Plus integration)
            sendControllerDataToCore(&controllerData)
        }
    }

    public func setN64Core(_ corePtr: UnsafeMutableRawPointer) {
        self.n64CorePtr = corePtr
    }

    private func sendControllerDataToCore(_ data: inout N64ControllerData) {
        // This would interface with Mupen64Plus
        // Example: CoreDoCommand(M64CMD_SEND_SDL_KEYDOWN, ...)
    }

    // Public interface for direct input
    public func sendButtonPress(_ button: N64Button, pressed: Bool) {
        switch button {
        case .a:
            updateButton(N64Buttons.A, pressed: pressed)
        case .b:
            updateButton(N64Buttons.B, pressed: pressed)
        case .z:
            updateButton(N64Buttons.Z, pressed: pressed)
        case .start:
            updateButton(N64Buttons.START, pressed: pressed)
        case .l:
            updateButton(N64Buttons.L, pressed: pressed)
        case .r:
            updateButton(N64Buttons.R, pressed: pressed)
        case .cUp:
            updateButton(N64Buttons.CUP, pressed: pressed)
        case .cDown:
            updateButton(N64Buttons.CDOWN, pressed: pressed)
        case .cLeft:
            updateButton(N64Buttons.CLEFT, pressed: pressed)
        case .cRight:
            updateButton(N64Buttons.CRIGHT, pressed: pressed)
        case .dUp:
            updateButton(N64Buttons.DUP, pressed: pressed)
        case .dDown:
            updateButton(N64Buttons.DDOWN, pressed: pressed)
        case .dLeft:
            updateButton(N64Buttons.DLEFT, pressed: pressed)
        case .dRight:
            updateButton(N64Buttons.DRIGHT, pressed: pressed)
        }
    }

    public func sendAnalogInput(x: Float, y: Float) {
        analogX = Int8(max(-127, min(127, Int(x * 127))))
        analogY = Int8(max(-127, min(127, Int(y * 127))))
        updateN64ControllerState()
    }

    // Get current state for debugging
    public func getCurrentState() -> (buttons: UInt16, x: Int8, y: Int8) {
        return (buttonState, analogX, analogY)
    }
}

// Data structure for N64 controller
struct N64ControllerData {
    let buttons: UInt16
    let analogX: Int8
    let analogY: Int8
}

// N64 button enum for public API
public enum N64Button {
    case a, b, z, start
    case l, r
    case cUp, cDown, cLeft, cRight
    case dUp, dDown, dLeft, dRight
}