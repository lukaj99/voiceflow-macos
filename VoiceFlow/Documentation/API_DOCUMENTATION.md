# VoiceFlow API Documentation

## Overview

VoiceFlow is a professional macOS voice transcription application built with Swift 6, featuring real-time speech-to-text powered by Deepgram's API, secure credential management, and advanced features like LLM post-processing and global text input.

This document provides comprehensive API documentation for all major components, classes, and protocols in the VoiceFlow codebase.

---

## Table of Contents

1. [Core Architecture](#core-architecture)
2. [View Models](#view-models)
3. [Services](#services)
4. [Core Components](#core-components)
5. [Export System](#export-system)
6. [Error Handling](#error-handling)
7. [Performance Monitoring](#performance-monitoring)
8. [Validation Framework](#validation-framework)

---

## Core Architecture

### AppState

**Purpose**: Central application state management with SwiftUI integration

**Type**: `@MainActor public class AppState: ObservableObject`

**Key Responsibilities**:
- Manages global application state
- Coordinates transcription sessions
- Handles LLM processing state
- Provides state observation for UI updates

**Published Properties**:
```swift
@Published public var isTranscribing: Bool
@Published public var currentTranscription: String
@Published public var audioLevel: Float
@Published public var connectionStatus: ConnectionStatus
@Published public var isConfigured: Bool
@Published public var errorMessage: String?
@Published public var llmPostProcessingEnabled: Bool
@Published public var hasLLMProvidersConfigured: Bool
@Published public var isLLMProcessing: Bool
@Published public var llmProcessingProgress: Float
@Published public var llmProcessingError: String?
```

**Key Methods**:

#### `startTranscriptionSession()`
Begins a new transcription session with state initialization.

**Usage**:
```swift
appState.startTranscriptionSession()
```

**State Changes**:
- `isTranscribing` → true
- `currentTranscription` → ""
- Session ID generated
- Start time recorded

---

#### `updateTranscription(_ text: String, isFinal: Bool)`
Updates the current transcription with new text.

**Parameters**:
- `text`: The transcription text to add
- `isFinal`: Whether this is a final transcript (true) or interim (false)

**Usage**:
```swift
appState.updateTranscription("Hello world", isFinal: true)
```

**Behavior**:
- Final transcripts are appended to `currentTranscription`
- Interim transcripts update temporary state
- Word count and statistics are updated

---

#### `setConnectionStatus(_ status: ConnectionStatus)`
Updates the connection status for UI display.

**Parameters**:
- `status`: The new connection status enum value

**Possible Status Values**:
- `.disconnected`
- `.connecting`
- `.connected`
- `.reconnecting`
- `.error`

---

#### `enableLLMPostProcessing()`
Enables LLM-based transcription enhancement.

**Requirements**:
- At least one LLM provider must be configured
- Valid API key for the selected provider

**Effects**:
- `llmPostProcessingEnabled` → true
- Future transcriptions will be enhanced with LLM
- Processing statistics begin tracking

---

#### `setLLMProcessing(_ processing: Bool, progress: Float)`
Updates LLM processing state and progress.

**Parameters**:
- `processing`: Whether LLM is currently processing
- `progress`: Progress value (0.0 to 1.0)

**Usage**:
```swift
appState.setLLMProcessing(true, progress: 0.5)  // 50% complete
```

---

## View Models

### SimpleTranscriptionViewModel

**Purpose**: Primary view model for the transcription interface

**Type**: `@MainActor public class SimpleTranscriptionViewModel: ObservableObject`

**Architecture**: Coordinates multiple services using dependency injection and follows MVVM pattern with Combine for reactive updates.

**Services Used**:
- `AudioManager` - Audio capture and processing
- `DeepgramClient` - Deepgram API communication
- `SecureCredentialService` - Keychain-based credential storage
- `GlobalTextInputService` - System-wide text insertion

**Published Properties**:
```swift
@Published public var transcriptionText: String        // Accumulated transcription
@Published public var isRecording: Bool                // Recording status
@Published public var audioLevel: Float               // Current audio level (0.0-1.0)
@Published public var connectionStatus: String        // Connection state display
@Published public var errorMessage: String?           // Error messages
@Published public var isConfigured: Bool              // Credentials configured
@Published public var globalInputEnabled: Bool        // Global input mode
@Published public var selectedModel: DeepgramModel    // Current AI model
```

---

#### `init()`
Initializes the view model with all dependencies.

**Process**:
1. Creates service instances
2. Sets up Combine bindings
3. Configures delegates
4. Initiates async credential initialization

**Example**:
```swift
let viewModel = SimpleTranscriptionViewModel()
// Automatically attempts to load credentials from environment or keychain
```

---

#### `startRecording() async`
Starts audio recording and real-time transcription.

**Async**: Must be called with `await`

**Preconditions**:
- `isConfigured` must be `true`
- Valid Deepgram API key stored in keychain

**Process Flow**:
1. Validates credentials are configured
2. Retrieves API key from secure keychain
3. Validates API key format
4. Connects to Deepgram WebSocket (with 10-second timeout)
5. Starts microphone audio capture
6. Begins processing audio data

**State Changes**:
- `isRecording` → true
- `transcriptionText` → "" (cleared)
- `errorMessage` → nil (if successful)
- `hasInsertedGlobalText` → false (reset)

**Error Handling**:
Sets `errorMessage` with descriptive error if:
- Credentials not configured
- Invalid API key format
- Connection timeout (>10 seconds)
- Deepgram service unavailable
- Microphone access denied

**Performance**:
- Connection time: 1-3 seconds typically
- Timeout: 10 seconds maximum
- Audio latency: ~50ms

**Example**:
```swift
if viewModel.isConfigured {
    await viewModel.startRecording()
    // Now receiving real-time transcriptions
}
```

---

#### `stopRecording()`
Stops audio recording and disconnects from transcription service.

**Synchronous**: No await required

**Process**:
1. Stops microphone audio capture
2. Disconnects Deepgram WebSocket
3. Resets UI state indicators
4. Preserves transcription text

**State Changes**:
- `isRecording` → false
- `audioLevel` → 0.0
- `connectionStatus` → "Disconnected"
- `hasInsertedGlobalText` → false

**Note**: Transcribed text is NOT cleared. Use `clearTranscription()` to reset.

**Example**:
```swift
viewModel.stopRecording()
// Can now export or review transcription
```

---

#### `clearTranscription()`
Clears all transcribed text and resets the view.

**Process**:
1. Empties `transcriptionText`
2. Clears `errorMessage`
3. Resets global input session tracking

**Preserved State** (NOT affected):
- Connection status
- API configuration
- Recording state
- Selected model
- Global input mode

**Example**:
```swift
viewModel.clearTranscription()
// Ready for new transcription session
```

---

#### `reconfigureCredentials(newAPIKey: String?) async`
Updates stored API credentials.

**Parameters**:
- `newAPIKey`: Optional API key. If nil, loads from environment variable `DEEPGRAM_API_KEY`

**Async**: Must be called with `await`

**Process**:
1. Stores new key in keychain (if provided) OR loads from environment
2. Validates credential format
3. Updates `isConfigured` status
4. Clears or sets error message

**Security**:
- Keys stored only in macOS Keychain
- Never logged in plain text
- Automatic cleanup on failure

**Example**:
```swift
// From user input
await viewModel.reconfigureCredentials(newAPIKey: "your-api-key")

// From environment
await viewModel.reconfigureCredentials()
```

---

#### `enableGlobalInputMode()`
Enables system-wide text insertion of transcriptions.

**Requirements**:
- macOS Accessibility permissions granted

**Process**:
1. Requests Accessibility permissions (if needed)
2. Checks permission status after 0.5-second delay
3. Enables mode if permissions granted
4. Sets error if permissions denied

**Permissions**:
User must grant permissions in:
**System Settings > Privacy & Security > Accessibility**

**State Changes**:
- `globalInputEnabled` → true (if permissions granted)
- `errorMessage` → set if permissions denied

**Example**:
```swift
viewModel.enableGlobalInputMode()
// Transcriptions will now be inserted into focused text fields
```

---

#### `setModel(_ model: DeepgramModel)`
Changes the active Deepgram transcription model.

**Parameters**:
- `model`: The DeepgramModel enum value to use

**Available Models**:
- `.general` - General-purpose transcription
- `.medical` - Optimized for medical terminology
- `.enhanced` - Enhanced accuracy model
- `.meeting` - Optimized for meetings
- `.phonecall` - Optimized for phone calls

**Example**:
```swift
viewModel.setModel(.medical)
// Now using medical terminology model
```

---

#### `checkCredentialStatus() async`
Validates the currently stored credentials.

**Async**: Requires await

**Process**:
1. Checks if API key exists in keychain
2. Retrieves key (if present)
3. Validates key format
4. Updates `isConfigured` status
5. Sets error message if invalid

**Example**:
```swift
await viewModel.checkCredentialStatus()
if viewModel.isConfigured {
    print("Credentials valid!")
}
```

---

#### `performHealthCheck() async -> Bool`
Performs a comprehensive system health check.

**Returns**: `true` if all systems healthy, `false` otherwise

**Checks**:
- Keychain accessibility
- Credential storage/retrieval
- Service permissions

**Example**:
```swift
let isHealthy = await viewModel.performHealthCheck()
if !isHealthy {
    print("System issue detected: \(viewModel.errorMessage ?? "Unknown")")
}
```

---

### MainTranscriptionViewModel

**Purpose**: Advanced view model with full feature set and service coordination

**Type**: `@MainActor public class MainTranscriptionViewModel: ObservableObject`

**Additional Features** (vs SimpleTranscriptionViewModel):
- Full LLM integration
- Processing statistics
- Advanced model selection
- Health monitoring

**Additional Services**:
- `TranscriptionCoordinator` - High-level workflow coordination
- `CredentialManager` - Advanced credential management
- `GlobalTextInputCoordinator` - Enhanced global input
- `TranscriptionTextProcessor` - LLM post-processing

**Extended API**:

#### `getProcessingStatistics() async -> TranscriptionProcessingStatistics`
Retrieves processing statistics including domain detection counts.

**Returns**: Statistics object with:
- `totalTextsProcessed`
- `medicalTextsDetected`
- `technicalTextsDetected`
- `legalTextsDetected`
- `financialTextsDetected`
- `generalTextsDetected`

---

#### `getGlobalInputStatistics() -> InsertionStatistics`
Gets global text insertion statistics.

**Returns**: Statistics including:
- Total insertions
- Successful insertions
- Failed insertions
- Success rate
- Last insertion time

---

### TranscriptionCoordinator

**Purpose**: Orchestrates the complete transcription workflow

**Type**: `@MainActor public class TranscriptionCoordinator: ObservableObject`

**Responsibilities**:
- Coordinates audio, Deepgram, and UI state
- Manages connection lifecycle
- Handles transcript processing
- Delegates audio and transcription events

**Key Methods**:

#### `startTranscription() async`
Starts the complete transcription workflow.

**Process**:
1. Validates app configuration
2. Retrieves API credentials
3. Establishes Deepgram connection
4. Starts audio recording
5. Begins transcript processing

---

#### `pauseTranscription()`
Pauses audio capture while maintaining connection.

**Use Case**: Temporarily stop transcribing without disconnecting

---

#### `resumeTranscription()`
Resumes audio capture and transcription.

**Use Case**: Continue after pause

---

## Services

### AudioManager

**Purpose**: Manages microphone input and audio processing

**Type**: `@MainActor public class AudioManager: ObservableObject`

**Architecture**: Uses Swift 6 actor isolation for thread-safe audio processing

**Components**:
- Main actor for UI state (`isRecording`, `audioLevel`)
- Dedicated `AudioProcessingActor` for audio processing
- Async streams for audio level updates

**Delegate Protocol**:
```swift
public protocol AudioManagerDelegate: AnyObject {
    func audioManager(_ manager: AudioManager, didReceiveAudioData data: Data)
}
```

**Key Methods**:

#### `startRecording() async throws`
Starts microphone recording.

**Throws**: `AudioError` if microphone unavailable

**Process**:
1. Checks not already recording
2. Requests microphone permissions (if needed)
3. Configures audio session
4. Starts audio capture
5. Begins streaming to delegate

---

#### `stopRecording()`
Stops microphone recording and releases audio resources.

---

#### `pauseRecording()`
Pauses audio capture without releasing resources.

---

#### `resumeRecording()`
Resumes paused audio capture.

---

### SecureCredentialService

**Purpose**: Secure storage and retrieval of API credentials

**Type**: `public actor SecureCredentialService`

**Security Features**:
- macOS Keychain integration
- Encrypted storage
- Automatic permission handling
- Validation before storage

**Supported Credentials**:
- Deepgram API key
- LLM provider API keys (OpenAI, Anthropic, etc.)

**Key Methods**:

#### `storeDeepgramAPIKey(_ key: String) async throws`
Securely stores Deepgram API key in keychain.

**Parameters**:
- `key`: The API key to store

**Throws**: `CredentialError` if storage fails

**Validation**: Checks key format before storing

---

#### `getDeepgramAPIKey() async throws -> String`
Retrieves stored Deepgram API key.

**Returns**: The API key string

**Throws**: `CredentialError` if key not found

---

#### `hasDeepgramAPIKey() async -> Bool`
Checks if Deepgram API key is stored.

**Returns**: `true` if key exists, `false` otherwise

---

#### `validateCredential(_ credential: String, for type: CredentialType) async -> Bool`
Validates credential format.

**Parameters**:
- `credential`: The credential to validate
- `type`: The credential type

**Returns**: `true` if valid format, `false` otherwise

---

#### `performHealthCheck() async -> Bool`
Checks keychain accessibility.

**Returns**: `true` if keychain is accessible, `false` otherwise

---

#### `configureFromEnvironment() async throws`
Loads credentials from environment variables.

**Environment Variables**:
- `DEEPGRAM_API_KEY` - Deepgram API key

**Throws**: `CredentialError` if variables not found

---

### GlobalTextInputService

**Purpose**: System-wide text insertion using Accessibility API

**Type**: `public actor GlobalTextInputService`

**Requirements**:
- macOS Accessibility permissions
- Focused text field in any application

**Key Methods**:

#### `insertText(_ text: String) async -> InsertionResult`
Inserts text into the currently focused text field.

**Parameters**:
- `text`: The text to insert

**Returns**: `InsertionResult` enum:
- `.success` - Text inserted successfully
- `.accessibilityDenied` - Permissions not granted
- `.noActiveTextField` - No text field focused
- `.insertionFailed(Error)` - Insertion failed with error

**Example**:
```swift
let result = await globalTextInput.insertText("Hello")
switch result {
case .success:
    print("Inserted successfully")
case .accessibilityDenied:
    print("Need permissions")
case .noActiveTextField:
    print("No text field focused")
case .insertionFailed(let error):
    print("Error: \(error)")
}
```

---

#### `requestAccessibilityPermissions()`
Opens System Settings to grant Accessibility permissions.

**Note**: Asynchronous - permissions dialog appears

---

#### `checkAccessibilityPermissions()`
Checks current permission status.

**Updates**: Internal `hasAccessibilityPermissions` property

---

### LLMPostProcessingService

**Purpose**: LLM-based enhancement of transcriptions

**Type**: `@MainActor public class LLMPostProcessingService: ObservableObject`

**Supported Providers**:
- OpenAI (GPT-4, GPT-3.5)
- Anthropic (Claude)
- Google (Gemini)
- Groq

**Features**:
- Grammar correction
- Punctuation enhancement
- Capitalization fixes
- Terminology standardization
- Context-aware improvements

**Key Methods**:

#### `processTranscription(_ text: String, context: String) async -> Result<ProcessingResult, Error>`
Processes transcription with LLM enhancement.

**Parameters**:
- `text`: Raw transcription text
- `context`: Domain context (medical, technical, etc.)

**Returns**: Result with `ProcessingResult` containing:
- `processedText` - Enhanced text
- `changes` - List of improvements made
- `improvementScore` - Quality improvement metric (0.0-1.0)

**Example**:
```swift
let result = await llmService.processTranscription(
    "hello doctor i have a headache",
    context: "Medical context"
)

switch result {
case .success(let processed):
    print(processed.processedText)
    // "Hello, Doctor. I have a headache."
case .failure(let error):
    print("LLM processing failed: \(error)")
}
```

---

#### `configureAPIKey(_ key: String, for provider: LLMProvider)`
Configures API key for an LLM provider.

**Parameters**:
- `key`: The API key
- `provider`: The LLM provider enum value

---

#### `isConfigured(for provider: LLMProvider) -> Bool`
Checks if a provider is configured.

**Returns**: `true` if API key is set for the provider

---

### ExportManager

**Purpose**: Multi-format transcription export

**Type**: `public final class ExportManager`

**Supported Formats**:
- Plain text (`.txt`)
- Markdown (`.md`)
- PDF (`.pdf`)
- Microsoft Word (`.docx`)
- SRT subtitles (`.srt`)

**Key Methods**:

#### `exportTranscription(session:format:to:configuration:) throws -> ExportResult`
Exports transcription to specified format.

**Parameters**:
- `session`: `TranscriptionSession` with data to export
- `format`: `ExportFormat` enum value
- `to`: File URL for output
- `configuration`: Optional `ExportConfiguration`

**Returns**: `ExportResult` with success status and metadata

**Throws**: File I/O errors

**Example**:
```swift
let session = TranscriptionSession(
    transcription: "Hello world",
    startTime: Date(),
    duration: 10.0,
    wordCount: 2,
    averageConfidence: 0.95
)

let result = try exportManager.exportTranscription(
    session: session,
    format: .markdown,
    to: URL(fileURLWithPath: "/path/to/export.md"),
    configuration: ExportConfiguration(includeMetadata: true)
)

print("Exported to: \(result.filePath?.path ?? "unknown")")
```

---

## Core Components

### TranscriptionTextProcessor

**Purpose**: Text processing, domain detection, and LLM enhancement

**Type**: `public actor TranscriptionTextProcessor`

**Features**:
- Medical terminology detection
- Technical jargon identification
- Legal term recognition
- Financial terminology detection
- Automatic model suggestion
- LLM integration

**Key Methods**:

#### `processTranscript(_ text: String, isFinal: Bool) async -> String`
Processes and enhances transcript text.

**Parameters**:
- `text`: Raw transcript
- `isFinal`: Whether this is a final transcript

**Returns**: Processed and potentially LLM-enhanced text

**Processing Steps**:
1. Text cleaning and normalization
2. Domain detection
3. Statistics update
4. LLM processing (if enabled and final)

---

#### `analyzeAndSuggestModel(_ text: String) async -> ProcessingResult`
Analyzes text and suggests optimal model.

**Parameters**:
- `text`: Text to analyze

**Returns**: `ProcessingResult` containing:
- Cleaned text
- Detected domain
- Confidence score
- Suggested model (if confidence > 0.7)

**Domains Detected**:
- Medical
- Technical
- Legal
- Financial
- General

---

#### `configureLLMService(provider:model:apiKey:) async`
Configures LLM service for post-processing.

**Parameters**:
- `provider`: LLM provider enum
- `model`: Model name string
- `apiKey`: API key for the provider

---

#### `enableLLMProcessing() async`
Enables LLM-based text enhancement.

---

#### `disableLLMProcessing() async`
Disables LLM-based text enhancement.

---

#### `getLLMStatistics() async -> LLMProcessingStatistics`
Retrieves LLM processing statistics.

**Returns**: Statistics including:
- Total processed
- Success rate
- Average processing time
- Average improvement score

---

### CredentialManager

**Purpose**: Advanced credential lifecycle management

**Type**: `@MainActor public class CredentialManager: ObservableObject`

**Features**:
- Comprehensive validation
- Health monitoring
- Automatic retry
- Error recovery

**Published Properties**:
```swift
@Published public var isConfigured: Bool
@Published public var validationStatus: ValidationStatus
@Published public var healthStatus: HealthStatus
@Published public var configurationError: String?
```

**Validation Statuses**:
- `.unknown` - Not yet validated
- `.valid` - Credentials validated
- `.invalid(String)` - Invalid with error message
- `.validating` - Validation in progress

**Health Statuses**:
- `.unknown` - Not yet checked
- `.healthy` - All systems operational
- `.unhealthy(String)` - Issue detected with description
- `.checking` - Health check in progress

**Key Methods**:

#### `configureAPIKey(_ apiKey: String) async`
Comprehensive API key configuration.

**Process**:
1. Validates key format
2. Stores in keychain
3. Validates stored key
4. Updates configuration status
5. Performs health check

---

#### `validateStoredCredentials() async`
Validates currently stored credentials.

**Process**:
1. Checks if credentials exist
2. Retrieves credentials
3. Validates format
4. Updates validation status
5. Updates configuration status

---

#### `performHealthCheck() async`
Comprehensive system health check.

**Checks**:
- Keychain accessibility
- Credential integrity
- Service connectivity

---

#### `removeCredentials() async`
Removes all stored credentials.

**Process**:
1. Deletes from keychain
2. Resets configuration status
3. Clears validation status
4. Updates UI state

---

## Export System

### ExportFormat

**Type**: `public enum ExportFormat: String, CaseIterable`

**Cases**:
- `.text` - Plain text format
- `.markdown` - Markdown format
- `.pdf` - PDF document
- `.docx` - Word document
- `.srt` - SRT subtitles

**Properties**:
```swift
var displayName: String     // User-friendly name
var fileExtension: String   // File extension (without dot)
```

---

### ExportConfiguration

**Type**: `public struct ExportConfiguration`

**Properties**:
```swift
let includeTimestamps: Bool  // Include timestamp data
let includeMetadata: Bool    // Include session metadata
```

**Defaults**: Both properties default to `true`

---

### ExportResult

**Type**: `public struct ExportResult`

**Properties**:
```swift
let success: Bool           // Operation success status
let filePath: URL?         // Output file location
let error: Error?          // Error if failed
let metadata: [String: Any] // Export metadata
```

---

## Error Handling

### VoiceFlowError

**Type**: `public enum VoiceFlowError: LocalizedError`

**Cases**:
- `.audioPermissionDenied` - Microphone access denied
- `.apiKeyMissing` - No API key configured
- `.apiKeyInvalid` - Invalid API key format
- `.connectionFailed` - Network connection failed
- `.transcriptionFailed` - Transcription service error
- `.exportFailed` - Export operation failed
- `.keychainAccessDenied` - Keychain access denied

**Protocol**: Conforms to `LocalizedError` for user-friendly descriptions

---

### ErrorRecoveryManager

**Purpose**: Automatic error recovery and retry logic

**Type**: `public actor ErrorRecoveryManager`

**Features**:
- Automatic retry with exponential backoff
- Error classification
- Recovery strategy selection
- Statistics tracking

**Key Methods**:

#### `attemptRecovery(from error: Error, using strategy: RecoveryStrategy) async -> RecoveryResult`
Attempts to recover from an error.

**Parameters**:
- `error`: The error to recover from
- `strategy`: Recovery strategy to use

**Returns**: `RecoveryResult` indicating success or failure

**Recovery Strategies**:
- `.retry` - Simple retry
- `.reconnect` - Reconnect and retry
- `.reconfigure` - Reconfigure and retry
- `.manual` - Requires manual intervention

---

## Performance Monitoring

### PerformanceMonitor

**Purpose**: Real-time performance tracking

**Type**: `public actor PerformanceMonitor`

**Metrics Tracked**:
- Audio processing latency
- Transcription latency
- Memory usage
- CPU usage
- Network bandwidth

**Key Methods**:

#### `startMonitoring()`
Begins performance monitoring.

---

#### `getMetrics() async -> PerformanceMetrics`
Retrieves current performance metrics.

---

#### `getReport() async -> String`
Generates formatted performance report.

---

### MetricsCollector

**Purpose**: Collects and aggregates performance metrics

**Type**: `public actor MetricsCollector`

**Features**:
- Real-time metric collection
- Statistical aggregation
- Trend analysis
- Export capabilities

---

## Validation Framework

### ValidationFramework

**Purpose**: Comprehensive validation for all inputs

**Type**: `public actor ValidationFramework`

**Validation Types**:
- API key format validation
- File path validation
- Text content validation
- Configuration validation

**Key Methods**:

#### `validateAPIKey(_ key: String) async -> ValidationResult`
Validates API key format.

**Returns**: `ValidationResult` with:
- `isValid` - Whether key is valid
- `errors` - Array of validation errors

---

#### `validateConfiguration(_ config: Configuration) async -> ValidationResult`
Validates application configuration.

**Parameters**:
- `config`: Configuration object to validate

**Returns**: Validation result with any errors

---

## Usage Examples

### Complete Workflow Example

```swift
// 1. Initialize view model
let viewModel = SimpleTranscriptionViewModel()

// 2. Configure credentials
await viewModel.reconfigureCredentials(newAPIKey: "your-api-key")

// 3. Check configuration status
await viewModel.checkCredentialStatus()
guard viewModel.isConfigured else {
    print("Configuration required")
    return
}

// 4. Start recording
await viewModel.startRecording()

// 5. Enable global input (optional)
viewModel.enableGlobalInputMode()

// 6. Change model if needed
viewModel.setModel(.medical)

// 7. Stop when done
viewModel.stopRecording()

// 8. Export transcription
let exportManager = ExportManager()
let session = TranscriptionSession(
    transcription: viewModel.transcriptionText,
    startTime: Date(),
    duration: 60.0,
    wordCount: 100,
    averageConfidence: 0.95
)

let result = try exportManager.exportTranscription(
    session: session,
    format: .markdown,
    to: URL(fileURLWithPath: "/path/to/output.md")
)

print("Exported: \(result.success)")
```

---

### LLM Post-Processing Example

```swift
// 1. Configure LLM service
let textProcessor = await TranscriptionTextProcessor.createDefault()
await textProcessor.configureLLMService(
    provider: .openAI,
    model: "gpt-4",
    apiKey: "your-openai-key"
)

// 2. Enable LLM processing
await textProcessor.enableLLMProcessing()

// 3. Process will happen automatically during transcription
// Final transcripts will be enhanced with:
// - Proper punctuation
// - Correct capitalization
// - Grammar fixes
// - Domain-specific terminology

// 4. Get statistics
let stats = await textProcessor.getLLMStatistics()
print("Success rate: \(stats.successRate)")
print("Average improvement: \(stats.averageImprovementScore)")
```

---

### Error Handling Example

```swift
do {
    await viewModel.startRecording()
} catch {
    switch error {
    case VoiceFlowError.audioPermissionDenied:
        print("Please grant microphone permission")
    case VoiceFlowError.apiKeyMissing:
        print("Configure API key first")
    case VoiceFlowError.connectionFailed:
        print("Check network connection")
    default:
        print("Error: \(error.localizedDescription)")
    }
}
```

---

## Best Practices

### Security
1. Always store API keys in Keychain
2. Never log credentials in plain text
3. Validate all user inputs
4. Use secure network connections (WSS/HTTPS)

### Performance
1. Use audio buffer pooling for memory efficiency
2. Process audio asynchronously
3. Batch export operations when possible
4. Monitor memory usage with PerformanceMonitor

### Error Handling
1. Always check `isConfigured` before operations
2. Handle all async errors with try/catch
3. Provide user-friendly error messages
4. Log errors for debugging

### Concurrency
1. Respect `@MainActor` isolation
2. Use `async/await` for all I/O operations
3. Avoid blocking the main thread
4. Use actors for shared mutable state

---

## Version Information

- **Swift Version**: 6.0
- **Minimum macOS**: 14.0
- **Architecture**: Universal (Apple Silicon + Intel)
- **Concurrency Model**: Swift 6 strict concurrency

---

## Support

For issues, feature requests, or contributions, please refer to the project repository.
