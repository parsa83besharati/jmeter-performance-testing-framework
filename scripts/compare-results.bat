@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo   JTL Result Comparator
echo ========================================
echo.

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set JTL_BASELINE=%1
set JTL_CURRENT=%2

if "%JTL_BASELINE%"=="" (
    echo Usage: compare-results.bat [baseline-jtl] [current-jtl]
    echo.
    echo Compares two JTL result files and shows differences in:
    echo   - Total requests
    echo   - Error rate
    echo   - Average response time
    echo   - Max response time
    echo   - Throughput
    echo.
    echo Example:
    echo   compare-results.bat baseline.jtl current.jtl
    exit /b 1
)

if "%JTL_CURRENT%"=="" (
    echo ERROR: Both baseline and current JTL files are required
    exit /b 1
)

if not exist "%JTL_BASELINE%" (
    echo ERROR: Baseline JTL file not found: %JTL_BASELINE%
    exit /b 1
)

if not exist "%JTL_CURRENT%" (
    echo ERROR: Current JTL file not found: %JTL_CURRENT%
    exit /b 1
)

echo Baseline: %JTL_BASELINE%
echo Current:  %JTL_CURRENT%
echo.

echo === BASELINE RESULTS ===
set B_TOTAL=0
set B_ERRORS=0
set B_SUM_TIME=0
set B_MAX_TIME=0

for /f "skip=1 tokens=1,2,3 delims=," %%A in (%JTL_BASELINE%) do (
    set /a B_TOTAL+=1
    if "%%B"=="false" set /a B_ERRORS+=1
    set /a B_SUM_TIME+=%%C
    if %%C gtr !B_MAX_TIME! set B_MAX_TIME=%%C
)

set /a B_ERROR_RATE=(B_ERRORS * 100) / (B_TOTAL + 1)
set /a B_AVG_TIME=B_SUM_TIME / (B_TOTAL + 1)

echo Total Requests:  %B_TOTAL%
echo Error Rate:      %B_ERROR_RATE%%%
echo Avg Response:    %B_AVG_TIME%ms
echo Max Response:    %B_MAX_TIME%ms

echo.
echo === CURRENT RESULTS ===
set C_TOTAL=0
set C_ERRORS=0
set C_SUM_TIME=0
set C_MAX_TIME=0

for /f "skip=1 tokens=1,2,3 delims=," %%A in (%JTL_CURRENT%) do (
    set /a C_TOTAL+=1
    if "%%B"=="false" set /a C_ERRORS+=1
    set /a C_SUM_TIME+=%%C
    if %%C gtr !C_MAX_TIME! set C_MAX_TIME=%%C
)

set /a C_ERROR_RATE=(C_ERRORS * 100) / (C_TOTAL + 1)
set /a C_AVG_TIME=C_SUM_TIME / (C_TOTAL + 1)

echo Total Requests:  %C_TOTAL%
echo Error Rate:      %C_ERROR_RATE%%%
echo Avg Response:    %C_AVG_TIME%ms
echo Max Response:    %C_MAX_TIME%ms

echo.
echo === COMPARISON ===

set /a DIFF_TOTAL=C_TOTAL - B_TOTAL
set /a DIFF_ERRORS=C_ERROR_RATE - B_ERROR_RATE
set /a DIFF_AVG=C_AVG_TIME - B_AVG_TIME
set /a DIFF_MAX=C_MAX_TIME - B_MAX_TIME

echo Requests Delta:  %DIFF_TOTAL% (%if %DIFF_TOTAL% gtr 0 then echo more%)
echo Error Rate Delta: %DIFF_ERRORS%%% 
echo Avg Time Delta:  %DIFF_AVG%ms
echo Max Time Delta:  %DIFF_MAX%ms

echo.
if %DIFF_ERRORS% gtr 0 (
    echo WARNING: Error rate increased by %DIFF_ERRORS%%%
)
if %DIFF_AVG% gtr 100 (
    echo WARNING: Average response time increased by %DIFF_AVG%ms
)
if %DIFF_MAX% gtr 500 (
    echo WARNING: Max response time increased by %DIFF_MAX%ms
)
