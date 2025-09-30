import SwiftUI
import UniformTypeIdentifiers

// This file provides shared UI state and UTType helpers for the EmulatorUI module.

public final class AppState: ObservableObject {
    @Published public var isEmulating = false
    @Published public var enableFullscreen = false
    @Published public var currentROM: URL?
    @Published public var showingSettings = false
    @Published public var showStreamChat = true
    @Published public var showInstallPrompt = false
    @Published public var showPermissionWizard = false

    public init() {}
}

// Global notifications for menu commands
public extension Notification.Name {
    static let emulatorStart = Notification.Name("EmulatorStart")
    static let emulatorPause = Notification.Name("EmulatorPause")
    static let emulatorStop = Notification.Name("EmulatorStop")
    static let emulatorOpenROM = Notification.Name("EmulatorOpenROM")
    static let gameStarted = Notification.Name("GameStarted")
    static let gameStopped = Notification.Name("GameStopped")
    static let showPermissionWizard = Notification.Name("ShowPermissionWizard")
    static let showToastMessage = Notification.Name("ShowToastMessage")
}

public extension UTType {
    static let rom = UTType(filenameExtension: "rom")!
    static let n64 = UTType(filenameExtension: "n64")!
    static let v64 = UTType(filenameExtension: "v64")!
    static let z64 = UTType(filenameExtension: "z64")!
    static let nes = UTType(filenameExtension: "nes")!
    static let smc = UTType(filenameExtension: "smc")!
    static let sfc = UTType(filenameExtension: "sfc")!
    static let gb = UTType(filenameExtension: "gb")!
    static let gbc = UTType(filenameExtension: "gbc")!
    static let gba = UTType(filenameExtension: "gba")!
    static let nds = UTType(filenameExtension: "nds")!
    static let dsi = UTType(filenameExtension: "dsi")!
    static let gcm = UTType(filenameExtension: "gcm")!
    static let iso = UTType(filenameExtension: "iso")!
    static let wbfs = UTType(filenameExtension: "wbfs")!
    static let nsp = UTType(filenameExtension: "nsp")!
    static let xci = UTType(filenameExtension: "xci")!
    static let sevenZ = UTType(filenameExtension: "7z")!
}
