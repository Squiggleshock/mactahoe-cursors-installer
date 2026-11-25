@echo off
setlocal DisableDelayedExpansion
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -NonInteractive -ExecutionPolicy Bypass -File "%~dp0Install-TahoeCursors.ps1"
set "TahoeExitCode=%ERRORLEVEL%"
echo.
pause
exit /b %TahoeExitCode%
