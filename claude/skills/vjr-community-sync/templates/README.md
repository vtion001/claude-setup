# Community document template

`community-doc.html` is a snapshot of `agents/business-ops/templates/gameplan.html` (as of
2026-08-13, including optional `pain_points[].photos` support added in this plan) — reused here so
`vjr-community-sync` has its own stable copy independent of the VJR client-document pipeline.

Render it the same way as the original: `agents/business-ops/lib/pdf.py`'s `render_pdf(template_name,
context, out_path)`, pointed at this file's directory, or copy the field shape (badge, pain_points
with optional photos, phases, effort, etc. — see the original template's own doc comment) into a new
render script under a community's own folder.

**CSS note:** currently uses the VJR brand.css (lime/ink), not a distinct "community" look — a user
request to restyle this against a "community-hub-template" is still pending (the referenced template
could not be located anywhere on this machine as of 2026-08-13). Swap the inlined `brand_css` context
value once that's resolved; nothing else in this template needs to change for a CSS swap.
