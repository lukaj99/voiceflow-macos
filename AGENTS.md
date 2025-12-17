# VoiceFlow AI Context (AGENTS.md)

## Persona & Mandate
*   **Role:** You are the **VoiceFlow Lead Developer**.
*   **Expertise:** Swift 6, macOS 14+, Speech Framework, AVFoundation, Deepgram API, LLM integration (OpenAI/Claude).
*   **Goal:** Maintain a high-quality, real-time voice transcription app for macOS.
*   **Style:** Concise, technical, and Swift 6 convention-adherent.

## Knowledge Sources (Single Source of Truth)
**You must consult these files to ground your responses:**

1.  **Project Context:** **`AGENTS.md`** (This file)
    *   *Contains:* Architecture, tech stack, and project structure.
2.  **Build Instructions:** **`CLAUDE.md`**
    *   *Contains:* Build commands and development workflow.

## Architecture & Technology Stack

VoiceFlow is a **single-process macOS app** with real-time audio streaming to transcription services.

*   **Language:** Swift 6 (macOS 14+ target)
*   **Build System:** Swift Package Manager (SPM)
*   **UI Framework:** SwiftUI with @Observable patterns
*   **Audio:** AVFoundation + Speech Framework
*   **Transcription:** Deepgram WebSocket API (primary), Apple Speech (fallback)
*   **LLM Processing:** OpenAI, Claude, Ollama for post-processing
*   **Hotkeys:** HotKey package for global shortcuts
*   **Security:** KeychainAccess for credential storage

### Application Design

```text
┌─────────────────────────────────────────────────────────────────┐
│                        VoiceFlow.app                            │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────┐  ┌──────────────┐  ┌──────────────────────┐ │
│  │  SwiftUI UI   │  │  Menu Bar    │  │  Floating Widget     │ │
│  └───────┬───────┘  └──────┬───────┘  └──────────┬───────────┘ │
│          └─────────────────┼─────────────────────┘             │
│                            ▼                                    │
│  ┌────────────────────────────────────────────────────────────┐│
│  │                     AppState (@Observable)                  ││
│  └────────────────────────────┬───────────────────────────────┘│
│                               ▼                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────────────┐  │
│  │ AudioManager │  │ Deepgram     │  │ LLMPostProcessing    │  │
│  │ (AVFoundation)│  │ WebSocket    │  │ Service              │  │
│  └──────┬───────┘  └──────┬───────┘  └──────────┬───────────┘  │
│         │                  │                     │              │
│         ▼                  ▼                     ▼              │
│    Microphone         Deepgram API        OpenAI/Claude API    │
└─────────────────────────────────────────────────────────────────┘
```

### Project Structure

```
VoiceFlow/
├── App/                      # Entry point
│   ├── VoiceFlowApp.swift   # @main SwiftUI App
│   └── Info.plist           # App configuration
├── Core/                     # Core business logic
│   ├── AppState.swift       # Central app state (@Observable)
│   ├── AppState+LLM.swift   # LLM-related state extensions
│   ├── AppState+Widgets.swift
│   ├── Architecture/        # DI & protocols
│   │   ├── DependencyInjection/
│   │   └── Protocols/
│   ├── ErrorHandling/       # Error types & recovery
│   ├── Performance/         # Metrics & monitoring
│   └── Validation/          # Input validation
├── Services/                 # External service integrations
│   ├── AudioManager.swift   # AVFoundation audio capture
│   ├── Deepgram/            # Deepgram transcription
│   │   ├── DeepgramClient.swift
│   │   ├── DeepgramWebSocket.swift
│   │   └── DeepgramModels.swift
│   ├── Export/              # Document export (PDF, DOCX, SRT)
│   │   ├── ExportManager.swift
│   │   ├── PDFExporter.swift
│   │   └── DOCXExporter.swift
│   ├── LLM/                 # LLM post-processing
│   │   ├── LLMPostProcessingService.swift
│   │   ├── LLMProviders.swift
│   │   └── LLMModels.swift
│   ├── GlobalHotkeyService.swift
│   ├── SecureCredentialService.swift
│   └── SettingsService.swift
├── ViewModels/              # View models & coordinators
│   ├── SimpleTranscriptionViewModel.swift
│   ├── TranscriptionCoordinator.swift
│   └── TranscriptionTextProcessor.swift
├── Views/                   # SwiftUI views
│   ├── ContentView.swift
│   ├── SettingsView.swift
│   ├── FloatingMicrophoneWidget.swift
│   └── *ConfigurationView.swift
└── Models/                  # Data models
    └── VoiceLanguage.swift
```

## Development Workflow

1.  **State Check:** List files in your immediate path to establish context.
2.  **Strategy Selection:**
    *   *Fixing a bug?* -> **Strict TDD** (Test First).
    *   *New Core Feature?* -> **Strict TDD** (Test First).
    *   *UI/Exploration?* -> **Post-Hoc** (Code First, Test Later).
3.  **Source Inspection (Crucial):** Before writing any code, **read the relevant source files** (e.g., `DeepgramWebSocket.swift` or `AudioManager.swift`). **Do not guess APIs.**
4.  **Execute:** Implement changes using best practices.
    *   **Rule:** Edit files **in-place**. Do not create `_v2` files.
5.  **Verify:**
    *   **Build:** `swift build`
    *   **Test:** `swift test`
    *   **Format:** `swiftformat VoiceFlow VoiceFlowTests`

## Key Service Patterns

### AudioManager (Audio Capture)

```swift
// VoiceFlow/Services/AudioManager.swift
@MainActor
public class AudioManager: ObservableObject {
    private let audioProcessor = AudioProcessingActor()

    public func startRecording() async throws {
        try await audioProcessor.startRecording { audioData in
            // Send to transcription service
        }
    }
}
```

### DeepgramWebSocket (Real-time Transcription)

```swift
// VoiceFlow/Services/Deepgram/DeepgramWebSocket.swift
actor DeepgramWebSocket {
    func connect(apiKey: String) async throws
    func send(audioData: Data) async
    func disconnect()

    // Receives JSON responses with transcript text
}
```

### LLM Post-Processing

```swift
// VoiceFlow/Services/LLM/LLMPostProcessingService.swift
@MainActor
class LLMPostProcessingService {
    func processTranscription(_ text: String,
                              provider: LLMProvider,
                              model: String) async throws -> String
}
```

## Common Tasks

### Audio Debugging
```bash
# Check microphone permissions
tccutil reset Microphone com.voiceflow.VoiceFlow

# List audio devices
system_profiler SPAudioDataType

# Check audio input
log show --predicate 'subsystem == "com.apple.coreaudio"' --last 5m
```

### Deepgram API Testing
```bash
# Test API key validity
curl -X POST "https://api.deepgram.com/v1/listen" \
  -H "Authorization: Token YOUR_API_KEY" \
  -H "Content-Type: audio/wav" \
  --data-binary @test.wav

# Check WebSocket connectivity
curl -I "wss://api.deepgram.com/v1/listen"
```

### Build & Test
```bash
# Build for development
swift build

# Run tests
swift test

# Build release
swift build --configuration release

# Format code
swiftformat VoiceFlow VoiceFlowTests
```

## Key Files Reference

| File | Purpose |
|------|---------|
| `VoiceFlow/App/VoiceFlowApp.swift` | App entry point |
| `VoiceFlow/Core/AppState.swift` | Central @Observable state |
| `VoiceFlow/Services/AudioManager.swift` | Microphone audio capture |
| `VoiceFlow/Services/Deepgram/DeepgramWebSocket.swift` | Real-time transcription |
| `VoiceFlow/Services/Deepgram/DeepgramClient.swift` | Deepgram API client |
| `VoiceFlow/Services/LLM/LLMPostProcessingService.swift` | LLM text processing |
| `VoiceFlow/Services/Export/ExportManager.swift` | Document export |
| `VoiceFlow/Services/SecureCredentialService.swift` | Keychain storage |
| `VoiceFlow/ViewModels/SimpleTranscriptionViewModel.swift` | Main view model |

## Error Handling

### VoiceFlowError Types
```swift
// VoiceFlow/Core/ErrorHandling/VoiceFlowError.swift
enum VoiceFlowError: LocalizedError {
    case audioPermissionDenied
    case microphoneUnavailable
    case transcriptionServiceUnavailable
    case apiKeyMissing
    case networkError(Error)
    case exportFailed(Error)
}
```

## Claude Code Tools

VoiceFlow includes Claude Code tools for AI-assisted development in `.claude/`.

### Directory Structure

```
.claude/
├── agents/                    # Specialized agents
│   ├── voiceflow-debugger.md # Audio/transcription debugging
│   ├── voiceflow-tester.md   # Test automation
│   ├── voiceflow-audio.md    # Audio processing expert
│   ├── voiceflow-llm.md      # LLM integration expert
│   └── voiceflow-reviewer.md # Code review
├── skills/                    # Auto-loading knowledge
│   ├── audio-processing/     # AVFoundation patterns
│   ├── deepgram-api/         # Deepgram integration
│   ├── llm-integration/      # LLM API patterns
│   └── swift-concurrency/    # Swift 6 async patterns
└── commands/                  # Slash commands
    ├── build.md              # Build project
    ├── test.md               # Run tests
    ├── debug-audio.md        # Audio diagnostics
    └── check-api.md          # API key validation
```

### Agents

| Agent | Expertise | Auto-Triggers |
|-------|-----------|---------------|
| **voiceflow-debugger** | Audio capture, WebSocket, API issues | "debug", "not working", "error" |
| **voiceflow-tester** | XCTest, mocking audio/network | "write test", "test failure" |
| **voiceflow-audio** | AVFoundation, audio formats, levels | "audio", "microphone", "recording" |
| **voiceflow-llm** | OpenAI/Claude integration, prompts | "LLM", "post-processing", "AI" |
| **voiceflow-reviewer** | Swift best practices, code review | "review", "before commit" |

**Explicit Invocation:**
```
Use the voiceflow-debugger agent to diagnose the audio capture issue.
Use the voiceflow-audio agent to analyze audio buffer performance.
Use the voiceflow-llm agent to optimize the post-processing prompts.
```

### Skills

| Skill | Description | File Triggers |
|-------|-------------|---------------|
| **audio-processing** | AVFoundation, audio buffers, formats | `**/Audio*.swift` |
| **deepgram-api** | WebSocket, streaming, response parsing | `**/Deepgram*.swift` |
| **llm-integration** | API clients, prompt engineering | `**/LLM*.swift` |
| **swift-concurrency** | async/await, actors, @MainActor | `**/*.swift` |

### Slash Commands

| Command | Description |
|---------|-------------|
| `/build` | Build the project |
| `/test` | Run test suite |
| `/debug-audio` | Run audio diagnostics |
| `/check-api` | Validate API keys |
| `/format` | Format all Swift code |

## Dependencies

| Package | Version | Purpose |
|---------|---------|---------|
| HotKey | 0.2.0+ | Global keyboard shortcuts |
| KeychainAccess | 4.2.0+ | Secure credential storage |
| AsyncAlgorithms | 1.0.0+ | Async stream processing |
| Starscream | local | WebSocket client |

## Platform Requirements

- **macOS 14.0+**: Required for Swift 6 and @Observable
- **Xcode 15.0+**: Swift 6 support
- **Microphone permission**: Required for audio capture

## Coding Style

Follow the repo's `.swiftformat` profile:
- 4-space indentation
- 120-character line limit
- `@MainActor` for UI-bound APIs
- Inject dependencies via initializers
- Organize with `// MARK:` blocks

## Safety & Integrity

*   **No Vibe-Coding:** Do not just "make it work." Make it robust.
*   **No Secrets:** Never commit API keys. Use SecureCredentialService.
*   **Privacy First:** Audio never leaves device except to selected API.
*   **Test Coverage:** Core services should have >80% coverage.
*   **No Shit Mocks:** Use proper mocking with protocol-based DI.
