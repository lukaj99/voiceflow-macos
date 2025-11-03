import Foundation
import AVFoundation

/// Performance metrics data models and supporting types for VoiceFlow monitoring
/// Single Responsibility: Define all performance-related data structures

// MARK: - Core Metrics

/// Comprehensive snapshot of system performance metrics
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

// MARK: - Performance Alerts

/// Performance alert with type, severity, and associated metrics
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

// MARK: - Performance Profile

/// Comprehensive performance profile with averages, peaks, and recommendations
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

// MARK: - Health Status

/// System health status with per-subsystem breakdown and recommendations
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
