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

for test_file in test-plans/*.jmx; do
    echo "Validating: $test_file"
    "$JMETER_BIN/jmeter" -n -t "$test_file" \
        -l "results/jtl/validation-$(basename "$test_file" .jmx).jtl" \
        -j "results/jtl/validation-$(basename "$test_file" .jmx).log" \
        -Jloop=0 2>/dev/null
    
    if [ $? -eq 0 ]; then
        echo "  [PASS] $test_file"
    else
        echo "  [FAIL] $test_file"
    fi
    
    rm -f "results/jtl/validation-$(basename "$test_file" .jmx).jtl" 2>/dev/null
    echo
done

echo "Validation complete."
