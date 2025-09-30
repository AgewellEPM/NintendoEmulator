import Foundation
import CoreInterface
import Combine
import os.log

/// Performance profiler for emulator optimization
public final class PerformanceProfiler: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isProfilingActive = false
    @Published public private(set) var currentSession: ProfilingSession?
    @Published public private(set) var historySessions: [ProfilingSession] = []
    @Published public private(set) var realTimeMetrics: RealTimeMetrics = RealTimeMetrics()

    // MARK: - Types

    public struct ProfilingSession {
        public var id: UUID = UUID()
        public let startTime: Date
        public var endTime: Date?
        public var duration: TimeInterval { (endTime ?? Date()).timeIntervalSince(startTime) }

        public var frameMetrics: FrameMetrics = FrameMetrics()
        public var cpuMetrics: CPUMetrics = CPUMetrics()
        public var memoryMetrics: MemoryMetrics = MemoryMetrics()
        public var renderingMetrics: RenderingMetrics = RenderingMetrics()
        public var audioMetrics: AudioMetrics = AudioMetrics()

        public var hotspots: [PerformanceHotspot] = []
        public var callGraph: CallGraph = CallGraph()
    }

    public struct RealTimeMetrics {
        public var fps: Double = 0
        public var frameTime: Double = 0
        public var cpuUsage: Double = 0
        public var memoryUsage: UInt64 = 0
        public var renderTime: Double = 0
        public var audioLatency: Double = 0
    }

    public struct FrameMetrics {
        public var totalFrames: UInt64 = 0
        public var droppedFrames: UInt64 = 0
        public var averageFPS: Double = 0
        public var minFrameTime: Double = Double.infinity
        public var maxFrameTime: Double = 0
        public var frameTimeHistory: [Double] = []

        public var frameDropRate: Double {
            totalFrames > 0 ? Double(droppedFrames) / Double(totalFrames) : 0
        }
    }

    public struct CPUMetrics {
        public var totalCycles: UInt64 = 0
        public var instructionsExecuted: UInt64 = 0
        public var cacheHits: UInt64 = 0
        public var cacheMisses: UInt64 = 0
        public var branchPredictions: UInt64 = 0
        public var branchMispredictions: UInt64 = 0

        public var ipc: Double {
            totalCycles > 0 ? Double(instructionsExecuted) / Double(totalCycles) : 0
        }

        public var cacheHitRate: Double {
            let total = cacheHits + cacheMisses
            return total > 0 ? Double(cacheHits) / Double(total) : 0
        }

        public var branchPredictionAccuracy: Double {
            let total = branchPredictions + branchMispredictions
            return total > 0 ? Double(branchPredictions) / Double(total) : 0
        }
    }

    public struct MemoryMetrics {
        public var currentUsage: UInt64 = 0
        public var peakUsage: UInt64 = 0
        public var allocations: UInt64 = 0
        public var deallocations: UInt64 = 0
        public var memoryReads: UInt64 = 0
        public var memoryWrites: UInt64 = 0
        public var usageHistory: [UInt64] = []

        public var netAllocations: Int64 {
            Int64(allocations) - Int64(deallocations)
        }
    }

    public struct RenderingMetrics {
        public var trianglesDrawn: UInt64 = 0
        public var drawCalls: UInt64 = 0
        public var textureUploads: UInt64 = 0
        public var shaderCompilations: UInt64 = 0
        public var renderTime: Double = 0
        public var gpuTime: Double = 0

        public var trianglesPerSecond: Double {
            renderTime > 0 ? Double(trianglesDrawn) / renderTime : 0
        }
    }

    public struct AudioMetrics {
        public var samplesGenerated: UInt64 = 0
        public var bufferUnderuns: UInt64 = 0
        public var bufferOverruns: UInt64 = 0
        public var averageLatency: Double = 0
        public var maxLatency: Double = 0

        public var underrunRate: Double {
            samplesGenerated > 0 ? Double(bufferUnderuns) / Double(samplesGenerated) * 100 : 0
        }
    }

    public struct PerformanceHotspot {
        public var id: UUID = UUID()
        public let function: String
        public let module: String
        public var hitCount: UInt64 = 0
        public var exclusiveTime: Double = 0
        public var inclusiveTime: Double = 0
        public var percentage: Double = 0

        public var averageTime: Double {
            hitCount > 0 ? exclusiveTime / Double(hitCount) : 0
        }
    }

    public struct CallGraph {
        public var nodes: [CallGraphNode] = []
        public var edges: [CallGraphEdge] = []
    }

    public struct CallGraphNode {
        public var id: UUID = UUID()
        public let function: String
        public let module: String
        public var selfTime: Double = 0
        public var totalTime: Double = 0
        public var callCount: UInt64 = 0
    }

    public struct CallGraphEdge {
        public let caller: UUID
        public let callee: UUID
        public var callCount: UInt64 = 0
        public var totalTime: Double = 0
    }

    // MARK: - Private Properties

    private var emulatorCore: EmulatorCoreProtocol?
    private var metricsTimer: Timer?
    private var frameStartTime: CFAbsoluteTime = 0
    private var lastFrameTime: CFAbsoluteTime = 0
    private var sampleCount = 0
    private let maxHistorySize = 1000
    private let logger = Logger(subsystem: "com.emulator", category: "Profiler")

    // MARK: - Initialization

    public init() {}

    // MARK: - Public Methods

    /// Connect to emulator core
    public func connect(to core: EmulatorCoreProtocol) {
        emulatorCore = core
    }

    /// Start profiling session
    public func startProfiling() {
        guard !isProfilingActive else { return }

        currentSession = ProfilingSession(startTime: Date())
        isProfilingActive = true

        // Start real-time metrics collection
        metricsTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.updateRealTimeMetrics()
        }

        logger.info("Performance profiling started")
    }

    /// Stop profiling session
    public func stopProfiling() {
        guard isProfilingActive, var session = currentSession else { return }

        session.endTime = Date()
        calculateSessionStatistics(&session)

        // Add to history
        historySessions.append(session)
        if historySessions.count > 20 {
            historySessions.removeFirst()
        }

        currentSession = nil
        isProfilingActive = false

        metricsTimer?.invalidate()
        metricsTimer = nil

        logger.info("Performance profiling stopped. Duration: \(session.duration)s")
    }

    /// Record frame timing
    public func recordFrameStart() {
        frameStartTime = CFAbsoluteTimeGetCurrent()
    }

    public func recordFrameEnd() {
        guard isProfilingActive, var session = currentSession else { return }

        let currentTime = CFAbsoluteTimeGetCurrent()
        let frameTime = currentTime - frameStartTime

        session.frameMetrics.totalFrames += 1
        session.frameMetrics.frameTimeHistory.append(frameTime)

        if frameTime < session.frameMetrics.minFrameTime {
            session.frameMetrics.minFrameTime = frameTime
        }
        if frameTime > session.frameMetrics.maxFrameTime {
            session.frameMetrics.maxFrameTime = frameTime
        }

        // Check for dropped frames (> 20ms for 60fps)
        if frameTime > 0.020 {
            session.frameMetrics.droppedFrames += 1
        }

        // Limit history size
        if session.frameMetrics.frameTimeHistory.count > maxHistorySize {
            session.frameMetrics.frameTimeHistory.removeFirst()
        }

        // Update real-time FPS
        if lastFrameTime > 0 {
            let fps = 1.0 / (currentTime - lastFrameTime)
            realTimeMetrics.fps = fps
            realTimeMetrics.frameTime = frameTime * 1000 // Convert to ms
        }

        lastFrameTime = currentTime
        currentSession = session
    }

    /// Record CPU metrics
    public func recordCPUMetrics(cycles: UInt64, instructions: UInt64) {
        guard isProfilingActive, var session = currentSession else { return }

        session.cpuMetrics.totalCycles += cycles
        session.cpuMetrics.instructionsExecuted += instructions

        currentSession = session
    }

    /// Record memory allocation
    public func recordMemoryAllocation(size: UInt64) {
        guard isProfilingActive, var session = currentSession else { return }

        session.memoryMetrics.allocations += 1
        session.memoryMetrics.currentUsage += size

        if session.memoryMetrics.currentUsage > session.memoryMetrics.peakUsage {
            session.memoryMetrics.peakUsage = session.memoryMetrics.currentUsage
        }

        currentSession = session
    }

    /// Record memory deallocation
    public func recordMemoryDeallocation(size: UInt64) {
        guard isProfilingActive, var session = currentSession else { return }

        session.memoryMetrics.deallocations += 1
        if session.memoryMetrics.currentUsage >= size {
            session.memoryMetrics.currentUsage -= size
        }

        currentSession = session
    }

    /// Record function call
    public func recordFunctionCall(function: String, module: String, executionTime: Double) {
        guard isProfilingActive, var session = currentSession else { return }

        // Update or create hotspot
        if let index = session.hotspots.firstIndex(where: { $0.function == function && $0.module == module }) {
            session.hotspots[index].hitCount += 1
            session.hotspots[index].exclusiveTime += executionTime
        } else {
            var hotspot = PerformanceHotspot(function: function, module: module)
            hotspot.hitCount = 1
            hotspot.exclusiveTime = executionTime
            session.hotspots.append(hotspot)
        }

        currentSession = session
    }

    /// Record rendering metrics
    public func recordRenderingMetrics(triangles: UInt64, drawCalls: UInt64, renderTime: Double) {
        guard isProfilingActive, var session = currentSession else { return }

        session.renderingMetrics.trianglesDrawn += triangles
        session.renderingMetrics.drawCalls += drawCalls
        session.renderingMetrics.renderTime += renderTime

        realTimeMetrics.renderTime = renderTime * 1000 // Convert to ms

        currentSession = session
    }

    /// Export profiling data
    public func exportProfilingData(session: ProfilingSession? = nil) -> Data? {
        let sessionToExport = session ?? currentSession ?? historySessions.last
        guard let session = sessionToExport else { return nil }

        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(session)
        } catch {
            logger.error("Failed to export profiling data: \(error.localizedDescription)")
            return nil
        }
    }

    /// Import profiling data
    public func importProfilingData(from data: Data) -> Bool {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let session = try decoder.decode(ProfilingSession.self, from: data)
            historySessions.append(session)
            return true
        } catch {
            logger.error("Failed to import profiling data: \(error.localizedDescription)")
            return false
        }
    }

    /// Clear profiling history
    public func clearHistory() {
        historySessions.removeAll()
    }

    /// Get performance summary
    public func getPerformanceSummary() -> PerformanceSummary {
        guard let session = currentSession ?? historySessions.last else {
            return PerformanceSummary()
        }

        return PerformanceSummary(
            averageFPS: session.frameMetrics.averageFPS,
            frameDropRate: session.frameMetrics.frameDropRate,
            cpuEfficiency: session.cpuMetrics.ipc,
            memoryPeakUsage: session.memoryMetrics.peakUsage,
            renderPerformance: session.renderingMetrics.trianglesPerSecond,
            overallScore: calculatePerformanceScore(session)
        )
    }

    // MARK: - Private Methods

    private func updateRealTimeMetrics() {
        guard emulatorCore != nil else { return }

        // Update CPU usage (simulated)
        realTimeMetrics.cpuUsage = Double.random(in: 20...80)

        // Update memory usage (simulated)
        realTimeMetrics.memoryUsage = UInt64.random(in: 50_000_000...200_000_000)

        // Update audio latency (simulated)
        realTimeMetrics.audioLatency = Double.random(in: 5...15)
    }

    private func calculateSessionStatistics(_ session: inout ProfilingSession) {
        // Calculate average FPS
        if !session.frameMetrics.frameTimeHistory.isEmpty {
            let totalTime = session.frameMetrics.frameTimeHistory.reduce(0, +)
            session.frameMetrics.averageFPS = Double(session.frameMetrics.frameTimeHistory.count) / totalTime
        }

        // Calculate hotspot percentages
        let totalExecutionTime = session.hotspots.reduce(0) { $0 + $1.exclusiveTime }
        for i in session.hotspots.indices {
            if totalExecutionTime > 0 {
                session.hotspots[i].percentage = (session.hotspots[i].exclusiveTime / totalExecutionTime) * 100
            }
        }

        // Sort hotspots by execution time
        session.hotspots.sort { $0.exclusiveTime > $1.exclusiveTime }
    }

    private func calculatePerformanceScore(_ session: ProfilingSession) -> Double {
        var score: Double = 100

        // Penalize low FPS
        if session.frameMetrics.averageFPS < 60 {
            score -= (60 - session.frameMetrics.averageFPS) * 2
        }

        // Penalize frame drops
        score -= session.frameMetrics.frameDropRate * 50

        // Penalize low CPU efficiency
        if session.cpuMetrics.ipc < 1.0 {
            score -= (1.0 - session.cpuMetrics.ipc) * 20
        }

        // Penalize excessive memory usage
        if session.memoryMetrics.peakUsage > 512_000_000 { // 512MB
            let excess = Double(session.memoryMetrics.peakUsage - 512_000_000) / 1_000_000
            score -= excess * 0.1
        }

        return max(0, min(100, score))
    }
}

// MARK: - Supporting Types

public struct PerformanceSummary {
    public let averageFPS: Double
    public let frameDropRate: Double
    public let cpuEfficiency: Double
    public let memoryPeakUsage: UInt64
    public let renderPerformance: Double
    public let overallScore: Double

    public init(
        averageFPS: Double = 0,
        frameDropRate: Double = 0,
        cpuEfficiency: Double = 0,
        memoryPeakUsage: UInt64 = 0,
        renderPerformance: Double = 0,
        overallScore: Double = 0
    ) {
        self.averageFPS = averageFPS
        self.frameDropRate = frameDropRate
        self.cpuEfficiency = cpuEfficiency
        self.memoryPeakUsage = memoryPeakUsage
        self.renderPerformance = renderPerformance
        self.overallScore = overallScore
    }
}

// MARK: - Codable Conformance

extension PerformanceProfiler.ProfilingSession: Codable {}
extension PerformanceProfiler.FrameMetrics: Codable {}
extension PerformanceProfiler.CPUMetrics: Codable {}
extension PerformanceProfiler.MemoryMetrics: Codable {}
extension PerformanceProfiler.RenderingMetrics: Codable {}
extension PerformanceProfiler.AudioMetrics: Codable {}
extension PerformanceProfiler.PerformanceHotspot: Codable {}
extension PerformanceProfiler.CallGraph: Codable {}
extension PerformanceProfiler.CallGraphNode: Codable {}
extension PerformanceProfiler.CallGraphEdge: Codable {}
