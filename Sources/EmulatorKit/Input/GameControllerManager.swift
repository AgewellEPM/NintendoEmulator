import Foundation
import GameController
import Combine
import os.log

@MainActor
public final class GameControllerManager: ObservableObject {

    // MARK: - Published Properties
    @Published public private(set) var connectedControllers: [GCController] = []
    @Published public private(set) var activeController: GCController?
    @Published public private(set) var isControllerConnected = false
    @Published public private(set) var controllerMappings: [Int: ControllerMapping] = [:]

    // MARK: - Properties
    private let logger = Logger(subsystem: "com.emulator", category: "GameControllerManager")
    private var cancellables = Set<AnyCancellable>()
    private var inputHandlers: [UUID: InputHandler] = [:]

    // MARK: - Singleton
    public static let shared = GameControllerManager()

    // MARK: - Controller Mapping
    public struct ControllerMapping {
        public var buttonA: String = "Button A"
        public var buttonB: String = "Button B"
        public var buttonX: String = "Button X"
        public var buttonY: String = "Button Y"
        public var leftShoulder: String = "L"
        public var rightShoulder: String = "R"
        public var leftTrigger: String = "ZL"
        public var rightTrigger: String = "ZR"
        public var menu: String = "Start"
        public var options: String = "Select"
        public var leftThumbstick: String = "Left Stick"
        public var rightThumbstick: String = "Right Stick"
        public var dpadUp: String = "D-Pad Up"
        public var dpadDown: String = "D-Pad Down"
        public var dpadLeft: String = "D-Pad Left"
        public var dpadRight: String = "D-Pad Right"

        // N64 specific mappings
        public var cButtonUp: String = "Right Stick Up"
        public var cButtonDown: String = "Right Stick Down"
        public var cButtonLeft: String = "Right Stick Left"
        public var cButtonRight: String = "Right Stick Right"
        public var zButton: String = "ZL"

        public init() {}
    }

    // MARK: - Input Handler
    public struct InputHandler {
        let id: UUID
        let handler: (ControllerInput) -> Void
    }

    // MARK: - Controller Input
    public enum ControllerInput {
        case buttonA(pressed: Bool)
        case buttonB(pressed: Bool)
        case buttonX(pressed: Bool)
        case buttonY(pressed: Bool)
        case leftShoulder(pressed: Bool)
        case rightShoulder(pressed: Bool)
        case leftTrigger(value: Float)
        case rightTrigger(value: Float)
        case leftThumbstick(x: Float, y: Float)
        case rightThumbstick(x: Float, y: Float)
        case dpad(x: Float, y: Float)
        case menu(pressed: Bool)
        case options(pressed: Bool)
        case home(pressed: Bool)

        // N64 specific inputs
        case cButtons(x: Float, y: Float)
        case zButton(pressed: Bool)
    }

    // MARK: - Initialization
    private init() {
        setupControllerNotifications()
        detectControllers()
        loadControllerMappings()
    }

    // MARK: - Setup
    private func setupControllerNotifications() {
        // Controller connection notifications
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .sink { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                Task { @MainActor in
                    self?.controllerDidConnect(controller)
                }
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .sink { [weak self] notification in
                guard let controller = notification.object as? GCController else { return }
                Task { @MainActor in
                    self?.controllerDidDisconnect(controller)
                }
            }
            .store(in: &cancellables)

        // Start wireless controller discovery
        GCController.startWirelessControllerDiscovery()
    }

    // MARK: - Controller Detection
    private func detectControllers() {
        connectedControllers = GCController.controllers()
        isControllerConnected = !connectedControllers.isEmpty

        if let firstController = connectedControllers.first {
            setActiveController(firstController)
        }

        logger.info("Detected \(self.connectedControllers.count) controller(s)")
    }

    // MARK: - Controller Connection
    private func controllerDidConnect(_ controller: GCController) {
        logger.info("Controller connected: \(controller.vendorName ?? "Unknown")")

        connectedControllers = GCController.controllers()
        isControllerConnected = true

        if activeController == nil {
            setActiveController(controller)
        }

        configureController(controller)
    }

    private func controllerDidDisconnect(_ controller: GCController) {
        logger.info("Controller disconnected: \(controller.vendorName ?? "Unknown")")

        connectedControllers = GCController.controllers()
        isControllerConnected = !connectedControllers.isEmpty

        if controller == activeController {
            activeController = connectedControllers.first
            if let newActive = activeController {
                configureController(newActive)
            }
        }
    }

    // MARK: - Controller Configuration
    public func setActiveController(_ controller: GCController) {
        activeController = controller
        configureController(controller)
        logger.info("Set active controller: \(controller.vendorName ?? "Unknown")")
    }

    private func configureController(_ controller: GCController) {
        // Configure extended gamepad
        if let extendedGamepad = controller.extendedGamepad {
            configureExtendedGamepad(extendedGamepad)
        }
        // Configure micro gamepad (for Siri Remote)
        else if let microGamepad = controller.microGamepad {
            configureMicroGamepad(microGamepad)
        }

        // Configure haptics if available
        if controller.haptics != nil {
            logger.info("Haptics available for controller")
        }

        // Configure light if available
        if let light = controller.light {
            light.color = GCColor(red: 0.0, green: 0.5, blue: 1.0)
        }

        // Configure battery if available
        if let battery = controller.battery {
            logger.info("Battery level: \(battery.batteryLevel)")
        }
    }

    private func configureExtendedGamepad(_ gamepad: GCExtendedGamepad) {
        // Button A
        gamepad.buttonA.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.buttonA(pressed: pressed))
        }

        // Button B
        gamepad.buttonB.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.buttonB(pressed: pressed))
        }

        // Button X
        gamepad.buttonX.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.buttonX(pressed: pressed))
        }

        // Button Y
        gamepad.buttonY.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.buttonY(pressed: pressed))
        }

        // Shoulders
        gamepad.leftShoulder.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.leftShoulder(pressed: pressed))
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.rightShoulder(pressed: pressed))
        }

        // Triggers
        gamepad.leftTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.leftTrigger(value: value))
        }

        gamepad.rightTrigger.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.rightTrigger(value: value))
        }

        // D-Pad
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleInput(.dpad(x: xValue, y: yValue))
        }

        // Left Thumbstick
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleInput(.leftThumbstick(x: xValue, y: yValue))
        }

        // Right Thumbstick
        gamepad.rightThumbstick.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleInput(.rightThumbstick(x: xValue, y: yValue))
            // Also map to C buttons for N64
            self?.handleInput(.cButtons(x: xValue, y: yValue))
        }

        // Menu buttons
        gamepad.buttonMenu.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.menu(pressed: pressed))
        }

        // Options button is optional on some controllers
        gamepad.buttonOptions?.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.options(pressed: pressed))
        }

        // Home button is optional
        gamepad.buttonHome?.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.home(pressed: pressed))
        }
    }

    private func configureMicroGamepad(_ gamepad: GCMicroGamepad) {
        // Configure for Siri Remote or basic controllers
        gamepad.dpad.valueChangedHandler = { [weak self] _, xValue, yValue in
            self?.handleInput(.dpad(x: xValue, y: yValue))
        }

        gamepad.buttonA.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.buttonA(pressed: pressed))
        }

        gamepad.buttonX.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.buttonX(pressed: pressed))
        }

        gamepad.buttonMenu.valueChangedHandler = { [weak self] _, value, pressed in
            self?.handleInput(.menu(pressed: pressed))
        }
    }

    // MARK: - Input Handling
    private func handleInput(_ input: ControllerInput) {
        // Forward to all registered handlers
        for handler in inputHandlers.values {
            handler.handler(input)
        }
    }

    public func registerInputHandler(_ handler: @escaping (ControllerInput) -> Void) -> UUID {
        let id = UUID()
        inputHandlers[id] = InputHandler(id: id, handler: handler)
        return id
    }

    public func unregisterInputHandler(_ id: UUID) {
        inputHandlers.removeValue(forKey: id)
    }

    // MARK: - Haptic Feedback
    public func triggerHapticFeedback(intensity: Float = 1.0, duration: TimeInterval = 0.1) {
        guard let controller = activeController else { return }

        // Use rumble motors if available (for Xbox/PlayStation controllers)
        if #available(macOS 11.0, *), controller.haptics != nil {
            // For now, we'll use the basic haptics API
            // The CHHapticEngine requires CoreHaptics which has limited support on macOS
            logger.info("Controller supports haptics, but advanced haptics not implemented yet")
        }

        // Fallback to controller light feedback if available
        if let light = controller.light {
            // Flash the light as feedback
            let originalColor = light.color
            light.color = GCColor(red: 1.0, green: 1.0, blue: 1.0)
            DispatchQueue.main.asyncAfter(deadline: .now() + duration) {
                light.color = originalColor
            }
        }
    }

    // MARK: - Controller Mapping
    public func getMapping(for playerIndex: Int) -> ControllerMapping {
        return controllerMappings[playerIndex] ?? ControllerMapping()
    }

    public func setMapping(_ mapping: ControllerMapping, for playerIndex: Int) {
        controllerMappings[playerIndex] = mapping
        saveControllerMappings()
    }

    private func loadControllerMappings() {
        // Load from UserDefaults or file
        if let data = UserDefaults.standard.data(forKey: "ControllerMappings"),
           let mappings = try? JSONDecoder().decode([Int: ControllerMapping].self, from: data) {
            controllerMappings = mappings
        }
    }

    private func saveControllerMappings() {
        // Save to UserDefaults
        if let data = try? JSONEncoder().encode(controllerMappings) {
            UserDefaults.standard.set(data, forKey: "ControllerMappings")
        }
    }

    // MARK: - Controller Info
    public func getControllerInfo() -> [String: Any] {
        guard let controller = activeController else {
            return ["status": "No controller connected"]
        }

        var info: [String: Any] = [
            "vendorName": controller.vendorName ?? "Unknown",
            "isAttachedToDevice": controller.isAttachedToDevice,
            "playerIndex": controller.playerIndex.rawValue
        ]

        if let battery = controller.battery {
            info["batteryLevel"] = battery.batteryLevel
            info["batteryState"] = battery.batteryState.rawValue
        }

        if controller.extendedGamepad != nil {
            info["type"] = "Extended Gamepad"
        } else if controller.microGamepad != nil {
            info["type"] = "Micro Gamepad"
        }

        return info
    }

    // MARK: - Calibration
    public func startCalibration(for playerIndex: Int) {
        logger.info("Starting controller calibration for player \(playerIndex)")
        // Implement calibration logic
    }

    // MARK: - Testing
    public func testControllerInput() {
        logger.info("Testing controller input...")

        guard let gamepad = activeController?.extendedGamepad else {
            logger.warning("No extended gamepad available for testing")
            return
        }

        // Test vibration
        triggerHapticFeedback(intensity: 0.5, duration: 0.2)

        // Log current state
        logger.info("""
            Controller Test:
            A: \(gamepad.buttonA.isPressed)
            B: \(gamepad.buttonB.isPressed)
            X: \(gamepad.buttonX.isPressed)
            Y: \(gamepad.buttonY.isPressed)
            Left Stick: (\(gamepad.leftThumbstick.xAxis.value), \(gamepad.leftThumbstick.yAxis.value))
            Right Stick: (\(gamepad.rightThumbstick.xAxis.value), \(gamepad.rightThumbstick.yAxis.value))
            """)
    }
}

// MARK: - Controller Mapping Extension
extension GameControllerManager.ControllerMapping: Codable {}

// MARK: - N64 Controller Mapping
extension GameControllerManager {
    public func mapToN64Input(_ input: ControllerInput) -> N64ControllerInput? {
        switch input {
        case .buttonA(let pressed):
            return .a(pressed: pressed)
        case .buttonB(let pressed):
            return .b(pressed: pressed)
        case .leftShoulder(let pressed):
            return .l(pressed: pressed)
        case .rightShoulder(let pressed):
            return .r(pressed: pressed)
        case .leftTrigger(let value):
            return value > 0.5 ? .z(pressed: true) : .z(pressed: false)
        case .dpad(let x, let y):
            return .dpad(x: x, y: y)
        case .leftThumbstick(let x, let y):
            return .analogStick(x: x, y: y)
        case .rightThumbstick(let x, let y):
            return .cButtons(x: x, y: y)
        case .menu(let pressed):
            return .start(pressed: pressed)
        default:
            return nil
        }
    }
}

// MARK: - N64 Controller Input
public enum N64ControllerInput {
    case a(pressed: Bool)
    case b(pressed: Bool)
    case z(pressed: Bool)
    case l(pressed: Bool)
    case r(pressed: Bool)
    case start(pressed: Bool)
    case dpad(x: Float, y: Float)
    case analogStick(x: Float, y: Float)
    case cButtons(x: Float, y: Float)
}

// MARK: - Controller Detection
extension GameControllerManager {
    public func scanForControllers() {
        logger.info("Scanning for wireless controllers...")
        GCController.startWirelessControllerDiscovery()

        // Stop scanning after 10 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
            GCController.stopWirelessControllerDiscovery()
            self.logger.info("Stopped scanning for controllers")
        }
    }

    public func stopScanning() {
        GCController.stopWirelessControllerDiscovery()
        logger.info("Stopped scanning for controllers")
    }
}