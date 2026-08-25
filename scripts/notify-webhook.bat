@echo off
REM ========================================
REM  Slack/Teams Webhook Notification Script
REM ========================================
REM
REM Usage: notify-webhook.bat <jtl-file> <test-type> [webhook-url]
REM
REM Environment Variables:
REM   SLACK_WEBHOOK_URL    - Slack incoming webhook URL
REM   TEAMS_WEBHOOK_URL    - Microsoft Teams incoming webhook URL

setlocal EnableDelayedExpansion

set JTL_FILE=%1
set TEST_TYPE=%2
set WEBHOOK_URL=%3

if "%JTL_FILE%"=="" (
    echo Usage: notify-webhook.bat ^<jtl-file^> ^<test-type^> [webhook-url]
    exit /b 1
)

if not exist "%JTL_FILE%" (
    echo ERROR: JTL file not found: %JTL_FILE%
    exit /b 1
)

if "%WEBHOOK_URL%"=="" (
    if not "%SLACK_WEBHOOK_URL%"=="" (
        set WEBHOOK_URL=%SLACK_WEBHOOK_URL%
    ) else if not "%TEAMS_WEBHOOK_URL%"=="" (
        set WEBHOOK_URL=%TEAMS_WEBHOOK_URL%
    ) else (
        echo WARNING: No webhook URL configured.
        exit /b 0
    )
)

echo Notification feature requires curl and a webhook URL.
echo Configure SLACK_WEBHOOK_URL or TEAMS_WEBHOOK_URL environment variable.
exit /b 0
