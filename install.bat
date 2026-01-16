@echo off
setlocal EnableDelayedExpansion

echo ============================================
echo   VisitIQ Windows Installer
echo ============================================

set REQ_URL=https://raw.githubusercontent.com/Siddh-Jwero/VisitIQ-Requirements/main/requirements.txt
set TMP_REQ=%TEMP%\visitiq_requirements.txt

REM -------------------------------------------------
REM Step 1: Check for REAL Python (not Store stub)
REM -------------------------------------------------
echo.
echo [1/5] Checking for Python...

python --version >nul 2>&1
if %ERRORLEVEL%==0 (
    for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PY_VER=%%v
    echo Found Python %PY_VER%
    goto PY_OK
)

echo Python not found or Microsoft Store stub detected.

REM -------------------------------------------------
REM Step 2: Install Python via winget (REQUIRED)
REM -------------------------------------------------
echo.
echo [2/5] Installing Python automatically...

where winget >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: winget is not available on this system.
    echo Please update Windows or install Python manually:
    echo https://www.python.org/downloads/windows/
    pause
    exit /b 1
)

winget install --id=Python.Python.3 -e --accept-package-agreements --accept-source-agreements

echo Waiting for Python to be registered in PATH...
timeout /t 8 >nul

python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Python installed but PATH not updated yet.
    echo Close this window and re-run install.bat.
    pause
    exit /b 1
)

:PY_OK

REM -------------------------------------------------
REM Step 3: Upgrade pip
REM -------------------------------------------------
echo.
echo [3/5] Upgrading pip...
python -m pip install --user --upgrade pip

REM -------------------------------------------------
REM Step 4: Download requirements
REM -------------------------------------------------
echo.
echo [4/5] Downloading requirements.txt...

curl -fsSL "%REQ_URL%" -o "%TMP_REQ%"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to download requirements.txt
    exit /b 1
)

REM -------------------------------------------------
REM Step 5: Install dependencies
REM -------------------------------------------------
echo.
echo [5/5] Installing VisitIQ dependencies...

python -m pip install --user -r "%TMP_REQ%"
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Dependency installation failed.
    exit /b 1
)

echo.
echo ============================================
echo   VisitIQ installation completed successfully
echo ============================================
echo.
pause
