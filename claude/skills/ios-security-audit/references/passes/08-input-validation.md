# Pass 08 — Input Validation (ML / PDF / Image / Deep Link / URL)

**Weight:** 2×
**MASVS:** MASVS-CODE-1, MASVS-PLATFORM-1, MASVS-PLATFORM-5
**MSTG:** MSTG-CODE-8, MSTG-PLATFORM-3, MSTG-PLATFORM-5

## What this audits

External, untrusted input reaching the app:
- **VisionKit / Vision ML** — PDF and image scanning (e.g. boarding pass)
- **Deep links** — `pookoo://oauth/callback`, custom URL schemes
- **Universal Links** — AASA-driven inbound URLs
- **WKWebView** message handlers (`WKScriptMessageHandler`)
- **App Intents / Shortcuts** — parameters from Siri / Shortcuts.app
- **Pasteboard reads**
- **Push notification payloads**

The audit confirms each entry point validates, size-limits, and sanitizes
before passing data to business logic.

## Tier 0 — static

```bash
# Deep link handlers
grep -rn --include='*.swift' \
  -E '\.onOpenURL|application\(_:open:options:\)|UIApplicationDelegate.*openURL' \
  <project-root>

# VisionKit / Vision usage
grep -rn --include='*.swift' \
  -E 'VNRecognizeTextRequest|DataScannerViewController|PDFKit\.PDFDocument|UIImagePickerController' \
  <project-root>

# WKScriptMessageHandler (high-risk JS bridge)
grep -rn --include='*.swift' \
  -E 'WKScriptMessageHandler|WKUserContentController|addUserScript|addScriptMessageHandler' \
  <project-root>

# Pasteboard reads
grep -rn --include='*.swift' \
  -E 'UIPasteboard\.general\.(string|url|image|items)' \
  <project-root>
```

## Scoring (1–5)

| Score | Criteria |
|---|---|
| 5 | Every entry point validates type + size + format. Deep links go through a routing dispatcher with allowlist. ML input has explicit size caps. WKWebView (if used) uses postMessage allowlist. |
| 4 | Mostly validated. 1-2 entry points missing size limits. |
| 3 | Validation present but inconsistent. ML input unbounded but unlikely to be malicious in practice. |
| 2 | Deep links parse parameters straight into business logic. |
| 1 | Untrusted input flows directly into URL constructors / SQL / view rendering / file paths. |

## Common findings + severity

| Finding | Severity |
|---|---|
| Deep link query param appended directly to URL request | **Critical** (server-side risk) |
| Deep link param used as a file path | **Critical** (path traversal) |
| PDF / image input without size limit (DoS surface) | **High** |
| `WKScriptMessageHandler` accepting messages without source validation | **Critical** |
| Pasteboard read auto-actioning (e.g. auto-submit) | **High** (clipboard spying) |
| AASA missing `paths` allowlist (every URL caught) | **Medium** |
| ML model loaded from network without integrity check | **High** |

## Recommended fixes

**Deep link router pattern** — all `.onOpenURL` flows through a single
dispatcher:

```swift
struct DeepLinkRouter {
    static func handle(_ url: URL, appState: AppState) {
        guard url.scheme == "pookoo" else { return }
        guard let host = url.host else { return }

        switch host {
        case "oauth":
            handleOAuthCallback(url, appState: appState)
        case "open":
            handleOpenScreen(url, appState: appState)
        default:
            return // Unknown route — drop, don't crash
        }
    }

    private static func handleOAuthCallback(_ url: URL, appState: AppState) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else { return }

        // Strict allowlist of params we accept
        var code: String?
        var state: String?
        for item in queryItems {
            switch item.name {
            case "code":  code = item.value
            case "state": state = item.value
            default:      continue
            }
        }
        guard let code = code, let state = state,
              GmailService.shared.verifyState(state) else { return }
        Task { await GmailService.shared.exchange(code: code) }
    }
}
```

**Image / PDF size limits**:
```swift
guard imageData.count <= 10 * 1024 * 1024 else {
    throw ImportError.tooLarge
}
```

## What NOT to flag

- Simple `Text("...")` rendering of user input — SwiftUI escapes by default
- Calls to `UIApplication.shared.open(_:)` with user-tap-initiated URLs
  that go through the user's choice (browser, Maps app, etc.)
- Pasteboard reads on explicit user action (Paste menu) that show
  Apple's permission UI
