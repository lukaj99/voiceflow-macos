#!/bin/bash
# VoiceFlow Code Quality Analysis Script

set -e

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_DIR="VoiceFlow/Documentation/Reports"
REPORT_FILE="${REPORT_DIR}/code-quality-report-${TIMESTAMP}.txt"

echo "======================================"
echo "VoiceFlow Code Quality Analysis"
echo "======================================"
echo "Timestamp: $(date)"
echo "Report: ${REPORT_FILE}"
echo ""

# Create report header
cat > "${REPORT_FILE}" << EOF
VoiceFlow Code Quality Report
Generated: $(date)
================================================================================

EOF

# Count Swift files
TOTAL_FILES=$(find VoiceFlow -name "*.swift" -type f | wc -l | tr -d ' ')
echo "Total Swift Files: ${TOTAL_FILES}"
echo "Total Swift Files: ${TOTAL_FILES}" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# SwiftLint Analysis
echo "Running SwiftLint analysis..."
if command -v swiftlint >/dev/null 2>&1; then
    echo "SwiftLint Analysis" >> "${REPORT_FILE}"
    echo "==================" >> "${REPORT_FILE}"

    # Run SwiftLint and capture output
    swiftlint lint --quiet 2>&1 | tee -a "${REPORT_FILE}" || true

    # Count warnings by severity
    WARNING_COUNT=$(swiftlint lint --quiet 2>&1 | grep -c "warning:" || echo "0")
    ERROR_COUNT=$(swiftlint lint --quiet 2>&1 | grep -c "error:" || echo "0")

    echo "" >> "${REPORT_FILE}"
    echo "Summary:" >> "${REPORT_FILE}"
    echo "  Errors: ${ERROR_COUNT}" >> "${REPORT_FILE}"
    echo "  Warnings: ${WARNING_COUNT}" >> "${REPORT_FILE}"
else
    echo "SwiftLint not installed. Skipping..." >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"

# Swift 6 Concurrency Compliance Check
echo "Swift 6 Concurrency Compliance" >> "${REPORT_FILE}"
echo "==============================" >> "${REPORT_FILE}"

# Check for @MainActor usage
MAINACTOR_COUNT=$(grep -r "@MainActor" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
echo "  @MainActor annotations: ${MAINACTOR_COUNT}" >> "${REPORT_FILE}"

# Check for async/await usage
ASYNC_COUNT=$(grep -r "async " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
AWAIT_COUNT=$(grep -r "await " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
echo "  async functions: ${ASYNC_COUNT}" >> "${REPORT_FILE}"
echo "  await calls: ${AWAIT_COUNT}" >> "${REPORT_FILE}"

# Check for old-style completion handlers
COMPLETION_COUNT=$(grep -r "completion:" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
echo "  Old-style completion handlers: ${COMPLETION_COUNT}" >> "${REPORT_FILE}"

# Check for Sendable conformance
SENDABLE_COUNT=$(grep -r "Sendable" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
echo "  Sendable references: ${SENDABLE_COUNT}" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Code Organization Analysis
echo "Code Organization" >> "${REPORT_FILE}"
echo "=================" >> "${REPORT_FILE}"

# Analyze file sizes
echo "Large Files (>500 lines):" >> "${REPORT_FILE}"
find VoiceFlow -name "*.swift" -type f -exec wc -l {} + | sort -rn | awk '$1 > 500 {print "  " $2 " (" $1 " lines)"}' >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Analyze protocol usage
PROTOCOL_COUNT=$(grep -r "protocol " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
CLASS_COUNT=$(grep -r "^class " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
STRUCT_COUNT=$(grep -r "^struct " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
ENUM_COUNT=$(grep -r "^enum " VoiceFlow --include="*.swift" | wc -l | tr -d ' ')

echo "Type Distribution:" >> "${REPORT_FILE}"
echo "  Protocols: ${PROTOCOL_COUNT}" >> "${REPORT_FILE}"
echo "  Classes: ${CLASS_COUNT}" >> "${REPORT_FILE}"
echo "  Structs: ${STRUCT_COUNT}" >> "${REPORT_FILE}"
echo "  Enums: ${ENUM_COUNT}" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Documentation Analysis
echo "Documentation Coverage" >> "${REPORT_FILE}"
echo "=====================" >> "${REPORT_FILE}"

# Count documentation comments
DOC_COMMENTS=$(grep -r "///" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')
REGULAR_COMMENTS=$(grep -r "^[[:space:]]*//" VoiceFlow --include="*.swift" | wc -l | tr -d ' ')

echo "  Documentation comments (///): ${DOC_COMMENTS}" >> "${REPORT_FILE}"
echo "  Regular comments (//): ${REGULAR_COMMENTS}" >> "${REPORT_FILE}"

# Calculate documentation ratio
TOTAL_LINES=$(find VoiceFlow -name "*.swift" -type f -exec wc -l {} + | tail -1 | awk '{print $1}')
DOC_RATIO=$(awk "BEGIN {printf \"%.2f\", (${DOC_COMMENTS}/${TOTAL_LINES})*100}")
echo "  Documentation ratio: ${DOC_RATIO}%" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Test Coverage Estimation
echo "Testing" >> "${REPORT_FILE}"
echo "=======" >> "${REPORT_FILE}"

TEST_FILES=$(find VoiceFlow -name "*Tests.swift" -o -name "*Test.swift" | wc -l | tr -d ' ')
echo "  Test files: ${TEST_FILES}" >> "${REPORT_FILE}"

# Count test methods
TEST_METHODS=$(grep -r "func test" VoiceFlow --include="*Tests.swift" --include="*Test.swift" | wc -l | tr -d ' ')
echo "  Test methods: ${TEST_METHODS}" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"
echo "================================================================================" >> "${REPORT_FILE}"
echo "Report generated: $(date)" >> "${REPORT_FILE}"

echo ""
echo "Code quality analysis complete!"
echo "Report saved to: ${REPORT_FILE}"
