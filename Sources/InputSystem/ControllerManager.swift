import Foundation
import GameController
import Combine
import CoreInterface
import os.log

/// Manages game controllers and input mapping
public final class ControllerManager: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var controllers: [GCController] = []
    @Published public private(set) var primaryController: GCController?
    @Published public private(set) var keyboardConnected = true
    @Published public private(set) var switchControllerConnected = false

    /// Computed property for connected controllers (for UI compatibility)
    public var connectedControllers: [GCController] {
        return controllers
    }

    private var cancellables = Set<AnyCancellable>()
    private let inputMapper: InputMapper
    private let logger = Logger(subsystem: "com.emulator", category: "ControllerManager")

    // Switch Pro Controller HID support
    private var switchProHID: SwitchProControllerHID?

    // Input delegates for each player
    private var inputDelegates: [Int: EmulatorInputProtocol?] = [:]

    // Controller profiles
    private var controllerProfiles: [String: ControllerProfile] = [:]

    // Haptic engines
    private var hapticEngines: [GCController: CHHapticEngine] = [:]

    // MARK: - Singleton

    public static let shared = ControllerManager()

    // MARK: - Initialization

    private init() {
        self.inputMapper = InputMapper()
        setupNotifications()
        scanForControllers()
        loadControllerProfiles()
        setupSwitchProController()
    }

    // MARK: - Switch Pro Controller Setup

    private func setupSwitchProController() {
        switchProHID = SwitchProControllerHID()

        // Monitor connection state
        switchProHID?.$isConnected
            .sink { [weak self] connected in
                self?.switchControllerConnected = connected
                if connected {
                    self?.logger.info("✅ Switch Pro Controller connected via Bluetooth HID")
                } else {
                    self?.logger.info("Switch Pro Controller disconnected")
                }
            }
            .store(in: &cancellables)
    }

    /// Set input delegate for Switch Pro Controller
    public func setSwitchControllerDelegate(_ delegate: EmulatorInputProtocol?) {
        switchProHID?.inputDelegate = delegate
    }

    // MARK: - Setup

    private func setupNotifications() {
        // Controller connected
        NotificationCenter.default.publisher(for: .GCControllerDidConnect)
            .compactMap { $0.object as? GCController }
            .sink { [weak self] controller in
                self?.controllerConnected(controller)
            }
            .store(in: &cancellables)

        // Controller disconnected
        NotificationCenter.default.publisher(for: .GCControllerDidDisconnect)
            .compactMap { $0.object as? GCController }
            .sink { [weak self] controller in
                self?.controllerDisconnected(controller)
            }
            .store(in: &cancellables)

        // Controller became current
        NotificationCenter.default.publisher(for: .GCControllerDidBecomeCurrent)
            .compactMap { $0.object as? GCController }
            .sink { [weak self] controller in
                self?.setPrimaryController(controller)
            }
            .store(in: &cancellables)

        // Keyboard connected
        NotificationCenter.default.publisher(for: .GCKeyboardDidConnect)
            .sink { [weak self] _ in
                self?.keyboardConnected = true
                self?.logger.info("Keyboard connected")
            }
            .store(in: &cancellables)

        // Mouse connected
        NotificationCenter.default.publisher(for: .GCMouseDidConnect)
            .sink { [weak self] _ in
                self?.logger.info("Mouse connected")
            }
            .store(in: &cancellables)
    }

    private func scanForControllers() {
        controllers = GCController.controllers()

        if let first = controllers.first {
            setPrimaryController(first)
        }

        logger.info("Found \(self.controllers.count) controller(s)")
    }

    // MARK: - Public Methods

    /// Set input delegate for a player
    public func setInputDelegate(_ delegate: EmulatorInputProtocol?, for player: Int) {
        inputDelegates[player] = delegate
    }

    // MARK: - AI Virtual Input Injection

    /// Inject virtual button input (for AI agents)
    public func injectVirtualInput(player: Int, button: EmulatorButton, pressed: Bool) {
        inputDelegates[player]??.setButtonState(player: player, button: button, pressed: pressed)
    }

    /// Inject virtual analog stick input (for AI agents)
    public func injectVirtualAnalog(player: Int, stick: AnalogStick, x: Float, y: Float) {
        inputDelegates[player]??.setAnalogState(player: player, stick: stick, x: x, y: y)
    }

    /// Inject virtual trigger input (for AI agents)
    public func injectVirtualTrigger(player: Int, trigger: Trigger, value: Float) {
        inputDelegates[player]??.setTriggerState(player: player, trigger: trigger, value: value)
    }

    /// Get current input delegate for a player (for AI to connect)
    public func getInputDelegate(for player: Int) -> EmulatorInputProtocol? {
        return inputDelegates[player]!
    }

    /// Configure controller for a specific player
    public func assignController(_ controller: GCController, to player: Int) {
        guard player >= 0 && player < 4 else { return }

        // Remove from previous assignment
        for i in 0..<4 {
            if controller.playerIndex.rawValue == i {
                controller.playerIndex = .indexUnset
            }
        }

        // Assign to new player
        controller.playerIndex = GCControllerPlayerIndex(rawValue: player)!

        // Setup input handlers
        setupControllerHandlers(controller, player: player)

        logger.info("Assigned controller to player \(player + 1)")
    }

    /// Start controller vibration
    public func rumble(player: Int, intensity: Float, duration: TimeInterval) {
        guard let controller = getController(for: player) else { return }

        if let haptics = controller.haptics {
            // Simplified haptics - some APIs may differ between macOS versions
            _ = haptics.createEngine(withLocality: .default)
            logger.info("Haptic feedback requested: intensity \(intensity), duration \(duration)")
            // Note: Actual haptic implementation may vary by controller type
        }
    }

    /// Get controller for player
    public func getController(for player: Int) -> GCController? {
        controllers.first { $0.playerIndex.rawValue == player }
    }

    /// Save controller profile
    public func saveProfile(for controller: GCController, name: String) {
        let profile = ControllerProfile(
            name: name,
            vendorName: controller.vendorName ?? "Unknown",
            mappings: getCurrentMappings(for: controller)
        )

        controllerProfiles[controller.vendorName ?? ""] = profile
        saveControllerProfiles()
    }

    // MARK: - Private Methods

    private func controllerConnected(_ controller: GCController) {
        controllers.append(controller)

        if primaryController == nil {
            setPrimaryController(controller)
        }

        // Auto-assign to next available player slot
        for player in 0..<4 {
            if getController(for: player) == nil {
                assignController(controller, to: player)
                break
            }
        }

        logger.info("Controller connected: \(controller.vendorName ?? "Unknown")")

        // Setup haptics if available
        if controller.haptics != nil {
            setupHaptics(for: controller)
        }
    }

    private func controllerDisconnected(_ controller: GCController) {
        controllers.removeAll { $0 == controller }

        if primaryController == controller {
            primaryController = controllers.first
        }

        hapticEngines[controller] = nil

        logger.info("Controller disconnected: \(controller.vendorName ?? "Unknown")")
    }

    private func setPrimaryController(_ controller: GCController) {
        primaryController = controller
        controller.playerIndex = .index1
        setupControllerHandlers(controller, player: 0)
    }

    private func setupControllerHandlers(_ controller: GCController, player: Int) {
        // Extended gamepad (Xbox, PlayStation, etc.)
        if let gamepad = controller.extendedGamepad {
            setupExtendedGamepad(gamepad, player: player)
        }
        // Micro gamepad (Siri Remote)
        else if let gamepad = controller.microGamepad {
            setupMicroGamepad(gamepad, player: player)
        }
    }

    private func setupExtendedGamepad(_ gamepad: GCExtendedGamepad, player: Int) {
        // Button handler
        gamepad.valueChangedHandler = { [weak self] gamepad, element in
            self?.handleExtendedGamepadInput(gamepad, element: element, player: player)
        }

        // Individual button handlers for better responsiveness
        gamepad.buttonA.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.a, pressed: pressed, player: player)
        }

        gamepad.buttonB.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.b, pressed: pressed, player: player)
        }

        gamepad.buttonX.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.x, pressed: pressed, player: player)
        }

        gamepad.buttonY.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.y, pressed: pressed, player: player)
        }

        // D-Pad
        gamepad.dpad.valueChangedHandler = { [weak self] dpad, xValue, yValue in
            self?.handleDPad(xValue: xValue, yValue: yValue, player: player)
        }

        // Analog sticks
        gamepad.leftThumbstick.valueChangedHandler = { [weak self] stick, xValue, yValue in
            self?.handleAnalogStick(.left, x: xValue, y: yValue, player: player)
        }

        gamepad.rightThumbstick.valueChangedHandler = { [weak self] stick, xValue, yValue in
            self?.handleAnalogStick(.right, x: xValue, y: yValue, player: player)
        }

        // Triggers
        gamepad.leftTrigger.valueChangedHandler = { [weak self] trigger, value, pressed in
            self?.handleTrigger(.left, value: value, player: player)
        }

        gamepad.rightTrigger.valueChangedHandler = { [weak self] trigger, value, pressed in
            self?.handleTrigger(.right, value: value, player: player)
        }

        // Shoulders
        gamepad.leftShoulder.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.l, pressed: pressed, player: player)
        }

        gamepad.rightShoulder.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.r, pressed: pressed, player: player)
        }

        // Menu buttons
        gamepad.buttonOptions?.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.select, pressed: pressed, player: player)
        }

        gamepad.buttonMenu.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.start, pressed: pressed, player: player)
        }

        // Home button
        gamepad.buttonHome?.valueChangedHandler = { [weak self] button, value, pressed in
            self?.handleButton(.home, pressed: pressed, player: player)
        }
    }

    private func setupMicroGamepad(_ gamepad: GCMicroGamepad, player: Int) {
        gamepad.valueChangedHandler = { [weak self] gamepad, element in
            // Handle micro gamepad input (Apple TV remote)
            if element == gamepad.buttonA {
                self?.handleButton(.a, pressed: gamepad.buttonA.isPressed, player: player)
            } else if element == gamepad.buttonX {
                self?.handleButton(.x, pressed: gamepad.buttonX.isPressed, player: player)
            } else if element == gamepad.dpad {
                self?.handleDPad(
                    xValue: gamepad.dpad.xAxis.value,
                    yValue: gamepad.dpad.yAxis.value,
                    player: player
                )
            }
        }
    }

    private func handleExtendedGamepadInput(
        _ gamepad: GCExtendedGamepad,
        element: GCControllerElement,
        player: Int
    ) {
        // This is called for any input change
        // Individual handlers above provide more specific control
    }

    private func handleButton(_ button: EmulatorButton, pressed: Bool, player: Int) {
        inputDelegates[player]??.setButtonState(player: player, button: button, pressed: pressed)
    }

    private func handleDPad(xValue: Float, yValue: Float, player: Int) {
        let threshold: Float = 0.5

        // Convert analog values to digital directions
        inputDelegates[player]??.setButtonState(
            player: player,
            button: .left,
            pressed: xValue < -threshold
        )
        inputDelegates[player]??.setButtonState(
            player: player,
            button: .right,
            pressed: xValue > threshold
        )
        inputDelegates[player]??.setButtonState(
            player: player,
            button: .up,
            pressed: yValue > threshold
        )
        inputDelegates[player]??.setButtonState(
            player: player,
            button: .down,
            pressed: yValue < -threshold
        )
    }

    private func handleAnalogStick(_ stick: AnalogStick, x: Float, y: Float, player: Int) {
        inputDelegates[player]??.setAnalogState(player: player, stick: stick, x: x, y: y)
    }

    private func handleTrigger(_ trigger: Trigger, value: Float, player: Int) {
        inputDelegates[player]??.setTriggerState(player: player, trigger: trigger, value: value)

        // Also handle as digital buttons for systems without analog triggers
        let pressed = value > 0.5
        let button: EmulatorButton = trigger == .left ? .zl : .zr
        inputDelegates[player]??.setButtonState(player: player, button: button, pressed: pressed)
    }

    private func setupHaptics(for controller: GCController) {
        guard controller.haptics != nil else { return }

        do {
            let engine = try CHHapticEngine()
            hapticEngines[controller] = engine
            try engine.start()
            logger.info("Haptics initialized for controller")
        } catch {
            logger.error("Failed to setup haptics: \(error.localizedDescription)")
        }
    }

    private func getCurrentMappings(for controller: GCController) -> [String: String] {
        // Get current button mappings for the controller
        var mappings: [String: String] = [:]

        if controller.extendedGamepad != nil {
            mappings["A"] = "A"
            mappings["B"] = "B"
            mappings["X"] = "X"
            mappings["Y"] = "Y"
            // Add more mappings
        }

        return mappings
    }

    // MARK: - Profile Management

    private func loadControllerProfiles() {
        guard let data = UserDefaults.standard.data(forKey: "ControllerProfiles"),
              let profiles = try? JSONDecoder().decode([String: ControllerProfile].self, from: data) else {
            return
        }

        controllerProfiles = profiles
        logger.info("Loaded \(profiles.count) controller profiles")
    }

    private func saveControllerProfiles() {
        guard let data = try? JSONEncoder().encode(controllerProfiles) else { return }
        UserDefaults.standard.set(data, forKey: "ControllerProfiles")
    }
}

// MARK: - Controller Profile

struct ControllerProfile: Codable {
    let name: String
    let vendorName: String
    let mappings: [String: String]
}

// MARK: - Input Mapper

/// Maps physical controller inputs to emulator inputs
final class InputMapper {

    private var mappings: [String: [String: EmulatorButton]] = [:]

    init() {
        setupDefaultMappings()
    }

    private func setupDefaultMappings() {
        // Xbox controller mapping
        mappings["Xbox"] = [
            "A": .a,
            "B": .b,
            "X": .x,
            "Y": .y,
            "LB": .l,
            "RB": .r,
            "LT": .zl,
            "RT": .zr,
            "Start": .start,
            "Select": .select
        ]

        // PlayStation controller mapping
        mappings["PlayStation"] = [
            "Cross": .a,
            "Circle": .b,
            "Square": .x,
            "Triangle": .y,
            "L1": .l,
            "R1": .r,
            "L2": .zl,
            "R2": .zr,
            "Options": .start,
            "Share": .select
        ]

        // Switch Pro Controller mapping
        mappings["Switch"] = [
            "A": .a,
            "B": .b,
            "X": .x,
            "Y": .y,
            "L": .l,
            "R": .r,
            "ZL": .zl,
            "ZR": .zr,
            "+": .start,
            "-": .select
        ]
    }

    func mapButton(_ physical: String, for controller: String) -> EmulatorButton? {
        mappings[controller]?[physical]
    }

    func setMapping(_ physical: String, to emulated: EmulatorButton, for controller: String) {
        if mappings[controller] == nil {
            mappings[controller] = [:]
        }
        mappings[controller]?[physical] = emulated
    }
}

// MARK: - CHHapticEngine Extensions

import CoreHaptics

extension CHHapticEngine {
    static func createEngine() -> CHHapticEngine? {
        do {
            let engine = try CHHapticEngine()
            return engine
        } catch {
            return nil
        }
    }
}
