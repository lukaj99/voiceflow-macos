# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Build Commands

### Swift Package Manager (Primary - 2025 Standard)
- `swift build`: Build for development
- `swift build --configuration release`: Build optimized release version  
- `swift run`: Build and run the VoiceFlow app
- `swift test`: Run the complete test suite
- `swift package resolve`: Resolve package dependencies
- `swift package clean`: Clean build artifacts

### Xcode Integration (For App Store Distribution)
- `open VoiceFlow.xcodeproj`: Open in Xcode when needed for distribution
- Archive and distribute through Xcode for App Store submission

## Project Architecture

### Simplified 2025 Architecture
VoiceFlow is a clean Swift 6 macOS voice transcription app:

**Core** (`VoiceFlow/Core/`)
- `TranscriptionEngine/`: Speech recognition using Apple's Speech framework
- `Performance/`: Essential performance monitoring
- `Protocols/`: Clean interface definitions

**Features** (`VoiceFlow/Features/`)
- `Transcription/`: Main UI and view models
- `MenuBar/`: macOS menu bar integration
- `FloatingWidget/`: Quick access overlay
- `Settings/`: User preferences

**Services** (`VoiceFlow/Services/`)
- `Export/`: Multi-format export (Text, Markdown, PDF, DOCX, SRT)
- Essential services (HotkeyService, SettingsService, etc.)

**Dependencies** (Swift Package Manager)
- `HotKey` (0.2.1): Global keyboard shortcuts
- `KeychainAccess` (4.2.2): Secure credential storage
- `AsyncAlgorithms` (1.0.4): Swift 6 async processing

### Concurrency Architecture
- **Swift 6 strict concurrency**: Clean concurrency with proper isolation
- **MainActor isolation**: UI components properly isolated to main thread
- **AsyncAlgorithms**: Modern async stream processing
- **async/await**: Modern Swift concurrency patterns

### Entry Point
- `main.swift`: Clean SwiftUI App bootstrap
- `App/VoiceFlowApp.swift`: Modern SwiftUI App implementation

## Development Workflow

### File Organization
- Core logic in `Core/TranscriptionEngine/`
- UI components in `Features/[FeatureName]/`
- Services in `Services/`
- Follow standard Swift package structure

### Swift 6 Compliance
- Use `@MainActor` for UI-related classes
- Prefer async/await over completion handlers
- Use AsyncAlgorithms for stream processing
- Enable strict concurrency checking

**Enabled Swift 6 Features**:
- `ExistentialAny`, `GlobalConcurrency`
- Compiler flag: `SWIFT_CONCURRENCY_STRICT`

### Testing Strategy
- Unit tests: `VoiceFlowTests/Unit/`
- Performance tests: `VoiceFlowTests/Performance/`
- UI tests: `VoiceFlowUITests/`
- Use standard `swift test` command

### Development Workflow
- Standard git branching strategy
- Use `swift build` for development
- Use `swift test` for testing
- Use Xcode only for App Store distribution

## 2025 Build System

### Swift Package Manager First
- **Primary development**: `swift build`, `swift test`, `swift run`
- **Xcode when needed**: App Store distribution only
- **Simple and clean**: No custom scripts or complex workflows

## Platform Requirements
- **macOS 14.0+**: Required for Swift 6 and modern frameworks
- **Xcode 15.0+**: For Swift 6 support
- **Apple Silicon or Intel**: Universal binary support

## Dependencies and Frameworks
- **Speech**: Apple's native speech recognition
- **AVFoundation**: Audio engine and processing
- **SwiftUI**: Modern declarative UI
- **AppKit**: Native macOS integration

## Code Style
- Follow Swift 6 concurrency patterns
- Use `@MainActor` for UI code
- Prefer async/await over callbacks
- Keep implementations simple and working
- Focus on essential functionality