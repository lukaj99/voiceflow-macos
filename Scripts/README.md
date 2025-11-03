# VoiceFlow Development Scripts

Comprehensive development tools for VoiceFlow Swift 6 macOS application.

## Quick Start

```bash
# Make executable (already done)
chmod +x Scripts/dev-tools.sh

# Show all commands
./Scripts/dev-tools.sh help

# Common workflows
./Scripts/dev-tools.sh build           # Quick debug build
./Scripts/dev-tools.sh test            # Run all tests
./Scripts/dev-tools.sh benchmark       # Performance benchmarks
./Scripts/dev-tools.sh coverage-html   # Generate coverage report
```

## Key Features

### 🏗️ Build & Test
- **build**: Fast incremental debug build
- **build-release**: Optimized release build with full optimizations
- **test**: Full test suite (unit + performance + UI)
- **test-perf**: Isolated performance benchmarks
- **clean**: Remove all build artifacts

### 🔍 Code Quality
- **concurrency**: Verify Swift 6 strict concurrency compliance
- **warnings**: Build with all warnings as errors
- **coverage**: Terminal coverage report
- **coverage-html**: Interactive HTML coverage report

### ⚡ Performance Analysis
- **benchmark**: Comprehensive performance suite
- **buffer-stats**: AudioBufferPool efficiency analysis
- **profile**: Quick performance timing
- **memory-profile**: Guide for Instruments profiling

### 🔬 Analysis Tools
- **actors**: Analyze @MainActor and actor isolation
- **dependencies**: Show Swift package dependency tree
- **size**: Binary size analysis
- **analyze**: Swift static analysis

### 🛠️ Utilities
- **format**: Code formatting (requires SwiftFormat)
- **lint**: SwiftLint checks (requires SwiftLint)
- **docs**: Generate Swift documentation

## Examples

### Pre-commit Workflow
```bash
./Scripts/dev-tools.sh concurrency  # Verify Swift 6 compliance
./Scripts/dev-tools.sh test         # Run full test suite
./Scripts/dev-tools.sh warnings     # No warnings allowed
```

### Performance Optimization
```bash
./Scripts/dev-tools.sh benchmark    # Run performance suite
./Scripts/dev-tools.sh buffer-stats # Check AudioBufferPool
./Scripts/dev-tools.sh size         # Analyze binary size
```

### Coverage Analysis
```bash
./Scripts/dev-tools.sh coverage-html
open coverage-report/index.html
```

### Actor Safety Audit
```bash
./Scripts/dev-tools.sh actors       # Find all actors and @MainActor
./Scripts/dev-tools.sh concurrency  # Verify data race safety
```

## Integration with Claude Code

Claude Code can directly invoke these tools:

```bash
# In Claude Code
./Scripts/dev-tools.sh <command>
```

This provides superior ergonomics compared to a custom MCP server:
- ✅ Direct execution, no IPC overhead
- ✅ Native Swift tooling integration
- ✅ Simple bash scripts, easy to maintain
- ✅ Colored output for better UX
- ✅ No external dependencies

## Why Not a Custom MCP?

For Swift macOS development, direct script execution is superior:

1. **Native Tooling**: Swift's CLI tools are comprehensive
2. **Zero Latency**: No server startup or IPC overhead
3. **Simplicity**: Just bash + Swift commands
4. **Maintainability**: No separate Node/Python service
5. **Portability**: Works anywhere Swift is installed

## Requirements

- **Required**: Xcode 15.0+, Swift 6.0+
- **Optional**: SwiftFormat, SwiftLint (for format/lint commands)
- **Platform**: macOS 14.0+ (Sonoma)

## Architecture Alignment

These tools directly support VoiceFlow's architecture:

- **Swift 6 Concurrency**: `concurrency` command verifies strict compliance
- **Performance**: `benchmark` and `buffer-stats` for audio processing metrics
- **Actor Safety**: `actors` command audits isolation boundaries
- **Test Coverage**: `coverage-html` for comprehensive testing feedback

## Contributing

To add new commands:

1. Add function: `cmd_mycommand() { ... }`
2. Add to help text
3. Add case in main dispatcher
4. Test: `./Scripts/dev-tools.sh mycommand`

Keep commands focused and fast. Leverage Swift's native tooling.
