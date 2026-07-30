---
name: vjr-quote-to-cash
description: Generate a priced proposal, service agreement, and deposit invoice (PDF) for a client and advance them to "proposed". Use when the user says "quote <client>", "make a proposal/contract/invoice", "price up <client>", "send <client> a proposal", or wants the full quote-to-cash run.
---

# Quote-to-Cash

Runs intake → market/price research → proposal → contract → invoice, saves branded PDFs to
`clients/<slug>/`, and advances the client to stage `proposed`.

## Gather before running
- **client** (required) and company name
- **services** (comma-separated, from the catalog: AI Agent Assistance, Virtual Assistant,
  Full Stack Development, Data Analysis, Process Automation, Business Intelligence,
  Cloud Solutions, Technical Consulting)
- **region**: AU | US | PH (drives currency + market rates + governing law)
- optional: scope, discount %, `--telegram` to deliver PDFs to Telegram, `--live` for live rate research

If the user hasn't given services/region, ask before running.

## Run (from repo root)
```bash
python3 vjros.py process quote-to-cash \
  --client "Acme" --company "Acme Pty Ltd" \
  --services "Full Stack Development,Process Automation" --region US \
  --scope "Replace manual order entry with a web app." --discount 10 --telegram
```

Then confirm the three PDFs in `clients/acme/` and the new stage via `vjros status --client "Acme"`.
