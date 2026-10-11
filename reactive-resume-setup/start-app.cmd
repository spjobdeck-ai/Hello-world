@echo off
REM Starts Reactive Resume (pnpm dev) from Command Prompt or by double-clicking.
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%USERPROFILE%\reactive-resume"
powershell -NoProfile -ExecutionPolicy Bypass -Command "$env:Path += ';' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine'); fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression; Set-Location '%TARGET%'; Write-Host 'Starting Reactive Resume... open http://localhost:3000 once it says ready'; pnpm dev"
pause
