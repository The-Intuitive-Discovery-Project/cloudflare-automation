@echo off
setlocal
cd /d "%~dp0"
echo.
echo === TinyThor Cloudflare Deployment Setup ===
echo This will prepare the local tools, GitHub login, and one-time Cloudflare credential setup.
echo It will NOT deploy any production website.
echo.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Bootstrap.ps1" -FullSetup
set "EXITCODE=%ERRORLEVEL%"
echo.
if not "%EXITCODE%"=="0" (
  echo Setup stopped with exit code %EXITCODE%.
  echo Read the message above before trying again.
) else (
  echo Setup finished successfully.
)
echo.
pause
exit /b %EXITCODE%
