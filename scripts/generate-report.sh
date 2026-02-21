#!/bin/bash

echo "========================================"
echo "  JMeter HTML Report Generator"
echo "========================================"
echo

if [ -z "$JMETER_HOME" ]; then
    echo "ERROR: JMETER_HOME environment variable is not set"
    exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
JMETER_BIN="$JMETER_HOME/bin"
JTL_FILE="${1:-}"

if [ -z "$JTL_FILE" ]; then
    echo "Usage: ./generate-report.sh [jtl-file]"
    echo
    echo "Example:"
    echo "  ./generate-report.sh ../jmeter/results/jtl/load-test-results.jtl"
    exit 1
fi

TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
JTL_NAME=$(basename "$JTL_FILE" .jtl)
HTML_DIR="$PROJECT_DIR/jmeter/results/html/${JTL_NAME}-report-${TIMESTAMP}"

echo "Generating HTML report from: $JTL_FILE"
echo "Report will be saved to: $HTML_DIR"

"$JMETER_BIN/jmeter" --generate-html "$HTML_DIR" --input-jtl "$JTL_FILE"

echo
echo "Report generated successfully!"
echo "Open: $HTML_DIR/index.html"

if command -v xdg-open &> /dev/null; then
    xdg-open "$HTML_DIR/index.html"
elif command -v open &> /dev/null; then
    open "$HTML_DIR/index.html"
fi
