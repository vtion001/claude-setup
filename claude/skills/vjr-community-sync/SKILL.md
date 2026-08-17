---
name: vjr-community-sync
description: >
  Find, scaffold, and pulse-check a WhatsApp-backed community Vincent runs (not a client, not a
  VJR-OS agent-managed entity) under communities/<slug>/. Use on "create a community folder for
  <group>", "set up a community for <group>", "check on <community>", "sync <community>", "how's
  <community> doing", "pulse check <community>", or when a `communities/<slug>/` folder needs
  either creating for the first time or refreshing against live WhatsApp state. Companion to
  vjr-client-sync — same wacli integration pattern, but for a community Vincent owns/runs, not a
  sales lead or paying client.
---

# VJR Community Sync — find a group, scaffold or refresh its folder

`communities/<slug>/` holds strategy and event planning for a community Vincent personally runs
(e.g. `communities/ai-sig-and-espresso/`). Unlike `clients/` and `leads/`, the top-level files here
(`README.md`, `strategy.md`, `events.md`) are **not** gitignored and **not** part of the
client-lifecycle state machine — they're not PII, just Vincent's own community notes. Don't route
this through `core/state.py` or the registry.

**Scope note on consent:** this skill only applies to a community Vincent owns/runs (verified in
Step 1) — members joined it directly and, per Vincent, gave their number specifically so he could
reach/invite them. That's a real, different consent basis than scraping a group he doesn't own or
compiling data on people who never gave it to him — don't re-litigate that basis every run once
ownership is confirmed. It does *not* extend to sharing this data outside the community's own
purpose (event planning, staying in touch) — still local-only, still not for any other business or
third party.

## Step 1 — Find the group via wacli

```bash
wacli chats list --query "<name or partial name>" --json
wacli groups info --jid "<jid>" --json     # full facts: owner, created date, member count, topic, settings
```

**Gotcha (real, hit this building the first one):** a loose name query can match multiple,
unrelated groups with similar names — e.g. "AI Sig and Espresso" (Vincent's own, renamed from "ai
and coffee manila") vs. a completely different, pre-existing "ai and coffee" group he's just a
member of. Don't assume the first/only result is the right one. Confirm ownership before treating a
group as "Vincent's community":

```bash
wacli doctor --json   # .data.linked_jid — Vincent's own JID/number, for comparison
```

Match `groups info`'s `OwnerJID`/`OwnerPN` (or an entry in `Participants` with `IsSuperAdmin: true`)
against `linked_jid`. If Vincent isn't the owner, it's not his community to scaffold a strategy
folder for — flag the ambiguity back to him rather than guessing which group he meant.

**Second gotcha, also real:** `chats list`'s cached `name` can lag behind a recent rename even when
`groups info` (which reads the group's live metadata) already has the new name — confirmed by
querying right after a same-day rename and getting the pre-rename name back. Don't trust `chats
list --query "<current name>"` to find a just-renamed group; resolve by JID (Step 1) and pull
`unread_count`/`last_message_ts` by filtering the full `chats list --limit 100 --json` output for
that JID, not by re-querying the new name.

**If `wacli sync` is needed first** (group/contact not showing up at all): see vjr-client-sync's
sync gotcha — always `--once --refresh-contacts`, never plain `wacli sync` (defaults to
follow-mode, never exits, holds the store lock).

## Step 2 — New community, or refresh an existing one?

```bash
ls communities/ 2>/dev/null
```

Pick a stable slug from the group's **current** name (`slugify`-style: lowercase, hyphens). Note in
the README if the group has already been renamed once — group names/topics change, the slug and
the JID don't; always re-resolve by JID once you have it, not by re-searching the name.

## Step 3 — New community: scaffold the folder

Three files, matching the `communities/ai-sig-and-espresso/` precedent:

- **`README.md`** — verified facts only, pulled from `groups info` (JID, owner, created date,
  member count, join-approval setting, lock setting, the group's own topic verbatim). Add a
  "do not confuse with" section if Step 1 turned up a similarly-named group. Do **not** put the raw
  `Participants` list (phone numbers/JIDs) in this file — it's PII and this file is git-tracked. A
  full member roster belongs in `members/` instead (Step 3b below), which is gitignored.
- **`strategy.md`** — a starting scaffold, not a finished plan: what's already working (pull this
  from the group's own topic/rules — that's Vincent's own positioning, don't invent one), concrete
  ideas for staying active past the first few weeks, a moderation flag if `MemberAddMode` is
  permissive, a pulse-check method (Step 4 below), and open questions only Vincent can answer (what
  does "afloat" mean as a target, who else gets admin).
- **`events.md`** — empty upcoming/past tables, pre-seeded with whatever event formats the group's
  own topic already commits to (don't invent formats it hasn't mentioned).

## Step 3b — Member roster (phone/name/location), on request

Only build this when Vincent actually asks for it (e.g. to plan an event around where members are
based) — it's not part of the default scaffold. When he does:

```bash
mkdir -p communities/<slug>/members
grep -q "communities/\*/members/" .gitignore || echo "communities/*/members/" >> .gitignore
wacli groups info --jid "<jid>" --json > /tmp/<slug>_group.json
```

**Bug to avoid (hit this the first time):** each entry in `Participants[].PhoneNumber` already
comes back as a *full JID string* (`"639171234567@s.whatsapp.net"`), not a bare number. Don't
re-append `@s.whatsapp.net` when building a lookup key — that silently breaks every match against
message-sender JIDs and every country-code check that relies on exact matching (a `.startswith()`
check for the country prefix still works by luck since the digits are still first, but exact-match
joins won't).

**Names mostly won't be there, and that's a platform limit, not something to work around:**
- Checking Vincent's saved contacts (`wacli contacts show --jid <phone-jid> --json`) will likely
  come back near-empty — most community-group members were never individually saved as contacts
  (0/101 on the first real run).
- The better source is WhatsApp's own self-reported push-name, visible only from messages someone
  has actually sent: `wacli messages list --chat "<group-jid>" --limit 500 --json`, then match each
  message's `SenderJID` (a full phone-based JID, e.g. `639171234567@s.whatsapp.net`) against the
  roster's phone field and take `SenderName`. Only members who've posted will resolve — say so in
  the output rather than implying the rest have no name.

**Location resolution caps out at country**, from the phone number's country-calling-code prefix
(`63` = PH, `971` = UAE, `60` = MY, `65` = SG, `1` = US/CA, etc.) — Philippine mobile numbers don't
encode city/region, so this tells you "PH vs. elsewhere," not which city to pick a venue in. For
that, point Vincent at posting a poll in the group (self-reported, consensual, actually accurate) —
`wacli send poll` — rather than trying to infer city from anything wacli exposes.

Write the result to `communities/<slug>/members/roster.json` (full data) and `roster.md` (a
human-readable table) — both inside the gitignored `members/` folder, never in the top-level files.
Verify the gitignore actually takes before considering this done: `git add -n communities/` should
list only the top-level `README.md`/`strategy.md`/`events.md`, not anything under `members/`.

**Profile photos, if also asked for:** `wacli profile picture-info --jid <phone-jid>` works
per-contact (returns a URL + hash, tested against Vincent's own JID) but there's no bulk endpoint —
pulling every member's photo means one live request per person, sequentially. Firing dozens of
those back-to-back is real, distinguishable traffic that can read as automated to WhatsApp and risk
friction on the account. Flag this plainly and get an explicit go-ahead before looping over an
entire roster; batching/spacing requests out is worth doing even after that go-ahead.

## Step 3c — Documents with photos (venue shortlists, event flyers, etc.)

Use `skills/vjr-community-sync/templates/community-doc.html` (a snapshot of `agents/business-ops/
templates/gameplan.html` with photo support) rather than reaching for `agents/business-ops/
templates/gameplan.html` directly — this skill's own copy can evolve independently (e.g. once a
community-specific CSS is available) without touching VJR's client-document pipeline. See
`skills/vjr-community-sync/templates/README.md` for the field shape and current CSS status.

## Step 4 — Existing community: refresh facts + pulse check

Re-run `groups info`, diff against what's in `README.md`'s facts block, and update anything that's
drifted (member count, name, settings). Then pulse-check activity health:

```bash
wacli chats list --query "<current name>" --json   # unread_count + last_message_ts = your ground truth
```

Compare `last_message_ts` against the last time this skill ran (keep that timestamp in a short
"Pulse check log" section at the bottom of `strategy.md` — date, unread_count, last_message_ts, one
line of read). A large, growing gap between `last_message_ts` and now is the actual "is this
community going quiet" signal — member count alone won't show it.

## Step 5 — Report back

Lead with the pulse-check verdict (active / going quiet / dead) if this was a refresh, not a
chronological recap. For a new scaffold, confirm the three files and flag anything Step 3 couldn't
verify (e.g. no upcoming event in the topic — don't fabricate one).
