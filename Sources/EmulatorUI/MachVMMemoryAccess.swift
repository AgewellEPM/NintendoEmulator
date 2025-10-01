import Foundation
import Darwin.Mach

/// Low-level Mach VM API wrapper for process memory reading
/// Uses macOS-specific APIs to read memory from another process
public class MachVMMemoryAccess {

    // MARK: - Properties

    private var targetTask: mach_port_t = 0
    private var targetPID: pid_t = 0

    public var isConnected: Bool {
        return targetTask != 0
    }

    /// Expose target task for advanced operations (like vm_region scanning)
    internal var taskPort: mach_port_t {
        return targetTask
    }

    // MARK: - Connection

    /// Connect to target process
    public func connect(pid: pid_t) -> Bool {
        self.targetPID = pid

        // Get task port for target process
        var task: mach_port_t = 0
        let kr = task_for_pid(mach_task_self_, pid, &task)

        guard kr == KERN_SUCCESS else {
            print("⚠️ [MachVM] task_for_pid failed: \(machErrorString(kr))")
            print("⚠️ [MachVM] This requires debugger entitlements or running as root")
            return false
        }

        targetTask = task
        print("✅ [MachVM] Connected to process \(pid)")
        return true
    }

    /// Disconnect from target process
    public func disconnect() {
        if targetTask != 0 {
            mach_port_deallocate(mach_task_self_, targetTask)
            targetTask = 0
        }
        targetPID = 0
    }

    // MARK: - Memory Reading

    /// Read bytes from target process memory
    public func readBytes(address: UInt64, size: Int) -> Data? {
        guard isConnected else { return nil }

        var data = Data(count: size)
        var bytesRead: mach_vm_size_t = 0

        let result = data.withUnsafeMutableBytes { ptr in
            var localBytesRead = vm_size_t(0)
            let kr = vm_read_overwrite(
                targetTask,
                vm_address_t(truncatingIfNeeded: address),
                vm_size_t(size),
                vm_address_t(UInt(bitPattern: ptr.baseAddress)),
                &localBytesRead
            )
            bytesRead = mach_vm_size_t(localBytesRead)
            return kr
        }

        guard result == KERN_SUCCESS && bytesRead == size else {
            return nil
        }

        return data
    }

    /// Read 8-bit value
    public func read8(address: UInt64) -> UInt8? {
        guard let data = readBytes(address: address, size: 1) else { return nil }
        return data[0]
    }

    /// Read 16-bit value (big-endian)
    public func read16(address: UInt64) -> UInt16? {
        guard let data = readBytes(address: address, size: 2) else { return nil }
        return UInt16(bigEndian: data.withUnsafeBytes { $0.load(as: UInt16.self) })
    }

    /// Read 32-bit value (big-endian)
    public func read32(address: UInt64) -> UInt32? {
        guard let data = readBytes(address: address, size: 4) else { return nil }
        return UInt32(bigEndian: data.withUnsafeBytes { $0.load(as: UInt32.self) })
    }

    /// Read float (big-endian)
    public func readFloat(address: UInt64) -> Float? {
        guard let value = read32(address: address) else { return nil }
        return Float(bitPattern: value)
    }

    // MARK: - Memory Writing

    /// Write bytes to target process memory
    public func writeBytes(address: UInt64, data: Data) -> Bool {
        guard isConnected else { return false }

        let result = data.withUnsafeBytes { ptr -> kern_return_t in
            return vm_write(
                targetTask,
                vm_address_t(truncatingIfNeeded: address),
                vm_offset_t(UInt(bitPattern: ptr.baseAddress)),
                mach_msg_type_number_t(data.count)
            )
        }

        guard result == KERN_SUCCESS else {
            print("⚠️ [MachVM] vm_write failed: \(machErrorString(result))")
            return false
        }

        return true
    }

    /// Write 8-bit value
    public func write8(address: UInt64, value: UInt8) -> Bool {
        var val = value
        let data = Data(bytes: &val, count: 1)
        return writeBytes(address: address, data: data)
    }

    /// Write 16-bit value (big-endian)
    public func write16(address: UInt64, value: UInt16) -> Bool {
        var val = value.bigEndian
        let data = Data(bytes: &val, count: 2)
        return writeBytes(address: address, data: data)
    }

    /// Write 32-bit value (big-endian)
    public func write32(address: UInt64, value: UInt32) -> Bool {
        var val = value.bigEndian
        let data = Data(bytes: &val, count: 4)
        return writeBytes(address: address, data: data)
    }

    /// Write float (big-endian)
    public func writeFloat(address: UInt64, value: Float) -> Bool {
        return write32(address: address, value: value.bitPattern)
    }

    // MARK: - Memory Scanning

    /// Scan process memory regions to find N64 RAM
    public func findRAMRegion(minSize: Int = 4 * 1024 * 1024) -> UInt64? {
        guard isConnected else { return nil }

        var address: vm_address_t = 0
        var size: vm_size_t = 0

        // Scan all memory regions
        while true {
            var info = vm_region_basic_info_data_64_t()
            var infoCount = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_data_64_t>.size / MemoryLayout<Int32>.size)
            var objectName: mach_port_t = 0

            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: Int32.self, capacity: Int(infoCount)) { intPtr in
                    vm_region_64(
                        targetTask,
                        &address,
                        &size,
                        VM_REGION_BASIC_INFO_64,
                        intPtr,
                        &infoCount,
                        &objectName
                    )
                }
            }

            if kr != KERN_SUCCESS {
                break
            }

            // Look for large writable regions (likely RAM)
            if size >= minSize && (info.protection & VM_PROT_WRITE) != 0 {
                let addr64 = UInt64(address)
                print("🔍 [MachVM] Found potential RAM region at 0x\(String(format: "%llX", addr64)) size: \(size / 1024 / 1024)MB")

                // Verify it looks like N64 RAM by checking for patterns
                if verifyN64RAM(at: addr64, size: Int(size)) {
                    return addr64
                }
            }

            // Move to next region
            address += size
        }

        return nil
    }

    /// Verify if memory region contains N64 RAM
    private func verifyN64RAM(at address: UInt64, size: Int) -> Bool {
        // Check for N64 RAM patterns
        // N64 RAM is typically 4-8MB and has specific patterns

        // Read first few bytes
        guard let firstBytes = readBytes(address: address, size: 16) else {
            return false
        }

        // Check if it's not all zeros (uninitialized memory)
        let nonZero = firstBytes.contains { $0 != 0 }
        if !nonZero {
            return false
        }

        // For now, accept large writable regions
        // A more robust check would look for N64 boot patterns
        return size >= 4 * 1024 * 1024 && size <= 8 * 1024 * 1024
    }

    /// Search for N64 boot signature in memory
    public func findN64BootSignature() -> UInt64? {
        guard isConnected else { return nil }

        // N64 ROM header signature: 0x80 0x37 0x12 0x40
        let signature: [UInt8] = [0x80, 0x37, 0x12, 0x40]

        var address: vm_address_t = 0
        var size: vm_size_t = 0

        while true {
            var info = vm_region_basic_info_data_64_t()
            var infoCount = mach_msg_type_number_t(MemoryLayout<vm_region_basic_info_data_64_t>.size / MemoryLayout<Int32>.size)
            var objectName: mach_port_t = 0

            let kr = withUnsafeMutablePointer(to: &info) { infoPtr in
                infoPtr.withMemoryRebound(to: Int32.self, capacity: Int(infoCount)) { intPtr in
                    vm_region_64(
                        targetTask,
                        &address,
                        &size,
                        VM_REGION_BASIC_INFO_64,
                        intPtr,
                        &infoCount,
                        &objectName
                    )
                }
            }

            if kr != KERN_SUCCESS {
                break
            }

            // Search in readable regions
            if (info.protection & VM_PROT_READ) != 0 {
                let addr64 = UInt64(address)
                // Search for signature
                if let offset = searchForPattern(at: addr64, size: Int(size), pattern: signature) {
                    return addr64 + offset
                }
            }

            address += size
        }

        return nil
    }

    /// Search for byte pattern in memory region
    private func searchForPattern(at address: UInt64, size: Int, pattern: [UInt8]) -> UInt64? {
        let chunkSize = 4096 // Read in 4KB chunks
        let patternSize = pattern.count

        for offset in stride(from: 0, to: size - patternSize, by: chunkSize) {
            let readSize = min(chunkSize + patternSize, size - offset)
            guard let chunk = readBytes(address: address + UInt64(offset), size: readSize) else {
                continue
            }

            // Search for pattern in chunk
            for i in 0..<(chunk.count - patternSize) {
                let matches = (0..<patternSize).allSatisfy { chunk[i + $0] == pattern[$0] }
                if matches {
                    return UInt64(offset + i)
                }
            }
        }

        return nil
    }

    // MARK: - Utilities

    /// Get process info
    public func getProcessInfo() -> ProcessInfo? {
        guard isConnected else { return nil }

        var info = proc_taskallinfo()
        let size = MemoryLayout<proc_taskallinfo>.size

        let result = withUnsafeMutablePointer(to: &info) { ptr in
            proc_pidinfo(targetPID, PROC_PIDTASKALLINFO, 0, ptr, Int32(size))
        }

        guard result > 0 else { return nil }

        // Extract process name safely
        let nameBytes = [
            info.pbsd.pbi_comm.0, info.pbsd.pbi_comm.1, info.pbsd.pbi_comm.2, info.pbsd.pbi_comm.3,
            info.pbsd.pbi_comm.4, info.pbsd.pbi_comm.5, info.pbsd.pbi_comm.6, info.pbsd.pbi_comm.7,
            info.pbsd.pbi_comm.8, info.pbsd.pbi_comm.9, info.pbsd.pbi_comm.10, info.pbsd.pbi_comm.11,
            info.pbsd.pbi_comm.12, info.pbsd.pbi_comm.13, info.pbsd.pbi_comm.14, info.pbsd.pbi_comm.15,
            0
        ]
        let name = String(cString: nameBytes)

        return ProcessInfo(
            pid: targetPID,
            name: name,
            virtualSize: info.ptinfo.pti_virtual_size,
            residentSize: info.ptinfo.pti_resident_size,
            threads: info.ptinfo.pti_threadnum
        )
    }

    public struct ProcessInfo {
        public let pid: pid_t
        public let name: String
        public let virtualSize: UInt64
        public let residentSize: UInt64
        public let threads: Int32
    }

    // MARK: - Error Handling

    private func machErrorString(_ error: kern_return_t) -> String {
        switch error {
        case KERN_SUCCESS: return "Success"
        case KERN_INVALID_ADDRESS: return "Invalid address"
        case KERN_PROTECTION_FAILURE: return "Protection failure"
        case KERN_NO_SPACE: return "No space"
        case KERN_INVALID_ARGUMENT: return "Invalid argument"
        case KERN_FAILURE: return "Failure"
        case KERN_RESOURCE_SHORTAGE: return "Resource shortage"
        case KERN_NOT_RECEIVER: return "Not receiver"
        case KERN_NO_ACCESS: return "No access"
        default: return "Error \(error)"
        }
    }
}

// MARK: - Mach VM Constants

private let KERN_SUCCESS: kern_return_t = 0
private let KERN_INVALID_ADDRESS: kern_return_t = 1
private let KERN_PROTECTION_FAILURE: kern_return_t = 2
private let KERN_NO_SPACE: kern_return_t = 3
private let KERN_INVALID_ARGUMENT: kern_return_t = 4
private let KERN_FAILURE: kern_return_t = 5
private let KERN_RESOURCE_SHORTAGE: kern_return_t = 6
private let KERN_NOT_RECEIVER: kern_return_t = 7
private let KERN_NO_ACCESS: kern_return_t = 8

private let VM_PROT_READ: vm_prot_t = 0x01
private let VM_PROT_WRITE: vm_prot_t = 0x02
private let VM_PROT_EXECUTE: vm_prot_t = 0x04

private let VM_REGION_BASIC_INFO_64: Int32 = 9

// MARK: - Process Info Structures

private let PROC_PIDTASKALLINFO: Int32 = 2

private struct proc_taskallinfo {
    var pbsd: proc_bsdinfo = proc_bsdinfo()
    var ptinfo: proc_taskinfo = proc_taskinfo()
}

private struct proc_bsdinfo {
    var pbi_flags: UInt32 = 0
    var pbi_status: UInt32 = 0
    var pbi_xstatus: UInt32 = 0
    var pbi_pid: UInt32 = 0
    var pbi_ppid: UInt32 = 0
    var pbi_uid: uid_t = 0
    var pbi_gid: gid_t = 0
    var pbi_ruid: uid_t = 0
    var pbi_rgid: gid_t = 0
    var pbi_svuid: uid_t = 0
    var pbi_svgid: gid_t = 0
    var rfu_1: UInt32 = 0
    var pbi_comm: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_name: (CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar, CChar) = (0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)
    var pbi_nfiles: UInt32 = 0
    var pbi_pgid: UInt32 = 0
    var pbi_pjobc: UInt32 = 0
    var e_tdev: UInt32 = 0
    var e_tpgid: UInt32 = 0
    var pbi_nice: Int32 = 0
    var pbi_start_tvsec: UInt64 = 0
    var pbi_start_tvusec: UInt64 = 0
}

private struct proc_taskinfo {
    var pti_virtual_size: UInt64 = 0
    var pti_resident_size: UInt64 = 0
    var pti_total_user: UInt64 = 0
    var pti_total_system: UInt64 = 0
    var pti_threads_user: UInt64 = 0
    var pti_threads_system: UInt64 = 0
    var pti_policy: Int32 = 0
    var pti_faults: Int32 = 0
    var pti_pageins: Int32 = 0
    var pti_cow_faults: Int32 = 0
    var pti_messages_sent: Int32 = 0
    var pti_messages_received: Int32 = 0
    var pti_syscalls_mach: Int32 = 0
    var pti_syscalls_unix: Int32 = 0
    var pti_csw: Int32 = 0
    var pti_threadnum: Int32 = 0
    var pti_numrunning: Int32 = 0
    var pti_priority: Int32 = 0
}