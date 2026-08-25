#!/bin/bash

echo "========================================"
echo "  JMeter Test Validator"
echo "========================================"
echo

if [ -z "$JMETER_HOME" ]; then
    echo "ERROR: JMETER_HOME environment variable is not set"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JMETER_BIN="$JMETER_HOME/bin"

cd "$PROJECT_DIR/jmeter"

echo "Validating all test plans..."
echo

PASS_COUNT=0
FAIL_COUNT=0

for test_file in test-plans/*.jmx; do
    test_name=$(basename "$test_file" .jmx)
    echo "Validating: $test_file"
    "$JMETER_BIN/jmeter" -n -t "$test_file" \
        -l "results/jtl/validation-${test_name}.jtl" \
        -j "results/jtl/validation-${test_name}.log" \
        -Jloop=0 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "  [PASS] $test_file"
        PASS_COUNT=$((PASS_COUNT + 1))
    else
        echo "  [FAIL] $test_file"
        FAIL_COUNT=$((FAIL_COUNT + 1))
    fi
    
    rm -f "results/jtl/validation-${test_name}.jtl" 2>/dev/null
    rm -f "results/jtl/validation-${test_name}.log" 2>/dev/null
    echo
done

echo "========================================"
echo "  Validation Summary"
echo "========================================"
echo "  Passed: $PASS_COUNT"
echo "  Failed: $FAIL_COUNT"
echo

if [ "$FAIL_COUNT" -gt 0 ]; then
    echo "  RESULT: Some test plans failed validation"
    exit 1
else
    echo "  RESULT: All test plans passed validation"
    exit 0
fi
