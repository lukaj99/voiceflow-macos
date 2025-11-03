#!/bin/bash
# VoiceFlow Dependency Analysis Script

set -e

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_DIR="VoiceFlow/Documentation/Reports"
REPORT_FILE="${REPORT_DIR}/dependency-analysis-${TIMESTAMP}.txt"

echo "======================================"
echo "VoiceFlow Dependency Analysis"
echo "======================================"
echo "Timestamp: $(date)"
echo "Report: ${REPORT_FILE}"
echo ""

# Create report header
cat > "${REPORT_FILE}" << EOF
VoiceFlow Dependency Analysis Report
Generated: $(date)
================================================================================

EOF

# Swift Package Dependencies
echo "Swift Package Dependencies" >> "${REPORT_FILE}"
echo "==========================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

if [ -f "Package.swift" ]; then
    echo "External Dependencies:" >> "${REPORT_FILE}"

    # Extract package dependencies
    grep -A 50 "dependencies:" Package.swift | grep ".package(" | sed 's/^[ \t]*/  /' >> "${REPORT_FILE}" || echo "  None found" >> "${REPORT_FILE}"

    echo "" >> "${REPORT_FILE}"

    # Count dependencies
    EXTERNAL_DEPS=$(grep -A 50 "dependencies:" Package.swift | grep -c ".package(" || echo "0")
    echo "Total external dependencies: ${EXTERNAL_DEPS}" >> "${REPORT_FILE}"
else
    echo "No Package.swift found" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"

# Analyze package dependencies from resolved file
if [ -f "Package.resolved" ]; then
    echo "Resolved Package Versions:" >> "${REPORT_FILE}"
    echo "" >> "${REPORT_FILE}"

    # Extract package info from Package.resolved (Swift 5.9+ format)
    if command -v jq >/dev/null 2>&1; then
        jq -r '.pins[] | "  \(.identity): \(.state.version // .state.branch // .state.revision[0:8])"' Package.resolved >> "${REPORT_FILE}" 2>/dev/null || {
            # Fallback for older format
            grep -A 3 '"package":' Package.resolved | grep '"identity"\|"version"\|"branch"' | sed 's/^[ \t]*/  /' >> "${REPORT_FILE}"
        }
    else
        grep -A 3 '"package":' Package.resolved | grep '"identity"\|"version"\|"branch"' | sed 's/^[ \t]*/  /' >> "${REPORT_FILE}"
    fi
fi

echo "" >> "${REPORT_FILE}"

# Internal Module Dependencies
echo "Internal Module Dependencies" >> "${REPORT_FILE}"
echo "============================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Analyze import statements
echo "Import Statement Analysis:" >> "${REPORT_FILE}"
TEMP_IMPORTS=$(mktemp)

find VoiceFlow -name "*.swift" -type f -exec grep "^import " {} + | \
    sed 's/^.*import //' | \
    sort | uniq -c | sort -rn > "$TEMP_IMPORTS"

echo "" >> "${REPORT_FILE}"
echo "Top 20 Most Used Imports:" >> "${REPORT_FILE}"
head -20 "$TEMP_IMPORTS" | awk '{printf "  %4d  %s\n", $1, $2}' >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Calculate import statistics
TOTAL_IMPORTS=$(awk '{sum += $1} END {print sum}' "$TEMP_IMPORTS")
UNIQUE_IMPORTS=$(wc -l < "$TEMP_IMPORTS" | tr -d ' ')

echo "Import Statistics:" >> "${REPORT_FILE}"
echo "  Total import statements: ${TOTAL_IMPORTS}" >> "${REPORT_FILE}"
echo "  Unique modules imported: ${UNIQUE_IMPORTS}" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Framework Dependencies
echo "Framework Dependencies:" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Categorize imports
SYSTEM_FRAMEWORKS=$(grep -E "^import (Foundation|AppKit|SwiftUI|Combine|CoreData|AVFoundation|Speech|UniformTypeIdentifiers)" "$TEMP_IMPORTS" | wc -l | tr -d ' ')
EXTERNAL_PACKAGES=$(grep -vE "^import (Foundation|AppKit|SwiftUI|Combine|CoreData|AVFoundation|Speech|UniformTypeIdentifiers|@testable)" "$TEMP_IMPORTS" | wc -l | tr -d ' ')

echo "  System frameworks: ${SYSTEM_FRAMEWORKS}" >> "${REPORT_FILE}"
echo "  External packages: ${EXTERNAL_PACKAGES}" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Dependency Graph Generation
echo "Module Dependency Graph" >> "${REPORT_FILE}"
echo "=======================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Analyze which modules depend on which
echo "Core Module Dependencies:" >> "${REPORT_FILE}"

for dir in VoiceFlow/Core/* VoiceFlow/Features/* VoiceFlow/Services/*; do
    if [ -d "$dir" ]; then
        module_name=$(basename "$dir")

        # Find all imports in this module
        module_imports=$(find "$dir" -name "*.swift" -type f -exec grep "^import " {} + 2>/dev/null | \
            sed 's/^.*import //' | sort -u | grep -v "Foundation\|AppKit\|SwiftUI\|Combine\|@testable" || true)

        if [ -n "$module_imports" ]; then
            echo "  ${module_name}:" >> "${REPORT_FILE}"
            echo "$module_imports" | sed 's/^/    → /' >> "${REPORT_FILE}"
        fi
    fi
done

echo "" >> "${REPORT_FILE}"

# Circular Dependency Detection
echo "Circular Dependency Detection" >> "${REPORT_FILE}"
echo "=============================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Simple circular dependency check
TEMP_DEPS=$(mktemp)

for dir in VoiceFlow/Core/* VoiceFlow/Features/* VoiceFlow/Services/*; do
    if [ -d "$dir" ]; then
        module_name=$(basename "$dir")
        find "$dir" -name "*.swift" -type f -exec grep "^import " {} + 2>/dev/null | \
            sed 's/^.*import //' | sort -u | while read imp; do
                echo "${module_name}:${imp}"
            done >> "$TEMP_DEPS"
    fi
done

# Check for potential circular dependencies
echo "Checking for circular dependencies..." >> "${REPORT_FILE}"
CIRCULAR_FOUND=false

while IFS=: read module import; do
    # Check if imported module imports back
    if grep -q "^${import}:${module}$" "$TEMP_DEPS" 2>/dev/null; then
        echo "  ⚠ Potential circular dependency: ${module} ↔ ${import}" >> "${REPORT_FILE}"
        CIRCULAR_FOUND=true
    fi
done < "$TEMP_DEPS"

if [ "$CIRCULAR_FOUND" = false ]; then
    echo "  ✓ No circular dependencies detected" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"

# Unused Dependencies
echo "Unused Dependency Detection" >> "${REPORT_FILE}"
echo "===========================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

if [ -f "Package.swift" ]; then
    # Extract declared dependencies
    DECLARED_DEPS=$(grep ".package(" Package.swift | sed 's/.*name: "\([^"]*\)".*/\1/' || true)

    echo "Checking for unused external dependencies..." >> "${REPORT_FILE}"

    UNUSED_FOUND=false
    for dep in $DECLARED_DEPS; do
        # Check if dependency is actually imported anywhere
        if ! grep -r "^import ${dep}" VoiceFlow --include="*.swift" > /dev/null 2>&1; then
            echo "  ⚠ Potentially unused: ${dep}" >> "${REPORT_FILE}"
            UNUSED_FOUND=true
        fi
    done

    if [ "$UNUSED_FOUND" = false ]; then
        echo "  ✓ All declared dependencies are in use" >> "${REPORT_FILE}"
    fi
else
    echo "  No Package.swift found for analysis" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"

# Dependency Health Metrics
echo "Dependency Health Metrics" >> "${REPORT_FILE}"
echo "=========================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Calculate coupling metrics
TOTAL_MODULES=$(find VoiceFlow/Core VoiceFlow/Features VoiceFlow/Services -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
TOTAL_MODULE_DEPS=$(wc -l < "$TEMP_DEPS" | tr -d ' ')

if [ $TOTAL_MODULES -gt 0 ]; then
    AVG_DEPS_PER_MODULE=$(awk "BEGIN {printf \"%.2f\", ${TOTAL_MODULE_DEPS}/${TOTAL_MODULES}}")
    echo "  Total internal modules: ${TOTAL_MODULES}" >> "${REPORT_FILE}"
    echo "  Total module dependencies: ${TOTAL_MODULE_DEPS}" >> "${REPORT_FILE}"
    echo "  Average dependencies per module: ${AVG_DEPS_PER_MODULE}" >> "${REPORT_FILE}"
fi

echo "" >> "${REPORT_FILE}"

# Recommendations
echo "Recommendations:" >> "${REPORT_FILE}"
echo "  1. Minimize external dependencies to reduce maintenance burden" >> "${REPORT_FILE}"
echo "  2. Break circular dependencies by introducing abstractions" >> "${REPORT_FILE}"
echo "  3. Remove unused dependencies to reduce build times" >> "${REPORT_FILE}"
echo "  4. Keep modules loosely coupled for better maintainability" >> "${REPORT_FILE}"
echo "  5. Consider dependency injection for testability" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"
echo "================================================================================" >> "${REPORT_FILE}"
echo "Report generated: $(date)" >> "${REPORT_FILE}"

# Cleanup
rm -f "$TEMP_IMPORTS" "$TEMP_DEPS"

echo ""
echo "Dependency analysis complete!"
echo "Report saved to: ${REPORT_FILE}"
