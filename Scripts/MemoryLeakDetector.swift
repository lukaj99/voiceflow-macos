#!/usr/bin/env swift

import Foundation

/// A specialized memory leak detector for Swift projects
/// Focuses on retain cycles, strong references, and memory management patterns
class MemoryLeakDetector {
    
    // MARK: - Data Structures
    
    struct LeakPattern: Codable {
        let type: LeakType
        let severity: Severity
        let file: String
        let line: Int?
        let code: String
        let description: String
        let recommendation: String
        let confidence: Confidence
        
        enum LeakType: String, Codable {
            case retainCycle = "Retain Cycle"
            case strongDelegate = "Strong Delegate Reference"
            case timerRetention = "Timer Retention"
            case notificationRetention = "Notification Observer Retention"
            case closureCapture = "Strong Closure Capture"
            case missingDeinit = "Missing Deinit"
            case weakSelfMissing = "Missing Weak Self"
            case asyncTaskRetention = "Async Task Retention"
            case singletonOveruse = "Singleton Overuse"
        }
        
        enum Severity: String, Codable {
            case critical = "Critical"
            case high = "High"
            case medium = "Medium"
            case low = "Low"
        }
        
        enum Confidence: String, Codable {
            case high = "High"
            case medium = "Medium"
            case low = "Low"
        }
    }
    
    struct AnalysisResult: Codable {
        let timestamp: Date
        let projectPath: String
        let totalFiles: Int
        let leakPatterns: [LeakPattern]
        let summary: Summary
        
        struct Summary: Codable {
            let totalLeaks: Int
            let criticalCount: Int
            let highCount: Int
            let mediumCount: Int
            let lowCount: Int
            let leakTypeBreakdown: [String: Int]
            let riskScore: Double
            let topRecommendations: [String]
        }
    }
    
    // MARK: - Properties
    
    private let projectPath: String
    private var leakPatterns: [LeakPattern] = []
    private let fileManager = FileManager.default
    
    // MARK: - Leak Detection Patterns
    
    private struct DetectionPatterns {
        
        // Retain cycle patterns
        static let retainCycles = [
            (pattern: #"\{\s*\[self\]"#, confidence: LeakPattern.Confidence.high),
            (pattern: #"self\.\w+\s*=\s*\{[^}]*self\."#, confidence: LeakPattern.Confidence.medium),
            (pattern: #"delegate\s*:\s*self"#, confidence: LeakPattern.Confidence.medium),
        ]
        
        // Timer retention patterns
        static let timerRetention = [
            (pattern: #"Timer\.scheduledTimer.*target:\s*self"#, confidence: LeakPattern.Confidence.high),
            (pattern: #"Timer\.scheduledTimer.*\{\s*self\."#, confidence: LeakPattern.Confidence.high),
            (pattern: #"timer\s*=\s*Timer\.scheduledTimer"#, confidence: LeakPattern.Confidence.medium),
        ]
        
        // Notification retention patterns
        static let notificationRetention = [
            (pattern: #"NotificationCenter\.default\.addObserver\(self"#, confidence: LeakPattern.Confidence.high),
            (pattern: #"addObserver.*observer:\s*self"#, confidence: LeakPattern.Confidence.high),
        ]
        
        // Strong delegate patterns
        static let strongDelegates = [
            (pattern: #"var\s+\w*[Dd]elegate\s*:\s*\w+\?"#, confidence: LeakPattern.Confidence.low),
            (pattern: #"@objc\s+protocol.*Delegate"#, confidence: LeakPattern.Confidence.low),
        ]
        
        // Missing weak self patterns
        static let missingWeakSelf = [
            (pattern: #"DispatchQueue.*\{\s*(?!.*\[weak self\]|.*\[unowned self\]).*self\."#, confidence: LeakPattern.Confidence.high),
            (pattern: #"URLSession.*completion:\s*\{(?!.*\[weak self\]|.*\[unowned self\]).*self\."#, confidence: LeakPattern.Confidence.high),
            (pattern: #"\.async\s*\{(?!.*\[weak self\]|.*\[unowned self\]).*self\."#, confidence: LeakPattern.Confidence.medium),
        ]
        
        // Async task retention
        static let asyncTaskRetention = [
            (pattern: #"Task\s*\{(?!.*\[weak self\]).*self\."#, confidence: LeakPattern.Confidence.medium),
            (pattern: #"Task\.detached\s*\{(?!.*weak).*self\."#, confidence: LeakPattern.Confidence.high),
        ]
    }
    
    // MARK: - Initialization
    
    init(projectPath: String) {
        self.projectPath = projectPath
    }
    
    // MARK: - Analysis Methods
    
    func analyzeMemoryLeaks() -> AnalysisResult {
        print("🔍 Starting memory leak analysis for: \(projectPath)")
        
        leakPatterns.removeAll()
        
        let swiftFiles = findSwiftFiles()
        print("📁 Found \(swiftFiles.count) Swift files to analyze")
        
        for file in swiftFiles {
            analyzeFileForLeaks(at: file)
        }
        
        let summary = generateSummary()
        
        return AnalysisResult(
            timestamp: Date(),
            projectPath: projectPath,
            totalFiles: swiftFiles.count,
            leakPatterns: leakPatterns,
            summary: summary
        )
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
    
    private func analyzeFileForLeaks(at path: String) {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            print("⚠️ Could not read file: \(path)")
            return
        }
        
        let fileName = (path as NSString).lastPathComponent
        let lines = content.components(separatedBy: .newlines)
        
        // Check for retain cycles
        checkRetainCycles(in: content, lines: lines, fileName: fileName)
        
        // Check for timer retention
        checkTimerRetention(in: content, lines: lines, fileName: fileName)
        
        // Check for notification retention
        checkNotificationRetention(in: content, lines: lines, fileName: fileName)
        
        // Check for strong delegates
        checkStrongDelegates(in: content, lines: lines, fileName: fileName)
        
        // Check for missing weak self
        checkMissingWeakSelf(in: content, lines: lines, fileName: fileName)
        
        // Check for async task retention
        checkAsyncTaskRetention(in: content, lines: lines, fileName: fileName)
        
        // Check for missing deinit
        checkMissingDeinit(in: content, lines: lines, fileName: fileName)
        
        // Check for singleton overuse
        checkSingletonOveruse(in: content, lines: lines, fileName: fileName)
    }
    
    private func checkRetainCycles(in content: String, lines: [String], fileName: String) {
        for (pattern, confidence) in DetectionPatterns.retainCycles {
            if let range = content.range(of: pattern, options: .regularExpression) {
                let lineNumber = getLineNumber(for: range.lowerBound, in: content)
                let codeLine = lineNumber <= lines.count ? lines[lineNumber - 1] : ""
                
                leakPatterns.append(LeakPattern(
                    type: .retainCycle,
                    severity: .high,
                    file: fileName,
                    line: lineNumber,
                    code: codeLine.trimmingCharacters(in: .whitespaces),
                    description: "Strong self capture in closure creates potential retain cycle",
                    recommendation: "Use [weak self] or [unowned self] capture list",
                    confidence: confidence
                ))
            }
        }
    }
    
    private func checkTimerRetention(in content: String, lines: [String], fileName: String) {
        for (pattern, confidence) in DetectionPatterns.timerRetention {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                let lineNumber = getLineNumber(for: Range(match.range, in: content)?.lowerBound ?? content.startIndex, in: content)
                let codeLine = lineNumber <= lines.count ? lines[lineNumber - 1] : ""
                
                // Check if timer is invalidated in deinit
                let hasDeinitInvalidation = content.contains("deinit") && content.contains("timer?.invalidate")
                let severity: LeakPattern.Severity = hasDeinitInvalidation ? .medium : .high
                
                leakPatterns.append(LeakPattern(
                    type: .timerRetention,
                    severity: severity,
                    file: fileName,
                    line: lineNumber,
                    code: codeLine.trimmingCharacters(in: .whitespaces),
                    description: "Timer with strong self reference may cause retain cycle",
                    recommendation: "Invalidate timer in deinit or use weak self reference",
                    confidence: confidence
                ))
            }
        }
    }
    
    private func checkNotificationRetention(in content: String, lines: [String], fileName: String) {
        for (pattern, confidence) in DetectionPatterns.notificationRetention {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                let lineNumber = getLineNumber(for: Range(match.range, in: content)?.lowerBound ?? content.startIndex, in: content)
                let codeLine = lineNumber <= lines.count ? lines[lineNumber - 1] : ""
                
                // Check if observer is removed in deinit
                let hasRemoveObserver = content.contains("removeObserver") || content.contains("deinit")
                let severity: LeakPattern.Severity = hasRemoveObserver ? .medium : .critical
                
                leakPatterns.append(LeakPattern(
                    type: .notificationRetention,
                    severity: severity,
                    file: fileName,
                    line: lineNumber,
                    code: codeLine.trimmingCharacters(in: .whitespaces),
                    description: "Notification observer may not be removed, causing memory leak",
                    recommendation: "Remove observer in deinit or use NotificationCenter.publisher",
                    confidence: confidence
                ))
            }
        }
    }
    
    private func checkStrongDelegates(in content: String, lines: [String], fileName: String) {
        for (pattern, confidence) in DetectionPatterns.strongDelegates {
            let regex = try! NSRegularExpression(pattern: pattern)
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                let lineNumber = getLineNumber(for: Range(match.range, in: content)?.lowerBound ?? content.startIndex, in: content)
                let codeLine = lineNumber <= lines.count ? lines[lineNumber - 1] : ""
                
                // Check if it's already marked as weak
                if !codeLine.contains("weak") && !codeLine.contains("unowned") {
                    leakPatterns.append(LeakPattern(
                        type: .strongDelegate,
                        severity: .medium,
                        file: fileName,
                        line: lineNumber,
                        code: codeLine.trimmingCharacters(in: .whitespaces),
                        description: "Delegate property should typically be weak to avoid retain cycles",
                        recommendation: "Mark delegate as weak unless ownership is required",
                        confidence: confidence
                    ))
                }
            }
        }
    }
    
    private func checkMissingWeakSelf(in content: String, lines: [String], fileName: String) {
        for (pattern, confidence) in DetectionPatterns.missingWeakSelf {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                let lineNumber = getLineNumber(for: Range(match.range, in: content)?.lowerBound ?? content.startIndex, in: content)
                let codeLine = lineNumber <= lines.count ? lines[lineNumber - 1] : ""
                
                leakPatterns.append(LeakPattern(
                    type: .weakSelfMissing,
                    severity: .high,
                    file: fileName,
                    line: lineNumber,
                    code: codeLine.trimmingCharacters(in: .whitespaces),
                    description: "Async operation captures self strongly, may cause retain cycle",
                    recommendation: "Use [weak self] capture list in closure",
                    confidence: confidence
                ))
            }
        }
    }
    
    private func checkAsyncTaskRetention(in content: String, lines: [String], fileName: String) {
        for (pattern, confidence) in DetectionPatterns.asyncTaskRetention {
            let regex = try! NSRegularExpression(pattern: pattern, options: [.dotMatchesLineSeparators])
            let matches = regex.matches(in: content, range: NSRange(content.startIndex..., in: content))
            
            for match in matches {
                let lineNumber = getLineNumber(for: Range(match.range, in: content)?.lowerBound ?? content.startIndex, in: content)
                let codeLine = lineNumber <= lines.count ? lines[lineNumber - 1] : ""
                
                leakPatterns.append(LeakPattern(
                    type: .asyncTaskRetention,
                    severity: .medium,
                    file: fileName,
                    line: lineNumber,
                    code: codeLine.trimmingCharacters(in: .whitespaces),
                    description: "Task captures self strongly, consider weak reference",
                    recommendation: "Use [weak self] in Task closure or structured concurrency",
                    confidence: confidence
                ))
            }
        }
    }
    
    private func checkMissingDeinit(in content: String, lines: [String], fileName: String) {
        // Check for classes that might need deinit
        if content.contains("class ") && 
           (content.contains("Timer") || content.contains("NotificationCenter") || 
            content.contains("URLSessionDataTask") || content.contains("observer")) &&
           !content.contains("deinit") {
            
            leakPatterns.append(LeakPattern(
                type: .missingDeinit,
                severity: .medium,
                file: fileName,
                line: nil,
                code: "class declaration",
                description: "Class uses resources that should be cleaned up but lacks deinit",
                recommendation: "Implement deinit to clean up timers, observers, and other resources",
                confidence: .medium
            ))
        }
    }
    
    private func checkSingletonOveruse(in content: String, lines: [String], fileName: String) {
        let singletonPatterns = ["\.shared", "\.default", "\.main"]
        var singletonCount = 0
        
        for pattern in singletonPatterns {
            singletonCount += content.components(separatedBy: pattern).count - 1
        }
        
        if singletonCount > 10 {
            leakPatterns.append(LeakPattern(
                type: .singletonOveruse,
                severity: .low,
                file: fileName,
                line: nil,
                code: "multiple singleton accesses",
                description: "Heavy singleton usage (\(singletonCount) instances) may indicate tight coupling",
                recommendation: "Consider dependency injection to reduce coupling",
                confidence: .medium
            ))
        }
    }
    
    private func getLineNumber(for index: String.Index, in content: String) -> Int {
        let substring = content[..<index]
        return substring.components(separatedBy: .newlines).count
    }
    
    private func generateSummary() -> AnalysisResult.Summary {
        let criticalCount = leakPatterns.filter { $0.severity == .critical }.count
        let highCount = leakPatterns.filter { $0.severity == .high }.count
        let mediumCount = leakPatterns.filter { $0.severity == .medium }.count
        let lowCount = leakPatterns.filter { $0.severity == .low }.count
        
        var typeBreakdown: [String: Int] = [:]
        for pattern in leakPatterns {
            typeBreakdown[pattern.type.rawValue, default: 0] += 1
        }
        
        // Calculate risk score (0-100, higher is riskier)
        let riskScore = min(100.0, Double(criticalCount * 25 + highCount * 15 + mediumCount * 8 + lowCount * 3))
        
        var recommendations: [String] = []
        
        if criticalCount > 0 {
            recommendations.append("Address \(criticalCount) critical memory leaks immediately")
        }
        
        if typeBreakdown["Retain Cycle", default: 0] > 3 {
            recommendations.append("Review closure capture patterns to prevent retain cycles")
        }
        
        if typeBreakdown["Timer Retention", default: 0] > 0 {
            recommendations.append("Ensure all timers are properly invalidated")
        }
        
        if typeBreakdown["Notification Observer Retention", default: 0] > 0 {
            recommendations.append("Remove all notification observers in deinit")
        }
        
        if typeBreakdown["Missing Deinit", default: 0] > 2 {
            recommendations.append("Implement deinit for classes managing resources")
        }
        
        if riskScore > 75 {
            recommendations.append("Consider memory profiling with Instruments")
        }
        
        return AnalysisResult.Summary(
            totalLeaks: leakPatterns.count,
            criticalCount: criticalCount,
            highCount: highCount,
            mediumCount: mediumCount,
            lowCount: lowCount,
            leakTypeBreakdown: typeBreakdown,
            riskScore: riskScore,
            topRecommendations: recommendations
        )
    }
    
    // MARK: - Export Methods
    
    func exportResults(_ result: AnalysisResult, to outputPath: String) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        
        let data = try encoder.encode(result)
        try data.write(to: URL(fileURLWithPath: outputPath))
        
        print("✅ Memory leak analysis exported to: \(outputPath)")
    }
    
    func exportMarkdownReport(_ result: AnalysisResult, to outputPath: String) throws {
        var markdown = """
        # Memory Leak Analysis Report
        
        **Generated:** \(ISO8601DateFormatter().string(from: result.timestamp))
        **Project:** \(result.projectPath)
        **Files Analyzed:** \(result.totalFiles)
        **Risk Score:** \(String(format: "%.1f", result.summary.riskScore))/100
        
        ## Summary
        
        - **Total Potential Leaks:** \(result.summary.totalLeaks)
        - **Critical:** \(result.summary.criticalCount)
        - **High:** \(result.summary.highCount)
        - **Medium:** \(result.summary.mediumCount)
        - **Low:** \(result.summary.lowCount)
        
        ## Leak Types Breakdown
        
        """
        
        for (type, count) in result.summary.leakTypeBreakdown.sorted(by: { $0.value > $1.value }) {
            markdown += "- **\(type):** \(count) issues\n"
        }
        
        markdown += "\n## Recommendations\n\n"
        for rec in result.summary.topRecommendations {
            markdown += "- \(rec)\n"
        }
        
        markdown += "\n## Detailed Findings\n\n"
        
        let groupedByType = Dictionary(grouping: result.leakPatterns) { $0.type }
        
        for (type, patterns) in groupedByType.sorted(by: { $0.value.count > $1.value.count }) {
            markdown += "### \(type.rawValue) (\(patterns.count) issues)\n\n"
            
            let sortedPatterns = patterns.sorted { pattern1, pattern2 in
                let severityOrder: [LeakPattern.Severity: Int] = [.critical: 0, .high: 1, .medium: 2, .low: 3]
                return severityOrder[pattern1.severity] ?? 4 < severityOrder[pattern2.severity] ?? 4
            }
            
            for pattern in sortedPatterns {
                markdown += """
                #### \(pattern.file)\(pattern.line.map { " (line \($0))" } ?? "")
                
                - **Severity:** \(pattern.severity.rawValue)
                - **Confidence:** \(pattern.confidence.rawValue)
                - **Code:** `\(pattern.code)`
                - **Issue:** \(pattern.description)
                - **Fix:** \(pattern.recommendation)
                
                ---
                
                """
            }
        }
        
        try markdown.write(to: URL(fileURLWithPath: outputPath), atomically: true, encoding: .utf8)
        print("✅ Markdown report exported to: \(outputPath)")
    }
}

// MARK: - Main Execution

let arguments = CommandLine.arguments

if arguments.count < 2 {
    print("Usage: swift MemoryLeakDetector.swift <project_path> [output_path]")
    exit(1)
}

let projectPath = arguments[1]
let outputPath = arguments.count > 2 ? arguments[2] : "\(projectPath)/memory_leak_analysis"

// Create output directory
try? FileManager.default.createDirectory(atPath: outputPath, withIntermediateDirectories: true)

// Run analysis
let detector = MemoryLeakDetector(projectPath: projectPath)
let result = detector.analyzeMemoryLeaks()

// Export results
let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
try? detector.exportResults(result, to: "\(outputPath)/memory_leaks_\(timestamp).json")
try? detector.exportMarkdownReport(result, to: "\(outputPath)/memory_leaks_\(timestamp).md")

// Print summary
print("""

🧠 Memory Leak Analysis Complete!
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Risk Score: \(String(format: "%.1f", result.summary.riskScore))/100
Potential Leaks: \(result.summary.totalLeaks)
Critical: \(result.summary.criticalCount) | High: \(result.summary.highCount) | Medium: \(result.summary.mediumCount) | Low: \(result.summary.lowCount)

Top Issues:
""")

for (type, count) in result.summary.leakTypeBreakdown.sorted(by: { $0.value > $1.value }).prefix(5) {
    print("• \(type): \(count)")
}

print("\nTop Recommendations:")
for (index, recommendation) in result.summary.topRecommendations.enumerated() {
    print("\(index + 1). \(recommendation)")
}

print("\nReports saved to: \(outputPath)")
