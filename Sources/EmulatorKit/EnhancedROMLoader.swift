import Foundation
import CoreInterface
import Logging

public final class EnhancedROMLoader {
    private let logger = Logger(label: "EnhancedROMLoader")
    private let safeLoadLimit: Int64 = 128 * 1024 * 1024 // 128MB cap for in-memory loads

    public init() {}

    public func loadROM(from url: URL) async throws -> LoadedROM {
        logger.info("Loading ROM from: \(url.lastPathComponent)")

        // Determine file size safely
        let attrs = try FileManager.default.attributesOfItem(atPath: url.path)
        let fileSize = (attrs[.size] as? NSNumber)?.int64Value ?? 0

        // Read a small prefix for detection (1MB max)
        let prefix = try readPrefix(from: url, maxBytes: 1 * 1024 * 1024)
        let system = detectSystem(from: url, data: prefix)

        // For cartridge-based systems, allow in-memory load with a safety cap
        let inMemorySystems: Set<EmulatorSystem> = [.nes, .snes, .n64, .gb, .gbc, .gba, .ds, .threeds]
        guard inMemorySystems.contains(system) else {
            logger.warning("Refusing to load entire disc image into memory for system: \(system.rawValue)")
            throw ROMLoadError.unsupportedSystem
        }

        if fileSize > safeLoadLimit {
            logger.error("ROM exceeds safe in-memory limit (\(fileSize) bytes > \(safeLoadLimit))")
            throw ROMLoadError.invalidFormat("ROM too large to load into memory safely (>128MB)")
        }

        let fullData = try Data(contentsOf: url)

        // Process ROM based on system
        let processedData = try processROMData(fullData, for: system)
        let metadata = try extractMetadata(from: processedData, url: url, system: system)

        return LoadedROM(
            data: processedData,
            metadata: metadata,
            originalURL: url
        )
    }

    private func readPrefix(from url: URL, maxBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        let chunk = try handle.read(upToCount: maxBytes) ?? Data()
        return chunk
    }

    private func detectSystem(from url: URL, data: Data) -> EmulatorSystem {
        let ext = url.pathExtension.lowercased()

        // Enhanced system detection with header analysis
        switch ext {
        case "nes", "unf", "fds":
            return .nes
        case "sfc", "smc", "swc", "fig":
            return .snes
        case "n64", "z64", "v64":
            return .n64
        case "rom":
            return detectROMSystem(data: data)
        case "gcm", "iso", "gcz", "dol":
            return detectGameCubeWii(data: data)
        case "wbfs", "wad":
            return .wii
        case "nds", "dsi", "ids", "srl":
            return .ds
        case "3ds", "cci", "cxi", "cia":
            return .threeds
        case "nsp", "xci", "nca", "nro":
            return .switchConsole
        default:
            return detectByHeader(data: data) ?? .nes
        }
    }

    private func detectROMSystem(data: Data) -> EmulatorSystem {
        // Analyze ROM header and size to determine system
        if data.count >= 1024 * 1024 && data.count <= 64 * 1024 * 1024 {
            // Likely N64 size range
            if hasN64Header(data) {
                return .n64
            }
        }

        if data.count <= 8 * 1024 * 1024 {
            // Could be SNES
            if hasSNESHeader(data) {
                return .snes
            }
        }

        // Default to NES for small ROMs
        return .nes
    }

    private func detectGameCubeWii(data: Data) -> EmulatorSystem {
        // Check for GameCube/Wii disc header
        if data.count > 0x20 {
            let magic = data.subdata(in: 0..<4)
            if magic == Data([0xC2, 0x33, 0x9F, 0x3D]) { // GameCube magic
                return .gamecube
            }
            if magic == Data([0x5D, 0x1C, 0x9E, 0xA3]) { // Wii magic
                return .wii
            }
        }
        return .gamecube
    }

    private func detectByHeader(data: Data) -> EmulatorSystem? {
        guard data.count >= 16 else { return nil }

        // NES header
        if data.starts(with: [0x4E, 0x45, 0x53, 0x1A]) {
            return .nes
        }

        // N64 header patterns
        if hasN64Header(data) {
            return .n64
        }

        // SNES header check
        if hasSNESHeader(data) {
            return .snes
        }

        return nil
    }

    private func hasN64Header(_ data: Data) -> Bool {
        guard data.count >= 0x40 else { return false }

        // Check for N64 magic numbers at start
        let possibleMagics: [[UInt8]] = [
            [0x80, 0x37, 0x12, 0x40], // Big endian
            [0x37, 0x80, 0x40, 0x12], // Little endian
            [0x40, 0x12, 0x37, 0x80], // Byte swapped
        ]

        let header = Array(data.prefix(4))
        return possibleMagics.contains(header)
    }

    private func hasSNESHeader(_ data: Data) -> Bool {
        // Check for SNES header at common locations
        let possibleHeaderOffsets = [0x7FC0, 0xFFC0, 0x40FFC0] // LoROM, HiROM, ExHiROM

        for offset in possibleHeaderOffsets {
            if data.count > offset + 32 {
                let title = data.subdata(in: offset..<offset + 21)
                if isValidSNESTitle(title) {
                    return true
                }
            }
        }

        return false
    }

    private func isValidSNESTitle(_ titleData: Data) -> Bool {
        // SNES titles are typically ASCII with some specific patterns
        let title = String(data: titleData, encoding: .ascii) ?? ""
        return title.count > 5 && title.allSatisfy { char in
            char.isASCII && (char.isLetter || char.isNumber || char.isWhitespace || char == "-" || char == ":")
        }
    }

    private func processROMData(_ data: Data, for system: EmulatorSystem) throws -> Data {
        switch system {
        case .nes:
            return try processNESROM(data)
        case .snes:
            return try processSNESROM(data)
        case .n64:
            return try processN64ROM(data)
        case .gamecube, .wii:
            return try processGCWiiROM(data)
        default:
            return data // Return as-is for other systems
        }
    }

    private func processNESROM(_ data: Data) throws -> Data {
        guard data.count >= 16 else {
            throw ROMLoadError.invalidFormat("ROM too small for NES")
        }

        // Validate NES header
        if data.starts(with: [0x4E, 0x45, 0x53, 0x1A]) {
            logger.info("Valid iNES format detected")
            return data
        }

        // Check for headerless ROM
        if data.count % 1024 == 0 {
            logger.info("Possible headerless NES ROM detected")
            return data
        }

        throw ROMLoadError.invalidFormat("Invalid NES ROM format")
    }

    private func processSNESROM(_ data: Data) throws -> Data {
        // Handle SMC header (512 bytes) if present
        if data.count % 1024 == 512 {
            logger.info("SMC header detected, removing...")
            return data.dropFirst(512)
        }

        // Validate size
        let validSizes = [256, 512, 768, 1024, 1536, 2048, 3072, 4096, 6144] // KB
        let sizeKB = data.count / 1024

        if !validSizes.contains(sizeKB) {
            logger.warning("Unusual SNES ROM size: \(sizeKB)KB")
        }

        return data
    }

    private func processN64ROM(_ data: Data) throws -> Data {
        guard data.count >= 1024 else {
            throw ROMLoadError.invalidFormat("ROM too small for N64")
        }

        // Handle byte swapping for N64 ROMs
        let header = Array(data.prefix(4))

        if header == [0x37, 0x80, 0x40, 0x12] {
            // Little endian - needs byte swapping
            logger.info("Little endian N64 ROM detected, byte swapping...")
            return byteSwapN64ROM(data, mode: .littleEndian)
        } else if header == [0x40, 0x12, 0x37, 0x80] {
            // Word swapped - needs different swapping
            logger.info("Word swapped N64 ROM detected, correcting...")
            return byteSwapN64ROM(data, mode: .wordSwapped)
        } else if header == [0x80, 0x37, 0x12, 0x40] {
            // Big endian - correct format
            logger.info("Big endian N64 ROM detected (correct format)")
            return data
        }

        logger.warning("Unknown N64 ROM format, attempting to load as-is")
        return data
    }

    private func processGCWiiROM(_ data: Data) throws -> Data {
        // Handle compressed formats
        if data.starts(with: [0x1F, 0x8B]) { // GZIP
            logger.info("GZIP compressed ROM detected")
            return try decompressGZIP(data)
        }

        return data
    }

    private func byteSwapN64ROM(_ data: Data, mode: ByteSwapMode) -> Data {
        var swapped = Data(capacity: data.count)

        switch mode {
        case .littleEndian:
            // Swap every 2 bytes
            for i in stride(from: 0, to: data.count, by: 2) {
                if i + 1 < data.count {
                    swapped.append(data[i + 1])
                    swapped.append(data[i])
                } else {
                    swapped.append(data[i])
                }
            }
        case .wordSwapped:
            // Swap every 4 bytes
            for i in stride(from: 0, to: data.count, by: 4) {
                let end = min(i + 4, data.count)
                let chunk = Array(data[i..<end])
                if chunk.count == 4 {
                    swapped.append(contentsOf: [chunk[3], chunk[2], chunk[1], chunk[0]])
                } else {
                    swapped.append(contentsOf: chunk)
                }
            }
        }

        return swapped
    }

    private func decompressGZIP(_ data: Data) throws -> Data {
        // Simple GZIP decompression (you might want to use a proper library)
        // For now, return as-is and log
        logger.warning("GZIP decompression not fully implemented")
        return data
    }

    private func extractMetadata(from data: Data, url: URL, system: EmulatorSystem) throws -> ROMMetadata {
        let title = extractTitle(from: data, system: system, url: url)
        let region = extractRegion(from: data, system: system)
        let checksum = calculateChecksum(data)
        let header = extractHeader(from: data, system: system)

        return ROMMetadata(
            path: url,
            system: system,
            title: title,
            region: region,
            checksum: checksum,
            size: Int64(data.count),
            header: header
        )
    }

    private func extractTitle(from data: Data, system: EmulatorSystem, url: URL) -> String {
        switch system {
        case .nes:
            return extractNESTitle(from: data) ?? cleanFilename(url.lastPathComponent)
        case .snes:
            return extractSNESTitle(from: data) ?? cleanFilename(url.lastPathComponent)
        case .n64:
            return extractN64Title(from: data) ?? cleanFilename(url.lastPathComponent)
        case .gamecube, .wii:
            return extractGCWiiTitle(from: data) ?? cleanFilename(url.lastPathComponent)
        default:
            return cleanFilename(url.lastPathComponent)
        }
    }

    private func extractNESTitle(from data: Data) -> String? {
        // NES ROMs don't have embedded titles, but we can try to detect known patterns
        return nil
    }

    private func extractSNESTitle(from data: Data) -> String? {
        let offsets = [0x7FC0, 0xFFC0, 0x40FFC0]

        for offset in offsets {
            if data.count > offset + 21 {
                let titleData = data.subdata(in: offset..<offset + 21)
                if let title = String(data: titleData, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters).trimmingCharacters(in: .whitespaces) {
                    if !title.isEmpty && isValidSNESTitle(titleData) {
                        return title
                    }
                }
            }
        }

        return nil
    }

    private func extractN64Title(from data: Data) -> String? {
        guard data.count > 0x34 else { return nil }

        let titleData = data.subdata(in: 0x20..<0x34)
        return String(data: titleData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces)
    }

    private func extractGCWiiTitle(from data: Data) -> String? {
        // GameCube/Wii titles are at offset 0x20, 64 bytes
        guard data.count > 0x60 else { return nil }

        let titleData = data.subdata(in: 0x20..<0x60)
        return String(data: titleData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces)
    }

    private func extractRegion(from data: Data, system: EmulatorSystem) -> String? {
        switch system {
        case .n64:
            return extractN64Region(from: data)
        case .snes:
            return extractSNESRegion(from: data)
        case .gamecube, .wii:
            return extractGCWiiRegion(from: data)
        default:
            return nil
        }
    }

    private func extractN64Region(from data: Data) -> String? {
        guard data.count > 0x3F else { return nil }

        let regionCode = data[0x3F]
        switch regionCode {
        case 0x45: return "USA"
        case 0x4A: return "Japan"
        case 0x50: return "Europe"
        case 0x55: return "Australia"
        default: return "Unknown"
        }
    }

    private func extractSNESRegion(from data: Data) -> String? {
        let offsets = [0x7FD9, 0xFFD9]

        for offset in offsets {
            if data.count > offset {
                let regionCode = data[offset]
                switch regionCode {
                case 0x00, 0x01: return "Japan"
                case 0x02: return "USA"
                case 0x03: return "Europe"
                case 0x06: return "France"
                case 0x07: return "Netherlands"
                case 0x08: return "Spain"
                case 0x09: return "Germany"
                case 0x0A: return "Italy"
                case 0x0B: return "China"
                case 0x0D: return "Korea"
                case 0x0F: return "Canada"
                case 0x10: return "Brazil"
                case 0x11: return "Australia"
                default: continue
                }
            }
        }

        return nil
    }

    private func extractGCWiiRegion(from data: Data) -> String? {
        guard data.count > 0x3 else { return nil }

        let regionCode = data[0x3]
        switch regionCode {
        case 0x45: return "USA"
        case 0x4A: return "Japan"
        case 0x50: return "Europe"
        default: return "Unknown"
        }
    }

    private func calculateChecksum(_ data: Data) -> String {
        // Use a more robust checksum
        let hash = data.withUnsafeBytes { bytes in
            var hasher = Hasher()
            hasher.combine(bytes: UnsafeRawBufferPointer(start: bytes.baseAddress, count: bytes.count))
            return hasher.finalize()
        }

        return String(format: "%016x", hash)
    }

    private func extractHeader(from data: Data, system: EmulatorSystem) -> Data? {
        switch system {
        case .nes:
            return data.count >= 16 ? data.prefix(16) : nil
        case .snes:
            return data.count >= 512 ? data.prefix(512) : nil
        case .n64:
            return data.count >= 64 ? data.prefix(64) : nil
        default:
            return data.count >= 64 ? data.prefix(64) : nil
        }
    }

    private func cleanFilename(_ filename: String) -> String {
        return filename
            .replacingOccurrences(of: #"\.[^.]*$"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: "[_-]", with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Supporting Types

public struct LoadedROM {
    public let data: Data
    public let metadata: ROMMetadata
    public let originalURL: URL
}

public enum ROMLoadError: LocalizedError {
    case invalidFormat(String)
    case unsupportedSystem
    case corruptedData
    case decompressionFailed

    public var errorDescription: String? {
        switch self {
        case .invalidFormat(let msg): return "Invalid ROM format: \(msg)"
        case .unsupportedSystem: return "Unsupported system"
        case .corruptedData: return "ROM data appears to be corrupted"
        case .decompressionFailed: return "Failed to decompress ROM"
        }
    }
}

private enum ByteSwapMode {
    case littleEndian
    case wordSwapped
}
