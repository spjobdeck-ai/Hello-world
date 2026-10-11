#!/usr/bin/env bash
# Reactive Resume local setup for macOS and Linux.
# Usage: ./setup-unix.sh [target-folder]
set -euo pipefail
TARGET="${1:-$HOME/reactive-resume}"
REPO_URL="https://github.com/reactive-resume/reactive-resume.git"

step() { printf '\n==> %s\n' "$1"; }
have() { command -v "$1" >/dev/null 2>&1; }

step "Git"
have git || { echo "Git is missing. Install it (macOS: xcode-select --install, Debian/Ubuntu: sudo apt-get install -y git) and re-run."; exit 1; }
git --version

step "Node.js 24 (via fnm)"
if ! have fnm; then
  curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
  export PATH="$HOME/.local/share/fnm:$HOME/.fnm:$PATH"
fi
eval "$(fnm env)"
fnm install 24
fnm use 24
[ "$(node -p 'process.versions.node.split(".")[0]')" = "24" ] || { echo "Node.js 24 is required, found $(node --version)."; exit 1; }
node --version

step "pnpm"
have pnpm || npm install -g pnpm
pnpm --version

step "Docker"
if ! have docker; then
  echo "Docker is missing. Install Docker Desktop (macOS) or Docker Engine + the compose plugin (Linux), start it, then re-run."
  exit 1
fi
docker info >/dev/null 2>&1 || { echo "Docker is installed but not running. Start it and re-run."; exit 1; }

step "Clone repository into $TARGET"
[ -d "$TARGET/.git" ] || git clone "$REPO_URL" "$TARGET"
cd "$TARGET"

step "Install dependencies (this takes a few minutes)"
pnpm install --frozen-lockfile

step "Start PostgreSQL, Redis and SeaweedFS containers"
docker compose -f compose.dev.yml up -d postgres redis seaweedfs seaweedfs_create_bucket
docker compose -f compose.dev.yml ps

step "Write .env.local"
if [ ! -e .env.local ]; then
  cp .env.example .env.local
  AUTH=$(openssl rand -hex 32); ENC=$(openssl rand -hex 32)
  sed -i.bak \
    -e 's#@postgres:5432#@localhost:5432#' \
    -e 's#http://seaweedfs:8333#http://localhost:8333#' \
    -e 's#redis://redis:6379#redis://localhost:6379#' \
    -e "s#^AUTH_SECRET=.*#AUTH_SECRET=\"$AUTH\"#" \
    -e "s#^ENCRYPTION_SECRET=.*#ENCRYPTION_SECRET=\"$ENC\"#" \
    .env.local && rm -f .env.local.bak
  echo ".env.local created with fresh secrets."
else
  echo ".env.local already exists, leaving it unchanged."
fi

printf '\nSetup complete.\nStart the app with:\n    cd "%s"\n    pnpm dev\nThen open http://localhost:3000 and sign up. The verification link is printed in the pnpm dev terminal.\n' "$TARGET"
