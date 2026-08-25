@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo   JMeter Performance Test Runner
echo ========================================
echo.

if "%JMETER_HOME%"=="" (
    echo ERROR: JMETER_HOME environment variable is not set
    echo Please set JMETER_HOME to your JMeter installation directory
    exit /b 1
)

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set JMETER_BIN=%JMETER_HOME%\bin
set TEST_PLAN=%1
set PROPERTIES_FILE=%2

if "%TEST_PLAN%"=="" (
    echo Usage: run-test.bat [test-plan] [properties-file]
    echo.
    echo Available test plans:
    echo   smoke   - Smoke test (quick validation)
    echo   load    - Load test (normal expected load)
    echo   stress  - Stress test (beyond normal load)
    echo   spike   - Spike test (sudden surge)
    echo   soak    - Soak test (sustained load over time)
    echo   all     - Run all tests sequentially
    echo.
    echo Example:
    echo   run-test.bat smoke
    echo   run-test.bat load test-config.properties
    exit /b 1
)

if "%PROPERTIES_FILE%"=="" (
    set PROPERTIES_FILE=config\test-config.properties
)

set TIMESTAMP=%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%

if not exist "%PROJECT_DIR%\jmeter\results\jtl" mkdir "%PROJECT_DIR%\jmeter\results\jtl"
if not exist "%PROJECT_DIR%\jmeter\results\html" mkdir "%PROJECT_DIR%\jmeter\results\html"

cd /d "%PROJECT_DIR%\jmeter"

if "%TEST_PLAN%"=="all" (
    call :run_test smoke
    call :run_test load
    call :run_test stress
    call :run_test spike
    call :run_test soak
) else (
    call :run_test %TEST_PLAN%
)

echo.
echo ========================================
echo   Test Execution Completed
echo ========================================
echo Results saved to: %PROJECT_DIR%\jmeter\results
exit /b 0

:run_test
set TEST_TYPE=%1
set JTL_FILE=results\jtl\%TEST_TYPE%-test-%TIMESTAMP%.jtl
set HTML_DIR=results\html\%TEST_TYPE%-test-%TIMESTAMP%

echo.
echo Running %TEST_TYPE% test...
echo Results will be saved to: %JTL_FILE%

"%JMETER_BIN%\jmeter.bat" -n -t test-plans\%TEST_TYPE%-test.jmx -l %JTL_FILE% -q %PROPERTIES_FILE% -p config\user.properties -j results\jtl\%TEST_TYPE%-test-%TIMESTAMP%.log

echo.
echo Validating results...
call "%SCRIPT_DIR%validate-results.bat" "%PROJECT_DIR%\jmeter\%JTL_FILE%"
set VALIDATE_RESULT=!errorlevel!

echo.
echo Generating HTML report...
"%JMETER_BIN%\jmeter.bat" --generate-html %HTML_DIR% --input-jtl %JTL_FILE%

echo %TEST_TYPE% test completed. HTML report: %HTML_DIR%

if !VALIDATE_RESULT! neq 0 (
    echo WARNING: %TEST_TYPE% test failed threshold validation!
)

exit /b 0
