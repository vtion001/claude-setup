# Session continuity (memory-toolkit)

`memory-toolkit` is installed globally. Use it to carry work across sessions:

- **Starting substantive work** → run `/session-start`. Loads last handoff (branch, last commit, uncommitted files, next steps). Its `SessionStart` hook also surfaces this automatically; `PreCompact` auto-saves before compaction.
- **Before wrapping up** → run `/session-end`. Writes a handoff to `workstreams/<name>/handoff.md` for the next session.
- Also: `/session-continue`, `/park`, `/reflect`, `/session-restore`.

Scope this to real multi-step work — don't ceremony-wrap trivial one-off sessions.

memory-toolkit carries *in-flight task state* between sessions. Complements auto-memory (durable facts).

# Client/Team-Facing Messages — Write in the Operator's Voice, No AI Tells

Applies to any message sent on the operator's behalf to a human or group they're part of —
WhatsApp (wacli), Telegram, Slack, email — as opposed to generated documents (PDF reports,
markdown files, dashboards), where structure/tables/headers are still appropriate.

- **No emojis** unless the operator's own established style in that specific thread already
  uses them consistently — default to none.
- **No AI-generated structural tells**: no markdown headers, no repeated `**bold label:**`
  patterns, no emoji-numbered lists (1️⃣2️⃣3️⃣), no "Here's a breakdown" / "Key takeaways" /
  "Bottom line" framing scaffolding. Write plain prose in short paragraphs, the way a person
  actually types a WhatsApp update — not a report pasted into a chat window.
- **No em dashes or en dashes** (—, –) — another classic AI tell. Use a period, comma, "and",
  or just a plain hyphen-free rephrase instead. Leave literal hyphens alone only where they're
  part of a real identifier, name, or date (e.g. `rex-reengage-2026`, a person's actual
  hyphenated name) — those aren't a style choice and shouldn't be altered.
- **Personalize it**: match the voice/tone of the account's own prior messages in that thread
  (check recent history first) rather than a generic professional-report register.
- Before sending, re-read the draft and ask: would this read as obviously AI-written to someone
  who knows the sender? If yes, rewrite.
 - This does not relax the separate rule that any external send still needs the operator's
   explicit go-ahead on content and destination — it only governs the *style* once content is
   approved.

# Destructive writes — confirm before firing, never assume additive

Applies to ANY write that deletes, replaces, overwrites, or clears existing data or config — in a
database, a CRM, an API, a cloud service (Render/Neon/etc.), a file, or a config store.

- **Any delete, any clear, any bulk reassignment/replacement → stop and confirm first.** Echo back
  exactly what will change (names, counts, IDs) and get an explicit go-ahead before firing. A
  "quick cleanup" or "set this one value" that silently removes something else is exactly the bug
  this rule exists to stop.
- **Never assume a write is additive. Verify the API's semantics first.** A `PUT`/`POST`/`PATCH`
  to a collection endpoint may *replace the whole collection* instead of adding to it (verified:
  Render's `PUT /v1/services/{id}/env-vars` replaces every env var on the service — a single-element
  body wipes the rest; a `DELETE /{parent}` cascades to everything under it). When in doubt, read
  the endpoint's replace-vs-add behavior before sending a write.
- **Before firing a config write, GET the current state and record it.** You need a recovery
  baseline (the full prior value set) in case the write turns out to be destructive. If the write
  would remove values you can't reconstruct (secrets that live only in the target store), flag that
  to the operator and get explicit sign-off before proceeding.
- **`delete` / `replace` / `clear` / `unset` / `wipe` are the trigger words.** If your planned
  action (or a command you're about to run) matches any of them, treat it as destructive and apply
  this section.

This complements (does not replace) the confirm-before-send rule for external messages above. A
wrong config write can take the site down; confirm it like one.

# Skills — available in both Claude Code AND opencode

All skills from `~/.claude/skills/` (Claude Code) are also discoverable by opencode from `~/.config/opencode/skills/` (global) and `.opencode/skills/` (project-local). Use `/command` in Claude Code, or the `skill` tool in opencode.

## Memory-toolkit management
`/session-start` `/session-end` `/session-continue` `/session-restore` `/park` `/reflect` `/docs-reflect` `/memory` `/memory-setup` `/session-insights` `/task-template`

## iOS / Swift development
`/swiftui-pro` `/swift-concurrency-pro` `/swift-testing-pro` `/swiftdata-pro` `/swift-concurrency-expert` `/core-data-expert`
`/swiftui-liquid-glass` `/swiftui-performance-audit` `/swiftui-ui-patterns` `/swiftui-view-refactor`
`/ios-audit-pipeline` `/ios-security-audit` `/ios-backend-audit` `/ios-integration-audit`
`/ios-code-review` `/ios-qa-audit` `/ios-ui-impl-audit` `/ios-dev-workbench` `/ios-debugger-agent`
`/ios-accessibility` `/ios-simulator-skill`
`/app-intents` `/widgets` `/background-execution`
`/test-driven-development` `/testing-dags`

## Apple ecosystem (apple-skills plugin)
`/app-store` `/apple-intelligence` `/core-ml` `/design` `/foundation` `/generators` `/growth`
`/ios` `/legal` `/macos` `/mapkit` `/monetization` `/performance` `/product`
`/release-review` `/security` `/shared` `/swift` `/swiftdata` `/swiftui` `/testing`
`/visionos` `/watchos`

## App Store Connect
`/app-store-changelog` `/asc-cli-usage` `/asc-release-flow` `/asc-testflight-orchestration`
`/asc-whats-new-writer` `/asc-xcode-build`

## Property / Real Estate
`/alto-os` `/connecting-to-alto-mac-mini` `/hero-video-generator` `/marketing-reel-generator`
`/property-listing-video` `/revamping-client-sites` `/probing-integration-endpoints`

## Business / VJR-OS
`/vjr-os` `/vjr-status` `/vjr-acquire-leads` `/vjr-deliver-project` `/vjr-marketing`
`/vjr-quote-to-cash` `/writing-delivery-reports` `/client-feedback-cross-reference`
`/doctor-health-check` `/six-sigma-business` `/six-sigma-mbb`

## Web development / audit
`/ui-audit` `/ux-audit` `/ui-promax` `/ui-ux-pro-max` `/qa-audit` `/backend-audit`
`/code-audit` `/security-audit` `/audit-orchestrator` `/playwright`
`/brainstorming` `/modularize` `/writing-plans` `/writing-skills`
`/skill-creator` `/self-improving-agent` `/systematic-debugging`

## Ponytail (anti-overengineering)
`/ponytail` `/ponytail-audit` `/ponytail-debt` `/ponytail-gain` `/ponytail-help` `/ponytail-review`

## macOS
`/macos-menubar-tuist-app` `/macos-spm-app-packaging`

## CLI tools
`/gog` (Google Workspace from shell) `/launch-remote-control` `/cloudflare-mcp`

## Process
`/dispatching-parallel-agents` `/executing-plans` `/subagent-driven-development`
`/task-decompose` `/finishing-a-development-branch` `/using-git-worktrees`
`/requesting-code-review` `/receiving-code-review` `/verification-before-completion`
`/on-boarding-generator` `/claude-md-improver`
