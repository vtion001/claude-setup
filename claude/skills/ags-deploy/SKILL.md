---
name: ags-deploy
description: Deploy a service to Render. Invoke when user says "deploy X to render", "push release", "trigger deploy", "redeploy", "deploy bob-ags", "push to production", or asks to deploy any of the AGS Render services.
---

# AGS Deploy

## What to do

1. Identify which service the user wants to deploy
2. Confirm the service name maps to a known Render service
3. Run: `python3 /mnt/d/ags-dev-os/agsdev.py deploy <service>`
4. Report the deploy ID and dashboard link
5. Optionally tail logs: `python3 /mnt/d/ags-dev-os/agsdev.py logs <service>`

## Service names

| User says | Service name |
|-----------|-------------|
| "bob-ags", "main app", "production" | `bob-ags` |
| "mca tracker", "afg tracker", "mca" | `mca-tracker` |
| "email tool api", "email api", "email backend" | `ags-email-tool-api` |
| "email ui", "email frontend" | `ags-email-tool-ui` |
| "ags email api", "legacy email" | `ags-email-api` |
| "ghl lc", "ghl mcp lc" | `ghl-mcp-lc` |
| "ghl afg", "ghl mcp afg" | `ghl-mcp-afg` |

## Notes

- Suspended services cannot be deployed — user must resume on Render dashboard first
- Auto-deploy is enabled on all services (pushes to `main` trigger deploy automatically)
- Manual deploy via this skill forces an immediate redeploy without code change
- Free tier services have cold starts on first request after inactivity
