import Foundation
import CoreGraphics

// MARK: - System Types

public enum EmulatorSystem: String, CaseIterable, Codable {
    case gb = "gb"
    case gbc = "gbc"
    case gba = "gba"
    case nes = "nes"
    case snes = "snes"
    case n64 = "n64"
    case gamecube = "gamecube"
    case wii = "wii"
    case wiiu = "wiiu"
    case ds = "ds"
    case threeds = "3ds"
    case switchConsole = "switch"

    public var displayName: String {
        switch self {
        case .gb: return "Game Boy"
        case .gbc: return "Game Boy Color"
        case .gba: return "Game Boy Advance"
        case .nes: return "Nintendo Entertainment System"
        case .snes: return "Super Nintendo"
        case .n64: return "Nintendo 64"
        case .gamecube: return "GameCube"
        case .wii: return "Wii"
        case .wiiu: return "Wii U"
        case .ds: return "Nintendo DS"
        case .threeds: return "Nintendo 3DS"
        case .switchConsole: return "Nintendo Switch"
        }
    }

    public var fileExtensions: [String] {
        switch self {
        case .gb: return ["gb"]
        case .gbc: return ["gbc"]
        case .gba: return ["gba"]
        case .nes: return ["nes", "unf", "fds"]
        case .snes: return ["sfc", "smc", "swc", "fig"]
        case .n64: return ["n64", "z64", "v64", "rom"]
        case .gamecube: return ["gcm", "iso", "gcz", "dol"]
        case .wii: return ["iso", "wbfs", "wad", "dol"]
        case .wiiu: return ["wud", "wux", "rpx", "rpl"]
        case .ds: return ["nds", "dsi", "ids", "srl"]
        case .threeds: return ["3ds", "cci", "cxi", "cia"]
        case .switchConsole: return ["nsp", "xci", "nca", "nro"]
        }
    }
}

// MARK: - Emulator State

public enum EmulatorState: String, Codable {
    case uninitialized
    case initialized
    case romLoaded
    case running
    case paused
    case stopped
    case error
}

// MARK: - ROM Types

public struct ROMMetadata: Codable, Identifiable {
    public let path: URL
    public let system: EmulatorSystem
    public let title: String
    public let region: String?
    public let checksum: String
    public let size: Int64
    public let header: Data?

    public var id: String { path.path }

    public init(path: URL, system: EmulatorSystem, title: String, region: String? = nil,
                checksum: String, size: Int64, header: Data? = nil) {
        self.path = path
        self.system = system
        self.title = title
        self.region = region
        self.checksum = checksum
        self.size = size
        self.header = header
    }
}

public struct ROMValidationResult {
    public let isValid: Bool
    public let system: EmulatorSystem?
    public let errors: [String]

    public init(isValid: Bool, system: EmulatorSystem? = nil, errors: [String] = []) {
        self.isValid = isValid
        self.system = system
        self.errors = errors
    }
}

// MARK: - Memory Types

public struct MemoryRegion: Codable {
    public let name: String
    public let startAddress: UInt32
    public let endAddress: UInt32
    public let size: UInt32
    public let isReadOnly: Bool
    public let isMapped: Bool

    public init(name: String, startAddress: UInt32, endAddress: UInt32,
                size: UInt32, isReadOnly: Bool, isMapped: Bool) {
        self.name = name
        self.startAddress = startAddress
        self.endAddress = endAddress
        self.size = size
        self.isReadOnly = isReadOnly
        self.isMapped = isMapped
    }
}

// MARK: - Input Types

public enum EmulatorButton: String, CaseIterable, Codable {
    // Standard buttons
    case a, b, x, y
    case start, select
    case up, down, left, right

    // Shoulder buttons
    case l, r, zl, zr

    // N64 specific
    case cUp, cDown, cLeft, cRight
    case z

    // Special
    case home, capture
}

public enum AnalogStick: String {
    case left, right
    case cStick // GameCube C-stick
}

public enum Trigger: String {
    case left, right
}

// MARK: - Graphics Types

public struct FrameData {
    public let pixelData: UnsafeMutableRawPointer
    public let width: Int
    public let height: Int
    public let bytesPerRow: Int
    public let pixelFormat: PixelFormat
    public let timestamp: TimeInterval

    public enum PixelFormat {
        case rgba8888
        case rgb565
        case bgra8888
    }

    public init(pixelData: UnsafeMutableRawPointer, width: Int, height: Int,
                bytesPerRow: Int, pixelFormat: PixelFormat, timestamp: TimeInterval) {
        self.pixelData = pixelData
        self.width = width
        self.height = height
        self.bytesPerRow = bytesPerRow
        self.pixelFormat = pixelFormat
        self.timestamp = timestamp
    }
}

public enum PostProcessEffect: String, CaseIterable {
    case none
    case crt
    case scanlines
    case bloom
    case motionBlur
    case fxaa
    case smaa
    case xbrz
    case hq2x
    case eagle
}

// MARK: - Audio Types

public struct AudioBuffer {
    public let samples: UnsafeMutablePointer<Float>
    public let frameCount: Int
    public let channelCount: Int
    public let sampleRate: Double
    public let timestamp: TimeInterval

    public init(samples: UnsafeMutablePointer<Float>, frameCount: Int,
                channelCount: Int, sampleRate: Double, timestamp: TimeInterval) {
        self.samples = samples
        self.frameCount = frameCount
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.timestamp = timestamp
    }
}

public enum AudioEffect: String, CaseIterable {
    case none
    case reverb
    case echo
    case lowpass
    case highpass
    case distortion
}

// MARK: - Debug Types

public struct DisassemblyLine {
    public let address: UInt32
    public let opcode: Data
    public let mnemonic: String
    public let operands: String
    public let comment: String?

    public init(address: UInt32, opcode: Data, mnemonic: String,
                operands: String, comment: String? = nil) {
        self.address = address
        self.opcode = opcode
        self.mnemonic = mnemonic
        self.operands = operands
        self.comment = comment
    }
}

// MARK: - Error Types

public enum EmulatorError: LocalizedError {
    case initializationFailed(String)
    case romLoadFailed(String)
    case invalidROM(String)
    case coreNotFound(EmulatorSystem)
    case noCoreLoaded
    case executionError(String)
    case saveStateFailed(String)
    case loadStateFailed(String)
    case memoryError(String)
    case graphicsError(String)
    case audioError(String)
    case inputError(String)
    case networkError(String)

    public var errorDescription: String? {
        switch self {
        case .initializationFailed(let msg): return "Initialization failed: \(msg)"
        case .romLoadFailed(let msg): return "ROM load failed: \(msg)"
        case .invalidROM(let msg): return "Invalid ROM: \(msg)"
        case .coreNotFound(let system): return "Core not found for \(system.displayName)"
        case .noCoreLoaded: return "No emulator core is loaded"
        case .executionError(let msg): return "Execution error: \(msg)"
        case .saveStateFailed(let msg): return "Save state failed: \(msg)"
        case .loadStateFailed(let msg): return "Load state failed: \(msg)"
        case .memoryError(let msg): return "Memory error: \(msg)"
        case .graphicsError(let msg): return "Graphics error: \(msg)"
        case .audioError(let msg): return "Audio error: \(msg)"
        case .inputError(let msg): return "Input error: \(msg)"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}
