# Community document template

`community-doc.html` is a snapshot of `agents/business-ops/templates/gameplan.html` (as of
2026-08-13, including optional `pain_points[].photos` support added in this plan) — reused here so
`vjr-community-sync` has its own stable copy independent of the VJR client-document pipeline.

Render it via `agents/business-ops/lib/pdf.py` (`render_html`/`html_to_pdf`, or `render_pdf`), but
point the Jinja loader at **both** template directories, not just this one — `brand.css` only lives
under `agents/business-ops/templates/`, not here, so reassigning `pdf_lib.TEMPLATES_DIR` alone breaks
the CSS lookup (confirmed 2026-08-20). Keep `TEMPLATES_DIR` pointed at the original and add this dir
to the search path instead:
```python
pdf_lib._env.loader.searchpath = [str(THIS_TEMPLATES_DIR), str(pdf_lib.TEMPLATES_DIR)]
```
Field shape (badge, `pain_points` with optional photos, `phases`, `effort`, etc.) is documented in
the original template's own doc comment. One field gotcha: `pain_points[].breakdown` defaults its
section header to "Subagent / skill breakdown" (a dev-doc label) unless you pass `breakdown_label`
explicitly — set it whenever `breakdown` is reused for something else (an event checklist, etc.).

**CSS note:** currently uses the VJR brand.css (lime/ink), not a distinct "community" look — a user
request to restyle this against a "community-hub-template" is still pending (the referenced template
could not be located anywhere on this machine as of 2026-08-13). Swap the inlined `brand_css` context
value once that's resolved; nothing else in this template needs to change for a CSS swap.
