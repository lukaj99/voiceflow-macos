# VoiceFlow Feature Guide

## Complete Feature Documentation

This comprehensive guide covers all features in VoiceFlow, including usage examples, best practices, and advanced configurations.

---

## Table of Contents

1. [Real-Time Voice Transcription](#real-time-voice-transcription)
2. [Multiple AI Models](#multiple-ai-models)
3. [LLM Post-Processing](#llm-post-processing)
4. [Global Text Input Mode](#global-text-input-mode)
5. [Multi-Format Export](#multi-format-export)
6. [Secure Credential Management](#secure-credential-management)
7. [Medical Terminology Detection](#medical-terminology-detection)
8. [Performance Monitoring](#performance-monitoring)
9. [Error Recovery](#error-recovery)
10. [Keyboard Shortcuts](#keyboard-shortcuts)
11. [Settings Management](#settings-management)
12. [Advanced Features](#advanced-features)

---

## Real-Time Voice Transcription

### Overview

VoiceFlow provides high-quality, low-latency voice transcription using Deepgram's streaming API. Transcriptions appear in real-time as you speak, with both interim and final results displayed.

### Key Features

- **Real-time processing**: See transcriptions as you speak
- **Interim results**: Preview what's being transcribed
- **Final results**: Accurate, finalized transcription text
- **Low latency**: Typically 100-300ms from speech to text
- **High accuracy**: 95%+ accuracy for general speech
- **Speaker adaptation**: Improves accuracy over time

### Usage

#### Basic Transcription

```swift
// 1. Initialize view model
let viewModel = SimpleTranscriptionViewModel()

// 2. Configure API key (one-time setup)
await viewModel.reconfigureCredentials(newAPIKey: "your-deepgram-api-key")

// 3. Start transcription
await viewModel.startRecording()

// 4. Speak into your microphone
// Transcriptions appear in viewModel.transcriptionText

// 5. Stop when done
viewModel.stopRecording()

// 6. Access your transcription
print(viewModel.transcriptionText)
```

#### UI Integration

```swift
struct TranscriptionView: View {
    @StateObject private var viewModel = SimpleTranscriptionViewModel()

    var body: some View {
        VStack {
            // Display transcription
            ScrollView {
                Text(viewModel.transcriptionText)
                    .textSelection(.enabled)
            }

            // Audio level indicator
            ProgressView(value: viewModel.audioLevel)

            // Controls
            HStack {
                Button(viewModel.isRecording ? "Stop" : "Start") {
                    Task {
                        if viewModel.isRecording {
                            viewModel.stopRecording()
                        } else {
                            await viewModel.startRecording()
                        }
                    }
                }

                Button("Clear") {
                    viewModel.clearTranscription()
                }
            }
        }
    }
}
```

### Advanced Configuration

#### Custom Audio Settings

```swift
let audioManager = AudioManager()

// Configure audio quality
audioManager.setSampleRate(16000)  // 16kHz for speech
audioManager.setChannelCount(1)    // Mono audio
audioManager.setBitDepth(16)       // 16-bit PCM
```

#### Connection Management

```swift
let connectionManager = TranscriptionConnectionManager()

// Get connection metrics
let metrics = await connectionManager.getConnectionMetrics()
print("Success rate: \(metrics.successRate)")
print("Average connection time: \(metrics.averageConnectionTime)s")

// Check connection health
let isHealthy = await connectionManager.checkConnectionHealth(client: deepgramClient)
```

### Troubleshooting

#### No Audio Detected

**Problem**: Audio level stays at 0.0

**Solutions**:
1. Check microphone permissions in System Settings
2. Verify correct microphone selected
3. Test microphone in another app
4. Restart audio engine

```swift
// Check microphone permission
let hasPermission = await audioManager.checkMicrophonePermission()
if !hasPermission {
    await audioManager.requestMicrophonePermission()
}
```

#### Connection Timeout

**Problem**: Connection fails after 10 seconds

**Solutions**:
1. Check network connectivity
2. Verify API key is valid
3. Check Deepgram service status
4. Try different network (VPN, cellular)

```swift
// Test with manual connection
let client = DeepgramClient()
do {
    try await client.testConnection(apiKey: "your-key")
    print("Connection successful")
} catch {
    print("Connection failed: \(error)")
}
```

#### Poor Transcription Quality

**Problem**: Transcriptions have many errors

**Solutions**:
1. Reduce background noise
2. Speak clearly and at normal pace
3. Use better microphone
4. Try enhanced model
5. Check microphone positioning

```swift
// Switch to enhanced model
viewModel.setModel(.enhanced)
```

---

## Multiple AI Models

### Available Models

VoiceFlow supports multiple Deepgram models optimized for different use cases:

#### 1. General Model (Default)

**Best for**: Everyday transcription, conversations, notes

**Characteristics**:
- Balanced accuracy and speed
- General vocabulary
- Good for most use cases
- Fast processing
- Lower cost

**Usage**:
```swift
viewModel.setModel(.general)
```

#### 2. Medical Model

**Best for**: Medical dictation, healthcare notes, clinical documentation

**Characteristics**:
- Medical terminology optimized
- Anatomy, procedures, medications
- Drug names and dosages
- Clinical abbreviations
- Higher accuracy for medical terms

**Specialized Vocabulary**:
- Anatomical terms (heart, lung, etc.)
- Medical conditions (diabetes, hypertension, etc.)
- Procedures (MRI, endoscopy, etc.)
- Medications (insulin, aspirin, etc.)

**Usage**:
```swift
viewModel.setModel(.medical)
```

**Automatic Switching**:
```swift
// VoiceFlow automatically detects medical terminology
// and suggests switching to medical model

// Medical terms detected: "patient", "diagnosis", "symptoms"
// Suggestion: Switch to medical model for better accuracy
```

#### 3. Enhanced Model

**Best for**: High-accuracy needs, professional transcription, legal/technical documents

**Characteristics**:
- Highest accuracy
- Better punctuation
- Improved capitalization
- Complex vocabulary
- Slower processing
- Higher cost

**Usage**:
```swift
viewModel.setModel(.enhanced)
```

#### 4. Meeting Model

**Best for**: Conference calls, team meetings, presentations

**Characteristics**:
- Optimized for multiple speakers
- Good with accents
- Background noise handling
- Clear speaker separation
- Meeting-specific vocabulary

**Usage**:
```swift
viewModel.setModel(.meeting)
```

#### 5. Phone Call Model

**Best for**: Phone conversations, voicemail, recordings

**Characteristics**:
- Telephony-optimized
- 8kHz audio support
- Compression-tolerant
- Call-specific vocabulary
- Good with poor quality audio

**Usage**:
```swift
viewModel.setModel(.phonecall)
```

### Model Comparison

| Model     | Accuracy | Speed    | Cost    | Best For                      |
|-----------|----------|----------|---------|-------------------------------|
| General   | Good     | Fast     | Low     | Everyday use                  |
| Medical   | Excellent| Medium   | Medium  | Healthcare                    |
| Enhanced  | Excellent| Slower   | Higher  | Professional transcription    |
| Meeting   | Good     | Fast     | Medium  | Multi-speaker conversations   |
| Phone Call| Good     | Fast     | Low     | Phone recordings              |

### Model Selection Best Practices

#### 1. Start with General

Begin with the general model and switch if needed:

```swift
// Start with general
viewModel.setModel(.general)

// Monitor for domain-specific terms
let stats = await textProcessor.getProcessingStatistics()

// Switch based on detection
if stats.medicalTextsDetected > 5 {
    viewModel.setModel(.medical)
}
```

#### 2. Use Domain Detection

Enable automatic model suggestion:

```swift
let processor = TranscriptionTextProcessor()
let result = await processor.analyzeAndSuggestModel(transcriptionText)

if let suggestedModel = result.suggestedModel {
    print("Suggested model: \(suggestedModel.displayName)")
    print("Confidence: \(result.confidence)")

    // Apply suggestion if confidence > 70%
    if result.confidence > 0.7 {
        viewModel.setModel(suggestedModel)
    }
}
```

#### 3. User Override

Always allow users to manually select:

```swift
// Provide model picker in UI
Picker("Model", selection: $viewModel.selectedModel) {
    ForEach(DeepgramModel.allCases) { model in
        Text(model.displayName).tag(model)
    }
}
```

### Model Performance

#### Latency Comparison

```
General:    100-200ms average
Medical:    150-250ms average
Enhanced:   200-300ms average
Meeting:    100-200ms average
Phone Call: 100-200ms average
```

#### Accuracy Benchmark

```
General (Clean Speech):     94-96%
Medical (Medical Terms):    97-99%
Enhanced (All Contexts):    96-98%
Meeting (Multi-speaker):    92-95%
Phone Call (Phone Audio):   90-94%
```

---

## LLM Post-Processing

### Overview

LLM post-processing enhances transcriptions using large language models like GPT-4, Claude, or Gemini. This adds punctuation, fixes grammar, corrects capitalization, and standardizes terminology.

### Supported LLM Providers

#### OpenAI

**Models**: GPT-4, GPT-3.5-turbo

**Configuration**:
```swift
let llmService = LLMPostProcessingService()
llmService.configureAPIKey("sk-...", for: .openAI)
llmService.selectedModel = .gpt4
```

**Best For**:
- General enhancement
- Creative text
- Conversational content

#### Anthropic (Claude)

**Models**: Claude 3 Opus, Claude 3 Sonnet

**Configuration**:
```swift
llmService.configureAPIKey("sk-ant-...", for: .anthropic)
llmService.selectedModel = .claude3Opus
```

**Best For**:
- Long transcriptions
- Technical content
- Detailed instructions

#### Google (Gemini)

**Models**: Gemini Pro, Gemini Ultra

**Configuration**:
```swift
llmService.configureAPIKey("AI...", for: .google)
llmService.selectedModel = .geminiPro
```

**Best For**:
- Multilingual content
- Fast processing
- Cost-effective enhancement

#### Groq

**Models**: Mixtral, Llama

**Configuration**:
```swift
llmService.configureAPIKey("gsk_...", for: .groq)
llmService.selectedModel = .mixtral
```

**Best For**:
- Ultra-low latency
- Real-time processing
- High throughput

### Enhancement Features

#### 1. Punctuation

**Before**: "hello how are you today im doing great"

**After**: "Hello! How are you today? I'm doing great."

**Improvements**:
- Sentence boundaries
- Question marks
- Exclamation points
- Commas and pauses
- Apostrophes

#### 2. Capitalization

**Before**: "john went to new york on monday"

**After**: "John went to New York on Monday."

**Improvements**:
- Proper nouns
- Sentence starts
- Acronyms
- Place names
- Person names

#### 3. Grammar Correction

**Before**: "he dont know nothing about it"

**After**: "He doesn't know anything about it."

**Improvements**:
- Subject-verb agreement
- Double negatives
- Tense consistency
- Pronoun usage

#### 4. Terminology Standardization

**Before**: "Doctor Jones prescribed acetaminophen 500 mg"

**After**: "Dr. Jones prescribed Acetaminophen 500mg."

**Improvements**:
- Medical abbreviations
- Technical terms
- Unit formatting
- Standard spellings

### Usage

#### Basic Setup

```swift
// 1. Create LLM service
let llmService = LLMPostProcessingService()

// 2. Configure API key
llmService.configureAPIKey("your-api-key", for: .openAI)

// 3. Select model
llmService.selectedModel = .gpt4

// 4. Enable processing
llmService.isEnabled = true

// 5. Configure text processor
let textProcessor = TranscriptionTextProcessor(
    llmService: llmService,
    appState: AppState.shared
)

// 6. Enable LLM enhancement
await textProcessor.enableLLMProcessing()
```

#### Processing Text

```swift
// Process transcript with context
let result = await llmService.processTranscription(
    "hello doctor i have a bad headache and fever",
    context: "Medical consultation"
)

switch result {
case .success(let processed):
    print("Original: \(processed.originalText)")
    print("Enhanced: \(processed.processedText)")
    print("Improvements: \(processed.changes.count)")
    print("Score: \(processed.improvementScore)")

    // View specific changes
    for change in processed.changes {
        print("\(change.type): \(change.original) → \(change.replacement)")
    }

case .failure(let error):
    print("Processing failed: \(error)")
}
```

#### Real-Time Enhancement

```swift
// Configure text processor for automatic enhancement
let coordinator = TranscriptionCoordinator(
    appState: appState,
    textProcessor: textProcessor
)

// LLM enhancement happens automatically
await coordinator.startTranscription()
// Speak: "hello doctor i have a headache"
// Final transcript: "Hello, Doctor. I have a headache."
```

### Advanced Configuration

#### Custom Prompts

```swift
// Configure context-specific prompts
llmService.setSystemPrompt("""
You are enhancing medical transcriptions.
- Maintain medical accuracy
- Use standard medical abbreviations
- Format drug dosages correctly
- Preserve clinical meaning
""")
```

#### Processing Options

```swift
// Configure processing behavior
llmService.maxTokens = 500           // Limit response length
llmService.temperature = 0.3         // Lower for consistency
llmService.timeout = 10.0            // 10-second timeout
llmService.retryAttempts = 2         // Retry on failure
```

#### Selective Enhancement

```swift
// Only enhance specific types
llmService.enhancePunctuation = true
llmService.enhanceCapitalization = true
llmService.enhanceGrammar = false    // Keep original grammar
llmService.enhanceTerminology = true
```

### Performance Optimization

#### Batch Processing

```swift
// Process multiple transcripts efficiently
let transcripts = [transcript1, transcript2, transcript3]
let results = await llmService.processBatch(transcripts)
```

#### Caching

```swift
// Enable result caching
llmService.enableCaching = true

// Repeated text returns cached result
let result1 = await llmService.process("hello world")
let result2 = await llmService.process("hello world")  // Cached, instant
```

#### Async Processing

```swift
// Don't block on LLM processing
llmService.asyncProcessing = true

// Transcription continues while LLM processes
// UI updates when enhancement completes
```

### Cost Management

#### Estimate Costs

```swift
// Estimate processing cost
let cost = llmService.estimateCost(
    text: transcriptionText,
    model: .gpt4
)

print("Estimated cost: $\(cost)")
```

#### Set Limits

```swift
// Set monthly spending limit
llmService.monthlyBudget = 50.00  // $50 USD

// Disable if limit reached
if llmService.isOverBudget {
    llmService.isEnabled = false
}
```

#### Track Usage

```swift
// Get usage statistics
let stats = await llmService.getStatistics()

print("Texts processed: \(stats.totalProcessed)")
print("Total tokens: \(stats.totalTokens)")
print("Estimated cost: $\(stats.estimatedCost)")
print("Average per text: $\(stats.averageCostPerText)")
```

### Quality Monitoring

#### Improvement Metrics

```swift
// Analyze enhancement quality
let metrics = await llmService.getQualityMetrics()

print("Average improvement score: \(metrics.averageImprovement)")
print("Success rate: \(metrics.successRate)%")
print("Average processing time: \(metrics.avgProcessingTime)s")
```

#### User Feedback

```swift
// Allow users to rate enhancements
llmService.recordFeedback(
    forText: transcriptId,
    rating: 5,  // 1-5 stars
    comment: "Excellent enhancement"
)
```

---

## Global Text Input Mode

### Overview

Global Text Input Mode allows VoiceFlow to insert transcriptions directly into any text field in any application on your Mac. This turns VoiceFlow into a system-wide dictation tool.

### How It Works

```
Speech → Transcription → Final Text → Accessibility API → Focused Text Field
```

### Setup

#### 1. Grant Accessibility Permissions

```swift
let coordinator = GlobalTextInputCoordinator(appState: AppState.shared)

// Request permissions
coordinator.enableGlobalInput()
// System will show permissions dialog
```

**Manual Permission**:
1. Open System Settings
2. Navigate to Privacy & Security
3. Click Accessibility
4. Enable VoiceFlow

#### 2. Enable Global Mode

```swift
// In UI
Button("Enable Global Input") {
    viewModel.enableGlobalInputMode()
}
```

#### 3. Start Transcribing

```swift
// Start recording with global input enabled
await viewModel.startRecording()

// Click into any text field in any app
// Speak - text appears in that field
```

### Usage Examples

#### 1. Email Composition

```swift
// 1. Enable global input
viewModel.enableGlobalInputMode()

// 2. Open Mail.app
// 3. Click in compose window
// 4. Start VoiceFlow recording
// 5. Speak your email
// 6. Text appears in Mail

// Result: Hands-free email writing
```

#### 2. Document Editing

```swift
// Dictate into Microsoft Word, Pages, Google Docs, etc.

// 1. Enable global input
// 2. Open document editor
// 3. Position cursor
// 4. Start recording
// 5. Dictate content
```

#### 3. Chat Applications

```swift
// Use with Slack, Teams, Messages, etc.

// 1. Enable global input
// 2. Open chat app
// 3. Click in message field
// 4. Dictate message
// 5. Text appears instantly
```

#### 4. Form Filling

```swift
// Fill web forms with voice

// 1. Open browser
// 2. Navigate to form
// 3. Click first field
// 4. Dictate value
// 5. Tab to next field
// 6. Continue dictating
```

### Advanced Features

#### Spacing Control

```swift
// Automatic spacing between transcripts
let coordinator = GlobalTextInputCoordinator(appState: appState)

// First insertion: "Hello"
// Second insertion: " world"  // Note space added
// Result: "Hello world"
```

#### Error Handling

```swift
// Handle insertion failures gracefully
coordinator.insertText("Hello world") { result in
    switch result {
    case .success:
        print("Inserted successfully")

    case .accessibilityDenied:
        // Show permissions alert
        showPermissionsAlert()

    case .noActiveTextField:
        // Show field focus reminder
        showFocusReminder()

    case .insertionFailed(let error):
        // Log error and show notification
        logError(error)
        showErrorNotification()
    }
}
```

#### Statistics

```swift
// Track insertion statistics
let stats = coordinator.getInsertionStatistics()

print("Total insertions: \(stats.totalInsertions)")
print("Successful: \(stats.successfulInsertions)")
print("Failed: \(stats.failedInsertions)")
print("Success rate: \(stats.successRate * 100)%")
```

### Best Practices

#### 1. Clear Mode Indication

```swift
// Show visual indicator when global mode is active
struct GlobalModeIndicator: View {
    @ObservedObject var viewModel: SimpleTranscriptionViewModel

    var body: some View {
        if viewModel.globalInputEnabled {
            HStack {
                Image(systemName: "globe")
                    .foregroundColor(.blue)
                Text("Global Input Active")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .padding(4)
            .background(Color.blue.opacity(0.1))
            .cornerRadius(4)
        }
    }
}
```

#### 2. Easy Toggle

```swift
// Provide keyboard shortcut for quick toggle
struct ContentView: View {
    @StateObject var viewModel: SimpleTranscriptionViewModel

    var body: some View {
        // View content
        .keyboardShortcut("g", modifiers: [.command, .shift])
        .onTapGesture {
            if viewModel.globalInputEnabled {
                viewModel.disableGlobalInputMode()
            } else {
                viewModel.enableGlobalInputMode()
            }
        }
    }
}
```

#### 3. Permission Checks

```swift
// Check permissions before enabling
func enableGlobalInput() {
    // Check current permissions
    if viewModel.checkGlobalInputPermissions() {
        viewModel.enableGlobalInputMode()
    } else {
        // Show permissions guide
        showPermissionsGuide()
    }
}
```

#### 4. Session Management

```swift
// Reset session between uses
coordinator.resetSession()

// Clear history periodically
coordinator.clearHistory()

// Get fresh statistics
let currentStats = coordinator.getInsertionStatistics()
```

### Troubleshooting

#### Text Not Inserting

**Problem**: Text doesn't appear in target field

**Solutions**:
1. Verify Accessibility permissions granted
2. Ensure text field is focused (blinking cursor)
3. Check if field is editable (not read-only)
4. Try clicking in field again
5. Restart VoiceFlow

```swift
// Debug insertion
let result = await coordinator.insertText("test")
switch result {
case .noActiveTextField:
    print("No text field focused")
case .accessibilityDenied:
    print("Permissions not granted")
case .insertionFailed(let error):
    print("Insertion error: \(error)")
default:
    break
}
```

#### Permissions Not Persisting

**Problem**: Permissions reset after restart

**Solution**:
1. Fully quit VoiceFlow
2. Remove from Accessibility list
3. Re-add and grant permissions
4. Restart Mac

```swift
// Verify permissions status
if !coordinator.hasPermissions {
    coordinator.checkPermissions()
    if coordinator.hasPermissions {
        print("Permissions restored")
    }
}
```

#### Wrong Application Receiving Text

**Problem**: Text goes to wrong app

**Solution**:
1. Ensure target app is frontmost
2. Click in desired text field
3. Wait for cursor blink
4. Then start dictating

```swift
// Verify focus before inserting
let hasFocus = await coordinator.verifyTextFieldFocus()
if hasFocus {
    await coordinator.insertText(transcript)
}
```

---

## Multi-Format Export

### Overview

VoiceFlow can export transcriptions to multiple professional formats:
- Plain Text (.txt)
- Markdown (.md)
- PDF (.pdf)
- Microsoft Word (.docx)
- SRT Subtitles (.srt)

### Export Formats

#### 1. Plain Text (.txt)

**Best for**: Simple text files, plain documentation, compatibility

**Features**:
- UTF-8 encoding
- Optional metadata header
- Line-wrapped or continuous
- Cross-platform compatible

**Example**:
```swift
let exportManager = ExportManager()

let session = TranscriptionSession(
    transcription: "Hello world",
    startTime: Date(),
    duration: 10.0,
    wordCount: 2,
    averageConfidence: 0.95
)

let result = try exportManager.exportTranscription(
    session: session,
    format: .text,
    to: URL(fileURLWithPath: "/path/to/output.txt"),
    configuration: ExportConfiguration(includeMetadata: true)
)
```

**Output Example**:
```
VoiceFlow Transcription
Date: Jan 1, 2025 10:00 AM
Duration: 10s
Words: 2
Confidence: 95%

---

Hello world
```

#### 2. Markdown (.md)

**Best for**: Documentation, notes, GitHub README, blogs

**Features**:
- Formatted headers
- Metadata section
- Proper structure
- GitHub-compatible

**Example**:
```swift
try exportManager.exportTranscription(
    session: session,
    format: .markdown,
    to: URL(fileURLWithPath: "/path/to/output.md")
)
```

**Output Example**:
```markdown
# VoiceFlow Transcription

**Date**: Jan 1, 2025 10:00 AM
**Duration**: 10s
**Words**: 2
**Confidence**: 95%

---

## Transcript

Hello world
```

#### 3. PDF (.pdf)

**Best for**: Professional documents, sharing, printing

**Features**:
- Professional formatting
- Embedded metadata
- Print-ready
- Universal compatibility

**Example**:
```swift
try exportManager.exportTranscription(
    session: session,
    format: .pdf,
    to: URL(fileURLWithPath: "/path/to/output.pdf")
)
```

#### 4. Microsoft Word (.docx)

**Best for**: Editing, collaboration, formatting

**Features**:
- Editable format
- Formatting options
- Comments and tracking
- Microsoft Office compatible

**Example**:
```swift
try exportManager.exportTranscription(
    session: session,
    format: .docx,
    to: URL(fileURLWithPath: "/path/to/output.docx")
)
```

#### 5. SRT Subtitles (.srt)

**Best for**: Video captions, subtitles, media production

**Features**:
- Timestamp synchronization
- Sequential numbering
- Standard subtitle format
- Video player compatible

**Example**:
```swift
try exportManager.exportTranscription(
    session: session,
    format: .srt,
    to: URL(fileURLWithPath: "/path/to/output.srt"),
    configuration: ExportConfiguration(includeTimestamps: true)
)
```

**Output Example**:
```
1
00:00:00,000 --> 00:00:02,500
Hello

2
00:00:02,500 --> 00:00:05,000
world
```

### Export Configuration

#### Metadata Options

```swift
let config = ExportConfiguration(
    includeTimestamps: true,     // Include timing information
    includeMetadata: true        // Include session metadata
)
```

**Metadata Included**:
- Transcription date and time
- Session duration
- Word count
- Average confidence score
- Model used (if applicable)
- Processing statistics

#### Timestamp Options

```swift
// For SRT and timestamped formats
let config = ExportConfiguration(includeTimestamps: true)

// Timestamps show when each phrase was spoken
// Useful for video synchronization
// Or reviewing long recordings
```

### Batch Export

Export to multiple formats at once:

```swift
let formats: [ExportFormat] = [.text, .markdown, .pdf]

for format in formats {
    let url = baseURL.appendingPathComponent("transcript.\(format.fileExtension)")
    try exportManager.exportTranscription(
        session: session,
        format: format,
        to: url
    )
}
```

### Custom Export Logic

#### Custom Formatting

```swift
// Create custom export format
class CustomExporter {
    func export(session: TranscriptionSession, to url: URL) throws {
        // Custom formatting logic
        var content = ""
        content += "=== TRANSCRIPT ===\n"
        content += "Time: \(session.startTime.formatted())\n"
        content += "Text: \(session.transcription)\n"
        content += "=== END ===\n"

        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}
```

#### Post-Processing

```swift
// Modify content before export
let enhancedSession = TranscriptionSession(
    transcription: session.transcription.uppercased(),  // All caps
    startTime: session.startTime,
    duration: session.duration,
    wordCount: session.wordCount,
    averageConfidence: session.averageConfidence
)

try exportManager.exportTranscription(
    session: enhancedSession,
    format: .text,
    to: url
)
```

### Export Results

Check export status:

```swift
let result = try exportManager.exportTranscription(
    session: session,
    format: .markdown,
    to: url
)

if result.success {
    print("Exported to: \(result.filePath?.path ?? "unknown")")
    print("File size: \(result.metadata["size"] ?? 0) bytes")
    print("Format: \(result.metadata["format"] ?? "")")
    print("Timestamp: \(result.metadata["timestamp"] ?? Date())")
} else if let error = result.error {
    print("Export failed: \(error)")
}
```

### Error Handling

```swift
do {
    let result = try exportManager.exportTranscription(
        session: session,
        format: .pdf,
        to: url
    )
} catch let error as NSError {
    switch error.code {
    case NSFileWriteNoPermissionError:
        print("Permission denied")
    case NSFileWriteOutOfSpaceError:
        print("Disk full")
    case NSFileWriteVolumeReadOnlyError:
        print("Read-only volume")
    default:
        print("Export error: \(error.localizedDescription)")
    }
}
```

### Best Practices

#### 1. Use Descriptive File Names

```swift
let formatter = DateFormatter()
formatter.dateFormat = "yyyy-MM-dd-HHmm"
let timestamp = formatter.string(from: Date())

let fileName = "transcript-\(timestamp).\(format.fileExtension)"
let url = documentsURL.appendingPathComponent(fileName)
```

#### 2. Verify Export Location

```swift
// Check if directory exists
let directory = url.deletingLastPathComponent()
if !FileManager.default.fileExists(atPath: directory.path) {
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
}
```

#### 3. Handle Large Transcriptions

```swift
// For very large transcriptions, export in chunks
if session.wordCount > 10000 {
    // Split into manageable sections
    let chunks = splitTranscription(session, chunkSize: 5000)
    for (index, chunk) in chunks.enumerated() {
        let chunkURL = baseURL.appendingPathComponent("transcript-part\(index).\(format.fileExtension)")
        try exportManager.exportTranscription(
            session: chunk,
            format: format,
            to: chunkURL
        )
    }
}
```

#### 4. Provide User Feedback

```swift
// Show progress during export
Task {
    let result = try await exportWithProgress(session, to: url)
    showCompletionAlert(success: result.success)
}

func exportWithProgress(_ session: TranscriptionSession, to url: URL) async throws -> ExportResult {
    // Show progress indicator
    await MainActor.run {
        showProgressIndicator()
    }

    let result = try exportManager.exportTranscription(
        session: session,
        format: .pdf,
        to: url
    )

    // Hide progress
    await MainActor.run {
        hideProgressIndicator()
    }

    return result
}
```

---

## Secure Credential Management

### Overview

VoiceFlow uses macOS Keychain for secure, encrypted storage of API credentials. All keys are encrypted at rest and protected by system-level security.

### Security Features

1. **Keychain Integration**: Leverages macOS Keychain Services
2. **Encryption**: AES-256 encryption at rest
3. **Access Control**: App-specific access only
4. **No Plain Text**: Keys never stored in plain text
5. **Secure Deletion**: Proper cleanup on removal

### Storing Credentials

#### Manual Configuration

```swift
let credentialService = SecureCredentialService()

// Store Deepgram API key
try await credentialService.storeDeepgramAPIKey("your-api-key")

// Store LLM API key
try await credentialService.store(
    "sk-...",
    for: .openAIKey
)
```

#### Environment Variables

```swift
// Load from environment (for development)
try await credentialService.configureFromEnvironment()

// Reads from:
// - DEEPGRAM_API_KEY
// - OPENAI_API_KEY
// - ANTHROPIC_API_KEY
// - etc.
```

#### UI Configuration

```swift
struct APIKeyConfigView: View {
    @State private var apiKey = ""
    @ObservedObject var viewModel: SimpleTranscriptionViewModel

    var body: some View {
        VStack {
            SecureField("Deepgram API Key", text: $apiKey)

            Button("Save") {
                Task {
                    await viewModel.reconfigureCredentials(newAPIKey: apiKey)
                    apiKey = ""  // Clear input
                }
            }
        }
    }
}
```

### Retrieving Credentials

```swift
// Get Deepgram API key
let apiKey = try await credentialService.getDeepgramAPIKey()

// Get LLM API key
let openAIKey = try await credentialService.get(for: .openAIKey)

// Check if key exists
let hasKey = await credentialService.hasDeepgramAPIKey()
```

### Validation

#### Format Validation

```swift
// Validate before storing
let isValid = await credentialService.validateCredential(
    apiKey,
    for: .deepgramAPIKey
)

if isValid {
    try await credentialService.storeDeepgramAPIKey(apiKey)
} else {
    throw CredentialError.invalidFormat
}
```

#### Health Checks

```swift
// Check keychain accessibility
let isHealthy = await credentialService.performHealthCheck()

if !isHealthy {
    print("Keychain access issue detected")
    // Handle keychain problems
}
```

### Removing Credentials

```swift
// Remove specific credential
try await credentialService.remove(for: .deepgramAPIKey)

// Remove all credentials
try await credentialService.removeAll()
```

### Error Handling

```swift
do {
    try await credentialService.storeDeepgramAPIKey(apiKey)
} catch CredentialError.keyNotFound {
    print("No API key provided")
} catch CredentialError.invalidFormat {
    print("Invalid API key format")
} catch CredentialError.keychainAccessDenied {
    print("Keychain access denied")
} catch {
    print("Storage error: \(error)")
}
```

### Best Practices

#### 1. Never Log Credentials

```swift
// ❌ BAD
print("API Key: \(apiKey)")

// ✅ GOOD
print("API Key configured: \(apiKey.prefix(8))...")
```

#### 2. Validate Before Use

```swift
// Always validate before API calls
guard await credentialService.hasDeepgramAPIKey() else {
    throw CredentialError.keyNotFound
}

let apiKey = try await credentialService.getDeepgramAPIKey()
guard await credentialService.validateCredential(apiKey, for: .deepgramAPIKey) else {
    throw CredentialError.invalidFormat
}

// Now safe to use
await deepgramClient.connect(apiKey: apiKey)
```

#### 3. Handle Keychain Errors

```swift
// Check keychain health on startup
Task {
    let isHealthy = await credentialService.performHealthCheck()
    if !isHealthy {
        showKeychainAlert()
    }
}
```

#### 4. Secure User Input

```swift
// Use SecureField for API key input
SecureField("API Key", text: $apiKey)
    .textContentType(.password)
    .autocapitalization(.none)
    .disableAutocorrection(true)
```

---

## Medical Terminology Detection

### Overview

VoiceFlow automatically detects medical terminology in transcriptions and can:
- Suggest switching to the medical model
- Highlight medical terms
- Provide specialized processing
- Track medical content statistics

### Detection Features

#### Recognized Medical Categories

1. **Anatomy**: heart, lung, liver, kidney, brain, etc.
2. **Conditions**: diabetes, hypertension, pneumonia, etc.
3. **Procedures**: MRI, surgery, endoscopy, etc.
4. **Medications**: insulin, aspirin, antibiotics, etc.
5. **Professionals**: doctor, nurse, surgeon, etc.
6. **Measurements**: blood pressure, heart rate, etc.
7. **Abbreviations**: ICU, ER, IV, etc.

#### Detection Algorithm

```swift
let detector = MedicalTerminologyDetector()

// Calculate medical score (0.0 to 1.0)
let score = await detector.calculateMedicalScore(transcriptionText)

if score > 0.3 {
    print("Medical content detected")
    print("Medical score: \(score * 100)%")

    // Suggest medical model
    viewModel.setModel(.medical)
}
```

### Automatic Model Switching

```swift
// Enable automatic detection
viewModel.enableMedicalTermDetection = true

// Transcribe: "The patient has hypertension and diabetes"
// Detection: Medical score 40%
// Action: Automatically switch to medical model
// Result: Better accuracy for medical terms
```

### Statistics Tracking

```swift
let processor = TranscriptionTextProcessor()
let stats = await processor.getProcessingStatistics()

print("Total texts: \(stats.totalTextsProcessed)")
print("Medical: \(stats.medicalTextsDetected)")
print("Technical: \(stats.technicalTextsDetected)")
print("Legal: \(stats.legalTextsDetected)")
print("Financial: \(stats.financialTextsDetected)")
print("General: \(stats.generalTextsDetected)")

print("Most common domain: \(stats.mostCommonDomain)")
```

### Custom Medical Terms

```swift
// Add custom medical terms
let detector = MedicalTerminologyDetector()
detector.addCustomTerms([
    "cardiomyopathy",
    "thrombocytopenia",
    "nephropathy"
])

// Remove terms
detector.removeCustomTerms(["aspirin"])
```

### Confidence Thresholds

```swift
// Adjust detection sensitivity
detector.medicalThreshold = 0.2   // 20% medical terms triggers detection
detector.confidenceThreshold = 0.7 // 70% confidence for model suggestion
```

---

## Performance Monitoring

### Overview

VoiceFlow includes comprehensive performance monitoring to track system health, identify bottlenecks, and ensure optimal performance.

### Metrics Tracked

#### Audio Processing
- Input latency
- Processing latency
- Buffer utilization
- Sample rate
- Dropped frames

#### Network
- Connection latency
- WebSocket throughput
- Reconnection count
- Error rate

#### Transcription
- Transcription latency
- Accuracy rate
- Word throughput
- Processing time

#### LLM Processing
- Enhancement latency
- Token usage
- Cost tracking
- Success rate

#### Memory
- Total allocation
- Peak usage
- Buffer pool efficiency
- Leak detection

#### CPU
- Average usage
- Peak usage
- Thread count
- Context switches

### Usage

#### Basic Monitoring

```swift
let monitor = PerformanceMonitor()

// Start monitoring
await monitor.startMonitoring()

// Perform operations...

// Get metrics
let metrics = await monitor.getMetrics()
print("Audio latency: \(metrics.audioLatency)ms")
print("Memory usage: \(metrics.memoryUsage)MB")
print("CPU usage: \(metrics.cpuUsage)%")
```

#### Metric Tracking

```swift
// Track specific operation
let result = await monitor.trackOperation("transcription") {
    return await performTranscription()
}

// Metrics automatically recorded
let opMetrics = await monitor.getOperationMetrics("transcription")
print("Average time: \(opMetrics.averageTime)ms")
print("Call count: \(opMetrics.callCount)")
```

#### Real-Time Monitoring

```swift
// Subscribe to metrics stream
for await metric in monitor.metricsStream {
    print("Current latency: \(metric.latency)ms")

    if metric.latency > 500 {
        print("⚠️ High latency detected")
    }
}
```

### Performance Reports

```swift
// Generate comprehensive report
let report = await monitor.generateReport()

print(report)
```

**Report Example**:
```
=== Performance Report ===

Audio Processing:
- Average latency: 45ms
- Buffer utilization: 78%
- Dropped frames: 0

Network:
- Connection latency: 125ms
- Throughput: 15KB/s
- Reconnections: 0

Transcription:
- Average latency: 230ms
- Accuracy: 96.5%
- Words/minute: 120

Memory:
- Current usage: 85MB
- Peak usage: 120MB
- Pool efficiency: 92%

CPU:
- Average usage: 12%
- Peak usage: 35%

=== End Report ===
```

### Performance Alerts

```swift
// Configure thresholds
monitor.setThreshold(for: .audioLatency, value: 100)
monitor.setThreshold(for: .memoryUsage, value: 200)
monitor.setThreshold(for: .cpuUsage, value: 80)

// Subscribe to alerts
monitor.onAlert { alert in
    print("⚠️ \(alert.metric) exceeded threshold")
    print("Current: \(alert.currentValue)")
    print("Threshold: \(alert.threshold)")

    // Take action
    if alert.metric == .memoryUsage {
        performMemoryCleanup()
    }
}
```

### Optimization Recommendations

```swift
// Get optimization suggestions
let recommendations = await monitor.getOptimizationRecommendations()

for recommendation in recommendations {
    print("\(recommendation.priority): \(recommendation.description)")
    print("Expected improvement: \(recommendation.expectedImprovement)%")
}
```

**Example Output**:
```
HIGH: Reduce audio buffer size to decrease latency
Expected improvement: 25%

MEDIUM: Enable audio buffer pooling
Expected improvement: 15%

LOW: Increase network timeout
Expected improvement: 5%
```

---

## Error Recovery

### Overview

VoiceFlow includes sophisticated error recovery mechanisms to handle failures gracefully and automatically retry when appropriate.

### Error Types

```swift
enum VoiceFlowError: LocalizedError {
    case audioPermissionDenied
    case apiKeyMissing
    case apiKeyInvalid
    case connectionFailed(underlying: Error)
    case transcriptionFailed(reason: String)
    case exportFailed(format: ExportFormat, error: Error)
    case keychainAccessDenied
    case llmProcessingFailed(provider: LLMProvider, error: Error)
}
```

### Recovery Strategies

#### Automatic Retry

```swift
let recoveryManager = ErrorRecoveryManager()

// Attempt operation with automatic retry
let result = await recoveryManager.execute(
    operation: {
        try await deepgramClient.connect(apiKey: apiKey)
    },
    recovery: .retry(maxAttempts: 3, delay: 2.0)
)
```

#### Exponential Backoff

```swift
// Retry with increasing delays
let result = await recoveryManager.execute(
    operation: connectOperation,
    recovery: .exponentialBackoff(
        baseDelay: 1.0,
        maxAttempts: 5,
        multiplier: 2.0
    )
)

// Delays: 1s, 2s, 4s, 8s, 16s
```

#### Fallback Strategy

```swift
// Try primary, fall back to alternative
let result = await recoveryManager.execute(
    operation: primaryOperation,
    fallback: alternativeOperation
)
```

#### Manual Intervention

```swift
// Require user action
let result = await recoveryManager.execute(
    operation: operation,
    recovery: .requiresUserAction(
        message: "Please check your API key and try again"
    )
)
```

### Error Handling Patterns

#### Try/Catch with Recovery

```swift
do {
    try await startTranscription()
} catch VoiceFlowError.connectionFailed(let underlying) {
    // Attempt recovery
    let recovered = await recoveryManager.attemptRecovery(from: underlying)

    if recovered {
        try await startTranscription()  // Retry
    } else {
        showError("Connection failed. Please check network.")
    }
}
```

#### Result Type

```swift
let result = await transcriptionService.process(text)

switch result {
case .success(let transcript):
    handleSuccess(transcript)

case .failure(let error):
    let recovered = await handleError(error)
    if !recovered {
        showUserError(error)
    }
}
```

### Circuit Breaker

```swift
let circuitBreaker = CircuitBreaker(
    failureThreshold: 5,
    timeout: 60.0
)

// Prevents repeated calls if service is down
let result = await circuitBreaker.execute {
    try await deepgramClient.connect(apiKey: apiKey)
}

// After 5 failures, circuit opens
// Waits 60 seconds before retry
```

### Error Reporting

```swift
let errorReporter = ErrorReporter()

// Log error with context
errorReporter.log(
    error: error,
    context: [
        "operation": "transcription",
        "model": selectedModel.rawValue,
        "sessionId": sessionId
    ]
)

// Get error history
let recentErrors = errorReporter.getRecentErrors(limit: 10)
```

### User-Friendly Messages

```swift
func userMessage(for error: Error) -> String {
    switch error {
    case VoiceFlowError.audioPermissionDenied:
        return "VoiceFlow needs microphone access. Please enable it in System Settings."

    case VoiceFlowError.apiKeyMissing:
        return "No API key configured. Please add your Deepgram API key in Settings."

    case VoiceFlowError.connectionFailed:
        return "Unable to connect to transcription service. Please check your internet connection."

    default:
        return "An unexpected error occurred. Please try again."
    }
}
```

---

## Keyboard Shortcuts

### Overview

VoiceFlow supports customizable keyboard shortcuts for common actions, enabling hands-free operation.

### Default Shortcuts

| Action               | Shortcut                  |
|----------------------|---------------------------|
| Start/Stop Recording | ⌘ + R                     |
| Clear Transcription  | ⌘ + K                     |
| Export               | ⌘ + E                     |
| Settings             | ⌘ + ,                     |
| Toggle Global Input  | ⌘ + ⇧ + G                 |
| Quick Copy           | ⌘ + C                     |
| Show/Hide Window     | ⌘ + ⇧ + V                 |

### Custom Configuration

```swift
let hotkeyService = GlobalHotkeyService()

// Configure start/stop hotkey
hotkeyService.register(
    key: .r,
    modifiers: [.command],
    action: .toggleRecording
)

// Configure export hotkey
hotkeyService.register(
    key: .e,
    modifiers: [.command],
    action: .export
)

// Configure custom action
hotkeyService.register(
    key: .space,
    modifiers: [.command, .option],
    action: .custom { viewModel in
        await viewModel.startRecording()
        viewModel.enableGlobalInputMode()
    }
)
```

### Global Hotkeys

```swift
// Register system-wide hotkey
hotkeyService.registerGlobalHotkey(
    key: .f1,
    modifiers: [.command, .shift]
) {
    // Bring VoiceFlow to front and start recording
    NSApp.activate(ignoringOtherApps: true)
    await viewModel.startRecording()
}
```

### Hotkey Conflicts

```swift
// Check for conflicts
if hotkeyService.hasConflict(key: .r, modifiers: [.command]) {
    print("Hotkey already registered")

    // Suggest alternative
    let alternative = hotkeyService.suggestAlternative(for: .r)
    print("Try: \(alternative)")
}
```

### UI Configuration

```swift
struct HotkeyConfigView: View {
    @State private var recordingKey: Key = .r
    @State private var modifiers: EventModifiers = [.command]

    var body: some View {
        VStack {
            Text("Recording Shortcut")

            HotkeyRecorder(
                key: $recordingKey,
                modifiers: $modifiers
            )

            Button("Save") {
                hotkeyService.register(
                    key: recordingKey,
                    modifiers: modifiers,
                    action: .toggleRecording
                )
            }
        }
    }
}
```

---

## Settings Management

### Overview

VoiceFlow provides comprehensive settings management for user preferences, API configuration, and application behavior.

### Settings Categories

#### 1. Audio Settings

```swift
let settings = SettingsService()

// Configure audio
settings.audioSampleRate = 16000      // 16kHz
settings.audioChannels = 1            // Mono
settings.audioBitDepth = 16           // 16-bit
settings.audioBufferSize = 1024       // Buffer size

// Input device
settings.setInputDevice("Built-in Microphone")
```

#### 2. Transcription Settings

```swift
// Model selection
settings.defaultModel = .general

// Language
settings.language = .english

// Interim results
settings.showInterimResults = true

// Punctuation
settings.enablePunctuation = true
```

#### 3. LLM Settings

```swift
// Enable/disable
settings.llmProcessingEnabled = false

// Provider
settings.llmProvider = .openAI
settings.llmModel = "gpt-4"

// Processing options
settings.llmTemperature = 0.3
settings.llmMaxTokens = 500
```

#### 4. Export Settings

```swift
// Default format
settings.defaultExportFormat = .markdown

// Metadata
settings.includeMetadataInExport = true

// Location
settings.defaultExportLocation = URL(fileURLWithPath: "~/Documents/Transcriptions")
```

#### 5. UI Settings

```swift
// Appearance
settings.showAudioLevel = true
settings.showConfidence = true
settings.showInterimResults = true

// Window
settings.alwaysOnTop = false
settings.hideWhenNotRecording = false
```

### Persistence

Settings are automatically persisted using UserDefaults:

```swift
// Save settings
settings.save()

// Load settings
settings.load()

// Reset to defaults
settings.resetToDefaults()
```

### Settings UI

```swift
struct SettingsView: View {
    @StateObject var settings = SettingsService()

    var body: some View {
        Form {
            Section("Audio") {
                Picker("Sample Rate", selection: $settings.audioSampleRate) {
                    Text("16kHz").tag(16000)
                    Text("48kHz").tag(48000)
                }
            }

            Section("Transcription") {
                Picker("Model", selection: $settings.defaultModel) {
                    ForEach(DeepgramModel.allCases) { model in
                        Text(model.displayName).tag(model)
                    }
                }

                Toggle("Show Interim Results", isOn: $settings.showInterimResults)
            }

            Section("LLM Enhancement") {
                Toggle("Enable", isOn: $settings.llmProcessingEnabled)

                if settings.llmProcessingEnabled {
                    Picker("Provider", selection: $settings.llmProvider) {
                        ForEach(LLMProvider.allCases) { provider in
                            Text(provider.displayName).tag(provider)
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
```

---

## Advanced Features

### Session Management

```swift
// Start session
let session = TranscriptionSession.start()

// Track metadata
session.recordMetadata("speaker", value: "Dr. Smith")
session.recordMetadata("topic", value: "Patient Consultation")

// End session
session.end()

// Get statistics
print("Duration: \(session.duration)")
print("Words: \(session.wordCount)")
print("Confidence: \(session.averageConfidence)")
```

### Multi-Language Support

```swift
// Set language
settings.language = .spanish

// Multi-language detection
let detector = LanguageDetector()
let language = await detector.detect(text: transcriptionText)

if language != settings.language {
    print("Detected: \(language)")
    // Suggest language change
}
```

### Plugin System (Future)

```swift
// Load custom exporters
let plugin = try PluginManager.load("CustomExporter")

// Register custom model
ModelRegistry.register(CustomModel())

// Add custom processor
ProcessorPipeline.add(CustomTextProcessor())
```

---

## Conclusion

VoiceFlow provides a comprehensive feature set for professional voice transcription, from basic recording to advanced LLM enhancement. Each feature is designed to work seamlessly together while remaining independently configurable.

For additional help or feature requests, please refer to the main documentation or open an issue on GitHub.
