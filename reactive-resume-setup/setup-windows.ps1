# Reactive Resume local setup for Windows 10/11 (PowerShell 5.1 or 7).
# Usage:  Set-ExecutionPolicy -Scope Process Bypass; .\setup-windows.ps1 [TargetFolder]
$ErrorActionPreference = "Stop"
$Target = if ($args.Count -ge 1) { $args[0] } else { Join-Path $HOME "reactive-resume" }
$RepoUrl = "https://github.com/reactive-resume/reactive-resume.git"

function Step($msg) { Write-Host "`n==> $msg" -ForegroundColor Cyan }
function Have($cmd) { return [bool](Get-Command $cmd -ErrorAction SilentlyContinue) }
function RefreshPath {
  # Append newly installed tools without dropping paths fnm added to this session.
  $env:Path = $env:Path + ";" + [Environment]::GetEnvironmentVariable("Path", "Machine") + ";" + [Environment]::GetEnvironmentVariable("Path", "User")
}
function RandomHex($bytes) {
  $buf = New-Object byte[] $bytes
  [System.Security.Cryptography.RandomNumberGenerator]::Create().GetBytes($buf)
  return ($buf | ForEach-Object { $_.ToString("x2") }) -join ""
}

if (-not (Have winget)) {
  throw "winget (App Installer) is required. Install it from the Microsoft Store, then re-run this script."
}

Step "Git"
if (-not (Have git)) { winget install --id Git.Git -e --accept-source-agreements --accept-package-agreements; RefreshPath }
git --version

Step "Node.js 24 (via fnm)"
if (-not (Have fnm)) { winget install --id Schniz.fnm -e --accept-source-agreements --accept-package-agreements; RefreshPath }
fnm install 24
fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression
fnm use 24
fnm default 24
# Make Node 24 available in every future PowerShell window.
$fnmInit = 'fnm env --use-on-cd --shell power-shell | Out-String | Invoke-Expression'
if (-not (Test-Path $PROFILE)) { New-Item -ItemType File -Path $PROFILE -Force | Out-Null }
if (-not (Select-String -Path $PROFILE -Pattern 'fnm env' -Quiet)) { Add-Content -Path $PROFILE -Value $fnmInit }
$nodeMajor = (node -p "process.versions.node.split('.')[0]")
if ($nodeMajor -ne "24") { throw "Node.js 24 is required, found $(node --version). Run 'fnm use 24' and retry." }
node --version

Step "pnpm"
if (-not (Have pnpm)) {
  # Newer npm refuses pnpm's install scripts unless allowed explicitly.
  npm install -g pnpm --allow-scripts=pnpm
  if (-not (Have pnpm)) { npm install -g pnpm }
  if (-not (Have pnpm)) { corepack enable pnpm }
  RefreshPath
}
if (-not (Have pnpm)) { throw "pnpm did not install. Run 'npm install -g pnpm --allow-scripts=pnpm' manually, then re-run this script." }
pnpm --version

Step "Docker Desktop"
if (-not (Have docker)) {
  winget install --id Docker.DockerDesktop -e --accept-source-agreements --accept-package-agreements
  Write-Host "Docker Desktop was installed. Open it once, finish its setup (WSL 2 may require a reboot), then re-run this script." -ForegroundColor Yellow
  exit 0
}
function DockerUp {
  # docker prints to stderr when the engine is down; don't let strict mode turn that into an exception.
  $prev = $ErrorActionPreference; $ErrorActionPreference = "Continue"
  try { $null = & docker info 2>&1; return ($LASTEXITCODE -eq 0) } catch { return $false } finally { $ErrorActionPreference = $prev }
}
if (-not (DockerUp)) {
  $dd = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
  if (Test-Path $dd) {
    Write-Host "Starting Docker Desktop and waiting for the engine (up to 4 minutes)..."
    Start-Process $dd | Out-Null
    for ($i = 0; $i -lt 48 -and -not (DockerUp); $i++) { Start-Sleep -Seconds 5; Write-Host -NoNewline "." }
    Write-Host ""
  }
  if (-not (DockerUp)) {
    Write-Host "Docker's engine is still not running." -ForegroundColor Yellow
    Write-Host "Open Docker Desktop and look at its window: accept the agreement, and if it asks to install or update WSL 2, run 'wsl --install' in an Administrator PowerShell and restart Windows."
    Write-Host "Once Docker Desktop shows 'Engine running', re-run this script."
    exit 0
  }
}
docker --version

Step "Clone repository into $Target"
if (-not (Test-Path (Join-Path $Target ".git"))) { git clone $RepoUrl $Target }
Set-Location $Target

Step "Install dependencies (this takes a few minutes)"
pnpm install --frozen-lockfile

Step "Start PostgreSQL, Redis and SeaweedFS containers"
docker compose -f compose.dev.yml up -d postgres redis seaweedfs seaweedfs_create_bucket
docker compose -f compose.dev.yml ps

Step "Write .env.local"
if (-not (Test-Path ".env.local")) {
  $env_ = Get-Content ".env.example" -Raw
  $env_ = $env_ -replace '@postgres:5432', '@localhost:5432'
  $env_ = $env_ -replace 'http://seaweedfs:8333', 'http://localhost:8333'
  $env_ = $env_ -replace 'redis://redis:6379', 'redis://localhost:6379'
  $env_ = $env_ -replace 'AUTH_SECRET="[^"]*"', ('AUTH_SECRET="' + (RandomHex 32) + '"')
  $env_ = $env_ -replace 'ENCRYPTION_SECRET="[^"]*"', ('ENCRYPTION_SECRET="' + (RandomHex 32) + '"')
  Set-Content -Path ".env.local" -Value $env_ -NoNewline
  Write-Host ".env.local created with fresh secrets."
} else {
  Write-Host ".env.local already exists, leaving it unchanged."
}

Write-Host "`nSetup complete." -ForegroundColor Green
Write-Host "Start the app by running start-app.cmd in this folder, or from PowerShell with:`n    cd `"$Target`"`n    pnpm dev"
Write-Host "Then open http://localhost:3000 and sign up. The verification link is printed in the pnpm dev terminal."
