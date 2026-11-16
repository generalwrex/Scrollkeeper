@echo off
rem Double-click to open a ready-to-send "Share your data" issue for Scrollkeeper.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0share-scrollkeeper-data.ps1" %*
echo.
pause
