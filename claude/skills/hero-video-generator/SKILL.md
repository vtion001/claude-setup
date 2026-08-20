---
name: hero-video-generator
description: Generate free, cinematic landscape hero-background videos (~20-30s, muted, 1920x1080) for a website from commercial-licensed stock footage, then deliver them to Telegram. Use when the user asks to "make a hero video", "create a background video for the homepage", "real estate video for the hero", a "property video", or wants 1+ short muted background-video variants without paying. Sources footage free-first — Pexels/Pixabay when PEXELS_API_KEY/PIXABAY_API_KEY is set (best), else Coverr's no-key API.
---

# Hero Video Generator

Produce N cinematic, muted, landscape hero-background videos from free, commercial-licensed
stock footage, then deliver them. No AI-gen keys required. Encodes the pro real-estate-video
playbook so output looks professional, not DIY.

## When NOT to use
- True AI-generated footage of a *specific* subject (a specific building) → needs paid Veo/Sora
  API or the user's browser (Google Flow). See `references/free-video-landscape.md`.
- Vertical/social crops → pass `--width 1080 --height 1920` and re-check framing.

## The playbook (why the output looks pro — from real-estate videographers)
1. **Hero shot first.** Open with the single strongest visual (aerial/drone/skyline). Order the
   clips deliberately; the assembler keeps your order.
2. **Wide → medium → detail**, in a logical flow. End strong (golden hour or the icon shot).
3. **Slow is smooth, smooth is cinematic.** Pick clips with slow, steady motion; avoid fast/shaky.
   Longer holds (~5.6s) beat quick cuts for a hero background.
4. **Warm, natural residential grade** (comfort/luxury) — baked into `build_variants.py` as the
   default. Do NOT over-grade; over-editing is the #1 amateur tell.
5. **Subtle crossfades only** (0.9s fade) — no flashy transitions/zooms.

## Content targeting (IMPORTANT — this is where relevance is won or lost)
Stock search titles/tags mislead — **always vet the contact sheet visually**. Use *specific*
queries for a recognisable identity. For **Brick Lane Property Group** the confirmed brief
(Mark, 2026-07-21) is **Australian capital cities**:
`Sydney aerial harbour, Sydney city skyline, Melbourne aerial skyline, Brisbane aerial city river,
Perth aerial skyline city, Australian suburb aerial homes, waterfront apartments, Australian city sunset aerial`.
Pexels coverage: Sydney (Opera House/harbour) and Perth (skyline/river) are excellent; Melbourne/
Brisbane good; Adelaide/Canberra/Hobart/Darwin thin.

## Workflow
1. **Clarify** (defaults fine): variants (default 2), duration (~24s), theme/queries. For BPG default
   to the Australian-capitals query set above.
2. **Source** — `python3 ~/.claude/skills/video-kit/lib/source_footage.py --out <workdir> --queries "<comma queries>" --provider auto --max 24`.
   `auto` = Pexels (key in `.env`, auto-loaded) → Pixabay → Coverr. Prints scored rows; writes
   `<workdir>/clips/cNN.mp4`, `manifest.json`, `contact_sheet.png`.
3. **Vet visually (required)** — Read `<workdir>/contact_sheet.png`. Grid is row-major, 6 per row,
   so grid position == clip index. Trust the frames, not titles. Pick ~5 indices per variant that
   are on-brand (recognisable cities / clean residential), and **order them hero-first**.
4. **Assemble** each variant — `python3 ~/.claude/skills/video-kit/lib/assemble.py --clips-dir <workdir> --order 10,8,1,19,15 --out <workdir>/A.mp4`.
   Give variants distinct moods (e.g. skyline-led vs residential-led). ~5 clips x 5.6s ≈ 24s.
5. **Verify** — `ffprobe` each output (1920x1080, ~20-30s, no audio); Read a mid-frame to confirm
   it looks premium. **Never deliver an unviewed video.**
6. **Deliver** — send each file **individually** (Telegram multi-file 400s):
   `python3 ~/.claude/scripts/tg_send.py --file <workdir>/A.mp4 --caption "..."`.
   Also `SendUserFile` to surface in-session — but note the **in-session limit is 30 MB** (Telegram
   is 50 MB); if a file is 30-50 MB it still reaches Telegram, just not the in-session preview.
   Keep files < 30 MB by trimming a clip or raising `--crf` (e.g. 22) if you want both.
7. **Do not wire into the site** unless asked — deliver files; let the operator choose.

## Gotchas (learned the hard way)
- Clips live under `<workdir>/clips/` — the builder handles both that and a flat dir.
- This ffmpeg build has **no `drawtext`** filter — don't label frames with it (grid position = index).
- Coverr `duration` is a **string**; scripts coerce it.
- Pexels/Pixabay **web pages 403** plain curl (anti-bot); their **APIs** work with a free key.
- Telegram bot: send files **one at a time** (a multi-file send returns HTTP 400).
- Licensing: Pexels / Pixabay / Coverr are all commercial-use, no-attribution. Source is recorded
  per clip in `manifest.json`.

## Files (shared engine)
This skill now runs on the shared toolkit in `~/.claude/skills/video-kit/lib/`:
- `source_footage.py` — fetch + score + download + contact sheet (Pexels/Pixabay/Coverr).
- `assemble.py` — the 16:9 hero assembler (warm grade + crossfades + vignette + fades).
- Keys live once in `~/.claude/skills/video-kit/.env` (gitignored, auto-loaded).
- `references/free-video-landscape.md` (in this skill) — the free-video landscape + research.
Sibling skill `marketing-reel-generator` shares the same lib for vertical reels.
