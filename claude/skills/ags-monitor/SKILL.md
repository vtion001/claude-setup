---
name: ags-monitor
description: Show all monitoring and observability dashboard URLs for the AGS-Dev environment. Invoke when user asks "open grafana", "monitoring dashboards", "check metrics", "where is prometheus", "show me the dashboards", "observability URLs", "check alerts", or asks about any monitoring tool.
---

# AGS Monitoring Dashboards

## What to do

Run `python3 /mnt/d/ags-dev-os/agsdev.py monitor` and present the output.

## Dashboard reference

| Tool | URL | Credentials | Purpose |
|------|-----|-------------|---------|
| **Grafana** | http://localhost:3000 | admin / admin | Dashboards + unified alerting |
| **Prometheus** | http://localhost:9090 | — | Metrics + alert rules |
| **Jaeger** | http://localhost:16686 | — | Distributed tracing |
| **Loki** | http://localhost:3100 | — | Log aggregation (via Grafana) |
| **SonarQube** | http://localhost:9001 | admin / admin | Code quality |
| **Jenkins** | http://localhost:8080 | admin / admin123! | CI/CD |
| **Drone** | http://localhost:8888 | GitHub OAuth | GitHub-integrated CI |
| **Blackbox** | http://localhost:9115 | — | Endpoint health probes |
| **Render Exporter** | http://localhost:9877/metrics | — | Render deploy metrics |

## Grafana — Key Dashboards

- **BOB-AGS Full Stack Monitor** — 24 panels: production health, Render fleet, observability stack
- Access: Dashboards → Browse → BOB-AGS Full Stack Monitor

## Alerting

Alerts fire to Telegram when:
- BOB-AGS health endpoint down > 2 min
- Response time > 3000ms for > 5 min
- 1h uptime below 95%
- SSL cert expiring in < 14 days
- Any Render service suspended
- Any deploy failure
- Prometheus target down > 5 min

**Telegram:** Bot `${TELEGRAM_BOT_TOKEN}...` → Chat ID `${TELEGRAM_CHAT_ID}`

## Render Production Links

- bob-ags health: https://bob-ags.onrender.com/health
- mca-tracker: https://mca-tracker-hsy7.onrender.com
- ags-email-tool-api: https://ags-email-tool-api.onrender.com
- ags-email-tool-ui: https://ags-email-tool-ui.onrender.com
