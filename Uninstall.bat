@echo off
chcp 65001 >nul
setlocal

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0Uninstall.ps1"
set "exitCode=%ERRORLEVEL%"

echo.
if not "%exitCode%"=="0" (
  echo 移除沒有完成，請把上面的錯誤訊息截圖給提供者。
) else (
  echo 移除完成。
)
echo.
pause
exit /b %exitCode%
