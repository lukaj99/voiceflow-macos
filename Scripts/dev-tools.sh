#!/bin/bash
# VoiceFlow Development Tools
# Comprehensive dev utilities for Swift 6 macOS development

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

print_header() {
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}  $1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠ $1${NC}"
}

print_info() {
    echo -e "${BLUE}ℹ $1${NC}"
}

show_help() {
    cat << EOF
${CYAN}VoiceFlow Development Tools${NC}

${YELLOW}Usage:${NC}
  ./Scripts/dev-tools.sh [command] [options]

${YELLOW}Commands:${NC}

  ${GREEN}Build & Test:${NC}
    build               Fast incremental debug build
    build-release       Optimized release build
    clean               Clean all build artifacts
    test                Run full test suite
    test-unit           Run only unit tests
    test-perf           Run performance benchmarks
    test-ui             Run UI tests

  ${GREEN}Code Quality:${NC}
    concurrency         Verify Swift 6 strict concurrency compliance
    typecheck           Explicit type checking
    warnings            Build with warnings as errors
    coverage            Generate test coverage report
    coverage-html       Generate HTML coverage report

  ${GREEN}Performance:${NC}
    benchmark           Run comprehensive performance suite
    buffer-stats        Analyze AudioBufferPool efficiency
    memory-profile      Profile memory usage
    profile             Quick performance profile

  ${GREEN}Analysis:${NC}
    analyze             Run static analysis
    dependencies        Show dependency tree
    size                Analyze binary size
    actors              Analyze actor isolation points

  ${GREEN}Utilities:${NC}
    format              Format code (requires SwiftFormat)
    lint                Run SwiftLint (requires SwiftLint)
    docs                Generate documentation
    help                Show this help message

${YELLOW}Examples:${NC}
  ./Scripts/dev-tools.sh build
  ./Scripts/dev-tools.sh test-perf
  ./Scripts/dev-tools.sh coverage-html
  ./Scripts/dev-tools.sh benchmark

EOF
}

# Build Commands
cmd_build() {
    print_header "Building VoiceFlow (Debug)"
    swift build
    print_success "Build completed"
}

cmd_build_release() {
    print_header "Building VoiceFlow (Release)"
    swift build --configuration release
    print_success "Release build completed"
}

cmd_clean() {
    print_header "Cleaning Build Artifacts"
    swift package clean
    rm -rf .build
    print_success "Clean completed"
}

# Test Commands
cmd_test() {
    print_header "Running Full Test Suite"
    swift test
    print_success "All tests passed"
}

cmd_test_unit() {
    print_header "Running Unit Tests"
    swift test --filter VoiceFlowTests
    print_success "Unit tests passed"
}

cmd_test_perf() {
    print_header "Running Performance Tests"
    swift test --filter PerformanceTests
    print_success "Performance tests completed"
}

cmd_test_ui() {
    print_header "Running UI Tests"
    swift test --filter VoiceFlowUITests
    print_success "UI tests passed"
}

# Code Quality Commands
cmd_concurrency() {
    print_header "Verifying Swift 6 Strict Concurrency"
    print_info "Checking actor isolation and data race safety..."
    swift build -Xswiftc -strict-concurrency=complete -Xswiftc -warn-concurrency
    print_success "Concurrency checks passed"
}

cmd_typecheck() {
    print_header "Type Checking"
    swift build -Xswiftc -typecheck
    print_success "Type check completed"
}

cmd_warnings() {
    print_header "Building with Warnings as Errors"
    swift build -Xswiftc -warnings-as-errors
    print_success "Build completed with no warnings"
}

cmd_coverage() {
    print_header "Generating Test Coverage Report"
    swift test --enable-code-coverage

    # Find the test binary
    TEST_BINARY=$(find .build -name "VoiceFlowPackageTests.xctest" 2>/dev/null | head -1)

    if [ -z "$TEST_BINARY" ]; then
        print_warning "Could not find test binary, trying alternate path..."
        TEST_BINARY=".build/debug/VoiceFlowPackageTests.xctest/Contents/MacOS/VoiceFlowPackageTests"
    fi

    if [ -f "$TEST_BINARY" ]; then
        echo ""
        print_info "Coverage Summary:"
        xcrun llvm-cov report "$TEST_BINARY" -instr-profile=.build/debug/codecov/default.profdata
        print_success "Coverage report generated"
    else
        print_error "Test binary not found. Run 'swift test' first."
        exit 1
    fi
}

cmd_coverage_html() {
    print_header "Generating HTML Coverage Report"
    swift test --enable-code-coverage

    TEST_BINARY=$(find .build -name "VoiceFlowPackageTests.xctest" 2>/dev/null | head -1)

    if [ -z "$TEST_BINARY" ]; then
        TEST_BINARY=".build/debug/VoiceFlowPackageTests.xctest/Contents/MacOS/VoiceFlowPackageTests"
    fi

    if [ -f "$TEST_BINARY" ]; then
        mkdir -p coverage-report
        xcrun llvm-cov show "$TEST_BINARY" \
            -instr-profile=.build/debug/codecov/default.profdata \
            -format=html \
            -output-dir=coverage-report \
            -use-color
        print_success "HTML coverage report generated in: coverage-report/"
        print_info "Open coverage-report/index.html in your browser"
    else
        print_error "Test binary not found"
        exit 1
    fi
}

# Performance Commands
cmd_benchmark() {
    print_header "Running Performance Benchmarks"
    print_info "Testing TranscriptionEngine performance..."
    swift test --filter PerformanceTests

    print_info "Analyzing AudioBufferPool..."
    cmd_buffer_stats

    print_success "Benchmark suite completed"
}

cmd_buffer_stats() {
    print_header "AudioBufferPool Statistics"
    print_info "Analyzing buffer efficiency and memory usage..."

    # Run tests that exercise the buffer pool
    swift test --filter "AudioBufferPoolTests" 2>&1 | grep -E "(buffer|pool|allocation|efficiency)" || true

    print_info "Buffer pool metrics available in test output"
}

cmd_memory_profile() {
    print_header "Memory Profiling"
    print_warning "This requires Xcode Instruments"
    print_info "Use: Xcode -> Open Developer Tool -> Instruments"
    print_info "Select 'Allocations' or 'Leaks' template"
}

cmd_profile() {
    print_header "Quick Performance Profile"
    time swift test --filter PerformanceTests
    print_success "Profile completed"
}

# Analysis Commands
cmd_analyze() {
    print_header "Static Analysis"
    swift build --analyze
    print_success "Static analysis completed"
}

cmd_dependencies() {
    print_header "Dependency Tree"
    swift package show-dependencies
}

cmd_size() {
    print_header "Binary Size Analysis"
    swift build --configuration release
    BINARY=".build/release/VoiceFlow"
    if [ -f "$BINARY" ]; then
        ls -lh "$BINARY"
        size "$BINARY"
    else
        print_error "Release binary not found. Build first."
        exit 1
    fi
}

cmd_actors() {
    print_header "Actor Isolation Analysis"
    print_info "Searching for @MainActor and actor definitions..."
    echo ""

    find VoiceFlow -name "*.swift" -exec grep -l "@MainActor\|^actor " {} \; | while read file; do
        echo -e "${GREEN}$file${NC}"
        grep -n "@MainActor\|^actor " "$file" | sed 's/^/  /'
    done

    echo ""
    print_success "Actor analysis completed"
}

# Utility Commands
cmd_format() {
    if command -v swiftformat &> /dev/null; then
        print_header "Formatting Code"
        swiftformat .
        print_success "Code formatted"
    else
        print_error "SwiftFormat not installed"
        print_info "Install with: brew install swiftformat"
        exit 1
    fi
}

cmd_lint() {
    if command -v swiftlint &> /dev/null; then
        print_header "Running SwiftLint"
        swiftlint
        print_success "Linting completed"
    else
        print_error "SwiftLint not installed"
        print_info "Install with: brew install swiftlint"
        exit 1
    fi
}

cmd_docs() {
    print_header "Generating Documentation"
    swift package generate-documentation
    print_success "Documentation generated"
}

# Main command dispatcher
main() {
    if [ $# -eq 0 ]; then
        show_help
        exit 0
    fi

    case "$1" in
        # Build & Test
        build)              cmd_build ;;
        build-release)      cmd_build_release ;;
        clean)              cmd_clean ;;
        test)               cmd_test ;;
        test-unit)          cmd_test_unit ;;
        test-perf)          cmd_test_perf ;;
        test-ui)            cmd_test_ui ;;

        # Code Quality
        concurrency)        cmd_concurrency ;;
        typecheck)          cmd_typecheck ;;
        warnings)           cmd_warnings ;;
        coverage)           cmd_coverage ;;
        coverage-html)      cmd_coverage_html ;;

        # Performance
        benchmark)          cmd_benchmark ;;
        buffer-stats)       cmd_buffer_stats ;;
        memory-profile)     cmd_memory_profile ;;
        profile)            cmd_profile ;;

        # Analysis
        analyze)            cmd_analyze ;;
        dependencies)       cmd_dependencies ;;
        size)               cmd_size ;;
        actors)             cmd_actors ;;

        # Utilities
        format)             cmd_format ;;
        lint)               cmd_lint ;;
        docs)               cmd_docs ;;
        help|--help|-h)     show_help ;;

        *)
            print_error "Unknown command: $1"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

main "$@"
