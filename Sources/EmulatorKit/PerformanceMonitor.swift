import Foundation
import Combine
import CoreInterface
import os.log
import os.signpost

/// Monitors emulator performance metrics
public final class PerformanceMonitor {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.emulator", category: "Performance")
    private let signposter = OSSignposter(subsystem: "com.emulator", category: "Performance")

    // Metrics tracking
    private var frameCount: Int = 0
    private var frameTimeSum: TimeInterval = 0
    private var lastFrameTime = Date()
    private var lastMetricsUpdate = Date()

    // CPU tracking
    private var lastProcessorInfo: processor_info_array_t?
    private var lastProcessorCount: mach_msg_type_number_t = 0
    private var lastCPUTime: TimeInterval = 0

    // Memory tracking
    private var peakMemoryUsage: Int64 = 0

    // Publishers
    private let metricsSubject = PassthroughSubject<PerformanceMetrics, Never>()
    public var metricsPublisher: AnyPublisher<PerformanceMetrics, Never> {
        metricsSubject.eraseToAnyPublisher()
    }

    // Update timer
    private var timer: Timer?
    private let updateInterval: TimeInterval = 1.0 // Update every second

    // MARK: - Initialization

    public init() {
        logger.info("Performance monitor initialized")
    }

    // MARK: - Public Methods

    /// Start monitoring performance
    public func startMonitoring() {
        logger.info("Starting performance monitoring")

        timer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            self?.updateMetrics()
        }

        lastMetricsUpdate = Date()
    }

    /// Stop monitoring performance
    public func stopMonitoring() {
        logger.info("Stopping performance monitoring")
        timer?.invalidate()
        timer = nil
    }

    /// Record frame rendered
    public func recordFrame() {
        let now = Date()
        let frameTime = now.timeIntervalSince(lastFrameTime)

        frameCount += 1
        frameTimeSum += frameTime
        lastFrameTime = now

        // Use signposts for Instruments integration
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("Frame", id: signpostID)
        signposter.endInterval("Frame", state)
    }

    /// Get current metrics
    public func getCurrentMetrics() -> PerformanceMetrics {
        let elapsed = Date().timeIntervalSince(lastMetricsUpdate)
        let fps = elapsed > 0 ? Double(frameCount) / elapsed : 0
        let avgFrameTime = frameCount > 0 ? frameTimeSum / Double(frameCount) : 0

        return PerformanceMetrics(
            fps: fps,
            frameTime: avgFrameTime,
            cpuUsage: getCPUUsage(),
            memoryUsage: getMemoryUsage(),
            audioLatency: getAudioLatency(),
            inputLatency: getInputLatency()
        )
    }

    /// Reset metrics
    public func reset() {
        frameCount = 0
        frameTimeSum = 0
        lastFrameTime = Date()
        lastMetricsUpdate = Date()
        peakMemoryUsage = 0
        logger.info("Performance metrics reset")
    }

    // MARK: - Private Methods

    private func updateMetrics() {
        let metrics = getCurrentMetrics()
        metricsSubject.send(metrics)

        // Log if performance is poor
        if metrics.fps < 55 && metrics.fps > 0 {
            logger.warning("Low FPS: \(String(format: "%.1f", metrics.fps))")
        }

        if metrics.cpuUsage > 80 {
            logger.warning("High CPU usage: \(String(format: "%.1f%%", metrics.cpuUsage))")
        }

        // Reset counters
        frameCount = 0
        frameTimeSum = 0
        lastMetricsUpdate = Date()
    }

    /// Get current CPU usage percentage
    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         intPointer,
                         &count)
            }
        }

        if result == KERN_SUCCESS {
            let currentTime = TimeInterval(info.user_time.seconds) +
                            TimeInterval(info.system_time.seconds)

            let elapsed = Date().timeIntervalSinceReferenceDate - lastCPUTime

            if lastCPUTime > 0 && elapsed > 0 {
                let cpuUsage = ((currentTime - lastCPUTime) / elapsed) * 100.0
                lastCPUTime = currentTime
                return min(100.0, cpuUsage) // Cap at 100%
            }

            lastCPUTime = currentTime
        }

        return 0
    }

    /// Get current memory usage in bytes
    private func getMemoryUsage() -> Int64 {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size / MemoryLayout<natural_t>.size)

        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPointer in
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         intPointer,
                         &count)
            }
        }

        if result == KERN_SUCCESS {
            let memoryUsage = Int64(info.resident_size)
            peakMemoryUsage = max(peakMemoryUsage, memoryUsage)
            return memoryUsage
        }

        return 0
    }

    /// Get audio latency (placeholder - would be provided by audio engine)
    private func getAudioLatency() -> TimeInterval {
        // This would be calculated by the audio engine based on buffer size and sample rate
        // For now, return a typical value
        return 0.020 // 20ms
    }

    /// Get input latency (placeholder - would be measured by input system)
    private func getInputLatency() -> TimeInterval {
        // This would be measured by tracking time from input event to frame render
        // For now, return a typical value
        return 0.008 // 8ms
    }

    /// Get system info for debugging
    public func getSystemInfo() -> SystemInfo {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        } ?? "Unknown"

        return SystemInfo(
            processorCount: ProcessInfo.processInfo.processorCount,
            physicalMemory: ProcessInfo.processInfo.physicalMemory,
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            machineType: machine,
            isAppleSilicon: isAppleSilicon()
        )
    }

    private func isAppleSilicon() -> Bool {
        var systemInfo = utsname()
        uname(&systemInfo)

        let machine = withUnsafePointer(to: &systemInfo.machine) {
            $0.withMemoryRebound(to: CChar.self, capacity: 1) {
                String(validatingUTF8: $0)
            }
        } ?? ""

        return machine.contains("arm64") || machine.contains("ARM64")
    }
}

// MARK: - System Info

public struct SystemInfo {
    public let processorCount: Int
    public let physicalMemory: UInt64
    public let systemVersion: String
    public let machineType: String
    public let isAppleSilicon: Bool

    public var memoryString: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(physicalMemory))
    }
}

// MARK: - Performance Profiler
// PerformanceProfiler is defined in DebugTools/PerformanceProfiler.swift