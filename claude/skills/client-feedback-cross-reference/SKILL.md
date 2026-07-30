---
name: client-feedback-cross-reference
description: Use whenever a client or stakeholder has sent feedback, corrections, bug reports, or change requests over WhatsApp, email, or another messaging channel, and you need to turn that into verified code changes plus a confirmation message back to them. Also use when placing client-supplied photos/images into a site or app (hero images, section photos) and you need to verify correct placement rather than just that a file changed. Trigger on phrases like "check what Mark/the client said on WhatsApp and fix it", "cross-reference his feedback against the codebase", "did we miss anything from his messages", "validate the changes against what he asked for", "place these photos properly", "make sure local and the tunnel/staging look the same", or "compose a message confirming the fix". Also use proactively before telling a client something is "done" — this skill's cross-reference sweep is what catches the same fact/bug stated a second time somewhere you didn't think to check.
---

# Client Feedback Cross-Reference

## Overview

Informal feedback (a WhatsApp thread, an email chain) is a low-friction way for a client to report issues, but it's an unstructured, unordered, sometimes-months-long stream — the opposite of a clean ticket. The failure mode this skill exists to prevent isn't "the fix was wrong," it's **"we missed something,"** in one of three shapes:

1. An item buried in the thread never got actioned (a scroll-past image, a message sent between two others).
2. An item got fixed in the one place the client pointed at, but the same fact/bug is stated a second time somewhere they never looked (see: a spend-cap figure corrected on the page they screenshotted, left wrong on a different page stating the same policy).
3. Something got marked "done" on the strength of a successful build, without ever checking the change actually reached the surface the client will look at.

Requirements-traceability practice calls the first case top-down traceability (feedback → code → verification) and the second bottom-up traceability (does the codebase say anything else that's now inconsistent with what you just fixed) — a good pass needs both directions, not just the one the client explicitly pointed you at. [Source: PMI / TestRail / Jamasoftware RTM guidance]

**Core principle:** treat the messaging thread as the live, authoritative source of the ask — not your memory of an earlier pass through it, not a summary you wrote three turns ago. Re-pull it. Then treat "the client mentioned it" and "it's actually fixed everywhere" as two separate claims, both requiring direct verification before you say either one out loud.

## When to use

- A client/stakeholder references feedback they sent over WhatsApp, email, Slack, or similar, and wants it acted on.
- You're about to tell a client "that's fixed" or "all done" — even if you're confident, run the cross-reference sweep (Phase 5) first.
- You've made changes based on a thread and want to validate nothing was missed before reporting back.
- A thread item sounds exploratory or open-ended (a redesign idea, "what if we tried X", references/mood images with no confirmed direction) — this skill's job here is to produce a plan + to-do list (Phase 3.5), not to start implementing off a one-line chat message.

**Not for:** structured ticket/PR workflows that already have an explicit, itemized spec (use `writing-plans` / `executing-plans` instead) — this skill is specifically for the *unstructured, easy-to-under-read* messaging case.

## The workflow

### Phase 1 — Pull the full thread, don't trust a stale copy

Re-fetch the conversation live. Do not rely on a summary from earlier in your own session — threads move while you're working, and a partial fetch silently truncates the oldest *or* newest messages depending on the tool's ordering, which you must determine empirically (don't assume).

- **WhatsApp (via `wacli`):** see `references/whatsapp-wacli.md` for exact commands and the tool's real gotchas (a naive `sync` call hangs forever — it's a persistent listener, not a one-shot job).
- **Email:** see `references/email.md`.
- Whatever the channel, confirm you have the *complete* recent window before extracting items — check the channel's own "last activity" metadata against the newest message your fetch returned. If they don't match, you're missing something; fetch again, don't proceed on a partial read.

### Phase 2 — Extract every distinct feedback item

Read the thread chronologically, not by skimming for keywords. For each item, capture:
- what was asked/reported (verbatim quote or a precise paraphrase — don't compress away detail you'll need later)
- exact timestamp and message ID (you'll want to cite this in commits and the confirmation message)
- **for every media message, check its actual caption field before concluding it has none.** This is a real, repeated mistake, not a hypothetical: a message-list view often shows a generic label like "Sent document"/"Sent image" as the display text for *any* media message regardless of whether the sender attached a caption — that generic label is a UI convenience field, not the caption. The real caption lives in a separate field (e.g. `MediaCaption`, or the message's own `Text`/`Body`), and the tool's summary/list view will not surface it by default. Concretely: dump the *full* raw message object for every media item, not just whatever field your first listing command happened to print — a caption that says exactly which page and section an image goes to turns a "guess or ask" situation into a "just do it" one, and skipping this check is how an unambiguous, fully-specified request gets miscategorized as Ambiguous.
- any attached media — **download and actually view every image too**, caption or not. A captioned image still needs viewing to confirm the caption and image agree; an uncaptioned one is still evidence — an uncaptioned circle/annotation on it is real signal even without words attached, and a photo with neither caption nor annotation is a legitimate "no action needed, just context" read — but you only know which situation you're in by actually looking, at both the text field and the pixels.

Do not stop at the first item you notice. Client threads bury asks between pleasantries, images sent without a leading question, and casual asides ("oh and also—"). A single grep for an obvious keyword will miss most of this. Read the whole window.

### Phase 3 — Classify and map each item to the codebase

For every item, land it in exactly one of these states — this is the ledger, and it's what stops "I think we got it all" from being a guess:

| State | Meaning | What you do |
|---|---|---|
| **Confirmed fixed** | Change made and independently verified (Phase 5) | Ship it, cite the evidence |
| **Needs fixing** | Clear ask, small/well-scoped, one obvious implementation | Implement directly (Phase 4) |
| **Needs planning** | Clear-ish ask, but large, exploratory, irreversible, or brand/architecture-level — more than a one-file, one-obvious-way change | Stop before writing code. Produce a plan + to-do checklist (Phase 3.5) and get it reviewed before implementing anything |
| **Ambiguous** | Unclear what's being asked (uncaptioned circle, contradictory prior messages) | Do **not** guess and implement. Queue a specific clarifying question for the confirmation message. |
| **Deferred** | The client themselves said they'd follow up (send a reference, confirm a detail) and nothing is actionable yet | Note it, don't build speculatively against something that might not match what actually arrives |

Map each item to the actual file(s) by reading the code, not by guessing from the client's description of what they see. A described symptom ("the video only loads when I move the mouse") may not have an obvious one-line cause — investigate the actual mechanism (server headers, JS event bindings, browser behavior) before either fixing or ruling it out; don't fabricate a fix for a cause you haven't confirmed, and don't silently drop it either — an inconclusive investigation is itself a reportable finding ("checked X and Y, inconclusive, need more info from you: ___"). This same investigation is what tells you whether an item is actually "Needs fixing" or secretly "Needs planning" — a request that sounds like a one-liner in chat ("keep some colour in the hero images") can turn out to touch a documented brand decision across eight surfaces once you've read the code; don't take the client's phrasing as a scope estimate.

### Phase 3.5 — Surface a plan + to-do checklist before implementing anything non-trivial

This is the checkpoint that keeps this skill from quietly grinding straight from "read the thread" to "here's a PR" on something the operator never actually signed off on the scope of. Run it for every **Needs planning** item, and proactively re-run it any time a "Needs fixing" item turns out bigger than it looked once you've read the code.

A plan checkpoint is short, and always has these parts:

1. **What you found investigating** — the concrete thing that makes this non-trivial (e.g., "the monochrome look is baked into the source image files, not a CSS filter — swapping it means new assets on 8 pages, not a one-line class change"). This is what justifies stopping instead of just building.
2. **A recommendation, not just options** — lead with the scoped-down version (a pilot, a single surface, the reversible option) over the maximal one, and say why. Client threads under-specify scope by default; the safe default is smaller than what the words alone suggest, especially for anything brand/identity-level or hard to reverse.
3. **A numbered to-do list**, ordered so blocking items (a question only the client can answer, a decision only the operator can make) come first — don't bury the thing that blocks everything under a list of things you could do in parallel.
4. **Explicitly no code yet** — say plainly that you're stopping here for review. Do not implement any part of a "Needs planning" item in the same pass as producing its plan, even the parts that seem obviously fine — the point of the checkpoint is the operator gets to react to the whole shape of it before anything is committed.

Fold any resulting clarifying questions into the same Phase 7 confirmation-message draft as everything else in this pass — don't send a separate one-off message for it. One consolidated message reads as "here's where everything stands," not a drip of pings.

### Phase 4 — Fix with TDD, one item at a time

Applies to **Needs fixing** items directly, and to **Needs planning** items only after their plan (Phase 3.5) has been reviewed and approved — never skip the checkpoint because the fix itself turned out to be easy to write.

For any change that has an observable, checkable symptom (visual layout, rendered copy, a specific value), write the test from the client's own evidence before touching the code:

1. If they sent a screenshot showing a measurable symptom (e.g., a lopsided layout), write an assertion that captures *that specific symptom* — a bounding-box gap comparison, not just "element exists." Verify it fails for the right reason against current code.
2. Minimal fix.
3. Verify the test passes.
4. Run the full relevant regression suite, not just the new test — a fix for one client complaint regressing an unrelated page is exactly the kind of thing a five-minute full-suite run catches for free.
5. Commit with the client's message ID/timestamp in the commit body — it's the paper trail from "why did this line change" back to the actual conversation, and it's what lets a future cross-reference sweep (yours or someone else's) find the source context fast.

If the codebase has no test tooling for the relevant surface, fall back to direct verification against the actual rendered output (build + inspect the built artifact / rendered page) — but say explicitly that you did that instead of an automated test, don't imply a test exists when it doesn't.

### Phase 4.5 — Visual placement verification for photo/image uploads

Applies whenever a fix places or swaps images across pages/sections (a client sending reference photos with per-image captions, a redesign pilot, anything where "correct" means *this specific image in this specific slot*, not just *a file changed*). A passing build and a passing pixel-content test (e.g. "this image is no longer monochrome") prove the file changed — neither proves it landed in the right place, at the right crop, next to the right copy. Placement is a visual claim; verify it visually.

1. **Understand each image before placing it — don't place from a filename or a guess.** Run OCR (`tesseract <file> -` — try `--psm 11` for sparse text on a photo, e.g. a number or sign, since default segmentation can miss it) on every image. Most photography returns nothing, which is itself useful signal (pure scene content, no embedded text to contradict the placement). When OCR does return text, cross-check it against the assigned section's own copy — an image whose OCR'd text echoes the heading it's being placed under (a "28" sign photo next to "The 28-Day Guarantee" copy) is a real, independent confirmation, not a coincidence to ignore.
2. **Screenshot every affected page/section with Playwright after implementing, not a sample.** One correct screenshot doesn't imply the other six are also correct — each placement is an independent claim. Scroll multi-image pages to bring each target into view before capturing; a full-page screenshot that never scrolls past the fold silently skips verifying anything below it.
3. **Cache-bust every verification fetch — a long-running browser session lies to you about "current" state.** If the same browser tab/context has visited these URLs earlier in the session (an earlier test run, an earlier build), the browser's own HTTP cache (`Cache-Control: max-age=...` on images is common and long-lived) can silently serve a stale copy on your "fresh" navigation or even a hard reload — screenshots and `naturalWidth`/`naturalHeight` reads both reflect the cached file, not the one actually on disk/served. This cuts both ways: a stale image can look *wrong* (a screenshot that appears broken/blank when the real site is fine) or *deceptively right* (an old cached image that happens to render plausibly, passing your eyeball check while verifying nothing). Before trusting any screenshot or reading any image dimension in verification, force a real fetch: `await fetch(src + '?cb=' + Date.now())` (or swap the `<img>` element's `src` to the cache-busted URL and wait for `onload`) and compare the result against the actual server-side file — a raw `curl`/direct HTTP HEAD for size or dimensions is the ground truth to check against, not another browser read.

### Phase 5 — Second-order cross-reference sweep (the step that's easy to skip)

After fixing every explicitly-flagged item, do a second pass that the client never asked for directly: **search the whole codebase — not just the file you just edited — for the same fact, value, or policy stated anywhere else.**

This is the single highest-value step in this workflow. A business fact (a price, a phone number, a policy threshold, a claim) is very often duplicated across a marketing page, a legal/footer section, a structured-data block (JSON-LD, sitemap, `llms.txt`/AI-crawler files), and sometimes a second page describing the same thing from a different angle. The client will point at *one* instance. Fixing only that instance leaves the site internally contradicting itself — which reads worse to a careful client than not having fixed anything, because now there are two different answers to the same question.

Concretely: after fixing the value/copy the client flagged, grep the entire relevant source tree for the old value (not just the file type you expect — check config/metadata/AI-crawler files too, they're easy to forget), and separately grep for the *semantic equivalent* stated in different words (the same policy phrased from the opposite direction, e.g. "you approve anything over $X" vs. "we handle up to $X without bothering you" — same number, same policy, inverted phrasing, easy to miss with a literal string search alone). Read each match in context before deciding whether it's the same fact restated or a coincidental unrelated number.

### Phase 6 — Validate live, not just "the build passed"

A green build or passing test suite proves the code is *correct*; it does not prove the client will actually see it. Before reporting anything as done:

- Rebuild/redeploy through whatever path actually serves the environment the client uses.
- Fetch the live surface directly (curl the actual URL, not just localhost) and check the specific content, not just an HTTP 200 — a status code proves a server answered, not that it answered with the right content (a wrong app squatting on the same port, or a stale cache, both return 200).
- If there's more than one serving path (a primary tunnel/CDN plus a fallback), check **every** path the client might use, not just the one you expect — a tunnel/reverse-proxy in front of a dev server typically points at the same origin, so all paths *should* agree, but only checking one lets a real divergence slip through. Treat a transient failure on any single path as worth one retry before concluding it's a real regression — flaky infra and a real bug look identical on the first failed request; only a second check tells them apart.
- **When work spans more than one branch (a fix here, an experiment there), confirm there is one actual combined state before claiming anything is deployed.** Building branch A, then separately building branch B, does not add up to "A and B are both live" — the second build replaces the first. If two changesets don't touch the same files, merge them into one branch and build *that* rather than context-switching between builds; verify with `git log`/`git diff` on the branch that's actually checked out immediately before rebuilding, not from memory of what you left it as.
- **If a human operator might be working the same environment in parallel** (their own terminal, a manual `git checkout`, testing while you're mid-task), assume the checked-out branch and build output can have changed without you doing it. Re-check current branch, `git status`, and what's actually in the build output fresh before every deploy/verify step in this phase — don't trust your last known state once other hands are plausibly on the same repo. A screenshot or a teammate's "looks live" report from *their* browser is not confirmation your session's fetch will see the same thing — verify independently.

### Phase 7 — Compose the confirmation message

Once the ledger from Phase 3 is fully resolved — Confirmed / Ambiguous / Deferred / Needs planning (its blocking questions surfaced, per Phase 3.5) — nothing left unclassified, draft — do not send — a message back to the client:

- **Recap what's resolved**, in plain language tied to what they'll actually notice, not implementation detail. "Fixed" language should map to their words, not your commit message.
- **Own any mistake plainly** if you gave them wrong information earlier in the thread (a bad link, wrong guidance) — a short, direct correction, not a defensive explanation.
- **Ask specific, narrow questions for every Ambiguous item** — never guess-and-ship something you're not sure about, and never silently drop it either. A good clarifying question names exactly what you saw ("the circle on the building photo in section X — what caught your eye there?") rather than a vague "did you mean anything else?"
- **Don't request fix-confirmation feedback prematurely** — the client hasn't had time to look yet immediately after you finish; a recap of what shipped is fine, asking them to confirm it works can wait.
- **Sending the message is a separate, explicit step** requiring the operator's sign-off — this skill produces the draft, not the send. Client-facing sends are not something to automate past a human.

## Ledger discipline

Keep the running ledger lean — a few fields that actually change a decision (item, state, evidence/file, message ID), not an elaborate matrix nobody will maintain past this one pass. [Source: Jamasoftware RTM best-practices — over-elaborate traceability matrices are the ones that don't survive contact with a real team.] If you're persisting this across sessions (e.g., in project memory), the ledger *is* the artifact worth keeping — the individual investigation steps that produced it aren't.

## References

- `references/whatsapp-wacli.md` — exact `wacli` commands, the persistent-sync gotcha, media download, chat-completeness check
- `references/email.md` — channel-agnostic notes for applying the same phases over email
