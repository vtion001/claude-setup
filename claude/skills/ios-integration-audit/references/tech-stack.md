# /ios-integration-audit — Tech Stack

## Tools

| Tool | Install | What it does |
|---|---|---|
| **AppAuth-iOS** | SPM `https://github.com/openid/AppAuth-iOS` | OAuth library that mandates ASWebAuthenticationSession + PKCE — RFC 8252 compliant |
| **StoreKit Testing** | bundled with Xcode | `.storekit` config for in-IDE IAP testing |
| **AASA Validator** | https://branch.io/resources/aasa-validator/ | Validates `apple-app-site-association` JSON |
| **Push notification tester** | Apple's Notification Tool / RemoteSim | Test pushes end-to-end |
| **App Intents Validation** | Xcode → App Intents preview | Test Shortcuts integration |

## MCP servers

| MCP | Use |
|---|---|
| **Apple Docs MCP** (kimsungwhee) | NL queries against developer.apple.com — invaluable for integration spec lookups |
| **XcodeBuildMCP** | Build + test runner; reads `.storekit` test results |

## Standards

| Standard | URL |
|---|---|
| **RFC 8252 — OAuth 2.0 for Native Apps** | https://datatracker.ietf.org/doc/html/rfc8252 |
| **RFC 7636 — PKCE** | https://datatracker.ietf.org/doc/html/rfc7636 |
| **Apple Associated Domains** | https://developer.apple.com/documentation/xcode/supporting-associated-domains |
| **Apple Push Notifications** | https://developer.apple.com/documentation/usernotifications |
| **Apple App Intents** | https://developer.apple.com/documentation/appintents |
| **Apple WidgetKit** | https://developer.apple.com/documentation/widgetkit |
| **Apple StoreKit 2** | https://developer.apple.com/storekit/ |
| **Sign in with Apple** | https://developer.apple.com/sign-in-with-apple/ |
| **App Store Review Guidelines 4.8** (Sign in with Apple) | https://developer.apple.com/app-store/review/guidelines/#sign-in-with-apple |

## Reference reading

- **WorkOS — Sign in with Apple review requirement** — https://workos.com/blog/apple-app-store-authentication-sign-in-with-apple-2025
- **WWDC25 — What's new in widgets** — https://developer.apple.com/videos/play/wwdc2025/278/
- **Live Activities + App Intents** — https://bfrearson.github.io/blog/ios-live-activties/
- **Deep-link security** — https://www.redfoxsec.com/blog/preventing-exploitation-of-deep-links
- **OAuth.tools** — https://oauth.tools (interactive OAuth flow debugger)

## Pookoo-specific baseline

Pookoo per exploration:
- Gmail OAuth via PKCE + ASWebAuthenticationSession (correct architecture)
- Custom URL scheme `pookoo://oauth/callback`
- No Universal Links (Associated Domains entitlement absent)
- No App Intents, WidgetKit, StoreKit, Sign in with Apple
- Push notifications: local only (not APNs)
- VisionKit for boarding pass scanning

First-run findings:
- **01-oauth-pkce**: 4/5 (PKCE correct; token storage flagged by security audit)
- **02-universal-links**: 1/5 (none; recommend adding for share-trip flows)
- **03-push-notifications**: N/A score 5 (local notifications only, correct usage)
- **04-app-intents**: 1/5 (none; "Add Trip via Siri" would be high-value)
- **05-widgetkit**: 1/5 (none; "Next flight" widget would be high-value)
- **06-storekit-2**: N/A score 5 (no IAP)
- **07-sign-in-with-apple**: N/A score 5 (no other social login; not required)
