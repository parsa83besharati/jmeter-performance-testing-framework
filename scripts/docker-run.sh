#!/bin/bash

echo "========================================"
echo "  JMeter Docker Runner"
echo "========================================"
echo

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEST_PLAN="${1:-smoke}"

echo "Running JMeter test in Docker..."
echo "Test Plan: $TEST_PLAN"
echo

docker-compose -f "$PROJECT_DIR/docker-compose.yml" run --rm jmeter \
    /opt/apache-jmeter/bin/jmeter -n \
    -t "/jmeter/jmeter/test-plans/${TEST_PLAN}-test.jmx" \
    -l "/jmeter/jmeter/results/jtl/${TEST_PLAN}-docker-test.jtl" \
    -q "/jmeter/jmeter/config/test-config.properties" \
    -p "/jmeter/jmeter/config/user.properties"

echo
echo "Generating HTML report..."

docker-compose -f "$PROJECT_DIR/docker-compose.yml" run --rm jmeter \
    /opt/apache-jmeter/bin/jmeter --generate-html \
    "/jmeter/jmeter/results/html/${TEST_PLAN}-docker-report" \
    --input-jtl "/jmeter/jmeter/results/jtl/${TEST_PLAN}-docker-test.jtl"

echo
echo "Test completed. Results in: $PROJECT_DIR/jmeter/results"
