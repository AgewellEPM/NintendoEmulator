import Foundation
import CoreInterface

public final class N64Cartridge {

    // MARK: - Properties

    private let romData: Data
    private let metadata: ROMMetadata
    private var saveData: Data?

    // ROM properties
    private let title: String
    private let region: String
    private let crc1: UInt32
    private let crc2: UInt32
    private let bootCode: Data

    // Save configuration
    private let saveType: SaveType
    private let saveSize: Int

    // Memory banking
    private var currentBank = 0
    private let bankSize = 2 * 1024 * 1024 // 2MB

    // MARK: - Save Types

    public enum SaveType {
        case none
        case eeprom512    // 512 bytes (4Kbit)
        case eeprom2048   // 2048 bytes (16Kbit)
        case sram32k      // 32KB SRAM
        case flash128k    // 128KB Flash
        case controller   // Controller Pak
    }

    // MARK: - Initialization

    public init(romData: Data, metadata: ROMMetadata) throws {
        guard romData.count >= 0x40 else {
            throw EmulatorError.romLoadFailed("ROM too small")
        }

        self.romData = romData
        self.metadata = metadata

        // Compute header fields first, then assign
        let parsedTitle = Self.extractTitle(from: romData)
        let parsedRegion = Self.extractRegion(from: romData)
        let parsedCRC1 = romData.read32BE(at: 0x10)
        let parsedCRC2 = romData.read32BE(at: 0x14)
        let parsedBoot = romData.subdata(in: 0x40..<0x1000)
        let st = Self.detectSaveType(from: romData, title: parsedTitle)
        let ss = Self.getSaveSize(for: st)

        self.title = parsedTitle
        self.region = parsedRegion
        self.crc1 = parsedCRC1
        self.crc2 = parsedCRC2
        self.bootCode = parsedBoot
        self.saveType = st
        self.saveSize = ss

        if self.saveSize > 0 {
            self.saveData = Data(count: self.saveSize)
        }
    }

    // MARK: - ROM Access

    public func read32(_ address: UInt32) -> UInt32 {
        let offset = Int(address)

        // Handle banking for large ROMs
        if romData.count > bankSize {
            let bankOffset = currentBank * bankSize
            let actualOffset = bankOffset + offset

            guard actualOffset + 3 < romData.count else { return 0 }
            return romData.read32BE(at: actualOffset)
        } else {
            guard offset + 3 < romData.count else { return 0 }
            return romData.read32BE(at: offset)
        }
    }

    public func read16(_ address: UInt32) -> UInt16 {
        let offset = Int(address)

        if romData.count > bankSize {
            let bankOffset = currentBank * bankSize
            let actualOffset = bankOffset + offset

            guard actualOffset + 1 < romData.count else { return 0 }
            return romData.read16BE(at: actualOffset)
        } else {
            guard offset + 1 < romData.count else { return 0 }
            return romData.read16BE(at: offset)
        }
    }

    public func read8(_ address: UInt32) -> UInt8 {
        let offset = Int(address)

        if romData.count > bankSize {
            let bankOffset = currentBank * bankSize
            let actualOffset = bankOffset + offset

            guard actualOffset < romData.count else { return 0 }
            return romData[actualOffset]
        } else {
            guard offset < romData.count else { return 0 }
            return romData[offset]
        }
    }

    // MARK: - Save Data Access

    public func readSave8(_ address: UInt32) -> UInt8 {
        guard let save = saveData, Int(address) < save.count else { return 0 }
        return save[Int(address)]
    }

    public func writeSave8(_ address: UInt32, value: UInt8) {
        guard saveData != nil, Int(address) < saveSize else { return }
        saveData![Int(address)] = value
    }

    public func readSave16(_ address: UInt32) -> UInt16 {
        guard let save = saveData, Int(address) + 1 < save.count else { return 0 }
        return save.read16BE(at: Int(address))
    }

    public func writeSave16(_ address: UInt32, value: UInt16) {
        guard saveData != nil, Int(address) + 1 < saveSize else { return }
        saveData!.write16BE(at: Int(address), value: value)
    }

    public func readSave32(_ address: UInt32) -> UInt32 {
        guard let save = saveData, Int(address) + 3 < save.count else { return 0 }
        return save.read32BE(at: Int(address))
    }

    public func writeSave32(_ address: UInt32, value: UInt32) {
        guard saveData != nil, Int(address) + 3 < saveSize else { return }
        saveData!.write32BE(at: Int(address), value: value)
    }

    // MARK: - Header Extraction

    private static func extractTitle(from data: Data) -> String {
        guard data.count > 0x34 else { return "Unknown" }

        let titleData = data.subdata(in: 0x20..<0x34)
        let title = String(data: titleData, encoding: .ascii)?
            .trimmingCharacters(in: .controlCharacters)
            .trimmingCharacters(in: .whitespaces) ?? "Unknown"

        return title.isEmpty ? "Unknown" : title
    }

    private static func extractRegion(from data: Data) -> String {
        guard data.count > 0x3F else { return "Unknown" }

        let regionCode = data[0x3F]
        switch regionCode {
        case 0x45: return "USA" // E
        case 0x4A: return "Japan" // J
        case 0x50: return "Europe" // P
        case 0x55: return "Australia" // U
        case 0x44: return "Germany" // D
        case 0x46: return "France" // F
        case 0x49: return "Italy" // I
        case 0x53: return "Spain" // S
        case 0x41: return "Australia" // A
        default: return "Unknown"
        }
    }

    // MARK: - Save Type Detection

    private static func detectSaveType(from data: Data, title: String) -> SaveType {
        // Check for known save types in ROM header or by title
        let upperTitle = title.uppercased()

        // EEPROM games
        if isEEPROMGame(title: upperTitle) {
            return isLargeEEPROMGame(title: upperTitle) ? .eeprom2048 : .eeprom512
        }

        // SRAM games
        if isSRAMGame(title: upperTitle) {
            return .sram32k
        }

        // Flash games
        if isFlashGame(title: upperTitle) {
            return .flash128k
        }

        // Default to no save
        return .none
    }

    private static func isEEPROMGame(title: String) -> Bool {
        let eepromGames = [
            "SUPER MARIO 64",
            "MARIO KART 64",
            "WAVE RACE 64",
            "STAR FOX 64",
            "YOSHI'S STORY",
            "THE LEGEND OF ZELDA",
            "ZELDA MAJORA'S MASK",
            "MARIO PARTY",
            "MARIO PARTY 2",
            "MARIO PARTY 3",
            "SUPER SMASH BROS",
            "GOLDENEYE 007",
            "PERFECT DARK",
            "DONKEY KONG 64",
            "KIRBY 64",
            "POKEMON STADIUM",
            "POKEMON STADIUM 2"
        ]

        return eepromGames.contains { title.contains($0) }
    }

    private static func isLargeEEPROMGame(title: String) -> Bool {
        let largeEepromGames = [
            "ZELDA MAJORA'S MASK",
            "PERFECT DARK",
            "DONKEY KONG 64",
            "POKEMON STADIUM 2"
        ]

        return largeEepromGames.contains { title.contains($0) }
    }

    private static func isSRAMGame(title: String) -> Bool {
        let sramGames = [
            "WAVERACE 64",
            "NEW TETRIS",
            "MARIO GOLF",
            "MARIO TENNIS",
            "POKEMON SNAP",
            "OGRE BATTLE 64",
            "HARVEST MOON 64"
        ]

        return sramGames.contains { title.contains($0) }
    }

    private static func isFlashGame(title: String) -> Bool {
        let flashGames = [
            "PAPER MARIO",
            "POKEMON STADIUM",
            "COMMAND & CONQUER"
        ]

        return flashGames.contains { title.contains($0) }
    }

    private static func getSaveSize(for saveType: SaveType) -> Int {
        switch saveType {
        case .none: return 0
        case .eeprom512: return 512
        case .eeprom2048: return 2048
        case .sram32k: return 32768
        case .flash128k: return 131072
        case .controller: return 32768
        }
    }

    // MARK: - Banking

    public func setBank(_ bank: Int) {
        currentBank = max(0, min(bank, (romData.count / bankSize) - 1))
    }

    public func getCurrentBank() -> Int {
        return currentBank
    }

    public func getTotalBanks() -> Int {
        return max(1, romData.count / bankSize)
    }

    // MARK: - ROM Information

    public func getTitle() -> String {
        return title
    }

    public func getRegion() -> String {
        return region
    }

    public func getCRC1() -> UInt32 {
        return crc1
    }

    public func getCRC2() -> UInt32 {
        return crc2
    }

    public func getBootCode() -> Data {
        return bootCode
    }

    public func getSaveType() -> SaveType {
        return saveType
    }

    public func getSaveSize() -> Int {
        return saveSize
    }

    public func getROMSize() -> Int {
        return romData.count
    }

    // MARK: - Save File Management

    public func getSaveData() -> Data? {
        return saveData
    }

    public func setSaveData(_ data: Data?) {
        if let data = data, data.count == saveSize {
            saveData = data
        } else if data == nil {
            saveData = saveSize > 0 ? Data(count: saveSize) : nil
        }
    }

    public func loadSaveFile(from url: URL) throws {
        guard saveSize > 0 else { return }

        if FileManager.default.fileExists(atPath: url.path) {
            let data = try Data(contentsOf: url)
            if data.count == saveSize {
                saveData = data
            } else {
                throw EmulatorError.loadStateFailed("Save file size mismatch")
            }
        } else {
            // Create new save file
            saveData = Data(count: saveSize)
        }
    }

    public func saveSaveFile(to url: URL) throws {
        guard let data = saveData else { return }
        try data.write(to: url)
    }

    // MARK: - ROM Validation

    public func validateROM() -> Bool {
        // Check basic ROM structure
        guard romData.count >= 0x1000 else { return false }

        // Check for valid N64 header
        let header = Array(romData.prefix(4))
        let validHeaders: [[UInt8]] = [
            [0x80, 0x37, 0x12, 0x40], // Big endian
            [0x37, 0x80, 0x40, 0x12], // Little endian
            [0x40, 0x12, 0x37, 0x80], // Byte swapped
        ]

        guard validHeaders.contains(header) else { return false }

        // Check ClockRate (should be reasonable)
        let clockRate = romData.read32BE(at: 0x04)
        guard clockRate >= 0x0F && clockRate <= 0x17 else { return false }

        // Check EntryPoint (should be in valid range)
        let entryPoint = romData.read32BE(at: 0x08)
        guard entryPoint >= 0x80000000 && entryPoint < 0x80800000 else { return false }

        return true
    }

    public func calculateCRC() -> (UInt32, UInt32) {
        // Simplified CRC calculation
        // Real N64 CRC is more complex
        var crc1: UInt32 = 0
        var crc2: UInt32 = 0

        let dataSize = min(romData.count, 1024 * 1024) // 1MB max for CRC
        for i in stride(from: 0x1000, to: dataSize, by: 4) {
            let value = romData.read32BE(at: i)
            crc1 = crc1 &+ value
            crc2 ^= value

            if (i & 0x3FFF) == 0 {
                crc1 = (crc1 << 1) | (crc1 >> 31)
                crc2 = (crc2 << 1) | (crc2 >> 31)
            }
        }

        return (crc1, crc2)
    }
}

// MARK: - Data Extensions for N64 Cartridge

extension Data {
    func read32BE(at offset: Int) -> UInt32 {
        guard offset + 3 < count else { return 0 }
        return withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt32.self).bigEndian
        }
    }

    func read16BE(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        return withUnsafeBytes { bytes in
            bytes.load(fromByteOffset: offset, as: UInt16.self).bigEndian
        }
    }

    mutating func write32BE(at offset: Int, value: UInt32) {
        guard offset + 3 < count else { return }
        withUnsafeMutableBytes { bytes in
            bytes.storeBytes(of: value.bigEndian, toByteOffset: offset, as: UInt32.self)
        }
    }

    mutating func write16BE(at offset: Int, value: UInt16) {
        guard offset + 1 < count else { return }
        withUnsafeMutableBytes { bytes in
            bytes.storeBytes(of: value.bigEndian, toByteOffset: offset, as: UInt16.self)
        }
    }
}
