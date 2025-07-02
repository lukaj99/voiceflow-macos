# VoiceFlow Testing Patterns

This document describes the testing infrastructure and patterns for VoiceFlow tests.

## Testing Infrastructure Overview

The VoiceFlow test suite provides a comprehensive testing framework with:

1. **Base Test Classes**: Common setup and utilities for all tests
2. **Mock Framework**: Thread-safe mocks for all external dependencies
3. **Test Utilities**: Helpers for async testing, performance measurement, and assertions
4. **Test Data Factories**: Consistent test data generation

## Base Test Classes

### BaseTestCase

The foundation for all VoiceFlow tests:

```swift
class MyTest: BaseTestCase {
    func testExample() async throws {
        // Mocks are automatically initialized
        await mockSpeechRecognizer.queueResult(...)
        
        // Use async test helpers
        try await runAsyncTest {
            // Your test code
        }
    }
}
```

### IntegrationTestCase

For testing component integration:

```swift
class TranscriptionIntegrationTest: IntegrationTestCase {
    func testFullTranscriptionFlow() async throws {
        // Real components with mock dependencies
        let result = try await transcriptionEngine.startTranscription()
        assertTranscription(result.text, matches: "expected text")
    }
}
```

### PerformanceTestCase

For performance testing:

```swift
class ExportPerformanceTest: PerformanceTestCase {
    func testPDFExportPerformance() async throws {
        try await measurePerformance(name: "pdf_export") {
            // Export operation
        }
    }
}
```

## Mock Framework

### MockSpeechRecognizer

```swift
// Basic usage
await mockSpeechRecognizer.setAuthorizationStatus(.authorized)
await mockSpeechRecognizer.queueResult(
    MockSpeechRecognizer.MockRecognitionResult(
        transcription: "Hello world",
        confidence: 0.95,
        isFinal: true
    )
)

// Simulate real-time transcription
await mockSpeechRecognizer.simulateRealTimeTranscription(
    phrases: ["Hello", "world", "this", "is", "a", "test"],
    intervalSeconds: 0.5
)

// Test error conditions
await mockSpeechRecognizer.setNextError(MockSpeechRecognizer.MockError.notAuthorized)
```

### MockAudioEngine

```swift
// Start and configure
try await mockAudioEngine.start()
await mockAudioEngine.setSimulatedAudioLevel(0.7)

// Simulate recording
try await mockAudioEngine.startRecording()
await mockAudioEngine.simulateRecording(duration: 5.0)

// Test interruptions
await mockAudioEngine.simulateInterruption(.began)
```

### MockFileSystem

```swift
// Create test files
try await mockFileSystem.createFile(
    at: "/test.txt",
    contents: "Test content".data(using: .utf8)!
)

// Test directory operations
try await mockFileSystem.createDirectory(at: "/TestDir")
let files = try await mockFileSystem.listDirectory(at: "/")

// Test error conditions
await mockFileSystem.setNextError(MockFileSystem.MockError.diskFull)
```

### MockExportService

```swift
// Export with specific format
let record = try await mockExportService.export(
    data: testData,
    format: .pdf,
    to: destinationURL
)

// Batch export
let records = try await mockExportService.batchExport(
    data: testData,
    formats: [.text, .markdown, .pdf],
    to: exportDirectory
)
```

### MockSettingsService

```swift
// Set and get settings
try await mockSettingsService.set("theme", value: "dark")
let theme = try await mockSettingsService.getString("theme")

// Observe changes
let observerId = await mockSettingsService.observe("theme") { newValue in
    print("Theme changed to: \(newValue)")
}
```

## Testing Patterns

### Testing Async Operations

```swift
func testAsyncOperation() async throws {
    // Use timeout wrapper
    try await AsyncTestUtilities.withTimeout(5.0) {
        let result = await someAsyncOperation()
        XCTAssertEqual(result, expected)
    }
    
    // Wait for condition
    try await AsyncTestUtilities.waitFor({
        await someCondition()
    }, timeout: 10.0)
}
```

### Testing Concurrent Access

```swift
func testConcurrentSafety() async throws {
    try await ConcurrencyTestUtilities.testConcurrentAccess(
        iterations: 100,
        accessors: [
            ("read", { await service.getValue() }),
            ("write", { await service.setValue(42) })
        ]
    )
}
```

### Testing Memory Leaks

```swift
func testNoMemoryLeak() async throws {
    let service = MyService()
    
    // Set up leak detection
    assertNoMemoryLeak(service)
    
    // Use service
    await service.performOperations()
    
    // Service should be deallocated after test
}
```

### Testing Performance

```swift
func testPerformance() async throws {
    try await measureAsyncPerformance(
        name: "operation_performance",
        iterations: 100
    ) {
        await performOperation()
    }
}
```

## Test Data Generation

### Audio Data

```swift
// Generate test audio
let audioData = TestDataFactory.createAudioData(
    duration: 5.0,
    sampleRate: 44100,
    frequency: 440
)

// Create audio buffer
let format = AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 44100, channels: 1, interleaved: false)!
let buffer = TestDataFactory.createAudioBuffer(format: format, duration: 0.1)
```

### Transcription Data

```swift
// Generate transcription text
let text = TestDataFactory.createTranscriptionText(wordCount: 100)

// Create export data
let exportData = TestDataFactory.createExportData()
```

## Best Practices

### 1. Use Appropriate Base Class

Choose the right base class for your test type:
- `BaseTestCase`: Unit tests
- `IntegrationTestCase`: Integration tests
- `PerformanceTestCase`: Performance tests
- `UITestCase`: UI-related tests

### 2. Configure Mocks Properly

```swift
override func setUp() async throws {
    try await super.setUp()
    
    // Configure test-specific behavior
    await mockSpeechRecognizer.setSimulationDelay(0.001)
    await mockAudioEngine.setSimulatedAudioLevel(0.8)
}
```

### 3. Test Error Conditions

```swift
func testErrorHandling() async throws {
    // Set up error condition
    await mockService.setNextError(CustomError.networkFailure)
    
    // Verify error handling
    do {
        try await service.performOperation()
        XCTFail("Expected error")
    } catch CustomError.networkFailure {
        // Expected
    }
}
```

### 4. Clean Up Resources

```swift
override func tearDown() async throws {
    // Clean up test-specific resources
    await mockService.reset()
    
    // Base class handles common cleanup
    try await super.tearDown()
}
```

### 5. Use Descriptive Test Names

```swift
func test_transcriptionEngine_whenAudioLevelLow_shouldAdjustSensitivity() async throws {
    // Test implementation
}
```

## Running Tests

### Run All Tests
```bash
swift test
```

### Run Specific Test
```bash
swift test --filter TestClassName/testMethodName
```

### Run with Coverage
```bash
swift test --enable-code-coverage
```

### Run in Parallel
```bash
swift test --parallel
```

## Debugging Tests

### Enable Verbose Output
```swift
// In test method
print("Debug: Current state = \(await service.getState())")
```

### Use Breakpoints with Async
- Set breakpoints inside async closures
- Use `po await variable` in debugger

### Check Mock State
```swift
// Verify mock was called correctly
let count = await mockService.getCallCount("methodName")
XCTAssertEqual(count, 1)
```

## Coverage Goals

Target coverage by component:
- Core functionality: 90%+
- Services: 85%+
- UI components: 70%+
- Export system: 90%+
- Error handling: 95%+

Use the test infrastructure to achieve comprehensive coverage while maintaining fast, reliable tests.