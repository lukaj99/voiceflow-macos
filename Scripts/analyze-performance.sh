#!/bin/bash
# VoiceFlow Performance Analysis Script

set -e

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_DIR="VoiceFlow/Documentation/Reports"
REPORT_FILE="${REPORT_DIR}/performance-report-${TIMESTAMP}.txt"

echo "======================================"
echo "VoiceFlow Performance Analysis"
echo "======================================"
echo "Timestamp: $(date)"
echo "Report: ${REPORT_FILE}"
echo ""

# Create report header
cat > "${REPORT_FILE}" << EOF
VoiceFlow Performance Analysis Report
Generated: $(date)
================================================================================

EOF

# Build Time Analysis
echo "Build Time Analysis" >> "${REPORT_FILE}"
echo "===================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "Running clean build to measure build time..."
echo "This may take a few minutes..." >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Clean build artifacts
swift package clean 2>&1 > /dev/null || true

# Measure build time
echo "Measuring build time..." >> "${REPORT_FILE}"
BUILD_START=$(date +%s)

# Build with timing
swift build 2>&1 | tee /tmp/voiceflow-build.log | tail -10 >> "${REPORT_FILE}"

BUILD_END=$(date +%s)
BUILD_TIME=$((BUILD_END - BUILD_START))

echo "" >> "${REPORT_FILE}"
echo "Total Build Time: ${BUILD_TIME} seconds" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Compilation Time by File
echo "Compilation Time Analysis" >> "${REPORT_FILE}"
echo "=========================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Try to extract compilation times from Xcode build logs if available
if [ -d ~/Library/Developer/Xcode/DerivedData ]; then
    echo "Checking for Xcode build logs..." >> "${REPORT_FILE}"

    LATEST_LOG=$(find ~/Library/Developer/Xcode/DerivedData -name "*.xcactivitylog" -type f -mtime -1 2>/dev/null | head -1 || true)

    if [ -n "$LATEST_LOG" ]; then
        echo "Found recent build log" >> "${REPORT_FILE}"
        # Note: .xcactivitylog files are gzipped plists - would need gunzip + plist parsing
        # For now, we'll document this as a placeholder
    else
        echo "No recent Xcode build logs found" >> "${REPORT_FILE}"
    fi
else
    echo "Xcode DerivedData not found" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"

# Code Size Analysis
echo "Code Size Metrics" >> "${REPORT_FILE}"
echo "=================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Count lines of code
TOTAL_LINES=$(find VoiceFlow -name "*.swift" -type f -exec wc -l {} + | tail -1 | awk '{print $1}')
TOTAL_FILES=$(find VoiceFlow -name "*.swift" -type f | wc -l | tr -d ' ')
AVG_LINES_PER_FILE=$(awk "BEGIN {printf \"%.0f\", ${TOTAL_LINES}/${TOTAL_FILES}}")

echo "Source Code:" >> "${REPORT_FILE}"
echo "  Total lines of code: ${TOTAL_LINES}" >> "${REPORT_FILE}"
echo "  Total Swift files: ${TOTAL_FILES}" >> "${REPORT_FILE}"
echo "  Average lines per file: ${AVG_LINES_PER_FILE}" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Binary size (if built)
if [ -f ".build/debug/VoiceFlow" ] || [ -f ".build/release/VoiceFlow" ]; then
    echo "Binary Size:" >> "${REPORT_FILE}"

    if [ -f ".build/debug/VoiceFlow" ]; then
        DEBUG_SIZE=$(du -h ".build/debug/VoiceFlow" | awk '{print $1}')
        echo "  Debug build: ${DEBUG_SIZE}" >> "${REPORT_FILE}"
    fi

    if [ -f ".build/release/VoiceFlow" ]; then
        RELEASE_SIZE=$(du -h ".build/release/VoiceFlow" | awk '{print $1}')
        echo "  Release build: ${RELEASE_SIZE}" >> "${REPORT_FILE}"
    fi
else
    echo "Binary Size: Not available (no built binaries found)" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"

# Module Size Distribution
echo "Module Size Distribution" >> "${REPORT_FILE}"
echo "========================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

printf "%-40s %12s %10s\n" "Module" "Lines" "Files" >> "${REPORT_FILE}"
echo "--------------------------------------------------------------------------------" >> "${REPORT_FILE}"

for dir in VoiceFlow/Core/* VoiceFlow/Features/* VoiceFlow/Services/*; do
    if [ -d "$dir" ]; then
        module_name=$(basename "$dir")
        module_lines=$(find "$dir" -name "*.swift" -type f -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")
        module_files=$(find "$dir" -name "*.swift" -type f 2>/dev/null | wc -l | tr -d ' ')

        printf "%-40s %12s %10s\n" "$module_name" "$module_lines" "$module_files" >> "${REPORT_FILE}"
    fi
done

echo "" >> "${REPORT_FILE}"

# Performance Indicators
echo "Performance Indicators" >> "${REPORT_FILE}"
echo "======================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Check for potential performance issues
echo "Potential Performance Concerns:" >> "${REPORT_FILE}"

# Check for synchronous operations that could block
SYNC_BLOCKING=$(grep -r "\.sync\b" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
if [ $SYNC_BLOCKING -gt 0 ]; then
    echo "  ⚠ Synchronous blocking operations: ${SYNC_BLOCKING}" >> "${REPORT_FILE}"
fi

# Check for main thread operations
MAIN_THREAD_OPS=$(grep -r "DispatchQueue.main.sync" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
if [ $MAIN_THREAD_OPS -gt 0 ]; then
    echo "  ⚠ Synchronous main thread operations: ${MAIN_THREAD_OPS}" >> "${REPORT_FILE}"
fi

# Check for force unwrapping (can cause crashes)
FORCE_UNWRAP=$(grep -r "!" VoiceFlow --include="*.swift" | grep -v "!=" | grep -v "// " | wc -l | tr -d ' ')
echo "  Force unwraps (!): ${FORCE_UNWRAP} (review for safety)" >> "${REPORT_FILE}"

# Check for retain cycles (weak/unowned usage)
WEAK_REFS=$(grep -r "\bweak\b" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
UNOWNED_REFS=$(grep -r "\bunowned\b" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
echo "  Memory management:" >> "${REPORT_FILE}"
echo "    - weak references: ${WEAK_REFS}" >> "${REPORT_FILE}"
echo "    - unowned references: ${UNOWNED_REFS}" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Swift Concurrency Usage
echo "Swift Concurrency Adoption" >> "${REPORT_FILE}"
echo "==========================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

ASYNC_FUNCS=$(grep -r "async " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
AWAIT_CALLS=$(grep -r "await " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
TASK_USAGE=$(grep -r "\bTask\b" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
ACTOR_USAGE=$(grep -r "^actor " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
MAINACTOR_USAGE=$(grep -r "@MainActor" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')

echo "Modern Concurrency:" >> "${REPORT_FILE}"
echo "  async functions: ${ASYNC_FUNCS}" >> "${REPORT_FILE}"
echo "  await calls: ${AWAIT_CALLS}" >> "${REPORT_FILE}"
echo "  Task usage: ${TASK_USAGE}" >> "${REPORT_FILE}"
echo "  Actor definitions: ${ACTOR_USAGE}" >> "${REPORT_FILE}"
echo "  @MainActor annotations: ${MAINACTOR_USAGE}" >> "${REPORT_FILE}"

# Old-style concurrency
DISPATCH_ASYNC=$(grep -r "DispatchQueue.*\.async" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
COMPLETION_HANDLERS=$(grep -r "completion:" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')

echo "" >> "${REPORT_FILE}"
echo "Legacy Concurrency:" >> "${REPORT_FILE}"
echo "  DispatchQueue.async: ${DISPATCH_ASYNC}" >> "${REPORT_FILE}"
echo "  Completion handlers: ${COMPLETION_HANDLERS}" >> "${REPORT_FILE}"

if [ $COMPLETION_HANDLERS -gt 0 ] || [ $DISPATCH_ASYNC -gt 10 ]; then
    echo "" >> "${REPORT_FILE}"
    echo "  💡 Consider migrating to async/await for better performance" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"

# Test Performance
echo "Test Suite Performance" >> "${REPORT_FILE}"
echo "======================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "Running test suite to measure performance..." >> "${REPORT_FILE}"
TEST_START=$(date +%s)

swift test 2>&1 > /tmp/voiceflow-test.log || true

TEST_END=$(date +%s)
TEST_TIME=$((TEST_END - TEST_START))

# Extract test results
TEST_COUNT=$(grep "Test Case" /tmp/voiceflow-test.log 2>/dev/null | wc -l | tr -d ' ' || echo "0")
TEST_PASSED=$(grep "passed" /tmp/voiceflow-test.log 2>/dev/null | wc -l | tr -d ' ' || echo "0")
TEST_FAILED=$(grep "failed" /tmp/voiceflow-test.log 2>/dev/null | wc -l | tr -d ' ' || echo "0")

echo "Test Execution:" >> "${REPORT_FILE}"
echo "  Total tests: ${TEST_COUNT}" >> "${REPORT_FILE}"
echo "  Passed: ${TEST_PASSED}" >> "${REPORT_FILE}"
echo "  Failed: ${TEST_FAILED}" >> "${REPORT_FILE}"
echo "  Execution time: ${TEST_TIME} seconds" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Optimization Recommendations
echo "Optimization Recommendations" >> "${REPORT_FILE}"
echo "============================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

echo "Performance Optimization Priorities:" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Calculate optimization score
OPTIMIZATION_SCORE=100

if [ $SYNC_BLOCKING -gt 5 ]; then
    echo "  1. Reduce synchronous blocking operations (found: ${SYNC_BLOCKING})" >> "${REPORT_FILE}"
    OPTIMIZATION_SCORE=$((OPTIMIZATION_SCORE - 10))
fi

if [ $COMPLETION_HANDLERS -gt 20 ]; then
    echo "  2. Migrate completion handlers to async/await (found: ${COMPLETION_HANDLERS})" >> "${REPORT_FILE}"
    OPTIMIZATION_SCORE=$((OPTIMIZATION_SCORE - 10))
fi

if [ $AVG_LINES_PER_FILE -gt 400 ]; then
    echo "  3. Refactor large files (avg: ${AVG_LINES_PER_FILE} lines/file)" >> "${REPORT_FILE}"
    OPTIMIZATION_SCORE=$((OPTIMIZATION_SCORE - 5))
fi

if [ $BUILD_TIME -gt 60 ]; then
    echo "  4. Optimize build time (current: ${BUILD_TIME}s)" >> "${REPORT_FILE}"
    OPTIMIZATION_SCORE=$((OPTIMIZATION_SCORE - 15))
fi

if [ $FORCE_UNWRAP -gt 100 ]; then
    echo "  5. Review force unwraps for safety (found: ${FORCE_UNWRAP})" >> "${REPORT_FILE}"
    OPTIMIZATION_SCORE=$((OPTIMIZATION_SCORE - 5))
fi

if [ $OPTIMIZATION_SCORE -eq 100 ]; then
    echo "  ✓ No major performance concerns detected" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"
echo "Performance Optimization Score: ${OPTIMIZATION_SCORE}/100" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"
echo "General Recommendations:" >> "${REPORT_FILE}"
echo "  • Use instruments to profile runtime performance" >> "${REPORT_FILE}"
echo "  • Enable whole module optimization for release builds" >> "${REPORT_FILE}"
echo "  • Consider lazy initialization for expensive resources" >> "${REPORT_FILE}"
echo "  • Implement proper caching strategies" >> "${REPORT_FILE}"
echo "  • Profile memory usage with Instruments" >> "${REPORT_FILE}"
echo "  • Use Swift 6 concurrency features for better performance" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"
echo "================================================================================" >> "${REPORT_FILE}"
echo "Report generated: $(date)" >> "${REPORT_FILE}"

echo ""
echo "Performance analysis complete!"
echo "Report saved to: ${REPORT_FILE}"
