@echo off
setlocal EnableDelayedExpansion

echo ============================================
echo   VisitIQ Windows Installer (BAT)
echo ============================================

set REQ_URL=https://raw.githubusercontent.com/Siddh-Jwero/VisitIQ-Requirements/main/requirements.txt
set TMP_REQ=%TEMP%\visitiq_requirements.txt
set PYTHON_OK=0

REM -------------------------------------------------
REM Step 1: Check for Python
REM -------------------------------------------------
echo.
echo [1/5] Checking for Python...

where python >nul 2>&1
if %ERRORLEVEL%==0 (
    python --version
    set PYTHON_OK=1
) else (
    echo Python not found on PATH.
)

REM -------------------------------------------------
REM Step 2: Install Python if missing
REM -------------------------------------------------
if %PYTHON_OK%==0 (
    echo.
    echo [2/5] Installing Python...

    REM Try winget first
    where winget >nul 2>&1
    if %ERRORLEVEL%==0 (
        echo Installing Python via winget...
        winget install --id=Python.Python.3 -e --accept-package-agreements --accept-source-agreements
    ) else (
        echo winget not available.
    )

    REM Refresh PATH
    call refreshenv >nul 2>&1

    where python >nul 2>&1
    if %ERRORLEVEL%==0 (
        set PYTHON_OK=1
    ) else (
        echo.
        echo Python still not detected.
        echo Downloading official Python installer...
        start https://www.python.org/downloads/windows/
        echo.
        echo Please install Python manually and CHECK:
        echo   [x] Add Python to PATH
        pause
        exit /b 1
    )
)

REM -------------------------------------------------
REM Step 3: Disable Microsoft Store Python alias
REM -------------------------------------------------
echo.
echo [3/5] Disabling Microsoft Store Python alias (if enabled)...

powershell -Command ^
 "Get-ItemProperty HKCU:\Software\Microsoft\Windows\CurrentVersion\AppExecutionAliases\python.exe -ErrorAction SilentlyContinue | Out-Null"

REM -------------------------------------------------
REM Step 4: Upgrade pip
REM -------------------------------------------------
echo.
echo [4/5] Upgrading pip...
python -m pip install --user --upgrade pip

REM -------------------------------------------------
REM Step 5: Install requirements
REM -------------------------------------------------
echo.
echo [5/5] Installing VisitIQ dependencies...

powershell -Command ^
 "Invoke-WebRequest -UseBasicParsing '%REQ_URL%' -OutFile '%TMP_REQ%'"

python -m pip install --user -r "%TMP_REQ%"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Dependency installation failed.
    exit /b 1
)

echo.
echo ============================================
echo   VisitIQ installation complete
echo ============================================
echo.
echo You may now run your application.
pause
