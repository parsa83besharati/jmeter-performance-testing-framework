#!/bin/bash

echo "========================================"
echo "  JMeter Performance Test Runner"
echo "========================================"
echo

if [ -z "$JMETER_HOME" ]; then
    echo "ERROR: JMETER_HOME environment variable is not set"
    echo "Please set JMETER_HOME to your JMeter installation directory"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JMETER_BIN="$JMETER_HOME/bin"
TEST_PLAN="${1:-}"
PROPERTIES_FILE="${2:-config/test-config.properties}"

if [ -z "$TEST_PLAN" ]; then
    echo "Usage: ./run-test.sh [test-plan] [properties-file]"
    echo
    echo "Available test plans:"
    echo "  smoke   - Smoke test (quick validation)"
    echo "  load    - Load test (normal expected load)"
    echo "  stress  - Stress test (beyond normal load)"
    echo "  spike   - Spike test (sudden surge)"
    echo "  all     - Run all tests sequentially"
    echo
    echo "Example:"
    echo "  ./run-test.sh smoke"
    echo "  ./run-test.sh load test-config.properties"
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")

mkdir -p "$PROJECT_DIR/jmeter/results/jtl"
mkdir -p "$PROJECT_DIR/jmeter/results/html"

cd "$PROJECT_DIR/jmeter"

run_test() {
    local test_type=$1
    local jtl_file="results/jtl/${test_type}-test-${TIMESTAMP}.jtl"
    local html_dir="results/html/${test_type}-test-${TIMESTAMP}"
    
    echo
    echo "Running $test_type test..."
    echo "Results will be saved to: $jtl_file"
    
    "$JMETER_BIN/jmeter" -n -t "test-plans/${test_type}-test.jmx" \
        -l "$jtl_file" \
        -q "$PROPERTIES_FILE" \
        -p "config/user.properties" \
        -j "results/jtl/${test_type}-test-${TIMESTAMP}.log"
    
    echo "Generating HTML report..."
    "$JMETER_BIN/jmeter" --generate-html "$html_dir" --input-jtl "$jtl_file"
    
    echo "$test_type test completed. HTML report: $html_dir"
}

case "$TEST_PLAN" in
    all)
        run_test "smoke"
        run_test "load"
        run_test "stress"
        run_test "spike"
        ;;
    smoke|load|stress|spike)
        run_test "$TEST_PLAN"
        ;;
    *)
        echo "Unknown test plan: $TEST_PLAN"
        exit 1
        ;;
esac

echo
echo "========================================"
echo "  Test Execution Completed"
echo "========================================"
echo "Results saved to: $PROJECT_DIR/jmeter/results"
