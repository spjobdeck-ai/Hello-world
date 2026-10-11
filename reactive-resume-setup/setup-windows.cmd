@echo off
REM Runs the PowerShell setup script from Command Prompt or by double-clicking.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup-windows.ps1" %*
pause
