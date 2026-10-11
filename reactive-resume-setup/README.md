# Reactive Resume: local install and setup

Steps to run [Reactive Resume](https://github.com/reactive-resume/reactive-resume) on your own computer, taken from the project's current `docs/contributing/development.mdx` (source checked 2026-10-11).

## Fastest path: run the setup script

**Windows:** from Command Prompt or File Explorer, run `setup-windows.cmd`. From PowerShell:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\setup-windows.ps1
```

**macOS / Linux:**

```bash
chmod +x setup-unix.sh
./setup-unix.sh
```

On Windows, `start-app.cmd` then starts the app in two windows, one for the API server and one for the web app (double-click it or run it from Command Prompt). It runs the server without file watching, which avoids a stall seen under `pnpm dev` on some Windows machines.

Both scripts install missing prerequisites where they can, clone the repo into `~/reactive-resume`, install dependencies, start the database containers, write `.env.local` with fresh secrets, and tell you the final command to run. Pass a folder as the first argument to clone somewhere else.

Docker Desktop is the one thing a script can't finish for you on Windows or macOS: after it installs, open Docker Desktop once, let it finish starting, then re-run the script.

## What you need

| Tool | Version | Why |
| --- | --- | --- |
| Git | any recent | clone the repo |
| Node.js | **24.x** (pinned in `.nvmrc` and `engines`) | run the server and build tools |
| pnpm | **12.x** (repo pins `pnpm@12.10.1` and auto-switches) | package manager |
| Docker + Docker Compose | current | PostgreSQL, Redis, SeaweedFS (S3 storage) |

## Manual steps

1. Clone and enter the repo:
   ```bash
   git clone https://github.com/reactive-resume/reactive-resume.git
   cd reactive-resume
   ```
2. Install dependencies:
   ```bash
   pnpm install --frozen-lockfile
   ```
3. Start the infrastructure (Docker Desktop must be running):
   ```bash
   docker compose -f compose.dev.yml up -d postgres redis seaweedfs seaweedfs_create_bucket
   docker compose -f compose.dev.yml ps
   ```
   Wait until the services show as healthy.
4. Create `.env.local` from `.env.example` and change the container hostnames to `localhost`:
   ```dotenv
   APP_URL=http://localhost:3000
   DATABASE_URL=postgresql://postgres:postgres@localhost:5432/postgres
   S3_ENDPOINT=http://localhost:8333
   REDIS_URL=redis://localhost:6379
   ```
   Set `AUTH_SECRET` and `ENCRYPTION_SECRET` to two different random 64-hex-character strings (`openssl rand -hex 32`).
5. Start the app:
   ```bash
   pnpm dev
   ```
   Open http://localhost:3000. Migrations run on startup.
6. Sign up. Without SMTP configured, the email verification link is printed in the `pnpm dev` terminal. Copy it into your browser.

## What `pnpm dev` runs

| Process | Address |
| --- | --- |
| Vite web app | http://localhost:3000 |
| Hono API server | http://localhost:3001 |
| Email template preview | http://localhost:3002 |

## Lighter option: skip S3 and Redis

Start only Postgres and store uploads on disk:

```bash
docker compose -f compose.dev.yml up -d postgres
```

In `.env.local` set `STORAGE_BACKEND=local` and leave `REDIS_URL` empty. Files go to `data/` inside the checkout.

## Troubleshooting

- **Port 3000 or 3001 in use**: change `PORT` / `SERVER_PORT` in `.env.local` and update `APP_URL` to match.
- **Database connection refused**: run `docker compose -f compose.dev.yml ps`; containers must be healthy. Local code connects to `localhost`, not `postgres`.
- **Upload errors**: check `S3_ENDPOINT=http://localhost:8333`, or switch to `STORAGE_BACKEND=local`.
- **AI features unavailable**: `ENCRYPTION_SECRET` must be at least 32 characters. Restart `pnpm dev` after changing it.
- **Windows: `pnpm` not recognized after install**: close and reopen the terminal so PATH refreshes.
