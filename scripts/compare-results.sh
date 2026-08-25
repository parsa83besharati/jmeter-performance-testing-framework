#!/bin/bash

echo "========================================"
echo "  JTL Result Comparator"
echo "========================================"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JTL_BASELINE="${1:-}"
JTL_CURRENT="${2:-}"

if [ -z "$JTL_BASELINE" ] || [ -z "$JTL_CURRENT" ]; then
    echo "Usage: ./compare-results.sh [baseline-jtl] [current-jtl]"
    echo
    echo "Compares two JTL result files and shows differences in:"
    echo "  - Total requests"
    echo "  - Error rate"
    echo "  - Average response time"
    echo "  - Max response time"
    echo "  - Throughput"
    echo
    echo "Example:"
    echo "  ./compare-results.sh baseline.jtl current.jtl"
    exit 1
fi

if [ ! -f "$JTL_BASELINE" ]; then
    echo "ERROR: Baseline JTL file not found: $JTL_BASELINE"
    exit 1
fi

if [ ! -f "$JTL_CURRENT" ]; then
    echo "ERROR: Current JTL file not found: $JTL_CURRENT"
    exit 1
fi

echo "Baseline: $JTL_BASELINE"
echo "Current:  $JTL_CURRENT"

analyze_jtl() {
    local file=$1
    tail -n +2 "$file" | awk -F',' '
    {
        total++
        if ($2 == "false") errors++
        sum_time += $3
        if ($3 > max_time) max_time = $3
        if (min_time == 0 || $3 < min_time) min_time = $3
        if (NR == 1) first_ts = $1
        last_ts = $1
    }
    END {
        error_rate = (total > 0) ? (errors * 100 / total) : 0
        avg_time = (total > 0) ? (sum_time / total) : 0
        duration = (last_ts - first_ts) / 1000
        throughput = (duration > 0) ? (total / duration) : 0
        printf "%d %.1f %.0f %d %d %.2f", total, error_rate, avg_time, max_time, min_time, throughput
    }'
}

echo
echo "=== BASELINE RESULTS ==="
read B_TOTAL B_ERROR_RATE B_AVG_TIME B_MAX_TIME B_MIN_TIME B_THROUGHPUT <<< $(analyze_jtl "$JTL_BASELINE")
echo "Total Requests:  $B_TOTAL"
echo "Error Rate:      ${B_ERROR_RATE}%"
echo "Avg Response:    ${B_AVG_TIME}ms"
echo "Max Response:    ${B_MAX_TIME}ms"
echo "Min Response:    ${B_MIN_TIME}ms"
echo "Throughput:      ${B_THROUGHPUT} req/s"

echo
echo "=== CURRENT RESULTS ==="
read C_TOTAL C_ERROR_RATE C_AVG_TIME C_MAX_TIME C_MIN_TIME C_THROUGHPUT <<< $(analyze_jtl "$JTL_CURRENT")
echo "Total Requests:  $C_TOTAL"
echo "Error Rate:      ${C_ERROR_RATE}%"
echo "Avg Response:    ${C_AVG_TIME}ms"
echo "Max Response:    ${C_MAX_TIME}ms"
echo "Min Response:    ${C_MIN_TIME}ms"
echo "Throughput:      ${C_THROUGHPUT} req/s"

echo
echo "=== COMPARISON ==="

DIFF_ERRORS=$(echo "$C_ERROR_RATE - $B_ERROR_RATE" | bc)
DIFF_AVG=$(echo "$C_AVG_TIME - $B_AVG_TIME" | bc | cut -d. -f1)
DIFF_MAX=$((C_MAX_TIME - B_MAX_TIME))
DIFF_THROUGHPUT=$(echo "$C_THROUGHPUT - $B_THROUGHPUT" | bc)

printf "Error Rate Delta:  %+.1f%%\n" "$DIFF_ERRORS"
printf "Avg Time Delta:    %+.0fms\n" "$DIFF_AVG"
echo "Max Time Delta:    ${DIFF_MAX}ms"
printf "Throughput Delta:  %+.2f req/s\n" "$DIFF_THROUGHPUT"

echo
WARNINGS=0

if (( $(echo "$DIFF_ERRORS > 0" | bc -l) )); then
    echo "WARNING: Error rate increased by ${DIFF_ERRORS}%"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$DIFF_AVG" -gt 100 ] 2>/dev/null; then
    echo "WARNING: Average response time increased by ${DIFF_AVG}ms"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$DIFF_MAX" -gt 500 ]; then
    echo "WARNING: Max response time increased by ${DIFF_MAX}ms"
    WARNINGS=$((WARNINGS + 1))
fi

if [ "$WARNINGS" -eq 0 ]; then
    echo "OK - No significant regressions detected"
fi
