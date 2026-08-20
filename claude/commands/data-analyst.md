---
description: "Activate the data-analyst agent"
---

# data-analyst Agent

Run the data-analyst agent with the provided arguments.

## SEO Sub-Commands

When arguments start with `seo-`, route to the SEO skills pipeline:

- `seo-audit <domain>` — Run CORE-EEAT + on-page SEO audit using seo-geo-skills
- `seo-report <domain>` — Combined analytics + SEO recommendations report
- `keyword-research <domain>` — Keyword opportunities from GSC data
- `schema-audit <domain>` — Validate JSON-LD schemas on live pages
- `seo-export <domain> [ga4-property-id]` — Export GSC/GA4 data to shared JSON

## Analytics-stack sync sub-commands (works on ANY repo)

For configuring (not just reading) the GA4 + GSC + GTM stack. Repo-agnostic — works for any site whose GA4 property the service-account `search-console-analyst@gen-lang-client-0122329766.iam.gserviceaccount.com` can read/write.

| Subcommand | Purpose |
|---|---|
| `init <domain>` | Bootstrap `analytics_config/<domain>.json` by auto-discovering the GA4 property + scanning the repo for the tracking module. |
| `list` | List every configured site + its GA4 property ID + GSC property. |
| `configure <domain>` | Apply config to live properties. Idempotent. (Default if first arg looks like a domain.) |
| `audit <domain>` | Read-only audit (alias for `configure <domain> --check-only`). |
| `tag-gateway <domain> --provider {vercel\|next-edge\|cloudflare}` | Print first-party Tag Gateway setup snippets (proxies `gtag.js` through the site's own origin to dodge content-blockers). |

All subcommands run `python3 ~/agents/data-analyst/configure_analytics_stack.py <subcommand> <args>`.

### Generic workflow for any new repo

```
# 1. Grant the SA Viewer on the GA4 property (one-time, via GA4 admin UI)
# 2. Bootstrap the per-site config:
python3 ~/agents/data-analyst/configure_analytics_stack.py init mysite.com \
    --repo /path/to/repo \
    --gsc-site-url sc-domain:mysite.com

# 3. Audit to see drift between code and live properties:
python3 ~/agents/data-analyst/configure_analytics_stack.py audit mysite.com

# 4. Apply the changes:
python3 ~/agents/data-analyst/configure_analytics_stack.py mysite.com
```

The `init` step auto-discovers:
- The GA4 property whose web data stream's `default_uri` matches the domain
- The tracking module by checking known paths (`components/analytics/tracking.ts`, `src/lib/analytics.ts`, etc.) then falling back to a recursive grep for `window.gtag` / `gtag('event'...)` call sites
- The event parameters the code actually fires, surfaced as a starting list

The `configure` step is idempotent and fixes:
- GA4 property time zone + currency
- Data retention (default: 14 months)
- Enhanced measurement collisions (auto-disables `page_changes`, `scrolls`, `form_interactions` when the codebase fires manual equivalents — otherwise you get double-counts)
- Key events (default: `form_submit`, `generate_lead`, `sign_up`)
- Custom dimensions for every reportable event param
- GSC sitemap re-submission

### Trigger WHENEVER:
1. The site's tracking module (`tracking.ts`, `analytics.ts`, etc.) is edited.
2. A new tracked CTA / popup / form parameter is added.
3. Before any analysis run, as a healthcheck.
4. After GA4 admin UI changes, to re-assert the declarative config.

Per-site config lives in `~/agents/data-analyst/analytics_config/<domain>.json`. The drift detector flags if code and config diverge.

## Instructions

Check if the first argument is an SEO sub-command:

### For `seo-export`:
```bash
python3 /Users/archerterminez/agents/data-analyst/export_for_seo.py $ARGUMENTS
```

### For `seo-audit`:
1. First run the data export: `python3 /Users/archerterminez/agents/data-analyst/export_for_seo.py <domain>`
2. Read the exported JSON from `~/agents/shared-data/<domain>-seo-data.json`
3. Read the SEO skill at `~/agents/seo-geo-skills/optimize/on-page-seo-auditor/`
4. Execute the audit using the skill's methodology against the domain
5. Store results at `~/agents/shared-data/<domain>-seo-recommendations.json`

### For `seo-report`:
1. Run the data export
2. Read the exported JSON
3. Generate a comprehensive report combining GA4 metrics, GSC rankings, keyword opportunities, and actionable recommendations
4. Format as a Streamlit dashboard or markdown report

### For `keyword-research`:
1. Run the data export
2. Read the exported JSON, focusing on the `opportunities` array
3. Read the SEO skill at `~/agents/seo-geo-skills/research/keyword-research/`
4. Execute keyword analysis using the skill's methodology
5. Output keyword clusters with search intent, volume estimates, and content recommendations

### For `schema-audit`:
1. Use Bash to fetch each page of the domain
2. Extract all `<script type="application/ld+json">` blocks
3. Validate against schema.org specifications
4. Report missing schemas, errors, and recommendations

### For `init <domain>`, `list`, `configure <domain>`, `audit <domain>`, `tag-gateway <domain>`:
Pass through verbatim:
```bash
python3 ~/agents/data-analyst/configure_analytics_stack.py $ARGUMENTS
```
Report the per-section output (CREATED / UPDATED / OK / SKIPPED / WARN / FAIL) and the final summary. If `init` finds no GA4 property matching the domain, the most common cause is the SA hasn't been granted Viewer on the right property — instruct the user to add `search-console-analyst@gen-lang-client-0122329766.iam.gserviceaccount.com` under GA4 → Admin → Property Access Management → +Add users → Viewer.

### For all other arguments (default analytics):
```bash
python3 /Users/archerterminez/agent activate data-analyst $ARGUMENTS
```

Show the output to the user. If the agent fails, check that ~/agents/data-analyst/ exists and has the correct main script.
