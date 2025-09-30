import Foundation
import CoreInterface

public final class N64CPU {

    // MARK: - Registers

    private var registers = [UInt64](repeating: 0, count: 32)
    private var pc: UInt32 = 0xBFC00000 // Boot ROM address
    private var hi: UInt64 = 0
    private var lo: UInt64 = 0

    // Coprocessor 0 (System Control)
    private var cop0Registers = [UInt32](repeating: 0, count: 32)

    // Floating Point Unit (Coprocessor 1)
    private var fpuRegisters = [UInt64](repeating: 0, count: 32)
    private var fcr31: UInt32 = 0 // FPU Control/Status

    // Memory management
    private let memory: N64Memory

    // Execution state
    private var branchDelay = false
    private var nextPC: UInt32 = 0
    private var llBit = false // Load-linked bit

    // Interrupts
    private var interruptPending: UInt8 = 0

    // Performance counters
    private var cycleCount: UInt64 = 0
    private var instructionCount: UInt64 = 0

    // MARK: - Initialization

    public init(memory: N64Memory) {
        self.memory = memory
        reset()
    }

    public func reset() {
        registers = [UInt64](repeating: 0, count: 32)
        pc = 0xBFC00000
        hi = 0
        lo = 0
        cop0Registers = [UInt32](repeating: 0, count: 32)
        fpuRegisters = [UInt64](repeating: 0, count: 32)
        fcr31 = 0
        branchDelay = false
        nextPC = 0
        llBit = false
        interruptPending = 0
        cycleCount = 0
        instructionCount = 0

        // Initialize COP0 registers
        cop0Registers[12] = 0x34000000 // Status register
        cop0Registers[15] = 0x00000B00 // PRId (VR4300)
        cop0Registers[16] = 0x0006E463 // Config
    }

    // MARK: - Execution

    public func executeInstruction() -> Int {
        let instruction = fetchInstruction()
        let cycles = decodeAndExecute(instruction)

        // Handle branch delay
        if branchDelay {
            pc = nextPC
            branchDelay = false
        } else {
            pc += 4
        }

        cycleCount += UInt64(cycles)
        instructionCount += 1

        // Check for interrupts
        if interruptPending != 0 && (cop0Registers[12] & 0x1) != 0 {
            handleInterrupt()
        }

        return cycles
    }

    private func fetchInstruction() -> UInt32 {
        return memory.read32(pc)
    }

    private func decodeAndExecute(_ instruction: UInt32) -> Int {
        let opcode = (instruction >> 26) & 0x3F
        let rs = Int((instruction >> 21) & 0x1F)
        let rt = Int((instruction >> 16) & 0x1F)
        let rd = Int((instruction >> 11) & 0x1F)
        let shamt = Int((instruction >> 6) & 0x1F)
        let funct = instruction & 0x3F
        let immediate = instruction & 0xFFFF
        let signExtImm = Int32(Int16(immediate))
        let address = instruction & 0x3FFFFFF

        switch opcode {
        case 0x00: // SPECIAL
            return executeSpecial(rs: rs, rt: rt, rd: rd, shamt: shamt, funct: funct)

        case 0x01: // REGIMM
            return executeRegimm(rs: rs, rt: rt, immediate: immediate)

        case 0x02: // J
            branch(to: (pc & 0xF0000000) | (address << 2))
            return 1

        case 0x03: // JAL
            registers[31] = UInt64(pc + 8)
            branch(to: (pc & 0xF0000000) | (address << 2))
            return 1

        case 0x04: // BEQ
            if registers[rs] == registers[rt] {
                branch(to: UInt32(Int32(pc + 4) + (signExtImm << 2)))
            }
            return 1

        case 0x05: // BNE
            if registers[rs] != registers[rt] {
                branch(to: UInt32(Int32(pc + 4) + (signExtImm << 2)))
            }
            return 1

        case 0x06: // BLEZ
            if Int64(registers[rs]) <= 0 {
                branch(to: UInt32(Int32(pc + 4) + (signExtImm << 2)))
            }
            return 1

        case 0x07: // BGTZ
            if Int64(registers[rs]) > 0 {
                branch(to: UInt32(Int32(pc + 4) + (signExtImm << 2)))
            }
            return 1

        case 0x08: // ADDI
            let result = Int64(registers[rs]) + Int64(signExtImm)
            if checkOverflow(Int64(registers[rs]), Int64(signExtImm), result) {
                triggerException(.overflow)
            } else {
                registers[rt] = UInt64(result)
            }
            return 1

        case 0x09: // ADDIU
            registers[rt] = UInt64(Int64(registers[rs]) + Int64(signExtImm))
            return 1

        case 0x0A: // SLTI
            registers[rt] = Int64(registers[rs]) < Int64(signExtImm) ? 1 : 0
            return 1

        case 0x0B: // SLTIU
            registers[rt] = registers[rs] < UInt64(signExtImm) ? 1 : 0
            return 1

        case 0x0C: // ANDI
            registers[rt] = registers[rs] & UInt64(immediate)
            return 1

        case 0x0D: // ORI
            registers[rt] = registers[rs] | UInt64(immediate)
            return 1

        case 0x0E: // XORI
            registers[rt] = registers[rs] ^ UInt64(immediate)
            return 1

        case 0x0F: // LUI
            registers[rt] = UInt64(immediate) << 16
            return 1

        case 0x10: // COP0
            return executeCOP0(rs: rs, rt: rt, rd: rd, funct: funct)

        case 0x11: // COP1 (FPU)
            return executeCOP1(instruction)

        case 0x20: // LB
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            let value = Int8(bitPattern: memory.read8(addr))
            registers[rt] = UInt64(Int64(value))
            return 3

        case 0x21: // LH
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            let value = Int16(bitPattern: memory.read16(addr))
            registers[rt] = UInt64(Int64(value))
            return 3

        case 0x23: // LW
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            let value = Int32(bitPattern: memory.read32(addr))
            registers[rt] = UInt64(Int64(value))
            return 3

        case 0x24: // LBU
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            registers[rt] = UInt64(memory.read8(addr))
            return 3

        case 0x25: // LHU
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            registers[rt] = UInt64(memory.read16(addr))
            return 3

        case 0x28: // SB
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            memory.write8(addr, value: UInt8(registers[rt] & 0xFF))
            return 1

        case 0x29: // SH
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            memory.write16(addr, value: UInt16(registers[rt] & 0xFFFF))
            return 1

        case 0x2B: // SW
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            memory.write32(addr, value: UInt32(registers[rt] & 0xFFFFFFFF))
            return 1

        case 0x30: // LL (Load Linked)
            let addr = UInt32(Int32(registers[rs]) + signExtImm)
            let value = Int32(bitPattern: memory.read32(addr))
            registers[rt] = UInt64(Int64(value))
            llBit = true
            return 3

        case 0x38: // SC (Store Conditional)
            if llBit {
                let addr = UInt32(Int32(registers[rs]) + signExtImm)
                memory.write32(addr, value: UInt32(registers[rt] & 0xFFFFFFFF))
                registers[rt] = 1
            } else {
                registers[rt] = 0
            }
            llBit = false
            return 1

        default:
            // Unimplemented instruction
            triggerException(.reservedInstruction)
            return 1
        }
    }

    private func executeSpecial(rs: Int, rt: Int, rd: Int, shamt: Int, funct: UInt32) -> Int {
        switch funct {
        case 0x00: // SLL
            if rd != 0 {
                registers[rd] = UInt64(UInt32(registers[rt]) << shamt)
            }
            return 1

        case 0x02: // SRL
            if rd != 0 {
                registers[rd] = UInt64(UInt32(registers[rt]) >> shamt)
            }
            return 1

        case 0x03: // SRA
            if rd != 0 {
                registers[rd] = UInt64(Int64(Int32(registers[rt])) >> shamt)
            }
            return 1

        case 0x08: // JR
            branch(to: UInt32(registers[rs]))
            return 1

        case 0x09: // JALR
            if rd != 0 {
                registers[rd] = UInt64(pc + 8)
            }
            branch(to: UInt32(registers[rs]))
            return 1

        case 0x0C: // SYSCALL
            triggerException(.syscall)
            return 1

        case 0x0D: // BREAK
            triggerException(.breakpoint)
            return 1

        case 0x20: // ADD
            let result = Int64(registers[rs]) + Int64(registers[rt])
            if checkOverflow(Int64(registers[rs]), Int64(registers[rt]), result) {
                triggerException(.overflow)
            } else if rd != 0 {
                registers[rd] = UInt64(result)
            }
            return 1

        case 0x21: // ADDU
            if rd != 0 {
                registers[rd] = registers[rs] + registers[rt]
            }
            return 1

        case 0x22: // SUB
            let result = Int64(registers[rs]) - Int64(registers[rt])
            if checkOverflow(Int64(registers[rs]), -Int64(registers[rt]), result) {
                triggerException(.overflow)
            } else if rd != 0 {
                registers[rd] = UInt64(result)
            }
            return 1

        case 0x23: // SUBU
            if rd != 0 {
                registers[rd] = registers[rs] - registers[rt]
            }
            return 1

        case 0x24: // AND
            if rd != 0 {
                registers[rd] = registers[rs] & registers[rt]
            }
            return 1

        case 0x25: // OR
            if rd != 0 {
                registers[rd] = registers[rs] | registers[rt]
            }
            return 1

        case 0x26: // XOR
            if rd != 0 {
                registers[rd] = registers[rs] ^ registers[rt]
            }
            return 1

        case 0x27: // NOR
            if rd != 0 {
                registers[rd] = ~(registers[rs] | registers[rt])
            }
            return 1

        case 0x2A: // SLT
            if rd != 0 {
                registers[rd] = Int64(registers[rs]) < Int64(registers[rt]) ? 1 : 0
            }
            return 1

        case 0x2B: // SLTU
            if rd != 0 {
                registers[rd] = registers[rs] < registers[rt] ? 1 : 0
            }
            return 1

        default:
            triggerException(.reservedInstruction)
            return 1
        }
    }

    private func executeRegimm(rs: Int, rt: Int, immediate: UInt32) -> Int {
        let signExtImm = Int32(Int16(immediate))

        switch rt {
        case 0x01: // BGEZ
            if Int64(registers[rs]) >= 0 {
                branch(to: UInt32(Int32(pc + 4) + (signExtImm << 2)))
            }
            return 1

        case 0x11: // BGEZAL
            registers[31] = UInt64(pc + 8)
            if Int64(registers[rs]) >= 0 {
                branch(to: UInt32(Int32(pc + 4) + (signExtImm << 2)))
            }
            return 1

        default:
            triggerException(.reservedInstruction)
            return 1
        }
    }

    private func executeCOP0(rs: Int, rt: Int, rd: Int, funct: UInt32) -> Int {
        switch rs {
        case 0x00: // MFC0
            if rt != 0 {
                registers[rt] = UInt64(Int64(Int32(cop0Registers[rd])))
            }
            return 1

        case 0x04: // MTC0
            cop0Registers[rd] = UInt32(registers[rt])
            handleCOP0Write(register: rd, value: UInt32(registers[rt]))
            return 1

        case 0x10: // COP0 function
            switch funct {
            case 0x18: // ERET
                pc = cop0Registers[14] // EPC
                cop0Registers[12] &= ~0x2 // Clear EXL bit
                return 1

            default:
                triggerException(.reservedInstruction)
                return 1
            }

        default:
            triggerException(.reservedInstruction)
            return 1
        }
    }

    private func executeCOP1(_ instruction: UInt32) -> Int {
        // Simplified FPU implementation
        triggerException(.coprocessorUnusable)
        return 1
    }

    // MARK: - Helper Methods

    private func branch(to address: UInt32) {
        nextPC = address
        branchDelay = true
    }

    private func checkOverflow(_ a: Int64, _ b: Int64, _ result: Int64) -> Bool {
        let signA = a < 0
        let signB = b < 0
        let signResult = result < 0

        return (signA == signB) && (signA != signResult)
    }

    private func handleCOP0Write(register: Int, value: UInt32) {
        switch register {
        case 12: // Status
            // Handle status register changes
            break
        case 13: // Cause
            // Handle cause register changes
            break
        default:
            break
        }
    }

    // MARK: - Interrupts and Exceptions

    public enum Interrupt: UInt8 {
        case vi = 0x01
        case si = 0x02
        case pi = 0x04
        case ai = 0x08
    }

    public enum Exception {
        case interrupt
        case tlbModification
        case tlbLoad
        case tlbStore
        case addressErrorLoad
        case addressErrorStore
        case busErrorInstruction
        case busErrorData
        case syscall
        case breakpoint
        case reservedInstruction
        case coprocessorUnusable
        case overflow
        case trap
        case floatingPoint
    }

    public func setInterrupt(_ interrupt: Interrupt) {
        interruptPending |= interrupt.rawValue
        cop0Registers[13] |= UInt32(interrupt.rawValue) << 8 // Set IP bits in Cause
    }

    public func clearInterrupt(_ interrupt: Interrupt) {
        interruptPending &= ~interrupt.rawValue
        cop0Registers[13] &= ~(UInt32(interrupt.rawValue) << 8)
    }

    private func triggerException(_ exception: Exception) {
        let exceptionCode: UInt32

        switch exception {
        case .interrupt: exceptionCode = 0
        case .tlbModification: exceptionCode = 1
        case .tlbLoad: exceptionCode = 2
        case .tlbStore: exceptionCode = 3
        case .addressErrorLoad: exceptionCode = 4
        case .addressErrorStore: exceptionCode = 5
        case .busErrorInstruction: exceptionCode = 6
        case .busErrorData: exceptionCode = 7
        case .syscall: exceptionCode = 8
        case .breakpoint: exceptionCode = 9
        case .reservedInstruction: exceptionCode = 10
        case .coprocessorUnusable: exceptionCode = 11
        case .overflow: exceptionCode = 12
        case .trap: exceptionCode = 13
        case .floatingPoint: exceptionCode = 15
        }

        // Save current PC to EPC
        cop0Registers[14] = branchDelay ? pc - 4 : pc

        // Set EXL bit in Status
        cop0Registers[12] |= 0x2

        // Set exception code in Cause
        cop0Registers[13] = (cop0Registers[13] & ~0x7C) | (exceptionCode << 2)

        // Set BD bit if in branch delay
        if branchDelay {
            cop0Registers[13] |= 0x80000000
        } else {
            cop0Registers[13] &= ~0x80000000
        }

        // Jump to exception handler
        pc = (cop0Registers[12] & 0x400000) != 0 ? 0xBFC00380 : 0x80000180
        branchDelay = false
    }

    private func handleInterrupt() {
        triggerException(.interrupt)
    }

    // MARK: - State Management

    public func getState() -> CPUState {
        return CPUState(
            pc: pc,
            registers: registers,
            hi: hi,
            lo: lo
        )
    }

    public func setState(_ state: CPUState) {
        pc = state.pc
        registers = state.registers
        hi = state.hi
        lo = state.lo
    }

    public func getUsage() -> Float {
        // Simple usage based on instruction complexity
        return Float(cycleCount % 1000) / 1000.0
    }

    // MARK: - Register Access

    public func getRegister(_ index: Int) -> UInt64 {
        guard index > 0 && index < 32 else { return 0 }
        return registers[index]
    }

    public func setRegister(_ index: Int, value: UInt64) {
        guard index > 0 && index < 32 else { return }
        registers[index] = value
    }

    public func getPC() -> UInt32 {
        return pc
    }

    public func getCOP0Register(_ index: Int) -> UInt32 {
        guard index >= 0 && index < 32 else { return 0 }
        return cop0Registers[index]
    }
}
