import Foundation
import Combine

/// Comprehensive performance monitoring dashboard for tracking all optimizations
/// Provides real-time metrics and automated performance tuning recommendations
@MainActor
public final class PerformanceMonitor: ObservableObject {
    
    // MARK: - Published Properties
    
    @Published public private(set) var audioMetrics = AudioPerformanceMetrics()
    @Published public private(set) var processingMetrics = ProcessingPerformanceMetrics()
    @Published public private(set) var exportMetrics = ExportPerformanceMetrics()
    @Published public private(set) var memoryMetrics = MemoryPerformanceMetrics()
    @Published public private(set) var overallScore: Double = 0
    @Published public private(set) var recommendations: [PerformanceRecommendation] = []
    
    // MARK: - Types
    
    public struct AudioPerformanceMetrics: Codable {
        public var bufferLatency: TimeInterval = 0
        public var poolHitRate: Double = 0
        public var taskCreationCount: Int = 0
        public var targetLatencyMet: Bool = false
        
        public var score: Double {
            let latencyScore = targetLatencyMet ? 1.0 : max(0, 1.0 - (bufferLatency / 0.1))
            let poolScore = poolHitRate
            let efficiencyScore = taskCreationCount < 100 ? 1.0 : max(0, 1.0 - Double(taskCreationCount - 100) / 1000)
            
            return (latencyScore * 0.4) + (poolScore * 0.3) + (efficiencyScore * 0.3)
        }
    }
    
    public struct ProcessingPerformanceMetrics: Codable {
        public var averageLatency: TimeInterval = 0
        public var throughputPerSecond: Double = 0
        public var qualityScore: Double = 0
        public var asyncEfficiency: Double = 0
        
        public var score: Double {
            let latencyScore = averageLatency < 0.05 ? 1.0 : max(0, 1.0 - (averageLatency / 0.2))
            let throughputScore = min(1.0, throughputPerSecond / 100.0)
            let qualityScore = self.qualityScore
            let asyncScore = asyncEfficiency
            
            return (latencyScore * 0.25) + (throughputScore * 0.25) + (qualityScore * 0.25) + (asyncScore * 0.25)
        }
    }
    
    public struct ExportPerformanceMetrics: Codable {
        public var parallelizationRatio: Double = 0
        public var averageExportTime: TimeInterval = 0
        public var throughputImprovement: Double = 0
        public var concurrentJobsCount: Int = 0
        
        public var score: Double {
            let parallelScore = min(1.0, parallelizationRatio / 4.0)
            let speedScore = averageExportTime < 5.0 ? 1.0 : max(0, 1.0 - (averageExportTime - 5.0) / 10.0)
            let improvementScore = min(1.0, throughputImprovement)
            
            return (parallelScore * 0.4) + (speedScore * 0.3) + (improvementScore * 0.3)
        }
    }
    
    public struct MemoryPerformanceMetrics: Codable {
        public var currentUsage: Int64 = 0
        public var peakUsage: Int64 = 0
        public var allocationEfficiency: Double = 0
        public var cacheHitRate: Double = 0
        
        public var score: Double {
            let usageScore = currentUsage < 500_000_000 ? 1.0 : max(0, 1.0 - Double(currentUsage - 500_000_000) / 1_000_000_000)
            let allocationScore = allocationEfficiency
            let cacheScore = cacheHitRate
            
            return (usageScore * 0.4) + (allocationScore * 0.3) + (cacheScore * 0.3)
        }
    }
    
    public struct PerformanceRecommendation: Identifiable, Codable {
        public let id = UUID()
        public let category: Category
        public let severity: Severity
        public let title: String
        public let description: String
        public let action: String
        
        public enum Category: String, CaseIterable, Codable {
            case audio = "Audio Processing"
            case async = "Async Operations"
            case export = "Export Performance"
            case memory = "Memory Usage"
            case ui = "UI Responsiveness"
        }
        
        public enum Severity: String, CaseIterable, Codable {
            case low = "Low"
            case medium = "Medium"
            case high = "High"
            case critical = "Critical"
            
            public var color: String {
                switch self {
                case .low: return "green"
                case .medium: return "yellow"
                case .high: return "orange"
                case .critical: return "red"
                }
            }
        }
    }
    
    // MARK: - Properties
    
    private var monitoringTimer: Timer?
    private let updateInterval: TimeInterval = 2.0
    
    // Performance targets
    private let targetAudioLatency: TimeInterval = 0.050
    private let targetProcessingThroughput: Double = 100.0
    private let targetMemoryUsage: Int64 = 500_000_000
    private let targetParallelization: Double = 3.0
    
    // Component references
    private weak var audioBufferPool: AudioBufferPool?
    private weak var asyncProcessor: OptimizedAsyncTranscriptionProcessor?
    private weak var exportEngine: ParallelExportEngine?
    private let memoryOptimizer = MemoryOptimizer.shared
    
    // MARK: - Initialization
    
    public init() {
        startMonitoring()
    }
    
    deinit {
        stopMonitoring()
    }
    
    // MARK: - Component Registration
    
    public func registerComponents(
        audioBufferPool: AudioBufferPool?,
        asyncProcessor: OptimizedAsyncTranscriptionProcessor?,
        exportEngine: ParallelExportEngine?
    ) {
        self.audioBufferPool = audioBufferPool
        self.asyncProcessor = asyncProcessor
        self.exportEngine = exportEngine
    }
    
    // MARK: - Monitoring Control
    
    public func startMonitoring() {
        stopMonitoring()
        
        monitoringTimer = Timer.scheduledTimer(withTimeInterval: updateInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                await self?.updateMetrics()
            }
        }
    }
    
    public func stopMonitoring() {
        monitoringTimer?.invalidate()
        monitoringTimer = nil
    }
    
    // MARK: - Metrics Update
    
    private func updateMetrics() async {
        await updateAudioMetrics()
        await updateProcessingMetrics()
        await updateExportMetrics()
        await updateMemoryMetrics()
        
        calculateOverallScore()
        generateRecommendations()
    }
    
    private func updateAudioMetrics() async {
        guard let audioBufferPool = audioBufferPool else { return }
        
        let poolMetrics = audioBufferPool.getMetrics()
        
        audioMetrics = AudioPerformanceMetrics(
            bufferLatency: 0.064, // Current 64ms buffer size
            poolHitRate: poolMetrics.hitRate,
            taskCreationCount: poolMetrics.borrowCount,
            targetLatencyMet: 0.064 < targetAudioLatency
        )
    }
    
    private func updateProcessingMetrics() async {
        guard let asyncProcessor = asyncProcessor else { return }
        
        let (rate, _, _, latency) = asyncProcessor.getProcessingMetrics()
        let qualityMetrics = asyncProcessor.getQualityMetrics()
        
        processingMetrics = ProcessingPerformanceMetrics(
            averageLatency: latency,
            throughputPerSecond: rate,
            qualityScore: qualityMetrics.qualityScore,
            asyncEfficiency: calculateAsyncEfficiency(throughput: rate)
        )
    }
    
    private func updateExportMetrics() async {
        guard let exportEngine = exportEngine else { return }
        
        let performanceMetrics = exportEngine.getPerformanceMetrics()
        
        exportMetrics = ExportPerformanceMetrics(
            parallelizationRatio: performanceMetrics.parallelEfficiency,
            averageExportTime: performanceMetrics.averageExportTime,
            throughputImprovement: performanceMetrics.throughputImprovement,
            concurrentJobsCount: performanceMetrics.activeConcurrentJobs
        )
    }
    
    private func updateMemoryMetrics() async {
        let memoryMetrics = memoryOptimizer.getCurrentMemoryMetrics()
        
        self.memoryMetrics = MemoryPerformanceMetrics(
            currentUsage: memoryMetrics.currentUsage,
            peakUsage: memoryMetrics.peakUsage,
            allocationEfficiency: memoryMetrics.efficiency,
            cacheHitRate: (memoryMetrics.stringBuilderPoolHitRate + memoryMetrics.regexCacheHitRate) / 2.0
        )
    }
    
    // MARK: - Score Calculation
    
    private func calculateOverallScore() {
        let audioScore = audioMetrics.score
        let processingScore = processingMetrics.score
        let exportScore = exportMetrics.score
        let memoryScore = memoryMetrics.score
        
        // Weighted average based on impact
        overallScore = (audioScore * 0.3) + (processingScore * 0.3) + (exportScore * 0.2) + (memoryScore * 0.2)
    }
    
    private func calculateAsyncEfficiency(throughput: Double) -> Double {
        // Calculate efficiency based on throughput vs theoretical maximum
        return min(1.0, throughput / targetProcessingThroughput)
    }
    
    // MARK: - Recommendations Generation
    
    private func generateRecommendations() {
        var newRecommendations: [PerformanceRecommendation] = []
        
        // Audio recommendations
        if audioMetrics.bufferLatency > targetAudioLatency {
            newRecommendations.append(PerformanceRecommendation(
                category: .audio,
                severity: .high,
                title: "Audio Buffer Latency High",
                description: "Current latency (\(Int(audioMetrics.bufferLatency * 1000))ms) exceeds target (\(Int(targetAudioLatency * 1000))ms)",
                action: "Reduce buffer size or implement buffer pooling"
            ))
        }
        
        if audioMetrics.poolHitRate < 0.8 {
            newRecommendations.append(PerformanceRecommendation(
                category: .audio,
                severity: .medium,
                title: "Buffer Pool Hit Rate Low",
                description: "Pool hit rate (\(Int(audioMetrics.poolHitRate * 100))%) is below optimal threshold",
                action: "Increase buffer pool size or adjust buffer lifecycle"
            ))
        }
        
        // Processing recommendations
        if processingMetrics.throughputPerSecond < targetProcessingThroughput {
            newRecommendations.append(PerformanceRecommendation(
                category: .async,
                severity: .medium,
                title: "Processing Throughput Below Target",
                description: "Current throughput (\(Int(processingMetrics.throughputPerSecond))) below target (\(Int(targetProcessingThroughput)))",
                action: "Optimize async processing pipeline or increase concurrency"
            ))
        }
        
        if processingMetrics.averageLatency > 0.1 {
            newRecommendations.append(PerformanceRecommendation(
                category: .async,
                severity: .high,
                title: "Processing Latency High",
                description: "Average latency (\(Int(processingMetrics.averageLatency * 1000))ms) impacts user experience",
                action: "Eliminate polling patterns and optimize async operations"
            ))
        }
        
        // Export recommendations
        if exportMetrics.parallelizationRatio < targetParallelization {
            newRecommendations.append(PerformanceRecommendation(
                category: .export,
                severity: .medium,
                title: "Export Parallelization Underutilized",
                description: "Parallelization ratio (\(String(format: "%.1f", exportMetrics.parallelizationRatio))) below target",
                action: "Increase concurrent export jobs or optimize job scheduling"
            ))
        }
        
        // Memory recommendations
        if memoryMetrics.currentUsage > targetMemoryUsage {
            newRecommendations.append(PerformanceRecommendation(
                category: .memory,
                severity: memoryMetrics.currentUsage > targetMemoryUsage * 2 ? .critical : .high,
                title: "High Memory Usage",
                description: "Current usage (\(ByteCountFormatter.string(fromByteCount: memoryMetrics.currentUsage, countStyle: .memory))) exceeds target",
                action: "Optimize string concatenation and implement memory pooling"
            ))
        }
        
        if memoryMetrics.cacheHitRate < 0.8 {
            newRecommendations.append(PerformanceRecommendation(
                category: .memory,
                severity: .medium,
                title: "Cache Hit Rate Low",
                description: "Cache hit rate (\(Int(memoryMetrics.cacheHitRate * 100))%) indicates inefficient caching",
                action: "Optimize cache size or improve cache key strategies"
            ))
        }
        
        recommendations = newRecommendations
    }
    
    // MARK: - Performance Reports
    
    public func generatePerformanceReport() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        
        return """
        VoiceFlow Performance Report
        Generated: \(formatter.string(from: Date()))
        
        OVERALL SCORE: \(String(format: "%.1f", overallScore * 100))%
        
        AUDIO PROCESSING:
        - Latency: \(String(format: "%.1f", audioMetrics.bufferLatency * 1000))ms (Target: \(String(format: "%.1f", targetAudioLatency * 1000))ms)
        - Buffer Pool Hit Rate: \(String(format: "%.1f", audioMetrics.poolHitRate * 100))%
        - Score: \(String(format: "%.1f", audioMetrics.score * 100))%
        
        ASYNC PROCESSING:
        - Throughput: \(String(format: "%.1f", processingMetrics.throughputPerSecond))/sec
        - Average Latency: \(String(format: "%.1f", processingMetrics.averageLatency * 1000))ms
        - Quality Score: \(String(format: "%.1f", processingMetrics.qualityScore * 100))%
        - Score: \(String(format: "%.1f", processingMetrics.score * 100))%
        
        EXPORT PERFORMANCE:
        - Parallelization Ratio: \(String(format: "%.1f", exportMetrics.parallelizationRatio))x
        - Average Export Time: \(String(format: "%.1f", exportMetrics.averageExportTime))s
        - Throughput Improvement: \(String(format: "%.1f", exportMetrics.throughputImprovement * 100))%
        - Score: \(String(format: "%.1f", exportMetrics.score * 100))%
        
        MEMORY USAGE:
        - Current: \(ByteCountFormatter.string(fromByteCount: memoryMetrics.currentUsage, countStyle: .memory))
        - Peak: \(ByteCountFormatter.string(fromByteCount: memoryMetrics.peakUsage, countStyle: .memory))
        - Cache Hit Rate: \(String(format: "%.1f", memoryMetrics.cacheHitRate * 100))%
        - Score: \(String(format: "%.1f", memoryMetrics.score * 100))%
        
        RECOMMENDATIONS:
        \(recommendations.map { "- [\($0.severity.rawValue)] \($0.title): \($0.action)" }.joined(separator: "\n"))
        """
    }
    
    public func exportMetricsToJSON() throws -> Data {
        let exportData = [
            "timestamp": Date().timeIntervalSince1970,
            "overallScore": overallScore,
            "audioMetrics": audioMetrics,
            "processingMetrics": processingMetrics,
            "exportMetrics": exportMetrics,
            "memoryMetrics": memoryMetrics,
            "recommendations": recommendations
        ] as [String: Any]
        
        return try JSONSerialization.data(withJSONObject: exportData, options: .prettyPrinted)
    }
    
    // MARK: - Performance Benchmarking
    
    public func runPerformanceBenchmark() async -> BenchmarkResults {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Run benchmarks for each component
        let audioBenchmark = await benchmarkAudioProcessing()
        let processingBenchmark = await benchmarkAsyncProcessing()
        let exportBenchmark = await benchmarkParallelExport()
        let memoryBenchmark = await benchmarkMemoryOperations()
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        
        return BenchmarkResults(
            audioScore: audioBenchmark,
            processingScore: processingBenchmark,
            exportScore: exportBenchmark,
            memoryScore: memoryBenchmark,
            totalTime: totalTime
        )
    }
    
    private func benchmarkAudioProcessing() async -> Double {
        // Benchmark audio buffer operations
        return 0.85 // Placeholder
    }
    
    private func benchmarkAsyncProcessing() async -> Double {
        // Benchmark async transcription processing
        return 0.90 // Placeholder
    }
    
    private func benchmarkParallelExport() async -> Double {
        // Benchmark parallel export operations
        return 0.88 // Placeholder
    }
    
    private func benchmarkMemoryOperations() async -> Double {
        // Benchmark memory optimization operations
        return 0.92 // Placeholder
    }
    
    public struct BenchmarkResults {
        public let audioScore: Double
        public let processingScore: Double
        public let exportScore: Double
        public let memoryScore: Double
        public let totalTime: TimeInterval
        
        public var overallScore: Double {
            return (audioScore + processingScore + exportScore + memoryScore) / 4.0
        }
    }
}