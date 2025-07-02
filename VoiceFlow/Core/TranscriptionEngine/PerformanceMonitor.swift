import Foundation
import os.log
import QuartzCore
import Combine

@MainActor
public final class PerformanceMonitor: ObservableObject {
    // MARK: - Singleton
    
    public static let shared = PerformanceMonitor()
    
    // MARK: - Logging
    
    private let performanceLog = OSLog(subsystem: "com.voiceflow.mac", category: "Performance")
    
    // MARK: - Latency Requirements
    
    public struct LatencyRequirements {
        public static let transcriptionP50: TimeInterval = 0.030  // 30ms
        public static let transcriptionP95: TimeInterval = 0.050  // 50ms
        public static let transcriptionP99: TimeInterval = 0.100  // 100ms
        public static let uiResponseTime: TimeInterval = 0.016   // 60fps
    }
    
    // MARK: - Memory Requirements
    
    public struct MemoryRequirements {
        public static let baselineUsage: Int = 150_000_000      // 150MB
        public static let activeTranscription: Int = 200_000_000 // 200MB
        public static let withModelsLoaded: Int = 500_000_000   // 500MB
        public static let warningThreshold: Int = 800_000_000   // 800MB
    }
    
    // MARK: - CPU Requirements
    
    public struct CPURequirements {
        public static let idleUsage: Double = 0.01              // 1%
        public static let activeTranscription: Double = 0.10     // 10%
        public static let peakUsage: Double = 0.25              // 25%
    }
    
    // MARK: - Metrics Storage
    
    private var latencyMeasurements: [TimeInterval] = []
    private let maxMeasurements = 1000
    
    // MARK: - Current Metrics
    
    @Published public private(set) var currentLatency: TimeInterval = 0
    @Published public private(set) var currentMemoryUsage: Int = 0
    @Published public private(set) var currentCPUUsage: Double = 0
    
    // MARK: - Initialization
    
    private init() {
        startMonitoring()
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        // Start periodic monitoring using Task-based scheduling
        Task {
            await startMonitoringLoop()
        }
    }
    
    private func startMonitoringLoop() async {
        while !Task.isCancelled {
            await updateMetrics()
            try? await Task.sleep(for: .seconds(1))
        }
    }
    
    private func updateMetrics() async {
        await updateMemoryUsage()
        await updateCPUUsage()
    }
    
    // MARK: - Latency Measurement
    
    public func measureTranscriptionLatency(operation: () async throws -> Void) async rethrows {
        let start = CACurrentMediaTime()
        
        try await operation()
        
        let latency = CACurrentMediaTime() - start
        recordLatency(latency)
    }
    
    public func recordLatency(_ latency: TimeInterval) {
        latencyMeasurements.append(latency)
        
        // Keep only recent measurements
        if latencyMeasurements.count > maxMeasurements {
            latencyMeasurements.removeFirst()
        }
        
        currentLatency = latency
        
        // Check against requirements
        if latency > LatencyRequirements.transcriptionP95 {
            os_log("Latency exceeds P95 target: %.2fms", log: performanceLog, type: .error, latency * 1000)
        }
    }
    
    // MARK: - Memory Monitoring
    
    private func updateMemoryUsage() async {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            let memoryUsage = Int(info.resident_size)
            currentMemoryUsage = memoryUsage
            
            if memoryUsage > MemoryRequirements.warningThreshold {
                os_log("Memory usage exceeds warning threshold: %d MB", log: performanceLog, type: .error, memoryUsage / 1_000_000)
            }
        }
    }
    
    // MARK: - CPU Monitoring
    
    private func updateCPUUsage() async {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if result == KERN_SUCCESS {
            // This is a simplified CPU calculation
            // In production, use host_processor_info for accurate measurements
            let cpuUsage = Double(info.user_time.microseconds + info.system_time.microseconds) / 1_000_000.0
            let normalizedUsage = min(cpuUsage, 1.0)
            
            currentCPUUsage = normalizedUsage
            
            if normalizedUsage > CPURequirements.peakUsage {
                os_log("CPU usage exceeds peak target: %.1f%%", log: performanceLog, type: .error, normalizedUsage * 100)
            }
        }
    }
    
    // MARK: - Latency Statistics
    
    public func latencyStatistics() -> LatencyMeasurement {
        guard !latencyMeasurements.isEmpty else {
            return LatencyMeasurement(p50: 0, p95: 0, p99: 0, average: 0, count: 0)
        }
        
        let sorted = latencyMeasurements.sorted()
        let count = sorted.count
        
        let p50 = sorted[Int(Double(count) * 0.5)]
        let p95 = sorted[Int(Double(count) * 0.95)]
        let p99 = sorted[Int(Double(count) * 0.99)]
        let average = sorted.reduce(0, +) / Double(count)
        
        return LatencyMeasurement(
            p50: p50,
            p95: p95,
            p99: p99,
            average: average,
            count: count
        )
    }
    
    // MARK: - Performance Report
    
    public func generatePerformanceReport() -> PerformanceReport {
        let latency = latencyStatistics()
        
        return PerformanceReport(
            timestamp: Date(),
            latency: latency,
            memoryUsage: currentMemoryUsage,
            cpuUsage: currentCPUUsage,
            meetsRequirements: checkRequirements(latency: latency)
        )
    }
    
    private func checkRequirements(latency: LatencyMeasurement) -> Bool {
        return latency.p50 <= LatencyRequirements.transcriptionP50 &&
               latency.p95 <= LatencyRequirements.transcriptionP95 &&
               latency.p99 <= LatencyRequirements.transcriptionP99 &&
               currentMemoryUsage <= MemoryRequirements.withModelsLoaded &&
               currentCPUUsage <= CPURequirements.peakUsage
    }
    
    // MARK: - Optimization Helpers
    
    public func profileOperation<T: Sendable>(_ name: String, operation: @Sendable () async throws -> T) async rethrows -> T {
        let start = CACurrentMediaTime()
        
        defer {
            let duration = CACurrentMediaTime() - start
            os_log(.debug, log: performanceLog, "%{public}s completed in %.2fms", name, duration * 1000)
        }
        
        return try await operation()
    }
}

// MARK: - Data Models

public struct LatencyMeasurement {
    public let p50: TimeInterval
    public let p95: TimeInterval
    public let p99: TimeInterval
    public let average: TimeInterval
    public let count: Int
}

public struct PerformanceReport {
    public let timestamp: Date
    public let latency: LatencyMeasurement
    public let memoryUsage: Int
    public let cpuUsage: Double
    public let meetsRequirements: Bool
    
    public var summary: String {
        """
        Performance Report - \(timestamp.formatted())
        
        Latency:
        - P50: \(String(format: "%.1f", latency.p50 * 1000))ms
        - P95: \(String(format: "%.1f", latency.p95 * 1000))ms  
        - P99: \(String(format: "%.1f", latency.p99 * 1000))ms
        
        Resources:
        - Memory: \(memoryUsage / 1_000_000)MB
        - CPU: \(String(format: "%.1f", cpuUsage * 100))%
        
        Status: \(meetsRequirements ? "✅ PASS" : "❌ FAIL")
        """
    }
}

// MARK: - Optimization Techniques

public enum OptimizationTechnique: CaseIterable {
    case metalAcceleration      // Use Metal for audio processing
    case speculativeDecoding    // Predict next words
    case keyValueCaching       // Cache attention computations
    case quantization          // INT8 quantization for models
    case lazyLoading          // Load features on demand
    case memoryMapping        // mmap for large files
    
    public var description: String {
        switch self {
        case .metalAcceleration:
            return "Metal GPU acceleration for audio processing"
        case .speculativeDecoding:
            return "Speculative decoding for reduced latency"
        case .keyValueCaching:
            return "KV-cache for transformer attention"
        case .quantization:
            return "Model quantization for reduced memory"
        case .lazyLoading:
            return "Lazy loading of optional features"
        case .memoryMapping:
            return "Memory-mapped file access"
        }
    }
    
    public var estimatedImprovement: String {
        switch self {
        case .metalAcceleration:
            return "30-50% faster audio processing"
        case .speculativeDecoding:
            return "20-40% latency reduction"
        case .keyValueCaching:
            return "15-25% compute reduction"
        case .quantization:
            return "50-75% memory reduction"
        case .lazyLoading:
            return "100-200MB initial memory saving"
        case .memoryMapping:
            return "90% memory reduction for large files"
        }
    }
}