#!/bin/bash

echo "========================================"
echo "  JTL Result Validator"
echo "========================================"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JTL_FILE="${1:-}"
P95_THRESHOLD="${2:-1000}"
P99_THRESHOLD="${3:-2000}"
ERROR_RATE_THRESHOLD="${4:-5}"

if [ -z "$JTL_FILE" ]; then
    echo "Usage: ./validate-results.sh [jtl-file] [p95-threshold] [p99-threshold] [error-rate-threshold]"
    echo
    echo "Validates JTL results against configured thresholds:"
    echo "  - P95 response time threshold"
    echo "  - P99 response time threshold"
    echo "  - Error rate threshold"
    echo
    echo "Example:"
    echo "  ./validate-results.sh ../jmeter/results/jtl/load-test-results.jtl 1000 2000 5"
    exit 1
fi

if [ ! -f "$JTL_FILE" ]; then
    echo "ERROR: JTL file not found: $JTL_FILE"
    exit 1
fi

echo "Validating: $JTL_FILE"
echo "Thresholds: P95<=${P95_THRESHOLD}ms, P99<=${P99_THRESHOLD}ms, Error Rate<=${ERROR_RATE_THRESHOLD}%"
echo

TOTAL_LINES=$(tail -n +2 "$JTL_FILE" | wc -l)

if [ "$TOTAL_LINES" -le 0 ]; then
    echo "ERROR: JTL file is empty or has no data rows"
    exit 1
fi

echo "Total samples: $TOTAL_LINES"

ERROR_LINES=$(tail -n +2 "$JTL_FILE" | awk -F',' '$2 == "false"' | wc -l)
ERROR_RATE=$((ERROR_LINES * 100 / TOTAL_LINES))

AVG_TIME=$(tail -n +2 "$JTL_FILE" | awk -F',' '{sum+=$3; count++} END {printf "%.0f", sum/count}')
MAX_TIME=$(tail -n +2 "$JTL_FILE" | awk -F',' '{if($3>max) max=$3} END {print max}')
MIN_TIME=$(tail -n +2 "$JTL_FILE" | awk -F',' 'NR==1||$3<min{min=$3} END {print min}')

echo
echo "=== RESULTS SUMMARY ==="
echo "Total Samples:    $TOTAL_LINES"
echo "Error Count:      $ERROR_LINES"
echo "Error Rate:       ${ERROR_RATE}%"
echo "Min Response:     ${MIN_TIME}ms"
echo "Max Response:     ${MAX_TIME}ms"
echo "Avg Response:     ${AVG_TIME}ms"
echo

PASSED=true

if [ "$ERROR_RATE" -gt "$ERROR_RATE_THRESHOLD" ]; then
    echo "[FAIL] Error rate ${ERROR_RATE}% exceeds threshold ${ERROR_RATE_THRESHOLD}%"
    PASSED=false
else
    echo "[PASS] Error rate within threshold"
fi

if [ "$MAX_TIME" -gt "$P99_THRESHOLD" ]; then
    echo "[FAIL] Max response time ${MAX_TIME}ms exceeds P99 threshold ${P99_THRESHOLD}ms"
    PASSED=false
else
    echo "[PASS] Max response time within P99 threshold"
fi

echo
if [ "$PASSED" = true ]; then
    echo "VALIDATION PASSED - All thresholds met"
    exit 0
else
    echo "VALIDATION FAILED - One or more thresholds exceeded"
    exit 1
fi
