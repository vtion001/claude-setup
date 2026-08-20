---
name: vjr-business
description: >
  Router for VJR Digital Solutions business operations — the VJR-OS lifecycle
  (leads/proposals/delivery/quote-to-cash/status), WhatsApp voice-matched
  messaging, Six Sigma process work, client feedback triage, and stakeholder
  deliverables (demo packages, onboarding tours, delivery reports). Use on
  "/vjr-business", "vjr-os", "my pipeline", "quote a client", "deliver a
  project", "wacli message", "six sigma", or any VJR business-operations
  request where you're not sure which specific specialist skill applies.
---

# VJR Business — Router

Doesn't do the work itself — figures out which specialist skill the request actually
needs and invokes it via the `Skill` tool.

## Routing table

| If the request is about... | Invoke |
|---|---|
| Finding/qualifying new leads and drafting outreach | `vjr-acquire-leads` |
| Cross-referencing a client's real Gmail/WhatsApp against their CRM record | `vjr-client-sync` |
| Finding/scaffolding/pulse-checking a WhatsApp community (not a client) | `vjr-community-sync` |
| Kicking off delivery for a signed client (planning/build/QA) | `vjr-deliver-project` |
| Building a legal/regulatory dispute case file and strategy | `vjr-legal-case-file` |
| Running marketing campaigns, content, SEO/Search Console reporting | `vjr-marketing` |
| Pushing session context into Vincent's own OpenClaw/Telegram agent | `vjr-notify-openclaw` |
| Activating VJR-OS itself (the agent+process registry) | `vjr-os` |
| Generating a priced proposal/service agreement/deposit invoice | `vjr-quote-to-cash` |
| Business dashboard — pipeline by lifecycle stage, or one client's history | `vjr-status` |
| Drafting any WhatsApp message on Vincent's behalf (voice-matched via wacli) | `wacli-msg` |
| Six Sigma DMAIC for business ops (Marketing/Sales/CS/Ops/Finance/People) | `six-sigma-business` |
| Six Sigma DMAIC for software quality/delivery, defect scoring | `six-sigma-mbb` |
| Turning client/stakeholder feedback into a structured plan | `client-feedback-cross-reference` |
| A stakeholder-ready demo video + brand-styled PDF package | `product-demo-package` |
| A first-run guided tour / in-app Help Center (Vue 3 + Laravel) | `on-boarding-generator` |
| A project progress/status/delivery/milestone report for a client | `writing-delivery-reports` |

## Fallback

If nothing above matches clearly, list the candidates above and ask which one fits
rather than guessing.
