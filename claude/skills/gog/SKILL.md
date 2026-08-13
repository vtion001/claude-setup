---
name: gog
description: This skill should be used when the user asks to interact with Google Workspace from the shell — "send a gmail", "search gmail", "list calendar events", "create a calendar event", "search Google Drive", "read a Google Doc", "read/update a Google Sheet", "list Google Contacts", "fetch Google Tasks", or any "use gog" / "via gog" request. On the macOS machine, the `gog` CLI (Mach-O binary at /opt/homebrew/bin/gog, v0.9.0) is pinned to vjrodriguez1994@gmail.com. On the Windows machine (C:\Users\VJ_Rodriguguez), `gog` v0.35.0 is installed via winget and authenticates v.rodriguez@allianceglobalsolutions.com against OAuth client `ags-web` — see "Windows machine" section below for that machine's real, tested workflow (including the keyring-password and browser-launch gotchas). Every `gog gmail send` on EITHER machine MUST go through the two guardrails in "MANDATORY pre-send workflow" below — no raw .md attachments, ever, and no send without a Telegram approval first.
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

# (macOS machine) gog — Google Workspace CLI (globalised, single-account)

## Auth state (current — 2026-05-26)

**Single account: `vjrodriguez1994@gmail.com`**  
**Single Desktop OAuth client: `desktop-lofty`** (project `lofty-bolt-453720-c7`, file `~/Library/Application Support/gogcli/credentials-desktop-lofty.json`)  
**Scopes: gmail + calendar**

The other three accounts that used to be authed (`agsdev@`, `joshua.kim@altoproperty.com.au`, `v.rodriguez@`) were removed on 2026-05-26 per user direction ("only vjrodriguez1994@gmail.com connected to claude globally"). Their refresh tokens were deleted via `gog auth remove`. Re-mint with `gog auth add <email> --client desktop-lofty --services gmail,calendar --force-consent` if you ever need them back.

### How defaults are pinned

Two layers, both already configured — Claude Code sessions don't need to set anything per-call:

1. **Default account** — `GOG_ACCOUNT=vjrodriguez1994@gmail.com` exported in `~/.zshrc` (will load in any interactive zsh session, including the ones Claude Code spawns via Bash tool calls). Avoids `--account` flag.
2. **Default OAuth client per account** — `account_clients: {"vjrodriguez1994@gmail.com": "desktop-lofty"}` in `~/Library/Application Support/gogcli/config.json` (auto-written when we ran `auth add`). Avoids `--client` flag.

So this works flag-free:
```bash
gog gmail labels list --json
gog gmail search 'newer_than:7d' --max 10 --json
gog calendar events primary --from 2026-05-26T00:00:00Z --to 2026-05-27T00:00:00Z --json
```

### Smoke-test command (run after any auth change)

```bash
gog --no-input gmail labels list --json | head -5
```

Expected: JSON array starting with `CHAT`/`SENT`/`INBOX` label objects. Anything containing `oauth2: "invalid_client"` means the auth pinning has been bypassed or the desktop-lofty client got revoked.

### OAuth client inventory on this machine

| Client (`--client` value) | File | Project | Status | Type | Notes |
|---|---|---|---|---|---|
| `default` | `credentials.json` | `(770598279386 — name unknown)` | ❌ revoked | Desktop | Old; leave on disk for audit |
| `joshua` | `credentials-joshua.json` | same as default | ❌ revoked | Desktop | Duplicate of default |
| `ags-automation` | `credentials-ags-automation.json` | ags-automation-490322 | ❌ deleted on Google | Desktop | |
| `ags-new` | `credentials-ags-new.json` | ags-automation-490322 | ✅ alive but Web App — rejects gog's redirect URI | Web | Unusable with gog |
| `ags-work` | `credentials-ags-work.json` | ags-automation-490322 | ❌ deleted on Google | Desktop | |
| **`desktop-lofty`** | `credentials-desktop-lofty.json` | `lofty-bolt-453720-c7` | **✅ ACTIVE — sole working client** | Desktop | The one we use |

Also known to exist on disk but not registered with gog (could be wired up the same way):
- `~/client_secrets.json` — project `gsc-cli-2025`, Desktop, alive
- `~/.openclaw/media/inbound/Client_Secret_JSON_from_Google---571a5090-….json` — project `email-marketing-490517`, Web App, alive

### How to re-mint another account against `desktop-lofty`

```bash
gog auth add <email> --client desktop-lofty --services gmail,calendar --force-consent
```

Browser opens → switch to the right Google account → click Allow → gog catches redirect → token saved. Test users may need to be added in GCP Console (OAuth consent screen → Test users) if `lofty-bolt-453720-c7`'s consent screen is in Testing mode.

### If desktop-lofty ever stops working

1. Probe each client with `curl -s -X POST https://oauth2.googleapis.com/token -d "client_id=$CID" -d "client_secret=$CSEC" -d "refresh_token=BOGUS" -d "grant_type=refresh_token"` and look for `invalid_grant` (alive) vs `invalid_client` (revoked) vs `deleted_client` (deleted).
2. Pick another alive Desktop client from disk (`~/client_secrets.json` is the next candidate), register it with `gog auth credentials set <file> --client <name>`, and `gog auth add <email> --client <name>`.
3. As last resort: create a fresh Desktop client in any GCP project you control — GCP Console → APIs & Services → Credentials → CREATE CREDENTIALS → OAuth client ID → Application type: **Desktop app** → download JSON → register with gog.
4. **Don't use Web App OAuth clients with gog** — gog's loopback redirect (`http://127.0.0.1:RANDOM_PORT/oauth2/callback`) will be rejected with `redirect_uri_mismatch`. Desktop clients are the only type that works without redirect-URI registration headaches.

### Service account alternative (for `allianceglobalsolutions.com` Workspace accounts only)

GCP Console → IAM → Service Accounts → Create → download JSON key. Admin Console → Security → API controls → domain-wide delegation → delegate scopes to the SA. Then `gog auth service-account /path/to/sa.json --account <email>`. No browser, no refresh-token rot. Doesn't work for personal Gmail.

---

## What `gog` covers

Single binary CLI for: Gmail, Calendar, Chat, Classroom, Drive, Contacts, Tasks, Sheets, Docs, Slides, People, Groups.

- **Binary:** `/opt/homebrew/bin/gog` (Mach-O ARM64, v0.9.0)
- **Config:** `~/Library/Application Support/gogcli/config.json`
- **Credentials/tokens:** same dir (`credentials*.json`, `token*.json`, `keyring/`)
- **Currently authed accounts** (per `gog auth list`):
  - `agsdev@allianceglobalsolutions.com` (default scopes)
  - `joshua.kim@altoproperty.com.au` (calendar, gmail)
  - `v.rodriguez@allianceglobalsolutions.com` (gmail)
  - `vjrodriguez1994@gmail.com` (calendar, gmail)

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
- `gog gmail send --to a@b.com --subject "Hi" --body "Hello"` (confirm before sending)
- `gog gmail get <messageId> --json`

### Calendar
- `gog calendar events <calendarId> --from <iso> --to <iso> --json`
- `gog calendar create <calendarId> --summary "..." --start <iso> --end <iso>` (confirm before creating)

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
- **Confirm with the user before sending mail, creating calendar events, or any destructive Drive/Sheets op.** `--force` exists; don't use it without explicit go-ahead.
- **For Sheets values, prefer `--values-json`** over inline rows — it handles quoting correctly.
- **When auth fails, surface the raw error to the user**, don't retry silently. The "invalid_client" failure is permanent until OAuth is rotated; retries waste turns.

## Smoke test (run after any auth fix)

```bash
gog --account vjrodriguez1994@gmail.com --no-input gmail labels list --json | head -5
```

Expected on success: JSON array of label objects starting with INBOX. Expected on broken auth: `oauth2: "invalid_client"` error.

## Related on this machine

- **OpenClaw mirror of this skill:** `~/.openclaw-joshuakim/skills/gog/SKILL.md` (Joshua-workspace version; source of this file)
- **Joshua's production deployment:** `github.com/vtion001/joshua-openclaw` → `workspace/skills/gog/` (per his `SKILL_INDEX.md` it's marked ✅ enabled there — different OAuth client, separate from this machine's gogcli config)
- **gogcli config dir:** `/Users/archerterminez/Library/Application Support/gogcli/` — DO NOT delete or `rm -rf`. Contains the only copy of refresh tokens for the 4 authed accounts; losing it forces a re-OAuth from scratch.
