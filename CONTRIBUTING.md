# Contributing to VoiceFlow

Thank you for your interest in contributing to VoiceFlow! This guide will help you get started with contributing to this professional macOS voice transcription application.

## 🚀 Getting Started

### Prerequisites

- macOS 14.0 or later
- Xcode 15.0 or later
- Swift 6.2 or later
- Git

### Setting Up Your Development Environment

1. **Fork the repository** on GitHub
2. **Clone your fork** locally:
   ```bash
   git clone https://github.com/YOUR_USERNAME/voiceflow-macos.git
   cd voiceflow-macos
   ```
3. **Add the upstream remote**:
   ```bash
   git remote add upstream https://github.com/lukaj99/voiceflow-macos.git
   ```
4. **Install dependencies**:
   ```bash
   swift package resolve
   ```
5. **Build the project**:
   ```bash
   swift build
   ```
6. **Run tests** to ensure everything works:
   ```bash
   swift test
   ```

## 📋 How to Contribute

### Reporting Issues

Before creating a new issue, please:

1. **Search existing issues** to avoid duplicates
2. **Use the issue template** when available
3. **Include detailed information**:
   - macOS version
   - Xcode version
   - Swift version
   - Steps to reproduce
   - Expected vs. actual behavior
   - Screenshots if applicable

### Submitting Changes

1. **Create a feature branch** from `main`:
   ```bash
   git checkout -b feature/your-feature-name
   ```

2. **Make your changes** following our coding standards:
   - Follow Swift API Design Guidelines
   - Use descriptive variable and function names
   - Add appropriate documentation
   - Include comprehensive tests

3. **Test your changes**:
   ```bash
   swift test
   swift build --configuration release
   ```

4. **Commit your changes** with clear messages:
   ```bash
   git commit -m "feat: add new transcription engine feature
   
   - Implement real-time processing improvements
   - Add error handling for edge cases
   - Update documentation"
   ```

5. **Push to your fork**:
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Create a pull request** with:
   - Clear title and description
   - Reference any related issues
   - Screenshots for UI changes
   - Test results

## 🎯 Coding Standards

### Swift Style Guide

- **Follow Swift API Design Guidelines**
- **Use SwiftFormat** for consistent formatting
- **Use SwiftLint** for code quality
- **Prefer explicit types** when it improves readability
- **Use meaningful names** for variables, functions, and types

### Code Structure

```swift
// MARK: - Type Definition
@Observable
final class MyViewModel {
    // MARK: - Properties
    @MainActor
    private(set) var state: ViewState = .idle
    
    // MARK: - Initialization
    init() {
        setupObservers()
    }
    
    // MARK: - Public Methods
    func performAction() async {
        // Implementation
    }
    
    // MARK: - Private Methods
    private func setupObservers() {
        // Implementation
    }
}
```

### Documentation

- **Document public APIs** with clear descriptions
- **Include parameter descriptions** for complex functions
- **Provide usage examples** where helpful
- **Update README.md** for significant changes

```swift
/// Processes audio input for transcription
/// - Parameters:
///   - audioData: Raw audio data to process
///   - language: Target language for transcription
/// - Returns: Processed transcription result
/// - Throws: TranscriptionError if processing fails
func processAudio(_ audioData: Data, language: VoiceLanguage) async throws -> TranscriptionResult
```

### Testing

- **Write unit tests** for all new functionality
- **Include integration tests** for complex features
- **Test error conditions** and edge cases
- **Maintain test coverage** above 90%

```swift
final class MyViewModelTests: XCTestCase {
    private var viewModel: MyViewModel!
    
    override func setUp() {
        super.setUp()
        viewModel = MyViewModel()
    }
    
    override func tearDown() {
        viewModel = nil
        super.tearDown()
    }
    
    func testFeatureImplementation() async {
        // Test implementation
    }
}
```

## 🏗️ Architecture Guidelines

### MVVM Pattern

- **Views**: SwiftUI views for UI presentation
- **ViewModels**: Business logic and state management
- **Models**: Data structures and business objects
- **Services**: External API and system integrations

### State Management

- Use `@Observable` for reactive state management
- Implement `@MainActor` for UI-related state
- Use `Combine` for complex data flows
- Follow Swift 6 concurrency patterns

### Error Handling

- Use structured error types
- Implement proper error recovery
- Provide user-friendly error messages
- Log errors for debugging

## 🔧 Development Workflow

### Branch Naming

- `feature/feature-name` - New features
- `bugfix/bug-description` - Bug fixes
- `hotfix/critical-fix` - Critical production fixes
- `docs/documentation-update` - Documentation changes

### Commit Messages

Follow the [Conventional Commits](https://www.conventionalcommits.org/) specification:

```
type(scope): description

[optional body]

[optional footer]
```

Types:
- `feat`: New features
- `fix`: Bug fixes
- `docs`: Documentation changes
- `style`: Code style changes
- `refactor`: Code refactoring
- `test`: Test additions or changes
- `chore`: Build process or auxiliary tool changes

### Pull Request Process

1. **Ensure CI passes** (tests, linting, security scans)
2. **Request review** from maintainers
3. **Address feedback** promptly
4. **Squash commits** if requested
5. **Merge** will be handled by maintainers

## 🛡️ Security Guidelines

- **Never commit credentials** or API keys
- **Use SecureCredentialService** for sensitive data
- **Validate all inputs** using ValidationFramework
- **Follow security best practices** for macOS development

## 📚 Resources

### Documentation

- [Swift API Design Guidelines](https://swift.org/documentation/api-design-guidelines/)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- [macOS Development Guide](https://developer.apple.com/macos/)

### Tools

- [SwiftFormat](https://github.com/nicklockwood/SwiftFormat)
- [SwiftLint](https://github.com/realm/SwiftLint)
- [Xcode](https://developer.apple.com/xcode/)

### Learning Resources

- [Swift Evolution](https://github.com/apple/swift-evolution)
- [Swift Concurrency](https://docs.swift.org/swift-book/documentation/the-swift-programming-language/concurrency/)
- [Combine Framework](https://developer.apple.com/documentation/combine)

## 🙋‍♂️ Getting Help

- **GitHub Issues**: For bug reports and feature requests
- **GitHub Discussions**: For questions and general discussion
- **Code Review**: For implementation feedback

## 📝 License

By contributing to VoiceFlow, you agree that your contributions will be licensed under the same MIT License that covers the project.

---

Thank you for contributing to VoiceFlow! Your help makes this project better for everyone. 🎉 