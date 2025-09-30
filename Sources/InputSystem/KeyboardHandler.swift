import Foundation
import AppKit
import CoreInterface
import Combine

/// Handles keyboard input for the emulator
public final class KeyboardHandler: ObservableObject {

    // MARK: - Properties

    @Published public private(set) var keysPressed: Set<UInt16> = []

    // Key mappings for each player
    private var keyMappings: [Int: KeyMapping] = [:]

    // Input delegates
    private var inputDelegates: [Int: EmulatorInputProtocol?] = [:]

    // Default key codes
    private enum DefaultKeys {
        // Player 1
        static let p1Up: UInt16 = 126      // Arrow Up
        static let p1Down: UInt16 = 125    // Arrow Down
        static let p1Left: UInt16 = 123    // Arrow Left
        static let p1Right: UInt16 = 124   // Arrow Right
        static let p1A: UInt16 = 49        // Space
        static let p1B: UInt16 = 7         // X
        static let p1X: UInt16 = 6         // Z
        static let p1Y: UInt16 = 0         // A
        static let p1L: UInt16 = 12        // Q
        static let p1R: UInt16 = 14        // E
        static let p1Start: UInt16 = 36    // Return
        static let p1Select: UInt16 = 48   // Tab

        // Player 2 (numpad)
        static let p2Up: UInt16 = 91       // Numpad 8
        static let p2Down: UInt16 = 84     // Numpad 2
        static let p2Left: UInt16 = 86     // Numpad 4
        static let p2Right: UInt16 = 88    // Numpad 6
        static let p2A: UInt16 = 82        // Numpad 0
        static let p2B: UInt16 = 65        // Numpad .
        static let p2X: UInt16 = 89        // Numpad 7
        static let p2Y: UInt16 = 92        // Numpad 9
        static let p2L: UInt16 = 83        // Numpad 1
        static let p2R: UInt16 = 85        // Numpad 3
        static let p2Start: UInt16 = 76    // Numpad Enter
        static let p2Select: UInt16 = 71   // Numpad Clear

        // System
        static let pause: UInt16 = 53      // Escape
        static let fastForward: UInt16 = 47 // .
        static let saveState: UInt16 = 1   // S
        static let loadState: UInt16 = 37  // L
        static let screenshot: UInt16 = 3  // F
        static let fullscreen: UInt16 = 45 // N
    }

    // MARK: - Singleton

    public static let shared = KeyboardHandler()

    // MARK: - Initialization

    private init() {
        setupDefaultMappings()
        loadCustomMappings()
    }

    // MARK: - Setup

    private func setupDefaultMappings() {
        // Player 1 default mapping
        keyMappings[0] = KeyMapping(
            up: DefaultKeys.p1Up,
            down: DefaultKeys.p1Down,
            left: DefaultKeys.p1Left,
            right: DefaultKeys.p1Right,
            a: DefaultKeys.p1A,
            b: DefaultKeys.p1B,
            x: DefaultKeys.p1X,
            y: DefaultKeys.p1Y,
            l: DefaultKeys.p1L,
            r: DefaultKeys.p1R,
            zl: nil,
            zr: nil,
            start: DefaultKeys.p1Start,
            select: DefaultKeys.p1Select,
            home: nil,
            capture: nil,
            leftStick: nil,
            rightStick: nil
        )

        // Player 2 default mapping
        keyMappings[1] = KeyMapping(
            up: DefaultKeys.p2Up,
            down: DefaultKeys.p2Down,
            left: DefaultKeys.p2Left,
            right: DefaultKeys.p2Right,
            a: DefaultKeys.p2A,
            b: DefaultKeys.p2B,
            x: DefaultKeys.p2X,
            y: DefaultKeys.p2Y,
            l: DefaultKeys.p2L,
            r: DefaultKeys.p2R,
            zl: nil,
            zr: nil,
            start: DefaultKeys.p2Start,
            select: DefaultKeys.p2Select,
            home: nil,
            capture: nil,
            leftStick: nil,
            rightStick: nil
        )
    }

    private func loadCustomMappings() {
        // Load from UserDefaults
        if let data = UserDefaults.standard.data(forKey: "KeyboardMappings"),
           let mappings = try? JSONDecoder().decode([Int: KeyMapping].self, from: data) {
            keyMappings = mappings
        }
    }

    // MARK: - Public Methods

    /// Handle key down event
    public func handleKeyDown(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode

        // Check for system shortcuts first
        if handleSystemKey(keyCode, pressed: true) {
            return true
        }

        // Add to pressed keys
        keysPressed.insert(keyCode)

        // Process for each player
        for (player, mapping) in keyMappings {
            if let button = mapping.buttonForKey(keyCode) {
                inputDelegates[player]??.setButtonState(
                    player: player,
                    button: button,
                    pressed: true
                )
                return true
            }
        }

        return false
    }

    /// Handle key up event
    public func handleKeyUp(_ event: NSEvent) -> Bool {
        let keyCode = event.keyCode

        // Check for system shortcuts first
        if handleSystemKey(keyCode, pressed: false) {
            return true
        }

        // Remove from pressed keys
        keysPressed.remove(keyCode)

        // Process for each player
        for (player, mapping) in keyMappings {
            if let button = mapping.buttonForKey(keyCode) {
                inputDelegates[player]??.setButtonState(
                    player: player,
                    button: button,
                    pressed: false
                )
                return true
            }
        }

        return false
    }

    /// Set input delegate for a player
    public func setInputDelegate(_ delegate: EmulatorInputProtocol?, for player: Int) {
        inputDelegates[player] = delegate
    }

    /// Update key mapping for a player
    public func updateMapping(for player: Int, button: EmulatorButton, keyCode: UInt16) {
        if keyMappings[player] == nil {
            keyMappings[player] = KeyMapping()
        }

        keyMappings[player]?.updateKey(for: button, keyCode: keyCode)
        saveMappings()
    }

    /// Get current mapping for a player
    public func getMapping(for player: Int) -> KeyMapping? {
        keyMappings[player]
    }

    /// Reset mappings to default
    public func resetMappings(for player: Int) {
        if player == 0 {
            setupDefaultMappings()
        } else if player == 1 {
            setupDefaultMappings()
        }
        saveMappings()
    }

    // MARK: - Private Methods

    private func handleSystemKey(_ keyCode: UInt16, pressed: Bool) -> Bool {
        guard pressed else { return false }

        switch keyCode {
        case DefaultKeys.pause:
            NotificationCenter.default.post(name: .togglePause, object: nil)
            return true

        case DefaultKeys.fastForward:
            NotificationCenter.default.post(name: .toggleFastForward, object: nil)
            return true

        case DefaultKeys.saveState:
            if NSEvent.modifierFlags.contains(.command) {
                NotificationCenter.default.post(name: .saveState, object: nil)
                return true
            }

        case DefaultKeys.loadState:
            if NSEvent.modifierFlags.contains(.command) {
                NotificationCenter.default.post(name: .loadState, object: nil)
                return true
            }

        case DefaultKeys.screenshot:
            if NSEvent.modifierFlags.contains(.command) {
                NotificationCenter.default.post(name: .takeScreenshot, object: nil)
                return true
            }

        case DefaultKeys.fullscreen:
            if NSEvent.modifierFlags.contains(.command) {
                NotificationCenter.default.post(name: .toggleFullscreen, object: nil)
                return true
            }

        default:
            break
        }

        return false
    }

    private func saveMappings() {
        if let data = try? JSONEncoder().encode(keyMappings) {
            UserDefaults.standard.set(data, forKey: "KeyboardMappings")
        }
    }
}

// MARK: - Key Mapping

public struct KeyMapping: Codable {
    var up: UInt16?
    var down: UInt16?
    var left: UInt16?
    var right: UInt16?
    var a: UInt16?
    var b: UInt16?
    var x: UInt16?
    var y: UInt16?
    var l: UInt16?
    var r: UInt16?
    var zl: UInt16?
    var zr: UInt16?
    var start: UInt16?
    var select: UInt16?
    var home: UInt16?
    var capture: UInt16?
    var leftStick: UInt16?
    var rightStick: UInt16?

    func buttonForKey(_ keyCode: UInt16) -> EmulatorButton? {
        switch keyCode {
        case up: return .up
        case down: return .down
        case left: return .left
        case right: return .right
        case a: return .a
        case b: return .b
        case x: return .x
        case y: return .y
        case l: return .l
        case r: return .r
        case zl: return .zl
        case zr: return .zr
        case start: return .start
        case select: return .select
        case home: return .home
        case capture: return .capture
        default: return nil
        }
    }

    mutating func updateKey(for button: EmulatorButton, keyCode: UInt16) {
        switch button {
        case .up: up = keyCode
        case .down: down = keyCode
        case .left: left = keyCode
        case .right: right = keyCode
        case .a: a = keyCode
        case .b: b = keyCode
        case .x: x = keyCode
        case .y: y = keyCode
        case .l: l = keyCode
        case .r: r = keyCode
        case .zl: zl = keyCode
        case .zr: zr = keyCode
        case .start: start = keyCode
        case .select: select = keyCode
        case .home: home = keyCode
        case .capture: capture = keyCode
        case .cUp, .cDown, .cLeft, .cRight, .z:
            // N64 specific buttons - not mapped for keyboard
            break
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let togglePause = Notification.Name("togglePause")
    static let toggleFastForward = Notification.Name("toggleFastForward")
    static let saveState = Notification.Name("saveState")
    static let loadState = Notification.Name("loadState")
    static let takeScreenshot = Notification.Name("takeScreenshot")
    static let toggleFullscreen = Notification.Name("toggleFullscreen")
}

// MARK: - Key Code Helper

public struct KeyCodeHelper {
    public static func keyName(for keyCode: UInt16) -> String {
        switch keyCode {
        case 0: return "A"
        case 1: return "S"
        case 2: return "D"
        case 3: return "F"
        case 4: return "H"
        case 5: return "G"
        case 6: return "Z"
        case 7: return "X"
        case 8: return "C"
        case 9: return "V"
        case 11: return "B"
        case 12: return "Q"
        case 13: return "W"
        case 14: return "E"
        case 15: return "R"
        case 16: return "Y"
        case 17: return "T"
        case 18: return "1"
        case 19: return "2"
        case 20: return "3"
        case 21: return "4"
        case 22: return "6"
        case 23: return "5"
        case 24: return "="
        case 25: return "9"
        case 26: return "7"
        case 27: return "-"
        case 28: return "8"
        case 29: return "0"
        case 30: return "]"
        case 31: return "O"
        case 32: return "U"
        case 33: return "["
        case 34: return "I"
        case 35: return "P"
        case 36: return "Return"
        case 37: return "L"
        case 38: return "J"
        case 39: return "'"
        case 40: return "K"
        case 41: return ";"
        case 42: return "\\"
        case 43: return ","
        case 44: return "/"
        case 45: return "N"
        case 46: return "M"
        case 47: return "."
        case 48: return "Tab"
        case 49: return "Space"
        case 50: return "`"
        case 51: return "Delete"
        case 53: return "Escape"
        case 55: return "Command"
        case 56: return "Shift"
        case 57: return "Caps Lock"
        case 58: return "Option"
        case 59: return "Control"
        case 60: return "Right Shift"
        case 61: return "Right Option"
        case 62: return "Right Control"
        case 63: return "Function"
        case 64: return "F17"
        case 65: return "Numpad ."
        case 67: return "Numpad *"
        case 69: return "Numpad +"
        case 71: return "Numpad Clear"
        case 75: return "Numpad /"
        case 76: return "Numpad Enter"
        case 78: return "Numpad -"
        case 79: return "F18"
        case 80: return "F19"
        case 81: return "Numpad ="
        case 82: return "Numpad 0"
        case 83: return "Numpad 1"
        case 84: return "Numpad 2"
        case 85: return "Numpad 3"
        case 86: return "Numpad 4"
        case 87: return "Numpad 5"
        case 88: return "Numpad 6"
        case 89: return "Numpad 7"
        case 90: return "F20"
        case 91: return "Numpad 8"
        case 92: return "Numpad 9"
        case 96: return "F5"
        case 97: return "F6"
        case 98: return "F7"
        case 99: return "F3"
        case 100: return "F8"
        case 101: return "F9"
        case 103: return "F11"
        case 105: return "F13"
        case 106: return "F16"
        case 107: return "F14"
        case 109: return "F10"
        case 111: return "F12"
        case 113: return "F15"
        case 114: return "Help"
        case 115: return "Home"
        case 116: return "Page Up"
        case 117: return "Forward Delete"
        case 118: return "F4"
        case 119: return "End"
        case 120: return "F2"
        case 121: return "Page Down"
        case 122: return "F1"
        case 123: return "Left Arrow"
        case 124: return "Right Arrow"
        case 125: return "Down Arrow"
        case 126: return "Up Arrow"
        default: return "Key \(keyCode)"
        }
    }
}