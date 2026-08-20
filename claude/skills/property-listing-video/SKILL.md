---
name: property-listing-video
description: Turn a property's own photos into a branded vertical listing reel (9:16) for Instagram/TikTok/Facebook — Ken Burns motion on the photos, the address/price/bed-bath as burned-in text, logo watermark, a listing CTA end card ("Book an inspection"/"Enquire"), music, and an .srt sidecar. Use when the user says "make a listing video", "video from these property photos", "new listing reel", "sold/leased video", or hands over property photos + listing details. Photos-first sibling of marketing-reel-generator; shares the same video-kit/lib engine.
---

# Property Listing Video

Make a share-ready listing reel from a property's **own photos** (no footage needed). Follows the
listing playbook: strong opener, a photo walkthrough in room order, the key facts on screen, and a
clear CTA + brand end card.

## Engine (shared — `~/.claude/skills/video-kit/lib/`)
`source_photos.py` (photos → Ken Burns clips) → `reel.py` (overlays + music + end card + .srt),
`brand.py` + `brand_tokens.json` (logo/hook/lower-third/end card). Keys/config auto-loaded from `video-kit/.env`.

## Inputs to gather
- **Photos** (5-8 best), ideally ordered as a walkthrough: exterior → living → kitchen → bedrooms → outdoor → hero/closing shot.
- **Listing text**: address, price (sale `$1,250,000` or rental `$895/week`), bed/bath, and whether it's *for sale*, *for lease*, or *sold/leased*.
- CTA: sale → "Book an inspection" / "Enquire today"; rental → "Book an inspection" / "Apply now". (BPG is property management → usually **rental / Now Leasing**.)

## Workflow
1. **Photos → clips** — `python3 ~/.claude/skills/video-kit/lib/source_photos.py --out <workdir> --photos <img1> <img2> ... --width 1080 --height 1920 --seconds 3.8`
   (list photos **in walkthrough order**; index = order). Read `<workdir>/contact_sheet.png` to sanity-check.
2. **Music** — reuse `video-kit/lib/assets/music/*.mp3` or pull one from Mixkit.
3. **Build** — `python3 ~/.claude/skills/video-kit/lib/reel.py --clips-dir <workdir> --order 0,1,2,3,4,5 --out <workdir>/listing.mp4 --fill crop --seglen 3.2 --hook "Now Leasing · <suburb>" --title "<address>" --sub "<price> · <beds> bed · <baths> bath" --cta "Book an inspection" --music <workdir>/music.mp3`
   - `--seglen 3.2` = snappier listing pace (must be ≤ the `--seconds` used for the photos).
   - `--fill crop` = full-bleed (photos are already 9:16 from step 1, so this is clean).
4. **Verify** — `ffprobe` (1080×1920, has audio); Read a mid-frame + the end card; never send unviewed.
5. **Deliver** — `python3 ~/.claude/scripts/tg_send.py --file <workdir>/listing.mp4 --caption "..."` (+ the `.srt`).
6. **Don't post** to socials — hand over the file + `.srt`; the agent posts it (with location tag + the property link).

## Notes
- **Compliance:** never invent price/bed/bath — use exactly what the operator supplies. If a fact is missing, leave it out rather than guess (real-estate advertising is regulated).
- **Photo order matters** — the reel plays clips in the order you pass them; lead with the hero shot.
- **Length:** 5-8 photos at `--seglen ~3.2` → ~18-25s. More photos → lower `--seglen` (keep ≤ `--seconds`).
- Music must stay licensed (Mixkit/commercial). Logo + brand look come from `brand_tokens.json`.
