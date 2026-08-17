---
name: fad-pipeline
description: >
  Router for the AI Delivery Pipeline (fad-*) family — brownfield style guardrails,
  PM-requirement-trace planning, Figma-driven execution, plan-gate checks, and
  release-gate verification. Use on "/fad-pipeline", "fad planner", "fad executor",
  "plan gate", "release gate", or any request naming one of the fad-* stages where
  you're not sure which specific specialist skill applies. Note: per this repo's own
  CLAUDE.md, this pipeline's supporting scripts/rules are not installed on every
  machine — confirm the underlying `.claude/scripts/`/`.claude/rules/` actually exist
  before assuming a fad-* skill can run end-to-end here.
---

# AI Delivery Pipeline (fad-*) — Router

Doesn't do the work itself — figures out which specialist skill the request actually
needs and invokes it via the `Skill` tool.

## Routing table

| If the request is about... | Invoke |
|---|---|
| Enforcing curated brownfield guardrails / approved conventions | `fad-brownfield-style` |
| Generating fixed-template delivery workbooks (.xlsx, EN/JA) | `fad-doc-export-spreadsheet` |
| Executing a plan with requirement trace + Figma-driven UI constraints | `fad-executor-ui-figma` |
| Verifying align-and-TDD planning gates before execution starts | `fad-plan-checker-gates` |
| PM requirement trace, one-sprint-per-phase planning, TDD scoping | `fad-planner-align` |
| Release-gate functional + DS-critical verification via browser automation | `fad-verifier-qc` |

## Fallback

If nothing above matches clearly, list the candidates above and ask which one fits
rather than guessing.
