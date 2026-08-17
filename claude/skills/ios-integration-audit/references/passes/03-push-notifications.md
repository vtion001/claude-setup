# Pass 03 — Push Notifications

**Weight:** 2×

## What this audits
- APNs entitlement (`aps-environment`) — `development` / `production`
- `UIBackgroundModes` includes `remote-notification` (for silent push)
- Registration on launch (`registerForRemoteNotifications()`)
- Permission request UX (delayed, contextual)
- `UNUserNotificationCenter` delegate handlers

## Tier 0
```bash
plutil -p Info.plist | grep -A 3 -E 'aps-environment|UIBackgroundModes'
grep -rln --include='*.swift' 'registerForRemoteNotifications\|UNUserNotificationCenter' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | APNs registered; contextual permission ask; handlers route notifications to relevant screens; tested via tools |
| 4 | Registration + handlers; permission ask is on-launch (suboptimal) |
| 3 | Local notifications only; no APNs |
| 2 | APNs without handlers (notifications open the wrong screen) |
| 1 | N/A — only score 1 if push is the app's primary value and totally broken |

## Pookoo
Local notifications only (pre-flight reminders). Correct usage. Score 5/5.

## What NOT to flag
- Apps that don't need push (local notifications are sufficient)
- Apps in TestFlight without production aps-environment yet
