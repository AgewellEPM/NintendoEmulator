import Foundation
import CoreInterface
import os.log

/// Registry for managing available emulator cores
public final class CoreRegistry {

    // MARK: - Properties

    private var registeredCores: [EmulatorSystem: EmulatorCoreProtocol.Type] = [:]
    private let logger = Logger(subsystem: "com.emulator", category: "CoreRegistry")

    // MARK: - Initialization

    public init() {
        registerBuiltInCores()
        loadDynamicCores()
    }

    // MARK: - Public Methods

    /// Register a core for a system
    public func registerCore(_ coreType: EmulatorCoreProtocol.Type, for system: EmulatorSystem) {
        registeredCores[system] = coreType
        logger.info("Registered core for \(system.rawValue)")
    }

    /// Get core class for a system
    public func coreClass(for system: EmulatorSystem) -> EmulatorCoreProtocol.Type? {
        registeredCores[system]
    }

    /// Get all available systems
    public var availableSystems: [EmulatorSystem] {
        Array(registeredCores.keys).sorted { $0.rawValue < $1.rawValue }
    }

    /// Check if a system is supported
    public func isSystemSupported(_ system: EmulatorSystem) -> Bool {
        registeredCores[system] != nil
    }

    /// Get core metadata
    public func getCoreMetadata(for system: EmulatorSystem) -> CoreMetadata? {
        guard let coreClass = registeredCores[system] else { return nil }

        // Create temporary instance to get metadata
        // Note: In production, this would be cached
        return CoreMetadata(
            system: system,
            identifier: String(describing: coreClass),
            version: "1.0.0",
            capabilities: determineCapabilities(for: system)
        )
    }

    // MARK: - Private Methods

    private func registerBuiltInCores() {
        // Register cores using runtime lookup to avoid circular dependencies
        func coreClass(byTrying names: [String]) -> EmulatorCoreProtocol.Type? {
            for name in names {
                if let cls = NSClassFromString(name) as? EmulatorCoreProtocol.Type {
                    return cls
                }
            }
            return nil
        }

        // N64 Swift core (if exposed to ObjC runtime via @objc/NSObject)
        if let n64CoreType = coreClass(byTrying: [
            "N64Core.N64Core",      // Swift module + class
            "N64Core"               // @objc class name fallback
        ]) {
            registerCore(n64CoreType, for: .n64)
        }

        // Prefer dynamic Mupen adapter only if CLI/core is available locally
        if isMupenAvailable(), let n64Mupen = coreClass(byTrying: [
            "N64MupenAdapter",                 // @objc(N64MupenAdapter)
            "N64MupenAdapter.N64MupenAdapter" // Swift module + class
        ]) {
            registerCore(n64Mupen, for: .n64)
        }

        // SNES, GameCube, Wii (discover via runtime)
        if let snesCoreType = coreClass(byTrying: ["SNESCore.SNESCore", "SNESCore"]) {
            registerCore(snesCoreType, for: .snes)
        }
        if let gcCoreType = coreClass(byTrying: ["GameCubeCore.GameCubeCore", "GameCubeCore"]) {
            registerCore(gcCoreType, for: .gamecube)
        }
        if let wiiCoreType = coreClass(byTrying: ["WiiCore.WiiCore", "WiiCore"]) {
            registerCore(wiiCoreType, for: .wii)
        }

        // Handhelds and newer systems (try dynamic discovery)
        if let gbCore = coreClass(byTrying: ["GBCore.GBCore", "GBCore"]) {
            registerCore(gbCore, for: .gb)
        }
        if let gbcCore = coreClass(byTrying: ["GBCore.GBCoreColor", "GBCoreColor"]) {
            registerCore(gbcCore, for: .gbc)
        }
        if let gbaCore = coreClass(byTrying: ["GBACore.GBACore", "GBACore"]) {
            registerCore(gbaCore, for: .gba)
        }
        if let dsCore = coreClass(byTrying: ["DSCore.DSCore", "DSCore"]) {
            registerCore(dsCore, for: .ds)
        }
        if let threeDSCore = coreClass(byTrying: ["ThreeDSCore.ThreeDSCore", "ThreeDSCore"]) {
            registerCore(threeDSCore, for: .threeds)
        }
        if let wiiuCore = coreClass(byTrying: ["WiiUCore.WiiUCore", "WiiUCore"]) {
            registerCore(wiiuCore, for: .wiiu)
        }
        if let switchCore = coreClass(byTrying: ["SwitchCore.SwitchCore", "SwitchCore"]) {
            registerCore(switchCore, for: .switchConsole)
        }

        // Note: Sega cores intentionally not implemented (per requirements)

        logger.info("Registered \(self.registeredCores.count) built-in cores")
    }

    private func loadDynamicCores() {
        // Load cores from bundles/frameworks
        let frameworksPath = Bundle.main.privateFrameworksPath ?? ""
        let frameworksURL = URL(fileURLWithPath: frameworksPath)

        do {
            let contents = try FileManager.default.contentsOfDirectory(
                at: frameworksURL,
                includingPropertiesForKeys: [.isDirectoryKey],
                options: .skipsHiddenFiles
            )

            for url in contents where url.pathExtension == "framework" {
                loadCore(at: url)
            }
        } catch {
            logger.warning("Failed to load dynamic cores: \(error.localizedDescription)")
        }
    }

    private func isMupenAvailable() -> Bool {
        let fm = FileManager.default
        let candidates = [
            "/opt/homebrew/bin/mupen64plus",
            "/usr/local/bin/mupen64plus",
            "\(FileManager.default.homeDirectoryForCurrentUser.path)/NintendoEmulator/build/mupen64/bin/mupen64plus"
        ]
        for path in candidates {
            if fm.fileExists(atPath: path) { return true }
        }
        return false
    }

    private func loadCore(at url: URL) {
        guard let bundle = Bundle(url: url) else {
            logger.warning("Failed to load bundle at \(url.path)")
            return
        }

        guard bundle.load() else {
            logger.warning("Failed to load bundle executable at \(url.path)")
            return
        }

        // Look for principal class
        if let principalClass = bundle.principalClass as? EmulatorCoreProtocol.Type {
            // Determine system from core
            if let tempInstance = try? principalClass.init() as EmulatorCoreProtocol {
                for system in tempInstance.supportedSystems {
                    registerCore(principalClass, for: system)
                }
            }
        }
    }


    private func determineCapabilities(for system: EmulatorSystem) -> CoreCapabilities {
        switch system {
        case .n64:
            return CoreCapabilities(
                hasSaveStates: true,
                hasRewind: false,
                hasNetplay: false,
                hasCheats: true,
                hasDebugger: true,
                maxPlayers: 4,
                supportedSaveTypes: [.sram, .eeprom, .flash],
                supportedEnhancements: [.hd_textures, .widescreen]
            )

        case .nes, .snes:
            return CoreCapabilities(
                hasSaveStates: true,
                hasRewind: true,
                hasNetplay: true,
                hasCheats: true,
                hasDebugger: true,
                maxPlayers: 2,
                supportedSaveTypes: [.sram],
                supportedEnhancements: [.filters, .shaders]
            )

        case .gamecube, .wii:
            return CoreCapabilities(
                hasSaveStates: true,
                hasRewind: false,
                hasNetplay: false,
                hasCheats: true,
                hasDebugger: false,
                maxPlayers: 4,
                supportedSaveTypes: [.memoryCard],
                supportedEnhancements: [.hd_textures, .widescreen, .progressive_scan]
            )

        default:
            return CoreCapabilities(
                hasSaveStates: true,
                hasRewind: false,
                hasNetplay: false,
                hasCheats: false,
                hasDebugger: false,
                maxPlayers: 1,
                supportedSaveTypes: [],
                supportedEnhancements: []
            )
        }
    }
}

// MARK: - Core Metadata

public struct CoreMetadata {
    public let system: EmulatorSystem
    public let identifier: String
    public let version: String
    public let capabilities: CoreCapabilities
}

public struct CoreCapabilities {
    public let hasSaveStates: Bool
    public let hasRewind: Bool
    public let hasNetplay: Bool
    public let hasCheats: Bool
    public let hasDebugger: Bool
    public let maxPlayers: Int
    public let supportedSaveTypes: [SaveType]
    public let supportedEnhancements: [Enhancement]

    public enum SaveType {
        case sram, eeprom, flash, memoryCard
    }

    public enum Enhancement {
        case hd_textures, widescreen, progressive_scan, filters, shaders
    }
}
