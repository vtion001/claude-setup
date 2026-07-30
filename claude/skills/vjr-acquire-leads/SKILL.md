---
name: vjr-acquire-leads
description: Find and qualify new leads in a niche/region, research them, and draft outreach. Use when the user says "find leads", "prospect <niche>", "get me clients in <industry>", or "acquisition".
---

# Acquire Leads

Runs the acquisition process: lead-generator → business-research → content-creator (outreach).

```bash
python3 vjros.py process acquire --niche "dental clinics" --region US
```

## Important honesty note
The acquisition agents are **experimental** in v1 — several need API keys or Python deps
(`GOOGLE_CREDENTIALS_PATH`, `AIRTABLE_API_KEY`, `OPENAI_API_KEY`, `bs4`, `python-dotenv`) and
`content-creator` is a prompt-spec (LLM-driven, not a script). The kernel degrades gracefully:
it runs what it can and logs clean skips for the rest. Relay those skips to the user and, if they
want full acquisition, offer to harden the specific agents (install deps / wire keys / adapt CLIs).
