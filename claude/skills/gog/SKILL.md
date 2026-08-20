---
name: gog
description: This skill should be used when the user asks to interact with Google Workspace from the shell — "send a gmail", "search gmail", "list calendar events", "create a calendar event", "search Google Drive", "read a Google Doc", "read/update a Google Sheet", "list Google Contacts", "fetch Google Tasks", or any "use gog" / "via gog" request. On the macOS machine, the `gog` CLI (Mach-O binary at /opt/homebrew/bin/gog, v0.9.0) is pinned to vjrodriguez1994@gmail.com plus 4 other accounts via OAuth client `gog-desktop` — see "macOS machine — Auth state" below. On the Windows machine (C:\Users\VJ_Rodriguguez), `gog` v0.35.0 is installed via winget and authenticates v.rodriguez@allianceglobalsolutions.com against OAuth client `ags-web` — see "Windows machine" section below for that machine's real, tested workflow (including the keyring-password and browser-launch gotchas). Every `gog gmail send` on EITHER machine MUST go through the two guardrails in "MANDATORY pre-send workflow" below — no raw .md attachments, ever, and no send without a Telegram approval first.
---

# gog — Google Workspace CLI

Adapted from `~/.openclaw-joshuakim/skills/gog/SKILL.md` and the binary's own `--help`. Source upstream: https://gogcli.sh

## MANDATORY pre-send workflow (both machines — read before ANY `gog gmail send`)

Two non-negotiable guardrails sit between "draft ready" and actually calling `gog gmail send`. Added 2026-08-14 after a real session where the first two sends of a 4-recipient outreach email each went out missing something (no attachments at all, then no production URL) — both guardrails below exist specifically to catch that class of mistake before it reaches a real inbox, not after.

### 1. Never attach a raw `.md` file — consolidate to PDF first

If ANY attachment in the draft ends in `.md`, stop. Do not pass it to `--attach`. Instead:

```bash
node ~/.claude/skills/gog/scripts/md-to-pdf.mjs \
  --title "<Project> -- <Category>" \
  --out /path/to/output.pdf \
  --glob "docs/**/*.md"          # or list files positionally instead of --glob
```

Run it once per natural grouping of docs (e.g. "Design Specs" vs. "Implementation Plans") — the goal is **1-2 comprehensive PDFs**, never a pile of individual files and never a raw `.md`. Each source file becomes its own section (filename heading, page break before the next) inside the combined PDF — nothing is summarized or dropped, just repackaged. Verify the result before attaching it: `file` reports Chromium-generated PDF page counts wrong (undercounts badly — seen 8 vs an actual 148), so check page count and content with `pypdf` or an equivalent real parser, not `file`/`pdfinfo` alone, if you need to confirm nothing was truncated:

```python
from pypdf import PdfReader
r = PdfReader("out.pdf"); print(len(r.pages), r.pages[0].extract_text()[:200])
```

Needs `marked` + `playwright` (already installed under `scripts/` in this skill dir; Chromium itself was already cached on this machine at `~/AppData/Local/ms-playwright` from other Playwright work — if it's ever missing, `npx playwright install chromium`).

### 2. Get Telegram approval before every send — no exceptions

After the draft (recipients, subject, body, and the final PDF/attachment list) is fully assembled — not before, the approver needs to see the real thing — gate the actual send behind:

```bash
~/.claude/skills/gog/scripts/telegram-approval.sh \
  --token "$AGS_APPROVAL_BOT_TOKEN" --chat "$AGS_APPROVAL_CHAT_ID" \
  --to "a@b.com,c@d.com" --subject "Subject line" --body-file /path/to/body.txt \
  --attach "file1.pdf,file2.pdf"
```

It posts the full draft (To/Subject/body preview/attachment list) to the `ags-approval` Telegram bot with Approve/Decline buttons and blocks until one is tapped (or times out after 15 min). Exit code IS the decision — branch on it, don't parse stdout:

- **0 = approved** → proceed with the real `gog gmail send`.
- **1 = declined** → stop. Report back to the user what was declined; do not retry with a "smaller" version without a fresh approval.
- **2 = timed out** → stop and tell the user directly; don't assume approval, don't assume decline.
- **3 = usage/API error** (bad token, Telegram unreachable) → surface the raw error, same as any other gog auth failure below.

**`$AGS_APPROVAL_BOT_TOKEN` / `$AGS_APPROVAL_CHAT_ID`**: not yet recorded anywhere durable — the user said they'd provide a dedicated `ags-approval` bot token for this (distinct from the general-purpose report/screenshot bot already in the root `CLAUDE.md`). Until then, this step cannot run for real — say so explicitly rather than skipping the guardrail silently. Once provided, record them in the root `~/.claude/CLAUDE.md` Telegram section (same convention as the existing bot) and reference the env var names here — don't hardcode the token inside this skill file or the script.

**Read the approval card content back to yourself before treating it as sufficient.** The card only shows what you put in `--to`/`--subject`/`--body-file`/`--attach` — if the body references a URL or resource, confirm it's actually IN the body text, not just intended to be. The Telegram gate catches a human reviewer forgetting to look; it does not catch you never having written the thing you meant to include.

## Windows machine (C:\Users\VJ_Rodriguguez — tested and working as of 2026-08-14)

**Binary:** `gog` v0.35.0, installed via `winget install steipete.gogcli` (resolves on PATH; full path `C:\Users\VJ_Rodriguguez\AppData\Local\Microsoft\WinGet\Packages\steipete.gogcli_Microsoft.Winget.Source_8wekyb3d8bbwe\gog.exe`).
**Config:** `C:\Users\VJ_Rodriguguez\AppData\Roaming\gogcli\config.json`. **Keyring:** `C:\Users\VJ_Rodriguguez\AppData\Roaming\gogcli\keyring\` (file backend — see gotcha below).
**Account:** `v.rodriguez@allianceglobalsolutions.com`. **OAuth client:** `ags-web` (Desktop-type, project has `http://127.0.0.1:30000/oauth2/callback` pre-registered as a redirect URI — stick to `--listen-addr=127.0.0.1:30000` so it never needs re-registering).
**Services authed:** `gmail`.

### Gotcha 1 — `GOG_KEYRING_PASSWORD` does not persist across separate commands

The `file` keyring backend needs `GOG_KEYRING_PASSWORD` set for every non-interactive operation. On this machine, **each separate `!`-prefixed local command (and each separate Bash tool call) is its own process — env vars set in one do NOT carry to the next.** Setting the password in one command and running `gog login` in a following command silently fails the login before it ever reaches the OAuth/browser step (no error surfaced to the user beyond "nothing happened").

**Fix: always set the var and run the gog command in the SAME single invocation.**

```bash
GOG_KEYRING_PASSWORD="<session-password>" gog gmail search "..." -j
```

Pick any password per session (it doesn't need to be memorable — nothing durable depends on it surviving between sessions; see Gotcha 3). Do not try to persist it to a dotfile or shell profile — a prior attempt at that was correctly blocked by the permission classifier as a risky write.

### Gotcha 2 — `gog auth keyring <backend>` writes to disk and persists across sessions

Unlike the password, the **backend choice** (`file` vs `keychain`) is written into `config.json` and survives. `keychain` (Windows Credential Manager) is NOT available in this gog build on this machine — testing it once (`gog auth keyring keychain`) left every subsequent command broken with `open keyring: Specified keyring backend not available`, including ones that had nothing to do with the test, until switched back:

```bash
gog auth keyring file
```

Confirm with `gog auth doctor --check` — `ok keyring.backend file` is the expected state; anything else means someone (agent or user) changed it. Don't experiment with `keychain` again on this machine unless you've confirmed the gog build changed.

### Gotcha 3 — if the user's local terminal won't open a browser for `gog login`, run it yourself instead

Root-caused once already: an OAuth login run via the user's own `!`-prefixed terminal command can fail to launch a visible browser with zero error output — the cause was never fully identified (terminal-specific browser-launch integration, most likely), and re-diagnosing it a second time is not worth the turns. **Don't debug it — route around it:**

1. Run the login yourself, in the background, from your own Bash tool (same machine, same real OAuth flow — this is not a workaround that skips auth, it's just a different process launching the identical `gog login` command):
   ```bash
   GOG_KEYRING_PASSWORD="<session-password>" gog login v.rodriguez@allianceglobalsolutions.com \
     --client ags-web --listen-addr=127.0.0.1:30000 --services=gmail --force-consent --timeout=10m --verbose
   ```
   (`run_in_background: true` — the local callback listener needs to stay alive while the user completes the browser step, which can take a couple of minutes.)
2. Read the task output file after a couple seconds — it prints an `https://accounts.google.com/o/oauth2/auth?...` URL ("If the browser doesn't open, visit this URL"). Hand that URL to the user directly and ask them to open it themselves.
3. Because YOUR process (not theirs) is holding the listener on `127.0.0.1:30000`, the callback lands correctly once they approve — no further action needed from them beyond clicking through Google's consent screen. Re-check with `gog auth list` (same `GOG_KEYRING_PASSWORD`) once the background task reports done.

This worked cleanly the one time it was tried and is now the **first** thing to reach for if login "does nothing" — not the third.

### Smoke test (Windows)

```bash
GOG_KEYRING_PASSWORD="<session-password>" gog auth list
```
Expected: one line, `v.rodriguez@allianceglobalsolutions.com  ags-web  gmail  <timestamp>  oauth`, no `WARN`/`error`. A `WARN ... integrity check failed` means the password doesn't match what's actually stored — don't guess a second password, fall back to Gotcha 3's re-login flow.

### Useful commands proven working this session

```bash
# Search
GOG_KEYRING_PASSWORD="<pw>" gog gmail search "<query>" -j --max 20
# Read a thread in full (headers + bodies, base64-encoded parts)
GOG_KEYRING_PASSWORD="<pw>" gog gmail thread get <threadId> -j
# Send (see the MANDATORY pre-send workflow above before ever running this for real)
GOG_KEYRING_PASSWORD="<pw>" gog gmail send --to "a@b.com" --subject "..." --body-file draft.txt --attach file1.pdf -j
# Reply in the same thread (keeps it out of a new thread)
GOG_KEYRING_PASSWORD="<pw>" gog gmail send --thread-id <threadId> --to "..." --subject "Re: ..." --body-file draft.txt -j
# Drive: upload a file too large for email (Gmail hard-caps at 25MB) and share with specific people, not "anyone with the link"
GOG_KEYRING_PASSWORD="<pw>" gog drive upload /path/to/big.mp4 --name "Friendly Name.mp4" -j
GOG_KEYRING_PASSWORD="<pw>" gog drive share <fileId> --to=user --email="someone@example.com" --role=reader -j
```

---

## macOS machine — Auth state (current: 5 accounts via `gog-desktop`)

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
