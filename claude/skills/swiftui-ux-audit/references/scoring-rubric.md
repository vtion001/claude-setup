# SwiftUI UX Audit — Scoring Rubric

This rubric is the SwiftUI sibling of the web `/ux-audit` rubric at
`/Users/archerterminez/.claude/skills/ux-audit/references/scoring-rubric.md`.
Most of it is identical. This file documents the deltas and re-prints the parts
needed for fast lookup. **For the canonical DQS formula, per-pass 1–5 criteria,
DQS range interpretation, and severity-to-Linear-priority mapping, read the
web rubric verbatim — they are unchanged.**

---

## Pass weights (14-pass, weighted total = 26)

| Weight | Pass | Rationale |
| --- | --- | --- |
| 3× | Visual hierarchy | Core usability driver |
| 3× | Emotional design | Brand + engagement |
| 3× | Nielsen heuristics | Foundational usability |
| 2× | Typography | Readability |
| 2× | Color | A11y + brand |
| 2× | Spacing & rhythm | Perceived quality |
| 2× | Micro-interactions | Perceived responsiveness |
| 2× | Accessibility (XCUI) | Legal + ethical (replaces web "WCAG" pass) |
| 2× | **Design tokens (NEW)** | Cross-file consistency at the source level |
| 1× | Laws of UX | Design maturity |
| 1× | Dark patterns | Trust |
| 1× | Device classes | Cross-device quality (replaces web "Mobile responsiveness") |
| 1× | Trust signals | Conversion + credibility |
| 1× | Performance perception | Perceived speed |

**Total weight: 26. Maximum raw score: 130 (26 × 5).**

```
DQS = (sum of (pass_score × weight) / 130) × 100
```

## DQS range — identical to web

| Range | Rating | Action |
|---|---|---|
| 90–100 | Ship-ready | Polish in backlog |
| 75–89 | Good | Address high/medium before next release |
| 60–74 | Needs attention | UX-debt sprint capacity |
| 40–59 | Design debt | Dedicated UX sprint, block features |
| <40 | Start over | Engage design lead for redesign |

## Severity → Linear priority — identical to web

| Severity | Linear priority | SLA |
| --- | --- | --- |
| Critical | Urgent | Fix before next deployment |
| High | High | Fix within current sprint |
| Medium | Medium | Fix within next 2 sprints |
| Low | Low | Backlog grooming |

## Design Consistency Score (DCS) — SwiftUI dimension swap

The DCS methodology is identical to the web rubric (sum of consistent / total
× 100). Two dimensions change for SwiftUI:

| Dimension | What's checked | Weight |
| --- | --- | --- |
| Color tokens | Same semantic colors used for same purpose. **Adapted:** `Color.<tokenName>` usage matches across pages; `Color(hex:)` outside `Models/` is flagged | 20% |
| Typography scale | Consistent `PukaTypography.*` usage. **Adapted:** raw `.font(.system(...))` is a deduction | 20% |
| Spacing system | Adherence to spacing tokens. **Adapted:** raw `.padding(N)` integer-literal usage is a deduction | 15% |
| Component variants | Same SwiftUI view styled the same way across pages | 20% |
| Interactive states | Hover/focus/pressed handled consistently (SwiftUI `.buttonStyle`, `.pressedStyle`) | 10% |
| Border radii | Consistent `.cornerRadius(...)` value or modifier (`.pukaCard()`) | 5% |
| Shadow system | Same elevation = same shadow OR same modifier | 5% |
| Icon sizing | SF Symbols sized consistently per context | 5% |

DCS interpretation is identical to web (≥90 / 75–89 / 60–74 / <60 bands).

## Per-tab scorecard

Use the same ASCII box from the web rubric, but title rows as:

- "PAGE SCORECARD" → "TAB SCORECARD"
- "URL: /route/path" → "Entry: <tab name>"

All 14 passes appear in the score table (web has 13). The new line is:

```
│  Design Tokens             ███░░  2x   3     6      │
```

Inserted between Accessibility and Laws of UX.

## What's deliberately the same as the web rubric

To minimize duplication and divergence, the following are **read directly
from** `/Users/archerterminez/.claude/skills/ux-audit/references/scoring-rubric.md`
at audit time and not re-printed here:

- The full 1–5 per-pass criteria (Excellent / Good / Adequate / Below standard / Critical)
- The DQS formula derivation
- The DCS formula
- The full severity criteria (Critical / High / Medium / Low examples)
- The multi-page summary template

If the web rubric changes, the SwiftUI audit picks up the change for free.
