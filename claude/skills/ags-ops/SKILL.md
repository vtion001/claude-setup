---
name: ags-ops
description: >
  Router for the AGS-Dev environment — deploying to Render, starting/stopping the
  local Docker dev stack, monitoring/observability dashboards, and overall system
  status. Use on "/ags-ops", "deploy to render", "start dev", "is render up",
  "monitoring dashboards", "ags status", or any AGS-Dev infra request where you're
  not sure which specific specialist skill applies.
---

# AGS-Dev Ops — Router

Doesn't do the work itself — figures out which specialist skill the request actually
needs and invokes it via the `Skill` tool.

## Routing table

| If the request is about... | Invoke |
|---|---|
| Deploying a service to Render (push release, redeploy, trigger deploy) | `ags-deploy` |
| Starting/stopping the local AGS dev environment (Docker stacks) | `ags-dev` |
| Monitoring/observability dashboard URLs (Grafana, Prometheus, etc.) | `ags-monitor` |
| "What can the OS do" — full system overview (Render, Docker, repos, team) | `ags-os` |
| Render service health / Docker stack status check | `ags-status` |

## Fallback

If nothing above matches clearly, list the candidates above and ask which one fits
rather than guessing.
