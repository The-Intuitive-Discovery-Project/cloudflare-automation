@echo off
setlocal
cd /d "%~dp0"
echo.
echo === TinyThor Cloudflare Deployment Setup ===
echo Hunter's Cloudflare deployment token already exists.
echo This will reuse/connect that existing token, prepare local tools, and check GitHub setup.
echo It will NOT create a new Cloudflare token and will NOT deploy any production website.
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
