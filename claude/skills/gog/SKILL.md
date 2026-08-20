---
name: gog
description: This skill should be used when the user asks to interact with Google Workspace from the shell — "send a gmail", "search gmail", "list calendar events", "create a calendar event", "search Google Drive", "read a Google Doc", "read/update a Google Sheet", "list Google Contacts", "fetch Google Tasks", or any "use gog" / "via gog" request. The `gog` CLI (Mach-O binary at /opt/homebrew/bin/gog, v0.9.0 from steipete/tap/gogcli) is already in PATH on this machine — no install needed. Five accounts already authed and working flag-free via OAuth client `gog-desktop` — see "Auth state" below for the current list, token-expiry date, and how to add another.
---

# gog — Google Workspace CLI (globalised, single-account)

Adapted from `~/.openclaw-joshuakim/skills/gog/SKILL.md` and the binary's own `--help`. Source upstream: https://gogcli.sh

## Auth state — current: 5 accounts via `gog-desktop`

`gog-desktop` (project `personal-computer-504416`) is the one working OAuth client — it's a
**Desktop app**-type client, not Web app. Web-type clients (`personal-computer`, `ags-new`, and
others on this machine) force gog's slow manual copy-paste flow and reliably die on its internal
~2min deadline — confirmed twice, don't try one again. Consent screen is in **Testing mode**:
refresh tokens expire ~7 days after mint, and any account not already below must be added as a
Test user first (GCP Console → Google Auth Platform → Audience → Add users) or auth fails
`access_denied` (distinct from `invalid_grant`/`invalid_client`, which mean the token/client itself
is stale — re-run `gog auth add`).

| Account | Scopes | Minted | Notes |
|---|---|---|---|
| `vjrodriguez1994@gmail.com` | calendar, gmail | 2026-08-12 | Default — `GOG_ACCOUNT` env + `account_clients` config both pin this + `gog-desktop`, so flag-free commands work |
| `tiongsonsph@gmail.com` | calendar, gmail | 2026-08-12 | |
| `generalmanager.tiongsons@gmail.com` | calendar, gmail | 2026-08-12 | Also the app's Test-user/developer contact shown in `access_denied` errors |
| `v.rodriguez@allianceglobalsolutions.com` | calendar, gmail | 2026-08-12 | AGS Workspace account |
| `sales@altoproperty.com.au` | calendar, contacts, docs, drive, gmail, sheets | 2026-08-13 | ALTO's inbound-enquiry mailbox — distinct from `joshua.kim@altoproperty.com.au`. **Verified live 2026-08-14**: `gmail labels list` ✅, `calendar events primary` ✅ (real event returned), `drive search` ✅ (valid empty result). `contacts list` ❌ — `403 accessNotConfigured`: the People API itself is disabled on the underlying GCP project (`12643776996`), separate from the OAuth scope grant (the scope is authorized, the API just isn't turned on) — enable at `console.developers.google.com/apis/api/people.googleapis.com/overview?project=12643776996`, one-time GCP Console click, not a re-auth. `docs`/`sheets` not yet smoke-tested (need a real file ID). |

`agsdev@` and `joshua.kim@altoproperty.com.au` are deliberately **not** connected — don't add
either without asking.

**Add or re-mint an account:**
```bash
gog auth credentials set "$HOME/Library/Application Support/gogcli/credentials-gog-desktop.json" --client gog-desktop  # skip if already registered
gog auth add <email> --client gog-desktop --services gmail,calendar --force-consent
```
Run in the background (`run_in_background: true`) — it blocks on the browser flow, opens the
system default browser, and finishes the moment the human clicks Allow (the one legitimately
human-only step). Target email needs to already be a Test user or it fails `access_denied`. If it
hits `context deadline exceeded`, have the human log into that account in a plain browser tab
first, then retry — cuts it to one click.

**Smoke-test after any auth change:** `gog --no-input gmail labels list --account <email> --json | head -5`.

**`gog auth list` can take well over a minute to return** (observed twice, 2026-08-14) — near-zero CPU while waiting, easy to mistake for a permanent hang. It's not confirmed to hang forever (a `gog gmail labels list` call without `--no-input` in the same session took ~2min then completed with exit 0 on its own) — give it 2-3 minutes before killing it, and always pass `--no-input` on scripted calls per the Operational rules below regardless.

**If `gog-desktop` itself is gone** (not just an expired token): GCP Console →
`personal-computer-504416` → Credentials → Create → OAuth client ID → **Desktop app** → download
JSON → `gog auth credentials set` + `gog auth add`. Never a Web-type client (see above).

**Bypasses gog entirely:** an account connected as a Gmail connector on claude.ai
(`mcp__claude_ai_Gmail__*`) — as of 2026-08-12 that's `v.rodriguez@allianceglobalsolutions.com`.

**Service accounts** (`allianceglobalsolutions.com` Workspace only, no browser/refresh-rot): GCP
Console → IAM → Service Accounts → download key → Admin Console → domain-wide delegation →
`gog auth service-account /path/to/sa.json --account <email>`. Doesn't work for personal Gmail.

---

## What `gog` covers

Single binary CLI for: Gmail, Calendar, Chat, Classroom, Drive, Contacts, Tasks, Sheets, Docs, Slides, People, Groups.

- **Binary:** `/opt/homebrew/bin/gog` (Mach-O ARM64, v0.9.0)
- **Config:** `~/Library/Application Support/gogcli/config.json`
- **Credentials/tokens:** same dir (`credentials*.json`, `token*.json`, `keyring/`)
- **Currently authed accounts:** see the table under "Auth state" above — don't duplicate it here.

## Routing — when to pick gog vs. an MCP

| Need | First try | Falls back to |
|---|---|---|
| Send / search Gmail | Claude.ai Gmail MCP | `gog gmail send/search` (once auth works) |
| Calendar events CRUD | Claude.ai Google Calendar MCP | `gog calendar` |
| Google Drive file search / download | `gog drive` (no MCP equivalent) | — |
| Google Sheets read / write / append / clear | `gog sheets` (no MCP equivalent) | Maton.ai / google-sheets-agent on the OpenClaw side |
| Google Docs export / cat | `gog docs export/cat` | — |
| Google Contacts list | `gog contacts list` | — |

When the MCP can do it and is authed, prefer the MCP. When the MCP can't do it, document the gog auth state and try anyway — log the error if it fails.

## Global flags worth knowing

- `--account <email>` — pick which authed account to use (set `GOG_ACCOUNT` env to avoid repeating)
- `--client <name>` — pick which OAuth client to use (selects which credentials/token bucket)
- `--json` — JSON to stdout (use for scripting / parsing)
- `--plain` — stable TSV, no colors (alternative to `--json`)
- `--no-input` — never prompt; fail instead (REQUIRED when invoking from automation)
- `--force` — skip confirmations for destructive commands
- `--verbose` — full logging for debugging auth issues

## Common commands (copy-paste reference)

### Auth
- `gog auth list` — show authed accounts (works even when API auth is broken)
- `gog auth status --account <email> --json` — config + keyring snapshot
- `gog auth credentials <path/to/client.json>` — point gog at an OAuth client_secret file
- `gog auth add <email> --services gmail,calendar,drive,contacts,sheets,docs` — browser OAuth flow
- `gog auth service-account <path/to/sa.json> --account <email>` — service-account auth

### Gmail
- `gog gmail labels list --json`
- `gog gmail search 'newer_than:7d' --max 10 --json`
- `gog gmail send --to a@b.com --subject "Hi" --body "Hello"` (gate via `tg_approval_gate.py` first — see Operational rules)
- `gog gmail get <messageId> --json` — takes a **message** ID, not a thread ID; `404 notFound` means you passed the wrong kind
- `gog gmail thread get <threadId> --json` — takes a **thread** ID; use this (not `gmail get`) to pull every message in a thread, including each message's own `id` (needed for `--reply-to-message-id` below)

**Replying within an existing thread** (e.g. following up on a prior email to the same recipient), confirmed working 13 Aug 2026:
```bash
gog gmail send --account <email> --to <recipient> \
  --subject "Re: <original subject>" \
  --body-file <path-to-body.txt> \
  --reply-to-message-id <messageId-from-thread-get> \
  --attach <file1> --attach <file2> \
  --no-input --json
```
`--reply-to-message-id` alone sets threading (`In-Reply-To`/`References`) — no need to also pass `--thread-id`. Gate the content through `tg_approval_gate.py` first as usual (see Operational rules); the approval preview is text-only (subject + body), it does not embed attachment contents, so if the attachments themselves need the operator's eyes, deliver them to Telegram separately before or alongside the gate request rather than assuming the gate covers them.

**Before assuming "no thread exists yet" or trusting a note that says a prior email is still an unsent draft — check live.** A case file/notes doc can go stale the moment the email is actually sent from outside that session. `gog gmail search 'to:<address> OR subject:"<subject fragment>"' --account <email> --json` costs nothing (read-only, no gate needed) and will show the real `SENT`/`DRAFT` label and thread ID — confirmed this session where a note claimed an email was "still sitting unsent in Gmail draft `r...`" and a live search showed it had actually been sent days earlier with a real thread to reply within.

### Calendar
- `gog calendar events <calendarId> --from <iso> --to <iso> --json`
- `gog calendar create <calendarId> --summary "..." --start <iso> --end <iso>` (gate via `tg_approval_gate.py` first if attendees are added — see Operational rules)

### Drive
- `gog drive search "name contains 'foo'" --max 10 --json`
- `gog drive get <fileId>` — download file

### Sheets
- `gog sheets get <sheetId> "Tab!A1:D10" --json`
- `gog sheets update <sheetId> "Tab!A1:B2" --values-json '[["A","B"],["1","2"]]' --input USER_ENTERED`
- `gog sheets append <sheetId> "Tab!A:C" --values-json '[["x","y","z"]]' --insert INSERT_ROWS`
- `gog sheets clear <sheetId> "Tab!A2:Z" --force`
- `gog sheets metadata <sheetId> --json`

### Docs
- `gog docs export <docId> --format txt --out /tmp/doc.txt`
- `gog docs cat <docId>` — print to stdout
- (In-place doc edits are not supported by gog — needs Docs API client.)

### Contacts / Tasks / Groups
- `gog contacts list --max 20 --json`
- `gog tasks list <listId> --json`
- `gog groups list --json`

## Operational rules

- **Always pass `--no-input` from scripted/agent invocations.** Browser-prompt fallbacks will hang the agent loop otherwise.
- **Always pass `--json`** when you'll parse the output. Avoid scraping the colored TTY output.
- **Gate outbound/irreversible actions through `~/.claude/scripts/tg_approval_gate.py`, not a chat reply.** As of 13 Aug 2026 this replaces the old "confirm with the user in chat" rule for: `gog gmail send`, `gog calendar create`/any calendar write that adds attendees (they get notified), and any destructive Sheets/Drive op (`sheets update|append|clear`, Drive delete/move). Shared script — the same one `wacli-msg`'s Step 6 uses, not a gog-specific fork; see that skill's SKILL.md for the full mechanism (dedicated bot, why it's separate from the openclaw-shared one, exit-code contract). Usage here — `--recipient` is a free-text label for what's about to happen, not necessarily a person:
  ```bash
  # Before gog gmail send — --channel makes the destination unambiguous in Telegram
  python3 ~/.claude/scripts/tg_approval_gate.py \
    --kind text --recipient "<to-address>" --channel "Gmail" \
    --content "Subject: <subject>

  <body>" [--timeout 900]

  # Before gog calendar create (or any write that notifies attendees)
  python3 ~/.claude/scripts/tg_approval_gate.py \
    --kind text --recipient "<attendees or calendar name>" --channel "Calendar" \
    --content "<summary>
  <start> – <end>
  <description>" [--timeout 900]

  # Before a destructive Sheets/Drive op
  python3 ~/.claude/scripts/tg_approval_gate.py \
    --kind text --recipient "<sheet or file name>" --channel "Sheets/Drive" \
    --content "<exact operation about to run, e.g. the gog command + values>" [--timeout 900]
  ```
  Run via Bash `run_in_background: true`; read the output file once the task-notification fires,
  then act accordingly — same contract as `wacli-msg`'s Step 6 (full exit-code table there):
  `APPROVED` (0) → proceed exactly as approved; `DECLINED` (1) → don't send, ask before redrafting;
  **`DECLINED_WITH_REVISION` (4, added 2026-08-14) → the operator replied to Telegram's follow-up
  prompt with a typed note (read past line 1 of the output file) — redraft against it directly,
  don't re-ask what to change**; `TIMEOUT` (2) → don't send, surface it rather than retrying.
  `--force` on the underlying `gog` command still exists for destructive ops; don't use it to skip
  this gate.
  **The gog CLI itself enforces no gate — the rule lives entirely in this skill.** Verified 17 Aug
  2026: `gog gmail send` fires immediately with zero prompting (with or without `--force`), so
  nothing in the binary blocks an ungated send. Load this skill before any gated action, and treat a
  chat "proceed"/"go ahead" from the operator as NOT satisfying the gate — the Telegram
  Approve/Decline buttons are the only approval.
  **As of 15 Aug 2026, dispatch the whole gate→revision→redraft cycle to a subagent** rather than
  running it inline and waiting on the main session between rounds — same pattern and same
  rationale as `wacli-msg`'s own "Dispatch the whole gate-and-revision loop to a subagent" section;
  read it there rather than duplicating the step-by-step here. **The subagent must NOT execute the
  final send itself on `APPROVED`** — see the next bullet for why; it reports the approved content
  back and the main session sends it.
- **`tg_approval_gate.py` approval is not the only gate — Claude Code's own local permission mode is a second, independent one, and it specifically scrutinizes subagent-executed sends.** Confirmed 13 Aug 2026 and refined 16 Aug 2026: after a `gog gmail send`/`wacli send` was approved via Telegram (exit 0 `APPROVED`), the actual Bash call running that exact command was blocked outright by Claude Code's auto-mode permission classifier, independent of the Telegram approval already obtained — but this specifically happens when a **subagent** runs the send; the identical command with identical content sent successfully on the first try when run directly in the **main session**. Fix: structure the dispatch so the subagent only waits/polls/redrafts and the main session performs the one final send call once `APPROVED` comes back — not a workaround, the correct division of labor. If the send still gets blocked even in the main session, report it plainly and let the operator send it themselves or explicitly instruct the send — don't attempt a workaround (e.g. shelling out through a different tool) to bypass a permission denial.
- **Read-only ops (search, list, get, export) don't need the gate** — only actions that send something to another person or destroy/overwrite data.
- **For Sheets values, prefer `--values-json`** over inline rows — it handles quoting correctly.
- **When auth fails, surface the raw error to the user**, don't retry silently. The "invalid_client" failure is permanent until OAuth is rotated; retries waste turns.

## Related on this machine

- **OpenClaw mirror of this skill:** `~/.openclaw-joshuakim/skills/gog/SKILL.md` (Joshua-workspace version; source of this file)
- **Joshua's production deployment:** `github.com/vtion001/joshua-openclaw` → `workspace/skills/gog/` (per his `SKILL_INDEX.md` it's marked ✅ enabled there — different OAuth client, separate from this machine's gogcli config; that directory is doc-only on the Mac-mini, no scripts dir)
- **Email voice-training engine (2026-08-13)** — since `joshua.kim@altoproperty.com.au` is explicitly NOT connected via gog (see Auth state above), Joshua's email-reply capability is built separately, on the Mac-mini itself, via `inbox-api`'s IMAP connection rather than gog: `email_voice_engine.py` + `push_email_draft.py` in `outreach-engine/scripts/`, gated through the same `tg_approval_gate.py` pattern as this skill's own Gmail-send gate. Full writeup: `~/.claude/skills/connecting-to-alto-mac-mini/SKILL.md` → "Email voice-training engine + Drafts-folder push".
- **gogcli config dir:** `/Users/archerterminez/Library/Application Support/gogcli/` — DO NOT delete or `rm -rf`. Contains the only copy of refresh tokens for every account in the Auth state table above, plus dead/stale credential files kept for audit; losing it forces a re-OAuth from scratch for all of them.
- **Two live local copies of this SKILL.md** — `~/.config/opencode/skills/gog/` (opencode) and `~/.claude/skills/gog/` (Claude Code), separate files that must be edited together (confirmed 17 Aug 2026, inode-checked). `wacli-msg` avoids this by symlinking to the repo copy; gog does not — apply gate-rule edits to both copies or the two runtimes will drift.
