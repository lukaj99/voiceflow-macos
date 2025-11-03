# VoiceFlow Developer Guide

## Comprehensive Development Documentation

Complete guide for developing, extending, and contributing to VoiceFlow.

---

## Table of Contents

1. [Development Setup](#development-setup)
2. [Project Structure](#project-structure)
3. [Build and Run](#build-and-run)
4. [Testing](#testing)
5. [Code Style](#code-style)
6. [Adding Features](#adding-features)
7. [Extending Components](#extending-components)
8. [Performance Optimization](#performance-optimization)
9. [Debugging](#debugging)
10. [Contributing](#contributing)

---

## Development Setup

### Prerequisites

Required software and tools for VoiceFlow development.

#### System Requirements

- **macOS**: 14.0 (Sonoma) or later
- **Xcode**: 15.0 or later
- **Swift**: 6.0 or later
- **Memory**: 8GB RAM minimum, 16GB recommended
- **Storage**: 10GB free space

#### Command Line Tools

```bash
# Install Xcode Command Line Tools
xcode-select --install

# Verify installation
swift --version
# Should show: Swift version 6.0 or later
```

#### Swift Package Manager

Already included with Xcode. Verify:

```bash
swift package --version
```

### Cloning the Repository

```bash
# Clone repository
git clone https://github.com/yourusername/voiceflow.git
cd voiceflow

# Create development branch
git checkout -b feature/my-new-feature
```

### Resolving Dependencies

```bash
# Resolve Swift package dependencies
swift package resolve

# Expected output:
# Fetching https://github.com/soffes/HotKey
# Fetching https://github.com/kishikawakatsumi/KeychainAccess
# Fetching https://github.com/apple/swift-async-algorithms
```

### Environment Configuration

#### API Keys for Development

Create `.env` file in project root (git-ignored):

```bash
# .env
DEEPGRAM_API_KEY=your_development_api_key
OPENAI_API_KEY=sk-your_openai_key
ANTHROPIC_API_KEY=sk-ant-your_anthropic_key
```

Load in development:

```swift
// Development only - never in production
if ProcessInfo.processInfo.environment["DEVELOPMENT"] == "true" {
    try await credentialService.configureFromEnvironment()
}
```

#### Xcode Configuration

Open project in Xcode (optional, for App Store builds):

```bash
open VoiceFlow.xcodeproj
```

**Xcode Settings**:
- Build System: New Build System
- Dependency Management: Swift Package Manager
- Signing: Automatic signing (for development)

### Verification

Verify setup is complete:

```bash
# Build project
swift build

# Run tests
swift test

# Run application
swift run
```

If all commands succeed, setup is complete!

---

## Project Structure

### Directory Layout

```
voiceflow/
├── VoiceFlow/                  # Main application code
│   ├── App/                    # App entry point
│   │   └── VoiceFlowApp.swift  # SwiftUI App
│   ├── Core/                   # Core functionality
│   │   ├── AppState.swift      # Global state
│   │   ├── Architecture/       # Architecture components
│   │   ├── ErrorHandling/      # Error management
│   │   ├── Performance/        # Performance tools
│   │   ├── TranscriptionEngine/# Transcription core
│   │   └── Validation/         # Validation framework
│   ├── Features/               # Feature modules
│   │   ├── FloatingWidget/     # Floating window
│   │   ├── MenuBar/            # Menu bar integration
│   │   ├── Settings/           # Settings UI
│   │   └── Transcription/      # Main transcription UI
│   ├── Services/               # Business logic services
│   │   ├── AudioManager.swift  # Audio capture
│   │   ├── Deepgram/           # Deepgram integration
│   │   ├── Export/             # Export functionality
│   │   ├── GlobalHotkeyService.swift
│   │   ├── GlobalTextInputService.swift
│   │   ├── LLMPostProcessingService.swift
│   │   ├── LanguageService.swift
│   │   ├── SecureCredentialService.swift
│   │   └── SettingsService.swift
│   ├── ViewModels/             # MVVM view models
│   │   ├── CredentialManager.swift
│   │   ├── GlobalTextInputCoordinator.swift
│   │   ├── MainTranscriptionViewModel.swift
│   │   ├── SimpleTranscriptionViewModel.swift
│   │   ├── TranscriptionConnectionManager.swift
│   │   ├── TranscriptionCoordinator.swift
│   │   └── TranscriptionTextProcessor.swift
│   ├── Views/                  # SwiftUI views
│   │   ├── APIKeyConfigurationView.swift
│   │   ├── ContentView.swift
│   │   ├── FloatingMicrophoneWidget.swift
│   │   ├── HotkeyConfigurationView.swift
│   │   ├── LLMAPIKeyConfigurationView.swift
│   │   ├── SettingsView.swift
│   │   └── SimpleSettingsView.swift
│   └── Documentation/          # Markdown documentation
│       ├── API_DOCUMENTATION.md
│       ├── ARCHITECTURE.md
│       ├── DEVELOPER_GUIDE.md
│       ├── FEATURE_GUIDE.md
│       └── LLM-Integration-Guide.md
├── VoiceFlowTests/             # Unit and integration tests
│   ├── Unit/                   # Unit tests
│   ├── Integration/            # Integration tests
│   └── Performance/            # Performance tests
├── VoiceFlowUITests/           # UI automation tests
├── Scripts/                    # Build and utility scripts
├── .gitignore                  # Git ignore rules
├── Package.swift               # Swift Package Manager manifest
├── README.md                   # Project README
└── CLAUDE.md                   # Claude Code instructions

```

### Key Files and Their Purposes

#### App Entry Point

**VoiceFlow/App/VoiceFlowApp.swift**
- SwiftUI App definition
- Window configuration
- App lifecycle management
- Menu bar integration

#### Core State

**VoiceFlow/Core/AppState.swift**
- Global application state
- Published properties for UI
- State coordination
- LLM processing state
- Session management

#### Main View Model

**VoiceFlow/ViewModels/SimpleTranscriptionViewModel.swift**
- Primary view model
- Coordinates all services
- Handles user actions
- Manages transcription lifecycle
- Published UI state

#### Main View

**VoiceFlow/Views/ContentView.swift**
- Primary UI implementation
- Transcription display
- Control buttons
- Status indicators
- Settings sheet

#### Audio Management

**VoiceFlow/Services/AudioManager.swift**
- Microphone capture
- Audio processing
- Level monitoring
- Swift 6 actor isolation

#### Deepgram Integration

**VoiceFlow/Services/Deepgram/**
- DeepgramClient.swift: WebSocket client
- DeepgramWebSocket.swift: Connection management
- DeepgramModels.swift: Data models
- DeepgramResponseParser.swift: Response parsing

#### Credential Security

**VoiceFlow/Services/SecureCredentialService.swift**
- Keychain integration
- Secure storage/retrieval
- Validation
- Health checks

#### Export System

**VoiceFlow/Services/Export/**
- ExportManager.swift: Main export logic
- ExportModels.swift: Data models
- PDFExporter.swift: PDF generation

### Module Responsibilities

#### Core Module
- Fundamental types
- Cross-cutting concerns
- No feature-specific logic
- Reusable across app

#### Services Module
- Business logic
- External integrations
- Actor-isolated
- Protocol-based

#### ViewModels Module
- Presentation logic
- UI state transformation
- Service coordination
- MainActor isolated

#### Views Module
- SwiftUI UI components
- User interaction
- Visual feedback
- State observation

---

## Build and Run

### Build Configurations

#### Debug Build

Optimized for development and debugging:

```bash
swift build

# Characteristics:
# - No optimizations (-Onone)
# - Debug symbols included
# - Assertions enabled
# - Fast compilation
# - Slower runtime
```

#### Release Build

Optimized for performance:

```bash
swift build --configuration release

# Characteristics:
# - Full optimizations (-O)
# - Debug symbols stripped
# - Assertions disabled
# - Slower compilation
# - Fast runtime
# - Smaller binary size
```

### Running the Application

#### Command Line

```bash
# Run debug build
swift run

# Run release build
swift run --configuration release

# Run with arguments
swift run -- --verbose

# Run with environment variables
DEVELOPMENT=true swift run
```

#### Xcode

1. Open `VoiceFlow.xcodeproj`
2. Select VoiceFlow scheme
3. Click Run (⌘ + R)

### Build Products Location

```bash
# Debug build
.build/debug/VoiceFlow

# Release build
.build/release/VoiceFlow

# Xcode builds (when using Xcode)
~/Library/Developer/Xcode/DerivedData/VoiceFlow-*/Build/Products/
```

### Clean Build

Remove build artifacts:

```bash
# Swift PM clean
swift package clean

# Remove entire .build directory
rm -rf .build

# Xcode clean (if using Xcode)
xcodebuild clean
```

### Build Performance

#### Parallel Compilation

Swift PM automatically uses all CPU cores:

```bash
# Check core usage during build
swift build --verbose

# Manually specify jobs (rarely needed)
swift build --jobs 8
```

#### Incremental Builds

Only recompile changed files:

```bash
# First build: ~30 seconds
swift build

# Subsequent builds: ~5 seconds
# (only if no changes)

# With changes to one file: ~8 seconds
```

---

## Testing

### Test Structure

```
VoiceFlowTests/
├── Unit/                       # Unit tests (isolated)
│   ├── AudioManagerTests.swift
│   ├── DeepgramClientTests.swift
│   ├── ExportManagerTests.swift
│   ├── SecureCredentialServiceTests.swift
│   └── TranscriptionTextProcessorTests.swift
├── Integration/                # Integration tests (multi-component)
│   ├── TranscriptionWorkflowTests.swift
│   ├── ExportIntegrationTests.swift
│   └── CredentialIntegrationTests.swift
└── Performance/                # Performance benchmarks
    ├── AudioProcessingPerfTests.swift
    ├── TranscriptionPerfTests.swift
    └── ExportPerfTests.swift
```

### Running Tests

#### All Tests

```bash
# Run complete test suite
swift test

# Parallel execution (default)
swift test --parallel

# Serial execution (for debugging)
swift test --no-parallel
```

#### Specific Tests

```bash
# Run specific test class
swift test --filter AudioManagerTests

# Run specific test method
swift test --filter AudioManagerTests.testStartRecording

# Run multiple test classes
swift test --filter "AudioManagerTests|DeepgramClientTests"
```

#### With Coverage

```bash
# Generate code coverage
swift test --enable-code-coverage

# View coverage report
open .build/debug/codecov/
```

### Writing Tests

#### Unit Test Example

```swift
import XCTest
@testable import VoiceFlow

final class AudioManagerTests: XCTestCase {
    var sut: AudioManager!
    var mockAudioEngine: MockAudioEngine!

    override func setUp() async throws {
        try await super.setUp()

        // Create test dependencies
        mockAudioEngine = MockAudioEngine()

        // Create system under test
        sut = AudioManager(audioEngine: mockAudioEngine)
    }

    override func tearDown() async throws {
        // Cleanup
        sut = nil
        mockAudioEngine = nil

        try await super.tearDown()
    }

    func testStartRecording_WhenPermissionGranted_StartsCapture() async throws {
        // Given
        mockAudioEngine.permissionGranted = true

        // When
        try await sut.startRecording()

        // Then
        XCTAssertTrue(sut.isRecording)
        XCTAssertTrue(mockAudioEngine.didStartCapture)
    }

    func testStopRecording_WhenRecording_StopsCapture() {
        // Given
        sut.isRecording = true

        // When
        sut.stopRecording()

        // Then
        XCTAssertFalse(sut.isRecording)
        XCTAssertEqual(sut.audioLevel, 0.0)
    }
}
```

#### Integration Test Example

```swift
final class TranscriptionWorkflowTests: XCTestCase {
    var coordinator: TranscriptionCoordinator!
    var mockServices: MockServiceContainer!

    func testCompleteTranscriptionWorkflow() async throws {
        // Given
        mockServices = MockServiceContainer()
        coordinator = TranscriptionCoordinator(
            appState: TestAppState(),
            audioManager: mockServices.audioManager,
            deepgramClient: mockServices.deepgramClient,
            credentialService: mockServices.credentialService
        )

        // When - Start transcription
        await coordinator.startTranscription()

        // Then - Verify workflow initiated
        XCTAssertTrue(coordinator.isActivelyTranscribing)

        // When - Simulate audio input
        await mockServices.audioManager.simulateAudioInput(
            Data([0x00, 0x01, 0x02])
        )

        // Then - Verify data sent to Deepgram
        XCTAssertTrue(mockServices.deepgramClient.didReceiveAudioData)

        // When - Simulate transcript response
        await mockServices.deepgramClient.simulateTranscript(
            "Hello world",
            isFinal: true
        )

        // Then - Verify transcript processed
        XCTAssertEqual(coordinator.transcriptionText, "Hello world")

        // When - Stop transcription
        coordinator.stopTranscription()

        // Then - Verify cleanup
        XCTAssertFalse(coordinator.isActivelyTranscribing)
    }
}
```

#### Performance Test Example

```swift
final class AudioProcessingPerfTests: XCTestCase {
    func testAudioProcessingLatency() {
        let audioManager = AudioManager()

        measure {
            // Process 1 second of audio
            let audioData = generateTestAudio(duration: 1.0)
            audioManager.process(audioData)
        }

        // Assert latency < 50ms
        XCTAssertLessThan(
            measurementTimeline.averageDuration,
            0.050
        )
    }

    func testMemoryUsage() {
        measure(metrics: [XCTMemoryMetric()]) {
            let audioManager = AudioManager()

            for _ in 0..<1000 {
                let data = generateTestAudio(duration: 0.1)
                audioManager.process(data)
            }
        }

        // Assert memory < 100MB
        XCTAssertLessThan(
            memoryMetric.peakUsage,
            100_000_000
        )
    }
}
```

### Test Doubles

#### Mocks

```swift
class MockDeepgramClient: DeepgramClient {
    var didConnect = false
    var didSendAudioData = false
    var simulatedTranscripts: [(String, Bool)] = []

    override func connect(apiKey: String, autoReconnect: Bool) async {
        didConnect = true
        _connectionState = .connected
    }

    override func sendAudioData(_ data: Data) {
        didSendAudioData = true
    }

    func simulateTranscript(_ text: String, isFinal: Bool) async {
        await delegate?.deepgramClient(self, didReceiveTranscript: text, isFinal: isFinal)
    }
}
```

#### Stubs

```swift
class StubCredentialService: SecureCredentialService {
    var stubbedAPIKey: String?

    override func getDeepgramAPIKey() async throws -> String {
        guard let key = stubbedAPIKey else {
            throw CredentialError.keyNotFound
        }
        return key
    }
}
```

#### Fakes

```swift
class FakeAudioEngine: AudioEngineProtocol {
    private var capturedData: [Data] = []

    func startCapture() {
        // Immediately start providing fake audio
        Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
            self.capturedData.append(self.generateFakeAudio())
        }
    }

    private func generateFakeAudio() -> Data {
        // Generate realistic audio data for testing
        return Data(repeating: 0x00, count: 1024)
    }
}
```

### Test Best Practices

#### 1. Fast Tests

```swift
// ❌ Slow
func testSlowOperation() async {
    await Task.sleep(for: .seconds(5))  // Avoid real delays
}

// ✅ Fast
func testFastOperation() async {
    await mockService.simulateOperation()  // Instant
}
```

#### 2. Isolated Tests

```swift
// ❌ Dependent
func testA() {
    // Modifies global state
    GlobalState.value = 42
}

func testB() {
    // Depends on testA running first
    XCTAssertEqual(GlobalState.value, 42)
}

// ✅ Isolated
func testA() {
    let state = TestState()
    state.value = 42
    // Test-specific state
}

func testB() {
    let state = TestState()
    // Fresh state for each test
}
```

#### 3. Meaningful Names

```swift
// ❌ Unclear
func test1() { }
func testStuff() { }

// ✅ Clear
func testStartRecording_WhenPermissionDenied_ThrowsError() { }
func testExport_WhenFormatIsPDF_GeneratesPDFFile() { }
```

#### 4. Arrange-Act-Assert

```swift
func testExample() {
    // Arrange - Set up test conditions
    let sut = AudioManager()
    let mockEngine = MockAudioEngine()
    sut.audioEngine = mockEngine

    // Act - Perform the action
    try await sut.startRecording()

    // Assert - Verify the outcome
    XCTAssertTrue(sut.isRecording)
    XCTAssertTrue(mockEngine.didStart)
}
```

---

## Code Style

### Swift Style Guide

VoiceFlow follows Swift official style guidelines with project-specific conventions.

#### File Structure

```swift
// 1. Imports (alphabetical)
import AVFoundation
import Combine
import Foundation

// 2. Type definition
public class AudioManager: ObservableObject {

    // 3. MARK: - Types (nested types)
    public enum AudioError: Error {
        case permissionDenied
    }

    // 4. MARK: - Properties
    // 4a. Published properties
    @Published public var isRecording = false

    // 4b. Public properties
    public weak var delegate: AudioManagerDelegate?

    // 4c. Private properties
    private let audioEngine = AVAudioEngine()

    // 5. MARK: - Initialization
    public init() {
        setupAudio()
    }

    // 6. MARK: - Public Methods
    public func startRecording() async throws {
        // Implementation
    }

    // 7. MARK: - Private Methods
    private func setupAudio() {
        // Implementation
    }
}

// 8. MARK: - Extensions
extension AudioManager: AudioDelegate {
    // Protocol conformance
}
```

#### Naming Conventions

**Types**: PascalCase
```swift
class TranscriptionCoordinator { }
struct ExportConfiguration { }
enum DeepgramModel { }
protocol ServiceProtocol { }
```

**Variables and Functions**: camelCase
```swift
var transcriptionText = ""
func startRecording() { }
let audioLevel: Float = 0.0
```

**Constants**: camelCase
```swift
let maxRetryAttempts = 3
let defaultTimeout: TimeInterval = 10.0
```

**Type Aliases**: PascalCase
```swift
typealias TranscriptionHandler = (String) -> Void
```

**Enums**: PascalCase for type, camelCase for cases
```swift
enum ExportFormat {
    case text
    case markdown
    case pdf
}
```

#### Documentation

**Public APIs**: Always documented
```swift
/// Starts audio recording and real-time transcription
///
/// Initiates the complete transcription workflow by connecting to Deepgram,
/// starting microphone capture, and beginning real-time processing.
///
/// - Throws: `AudioError.permissionDenied` if microphone access denied
/// - Note: Requires valid API key configured
public func startRecording() async throws {
    // Implementation
}
```

**Private Methods**: Document complex logic
```swift
/// Processes raw audio buffer using optimized pooling strategy
///
/// Reduces memory allocations by reusing buffers from the pool.
/// Performance-critical path - avoid allocations in this method.
private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
    // Implementation
}
```

#### Swift 6 Concurrency

**MainActor Isolation**:
```swift
// UI-related code
@MainActor
public class ContentView: View {
    // All properties and methods run on main thread
}
```

**Actor Isolation**:
```swift
// Thread-safe services
public actor SecureCredentialService {
    // Automatically serialized access
}
```

**Async/Await**:
```swift
// ❌ Old style
func startRecording(completion: @escaping (Result<Void, Error>) -> Void) {
    // Callback hell
}

// ✅ New style
func startRecording() async throws {
    // Clean async/await
}
```

**Sendable Types**:
```swift
// Mark types that can be safely shared across actors
struct TranscriptionResult: Sendable {
    let text: String
    let confidence: Double
}
```

#### Error Handling

**Typed Errors**:
```swift
enum VoiceFlowError: LocalizedError {
    case audioPermissionDenied
    case apiKeyMissing
    case connectionFailed(Error)

    var errorDescription: String? {
        switch self {
        case .audioPermissionDenied:
            return "Microphone permission required"
        case .apiKeyMissing:
            return "No API key configured"
        case .connectionFailed(let error):
            return "Connection failed: \(error.localizedDescription)"
        }
    }
}
```

**Do-Try-Catch**:
```swift
func performOperation() async {
    do {
        try await riskyOperation()
    } catch VoiceFlowError.audioPermissionDenied {
        // Handle specific error
    } catch {
        // Handle all other errors
    }
}
```

### Code Formatting

#### SwiftLint

Configure SwiftLint for consistent formatting:

```yaml
# .swiftlint.yml
disabled_rules:
  - trailing_whitespace

opt_in_rules:
  - empty_count
  - closure_spacing
  - explicit_init

line_length: 120

identifier_name:
  min_length: 2
  max_length: 50

type_name:
  min_length: 3
  max_length: 40

function_parameter_count:
  warning: 5
  error: 8
```

Install and run:
```bash
# Install SwiftLint
brew install swiftlint

# Run linting
swiftlint

# Auto-fix issues
swiftlint --fix
```

#### SwiftFormat

Automatic code formatting:

```bash
# Install
brew install swiftformat

# Format all files
swiftformat .

# Check without modifying
swiftformat --lint .
```

Configuration (`.swiftformat`):
```
--indent 4
--maxwidth 120
--wraparguments before-first
--wrapcollections before-first
--self insert
--importgrouping testable-bottom
```

---

## Adding Features

### Feature Development Workflow

#### 1. Plan Feature

Define requirements:
- What problem does it solve?
- What are the acceptance criteria?
- What are the edge cases?
- What are the dependencies?

Example: Adding voice commands feature

```
Feature: Voice Commands
Purpose: Control transcription with voice commands
Acceptance Criteria:
- Recognize "start recording" command
- Recognize "stop recording" command
- Recognize "clear text" command
Commands work during transcription
Provides audio feedback
```

#### 2. Design API

Design the public interface:

```swift
/// Voice command recognition service
public actor VoiceCommandService {
    /// Supported voice commands
    public enum Command: String, CaseIterable {
        case startRecording = "start recording"
        case stopRecording = "stop recording"
        case clearText = "clear text"
    }

    /// Enable voice command recognition
    public func enable() async

    /// Disable voice command recognition
    public func disable() async

    /// Process audio for commands
    public func processAudio(_ data: Data) async -> Command?
}
```

#### 3. Implement Core Logic

Start with service implementation:

```swift
public actor VoiceCommandService {
    private var isEnabled = false
    private let commandRecognizer: CommandRecognizer

    public init(recognizer: CommandRecognizer = DefaultCommandRecognizer()) {
        self.commandRecognizer = recognizer
    }

    public func enable() async {
        isEnabled = true
        print("Voice commands enabled")
    }

    public func disable() async {
        isEnabled = false
        print("Voice commands disabled")
    }

    public func processAudio(_ data: Data) async -> Command? {
        guard isEnabled else { return nil }

        let text = await commandRecognizer.recognize(data)

        return Command.allCases.first { command in
            text.lowercased().contains(command.rawValue)
        }
    }
}
```

#### 4. Add Tests

Write comprehensive tests:

```swift
final class VoiceCommandServiceTests: XCTestCase {
    var sut: VoiceCommandService!
    var mockRecognizer: MockCommandRecognizer!

    override func setUp() async throws {
        mockRecognizer = MockCommandRecognizer()
        sut = VoiceCommandService(recognizer: mockRecognizer)
    }

    func testProcessAudio_WhenStartCommandSpoken_ReturnsStartCommand() async {
        // Given
        await sut.enable()
        mockRecognizer.stubbedText = "please start recording now"

        // When
        let command = await sut.processAudio(Data())

        // Then
        XCTAssertEqual(command, .startRecording)
    }

    func testProcessAudio_WhenDisabled_ReturnsNil() async {
        // Given
        await sut.disable()
        mockRecognizer.stubbedText = "start recording"

        // When
        let command = await sut.processAudio(Data())

        // Then
        XCTAssertNil(command)
    }
}
```

#### 5. Integrate with ViewModel

Add to view model:

```swift
@MainActor
public class SimpleTranscriptionViewModel: ObservableObject {
    private let voiceCommandService: VoiceCommandService

    public init(voiceCommandService: VoiceCommandService = VoiceCommandService()) {
        self.voiceCommandService = voiceCommandService
        setupVoiceCommands()
    }

    private func setupVoiceCommands() {
        Task {
            await voiceCommandService.enable()

            // Process audio for commands
            audioManager.$audioData
                .compactMap { $0 }
                .sink { [weak self] data in
                    Task {
                        if let command = await self?.voiceCommandService.processAudio(data) {
                            await self?.handleVoiceCommand(command)
                        }
                    }
                }
                .store(in: &cancellables)
        }
    }

    private func handleVoiceCommand(_ command: VoiceCommandService.Command) async {
        switch command {
        case .startRecording:
            await startRecording()
        case .stopRecording:
            stopRecording()
        case .clearText:
            clearTranscription()
        }
    }
}
```

#### 6. Add UI

Create UI for the feature:

```swift
struct VoiceCommandsView: View {
    @ObservedObject var viewModel: SimpleTranscriptionViewModel
    @State private var voiceCommandsEnabled = false

    var body: some View {
        VStack {
            Toggle("Enable Voice Commands", isOn: $voiceCommandsEnabled)
                .onChange(of: voiceCommandsEnabled) { enabled in
                    if enabled {
                        viewModel.enableVoiceCommands()
                    } else {
                        viewModel.disableVoiceCommands()
                    }
                }

            if voiceCommandsEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Available Commands:")
                        .font(.headline)

                    ForEach(VoiceCommandService.Command.allCases, id: \.self) { command in
                        HStack {
                            Image(systemName: "mic.fill")
                                .foregroundColor(.blue)
                            Text("\"\(command.rawValue)\"")
                                .font(.caption)
                        }
                    }
                }
                .padding()
                .background(Color.blue.opacity(0.1))
                .cornerRadius(8)
            }
        }
    }
}
```

#### 7. Document

Add comprehensive documentation:

```swift
/// Voice command recognition service for hands-free control
///
/// `VoiceCommandService` enables users to control transcription using voice commands.
/// Commands are recognized from the audio stream in real-time and trigger corresponding actions.
///
/// # Supported Commands
/// - "start recording": Begins transcription
/// - "stop recording": Stops transcription
/// - "clear text": Clears current transcription
///
/// # Example
/// ```swift
/// let commandService = VoiceCommandService()
/// await commandService.enable()
///
/// let command = await commandService.processAudio(audioData)
/// if command == .startRecording {
///     await startRecording()
/// }
/// ```
///
/// # Performance
/// - Command recognition: < 100ms latency
/// - Memory usage: < 10MB
/// - CPU impact: < 5% during recognition
///
/// - Note: Requires microphone access
/// - SeeAlso: `SimpleTranscriptionViewModel.enableVoiceCommands()`
public actor VoiceCommandService {
    // Implementation
}
```

#### 8. Update Documentation

Add to user guides:
- Update FEATURE_GUIDE.md with new feature
- Add usage examples
- Document configuration options
- Include troubleshooting

---

## Extending Components

### Custom Export Format

Add support for new export format:

#### 1. Extend ExportFormat Enum

```swift
// VoiceFlow/Services/Export/ExportModels.swift

public enum ExportFormat: String, CaseIterable, Identifiable {
    case text = "txt"
    case markdown = "md"
    case pdf = "pdf"
    case docx = "docx"
    case srt = "srt"
    case json = "json"  // NEW FORMAT

    public var displayName: String {
        switch self {
        case .json: return "JSON"
        // ... existing cases
        }
    }
}
```

#### 2. Implement Export Logic

```swift
// VoiceFlow/Services/Export/JSONExporter.swift

/// Exports transcription to JSON format
public final class JSONExporter {
    /// Export transcription session to JSON
    public func export(session: TranscriptionSession, to url: URL) throws {
        let json: [String: Any] = [
            "transcription": session.transcription,
            "startTime": session.startTime.timeIntervalSince1970,
            "duration": session.duration,
            "wordCount": session.wordCount,
            "averageConfidence": session.averageConfidence,
            "metadata": [
                "version": "1.0",
                "exportDate": Date().timeIntervalSince1970
            ]
        ]

        let data = try JSONSerialization.data(
            withJSONObject: json,
            options: [.prettyPrinted, .sortedKeys]
        )

        try data.write(to: url, options: .atomic)
    }
}
```

#### 3. Integrate with ExportManager

```swift
// VoiceFlow/Services/Export/ExportManager.swift

public final class ExportManager {
    private let jsonExporter = JSONExporter()

    public func exportTranscription(
        session: TranscriptionSession,
        format: ExportFormat,
        to url: URL,
        configuration: ExportConfiguration = ExportConfiguration()
    ) throws -> ExportResult {
        switch format {
        case .json:
            try jsonExporter.export(session: session, to: url)
            return ExportResult(success: true, filePath: url)
        // ... existing formats
        }
    }
}
```

#### 4. Add Tests

```swift
final class JSONExporterTests: XCTestCase {
    func testExport_CreatesValidJSON() throws {
        // Given
        let exporter = JSONExporter()
        let session = TranscriptionSession(
            transcription: "Test",
            startTime: Date(),
            duration: 10.0,
            wordCount: 1,
            averageConfidence: 0.95
        )
        let tempURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("test.json")

        // When
        try exporter.export(session: session, to: tempURL)

        // Then
        XCTAssertTrue(FileManager.default.fileExists(atPath: tempURL.path))

        let data = try Data(contentsOf: tempURL)
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]

        XCTAssertEqual(json?["transcription"] as? String, "Test")
        XCTAssertEqual(json?["wordCount"] as? Int, 1)
    }
}
```

### Custom LLM Provider

Add support for new LLM provider:

#### 1. Extend LLMProvider Enum

```swift
public enum LLMProvider: String, CaseIterable {
    case openAI = "openai"
    case anthropic = "anthropic"
    case google = "google"
    case groq = "groq"
    case custom = "custom"  // NEW PROVIDER

    public var displayName: String {
        switch self {
        case .custom: return "Custom Provider"
        // ... existing cases
        }
    }
}
```

#### 2. Implement Provider Client

```swift
/// Custom LLM provider client
public actor CustomLLMClient {
    private let apiKey: String
    private let baseURL: URL

    public init(apiKey: String, baseURL: URL) {
        self.apiKey = apiKey
        self.baseURL = baseURL
    }

    public func processText(_ text: String, context: String) async throws -> String {
        var request = URLRequest(url: baseURL.appendingPathComponent("/v1/process"))
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "text": text,
            "context": context
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw LLMError.requestFailed
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let processedText = json["processedText"] as? String else {
            throw LLMError.invalidResponse
        }

        return processedText
    }
}
```

#### 3. Integrate with LLMPostProcessingService

```swift
public class LLMPostProcessingService {
    private var customClient: CustomLLMClient?

    public func configureCustomProvider(apiKey: String, baseURL: URL) {
        customClient = CustomLLMClient(apiKey: apiKey, baseURL: baseURL)
    }

    public func processTranscription(_ text: String, context: String) async -> Result<ProcessingResult, Error> {
        // ... existing provider handling

        if selectedProvider == .custom {
            guard let client = customClient else {
                return .failure(LLMError.notConfigured)
            }

            do {
                let processed = try await client.processText(text, context: context)
                return .success(ProcessingResult(processedText: processed))
            } catch {
                return .failure(error)
            }
        }

        // ... existing provider handling
    }
}
```

---

## Performance Optimization

### Profiling

#### Time Profiler

Use Instruments to profile performance:

```bash
# Build with release configuration
swift build --configuration release

# Profile with Instruments
open -a Instruments .build/release/VoiceFlow
```

**What to look for**:
- Hot paths (functions taking most time)
- Unexpected allocations
- Thread contention
- Blocking operations

#### Allocations Instrument

Track memory allocations:

```bash
# Look for:
# - High allocation rate
# - Memory leaks
# - Retain cycles
# - Excessive copying
```

#### System Trace

Analyze system-level performance:

```bash
# View:
# - Thread usage
# - Context switches
# - System calls
# - I/O operations
```

### Common Optimizations

#### 1. Buffer Pooling

Reduce allocations in audio processing:

```swift
// ❌ Before: New allocation every time
func processAudio(_ data: Data) {
    let buffer = AVAudioPCMBuffer(...)  // Allocation
    // Process buffer
}

// ✅ After: Reuse buffers
private let bufferPool = AudioBufferPool()

func processAudio(_ data: Data) {
    let buffer = bufferPool.acquire()  // Reuse
    defer { bufferPool.release(buffer) }
    // Process buffer
}

// Result: 60% fewer allocations
```

#### 2. Async Processing

Don't block main thread:

```swift
// ❌ Before: Blocks UI
func exportTranscription() {
    let result = try exportManager.export(...)  // Slow, blocks
    updateUI(result)
}

// ✅ After: Async
func exportTranscription() async {
    Task {
        let result = try await exportManager.export(...)
        await MainActor.run {
            updateUI(result)
        }
    }
}

// Result: Smooth UI during export
```

#### 3. Lazy Loading

Load only when needed:

```swift
// ❌ Before: Load everything upfront
class SettingsManager {
    let allSettings = loadAllSettings()  // Slow startup
}

// ✅ After: Load on demand
class SettingsManager {
    private var cachedSettings: Settings?

    func getSettings() -> Settings {
        if let cached = cachedSettings {
            return cached
        }

        let settings = loadAllSettings()
        cachedSettings = settings
        return settings
    }
}

// Result: Faster app launch
```

#### 4. Batch Operations

Group operations together:

```swift
// ❌ Before: One at a time
for transcript in transcripts {
    try await llmService.process(transcript)
}

// ✅ After: Batch processing
try await llmService.processBatch(transcripts)

// Result: Lower overhead, faster overall
```

#### 5. Caching

Cache expensive computations:

```swift
// ❌ Before: Recalculate every time
func getDomainScore(_ text: String) -> Double {
    return calculateComplexScore(text)  // Expensive
}

// ✅ After: Cache results
private var scoreCache: [String: Double] = [:]

func getDomainScore(_ text: String) -> Double {
    if let cached = scoreCache[text] {
        return cached
    }

    let score = calculateComplexScore(text)
    scoreCache[text] = score
    return score
}

// Result: Instant repeated calls
```

### Performance Targets

```
Audio Latency:        < 50ms
Transcription Latency: < 300ms
LLM Processing:       < 2s
Export Time:          < 1s for 10k words
Memory Usage:         < 200MB
Launch Time:          < 2s
CPU Usage (idle):     < 2%
CPU Usage (active):   < 30%
```

---

## Debugging

### Xcode Debugging

#### Breakpoints

Set breakpoints in code:

```swift
func startRecording() async {
    // Set breakpoint here
    let apiKey = try await credentialService.getDeepgramAPIKey()

    // Inspect apiKey value when breakpoint hits
}
```

**Conditional Breakpoints**:
```
Right-click breakpoint → Edit Breakpoint
Condition: errorMessage != nil
Action: Log message: Error occurred: @(errorMessage)@
```

#### LLDB Commands

```bash
# Print variable
(lldb) po transcriptionText

# Print expression
(lldb) p audioLevel > 0.5

# Continue execution
(lldb) c

# Step over
(lldb) n

# Step into
(lldb) s

# Step out
(lldb) finish
```

### Print Debugging

Strategic logging:

```swift
// ❌ Too much logging
print("Function called")
print("Variable: \(x)")
print("Done")

// ✅ Strategic logging
print("🎯 Starting transcription with model: \(selectedModel)")
print("✅ Connected to Deepgram in \(connectionTime)s")
print("❌ Connection failed: \(error.localizedDescription)")
```

### os_log

Structured logging:

```swift
import os.log

let logger = Logger(subsystem: "com.voiceflow.app", category: "transcription")

// Levels: debug, info, notice, error, fault
logger.debug("Audio level: \(audioLevel)")
logger.info("Transcription started")
logger.error("Failed to connect: \(error.localizedDescription)")
```

View logs in Console.app:
```
Filter: subsystem:com.voiceflow.app
```

### Memory Debugging

#### Detect Leaks

```bash
# Run with leak detection
leaks --atExit -- .build/debug/VoiceFlow
```

#### Memory Graph

In Xcode:
1. Run app
2. Click Debug Memory Graph button
3. Look for retain cycles
4. Inspect strong references

### Network Debugging

#### Charles Proxy

Intercept WebSocket traffic:

```bash
# Install Charles
brew install --cask charles

# Configure system proxy
# Run VoiceFlow
# View WebSocket frames in Charles
```

#### Wireshark

Low-level packet inspection:

```bash
# Install Wireshark
brew install --cask wireshark

# Capture on loopback interface
# Filter: tcp.port == 443
# Inspect SSL/TLS handshake
```

---

## Contributing

### Contribution Process

#### 1. Fork Repository

```bash
# Fork on GitHub
# Clone your fork
git clone https://github.com/your-username/voiceflow.git
cd voiceflow

# Add upstream remote
git remote add upstream https://github.com/original/voiceflow.git
```

#### 2. Create Feature Branch

```bash
# Create branch
git checkout -b feature/my-awesome-feature

# Or for bug fixes
git checkout -b fix/issue-123
```

#### 3. Make Changes

Follow these guidelines:
- Write clean, documented code
- Add tests for new functionality
- Update documentation
- Follow code style guide
- Keep commits focused and atomic

#### 4. Test Thoroughly

```bash
# Run all tests
swift test

# Run linting
swiftlint

# Format code
swiftformat .

# Build release
swift build --configuration release
```

#### 5. Commit Changes

Write good commit messages:

```bash
# ✅ Good commit message
git commit -m "Add voice commands feature

Implements voice command recognition for hands-free control.
Users can now say 'start recording', 'stop recording', or
'clear text' to control transcription.

- Add VoiceCommandService
- Integrate with SimpleTranscriptionViewModel
- Add UI toggle for voice commands
- Include comprehensive tests
- Update documentation

Fixes #123"

# ❌ Bad commit message
git commit -m "stuff"
```

#### 6. Push to Fork

```bash
git push origin feature/my-awesome-feature
```

#### 7. Create Pull Request

On GitHub:
1. Navigate to your fork
2. Click "New Pull Request"
3. Select your feature branch
4. Fill out PR template
5. Submit for review

### Pull Request Template

```markdown
## Description
Brief description of changes

## Type of Change
- [ ] Bug fix
- [ ] New feature
- [ ] Performance improvement
- [ ] Documentation update

## Testing
- [ ] Unit tests added/updated
- [ ] Integration tests added/updated
- [ ] Manual testing performed

## Checklist
- [ ] Code follows style guidelines
- [ ] Documentation updated
- [ ] Tests pass
- [ ] No breaking changes

## Screenshots (if applicable)
Add screenshots here

## Related Issues
Fixes #123
```

### Code Review

Expect reviews to check:
- Code quality and style
- Test coverage
- Documentation completeness
- Performance impact
- Security implications
- Backward compatibility

### Merge Process

1. PR submitted
2. Automated checks run (tests, linting)
3. Code review by maintainers
4. Address feedback
5. Approval from maintainer
6. Squash and merge to main
7. Delete feature branch

---

## Best Practices Summary

### Development

1. ✅ Use Swift 6 concurrency patterns
2. ✅ Write tests first (TDD)
3. ✅ Document all public APIs
4. ✅ Follow code style guide
5. ✅ Keep functions small and focused
6. ✅ Use dependency injection
7. ✅ Profile before optimizing
8. ✅ Handle errors gracefully

### Testing

1. ✅ Fast, isolated tests
2. ✅ Mock external dependencies
3. ✅ Test edge cases
4. ✅ Maintain >80% coverage
5. ✅ Use meaningful test names
6. ✅ Test behavior, not implementation

### Performance

1. ✅ Profile with Instruments
2. ✅ Use buffer pooling
3. ✅ Async for I/O operations
4. ✅ Lazy load when possible
5. ✅ Cache expensive operations
6. ✅ Measure, don't guess

### Security

1. ✅ Store secrets in Keychain
2. ✅ Never log credentials
3. ✅ Use secure network protocols
4. ✅ Validate all inputs
5. ✅ Follow least privilege principle

---

## Conclusion

This guide provides comprehensive information for developing VoiceFlow. For specific questions or issues:

1. Check existing documentation
2. Search closed issues on GitHub
3. Ask in discussions
4. Open new issue if needed

Happy coding! 🎉
