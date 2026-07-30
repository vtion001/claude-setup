# Doc-Agent Prompt Templates

Dispatch **one general-purpose agent per document, in a single message** (parallel). Each agent writes ONE Markdown file and inherits none of your context, so every prompt is fully self-contained. Verbatim worked examples (system doc, migration plan, meeting brief) are in `runbook.md` Task 2 — reuse and adapt them.

## The template (fill the `<…>`)

> Write a **`<DOC TYPE>`** for **`<APP NAME>`** as Markdown to **`<absolute output path>/<slug>.md`**.
> AUDIENCE: `<who reads it>` — `<exec | technical | mixed>`; it will be rendered to a polished PDF.
> WHAT THE APP IS: `<2–3 factual sentences: purpose, stack, source-of-truth>`.
> VERIFY every claim against the real code — read: `<explicit list of files/dirs>`. Use `mcp__lumen__semantic_search` to navigate.
> CRITICAL GUARDRAILS: `<the exact facts an earlier draft is likely to get wrong — state them right>`. Do NOT print secrets/API keys. For any external-system specifics you cannot confirm from THIS repo, mark them **"to verify"** — do not assert them as settled.
> STRUCTURE: `<numbered section list, each with what it must contain>`. `<if a screenshots dir exists: embed 2–4 images by ABSOLUTE path, verified with ls first, each captioned>`.
> Return a 3–5 sentence summary of what you wrote + a list of anything you could NOT verify.

## Rules that make the output trustworthy
- **One file per agent, distinct paths** → no write conflicts, true parallelism.
- **"Verify against code" + an explicit file list** → grounds claims, kills hallucination. Name the files; don't say "the codebase."
- **State the guardrail facts explicitly.** Agents drift on specifics (e.g. "which OCR library", "which auth flow"). Give them the correct value in the prompt.
- **"Mark unconfirmable external specifics as to-verify."** Essential for migration/strategy docs about a system not in the repo (e.g. the *target* CRM). Prevents confident-but-wrong claims.
- **Require a return summary + unverifiable list** → you get a QC signal per agent.

## After agents return
Cross-check each doc against the code yourself (spot-check the load-bearing claims), fix any drift, THEN render to PDF (`scripts/make-pdfs.mjs`). The agents' self-reported "could not verify" list tells you exactly where to look.
