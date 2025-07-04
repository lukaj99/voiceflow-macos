import Foundation
import AVFoundation
import OSLog

/// Comprehensive performance monitoring system for VoiceFlow
/// Single Responsibility: Application performance tracking and analytics
public actor PerformanceMonitor {
    
    // MARK: - Types
    
    public struct PerformanceMetrics: Sendable, Codable {
        public let timestamp: Date
        public let cpuUsage: Double
        public let memoryUsageMB: Double
        public let diskUsageMB: Double
        public let networkLatency: TimeInterval
        public let audioBufferStats: AudioBufferPool.PoolStatistics?
        public let transcriptionLatency: TimeInterval
        public let audioProcessingLatency: TimeInterval
        public let sessionDuration: TimeInterval
        public let errorCount: Int
        public let operationsPerSecond: Double
        
        public init(
            timestamp: Date,
            cpuUsage: Double,
            memoryUsageMB: Double,
            diskUsageMB: Double,
            networkLatency: TimeInterval,
            audioBufferStats: AudioBufferPool.PoolStatistics?,
            transcriptionLatency: TimeInterval,
            audioProcessingLatency: TimeInterval,
            sessionDuration: TimeInterval,
            errorCount: Int,
            operationsPerSecond: Double
        ) {
            self.timestamp = timestamp
            self.cpuUsage = cpuUsage
            self.memoryUsageMB = memoryUsageMB
            self.diskUsageMB = diskUsageMB
            self.networkLatency = networkLatency
            self.audioBufferStats = audioBufferStats
            self.transcriptionLatency = transcriptionLatency
            self.audioProcessingLatency = audioProcessingLatency
            self.sessionDuration = sessionDuration
            self.errorCount = errorCount
            self.operationsPerSecond = operationsPerSecond
        }
    }
    
    public struct PerformanceAlert: Sendable, Identifiable {
        public let id = UUID()
        public let type: AlertType
        public let message: String
        public let severity: AlertSeverity
        public let timestamp: Date
        public let metrics: PerformanceMetrics
        
        public enum AlertType: String, CaseIterable, Codable, Sendable {
            case highCPUUsage = "High CPU Usage"
            case highMemoryUsage = "High Memory Usage"
            case highLatency = "High Latency"
            case bufferPoolInefficiency = "Buffer Pool Inefficiency"
            case frequentErrors = "Frequent Errors"
            case performanceDegradation = "Performance Degradation"
        }
        
        public enum AlertSeverity: String, CaseIterable, Codable, Sendable {
            case info = "Info"
            case warning = "Warning"
            case critical = "Critical"
            
            public var color: String {
                switch self {
                case .info: return "blue"
                case .warning: return "orange"
                case .critical: return "red"
                }
            }
        }
    }
    
    public struct PerformanceProfile: Sendable, Codable {
        public let profileName: String
        public let averageMetrics: PerformanceMetrics
        public let peakMetrics: PerformanceMetrics
        public let samplesCount: Int
        public let profileDuration: TimeInterval
        public let recommendations: [String]
        
        public init(
            profileName: String,
            averageMetrics: PerformanceMetrics,
            peakMetrics: PerformanceMetrics,
            samplesCount: Int,
            profileDuration: TimeInterval,
            recommendations: [String]
        ) {
            self.profileName = profileName
            self.averageMetrics = averageMetrics
            self.peakMetrics = peakMetrics
            self.samplesCount = samplesCount
            self.profileDuration = profileDuration
            self.recommendations = recommendations
        }
    }
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voiceflow.app", category: "PerformanceMonitor")
    private var metricsHistory: [PerformanceMetrics] = []
    private var performanceAlerts: [PerformanceAlert] = []
    private let maxHistorySize = 1000
    private let maxAlertsSize = 100
    
    // Session tracking
    private var sessionStartTime = Date()
    private var operationCount = 0
    private var lastMetricsTime = Date()
    private var isMonitoring = false
    
    // Performance thresholds
    private let cpuThreshold: Double = 80.0 // 80% CPU
    private let memoryThreshold: Double = 500.0 // 500MB
    private let latencyThreshold: TimeInterval = 2.0 // 2 seconds
    private let errorRateThreshold: Double = 10.0 // 10 errors per hour
    
    // Buffer pool reference
    private weak var bufferPool: AudioBufferPool?
    
    // MARK: - Singleton Instance
    
    public static let shared = PerformanceMonitor()
    
    private init() {
        logger.info("📊 PerformanceMonitor initialized")
    }
    
    // MARK: - Public Interface
    
    /// Start performance monitoring
    public func startMonitoring(bufferPool: AudioBufferPool? = nil) {
        guard !isMonitoring else { return }
        
        self.bufferPool = bufferPool
        isMonitoring = true
        sessionStartTime = Date()
        operationCount = 0
        lastMetricsTime = Date()
        
        logger.info("📊 Performance monitoring started")
        
        // Start periodic metrics collection
        Task {
            await schedulePeriodicMetricsCollection()
        }
    }
    
    /// Stop performance monitoring
    public func stopMonitoring() {
        guard isMonitoring else { return }
        
        isMonitoring = false
        logger.info("📊 Performance monitoring stopped")
    }
    
    /// Record a performance operation
    public func recordOperation() {
        operationCount += 1
    }
    
    /// Record transcription latency
    public func recordTranscriptionLatency(_ latency: TimeInterval) {
        if latency > latencyThreshold {
            Task {
                let metrics = await getCurrentMetrics()
                let alert = PerformanceAlert(
                    type: .highLatency,
                    message: "Transcription latency is high: \(String(format: "%.2f", latency))s",
                    severity: .warning,
                    timestamp: Date(),
                    metrics: metrics
                )
                recordAlert(alert)
            }
        }
    }
    
    /// Record audio processing latency
    public func recordAudioProcessingLatency(_ latency: TimeInterval) {
        if latency > latencyThreshold / 2 { // Audio should be faster than transcription
            Task {
                let metrics = await getCurrentMetrics()
                let alert = PerformanceAlert(
                    type: .highLatency,
                    message: "Audio processing latency is high: \(String(format: "%.2f", latency))s",
                    severity: .warning,
                    timestamp: Date(),
                    metrics: metrics
                )
                recordAlert(alert)
            }
        }
    }
    
    /// Get current performance metrics
    public func getCurrentMetrics() async -> PerformanceMetrics {
        let currentTime = Date()
        let sessionDuration = currentTime.timeIntervalSince(sessionStartTime)
        let timeSinceLastMetrics = currentTime.timeIntervalSince(lastMetricsTime)
        let operationsPerSecond = timeSinceLastMetrics > 0 ? Double(operationCount) / timeSinceLastMetrics : 0.0
        
        return PerformanceMetrics(
            timestamp: currentTime,
            cpuUsage: getCPUUsage(),
            memoryUsageMB: getMemoryUsage(),
            diskUsageMB: getDiskUsage(),
            networkLatency: 0.0, // Would be measured during actual network calls
            audioBufferStats: await bufferPool?.getStatistics(),
            transcriptionLatency: 0.0, // Would be measured during actual transcription
            audioProcessingLatency: 0.0, // Would be measured during actual audio processing
            sessionDuration: sessionDuration,
            errorCount: 0, // Would be fetched from ErrorReporter
            operationsPerSecond: operationsPerSecond
        )
    }
    
    /// Get performance history
    public func getPerformanceHistory(limit: Int = 100) -> [PerformanceMetrics] {
        return Array(metricsHistory.suffix(limit))
    }
    
    /// Get performance alerts
    public func getPerformanceAlerts(limit: Int = 50) -> [PerformanceAlert] {
        return Array(performanceAlerts.suffix(limit))
    }
    
    /// Generate performance profile
    public func generatePerformanceProfile(name: String = "Current Session") async -> PerformanceProfile {
        guard !metricsHistory.isEmpty else {
            let emptyMetrics = await getCurrentMetrics()
            return PerformanceProfile(
                profileName: name,
                averageMetrics: emptyMetrics,
                peakMetrics: emptyMetrics,
                samplesCount: 0,
                profileDuration: 0,
                recommendations: ["No data available for analysis"]
            )
        }
        
        let averageMetrics = await calculateAverageMetrics()
        let peakMetrics = await calculatePeakMetrics()
        let recommendations = generateRecommendations(average: averageMetrics, peak: peakMetrics)
        let profileDuration = Date().timeIntervalSince(sessionStartTime)
        
        return PerformanceProfile(
            profileName: name,
            averageMetrics: averageMetrics,
            peakMetrics: peakMetrics,
            samplesCount: metricsHistory.count,
            profileDuration: profileDuration,
            recommendations: recommendations
        )
    }
    
    /// Export performance data
    public func exportPerformanceData() async -> Data? {
        let profile = await generatePerformanceProfile(name: "Export - \(Date().formatted())")
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(profile)
        } catch {
            logger.error("📊 Failed to export performance data: \(error.localizedDescription)")
            return nil
        }
    }
    
    /// Clear performance history
    public func clearHistory() {
        metricsHistory.removeAll()
        performanceAlerts.removeAll()
        logger.info("📊 Performance history cleared")
    }
    
    /// Check performance health
    public func checkPerformanceHealth() -> PerformanceHealthStatus {
        guard !metricsHistory.isEmpty else {
            return PerformanceHealthStatus(
                overall: .unknown,
                cpu: .unknown,
                memory: .unknown,
                latency: .unknown,
                bufferPool: .unknown,
                recommendations: ["Insufficient data for health assessment"]
            )
        }
        
        let recent = Array(metricsHistory.suffix(10))
        let avgCPU = recent.map { $0.cpuUsage }.reduce(0, +) / Double(recent.count)
        let avgMemory = recent.map { $0.memoryUsageMB }.reduce(0, +) / Double(recent.count)
        let avgLatency = recent.map { $0.transcriptionLatency }.reduce(0, +) / Double(recent.count)
        
        let cpuHealth = getHealthStatus(value: avgCPU, threshold: cpuThreshold)
        let memoryHealth = getHealthStatus(value: avgMemory, threshold: memoryThreshold)
        let latencyHealth = getHealthStatus(value: avgLatency, threshold: latencyThreshold)
        
        // Buffer pool health
        let bufferPoolHealth: PerformanceHealthStatus.HealthLevel
        if let bufferStats = recent.compactMap({ $0.audioBufferStats }).last {
            bufferPoolHealth = bufferStats.poolHitRate > 0.8 ? .good : (bufferStats.poolHitRate > 0.5 ? .warning : .critical)
        } else {
            bufferPoolHealth = .unknown
        }
        
        // Overall health
        let healthLevels = [cpuHealth, memoryHealth, latencyHealth, bufferPoolHealth]
        let overall: PerformanceHealthStatus.HealthLevel
        if healthLevels.contains(.critical) {
            overall = .critical
        } else if healthLevels.contains(.warning) {
            overall = .warning
        } else if healthLevels.allSatisfy({ $0 == .good }) {
            overall = .good
        } else {
            overall = .unknown
        }
        
        return PerformanceHealthStatus(
            overall: overall,
            cpu: cpuHealth,
            memory: memoryHealth,
            latency: latencyHealth,
            bufferPool: bufferPoolHealth,
            recommendations: generateHealthRecommendations(
                cpu: cpuHealth,
                memory: memoryHealth,
                latency: latencyHealth,
                bufferPool: bufferPoolHealth
            )
        )
    }
    
    // MARK: - Private Methods
    
    private func schedulePeriodicMetricsCollection() async {
        while isMonitoring {
            let metrics = await getCurrentMetrics()
            recordMetrics(metrics)
            
            // Check for performance issues
            await checkForPerformanceIssues(metrics)
            
            // Wait 5 seconds before next collection
            try? await Task.sleep(nanoseconds: 5_000_000_000)
        }
    }
    
    private func recordMetrics(_ metrics: PerformanceMetrics) {
        metricsHistory.append(metrics)
        
        // Trim history if needed
        if metricsHistory.count > maxHistorySize {
            metricsHistory.removeFirst(metricsHistory.count - maxHistorySize)
        }
        
        lastMetricsTime = metrics.timestamp
    }
    
    private func recordAlert(_ alert: PerformanceAlert) {
        performanceAlerts.append(alert)
        
        // Trim alerts if needed
        if performanceAlerts.count > maxAlertsSize {
            performanceAlerts.removeFirst(performanceAlerts.count - maxAlertsSize)
        }
        
        logger.warning("📊 Performance alert: \(alert.type.rawValue) - \(alert.message)")
    }
    
    private func checkForPerformanceIssues(_ metrics: PerformanceMetrics) async {
        // Check CPU usage
        if metrics.cpuUsage > cpuThreshold {
            let alert = PerformanceAlert(
                type: .highCPUUsage,
                message: "CPU usage is high: \(String(format: "%.1f", metrics.cpuUsage))%",
                severity: metrics.cpuUsage > 90 ? .critical : .warning,
                timestamp: Date(),
                metrics: metrics
            )
            recordAlert(alert)
        }
        
        // Check memory usage
        if metrics.memoryUsageMB > memoryThreshold {
            let alert = PerformanceAlert(
                type: .highMemoryUsage,
                message: "Memory usage is high: \(String(format: "%.1f", metrics.memoryUsageMB))MB",
                severity: metrics.memoryUsageMB > 1000 ? .critical : .warning,
                timestamp: Date(),
                metrics: metrics
            )
            recordAlert(alert)
        }
        
        // Check buffer pool efficiency
        if let bufferStats = metrics.audioBufferStats {
            if bufferStats.poolHitRate < 0.5 {
                let alert = PerformanceAlert(
                    type: .bufferPoolInefficiency,
                    message: "Buffer pool hit rate is low: \(String(format: "%.1f", bufferStats.poolHitRate * 100))%",
                    severity: .warning,
                    timestamp: Date(),
                    metrics: metrics
                )
                recordAlert(alert)
            }
        }
    }
    
    private func getCPUUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB for consistent units
        }
        
        return 0.0
    }
    
    private func getMemoryUsage() -> Double {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_, task_flavor_t(MACH_TASK_BASIC_INFO), $0, &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Double(info.resident_size) / 1024.0 / 1024.0 // Convert to MB
        }
        
        return 0.0
    }
    
    private func getDiskUsage() -> Double {
        // Get available disk space
        do {
            let fileURL = URL(fileURLWithPath: NSHomeDirectory())
            let values = try fileURL.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
            if let capacity = values.volumeAvailableCapacityForImportantUsage {
                return Double(capacity) / 1024.0 / 1024.0 // Convert to MB
            }
        } catch {
            logger.error("📊 Failed to get disk usage: \(error.localizedDescription)")
        }
        
        return 0.0
    }
    
    private func calculateAverageMetrics() async -> PerformanceMetrics {
        guard !metricsHistory.isEmpty else {
            return await getCurrentMetrics()
        }
        
        let count = Double(metricsHistory.count)
        let avgCPU = metricsHistory.map { $0.cpuUsage }.reduce(0, +) / count
        let avgMemory = metricsHistory.map { $0.memoryUsageMB }.reduce(0, +) / count
        let avgLatency = metricsHistory.map { $0.transcriptionLatency }.reduce(0, +) / count
        let avgAudioLatency = metricsHistory.map { $0.audioProcessingLatency }.reduce(0, +) / count
        let avgOPS = metricsHistory.map { $0.operationsPerSecond }.reduce(0, +) / count
        
        return PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: avgCPU,
            memoryUsageMB: avgMemory,
            diskUsageMB: getDiskUsage(),
            networkLatency: 0.0,
            audioBufferStats: await bufferPool?.getStatistics(),
            transcriptionLatency: avgLatency,
            audioProcessingLatency: avgAudioLatency,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            errorCount: 0,
            operationsPerSecond: avgOPS
        )
    }
    
    private func calculatePeakMetrics() async -> PerformanceMetrics {
        guard !metricsHistory.isEmpty else {
            return await getCurrentMetrics()
        }
        
        let maxCPU = metricsHistory.map { $0.cpuUsage }.max() ?? 0
        let maxMemory = metricsHistory.map { $0.memoryUsageMB }.max() ?? 0
        let maxLatency = metricsHistory.map { $0.transcriptionLatency }.max() ?? 0
        let maxAudioLatency = metricsHistory.map { $0.audioProcessingLatency }.max() ?? 0
        let maxOPS = metricsHistory.map { $0.operationsPerSecond }.max() ?? 0
        
        return PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: maxCPU,
            memoryUsageMB: maxMemory,
            diskUsageMB: getDiskUsage(),
            networkLatency: 0.0,
            audioBufferStats: await bufferPool?.getStatistics(),
            transcriptionLatency: maxLatency,
            audioProcessingLatency: maxAudioLatency,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            errorCount: 0,
            operationsPerSecond: maxOPS
        )
    }
    
    private func generateRecommendations(average: PerformanceMetrics, peak: PerformanceMetrics) -> [String] {
        var recommendations: [String] = []
        
        if average.cpuUsage > 50 {
            recommendations.append("Consider optimizing CPU-intensive operations")
        }
        
        if average.memoryUsageMB > 300 {
            recommendations.append("Monitor memory usage and consider optimization")
        }
        
        if average.transcriptionLatency > 1.0 {
            recommendations.append("Network latency is affecting transcription performance")
        }
        
        if let bufferStats = average.audioBufferStats {
            if bufferStats.poolHitRate < 0.8 {
                recommendations.append("Audio buffer pool could be optimized for better performance")
            }
            
            if bufferStats.memoryUsageMB > 50 {
                recommendations.append("Consider reducing buffer pool size to save memory")
            }
        }
        
        if average.operationsPerSecond > 100 {
            recommendations.append("High operation rate detected - consider batching operations")
        }
        
        if recommendations.isEmpty {
            recommendations.append("Performance is within acceptable ranges")
        }
        
        return recommendations
    }
    
    private func getHealthStatus(value: Double, threshold: Double) -> PerformanceHealthStatus.HealthLevel {
        if value > threshold {
            return .critical
        } else if value > threshold * 0.7 {
            return .warning
        } else {
            return .good
        }
    }
    
    private func generateHealthRecommendations(
        cpu: PerformanceHealthStatus.HealthLevel,
        memory: PerformanceHealthStatus.HealthLevel,
        latency: PerformanceHealthStatus.HealthLevel,
        bufferPool: PerformanceHealthStatus.HealthLevel
    ) -> [String] {
        var recommendations: [String] = []
        
        if cpu == .critical {
            recommendations.append("High CPU usage detected - consider closing other applications")
        }
        
        if memory == .critical {
            recommendations.append("High memory usage detected - restart the app or reduce session length")
        }
        
        if latency == .critical {
            recommendations.append("High latency detected - check network connection")
        }
        
        if bufferPool == .critical {
            recommendations.append("Buffer pool performance is poor - consider optimizing audio settings")
        }
        
        if recommendations.isEmpty {
            recommendations.append("System performance is healthy")
        }
        
        return recommendations
    }
}

// MARK: - Supporting Types

public struct PerformanceHealthStatus: Sendable {
    public enum HealthLevel: String, CaseIterable, Codable, Sendable {
        case good = "Good"
        case warning = "Warning"
        case critical = "Critical"
        case unknown = "Unknown"
        
        public var color: String {
            switch self {
            case .good: return "green"
            case .warning: return "orange"
            case .critical: return "red"
            case .unknown: return "gray"
            }
        }
    }
    
    public let overall: HealthLevel
    public let cpu: HealthLevel
    public let memory: HealthLevel
    public let latency: HealthLevel
    public let bufferPool: HealthLevel
    public let recommendations: [String]
    
    public init(
        overall: HealthLevel,
        cpu: HealthLevel,
        memory: HealthLevel,
        latency: HealthLevel,
        bufferPool: HealthLevel,
        recommendations: [String]
    ) {
        self.overall = overall
        self.cpu = cpu
        self.memory = memory
        self.latency = latency
        self.bufferPool = bufferPool
        self.recommendations = recommendations
    }
}

// MARK: - Codable Extensions

extension AudioBufferPool.PoolStatistics: Codable {
    enum CodingKeys: String, CodingKey {
        case totalBuffers, availableBuffers, allocatedBuffers, poolHitRate, memoryUsageMB, peakMemoryUsageMB
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalBuffers, forKey: .totalBuffers)
        try container.encode(availableBuffers, forKey: .availableBuffers)
        try container.encode(allocatedBuffers, forKey: .allocatedBuffers)
        try container.encode(poolHitRate, forKey: .poolHitRate)
        try container.encode(memoryUsageMB, forKey: .memoryUsageMB)
        try container.encode(peakMemoryUsageMB, forKey: .peakMemoryUsageMB)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.totalBuffers = try container.decode(Int.self, forKey: .totalBuffers)
        self.availableBuffers = try container.decode(Int.self, forKey: .availableBuffers)
        self.allocatedBuffers = try container.decode(Int.self, forKey: .allocatedBuffers)
        self.poolHitRate = try container.decode(Double.self, forKey: .poolHitRate)
        self.memoryUsageMB = try container.decode(Double.self, forKey: .memoryUsageMB)
        self.peakMemoryUsageMB = try container.decode(Double.self, forKey: .peakMemoryUsageMB)
    }
}