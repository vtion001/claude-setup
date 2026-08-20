---
name: revamping-client-sites
description: Use when asked to crawl/scrape an existing website and rebuild it as one or more differently-designed variant sites (cloning reference sites' look with the client's own content), or to serve demo sites always-up from this Mac via Tailscale Funnel with a personal run/stop dashboard.
---

# Revamping Client Sites into Multi-Variant Demos

## Overview

One scraped content source feeds every design variant — parity by construction, not by syncing. Reference sites contribute **layout patterns and design language only**; their photos, copy, logos, and brand assets are never copied. Demos serve from this Mac via Tailscale Funnel behind a Flask run/stop dashboard.

## When to Use

- "Scrape/clone this site", "revamp using these examples", "N designs, same content"
- "Always-up demo from my machine", "tunnel with run/stop control"
- NOT for: production hosting builds (use a real host), single-page copy tweaks

## Workflow

1. **Discovery** — Playwright full-page screenshots of client + reference sites → `docs/reference-screenshots/`; WebFetch for structure. Then brainstorming → spec (user reviews; pandoc→PDF→tg-send if they're mobile) → writing-plans → subagent-driven-development.
2. **Scrape** — Playwright render (Google Sites is client-rendered; scroll to trigger lazy images). googleusercontent images: replace the `=w###`/`=s###` URL suffix with `=s0` for original resolution. Save raw text, images, source-URL manifest.
3. **Content** — curate `content/site.json`: every sentence traces to the scrape, NO invented business claims; copy you must author (FAQs, process steps) goes in `content/DERIVED-CONTENT.md` with quoted source facts, flagged for client sign-off. Audit images against per-slot minimums; AI-generate photoreal replacements for failures (no text/watermarks; exclude photos of identifiable people, especially children); record `origin: original|generated` + prompt per slot in `manifest.json`. Generation mechanism: a FLUX text-to-image space on Hugging Face — `dynamic_space` via the HF MCP, or the space's public Gradio REST API when MCP invoke is unavailable (both proven; e.g. `evalstate/flux1_schnell`). sharp → webp+jpg into each app's `public/images/`.
4. **Variants** — one Vite SPA per variant (different stacks fine: Vue/React); each imports the SAME `content/site.json` at build time (`server.fs.allow: ['../..']`). Distinct Tailwind v4 `@theme` tokens per design. Inject `<meta name="x-build" content="<git-sha>-<timestamp>">` via a small vite plugin — the freshness chain depends on it. Full-bleed sections with absolute `-z-10` background layers need `isolate` on the section (else they vanish behind the app root's background). Build every variant through the Design Quality section below — hand-rolled generic sections are how AI slop happens.
5. **Backend** — only for writes (quote/contact form), TDD mandatory. Browsers must call **same-origin `/api`** (dev: vite proxy; prod: funnel path-proxy). Never ship a frontend that fetches `http://127.0.0.1:<port>` — it works on the dev machine and breaks for every external visitor.
6. **Serving** — stdlib static server (SPA fallback + `/api` forward to the backend); Flask dashboard on localhost: Run/Stop per site, status dots, freshness check (compare deployed dist's `x-build` vs the public URL's) — kept alive by launchd. Dashboard binds 127.0.0.1 and is never funneled.
7. **Gates** — Playwright QC: all routes × 2 viewports, listeners for console errors AND `pageerror` AND responses ≥400, form E2E to a DB row; grep-gates for inline styles / JS hover handlers; verify from an external vantage before sharing any URL.
8. **Finish** — final whole-branch review, README (run/deploy/restore instructions), feature branch → PR.

## Design Quality — anti-slop gates (a variant that is structurally correct can still look cheap; these are mandatory)

1. **Concept before code, per variant.** For a reference-site-based variant, extract the structural blueprint first: copy `wireframe-extract.mjs` from this skill's directory into the project's `scripts/` and run `node scripts/wireframe-extract.mjs <url> <slug>` → `docs/design/<slug>/` (desktop+mobile full-page screenshots, `wireframe.json` per-section geometry/layout/media-buckets/text-architecture, `tokens.json` type scale + palette, human-readable `WIREFRAME.md`). The script captures STRUCTURE ONLY by construction — no image URLs, no text beyond 30-char identification labels — so the IP boundary is mechanical, not disciplinary. Hand-verify the MD against the screenshots (carousels/off-canvas menus can misread), map every reference section to a client-content equivalent (drop sections with no honest mapping, e.g. award-logo strips become text-badge strips), then implement TO the blueprint. For from-scratch variants without a structural reference: Stitch MCP screens or an annotated section-map of the reference screenshot. Either way, screenshot your build and compare side-by-side against the reference for density, rhythm, and mood; iterate until it holds up.
2. **Source components from curated registries — don't hand-roll generic sections.** React variants: shadcn/ui via the shadcn MCP (user-scope installed), with third-party registries wired in `components.json` — Tailark (300+ marketing blocks: heroes, testimonials, pricing, FAQ, footers), Magic UI (motion/marketing polish, own MCP installed), Aceternity (dramatic effects), Origin UI (primitives). Vue variants: shadcn-vue (Reka UI + Tailwind) via the same MCP mechanism. Bespoke one-offs: 21st.dev Magic MCP (`mcp__magic__21st_magic_component_builder` / `_inspiration` / `_refiner`).
3. **Never ship default-looking tokens.** Build a real theme per variant — tweakcn.com presets/AI-generation for shadcn CSS variables, or `/ui-ux-pro-max` for palette + font pairing. Typography needs genuine scale contrast (display ≥3× body) and an intentional pairing, not two defaults.
4. **Match photo mood to design mood, per variant.** A dark moody photo survives under a dark overlay but looks cheap in a bright clean card. Curate/generate images PER VARIANT: bright airy designs need bright high-quality photography — regenerate rather than reuse a murky original. This exact mismatch is what makes a light variant read as AI slop.
5. **Design-quality gate before ship:** run `/ux-audit` on every variant; block on the craft red flags — default-theme look, mismatched photo mood, dead unstructured whitespace, template-DNA layout (split hero + pill buttons + centered kickers with nothing bespoke), timid typography.

## Landmines (each cost real debugging time — check them, don't rediscover them)

| Landmine | Guard |
|---|---|
| macOS TCC: launchd agents cannot read `~/Desktop` — plists pointing into a Desktop repo crash-loop with EPERM | Deploy runtime + dists + backend to `~/Library/Application Support/<project>/` via an idempotent `install.sh` (rsync; preserve the deployed DB); plists point there; base paths env-overridable. Re-run install.sh after rebuilds |
| If the service is Dockerized, the whole TCC/`~/Desktop` problem doesn't need solving at all | Skip the LaunchAgent entirely: `restart: unless-stopped` in `docker-compose.yml` + confirm Docker Desktop's own `AutoStart` is on (`~/Library/Group Containers/group.com.docker/settings-store.json`) is enough — Docker's daemon (not a launchd-spawned process) re-reads the compose file and restarts the container, so nothing ever tries to open a file under `~/Desktop` from launchd's restricted context |
| Tailscale Funnel exposes ONLY ports 443/8443/10000 — and existing serve/funnel mappings may already occupy them | `tailscale serve status` FIRST; ask the user before displacing anything; record prior mappings verbatim + restore commands in the audit log/README. Fewer free ports than variants → path-mount several under one port (`--set-path /<variant>`; then each app needs vite `base: '/<variant>/'` + matching router basename, and partial-mount removal syntax must be spiked before writing Stop logic) — or ask which mappings to displace |
| `tailscale funnel --set-path /api` strips the prefix before proxying | Target must re-add it: `--set-path /api http://127.0.0.1:<port>/api` |
| A port can look free while shadowed: `php spark serve` binds IPv6 `[::1]` only while another service owns IPv4 `0.0.0.0:<port>` | `lsof -nP -iTCP:<port> -sTCP:LISTEN` (shows both stacks); bind explicitly `--host 127.0.0.1`; pick a genuinely free port and reconcile it everywhere (configs AND docs) |
| curl from this Mac to the funnel hostname resolves via MagicDNS → tests the serve path, not the public edge | External-vantage check (WebFetch or off-tailnet device) + `x-build` hash equality before any URL is shared |
| Behind the funnel every visitor arrives as 127.0.0.1 | Per-IP rate limits become global caps — size them for that reality; don't pretend per-visitor keying works |
| Dashboard restart loses in-memory process state while OS-level funnel mappings persist → public 502s until a human clicks Run | Auto-reconverge on startup: parse `tailscale funnel status --json`, restart static servers for mapped ports; backend gets its own KeepAlive LaunchAgent |
| Runtime content API + DB + seeder for static demo content | Don't — build-time JSON import gives parity and removes a runtime dependency; backend exists only for writes |

## Red Flags — stop and fix

- A variant renders any sentence that doesn't trace to the scrape → remove it or move to DERIVED-CONTENT.md with its source fact
- Any asset, copy, or logo from a reference site in the build → delete
- About to share a tunnel URL you haven't externally verified fresh → verify first (standing rule)
- About to kill a process on a "conflicting" port → identify its owner first; other tunnels (localtunnel/ngrok/openclaw) and user services are off-limits without approval
