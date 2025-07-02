//
//  BaseTestCase.swift
//  VoiceFlowTests
//
//  Base test case class with common setup and utilities
//

import XCTest
import Foundation
@testable import VoiceFlow

/// Base test case providing common functionality for all VoiceFlow tests
open class BaseTestCase: XCTestCase {
    
    // MARK: - Properties
    
    /// Temporary directory for test files
    private(set) var testDirectory: URL!
    
    /// Mock speech recognizer
    private(set) var mockSpeechRecognizer: MockSpeechRecognizer!
    
    /// Mock audio engine
    private(set) var mockAudioEngine: MockAudioEngine!
    
    /// Mock file system
    private(set) var mockFileSystem: MockFileSystem!
    
    /// Test start time for performance tracking
    private var testStartTime: Date!
    
    /// Collected performance metrics
    private var performanceMetrics: [String: TimeInterval] = [:]
    
    // MARK: - Setup & Teardown
    
    override open func setUp() async throws {
        try await super.setUp()
        
        testStartTime = Date()
        
        // Create test directory
        testDirectory = try FileSystemTestUtilities.createTestDirectory()
        
        // Initialize mocks
        mockSpeechRecognizer = MockSpeechRecognizer()
        mockAudioEngine = MockAudioEngine()
        mockFileSystem = MockFileSystem()
        
        // Configure default mock behavior
        await configureMocks()
        
        // Set up test environment
        await setupTestEnvironment()
    }
    
    override open func tearDown() async throws {
        // Record test duration
        let testDuration = Date().timeIntervalSince(testStartTime)
        performanceMetrics["total_duration"] = testDuration
        
        // Clean up
        await cleanupMocks()
        
        // Remove test directory
        FileSystemTestUtilities.cleanupTestDirectory(testDirectory)
        
        // Report performance if needed
        if !performanceMetrics.isEmpty {
            reportPerformanceMetrics()
        }
        
        try await super.tearDown()
    }
    
    // MARK: - Mock Configuration
    
    /// Configures default mock behavior
    private func configureMocks() async {
        // Configure speech recognizer
        await mockSpeechRecognizer.setAuthorizationStatus(.authorized)
        await mockSpeechRecognizer.setAvailability(true)
        await mockSpeechRecognizer.setSimulationDelay(0.01)
        
        // Configure audio engine
        await mockAudioEngine.setSimulatedAudioLevel(0.5)
        
        // Configure file system
        await mockFileSystem.setIODelay(0.001)
    }
    
    /// Cleans up mocks after test
    private func cleanupMocks() async {
        await mockSpeechRecognizer.stopAllTasks()
        await mockAudioEngine.stop()
        await mockFileSystem.reset()
    }
    
    // MARK: - Test Environment
    
    /// Sets up the test environment
    private func setupTestEnvironment() async {
        // Set test-specific environment variables
        ProcessInfo.processInfo.setValue("true", forKey: "VOICEFLOW_TESTING")
        
        // Create test file hierarchy
        try? await mockFileSystem.createTestHierarchy()
    }
    
    // MARK: - Test Helpers
    
    /// Waits for an expectation with custom timeout
    public func waitForExpectation(
        timeout: TimeInterval = 5.0,
        handler: XCWaitCompletionHandler? = nil
    ) {
        waitForExpectations(timeout: timeout, handler: handler)
    }
    
    /// Runs an async test with timeout
    public func runAsyncTest(
        timeout: TimeInterval = 10.0,
        test: @escaping () async throws -> Void
    ) async throws {
        try await AsyncTestUtilities.withTimeout(timeout) {
            try await test()
        }
    }
    
    /// Measures async operation performance
    public func measureAsyncPerformance(
        name: String,
        iterations: Int = 10,
        operation: @escaping () async throws -> Void
    ) async throws {
        let metrics = try await AsyncTestUtilities.measureAsync(
            iterations: iterations,
            operation: operation
        )
        
        performanceMetrics[name] = metrics.average
        
        print("""
        Performance Test: \(name)
        Average: \(metrics.average)s
        Min: \(metrics.min)s
        Max: \(metrics.max)s
        Median: \(metrics.median)s
        """)
    }
    
    // MARK: - Mock Helpers
    
    /// Creates a mock transcription session
    public func createMockTranscriptionSession() async -> TranscriptionSession {
        let session = TranscriptionSession(
            id: UUID(),
            startTime: Date(),
            endTime: nil,
            transcription: "",
            segments: [],
            metadata: SessionMetadata()
        )
        
        return session
    }
    
    /// Simulates a complete transcription flow
    public func simulateTranscription(
        text: String,
        duration: TimeInterval = 5.0
    ) async throws {
        // Start audio engine
        try await mockAudioEngine.start()
        
        // Queue recognition results
        let words = text.split(separator: " ")
        var accumulatedText = ""
        
        for (index, word) in words.enumerated() {
            accumulatedText += (accumulatedText.isEmpty ? "" : " ") + String(word)
            
            await mockSpeechRecognizer.queueResult(
                MockSpeechRecognizer.MockRecognitionResult(
                    transcription: accumulatedText,
                    confidence: 0.9,
                    isFinal: index == words.count - 1
                )
            )
        }
        
        // Start recognition
        _ = try await mockSpeechRecognizer.startRecognition()
        
        // Simulate recording
        await mockAudioEngine.simulateRecording(duration: duration)
    }
    
    // MARK: - Assertion Helpers
    
    /// Asserts that an async operation completes within timeout
    public func assertCompletesWithin(
        _ timeout: TimeInterval,
        operation: @escaping () async throws -> Void,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            try await AsyncTestUtilities.withTimeout(timeout, operation: operation)
        } catch {
            XCTFail(
                "Operation did not complete within \(timeout) seconds",
                file: file,
                line: line
            )
        }
    }
    
    /// Asserts no memory leaks for an object
    public func assertNoMemoryLeak(
        _ object: AnyObject,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        addTeardownBlock { [weak object] in
            XCTAssertNil(
                object,
                "Memory leak detected - object not deallocated",
                file: file,
                line: line
            )
        }
    }
    
    /// Asserts transcription matches expected text
    public func assertTranscription(
        _ actual: String,
        matches expected: String,
        accuracy: Double = 0.8,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        VoiceFlowAssertions.assertTranscriptionQuality(
            actual,
            expectedText: expected,
            minimumAccuracy: accuracy,
            file: file,
            line: line
        )
    }
    
    // MARK: - Performance Reporting
    
    private func reportPerformanceMetrics() {
        guard !performanceMetrics.isEmpty else { return }
        
        print("\n=== Performance Metrics ===")
        for (metric, value) in performanceMetrics.sorted(by: { $0.key < $1.key }) {
            print("\(metric): \(String(format: "%.3f", value))s")
        }
        print("========================\n")
    }
}

// MARK: - Integration Test Base

/// Base class for integration tests
open class IntegrationTestCase: BaseTestCase {
    
    // Real components for integration testing
    private(set) var transcriptionEngine: TranscriptionEngine!
    private(set) var exportManager: ExportManager!
    private(set) var sessionStorage: SessionStorageService!
    
    override open func setUp() async throws {
        try await super.setUp()
        
        // Initialize real components with mocks
        await setupIntegrationComponents()
    }
    
    private func setupIntegrationComponents() async {
        // Create transcription engine with mocks
        transcriptionEngine = await TranscriptionEngine(
            speechRecognizer: mockSpeechRecognizer,
            audioEngine: mockAudioEngine
        )
        
        // Create export manager
        exportManager = ExportManager()
        
        // Create session storage
        sessionStorage = SessionStorageService(
            storageDirectory: testDirectory
        )
    }
}

// MARK: - Performance Test Base

/// Base class for performance tests
open class PerformanceTestCase: BaseTestCase {
    
    /// Number of iterations for performance tests
    public var performanceIterations: Int = 100
    
    /// Performance baseline values
    private let performanceBaselines: [String: TimeInterval] = [
        "transcription_start": 0.1,
        "export_pdf": 1.0,
        "session_save": 0.05,
        "audio_processing": 0.01
    ]
    
    /// Measures performance against baseline
    public func measurePerformance(
        name: String,
        baseline: TimeInterval? = nil,
        operation: @escaping () async throws -> Void
    ) async throws {
        let effectiveBaseline = baseline ?? performanceBaselines[name] ?? 1.0
        
        try await measureAsyncPerformance(
            name: name,
            iterations: performanceIterations,
            operation: operation
        )
        
        if let measuredTime = performanceMetrics[name] {
            XCTAssertLessThanOrEqual(
                measuredTime,
                effectiveBaseline * 1.2, // Allow 20% variance
                "\(name) performance (\(measuredTime)s) exceeds baseline (\(effectiveBaseline)s)"
            )
        }
    }
}

// MARK: - UI Test Base

/// Base class for UI-related tests
open class UITestCase: BaseTestCase {
    
    /// Main run loop for UI testing
    private var runLoop: RunLoop!
    
    override open func setUp() async throws {
        try await super.setUp()
        
        // Set up run loop for UI testing
        runLoop = RunLoop.current
    }
    
    /// Processes pending UI events
    public func processUIEvents() {
        runLoop.run(until: Date().addingTimeInterval(0.1))
    }
    
    /// Waits for UI to update
    public func waitForUIUpdate(timeout: TimeInterval = 1.0) async {
        try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
        processUIEvents()
    }
}