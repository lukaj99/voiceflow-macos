# VoiceFlow Development Plan

## Project Overview
VoiceFlow is a Swift 6 macOS application for voice-to-text transcription and workflow automation.

## Architecture

### Module Structure
```
VoiceFlow/
├── App/              # Application bootstrap & entry point
├── Core/             # Shared state management & coordination
├── Features/         # Modular feature implementations
├── Services/         # External integrations (Deepgram, Keychain, Audio)
├── Shared/           # Utilities & common helpers
├── Resources/        # Assets, entitlements, configuration
├── ViewModels/       # Presentation logic
└── Views/            # SwiftUI interface components

ThirdParty/           # Vendored dependencies (e.g., Starscream)
Scripts/              # Build & automation tooling
VoiceFlowTests/       # Test suites
VoiceFlowUITests/     # UI automation tests
```

## Development Workflow

### 1. Setup & Dependencies
```bash
# Resolve dependencies
swift package resolve

# Verify build
swift build
```

### 2. Development Cycle
```bash
# Incremental debug builds
swift build

# Run locally
swift run VoiceFlow

# Run with testing diagnostics
swift run VoiceFlow --enable-testing
```

### 3. Code Quality
```bash
# Format code (required before commits)
swiftformat VoiceFlow VoiceFlowTests

# Lint (strict mode - warnings = failures)
swiftlint --strict
```

### 4. Testing
```bash
# Run all tests
swift test

# Run specific test suite
swift test --filter VoiceFlowTests.Unit

# Generate coverage report (maintain ≥90%)
swift test --enable-code-coverage
```

### 5. Release Builds
```bash
# Production-ready build
swift build --configuration release
```

## Testing Strategy

### Test Organization
- **Unit Tests** (`VoiceFlowTests/Unit/`) - Component-level coverage
- **Integration Tests** (`VoiceFlowTests/Integration/`) - Feature flows with mocks
- **Performance Tests** (`VoiceFlowTests/Performance/`) - Concurrency & benchmarks
- **Security Tests** (`VoiceFlowTests/Security/`) - Credential & entitlement validation
- **LLM Tests** (`VoiceFlowTests/LLM/`) - AI integration scenarios
- **UI Tests** (`VoiceFlowUITests/`) - End-to-end smoke tests

### Coverage Requirements
- Minimum: 90% code coverage
- All new features require corresponding unit tests
- Integration tests for external service interactions
- Performance tests gated behind `#if PERFORMANCE`

## Code Style Standards

### Formatting Rules
- **Indentation**: 4 spaces (no tabs)
- **Line Length**: 120 characters max
- **Case Conventions**:
  - Types/Protocols: `UpperCamelCase`
  - Members/functions: `lowerCamelCase`
  - Acronyms: `URL`, `API`, `LLM` (preserved casing)
- **Organization**: Use `// MARK:` to delineate module sections
- **Concurrency**: Apply `@MainActor` for UI-bound APIs
- **Dependencies**: Inject via initializers (no singletons)

## Security Guidelines

### Credential Management
- **Never** hardcode API keys or secrets
- Use `SecureCredentialService` for all sensitive data
- Store credentials in macOS Keychain
- Isolate WebSocket changes to `ThirdParty/Starscream`

### Entitlements & Configuration
- Update `Resources/Entitlements/VoiceFlow.entitlements` when modifying capabilities
- Document all security-related changes in PRs
- Flag manual verification steps for reviewers

## Commit & PR Process

### Commit Format
```
<type>: <imperative summary>

- Bullet point details
- Group related changes
- Squash fixups before PR
```

### Pull Request Checklist
- [ ] Concise summary with linked issues
- [ ] Screenshots for UI changes
- [ ] Test command outputs included
- [ ] Security changes highlighted
- [ ] SwiftLint passes (`--strict`)
- [ ] SwiftFormat applied
- [ ] ≥90% test coverage maintained
- [ ] Manual verification steps documented

## Common Tasks

### Adding a New Feature
1. Create feature module in `VoiceFlow/Features/<FeatureName>/`
2. Implement with `@MainActor` annotations where needed
3. Add unit tests in `VoiceFlowTests/Unit/<FeatureName>Tests.swift`
4. Add integration tests if external services involved
5. Run full test suite + coverage check
6. Format and lint before committing

### Modifying External Services
1. Isolate changes to appropriate `Services/` module
2. Update mocks in `VoiceFlowTests/Mocks/`
3. Add integration tests for new service behavior
4. Document API changes in PR
5. Verify Keychain integration if credentials affected

### Performance Optimization
1. Add baseline performance test in `Performance/`
2. Gate with `#if PERFORMANCE`
3. Implement optimization
4. Verify improvement with benchmark
5. Include before/after metrics in PR

## CI/CD Notes
- Warnings treated as failures in CI
- Code coverage checked automatically
- SwiftLint runs in strict mode
- Release builds validated before App Store submission
