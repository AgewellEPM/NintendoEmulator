import Foundation
import CoreInterface

/// Direct memory injection for N64 controller input
/// Writes directly to mupen64plus input plugin's BUTTONS structure in memory
public class N64InputMemoryInjector {

    // MARK: - N64 Button Bitmasks

    /// N64 BUTTONS structure bit mapping (from m64p_plugin.h)
    public enum N64Button: UInt32 {
        case cRight     = 0x0001  // C-Right
        case cLeft      = 0x0002  // C-Left
        case cDown      = 0x0004  // C-Down
        case cUp        = 0x0008  // C-Up
        case rTrigger   = 0x0010  // R Trigger
        case lTrigger   = 0x0020  // L Trigger
        case reserved1  = 0x0040  // Reserved
        case reserved2  = 0x0080  // Reserved
        case dpadRight  = 0x0100  // D-Pad Right
        case dpadLeft   = 0x0200  // D-Pad Left
        case dpadDown   = 0x0400  // D-Pad Down
        case dpadUp     = 0x0800  // D-Pad Up
        case start      = 0x1000  // Start Button
        case zTrigger   = 0x2000  // Z Trigger
        case bButton    = 0x4000  // B Button
        case aButton    = 0x8000  // A Button
    }

    // MARK: - Properties

    private let memory: MachVMMemoryAccess
    private var controllerStateAddress: UInt64?
    private var currentButtonState: UInt32 = 0
    private var currentAnalogX: Int8 = 0
    private var currentAnalogY: Int8 = 0

    // Player index (0-3 for N64 controllers 1-4)
    private let player: Int

    // Base address of controller array (Player 1 = offset 0)
    private var baseControllerAddress: UInt64?

    // MARK: - Initialization

    public init(memory: MachVMMemoryAccess, player: Int = 0) {
        self.memory = memory
        self.player = min(max(player, 0), 3)  // Clamp to 0-3
        print("🎮 [N64InputInjector] Initialized for Player \(self.player + 1)")
    }

    // MARK: - Connection

    /// Find and connect to the controller input state in memory
    public func connect() -> Bool {
        guard let address = findControllerStateAddress() else {
            print("❌ [N64InputInjector] Failed to find controller state address for Player \(player + 1)")
            return false
        }

        // Store base address (Player 1)
        self.baseControllerAddress = address

        // Calculate offset for this player (each BUTTONS is 4 bytes)
        // Player 1 = +0, Player 2 = +4, Player 3 = +8, Player 4 = +12
        self.controllerStateAddress = address + UInt64(player * 4)

        print("✅ [N64InputInjector] Player \(player + 1) controller at: 0x\(String(format: "%llX", controllerStateAddress!))")
        return true
    }

    // MARK: - Input Injection

    /// Set button state (pressed or released)
    public func setButton(_ button: N64Button, pressed: Bool) {
        if pressed {
            currentButtonState |= button.rawValue
        } else {
            currentButtonState &= ~button.rawValue
        }

        flushButtonState()
    }

    /// Set analog stick position (-127 to 127)
    public func setAnalogStick(x: Int8, y: Int8) {
        currentAnalogX = x
        currentAnalogY = y
        flushAnalogState()
    }

    /// Release all buttons
    public func releaseAll() {
        currentButtonState = 0
        currentAnalogX = 0
        currentAnalogY = 0
        flushState()
    }

    // MARK: - Memory Writing

    /// Write button state to memory
    private func flushButtonState() {
        guard let address = controllerStateAddress else { return }

        // BUTTONS structure layout:
        // [0-1]: Button bits (16 bits)
        // [2]: X axis (signed byte)
        // [3]: Y axis (signed byte)

        // Write buttons (first 16 bits of UInt32)
        let buttonData = withUnsafeBytes(of: currentButtonState.littleEndian) { Data($0.prefix(2)) }
        if !memory.writeBytes(address: address, data: buttonData) {
            print("⚠️ [N64InputInjector] Failed to write button state")
        }
    }

    /// Write analog stick state to memory
    private func flushAnalogState() {
        guard let address = controllerStateAddress else { return }

        // Write X axis (byte 2)
        var xData = UInt8(bitPattern: currentAnalogX)
        _ = memory.writeBytes(address: address + 2, data: Data(bytes: &xData, count: 1))

        // Write Y axis (byte 3)
        var yData = UInt8(bitPattern: currentAnalogY)
        _ = memory.writeBytes(address: address + 3, data: Data(bytes: &yData, count: 1))
    }

    /// Write complete controller state
    private func flushState() {
        flushButtonState()
        flushAnalogState()
    }

    // MARK: - Memory Scanning

    /// Find the BUTTONS structure in process memory
    private func findControllerStateAddress() -> UInt64? {
        print("🔍 [N64InputInjector] Scanning for controller state...")

        // Strategy 1: Look for known patterns in SDL input plugin
        if let address = scanForSDLControllerState() {
            return address
        }

        // Strategy 2: Look for writable regions with typical controller state patterns
        if let address = scanForControllerPattern() {
            return address
        }

        // Strategy 3: Scan for the plugin itself and find its data section
        if let address = scanForInputPluginData() {
            return address
        }

        print("❌ [N64InputInjector] Could not locate controller state")
        return nil
    }

    /// Scan for SDL input plugin controller state
    private func scanForSDLControllerState() -> UInt64? {
        // The SDL input plugin typically stores controller state near its .data section
        // Look for regions that match expected patterns

        var address: vm_address_t = 0
        var size: vm_size_t = 0

        while true {
            var info = vm_region_basic_info_data_64_t()
            var infoCount = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_data_64_t>.size / MemoryLayout<Int32>.size)
            var objectName: mach_port_t = 0

            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: Int32.self, capacity: Int(infoCount)) { intPtr in
                    vm_region_64(
                        memory.taskPort,
                        &address,
                        &size,
                        VM_REGION_BASIC_INFO_64,
                        intPtr,
                        &infoCount,
                        &objectName
                    )
                }
            }

            if kr != KERN_SUCCESS { break }

            // Look for small writable regions (likely plugin data)
            if size < 1024 * 1024 && size > 1024 &&  // 1KB - 1MB
               (info.protection & VM_PROT_WRITE) != 0 {

                let addr64 = UInt64(address)

                // Read the region and look for controller state patterns
                if let controllerAddr = searchRegionForControllerState(at: addr64, size: Int(size)) {
                    return controllerAddr
                }
            }

            address += size
        }

        return nil
    }

    /// Search a memory region for BUTTONS structure
    private func searchRegionForControllerState(at baseAddress: UInt64, size: Int) -> UInt64? {
        // Read the entire region
        guard let data = memory.readBytes(address: baseAddress, size: size) else {
            return nil
        }

        // Look for patterns that match a BUTTONS structure:
        // - First 2 bytes: button bits (likely 0x0000 if idle)
        // - Next byte: X axis (signed, likely 0x00 or near 0)
        // - Next byte: Y axis (signed, likely 0x00 or near 0)

        // Scan for 4-byte aligned addresses
        for offset in stride(from: 0, to: data.count - 4, by: 4) {
            let bytes = data[offset..<offset+4]

            // Check if this looks like a controller state:
            // - Buttons should be reasonable (not random garbage)
            // - Analog values should be in range -127 to 127

            let buttons = UInt16(bytes[0]) | (UInt16(bytes[1]) << 8)
            let xAxis = Int8(bitPattern: bytes[2])
            let yAxis = Int8(bitPattern: bytes[3])

            // Heuristics:
            // - Button bits should use known masks (not all bits set)
            // - Analog values should be reasonable
            let buttonMask: UInt16 = 0xFF3F  // Valid button bits
            if (buttons & ~buttonMask) == 0 &&  // No invalid bits
               abs(xAxis) <= 127 &&  // Valid X range
               abs(yAxis) <= 127 {   // Valid Y range

                let candidateAddr = baseAddress + UInt64(offset)
                print("🎯 [N64InputInjector] Found candidate at: 0x\(String(format: "%llX", candidateAddr))")
                return candidateAddr
            }
        }

        return nil
    }

    /// Scan for controller pattern by looking for specific signatures
    private func scanForControllerPattern() -> UInt64? {
        // Alternative strategy: look for memory regions that change when pressing buttons
        // This requires the emulator to be running and someone pressing buttons

        print("💡 [N64InputInjector] Hint: Press buttons in the emulator to help locate controller state")

        // Take snapshot 1
        let snapshot1 = captureMemorySnapshot()

        // Wait briefly
        Thread.sleep(forTimeInterval: 0.5)

        // Take snapshot 2
        let snapshot2 = captureMemorySnapshot()

        // Find differences
        for (address, data1) in snapshot1 {
            if let data2 = snapshot2[address] {
                if data1 != data2 {
                    print("🔍 [N64InputInjector] Changed region at: 0x\(String(format: "%llX", address))")
                    // Check if this looks like controller state
                    if let controllerAddr = searchRegionForControllerState(at: address, size: data1.count) {
                        return controllerAddr
                    }
                }
            }
        }

        return nil
    }

    /// Scan for input plugin .data section
    private func scanForInputPluginData() -> UInt64? {
        // Look for dylib regions containing "input" in their name
        // This requires parsing the process's loaded dylib list

        var address: vm_address_t = 0
        var size: vm_size_t = 0

        while true {
            var info = vm_region_basic_info_data_64_t()
            var infoCount = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_data_64_t>.size / MemoryLayout<Int32>.size)
            var objectName: mach_port_t = 0

            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: Int32.self, capacity: Int(infoCount)) { intPtr in
                    vm_region_64(
                        memory.taskPort,
                        &address,
                        &size,
                        VM_REGION_BASIC_INFO_64,
                        intPtr,
                        &infoCount,
                        &objectName
                    )
                }
            }

            if kr != KERN_SUCCESS { break }

            // Look for regions around 64KB-1MB (typical plugin size)
            if size >= 64 * 1024 && size <= 1024 * 1024 &&
               (info.protection & VM_PROT_WRITE) != 0 {

                let addr64 = UInt64(address)

                // Search this region
                if let controllerAddr = searchRegionForControllerState(at: addr64, size: Int(size)) {
                    return controllerAddr
                }
            }

            address += size
        }

        return nil
    }

    /// Capture snapshot of writable memory regions
    private func captureMemorySnapshot() -> [UInt64: Data] {
        var snapshot: [UInt64: Data] = [:]
        var address: vm_address_t = 0
        var size: vm_size_t = 0

        while true {
            var info = vm_region_basic_info_data_64_t()
            var infoCount = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_data_64_t>.size / MemoryLayout<Int32>.size)
            var objectName: mach_port_t = 0

            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: Int32.self, capacity: Int(infoCount)) { intPtr in
                    vm_region_64(
                        memory.taskPort,
                        &address,
                        &size,
                        VM_REGION_BASIC_INFO_64,
                        intPtr,
                        &infoCount,
                        &objectName
                    )
                }
            }

            if kr != KERN_SUCCESS { break }

            if size < 1024 * 1024 && (info.protection & VM_PROT_WRITE) != 0 {
                let addr64 = UInt64(address)
                if let data = memory.readBytes(address: addr64, size: Int(size)) {
                    snapshot[addr64] = data
                }
            }

            address += size
        }

        return snapshot
    }

    // MARK: - Mach VM Constants

    private var VM_REGION_BASIC_INFO_64: Int32 { 9 }
    private var VM_PROT_READ: vm_prot_t { 0x01 }
    private var VM_PROT_WRITE: vm_prot_t { 0x02 }
    private var KERN_SUCCESS: kern_return_t { 0 }
}

// MARK: - Convenience Extensions

extension N64InputMemoryInjector {
    /// Map EmulatorButton to N64Button
    public static func mapButton(_ button: EmulatorButton) -> N64Button? {
        switch button {
        case .a: return .aButton
        case .b: return .bButton
        case .x: return .bButton  // N64 has no X
        case .y: return .aButton  // N64 has no Y
        case .start: return .start
        case .select: return nil  // N64 has no select
        case .up: return .dpadUp
        case .down: return .dpadDown
        case .left: return .dpadLeft
        case .right: return .dpadRight
        case .l: return .lTrigger
        case .r: return .rTrigger
        case .zl: return .zTrigger
        case .zr: return .rTrigger
        case .z: return .zTrigger
        case .cUp: return .cUp
        case .cDown: return .cDown
        case .cLeft: return .cLeft
        case .cRight: return .cRight
        case .home: return nil
        case .capture: return nil
        @unknown default: return nil  // Future buttons
        }
    }
}
