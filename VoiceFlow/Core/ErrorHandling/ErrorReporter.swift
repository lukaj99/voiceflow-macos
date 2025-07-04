import Foundation
import OSLog

/// Centralized error reporting and logging system
/// Single Responsibility: Error collection, logging, and reporting
public actor ErrorReporter {
    
    // MARK: - Properties
    
    private let logger = Logger(subsystem: "com.voiceflow.app", category: "ErrorReporter")
    private var errorHistory: [ErrorReport] = []
    private var errorStatistics: ErrorStatistics = ErrorStatistics()
    private let maxHistorySize = 1000
    
    // MARK: - Types
    
    public struct ErrorReport: Sendable, Identifiable {
        public let id = UUID()
        public let error: VoiceFlowError
        public let timestamp: Date
        public let context: ErrorContext
        public let stackTrace: String?
        public let userActions: [String]
        public let deviceInfo: DeviceInfo
        
        public init(
            error: VoiceFlowError,
            timestamp: Date = Date(),
            context: ErrorContext,
            stackTrace: String? = nil,
            userActions: [String] = [],
            deviceInfo: DeviceInfo = DeviceInfo.current
        ) {
            self.error = error
            self.timestamp = timestamp
            self.context = context
            self.stackTrace = stackTrace
            self.userActions = userActions
            self.deviceInfo = deviceInfo
        }
    }
    
    public struct ErrorContext: Sendable {
        public let component: String
        public let function: String
        public let userID: String?
        public let sessionID: String
        public let additionalInfo: [String: String]
        
        public init(
            component: String,
            function: String = #function,
            userID: String? = nil,
            sessionID: String = UUID().uuidString,
            additionalInfo: [String: String] = [:]
        ) {
            self.component = component
            self.function = function
            self.userID = userID
            self.sessionID = sessionID
            self.additionalInfo = additionalInfo
        }
    }
    
    public struct DeviceInfo: Sendable {
        public let deviceModel: String
        public let osVersion: String
        public let appVersion: String
        public let language: String
        public let timezone: String
        
        public static var current: DeviceInfo {
            DeviceInfo(
                deviceModel: ProcessInfo.processInfo.hostName,
                osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
                appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown",
                language: Locale.current.identifier,
                timezone: TimeZone.current.identifier
            )
        }
    }
    
    public struct ErrorStatistics: Sendable {
        public var totalErrors: Int = 0
        public var errorsByCategory: [ErrorCategory: Int] = [:]
        public var errorsBySeverity: [ErrorSeverity: Int] = [:]
        public var lastReportTime: Date?
        public var sessionErrorCount: Int = 0
        
        public mutating func recordError(_ error: VoiceFlowError) {
            totalErrors += 1
            sessionErrorCount += 1
            lastReportTime = Date()
            
            errorsByCategory[error.category, default: 0] += 1
            errorsBySeverity[error.severity, default: 0] += 1
        }
        
        public var errorRate: Double {
            // Calculate errors per hour for current session
            guard let lastReport = lastReportTime else { return 0.0 }
            let sessionDuration = Date().timeIntervalSince(lastReport) / 3600.0 // Convert to hours
            return sessionDuration > 0 ? Double(sessionErrorCount) / sessionDuration : 0.0
        }
        
        public var mostCommonCategory: ErrorCategory? {
            errorsByCategory.max { $0.value < $1.value }?.key
        }
        
        public var criticalErrorCount: Int {
            errorsBySeverity[.critical] ?? 0
        }
    }
    
    // MARK: - Singleton Instance
    
    public static let shared = ErrorReporter()
    
    private init() {
        logger.info("🚨 ErrorReporter initialized")
    }
    
    // MARK: - Public Interface
    
    /// Report an error with context
    public func reportError(
        _ error: VoiceFlowError,
        context: ErrorContext,
        userActions: [String] = [],
        stackTrace: String? = nil
    ) {
        let report = ErrorReport(
            error: error,
            context: context,
            stackTrace: stackTrace,
            userActions: userActions
        )
        
        // Add to history
        errorHistory.append(report)
        if errorHistory.count > maxHistorySize {
            errorHistory.removeFirst(errorHistory.count - maxHistorySize)
        }
        
        // Update statistics
        errorStatistics.recordError(error)
        
        // Log the error
        logError(report)
        
        // Handle critical errors immediately
        if error.severity == .critical {
            handleCriticalError(report)
        }
        
        logger.info("🚨 Error reported: \(error.category.rawValue) - \(error.errorDescription ?? "Unknown error")")
    }
    
    /// Report an error with minimal context (convenience method)
    public func reportError(
        _ error: VoiceFlowError,
        component: String,
        function: String = #function
    ) {
        let context = ErrorContext(component: component, function: function)
        reportError(error, context: context)
    }
    
    /// Get error statistics
    public func getStatistics() -> ErrorStatistics {
        return errorStatistics
    }
    
    /// Get recent error reports
    public func getRecentErrors(limit: Int = 50) -> [ErrorReport] {
        return Array(errorHistory.suffix(limit))
    }
    
    /// Get errors filtered by category
    public func getErrors(category: ErrorCategory, limit: Int = 50) -> [ErrorReport] {
        return errorHistory
            .filter { $0.error.category == category }
            .suffix(limit)
            .reversed()
    }
    
    /// Get errors filtered by severity
    public func getErrors(severity: ErrorSeverity, limit: Int = 50) -> [ErrorReport] {
        return errorHistory
            .filter { $0.error.severity == severity }
            .suffix(limit)
            .reversed()
    }
    
    /// Clear error history
    public func clearHistory() {
        errorHistory.removeAll()
        errorStatistics = ErrorStatistics()
        logger.info("🚨 Error history cleared")
    }
    
    /// Generate error report for debugging
    public func generateErrorReport() -> ErrorReportSummary {
        let recentErrors = Array(errorHistory.suffix(10))
        let criticalErrors = errorHistory.filter { $0.error.severity == .critical }
        
        return ErrorReportSummary(
            totalErrors: errorStatistics.totalErrors,
            sessionErrors: errorStatistics.sessionErrorCount,
            statistics: errorStatistics,
            recentErrors: recentErrors,
            criticalErrors: Array(criticalErrors.suffix(5)),
            deviceInfo: DeviceInfo.current,
            reportGenerated: Date()
        )
    }
    
    /// Export error data for support
    public func exportErrorData() -> Data? {
        let report = generateErrorReport()
        
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = .prettyPrinted
            return try encoder.encode(report)
        } catch {
            logger.error("🚨 Failed to export error data: \(error.localizedDescription)")
            return nil
        }
    }
    
    // MARK: - Private Methods
    
    private func logError(_ report: ErrorReport) {
        let logLevel: OSLogType = {
            switch report.error.severity {
            case .critical: return .fault
            case .high: return .error
            case .medium: return .default
            case .low: return .info
            }
        }()
        
        logger.log(
            level: logLevel,
            """
            🚨 ERROR REPORT
            Category: \(report.error.category.rawValue)
            Severity: \(report.error.severity.rawValue)
            Component: \(report.context.component)
            Function: \(report.context.function)
            Error: \(report.error.errorDescription ?? "Unknown")
            Session: \(report.context.sessionID)
            """
        )
        
        // Log stack trace if available
        if let stackTrace = report.stackTrace {
            logger.debug("🚨 Stack trace: \(stackTrace)")
        }
        
        // Log user actions if any
        if !report.userActions.isEmpty {
            logger.debug("🚨 User actions: \(report.userActions.joined(separator: " -> "))")
        }
    }
    
    private func handleCriticalError(_ report: ErrorReport) {
        logger.fault("🚨 CRITICAL ERROR DETECTED: \(report.error.errorDescription ?? "Unknown critical error")")
        
        // For critical errors, we might want to:
        // 1. Send immediate telemetry (if configured)
        // 2. Create crash reports
        // 3. Trigger automatic recovery procedures
        // 4. Alert system administrators (in enterprise versions)
        
        print("🚨 CRITICAL ERROR: \(report.error.errorDescription ?? "Unknown")")
        print("🚨 Component: \(report.context.component)")
        print("🚨 Function: \(report.context.function)")
        print("🚨 Timestamp: \(report.timestamp)")
    }
}

// MARK: - Supporting Types

public struct ErrorReportSummary: Codable, Sendable {
    public let totalErrors: Int
    public let sessionErrors: Int
    public let statistics: ErrorReporter.ErrorStatistics
    public let recentErrors: [ErrorReporter.ErrorReport]
    public let criticalErrors: [ErrorReporter.ErrorReport]
    public let deviceInfo: ErrorReporter.DeviceInfo
    public let reportGenerated: Date
    
    public init(
        totalErrors: Int,
        sessionErrors: Int,
        statistics: ErrorReporter.ErrorStatistics,
        recentErrors: [ErrorReporter.ErrorReport],
        criticalErrors: [ErrorReporter.ErrorReport],
        deviceInfo: ErrorReporter.DeviceInfo,
        reportGenerated: Date
    ) {
        self.totalErrors = totalErrors
        self.sessionErrors = sessionErrors
        self.statistics = statistics
        self.recentErrors = recentErrors
        self.criticalErrors = criticalErrors
        self.deviceInfo = deviceInfo
        self.reportGenerated = reportGenerated
    }
}

// MARK: - Codable Extensions

extension ErrorReporter.ErrorReport: Codable {
    enum CodingKeys: String, CodingKey {
        case id, error, timestamp, context, stackTrace, userActions, deviceInfo
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(error.errorDescription, forKey: .error) // Encode as string for JSON export
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(context, forKey: .context)
        try container.encodeIfPresent(stackTrace, forKey: .stackTrace)
        try container.encode(userActions, forKey: .userActions)
        try container.encode(deviceInfo, forKey: .deviceInfo)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let _ = try container.decode(UUID.self, forKey: .id)
        let errorDescription = try container.decode(String.self, forKey: .error)
        let timestamp = try container.decode(Date.self, forKey: .timestamp)
        let context = try container.decode(ErrorReporter.ErrorContext.self, forKey: .context)
        let stackTrace = try container.decodeIfPresent(String.self, forKey: .stackTrace)
        let userActions = try container.decode([String].self, forKey: .userActions)
        let deviceInfo = try container.decode(ErrorReporter.DeviceInfo.self, forKey: .deviceInfo)
        
        // Create a generic unexpected error since we can't reconstruct the original VoiceFlowError
        let error = VoiceFlowError.unexpectedError(errorDescription)
        
        self.init(
            error: error,
            timestamp: timestamp,
            context: context,
            stackTrace: stackTrace,
            userActions: userActions,
            deviceInfo: deviceInfo
        )
    }
}

extension ErrorReporter.ErrorContext: Codable {}
extension ErrorReporter.DeviceInfo: Codable {}

// ErrorStatistics simplified for export (no complex dictionaries)
extension ErrorReporter.ErrorStatistics: Codable {
    enum CodingKeys: String, CodingKey {
        case totalErrors, sessionErrorCount, lastReportTime
    }
    
    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(totalErrors, forKey: .totalErrors)
        try container.encode(sessionErrorCount, forKey: .sessionErrorCount)
        try container.encodeIfPresent(lastReportTime, forKey: .lastReportTime)
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.totalErrors = try container.decode(Int.self, forKey: .totalErrors)
        self.sessionErrorCount = try container.decode(Int.self, forKey: .sessionErrorCount)
        self.lastReportTime = try container.decodeIfPresent(Date.self, forKey: .lastReportTime)
        self.errorsByCategory = [:]
        self.errorsBySeverity = [:]
    }
}