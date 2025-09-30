import Foundation
import CoreInterface
import Combine

/// CPU debugger for step-by-step execution and state inspection
public final class CPUDebugger: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isEnabled = false
    @Published public private(set) var isPaused = false
    @Published public private(set) var cpuState: CPUState?
    @Published public private(set) var executionHistory: [ExecutionStep] = []
    @Published public private(set) var breakpoints: Set<UInt32> = []
    @Published public private(set) var watchpoints: [Watchpoint] = []

    // MARK: - Types

    public struct CPUState {
        public let pc: UInt32
        public let sp: UInt32
        public let registers: [String: UInt32]
        public let flags: [String: Bool]
        public let cycles: UInt64
        public let instructionCount: UInt64
    }

    public struct ExecutionStep {
        public let address: UInt32
        public let instruction: String
        public let opcode: [UInt8]
        public let cycles: UInt32
        public let timestamp: Date
        public let registers: [String: UInt32]
    }

    public struct Watchpoint {
        public let id = UUID()
        public let address: UInt32
        public let type: WatchpointType
        public var isEnabled = true
        public var hitCount = 0

        public enum WatchpointType {
            case read
            case write
            case readWrite
        }
    }

    // MARK: - Private Properties

    private var emulatorCore: EmulatorCoreProtocol?
    private let maxHistoryEntries = 1000
    private var stepMode = false
    private var runToAddress: UInt32?

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Enable debugging for the specified core
    public func enable(for core: EmulatorCoreProtocol) {
        emulatorCore = core
        isEnabled = true
        updateCPUState()
    }

    /// Disable debugging
    public func disable() {
        emulatorCore = nil
        isEnabled = false
        isPaused = false
        cpuState = nil
        executionHistory.removeAll()
    }

    /// Pause execution
    public func pause() {
        isPaused = true
        updateCPUState()
    }

    /// Resume execution
    public func resume() {
        isPaused = false
        stepMode = false
        runToAddress = nil
    }

    /// Execute a single instruction
    public func stepInstruction() async {
        guard emulatorCore != nil else { return }

        stepMode = true
        isPaused = false

        // Execute one frame (placeholder for single-instruction step)
        try? await emulatorCore?.runFrame()

        isPaused = true
        updateCPUState()
        logExecutionStep()
    }

    /// Execute until the next function call/return
    public func stepOver() {
        guard emulatorCore != nil, let state = cpuState else { return }

        // Determine next instruction address
        let nextAddress = state.pc + 4 // Simplified - would need proper instruction length
        runToAddress = nextAddress
        resume()
    }

    /// Step into function calls
    public func stepInto() async {
        await stepInstruction()
    }

    /// Execute until function returns
    public func stepOut() async {
        // This would require stack frame analysis
        // Simplified implementation
        await stepInstruction()
    }

    /// Run until hitting a breakpoint or watchpoint
    public func runToCursor(address: UInt32) {
        runToAddress = address
        resume()
    }

    /// Add a breakpoint at the specified address
    public func addBreakpoint(at address: UInt32) {
        breakpoints.insert(address)
    }

    /// Remove a breakpoint
    public func removeBreakpoint(at address: UInt32) {
        breakpoints.remove(address)
    }

    /// Toggle breakpoint at address
    public func toggleBreakpoint(at address: UInt32) {
        if breakpoints.contains(address) {
            removeBreakpoint(at: address)
        } else {
            addBreakpoint(at: address)
        }
    }

    /// Add a watchpoint
    public func addWatchpoint(address: UInt32, type: Watchpoint.WatchpointType) {
        let watchpoint = Watchpoint(address: address, type: type)
        watchpoints.append(watchpoint)
    }

    /// Remove a watchpoint
    public func removeWatchpoint(id: UUID) {
        watchpoints.removeAll { $0.id == id }
    }

    /// Clear all breakpoints
    public func clearBreakpoints() {
        breakpoints.removeAll()
    }

    /// Clear all watchpoints
    public func clearWatchpoints() {
        watchpoints.removeAll()
    }

    /// Clear execution history
    public func clearHistory() {
        executionHistory.removeAll()
    }

    /// Get memory at address
    public func readMemory(at address: UInt32, length: Int = 16) -> [UInt8]? {
        guard emulatorCore != nil else { return nil }

        // This would need to be implemented by the core
        // For now, return dummy data
        return Array(0..<length).map { _ in UInt8.random(in: 0...255) }
    }

    /// Write memory at address
    public func writeMemory(at address: UInt32, data: [UInt8]) -> Bool {
        guard emulatorCore != nil else { return false }

        // This would need to be implemented by the core
        return true
    }

    /// Disassemble instructions at address
    public func disassemble(at address: UInt32, count: Int = 10) -> [DisassemblyLine] {
        guard emulatorCore != nil else { return [] }

        // This would need proper disassembly implementation
        return (0..<count).map { i in
            DisassemblyLine(
                address: address + UInt32(i * 4),
                opcode: Data([0x00, 0x00, 0x00, 0x00]),
                mnemonic: "NOP",
                operands: "",
                comment: nil
            )
        }
    }

    /// Search memory for pattern
    public func searchMemory(pattern: [UInt8], startAddress: UInt32 = 0, endAddress: UInt32 = 0xFFFFFFFF) -> [UInt32] {
        guard emulatorCore != nil else { return [] }

        let results: [UInt32] = []
        // This would need proper memory search implementation
        return results
    }

    // MARK: - Internal Methods

    internal func shouldBreak(at address: UInt32) -> Bool {
        // Check breakpoints
        if breakpoints.contains(address) {
            return true
        }

        // Check run-to address
        if let targetAddress = runToAddress, address == targetAddress {
            runToAddress = nil
            return true
        }

        return false
    }

    internal func checkWatchpoint(address: UInt32, type: Watchpoint.WatchpointType) -> Bool {
        for i in watchpoints.indices {
            let watchpoint = watchpoints[i]
            if watchpoint.isEnabled && watchpoint.address == address {
                switch (watchpoint.type, type) {
                case (.read, .read), (.write, .write), (.readWrite, _):
                    watchpoints[i].hitCount += 1
                    return true
                default:
                    break
                }
            }
        }
        return false
    }

    // MARK: - Private Methods

    private func updateCPUState() {
        guard emulatorCore != nil else { return }

        // This would need to be implemented by the core
        cpuState = CPUState(
            pc: 0x80000000,
            sp: 0x80000000,
            registers: [:],
            flags: [:],
            cycles: 0,
            instructionCount: 0
        )
    }

    private func logExecutionStep() {
        guard let state = cpuState else { return }

        let step = ExecutionStep(
            address: state.pc,
            instruction: "NOP", // Would need proper disassembly
            opcode: [0x00, 0x00, 0x00, 0x00],
            cycles: 1,
            timestamp: Date(),
            registers: state.registers
        )

        executionHistory.append(step)

        // Limit history size
        if executionHistory.count > maxHistoryEntries {
            executionHistory.removeFirst()
        }
    }
}

// MARK: - Supporting Types
// DisassemblyLine is defined in CoreInterface

// MARK: - CPU Debugger Extensions

public extension CPUDebugger {

    /// Get formatted register display
    func getRegisterDisplay() -> [String] {
        guard let state = cpuState else { return [] }

        var display: [String] = []

        // Program Counter
        display.append("PC: \(String(format: "%08X", state.pc))")
        display.append("SP: \(String(format: "%08X", state.sp))")

        // General registers
        for (name, value) in state.registers.sorted(by: { $0.key < $1.key }) {
            display.append("\(name): \(String(format: "%08X", value))")
        }

        // Flags
        let flagDisplay = state.flags.map { name, value in
            "\(name): \(value ? "1" : "0")"
        }.joined(separator: " ")

        if !flagDisplay.isEmpty {
            display.append("Flags: \(flagDisplay)")
        }

        // Execution stats
        display.append("Cycles: \(state.cycles)")
        display.append("Instructions: \(state.instructionCount)")

        return display
    }

    /// Get formatted memory display
    func getMemoryDisplay(at address: UInt32, length: Int = 256) -> [String] {
        guard let memory = readMemory(at: address, length: length) else { return [] }

        var display: [String] = []
        let bytesPerLine = 16

        for i in stride(from: 0, to: memory.count, by: bytesPerLine) {
            let lineAddress = address + UInt32(i)
            let endIndex = min(i + bytesPerLine, memory.count)
            let lineData = Array(memory[i..<endIndex])

            let hexBytes = lineData.map { String(format: "%02X", $0) }.joined(separator: " ")
            let asciiChars = lineData.map { byte in
                (byte >= 32 && byte <= 126) ? Character(UnicodeScalar(byte)) : "."
            }

            let line = String(format: "%08X: %-48s %s",
                            lineAddress,
                            hexBytes,
                            String(asciiChars))
            display.append(line)
        }

        return display
    }

    /// Get call stack (simplified)
    func getCallStack() -> [StackFrame] {
        // This would require stack analysis
        return []
    }
}

public struct StackFrame {
    public let address: UInt32
    public let function: String?
    public let module: String?
}
