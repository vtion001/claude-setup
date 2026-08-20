---
name: property-realestate
description: >
  Router for ALTO Property / real-estate work — the ALTO Mac-mini, Twilio phone
  ops, marketing/hero/listing videos, client-site rebuilds, and Information
  Memorandums. Use on "/property-realestate", "ALTO", "Josh's machine", "IM for
  <address>", "listing video", "hero video", or any ALTO/real-estate request
  where you're not sure which specific specialist skill applies.
---

# Property / Real Estate — Router

Doesn't do the work itself — figures out which specialist skill the request actually
needs and invokes it via the `Skill` tool.

## Routing table

| If the request is about... | Invoke |
|---|---|
| Activating ALTO Property's business operating system / operations registry | `alto-os` |
| Investigating/changing ALTO's shared Twilio account, numbers, call routing | `alto-twilio-ops` |
| Connecting to Joshua Kim's / ALTO's Mac-mini-2 (joshua-openclaw, mission-control) | `connecting-to-alto-mac-mini` |
| Connecting to "ags-aidev002" (the operator's own Linux work machine) | `connecting-to-ags-aidev002` |
| Free cinematic hero-background video for a website | `hero-video-generator` |
| Branded vertical real-estate marketing reel (Instagram/TikTok) | `marketing-reel-generator` |
| Turning a property's own photos into a branded listing reel | `property-listing-video` |
| Crawling/rebuilding an existing client site as a redesigned variant | `revamping-client-sites` |
| Drafting/updating an ALTO commercial-property Information Memorandum PDF | `sales-information-memorandum` |

## Fallback

If nothing above matches clearly, list the candidates above and ask which one fits
rather than guessing.
