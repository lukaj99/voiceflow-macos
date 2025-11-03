#!/usr/bin/env swift

import Foundation

/// A modular and reusable performance analyzer for Swift projects
/// This tool can be integrated into CI/CD pipelines or run standalone
class PerformanceAnalyzer {
    
    // MARK: - Data Structures
    
    struct PerformanceMetric: Codable {
        let name: String
        let category: Category
        let severity: Severity
        let file: String
        let line: Int?
        let description: String
        let recommendation: String?
        let estimatedImpact: Impact
        
        enum Category: String, Codable {
            case memory = "Memory Management"
            case concurrency = "Concurrency"
            case algorithm = "Algorithm Complexity"
            case io = "I/O Operations"
            case ui = "UI Responsiveness"
            case network = "Network"
            case database = "Database"
        }
        
        enum Severity: String, Codable {
            case critical = "Critical"
            case high = "High"
            case medium = "Medium"
            case low = "Low"
            case info = "Info"
        }
        
        enum Impact: String, Codable {
            case high = "High Performance Impact"
            case medium = "Medium Performance Impact"
            case low = "Low Performance Impact"
            case negligible = "Negligible"
        }
    }
    
    struct AnalysisResult: Codable {
        let timestamp: Date
        let projectPath: String
        let metrics: [PerformanceMetric]
        let summary: Summary
        
        struct Summary: Codable {
            let totalIssues: Int
            let criticalCount: Int
            let highCount: Int
            let mediumCount: Int
            let lowCount: Int
            let categoryCounts: [String: Int]
            let performanceScore: Double
            let recommendations: [String]
        }
    }
    
    // MARK: - Properties
    
    private let projectPath: String
    private var metrics: [PerformanceMetric] = []
    private let fileManager = FileManager.default
    
    // MARK: - Patterns to Detect
    
    private struct Patterns {
        static let strongReferencePatterns = [
            "\\{\\s*\\[\\s*(?:weak|unowned)\\s+self\\s*\\]",  // Good pattern
            "\\{\\s*\\[self\\]",  // Potential retain cycle
            "self\\.",  // Direct self reference
            "timer\\.scheduledTimer",  // Timer retention
            "NotificationCenter\\.default\\.addObserver"  // Notification retention
        ]
        
        static let memoryPatterns = [
            "autoreleasepool",  // Memory pool usage
            "\\.copy\\(\\)",  // Copy operations
            "Data\\(contentsOf:",  // Large data loading
            "UIImage\\(named:",  // Image caching
            "NSCache",  // Cache usage
            "deinit\\s*\\{",  // Deinit implementation
            "memoryWarning"  // Memory warning handling
        ]
        
        static let concurrencyPatterns = [
            "DispatchQueue\\.main\\.async",  // Main thread dispatch
            "DispatchQueue\\.global",  // Background dispatch
            "Task\\.detached",  // Detached tasks
            "await\\s+withChecked",  // Checked continuations
            "actor\\s+",  // Actor usage
            "@MainActor",  // Main actor annotation
            "nonisolated",  // Nonisolated usage
            "Sendable"  // Sendable conformance
        ]
        
        static let algorithmPatterns = [
            "for.*in.*for.*in",  // Nested loops
            "\\.sorted\\(\\)",  // Sorting operations
            "\\.filter\\(.*\\.filter",  // Chained filters
            "\\.map\\(.*\\.map",  // Chained maps
            "\\.reduce\\(",  // Reduce operations
            "recursiv",  // Recursive calls
            "while.*true",  // Infinite loops
            "\\.contains\\(where:"  // Complex contains
        ]
        
        static let ioPatterns = [
            "FileManager\\.default",  // File operations
            "try.*Data\\(contentsOf",  // Synchronous file loading
            "UserDefaults\\.standard",  // UserDefaults access
            "CoreData",  // Core Data operations
            "\\.write\\(to:",  // File writing
            "JSONEncoder\\(\\)",  // JSON encoding
            "JSONDecoder\\(\\)"  // JSON decoding
        ]
    }
    
    // MARK: - Initialization
    
    init(projectPath: String) {
        self.projectPath = projectPath
    }
    
    // MARK: - Analysis Methods
    
    func analyze() -> AnalysisResult {
        print("🔍 Starting performance analysis for: \(projectPath)")
        
        // Clear previous metrics
        metrics.removeAll()
        
        // Analyze Swift files
        let swiftFiles = findSwiftFiles()
        print("📁 Found \(swiftFiles.count) Swift files to analyze")
        
        for file in swiftFiles {
            analyzeFile(at: file)
        }
        
        // Generate summary
        let summary = generateSummary()
        
        // Create result
        let result = AnalysisResult(
            timestamp: Date(),
            projectPath: projectPath,
            metrics: metrics,
            summary: summary
        )
        
        return result
    }
    
    private func findSwiftFiles() -> [String] {
        var swiftFiles: [String] = []
        
        if let enumerator = fileManager.enumerator(atPath: projectPath) {
            for case let file as String in enumerator {
                if file.hasSuffix(".swift") && 
                   !file.contains(".build") && 
                   !file.contains("Tests") {
                    swiftFiles.append("\(projectPath)/\(file)")
                }
            }
        }
        
        return swiftFiles
    }
    
    private func analyzeFile(at path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return
        }
        
        let fileName = (path as NSString).lastPathComponent
        let lines = content.components(separatedBy: .newlines)
        
        // Analyze memory management
        analyzeMemoryManagement(content: content, fileName: fileName, lines: lines)
        
        // Analyze concurrency
        analyzeConcurrency(content: content, fileName: fileName, lines: lines)
        
        // Analyze algorithm complexity
        analyzeAlgorithmComplexity(content: content, fileName: fileName, lines: lines)
        
        // Analyze I/O operations
        analyzeIOOperations(content: content, fileName: fileName, lines: lines)
        
        // Analyze UI responsiveness
        analyzeUIResponsiveness(content: content, fileName: fileName, lines: lines)
    }
    
    private func analyzeMemoryManagement(content: String, fileName: String, lines: [String]) {
        // Check for potential retain cycles
        if content.contains("{ [self]") || content.contains("{[self]") {
            if let lineNumber = findLineNumber(pattern: "\\{\\s*\\[self\\]", in: lines) {
                metrics.append(PerformanceMetric(
                    name: "Potential Retain Cycle",
                    category: .memory,
                    severity: .high,
                    file: fileName,
                    line: lineNumber,
                    description: "Strong self capture in closure may cause retain cycle",
                    recommendation: "Use [weak self] or [unowned self] to break potential retain cycles",
                    estimatedImpact: .high
                ))
            }
        }
        
        // Check for large data loading
        if content.contains("Data(contentsOf:") && !content.contains("async") {
            if let lineNumber = findLineNumber(pattern: "Data\\(contentsOf:", in: lines) {
                metrics.append(PerformanceMetric(
                    name: "Synchronous Data Loading",
                    category: .memory,
                    severity: .medium,
                    file: fileName,
                    line: lineNumber,
                    description: "Synchronous data loading can block main thread and consume memory",
                    recommendation: "Use async/await or background queue for data loading",
                    estimatedImpact: .medium
                ))
            }
        }
        
        // Check for missing deinit in classes with resources
        if content.contains("class ") && 
           (content.contains("Timer") || content.contains("NotificationCenter")) &&
           !content.contains("deinit") {
            metrics.append(PerformanceMetric(
                name: "Missing Deinit",
                category: .memory,
                severity: .medium,
                file: fileName,
                line: nil,
                description: "Class with resources lacks deinit implementation",
                recommendation: "Implement deinit to properly clean up resources",
                estimatedImpact: .medium
            ))
        }
    }
    
    private func analyzeConcurrency(content: String, fileName: String, lines: [String]) {
        // Check for main thread blocking
        if content.contains("DispatchQueue.main.sync") {
            if let lineNumber = findLineNumber(pattern: "DispatchQueue\\.main\\.sync", in: lines) {
                metrics.append(PerformanceMetric(
                    name: "Main Thread Blocking",
                    category: .concurrency,
                    severity: .critical,
                    file: fileName,
                    line: lineNumber,
                    description: "Synchronous dispatch to main queue can cause deadlock",
                    recommendation: "Use async dispatch or restructure code to avoid blocking",
                    estimatedImpact: .high
                ))
            }
        }
        
        // Check for unstructured concurrency
        if content.contains("Task.detached") {
            if let lineNumber = findLineNumber(pattern: "Task\\.detached", in: lines) {
                metrics.append(PerformanceMetric(
                    name: "Unstructured Concurrency",
                    category: .concurrency,
                    severity: .low,
                    file: fileName,
                    line: lineNumber,
                    description: "Detached tasks lose structured concurrency benefits",
                    recommendation: "Consider using Task {} or async methods for structured concurrency",
                    estimatedImpact: .low
                ))
            }
        }
        
        // Check for missing @MainActor on UI updates
        if content.contains("@Published") && !content.contains("@MainActor") {
            metrics.append(PerformanceMetric(
                name: "UI State Without MainActor",
                category: .concurrency,
                severity: .medium,
                file: fileName,
                line: nil,
                description: "Published properties should be isolated to MainActor",
                recommendation: "Add @MainActor annotation to ensure UI updates on main thread",
                estimatedImpact: .medium
            ))
        }
    }
    
    private func analyzeAlgorithmComplexity(content: String, fileName: String, lines: [String]) {
        // Check for nested loops
        let nestedLoopPattern = "for.*\\{[^}]*for.*\\{"
        if let range = content.range(of: nestedLoopPattern, options: .regularExpression) {
            if let lineNumber = findLineNumber(pattern: nestedLoopPattern, in: lines) {
                metrics.append(PerformanceMetric(
                    name: "Nested Loop Detected",
                    category: .algorithm,
                    severity: .medium,
                    file: fileName,
                    line: lineNumber,
                    description: "Nested loops can lead to O(n²) complexity",
                    recommendation: "Consider optimizing with hash maps or better algorithms",
                    estimatedImpact: .medium
                ))
            }
        }
        
        // Check for multiple chained operations
        if content.contains(".filter") && content.contains(".map") && content.contains(".reduce") {
            metrics.append(PerformanceMetric(
                name: "Multiple Collection Operations",
                category: .algorithm,
                severity: .low,
                file: fileName,
                line: nil,
                description: "Multiple chained collection operations create intermediate arrays",
                recommendation: "Consider using lazy collections or combining operations",
                estimatedImpact: .low
            ))
        }
    }
    
    private func analyzeIOOperations(content: String, fileName: String, lines: [String]) {
        // Check for synchronous file operations
        if content.contains("try ") && content.contains("contentsOf") && !content.contains("async") {
            metrics.append(PerformanceMetric(
                name: "Synchronous File I/O",
                category: .io,
                severity: .medium,
                file: fileName,
                line: nil,
                description: "Synchronous file operations can block thread",
                recommendation: "Use async/await for file operations",
                estimatedImpact: .medium
            ))
        }
        
        // Check for excessive UserDefaults access
        let userDefaultsCount = content.components(separatedBy: "UserDefaults.standard").count - 1
        if userDefaultsCount > 5 {
            metrics.append(PerformanceMetric(
                name: "Excessive UserDefaults Access",
                category: .io,
                severity: .low,
                file: fileName,
                line: nil,
                description: "Multiple UserDefaults accesses detected (\(userDefaultsCount) times)",
                recommendation: "Cache UserDefaults values in properties",
                estimatedImpact: .low
            ))
        }
    }
    
    private func analyzeUIResponsiveness(content: String, fileName: String, lines: [String]) {
        // Check for heavy operations in view body
        if fileName.contains("View.swift") && content.contains("struct") && content.contains("View") {
            if content.contains(".sorted()") || content.contains(".filter") {
                metrics.append(PerformanceMetric(
                    name: "Heavy Operation in View",
                    category: .ui,
                    severity: .high,
                    file: fileName,
                    line: nil,
                    description: "Heavy operations in SwiftUI view body",
                    recommendation: "Move heavy operations to ViewModel or use @State for caching",
                    estimatedImpact: .high
                ))
            }
        }
        
        // Check for missing async image loading
        if content.contains("UIImage(data:") || content.contains("Image(uiImage:") {
            if !content.contains("async") && !content.contains("AsyncImage") {
                metrics.append(PerformanceMetric(
                    name: "Synchronous Image Loading",
                    category: .ui,
                    severity: .medium,
                    file: fileName,
                    line: nil,
                    description: "Synchronous image loading can freeze UI",
                    recommendation: "Use AsyncImage or async loading pattern",
                    estimatedImpact: .medium
                ))
            }
        }
    }
    
    private func findLineNumber(pattern: String, in lines: [String]) -> Int? {
        for (index, line) in lines.enumerated() {
            if line.range(of: pattern, options: .regularExpression) != nil {
                return index + 1
            }
        }
        return nil
    }
    
    private func generateSummary() -> AnalysisResult.Summary {
        let criticalCount = metrics.filter { $0.severity == .critical }.count
        let highCount = metrics.filter { $0.severity == .high }.count
        let mediumCount = metrics.filter { $0.severity == .medium }.count
        let lowCount = metrics.filter { $0.severity == .low }.count
        
        var categoryCounts: [String: Int] = [:]
        for metric in metrics {
            categoryCounts[metric.category.rawValue, default: 0] += 1
        }
        
        // Calculate performance score (0-100)
        let totalWeight = Double(criticalCount * 10 + highCount * 5 + mediumCount * 2 + lowCount)
        let maxWeight = Double(metrics.count * 10)
        let performanceScore = maxWeight > 0 ? max(0, 100 - (totalWeight / maxWeight * 100)) : 100
        
        // Generate top recommendations
        var recommendations: [String] = []
        
        if criticalCount > 0 {
            recommendations.append("Fix \(criticalCount) critical performance issues immediately")
        }
        
        if categoryCounts[PerformanceMetric.Category.memory.rawValue, default: 0] > 3 {
            recommendations.append("Review memory management patterns and potential leaks")
        }
        
        if categoryCounts[PerformanceMetric.Category.concurrency.rawValue, default: 0] > 3 {
            recommendations.append("Audit concurrency patterns for thread safety")
        }
        
        if categoryCounts[PerformanceMetric.Category.ui.rawValue, default: 0] > 2 {
            recommendations.append("Optimize UI operations for better responsiveness")
        }
        
        if performanceScore < 70 {
            recommendations.append("Consider performance profiling with Instruments")
        }
        
        return AnalysisResult.Summary(
            totalIssues: metrics.count,
            criticalCount: criticalCount,
            highCount: highCount,
            mediumCount: mediumCount,
            lowCount: lowCount,
            categoryCounts: categoryCounts,
            performanceScore: performanceScore.rounded(),
            recommendations: recommendations
        )
    }
    
    // MARK: - Export Methods
    
    func exportJSON(result: AnalysisResult, to path: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(result)
        try data.write(to: URL(fileURLWithPath: path))
        print("✅ JSON report exported to: \(path)")
    }
    
    func exportMarkdown(result: AnalysisResult, to path: String) throws {
        var markdown = """
        # Performance Analysis Report
        
        **Generated:** \(ISO8601DateFormatter().string(from: result.timestamp))
        **Project:** \(result.projectPath)
        **Performance Score:** \(result.summary.performanceScore)/100
        
        ## Summary
        
        - **Total Issues:** \(result.summary.totalIssues)
        - **Critical:** \(result.summary.criticalCount)
        - **High:** \(result.summary.highCount)
        - **Medium:** \(result.summary.mediumCount)
        - **Low:** \(result.summary.lowCount)
        
        ## Issues by Category
        
        """
        
        for (category, count) in result.summary.categoryCounts.sorted(by: { $0.value > $1.value }) {
            markdown += "- **\(category):** \(count) issues\n"
        }
        
        markdown += "\n## Recommendations\n\n"
        for recommendation in result.summary.recommendations {
            markdown += "- \(recommendation)\n"
        }
        
        markdown += "\n## Detailed Findings\n\n"
        
        // Group metrics by severity
        let groupedMetrics = Dictionary(grouping: result.metrics) { $0.severity }
        
        for severity in [PerformanceMetric.Severity.critical, .high, .medium, .low] {
            if let severityMetrics = groupedMetrics[severity], !severityMetrics.isEmpty {
                markdown += "### \(severity.rawValue) Priority\n\n"
                
                for metric in severityMetrics {
                    markdown += """
                    #### \(metric.name)
                    
                    - **File:** `\(metric.file)`\(metric.line.map { " (line \($0))" } ?? "")
                    - **Category:** \(metric.category.rawValue)
                    - **Impact:** \(metric.estimatedImpact.rawValue)
                    - **Description:** \(metric.description)
                    \(metric.recommendation.map { "- **Recommendation:** \($0)" } ?? "")
                    
                    ---
                    
                    """
                }
            }
        }
        
        try markdown.write(to: URL(fileURLWithPath: path), atomically: true, encoding: .utf8)
        print("✅ Markdown report exported to: \(path)")
    }
}

// MARK: - Main Execution

let arguments = CommandLine.arguments

if arguments.count < 2 {
    print("Usage: swift PerformanceAnalyzer.swift <project_path> [output_path]")
    exit(1)
}

let projectPath = arguments[1]
let outputPath = arguments.count > 2 ? arguments[2] : "\(projectPath)/performance_analysis"

// Create output directory
try? FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

// Run analysis
let analyzer = PerformanceAnalyzer(projectPath: projectPath)
let result = analyzer.analyze()

// Export results
let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
try? analyzer.exportJSON(result: result, to: "\(outputPath)/performance_\(timestamp).json")
try? analyzer.exportMarkdown(result: result, to: "\(outputPath)/performance_\(timestamp).md")

// Print summary
print("""

📊 Performance Analysis Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Performance Score: \(result.summary.performanceScore)/100
Total Issues: \(result.summary.totalIssues)
Critical: \(result.summary.criticalCount) | High: \(result.summary.highCount) | Medium: \(result.summary.mediumCount) | Low: \(result.summary.lowCount)

Top Recommendations:
""")

for (index, recommendation) in result.summary.recommendations.enumerated() {
    print("\(index + 1). \(recommendation)")
}

print("\nReports saved to: \(outputPath)")
