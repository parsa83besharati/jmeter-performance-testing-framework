@echo off
setlocal EnableDelayedExpansion

echo ========================================
echo   JMeter HTML Report Generator
echo ========================================
echo.

if "%JMETER_HOME%"=="" (
    echo ERROR: JMETER_HOME environment variable is not set
    exit /b 1
)

set SCRIPT_DIR=%~dp0
set PROJECT_DIR=%SCRIPT_DIR%..
set JMETER_BIN=%JMETER_HOME%\bin
set JTL_FILE=%1

if "%JTL_FILE%"=="" (
    echo Usage: generate-report.bat [jtl-file]
    echo.
    echo Example:
    echo   generate-report.bat ..\jmeter\results\jtl\load-test-results.jtl
    exit /b 1
)

set TIMESTAMP=%date:~-4,4%%date:~-7,2%%date:~-10,2%_%time:~0,2%%time:~3,2%%time:~6,2%
set TIMESTAMP=%TIMESTAMP: =0%

for %%F in ("%JTL_FILE%") do set JTL_NAME=%%~nF

set HTML_DIR=%PROJECT_DIR%\jmeter\results\html\%JTL_NAME%-report-%TIMESTAMP%

echo Generating HTML report from: %JTL_FILE%
echo Report will be saved to: %HTML_DIR%

"%JMETER_BIN%\jmeter.bat" --generate-html "%HTML_DIR%" --input-jtl "%JTL_FILE%"

echo.
echo Report generated successfully!
echo Open: %HTML_DIR%\index.html

start "" "%HTML_DIR%\index.html"
