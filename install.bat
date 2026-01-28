@echo off
setlocal EnableExtensions EnableDelayedExpansion

chcp 65001 >nul

echo ============================================
echo   VisitIQ Windows Installer
echo ============================================

set LOG_FILE=%TEMP%\visitiq_install.log
set PYTHON=python
set PIP_DISABLE_PIP_VERSION_CHECK=1
set PIP_NO_PYTHON_VERSION_WARNING=1

echo VisitIQ install started > "%LOG_FILE%"

REM -------------------------------------------------
REM Initial system check
REM -------------------------------------------------
where winget >nul 2>&1 || (
    echo [ERROR] Required system component not found.
    echo Please install "App Installer" from the Microsoft Store.
    exit /b 1
)

REM -------------------------------------------------
REM Step 1: Checking required software
REM -------------------------------------------------
echo.
echo [1/5] Checking required software...

%PYTHON% --version 2>nul | find "3.12" >nul
if %ERRORLEVEL% NEQ 0 (
    echo Required software not found. Installing...

    winget install --id Python.Python.3.12 -e ^
        --accept-package-agreements ^
        --accept-source-agreements ^
        >> "%LOG_FILE%" 2>&1

    echo Finalizing installation...
    timeout /t 15 >nul
)

REM Ensure correct version is used
set PYTHON=py -3.12

%PYTHON% --version 2>nul | find "3.12" >nul || (
    echo [ERROR] Required software unavailable.
    echo Please close this window and run the installer again.
    echo See log: %LOG_FILE%
    exit /b 1
)

echo System check complete.

REM -------------------------------------------------
REM Step 2: Preparing your computer
REM -------------------------------------------------
echo.
echo [2/5] Preparing your computer...

%PYTHON% -m pip install --upgrade ^
    pip setuptools wheel ^
    --user ^
    >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Preparation step failed.
    echo See log: %LOG_FILE%
    exit /b 1
)

REM -------------------------------------------------
REM Step 3: Installing required files
REM -------------------------------------------------
echo.
echo [3/5] Installing required files...

%PYTHON% -m pip install --user ^
    psutil requests cryptography keyring tqdm ^
    fastapi uvicorn pydantic ^
    ip2geotools Pillow python-nmap pyinstaller pyzipper ^
    "numpy>=1.24,<2.0" scipy opencv-python ^
    huggingface_hub transformers ^
    PyYAML matplotlib ^
    >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Installation failed.
    echo See log: %LOG_FILE%
    exit /b 1
)

REM -------------------------------------------------
REM Step 4: Installing additional features
REM -------------------------------------------------
echo.
echo [4/5] Installing additional features...
echo This may take a few minutes.

%PYTHON% -m pip install --user ^
    torch torchvision ^
    --index-url https://download.pytorch.org/whl/cpu ^
    >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Additional feature installation failed.
    echo See log: %LOG_FILE%
    exit /b 1
)

%PYTHON% -m pip install --user ^
    ultralytics onnxruntime deepface ^
    >> "%LOG_FILE%" 2>&1

if %ERRORLEVEL% NEQ 0 (
    echo [ERROR] Additional feature installation failed.
    echo See log: %LOG_FILE%
    exit /b 1
)

REM -------------------------------------------------
REM Step 5: Final setup
REM -------------------------------------------------
echo.
echo [5/5] Final setup...

where nmap >nul 2>&1 || (
    echo Installing optional system component...
    winget install Insecure.Nmap ^
        --accept-package-agreements ^
        --accept-source-agreements ^
        >> "%LOG_FILE%" 2>&1
)

echo.
echo NOTE:
echo - Some tools may require reopening your command window.
echo - Installation details are saved here:
echo   %LOG_FILE%

echo.
echo ============================================
echo   VisitIQ installed successfully
echo ============================================
echo.

pause
exit /b 0
