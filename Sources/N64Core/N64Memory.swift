import Foundation
import CoreInterface

public final class N64Memory {

    // MARK: - Memory Map

    private var rdram = Data(count: 8 * 1024 * 1024) // 8MB RDRAM (expansion pak)
    private var cartridge: N64Cartridge?
    private var pif = Data(count: 2048) // PIF RAM/ROM
    private var sram = Data(count: 32768) // Save RAM

    // Memory-mapped registers
    private var viRegisters = Data(count: 56) // Video Interface
    private var aiRegisters = Data(count: 24) // Audio Interface
    private var piRegisters = Data(count: 52) // Peripheral Interface
    private var riRegisters = Data(count: 32) // RDRAM Interface
    private var siRegisters = Data(count: 28) // Serial Interface
    private var miRegisters = Data(count: 16) // MIPS Interface

    // Controller state
    private var controllerStates: [ControllerState] = Array(repeating: ControllerState(), count: 4)

    // MARK: - Memory Access

    public func read32(_ address: UInt32) -> UInt32 {
        let physicalAddress = translateAddress(address)

        switch physicalAddress {
        case 0x00000000..<0x00800000: // RDRAM
            return rdram.read32BE(at: Int(physicalAddress))

        case 0x10000000..<0x20000000: // Cartridge ROM
            return cartridge?.read32(physicalAddress - 0x10000000) ?? 0

        case 0x04000000..<0x04001000: // RSP DMEM
            return 0 // TODO: RSP memory

        case 0x04001000..<0x04002000: // RSP IMEM
            return 0 // TODO: RSP memory

        case 0x04100000..<0x04100038: // VI registers
            return readVIRegister(physicalAddress - 0x04100000)

        case 0x04300000..<0x04300018: // MI registers
            return readMIRegister(physicalAddress - 0x04300000)

        case 0x04400000..<0x04400034: // SI registers
            return readSIRegister(physicalAddress - 0x04400000)

        case 0x04500000..<0x04500018: // AI registers
            return readAIRegister(physicalAddress - 0x04500000)

        case 0x04600000..<0x04600034: // PI registers
            return readPIRegister(physicalAddress - 0x04600000)

        case 0x1FC00000..<0x1FC00800: // PIF
            return pif.read32BE(at: Int(physicalAddress - 0x1FC00000))

        default:
            return 0
        }
    }

    public func write32(_ address: UInt32, value: UInt32) {
        let physicalAddress = translateAddress(address)

        switch physicalAddress {
        case 0x00000000..<0x00800000: // RDRAM
            rdram.write32BE(at: Int(physicalAddress), value: value)

        case 0x04000000..<0x04001000: // RSP DMEM
            break // TODO: RSP memory

        case 0x04001000..<0x04002000: // RSP IMEM
            break // TODO: RSP memory

        case 0x04100000..<0x04100038: // VI registers
            writeVIRegister(physicalAddress - 0x04100000, value: value)

        case 0x04300000..<0x04300018: // MI registers
            writeMIRegister(physicalAddress - 0x04300000, value: value)

        case 0x04400000..<0x04400034: // SI registers
            writeSIRegister(physicalAddress - 0x04400000, value: value)

        case 0x04500000..<0x04500018: // AI registers
            writeAIRegister(physicalAddress - 0x04500000, value: value)

        case 0x04600000..<0x04600034: // PI registers
            writePIRegister(physicalAddress - 0x04600000, value: value)

        case 0x1FC00000..<0x1FC00800: // PIF
            pif.write32BE(at: Int(physicalAddress - 0x1FC00000), value: value)

        default:
            break
        }
    }

    public func read16(_ address: UInt32) -> UInt16 {
        let value = read32(address & ~0x3)
        let shift = (address & 0x3) * 8
        return UInt16((value >> shift) & 0xFFFF)
    }

    public func write16(_ address: UInt32, value: UInt16) {
        let currentValue = read32(address & ~0x3)
        let shift = (address & 0x3) * 8
        let mask = UInt32(0xFFFF) << shift
        let newValue = (currentValue & ~mask) | (UInt32(value) << shift)
        write32(address & ~0x3, value: newValue)
    }

    public func read8(_ address: UInt32) -> UInt8 {
        let value = read32(address & ~0x3)
        let shift = (address & 0x3) * 8
        return UInt8((value >> shift) & 0xFF)
    }

    public func write8(_ address: UInt32, value: UInt8) {
        let currentValue = read32(address & ~0x3)
        let shift = (address & 0x3) * 8
        let mask = UInt32(0xFF) << shift
        let newValue = (currentValue & ~mask) | (UInt32(value) << shift)
        write32(address & ~0x3, value: newValue)
    }

    // MARK: - Address Translation

    private func translateAddress(_ address: UInt32) -> UInt32 {
        // Remove segment bits for physical addressing
        switch address >> 29 {
        case 0x4, 0x5: // KSEG0, KSEG1 (cached/uncached)
            return address & 0x1FFFFFFF
        default:
            return address
        }
    }

    // MARK: - Cartridge Management

    public func mapCartridge(_ cartridge: N64Cartridge) {
        self.cartridge = cartridge
    }

    public func unmapCartridge() {
        cartridge = nil
    }

    // MARK: - Register Access

    private func readVIRegister(_ offset: UInt32) -> UInt32 {
        return viRegisters.read32BE(at: Int(offset))
    }

    private func writeVIRegister(_ offset: UInt32, value: UInt32) {
        viRegisters.write32BE(at: Int(offset), value: value)

        // Handle special VI registers
        switch offset {
        case 0x00: // VI_STATUS
            // Configure video mode
            break
        case 0x04: // VI_ORIGIN
            // Set framebuffer address
            break
        case 0x08: // VI_WIDTH
            // Set screen width
            break
        case 0x0C: // VI_INTR
            // Set interrupt line
            break
        default:
            break
        }
    }

    private func readMIRegister(_ offset: UInt32) -> UInt32 {
        return miRegisters.read32BE(at: Int(offset))
    }

    private func writeMIRegister(_ offset: UInt32, value: UInt32) {
        miRegisters.write32BE(at: Int(offset), value: value)
    }

    private func readSIRegister(_ offset: UInt32) -> UInt32 {
        switch offset {
        case 0x00: // SI_DRAM_ADDR
            return siRegisters.read32BE(at: Int(offset))
        case 0x04: // SI_PIF_ADDR_RD64B
            return siRegisters.read32BE(at: Int(offset))
        case 0x18: // SI_STATUS
            return 0 // Not busy
        default:
            return siRegisters.read32BE(at: Int(offset))
        }
    }

    private func writeSIRegister(_ offset: UInt32, value: UInt32) {
        siRegisters.write32BE(at: Int(offset), value: value)

        switch offset {
        case 0x04: // SI_PIF_ADDR_RD64B
            // Transfer from PIF to RDRAM
            transferFromPIF()
        case 0x10: // SI_PIF_ADDR_WR64B
            // Transfer from RDRAM to PIF
            transferToPIF()
        default:
            break
        }
    }

    private func readAIRegister(_ offset: UInt32) -> UInt32 {
        return aiRegisters.read32BE(at: Int(offset))
    }

    private func writeAIRegister(_ offset: UInt32, value: UInt32) {
        aiRegisters.write32BE(at: Int(offset), value: value)
    }

    private func readPIRegister(_ offset: UInt32) -> UInt32 {
        return piRegisters.read32BE(at: Int(offset))
    }

    private func writePIRegister(_ offset: UInt32, value: UInt32) {
        piRegisters.write32BE(at: Int(offset), value: value)
    }

    // MARK: - Controller Interface

    public func setControllerButton(player: Int, button: EmulatorButton, pressed: Bool) {
        guard player < controllerStates.count else { return }
        controllerStates[player].setButton(button, pressed: pressed)
        updatePIFController(player: player)
    }

    public func setControllerAnalog(player: Int, x: Float, y: Float) {
        guard player < controllerStates.count else { return }
        controllerStates[player].analogX = Int8(x * 127)
        controllerStates[player].analogY = Int8(y * 127)
        updatePIFController(player: player)
    }

    public func getControllerState(player: Int) -> InputState {
        guard player < controllerStates.count else { return InputState() }
        return controllerStates[player].toInputState()
    }

    private func updatePIFController(player: Int) {
        // Update PIF RAM with controller state
        let baseOffset = 0x40 + (player * 4)
        let state = controllerStates[player]

        pif.write32BE(at: baseOffset, value: state.toUInt32())
    }

    private func transferFromPIF() {
        // Handle controller input reading
        let dramAddr = siRegisters.read32BE(at: 0x00)

        // Copy controller data from PIF to RDRAM
        for i in 0..<64 {
            let value = pif.read8(at: i)
            rdram.write8(at: Int(dramAddr) + i, value: value)
        }
    }

    private func transferToPIF() {
        // Handle controller commands
        let dramAddr = siRegisters.read32BE(at: 0x00)

        // Copy commands from RDRAM to PIF
        for i in 0..<64 {
            let value = rdram.read8(at: Int(dramAddr) + i)
            pif.write8(at: i, value: value)
        }

        // Process controller commands
        processControllerCommands()
    }

    private func processControllerCommands() {
        // Simple controller identification and input reading
        for player in 0..<4 {
            let baseOffset = player * 8
            let command = pif.read8(at: baseOffset)

            switch command {
            case 0x00, 0xFF: // Controller info
                pif.write8(at: baseOffset + 1, value: 0x05) // Standard controller
                pif.write8(at: baseOffset + 2, value: 0x00)
                pif.write8(at: baseOffset + 3, value: 0x02) // Has pak

            case 0x01: // Read controller state
                let state = controllerStates[player]
                let buttons = state.toUInt32()

                pif.write8(at: baseOffset + 1, value: UInt8((buttons >> 24) & 0xFF))
                pif.write8(at: baseOffset + 2, value: UInt8((buttons >> 16) & 0xFF))
                pif.write8(at: baseOffset + 3, value: UInt8(state.analogX))
                pif.write8(at: baseOffset + 4, value: UInt8(state.analogY))

            default:
                break
            }
        }
    }

    // MARK: - State Management

    public func reset() {
        rdram = Data(count: 8 * 1024 * 1024)
        viRegisters = Data(count: 56)
        aiRegisters = Data(count: 24)
        piRegisters = Data(count: 52)
        riRegisters = Data(count: 32)
        siRegisters = Data(count: 28)
        miRegisters = Data(count: 16)
        controllerStates = Array(repeating: ControllerState(), count: 4)
    }

    public func getState() -> MemoryState {
        return MemoryState(
            rdram: rdram,
            cartridgeRam: cartridge?.getSaveData()
        )
    }

    public func setState(_ state: MemoryState) {
        rdram = state.rdram
        cartridge?.setSaveData(state.cartridgeRam)
    }

    public func getUsage() -> Float {
        // Simple usage calculation
        return Float(rdram.count) / Float(8 * 1024 * 1024)
    }
}

// MARK: - Controller State

private struct ControllerState {
    var analogX: Int8 = 0
    var analogY: Int8 = 0
    var buttons: UInt16 = 0

    mutating func setButton(_ button: EmulatorButton, pressed: Bool) {
        let bit: UInt16

        switch button {
        case .a: bit = 0x8000
        case .b: bit = 0x4000
        case .z: bit = 0x2000
        case .start: bit = 0x1000
        case .up: bit = 0x0800
        case .down: bit = 0x0400
        case .left: bit = 0x0200
        case .right: bit = 0x0100
        case .l: bit = 0x0020
        case .r: bit = 0x0010
        case .cUp: bit = 0x0008
        case .cDown: bit = 0x0004
        case .cLeft: bit = 0x0002
        case .cRight: bit = 0x0001
        default: return
        }

        if pressed {
            buttons |= bit
        } else {
            buttons &= ~bit
        }
    }

    func toUInt32() -> UInt32 {
        return (UInt32(buttons) << 16) | (UInt32(bitPattern: Int32(analogX)) << 8) | UInt32(bitPattern: Int32(analogY))
    }

    func toInputState() -> InputState {
        var pressed: Set<EmulatorButton> = []
        if (buttons & 0x8000) != 0 { pressed.insert(.a) }
        if (buttons & 0x4000) != 0 { pressed.insert(.b) }
        if (buttons & 0x2000) != 0 { pressed.insert(.z) }
        if (buttons & 0x1000) != 0 { pressed.insert(.start) }
        if (buttons & 0x0800) != 0 { pressed.insert(.up) }
        if (buttons & 0x0400) != 0 { pressed.insert(.down) }
        if (buttons & 0x0200) != 0 { pressed.insert(.left) }
        if (buttons & 0x0100) != 0 { pressed.insert(.right) }
        if (buttons & 0x0020) != 0 { pressed.insert(.l) }
        if (buttons & 0x0010) != 0 { pressed.insert(.r) }
        if (buttons & 0x0008) != 0 { pressed.insert(.cUp) }
        if (buttons & 0x0004) != 0 { pressed.insert(.cDown) }
        if (buttons & 0x0002) != 0 { pressed.insert(.cLeft) }
        if (buttons & 0x0001) != 0 { pressed.insert(.cRight) }

        let lx = CGFloat(Int(analogX)) / 127.0
        let ly = CGFloat(Int(analogY)) / 127.0
        return InputState(buttons: pressed, leftStick: CGPoint(x: lx, y: ly))
    }
}

// MARK: - Data Extensions (8-bit only)

extension Data {
    mutating func read8(at offset: Int) -> UInt8 {
        guard offset < count else { return 0 }
        return self[offset]
    }

    mutating func write8(at offset: Int, value: UInt8) {
        guard offset < count else { return }
        self[offset] = value
    }
}
