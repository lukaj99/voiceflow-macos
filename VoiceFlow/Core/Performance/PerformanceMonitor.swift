import Foundation
import AVFoundation
import OSLog

/// Comprehensive performance monitoring system for VoiceFlow
/// Single Responsibility: Coordinate performance tracking and alert management
public actor PerformanceMonitor {

    // MARK: - Properties

    private let logger = Logger(subsystem: "com.voiceflow.app", category: "PerformanceMonitor")
    private let collector = MetricsCollector()
    private let reporter = PerformanceReporter()

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
    private let cpuThreshold: Double = 80.0
    private let memoryThreshold: Double = 500.0
    private let latencyThreshold: TimeInterval = 2.0

    // Buffer pool reference
    private weak var bufferPool: AudioBufferPool?

    // MARK: - Singleton Instance

    public static let shared = PerformanceMonitor()

    private init() {
        logger.info("📊 PerformanceMonitor initialized")
    }

    // MARK: - Public Interface

    /// Start performance monitoring with optional audio buffer pool tracking.
    ///
    /// Initiates continuous performance monitoring including CPU, memory, network latency,
    /// and audio buffer pool statistics. Collects metrics every 5 seconds for analysis.
    ///
    /// ## Usage Example
    /// ```swift
    /// let monitor = PerformanceMonitor.shared
    /// let bufferPool = AudioBufferPool.shared
    /// await monitor.startMonitoring(bufferPool: bufferPool)
    /// // Monitoring active, metrics collected every 5s
    /// ```
    ///
    /// ## Performance Characteristics
    /// - Time complexity: O(1) initialization
    /// - Memory usage: O(n) where n = maxHistorySize (1000 samples)
    /// - Thread-safe: Yes (actor isolated)
    ///
    /// - Parameter bufferPool: Optional audio buffer pool for pool statistics tracking
    /// - Note: Monitoring runs on a background timer until stopMonitoring() is called
    /// - SeeAlso: `stopMonitoring()`, `getCurrentMetrics()`
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

    /// Stop performance monitoring and cease metric collection.
    public func stopMonitoring() {
        guard isMonitoring else { return }

        isMonitoring = false
        logger.info("📊 Performance monitoring stopped")
    }

    /// Record a performance operation for throughput tracking.
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
        if latency > latencyThreshold / 2 {
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

    /// Get current performance metrics snapshot.
    public func getCurrentMetrics() async -> PerformanceMetrics {
        let currentTime = Date()
        let sessionDuration = currentTime.timeIntervalSince(sessionStartTime)
        let timeSinceLastMetrics = currentTime.timeIntervalSince(lastMetricsTime)
        let operationsPerSecond = timeSinceLastMetrics > 0 ? Double(operationCount) / timeSinceLastMetrics : 0.0

        return PerformanceMetrics(
            timestamp: currentTime,
            cpuUsage: await collector.getCPUUsage(),
            memoryUsageMB: await collector.getMemoryUsage(),
            diskUsageMB: await collector.getDiskUsage(),
            networkLatency: 0.0,
            audioBufferStats: await bufferPool?.getStatistics(),
            transcriptionLatency: 0.0,
            audioProcessingLatency: 0.0,
            sessionDuration: sessionDuration,
            errorCount: 0,
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

    /// Generate comprehensive performance profile with recommendations.
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

        let averageMetrics = await reporter.calculateAverageMetrics(
            from: metricsHistory,
            sessionStartTime: sessionStartTime,
            bufferPool: bufferPool
        )
        let peakMetrics = await reporter.calculatePeakMetrics(
            from: metricsHistory,
            sessionStartTime: sessionStartTime,
            bufferPool: bufferPool
        )
        let recommendations = await reporter.generateRecommendations(average: averageMetrics, peak: peakMetrics)
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

    /// Export performance data as JSON for external analysis.
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

    /// Check performance health across all monitored subsystems.
    public func checkPerformanceHealth() async -> PerformanceHealthStatus {
        return await reporter.analyzeHealth(from: metricsHistory)
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
}
