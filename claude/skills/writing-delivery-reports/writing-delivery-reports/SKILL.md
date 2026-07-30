---
name: writing-delivery-reports
description: Use when a client or stakeholder needs a project progress report, status update, delivery summary, milestone/acceptance record, or system/architecture documentation — especially when the report supports sign-off, milestone acceptance, or protecting payment/receivables.
---

# Writing Delivery Reports

## Overview
A delivery report tells a client **what shipped, what's next, what's at risk, and what you need from them** — and doubles as an **acceptance record** that maps delivered work to milestones so invoicing is clean and disputes have a paper trail. Core principle: **report outcomes, not activities, and claim only what's verified.**

## When to use
- Client/stakeholder asks for a progress report, status update, or "where are we."
- End of a sprint/phase, or before a milestone invoice / sign-off.
- Documenting system architecture for handover or onboarding.
- Any report that a human acts on for **payment, acceptance, or a go/no-go**.

**Not for:** internal-only stand-up notes (lead with capacity/blockers instead), or a commit message.

## The two-part structure

**Part 1 — Progress (client-facing).** Lead with deliverables + status, not internals.
1. **Header + overall RAG** (🟢/🟡/🔴) — status at a glance.
2. **Executive summary** — 3–5 sentences a non-technical sponsor understands.
3. **Delivered this period** — a table of *outcomes* ("dashboard now shows real data") with a **status** and **evidence** column (PR #, passing tests, live verification). This is the acceptance record.
4. **In progress** / **Upcoming (next, prioritised)** — set expectations; don't dump the backlog.
5. **Risks & mitigations** — specific, with severity + effort + a mitigation. Vague ≠ useful.
6. **Decisions needed** — the explicit asks that unblock you (and protect timeline).
7. **Milestone / acceptance ledger** — *what was agreed → delivered → evidence*. The receivables trail: sign-off and invoices map to shipped, verified work.

**Part 2 — System documentation** (C4 / arc42-lite; skip if pure status update).
1. **System overview** (conceptual — user value, in plain language).
2. **Containers** — table: each major piece, its tech, its responsibility.
3. **Key data flows** (component view — how data moves between parts).
4. **Notable components** / recent additions.
5. **Environments & operations** (build, deploy, config/secrets posture).
6. **Quality gates** (tests, type-checks, "docs updated with every change").

**Appendix:** audit/quality scorecard, evidence links, methodology references.

## Non-negotiable rules
- **Outcomes, not activities.** "Launched X" not "worked on X."
- **Verified-only claims.** In a report that drives payment, never state something as delivered unless it's actually done and checked. Mark in-progress as in-progress. (A fabricated "done" is the fastest way to lose trust — and receivables.)
- **RAG honestly.** If an area is amber/red, say so with the mitigation; a report that's all-green and wrong destroys credibility on the next one.
- **Every delivered item gets evidence** (PR/commit, test result, screenshot/live check) — that column *is* the receivables protection.
- **Specific risks.** "API rate limits block sync testing, need infra review Thu" > "some issues."

## Delivery
- Write as **Markdown** (portable, diff-able, sendable). Put it in the repo (`docs/`) so it versions with the work.
- Client-facing polish needed? Render to an **Artifact** (private web page) or PDF.
- Send channel (Slack/Telegram/email) on request — e.g. Telegram: `python3 ~/.claude/scripts/tg_send.py --file <report.md> --caption "<one-line status>"`.

## Common mistakes
- Listing activities/hours instead of shipped outcomes → client can't tell what they got.
- Burying or omitting the acceptance/evidence mapping → invoice disputes.
- Over-claiming ("done" when it's 80%) → trust + payment risk.
- Technical wall-of-text with no exec summary/RAG → sponsor doesn't read it.
- One giant internal+client report → keep the client version outcome-led; internals go elsewhere.

## Reference
Worked example: `bricklane-property-group/docs/DELIVERY-REPORT-2026-07-18.md` (progress + system doc + audit appendix, grounded in real PRs/tests).
Methodology: Teamwork/Atlassian status-report guidance; freelance milestone-payment practice (document the trail); arc42 / C4 for the system-doc structure.
