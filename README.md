# VoiceFlow 🎙️

VoiceFlow is a high-performance macOS voice transcription app that leverages the latest speech recognition technology to provide real-time, context-aware transcription with industry-leading sub-50ms latency.

## Features

### Core Capabilities
- **Real-time Transcription**: Sub-50ms latency using the new SpeechAnalyzer framework (macOS 26)
- **Context Awareness**: Automatically adapts to your current application (coding, email, meetings)
- **Global Hotkey**: Quick access with ⌘⌥Space from anywhere
- **Floating Widget**: Always-visible, draggable transcription status
- **Menu Bar Integration**: Unobtrusive control from the menu bar

### Advanced Features
- **Custom Vocabulary**: Add technical terms, names, and jargon
- **Multi-Language Support**: Automatic language detection
- **Privacy-First**: All processing happens on-device
- **Export Options**: Save as TXT, Markdown, or DOCX

## System Requirements

- macOS 14.0 (Sonoma) or later
- Apple Silicon (M1/M2/M3) or Intel processor
- 4GB RAM minimum (8GB recommended)
- 500MB free disk space

## Installation

### From Release (Recommended)
1. Download the latest release from [Releases](https://github.com/yourusername/voiceflow/releases)
2. Open the DMG file
3. Drag VoiceFlow to your Applications folder
4. Launch VoiceFlow from Applications

### Building from Source
```bash
# Clone the repository
git clone https://github.com/yourusername/voiceflow.git
cd voiceflow

# Install dependencies
swift package resolve

# Build
xcodebuild -scheme VoiceFlow -configuration Release

# Run
open build/Release/VoiceFlow.app
```

## Usage

### Getting Started
1. Launch VoiceFlow
2. Grant microphone permissions when prompted
3. Click the microphone icon in the menu bar
4. Press ⌘⌥Space to start/stop transcription

### Keyboard Shortcuts
- `⌘⌥Space` - Toggle transcription
- `⌘,` - Open settings
- `⌘Q` - Quit VoiceFlow

### Context Modes
VoiceFlow automatically detects your active application and optimizes transcription:
- **Coding Mode**: Recognizes programming keywords and syntax
- **Email Mode**: Formal language and proper capitalization
- **Meeting Mode**: Speaker identification and action items
- **General Mode**: Balanced accuracy for everyday use

## Development

### Project Structure
```
VoiceFlow/
├── App/                    # Application entry point
├── Core/                   # Core transcription engine
│   ├── TranscriptionEngine/
│   ├── AI/
│   └── Storage/
├── Features/              # UI components
│   ├── MenuBar/
│   ├── FloatingWidget/
│   └── Transcription/
└── Tests/                 # Test suites
```

### Key Components
- **SpeechAnalyzerEngine**: Core transcription engine with <50ms latency
- **ContextAnalyzer**: Detects active application context
- **MenuBarController**: Global hotkey and menu management
- **FloatingWidget**: Draggable transcription status widget

### Performance Targets
- Transcription Latency: P95 < 50ms
- Memory Usage: < 200MB active
- CPU Usage: < 10% during transcription
- Accuracy: > 95% in quiet environments

### Testing
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter PerformanceTests

# Run with coverage
swift test --enable-code-coverage
```

## Privacy

VoiceFlow is designed with privacy as a core principle:
- ✅ All transcription happens on-device
- ✅ No audio data leaves your Mac
- ✅ No internet connection required
- ✅ Open source for transparency

## Contributing

We welcome contributions! Please see [CONTRIBUTING.md](CONTRIBUTING.md) for guidelines.

### Development Setup
1. Fork the repository
2. Create a feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built with Swift and SwiftUI
- Uses the new SpeechAnalyzer framework (macOS 26)
- Inspired by the need for better voice transcription tools

## Support

- 📧 Email: support@voiceflow.app
- 🐛 Issues: [GitHub Issues](https://github.com/yourusername/voiceflow/issues)
- 💬 Discussions: [GitHub Discussions](https://github.com/yourusername/voiceflow/discussions)

---

Made with ❤️ for the macOS community