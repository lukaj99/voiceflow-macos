#!/bin/bash
# VoiceFlow Complexity Analysis Script

set -e

TIMESTAMP=$(date +"%Y%m%d-%H%M%S")
REPORT_DIR="VoiceFlow/Documentation/Reports"
REPORT_FILE="${REPORT_DIR}/complexity-report-${TIMESTAMP}.txt"

echo "======================================"
echo "VoiceFlow Complexity Analysis"
echo "======================================"
echo "Timestamp: $(date)"
echo "Report: ${REPORT_FILE}"
echo ""

# Create report header
cat > "${REPORT_FILE}" << EOF
VoiceFlow Complexity Report
Generated: $(date)
================================================================================

EOF

# Cyclomatic Complexity Analysis
echo "Cyclomatic Complexity Analysis" >> "${REPORT_FILE}"
echo "==============================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Function to calculate complexity for a file
analyze_file_complexity() {
    local file=$1
    local filename=$(basename "$file")

    # Count decision points: if, else if, while, for, case, guard, catch, &&, ||
    local if_count=$(grep -o "\bif\b" "$file" | wc -l | tr -d ' ')
    local while_count=$(grep -o "\bwhile\b" "$file" | wc -l | tr -d ' ')
    local for_count=$(grep -o "\bfor\b" "$file" | wc -l | tr -d ' ')
    local case_count=$(grep -o "\bcase\b" "$file" | wc -l | tr -d ' ')
    local guard_count=$(grep -o "\bguard\b" "$file" | wc -l | tr -d ' ')
    local catch_count=$(grep -o "\bcatch\b" "$file" | wc -l | tr -d ' ')
    local and_count=$(grep -o "&&" "$file" | wc -l | tr -d ' ')
    local or_count=$(grep -o "||" "$file" | wc -l | tr -d ' ')

    # Calculate total complexity (sum of decision points + 1)
    local complexity=$((if_count + while_count + for_count + case_count + guard_count + catch_count + and_count + or_count + 1))

    # Count functions in file
    local func_count=$(grep -o "\bfunc\b" "$file" | wc -l | tr -d ' ')

    # Calculate average complexity per function
    local avg_complexity=0
    if [ $func_count -gt 0 ]; then
        avg_complexity=$((complexity / func_count))
    fi

    echo "${file}|${complexity}|${func_count}|${avg_complexity}"
}

# Analyze all Swift files
echo "Analyzing Swift files for complexity..."

# Temporary file for results
TEMP_FILE=$(mktemp)

# Find all Swift files and analyze them
find VoiceFlow -name "*.swift" -type f | while read file; do
    analyze_file_complexity "$file"
done > "$TEMP_FILE"

# Sort by complexity (descending) and display top 20
echo "Top 20 Most Complex Files:" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"
printf "%-60s %12s %10s %10s\n" "File" "Complexity" "Functions" "Avg/Func" >> "${REPORT_FILE}"
echo "--------------------------------------------------------------------------------" >> "${REPORT_FILE}"

sort -t'|' -k2 -rn "$TEMP_FILE" | head -20 | while IFS='|' read file complexity funcs avg; do
    filename=$(echo "$file" | sed 's/VoiceFlow\///')
    printf "%-60s %12s %10s %10s\n" "$filename" "$complexity" "$funcs" "$avg" >> "${REPORT_FILE}"
done

echo "" >> "${REPORT_FILE}"

# Calculate statistics
TOTAL_FILES=$(wc -l < "$TEMP_FILE" | tr -d ' ')
TOTAL_COMPLEXITY=$(awk -F'|' '{sum += $2} END {print sum}' "$TEMP_FILE")
TOTAL_FUNCTIONS=$(awk -F'|' '{sum += $3} END {print sum}' "$TEMP_FILE")
AVG_FILE_COMPLEXITY=$(awk -F'|' '{sum += $2} END {printf "%.2f", sum/NR}' "$TEMP_FILE")
AVG_FUNC_COMPLEXITY=$(awk -F'|' '{sum += $2; funcs += $3} END {if(funcs>0) printf "%.2f", sum/funcs; else print "0"}' "$TEMP_FILE")

echo "Overall Statistics:" >> "${REPORT_FILE}"
echo "  Total files analyzed: ${TOTAL_FILES}" >> "${REPORT_FILE}"
echo "  Total complexity score: ${TOTAL_COMPLEXITY}" >> "${REPORT_FILE}"
echo "  Total functions: ${TOTAL_FUNCTIONS}" >> "${REPORT_FILE}"
echo "  Average complexity per file: ${AVG_FILE_COMPLEXITY}" >> "${REPORT_FILE}"
echo "  Average complexity per function: ${AVG_FUNC_COMPLEXITY}" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Files exceeding complexity threshold
THRESHOLD=15
echo "Files Exceeding Complexity Threshold (>${THRESHOLD}):" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

HIGH_COMPLEXITY_COUNT=$(awk -F'|' -v threshold=$THRESHOLD '$4 > threshold {count++} END {print count+0}' "$TEMP_FILE")
echo "  Files with high average complexity: ${HIGH_COMPLEXITY_COUNT}" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

awk -F'|' -v threshold=$THRESHOLD '$4 > threshold' "$TEMP_FILE" | sort -t'|' -k4 -rn | while IFS='|' read file complexity funcs avg; do
    filename=$(echo "$file" | sed 's/VoiceFlow\///')
    echo "  - ${filename} (avg: ${avg})" >> "${REPORT_FILE}"
done

echo "" >> "${REPORT_FILE}"

# Code Smells Detection
echo "Code Smells Detection" >> "${REPORT_FILE}"
echo "=====================" >> "${REPORT_FILE}"
echo "" >> "${REPORT_FILE}"

# Long methods (>50 lines)
echo "Long Methods (>50 lines):" >> "${REPORT_FILE}"
find VoiceFlow -name "*.swift" -type f -exec awk '
    /func / {
        in_func=1
        func_name=$0
        func_line=NR
        line_count=0
        brace_count=0
    }
    in_func {
        line_count++
        brace_count += gsub(/{/, "{")
        brace_count -= gsub(/}/, "}")
        if (brace_count == 0 && line_count > 1) {
            if (line_count > 50) {
                print FILENAME ":" func_line " - " func_name " (" line_count " lines)"
            }
            in_func=0
        }
    }
' {} + | head -20 | sed 's/^/  /' >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Nested depth analysis
echo "Deep Nesting Analysis:" >> "${REPORT_FILE}"
find VoiceFlow -name "*.swift" -type f | while read file; do
    # Count maximum indentation depth
    max_depth=$(awk '{
        depth = (length($0) - length(ltrim($0))) / 4
        if (depth > max) max = depth
    }
    function ltrim(s) { sub(/^[ \t\r\n]+/, "", s); return s }
    END {print max}' "$file")

    if [ "$max_depth" -gt 6 ]; then
        filename=$(echo "$file" | sed 's/VoiceFlow\///')
        echo "  - ${filename} (max depth: ${max_depth})" >> "${REPORT_FILE}"
    fi
done | head -20

echo "" >> "${REPORT_FILE}"

# God Classes Detection (classes with too many methods)
echo "God Classes (>20 methods):" >> "${REPORT_FILE}"
find VoiceFlow -name "*.swift" -type f -exec awk '
    /^(class|struct|enum|actor) / {
        type=$0
        file=FILENAME
        method_count=0
    }
    /func / && type != "" {
        method_count++
    }
    /^}/ && type != "" {
        if (method_count > 20) {
            print file " - " type " (" method_count " methods)"
        }
        type=""
    }
' {} + | sed 's/^/  /' >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"

# Refactoring Recommendations
echo "Refactoring Recommendations:" >> "${REPORT_FILE}"
echo "  1. Extract complex methods into smaller, focused functions" >> "${REPORT_FILE}"
echo "  2. Consider splitting large classes into separate concerns" >> "${REPORT_FILE}"
echo "  3. Reduce nesting depth using guard statements and early returns" >> "${REPORT_FILE}"
echo "  4. Apply SOLID principles to reduce coupling" >> "${REPORT_FILE}"

echo "" >> "${REPORT_FILE}"
echo "================================================================================" >> "${REPORT_FILE}"
echo "Report generated: $(date)" >> "${REPORT_FILE}"

# Cleanup
rm -f "$TEMP_FILE"

echo ""
echo "Complexity analysis complete!"
echo "Report saved to: ${REPORT_FILE}"
