import Foundation

/// High-performance parallel export engine that processes multiple formats simultaneously
/// Addresses sequential export processing bottleneck with 50% target speed improvement
public final class ParallelExportEngine {
    
    // MARK: - Types
    
    public struct ExportJob: Sendable {
        public let id: UUID
        public let format: ExportFormat
        public let session: TranscriptionSession
        public let configuration: ExportConfiguration?
        public let outputURL: URL?
        public let priority: Priority
        
        public enum Priority: Int, CaseIterable {
            case low = 1
            case normal = 2
            case high = 3
            case critical = 4
        }
        
        public init(format: ExportFormat, session: TranscriptionSession, configuration: ExportConfiguration? = nil, outputURL: URL? = nil, priority: Priority = .normal) {
            self.id = UUID()
            self.format = format
            self.session = session
            self.configuration = configuration
            self.outputURL = outputURL
            self.priority = priority
        }
    }
    
    public struct ExportResults: Sendable {
        public let successful: [ExportFormat: ExportResult]
        public let failed: [ExportFormat: ExportError]
        public let totalTime: TimeInterval
        public let parallelizationRatio: Double
        
        public var successRate: Double {
            let total = successful.count + failed.count
            return total > 0 ? Double(successful.count) / Double(total) : 0
        }
    }
    
    public struct PerformanceMetrics {
        public let averageExportTime: TimeInterval
        public let parallelEfficiency: Double
        public let throughputImprovement: Double
        public let memoryUsage: Int64
        public let activeConcurrentJobs: Int
        
        public var description: String {
            return """
            Parallel Export Performance:
            - Average Export Time: \(String(format: "%.2f", averageExportTime))s
            - Parallel Efficiency: \(String(format: "%.1f", parallelEfficiency * 100))%
            - Throughput Improvement: \(String(format: "%.1f", throughputImprovement * 100))%
            - Memory Usage: \(ByteCountFormatter.string(fromByteCount: memoryUsage, countStyle: .memory))
            - Active Jobs: \(activeConcurrentJobs)
            """
        }
    }
    
    // MARK: - Properties
    
    private let maxConcurrentJobs: Int
    private let exportManager: ExportManager
    private var activeJobs: Set<UUID> = []
    private var jobQueue: [ExportJob] = []
    private let performanceTracker = ExportPerformanceTracker()
    
    // Thread-safe queues
    private let coordinationQueue = DispatchQueue(label: "com.voiceflow.export.coordination")
    private let executionGroup = DispatchGroup()
    
    // Performance monitoring
    private var exportStartTimes: [UUID: CFAbsoluteTime] = [:]
    private var recentExportTimes: [TimeInterval] = []
    private let maxHistorySize = 100
    
    // MARK: - Initialization
    
    public init(maxConcurrentJobs: Int = 4, exportManager: ExportManager) {
        self.maxConcurrentJobs = maxConcurrentJobs
        self.exportManager = exportManager
    }
    
    // MARK: - Parallel Export Operations
    
    /// Execute multiple export jobs in parallel with optimal resource utilization
    public func executeParallelExports(_ jobs: [ExportJob]) async throws -> ExportResults {
        let startTime = CFAbsoluteTimeGetCurrent()
        
        // Sort jobs by priority for optimal execution order
        let prioritizedJobs = jobs.sorted { $0.priority.rawValue > $1.priority.rawValue }
        
        var successful: [ExportFormat: ExportResult] = [:]
        var failed: [ExportFormat: ExportError] = [:]
        
        // Execute jobs in parallel using TaskGroup
        try await withThrowingTaskGroup(of: (ExportFormat, Result<ExportResult, ExportError>).self) { group in
            
            // Add all jobs to the task group
            for job in prioritizedJobs {
                group.addTask { [weak self] in
                    guard let self = self else { 
                        return (job.format, .failure(.cancelled))
                    }
                    
                    let result = await self.executeJob(job)
                    return (job.format, result)
                }
            }
            
            // Collect results
            for try await (format, result) in group {
                switch result {
                case .success(let exportResult):
                    successful[format] = exportResult
                case .failure(let error):
                    failed[format] = error
                }
            }
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let sequentialEstimate = estimateSequentialTime(for: prioritizedJobs)
        let parallelizationRatio = sequentialEstimate / totalTime
        
        // Update performance metrics
        performanceTracker.recordExportBatch(
            jobCount: jobs.count,
            totalTime: totalTime,
            parallelizationRatio: parallelizationRatio
        )
        
        return ExportResults(
            successful: successful,
            failed: failed,
            totalTime: totalTime,
            parallelizationRatio: parallelizationRatio
        )
    }
    
    /// Execute batch export with automatic format optimization
    public func batchExport(
        session: TranscriptionSession,
        formats: [ExportFormat],
        outputDirectory: URL,
        configurations: [ExportFormat: ExportConfiguration] = [:],
        progressDelegate: ExportProgressDelegate? = nil
    ) async throws -> ExportResults {
        
        // Create optimized export jobs
        let jobs = formats.map { format in
            let config = configurations[format]
            let filename = exportManager.suggestedFilename(for: session, format: format)
            let outputURL = outputDirectory.appendingPathComponent(filename)
            
            return ExportJob(
                format: format,
                session: session,
                configuration: config,
                outputURL: outputURL,
                priority: determinePriority(for: format)
            )
        }
        
        // Execute with progress tracking
        let progressTracker = ParallelExportProgressTracker(
            totalJobs: jobs.count,
            delegate: progressDelegate
        )
        
        return try await executeParallelExportsWithProgress(jobs, progressTracker: progressTracker)
    }
    
    // MARK: - Optimized Job Execution
    
    private func executeJob(_ job: ExportJob) async -> Result<ExportResult, ExportError> {
        let jobStartTime = CFAbsoluteTimeGetCurrent()
        
        // Track active job
        coordinationQueue.sync {
            activeJobs.insert(job.id)
            exportStartTimes[job.id] = jobStartTime
        }
        
        defer {
            coordinationQueue.sync {
                activeJobs.remove(job.id)
                exportStartTimes.removeValue(forKey: job.id)
                
                // Update performance history
                let duration = CFAbsoluteTimeGetCurrent() - jobStartTime
                recentExportTimes.append(duration)
                if recentExportTimes.count > maxHistorySize {
                    recentExportTimes.removeFirst()
                }
            }
        }
        
        do {
            let result: ExportResult
            
            if let outputURL = job.outputURL {
                // Export to file
                try await exportManager.exportToFile(
                    session: job.session,
                    format: job.format,
                    fileURL: outputURL,
                    configuration: job.configuration,
                    progressDelegate: nil
                )
                result = .fileURL(outputURL)
            } else {
                // Export to data
                result = try await exportManager.export(
                    session: job.session,
                    format: job.format,
                    configuration: job.configuration,
                    progressDelegate: nil
                )
            }
            
            return .success(result)
            
        } catch let error as ExportError {
            return .failure(error)
        } catch {
            return .failure(.encodingError(error))
        }
    }
    
    private func executeParallelExportsWithProgress(
        _ jobs: [ExportJob],
        progressTracker: ParallelExportProgressTracker
    ) async throws -> ExportResults {
        
        let startTime = CFAbsoluteTimeGetCurrent()
        var successful: [ExportFormat: ExportResult] = [:]
        var failed: [ExportFormat: ExportError] = [:]
        
        try await withThrowingTaskGroup(of: (ExportFormat, Result<ExportResult, ExportError>).self) { group in
            
            for job in jobs {
                group.addTask { [weak self] in
                    guard let self = self else {
                        return (job.format, .failure(.cancelled))
                    }
                    
                    let result = await self.executeJob(job)
                    await progressTracker.jobCompleted(format: job.format, result: result)
                    return (job.format, result)
                }
            }
            
            for try await (format, result) in group {
                switch result {
                case .success(let exportResult):
                    successful[format] = exportResult
                case .failure(let error):
                    failed[format] = error
                }
            }
        }
        
        let totalTime = CFAbsoluteTimeGetCurrent() - startTime
        let sequentialEstimate = estimateSequentialTime(for: jobs)
        let parallelizationRatio = sequentialEstimate / totalTime
        
        await progressTracker.batchCompleted()
        
        return ExportResults(
            successful: successful,
            failed: failed,
            totalTime: totalTime,
            parallelizationRatio: parallelizationRatio
        )
    }
    
    // MARK: - Performance Optimization
    
    private func determinePriority(for format: ExportFormat) -> ExportJob.Priority {
        switch format {
        case .text:
            return .high      // Fastest to process
        case .markdown:
            return .high      // Fast to process
        case .srt:
            return .normal    // Medium complexity
        case .docx:
            return .low       // Slower due to formatting
        case .pdf:
            return .low       // Slowest due to rendering
        }
    }
    
    private func estimateSequentialTime(for jobs: [ExportJob]) -> TimeInterval {
        // Estimate based on format complexity and session size
        let baseTime: TimeInterval = 0.5 // Base processing time
        
        return jobs.reduce(0) { total, job in
            let formatMultiplier: Double
            switch job.format {
            case .text: formatMultiplier = 1.0
            case .markdown: formatMultiplier = 1.2
            case .srt: formatMultiplier = 1.5
            case .docx: formatMultiplier = 2.0
            case .pdf: formatMultiplier = 3.0
            }
            
            let sessionComplexity = Double(job.session.segments.count) / 100.0 + 1.0
            return total + (baseTime * formatMultiplier * sessionComplexity)
        }
    }
    
    // MARK: - Monitoring and Analytics
    
    public func getPerformanceMetrics() -> PerformanceMetrics {
        return coordinationQueue.sync {
            let averageTime = recentExportTimes.isEmpty ? 0 : 
                             recentExportTimes.reduce(0, +) / Double(recentExportTimes.count)
            
            let efficiency = performanceTracker.getParallelEfficiency()
            let improvement = performanceTracker.getThroughputImprovement()
            let memoryUsage = performanceTracker.getCurrentMemoryUsage()
            
            return PerformanceMetrics(
                averageExportTime: averageTime,
                parallelEfficiency: efficiency,
                throughputImprovement: improvement,
                memoryUsage: memoryUsage,
                activeConcurrentJobs: activeJobs.count
            )
        }
    }
    
    public func resetPerformanceMetrics() {
        coordinationQueue.sync {
            recentExportTimes.removeAll()
            exportStartTimes.removeAll()
            performanceTracker.reset()
        }
    }
}

// MARK: - Performance Tracking

private class ExportPerformanceTracker {
    private var batchHistory: [(jobCount: Int, time: TimeInterval, ratio: Double)] = []
    private let maxHistory = 50
    
    func recordExportBatch(jobCount: Int, totalTime: TimeInterval, parallelizationRatio: Double) {
        batchHistory.append((jobCount, totalTime, parallelizationRatio))
        if batchHistory.count > maxHistory {
            batchHistory.removeFirst()
        }
    }
    
    func getParallelEfficiency() -> Double {
        guard !batchHistory.isEmpty else { return 0 }
        let totalRatio = batchHistory.map { $0.ratio }.reduce(0, +)
        return totalRatio / Double(batchHistory.count)
    }
    
    func getThroughputImprovement() -> Double {
        guard !batchHistory.isEmpty else { return 0 }
        let averageRatio = getParallelEfficiency()
        return max(0, (averageRatio - 1.0)) // Improvement over sequential
    }
    
    func getCurrentMemoryUsage() -> Int64 {
        let info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size)/4
        
        let kerr: kern_return_t = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(mach_task_self_,
                         task_flavor_t(MACH_TASK_BASIC_INFO),
                         $0,
                         &count)
            }
        }
        
        if kerr == KERN_SUCCESS {
            return Int64(info.resident_size)
        } else {
            return 0
        }
    }
    
    func reset() {
        batchHistory.removeAll()
    }
}

// MARK: - Progress Tracking

private actor ParallelExportProgressTracker {
    private let totalJobs: Int
    private var completedJobs: Int = 0
    private let delegate: ExportProgressDelegate?
    
    init(totalJobs: Int, delegate: ExportProgressDelegate?) {
        self.totalJobs = totalJobs
        self.delegate = delegate
    }
    
    func jobCompleted(format: ExportFormat, result: Result<ExportResult, ExportError>) {
        completedJobs += 1
        let progress = Double(completedJobs) / Double(totalJobs)
        
        delegate?.exportDidUpdateProgress(
            progress,
            currentStep: "Completed \(format.displayName) (\(completedJobs)/\(totalJobs))"
        )
    }
    
    func batchCompleted() {
        delegate?.exportDidUpdateProgress(1.0, currentStep: "All exports completed")
    }
}