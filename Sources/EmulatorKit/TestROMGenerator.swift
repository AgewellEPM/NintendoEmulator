import Foundation
import CoreInterface

public final class TestROMGenerator {

    public static func generateNESTestROM() -> Data {
        var romData = Data()

        // NES Header (16 bytes)
        romData.append(contentsOf: [
            0x4E, 0x45, 0x53, 0x1A, // "NES" + MS-DOS EOF
            0x01, // PRG ROM size (16KB units)
            0x01, // CHR ROM size (8KB units)
            0x00, // Mapper, mirroring, battery, trainer
            0x00, // Mapper, VS System, PlayChoice-10
            0x00, // PRG RAM size
            0x00, // TV system
            0x00, // TV system, PRG RAM presence
            0x00, 0x00, 0x00, 0x00, 0x00 // Unused padding
        ])

        // PRG ROM (16KB) - Simple test program
        var prgRom = Data(count: 16384)

        // Reset vector at end of ROM
        let resetVector: UInt16 = 0x8000 // Start of ROM
        prgRom[0x3FFC] = UInt8(resetVector & 0xFF)
        prgRom[0x3FFD] = UInt8(resetVector >> 8)

        // Simple test program at $8000
        let testProgram: [UInt8] = [
            0xA9, 0x01, // LDA #$01
            0x8D, 0x00, 0x02, // STA $0200 (write to PPU)
            0xA9, 0x05, // LDA #$05
            0x8D, 0x01, 0x02, // STA $0201
            0x4C, 0x00, 0x80  // JMP $8000 (infinite loop)
        ]

        for (i, byte) in testProgram.enumerated() {
            prgRom[i] = byte
        }

        romData.append(prgRom)

        // CHR ROM (8KB) - Simple pattern data
        let chrRom = Data(repeating: 0x55, count: 8192) // Alternating pattern
        romData.append(chrRom)

        return romData
    }

    public static func generateSNESTestROM() -> Data {
        // SNES ROM Header (at LoROM $7FC0)
        var snesRom = Data(count: 524288) // 512KB

        // Header at $7FC0
        let headerOffset = 0x7FC0

        // Game title (21 bytes)
        let title = "SNES HOMEBREW TEST   "
        for (i, char) in title.utf8.enumerated() {
            if i < 21 {
                snesRom[headerOffset + i] = char
            }
        }

        // ROM makeup byte
        snesRom[headerOffset + 21] = 0x20 // LoROM, no FastROM

        // Cartridge type
        snesRom[headerOffset + 22] = 0x00 // ROM only

        // ROM size
        snesRom[headerOffset + 23] = 0x09 // 512KB

        // RAM size
        snesRom[headerOffset + 24] = 0x00 // No RAM

        // Country code
        snesRom[headerOffset + 25] = 0x01 // USA

        // License code
        snesRom[headerOffset + 26] = 0x33 // Extended header

        // Version
        snesRom[headerOffset + 27] = 0x00

        // Checksum complement and checksum (calculate later)
        let checksum = calculateSNESChecksum(snesRom)
        snesRom[headerOffset + 28] = UInt8((checksum ^ 0xFFFF) & 0xFF)
        snesRom[headerOffset + 29] = UInt8(((checksum ^ 0xFFFF) >> 8) & 0xFF)
        snesRom[headerOffset + 30] = UInt8(checksum & 0xFF)
        snesRom[headerOffset + 31] = UInt8((checksum >> 8) & 0xFF)

        // Native mode vectors at $7FE0+
        let vectorsOffset = 0x7FE0

        // Reset vector
        snesRom[vectorsOffset + 28] = 0x00 // Low byte
        snesRom[vectorsOffset + 29] = 0x80 // High byte ($8000)

        // Simple test program at $8000
        let testProgram: [UInt8] = [
            0x18,       // CLC
            0xFB,       // XCE (switch to native mode)
            0xA9, 0x8F, // LDA #$8F
            0x8D, 0x00, 0x21, // STA $2100 (screen brightness)
            0x80, 0xFE  // BRA -2 (infinite loop)
        ]

        for (i, byte) in testProgram.enumerated() {
            snesRom[i] = byte
        }

        return snesRom
    }

    public static func generateN64TestROM() -> Data {
        var romData = Data(count: 1048576) // 1MB

        // N64 header (64 bytes)

        // PI BSB Domain 1 register
        romData[0x00] = 0x80
        romData[0x01] = 0x37
        romData[0x02] = 0x12
        romData[0x03] = 0x40

        // Clock rate
        romData[0x04] = 0x00
        romData[0x05] = 0x00
        romData[0x06] = 0x00
        romData[0x07] = 0x0F

        // Entry point
        romData[0x08] = 0x80
        romData[0x09] = 0x00
        romData[0x0A] = 0x10
        romData[0x0B] = 0x00

        // Release offset (skip)

        // CRC1 and CRC2 (would need proper calculation)

        // Unknown (8 bytes at 0x18)

        // Image name (20 bytes at 0x20)
        let title = "N64 HOMEBREW TEST   "
        for (i, char) in title.utf8.enumerated() {
            if i < 20 {
                romData[0x20 + i] = char
            }
        }

        // Unknown (4 bytes at 0x34)

        // Manufacturer ID
        romData[0x38] = 0x4E // 'N'
        romData[0x39] = 0x49 // 'I'

        // Cartridge ID
        romData[0x3A] = 0x48 // 'H'
        romData[0x3B] = 0x42 // 'B'

        // Country code
        romData[0x3C] = 0x45 // 'E' (USA)

        // Version
        romData[0x3D] = 0x00

        // Bootstrap code at entry point (0x1000)
        let bootstrapOffset = 0x1000
        let bootstrap: [UInt8] = [
            0x3C, 0x08, 0x80, 0x00, // lui $t0, 0x8000
            0x25, 0x08, 0x10, 0x40, // addiu $t0, 0x1040
            0x01, 0x00, 0x00, 0x08, // jr $t0
            0x00, 0x00, 0x00, 0x00  // nop (delay slot)
        ]

        for (i, byte) in bootstrap.enumerated() {
            romData[bootstrapOffset + i] = byte
        }

        // Simple test program at 0x1040
        let testProgramOffset = 0x1040
        let testProgram: [UInt8] = [
            0x3C, 0x09, 0xA4, 0x40, // lui $t1, 0xA440 (VI base)
            0x24, 0x0A, 0x00, 0x02, // addiu $t2, $zero, 2
            0xAD, 0x2A, 0x00, 0x00, // sw $t2, 0($t1) (VI control)
            0x08, 0x00, 0x41, 0x01, // j 0x1040 (infinite loop)
            0x00, 0x00, 0x00, 0x00  // nop
        ]

        for (i, byte) in testProgram.enumerated() {
            romData[testProgramOffset + i] = byte
        }

        return romData
    }

    private static func calculateSNESChecksum(_ rom: Data) -> UInt16 {
        var checksum: UInt32 = 0

        for byte in rom {
            checksum += UInt32(byte)
        }

        return UInt16(checksum & 0xFFFF)
    }

    public static func createTestROMsInDirectory(_ directory: URL) throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        // Create NES test ROM
        let nesROM = generateNESTestROM()
        let nesURL = directory.appendingPathComponent("NES_Homebrew_Test.nes")
        try nesROM.write(to: nesURL)

        // Create SNES test ROM
        let snesROM = generateSNESTestROM()
        let snesURL = directory.appendingPathComponent("SNES_Homebrew_Test.smc")
        try snesROM.write(to: snesURL)

        // Create N64 test ROM
        let n64ROM = generateN64TestROM()
        let n64URL = directory.appendingPathComponent("N64_Homebrew_Test.n64")
        try n64ROM.write(to: n64URL)
    }
}
