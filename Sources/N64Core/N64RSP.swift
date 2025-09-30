import Foundation
import CoreInterface

public final class N64RSP {

    // MARK: - Properties

    private let memory: N64Memory

    // RSP registers (32 x 32-bit)
    private var registers = [UInt32](repeating: 0, count: 32)
    private var pc: UInt32 = 0
    private var nextPC: UInt32 = 4

    // Vector registers (32 x 128-bit)
    private var vectorRegisters = [[UInt16]](repeating: [UInt16](repeating: 0, count: 8), count: 32)

    // RSP memory
    private var dmem = Data(count: 4096) // Data Memory (4KB)
    private var imem = Data(count: 4096) // Instruction Memory (4KB)

    // Control registers
    private var status: UInt32 = 0
    private var dmaFull: UInt32 = 0
    private var dmaBusy: UInt32 = 0
    private var semaphore: UInt32 = 0

    // Execution state
    private var running = false
    private var halted = false
    private var broke = false
    private var singleStep = false

    // Performance
    public var needsUpdate = false
    private var cycleCount = 0
    private var instructionCount = 0

    // MARK: - Initialization

    public init(memory: N64Memory) {
        self.memory = memory
        reset()
    }

    public func reset() {
        registers = [UInt32](repeating: 0, count: 32)
        vectorRegisters = [[UInt16]](repeating: [UInt16](repeating: 0, count: 8), count: 32)
        pc = 0
        nextPC = 4
        status = 0
        dmaFull = 0
        dmaBusy = 0
        semaphore = 0
        running = false
        halted = true
        broke = false
        singleStep = false
        needsUpdate = false
        cycleCount = 0
        instructionCount = 0

        dmem = Data(count: 4096)
        imem = Data(count: 4096)
    }

    // MARK: - Execution

    public func executeFrame() {
        guard running && !halted else { return }

        // Execute up to 1000 instructions per frame
        var executed = 0
        while executed < 1000 && running && !halted && !broke {
            executeInstruction()
            executed += 1
        }

        needsUpdate = false
    }

    private func executeInstruction() {
        let instruction = fetchInstruction()
        decodeAndExecute(instruction)

        pc = nextPC
        nextPC += 4
        instructionCount += 1
        cycleCount += 1

        // Check for break
        if broke {
            halt()
        }

        // Check for single step
        if singleStep {
            halt()
            singleStep = false
        }
    }

    private func fetchInstruction() -> UInt32 {
        guard pc < 4096 else { return 0 }
        return imem.read32BE(at: Int(pc))
    }

    private func decodeAndExecute(_ instruction: UInt32) {
        let opcode = (instruction >> 26) & 0x3F
        let rs = Int((instruction >> 21) & 0x1F)
        let rt = Int((instruction >> 16) & 0x1F)
        let rd = Int((instruction >> 11) & 0x1F)
        let shamt = Int((instruction >> 6) & 0x1F)
        let funct = instruction & 0x3F
        let immediate = instruction & 0xFFFF
        let signExtImm = Int32(Int16(immediate))

        switch opcode {
        case 0x00: // SPECIAL
            executeSpecial(rs: rs, rt: rt, rd: rd, shamt: shamt, funct: funct)

        case 0x01: // REGIMM
            executeRegimm(rs: rs, rt: rt, immediate: immediate)

        case 0x02: // J
            let target = (pc & 0xFFFFF000) | ((instruction & 0x3FFFFFF) << 2)
            nextPC = target

        case 0x03: // JAL
            if rt != 0 { registers[rt] = pc + 8 }
            let target = (pc & 0xFFFFF000) | ((instruction & 0x3FFFFFF) << 2)
            nextPC = target

        case 0x04: // BEQ
            if registers[rs] == registers[rt] {
                nextPC = UInt32(Int32(pc + 4) + (signExtImm << 2))
            }

        case 0x05: // BNE
            if registers[rs] != registers[rt] {
                nextPC = UInt32(Int32(pc + 4) + (signExtImm << 2))
            }

        case 0x08: // ADDI
            if rt != 0 { registers[rt] = UInt32(Int32(registers[rs]) + signExtImm) }

        case 0x09: // ADDIU
            if rt != 0 { registers[rt] = UInt32(Int32(registers[rs]) + signExtImm) }

        case 0x0A: // SLTI
            if rt != 0 { registers[rt] = (Int32(registers[rs]) < signExtImm) ? 1 : 0 }

        case 0x0B: // SLTIU
            if rt != 0 { registers[rt] = (registers[rs] < UInt32(signExtImm)) ? 1 : 0 }

        case 0x0C: // ANDI
            if rt != 0 { registers[rt] = registers[rs] & UInt32(immediate) }

        case 0x0D: // ORI
            if rt != 0 { registers[rt] = registers[rs] | UInt32(immediate) }

        case 0x0E: // XORI
            if rt != 0 {
                registers[rt] = registers[rs] ^ UInt32(immediate)
            }

        case 0x0F: // LUI
            if rt != 0 {
                registers[rt] = UInt32(immediate) << 16
            }

        case 0x12: // COP2 (Vector Unit)
            executeVectorInstruction(instruction)

        case 0x20: // LB
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            if rt != 0 {
                registers[rt] = UInt32(Int32(Int8(bitPattern: readDMEM8(addr))))
            }

        case 0x21: // LH
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            if rt != 0 {
                registers[rt] = UInt32(Int32(Int16(bitPattern: readDMEM16(addr))))
            }

        case 0x23: // LW
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            if rt != 0 {
                registers[rt] = readDMEM32(addr)
            }

        case 0x28: // SB
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            writeDMEM8(addr, value: UInt8(registers[rt] & 0xFF))

        case 0x29: // SH
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            writeDMEM16(addr, value: UInt16(registers[rt] & 0xFFFF))

        case 0x2B: // SW
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            writeDMEM32(addr, value: registers[rt])

        case 0x32: // LWC2 (Load Vector)
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            loadVector(vt: rt, addr: addr, element: Int(rd))

        case 0x3A: // SWC2 (Store Vector)
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            storeVector(vt: rt, addr: addr, element: Int(rd))

        default:
            // Unknown instruction
            break
        }
    }

    private func executeSpecial(rs: Int, rt: Int, rd: Int, shamt: Int, funct: UInt32) {
        switch funct {
        case 0x00: // SLL
            if rd != 0 {
                registers[rd] = registers[rt] << shamt
            }

        case 0x02: // SRL
            if rd != 0 {
                registers[rd] = registers[rt] >> shamt
            }

        case 0x03: // SRA
            if rd != 0 {
                registers[rd] = UInt32(Int32(registers[rt]) >> shamt)
            }

        case 0x08: // JR
            nextPC = registers[rs]

        case 0x09: // JALR
            if rd != 0 {
                registers[rd] = pc + 8
            }
            nextPC = registers[rs]

        case 0x0D: // BREAK
            broke = true

        case 0x21: // ADDU
            if rd != 0 {
                registers[rd] = registers[rs] + registers[rt]
            }

        case 0x23: // SUBU
            if rd != 0 {
                registers[rd] = registers[rs] - registers[rt]
            }

        case 0x24: // AND
            if rd != 0 {
                registers[rd] = registers[rs] & registers[rt]
            }

        case 0x25: // OR
            if rd != 0 {
                registers[rd] = registers[rs] | registers[rt]
            }

        case 0x26: // XOR
            if rd != 0 {
                registers[rd] = registers[rs] ^ registers[rt]
            }

        case 0x27: // NOR
            if rd != 0 {
                registers[rd] = ~(registers[rs] | registers[rt])
            }

        case 0x2A: // SLT
            if rd != 0 {
                registers[rd] = Int32(registers[rs]) < Int32(registers[rt]) ? 1 : 0
            }

        case 0x2B: // SLTU
            if rd != 0 {
                registers[rd] = registers[rs] < registers[rt] ? 1 : 0
            }

        default:
            break
        }
    }

    private func executeRegimm(rs: Int, rt: Int, immediate: UInt32) {
        let signExtImm = Int32(Int16(immediate))

        switch rt {
        case 0x00: // BLTZ
            if Int32(registers[rs]) < 0 {
                nextPC = UInt32(Int32(pc + 4) + (signExtImm << 2))
            }

        case 0x01: // BGEZ
            if Int32(registers[rs]) >= 0 {
                nextPC = UInt32(Int32(pc + 4) + (signExtImm << 2))
            }

        default:
            break
        }
    }

    private func executeVectorInstruction(_ instruction: UInt32) {
        let opcode = (instruction >> 21) & 0x1F
        let vt = Int((instruction >> 16) & 0x1F)
        let vs = Int((instruction >> 11) & 0x1F)
        let vd = Int((instruction >> 6) & 0x1F)
        let element = instruction & 0xF
        let funct = instruction & 0x3F

        switch opcode {
        case 0x10: // Vector ALU operations
            executeVectorALU(vs: vs, vt: vt, vd: vd, element: Int(element), funct: funct)

        default:
            break
        }
    }

    private func executeVectorALU(vs: Int, vt: Int, vd: Int, element: Int, funct: UInt32) {
        switch funct {
        case 0x00: // VMULF - Vector Multiply Low
            for i in 0..<8 {
                let a = Int32(vectorRegisters[vs][i])
                let b = Int32(vectorRegisters[vt][element >= 0 ? element : i])
                let result = (a * b) >> 16
                vectorRegisters[vd][i] = UInt16(result & 0xFFFF)
            }

        case 0x01: // VMULU - Vector Multiply Low Unsigned
            for i in 0..<8 {
                let a = UInt32(vectorRegisters[vs][i])
                let b = UInt32(vectorRegisters[vt][element >= 0 ? element : i])
                let result = (a * b) >> 16
                vectorRegisters[vd][i] = UInt16(result & 0xFFFF)
            }

        case 0x10: // VADD - Vector Add
            for i in 0..<8 {
                let a = Int32(vectorRegisters[vs][i])
                let b = Int32(vectorRegisters[vt][element >= 0 ? element : i])
                let result = a + b
                vectorRegisters[vd][i] = UInt16(result & 0xFFFF)
            }

        case 0x11: // VSUB - Vector Subtract
            for i in 0..<8 {
                let a = Int32(vectorRegisters[vs][i])
                let b = Int32(vectorRegisters[vt][element >= 0 ? element : i])
                let result = a - b
                vectorRegisters[vd][i] = UInt16(result & 0xFFFF)
            }

        case 0x1D: // VSAW - Vector Accumulator Write
            // Write accumulator to vector register
            for i in 0..<8 {
                vectorRegisters[vd][i] = vectorRegisters[vs][i] // Simplified
            }

        default:
            break
        }
    }

    // MARK: - Memory Access

    private func readDMEM8(_ addr: UInt32) -> UInt8 {
        let offset = Int(addr & 0xFFF)
        guard offset < dmem.count else { return 0 }
        return dmem[offset]
    }

    private func readDMEM16(_ addr: UInt32) -> UInt16 {
        let offset = Int(addr & 0xFFE)
        guard offset + 1 < dmem.count else { return 0 }
        return dmem.read16BE(at: offset)
    }

    private func readDMEM32(_ addr: UInt32) -> UInt32 {
        let offset = Int(addr & 0xFFC)
        guard offset + 3 < dmem.count else { return 0 }
        return dmem.read32BE(at: offset)
    }

    private func writeDMEM8(_ addr: UInt32, value: UInt8) {
        let offset = Int(addr & 0xFFF)
        guard offset < dmem.count else { return }
        dmem[offset] = value
    }

    private func writeDMEM16(_ addr: UInt32, value: UInt16) {
        let offset = Int(addr & 0xFFE)
        guard offset + 1 < dmem.count else { return }
        dmem.write16BE(at: offset, value: value)
    }

    private func writeDMEM32(_ addr: UInt32, value: UInt32) {
        let offset = Int(addr & 0xFFC)
        guard offset + 3 < dmem.count else { return }
        dmem.write32BE(at: offset, value: value)
    }

    private func loadVector(vt: Int, addr: UInt32, element: Int) {
        // Load vector from DMEM
        for i in 0..<8 {
            let offset = addr + UInt32(i * 2)
            vectorRegisters[vt][i] = readDMEM16(offset)
        }
    }

    private func storeVector(vt: Int, addr: UInt32, element: Int) {
        // Store vector to DMEM
        for i in 0..<8 {
            let offset = addr + UInt32(i * 2)
            writeDMEM16(offset, value: vectorRegisters[vt][i])
        }
    }

    // MARK: - Control Interface

    public func start() {
        running = true
        halted = false
        broke = false
        needsUpdate = true
    }

    public func halt() {
        running = false
        halted = true
        needsUpdate = false
    }

    public func step() {
        if halted {
            singleStep = true
            running = true
            halted = false
        }
    }

    public func loadProgram(_ program: Data, at address: UInt32 = 0) {
        let maxSize = min(program.count, imem.count - Int(address))
        let range = Int(address)..<Int(address) + maxSize
        imem.replaceSubrange(range, with: program.prefix(maxSize))
    }

    public func readRegister(_ index: Int) -> UInt32 {
        guard index >= 0 && index < 32 else { return 0 }
        return registers[index]
    }

    public func writeRegister(_ index: Int, value: UInt32) {
        guard index > 0 && index < 32 else { return }
        registers[index] = value
    }

    public func readVectorRegister(_ index: Int) -> [UInt16] {
        guard index >= 0 && index < 32 else { return [] }
        return vectorRegisters[index]
    }

    public func writeVectorRegister(_ index: Int, value: [UInt16]) {
        guard index >= 0 && index < 32 && value.count == 8 else { return }
        vectorRegisters[index] = value
    }

    // MARK: - DMA Operations

    public func dmaFromRDRAM(rdramAddr: UInt32, length: UInt32, dmemAddr: UInt32) {
        for i in 0..<length {
            let value = memory.read8(rdramAddr + i)
            writeDMEM8(dmemAddr + i, value: value)
        }
    }

    public func dmaToRDRAM(dmemAddr: UInt32, length: UInt32, rdramAddr: UInt32) {
        for i in 0..<length {
            let value = readDMEM8(dmemAddr + i)
            memory.write8(rdramAddr + i, value: value)
        }
    }

    // MARK: - State Management

    public func getState() -> RSPState {
        return RSPState(
            pc: pc,
            registers: registers,
            dmem: dmem,
            imem: imem
        )
    }

    public func setState(_ state: RSPState) {
        pc = state.pc
        registers = state.registers
        dmem = state.dmem
        imem = state.imem
    }

    public func getStatus() -> UInt32 {
        var result: UInt32 = 0
        if halted { result |= 0x1 }
        if broke { result |= 0x2 }
        if running { result |= 0x4 }
        return result
    }

    public func setStatus(_ value: UInt32) {
        if (value & 0x1) != 0 { halt() }
        if (value & 0x2) != 0 { start() }
        if (value & 0x4) != 0 { broke = false }
    }
}

// Data read/write helpers are defined elsewhere
