//
//  TestUtilities.swift
//  VoiceFlowTests
//
//  Common utilities and helpers for testing
//

import Foundation
import XCTest
import AVFoundation
@testable import VoiceFlow

// MARK: - Async Testing Utilities

/// Utilities for testing async code with proper Swift 6 concurrency
public struct AsyncTestUtilities {
    
    /// Waits for an async condition to become true
    public static func waitFor(
        _ condition: @escaping () async -> Bool,
        timeout: TimeInterval = 5.0,
        pollInterval: TimeInterval = 0.1,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        
        while Date() < deadline {
            if await condition() {
                return
            }
            try await Task.sleep(nanoseconds: UInt64(pollInterval * 1_000_000_000))
        }
        
        XCTFail("Condition not met within \(timeout) seconds", file: file, line: line)
    }
    
    /// Executes an async operation with timeout
    public static func withTimeout<T>(
        _ timeout: TimeInterval = 5.0,
        operation: @escaping () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                throw TimeoutError()
            }
            
            guard let result = try await group.next() else {
                XCTFail("No result returned", file: file, line: line)
                throw TimeoutError()
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Measures async operation performance
    public static func measureAsync(
        iterations: Int = 10,
        operation: @escaping () async throws -> Void
    ) async throws -> PerformanceMetrics {
        var durations: [TimeInterval] = []
        
        for _ in 0..<iterations {
            let start = Date()
            try await operation()
            let duration = Date().timeIntervalSince(start)
            durations.append(duration)
        }
        
        return PerformanceMetrics(durations: durations)
    }
    
    public struct TimeoutError: Error {}
    
    public struct PerformanceMetrics {
        public let durations: [TimeInterval]
        public let average: TimeInterval
        public let min: TimeInterval
        public let max: TimeInterval
        public let median: TimeInterval
        
        init(durations: [TimeInterval]) {
            self.durations = durations
            self.average = durations.reduce(0, +) / Double(durations.count)
            self.min = durations.min() ?? 0
            self.max = durations.max() ?? 0
            
            let sorted = durations.sorted()
            if sorted.count % 2 == 0 {
                self.median = (sorted[sorted.count/2 - 1] + sorted[sorted.count/2]) / 2
            } else {
                self.median = sorted[sorted.count/2]
            }
        }
    }
}

// MARK: - Test Data Factory

/// Factory for creating test data
public struct TestDataFactory {
    
    /// Creates sample audio data
    public static func createAudioData(
        duration: TimeInterval = 1.0,
        sampleRate: Double = 44100.0,
        frequency: Double = 440.0
    ) -> Data {
        let sampleCount = Int(duration * sampleRate)
        var samples = [Float](repeating: 0, count: sampleCount)
        
        for i in 0..<sampleCount {
            let time = Double(i) / sampleRate
            samples[i] = Float(sin(2.0 * .pi * frequency * time))
        }
        
        return samples.withUnsafeBytes { Data($0) }
    }
    
    /// Creates an audio buffer
    public static func createAudioBuffer(
        format: AVAudioFormat,
        duration: TimeInterval = 0.1
    ) -> AVAudioPCMBuffer? {
        let frameCount = AVAudioFrameCount(duration * format.sampleRate)
        
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: frameCount
        ) else {
            return nil
        }
        
        buffer.frameLength = frameCount
        
        // Fill with test data
        if let channelData = buffer.floatChannelData {
            for channel in 0..<Int(format.channelCount) {
                for frame in 0..<Int(frameCount) {
                    let time = Double(frame) / format.sampleRate
                    channelData[channel][frame] = Float(sin(2.0 * .pi * 440.0 * time))
                }
            }
        }
        
        return buffer
    }
    
    /// Creates sample transcription text
    public static func createTranscriptionText(wordCount: Int = 100) -> String {
        let words = [
            "the", "quick", "brown", "fox", "jumps", "over", "lazy", "dog",
            "and", "then", "runs", "through", "forest", "while", "birds", "sing",
            "in", "trees", "above", "creating", "beautiful", "melody", "that", "echoes"
        ]
        
        return (0..<wordCount).map { _ in
            words.randomElement() ?? "word"
        }.joined(separator: " ")
    }
    
    /// Creates a temporary file URL
    public static func createTemporaryFileURL(
        filename: String = "test",
        extension ext: String = "txt"
    ) -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueName = "\(filename)_\(UUID().uuidString).\(ext)"
        return tempDir.appendingPathComponent(uniqueName)
    }
    
    /// Creates test export data
    public static func createExportData() -> ExportData {
        return ExportData(
            transcription: createTranscriptionText(),
            segments: [
                TranscriptionSegment(
                    text: "Test segment one",
                    startTime: 0.0,
                    endTime: 2.0,
                    confidence: 0.95
                ),
                TranscriptionSegment(
                    text: "Test segment two",
                    startTime: 2.0,
                    endTime: 4.0,
                    confidence: 0.92
                )
            ],
            metadata: ExportMetadata(
                createdAt: Date(),
                duration: 4.0,
                wordCount: 5,
                speakerCount: 1
            )
        )
    }
}

// MARK: - Memory Testing Utilities

/// Utilities for testing memory usage and leaks
public struct MemoryTestUtilities {
    
    /// Tracks memory allocations
    public static func trackMemory<T>(
        operation: () async throws -> T
    ) async throws -> (result: T, memoryDelta: Int) {
        let initialMemory = getCurrentMemoryUsage()
        let result = try await operation()
        let finalMemory = getCurrentMemoryUsage()
        
        return (result, finalMemory - initialMemory)
    }
    
    /// Checks for memory leaks
    public static func checkForLeaks(
        _ object: AnyObject,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        addTeardownBlock { [weak object] in
            XCTAssertNil(
                object,
                "Object leaked - strong reference cycle detected",
                file: file,
                line: line
            )
        }
    }
    
    private static func getCurrentMemoryUsage() -> Int {
        var info = mach_task_basic_info()
        var count = mach_msg_type_number_t(MemoryLayout<mach_task_basic_info>.size) / 4
        
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                task_info(
                    mach_task_self_,
                    task_flavor_t(MACH_TASK_BASIC_INFO),
                    $0,
                    &count
                )
            }
        }
        
        return result == KERN_SUCCESS ? Int(info.resident_size) : 0
    }
    
    private static func addTeardownBlock(_ block: @escaping () -> Void) {
        // This would be called in test teardown
        // Implementation depends on test framework integration
    }
}

// MARK: - Concurrency Testing Utilities

/// Utilities for testing concurrent code
public struct ConcurrencyTestUtilities {
    
    /// Tests for data races
    public static func testConcurrentAccess<T>(
        iterations: Int = 100,
        accessors: [(String, () async throws -> T)]
    ) async throws {
        await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<iterations {
                for (name, accessor) in accessors {
                    group.addTask {
                        do {
                            _ = try await accessor()
                        } catch {
                            XCTFail("Concurrent access \(name) failed at iteration \(i): \(error)")
                        }
                    }
                }
            }
            
            try await group.waitForAll()
        }
    }
    
    /// Tests actor isolation
    public static func verifyActorIsolation<T: Actor>(
        _ actor: T,
        operation: @escaping (isolated T) async throws -> Void
    ) async throws {
        // Verify operation runs on actor's executor
        try await operation(actor)
    }
    
    /// Creates concurrent stress test
    public static func stressTest(
        concurrency: Int = 10,
        iterations: Int = 1000,
        operation: @escaping (Int) async throws -> Void
    ) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            for i in 0..<concurrency {
                group.addTask {
                    for j in 0..<iterations {
                        try await operation(i * iterations + j)
                    }
                }
            }
            
            try await group.waitForAll()
        }
    }
}

// MARK: - File System Testing Utilities

/// Utilities for testing file operations
public struct FileSystemTestUtilities {
    
    /// Creates a temporary test directory
    public static func createTestDirectory() throws -> URL {
        let tempDir = FileManager.default.temporaryDirectory
        let testDir = tempDir.appendingPathComponent("VoiceFlowTests_\(UUID().uuidString)")
        
        try FileManager.default.createDirectory(
            at: testDir,
            withIntermediateDirectories: true
        )
        
        return testDir
    }
    
    /// Cleans up test directory
    public static func cleanupTestDirectory(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Creates test file hierarchy
    public static func createTestHierarchy(in directory: URL) throws {
        let subdirs = ["Transcripts", "Exports", "Settings"]
        
        for subdir in subdirs {
            let subdirURL = directory.appendingPathComponent(subdir)
            try FileManager.default.createDirectory(
                at: subdirURL,
                withIntermediateDirectories: true
            )
        }
        
        // Create some test files
        let testContent = "Test content"
        let files = [
            "test.txt",
            "Transcripts/session1.txt",
            "Exports/export1.md"
        ]
        
        for file in files {
            let fileURL = directory.appendingPathComponent(file)
            try testContent.write(to: fileURL, atomically: true, encoding: .utf8)
        }
    }
}

// MARK: - Assertion Helpers

/// Custom assertions for VoiceFlow testing
public struct VoiceFlowAssertions {
    
    /// Asserts transcription quality
    public static func assertTranscriptionQuality(
        _ transcription: String,
        expectedText: String,
        minimumAccuracy: Double = 0.8,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let accuracy = calculateAccuracy(transcription, expected: expectedText)
        
        XCTAssertGreaterThanOrEqual(
            accuracy,
            minimumAccuracy,
            "Transcription accuracy \(accuracy) below minimum \(minimumAccuracy)",
            file: file,
            line: line
        )
    }
    
    /// Asserts export format validity
    public static func assertValidExport(
        _ data: Data,
        format: ExportFormat,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        switch format {
        case .text:
            XCTAssertNotNil(
                String(data: data, encoding: .utf8),
                "Invalid text format",
                file: file,
                line: line
            )
        case .markdown:
            guard let content = String(data: data, encoding: .utf8) else {
                XCTFail("Invalid markdown format", file: file, line: line)
                return
            }
            XCTAssertTrue(
                content.contains("#") || content.contains("*"),
                "Markdown missing formatting",
                file: file,
                line: line
            )
        case .pdf:
            XCTAssertTrue(
                data.starts(with: "%PDF".data(using: .ascii)!),
                "Invalid PDF format",
                file: file,
                line: line
            )
        default:
            break
        }
    }
    
    private static func calculateAccuracy(_ actual: String, expected: String) -> Double {
        let actualWords = actual.lowercased().split(separator: " ")
        let expectedWords = expected.lowercased().split(separator: " ")
        
        let matches = actualWords.filter { expectedWords.contains($0) }.count
        let total = max(actualWords.count, expectedWords.count)
        
        return total > 0 ? Double(matches) / Double(total) : 0.0
    }
}

// MARK: - Test Extensions

extension XCTestCase {
    /// Adds async test support
    public func asyncTest(
        timeout: TimeInterval = 30,
        _ block: @escaping () async throws -> Void
    ) {
        let expectation = expectation(description: "Async test")
        
        Task {
            do {
                try await block()
                expectation.fulfill()
            } catch {
                XCTFail("Async test failed: \(error)")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: timeout)
    }
}