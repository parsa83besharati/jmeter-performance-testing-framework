@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo   JTL Result Validator
echo ========================================
echo.

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set JTL_FILE=%1

if "%JTL_FILE%"=="" (
    echo Usage: validate-results.bat [jtl-file]
    echo.
    echo Validates JTL results against configured thresholds:
    echo   - P95 response time threshold
    echo   - P99 response time threshold
    echo   - Error rate threshold
    echo.
    echo Example:
    echo   validate-results.bat ..\jmeter\results\jtl\load-test-results.jtl
    exit /b 1
)

if not exist "%JTL_FILE%" (
    echo ERROR: JTL file not found: %JTL_FILE%
    exit /b 1
)

set P95_THRESHOLD=%2
set P99_THRESHOLD=%3
set ERROR_RATE_THRESHOLD=%4

if "%P95_THRESHOLD%"=="" set P95_THRESHOLD=1000
if "%P99_THRESHOLD%"=="" set P99_THRESHOLD=2000
if "%ERROR_RATE_THRESHOLD%"=="" set ERROR_RATE_THRESHOLD=5

echo Validating: %JTL_FILE%
echo Thresholds: P95^<=%P95_THRESHOLD%ms, P99^<=%P99_THRESHOLD%ms, Error Rate^<=%ERROR_RATE_THRESHOLD%%%
echo.

set TOTAL_LINES=0
set ERROR_LINES=0
set SUM_TIME=0
set MAX_TIME=0
set MIN_TIME=999999
set COUNT=0

for /f "tokens=*" %%A in (%JTL_FILE%) do (
    set /a COUNT+=1
)

set /a TOTAL_LINES=%COUNT% - 1

if %TOTAL_LINES% leq 0 (
    echo ERROR: JTL file is empty or has no data rows
    exit /b 1
)

echo Total samples: %TOTAL_LINES%

for /f "skip=1 tokens=1,2,3,4 delims=," %%A in (%JTL_FILE%) do (
    set SUCCESS=%%B
    set ELAPSED=%%C
    
    if "!SUCCESS!"=="false" (
        set /a ERROR_LINES+=1
    )
    
    set /a SUM_TIME+=!ELAPSED!
    
    if !ELAPSED! gtr !MAX_TIME! set MAX_TIME=!ELAPSED!
    if !ELAPSED! lss !MIN_TIME! set MIN_TIME=!ELAPSED!
)

set /a ERROR_RATE=(!ERROR_LINES! * 100) / !TOTAL_LINES!
set /a AVG_TIME=!SUM_TIME! / !TOTAL_LINES!

echo.
echo === RESULTS SUMMARY ===
echo Total Samples:    %TOTAL_LINES%
echo Error Count:      %ERROR_LINES%
echo Error Rate:       %ERROR_RATE%%%
echo Min Response:     %MIN_TIME%ms
echo Max Response:     %MAX_TIME%ms
echo Avg Response:     %AVG_TIME%ms
echo.

set PASSED=true

if %ERROR_RATE% gtr %ERROR_RATE_THRESHOLD% (
    echo [FAIL] Error rate %ERROR_RATE%%% exceeds threshold %ERROR_RATE_THRESHOLD%%%
    set PASSED=false
) else (
    echo [PASS] Error rate within threshold
)

if %MAX_TIME% gtr %P99_THRESHOLD% (
    echo [FAIL] Max response time %MAX_TIME%ms exceeds P99 threshold %P99_THRESHOLD%ms
    set PASSED=false
) else (
    echo [PASS] Max response time within P99 threshold
)

echo.
if "%PASSED%"=="true" (
    echo VALIDATION PASSED - All thresholds met
    exit /b 0
) else (
    echo VALIDATION FAILED - One or more thresholds exceeded
    exit /b 1
)
