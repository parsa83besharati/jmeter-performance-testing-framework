#!/bin/bash

# ========================================
#  Slack/Teams Webhook Notification Script
# ========================================
#
# Sends test results to Slack or Microsoft Teams webhook.
#
# Usage:
#   ./notify-webhook.sh <jtl-file> <test-type> [webhook-url]
#
# Environment Variables:
#   SLACK_WEBHOOK_URL    - Slack incoming webhook URL
#   TEAMS_WEBHOOK_URL    - Microsoft Teams incoming webhook URL
#   NOTIFY_WEBHOOK       - Generic webhook URL (Slack/Teams auto-detected)
#
# Examples:
#   ./notify-webhook.sh results.jtl load
#   SLACK_WEBHOOK_URL=https://hooks.slack.com/... ./notify-webhook.sh results.jtl load
#   TEAMS_WEBHOOK_URL=https://outlook.office.com/... ./notify-webhook.sh results.jtl smoke

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
JTL_FILE="${1:-}"
TEST_TYPE="${2:-}"
WEBHOOK_URL="${3:-${NOTIFY_WEBHOOK:-}}"

if [ -z "$JTL_FILE" ] || [ -z "$TEST_TYPE" ]; then
    echo "Usage: ./notify-webhook.sh <jtl-file> <test-type> [webhook-url]"
    echo
    echo "Set SLACK_WEBHOOK_URL or TEAMS_WEBHOOK_URL environment variable."
    exit 1
fi

if [ ! -f "$JTL_FILE" ]; then
    echo "ERROR: JTL file not found: $JTL_FILE"
    exit 1
fi

# Auto-detect webhook URL from env
if [ -z "$WEBHOOK_URL" ]; then
    WEBHOOK_URL="${SLACK_WEBHOOK_URL:-${TEAMS_WEBHOOK_URL:-}}"
fi

if [ -z "$WEBHOOK_URL" ]; then
    echo "WARNING: No webhook URL configured. Set SLACK_WEBHOOK_URL or TEAMS_WEBHOOK_URL."
    echo "Skipping notification."
    exit 0
fi

# Parse JTL
TOTAL=$(tail -n +2 "$JTL_FILE" | wc -l)
ERRORS=$(tail -n +2 "$JTL_FILE" | awk -F',' '$2 == "false"' | wc -l)
ERROR_RATE=0
if [ "$TOTAL" -gt 0 ]; then
    ERROR_RATE=$((ERRORS * 100 / TOTAL))
fi

AVG_TIME=$(tail -n +2 "$JTL_FILE" | awk -F',' '{sum+=$3; count++} END {printf "%.0f", sum/count}')
MAX_TIME=$(tail -n +2 "$JTL_FILE" | awk -F',' '{if($3>max) max=$3} END {print max}')
P95_TIME=$(tail -n +2 "$JTL_FILE" | awk -F',' '{print $3}' | sort -n | awk -v n="$TOTAL" 'NR==int(n*0.95){print}')

# Determine status
if [ "$ERROR_RATE" -le 1 ]; then
    STATUS="PASS"
    COLOR="#36a64f"
    EMOJI=":white_check_mark:"
elif [ "$ERROR_RATE" -le 5 ]; then
    STATUS="WARNING"
    COLOR="#ff9900"
    EMOJI=":warning:"
else
    STATUS="FAIL"
    COLOR="#ff0000"
    EMOJI=":x:"
fi

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "N/A")

# Detect Slack vs Teams
if echo "$WEBHOOK_URL" | grep -q "hooks.slack.com"; then
    # Slack payload
    PAYLOAD=$(cat <<EOF
{
    "attachments": [
        {
            "color": "${COLOR}",
            "blocks": [
                {
                    "type": "header",
                    "text": {
                        "type": "plain_text",
                        "text": "${EMOJI} Performance Test ${STATUS}"
                    }
                },
                {
                    "type": "section",
                    "fields": [
                        {"type": "mrkdwn", "text": "*Test Type:*\n${TEST_TYPE}"},
                        {"type": "mrkdwn", "text": "*Environment:*\n${ENV:-development}"},
                        {"type": "mrkdwn", "text": "*Total Requests:*\n${TOTAL}"},
                        {"type": "mrkdwn", "text": "*Error Rate:*\n${ERROR_RATE}%"},
                        {"type": "mrkdwn", "text": "*Avg Response:*\n${AVG_TIME}ms"},
                        {"type": "mrkdwn", "text": "*P95 Response:*\n${P95_TIME}ms"},
                        {"type": "mrkdwn", "text": "*Max Response:*\n${MAX_TIME}ms"},
                        {"type": "mrkdwn", "text": "*Git Commit:*\n${GIT_COMMIT}"}
                    ]
                },
                {
                    "type": "context",
                    "elements": [
                        {"type": "mrkdwn", "text": "JMeter Performance Framework | ${TIMESTAMP}"}
                    ]
                }
            ]
        }
    ]
}
EOF
)
else
    # Teams payload
    PAYLOAD=$(cat <<EOF
{
    "@type": "MessageCard",
    "@context": "http://schema.org/extensions",
    "themeColor": "${COLOR}",
    "summary": "Performance Test ${STATUS} - ${TEST_TYPE}",
    "sections": [
        {
            "activityTitle": "${EMOJI} Performance Test ${STATUS}",
            "facts": [
                {"name": "Test Type", "value": "${TEST_TYPE}"},
                {"name": "Environment", "value": "${ENV:-development}"},
                {"name": "Total Requests", "value": "${TOTAL}"},
                {"name": "Error Rate", "value": "${ERROR_RATE}%"},
                {"name": "Avg Response", "value": "${AVG_TIME}ms"},
                {"name": "P95 Response", "value": "${P95_TIME}ms"},
                {"name": "Max Response", "value": "${MAX_TIME}ms"},
                {"name": "Git Commit", "value": "${GIT_COMMIT}"}
            ],
            "markdown": true
        }
    ],
    "potentialAction": [
        {
            "@type": "OpenUri",
            "name": "View Results",
            "targets": [
                {"os": "default", "uri": "https://github.com/parsa83besharati/jmeter-performance-testing-framework/actions"}
            ]
        }
    ]
}
EOF
)
fi

# Send webhook
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    "$WEBHOOK_URL")

if [ "$HTTP_CODE" -eq 200 ] || [ "$HTTP_CODE" -eq 204 ]; then
    echo "Notification sent successfully (${STATUS})"
else
    echo "WARNING: Webhook returned HTTP ${HTTP_CODE}"
fi
