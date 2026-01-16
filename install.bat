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
REM Step 1: Ensure Python 3.10 exists
REM -------------------------------------------------
echo.
echo [1/6] Checking for Python 3.10...

%PY% --version >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo Python 3.10 not found.
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

echo Python 3.10 ready.

REM -------------------------------------------------
REM Step 2: Upgrade pip
REM -------------------------------------------------
echo.
echo [2/6] Upgrading pip...

%PY% -m pip install --upgrade pip ^
  --disable-pip-version-check --no-python-version-warning ^
  >> "%LOG_FILE%" 2>&1

REM -------------------------------------------------
REM Step 3: Install insightface (WHEEL ONLY)
REM -------------------------------------------------
echo.
echo [3/6] Installing core vision engine...

%PY% -m pip install insightface==0.7.3 ^
  --only-binary=:all: ^
  --disable-pip-version-check ^
  >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to install core vision engine.
    echo See log: %LOG_FILE%
    exit /b 1
)

REM -------------------------------------------------
REM Step 4: Download remaining requirements
REM -------------------------------------------------
echo.
echo [4/6] Downloading dependencies list...

curl -fsSL "%REQ_URL%" -o "%TMP_REQ%" >> "%LOG_FILE%" 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ❌ Failed to download requirements.
    echo See log: %LOG_FILE%
    exit /b 1
)

REM -------------------------------------------------
REM Step 5: Install remaining dependencies (silent)
REM -------------------------------------------------
echo.
echo [5/6] Installing remaining dependencies...
echo This may take a few minutes.

%PY% -m pip install --user ^
  --only-binary=:all: ^
  --disable-pip-version-check ^
  --no-python-version-warning ^
  -r "%TMP_REQ%" ^
  >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Dependency installation failed.
    echo See log: %LOG_FILE%
    exit /b 1
)

REM -------------------------------------------------
REM Step 6: Done
REM -------------------------------------------------
echo.
echo ============================================
echo   VisitIQ installation completed successfully
echo ============================================
echo.
pause
