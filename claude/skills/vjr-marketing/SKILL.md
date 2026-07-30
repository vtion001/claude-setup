---
name: vjr-marketing
description: Run marketing campaigns and reporting — content, marketing orchestration, analytics, SEO/Search Console. Use when the user says "run a campaign", "marketing", "create content", "weekly report", or "analytics".
---

# Marketing & Reporting

Business-wide process (not tied to one client): marketing-orchestrator + content-creator
(campaign) and data-analyst + search-console-analyst (reporting).

```bash
python3 vjros.py process market --campaign "Q3 lead-gen push"
```

## Honesty note
Marketing/reporting agents are **experimental** in v1 and may need keys/deps
(`GSC_CREDENTIALS_PATH`, `OPENAI_API_KEY`, pandas/matplotlib). The kernel degrades gracefully and
logs skips — relay them and offer to wire up the specific agent the user cares about.
