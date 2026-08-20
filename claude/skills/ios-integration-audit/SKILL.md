---
name: ios-integration-audit
description: >
  iOS integration audit. Covers OAuth + PKCE, Universal Links + custom
  URL schemes, push notifications, App Intents + App Shortcuts,
  WidgetKit, Live Activities, StoreKit 2, Sign in with Apple, App Clips,
  SharePlay, and share extensions. Benchmarked against RFC 8252 + Apple
  integration guidelines.

  Triggers: "ios integration audit", "oauth check", "universal links",
  "app intents", "widget audit", "deep link review", "/ios-integration-audit",
  "is my oauth correct", "sign in with apple review".

  Flags:
    --quick           # Static only
    --pass <names>    # Cherry-pick
    --linear

  Sibling skills:
    - /ios-security-audit owns token storage, ATS, cert pinning
    - /ios-backend-audit owns URLSession patterns and concurrency
---

# iOS Integration Audit

Static + AI audit for the third-party + system integrations a SwiftUI
iOS app commonly carries. Benchmarked against **RFC 8252** (OAuth for
Native Apps), Apple's integration guidelines, and current App Store
Review requirements.

## Prerequisites

- macOS with Xcode 26.5 + DEVELOPER_DIR
- An iOS project at cwd

## Invocation

```
/ios-integration-audit
/ios-integration-audit --pass oauth-pkce,sign-in-with-apple
/ios-integration-audit --quick
```

## Pass Names

`oauth-pkce`, `universal-links`, `push-notifications`, `app-intents`,
`widgetkit`, `storekit-2`, `sign-in-with-apple`

## Workflow

### Phase 0
Detect project. Inventory `Info.plist` for `CFBundleURLTypes`,
`UIBackgroundModes`, `NSUserActivityTypes`, `aps-environment`. Inventory
entitlements for capabilities (Associated Domains, Push, App Intents,
StoreKit, In-App Purchase).

### Phase 1: Tier 0 — static
Run per-pass scans.

### Phase 2: Tier 2 — AI reasoning
For each integration, reason about correctness against the published
standard.

### Phase 3: Source cross-reference
Tag with `file:line`.

### Phase 4: Report
`<project>/ios-audit/ios-integration-audit/`.

## Rules

- **Defer to /ios-security-audit** for any secret / token / Keychain issue.
- **Defer to /ios-backend-audit** for URLSession / concurrency issues
  inside an OAuth flow.
- **Cite the standard.** OAuth findings reference RFC 8252 sections. Apple
  integration findings reference the Apple docs URL.
- **App Store Review readiness.** If Sign in with Apple is missing on an
  app that uses any other social login → App Store Review will reject.
  Flag as Critical.

## Reference files

- `references/passes/01-oauth-pkce.md`
- `references/passes/02-universal-links.md`
- `references/passes/03-push-notifications.md`
- `references/passes/04-app-intents.md`
- `references/passes/05-widgetkit.md`
- `references/passes/06-storekit-2.md`
- `references/passes/07-sign-in-with-apple.md`
- `references/scoring-rubric.md`
- `references/report-template.md`
- `references/tech-stack.md`
- `references/deep-references.md`
- `scripts/install-tools.sh`
- `scripts/integrations-scan.sh`
