# VoiceFlow - Technical Product Requirements Document
## macOS Voice Transcription App - Implementation Specification

### Development Setup & Workflow

#### Git Worktree Structure
```bash
voiceflow/                          # Main repository
├── main/                          # Stable branch
├── feature-transcription-engine/  # Core engine development
├── feature-ui-components/         # UI development
├── feature-ai-integration/        # AI features
└── release-1.0/                  # Release preparation
```

Use worktrees for parallel development:
- `main`: Production-ready code only
- `feature-*`: Individual feature branches
- `release-*`: Release candidates with feature freeze

#### Project Structure
```
VoiceFlow.xcodeproj
├── VoiceFlow/
│   ├── App/
│   │   ├── VoiceFlowApp.swift          # @main entry point
│   │   ├── AppDelegate.swift           # NSApplicationDelegate
│   │   └── Info.plist                  # Bundle configuration
│   ├── Core/
│   │   ├── TranscriptionEngine/
│   │   │   ├── SpeechAnalyzerEngine.swift
│   │   │   ├── AudioProcessor.swift
│   │   │   └── TranscriptionModels.swift
│   │   ├── AI/
│   │   │   ├── ContextAnalyzer.swift
│   │   │   ├── VocabularyLearner.swift
│   │   │   └── PostProcessor.swift
│   │   └── Storage/
│   │       ├── SecureStorage.swift
│   │       ├── TranscriptionDatabase.swift
│   │       └── KeychainManager.swift
│   ├── Features/
│   │   ├── Transcription/
│   │   │   ├── TranscriptionView.swift
│   │   │   ├── TranscriptionViewModel.swift
│   │   │   └── TranscriptionService.swift
│   │   ├── MenuBar/
│   │   │   ├── MenuBarController.swift
│   │   │   └── MenuBarView.swift
│   │   ├── FloatingWidget/
│   │   │   ├── FloatingWidgetWindow.swift
│   │   │   └── FloatingWidgetView.swift
│   │   └── Settings/
│   │       ├── SettingsWindow.swift
│   │       └── SettingsViewModel.swift
│   ├── Shared/
│   │   ├── Extensions/
│   │   ├── Utilities/
│   │   ├── DesignSystem/
│   │   │   ├── LiquidGlass.swift
│   │   │   ├── Colors.swift
│   │   │   └── Typography.swift
│   │   └── Constants.swift
│   └── Resources/
│       ├── Assets.xcassets
│       ├── Sounds/
│       └── Entitlements/
│           ├── VoiceFlow.entitlements
│           └── VoiceFlowDebug.entitlements
├── VoiceFlowTests/
├── VoiceFlowUITests/
└── VoiceFlowPerformanceTests/
```

### Core Implementation Specifications

#### 1. Transcription Engine

```swift
// EXACT IMPLEMENTATION - SpeechAnalyzerEngine.swift
import Speech
import SpeechAnalyzer // New in macOS 26
import AVFoundation
import Combine

@AudioProcessingActor
final class SpeechAnalyzerEngine: TranscriptionEngineProtocol {
    // REQUIRED: Use these exact buffer sizes for optimal performance
    private let kBufferSize: AVAudioFrameCount = 256  // 5.8ms at 44.1kHz
    private let kSampleRate: Double = 44100
    private let kProcessingInterval: TimeInterval = 0.01 // 10ms
    
    // REQUIRED: SpeechAnalyzer configuration
    private lazy var analyzer: SpeechAnalyzer = {
        let config = SpeechAnalyzer.Configuration()
        config.model = .enhanced  // 250MB model, shared across system
        config.language = .automatic
        config.enablePunctuation = true
        config.enableCapitalization = true
        config.enablePartialResults = true
        config.enableSpeakerDiarization = false // Enable in Phase 3
        config.enableSpeculativeDecoding = true // Critical for <50ms latency
        config.maxAlternatives = 3
        config.confidenceThreshold = 0.85
        
        return SpeechAnalyzer(configuration: config)
    }()
    
    // REQUIRED: Audio engine setup
    private let audioEngine = AVAudioEngine()
    private let audioSession = AVAudioSession.sharedInstance()
    
    // REQUIRED: Use PassthroughSubject for real-time updates
    private let transcriptionSubject = PassthroughSubject<TranscriptionUpdate, Never>()
    var transcriptionPublisher: AnyPublisher<TranscriptionUpdate, Never> {
        transcriptionSubject.eraseToAnyPublisher()
    }
    
    func startTranscription() async throws {
        // STEP 1: Configure audio session
        try audioSession.setCategory(.record, mode: .measurement)
        try audioSession.setActive(true)
        
        // STEP 2: Setup audio tap with exact format
        let inputNode = audioEngine.inputNode
        let recordingFormat = AVAudioFormat(
            commonFormat: .pcmFormatFloat32,
            sampleRate: kSampleRate,
            channels: 1,
            interleaved: false
        )!
        
        // STEP 3: Install tap with minimal buffer
        inputNode.installTap(
            onBus: 0,
            bufferSize: kBufferSize,
            format: recordingFormat
        ) { [weak self] buffer, time in
            Task { @AudioProcessingActor in
                await self?.processAudioBuffer(buffer, at: time)
            }
        }
        
        // STEP 4: Start audio engine
        try audioEngine.start()
        
        // STEP 5: Begin analyzer session
        try await analyzer.startAnalyzing()
    }
    
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, at time: AVAudioTime) async {
        // REQUIRED: Process with speculative decoding for <50ms latency
        let result = await analyzer.analyzeBuffer(buffer, timestamp: time)
        
        // REQUIRED: Emit updates for both partial and final results
        if let partial = result.partialTranscript {
            transcriptionSubject.send(.partial(
                text: partial.text,
                confidence: partial.confidence,
                alternatives: partial.alternatives
            ))
        }
        
        if let final = result.finalTranscript {
            transcriptionSubject.send(.final(
                text: final.text,
                confidence: final.confidence,
                timing: final.wordTimings
            ))
        }
    }
}
```

#### 2. Context Awareness System

```swift
// EXACT IMPLEMENTATION - ContextAnalyzer.swift
import AppKit
import ApplicationServices

final class ContextAnalyzer {
    // REQUIRED: Check these specific bundle identifiers
    private let contextualApps = [
        "com.microsoft.VSCode": AppContext.coding(language: nil),
        "com.apple.dt.Xcode": AppContext.coding(language: .swift),
        "com.jetbrains.intellij": AppContext.coding(language: .java),
        "com.apple.mail": AppContext.email(tone: .professional),
        "com.tinyspeck.slackmacgap": AppContext.chat(formality: .casual),
        "com.readdle.SparkDesktop": AppContext.email(tone: .professional),
        "com.microsoft.teams2": AppContext.meeting,
        "us.zoom.xos": AppContext.meeting,
        "com.apple.Notes": AppContext.notes,
        "md.obsidian": AppContext.notes,
        "com.microsoft.Word": AppContext.document(type: .formal)
    ]
    
    // REQUIRED: Use AXUIElement for window content access
    func getCurrentContext() async -> (app: AppContext, content: String?) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication,
              let bundleID = frontApp.bundleIdentifier else {
            return (.general, nil)
        }
        
        let appContext = contextualApps[bundleID] ?? .general
        
        // REQUIRED: Only attempt content reading if user granted accessibility permission
        guard AXIsProcessTrusted() else {
            return (appContext, nil)
        }
        
        // Extract focused text field content
        let content = await extractFocusedContent(from: frontApp)
        return (appContext, content)
    }
    
    private func extractFocusedContent(from app: NSRunningApplication) async -> String? {
        let axApp = AXUIElementCreateApplication(app.processIdentifier)
        
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            axApp,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )
        
        guard result == .success,
              let element = focusedElement as! AXUIElement? else {
            return nil
        }
        
        var value: CFTypeRef?
        AXUIElementCopyAttributeValue(
            element,
            kAXValueAttribute as CFString,
            &value
        )
        
        return value as? String
    }
}
```

#### 3. UI Specifications

```swift
// EXACT IMPLEMENTATION - Main Window Design
struct TranscriptionMainView: View {
    @StateObject private var viewModel: TranscriptionViewModel
    @Environment(\.colorScheme) var colorScheme
    
    // REQUIRED: Exact dimensions and constraints
    private let windowSize = CGSize(width: 600, height: 400)
    private let minWindowSize = CGSize(width: 400, height: 300)
    private let maxWindowSize = CGSize(width: 1200, height: 800)
    
    var body: some View {
        ZStack {
            // REQUIRED: Liquid Glass background implementation
            LiquidGlassBackground()
            
            VStack(spacing: 0) {
                // Header bar - 44pt height
                HeaderBar(viewModel: viewModel)
                    .frame(height: 44)
                
                // Transcription area with padding
                TranscriptionEditor(
                    text: $viewModel.transcribedText,
                    isTranscribing: viewModel.isTranscribing
                )
                .padding(20)
                
                // Waveform visualizer - 60pt height
                WaveformVisualizer(
                    audioLevel: viewModel.currentAudioLevel,
                    isActive: viewModel.isTranscribing
                )
                .frame(height: 60)
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .frame(
            minWidth: minWindowSize.width,
            minHeight: minWindowSize.height,
            idealWidth: windowSize.width,
            idealHeight: windowSize.height,
            maxWidth: maxWindowSize.width,
            maxHeight: maxWindowSize.height
        )
    }
}

// REQUIRED: Liquid Glass visual specifications
struct LiquidGlassBackground: View {
    @Environment(\.colorScheme) var colorScheme
    
    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: colorScheme == .dark ? 
                    [Color(hex: "1C1C1E"), Color(hex: "000000")] :
                    [Color(hex: "F2F2F7"), Color(hex: "E5E5EA")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            
            // Glass effect
            Rectangle()
                .fill(.ultraThinMaterial)
                .opacity(0.6)
            
            // Glossy overlay
            GeometryReader { geometry in
                LinearGradient(
                    colors: [
                        Color.white.opacity(0.1),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .center
                )
                .frame(height: geometry.size.height * 0.5)
                .blur(radius: 3)
            }
            
            // Edge highlight
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.3),
                            Color.white.opacity(0.1),
                            Color.clear
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
                .padding(1)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
```

#### 4. Data Models

```swift
// REQUIRED: Complete data model definitions
import Foundation

// Core transcription models
struct TranscriptionUpdate: Codable, Identifiable {
    let id = UUID()
    let timestamp: Date
    let type: UpdateType
    let text: String
    let confidence: Double
    let alternatives: [Alternative]?
    let wordTimings: [WordTiming]?
    
    enum UpdateType: String, Codable {
        case partial
        case final
        case correction
    }
    
    struct Alternative: Codable {
        let text: String
        let confidence: Double
    }
    
    struct WordTiming: Codable {
        let word: String
        let startTime: TimeInterval
        let endTime: TimeInterval
        let confidence: Double
    }
}

// Context models
enum AppContext: Equatable {
    case general
    case coding(language: CodingLanguage?)
    case email(tone: EmailTone)
    case chat(formality: Formality)
    case meeting
    case notes
    case document(type: DocumentType)
    
    enum CodingLanguage: String {
        case swift, python, javascript, java, go, rust
    }
    
    enum EmailTone: String {
        case professional, casual, formal
    }
    
    enum Formality: String {
        case casual, business, formal
    }
    
    enum DocumentType: String {
        case formal, creative, technical, academic
    }
}

// Storage models
struct TranscriptionSession: Codable, Identifiable {
    let id: UUID
    let startTime: Date
    let endTime: Date?
    let duration: TimeInterval
    let wordCount: Int
    let averageConfidence: Double
    let context: String // Serialized AppContext
    let transcription: String
    let metadata: Metadata
    
    struct Metadata: Codable {
        let appName: String?
        let appBundleID: String?
        let customVocabularyHits: Int
        let correctionsApplied: Int
        let privacyMode: PrivacyMode
    }
}

// Privacy models
enum PrivacyMode: String, Codable, CaseIterable {
    case maximum = "maximum"      // No telemetry, no sync
    case balanced = "balanced"     // Anonymous telemetry only
    case convenience = "convenience" // Full features with encryption
}
```

#### 5. Error Handling Matrix

```swift
// REQUIRED: Comprehensive error handling
enum VoiceFlowError: LocalizedError {
    // Audio errors
    case microphonePermissionDenied
    case audioSessionFailure(Error)
    case audioEngineFailure(Error)
    case noAudioInput
    
    // Transcription errors
    case speechRecognitionUnavailable
    case languageNotSupported(String)
    case transcriptionTimeout
    case lowConfidenceResult(Double)
    
    // System errors
    case insufficientMemory
    case modelLoadFailure(String)
    case storageFailure(Error)
    
    // Network errors (for optional features)
    case syncFailure(Error)
    case authenticationFailure
    
    var errorDescription: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Microphone access is required. Please grant permission in System Settings > Privacy & Security > Microphone."
        case .audioSessionFailure(let error):
            return "Audio session failed: \(error.localizedDescription)"
        case .speechRecognitionUnavailable:
            return "Speech recognition is not available. Please check your internet connection or try again later."
        case .languageNotSupported(let language):
            return "Language '\(language)' is not supported. Please select a different language in settings."
        default:
            return "An unexpected error occurred. Please try again."
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .microphonePermissionDenied:
            return "Click here to open System Settings"
        case .insufficientMemory:
            return "Try closing other applications to free up memory"
        case .modelLoadFailure:
            return "Restart VoiceFlow to reload the speech model"
        default:
            return nil
        }
    }
}

// REQUIRED: Error recovery strategies
protocol ErrorRecoverable {
    func attemptRecovery(from error: VoiceFlowError) async -> Bool
}

extension TranscriptionViewModel: ErrorRecoverable {
    func attemptRecovery(from error: VoiceFlowError) async -> Bool {
        switch error {
        case .audioSessionFailure, .audioEngineFailure:
            // Attempt to restart audio engine
            try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            return await restartAudioEngine()
            
        case .transcriptionTimeout:
            // Increase timeout and retry
            transcriptionTimeout = min(transcriptionTimeout * 1.5, 30.0)
            return true
            
        case .modelLoadFailure:
            // Attempt to download model again
            return await redownloadSpeechModel()
            
        default:
            return false
        }
    }
}
```

#### 6. Performance Requirements

```swift
// REQUIRED: Performance monitoring
final class PerformanceMonitor {
    static let shared = PerformanceMonitor()
    
    // Latency requirements
    struct LatencyRequirements {
        static let transcriptionP50: TimeInterval = 0.030  // 30ms
        static let transcriptionP95: TimeInterval = 0.050  // 50ms
        static let transcriptionP99: TimeInterval = 0.100  // 100ms
        static let uiResponseTime: TimeInterval = 0.016   // 60fps
    }
    
    // Memory requirements
    struct MemoryRequirements {
        static let baselineUsage: Int = 150_000_000      // 150MB
        static let activeTranscription: Int = 200_000_000 // 200MB
        static let withModelsLoaded: Int = 500_000_000   // 500MB
        static let warningThreshold: Int = 800_000_000   // 800MB
    }
    
    // CPU requirements
    struct CPURequirements {
        static let idleUsage: Double = 0.01              // 1%
        static let activeTranscription: Double = 0.10     // 10%
        static let peakUsage: Double = 0.25              // 25%
    }
    
    func measureTranscriptionLatency() -> LatencyMeasurement {
        // Implementation for CI/CD performance gates
    }
}

// REQUIRED: Optimization checklist
enum OptimizationTechnique {
    case metalAcceleration      // Use Metal for audio processing
    case speculativeDecoding    // Predict next words
    case keyValueCaching       // Cache attention computations
    case quantization          // INT8 quantization for models
    case lazyLoading          // Load features on demand
    case memoryMapping        // mmap for large files
}
```

#### 7. Testing Requirements

```swift
// REQUIRED: Test coverage targets
enum TestCoverage {
    static let minimum: Double = 0.80      // 80% overall
    static let coreFeatures: Double = 0.95 // 95% for transcription
    static let ui: Double = 0.70          // 70% for UI
    static let performance: Double = 1.00  // 100% for performance tests
}

// REQUIRED: Test scenarios
enum RequiredTests {
    // Accuracy tests
    case quietEnvironment      // Target: 95% WER
    case officeNoise          // Target: 90% WER
    case cafeNoise           // Target: 85% WER
    case multipleAccents     // Support: US, UK, AU, IN
    case technicalJargon     // Programming terms, medical, legal
    
    // Performance tests
    case latencyMeasurement   // Must pass P95 < 50ms
    case memoryLeaks         // No leaks over 24hr run
    case cpuUsage           // < 10% during transcription
    case batteryDrain       // < 5% per hour impact
    
    // UI tests
    case voiceOverNavigation // Full VoiceOver support
    case keyboardNavigation  // All features keyboard accessible
    case highContrastMode   // WCAG AAA compliance
    case textScaling        // 50% - 200% scaling
    
    // Integration tests
    case appContextSwitching // Verify context detection
    case exportFormats      // All export formats work
    case shortcutsIntegration // Shortcuts app support
}
```

#### 8. Build Configuration

```yaml
# REQUIRED: Xcode build settings
Build Settings:
  Base:
    PRODUCT_NAME: VoiceFlow
    PRODUCT_BUNDLE_IDENTIFIER: com.voiceflow.mac
    DEVELOPMENT_TEAM: $(DEVELOPMENT_TEAM)
    CODE_SIGN_STYLE: Automatic
    MACOSX_DEPLOYMENT_TARGET: 14.0  # macOS 26 Beta
    SWIFT_VERSION: 6.0
    ENABLE_HARDENED_RUNTIME: YES
    ENABLE_APP_SANDBOX: YES
    
  Debug:
    SWIFT_OPTIMIZATION_LEVEL: -Onone
    ENABLE_TESTABILITY: YES
    DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
    
  Release:
    SWIFT_OPTIMIZATION_LEVEL: -O
    ENABLE_TESTABILITY: NO
    DEBUG_INFORMATION_FORMAT: dwarf-with-dsym
    STRIP_INSTALLED_PRODUCT: YES

# REQUIRED: Entitlements
Entitlements:
  # Microphone access
  com.apple.security.device.audio-input: true
  
  # For context awareness (optional)
  com.apple.security.automation.apple-events: true
  com.apple.security.temporary-exception.apple-events:
    - com.microsoft.VSCode
    - com.apple.dt.Xcode
    - com.apple.mail
  
  # File access for exports
  com.apple.security.files.user-selected.read-write: true
  
  # Network for optional sync
  com.apple.security.network.client: true
  
  # App Sandbox
  com.apple.security.app-sandbox: true

# REQUIRED: Info.plist entries
Info.plist:
  NSMicrophoneUsageDescription: "VoiceFlow needs microphone access to transcribe your speech"
  NSAppleEventsUsageDescription: "VoiceFlow can read your active app to improve transcription accuracy"
  LSApplicationCategoryType: public.app-category.productivity
  LSMinimumSystemVersion: 14.0
  CFBundleShortVersionString: 1.0.0
  CFBundleVersion: 1
```

### Launch Checklist

#### Pre-Development (Day 1)
- [ ] Create git repository with worktree structure
- [ ] Setup Xcode project with exact folder structure
- [ ] Configure build settings and entitlements
- [ ] Create App Store Connect app record
- [ ] Setup TestFlight for beta testing

#### Development Phase 1 (Week 1-4)
- [ ] Implement SpeechAnalyzerEngine exactly as specified
- [ ] Build menu bar controller with global hotkey
- [ ] Create floating widget with drag support
- [ ] Implement secure storage with Keychain
- [ ] Add basic voice commands
- [ ] Achieve <50ms latency benchmark
- [ ] Pass all Phase 1 performance tests

#### Development Phase 2 (Week 5-8)
- [ ] Implement ContextAnalyzer with app detection
- [ ] Build AI post-processor with Foundation Models
- [ ] Create custom vocabulary system
- [ ] Add export functionality (TXT, MD, DOCX)
- [ ] Implement transcription history
- [ ] Achieve 95% accuracy benchmark
- [ ] Complete accessibility compliance

#### Development Phase 3 (Week 9-12)
- [ ] Add speaker diarization
- [ ] Build meeting mode with summaries
- [ ] Implement Notion/Obsidian integration
- [ ] Create team features
- [ ] Add Shortcuts support
- [ ] Complete all performance optimizations
- [ ] Achieve 100% test coverage for core features

#### Launch Preparation (Week 13-14)
- [ ] Submit for App Store review
- [ ] Prepare marketing website
- [ ] Create demo video
- [ ] Setup support documentation
- [ ] Configure analytics (privacy-preserving)
- [ ] Plan ProductHunt launch

### Critical Success Factors

1. **Performance is non-negotiable**: Every transcription must appear within 50ms
2. **Privacy by default**: No feature should require internet connection
3. **Context awareness differentiates us**: This is our unique advantage
4. **Accessibility is a feature**: Full VoiceOver and Voice Control support
5. **Quality over quantity**: Launch with fewer, perfect features

### Implementation Order (Strict)

1. Audio engine with SpeechAnalyzer
2. Menu bar integration
3. Global hotkey system
4. Basic transcription display
5. Floating widget
6. Voice commands
7. Context detection
8. AI corrections
9. Custom vocabulary
10. Export features

Build each feature completely before moving to the next. Use feature flags for incomplete features.