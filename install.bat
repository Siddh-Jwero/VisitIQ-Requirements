@echo off
REM Wrapper to call the PowerShell installer. For Windows users run this.
REM Usage: install.bat [--yes] [--venv] [--requirements <path_or_url>]

SETLOCAL
REM Forward all args to PowerShell script
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
ENDLOCAL
