// Diagnostic runner: starts the Reactive Resume server step by step with timestamps,
// so a stall or silent exit shows exactly where it happens. Copy into apps/server/src/.
const t = () => new Date().toISOString().slice(11, 19);
const log = (msg: string) => console.log(`[${t()}] ${msg}`);

process.on("exit", (code) => log(`process exiting with code ${code}`));
process.on("uncaughtException", (e) => { log("uncaughtException"); console.error(e); });
process.on("unhandledRejection", (e) => { log("unhandledRejection"); console.error(e); });

log("1. node " + process.version + ", importing env");
const { env } = await import("@reactive-resume/env/server");
log(`2. env ok (SERVER_PORT=${env.SERVER_PORT}, STORAGE_BACKEND=${env.STORAGE_BACKEND ?? "auto"})`);

const { runDatabaseMigrations } = await import("./startup/checks");
log("3. running migrations + schema check");
await runDatabaseMigrations();
log("4. migrations done, importing agent runs (loads the api package)");
const { reapStaleAgentRunsAtBoot } = await import("@reactive-resume/api/features/agent/runs");
log("5. api package loaded, reaping stale runs");
await reapStaleAgentRunsAtBoot();
log("6. reap done, importing http/app");
const { createApp } = await import("./http/app");
log("7. http/app loaded, importing auth");
const { initializeAuth } = await import("@reactive-resume/auth/config");
log("8. auth loaded, initializing");
await initializeAuth();
log("9. auth initialized, creating app");
const app = createApp();
log("10. app created, starting listener");
const { serve } = await import("@hono/node-server");
serve({ fetch: app.fetch, port: env.SERVER_PORT }, (info) => log(`11. UP on http://localhost:${info.port}`));
