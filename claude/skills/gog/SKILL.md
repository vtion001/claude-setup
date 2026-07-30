---
name: gog
description: This skill should be used when the user asks to interact with Google Workspace from the shell — "send a gmail", "search gmail", "list calendar events", "create a calendar event", "search Google Drive", "read a Google Doc", "read/update a Google Sheet", "list Google Contacts", "fetch Google Tasks", or any "use gog" / "via gog" request. The `gog` CLI (Mach-O binary at /opt/homebrew/bin/gog, v0.9.0 from steipete/tap/gogcli) is already in PATH on this machine — no install needed. The ONLY authed account is vjrodriguez1994@gmail.com (gmail+calendar scopes via Desktop client `desktop-lofty`, project `lofty-bolt-453720-c7`, minted 2026-05-26). It's pinned via `GOG_ACCOUNT` env var in ~/.zshrc and via `account_clients` mapping in gog's config — so plain `gog gmail/calendar/...` commands work without any flags.
---

# gog — Google Workspace CLI (globalised, single-account)

Adapted from `~/.openclaw-joshuakim/skills/gog/SKILL.md` and the binary's own `--help`. Source upstream: https://gogcli.sh

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
