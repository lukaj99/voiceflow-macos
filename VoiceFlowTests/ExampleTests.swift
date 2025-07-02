//
//  ExampleTests.swift
//  VoiceFlowTests
//
//  Example tests demonstrating the testing infrastructure usage
//

import XCTest
import Foundation
@testable import VoiceFlow

/// Example unit tests showing basic mock usage
final class ExampleUnitTests: BaseTestCase {
    
    func test_speechRecognizer_authorization_flow() async throws {
        // Given: Unauthorized recognizer
        await mockSpeechRecognizer.setAuthorizationStatus(.notDetermined)
        
        // When: Request authorization
        let status = await mockSpeechRecognizer.requestAuthorization()
        
        // Then: Should be authorized
        XCTAssertEqual(status, .authorized)
    }
    
    func test_audioEngine_recording_with_interruption() async throws {
        // Given: Running audio engine
        try await mockAudioEngine.start()
        try await mockAudioEngine.startRecording()
        
        // When: Interruption occurs
        var interruptionReceived = false
        await mockAudioEngine.setInterruptionHandler { type in
            if type == .began {
                interruptionReceived = true
            }
        }
        
        await mockAudioEngine.simulateInterruption(.began)
        
        // Then: Recording should stop
        XCTAssertTrue(interruptionReceived)
        XCTAssertFalse(await mockAudioEngine.getIsRecording())
    }
    
    func test_fileSystem_create_and_read_file() async throws {
        // Given: Test content
        let content = "Test file content"
        let data = content.data(using: .utf8)!
        
        // When: Create and read file
        try await mockFileSystem.createFile(at: "/test.txt", contents: data)
        let readData = try await mockFileSystem.readFile(at: "/test.txt")
        
        // Then: Content should match
        XCTAssertEqual(readData, data)
        XCTAssertEqual(String(data: readData, encoding: .utf8), content)
    }
}

/// Example integration tests
final class ExampleIntegrationTests: IntegrationTestCase {
    
    func test_full_transcription_flow() async throws {
        // Given: Prepared mock data
        let expectedText = "Hello world this is a test transcription"
        await simulateTranscriptionData(expectedText)
        
        // When: Run transcription
        let session = try await transcriptionEngine.startTranscription()
        
        // Wait for processing
        try await AsyncTestUtilities.waitFor({
            await self.transcriptionEngine.getActiveSession()?.transcription.isEmpty == false
        }, timeout: 5.0)
        
        let finalSession = try await transcriptionEngine.stopTranscription()
        
        // Then: Verify results
        assertTranscription(
            finalSession.transcription,
            matches: expectedText,
            accuracy: 0.95
        )
    }
    
    func test_export_multiple_formats() async throws {
        // Given: Test transcription data
        let exportData = TestDataFactory.createExportData()
        
        // When: Export to multiple formats
        let formats: [ExportFormat] = [.text, .markdown, .pdf]
        var exports: [URL] = []
        
        for format in formats {
            let url = testDirectory.appendingPathComponent("export.\(format.fileExtension)")
            try await exportManager.export(exportData, to: url, format: format)
            exports.append(url)
        }
        
        // Then: Verify all exports exist
        for url in exports {
            XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))
        }
    }
    
    private func simulateTranscriptionData(_ text: String) async {
        let words = text.split(separator: " ")
        var results: [MockSpeechRecognizer.MockRecognitionResult] = []
        
        for (index, _) in words.enumerated() {
            let partial = words[0...index].joined(separator: " ")
            results.append(
                MockSpeechRecognizer.MockRecognitionResult(
                    transcription: partial,
                    confidence: 0.9,
                    isFinal: index == words.count - 1
                )
            )
        }
        
        await mockSpeechRecognizer.queueResults(results)
    }
}

/// Example performance tests
final class ExamplePerformanceTests: PerformanceTestCase {
    
    override func setUp() async throws {
        try await super.setUp()
        performanceIterations = 50 // Reduced for example
    }
    
    func test_transcription_startup_performance() async throws {
        try await measurePerformance(
            name: "transcription_start",
            baseline: 0.1 // 100ms baseline
        ) {
            let engine = MockTranscriptionEngineFactory.createDefault()
            _ = try await engine.startTranscription()
            try await engine.stopTranscription()
        }
    }
    
    func test_large_file_export_performance() async throws {
        // Given: Large transcription
        let largeText = TestDataFactory.createTranscriptionText(wordCount: 10000)
        let exportData = ExportData(
            transcription: largeText,
            segments: [],
            metadata: ExportMetadata(
                createdAt: Date(),
                duration: 300,
                wordCount: 10000,
                speakerCount: 1
            )
        )
        
        // Measure export performance
        try await measurePerformance(
            name: "large_export",
            baseline: 2.0 // 2 second baseline
        ) {
            let service = MockExportServiceFactory.createDefaultService()
            _ = try await service.export(
                data: exportData,
                format: .pdf,
                to: TestDataFactory.createTemporaryFileURL()
            )
        }
    }
}

/// Example concurrent access tests
final class ExampleConcurrencyTests: BaseTestCase {
    
    func test_settings_concurrent_access() async throws {
        let settings = await MockSettingsServiceFactory.createDefault()
        
        // Test concurrent read/write access
        try await ConcurrencyTestUtilities.testConcurrentAccess(
            iterations: 100,
            accessors: [
                ("read", {
                    _ = try await settings.getString("theme")
                }),
                ("write", {
                    try await settings.set("theme", value: ["dark", "light"].randomElement()!)
                }),
                ("observe", {
                    let id = await settings.observe("theme") { _ in }
                    await settings.removeObserver(id)
                })
            ]
        )
    }
    
    func test_transcription_engine_thread_safety() async throws {
        let engine = MockTranscriptionEngineFactory.createDefault()
        
        // Run multiple operations concurrently
        try await ConcurrencyTestUtilities.stressTest(
            concurrency: 5,
            iterations: 20
        ) { iteration in
            if iteration % 2 == 0 {
                _ = try? await engine.startTranscription()
                try? await Task.sleep(nanoseconds: 10_000_000) // 10ms
                _ = try? await engine.stopTranscription()
            } else {
                _ = await engine.getState()
                _ = await engine.getMetrics()
            }
        }
    }
}

/// Example error handling tests
final class ExampleErrorHandlingTests: BaseTestCase {
    
    func test_handle_speech_recognition_errors() async throws {
        // Test authorization error
        await mockSpeechRecognizer.setAuthorizationStatus(.denied)
        await mockSpeechRecognizer.setNextError(
            MockSpeechRecognizer.MockError.notAuthorized
        )
        
        do {
            _ = try await mockSpeechRecognizer.startRecognition()
            XCTFail("Expected authorization error")
        } catch MockSpeechRecognizer.MockError.notAuthorized {
            // Expected error
        }
        
        // Test network error
        await mockSpeechRecognizer.setAuthorizationStatus(.authorized)
        await mockSpeechRecognizer.setNextError(
            MockSpeechRecognizer.MockError.networkError
        )
        
        do {
            _ = try await mockSpeechRecognizer.startRecognition()
            XCTFail("Expected network error")
        } catch MockSpeechRecognizer.MockError.networkError {
            // Expected error
        }
    }
    
    func test_handle_file_system_errors() async throws {
        // Test disk full error
        await mockFileSystem.setNextError(MockFileSystem.MockError.diskFull)
        
        do {
            try await mockFileSystem.createFile(
                at: "/large_file.txt",
                contents: Data(repeating: 0, count: 1_000_000)
            )
            XCTFail("Expected disk full error")
        } catch MockFileSystem.MockError.diskFull {
            // Expected error
        }
        
        // Test permission error
        await mockFileSystem.setPermissions(
            MockFileSystem.FilePermissions(canRead: true, canWrite: false),
            for: "/protected"
        )
        
        try await mockFileSystem.createDirectory(at: "/protected")
        
        do {
            try await mockFileSystem.createFile(
                at: "/protected/file.txt",
                contents: Data()
            )
            XCTFail("Expected permission error")
        } catch MockFileSystem.MockError.permissionDenied {
            // Expected error
        }
    }
}

/// Example async testing patterns
final class ExampleAsyncTests: BaseTestCase {
    
    func test_async_operation_with_timeout() async throws {
        // Test successful operation within timeout
        try await assertCompletesWithin(2.0) {
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        }
        
        // Test timeout handling
        do {
            try await AsyncTestUtilities.withTimeout(0.5) {
                try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            }
            XCTFail("Expected timeout")
        } catch is AsyncTestUtilities.TimeoutError {
            // Expected timeout
        }
    }
    
    func test_wait_for_condition() async throws {
        var flag = false
        
        // Set flag after delay
        Task {
            try await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
            flag = true
        }
        
        // Wait for flag
        try await AsyncTestUtilities.waitFor({
            flag
        }, timeout: 1.0)
        
        XCTAssertTrue(flag)
    }
}

/// Example memory leak tests
final class ExampleMemoryTests: BaseTestCase {
    
    func test_no_memory_leak_in_transcription_engine() async throws {
        var engine: MockTranscriptionEngine? = MockTranscriptionEngineFactory.createDefault()
        
        // Set up leak detection
        assertNoMemoryLeak(engine!)
        
        // Use engine
        _ = try await engine!.startTranscription()
        try await Task.sleep(nanoseconds: 100_000_000) // 100ms
        _ = try await engine!.stopTranscription()
        
        // Clear reference
        engine = nil
        
        // Engine should be deallocated
    }
    
    func test_memory_usage_tracking() async throws {
        let (_, memoryDelta) = try await MemoryTestUtilities.trackMemory {
            // Allocate some memory
            var data = [Data]()
            for _ in 0..<100 {
                data.append(Data(repeating: 0, count: 10_000))
            }
            return data.count
        }
        
        print("Memory delta: \(memoryDelta) bytes")
        XCTAssertGreaterThan(memoryDelta, 0)
    }
}