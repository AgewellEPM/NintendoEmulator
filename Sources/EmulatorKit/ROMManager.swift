import Foundation
import CoreInterface
import Logging
import CryptoKit

@MainActor
public final class ROMManager: ObservableObject {
    @Published public private(set) var roms: [ROMMetadata] = []
    @Published public private(set) var isLoading = false

    // Alias for compatibility
    public var games: [ROMMetadata] {
        return roms
    }

    private let logger = Logger(label: "ROMManager")
    private let romsDirectory: URL
    private let supportedExtensions = Set([
        // NES
        "nes", "unf", "fds",
        // SNES
        "sfc", "smc", "swc", "fig",
        // N64
        "n64", "z64", "v64", "rom",
        // GameCube
        "gcm", "iso", "gcz", "dol",
        // Wii
        "wbfs", "wad",
        // DS
        "nds", "dsi", "ids", "srl",
        // 3DS
        "3ds", "cci", "cxi", "cia",
        // Switch
        "nsp", "xci", "nca", "nro"
    ])

    public init() {
        // Create ROMs directory in user's Documents
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        romsDirectory = documentsPath.appendingPathComponent("Nintendo Emulator/ROMs")

        // Ensure directory exists
        try? FileManager.default.createDirectory(at: romsDirectory, withIntermediateDirectories: true)
    }

    public func loadROMs() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let urls = try FileManager.default.contentsOfDirectory(
                at: romsDirectory,
                includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )

            var loadedROMs: [ROMMetadata] = []

            for url in urls {
                if supportedExtensions.contains(url.pathExtension.lowercased()) {
                    if let rom = await processROM(at: url) {
                        loadedROMs.append(rom)
                    }
                }
            }

            roms = loadedROMs.sorted { $0.title < $1.title }
            logger.info("Loaded \(roms.count) ROMs")

        } catch {
            logger.error("Failed to load ROMs: \(error)")
        }
    }

    public func addROMs(from urls: [URL]) async {
        isLoading = true
        defer { isLoading = false }

        var newROMs: [ROMMetadata] = []

        for url in urls {
            guard url.startAccessingSecurityScopedResource() else {
                logger.warning("Failed to access security scoped resource: \(url)")
                continue
            }
            defer { url.stopAccessingSecurityScopedResource() }

            // Copy ROM to our directory
            let filename = url.lastPathComponent
            let destinationURL = romsDirectory.appendingPathComponent(filename)

            do {
                // Remove existing file if it exists
                if FileManager.default.fileExists(atPath: destinationURL.path) {
                    try FileManager.default.removeItem(at: destinationURL)
                }

                try FileManager.default.copyItem(at: url, to: destinationURL)

                if let rom = await processROM(at: destinationURL) {
                    newROMs.append(rom)
                    logger.info("Added ROM: \(rom.title)")
                }
            } catch {
                logger.error("Failed to copy ROM \(filename): \(error)")
            }
        }

        // Add new ROMs to the list
        roms.append(contentsOf: newROMs)
        roms.sort { $0.title < $1.title }
    }

    public func deleteROM(_ rom: ROMMetadata) async {
        do {
            try FileManager.default.removeItem(at: rom.path)
            roms.removeAll { $0.path == rom.path }
            logger.info("Deleted ROM: \(rom.title)")
        } catch {
            logger.error("Failed to delete ROM: \(error)")
        }
    }

    /// Refresh the display of ROMs (forces UI update)
    public func refreshDisplay() {
        // Force a UI refresh by triggering the published property
        let currentROMs = roms
        roms = []
        roms = currentROMs
    }

    public func validateROM(_ rom: ROMMetadata) -> ROMValidationResult {
        // Basic validation
        guard FileManager.default.fileExists(atPath: rom.path.path) else {
            return ROMValidationResult(isValid: false, errors: ["ROM file not found"])
        }

        var errors: [String] = []

        // Check file size
        if rom.size == 0 {
            errors.append("ROM file is empty")
        }

        // Check if it's a known homebrew ROM (basic check)
        if isLikelyHomebrew(rom) {
            logger.info("ROM appears to be homebrew: \(rom.title)")
        } else {
            logger.warning("ROM validation unclear for: \(rom.title)")
        }

        return ROMValidationResult(
            isValid: errors.isEmpty,
            system: rom.system,
            errors: errors
        )
    }

    private func processROM(at url: URL) async -> ROMMetadata? {
        do {
            let enhancedLoader = EnhancedROMLoader()
            let loadedROM = try await enhancedLoader.loadROM(from: url)

            logger.info("Successfully processed ROM: \(loadedROM.metadata.title)")
            return loadedROM.metadata
        } catch {
            logger.error("Failed to process ROM at \(url): \(error)")

            // Fallback to basic processing
            return await processROMBasic(at: url)
        }
    }

    private func processROMBasic(at url: URL) async -> ROMMetadata? {
        do {
            // Read a safe prefix for detection and metadata extraction
            let prefix = try readPrefix(from: url, maxBytes: 1 * 1024 * 1024) // 1MB
            guard !prefix.isEmpty else { return nil }

            let system = detectSystem(from: url, data: prefix)
            let title = extractTitle(from: url, data: prefix, system: system)
            let region = detectRegion(from: prefix, system: system)
            let checksum = try streamingSHA256(for: url)

            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let fileSize = attributes[.size] as? Int64 ?? 0

            let header = extractHeader(from: prefix, system: system)

            return ROMMetadata(
                path: url,
                system: system,
                title: title,
                region: region,
                checksum: checksum,
                size: fileSize,
                header: header
            )
        } catch {
            logger.error("Failed basic ROM processing at \(url): \(error)")
            return nil
        }
    }

    private func readPrefix(from url: URL, maxBytes: Int) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        return try handle.read(upToCount: maxBytes) ?? Data()
    }

    private func streamingSHA256(for url: URL) throws -> String {
        var hasher = SHA256()
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }
        while true {
            let data = try handle.read(upToCount: 1_048_576) // 1MB chunks
            guard let chunk = data, !chunk.isEmpty else { break }
            hasher.update(data: chunk)
        }
        let digest = hasher.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func detectSystem(from url: URL, data: Data) -> EmulatorSystem {
        let ext = url.pathExtension.lowercased()

        switch ext {
        case "nes", "unf", "fds":
            return .nes
        case "sfc", "smc", "swc", "fig":
            return .snes
        case "n64", "z64", "v64":
            return .n64
        case "rom":
            // Could be N64 or other, check size/header
            if data.count >= 1024 * 1024 {
                return .n64
            }
            return .nes
        case "gcm", "iso", "gcz", "dol":
            return .gamecube
        case "wbfs", "wad":
            return .wii
        case "nds", "dsi", "ids", "srl":
            return .ds
        case "3ds", "cci", "cxi", "cia":
            return .threeds
        case "nsp", "xci", "nca", "nro":
            return .switchConsole
        default:
            return .nes // Default fallback
        }
    }

    private func extractTitle(from url: URL, data: Data, system: EmulatorSystem) -> String {
        // Try to extract title from ROM header
        switch system {
        case .nes:
            return extractNESTitle(from: data) ?? url.deletingPathExtension().lastPathComponent
        case .snes:
            return extractSNESTitle(from: data) ?? url.deletingPathExtension().lastPathComponent
        case .n64:
            return extractN64Title(from: data) ?? url.deletingPathExtension().lastPathComponent
        default:
            return url.deletingPathExtension().lastPathComponent
        }
    }

    private func extractNESTitle(from data: Data) -> String? {
        // NES ROMs don't typically have embedded titles, use filename
        return nil
    }

    private func extractSNESTitle(from data: Data) -> String? {
        // SNES title is at offset 0x7FC0 (HiROM) or 0xFFC0 (LoROM)
        guard data.count > 0x10000 else { return nil }

        let hiromOffset = 0x7FC0
        let loromOffset = 0xFFC0

        // Try LoROM first
        if data.count > loromOffset + 20 {
            let titleData = data.subdata(in: loromOffset..<loromOffset + 20)
            if let title = String(data: titleData, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) {
                if !title.isEmpty && title.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0.isWhitespace) }) {
                    return title
                }
            }
        }

        // Try HiROM
        if data.count > hiromOffset + 20 {
            let titleData = data.subdata(in: hiromOffset..<hiromOffset + 20)
            if let title = String(data: titleData, encoding: .ascii)?.trimmingCharacters(in: .controlCharacters) {
                if !title.isEmpty && title.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0.isWhitespace) }) {
                    return title
                }
            }
        }

        return nil
    }

    private func extractN64Title(from data: Data) -> String? {
        // N64 title is at offset 0x20, 20 bytes
        guard data.count > 0x34 else { return nil }

        let titleData = data.subdata(in: 0x20..<0x34)
        return String(data: titleData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces)
    }

    private func detectRegion(from data: Data, system: EmulatorSystem) -> String? {
        switch system {
        case .nes:
            return "NTSC" // Default assumption
        case .snes:
            return detectSNESRegion(from: data)
        case .n64:
            return detectN64Region(from: data)
        default:
            return nil
        }
    }

    private func detectSNESRegion(from data: Data) -> String? {
        guard data.count > 0xFFD9 else { return nil }
        let regionByte = data[0xFFD9]

        switch regionByte {
        case 0x00, 0x01: return "Japan"
        case 0x02: return "USA"
        case 0x03: return "Europe"
        default: return "Unknown"
        }
    }

    private func detectN64Region(from data: Data) -> String? {
        guard data.count > 0x3E else { return nil }
        let regionByte = data[0x3E]

        switch regionByte {
        case 0x45: return "USA"
        case 0x4A: return "Japan"
        case 0x50: return "Europe"
        default: return "Unknown"
        }
    }

    private func calculateChecksum(_ data: Data) -> String {
        let hash = SHA256.hash(data: data)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }

    private func extractHeader(from data: Data, system: EmulatorSystem) -> Data? {
        switch system {
        case .nes:
            return data.count >= 16 ? data.subdata(in: 0..<16) : nil
        case .snes:
            return data.count >= 512 ? data.subdata(in: 0..<512) : nil
        case .n64:
            return data.count >= 64 ? data.subdata(in: 0..<64) : nil
        default:
            return data.count >= 64 ? data.subdata(in: 0..<64) : nil
        }
    }

    private func isLikelyHomebrew(_ rom: ROMMetadata) -> Bool {
        let filename = rom.path.lastPathComponent.lowercased()
        let title = rom.title.lowercased()

        // Common homebrew indicators
        let homebrewKeywords = [
            "homebrew", "demo", "test", "nestest", "240p", "stress",
            "competition", "compo", "jam", "indie", "free", "open source"
        ]

        for keyword in homebrewKeywords {
            if filename.contains(keyword) || title.contains(keyword) {
                return true
            }
        }

        // Check for very small file sizes (often test ROMs)
        if rom.size < 1024 * 50 { // Less than 50KB
            return true
        }

        return false
    }
}
