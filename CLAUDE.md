# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### Development
- `swift build --configuration debug`: Build for development
- `swift build --configuration release`: Build optimized release version  
- `swift run`: Build and run the VoiceFlow app
- `swift test`: Run the complete test suite
- `./Scripts/optimize-build.sh`: Build with Swift 6 optimizations and parallel compilation

### Testing
- `swift test --parallel`: Run tests in parallel
- `swift test --filter <TestName>`: Run specific test
- `./Scripts/run-parallel-tests.sh`: Run tests across multiple worktrees

### Xcode Integration
- `open VoiceFlow.xcodeproj`: Open in Xcode (preferred for UI work)
- `xcodebuild -project VoiceFlow.xcodeproj -scheme VoiceFlow -configuration Debug build`: Command-line Xcode build
- `xcodebuild test -project VoiceFlow.xcodeproj -scheme VoiceFlow`: Run tests via Xcode

## Project Architecture

### Core Application Structure
VoiceFlow is a Swift 6 macOS voice transcription app with strict concurrency compliance:

**Core Engine** (`VoiceFlow/Core/TranscriptionEngine/`)
- `RealSpeechRecognitionEngine.swift`: Main speech recognition using Apple Speech framework
- `AudioEngineManager.swift`: AVAudioEngine management and audio processing
- `TranscriptionModels.swift`: Data models for transcription state and results
- `PerformanceMonitor.swift`: Real-time performance tracking and metrics

**Features** (`VoiceFlow/Features/`)
- **MenuBar**: Native macOS menu bar integration with global shortcuts
- **FloatingWidget**: Overlay window for quick transcription access
- **Settings**: User preferences and configuration UI
- **Transcription**: Main transcription interface and view models

**Services** (`VoiceFlow/Services/`)
- **Export**: Multi-format export system (Text, Markdown, PDF, DOCX, SRT subtitles)
- **HotkeyService**: Global keyboard shortcuts using HotKey framework
- **SessionStorageService**: Persistent transcription session management
- **LaunchAtLoginService**: System startup integration

**Dependencies** (Swift Package Manager)
- `HotKey`: Global keyboard shortcuts
- `KeychainAccess`: Secure credential storage
- `AsyncAlgorithms`: Swift 6 async stream processing

### Concurrency Architecture
- **Swift 6 strict concurrency**: All concurrency issues resolved with proper isolation
- **MainActor isolation**: UI components properly isolated to main thread
- **AsyncAlgorithms**: Used for parallel transcription processing
- **Combine + async/await**: Hybrid reactive and async patterns

### Entry Points
- `main.swift`: App bootstrap using AdvancedAppDelegate
- `AdvancedApp.swift`: Main application delegate and window management
- `VoiceFlowApp.swift`: Alternative SwiftUI app entry point

## Development Workflow

### File Organization
- Keep transcription logic in `Core/TranscriptionEngine/`
- UI components go in `Features/[FeatureName]/`
- Cross-cutting services in `Services/`
- Export functionality in `Services/Export/`

### Swift 6 Compliance
- Use `@MainActor` for UI-related classes
- Prefer async/await over completion handlers
- Use AsyncAlgorithms for stream processing
- Enable strict concurrency checking in all new code

### Testing Strategy
- Unit tests: `VoiceFlowTests/Unit/`
- Performance tests: `VoiceFlowTests/Performance/`
- Integration tests: Speech recognition integration tests
- UI tests: `VoiceFlowUITests/`

### Parallel Development
This project uses git worktrees for parallel development across multiple feature branches. Scripts in `Scripts/` directory support:
- Parallel builds across worktrees
- Coordinated testing
- Build optimization

## Platform Requirements
- **macOS 14.0+**: Required for latest Swift and system frameworks
- **Xcode 15.0+**: For Swift 6 support and native framework access
- **Apple Silicon or Intel**: Universal binary support

## Dependencies and Frameworks
- **Speech**: Apple's native speech recognition
- **AVFoundation**: Audio engine and processing
- **SwiftUI + AppKit**: Hybrid UI approach for native macOS experience
- **PDFKit**: PDF export generation
- **Combine**: Reactive UI updates

## Code Style
- Follow Swift 6 concurrency patterns
- Use explicit MainActor annotations for UI code
- Prefer structured concurrency over callbacks
- Keep models in separate files from view logic
- Use meaningful async function names