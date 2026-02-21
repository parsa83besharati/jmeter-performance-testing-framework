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

for %%F in (test-plans\*.jmx) do (
    echo Validating: %%F
    "%JMETER_BIN%\jmeter.bat" -n -t "%%F" -l results\jtl\validation-%%~nF.jtl -j results\jtl\validation-%%~nF.log -Jloop=0
    if !errorlevel! equ 0 (
        echo   [PASS] %%F
    ) else (
        echo   [FAIL] %%F
    )
    del /q results\jtl\validation-%%~nF.jtl 2>nul
    echo.
)

echo Validation complete.
