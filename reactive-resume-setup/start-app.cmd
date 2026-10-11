@echo off
REM Starts Reactive Resume in two windows: the API server (port 3001) and the web app (port 3000).
set "TARGET=%~1"
if "%TARGET%"=="" set "TARGET=%USERPROFILE%\reactive-resume"
set "PS=powershell -NoProfile -ExecutionPolicy Bypass -Command"
set "INIT=$env:Path += ';' + [Environment]::GetEnvironmentVariable('Path','User') + ';' + [Environment]::GetEnvironmentVariable('Path','Machine'); fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression;"

start "Reactive Resume - API server (port 3001)" %PS% "%INIT% Set-Location '%TARGET%\apps\server'; Write-Host 'Starting API server, wait for: Up and running on http://localhost:3001' -ForegroundColor Cyan; ..\..\node_modules\.bin\dotenvx.cmd run -f ..\..\.env.local -- .\node_modules\.bin\tsx.cmd --tsconfig ../../tsconfig.json src/index.ts; Read-Host 'API server stopped. Press Enter to close'"
timeout /t 5 /nobreak >nul
start "Reactive Resume - Web app (port 3000)" %PS% "%INIT% Set-Location '%TARGET%'; Write-Host 'Starting web app, wait for: Local: http://localhost:3000' -ForegroundColor Cyan; pnpm dev:web; Read-Host 'Web app stopped. Press Enter to close'"

echo.
echo Two windows were opened:
echo   1. API server  - wait for "Up and running on http://localhost:3001"
echo   2. Web app     - wait for "Local: http://localhost:3000"
echo Then open http://localhost:3000 in your browser.
echo Close both windows to stop Reactive Resume.
echo.
pause
