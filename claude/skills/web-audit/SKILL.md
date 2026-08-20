---
name: web-audit
description: >
  Router for web-app development, audits, and ops health — UI/UX/security/backend/QA/
  code audits, health checks, browser automation, deployment to Render, and endpoint
  probing. Use on "/web-audit", "audit my app", "full audit", "health check", "is
  everything up and running", "deploy to render", or any web dev/audit request where
  you're not sure which specific specialist skill applies.
---

# Web Dev / Audit — Router

Doesn't do the work itself — figures out which specialist skill the request actually
needs and invokes it via the `Skill` tool. For "audit everything"/"full audit sweep,"
prefer `audit-orchestrator` (it already fans out to 8 audits in parallel and merges the
report) over invoking individual audits one at a time.

## Routing table

| If the request is about... | Invoke |
|---|---|
| "Run all audits" / "full audit" / "audit everything" in one shot | `audit-orchestrator` |
| N+1 queries, caching, rate limits, resilience — backend/API performance | `backend-audit` |
| General codebase bug scan, agshub work-item filing | `code-audit` |
| Deploying a web app/database to Render, env vars, migrations | `deploying-to-render` |
| Full operational health check (build gates → frontend → deps → integrations → cron) | `doctor-health-check` |
| Making a self-hosted service on Windows/WSL2/Docker survive reboots | `hardening-self-hosted-uptime` |
| Automating a real browser from the terminal (nav, forms, screenshots) | `playwright` |
| Checking if specific data is reachable through an already-authed integration/API | `probing-integration-endpoints` |
| Page-by-page QA sweep of a running web app via Playwright | `qa-audit` |
| OWASP Top 10 / API Security audit (Burp Suite MCP, Playwright, source) | `security-audit` |
| UI implementation-quality audit (visual + source + design theory) | `ui-audit` |
| UI/UX design-intelligence — styles/palettes/font pairings/component generation | `ui-ux-pro-max` |
| Generating N distinct mockups of an existing UI page for stakeholder comparison | `ui-variant-review` |
| Whether a live UI "feels human" — design-quality audit via Playwright | `ux-audit` |

## Fallback

If nothing above matches clearly, list the candidates above and ask which one fits
rather than guessing.
