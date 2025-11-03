import Foundation
import OSLog

/// Performance analysis and reporting with recommendations
/// Single Responsibility: Metrics analysis and recommendation generation

actor PerformanceReporter {

    private let logger = Logger(subsystem: "com.voiceflow.app", category: "PerformanceReporter")

    // Performance thresholds
    private let cpuThreshold: Double = 80.0 // 80% CPU
    private let memoryThreshold: Double = 500.0 // 500MB
    private let latencyThreshold: TimeInterval = 2.0 // 2 seconds

    // MARK: - Metrics Analysis

    /// Calculate average metrics from history
    func calculateAverageMetrics(
        from history: [PerformanceMetrics],
        sessionStartTime: Date,
        bufferPool: AudioBufferPool?
    ) async -> PerformanceMetrics {
        guard !history.isEmpty else {
            return await createEmptyMetrics(sessionStartTime: sessionStartTime, bufferPool: bufferPool)
        }

        let count = Double(history.count)
        let avgCPU = history.map { $0.cpuUsage }.reduce(0, +) / count
        let avgMemory = history.map { $0.memoryUsageMB }.reduce(0, +) / count
        let avgLatency = history.map { $0.transcriptionLatency }.reduce(0, +) / count
        let avgAudioLatency = history.map { $0.audioProcessingLatency }.reduce(0, +) / count
        let avgOPS = history.map { $0.operationsPerSecond }.reduce(0, +) / count

        let collector = MetricsCollector()
        let diskUsage = await collector.getDiskUsage()

        return PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: avgCPU,
            memoryUsageMB: avgMemory,
            diskUsageMB: diskUsage,
            networkLatency: 0.0,
            audioBufferStats: await bufferPool?.getStatistics(),
            transcriptionLatency: avgLatency,
            audioProcessingLatency: avgAudioLatency,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            errorCount: 0,
            operationsPerSecond: avgOPS
        )
    }

    /// Calculate peak (maximum) metrics from history
    func calculatePeakMetrics(
        from history: [PerformanceMetrics],
        sessionStartTime: Date,
        bufferPool: AudioBufferPool?
    ) async -> PerformanceMetrics {
        guard !history.isEmpty else {
            return await createEmptyMetrics(sessionStartTime: sessionStartTime, bufferPool: bufferPool)
        }

        let maxCPU = history.map { $0.cpuUsage }.max() ?? 0
        let maxMemory = history.map { $0.memoryUsageMB }.max() ?? 0
        let maxLatency = history.map { $0.transcriptionLatency }.max() ?? 0
        let maxAudioLatency = history.map { $0.audioProcessingLatency }.max() ?? 0
        let maxOPS = history.map { $0.operationsPerSecond }.max() ?? 0

        let collector = MetricsCollector()
        let diskUsage = await collector.getDiskUsage()

        return PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: maxCPU,
            memoryUsageMB: maxMemory,
            diskUsageMB: diskUsage,
            networkLatency: 0.0,
            audioBufferStats: await bufferPool?.getStatistics(),
            transcriptionLatency: maxLatency,
            audioProcessingLatency: maxAudioLatency,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            errorCount: 0,
            operationsPerSecond: maxOPS
        )
    }

    // MARK: - Recommendations

    /// Generate performance recommendations based on metrics
    func generateRecommendations(average: PerformanceMetrics, peak: PerformanceMetrics) -> [String] {
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

    // MARK: - Health Analysis

    /// Determine health status based on value and threshold
    func getHealthStatus(value: Double, threshold: Double) -> PerformanceHealthStatus.HealthLevel {
        if value > threshold {
            return .critical
        } else if value > threshold * 0.7 {
            return .warning
        } else {
            return .good
        }
    }

    /// Generate health-specific recommendations
    func generateHealthRecommendations(
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

    /// Analyze recent metrics for health status
    func analyzeHealth(
        from history: [PerformanceMetrics]
    ) -> PerformanceHealthStatus {
        guard !history.isEmpty else {
            return PerformanceHealthStatus(
                overall: .unknown,
                cpu: .unknown,
                memory: .unknown,
                latency: .unknown,
                bufferPool: .unknown,
                recommendations: ["Insufficient data for health assessment"]
            )
        }

        let recent = Array(history.suffix(10))
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

    // MARK: - Helper Methods

    private func createEmptyMetrics(sessionStartTime: Date, bufferPool: AudioBufferPool?) async -> PerformanceMetrics {
        let collector = MetricsCollector()
        return PerformanceMetrics(
            timestamp: Date(),
            cpuUsage: await collector.getCPUUsage(),
            memoryUsageMB: await collector.getMemoryUsage(),
            diskUsageMB: await collector.getDiskUsage(),
            networkLatency: 0.0,
            audioBufferStats: await bufferPool?.getStatistics(),
            transcriptionLatency: 0.0,
            audioProcessingLatency: 0.0,
            sessionDuration: Date().timeIntervalSince(sessionStartTime),
            errorCount: 0,
            operationsPerSecond: 0.0
        )
    }
}
