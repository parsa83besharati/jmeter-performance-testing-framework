@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo   JMeter Test Validator
echo ========================================
echo.

if "%JMETER_HOME%"=="" (
    echo ERROR: JMETER_HOME environment variable is not set
    exit /b 1
)

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set JMETER_BIN=%JMETER_HOME%\bin

cd /d "%PROJECT_DIR%\jmeter"

echo Validating all test plans...
echo.

set PASS_COUNT=0
set FAIL_COUNT=0

for %%F in (test-plans\*.jmx) do (
    echo Validating: %%F
    "%JMETER_BIN%\jmeter.bat" -n -t "%%F" -l results\jtl\validation-%%~nF.jtl -j results\jtl\validation-%%~nF.log -Jloop=0 2>nul
    if !errorlevel! equ 0 (
        echo   [PASS] %%F
        set /a PASS_COUNT+=1
    ) else (
        echo   [FAIL] %%F
        set /a FAIL_COUNT+=1
    )
    del /q results\jtl\validation-%%~nF.jtl 2>nul
    del /q results\jtl\validation-%%~nF.log 2>nul
    echo.
)

echo ========================================
echo   Validation Summary
echo ========================================
echo   Passed: %PASS_COUNT%
echo   Failed: %FAIL_COUNT%
echo.

if %FAIL_COUNT% gtr 0 (
    echo   RESULT: Some test plans failed validation
    exit /b 1
) else (
    echo   RESULT: All test plans passed validation
    exit /b 0
)
