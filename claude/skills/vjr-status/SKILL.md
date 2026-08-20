---
name: vjr-status
description: Show the VJR business dashboard — clients grouped by lifecycle stage, or one client's full history and artifacts. Use when the user asks "what's my pipeline", "business status", "where is <client>", "what's the state of the business", or "show clients".
---

# VJR Business Status

Run from the repo root (`~/Desktop/VJR-Digital-Solutions`):

```bash
python3 vjros.py status                 # whole pipeline, grouped by stage
python3 vjros.py status --client "Acme" # one client: stage, services, artifacts, history
```

Report the output back conversationally: how many clients at each stage, and for a single
client, its current stage, the artifacts in `clients/<slug>/`, and the most recent history entry.
