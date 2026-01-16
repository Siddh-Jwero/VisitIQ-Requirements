@echo off
setlocal EnableDelayedExpansion

echo ============================================
echo   VisitIQ Windows Installer
echo ============================================

set LOG_FILE=%TEMP%\visitiq_install.log
set REQ_URL=https://raw.githubusercontent.com/Siddh-Jwero/VisitIQ-Requirements/main/requirements.txt
set TMP_REQ=%TEMP%\visitiq_requirements.txt
set PY=py -3.10

echo VisitIQ install started > "%LOG_FILE%"

REM -------------------------------------------------
REM Step 1: Ensure Python 3.10
REM -------------------------------------------------
echo.
echo [1/5] Checking for Python 3.10...

%PY% --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Installing Python 3.10...

    winget install --id Python.Python.3.10 -e ^
      --accept-package-agreements --accept-source-agreements ^
      >> "%LOG_FILE%" 2>&1

    timeout /t 8 >nul

    %PY% --version >nul 2>&1
    if %ERRORLEVEL% NEQ 0 (
        echo ❌ Python installation failed.
        echo See log: %LOG_FILE%
        exit /b 1
    )
)

echo Python ready.

REM -------------------------------------------------
REM Step 2: Upgrade pip (silent)
REM -------------------------------------------------
echo.
echo [2/5] Preparing installer...

%PY% -m pip install --upgrade pip ^
  --disable-pip-version-check ^
  --no-python-version-warning ^
  >> "%LOG_FILE%" 2>&1

REM -------------------------------------------------
REM Step 3: Download requirements
REM -------------------------------------------------
echo.
echo [3/5] Downloading dependencies list...

curl -fsSL "%REQ_URL%" -o "%TMP_REQ%" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to download requirements.
    exit /b 1
)

REM -------------------------------------------------
REM Step 4: Install dependencies (NO LIBRARY NAMES)
REM -------------------------------------------------
echo.
echo [4/5] Installing dependencies...
echo This may take a few minutes.

%PY% -m pip install --user ^
  --only-binary=:all: ^
  --disable-pip-version-check ^
  --no-python-version-warning ^
  -r "%TMP_REQ%" ^
  >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Dependency installation failed.
    echo See log:
    echo %LOG_FILE%
    exit /b 1
)

REM -------------------------------------------------
REM Step 5: Done
REM -------------------------------------------------
echo.
echo ============================================
echo   VisitIQ installed successfully
echo ============================================
echo.
pause
