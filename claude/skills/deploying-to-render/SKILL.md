---
name: deploying-to-render
description: Use when deploying a web app (or full-stack app + database) to Render from this machine — creating web services, managed Postgres, wiring env vars, triggering deploys, running migrations, or debugging a 500/build failure on Render. Covers Docker services, Blueprints, and the single-origin SPA+API pattern via the Render CLI, for any stack (Node, PHP, Python, …).
---

# Deploying to Render (CLI)

## Overview

Ship any web app to Render's global network from this computer using the **Render CLI**
(`D:\render-cli\render.exe`, alias `render`). Core pattern for full-stack apps: **one Docker web
service serving both the built frontend and the API on a single origin**, plus a **managed
Postgres** — no CORS, relative `/api` works, one URL.

The deploy *shape* is stack-agnostic (Docker service + Postgres + verify triad). Framework-specific
traps are flagged **[framework-specific]** with a worked CI4/PHP example — read the principle, then
apply it to your stack.

**This machine's setup:** CLI lives at `D:\render-cli\render.exe`. It is NOT on PATH — invoke the
full path (or `R="D:/render-cli/render.exe"`). Authenticated as **AGS Dev**
(`agsdev@allianceglobalsolutions.com`).

## Prerequisites

1. **Login is interactive and browser-based.** `render login` opens the dashboard; it must run in a
   **real terminal** the user controls, not a tool-run shell (a headless run writes an empty token).
   Verify with `render whoami` → expects a Name/Email. If it fails, ask the user to run
   `! D:\render-cli\render.exe login` themselves.
2. **Code is on a Git provider connected to Render** (GitHub/GitLab). `--repo <url>` and
   auto-deploy require the repo to be pushed and the provider linked in the Render account. A
   brand-new repo needs that one-time connection in the dashboard first.

## Quick reference

| Task | Command |
|------|---------|
| Who am I | `render whoami` |
| List services / find IDs | `render services -o json` |
| Create Postgres (do this FIRST) | `render postgres create --name X-db --plan basic_256mb --region oregon -o json` |
| **Get DB password / conn string** | `render postgres get <dpg-id> --include-sensitive-connection-info -o json` |
| Create web service (Docker) | `render services create --name X --type web_service --runtime image --repo <url> --branch main --plan starter --region oregon --health-check-path /api/health --env-var DATABASE_URL=<internal-conn-str> --pre-deploy-command "<migrate cmd>" -o json` |
| Trigger deploy + stream logs | `render deploys create <srv-id>` |
| List deploys (status) | `render deploys list <srv-id> -o json` |
| Tail logs | `render logs --resources <srv-id> --tail` |
| psql into the DB | `render psql <dpg-id>` |

Add `--confirm` to skip prompts non-interactively. `-o json` is required for parsing (the CLI
auto-switches to `text` on a non-TTY). `--plan`/`--region` shown are examples — they are choices.

## Setting environment variables (read this — it has a sharp edge)

- **On the imperative CLI path:** pass `--env-var KEY=VALUE` (repeatable) to `render services
  create`. This is the ONLY way the CLI sets env vars — **`render services update` has no env-var
  flag.**
- **After creation, to add/change env vars:** use the Render **MCP**
  `mcp__render__update_environment_variables`, the dashboard, or a Blueprint redeploy. (The MCP is
  fine here — its only limitation is that it *cannot create Docker services*, see Gotcha 1. Use it
  freely for env vars, logs, deploys, metrics.)
- **On the Blueprint path:** `render.yaml` sets them declaratively, and
  `fromDatabase: { property: connectionString }` injects the DB URL automatically. **`fromDatabase`
  is a Blueprint-only construct — it does nothing on the `services create` path**, where you must
  pass `--env-var DATABASE_URL=<internal connection string>` yourself.

**Pick one path:** Blueprint (`render.yaml` + dashboard "New → Blueprint") for reproducible infra,
OR imperative `render ... create` calls for a quick one-off. Don't mix — `fromDatabase` won't fire
for a CLI-created service.

## The reliable path (single-origin Docker + Postgres)

1. **Put the `Dockerfile` where the build context expects it.** There is **no `--dockerfile-path`
   flag** — the build looks for `./Dockerfile` at the repo root (or at `--root-directory`). For a
   monorepo, move the Dockerfile to root or set `--root-directory`; build context = repo root so the
   image can `COPY` both the web and api folders.
2. **Single-origin Dockerfile** (multi-stage): a build stage compiles the SPA (`npm run build` →
   `dist/`); the serve stage copies that `dist/` into the API's static web root and routes `/api/*`
   to the backend, everything else to the SPA entry point (history-mode fallback). One server, one
   port.
   - *Node/Express:* `express.static(dist)` + a catch-all `app.get('*', … res.sendFile(index.html))`
     ordered AFTER the `/api` routes.
   - *PHP/Apache [framework-specific]:* copy `dist/` into `public/`; `.htaccess` routes `^api →
     index.php`, `^ → index.html` (and see Gotcha 4).
3. **Add the health route in app code.** `--health-check-path /api/health` assumes that endpoint
   exists and returns 200 — you must write it.
4. **Bind to `$PORT`.** Render sets `$PORT` (often 10000); the server MUST listen on it
   (`process.env.PORT` / Apache `Listen $PORT` in the entrypoint).
5. **Create Postgres FIRST, then the web service** (the service needs the DB's connection string).
   Grab the **internal** connection string (Gotcha 5) and pass it as `DATABASE_URL`.
6. **Deploy:** `git push` (auto-deploy is on by default) or `render deploys create <srv-id>`.

## Running migrations

Migrations are your responsibility — Render doesn't run them. Two clean options:

- **`--pre-deploy-command "<migrate>"`** on the service — runs once per deploy before traffic
  shifts (`npx prisma migrate deploy`, `knex migrate:latest`, `php spark migrate --all`,
  `alembic upgrade head`, …). Preferred: a failed migration fails the deploy.
- **In the container entrypoint/start script**, before starting the server. Simpler, but a failed
  migration can still boot a broken app unless you guard it.

The log line proving success is stack-specific (CI4 prints `Migrations complete.`; Prisma prints
`All migrations have been successfully applied.`). Grep the boot logs for your tool's equivalent.

## Critical gotchas (each cost a real debugging cycle)

**1. The Render MCP cannot create Docker services.** `mcp__render__create_web_service`'s runtime
enum is node/python/go/rust/ruby/elixir — no `docker`. Use the **CLI** (`services create --runtime
image`) or a Blueprint for anything containerized. (The MCP is still the best tool for env vars,
`list_logs`, `list_deploys`, `get_metrics`.)

**2. Config keys with DOTS break as OS env vars. [framework-specific — any framework using dotted
config]** Some frameworks override config via dotted keys — CI4: `database.default.hostname`,
`app.baseURL`, `email.SMTPPass`. **Dots are illegal in OS environment-variable names**: neither the
shell nor most runtimes' `getenv()` can read them, so Render stores them but the app never sees them
and silently falls back to config defaults (e.g. the *local dev* DB `127.0.0.1` → HTTP 500 on every
DB write, while `/health` and static pages still work). **Fix:** pass **underscore-named** vars
(`DATABASE_URL`, `APP_BASE_URL`, …) and have the container's `start.sh` translate them into a real
`.env` file, where dotted keys ARE valid because the framework parses that file itself:
```sh
{ echo "app.baseURL=${APP_BASE_URL}"
  # parse DATABASE_URL=postgresql://user:pass@host[:port]/db into database.default.* lines
} > /var/www/html/.env
```
**Node/Python don't have this problem** — they read `process.env.DATABASE_URL` / `os.environ`
directly with underscore names; no `.env`-bridge needed. The trap only bites frameworks with a
dotted-key config layer. Symptom fingerprint: build succeeds, health 200, SPA loads, but **every
write endpoint 500s** and boot logs show the app connecting to `127.0.0.1` / a dev host.

**3. Native driver extension, not just the ORM/PDO one. [framework-specific — PHP]** CI4's
`DBDriver=Postgre` uses the **native `pgsql`** extension (`pg_connect`), not `pdo_pgsql`. Install
both: `docker-php-ext-install pdo pdo_pgsql pgsql`. Missing it → `CriticalError` at `Database.php`
on migrate. (General principle: confirm your image has the DB driver your framework actually calls,
not just a lookalike — e.g. `psycopg2` vs `asyncpg` for Python.)

**4. SPA root serves the framework welcome page. [framework-specific — Apache/PHP]** When `/`
resolves to the public dir, Apache's `DirectoryIndex` may serve `index.php` (framework welcome)
instead of the SPA. Add `DirectoryIndex index.html`. (General principle: make sure `/` maps to the
SPA entry, not a default index the runtime injects.)

**5. The DB password isn't in normal output.** `render postgres get` hides it; add
`--include-sensitive-connection-info -o json` to get `internalConnectionString`. Use the
**internal** host for service→DB traffic (same-datacenter, no SSL hassle); the external host
requires `sslmode=require`.

## Verify a deploy

```sh
BASE=https://<service>.onrender.com
curl -s -o /dev/null -w '%{http_code}\n' "$BASE/api/health"          # 200
curl -s "$BASE/" | grep -o '<title>[^<]*</title>'                    # SPA title, not framework welcome
curl -s -X POST "$BASE/api/<write-endpoint>" -H 'Content-Type: application/json' -d '{...}'  # NOT 500
```
Then confirm migrations ran in boot logs (`render logs --resources <srv-id> --tail`, or MCP
`list_logs`). A build that is `live` but 500s on **writes** almost always means Gotcha 2.

## Common mistakes

| Mistake | Fix |
|---------|-----|
| Using the MCP to create a Docker service | Use the CLI or a Blueprint (Gotcha 1) |
| Expecting `render services update` to set env vars | It can't; use `--env-var` on create, or the MCP/dashboard after |
| Expecting `fromDatabase` to work on a CLI-created service | Blueprint-only; pass `--env-var DATABASE_URL=<internal>` for CLI |
| Setting dotted keys as Render env vars (CI4 etc.) | Underscore names + `.env` bridge (Gotcha 2) |
| Assuming Render runs your migrations | `--pre-deploy-command` or entrypoint |
| Creating the web service before the DB | Create Postgres first; it owns the connection string |
| `render login` in a tool shell | Have the user run it in their own terminal |
| Parsing CLI output that came back as text | Add `-o json` |
| Trusting a green build = working app | Curl a **write** endpoint; confirm migrations in logs |

## Secret hygiene

Never type a raw API key or DB/SMTP password into a command or file on the user's behalf — have the
user set secrets in the dashboard (`sync: false` env vars) or supply them via their own action. If a
secret appears in the transcript, tell the user to **rotate** it.
