import Foundation
import IOKit
import IOKit.hid
import CoreInterface
import os.log

/// Direct HID support for Nintendo Switch Pro Controller over Bluetooth
public final class SwitchProControllerHID: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var isConnected = false
    private var hidManager: IOHIDManager?
    private let logger = Logger(subsystem: "com.emulator", category: "SwitchProHID")

    // Switch Pro Controller identifiers
    private let vendorID = 0x057E  // Nintendo
    private let productID = 0x2009 // Switch Pro Controller

    // Button state
    public struct ButtonState {
        public var y = false
        public var x = false
        public var b = false
        public var a = false
        public var rightShoulder = false
        public var rightTrigger = false
        public var leftShoulder = false
        public var leftTrigger = false
        public var minus = false
        public var plus = false
        public var rightStick = false
        public var leftStick = false
        public var home = false
        public var capture = false
        public var dpadUp = false
        public var dpadDown = false
        public var dpadLeft = false
        public var dpadRight = false

        // Analog sticks (range: 0-255, center: ~128)
        public var leftStickX: UInt8 = 128
        public var leftStickY: UInt8 = 128
        public var rightStickX: UInt8 = 128
        public var rightStickY: UInt8 = 128
    }

    public var currentState = ButtonState()
    public var inputDelegate: EmulatorInputProtocol?

    // MARK: - Initialization

    public init() {
        setupHIDManager()
    }

    deinit {
        cleanup()
    }

    // MARK: - Setup

    private func setupHIDManager() {
        // Create HID Manager
        hidManager = IOHIDManagerCreate(kCFAllocatorDefault, IOOptionBits(kIOHIDOptionsTypeNone))

        guard let manager = hidManager else {
            logger.error("Failed to create HID manager")
            return
        }

        // Match ANY gamepad (UsagePage 1, Usage 5)
        // This works for official Switch Pro Controllers AND third-party clones
        let deviceMatch: [String: Any] = [
            kIOHIDPrimaryUsagePageKey: 1,  // Generic Desktop
            kIOHIDPrimaryUsageKey: 5       // Gamepad
        ]

        IOHIDManagerSetDeviceMatching(manager, deviceMatch as CFDictionary)

        // Register callbacks
        let matchingCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let hidManager = Unmanaged<SwitchProControllerHID>.fromOpaque(context!).takeUnretainedValue()
            hidManager.deviceConnected(device: device)
        }

        let removalCallback: IOHIDDeviceCallback = { context, result, sender, device in
            let hidManager = Unmanaged<SwitchProControllerHID>.fromOpaque(context!).takeUnretainedValue()
            hidManager.deviceDisconnected(device: device)
        }

        let context = Unmanaged.passUnretained(self).toOpaque()
        IOHIDManagerRegisterDeviceMatchingCallback(manager, matchingCallback, context)
        IOHIDManagerRegisterDeviceRemovalCallback(manager, removalCallback, context)

        // Schedule with run loop
        IOHIDManagerScheduleWithRunLoop(manager, CFRunLoopGetCurrent(), CFRunLoopMode.defaultMode.rawValue)

        // Open the manager
        let openResult = IOHIDManagerOpen(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        if openResult == kIOReturnSuccess {
            logger.info("HID Manager opened successfully")
        } else {
            logger.error("Failed to open HID manager: \(openResult)")
        }
    }

    // MARK: - Device Management

    private func deviceConnected(device: IOHIDDevice) {
        logger.info("Switch Pro Controller connected via HID")
        isConnected = true

        // Register input callback
        let inputCallback: IOHIDReportCallback = { context, result, sender, type, reportID, report, reportLength in
            let hidManager = Unmanaged<SwitchProControllerHID>.fromOpaque(context!).takeUnretainedValue()
            hidManager.handleInputReport(report: report, length: reportLength)
        }

        let context = Unmanaged.passUnretained(self).toOpaque()

        // Set up input report callback
        var reportBuffer = [UInt8](repeating: 0, count: 64)
        IOHIDDeviceRegisterInputReportCallback(
            device,
            &reportBuffer,
            reportBuffer.count,
            inputCallback,
            context
        )

        // Request full input reports
        sendInitCommands(to: device)
    }

    private func deviceDisconnected(device: IOHIDDevice) {
        logger.info("Switch Pro Controller disconnected")
        isConnected = false
        currentState = ButtonState()
    }

    // MARK: - Input Handling

    private func handleInputReport(report: UnsafePointer<UInt8>, length: Int) {
        guard length >= 12 else { return }

        let data = UnsafeBufferPointer(start: report, count: length)

        // Parse button data (bytes 3-5 for standard input reports)
        if length >= 12 && data[0] == 0x30 {
            parseStandardInputReport(data: Array(data))
        } else if length >= 49 && data[0] == 0x21 {
            parseFullInputReport(data: Array(data))
        }
    }

    private func parseStandardInputReport(data: [UInt8]) {
        guard data.count >= 12 else { return }

        // Buttons (byte 3-5)
        let buttons1 = data[3]
        let buttons2 = data[4]
        let buttons3 = data[5]

        // Right buttons (byte 3)
        currentState.y = (buttons1 & 0x01) != 0
        currentState.x = (buttons1 & 0x02) != 0
        currentState.b = (buttons1 & 0x04) != 0
        currentState.a = (buttons1 & 0x08) != 0
        currentState.rightShoulder = (buttons1 & 0x40) != 0
        currentState.rightTrigger = (buttons1 & 0x80) != 0

        // Left buttons (byte 4)
        currentState.minus = (buttons2 & 0x01) != 0
        currentState.plus = (buttons2 & 0x02) != 0
        currentState.rightStick = (buttons2 & 0x04) != 0
        currentState.leftStick = (buttons2 & 0x08) != 0
        currentState.home = (buttons2 & 0x10) != 0
        currentState.capture = (buttons2 & 0x20) != 0
        currentState.leftShoulder = (buttons2 & 0x40) != 0
        currentState.leftTrigger = (buttons2 & 0x80) != 0

        // D-Pad (byte 5)
        let dpad = buttons3 & 0x0F
        currentState.dpadUp = (dpad == 0 || dpad == 1 || dpad == 7)
        currentState.dpadDown = (dpad == 3 || dpad == 4 || dpad == 5)
        currentState.dpadLeft = (dpad == 5 || dpad == 6 || dpad == 7)
        currentState.dpadRight = (dpad == 1 || dpad == 2 || dpad == 3)

        // Analog sticks (bytes 6-11)
        if data.count >= 12 {
            currentState.leftStickX = data[6]
            currentState.leftStickY = data[7]
            currentState.rightStickX = data[9]
            currentState.rightStickY = data[10]
        }

        // Forward to input delegate
        forwardInputToDelegate()
    }

    private func parseFullInputReport(data: [UInt8]) {
        // Full input report with IMU data - parse the button section
        guard data.count >= 12 else { return }
        parseStandardInputReport(data: data)
    }

    private func forwardInputToDelegate() {
        guard let delegate = inputDelegate else { return }

        // Map to emulator buttons
        delegate.setButtonState(player: 0, button: .a, pressed: currentState.b)
        delegate.setButtonState(player: 0, button: .b, pressed: currentState.a)
        delegate.setButtonState(player: 0, button: .x, pressed: currentState.y)
        delegate.setButtonState(player: 0, button: .y, pressed: currentState.x)

        delegate.setButtonState(player: 0, button: .l, pressed: currentState.leftShoulder)
        delegate.setButtonState(player: 0, button: .r, pressed: currentState.rightShoulder)
        delegate.setButtonState(player: 0, button: .zl, pressed: currentState.leftTrigger)
        delegate.setButtonState(player: 0, button: .zr, pressed: currentState.rightTrigger)

        delegate.setButtonState(player: 0, button: .start, pressed: currentState.plus)
        delegate.setButtonState(player: 0, button: .select, pressed: currentState.minus)

        delegate.setButtonState(player: 0, button: .up, pressed: currentState.dpadUp)
        delegate.setButtonState(player: 0, button: .down, pressed: currentState.dpadDown)
        delegate.setButtonState(player: 0, button: .left, pressed: currentState.dpadLeft)
        delegate.setButtonState(player: 0, button: .right, pressed: currentState.dpadRight)

        // Convert analog values (0-255) to normalized float (-1.0 to 1.0)
        let leftX = (Float(currentState.leftStickX) - 128.0) / 128.0
        let leftY = (Float(currentState.leftStickY) - 128.0) / 128.0
        let rightX = (Float(currentState.rightStickX) - 128.0) / 128.0
        let rightY = (Float(currentState.rightStickY) - 128.0) / 128.0

        delegate.setAnalogState(player: 0, stick: .left, x: leftX, y: -leftY)
        delegate.setAnalogState(player: 0, stick: .right, x: rightX, y: -rightY)
    }

    // MARK: - Initialization Commands

    private func sendInitCommands(to device: IOHIDDevice) {
        // Send initialization command to enable standard input reports
        // This enables full button and stick data
        var enableStandardReport: [UInt8] = [0x01, 0x00] // Enable standard input

        let result = IOHIDDeviceSetReport(
            device,
            kIOHIDReportTypeOutput,
            CFIndex(0x01),
            &enableStandardReport,
            enableStandardReport.count
        )

        if result == kIOReturnSuccess {
            logger.info("Sent initialization command to Switch Pro Controller")
        }
    }

    // MARK: - Cleanup

    private func cleanup() {
        if let manager = hidManager {
            IOHIDManagerClose(manager, IOOptionBits(kIOHIDOptionsTypeNone))
        }
    }

    // MARK: - Public Interface

    public func enableVibration() {
        // Implement rumble support if needed
        logger.info("Vibration support not yet implemented")
    }
}