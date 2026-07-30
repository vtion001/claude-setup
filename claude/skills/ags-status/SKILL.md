---
name: ags-status
description: Show Render service health and Docker stack status for the AGS-Dev environment. Invoke when user asks "service status", "is render up", "deployment status", "check services", "what's running", "are the services up", "check bob-ags", or asks about any specific Render service status.
---

# AGS Service Status

## What to do

1. Run `python3 /mnt/d/ags-dev-os/agsdev.py status`
2. Present Render service statuses clearly — flag any suspended or failing services
3. If user asked about a specific service, also run `python3 /mnt/d/ags-dev-os/agsdev.py logs <service>` to get recent logs
4. If Docker stacks are relevant, mention which are running via `docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "prometheus|grafana|jenkins|sonarqube"`

## Service reference

**Active services:**
- bob-ags (Oregon Starter) — https://bob-ags.onrender.com
- mca-tracker (Oregon Starter) — https://mca-tracker-hsy7.onrender.com
- ags-email-tool-api (Ohio Starter) — https://ags-email-tool-api.onrender.com
- ags-email-tool-ui (Static) — https://ags-email-tool-ui.onrender.com
- ags-email-api (Oregon Free) — https://ags-email-api.onrender.com
- ghl-mcp-lc (Ohio Free) — https://ghl-mcp-lc.onrender.com
- ghl-mcp-afg (Ohio Free) — https://ghl-mcp-afg.onrender.com

**Suspended:**
- ags-break-tracker, ags-phillies-kpi (user-suspended, free tier)

## Interpreting results

- Suspended services spin up on first request (cold start ~30s on free tier)
- Ohio region = US East; Oregon region = US West
- If bob-ags health endpoint fails, check: `python3 /mnt/d/ags-dev-os/agsdev.py logs bob-ags`
