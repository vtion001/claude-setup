# Free hero-video landscape + technique research (2026-07)

## Free video-generation reality (why this skill uses stock, not AI-gen)
- **No free Veo 3 API.** "Free Veo 3.1" (2026) is browser-only: Google Flow (~50 credits/day) and
  Google Vids (~10 clips/mo), driven manually in a signed-in Google account. Programmatic = paid
  Vertex AI (~$0.05/s). Can't be automated for free.
- **Hugging Face** has free image→video (`zerogpu-aoti/wan2-2-fp8da-aoti-faster`) + FLUX image gen,
  and works when authenticated — BUT the MCP's `invoke` is gated by `gradio=none`, and MCP config
  only reloads on a Claude restart. If enabled, the pipeline is: FLUX (real-estate still) → Wan 2.2
  i2v (cinematic motion, feed FLUX's output URL) → ffmpeg stitch. ~5s per clip; stitch ~5 for 24s.
- **Stock sourcing:** Pexels/Pixabay *web* pages 403 curl (anti-bot); their **APIs** are free with a
  key and return 4K footage (Pexels: 8000+ results for "luxury real estate home"). **Coverr** has a
  no-key public API (`coverr.co/api/videos?urls=true&query=...`) but a thin, globally-generic pool.
  → Pexels (with key) is the quality tier; Coverr is the zero-config fallback.

## Real-estate video technique (from videographers — applied in build_variants.py)
- **Shot sequence:** open with the strongest hero (exterior/drone/skyline) → wide establishing →
  medium → detail, in a logical route; end strong.
- **Pacing:** "slow is smooth, smooth is cinematic." Fast motion blurs, cramps rooms, loses viewers.
  Longer holds; every shot earns its place.
- **Grade:** warm tones = comfort/luxury (residential); cool = modern/commercial. Balance first
  (WB/exposure/contrast, match shots), then a *subtle* creative grade. Natural colour, straight
  horizons. Over-grading + flashy effects = the amateur tell.
- **Transitions:** simple crossfades/fades; combine with real camera motion (pan/tilt/dolly) to
  simulate walking through. Few transitions, used well.
Sources: fotober.com, studiobinder.com, lumatrixmedia.com, noamkroll.com, activerain.com (2025-26).

## Project note — Brick Lane Property Group
Confirmed brief (Mark, 2026-07-21): the hero must **specifically represent Australian capital
cities** as the real-estate identity — Sydney (Opera House/harbour), Melbourne, Brisbane, Perth
skylines + Australian suburbs/waterfront homes. Delivered variants A "Capital Skylines" and
B "Capital Living" on that brief. BPG is residential property management, so blend capital-city
identity with residential/property footage.
