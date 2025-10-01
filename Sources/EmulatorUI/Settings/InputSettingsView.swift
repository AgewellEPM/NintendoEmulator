import SwiftUI
import GameController
import EmulatorKit

struct InputSettingsView: View {
    @Binding var vibrationEnabled: Bool
    @Binding var analogDeadzone: Double
    @Binding var analogSensitivity: Double

    @StateObject private var controllerManager = GameControllerManager.shared
    @State private var selectedController: GCController?
    @State private var showingControllerConfig = false
    @State private var isScanning = false
    @State private var selectedPlayerIndex = 0
    @State private var showingTestMode = false

    var body: some View {
        Form {
            // Controller Detection Section
            Section("Connected Controllers") {
                if controllerManager.connectedControllers.isEmpty {
                    HStack {
                        Image(systemName: "gamecontroller")
                            .foregroundColor(.secondary)
                        Text("No controllers connected")
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 8)

                    HStack {
                        Button(action: {
                            isScanning = true
                            controllerManager.scanForControllers()
                            DispatchQueue.main.asyncAfter(deadline: .now() + 10) {
                                isScanning = false
                            }
                        }) {
                            HStack {
                                if isScanning {
                                    ProgressView()
                                        .scaleEffect(0.8)
                                        .frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "wifi")
                                }
                                Text(isScanning ? "Scanning..." : "Scan for Wireless Controllers")
                            }
                        }
                        .disabled(isScanning)

                        Spacer()

                        Button("Bluetooth Settings") {
                            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.bluetooth")!)
                        }
                        .buttonStyle(.bordered)
                    }
                } else {
                    ForEach(controllerManager.connectedControllers, id: \.self) { controller in
                        ControllerRow(
                            controller: controller,
                            isActive: controller == controllerManager.activeController,
                            onSelect: {
                                controllerManager.setActiveController(controller)
                                selectedController = controller
                            }
                        )
                    }
                }
            }

            // Active Controller Settings
            if let activeController = controllerManager.activeController {
                Section("Active Controller: \(activeController.vendorName ?? "Unknown")") {
                    // Controller Info
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("Type:")
                                .foregroundColor(.secondary)
                            Text(getControllerType(activeController))
                        }

                        if let battery = activeController.battery {
                            HStack {
                                Text("Battery:")
                                    .foregroundColor(.secondary)
                                BatteryIndicator(level: battery.batteryLevel, state: battery.batteryState)
                            }
                        }

                        HStack {
                            Text("Player Index:")
                                .foregroundColor(.secondary)
                            Picker("", selection: $selectedPlayerIndex) {
                                ForEach(0..<4) { index in
                                    Text("Player \(index + 1)").tag(index)
                                }
                            }
                            .pickerStyle(SegmentedPickerStyle())
                            .frame(width: 200)
                            .onChange(of: selectedPlayerIndex) { newValue in
                                activeController.playerIndex = GCControllerPlayerIndex(rawValue: newValue) ?? .index1
                            }
                        }
                    }
                    .padding(.vertical, 4)

                    // Controller Actions
                    HStack {
                        Button("Configure Mapping") {
                            showingControllerConfig = true
                        }
                        .sheet(isPresented: $showingControllerConfig) {
                            ControllerMappingView(
                                controller: activeController,
                                playerIndex: selectedPlayerIndex
                            )
                        }

                        Button("Test Controller") {
                            showingTestMode = true
                        }
                        .sheet(isPresented: $showingTestMode) {
                            ControllerTestView(controller: activeController)
                        }

                        if activeController.haptics != nil {
                            Button("Test Vibration") {
                                controllerManager.triggerHapticFeedback(intensity: 0.7, duration: 0.3)
                            }
                        }
                    }
                }
            }

            // Analog Settings
            Section("Analog Sticks") {
                HStack {
                    Text("Dead Zone")
                    Slider(value: $analogDeadzone, in: 0...0.5, step: 0.05) {
                        Text("Dead Zone")
                    }
                    Text("\(Int(analogDeadzone * 100))%")
                        .frame(width: 50)
                }

                HStack {
                    Text("Sensitivity")
                    Slider(value: $analogSensitivity, in: 0.5...2.0, step: 0.1) {
                        Text("Sensitivity")
                    }
                    Text("\(analogSensitivity, specifier: "%.1f")x")
                        .frame(width: 50)
                }

                Toggle("Enable Vibration/Haptics", isOn: $vibrationEnabled)
            }

            // Emulator-Specific Settings
            Section("Emulator Mappings") {
                NavigationLink("N64 Controller Mapping") {
                    N64ControllerMappingView()
                }
                NavigationLink("SNES Controller Mapping") {
                    Text("SNES mapping coming soon")
                }
                NavigationLink("NES Controller Mapping") {
                    Text("NES mapping coming soon")
                }
            }

            // Keyboard Mappings
            Section("Keyboard") {
                Button("Configure Keyboard Controls") {
                    // Show keyboard mapping
                }
                .disabled(true) // Will implement later

                Text("Keyboard controls allow you to play without a controller")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Advanced Settings
            Section("Advanced") {
                Button("Reset All Controller Settings") {
                    vibrationEnabled = true
                    analogDeadzone = 0.15
                    analogSensitivity = 1.0
                    // Reset mappings
                }
                .foregroundColor(.red)

                Button("Export Controller Profile") {
                    exportControllerProfile()
                }

                Button("Import Controller Profile") {
                    importControllerProfile()
                }
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // Set initial player index from active controller
            if let activeController = controllerManager.activeController {
                selectedPlayerIndex = activeController.playerIndex.rawValue
            }
        }
    }

    private func getControllerType(_ controller: GCController) -> String {
        if controller.extendedGamepad != nil {
            return "Extended Gamepad"
        } else if controller.microGamepad != nil {
            return "Micro Gamepad"
        } else {
            return "Unknown"
        }
    }

    private func exportControllerProfile() {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [.json]
        savePanel.nameFieldStringValue = "controller_profile.json"

        if savePanel.runModal() == .OK, let url = savePanel.url {
            // Export controller mappings
            let mappings = controllerManager.controllerMappings
            if let data = try? JSONEncoder().encode(mappings) {
                try? data.write(to: url)
            }
        }
    }

    private func importControllerProfile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false

        if openPanel.runModal() == .OK, let url = openPanel.url {
            // Import controller mappings
            if let data = try? Data(contentsOf: url),
               let mappings = try? JSONDecoder().decode([Int: GameControllerManager.ControllerMapping].self, from: data) {
                for (index, mapping) in mappings {
                    controllerManager.setMapping(mapping, for: index)
                }
            }
        }
    }
}

// MARK: - Controller Row
struct ControllerRow: View {
    let controller: GCController
    let isActive: Bool
    let onSelect: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "gamecontroller.fill")
                .foregroundColor(isActive ? .accentColor : .secondary)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(controller.vendorName ?? "Unknown Controller")
                    .font(.headline)

                HStack {
                    if controller.isAttachedToDevice {
                        Label("Built-in", systemImage: "iphone")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let battery = controller.battery {
                        BatteryIndicator(level: battery.batteryLevel, state: battery.batteryState)
                            .font(.caption)
                    }

                    Text("Player \(controller.playerIndex.rawValue + 1)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if isActive {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                Button("Set Active") {
                    onSelect()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Battery Indicator
struct BatteryIndicator: View {
    let level: Float
    let state: GCDeviceBattery.State

    var body: some View {
        HStack(spacing: DesignSystem.Spacing.xs) {
            Image(systemName: batteryIcon)
                .foregroundColor(batteryColor)

            Text("\(Int(level * 100))%")
                .foregroundColor(.secondary)
        }
    }

    private var batteryIcon: String {
        switch level {
        case 0..<0.25:
            return state == .charging ? "battery.25" : "battery.0"
        case 0.25..<0.5:
            return state == .charging ? "battery.50" : "battery.25"
        case 0.5..<0.75:
            return state == .charging ? "battery.75" : "battery.50"
        default:
            return state == .charging ? "battery.100.bolt" : "battery.100"
        }
    }

    private var batteryColor: Color {
        if state == .charging {
            return .green
        } else if level < 0.2 {
            return .red
        } else if level < 0.5 {
            return .orange
        } else {
            return .primary
        }
    }
}

// MARK: - Controller Mapping View
struct ControllerMappingView: View {
    let controller: GCController
    let playerIndex: Int
    @Environment(\.dismiss) private var dismiss
    @StateObject private var controllerManager = GameControllerManager.shared
    @State private var mapping: GameControllerManager.ControllerMapping
    @State private var isListeningForInput = false
    @State private var currentButton = ""

    init(controller: GCController, playerIndex: Int) {
        self.controller = controller
        self.playerIndex = playerIndex
        _mapping = State(initialValue: GameControllerManager.shared.getMapping(for: playerIndex))
    }

    var body: some View {
        VStack {
            // Header
            HStack {
                Text("Controller Mapping")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Spacer()

                Text("\(controller.vendorName ?? "Controller") - Player \(playerIndex + 1)")
                    .foregroundColor(.secondary)
            }
            .padding()

            Divider()

            // Mapping List
            ScrollView {
                VStack(spacing: DesignSystem.Spacing.lg) {
                    // Face Buttons
                    MappingSection(title: "Face Buttons") {
                        MappingRow(label: "A Button", mapping: $mapping.buttonA, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "B Button", mapping: $mapping.buttonB, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "X Button", mapping: $mapping.buttonX, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "Y Button", mapping: $mapping.buttonY, currentButton: $currentButton, isListening: $isListeningForInput)
                    }

                    // Shoulders & Triggers
                    MappingSection(title: "Shoulders & Triggers") {
                        MappingRow(label: "Left Shoulder", mapping: $mapping.leftShoulder, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "Right Shoulder", mapping: $mapping.rightShoulder, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "Left Trigger", mapping: $mapping.leftTrigger, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "Right Trigger", mapping: $mapping.rightTrigger, currentButton: $currentButton, isListening: $isListeningForInput)
                    }

                    // D-Pad
                    MappingSection(title: "D-Pad") {
                        MappingRow(label: "D-Pad Up", mapping: $mapping.dpadUp, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "D-Pad Down", mapping: $mapping.dpadDown, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "D-Pad Left", mapping: $mapping.dpadLeft, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "D-Pad Right", mapping: $mapping.dpadRight, currentButton: $currentButton, isListening: $isListeningForInput)
                    }

                    // Control Sticks
                    MappingSection(title: "Control Sticks") {
                        MappingRow(label: "Left Stick", mapping: $mapping.leftThumbstick, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "Right Stick", mapping: $mapping.rightThumbstick, currentButton: $currentButton, isListening: $isListeningForInput)
                    }

                    // System Buttons
                    MappingSection(title: "System Buttons") {
                        MappingRow(label: "Menu/Start", mapping: $mapping.menu, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "Options/Select", mapping: $mapping.options, currentButton: $currentButton, isListening: $isListeningForInput)
                    }

                    // N64 Specific
                    MappingSection(title: "N64 Specific") {
                        MappingRow(label: "C-Up", mapping: $mapping.cButtonUp, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "C-Down", mapping: $mapping.cButtonDown, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "C-Left", mapping: $mapping.cButtonLeft, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "C-Right", mapping: $mapping.cButtonRight, currentButton: $currentButton, isListening: $isListeningForInput)
                        MappingRow(label: "Z Button", mapping: $mapping.zButton, currentButton: $currentButton, isListening: $isListeningForInput)
                    }
                }
                .padding()
            }

            Divider()

            // Footer Buttons
            HStack {
                Button("Reset to Defaults") {
                    mapping = GameControllerManager.ControllerMapping()
                }
                .foregroundColor(.red)

                Spacer()

                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)

                Button("Save") {
                    controllerManager.setMapping(mapping, for: playerIndex)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
            .padding()
        }
        .frame(width: 600, height: 700)
    }
}

// MARK: - Mapping Section
struct MappingSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Text(title)
                .font(.headline)
                .foregroundColor(.secondary)

            VStack(spacing: DesignSystem.Spacing.sm) {
                content
            }
            .padding()
            .background(Color.gray.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.lg)
        }
    }
}

// MARK: - Mapping Row
struct MappingRow: View {
    let label: String
    @Binding var mapping: String
    @Binding var currentButton: String
    @Binding var isListening: Bool

    var body: some View {
        HStack {
            Text(label)
                .frame(width: 150, alignment: .leading)

            Spacer()

            Text(mapping)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isListening && currentButton == label ? Color.accentColor.opacity(0.2) : Color.gray.opacity(0.2))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 6)
                        .stroke(isListening && currentButton == label ? Color.accentColor : Color.clear, lineWidth: 2)
                )

            Button(isListening && currentButton == label ? "Cancel" : "Change") {
                if isListening && currentButton == label {
                    isListening = false
                    currentButton = ""
                } else {
                    isListening = true
                    currentButton = label
                    // Start listening for controller input
                }
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }
}

// MARK: - Controller Test View
struct ControllerTestView: View {
    let controller: GCController
    @Environment(\.dismiss) private var dismiss
    @State private var inputStates: [String: Bool] = [:]
    @State private var analogValues: [String: (x: Float, y: Float)] = [:]
    @State private var triggerValues: [String: Float] = [:]

    var body: some View {
        VStack {
            Text("Controller Test")
                .font(.largeTitle)
                .fontWeight(.bold)
                .padding()

            Text("\(controller.vendorName ?? "Controller")")
                .foregroundColor(.secondary)

            Divider()

            // Visual representation of controller
            ControllerVisualizer(
                inputStates: inputStates,
                analogValues: analogValues,
                triggerValues: triggerValues
            )
            .frame(height: 300)
            .padding()

            // Input log
            ScrollView {
                VStack(alignment: .leading, spacing: DesignSystem.Spacing.xs) {
                    Text("Input Log:")
                        .font(.headline)

                    ForEach(Array(inputStates.keys.sorted()), id: \.self) { key in
                        if inputStates[key] == true {
                            Text("• \(key) pressed")
                                .foregroundColor(.green)
                        }
                    }

                    ForEach(Array(analogValues.keys.sorted()), id: \.self) { key in
                        if let value = analogValues[key], abs(value.x) > 0.1 || abs(value.y) > 0.1 {
                            Text("• \(key): X=\(value.x, specifier: "%.2f") Y=\(value.y, specifier: "%.2f")")
                                .foregroundColor(.blue)
                        }
                    }
                }
                .padding()
            }
            .frame(height: 150)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(DesignSystem.Radius.lg)
            .padding(.horizontal)

            Button("Close") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .padding()
        }
        .frame(width: 500, height: 600)
        .onAppear {
            setupControllerMonitoring()
        }
    }

    private func setupControllerMonitoring() {
        guard let gamepad = controller.extendedGamepad else { return }

        // Monitor all inputs
        gamepad.buttonA.valueChangedHandler = { _, _, pressed in
            inputStates["A"] = pressed
        }
        gamepad.buttonB.valueChangedHandler = { _, _, pressed in
            inputStates["B"] = pressed
        }
        gamepad.buttonX.valueChangedHandler = { _, _, pressed in
            inputStates["X"] = pressed
        }
        gamepad.buttonY.valueChangedHandler = { _, _, pressed in
            inputStates["Y"] = pressed
        }
        gamepad.leftShoulder.valueChangedHandler = { _, _, pressed in
            inputStates["L"] = pressed
        }
        gamepad.rightShoulder.valueChangedHandler = { _, _, pressed in
            inputStates["R"] = pressed
        }
        gamepad.leftTrigger.valueChangedHandler = { _, value, _ in
            triggerValues["LT"] = value
        }
        gamepad.rightTrigger.valueChangedHandler = { _, value, _ in
            triggerValues["RT"] = value
        }
        gamepad.leftThumbstick.valueChangedHandler = { _, x, y in
            analogValues["Left Stick"] = (x: x, y: y)
        }
        gamepad.rightThumbstick.valueChangedHandler = { _, x, y in
            analogValues["Right Stick"] = (x: x, y: y)
        }
        gamepad.dpad.valueChangedHandler = { _, x, y in
            analogValues["D-Pad"] = (x: x, y: y)
        }
    }
}

// MARK: - Controller Visualizer
struct ControllerVisualizer: View {
    let inputStates: [String: Bool]
    let analogValues: [String: (x: Float, y: Float)]
    let triggerValues: [String: Float]

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Controller outline
                RoundedRectangle(cornerRadius: 30)
                    .stroke(Color.gray, lineWidth: 2)
                    .frame(width: 300, height: 200)

                // Face buttons
                VStack(spacing: DesignSystem.Spacing.sm) {
                    ButtonIndicator(label: "Y", isPressed: inputStates["Y"] ?? false)
                    HStack(spacing: DesignSystem.Spacing.sm) {
                        ButtonIndicator(label: "X", isPressed: inputStates["X"] ?? false)
                        Spacer().frame(width: 20)
                        ButtonIndicator(label: "A", isPressed: inputStates["A"] ?? false)
                    }
                    ButtonIndicator(label: "B", isPressed: inputStates["B"] ?? false)
                }
                .position(x: 220, y: 100)

                // D-Pad
                DPadIndicator(value: analogValues["D-Pad"] ?? (x: 0, y: 0))
                    .position(x: 80, y: 100)

                // Analog sticks
                AnalogStickIndicator(value: analogValues["Left Stick"] ?? (x: 0, y: 0))
                    .position(x: 100, y: 170)

                AnalogStickIndicator(value: analogValues["Right Stick"] ?? (x: 0, y: 0))
                    .position(x: 200, y: 170)

                // Shoulders
                HStack(spacing: 150) {
                    ShoulderIndicator(label: "L", isPressed: inputStates["L"] ?? false)
                    ShoulderIndicator(label: "R", isPressed: inputStates["R"] ?? false)
                }
                .position(x: 150, y: 30)

                // Triggers
                HStack(spacing: 150) {
                    TriggerIndicator(label: "LT", value: triggerValues["LT"] ?? 0)
                    TriggerIndicator(label: "RT", value: triggerValues["RT"] ?? 0)
                }
                .position(x: 150, y: 10)
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}

struct ButtonIndicator: View {
    let label: String
    let isPressed: Bool

    var body: some View {
        Circle()
            .fill(isPressed ? Color.green : Color.gray.opacity(0.3))
            .frame(width: 30, height: 30)
            .overlay(
                Text(label)
                    .font(.caption)
                    .foregroundColor(isPressed ? .white : .primary)
            )
    }
}

struct DPadIndicator: View {
    let value: (x: Float, y: Float)

    var body: some View {
        ZStack {
            // D-Pad shape
            VStack(spacing: 0) {
                Rectangle()
                    .fill(value.y > 0.5 ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 20, height: 25)
                HStack(spacing: 0) {
                    Rectangle()
                        .fill(value.x < -0.5 ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 25, height: 20)
                    Rectangle()
                        .fill(Color.clear)
                        .frame(width: 20, height: 20)
                    Rectangle()
                        .fill(value.x > 0.5 ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 25, height: 20)
                }
                Rectangle()
                    .fill(value.y < -0.5 ? Color.green : Color.gray.opacity(0.3))
                    .frame(width: 20, height: 25)
            }
        }
    }
}

struct AnalogStickIndicator: View {
    let value: (x: Float, y: Float)

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray, lineWidth: 2)
                .frame(width: 40, height: 40)

            Circle()
                .fill(Color.blue)
                .frame(width: 15, height: 15)
                .offset(x: CGFloat(value.x) * 12, y: CGFloat(-value.y) * 12)
        }
    }
}

struct ShoulderIndicator: View {
    let label: String
    let isPressed: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 5)
            .fill(isPressed ? Color.green : Color.gray.opacity(0.3))
            .frame(width: 40, height: 15)
            .overlay(
                Text(label)
                    .font(.caption2)
                    .foregroundColor(isPressed ? .white : .primary)
            )
    }
}

struct TriggerIndicator: View {
    let label: String
    let value: Float

    var body: some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
            RoundedRectangle(cornerRadius: 3)
                .fill(value > 0.1 ? Color.green.opacity(Double(value)) : Color.gray.opacity(0.3))
                .frame(width: 35, height: 8)
        }
    }
}

// MARK: - N64 Controller Mapping View
struct N64ControllerMappingView: View {
    @State private var mapping = N64ControllerMapping()
    @State private var rumbleEnabled = true
    @State private var analogDeadzone: Double = 0.125
    @State private var analogPeak: Double = 1.0
    @State private var showConfigFile = false

    struct N64ControllerMapping: Codable {
        var aButton = "button(1)"
        var bButton = "button(0)"
        var startButton = "button(10)"
        var lTrigger = "button(4)"
        var rTrigger = "button(6)"
        var zTrigger = "button(7)"
        var cUp = "axis(3+)"
        var cDown = "axis(3-)"
        var cLeft = "axis(2-)"
        var cRight = "axis(2+)"
        var analogStickX = "axis(0-,0+)"
        var analogStickY = "axis(1-,1+)"
        var dpadUp = "hat(0 Up)"
        var dpadDown = "hat(0 Down)"
        var dpadLeft = "hat(0 Left)"
        var dpadRight = "hat(0 Right)"
        var rumblePak = "button(2)"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: DesignSystem.Spacing.lg) {
                // Header with controller image
                VStack(spacing: DesignSystem.Spacing.md) {
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.accentColor)

                    Text("Nintendo Switch Pro Controller")
                        .font(.title2)
                        .fontWeight(.bold)

                    Text("Perfect N64 Controller Mapping")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: DesignSystem.Radius.lg)
                        .fill(Color.accentColor.opacity(0.1))
                )

                // Configuration Overview
                GroupBox {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Label("Controller Layout", systemImage: "info.circle")
                            .font(.headline)

                        Text("This mapping perfectly mimics a real N64 controller:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Divider()

                        VStack(alignment: .leading, spacing: 4) {
                            InfoRow(icon: "circle.fill", label: "Face Buttons", value: "B (B button) / A (A button)")
                            InfoRow(icon: "l.square.fill", label: "Triggers", value: "L (L shoulder) / R (R shoulder) / ZR (Z trigger)")
                            InfoRow(icon: "play.circle.fill", label: "Start", value: "+ button (Start)")
                            InfoRow(icon: "dpad.fill", label: "D-Pad", value: "Hat switch (D-pad)")
                            InfoRow(icon: "joystick.fill", label: "Left Stick", value: "N64 Analog Stick (movement)")
                            InfoRow(icon: "camera.fill", label: "Right Stick", value: "C-Buttons (camera/aim in GoldenEye)")
                            InfoRow(icon: "waveform", label: "Rumble", value: "X button toggles Rumble Pak")
                        }
                    }
                    .padding()
                }

                // Detailed Button Mappings
                GroupBox("Button Mappings") {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        MappingDetailRow(n64Button: "A Button", switchButton: "A", sdlCode: mapping.aButton, color: .blue)
                        MappingDetailRow(n64Button: "B Button", switchButton: "B", sdlCode: mapping.bButton, color: .green)
                        MappingDetailRow(n64Button: "Start Button", switchButton: "+", sdlCode: mapping.startButton, color: .orange)
                    }
                }

                GroupBox("Shoulder Buttons & Triggers") {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        MappingDetailRow(n64Button: "L Trigger", switchButton: "L", sdlCode: mapping.lTrigger, color: .purple)
                        MappingDetailRow(n64Button: "R Trigger", switchButton: "R", sdlCode: mapping.rTrigger, color: .purple)
                        MappingDetailRow(n64Button: "Z Trigger", switchButton: "ZR", sdlCode: mapping.zTrigger, color: .red)
                    }
                }

                GroupBox("C-Buttons (Camera Controls)") {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        MappingDetailRow(n64Button: "C-Up", switchButton: "Right Stick ↑", sdlCode: mapping.cUp, color: .cyan)
                        MappingDetailRow(n64Button: "C-Down", switchButton: "Right Stick ↓", sdlCode: mapping.cDown, color: .cyan)
                        MappingDetailRow(n64Button: "C-Left", switchButton: "Right Stick ←", sdlCode: mapping.cLeft, color: .cyan)
                        MappingDetailRow(n64Button: "C-Right", switchButton: "Right Stick →", sdlCode: mapping.cRight, color: .cyan)
                    }
                }

                GroupBox("Analog Controls") {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        HStack {
                            VStack(alignment: .leading) {
                                Text("N64 Analog Stick")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Left Stick")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            VStack(alignment: .trailing) {
                                Text("X: \(mapping.analogStickX)")
                                    .font(.caption)
                                    .monospaced()
                                Text("Y: \(mapping.analogStickY)")
                                    .font(.caption)
                                    .monospaced()
                            }
                            .foregroundColor(.secondary)
                        }

                        Divider()

                        VStack(spacing: 8) {
                            HStack {
                                Text("Dead Zone")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(analogDeadzone * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $analogDeadzone, in: 0...0.5, step: 0.025)

                            HStack {
                                Text("Analog Peak")
                                    .font(.caption)
                                Spacer()
                                Text("\(Int(analogPeak * 100))%")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Slider(value: $analogPeak, in: 0.5...1.5, step: 0.05)
                        }
                    }
                }

                GroupBox("D-Pad") {
                    VStack(spacing: DesignSystem.Spacing.md) {
                        MappingDetailRow(n64Button: "D-Pad Up", switchButton: "↑", sdlCode: mapping.dpadUp, color: .gray)
                        MappingDetailRow(n64Button: "D-Pad Down", switchButton: "↓", sdlCode: mapping.dpadDown, color: .gray)
                        MappingDetailRow(n64Button: "D-Pad Left", switchButton: "←", sdlCode: mapping.dpadLeft, color: .gray)
                        MappingDetailRow(n64Button: "D-Pad Right", switchButton: "→", sdlCode: mapping.dpadRight, color: .gray)
                    }
                }

                GroupBox("Rumble Pak") {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                        Toggle("Enable Rumble", isOn: $rumbleEnabled)

                        HStack {
                            VStack(alignment: .leading) {
                                Text("Rumble Toggle")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                Text("Press X to toggle Rumble Pak")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(mapping.rumblePak)
                                .font(.caption)
                                .monospaced()
                                .padding(6)
                                .background(Color.secondary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                }

                // Action Buttons
                VStack(spacing: DesignSystem.Spacing.md) {
                    Button(action: {
                        showConfigFile = true
                    }) {
                        Label("View Config File", systemImage: "doc.text")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)

                    Button(action: {
                        saveConfiguration()
                    }) {
                        Label("Apply Configuration", systemImage: "checkmark.circle")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    Button(action: {
                        openConfigLocation()
                    }) {
                        Label("Open Config Folder", systemImage: "folder")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                }
            }
            .padding()
        }
        .navigationTitle("N64 Controller Mapping")
        .sheet(isPresented: $showConfigFile) {
            ConfigFileView()
        }
    }

    private func saveConfiguration() {
        // Save to UserDefaults or config file
        let _ = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mupen64plus/InputAutoCfg.ini")

        // TODO: Implement configuration saving
        // Show success notification
        NSSound.beep()
    }

    private func openConfigLocation() {
        let configPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/mupen64plus")
        NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: configPath.path)
    }
}

// MARK: - Supporting Views
struct InfoRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundColor(.accentColor)
                .frame(width: 16)

            Text(label + ":")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 80, alignment: .leading)

            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }
}

struct MappingDetailRow: View {
    let n64Button: String
    let switchButton: String
    let sdlCode: String
    let color: Color

    var body: some View {
        HStack {
            // N64 side
            HStack(spacing: 8) {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: 8, height: 8)

                Text(n64Button)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Spacer()

            // Arrow
            Image(systemName: "arrow.right")
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            // Switch side
            VStack(alignment: .trailing, spacing: 2) {
                Text(switchButton)
                    .font(.subheadline)
                    .foregroundColor(color)
                    .fontWeight(.semibold)

                Text(sdlCode)
                    .font(.caption2)
                    .monospaced()
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}

struct ConfigFileView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("InputAutoCfg.ini")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                Button("Done") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
            .padding()
            .background(Color.secondary.opacity(0.1))

            // Config file content
            ScrollView {
                Text(configFileContent)
                    .font(.system(.caption, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .background(Color.black.opacity(0.05))
        }
        .frame(width: 700, height: 600)
    }

    private var configFileContent: String {
        """
        ; ═══════════════════════════════════════════════════════════════════
        ; Nintendo Switch Pro Controller - Perfect N64 Controller Mapping
        ; ═══════════════════════════════════════════════════════════════════
        ;
        ; Button Layout (matches real N64 controller):
        ;   Face Buttons:  B (B button) / A (A button)
        ;   Triggers:      L (L shoulder) / R (R shoulder) / ZR (Z trigger)
        ;   Start:         + button (Start)
        ;   D-Pad:         Hat switch (D-pad)
        ;   Left Stick:    N64 Analog Stick (movement)
        ;   Right Stick:   C-Buttons (camera/aim in GoldenEye)
        ;   Rumble:        X button toggles Rumble Pak
        ;
        ; ═══════════════════════════════════════════════════════════════════

        [Nintendo Switch Pro Controller]
        plugged = True
        mouse = False
        AnalogDeadzone = 4096,4096
        AnalogPeak = 32768,32768

        ; D-Pad
        DPad R = hat(0 Right)
        DPad L = hat(0 Left)
        DPad D = hat(0 Down)
        DPad U = hat(0 Up)

        ; Start Button
        Start = button(10)

        ; Action Buttons
        A Button = button(1)
        B Button = button(0)

        ; Triggers
        Z Trig = button(7)
        R Trig = button(6)
        L Trig = button(4)

        ; C-Buttons (Right Stick)
        C Button R = axis(2+)
        C Button L = axis(2-)
        C Button D = axis(3-)
        C Button U = axis(3+)

        ; Analog Stick
        X Axis = axis(0-,0+)
        Y Axis = axis(1-,1+)

        ; Memory/Rumble Paks
        Mempak switch =
        Rumblepak switch = button(2)
        """
    }
}