# VoiceFlow Agent Guide

## 🤖 Background Agent Quick Reference

This guide provides essential information for background agents working with the VoiceFlow codebase.

## 📋 Project Summary

**VoiceFlow** is a professional macOS voice transcription application built with Swift 6, featuring real-time speech recognition, advanced export capabilities, and a privacy-first design.

### Key Technologies
- **Swift 6.2** with strict concurrency
- **SwiftUI + AppKit** for native macOS UI
- **Speech Framework** for on-device transcription
- **Deepgram API** for cloud-based transcription
- **AVFoundation** for audio processing
- **Keychain Services** for secure credential storage

## 🏗️ Architecture Overview

### Core Components Structure

```
VoiceFlow/
├── App/                          # Application lifecycle
│   └── VoiceFlowApp.swift       # Main app entry point
├── Core/                         # Business logic core
│   ├── AppState.swift           # Global state management
│   ├── ErrorHandling/           # Error management system
│   ├── Performance/             # Performance monitoring
│   ├── TranscriptionEngine/     # Core transcription models
│   └── Validation/              # Input validation
├── Services/                     # External integrations
│   ├── AudioManager.swift       # Audio input management
│   ├── DeepgramClient.swift     # API client
│   ├── GlobalHotkeyService.swift # System hotkeys
│   └── SecureCredentialService.swift # Credential management
├── ViewModels/                   # MVVM layer
│   ├── MainTranscriptionViewModel.swift
│   ├── TranscriptionCoordinator.swift
│   └── CredentialManager.swift
└── Views/                        # SwiftUI interface
    ├── ContentView.swift
    ├── SettingsView.swift
    └── FloatingMicrophoneWidget.swift
```

## 🔧 Common Operations

### Building and Running

```bash
# Build the project
swift build --configuration release

# Run the application
swift run

# Run tests
swift test

# Build for Xcode
open Package.swift
```

### Key Files to Understand

1. **VoiceFlowApp.swift** - Application entry point and lifecycle
2. **AppState.swift** - Global state management with @Observable
3. **MainTranscriptionViewModel.swift** - Core transcription logic
4. **AudioManager.swift** - Audio input and processing
5. **DeepgramClient.swift** - API integration for cloud transcription
6. **ContentView.swift** - Main user interface

## 🎯 Development Patterns

### State Management
- Uses `@Observable` for reactive state management
- `AppState` holds global application state
- ViewModels manage feature-specific state

### Concurrency
- Swift 6 strict concurrency enabled
- `@MainActor` isolation for UI updates
- Async/await patterns throughout
- Actor-based state management for thread safety

### Error Handling
- Custom `VoiceFlowError` types
- Structured error recovery with `ErrorRecoveryManager`
- User-friendly error reporting

## 🔐 Security & Privacy

### Credential Management
- Keychain integration for API keys
- Secure credential storage with `SecureCredentialService`
- No plain-text credential storage

### Privacy Features
- On-device transcription option
- Local audio processing
- Privacy-first design principles

## 📊 Performance Considerations

### Optimization Points
- Audio buffer pooling in `AudioBufferPool`
- Concurrent processing for transcription
- Memory-efficient export operations
- Background processing for non-blocking UI

### Monitoring
- `PerformanceMonitor` tracks key metrics
- Audio processing latency monitoring
- Memory usage tracking

## 🧪 Testing Strategy

### Test Structure
```
VoiceFlowTests/
├── Unit/              # Unit tests for components
├── Integration/       # Integration tests
├── Performance/       # Performance benchmarks
├── Security/          # Security validation
└── Mocks/            # Mock implementations
```

### Key Test Files
- `SecureCredentialServiceTests.swift` - Credential security
- `ValidationFrameworkTests.swift` - Input validation
- `PerformanceTests.swift` - Performance benchmarks

## 🔌 API Integration

### Deepgram Integration
- Real-time WebSocket connection
- Streaming audio processing
- Multiple language support
- Error handling and reconnection

### Apple Speech Framework
- On-device processing
- Privacy-focused transcription
- Offline capability

## 🛠️ Development Tools

### Useful Commands
```bash
# Format code
swiftformat .

# Run linting
swiftlint

# Generate documentation
swift package generate-documentation

# Clean build
swift package clean
```

### IDE Configuration
- Xcode project via `Package.swift`
- VSCode with Swift extension
- SwiftFormat and SwiftLint integration

## 📱 macOS Integration

### System Features
- Menu bar integration
- Global hotkeys support
- Floating widget capability
- Dock integration
- Notification center support

### Permissions Required
- Microphone access
- Accessibility permissions (for global hotkeys)
- Network access (for Deepgram API)

## 🚀 Deployment

### Build Configuration
- Debug: Local development with verbose logging
- Release: Optimized for performance
- Distribution: App Store ready

### App Store Preparation
- Code signing configuration
- Entitlements setup
- Privacy policy compliance
- App metadata preparation

## 🔄 Common Workflows

### Adding New Features
1. Create feature branch
2. Implement in appropriate layer (Core/Services/ViewModels/Views)
3. Add comprehensive tests
4. Update documentation
5. Performance testing
6. Security review

### Debugging Issues
1. Check console logs in `ErrorReporter`
2. Review performance metrics
3. Validate input/output in validation layer
4. Check network connectivity for API issues

## 💡 Agent Tips

### Code Navigation
- Use semantic search for broad understanding
- Focus on protocol definitions for interfaces
- Check test files for usage examples
- Review error handling for edge cases

### Understanding Data Flow
1. **Audio Input** → `AudioManager` → Processing
2. **Transcription** → `TranscriptionEngine` → Text
3. **Export** → `ExportManager` → File System
4. **Settings** → `SettingsService` → User Preferences

### Key Protocols and Interfaces
- `AudioManagerProtocol` - Audio input abstraction
- `TranscriptionEngineProtocol` - Transcription interface
- `ExportManagerProtocol` - Export functionality
- `SettingsServiceProtocol` - Configuration management

## 🎨 UI/UX Patterns

### SwiftUI Components
- Custom `LiquidGlassBackground` for modern aesthetic
- Responsive design for different screen sizes
- Dark/light mode support
- Accessibility compliance

### User Experience
- Minimal cognitive load
- Clear visual feedback
- Intuitive navigation
- Professional appearance

## 📈 Performance Metrics

### Key Indicators
- Audio processing latency: <50ms target
- Memory usage: <100MB steady state
- CPU usage: <10% during transcription
- Network efficiency: Minimal data usage

### Optimization Areas
- Audio buffer management
- Concurrent processing
- Memory allocation patterns
- Network request batching

---

## 🔗 Quick Links

- **Repository**: https://github.com/lukaj99/voiceflow-macos
- **Documentation**: `/Documentation/`
- **Tests**: `/VoiceFlowTests/`
- **Issues**: Track in GitHub Issues
- **Releases**: GitHub Releases page

## 📚 Additional Resources

- Swift 6 Concurrency Documentation
- SwiftUI Best Practices
- macOS Development Guidelines
- App Store Review Guidelines

---

*This guide is optimized for background agent interactions and provides comprehensive coverage of the VoiceFlow codebase structure and development patterns.* 