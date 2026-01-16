@echo off
setlocal EnableDelayedExpansion

echo ============================================
echo   VisitIQ Windows Installer
echo ============================================

set REQ_URL=https://raw.githubusercontent.com/Siddh-Jwero/VisitIQ-Requirements/main/requirements.txt
set TMP_REQ=%TEMP%\visitiq_requirements.txt
set PY_EXE=

REM -------------------------------------------------
REM Step 0: Disable Microsoft Store Python aliases
REM -------------------------------------------------
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AppExecutionAliases" ^
 /v python.exe /t REG_SZ /d "" /f >nul 2>&1
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\AppExecutionAliases" ^
 /v python3.exe /t REG_SZ /d "" /f >nul 2>&1

REM -------------------------------------------------
REM Step 1: Check for real Python
REM -------------------------------------------------
echo.
echo [1/5] Checking for Python...

python --version >nul 2>&1
if %ERRORLEVEL%==0 (
    set PY_EXE=python
    goto PY_OK
)

py -3 --version >nul 2>&1
if %ERRORLEVEL%==0 (
    set PY_EXE=py -3
    goto PY_OK
)

echo Python not found.

REM -------------------------------------------------
REM Step 2: Try winget (VALID IDs ONLY)
REM -------------------------------------------------
echo.
echo [2/5] Installing Python via winget...

where winget >nul 2>&1
if %ERRORLEVEL%==0 (
    winget install --id Python.Python.3.11 -e --accept-package-agreements --accept-source-agreements
)

timeout /t 6 >nul

python --version >nul 2>&1 && set PY_EXE=python && goto PY_OK
py -3 --version >nul 2>&1 && set PY_EXE=py -3 && goto PY_OK

REM -------------------------------------------------
REM Step 3: Fallback to official Python installer
REM -------------------------------------------------
echo.
echo Winget failed. Using official Python installer...

set PY_URL=https://www.python.org/ftp/python/3.11.8/python-3.11.8-amd64.exe
set PY_INSTALLER=%TEMP%\python_installer.exe

curl -fsSL "%PY_URL%" -o "%PY_INSTALLER%"
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Failed to download Python installer.
    exit /b 1
)

"%PY_INSTALLER%" /quiet InstallAllUsers=1 PrependPath=1 Include_test=0

timeout /t 8 >nul

python --version >nul 2>&1 && set PY_EXE=python && goto PY_OK
py -3 --version >nul 2>&1 && set PY_EXE=py -3 && goto PY_OK

echo.
echo ❌ Python installation failed.
echo Please reboot and re-run install.bat
exit /b 1

:PY_OK
echo.
echo Python ready.

REM -------------------------------------------------
REM Step 4: Upgrade pip
REM -------------------------------------------------
echo.
echo [3/5] Upgrading pip...
%PY_EXE% -m pip install --user --upgrade pip

REM -------------------------------------------------
REM Step 5: Install VisitIQ dependencies
REM -------------------------------------------------
echo.
echo [4/5] Downloading requirements.txt...
curl -fsSL "%REQ_URL%" -o "%TMP_REQ%"

echo.
echo [5/5] Installing dependencies...
%PY_EXE% -m pip install --user -r "%TMP_REQ%"

if %ERRORLEVEL% NEQ 0 (
    echo ❌ Dependency installation failed.
    exit /b 1
)

echo.
echo ============================================
echo   VisitIQ installation completed successfully
echo ============================================
pause
