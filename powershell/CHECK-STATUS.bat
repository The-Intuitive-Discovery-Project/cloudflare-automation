@echo off
setlocal
cd /d "%~dp0"
echo.
echo === TinyThor Automation Status ===
echo Read-only check. No secrets will be changed and no website will be deployed.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Check-Status.ps1"
set "EXITCODE=%ERRORLEVEL%"
echo.
pause
exit /b %EXITCODE%
