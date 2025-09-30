import Foundation
import CoreInterface
import CryptoKit
import os.log

/// Analyzes ROM files to extract metadata and determine system type
public enum ROMAnalyzer {

    private static let logger = Logger(subsystem: "com.emulator", category: "ROMAnalyzer")

    /// Analyze ROM data and extract metadata
    public static func analyze(data: Data, url: URL) async throws -> ROMMetadata {
        let system = try detectSystem(from: data, fileName: url.lastPathComponent)
        let checksum = calculateChecksum(data: data)

        let metadata: ROMMetadata

        switch system {
        case .n64:
            metadata = try analyzeN64ROM(data: data, url: url, checksum: checksum)
        case .nes:
            metadata = try analyzeNESROM(data: data, url: url, checksum: checksum)
        case .snes:
            metadata = try analyzeSNESROM(data: data, url: url, checksum: checksum)
        case .gamecube, .wii:
            metadata = try analyzeGCWiiROM(data: data, url: url, checksum: checksum)
        default:
            metadata = ROMMetadata(
                path: url,
                system: system,
                title: url.deletingPathExtension().lastPathComponent,
                region: nil,
                checksum: checksum,
                size: Int64(data.count),
                header: nil
            )
        }

        logger.info("Analyzed ROM: \(metadata.title) [\(system.rawValue)]")
        return metadata
    }

    /// Detect system from ROM data and filename
    private static func detectSystem(from data: Data, fileName: String) throws -> EmulatorSystem {
        let ext = (fileName as NSString).pathExtension.lowercased()

        // Check by extension first
        for system in EmulatorSystem.allCases {
            if system.fileExtensions.contains(ext) {
                // Verify with magic bytes
                if verifySystem(system, data: data) {
                    return system
                }
            }
        }

        // Try magic byte detection
        if let system = detectByMagicBytes(data: data) {
            return system
        }

        throw EmulatorError.invalidROM("Unable to detect system type")
    }

    /// Verify system by checking magic bytes
    private static func verifySystem(_ system: EmulatorSystem, data: Data) -> Bool {
        guard data.count > 16 else { return false }

        switch system {
        case .gb:
            // Basic heuristic: GB header at 0x104..0x133 contains logo & title; we skip strict check here
            return true
        case .gbc:
            return true
        case .gba:
            // GBA has a Nintendo logo and header at 0xA0..0xBC
            return data.count > 0xC0
        case .n64:
            // N64 ROMs start with specific byte patterns
            let magic = data.prefix(4)
            return magic == Data([0x80, 0x37, 0x12, 0x40]) || // z64
                   magic == Data([0x37, 0x80, 0x40, 0x12]) || // v64
                   magic == Data([0x40, 0x12, 0x37, 0x80])    // n64

        case .nes:
            // NES ROMs have "NES\x1A" header
            return data.prefix(4) == Data([0x4E, 0x45, 0x53, 0x1A])

        case .snes:
            // SNES detection is more complex, check for valid header location
            return checkSNESHeader(data: data)

        case .gamecube, .wii:
            // GameCube/Wii ISOs have magic bytes at offset 0x1C
            guard data.count > 0x20 else { return false }
            let magic = data[0x1C..<0x20]
            return magic == Data([0xC2, 0x33, 0x9F, 0x3D])

        case .wiiu:
            // Wii U images/executables (best-effort via extension)
            return true
        case .ds:
            return data.count > 0x170
        case .threeds:
            return data.count > 0x200
        case .switchConsole:
            return data.count > 0x200
        }
    }

    /// Detect system by magic bytes alone
    private static func detectByMagicBytes(data: Data) -> EmulatorSystem? {
        guard data.count > 16 else { return nil }

        // Check each system's magic bytes
        for system in EmulatorSystem.allCases {
            if verifySystem(system, data: data) {
                return system
            }
        }

        return nil
    }

    /// Calculate checksum for ROM data
    private static func calculateChecksum(data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    // MARK: - System-Specific Analysis

    /// Analyze N64 ROM
    private static func analyzeN64ROM(data: Data, url: URL, checksum: String) throws -> ROMMetadata {
        guard data.count >= 0x40 else {
            throw EmulatorError.invalidROM("N64 ROM too small")
        }

        // Detect endianness and convert if needed
        let convertedData = convertN64Endianness(data)

        // Extract header (0x00-0x40)
        let header = convertedData[0..<0x40]

        // Extract title (0x20-0x34)
        let titleData = convertedData[0x20..<0x34]
        let title = String(data: titleData, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces.union(.controlCharacters)) ??
            url.deletingPathExtension().lastPathComponent

        // Extract game code and region (0x3B-0x3F)
        let regionCode = String(data: convertedData[0x3E..<0x3F], encoding: .ascii) ?? "?"
        let region = parseN64Region(regionCode)

        return ROMMetadata(
            path: url,
            system: .n64,
            title: title,
            region: region,
            checksum: checksum,
            size: Int64(data.count),
            header: header
        )
    }

    /// Convert N64 ROM endianness if needed
    private static func convertN64Endianness(_ data: Data) -> Data {
        guard data.count >= 4 else { return data }

        let magic = data.prefix(4)

        // z64 format (big endian) - correct format
        if magic == Data([0x80, 0x37, 0x12, 0x40]) {
            return data
        }

        // v64 format (byte swapped)
        if magic == Data([0x37, 0x80, 0x40, 0x12]) {
            var converted = Data(capacity: data.count)
            for i in stride(from: 0, to: data.count - 1, by: 2) {
                converted.append(data[i + 1])
                converted.append(data[i])
            }
            return converted
        }

        // n64 format (little endian)
        if magic == Data([0x40, 0x12, 0x37, 0x80]) {
            var converted = Data(capacity: data.count)
            for i in stride(from: 0, to: data.count - 3, by: 4) {
                converted.append(data[i + 3])
                converted.append(data[i + 2])
                converted.append(data[i + 1])
                converted.append(data[i])
            }
            return converted
        }

        return data
    }

    /// Parse N64 region code
    private static func parseN64Region(_ code: String) -> String {
        switch code {
        case "A": return "Asia (NTSC)"
        case "B": return "Brazil"
        case "C": return "China"
        case "D": return "Germany"
        case "E": return "USA"
        case "F": return "France"
        case "G": return "Gateway 64 (NTSC)"
        case "H": return "Netherlands"
        case "I": return "Italy"
        case "J": return "Japan"
        case "K": return "Korea"
        case "L": return "Gateway 64 (PAL)"
        case "N": return "Canada"
        case "P": return "Europe"
        case "S": return "Spain"
        case "U": return "Australia"
        case "W": return "Scandinavia"
        case "X": return "Europe (Alternative)"
        case "Y": return "Europe (Alternative)"
        case "Z": return "Europe (Alternative)"
        default: return "Unknown"
        }
    }

    /// Analyze NES ROM
    private static func analyzeNESROM(data: Data, url: URL, checksum: String) throws -> ROMMetadata {
        guard data.count >= 16 else {
            throw EmulatorError.invalidROM("NES ROM too small")
        }

        // iNES header format
        let header = data[0..<16]

        // Check for "NES\x1A" magic
        guard header.prefix(4) == Data([0x4E, 0x45, 0x53, 0x1A]) else {
            throw EmulatorError.invalidROM("Invalid NES header")
        }

        let prgRomSize = Int(header[4]) * 16384 // 16KB units
        let chrRomSize = Int(header[5]) * 8192  // 8KB units
        let mapper = (Int(header[6]) >> 4) | (Int(header[7]) & 0xF0)

        let title = url.deletingPathExtension().lastPathComponent

        logger.info("NES ROM: PRG=\(prgRomSize) CHR=\(chrRomSize) Mapper=\(mapper)")

        return ROMMetadata(
            path: url,
            system: .nes,
            title: title,
            region: nil,
            checksum: checksum,
            size: Int64(data.count),
            header: header
        )
    }

    /// Analyze SNES ROM
    private static func analyzeSNESROM(data: Data, url: URL, checksum: String) throws -> ROMMetadata {
        guard data.count >= 0x8000 else {
            throw EmulatorError.invalidROM("SNES ROM too small")
        }

        // Find header location (LoROM or HiROM)
        let headerOffset = findSNESHeaderOffset(data: data)
        guard let offset = headerOffset else {
            throw EmulatorError.invalidROM("SNES header not found")
        }

        let header = data[offset..<(offset + 0x20)]

        // Extract title (21 bytes at offset 0x10)
        let titleOffset = offset + 0x10
        let titleData = data[titleOffset..<min(titleOffset + 21, data.count)]
        let title = String(data: titleData, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces.union(.controlCharacters)) ??
            url.deletingPathExtension().lastPathComponent

        return ROMMetadata(
            path: url,
            system: .snes,
            title: title,
            region: nil,
            checksum: checksum,
            size: Int64(data.count),
            header: header
        )
    }

    /// Check for SNES header
    private static func checkSNESHeader(data: Data) -> Bool {
        return findSNESHeaderOffset(data: data) != nil
    }

    /// Find SNES header offset
    private static func findSNESHeaderOffset(data: Data) -> Int? {
        // Common header locations
        let offsets = [0x7FB0, 0xFFB0, 0x40FFB0] // LoROM, HiROM, ExHiROM

        for offset in offsets {
            if offset + 0x20 <= data.count {
                // Verify checksum complement
                let checksum = UInt16(data[offset + 0x1E]) | (UInt16(data[offset + 0x1F]) << 8)
                let complement = UInt16(data[offset + 0x1C]) | (UInt16(data[offset + 0x1D]) << 8)

                if checksum ^ complement == 0xFFFF {
                    return offset
                }
            }
        }

        return nil
    }

    /// Analyze GameCube/Wii ROM
    private static func analyzeGCWiiROM(data: Data, url: URL, checksum: String) throws -> ROMMetadata {
        guard data.count >= 0x440 else {
            throw EmulatorError.invalidROM("GameCube/Wii ISO too small")
        }

        // Game ID at 0x00 (6 bytes)
        let gameID = String(data: data[0..<6], encoding: .ascii) ?? "UNKNOWN"

        // Title at 0x20 (up to 0x60 bytes)
        let titleData = data[0x20..<0x80]
        let title = String(data: titleData, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces.union(.controlCharacters)) ??
            url.deletingPathExtension().lastPathComponent

        // Region code from game ID
        let regionChar = gameID[gameID.index(gameID.startIndex, offsetBy: 3)]
        let region = parseGCRegion(String(regionChar))

        // Determine if Wii or GameCube
        let system: EmulatorSystem = data[0x18] == 0x5D ? .wii : .gamecube

        return ROMMetadata(
            path: url,
            system: system,
            title: title,
            region: region,
            checksum: checksum,
            size: Int64(data.count),
            header: data[0..<0x440]
        )
    }

    /// Parse GameCube/Wii region code
    private static func parseGCRegion(_ code: String) -> String {
        switch code {
        case "E": return "USA/NTSC"
        case "P": return "Europe/PAL"
        case "J": return "Japan/NTSC-J"
        case "K": return "Korea/NTSC-K"
        case "D": return "Germany/PAL"
        case "F": return "France/PAL"
        case "S": return "Spain/PAL"
        case "I": return "Italy/PAL"
        case "L": return "Japanese Import"
        case "M": return "American Import"
        case "N": return "Japanese Import (GameCube)"
        default: return "Unknown"
        }
    }
}
