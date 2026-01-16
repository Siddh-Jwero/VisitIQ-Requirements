@echo off
setlocal EnableDelayedExpansion

echo ============================================
echo   VisitIQ Windows Installer
echo ============================================

set LOG_FILE=%TEMP%\visitiq_install.log
set REQ_URL=https://raw.githubusercontent.com/Siddh-Jwero/VisitIQ-Requirements/main/requirements.txt
set TMP_REQ=%TEMP%\visitiq_requirements.txt
set PYTHON_EXE=python

echo VisitIQ install started > "%LOG_FILE%"

REM -------------------------------------------------
REM Step 1: Check for Python 3.10 specifically
REM -------------------------------------------------
echo.
echo [1/5] Checking for Python...

for /f "tokens=2 delims= " %%v in ('python --version 2^>^&1') do set PY_VER=%%v

if "%PY_VER:~0,4%"=="3.10" (
    echo Python 3.10 detected.
    goto PY_OK
)

echo Python 3.10 not found.

REM -------------------------------------------------
REM Step 2: Install Python 3.10 silently
REM -------------------------------------------------
echo.
echo [2/5] Installing Python 3.10...

where winget >nul 2>&1
if %ERRORLEVEL%==0 (
    winget install --id Python.Python.3.10 -e ^
        --accept-package-agreements --accept-source-agreements ^
        >> "%LOG_FILE%" 2>&1
) else (
    echo ERROR: winget not available. >> "%LOG_FILE%"
    echo Please install Python 3.10 manually.
    pause
    exit /b 1
)

echo Waiting for Python to initialize...
timeout /t 8 >nul

python --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ERROR: Python installed but PATH not refreshed.
    echo Close this window and re-run install.bat.
    pause
    exit /b 1
)

:PY_OK

REM -------------------------------------------------
REM Step 3: Upgrade pip quietly
REM -------------------------------------------------
echo.
echo [3/5] Upgrading pip...
%PYTHON_EXE% -m pip install --upgrade pip ^
    --disable-pip-version-check --no-python-version-warning ^
    >> "%LOG_FILE%" 2>&1

REM -------------------------------------------------
REM Step 4: Download requirements
REM -------------------------------------------------
echo.
echo [4/5] Downloading requirements...

curl -fsSL "%REQ_URL%" -o "%TMP_REQ%" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to download requirements.
    echo See log: %LOG_FILE%
    exit /b 1
)

REM -------------------------------------------------
REM Step 5: Install dependencies (binary-only, silent)
REM -------------------------------------------------
echo.
echo [5/5] Installing dependencies (this may take a few minutes)...

%PYTHON_EXE% -m pip install --user ^
    --only-binary=:all: ^
    --disable-pip-version-check ^
    --no-python-version-warning ^
    -r "%TMP_REQ%" ^
    >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo ❌ Dependency installation failed.
    echo See log file:
    echo %LOG_FILE%
    exit /b 1
)

echo.
echo ============================================
echo   VisitIQ installation completed successfully
echo ============================================
echo.
pause
