# Email channel

The same seven phases in the parent `SKILL.md` apply unchanged — email is just a different Phase 1 fetch mechanism. This reference is lighter than `whatsapp-wacli.md` because it hasn't been exercised end-to-end the way the WhatsApp path has; treat the phase structure as solid (it's channel-agnostic by design) but verify the specific tool commands empirically each time rather than trusting this as a tested recipe.

## Pull the thread

Use whatever email access is actually connected in the session — check `ToolSearch` for Gmail/Microsoft 365 MCP tools (`mcp__claude_ai_Gmail__search_threads` / `get_thread`, or the Microsoft 365 equivalents) before assuming a specific one is available. Search/filter to the specific sender and thread, then read every message in the thread top to bottom — the same "don't stop at the first item, don't skim for keywords" discipline from Phase 2 applies, and email threads bury asks in quoted-reply chains just as easily as a WhatsApp scroll does.

## Attachments are the email equivalent of WhatsApp images

Download and actually open every attachment (screenshots, docs, spec sheets) before deciding it's irrelevant — same reasoning as the WhatsApp media step: you don't know what's in an uncaptioned attachment until you look.

## Confirm completeness

Email threads don't have a WhatsApp-style `unread_count`/`last_message_ts` chat-metadata shortcut, but the equivalent check still applies: after fetching, confirm you have the *most recent* message in the thread (check the thread's own message count / latest-message timestamp against what your search returned) before treating the fetch as complete. A search that silently paginates or caps results will make you miss the newest messages exactly the way a truncated `wacli` fetch does.

## Sending

Same gate as WhatsApp: drafting a reply is part of this skill's output; sending it to the actual client is a separate, explicit, operator-approved step — never automate past that gate regardless of channel.
