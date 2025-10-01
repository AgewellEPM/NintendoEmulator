import Foundation
import CoreInterface

/// Bridge for reading N64 emulator memory in real-time
/// Uses shared memory or process memory reading to access emulator RAM
public class N64MemoryBridge {

    // MARK: - Types

    public enum MemoryAccessMethod {
        case sharedMemory   // Fastest - shared memory segment
        case processMemory  // Medium - read from process memory
        case periodicDump   // Slowest - periodic memory dumps
    }

    // MARK: - Properties

    private var accessMethod: MemoryAccessMethod = .processMemory
    private var emulatorPID: pid_t = 0
    private var ramBaseAddress: UInt64 = 0
    private var sharedMemoryFd: Int32 = -1
    private var sharedMemorySize: Int = 8 * 1024 * 1024 // 8MB (N64 RAM expansion)
    private var machVM: MachVMMemoryAccess?

    // Cache for performance
    private var cachedMemory: Data?
    private var lastUpdateTime: Date = Date()
    private let cacheTimeout: TimeInterval = 0.016 // ~60 FPS

    public var isConnected: Bool {
        return ramBaseAddress != 0 && machVM?.isConnected == true
    }

    /// Expose MachVM instance for advanced operations
    public func getMachVM() -> MachVMMemoryAccess? {
        return machVM
    }

    // MARK: - Initialization

    public init() {}

    deinit {
        disconnect()
    }

    // MARK: - Connection

    /// Connect to running mupen64plus emulator
    public func connect(emulatorPID: pid_t) -> Bool {
        self.emulatorPID = emulatorPID
        self.accessMethod = .processMemory

        print("🧠 [N64MemoryBridge] Connecting to PID: \(emulatorPID)")

        // Create MachVM accessor
        let vm = MachVMMemoryAccess()
        guard vm.connect(pid: emulatorPID) else {
            print("⚠️ [N64MemoryBridge] Failed to connect via task_for_pid")
            print("💡 [N64MemoryBridge] Try running with debugger entitlement or as root")
            return false
        }

        machVM = vm

        // Get process info
        if let info = vm.getProcessInfo() {
            print("🧠 [N64MemoryBridge] Process: \(info.name)")
            print("🧠 [N64MemoryBridge] Memory: \(info.virtualSize / 1024 / 1024)MB virtual, \(info.residentSize / 1024 / 1024)MB resident")
        }

        // Try to find RAM base address in process memory
        if let baseAddr = findRAMBaseAddress() {
            ramBaseAddress = baseAddr
            print("🧠 [N64MemoryBridge] Found RAM at: 0x\(String(format: "%llX", baseAddr))")
            return true
        }

        print("⚠️ [N64MemoryBridge] Could not find RAM base address")
        return false
    }

    /// Connect using shared memory segment
    public func connectSharedMemory(segmentName: String) -> Bool {
        self.accessMethod = .sharedMemory

        // Shared memory support - would use shm_open in full implementation
        // For now, just return false as it needs proper POSIX setup
        print("⚠️ [N64MemoryBridge] Shared memory not yet implemented: \(segmentName)")
        return false

        // TODO: Implement with proper shm_open when needed
        // let fd = shm_open(segmentName, O_RDONLY, 0)
        // guard fd != -1 else {
        //     print("⚠️ [N64MemoryBridge] Failed to open shared memory: \(segmentName)")
        //     return false
        // }
        // ...
    }

    /// Disconnect from emulator
    public func disconnect() {
        machVM?.disconnect()
        machVM = nil
        ramBaseAddress = 0
        emulatorPID = 0
        cachedMemory = nil
        print("🧠 [N64MemoryBridge] Disconnected")
    }

    // MARK: - Memory Reading

    /// Read 8-bit value from N64 RAM
    public func read8(_ address: UInt32) -> UInt8 {
        guard isConnected else { return 0 }

        switch accessMethod {
        case .sharedMemory:
            return readFromSharedMemory8(address)
        case .processMemory:
            return readFromProcessMemory8(address)
        case .periodicDump:
            return readFromCachedDump8(address)
        }
    }

    /// Read 16-bit value from N64 RAM (big-endian)
    public func read16(_ address: UInt32) -> UInt16 {
        let high = UInt16(read8(address))
        let low = UInt16(read8(address + 1))
        return (high << 8) | low
    }

    /// Read 32-bit value from N64 RAM (big-endian)
    public func read32(_ address: UInt32) -> UInt32 {
        let b0 = UInt32(read8(address))
        let b1 = UInt32(read8(address + 1))
        let b2 = UInt32(read8(address + 2))
        let b3 = UInt32(read8(address + 3))
        return (b0 << 24) | (b1 << 16) | (b2 << 8) | b3
    }

    /// Read float from N64 RAM
    public func readFloat(_ address: UInt32) -> Float {
        let bits = read32(address)
        return Float(bitPattern: bits)
    }

    /// Read multiple bytes from N64 RAM
    public func readBytes(_ address: UInt32, count: Int) -> Data {
        var data = Data(capacity: count)
        for i in 0..<count {
            data.append(read8(address + UInt32(i)))
        }
        return data
    }

    // MARK: - Private Memory Access Methods

    private func readFromSharedMemory8(_ address: UInt32) -> UInt8 {
        // Not implemented yet
        return 0
    }

    private func readFromProcessMemory8(_ address: UInt32) -> UInt8 {
        guard let vm = machVM, ramBaseAddress != 0 else { return 0 }

        // N64 RAM starts at 0x80000000, map to actual memory address
        let offset = UInt64(address & 0x007FFFFF) // Mask to 8MB range
        let actualAddr = ramBaseAddress + offset

        return vm.read8(address: actualAddr) ?? 0
    }

    private func readFromCachedDump8(_ address: UInt32) -> UInt8 {
        // Update cache if expired
        if Date().timeIntervalSince(lastUpdateTime) > cacheTimeout {
            updateMemoryCache()
        }

        guard let cache = cachedMemory else { return 0 }

        let offset = Int(address & 0x007FFFFF)
        guard offset < cache.count else { return 0 }

        return cache[offset]
    }

    // MARK: - Memory Discovery

    private func findRAMBaseAddress() -> UInt64? {
        guard let vm = machVM else { return nil }

        print("🔍 [N64MemoryBridge] Scanning process memory for N64 RAM...")

        // Try method 1: Search for N64 boot signature
        if let addr = vm.findN64BootSignature() {
            print("✅ [N64MemoryBridge] Found N64 boot signature at 0x\(String(format: "%llX", addr))")
            return addr
        }

        // Try method 2: Find large writable region (4-8MB)
        if let addr = vm.findRAMRegion(minSize: 4 * 1024 * 1024) {
            print("✅ [N64MemoryBridge] Found potential RAM region at 0x\(String(format: "%llX", addr))")
            return addr
        }

        return nil
    }

    private func updateMemoryCache() {
        // Periodically read entire RAM for cached access
        // This is the slowest method but most compatible

        guard emulatorPID > 0 else { return }

        // Read 8MB of RAM
        var data = Data(capacity: sharedMemorySize)

        for offset in stride(from: 0, to: sharedMemorySize, by: 4096) {
            let chunk = readProcessMemoryChunk(offset: offset, size: 4096)
            data.append(chunk)
        }

        cachedMemory = data
        lastUpdateTime = Date()
    }

    private func readProcessMemoryChunk(offset: Int, size: Int) -> Data {
        guard let vm = machVM, ramBaseAddress != 0 else {
            return Data(count: size)
        }

        let addr = ramBaseAddress + UInt64(offset)
        return vm.readBytes(address: addr, size: size) ?? Data(count: size)
    }
}