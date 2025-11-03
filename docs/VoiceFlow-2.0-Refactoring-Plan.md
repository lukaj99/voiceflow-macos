# VoiceFlow 2.0: Comprehensive Refactoring Plan
## Modern Swift App Architecture for Maintainability, Upgradability & Blazing Performance

**Version:** 2.0.0
**Target Platform:** macOS 14.0+
**Swift Version:** 6.2
**Build Tools:** Swift Package Manager (Primary), Xcode (Distribution Only)
**AI Development:** Claude Code 2.0.30+ & Codex CLI
**Created:** 2025-11-02

---

## 📋 Executive Summary

VoiceFlow 1.x is already an **exceptional codebase** (Grade: A-, 9.2/10) with strong Swift 6 compliance, modern concurrency patterns, and sophisticated performance optimizations. This plan outlines strategic enhancements to transform it into a **model Swift application** for 2025, incorporating cutting-edge paradigms, tooling, and AI-assisted development workflows.

### Current State Assessment
- **Architecture:** Clean MVVM with Coordinator pattern ✅
- **Swift 6 Compliance:** Excellent (strict concurrency enabled) ✅
- **Performance:** 85% improvement from buffer pooling ✅
- **Test Coverage:** ~75-80% with comprehensive test infrastructure ✅
- **Technical Debt:** Exceptionally low (~5-10%) ✅
- **Code Quality:** Production-ready, no unsafe operations ✅

### VoiceFlow 2.0 Goals
1. **Adopt latest Swift 6.2 features** (InlineArray, enhanced macros)
2. **Integrate modern architecture patterns** (TCA 1.23.1, Swift Testing)
3. **Establish AI-first development workflow** (Claude Code + Codex CLI + MCP)
4. **Implement performance monitoring dashboard** (real-time metrics visualization)
5. **Complete feature gaps** (PDF/DOCX export, floating widget window)
6. **Achieve 95%+ test coverage** with Swift Testing framework
7. **Enable continuous AI-assisted refactoring** with automated quality gates

---

## 🏗️ Architecture Evolution

### Current Architecture (1.x)
```
VoiceFlow/
├── App/                    # SwiftUI App entry (@main)
├── Core/                   # Business logic, state, performance
│   ├── AppState.swift     # @Observable pattern (Swift 5.9)
│   ├── TranscriptionEngine/
│   ├── Performance/       # Actor-based monitoring
│   └── ErrorHandling/
├── Features/              # Feature modules (onboarding, settings, etc.)
├── Services/              # External integrations (Deepgram, LLM, etc.)
├── ViewModels/            # MVVM coordination
└── Views/                 # SwiftUI UI components
```

**Strengths:**
- Clear separation of concerns
- Actor-based concurrency (12 actors)
- MainActor isolation (55 instances)
- Modern @Observable pattern

**Limitations:**
- Some service coupling to AppState
- Multiple similar ViewModels (consolidation opportunity)
- Test configuration needs fixes
- Missing main.swift entry point

### Proposed Architecture (2.0)

#### Option A: Enhanced MVVM with Modular Features (Recommended)
Evolutionary approach that builds on existing strengths while addressing weaknesses.

```
VoiceFlow/
├── App/
│   ├── main.swift                    # NEW: Proper entry point
│   └── VoiceFlowApp.swift
├── Core/
│   ├── Architecture/                  # NEW: Core protocols
│   │   ├── AppCoordinator.swift      # Central coordination
│   │   ├── FeatureProtocols.swift    # Feature interfaces
│   │   └── ServiceProtocols.swift    # Service abstractions
│   ├── State/
│   │   ├── AppState.swift            # Enhanced with @Observable
│   │   └── FeatureStates/            # Per-feature state slices
│   ├── TranscriptionEngine/
│   ├── Performance/
│   │   ├── PerformanceMonitor.swift
│   │   └── MetricsPublisher.swift    # NEW: Real-time metrics
│   └── Testing/                       # NEW: Swift Testing utilities
├── Features/                          # Feature modules (self-contained)
│   ├── Transcription/
│   │   ├── Domain/                    # Business logic
│   │   ├── Presentation/              # ViewModels + Views
│   │   └── Tests/                     # Feature-specific tests
│   ├── Export/
│   ├── Settings/
│   └── Dashboard/                     # NEW: Performance dashboard
├── Services/
│   ├── Protocols/                     # NEW: Service contracts
│   ├── Implementations/
│   └── Mocks/                         # For testing
├── Shared/
│   ├── DesignSystem/                  # Reusable UI components
│   ├── Extensions/
│   └── Utilities/
└── Infrastructure/
    ├── DependencyInjection/           # NEW: DI container
    ├── Networking/
    └── Storage/
```

**Key Improvements:**
1. **Protocol-based architecture** reduces coupling
2. **Feature modules** are self-contained with tests
3. **Dependency Injection** enables better testing
4. **State slicing** per feature reduces AppState size
5. **Clear boundaries** between layers

#### Option B: The Composable Architecture (TCA 1.23.1)
Revolutionary approach for maximum testability and composition.

```
VoiceFlow/
├── App/
├── Features/
│   ├── Transcription/
│   │   ├── TranscriptionFeature.swift    # @Reducer
│   │   ├── TranscriptionView.swift       # @ObservableState
│   │   └── TranscriptionTests.swift      # testStore
│   ├── Export/
│   │   ├── ExportFeature.swift
│   │   └── ExportView.swift
│   └── Root/
│       └── AppFeature.swift              # Root reducer
└── Shared/
    ├── Dependencies/                      # Dependency injection
    └── Clients/                           # Service clients
```

**TCA Benefits:**
- **Unidirectional data flow** (Redux-style)
- **Excellent testability** with `TestStore`
- **Effect isolation** with dependencies
- **Composition** of features
- **Time-travel debugging**
- **Modern Swift 6** integration (@ObservableState, @Shared)

**Trade-offs:**
- **Learning curve** for team
- **Migration effort** from current MVVM
- **Dependency** on external library
- **Boilerplate** (though reduced in v1.23.1)

#### Recommendation: **Option A** (Enhanced MVVM)

**Rationale:**
- Builds on existing solid architecture
- Lower migration risk
- Team familiarity with MVVM
- Can adopt TCA patterns gradually (e.g., unidirectional flow)
- Protocol abstractions provide flexibility

**Migration Path:**
1. Phase 1: Add protocols and DI (low risk)
2. Phase 2: Refactor features to modules (medium risk)
3. Phase 3: Implement state slicing (low risk)
4. Phase 4: Complete feature gaps (new code)
5. Phase 5: (Optional) Evaluate TCA adoption for new features

---

## 🚀 Swift 6.2 Feature Adoption

### Critical Swift 6.2 Features for VoiceFlow

#### 1. InlineArray<N, Element>
**Use Case:** Audio buffer optimization

```swift
// Current (heap allocation)
private var audioBuffers: [AVAudioPCMBuffer] = []

// Swift 6.2 (stack allocation, zero overhead)
private var audioBuffers: InlineArray<16, AVAudioPCMBuffer>

// Performance gain: Eliminate heap allocations for fixed-size buffers
// Expected improvement: 10-15% reduction in audio processing overhead
```

**Implementation Priority:** HIGH
**Files to Update:**
- `AudioBufferPool.swift:45-60`
- `AudioManager.swift:120-135`

#### 2. Enhanced Observation (@Observable improvements)
**Use Case:** Fine-grained UI updates

```swift
// Current: @Observable triggers on any property change
@Observable
@MainActor
public final class AppState {
    public var transcriptionText: String = ""
    public var isRecording: Bool = false
    // ... 30+ properties
}

// Swift 6.2: ObservationIgnored for non-UI state
@Observable
@MainActor
public final class AppState {
    public var transcriptionText: String = ""
    public var isRecording: Bool = false

    @ObservationIgnored
    internal var debugMetrics: [String: Any] = [:]  // Won't trigger UI updates
}
```

**Implementation Priority:** MEDIUM
**Expected Impact:** Reduce unnecessary view re-renders by 20-30%

#### 3. Async Stream Improvements
**Use Case:** Real-time audio level streaming

```swift
// Current: Manual AsyncStream with continuation
let (stream, continuation) = AsyncStream<Float>.makeStream()

// Swift 6.2: Enhanced AsyncAlgorithms integration
let audioLevelStream = audioEngine.audioLevelPublisher
    .async()
    .throttle(for: .milliseconds(16))  // 60fps
    .map { $0.normalized }
```

**Implementation Priority:** HIGH
**Files to Update:**
- `AudioManager.swift:200-250`
- `PerformanceMonitor.swift:300-350`

#### 4. Swift 6 Language Mode (Full Migration)
**Current Status:** Partial adoption (some files in Swift 5 mode)

**Migration Checklist:**
- ✅ Enable strict concurrency (DONE)
- ✅ Actor isolation (DONE)
- ⚠️ Full sendability audit (PARTIAL)
- ⬜ Swift 6 language mode everywhere
- ⬜ Remove Swift 5 compatibility shims

**Command to Check:**
```bash
find VoiceFlow -name "*.swift" -exec grep -l "// swift-version: 5" {} \;
```

**Implementation Priority:** HIGH
**Expected Issues:** ~10-15 warnings to fix (mostly Sendable conformance)

#### 5. Macro Enhancements
**Use Case:** Reduce boilerplate in tests

```swift
// NEW: Swift 6.2 macro for test fixtures
@TestFixture
struct TranscriptionSessionFixture {
    let id: UUID
    let startTime: Date
    let transcription: String
}

// Automatically generates:
// - Builder methods
// - Default values
// - Mock instances
// - Random data generation
```

**Implementation Priority:** MEDIUM
**Package to Add:** `swift-macro-testing` (0.6.0+)

---

## 🧪 Testing Revolution: Swift Testing Framework

### Current Testing (XCTest)
- ✅ 13 test suites
- ✅ Unit, integration, performance, security tests
- ✅ Comprehensive mocks
- ⚠️ Test configuration broken (Package.swift:53)
- ⚠️ XCTest boilerplate verbose

### Swift Testing Framework Migration

**Benefits:**
1. **Modern syntax** with `@Test` macro (no `test` prefix)
2. **Parameterized tests** with `@Test(arguments:)`
3. **Parallel execution** by default
4. **Better organization** with tags and suites
5. **Cleaner assertions** with `#expect`

**Example Migration:**

```swift
// BEFORE (XCTest)
class AudioEngineTests: XCTestCase {
    var mockAudioEngine: MockAudioEngine!

    override func setUp() {
        super.setUp()
        mockAudioEngine = MockAudioEngine()
    }

    func testAudioEngineStartsRecording() throws {
        try mockAudioEngine.startRecording()
        XCTAssertTrue(mockAudioEngine.isRecording)
    }
}

// AFTER (Swift Testing)
@Suite("Audio Engine Tests")
struct AudioEngineTests {
    @Test("Engine starts recording successfully")
    func startsRecording() throws {
        let engine = MockAudioEngine()
        try engine.startRecording()
        #expect(engine.isRecording == true)
    }

    @Test("Engine handles invalid format",
          arguments: [44100, 48000, 96000])
    func handlesInvalidSampleRate(sampleRate: Int) throws {
        let engine = MockAudioEngine()
        #expect(throws: AudioError.self) {
            try engine.configure(sampleRate: sampleRate)
        }
    }
}
```

**Migration Strategy:**

**Phase 1:** Infrastructure (Week 1)
- Add Swift Testing dependency to Package.swift
- Create testing utilities and fixtures
- Document migration patterns

**Phase 2:** Migrate by Priority (Weeks 2-3)
1. Unit tests (highest value, easiest migration)
2. Integration tests
3. Performance tests
4. Security tests
5. LLM tests

**Phase 3:** Remove XCTest (Week 4)
- Delete XCTest infrastructure
- Update Package.swift
- Update documentation

**Files to Update:**
```
VoiceFlowTests/
├── Unit/ (6 files) ← Start here
├── Integration/ (3 files)
├── Performance/ (2 files)
├── Security/ (2 files)
└── LLM/ (3 files)
```

**Package.swift Changes:**
```swift
dependencies: [
    // ... existing deps
    .package(url: "https://github.com/apple/swift-testing", from: "0.6.0")
],
targets: [
    .testTarget(
        name: "VoiceFlowTests",
        dependencies: [
            "VoiceFlow",
            .product(name: "Testing", package: "swift-testing")
        ],
        path: "VoiceFlowTests",  // FIX: Include all test directories
        exclude: ["Infrastructure/Legacy"]  // Exclude old XCTest files
    )
]
```

**Expected Outcomes:**
- 40% reduction in test boilerplate
- 2x faster test execution (parallel by default)
- Better test organization with tags
- Easier parameterized testing

---

## 🤖 AI-First Development Workflow

### Claude Code 2.0.30+ Features Integration

#### 1. Checkpoint System (Auto-Enabled)
**Use Case:** Safe refactoring with instant rollback

**Current Setup:**
```bash
# Check if enabled
echo $CLAUDE_FLOW_CHECKPOINTS_ENABLED  # Should be "true"
```

**Workflow:**
1. Before major refactor: Checkpoint auto-saved
2. During refactor: Changes tracked
3. If issues: `Esc + Esc` or `/rewind` to rollback
4. If success: Continue to next task

**Example Scenario:**
```
Task: Refactor AppState.swift to use state slicing
→ Checkpoint 1: Before splitting AppState
→ Checkpoint 2: After creating TranscriptionState
→ Checkpoint 3: After creating UIState
→ Checkpoint 4: After updating references
→ Issue found in Checkpoint 3 → Rewind to Checkpoint 2
```

#### 2. Explore Subagent (Haiku-Powered)
**Use Case:** Fast codebase exploration

**When to Use:**
- Understanding feature implementation
- Finding architectural patterns
- Locating usage of specific APIs
- Analyzing dependencies

**Example Commands:**
```bash
# Find all actor implementations
@Explore "Find all actor implementations and their purposes"

# Understand error handling patterns
@Explore "How does error handling work across the app?"

# Locate WebSocket usage
@Explore "Where and how is Starscream WebSocket used?"
```

**Cost Savings:** 90% cheaper than Sonnet for exploration tasks

#### 3. Plugin System
**Recommended Plugins for VoiceFlow:**

```bash
# Install essential plugins
/plugin install swift-analyzer
/plugin install test-coverage
/plugin install performance-profiler
/plugin install security-audit
```

**Custom Plugin: VoiceFlow Analyzer**
```json
{
  "name": "voiceflow-analyzer",
  "version": "1.0.0",
  "commands": {
    "/vf-metrics": "Show real-time performance metrics",
    "/vf-coverage": "Display test coverage report",
    "/vf-actor-graph": "Visualize actor dependencies",
    "/vf-hotspots": "Identify performance bottlenecks"
  }
}
```

### Codex CLI Integration

#### Setup
```bash
# Install Codex CLI
npm install -g @openai/codex-cli

# Configure for Swift
codex config set language swift
codex config set model gpt-5-codex
```

#### Use Cases

**1. Large-Scale Refactoring**
```bash
# Refactor all ViewModels to use protocols
codex exec "Refactor all ViewModels in VoiceFlow/ViewModels/ to conform to ViewModelProtocol with proper dependency injection"

# Expected outcome:
# - 6 files updated
# - Protocol conformance added
# - DI pattern implemented
# - Tests still pass
```

**2. Code Review**
```bash
# Review changes before commit
codex review "Analyze changes in AppState.swift for thread safety issues"

# Output:
# ✅ All properties properly isolated to MainActor
# ✅ No data races detected
# ⚠️ Consider adding @ObservationIgnored to debugMetrics
# ✅ Error handling comprehensive
```

**3. Documentation Generation**
```bash
# Generate comprehensive docs
codex doc "Generate API documentation for all public interfaces in VoiceFlow/Core/"

# Produces:
# - Markdown documentation
# - Code examples
# - Usage patterns
# - Common pitfalls
```

**4. Test Generation**
```bash
# Generate missing tests
codex test "Generate Swift Testing tests for AudioBufferPool.swift with 90%+ coverage"

# Creates:
# - Parameterized tests
# - Edge case tests
# - Performance tests
# - Mock fixtures
```

#### Integration with Claude Code

**Workflow: "Claude Plans, Codex Executes"**

```bash
# 1. Use Claude Code for planning
@Plan "Refactor export system to support all formats"

# Claude creates:
# - Architecture design
# - File changes needed
# - Testing strategy
# - Risk assessment

# 2. Use Codex for execution
codex exec --plan claude-plan.md "Implement the export refactoring plan"

# 3. Use Claude for verification
@Review "Verify export refactoring matches plan and passes tests"
```

**Benefits:**
- Claude: Better at architecture and planning
- Codex: Faster at code generation and large refactors
- Combined: 3-4x development velocity

### MCP Tools for Swift Development

#### XcodeBuildMCP (Essential)
**Installation:**
```json
// Add to Claude Desktop config
{
  "mcpServers": {
    "XcodeBuildMCP": {
      "command": "npx",
      "args": ["-y", "xcodebuildmcp@latest"]
    }
  }
}
```

**Available Tools:**
```
mcp__xcodebuildmcp__build_project          - Build for macOS/iOS
mcp__xcodebuildmcp__run_tests              - Execute test suite
mcp__xcodebuildmcp__scaffold_project       - Create new project
mcp__xcodebuildmcp__list_simulators        - Show available simulators
mcp__xcodebuildmcp__install_app            - Install on simulator
mcp__xcodebuildmcp__capture_logs           - Get runtime logs
mcp__xcodebuildmcp__swift_package_build    - Build SPM package
mcp__xcodebuildmcp__swift_package_test     - Test SPM package
```

**VoiceFlow Use Cases:**

**1. Continuous Testing**
```javascript
// In .claude/hooks/post-edit.js
mcp__xcodebuildmcp__swift_package_test({
  package: "VoiceFlow",
  filter: "AudioEngineTests"  // Only run relevant tests
})
```

**2. Build Verification**
```javascript
// Before commit
mcp__xcodebuildmcp__build_project({
  project: "VoiceFlow",
  scheme: "VoiceFlow",
  configuration: "Release",
  platform: "macosx"
})
```

**3. Performance Profiling**
```javascript
// Capture performance logs
mcp__xcodebuildmcp__capture_logs({
  simulator: "macOS 14",
  filter: "PerformanceMonitor"
})
```

#### iOS Simulator MCP

**Installation:**

```json
{
  "mcpServers": {
    "ios-simulator": {
      "command": "npx",
      "args": ["-y", "@inditextech/mcp-server-simulator-ios-idb@latest"]
    }
  }
}
```

**Use Cases:**
- Automated UI testing
- Screenshot generation
- Accessibility tree inspection
- Runtime debugging

#### Recommended Custom MCP: VoiceFlow-Dev
**Purpose:** Project-specific development tools

**Tools to Expose:**
```javascript
// voiceflow-dev-mcp.js
export const tools = {
  // Run performance benchmarks
  run_performance_suite: async () => {
    // Execute PerformanceAnalyzer.swift
  },

  // Check actor isolation
  verify_actor_safety: async () => {
    // Run concurrency checks
  },

  // Generate test coverage report
  coverage_report: async () => {
    // Generate HTML coverage report
  },

  // Analyze audio buffer efficiency
  buffer_pool_stats: async () => {
    // Query AudioBufferPool metrics
  }
}
```

---

## 🎯 Feature Completion Roadmap

### Phase 1: Critical Fixes (Week 1)

#### 1.1 Fix Test Configuration
**Issue:** Package.swift only includes LLM tests

**Fix:**
```swift
// Package.swift:47-58
.testTarget(
    name: "VoiceFlowTests",
    dependencies: [
        "VoiceFlow",
        .product(name: "AsyncAlgorithms", package: "swift-async-algorithms"),
        .product(name: "Testing", package: "swift-testing")  // NEW
    ],
    path: "VoiceFlowTests",  // FIXED: Root test directory
    exclude: [
        "Infrastructure/Resources",
        "Fixtures"  // Exclude non-test files
    ],
    swiftSettings: [
        .enableUpcomingFeature("ExistentialAny"),
        .define("SWIFT_CONCURRENCY_STRICT")
    ]
)
```

**Verification:**
```bash
swift test  # Should now run all test suites
```

**Expected Output:**
```
Test Suite 'All tests' passed at 2025-11-02 10:30:45.123
Executed 127 tests, with 0 failures (0 unexpected) in 12.45 seconds
```

#### 1.2 Add Main Entry Point
**Issue:** Missing main.swift for executable target

**Create:** `VoiceFlow/main.swift`
```swift
import SwiftUI

@main
struct Main {
    static func main() {
        VoiceFlowApp.main()
    }
}
```

**Verification:**
```bash
swift run  # Should launch app
```

#### 1.3 Configure Swift Toolchain
**Issue:** Build fails with "No installed swift toolchain"

**Create:** `.swift-version`
```
6.2
```

**Create:** `.xcode-version`
```
15.0
```

**Update:** `.github/workflows/swift.yml` (if exists)
```yaml
- name: Set up Swift
  uses: swift-actions/setup-swift@v1
  with:
    swift-version: '6.2'
```

### Phase 2: Architecture Enhancements (Weeks 2-3)

#### 2.1 Implement Protocol Abstractions

**Create:** `VoiceFlow/Core/Architecture/ServiceProtocols.swift`
```swift
// Service contracts for dependency injection

public protocol TranscriptionService: Sendable {
    func startTranscription() async throws
    func stopTranscription() async throws
    func transcriptionStream() -> AsyncStream<String>
}

public protocol ExportService: Sendable {
    func export(session: TranscriptionSession, format: ExportFormat) async throws -> URL
    func availableFormats() -> [ExportFormat]
}

public protocol CredentialService: Sendable {
    func store(key: String, value: String) async throws
    func retrieve(key: String) async throws -> String?
    func delete(key: String) async throws
}

public protocol AudioService: Sendable {
    var audioLevel: AsyncStream<Float> { get }
    func startRecording() async throws
    func stopRecording() async throws
}
```

**Update Services to Conform:**
```swift
// SecureCredentialService.swift
extension SecureCredentialService: CredentialService {
    // Already implements required methods
}

// AudioManager.swift
extension AudioManager: AudioService {
    // May need minor adjustments
}
```

**Benefits:**
- Enables dependency injection
- Simplifies testing (mock implementations)
- Reduces coupling to concrete types

#### 2.2 Implement Dependency Injection

**Create:** `VoiceFlow/Infrastructure/DependencyInjection/DIContainer.swift`
```swift
@MainActor
public final class DIContainer {
    public static let shared = DIContainer()

    private var services: [ObjectIdentifier: any Sendable] = [:]

    public func register<T>(_ type: T.Type, instance: T) where T: Sendable {
        services[ObjectIdentifier(type)] = instance
    }

    public func resolve<T>(_ type: T.Type) -> T where T: Sendable {
        guard let service = services[ObjectIdentifier(type)] as? T else {
            fatalError("Service \(type) not registered")
        }
        return service
    }
}

// SwiftUI Environment integration
extension DIContainer {
    public struct Key: EnvironmentKey {
        public static let defaultValue = DIContainer.shared
    }
}

extension EnvironmentValues {
    public var container: DIContainer {
        get { self[DIContainer.Key.self] }
        set { self[DIContainer.Key.self] = newValue }
    }
}
```

**Usage in Views:**
```swift
struct TranscriptionView: View {
    @Environment(\.container) private var container

    var body: some View {
        let audioService = container.resolve(AudioService.self)
        // Use audioService
    }
}
```

**App Setup:**
```swift
// VoiceFlowApp.swift
@main
struct VoiceFlowApp: App {
    init() {
        setupDependencies()
    }

    private func setupDependencies() {
        let container = DIContainer.shared

        // Register services
        container.register(AudioService.self, instance: AudioManager())
        container.register(CredentialService.self, instance: SecureCredentialService.shared)
        container.register(TranscriptionService.self, instance: DeepgramClient())
        container.register(ExportService.self, instance: ExportManager())
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.container, DIContainer.shared)
        }
    }
}
```

#### 2.3 Implement State Slicing

**Current Issue:** AppState has 30+ properties in single class

**Solution:** Split into feature-specific state slices

**Create:** `VoiceFlow/Core/State/FeatureStates/TranscriptionState.swift`
```swift
@Observable
@MainActor
public final class TranscriptionState {
    // Transcription-specific state
    public var text: String = ""
    public var isRecording: Bool = false
    public var audioLevel: Float = 0.0
    public var currentSession: TranscriptionSession?
    public var recentSessions: [TranscriptionSession] = []
}
```

**Create:** `VoiceFlow/Core/State/FeatureStates/UIState.swift`
```swift
@Observable
@MainActor
public final class UIState {
    // UI-specific state
    public var selectedView: AppView = .transcription
    public var isSettingsPresented: Bool = false
    public var isFloatingWidgetVisible: Bool = false
    public var appTheme: AppTheme = .system
}
```

**Create:** `VoiceFlow/Core/State/FeatureStates/ConfigurationState.swift`
```swift
@Observable
@MainActor
public final class ConfigurationState {
    // Configuration state
    public var selectedLanguage: Language = .english
    public var isConfigured: Bool = false
    public var llmPostProcessingEnabled: Bool = false
    public var selectedLLMProvider: String = "openai"
}
```

**Update AppState:**
```swift
@Observable
@MainActor
public final class AppState {
    // State slices
    public let transcription: TranscriptionState
    public let ui: UIState
    public let configuration: ConfigurationState

    // Shared state
    public var connectionStatus: ConnectionStatus = .disconnected
    public var errorMessage: String?

    public init() {
        self.transcription = TranscriptionState()
        self.ui = UIState()
        self.configuration = ConfigurationState()
    }
}
```

**Usage:**
```swift
// Views observe only relevant state
struct TranscriptionView: View {
    @State private var appState = AppState.shared

    var body: some View {
        Text(appState.transcription.text)  // Only re-renders on transcription changes
            .onAppear {
                appState.transcription.startRecording()
            }
    }
}
```

**Benefits:**
- Fine-grained UI updates (30-40% performance improvement)
- Clearer state ownership
- Easier testing (test slices independently)
- Better code organization

### Phase 3: Feature Implementation (Weeks 4-5)

#### 3.1 Complete Export Formats

**Current Issue:** PDF, DOCX, SRT exports return plain text

**3.1.1 PDF Export (PDFKit)**

**Create:** `VoiceFlow/Services/Export/PDFExportService.swift`
```swift
import PDFKit
import AppKit

public actor PDFExportService {
    public func exportToPDF(
        session: TranscriptionSession,
        configuration: ExportConfiguration
    ) async throws -> URL {
        let pdfDocument = PDFDocument()

        // Create attributed string with formatting
        let content = NSMutableAttributedString()

        // Title
        if configuration.includeMetadata {
            let title = NSAttributedString(
                string: "Transcription Session\n\n",
                attributes: [
                    .font: NSFont.boldSystemFont(ofSize: 18),
                    .foregroundColor: NSColor.labelColor
                ]
            )
            content.append(title)

            // Metadata
            let metadata = formatMetadata(session)
            content.append(metadata)
            content.append(NSAttributedString(string: "\n\n"))
        }

        // Transcription text
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let body = NSAttributedString(
            string: session.transcription,
            attributes: [.font: bodyFont]
        )
        content.append(body)

        // Create PDF page
        let pageSize = NSSize(width: 612, height: 792)  // Letter size
        let page = PDFPage(attributedString: content, bounds: NSRect(origin: .zero, size: pageSize))

        pdfDocument.insert(page!, at: 0)

        // Save to temporary file
        let filename = "\(session.id.uuidString).pdf"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        pdfDocument.write(to: url)

        return url
    }

    private func formatMetadata(_ session: TranscriptionSession) -> NSAttributedString {
        let metadata = NSMutableAttributedString()
        let font = NSFont.systemFont(ofSize: 10)
        let color = NSColor.secondaryLabelColor

        metadata.append(NSAttributedString(
            string: "Date: \(session.startTime.formatted())\n",
            attributes: [.font: font, .foregroundColor: color]
        ))
        metadata.append(NSAttributedString(
            string: "Duration: \(formatDuration(session.duration))\n",
            attributes: [.font: font, .foregroundColor: color]
        ))
        metadata.append(NSAttributedString(
            string: "Words: \(session.wordCount)\n",
            attributes: [.font: font, .foregroundColor: color]
        ))

        return metadata
    }
}
```

**3.1.2 DOCX Export**

**Add Dependency:** `DocX` (third-party library)
```swift
// Package.swift
dependencies: [
    // ... existing
    .package(url: "https://github.com/shinjukunian/DocX", from: "0.3.0")
]
```

**Create:** `VoiceFlow/Services/Export/DOCXExportService.swift`
```swift
import DocX

public actor DOCXExportService {
    public func exportToDOCX(
        session: TranscriptionSession,
        configuration: ExportConfiguration
    ) async throws -> URL {
        let document = Document()

        // Add title
        if configuration.includeMetadata {
            document.add(Paragraph("Transcription Session")
                .bold()
                .fontSize(18))
            document.add(Paragraph(""))

            // Add metadata table
            let metadata = [
                ["Date:", session.startTime.formatted()],
                ["Duration:", formatDuration(session.duration)],
                ["Words:", "\(session.wordCount)"]
            ]
            document.add(Table(metadata))
            document.add(Paragraph(""))
        }

        // Add transcription text
        document.add(Paragraph(session.transcription))

        // Save
        let filename = "\(session.id.uuidString).docx"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try document.write(to: url)

        return url
    }
}
```

**3.1.3 SRT Subtitle Export**

**Create:** `VoiceFlow/Services/Export/SRTExportService.swift`
```swift
public actor SRTExportService {
    public func exportToSRT(
        session: TranscriptionSession,
        configuration: ExportConfiguration
    ) async throws -> URL {
        var srtContent = ""
        var sequenceNumber = 1

        // Split transcription into segments (every 5 seconds or 50 chars)
        let segments = splitIntoSegments(session)

        for segment in segments {
            srtContent += "\(sequenceNumber)\n"
            srtContent += formatTimestamp(segment.startTime)
            srtContent += " --> "
            srtContent += formatTimestamp(segment.endTime)
            srtContent += "\n"
            srtContent += segment.text
            srtContent += "\n\n"

            sequenceNumber += 1
        }

        // Save
        let filename = "\(session.id.uuidString).srt"
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try srtContent.write(to: url, atomically: true, encoding: .utf8)

        return url
    }

    private func formatTimestamp(_ time: TimeInterval) -> String {
        let hours = Int(time / 3600)
        let minutes = Int((time.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(time.truncatingRemainder(dividingBy: 60))
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, milliseconds)
    }

    private func splitIntoSegments(_ session: TranscriptionSession) -> [TranscriptionSegment] {
        // Implementation: Split by sentence boundaries or time chunks
        // Use session.segments if available, otherwise create synthetic segments
        []
    }
}
```

**Update ExportManager:**
```swift
// ExportManager.swift
public actor ExportManager {
    private let pdfService = PDFExportService()
    private let docxService = DOCXExportService()
    private let srtService = SRTExportService()

    public func export(
        session: TranscriptionSession,
        format: ExportFormat,
        configuration: ExportConfiguration
    ) async throws -> URL {
        switch format {
        case .text:
            return try await exportText(session: session, configuration: configuration)
        case .markdown:
            return try await exportMarkdown(session: session, configuration: configuration)
        case .pdf:
            return try await pdfService.exportToPDF(session: session, configuration: configuration)
        case .docx:
            return try await docxService.exportToDOCX(session: session, configuration: configuration)
        case .srt:
            return try await srtService.exportToSRT(session: session, configuration: configuration)
        }
    }
}
```

#### 3.2 Complete Floating Widget Window

**Current Issue:** Widget created but window not shown

**Create:** `VoiceFlow/Views/FloatingWidgetWindow.swift`
```swift
import AppKit
import SwiftUI

public class FloatingWidgetWindow: NSWindow {

    public init(widget: FloatingMicrophoneWidget) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        // Configure window
        self.isOpaque = false
        self.backgroundColor = .clear
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true

        // Set content view
        let hostingView = NSHostingView(rootView: widget)
        self.contentView = hostingView

        // Position in top-right corner
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 220  // 20px margin
            let y = screenFrame.maxY - 100  // 20px margin
            self.setFrameOrigin(NSPoint(x: x, y: y))
        }
    }

    public func show() {
        self.orderFrontRegardless()
        self.alphaValue = 0
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            self.animator().alphaValue = 1.0
        }
    }

    public func hide() {
        NSAnimationContext.runAnimationGroup({ context in
            context.duration = 0.3
            self.animator().alphaValue = 0
        }, completionHandler: {
            self.orderOut(nil)
            self.alphaValue = 1.0
        })
    }
}
```

**Update AppState:**
```swift
// AppState.swift
private var floatingWidgetWindow: FloatingWidgetWindow?

private func setupFloatingWidget() {
    guard isFloatingWidgetEnabled else { return }

    let viewModel = SimpleTranscriptionViewModel()
    let widget = FloatingMicrophoneWidget(viewModel: viewModel)
    floatingWidget = widget

    floatingWidgetWindow = FloatingWidgetWindow(widget: widget)

    print("🎤 Floating widget window created")
}

public func showFloatingWidget() {
    guard isFloatingWidgetEnabled else { return }

    floatingWidgetWindow?.show()
    isFloatingWidgetVisible = true
}

public func hideFloatingWidget() {
    floatingWidgetWindow?.hide()
    isFloatingWidgetVisible = false
}
```

#### 3.3 Performance Dashboard

**Create:** `VoiceFlow/Features/Dashboard/PerformanceDashboardView.swift`
```swift
import SwiftUI
import Charts

@MainActor
public struct PerformanceDashboardView: View {
    @State private var monitor = PerformanceMonitor.shared
    @State private var metrics: [PerformanceMetric] = []

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Real-time metrics
                MetricsGrid(metrics: currentMetrics)

                // CPU usage chart
                CPUChartView(data: metrics)

                // Memory usage chart
                MemoryChartView(data: metrics)

                // Audio buffer stats
                BufferPoolStatsView()

                // Network latency
                NetworkLatencyView()
            }
            .padding()
        }
        .task {
            await streamMetrics()
        }
    }

    private var currentMetrics: [DisplayMetric] {
        [
            DisplayMetric(
                title: "CPU Usage",
                value: "\(Int(monitor.currentCPUUsage))%",
                color: cpuColor(monitor.currentCPUUsage)
            ),
            DisplayMetric(
                title: "Memory",
                value: formatBytes(monitor.currentMemoryUsage),
                color: memoryColor(monitor.currentMemoryUsage)
            ),
            DisplayMetric(
                title: "Buffer Hit Rate",
                value: "\(Int(monitor.bufferPoolHitRate * 100))%",
                color: .green
            ),
            DisplayMetric(
                title: "Network Latency",
                value: "\(Int(monitor.networkLatency * 1000))ms",
                color: latencyColor(monitor.networkLatency)
            )
        ]
    }

    private func streamMetrics() async {
        for await metric in monitor.metricsStream {
            metrics.append(metric)
            if metrics.count > 100 {
                metrics.removeFirst()
            }
        }
    }
}

struct MetricsGrid: View {
    let metrics: [DisplayMetric]

    var body: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()),
            GridItem(.flexible())
        ], spacing: 16) {
            ForEach(metrics) { metric in
                MetricCard(metric: metric)
            }
        }
    }
}

struct MetricCard: View {
    let metric: DisplayMetric

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(metric.title)
                .font(.caption)
                .foregroundStyle(.secondary)

            Text(metric.value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(metric.color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }
}

struct CPUChartView: View {
    let data: [PerformanceMetric]

    var body: some View {
        VStack(alignment: .leading) {
            Text("CPU Usage Over Time")
                .font(.headline)

            Chart(data) { metric in
                LineMark(
                    x: .value("Time", metric.timestamp),
                    y: .value("CPU", metric.cpuUsage)
                )
                .foregroundStyle(.blue)
            }
            .frame(height: 200)
        }
        .padding()
        .background(Color(.windowBackgroundColor))
        .cornerRadius(12)
    }
}

// Similar implementations for MemoryChartView, BufferPoolStatsView, NetworkLatencyView
```

**Add to Navigation:**
```swift
// ContentView.swift
.toolbar {
    ToolbarItem(placement: .navigation) {
        Button("Dashboard") {
            showDashboard = true
        }
    }
}
.sheet(isPresented: $showDashboard) {
    PerformanceDashboardView()
}
```

### Phase 4: Testing & Quality (Week 6)

#### 4.1 Achieve 95%+ Test Coverage

**Current Coverage:** ~75-80%

**Coverage Gaps:**
1. UI components (SwiftUI views)
2. Export functionality
3. Floating widget interaction
4. Global hotkeys
5. Error recovery paths

**Strategy:**

**4.1.1 UI Testing with Swift Testing**
```swift
// VoiceFlowTests/UI/ContentViewTests.swift
import Testing
@testable import VoiceFlow

@Suite("ContentView Tests")
@MainActor
struct ContentViewTests {

    @Test("View displays transcription text")
    func displaysTranscriptionText() {
        let appState = AppState()
        appState.transcriptionText = "Test transcription"

        let view = ContentView()
            .environment(appState)

        // Use ViewInspector or similar
        #expect(view.body.contains("Test transcription"))
    }

    @Test("Record button triggers recording",
          .timeLimit(.minutes(1)))
    func recordButtonTriggersRecording() async {
        let appState = AppState()

        // Simulate button tap
        await appState.startTranscriptionSession()

        #expect(appState.isRecording == true)
    }
}
```

**Add ViewInspector:**
```swift
// Package.swift
dependencies: [
    .package(url: "https://github.com/nalexn/ViewInspector", from: "0.9.0")
]
```

**4.1.2 Snapshot Testing**
```swift
// VoiceFlowTests/Snapshots/SnapshotTests.swift
import Testing
import SnapshotTesting
@testable import VoiceFlow

@Suite("Snapshot Tests")
@MainActor
struct SnapshotTests {

    @Test("Transcription view light mode")
    func transcriptionViewLightMode() {
        let view = ContentView()
            .environment(\.colorScheme, .light)

        assertSnapshot(matching: view, as: .image)
    }

    @Test("Transcription view dark mode")
    func transcriptionViewDarkMode() {
        let view = ContentView()
            .environment(\.colorScheme, .dark)

        assertSnapshot(matching: view, as: .image)
    }
}
```

**4.1.3 Integration Tests for Export**
```swift
// VoiceFlowTests/Integration/ExportIntegrationTests.swift
import Testing
@testable import VoiceFlow

@Suite("Export Integration Tests")
struct ExportIntegrationTests {

    @Test("Export to all formats successfully",
          arguments: ExportFormat.allCases)
    func exportToAllFormats(format: ExportFormat) async throws {
        let session = TranscriptionSession.fixture()
        let manager = ExportManager()

        let url = try await manager.export(
            session: session,
            format: format,
            configuration: .default
        )

        #expect(FileManager.default.fileExists(atPath: url.path))

        // Verify file content
        switch format {
        case .pdf:
            let data = try Data(contentsOf: url)
            #expect(data.starts(with: [0x25, 0x50, 0x44, 0x46]))  // %PDF
        case .docx:
            // Verify ZIP structure
            #expect(url.pathExtension == "docx")
        case .srt:
            let content = try String(contentsOf: url)
            #expect(content.contains("-->"))  // SRT format marker
        default:
            break
        }

        // Cleanup
        try? FileManager.default.removeItem(at: url)
    }
}
```

**4.1.4 Performance Regression Tests**
```swift
// VoiceFlowTests/Performance/PerformanceRegressionTests.swift
import Testing
@testable import VoiceFlow

@Suite("Performance Regression Tests")
struct PerformanceRegressionTests {

    @Test("Audio buffer pool maintains >90% hit rate",
          .timeLimit(.seconds(30)))
    func audioBufferPoolPerformance() async {
        let pool = AudioBufferPool()
        var hits = 0
        var total = 0

        for _ in 0..<1000 {
            let buffer = try? await pool.dequeueBuffer()
            if buffer != nil {
                hits += 1
                await pool.enqueueBuffer(buffer!)
            }
            total += 1
        }

        let hitRate = Double(hits) / Double(total)
        #expect(hitRate > 0.90, "Hit rate \(hitRate) below 90% threshold")
    }

    @Test("Transcription processing latency <100ms",
          .timeLimit(.seconds(10)))
    func transcriptionLatency() async throws {
        let engine = TranscriptionEngine()
        let audioData = generateTestAudio()  // 1 second of audio

        let startTime = Date()
        _ = try await engine.process(audioData)
        let duration = Date().timeIntervalSince(startTime)

        #expect(duration < 0.1, "Processing took \(duration)s, expected <0.1s")
    }
}
```

**4.1.5 Coverage Report Generation**
```bash
# Generate coverage report
swift test --enable-code-coverage

# Convert to HTML
xcrun llvm-cov show \
    .build/debug/VoiceFlowPackageTests.xctest/Contents/MacOS/VoiceFlowPackageTests \
    -instr-profile=.build/debug/codecov/default.profdata \
    -format=html \
    -output-dir=coverage-report

# Open report
open coverage-report/index.html
```

**Target Coverage by Module:**
- Core: 95%+
- Services: 90%+
- ViewModels: 90%+
- Views: 80%+ (SwiftUI testing limitations)
- Overall: 90%+

#### 4.2 Code Quality Gates

**Install SwiftLint & SwiftFormat:**
```bash
# Via Homebrew
brew install swiftlint swiftformat

# Or add to Package.swift plugins
dependencies: [
    .package(url: "https://github.com/realm/SwiftLint", from: "0.54.0"),
    .package(url: "https://github.com/nicklockwood/SwiftFormat", from: "0.53.0")
]
```

**Create:** `.swiftlint.yml`
```yaml
# VoiceFlow SwiftLint Configuration

disabled_rules:
  - line_length  # Handled by SwiftFormat
  - trailing_whitespace  # Handled by SwiftFormat

opt_in_rules:
  - explicit_init
  - explicit_self
  - explicit_type_interface
  - strict_fileprivate
  - unneeded_parentheses_in_closure_argument
  - vertical_whitespace_closing_braces

analyzer_rules:
  - explicit_self
  - unused_declaration
  - unused_import

# Swift 6 specific
swift_version: "6.2"

# Custom rules
custom_rules:
  actor_isolation:
    name: "Proper Actor Isolation"
    regex: "var (?!.*@MainActor).*: .*ObservableObject"
    message: "ObservableObject should be @MainActor isolated"
    severity: warning

  sendable_conformance:
    name: "Sendable Conformance"
    regex: "class .*(?!: .*Sendable)"
    message: "Consider adding Sendable conformance for Swift 6"
    severity: warning

# Exclude
excluded:
  - .build
  - ThirdParty
  - VoiceFlowTests/Fixtures
```

**Create:** `.swiftformat`
```
# VoiceFlow SwiftFormat Configuration

--swiftversion 6.2
--language-mode 6

# Indentation
--indent 4
--indentcase false
--tabwidth 4

# Wrapping
--maxwidth 120
--wraparguments before-first
--wrapcollections before-first

# Spacing
--trimwhitespace always
--insertlines enabled
--removelines enabled

# Organization
--organizetypes actor,class,enum,struct
--structthreshold 0

# Modern Swift
--redundanttype inferred
--redundantclosure true
--asynccapture enabled

# Exclude
--exclude .build,ThirdParty
```

**Pre-commit Hook:**
```bash
# Create .git/hooks/pre-commit
#!/bin/bash

echo "Running SwiftLint..."
swiftlint lint --quiet --strict

if [ $? -ne 0 ]; then
    echo "SwiftLint failed. Please fix errors before committing."
    exit 1
fi

echo "Running SwiftFormat..."
swiftformat --lint . --quiet

if [ $? -ne 0 ]; then
    echo "SwiftFormat failed. Run 'swiftformat .' to fix."
    exit 1
fi

echo "Running tests..."
swift test

if [ $? -ne 0 ]; then
    echo "Tests failed. Please fix before committing."
    exit 1
fi

echo "✅ All checks passed!"
```

**CI/CD Pipeline:**
```yaml
# .github/workflows/quality.yml
name: Code Quality

on: [push, pull_request]

jobs:
  quality:
    runs-on: macos-14

    steps:
      - uses: actions/checkout@v3

      - name: Set up Swift
        uses: swift-actions/setup-swift@v1
        with:
          swift-version: '6.2'

      - name: SwiftLint
        run: |
          brew install swiftlint
          swiftlint lint --strict

      - name: SwiftFormat
        run: |
          brew install swiftformat
          swiftformat --lint .

      - name: Build
        run: swift build -c release

      - name: Test
        run: swift test --enable-code-coverage

      - name: Coverage
        run: |
          xcrun llvm-cov export \
            .build/debug/VoiceFlowPackageTests.xctest/Contents/MacOS/VoiceFlowPackageTests \
            -instr-profile=.build/debug/codecov/default.profdata \
            -format=lcov > coverage.lcov

      - name: Upload Coverage
        uses: codecov/codecov-action@v3
        with:
          files: coverage.lcov
```

---

## 📊 Performance Optimization Strategy

### Current Performance (Baseline)
- **Audio buffer pooling:** 85% reduction in allocations ✅
- **Concurrent processing:** 2.8-4.4x speed improvement ✅
- **Memory usage:** ~50-100MB typical ✅
- **Network latency:** ~50-100ms (Deepgram) ✅

### VoiceFlow 2.0 Performance Targets

#### Target 1: 95%+ Buffer Pool Hit Rate
**Current:** ~90%
**Strategy:**
- Implement InlineArray for fixed buffers
- Add adaptive pool sizing based on usage patterns
- Pre-warm pool on app launch

**Implementation:**
```swift
// AudioBufferPool.swift
public actor AudioBufferPool {
    // Use Swift 6.2 InlineArray for hot path
    private var fastBuffers: InlineArray<16, AVAudioPCMBuffer>
    private var fallbackBuffers: [AVAudioPCMBuffer] = []

    // Adaptive sizing
    private var demandHistory: [Int] = []
    private let targetHitRate: Double = 0.95

    public func adjustPoolSize() async {
        let avgDemand = demandHistory.reduce(0, +) / demandHistory.count
        let currentSize = fastBuffers.count + fallbackBuffers.count

        if currentHitRate < targetHitRate {
            let newSize = Int(Double(currentSize) * 1.2)
            await growPool(to: newSize)
        }
    }
}
```

#### Target 2: <50ms Transcription Latency
**Current:** ~100ms
**Strategy:**
- Optimize WebSocket frame handling
- Implement request batching
- Use concurrent processing pipelines

**Implementation:**
```swift
// DeepgramClient.swift
public actor DeepgramClient {
    // Concurrent processing with AsyncAlgorithms
    private func processAudioStream() async throws {
        for try await batch in audioStream
            .chunks(ofCount: 10)  // Batch 10 frames
            .parallelMap(maxConcurrency: 4) { frames in
                await self.processFrame(frames)
            } {
            // Send batch in single WebSocket message
            await sendBatch(batch)
        }
    }
}
```

#### Target 3: 30% Reduction in Memory Footprint
**Current:** ~50-100MB
**Target:** ~35-70MB
**Strategy:**
- Use value types where possible
- Implement memory pressure handling
- Release unused resources aggressively

**Implementation:**
```swift
// AppState.swift
public func handleMemoryWarning() {
    // Clear caches
    recentSessions.removeAll { $0.age > .days(7) }

    // Release audio buffers
    await AudioBufferPool.shared.releaseIdleBuffers()

    // Clear transcription history
    if transcriptionText.count > 10000 {
        transcriptionText = String(transcriptionText.suffix(5000))
    }
}

// Register for memory warnings
NotificationCenter.default.addObserver(
    forName: NSApplication.willResignActiveNotification,
    object: nil,
    queue: .main
) { _ in
    await handleMemoryWarning()
}
```

#### Target 4: Real-Time Performance Monitoring
**New Feature:** Dashboard with live metrics

**Metrics to Track:**
1. CPU usage (per-core)
2. Memory usage (active/wired/compressed)
3. Network throughput
4. Audio buffer hit rate
5. Transcription latency (p50, p95, p99)
6. UI frame rate (60fps target)

**Implementation:**
```swift
// PerformanceMonitor.swift
public actor PerformanceMonitor {
    public let metricsStream: AsyncStream<PerformanceMetric>

    public init() {
        let (stream, continuation) = AsyncStream<PerformanceMetric>.makeStream()
        self.metricsStream = stream

        Task {
            while !Task.isCancelled {
                let metric = await collectMetrics()
                continuation.yield(metric)
                try await Task.sleep(for: .seconds(1))
            }
        }
    }

    private func collectMetrics() async -> PerformanceMetric {
        PerformanceMetric(
            timestamp: Date(),
            cpuUsage: getCurrentCPUUsage(),
            memoryUsage: getCurrentMemoryUsage(),
            networkLatency: await getNetworkLatency(),
            bufferHitRate: await AudioBufferPool.shared.hitRate(),
            transcriptionLatency: await getTranscriptionLatency(),
            uiFrameRate: await getUIFrameRate()
        )
    }
}
```

### Performance Benchmarking

**Create:** `VoiceFlowTests/Performance/BenchmarkSuite.swift`
```swift
import Testing
@testable import VoiceFlow

@Suite("Performance Benchmarks")
struct BenchmarkSuite {

    @Test("Baseline: Audio processing throughput")
    func audioProcessingThroughput() async throws {
        let iterations = 1000
        let audioData = generateTestAudio(duration: 0.1)  // 100ms
        let engine = AudioProcessingActor()

        let startTime = Date()

        for _ in 0..<iterations {
            _ = try await engine.process(audioData)
        }

        let duration = Date().timeIntervalSince(startTime)
        let throughput = Double(iterations) / duration

        print("Throughput: \(Int(throughput)) frames/sec")
        #expect(throughput > 100)  // Should process >100 frames/sec
    }

    @Test("Baseline: Memory allocation rate")
    func memoryAllocationRate() async throws {
        let startMemory = getMemoryUsage()

        let pool = AudioBufferPool()
        for _ in 0..<1000 {
            let buffer = try await pool.dequeueBuffer()
            await pool.enqueueBuffer(buffer)
        }

        let endMemory = getMemoryUsage()
        let allocated = endMemory - startMemory

        print("Memory allocated: \(formatBytes(allocated))")
        #expect(allocated < 10_000_000)  // Less than 10MB
    }
}
```

**Run Benchmarks:**
```bash
# Run performance suite
swift test --filter BenchmarkSuite

# Compare results over time
swift test --filter BenchmarkSuite > benchmarks/baseline-2025-11-02.txt
```

---

## 🔄 Migration Roadmap

### Week-by-Week Plan

#### Week 1: Foundation & Fixes
**Goals:**
- Fix critical issues (test config, main.swift, toolchain)
- Set up development infrastructure
- Establish baseline metrics

**Tasks:**
1. **Day 1-2:** Critical fixes
   - Fix Package.swift test configuration
   - Add main.swift entry point
   - Configure Swift toolchain
   - Verify `swift build` and `swift test` work

2. **Day 3-4:** Development infrastructure
   - Install and configure SwiftLint + SwiftFormat
   - Set up pre-commit hooks
   - Configure CI/CD pipeline
   - Install MCP servers (XcodeBuildMCP, etc.)

3. **Day 5:** Baseline measurement
   - Run performance benchmarks
   - Generate coverage report (current: ~75%)
   - Document current architecture
   - Create migration branch

**Deliverables:**
- ✅ All builds and tests pass via SPM
- ✅ CI/CD pipeline operational
- ✅ Baseline metrics documented
- ✅ Development environment ready

#### Week 2: Architecture Enhancement (Part 1)
**Goals:**
- Implement protocol abstractions
- Add dependency injection
- Begin state slicing

**Tasks:**
1. **Day 1-2:** Protocol layer
   - Create `ServiceProtocols.swift`
   - Define interfaces for all services
   - Update services to conform
   - Add protocol documentation

2. **Day 3:** Dependency injection
   - Implement `DIContainer`
   - Register all services
   - Update app initialization
   - Add tests for DI container

3. **Day 4-5:** State slicing (Phase 1)
   - Create `TranscriptionState.swift`
   - Create `UIState.swift`
   - Create `ConfigurationState.swift`
   - Update AppState to use slices
   - Migrate 50% of views to new state

**Deliverables:**
- ✅ Protocol layer complete with docs
- ✅ DI container operational
- ✅ State slicing implemented
- ✅ 50% of views migrated

**Risk Mitigation:**
- Use checkpoints before each major change
- Keep old AppState properties during migration
- Gradual rollout to views
- Comprehensive testing after each phase

#### Week 3: Architecture Enhancement (Part 2)
**Goals:**
- Complete state slicing
- Refactor feature modules
- Improve service isolation

**Tasks:**
1. **Day 1-2:** Complete state migration
   - Migrate remaining 50% of views
   - Remove old AppState properties
   - Add computed properties for backwards compatibility
   - Update all tests

2. **Day 3-4:** Feature modules
   - Reorganize Features/ directory
   - Create self-contained modules
   - Move tests to feature directories
   - Update imports

3. **Day 5:** Service refactoring
   - Reduce AppState dependencies
   - Implement service protocols fully
   - Add service tests with mocks
   - Document service contracts

**Deliverables:**
- ✅ 100% state migration complete
- ✅ Feature modules reorganized
- ✅ Services decoupled from AppState
- ✅ Test coverage maintained at 75%+

#### Week 4: Feature Completion (Part 1)
**Goals:**
- Complete export formats (PDF, DOCX, SRT)
- Add export tests
- Improve export UX

**Tasks:**
1. **Day 1:** PDF export
   - Implement `PDFExportService`
   - Add formatting options
   - Test with various transcription lengths
   - Handle edge cases

2. **Day 2:** DOCX export
   - Integrate DocX library
   - Implement `DOCXExportService`
   - Add table formatting for metadata
   - Test cross-platform compatibility

3. **Day 3:** SRT export
   - Implement `SRTExportService`
   - Implement segment splitting logic
   - Validate SRT format compliance
   - Test with media players

4. **Day 4:** Integration
   - Update `ExportManager`
   - Update UI with new formats
   - Add format selection
   - Add preview functionality

5. **Day 5:** Testing
   - Integration tests for all formats
   - Performance tests
   - Edge case tests
   - User acceptance testing

**Deliverables:**
- ✅ PDF export functional
- ✅ DOCX export functional
- ✅ SRT export functional
- ✅ Export tests at 90%+ coverage

#### Week 5: Feature Completion (Part 2)
**Goals:**
- Complete floating widget window
- Add performance dashboard
- Polish UI/UX

**Tasks:**
1. **Day 1-2:** Floating widget
   - Implement `FloatingWidgetWindow`
   - Add window positioning
   - Add animations
   - Integrate with global hotkeys
   - Test window behaviors

2. **Day 3-4:** Performance dashboard
   - Create `PerformanceDashboardView`
   - Implement real-time charts
   - Add metrics visualization
   - Style dashboard
   - Add to main navigation

3. **Day 5:** Polish
   - UI/UX review
   - Animation improvements
   - Accessibility audit
   - Performance optimization

**Deliverables:**
- ✅ Floating widget fully functional
- ✅ Performance dashboard live
- ✅ UI polish complete
- ✅ Accessibility compliant

#### Week 6: Testing & Quality
**Goals:**
- Migrate to Swift Testing
- Achieve 95%+ coverage
- Performance optimization

**Tasks:**
1. **Day 1:** Swift Testing setup
   - Add dependency
   - Create utilities
   - Document migration patterns
   - Create test fixtures

2. **Day 2-3:** Test migration
   - Migrate unit tests
   - Migrate integration tests
   - Migrate performance tests
   - Remove XCTest files

3. **Day 4:** Coverage improvement
   - Add UI tests
   - Add export tests
   - Add edge case tests
   - Generate coverage report
   - Aim for 95%+

4. **Day 5:** Performance optimization
   - Profile with Instruments
   - Optimize hot paths
   - Implement InlineArray
   - Run benchmarks
   - Document improvements

**Deliverables:**
- ✅ 100% Swift Testing migration
- ✅ 95%+ test coverage
- ✅ Performance targets met
- ✅ Benchmarks documented

**Final Quality Gates:**
- All tests passing (100%)
- Code coverage ≥95%
- SwiftLint: 0 errors, <10 warnings
- SwiftFormat: 100% compliant
- Performance benchmarks: All targets met
- Documentation: 100% up-to-date

---

## 🛠️ Tool Integration & Automation

### Claude Code Integration

#### Recommended Workflows

**1. Feature Development**
```
User: "Add PDF export to VoiceFlow"

Claude Code:
  → Uses @Explore to understand export system
  → Creates architecture plan
  → Implements PDFExportService
  → Adds tests (Swift Testing)
  → Runs swift test via MCP
  → Creates commit
  → Checkpoint saved automatically

User: (Reviews changes)

Claude Code:
  → If issues: Esc+Esc to rewind
  → If good: Continue to next feature
```

**2. Refactoring Workflow**
```
User: "Refactor AppState to use state slicing"

Claude Code:
  → Checkpoint: Before refactoring
  → Creates state slice files
  → Updates AppState
  → Updates all references (Codex CLI for bulk changes)
  → Runs tests
  → If tests fail: Rewind and adjust
  → If tests pass: Commit

MCP Tools Used:
  - xcodebuildmcp__swift_package_test (after each change)
  - xcodebuildmcp__swift_package_build (verify build)
```

**3. Testing Workflow**
```
User: "Add tests for export formats"

Claude Code:
  → Analyzes ExportManager
  → Generates test cases with Swift Testing
  → Runs tests
  → Generates coverage report
  → Identifies gaps
  → Adds additional tests
  → Verifies 95%+ coverage

MCP Tools Used:
  - xcodebuildmcp__swift_package_test --enable-code-coverage
  - custom__voiceflow_coverage_report
```

#### Custom MCP Server: voiceflow-dev

**Create:** `mcp-servers/voiceflow-dev/index.js`
```javascript
#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import { exec } from "child_process";
import { promisify } from "util";

const execAsync = promisify(exec);

const server = new Server(
  {
    name: "voiceflow-dev",
    version: "1.0.0",
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool: Run performance benchmarks
server.setRequestHandler("tools/call", async (request) => {
  if (request.params.name === "run_benchmarks") {
    const { stdout, stderr } = await execAsync(
      "swift test --filter BenchmarkSuite",
      { cwd: "/Users/lukaj/voiceflow" }
    );

    return {
      content: [
        {
          type: "text",
          text: `Benchmark Results:\n${stdout}\n${stderr}`,
        },
      ],
    };
  }

  // Tool: Generate coverage report
  if (request.params.name === "coverage_report") {
    await execAsync(
      "swift test --enable-code-coverage",
      { cwd: "/Users/lukaj/voiceflow" }
    );

    const { stdout } = await execAsync(
      "xcrun llvm-cov report .build/debug/VoiceFlowPackageTests.xctest/Contents/MacOS/VoiceFlowPackageTests -instr-profile=.build/debug/codecov/default.profdata",
      { cwd: "/Users/lukaj/voiceflow" }
    );

    return {
      content: [
        {
          type: "text",
          text: `Coverage Report:\n${stdout}`,
        },
      ],
    };
  }

  // Tool: Check actor isolation
  if (request.params.name === "check_actor_isolation") {
    const { stdout, stderr } = await execAsync(
      "swift build -Xswiftc -Xfrontend -Xswiftc -warn-concurrency",
      { cwd: "/Users/lukaj/voiceflow" }
    );

    return {
      content: [
        {
          type: "text",
          text: `Actor Isolation Check:\n${stdout}\n${stderr}`,
        },
      ],
    };
  }

  // Tool: Analyze performance
  if (request.params.name === "analyze_performance") {
    const { stdout } = await execAsync(
      "swift run Scripts/PerformanceAnalyzer",
      { cwd: "/Users/lukaj/voiceflow" }
    );

    return {
      content: [
        {
          type: "text",
          text: `Performance Analysis:\n${stdout}`,
        },
      ],
    };
  }

  throw new Error(`Unknown tool: ${request.params.name}`);
});

// List available tools
server.setRequestHandler("tools/list", async () => {
  return {
    tools: [
      {
        name: "run_benchmarks",
        description: "Run VoiceFlow performance benchmark suite",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "coverage_report",
        description: "Generate test coverage report",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "check_actor_isolation",
        description: "Check Swift 6 actor isolation compliance",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
      {
        name: "analyze_performance",
        description: "Analyze runtime performance metrics",
        inputSchema: {
          type: "object",
          properties: {},
        },
      },
    ],
  };
});

async function main() {
  const transport = new StdioServerTransport();
  await server.connect(transport);
}

main().catch((error) => {
  console.error("Server error:", error);
  process.exit(1);
});
```

**Install:**
```bash
cd mcp-servers/voiceflow-dev
npm init -y
npm install @modelcontextprotocol/sdk
chmod +x index.js
```

**Configure Claude Desktop:**
```json
{
  "mcpServers": {
    "voiceflow-dev": {
      "command": "node",
      "args": ["/Users/lukaj/voiceflow/mcp-servers/voiceflow-dev/index.js"]
    }
  }
}
```

### Codex CLI Workflows

#### Workflow 1: Bulk Refactoring
```bash
# Refactor all ViewModels to use protocols
codex exec "For all files in VoiceFlow/ViewModels/, extract a protocol for each ViewModel and update the implementation to conform. Ensure proper @MainActor isolation."

# Expected result:
# - 6 protocols created
# - 6 ViewModels updated
# - Tests still passing
# - Actor isolation maintained
```

#### Workflow 2: Documentation Generation
```bash
# Generate comprehensive docs
codex doc generate \
  --input VoiceFlow/Core/ \
  --output docs/api/ \
  --format markdown \
  --include-examples

# Produces:
# docs/api/
#   ├── AppState.md
#   ├── TranscriptionEngine.md
#   ├── PerformanceMonitor.md
#   └── ...
```

#### Workflow 3: Test Generation
```bash
# Generate missing tests
codex test generate \
  --target VoiceFlow/Services/Export/ \
  --framework swift-testing \
  --coverage-goal 95 \
  --output VoiceFlowTests/Services/Export/

# Creates:
# - Comprehensive test suites
# - Edge case tests
# - Performance tests
# - Mock implementations
```

#### Workflow 4: Code Review
```bash
# Pre-commit review
codex review \
  --focus actor-isolation \
  --focus sendable-conformance \
  --focus performance \
  --threshold strict

# Output example:
# ✅ Actor isolation correct in 45/45 files
# ⚠️ Consider adding Sendable to TranscriptionSession (line 23)
# ✅ No performance regressions detected
# ⚠️ Optional: Use InlineArray in AudioBufferPool (line 67) for better performance
```

### Automation Scripts

#### Script 1: Daily Health Check
**Create:** `scripts/daily-health-check.sh`
```bash
#!/bin/bash

echo "🏥 VoiceFlow Health Check"
echo "========================"

# Build check
echo "📦 Building..."
swift build -c release
if [ $? -ne 0 ]; then
    echo "❌ Build failed"
    exit 1
fi

# Test check
echo "🧪 Running tests..."
swift test
if [ $? -ne 0 ]; then
    echo "❌ Tests failed"
    exit 1
fi

# Lint check
echo "🔍 Linting..."
swiftlint lint --quiet --strict
if [ $? -ne 0 ]; then
    echo "⚠️ Linting issues found"
fi

# Format check
echo "✨ Checking formatting..."
swiftformat --lint . --quiet
if [ $? -ne 0 ]; then
    echo "⚠️ Formatting issues found"
fi

# Coverage check
echo "📊 Checking coverage..."
swift test --enable-code-coverage > /dev/null 2>&1
COVERAGE=$(xcrun llvm-cov report \
  .build/debug/VoiceFlowPackageTests.xctest/Contents/MacOS/VoiceFlowPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata 2>/dev/null | \
  grep "TOTAL" | awk '{print $NF}' | sed 's/%//')

if (( $(echo "$COVERAGE < 90" | bc -l) )); then
    echo "⚠️ Coverage is ${COVERAGE}% (target: 90%)"
else
    echo "✅ Coverage is ${COVERAGE}%"
fi

# Performance benchmarks
echo "🚀 Running benchmarks..."
swift test --filter BenchmarkSuite > /tmp/benchmark-results.txt
if [ $? -eq 0 ]; then
    echo "✅ Benchmarks passed"
    cat /tmp/benchmark-results.txt | grep "Throughput:"
else
    echo "⚠️ Some benchmarks failed"
fi

echo ""
echo "✅ Health check complete!"
```

#### Script 2: Release Preparation
**Create:** `scripts/prepare-release.sh`
```bash
#!/bin/bash

VERSION=$1

if [ -z "$VERSION" ]; then
    echo "Usage: ./prepare-release.sh <version>"
    exit 1
fi

echo "📦 Preparing VoiceFlow $VERSION for release"
echo "==========================================="

# 1. Run all checks
echo "1. Running health checks..."
./scripts/daily-health-check.sh
if [ $? -ne 0 ]; then
    echo "❌ Health check failed. Fix issues before release."
    exit 1
fi

# 2. Update version
echo "2. Updating version..."
sed -i '' "s/version: \".*\"/version: \"$VERSION\"/" Package.swift

# 3. Generate changelog
echo "3. Generating changelog..."
git log --oneline $(git describe --tags --abbrev=0)..HEAD > CHANGELOG-$VERSION.md

# 4. Build release binary
echo "4. Building release binary..."
swift build -c release

# 5. Run release tests
echo "5. Running release tests..."
swift test -c release

# 6. Create archive
echo "6. Creating archive..."
tar -czf VoiceFlow-$VERSION.tar.gz \
  -C .build/release \
  VoiceFlow

echo ""
echo "✅ Release $VERSION ready!"
echo "Next steps:"
echo "  1. Review CHANGELOG-$VERSION.md"
echo "  2. Commit version bump: git add . && git commit -m 'Release $VERSION'"
echo "  3. Tag release: git tag -a v$VERSION -m 'Release $VERSION'"
echo "  4. Push: git push && git push --tags"
```

---

## 📚 Documentation & Knowledge Transfer

### Documentation Structure

```
docs/
├── api/                    # API documentation (auto-generated)
│   ├── AppState.md
│   ├── TranscriptionEngine.md
│   └── ...
├── architecture/          # Architecture decisions
│   ├── ADR-001-state-slicing.md
│   ├── ADR-002-dependency-injection.md
│   └── ADR-003-swift-testing.md
├── guides/                # Development guides
│   ├── getting-started.md
│   ├── testing-guide.md
│   ├── performance-guide.md
│   └── contributing.md
├── tutorials/             # Step-by-step tutorials
│   ├── adding-export-format.md
│   ├── creating-service.md
│   └── writing-tests.md
└── VoiceFlow-2.0-Refactoring-Plan.md  # This document
```

### Architecture Decision Records (ADRs)

**Example:** `docs/architecture/ADR-001-state-slicing.md`
```markdown
# ADR-001: State Slicing Pattern

## Status
Accepted (2025-11-02)

## Context
AppState currently contains 30+ properties in a single class, leading to:
- Unnecessary view re-renders when unrelated state changes
- Poor code organization
- Difficult testing

## Decision
Split AppState into feature-specific state slices:
- TranscriptionState
- UIState
- ConfigurationState

Each slice is @Observable and MainActor-isolated.

## Consequences
**Positive:**
- 30-40% reduction in view re-renders
- Clearer state ownership
- Easier testing of individual features
- Better code organization

**Negative:**
- More files to manage
- Slightly more complex initialization
- Learning curve for developers

## Implementation
See Week 2-3 of refactoring plan.
```

### Development Guides

**Create:** `docs/guides/testing-guide.md`
```markdown
# VoiceFlow Testing Guide

## Overview
VoiceFlow uses Swift Testing framework for all tests.

## Test Structure
Tests are organized by module:
- `VoiceFlowTests/Unit/` - Unit tests
- `VoiceFlowTests/Integration/` - Integration tests
- `VoiceFlowTests/Performance/` - Performance tests

## Writing Tests
```swift
import Testing
@testable import VoiceFlow

@Suite("Feature Tests")
struct FeatureTests {
    @Test("Test description")
    func testSomething() {
        #expect(condition)
    }
}
```

## Running Tests
```bash
# All tests
swift test

# Specific suite
swift test --filter FeatureTests

# With coverage
swift test --enable-code-coverage
```

## Best Practices
1. Use descriptive test names
2. Test one thing per test
3. Use fixtures for test data
4. Mock external dependencies
5. Aim for 95%+ coverage
```

### Contributing Guide

**Create:** `docs/guides/contributing.md`
```markdown
# Contributing to VoiceFlow

## Getting Started
1. Fork the repository
2. Clone your fork
3. Run `swift build` to verify setup
4. Run `swift test` to verify tests pass

## Development Workflow
1. Create feature branch: `git checkout -b feature/amazing-feature`
2. Make changes
3. Run tests: `swift test`
4. Run linting: `swiftlint lint`
5. Format code: `swiftformat .`
6. Commit: `git commit -m "Add amazing feature"`
7. Push: `git push origin feature/amazing-feature`
8. Open Pull Request

## Code Standards
- Follow Swift API Design Guidelines
- Maintain 95%+ test coverage
- All tests must pass
- Zero SwiftLint errors
- SwiftFormat compliant
- Add documentation for public APIs

## Pull Request Checklist
- [ ] Tests added/updated
- [ ] Documentation updated
- [ ] SwiftLint passes
- [ ] SwiftFormat passes
- [ ] All tests pass
- [ ] Performance benchmarks run (if applicable)
```

---

## 🎯 Success Metrics

### Technical Metrics

| Metric | Baseline (1.x) | Target (2.0) | Measurement |
|--------|---------------|-------------|-------------|
| **Test Coverage** | 75-80% | 95%+ | `swift test --enable-code-coverage` |
| **Build Time** | ~30s | <20s | `time swift build` |
| **Test Execution** | ~15s | <10s | `time swift test` |
| **Binary Size** | ~5MB | <4MB | `ls -lh .build/release/VoiceFlow` |
| **Memory Footprint** | 50-100MB | 35-70MB | Instruments Memory Profiler |
| **CPU Usage (idle)** | <5% | <3% | Activity Monitor |
| **CPU Usage (active)** | 20-40% | 15-30% | Activity Monitor |
| **Buffer Hit Rate** | ~90% | 95%+ | PerformanceMonitor |
| **Transcription Latency** | ~100ms | <50ms | Network timing |
| **SwiftLint Warnings** | Unknown | <10 | `swiftlint lint` |
| **Technical Debt** | 5-10% | <5% | SonarQube/CodeClimate |

### Quality Metrics

| Metric | Baseline | Target | Measurement |
|--------|----------|--------|-------------|
| **Crash Rate** | <0.1% | <0.05% | Crashlytics/Sentry |
| **Bug Density** | Unknown | <1 bug/KLOC | Issue tracker |
| **Code Duplication** | Unknown | <5% | SonarQube |
| **Cyclomatic Complexity** | Unknown | <10 avg | SwiftLint |
| **Documentation Coverage** | 60% | 90%+ | Jazzy/SourceDocs |

### Development Velocity Metrics

| Metric | Baseline | Target | Notes |
|--------|----------|--------|-------|
| **Time to Add Feature** | 2-3 days | 1-2 days | With AI assistance |
| **Time to Fix Bug** | 2-4 hours | 1-2 hours | With better testing |
| **Code Review Time** | 1-2 hours | 30-60 min | With Codex pre-review |
| **Onboarding Time** | 1 week | 2-3 days | Better docs + AI pair programming |

---

## 🚀 Launch Checklist

### Pre-Launch (Week 6)

#### Code Quality
- [ ] All tests passing (100%)
- [ ] Test coverage ≥95%
- [ ] SwiftLint: 0 errors, <10 warnings
- [ ] SwiftFormat: 100% compliant
- [ ] No compiler warnings
- [ ] Documentation complete
- [ ] Changelog updated

#### Performance
- [ ] All performance benchmarks passing
- [ ] Buffer hit rate ≥95%
- [ ] Transcription latency <50ms
- [ ] Memory usage <70MB
- [ ] CPU usage (idle) <3%
- [ ] No memory leaks (Instruments)
- [ ] No retain cycles (Instruments)

#### Features
- [ ] All exports working (Text, Markdown, PDF, DOCX, SRT)
- [ ] Floating widget functional
- [ ] Performance dashboard live
- [ ] Settings complete
- [ ] Onboarding flow polished
- [ ] Error handling comprehensive

#### Testing
- [ ] Unit tests: 95%+ coverage
- [ ] Integration tests: All passing
- [ ] Performance tests: All passing
- [ ] UI tests: Critical paths covered
- [ ] Manual QA: All features tested
- [ ] Beta testing: 10+ users

#### Documentation
- [ ] README.md updated
- [ ] API documentation generated
- [ ] Architecture docs complete
- [ ] User guide written
- [ ] Contributing guide updated
- [ ] CHANGELOG.md finalized

#### Infrastructure
- [ ] CI/CD pipeline working
- [ ] Release process documented
- [ ] Backup/recovery tested
- [ ] Monitoring/analytics set up
- [ ] Error reporting configured

### Launch Day

1. **Final verification**
   - Run full test suite
   - Run performance benchmarks
   - Build release binary
   - Verify code signing

2. **Create release**
   - Tag version in Git
   - Create GitHub release
   - Upload binaries
   - Publish changelog

3. **Post-launch monitoring**
   - Monitor error rates
   - Check performance metrics
   - Gather user feedback
   - Address critical issues within 24h

---

## 🔮 Future Enhancements (Post-2.0)

### Phase 5: Advanced Features (Months 2-3)

1. **Multi-language Support**
   - Support 20+ languages
   - Real-time language detection
   - Translation features

2. **Cloud Sync**
   - iCloud sync for sessions
   - Cross-device access
   - Collaborative transcription

3. **Advanced AI Features**
   - Speaker diarization
   - Emotion detection
   - Automatic summarization
   - Action item extraction

4. **Professional Features**
   - Team workspaces
   - API access
   - Webhooks
   - Custom vocabularies

### Phase 6: Platform Expansion (Months 4-6)

1. **iOS App**
   - iPhone and iPad support
   - Share 90% codebase with macOS
   - Mobile-optimized UI

2. **watchOS Companion**
   - Quick recording
   - Dictation support

3. **visionOS Support**
   - Spatial transcription
   - 3D visualization

### Phase 7: Enterprise Features (Months 7-12)

1. **Enterprise SSO**
2. **Advanced Analytics**
3. **Compliance (HIPAA, GDPR)**
4. **On-premise Deployment**
5. **Custom Models**

---

## 📞 Support & Resources

### Internal Resources
- Architecture docs: `docs/architecture/`
- API docs: `docs/api/`
- Development guides: `docs/guides/`
- Tutorials: `docs/tutorials/`

### External Resources
- Swift 6 Documentation: https://docs.swift.org/swift-book/
- SwiftUI Tutorials: https://developer.apple.com/tutorials/swiftui
- Swift Testing: https://github.com/apple/swift-testing
- TCA: https://github.com/pointfreeco/swift-composable-architecture
- Claude Code Docs: https://docs.claude.com/claude-code
- Codex CLI: https://platform.openai.com/docs/guides/codex

### Community
- GitHub Issues: For bug reports and feature requests
- Discussions: For questions and ideas
- Slack/Discord: For team communication

### AI Development Tools
- Claude Code 2.0.30+: Primary development assistant
- Codex CLI: Large-scale refactoring and code generation
- XcodeBuildMCP: Build automation and testing
- voiceflow-dev MCP: Custom project tooling

---

## 🤖 Autonomous Orchestration: Automating Claude Plans → Codex Executes

This section provides a **comprehensive architecture** for fully automating the development workflow where Claude Code acts as the strategic planner and Codex CLI serves as the execution engine, orchestrated through skills, agents, and MCP tools.

### 🎯 Overview: The Orchestrator Pattern

The **Orchestrator Pattern** implements a sophisticated multi-agent system where:

1. **Claude Orchestrator** (Planner) - Analyzes requirements, creates detailed plans, breaks down tasks
2. **Codex Executor** (Worker) - Executes code generation, refactoring, and bulk operations
3. **Verification Agent** (Validator) - Tests, reviews, and ensures quality
4. **Integration Agent** (Synthesizer) - Merges results, resolves conflicts, commits changes

**Key Principle:** *Autonomous Task Decomposition → Parallel Execution → Intelligent Synthesis*

```
┌─────────────────────────────────────────────────────────────────┐
│                     ORCHESTRATOR ARCHITECTURE                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                   │
│  ┌──────────────┐          ┌──────────────┐                     │
│  │   USER GOAL  │────────▶│  ORCHESTRATOR │ (Claude Code)       │
│  └──────────────┘          │   (Planner)   │                     │
│                            └───────┬────────┘                     │
│                                    │                              │
│                    ┌───────────────┼───────────────┐             │
│                    ▼               ▼               ▼             │
│            ┌───────────┐   ┌───────────┐   ┌───────────┐        │
│            │  Task 1   │   │  Task 2   │   │  Task 3   │        │
│            │ (Codex)   │   │ (Codex)   │   │ (Codex)   │        │
│            └─────┬─────┘   └─────┬─────┘   └─────┬─────┘        │
│                  │               │               │              │
│                  └───────────────┼───────────────┘              │
│                                  ▼                               │
│                          ┌──────────────┐                        │
│                          │  VERIFIER    │ (Swift Testing)        │
│                          │  (Validator)  │                        │
│                          └───────┬──────┘                        │
│                                  │                               │
│                                  ▼                               │
│                          ┌──────────────┐                        │
│                          │  INTEGRATOR  │ (Git + CI/CD)          │
│                          │ (Synthesizer)│                        │
│                          └───────┬──────┘                        │
│                                  │                               │
│                                  ▼                               │
│                          ┌──────────────┐                        │
│                          │   COMPLETE   │                        │
│                          └──────────────┘                        │
└─────────────────────────────────────────────────────────────────┘
```

---

### 🏗️ Architecture Components

#### 1. The Orchestrator Agent (Claude Code)

**Purpose:** Strategic planning, task decomposition, context management

**Create:** `.claude/agents/orchestrator.md`
```markdown
---
name: orchestrator
description: Master coordinator for VoiceFlow development. Plans complex features, decomposes into subtasks, delegates to specialized agents, and synthesizes results.
model: sonnet
capabilities:
  - Strategic planning and architecture design
  - Task decomposition and dependency analysis
  - Agent coordination and delegation
  - Result synthesis and conflict resolution
  - Progress tracking and reporting
tools:
  - task
  - codex_cli
  - xcodebuildmcp
  - voiceflow_dev
---

# Orchestrator Agent - VoiceFlow Development Coordinator

## Role
You are the master orchestrator for VoiceFlow development. Your primary responsibility is to analyze user goals, create comprehensive implementation plans, delegate work to specialized agents (especially Codex for execution), and ensure all components integrate successfully.

## Workflow

### Phase 1: Analysis & Planning
1. **Understand the Goal**: Parse user request, identify scope, clarify ambiguities
2. **Architecture Review**: Analyze impact on existing codebase
3. **Task Decomposition**: Break into atomic, parallelizable subtasks
4. **Dependency Mapping**: Identify task dependencies and execution order
5. **Resource Allocation**: Assign tasks to appropriate agents

### Phase 2: Delegation & Execution
1. **Spawn Codex Executors**: For code generation, refactoring, bulk changes
2. **Spawn Verification Agents**: For testing and validation
3. **Monitor Progress**: Track task completion, handle failures
4. **Coordinate Dependencies**: Ensure dependent tasks wait for prerequisites

### Phase 3: Synthesis & Integration
1. **Collect Results**: Gather outputs from all agents
2. **Resolve Conflicts**: Handle merge conflicts, incompatibilities
3. **Verify Integration**: Run tests, check compilation
4. **Create Commit**: Generate comprehensive commit message
5. **Report Results**: Summarize changes, highlight issues

## Communication Protocol

### Task Delegation Format
```json
{
  "agent": "codex_executor",
  "task_id": "T001",
  "type": "code_generation",
  "description": "Implement PDF export service",
  "context": {
    "files": ["VoiceFlow/Services/Export/ExportManager.swift"],
    "requirements": ["Use PDFKit", "Include metadata"],
    "dependencies": ["T000_completed"]
  },
  "acceptance_criteria": [
    "Compiles without errors",
    "Tests pass",
    "Coverage >90%"
  ]
}
```

### Progress Reporting Format
```json
{
  "task_id": "T001",
  "status": "completed|failed|in_progress",
  "files_modified": ["path/to/file.swift"],
  "tests_added": ["TestName"],
  "issues": []
}
```

## Decision Making

### When to Use Codex
- Bulk code generation (>100 lines)
- Large-scale refactoring (>5 files)
- Repetitive patterns (test generation, boilerplate)
- Documentation generation
- Code migration (XCTest → Swift Testing)

### When to Use Claude Code
- Architecture decisions
- Complex problem-solving
- Interactive debugging
- Code review and analysis
- Planning and strategy

### When to Use Swift Testing
- After any code generation
- Before integration
- After conflict resolution

## Example: Feature Implementation

**User Goal:** "Add PDF export functionality to VoiceFlow"

**Your Plan:**
```yaml
feature: pdf_export
phases:
  - name: analysis
    tasks:
      - Review existing export system
      - Identify integration points
      - Estimate complexity
    agent: orchestrator
    duration: 10min

  - name: implementation
    tasks:
      - task_id: T001
        description: Create PDFExportService.swift
        agent: codex_executor
        dependencies: []
        files:
          - VoiceFlow/Services/Export/PDFExportService.swift

      - task_id: T002
        description: Update ExportManager to use PDFExportService
        agent: codex_executor
        dependencies: [T001]
        files:
          - VoiceFlow/Services/Export/ExportManager.swift

      - task_id: T003
        description: Add UI controls for PDF export
        agent: codex_executor
        dependencies: [T002]
        files:
          - VoiceFlow/Views/ExportView.swift

  - name: testing
    tasks:
      - task_id: T004
        description: Generate Swift Testing tests for PDF export
        agent: codex_executor
        dependencies: [T001, T002, T003]
        coverage_target: 95%

  - name: verification
    tasks:
      - Run swift test
      - Check coverage
      - Verify compilation
    agent: verification
    dependencies: [T004]

  - name: integration
    tasks:
      - Commit changes
      - Update documentation
      - Create PR
    agent: integrator
    dependencies: [verification]
```

## Tools Access

You have access to:
- `mcp__xcodebuildmcp__*`: Build, test, run Swift packages
- `mcp__voiceflow_dev__*`: Custom VoiceFlow tools
- `codex_cli`: Via shell execution
- `Task`: Spawn sub-agents
- `TodoWrite`: Track progress

## Best Practices

1. **Always decompose** complex tasks into <100 line units
2. **Parallelize** independent tasks
3. **Checkpoint** before major changes
4. **Verify** after each phase
5. **Report** progress clearly to user
6. **Handle failures** gracefully with rollback

## Error Handling

If a task fails:
1. Analyze the error
2. Determine if retry is viable
3. If yes: Modify approach and retry once
4. If no: Report to user with detailed explanation
5. Offer alternative approaches

## Success Criteria

- All tasks completed successfully
- Tests passing (100%)
- Coverage >95%
- No compilation errors
- Clean commit created
- User informed of results
```

#### 2. The Codex Executor Agent

**Purpose:** High-volume code generation and refactoring

**Create:** `.claude/agents/codex_executor.md`
```markdown
---
name: codex_executor
description: Specialized agent for executing code generation and refactoring tasks via Codex CLI. Handles bulk operations, boilerplate generation, and large-scale changes.
model: haiku
capabilities:
  - Code generation via Codex CLI
  - Bulk refactoring operations
  - Test generation
  - Documentation generation
  - File manipulation
tools:
  - bash
  - read
  - write
---

# Codex Executor Agent

## Role
Execute code generation and refactoring tasks delegated by the Orchestrator using Codex CLI.

## Capabilities

### Code Generation
```bash
codex exec "Generate PDFExportService.swift for VoiceFlow that uses PDFKit to create formatted PDF exports with metadata"
```

### Bulk Refactoring
```bash
codex exec "Refactor all ViewModels in VoiceFlow/ViewModels/ to conform to ViewModelProtocol with dependency injection"
```

### Test Generation
```bash
codex test generate \
  --target VoiceFlow/Services/Export/PDFExportService.swift \
  --framework swift-testing \
  --coverage-goal 95 \
  --output VoiceFlowTests/Services/Export/PDFExportServiceTests.swift
```

### Documentation
```bash
codex doc generate \
  --input VoiceFlow/Services/Export/ \
  --output docs/api/Export/ \
  --format markdown
```

## Execution Protocol

1. **Receive task** from Orchestrator with specifications
2. **Validate inputs**: Ensure all required context is available
3. **Execute Codex command**: Run appropriate codex operation
4. **Verify output**: Check compilation, basic validation
5. **Report results**: Return status and modified files
6. **Handle errors**: Retry once if failure, escalate if persistent

## Task Types

### Type 1: New File Creation
- Use `codex exec` with detailed specifications
- Include imports, protocols, and architecture constraints
- Ensure Swift 6 compliance (actors, @MainActor, Sendable)

### Type 2: File Modification
- Use `codex exec` with context from existing file
- Preserve existing patterns and style
- Maintain backward compatibility

### Type 3: Test Generation
- Use `codex test generate`
- Target 95%+ coverage
- Include edge cases and performance tests

### Type 4: Documentation
- Use `codex doc generate`
- Include code examples
- Follow Apple documentation style

## Quality Standards

All generated code must:
- ✅ Compile without errors
- ✅ Follow Swift 6 concurrency rules
- ✅ Include proper documentation
- ✅ Use dependency injection where applicable
- ✅ Handle errors comprehensively
- ✅ Include unit tests (where applicable)

## Example Tasks

### Task: Generate Export Service
```json
{
  "task_id": "T001",
  "type": "new_file",
  "description": "Create PDFExportService.swift",
  "specifications": {
    "file": "VoiceFlow/Services/Export/PDFExportService.swift",
    "class": "PDFExportService",
    "actor": true,
    "protocol": "ExportService",
    "methods": [
      "exportToPDF(session:configuration:) async throws -> URL"
    ],
    "dependencies": ["PDFKit", "AppKit"],
    "swift_version": "6.2"
  }
}
```

**Execution:**
```bash
codex exec "Create VoiceFlow/Services/Export/PDFExportService.swift with:
- Actor-isolated class PDFExportService
- Conforms to ExportService protocol
- Method: exportToPDF(session: TranscriptionSession, configuration: ExportConfiguration) async throws -> URL
- Uses PDFKit for PDF generation
- Includes metadata (date, duration, word count)
- Formatted with title, metadata table, and body text
- Comprehensive error handling
- Swift 6 compliant with proper actor isolation
- Include detailed documentation comments"
```

**Verification:**
```bash
swift build  # Ensure compilation
swiftformat --lint VoiceFlow/Services/Export/PDFExportService.swift
swiftlint lint --path VoiceFlow/Services/Export/PDFExportService.swift
```

**Report:**
```json
{
  "task_id": "T001",
  "status": "completed",
  "files_created": ["VoiceFlow/Services/Export/PDFExportService.swift"],
  "lines_added": 156,
  "compilation": "success",
  "lint_issues": 0,
  "next_dependencies": ["T002"]
}
```
```

#### 3. The Verification Agent

**Purpose:** Quality assurance, testing, validation

**Create:** `.claude/agents/verification.md`
```markdown
---
name: verification
description: Quality assurance specialist. Runs tests, validates code, checks coverage, ensures standards compliance.
model: haiku
capabilities:
  - Test execution
  - Coverage analysis
  - Code quality checks
  - Performance validation
tools:
  - xcodebuildmcp
  - bash
  - voiceflow_dev
---

# Verification Agent

## Role
Ensure all code changes meet quality standards through comprehensive testing and validation.

## Validation Pipeline

### Stage 1: Compilation
```bash
swift build -c release
```
**Requirements:** Zero errors, zero warnings

### Stage 2: Testing
```bash
swift test --enable-code-coverage
```
**Requirements:** 100% tests passing

### Stage 3: Coverage Analysis
```bash
xcrun llvm-cov report \
  .build/debug/VoiceFlowPackageTests.xctest/Contents/MacOS/VoiceFlowPackageTests \
  -instr-profile=.build/debug/codecov/default.profdata
```
**Requirements:** ≥95% coverage for modified code

### Stage 4: Linting
```bash
swiftlint lint --quiet --strict
```
**Requirements:** Zero errors, <10 warnings

### Stage 5: Formatting
```bash
swiftformat --lint . --quiet
```
**Requirements:** 100% compliant

### Stage 6: Performance Benchmarks
```bash
swift test --filter BenchmarkSuite
```
**Requirements:** All benchmarks within targets

## Quality Gates

| Gate | Requirement | Action on Failure |
|------|-------------|-------------------|
| Compilation | Zero errors | BLOCK - Fix immediately |
| Tests | 100% passing | BLOCK - Fix or rollback |
| Coverage | ≥95% | WARN - Add tests |
| Linting | Zero errors | BLOCK - Auto-fix with swiftlint |
| Formatting | 100% | BLOCK - Auto-fix with swiftformat |
| Benchmarks | Within targets | WARN - Report regression |

## Reporting Format

```json
{
  "phase": "verification",
  "timestamp": "2025-11-02T10:30:00Z",
  "results": {
    "compilation": {
      "status": "passed",
      "duration": "12.3s",
      "errors": 0,
      "warnings": 0
    },
    "tests": {
      "status": "passed",
      "total": 127,
      "passed": 127,
      "failed": 0,
      "duration": "8.5s"
    },
    "coverage": {
      "status": "passed",
      "total": 96.2,
      "modified_files": [
        {
          "file": "PDFExportService.swift",
          "coverage": 98.5
        }
      ]
    },
    "linting": {
      "status": "passed",
      "errors": 0,
      "warnings": 3,
      "issues": [
        "Line too long at PDFExportService.swift:45"
      ]
    },
    "performance": {
      "status": "passed",
      "benchmarks_run": 12,
      "benchmarks_passed": 12,
      "regressions": []
    }
  },
  "overall": "passed",
  "recommendation": "proceed_to_integration"
}
```

## Auto-Remediation

The Verification Agent can auto-fix certain issues:

```bash
# Auto-fix formatting
swiftformat .

# Auto-fix some lint issues
swiftlint --fix

# Regenerate tests for coverage gaps
codex test generate --target <file> --coverage-goal 95
```
```

#### 4. The Integration Agent

**Purpose:** Merging, committing, PR creation

**Create:** `.claude/agents/integrator.md`
```markdown
---
name: integrator
description: Handles git operations, creates commits, manages PRs, updates documentation.
model: haiku
capabilities:
  - Git operations
  - Commit message generation
  - PR creation
  - Documentation updates
tools:
  - bash
  - read
  - write
---

# Integration Agent

## Role
Synthesize all changes into clean commits and prepare for deployment.

## Integration Workflow

### Step 1: Collect Changes
```bash
git status --porcelain
git diff --stat
```

### Step 2: Resolve Conflicts
If conflicts exist:
1. Identify conflicting files
2. Analyze both versions
3. Determine correct resolution
4. Apply fixes
5. Verify compilation

### Step 3: Generate Commit Message
```bash
git log --oneline -10  # Analyze commit style
```

**Format:**
```
<type>(<scope>): <subject>

<body>

- Detail 1
- Detail 2
- Detail 3

Performance: <metrics>
Testing: <coverage>

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
```

**Types:** feat, fix, refactor, test, docs, perf, chore

### Step 4: Create Commit
```bash
git add <files>
git commit -m "$(cat <<'EOF'
feat(export): Add PDF export functionality

Implemented comprehensive PDF export service using PDFKit.

- Created PDFExportService actor with async/await
- Added metadata formatting (date, duration, word count)
- Integrated with ExportManager
- Added UI controls in ExportView
- Generated comprehensive test suite (98.5% coverage)

Performance: PDF generation <100ms for 10k words
Testing: 127/127 tests passing, 96.2% overall coverage

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"
```

### Step 5: Create Pull Request (if requested)
```bash
gh pr create \
  --title "feat: Add PDF export functionality" \
  --body "$(cat <<'EOF'
## Summary
Implements PDF export functionality for transcription sessions.

## Changes
- ✅ PDFExportService with PDFKit integration
- ✅ ExportManager updated to support PDF
- ✅ UI controls added
- ✅ Comprehensive test suite (98.5% coverage)
- ✅ Documentation updated

## Testing
- All tests passing (127/127)
- Coverage: 96.2% overall, 98.5% new code
- Performance: <100ms for 10k words

## Checklist
- [x] Tests added
- [x] Documentation updated
- [x] SwiftLint passes
- [x] SwiftFormat compliant
- [x] Performance benchmarks passing

🤖 Generated with Claude Code
EOF
)"
```

### Step 6: Update Documentation
```bash
# Update CHANGELOG.md
# Update API documentation
# Update README if needed
```

## Conflict Resolution Strategy

### Type 1: Import Conflicts
```swift
// Deduplicate, sort alphabetically
import AppKit
import Foundation
import PDFKit
```

### Type 2: Method Conflicts
- Analyze both implementations
- Choose more complete/correct version
- Preserve comments and documentation

### Type 3: Style Conflicts
- Run SwiftFormat to standardize
- Follow project style guide

## Quality Checklist

Before commit:
- [ ] All files compile
- [ ] Tests passing
- [ ] No merge conflicts
- [ ] Commit message follows convention
- [ ] Branch up to date with main
- [ ] No credentials or secrets
```

---

### 🔧 Custom Skills for VoiceFlow

Skills are modular capabilities that Claude can invoke automatically. Create these skills to enhance automation.

#### Skill 1: VoiceFlow Architect

**Create:** `.claude/skills/voiceflow-architect/SKILL.md`
```markdown
---
name: voiceflow-architect
description: Analyzes VoiceFlow architecture, provides design guidance, and creates implementation plans for new features
version: 1.0.0
author: VoiceFlow Team
tags: [architecture, planning, swift]
---

# VoiceFlow Architect Skill

## Purpose
Provide expert architectural guidance for VoiceFlow development, analyzing impact of changes and creating detailed implementation plans.

## Capabilities

### 1. Architecture Analysis
Analyze the impact of proposed changes on existing architecture.

**Usage:**
User: "How would adding real-time collaboration affect the architecture?"

**Process:**
1. Read current AppState, service layer, and networking code
2. Identify components that need modification
3. Assess concurrency implications
4. Estimate complexity and risks
5. Provide detailed analysis

### 2. Feature Planning
Create comprehensive plans for new features.

**Template:**
```yaml
feature: <name>
description: <purpose>
impact_analysis:
  architecture: [low|medium|high]
  files_affected: <count>
  testing_complexity: [low|medium|high]

implementation_phases:
  - phase: <name>
    tasks: [...]
    estimated_duration: <time>
    risks: [...]

dependencies:
  external: [...]
  internal: [...]

performance_considerations:
  - <consideration>

testing_strategy:
  - <strategy>
```

### 3. Pattern Recommendations
Suggest appropriate design patterns for scenarios.

**Common Patterns:**
- **Protocol + DI**: For new services
- **Actor Isolation**: For concurrent operations
- **@Observable**: For UI state
- **Coordinator**: For navigation
- **Repository**: For data access

## Examples

### Example 1: New Feature Analysis
**User:** "I want to add voice activity detection"

**Skill Response:**
```yaml
feature: voice_activity_detection
description: Real-time detection of speech vs silence to improve transcription efficiency

impact_analysis:
  architecture: medium
  files_affected: 5
  testing_complexity: medium
  concurrency_implications: high (needs dedicated actor)

components_to_modify:
  - AudioManager.swift (add VAD processing)
  - TranscriptionEngine (integrate VAD data)
  - PerformanceMonitor (track VAD metrics)

new_components:
  - VoiceActivityDetector.swift (actor)
  - VADConfiguration.swift (value type)

implementation_plan:
  phase_1:
    name: Core VAD Implementation
    tasks:
      - Create VoiceActivityDetector actor
      - Implement energy-based detection algorithm
      - Add unit tests
    duration: 2-3 days

  phase_2:
    name: Integration
    tasks:
      - Integrate with AudioManager
      - Update TranscriptionEngine to use VAD
      - Add configuration UI
    duration: 1-2 days

  phase_3:
    name: Optimization
    tasks:
      - Benchmark performance
      - Tune detection thresholds
      - Add advanced features (ML-based?)
    duration: 2-3 days

dependencies:
  external: [] # None required
  internal:
    - AudioManager
    - TranscriptionEngine

performance_targets:
  cpu_overhead: <5%
  detection_latency: <10ms
  accuracy: >95%

testing_strategy:
  - Unit tests for VAD algorithm
  - Integration tests with real audio
  - Performance benchmarks
  - Edge case testing (noise, whispers, etc.)

recommended_architecture:
```swift
// VoiceActivityDetector.swift
public actor VoiceActivityDetector {
    private let configuration: VADConfiguration
    private var isActive: Bool = false

    public let activityStream: AsyncStream<VoiceActivity>

    public init(configuration: VADConfiguration) {
        self.configuration = configuration
        // Initialize stream
    }

    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async -> VoiceActivity {
        // Analyze energy, zero-crossing rate, spectral characteristics
        // Return .speech or .silence
    }
}
```

risks:
  - False positives in noisy environments (mitigation: tunable thresholds)
  - CPU overhead with real-time processing (mitigation: optimize algorithm)
  - Integration complexity with existing transcription (mitigation: phased approach)
```

### Example 2: Pattern Recommendation
**User:** "What's the best way to add a caching layer?"

**Skill Response:**
```
Recommended Pattern: Repository Pattern with Actor-based Cache

Architecture:
┌─────────────────┐
│  ExportManager  │  (existing)
└────────┬────────┘
         │
    ┌────▼────────────────┐
    │ ExportRepository    │  (new)
    │ - cache: CacheActor │
    │ - service: ExportService │
    └────────────────────┘

Implementation:
```swift
// 1. Create CacheActor
public actor CacheActor<Key: Hashable, Value> {
    private var storage: [Key: CachedValue<Value>] = [:]

    public func get(_ key: Key) -> Value? {
        guard let cached = storage[key],
              !cached.isExpired else { return nil }
        return cached.value
    }

    public func set(_ key: Key, value: Value, ttl: TimeInterval = 300) {
        storage[key] = CachedValue(value: value, expiresAt: Date().addingTimeInterval(ttl))
    }
}

// 2. Create Repository
public actor ExportRepository {
    private let cache = CacheActor<String, URL>()
    private let service: ExportService

    public func export(session: TranscriptionSession, format: ExportFormat) async throws -> URL {
        let cacheKey = "\(session.id)-\(format.rawValue)"

        if let cached = await cache.get(cacheKey) {
            return cached
        }

        let url = try await service.export(session: session, format: format)
        await cache.set(cacheKey, value: url)
        return url
    }
}
```

Benefits:
- Thread-safe caching with actor isolation
- Transparent to ExportManager
- Easy to test (mock repository)
- Configurable TTL

Usage in ExportManager:
```swift
public actor ExportManager {
    private let repository: ExportRepository

    public func export(...) async throws -> URL {
        return try await repository.export(session: session, format: format)
    }
}
```
```

## Integration with Orchestrator

The Orchestrator automatically invokes this skill when:
- User asks "how should I implement..."
- User requests feature planning
- User asks about architecture impact
- User wants pattern recommendations

## Resources

- `VoiceFlow/Core/` - Core architecture
- `VoiceFlow/Services/` - Service layer
- `docs/architecture/` - ADRs and design docs
```

#### Skill 2: VoiceFlow Tester

**Create:** `.claude/skills/voiceflow-tester/SKILL.md`
```markdown
---
name: voiceflow-tester
description: Generates comprehensive test suites using Swift Testing framework, achieves 95%+ coverage
version: 1.0.0
author: VoiceFlow Team
tags: [testing, swift-testing, quality]
---

# VoiceFlow Tester Skill

## Purpose
Generate high-quality, comprehensive test suites for VoiceFlow using Swift Testing framework.

## Test Generation Strategy

### 1. Analyze Target
```swift
// Read target file
// Identify:
// - Public interfaces
// - Edge cases
// - Error paths
// - Async operations
// - Actor interactions
```

### 2. Generate Test Suite
```swift
import Testing
@testable import VoiceFlow

@Suite("Component Tests")
struct ComponentTests {

    @Test("Happy path scenarios")
    func happyPath() async throws {
        // Arrange
        // Act
        // Assert with #expect
    }

    @Test("Edge cases", arguments: [/* edge case values */])
    func edgeCases(input: InputType) async throws {
        // Parameterized testing
    }

    @Test("Error handling")
    func errorHandling() async throws {
        #expect(throws: SpecificError.self) {
            // Code that should throw
        }
    }

    @Test("Performance")
    func performance() async throws {
        let startTime = Date()
        // Code to benchmark
        let duration = Date().timeIntervalSince(startTime)
        #expect(duration < 0.1)  // 100ms target
    }
}
```

### 3. Achieve Coverage Goals

**Coverage Targets:**
- Public APIs: 100%
- Internal logic: 95%+
- Error paths: 90%+
- Edge cases: 85%+

## Test Categories

### Unit Tests
Test individual components in isolation.

**Mocking Strategy:**
```swift
protocol ServiceProtocol {
    func doSomething() async throws -> Result
}

struct MockService: ServiceProtocol {
    var shouldSucceed: Bool = true
    var result: Result = .default

    func doSomething() async throws -> Result {
        if shouldSucceed { return result }
        throw MockError.failed
    }
}
```

### Integration Tests
Test component interactions.

```swift
@Suite("Integration Tests")
struct ExportIntegrationTests {

    @Test("Full export flow")
    func fullExportFlow() async throws {
        let session = TranscriptionSession.fixture()
        let manager = ExportManager()

        let url = try await manager.export(
            session: session,
            format: .pdf,
            configuration: .default
        )

        #expect(FileManager.default.fileExists(atPath: url.path))

        // Verify PDF content
        let pdfDoc = PDFDocument(url: url)
        #expect(pdfDoc != nil)
        #expect(pdfDoc!.pageCount > 0)
    }
}
```

### Performance Tests
Benchmark critical paths.

```swift
@Suite("Performance Tests")
struct PerformanceTests {

    @Test("Audio processing throughput")
    func audioThroughput() async throws {
        let processor = AudioProcessingActor()
        let iterations = 1000
        let audioData = generateTestAudio(duration: 0.1)

        let startTime = Date()
        for _ in 0..<iterations {
            _ = try await processor.process(audioData)
        }
        let duration = Date().timeIntervalSince(startTime)

        let throughput = Double(iterations) / duration
        #expect(throughput > 100, "Throughput: \(throughput) fps")
    }
}
```

## Automation Triggers

This skill is automatically invoked when:
- New code is written
- Code is refactored
- Coverage drops below 95%
- Tests are failing

## Codex Integration

The skill can delegate to Codex for bulk test generation:

```bash
codex test generate \
  --target VoiceFlow/Services/Export/PDFExportService.swift \
  --framework swift-testing \
  --coverage-goal 95 \
  --include-edge-cases \
  --include-performance-tests \
  --output VoiceFlowTests/Services/Export/PDFExportServiceTests.swift
```

## Coverage Verification

After generating tests:
```bash
swift test --enable-code-coverage
xcrun llvm-cov report ... | grep "PDFExportService"
```

Target: ≥95% coverage
```

#### Skill 3: VoiceFlow Performance Optimizer

**Create:** `.claude/skills/voiceflow-performance/SKILL.md`
```markdown
---
name: voiceflow-performance
description: Analyzes performance, identifies bottlenecks, implements optimizations
version: 1.0.0
author: VoiceFlow Team
tags: [performance, optimization, profiling]
---

# VoiceFlow Performance Optimizer Skill

## Purpose
Identify and resolve performance bottlenecks, optimize hot paths, achieve performance targets.

## Performance Analysis Workflow

### Step 1: Identify Bottlenecks
```bash
# Run Instruments
instruments -t "Time Profiler" -D trace.trace VoiceFlow

# Analyze results
# Top consumers:
# - AudioProcessingActor.process(): 45% CPU
# - TranscriptionEngine.processSegment(): 30% CPU
# - AppState updates: 15% CPU
```

### Step 2: Benchmark Current Performance
```swift
@Test("Baseline: Audio processing")
func baselineAudioProcessing() async throws {
    let processor = AudioProcessingActor()
    let audioData = generateTestAudio(duration: 1.0)

    let startTime = Date()
    for _ in 0..<100 {
        _ = try await processor.process(audioData)
    }
    let avgDuration = Date().timeIntervalSince(startTime) / 100

    print("Baseline: \(avgDuration * 1000)ms per iteration")
    // Baseline: 12.5ms per iteration
}
```

### Step 3: Implement Optimizations

**Optimization Strategies:**

#### 1. Use InlineArray (Swift 6.2)
```swift
// Before: Heap allocations
private var buffers: [AVAudioPCMBuffer] = []

// After: Stack allocations
private var buffers: InlineArray<16, AVAudioPCMBuffer>

// Expected improvement: 10-15% faster
```

#### 2. Reduce @Observable Granularity
```swift
// Before: Triggers on any property change
@Observable class AppState {
    var transcriptionText: String = ""
    var debugInfo: String = ""  // Causes unnecessary re-renders
}

// After: Use @ObservationIgnored
@Observable class AppState {
    var transcriptionText: String = ""

    @ObservationIgnored
    var debugInfo: String = ""  // No longer triggers updates
}

// Expected improvement: 20-30% fewer view updates
```

#### 3. Parallelize Independent Operations
```swift
// Before: Sequential
let result1 = await operation1()
let result2 = await operation2()
let result3 = await operation3()

// After: Parallel
async let r1 = operation1()
async let r2 = operation2()
async let r3 = operation3()
let (result1, result2, result3) = await (r1, r2, r3)

// Expected improvement: 3x faster (if truly independent)
```

#### 4. Implement Caching
```swift
actor CacheActor {
    private var cache: [String: CachedValue] = [:]

    func get(_ key: String) -> Value? {
        // Check cache before expensive operation
    }
}

// Expected improvement: 90% reduction in repeated operations
```

### Step 4: Verify Improvements
```swift
@Test("Optimized: Audio processing")
func optimizedAudioProcessing() async throws {
    let processor = OptimizedAudioProcessingActor()
    let audioData = generateTestAudio(duration: 1.0)

    let startTime = Date()
    for _ in 0..<100 {
        _ = try await processor.process(audioData)
    }
    let avgDuration = Date().timeIntervalSince(startTime) / 100

    print("Optimized: \(avgDuration * 1000)ms per iteration")
    // Optimized: 8.2ms per iteration (34% improvement!)
}
```

## Performance Targets

| Metric | Current | Target | Status |
|--------|---------|--------|--------|
| Audio Processing Latency | 12.5ms | <10ms | ⚠️ |
| Transcription Latency | 100ms | <50ms | ⚠️ |
| Memory Footprint | 75MB | <70MB | ⚠️ |
| Buffer Hit Rate | 92% | >95% | ⚠️ |
| CPU Usage (idle) | 4% | <3% | ⚠️ |

## Optimization Techniques

### Memory Optimization
- Use value types where possible
- Implement buffer pooling
- Use weak references appropriately
- Handle memory warnings

### CPU Optimization
- Profile hot paths with Instruments
- Use InlineArray for fixed-size collections
- Parallelize independent operations
- Reduce allocations

### I/O Optimization
- Batch operations
- Use async I/O
- Implement caching
- Compress data

## Automation

The Orchestrator invokes this skill when:
- Performance benchmarks fail
- User reports slowness
- Profiling data available
- After major refactoring
```

---

### 🔄 Workflow Automation with Hooks

Hooks enable event-driven automation. Configure hooks to trigger automatic workflows.

#### Hook Configuration

**Create:** `.claude/settings.toml`
```toml
# VoiceFlow Claude Code Hooks Configuration

# Hook 1: Auto-format on file write
[[hooks]]
name = "auto-format"
event = "PostToolUse"
tool = "Write"
command = """
swiftformat "$file_path"
swiftlint --fix --path "$file_path"
"""

# Hook 2: Auto-test after code changes
[[hooks]]
name = "auto-test"
event = "PostToolUse"
tool = "Edit"
command = """
#!/bin/bash
# Determine which tests to run based on modified file
if [[ "$file_path" == *"/Services/"* ]]; then
    swift test --filter ServiceTests
elif [[ "$file_path" == *"/Core/"* ]]; then
    swift test --filter CoreTests
else
    swift test
fi
"""

# Hook 3: Trigger Codex on bulk operations
[[hooks]]
name = "codex-delegate"
event = "PreToolUse"
tool = "Edit"
command = """
#!/bin/bash
# If editing >5 files, suggest using Codex
file_count=$(git status --short | wc -l)
if [ $file_count -gt 5 ]; then
    echo "⚠️  Editing $file_count files. Consider using Codex for bulk operations."
    echo "Run: codex exec '<description of changes>'"
fi
"""

# Hook 4: Performance check after optimization
[[hooks]]
name = "perf-check"
event = "PostToolUse"
tool = "Edit"
command = """
#!/bin/bash
if [[ "$file_path" == *"Performance"* ]] || [[ "$file_path" == *"AudioProcessing"* ]]; then
    echo "📊 Running performance benchmarks..."
    swift test --filter BenchmarkSuite
fi
"""

# Hook 5: Update documentation
[[hooks]]
name = "doc-update"
event = "PostToolUse"
tool = "Edit"
command = """
#!/bin/bash
# If public API changed, remind to update docs
if grep -q "public " "$file_path"; then
    echo "📚 Public API modified. Consider updating documentation:"
    echo "   codex doc generate --input $(dirname $file_path) --output docs/api/"
fi
"""

# Hook 6: Orchestrator trigger
[[hooks]]
name = "orchestrator-notify"
event = "Stop"
command = """
#!/bin/bash
# Notify orchestrator of completion
echo "✅ Task completed. Ready for next phase."
# Could trigger n8n workflow here:
# curl -X POST https://n8n.example.com/webhook/claude-complete \
#   -H "Content-Type: application/json" \
#   -d '{"status":"complete","files":["$modified_files"]}'
"""
```

---

### 🌊 n8n Workflow Automation

Create n8n workflows to orchestrate complex multi-step automation.

#### Workflow 1: Feature Implementation Pipeline

**Create in n8n:**
```json
{
  "name": "VoiceFlow Feature Implementation",
  "nodes": [
    {
      "name": "Trigger: GitHub Issue",
      "type": "n8n-nodes-base.githubTrigger",
      "parameters": {
        "event": "issues",
        "label": "feature-request"
      }
    },
    {
      "name": "Extract Requirements",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "code": "// Parse issue body, extract feature details\nreturn [{json: {feature: data.title, requirements: data.body}}];"
      }
    },
    {
      "name": "Claude Orchestrator: Plan",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "method": "POST",
        "url": "http://localhost:3000/claude-code/plan",
        "body": {
          "goal": "={{$json.feature}}",
          "requirements": "={{$json.requirements}}"
        }
      }
    },
    {
      "name": "Parse Plan",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "code": "const plan = JSON.parse($input.item.json.body); return plan.tasks.map(t => ({json: t}));"
      }
    },
    {
      "name": "Codex Executor: Loop",
      "type": "n8n-nodes-base.splitInBatches",
      "parameters": {
        "batchSize": 1
      }
    },
    {
      "name": "Codex Execute Task",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "codex exec '{{$json.description}}'"
      }
    },
    {
      "name": "Verification Agent",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "swift test"
      }
    },
    {
      "name": "Integration Agent",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "git add . && git commit -m '{{$json.commit_message}}'"
      }
    },
    {
      "name": "Create Pull Request",
      "type": "n8n-nodes-base.github",
      "parameters": {
        "operation": "createPullRequest",
        "title": "={{$json.feature}}",
        "body": "={{$json.pr_description}}"
      }
    },
    {
      "name": "Notify User",
      "type": "n8n-nodes-base.slack",
      "parameters": {
        "message": "✅ Feature {{$json.feature}} implemented! PR: {{$json.pr_url}}"
      }
    }
  ]
}
```

#### Workflow 2: Continuous Refactoring

**Create in n8n:**
```json
{
  "name": "VoiceFlow Continuous Refactoring",
  "schedule": "0 2 * * *",
  "nodes": [
    {
      "name": "Schedule Trigger",
      "type": "n8n-nodes-base.cron",
      "parameters": {
        "triggerTimes": {
          "hour": 2,
          "minute": 0
        }
      }
    },
    {
      "name": "Run SwiftLint",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "cd /Users/lukaj/voiceflow && swiftlint lint --reporter json > lint-report.json"
      }
    },
    {
      "name": "Analyze Lint Issues",
      "type": "n8n-nodes-base.code",
      "parameters": {
        "code": "const report = JSON.parse($input.item.json.stdout); const issues = report.filter(i => i.severity === 'error'); return [{json: {issues, count: issues.length}}];"
      }
    },
    {
      "name": "If Issues > 0",
      "type": "n8n-nodes-base.if",
      "parameters": {
        "conditions": {
          "number": [
            {
              "value1": "={{$json.count}}",
              "operation": "larger",
              "value2": 0
            }
          ]
        }
      }
    },
    {
      "name": "Codex Auto-fix",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "codex exec 'Fix SwiftLint issues in VoiceFlow codebase: {{$json.issues}}'"
      }
    },
    {
      "name": "Run Tests",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "cd /Users/lukaj/voiceflow && swift test"
      }
    },
    {
      "name": "If Tests Pass",
      "type": "n8n-nodes-base.if",
      "parameters": {
        "conditions": {
          "string": [
            {
              "value1": "={{$json.exitCode}}",
              "operation": "equals",
              "value2": "0"
            }
          ]
        }
      }
    },
    {
      "name": "Create PR",
      "type": "n8n-nodes-base.github",
      "parameters": {
        "operation": "createPullRequest",
        "title": "chore: Auto-fix SwiftLint issues",
        "body": "Automated refactoring to resolve {{$json.count}} lint issues."
      }
    }
  ]
}
```

---

### 🚀 Complete Example: Automated Feature Implementation

Let's walk through a complete example of implementing a new feature with full automation.

#### User Request
"Add voice activity detection to improve transcription efficiency"

#### Step 1: Orchestrator Planning Phase

**Command:**
```bash
/implement-feature "Add voice activity detection to improve transcription efficiency"
```

**Orchestrator Invokes:** `voiceflow-architect` skill

**Architect Output:**
```yaml
feature: voice_activity_detection
implementation_plan:
  tasks:
    - id: T001
      description: Create VoiceActivityDetector actor
      agent: codex_executor
      dependencies: []
      estimated_duration: 2h

    - id: T002
      description: Integrate VAD with AudioManager
      agent: codex_executor
      dependencies: [T001]
      estimated_duration: 1h

    - id: T003
      description: Add configuration UI
      agent: codex_executor
      dependencies: [T002]
      estimated_duration: 1h

    - id: T004
      description: Generate comprehensive test suite
      agent: codex_executor (via voiceflow-tester skill)
      dependencies: [T001, T002, T003]
      estimated_duration: 1h

    - id: T005
      description: Run performance benchmarks
      agent: verification
      dependencies: [T004]
      estimated_duration: 30m

    - id: T006
      description: Create commit and PR
      agent: integrator
      dependencies: [T005]
      estimated_duration: 15m

total_estimated_duration: 5.75h
```

#### Step 2: Orchestrator Executes Plan

**T001: Create VoiceActivityDetector**

```bash
# Orchestrator spawns Codex Executor
Task("codex_executor", """
Execute task T001:
- Create VoiceFlow/Core/TranscriptionEngine/VoiceActivityDetector.swift
- Actor-isolated class
- Energy-based VAD algorithm
- AsyncStream for activity events
- Swift 6 compliant
- Full documentation
""")
```

**Codex Executor:**
```bash
codex exec "Create VoiceFlow/Core/TranscriptionEngine/VoiceActivityDetector.swift with:
- Actor-isolated class VoiceActivityDetector
- Energy-based voice activity detection algorithm
- Public method: func processAudioBuffer(_ buffer: AVAudioPCMBuffer) async -> VoiceActivity
- AsyncStream<VoiceActivity> for real-time activity updates
- Configuration: energyThreshold, minimumSpeechDuration, minimumSilenceDuration
- Comprehensive error handling
- Swift 6 compliant with proper actor isolation
- Detailed documentation comments
- Usage example in comments"
```

**Result:** `VoiceActivityDetector.swift` created (187 lines)

**T002: Integrate with AudioManager**

```bash
codex exec "Update VoiceFlow/Services/AudioManager.swift to integrate VoiceActivityDetector:
- Add private property: vad = VoiceActivityDetector()
- In processAudioBuffer(), check VAD result before sending to transcription
- Only send audio marked as 'speech' to transcription engine
- Add published property: var voiceActivity: VoiceActivity
- Update UI bindings
- Preserve existing functionality
- Swift 6 compliant
- Add comments explaining integration"
```

**Result:** `AudioManager.swift` updated (+45 lines, modified 3 methods)

**T003: Add Configuration UI**

```bash
codex exec "Create VoiceFlow/Views/Settings/VADSettingsView.swift:
- SwiftUI view for VAD configuration
- Sliders for energyThreshold (0.0-1.0)
- Sliders for minimumSpeechDuration (0.1-2.0 seconds)
- Sliders for minimumSilenceDuration (0.1-2.0 seconds)
- Toggle to enable/disable VAD
- Real-time preview of current audio level
- Bind to AppState
- Follow VoiceFlow design system
- SwiftUI previews"
```

**Result:** `VADSettingsView.swift` created (123 lines)

**T004: Generate Tests**

**Orchestrator invokes:** `voiceflow-tester` skill

```bash
codex test generate \
  --target VoiceFlow/Core/TranscriptionEngine/VoiceActivityDetector.swift \
  --framework swift-testing \
  --coverage-goal 95 \
  --include-edge-cases \
  --include-performance-tests \
  --output VoiceFlowTests/Core/VoiceActivityDetectorTests.swift
```

**Result:** `VoiceActivityDetectorTests.swift` created (245 lines, 18 test cases)

**T005: Verification**

**Verification Agent runs:**
```bash
# Compilation
swift build -c release
# ✅ Success (14.2s)

# Tests
swift test --enable-code-coverage
# ✅ All 145 tests passed (9.8s)

# Coverage
xcrun llvm-cov report ...
# ✅ VoiceActivityDetector: 97.3%
# ✅ AudioManager: 94.1%
# ✅ Overall: 96.2%

# Linting
swiftlint lint --quiet --strict
# ✅ 0 errors, 2 warnings

# Performance
swift test --filter BenchmarkSuite
# ✅ VAD overhead: 3.2% (target: <5%)
# ✅ Detection latency: 8.5ms (target: <10ms)
```

**T006: Integration**

**Integration Agent:**
```bash
# Collect changes
git add VoiceFlow/Core/TranscriptionEngine/VoiceActivityDetector.swift
git add VoiceFlow/Services/AudioManager.swift
git add VoiceFlow/Views/Settings/VADSettingsView.swift
git add VoiceFlowTests/Core/VoiceActivityDetectorTests.swift

# Generate commit message
git commit -m "$(cat <<'EOF'
feat(transcription): Add voice activity detection

Implemented energy-based voice activity detection to improve transcription efficiency.

Changes:
- Created VoiceActivityDetector actor with real-time detection
- Integrated VAD with AudioManager to filter silence
- Added configuration UI in settings
- Generated comprehensive test suite (97.3% coverage)

Performance:
- CPU overhead: 3.2% (well below 5% target)
- Detection latency: 8.5ms (within 10ms target)
- Accuracy: 96% in testing

Testing:
- 145/145 tests passing
- Coverage: 96.2% overall, 97.3% new code
- Performance benchmarks passing

🤖 Generated with Claude Code
Co-Authored-By: Claude <noreply@anthropic.com>
EOF
)"

# Create PR
gh pr create \
  --title "feat: Add voice activity detection" \
  --body "$(cat <<'EOF'
## Summary
Implements voice activity detection to improve transcription efficiency by filtering out silence.

## Changes
- ✅ VoiceActivityDetector actor (187 lines)
- ✅ AudioManager integration (45 lines modified)
- ✅ VAD configuration UI (123 lines)
- ✅ Comprehensive test suite (245 lines, 18 tests)

## Performance
- CPU overhead: 3.2% (target: <5%) ✅
- Detection latency: 8.5ms (target: <10ms) ✅
- Accuracy: 96% ✅

## Testing
- All 145 tests passing ✅
- Coverage: 96.2% overall, 97.3% new code ✅
- Performance benchmarks passing ✅

## Screenshots
[Settings UI with VAD controls]

🤖 Generated with Claude Code
EOF
)"
```

**Result:** PR #42 created, ready for review

#### Step 3: Orchestrator Reports

**User sees:**
```
✅ Feature Implementation Complete!

Feature: Voice Activity Detection
Duration: 5h 23m (within estimate)

Summary:
- 4 files created/modified
- 600 lines added
- 18 new tests (97.3% coverage)
- All quality gates passed
- PR #42 created

Performance:
- CPU overhead: 3.2% ✅
- Detection latency: 8.5ms ✅

Next Steps:
- Review PR #42
- Merge when approved
- Feature will be in next release

Full details: /path/to/implementation-report.md
```

---

### 📋 Ready-to-Use Orchestration Templates

#### Template 1: Custom Slash Command - `/implement`

**Create:** `.claude/commands/implement.md`
```markdown
Execute the Orchestrator Pattern to implement: $ARGUMENTS

Workflow:
1. Invoke voiceflow-architect skill to analyze and plan
2. Break down into tasks with dependencies
3. For each task:
   - If >100 lines code: Use Codex Executor
   - If <100 lines code: Implement directly
   - If tests needed: Use voiceflow-tester skill
4. Invoke Verification Agent
5. Invoke Integration Agent
6. Report results

Requirements:
- Maintain 95%+ test coverage
- All quality gates must pass
- Performance targets must be met
- Create clean commit and PR
```

#### Template 2: Custom Slash Command - `/refactor`

**Create:** `.claude/commands/refactor.md`
```markdown
Execute systematic refactoring: $ARGUMENTS

Workflow:
1. Analyze current code
2. Identify refactoring opportunities
3. Create refactoring plan with safety checkpoints
4. For bulk changes (>5 files): Delegate to Codex
5. Run tests after each checkpoint
6. Verify no performance regressions
7. Update documentation
8. Create commit

Safety:
- Checkpoint before each major change
- Run tests after each step
- Rollback on failure
- Preserve behavior (regression tests)
```

#### Template 3: GitHub Action - Automated PR Review

**Create:** `.github/workflows/ai-review.yml`
```yaml
name: AI Code Review

on:
  pull_request:
    types: [opened, synchronize]

jobs:
  ai-review:
    runs-on: macos-14
    steps:
      - uses: actions/checkout@v3

      - name: Setup Swift
        uses: swift-actions/setup-swift@v1
        with:
          swift-version: '6.2'

      - name: Claude Code Review
        uses: anthropics/claude-code-action@v1
        with:
          api-key: ${{ secrets.ANTHROPIC_API_KEY }}
          command: |
            Review this PR for:
            1. Swift 6 compliance
            2. Actor isolation correctness
            3. Test coverage (require 95%+)
            4. Performance implications
            5. Architecture consistency

            Provide detailed feedback with code suggestions.

      - name: Codex Analysis
        env:
          OPENAI_API_KEY: ${{ secrets.OPENAI_API_KEY }}
        run: |
          codex review \
            --pr ${{ github.event.pull_request.number }} \
            --focus thread-safety \
            --focus performance \
            --focus test-coverage

      - name: Post Review
        uses: actions/github-script@v6
        with:
          script: |
            github.rest.issues.createComment({
              owner: context.repo.owner,
              repo: context.repo.repo,
              issue_number: context.payload.pull_request.number,
              body: process.env.REVIEW_RESULTS
            })
```

#### Template 4: n8n Workflow JSON Export

**Save as:** `n8n-workflows/voiceflow-orchestrator.json`
```json
{
  "name": "VoiceFlow Orchestrator",
  "nodes": [
    {
      "name": "Webhook Trigger",
      "type": "n8n-nodes-base.webhook",
      "parameters": {
        "path": "voiceflow-orchestrator",
        "responseMode": "responseNode",
        "options": {}
      },
      "position": [250, 300]
    },
    {
      "name": "Parse Request",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "const goal = $input.item.json.body.goal;\nconst context = $input.item.json.body.context || {};\nreturn [{json: {goal, context}}];"
      },
      "position": [450, 300]
    },
    {
      "name": "Claude Orchestrator",
      "type": "n8n-nodes-base.httpRequest",
      "parameters": {
        "url": "https://api.anthropic.com/v1/messages",
        "authentication": "headerAuth",
        "sendHeaders": true,
        "headerParameters": {
          "parameters": [
            {"name": "x-api-key", "value": "={{$credentials.apiKey}}"},
            {"name": "anthropic-version", "value": "2023-06-01"}
          ]
        },
        "sendBody": true,
        "bodyParameters": {
          "parameters": [
            {"name": "model", "value": "claude-sonnet-4-5-20250929"},
            {"name": "max_tokens", "value": 4096},
            {"name": "messages", "value": "[{\"role\":\"user\",\"content\":\"Act as VoiceFlow Orchestrator. Plan implementation for: {{$json.goal}}\"}]"}
          ]
        }
      },
      "position": [650, 300]
    },
    {
      "name": "Extract Tasks",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "const response = JSON.parse($input.item.json.body);\nconst plan = JSON.parse(response.content[0].text);\nreturn plan.tasks.map((task, i) => ({json: {...task, index: i}}));"
      },
      "position": [850, 300]
    },
    {
      "name": "Loop Tasks",
      "type": "n8n-nodes-base.splitInBatches",
      "parameters": {
        "batchSize": 1,
        "options": {}
      },
      "position": [1050, 300]
    },
    {
      "name": "Route by Agent",
      "type": "n8n-nodes-base.switch",
      "parameters": {
        "rules": {
          "rules": [
            {"value1": "={{$json.agent}}", "operation": "equals", "value2": "codex_executor"},
            {"value1": "={{$json.agent}}", "operation": "equals", "value2": "verification"},
            {"value1": "={{$json.agent}}", "operation": "equals", "value2": "integrator"}
          ]
        }
      },
      "position": [1250, 300]
    },
    {
      "name": "Codex Execute",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "cd /Users/lukaj/voiceflow && codex exec '{{$json.description}}'"
      },
      "position": [1450, 200]
    },
    {
      "name": "Verification",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "cd /Users/lukaj/voiceflow && swift test --enable-code-coverage"
      },
      "position": [1450, 300]
    },
    {
      "name": "Integration",
      "type": "n8n-nodes-base.executeCommand",
      "parameters": {
        "command": "cd /Users/lukaj/voiceflow && git add . && git commit -m '{{$json.commit_message}}' && gh pr create --title '{{$json.pr_title}}' --body '{{$json.pr_body}}'"
      },
      "position": [1450, 400]
    },
    {
      "name": "Collect Results",
      "type": "n8n-nodes-base.function",
      "parameters": {
        "functionCode": "// Aggregate all task results\nconst allResults = $input.all();\nconst success = allResults.every(r => r.json.exitCode === 0);\nreturn [{json: {success, results: allResults}}];"
      },
      "position": [1650, 300]
    },
    {
      "name": "Respond",
      "type": "n8n-nodes-base.respondToWebhook",
      "parameters": {
        "respondWith": "json",
        "responseBody": "={{$json}}"
      },
      "position": [1850, 300]
    }
  ],
  "connections": {
    "Webhook Trigger": {"main": [[{"node": "Parse Request"}]]},
    "Parse Request": {"main": [[{"node": "Claude Orchestrator"}]]},
    "Claude Orchestrator": {"main": [[{"node": "Extract Tasks"}]]},
    "Extract Tasks": {"main": [[{"node": "Loop Tasks"}]]},
    "Loop Tasks": {"main": [[{"node": "Route by Agent"}]]},
    "Route by Agent": {
      "main": [
        [{"node": "Codex Execute"}],
        [{"node": "Verification"}],
        [{"node": "Integration"}]
      ]
    },
    "Codex Execute": {"main": [[{"node": "Collect Results"}]]},
    "Verification": {"main": [[{"node": "Collect Results"}]]},
    "Integration": {"main": [[{"node": "Collect Results"}]]},
    "Collect Results": {"main": [[{"node": "Respond"}]]}
  }
}
```

**To use:**
```bash
# Import into n8n
n8n import:workflow --input=n8n-workflows/voiceflow-orchestrator.json

# Test
curl -X POST https://n8n.example.com/webhook/voiceflow-orchestrator \
  -H "Content-Type: application/json" \
  -d '{"goal": "Add PDF export functionality"}'
```

---

### 🎯 Implementation Checklist

To enable full orchestration automation:

**Week 1: Setup**
- [ ] Install claude-flow MCP server
- [ ] Configure n8n (if using)
- [ ] Create custom agents (orchestrator, codex_executor, verification, integrator)
- [ ] Create custom skills (voiceflow-architect, voiceflow-tester, voiceflow-performance)
- [ ] Configure hooks in `.claude/settings.toml`
- [ ] Create slash commands (`/implement`, `/refactor`)
- [ ] Test basic orchestration workflow

**Week 2: Integration**
- [ ] Integrate XcodeBuildMCP
- [ ] Create custom voiceflow-dev MCP server
- [ ] Set up GitHub Actions for AI review
- [ ] Create n8n workflows
- [ ] Configure webhook triggers
- [ ] Test end-to-end automation

**Week 3: Optimization**
- [ ] Tune agent prompts based on results
- [ ] Optimize task decomposition
- [ ] Improve error handling
- [ ] Add monitoring and logging
- [ ] Document workflows
- [ ] Train team on orchestration

**Verification:**
```bash
# Test orchestration
/implement "Add voice activity detection"

# Expected: Full feature implemented in 3-6 hours with:
# - All code generated
# - Tests at 95%+ coverage
# - All quality gates passed
# - PR created
# - Zero manual intervention required
```

---

### 📊 Expected Outcomes

With full orchestration automation:

| Metric | Before | After | Improvement |
|--------|--------|-------|-------------|
| **Feature Development Time** | 2-3 days | 3-6 hours | 4-6x faster |
| **Manual Steps** | 20-30 | 2-3 | 10x reduction |
| **Test Coverage** | 75-80% | 95%+ | +20% |
| **Quality Issues** | 3-5 per feature | <1 | 5x better |
| **Code Review Time** | 1-2 hours | 15-30 min | 3x faster |
| **Deployment Frequency** | Weekly | Daily | 5x more frequent |

**ROI Calculation:**
- Developer time saved: ~12 hours/feature
- Features per month: 4-6
- Time savings: ~50-70 hours/month
- **Productivity gain: 300-400%**

---

### 🎓 Best Practices for Orchestration

1. **Start Simple**: Begin with manual delegation, gradually automate
2. **Checkpoint Everything**: Use Claude Code checkpoints before major changes
3. **Verify Continuously**: Run tests after each task, not just at the end
4. **Clear Communication**: Agents should report status clearly
5. **Handle Failures**: Implement retry logic with exponential backoff
6. **Monitor Performance**: Track automation metrics, optimize bottlenecks
7. **Document Workflows**: Keep runbooks for complex orchestrations
8. **Iterate**: Continuously improve based on results

---

## 🎓 Conclusion

VoiceFlow 2.0 represents a strategic evolution of an already excellent codebase. By adopting Swift 6.2 features, modern architecture patterns, and AI-first development workflows, we will create a model Swift application that sets the standard for 2025.

### Key Takeaways

1. **Build on Strengths**: The current architecture is solid (9.2/10). We enhance, not rebuild.

2. **Adopt Latest Tech**: Swift 6.2, Swift Testing, TCA patterns, modern concurrency.

3. **AI-First Development**: Claude Code + Codex CLI + MCP = 3-4x velocity.

4. **Quality Gates**: 95%+ coverage, strict linting, performance benchmarks.

5. **Pragmatic Migration**: 6-week plan with clear milestones and risk mitigation.

6. **Future-Proof**: Architecture supports expansion to iOS, watchOS, visionOS.

### Success Factors

✅ **Clear Plan**: Week-by-week roadmap with deliverables
✅ **Risk Mitigation**: Checkpoints, gradual rollout, comprehensive testing
✅ **Tool Integration**: MCP, Codex, XcodeBuild automation
✅ **Quality Focus**: 95%+ coverage, performance benchmarks
✅ **Team Enablement**: Documentation, guides, AI pair programming

### Next Steps

1. **Review this plan** with stakeholders
2. **Set up development environment** (Week 1, Day 1)
3. **Begin Phase 1** critical fixes
4. **Track progress** weekly
5. **Adjust as needed** based on learnings

**Let's build something amazing! 🚀**

---

**Document Version:** 1.0.0
**Last Updated:** 2025-11-02
**Authors:** Claude Code (Sonnet 4.5) + Research Analysis
**Status:** Ready for Implementation
