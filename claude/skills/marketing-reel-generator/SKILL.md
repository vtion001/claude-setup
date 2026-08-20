---
name: marketing-reel-generator
description: Create branded vertical (9:16) real-estate marketing reels for Instagram/TikTok/Shorts — hook, cinematic footage or your own photos, burned-in property text, logo watermark, animated CTA end card, licensed music, and an .srt caption sidecar. Use when the user asks to "make a reel", "marketing video", "Instagram/TikTok video", "listing video", "property promo", or a social/vertical video (as opposed to a muted hero background — that's hero-video-generator). Free-first: Pexels footage + Mixkit music.
---

# Marketing Reel Generator

Produce a short vertical reel that follows the 2026 real-estate playbook: **hook in the
first 3s**, slow-smooth shots, **captions/text on** (most watch muted), warm grade, subtle
transitions, and a **logo + CTA end card**. Shares the engine in `~/.claude/skills/video-kit/lib`.

## Engine (shared lib — `~/.claude/skills/video-kit/lib/`)
- `source_footage.py` — Pexels (key in `.env`) / Pixabay / Coverr → clips + contact sheet.
- `source_photos.py` — the user's own photos → Ken Burns clips (drop-in).
- `reel.py` — the vertical builder: 9:16 segments (`--fill` crop or blurpad) → xfade → overlays → end card → music → `.mp4 + .srt`.
- `brand.py` + `brand_tokens.json` — Pillow-rendered logo/hook/lower-third/end-card (this ffmpeg has **no drawtext**, so text = PNG overlays).
- `assets/music/` — cached Mixkit tracks (no-key, commercial-licensed).

## Reel structure (what `reel.py` produces)
`hook (0-3s) → 3-5 slow-smooth shots (hero first) → capitals/property lower-third → CTA + logo end card`, plus a persistent logo watermark, warm grade, music bed, and a `.srt` sidecar for platform-native captions.

## Workflow
1. **Clarify**: theme/queries, hook line, and property/brand text. For **BPG** the confirmed brief is
   **Australian capital cities** — default queries: `Sydney aerial harbour, Melbourne aerial skyline,
   Brisbane aerial city river, Perth aerial skyline city, Australian suburb aerial homes, waterfront apartments`.
   Default hook = the brand tagline; default lower-third = `Sydney · Melbourne · Brisbane · Perth`.
2. **Source** — `python3 ~/.claude/skills/video-kit/lib/source_footage.py --out <workdir> --queries "<...>" --provider pexels --max 24`.
3. **Vet visually (required)** — Read `<workdir>/contact_sheet.png`; pick ~4-5 indices, **hero shot first**.
4. **Music** — reuse a cached track in `video-kit/lib/assets/music/`, or pull one:
   `curl -A "Mozilla/5.0" "https://assets.mixkit.co/music/105/105.mp3" -o <workdir>/music.mp3` (browse tags at mixkit.co/free-stock-music).
5. **Build** — `python3 ~/.claude/skills/video-kit/lib/reel.py --clips-dir <workdir> --order 10,8,1,15 --out <workdir>/reel.mp4 --music <workdir>/music.mp3 [--fill crop|blurpad] [--hook "..."] [--title "..."] [--sub "..."]`.
   `--fill crop` = **full-bleed** (footage fills the whole 9:16 frame — immersive, recommended for reels); `--fill blurpad` (default) keeps the whole 16:9 frame over a blurred bg (nothing cropped — best when a wide skyline/landmark must stay intact).
   Output: 1080×1920, ~18-22s, with `.srt`.
6. **Verify** — `ffprobe` (1080×1920, has audio); Read a mid-frame + an end-card frame; **never send an unviewed reel**.
7. **Deliver** — `python3 ~/.claude/scripts/tg_send.py --file <workdir>/reel.mp4 --caption "..."` (one file at a time). Note the in-session `SendUserFile` limit is 30 MB (Telegram 50 MB).
8. **Don't publish** to the site/socials — deliver the file + `.srt`; the operator posts it.

## Notes & gotchas
- **Captions strategy:** burn in *property/brand text* (address/price/capitals/CTA) — that's graphic-appropriate. For *spoken* captions, hand over the `.srt` so IG/TikTok's native tool tags them (third-party burned-in spoken captions can be down-ranked as "graphics").
- **Speed:** intermediate ffmpeg stages use `-preset veryfast`; a reel takes ~1-3 min. Run in the background if it risks a tool timeout.
- **Own photos:** run `source_photos.py` first, then point `reel.py --clips-dir` at that workdir.
- **Vertical fit (`--fill`):** `crop` = full-bleed/immersive (trims the sides of 16:9 — fine for centred subjects); `blurpad` = whole frame over a blurred bg (nothing lost). Both are built-in; pick per footage.
- Licensing: Pexels + Mixkit are commercial-use, no-attribution. Keep `manifest.json` for provenance.
