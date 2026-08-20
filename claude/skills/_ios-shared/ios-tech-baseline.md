# iOS Tech Baseline (June 2026)

Pinned versions, paths, and assumptions every iOS audit skill builds on.

---

## Xcode + SDK
- **Xcode**: 26.5 (App Store) — required for iOS 26 SDK + Swift 6 mode
- **DEVELOPER_DIR**: `/Applications/Xcode.app/Contents/Developer`
  Pinned in `~/.zshrc` so `xcrun simctl` resolves to Xcode and not CommandLineTools
- **iOS SDK**: 26.5 (matches Xcode)
- **CommandLineTools** (`/Library/Developer/CommandLineTools`): may still be present; never use it as DEVELOPER_DIR for any audit work

## Swift
- **Language version**: Swift 5.0 default, Swift 6 mode opt-in on a per-target basis (`SWIFT_VERSION = 5` or `6`)
- **Concurrency**: Swift 6 strict concurrency mode is the long-term target; Swift 5.10+ is acceptable for legacy targets
- **Deployment target**: iOS 26.4 (Pookoo). Audits target iOS 17.0+ minimum (required for `XCUIApplication.performAccessibilityAudit`)

## Project format
- **XcodeGen** (`project.yml`) is the source of truth on this Mac for Pookoo
- Alternative formats audits must handle: `*.xcworkspace` (CocoaPods), `*.xcodeproj`, `Package.swift` (SPM)
- Detection order: `project.yml` → `*.xcworkspace` → `*.xcodeproj` → `Package.swift`

## Java + automation tooling (installed)
- **OpenJDK**: 17.0.19 at `/opt/homebrew/opt/openjdk@17/`
- **JAVA_HOME**: `/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home`
- **Maestro CLI**: 2.6.1 at `~/.maestro/bin/maestro`
- All three exported in `~/.zshrc` under the `# ── Maestro + Java` marker

## Simulator
- **Default device for audits**: iPhone 17, iOS 26.5
  UDID: `5F8D5C74-5D1C-43CA-9325-45DDA228B43B`
- **Secondary devices**: iPhone 17 Pro, iPhone Air, iPad Air 11-inch (M4) — used for device-class audits
- **Boot pattern**: idempotent `xcrun simctl boot <UDID>` (no-op if booted)

## Paired physical device (Pookoo dev)
- **Vincent John Rodriguez's iPhone 15 Pro Max** (iOS 26.5)
  UDID: `00008130-000169AE3601001C`
- **Sideload bundle ID**: `com.vjrodriguez.pookoo` (Personal Team, free)
- **Production bundle ID** (TestFlight + App Store): `com.pookoo.app`
- **Team ID**: env var `POOKOO_DEV_TEAM` (never commit)

## Build commands
```bash
# Simulator build
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild -project <Project>.xcodeproj -scheme <Scheme> \
  -destination 'platform=iOS Simulator,name=iPhone 17' build

# Device deploy (Pookoo-specific via Makefile)
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
POOKOO_BUNDLE_ID=com.vjrodriguez.pookoo \
POOKOO_DEV_TEAM=63LMV9KR2L \
make device-install
```

## Known dependency-free baseline (Pookoo)
Pookoo has **zero external SPM/CocoaPods/Carthage dependencies**. Apple-only.
Audits should not assume any third-party SDK is present.

## Standard audit-tool install commands

Reference list every audit Phase 0 may invoke via `_ios-shared/scripts/install-tool.sh`:

| Tool | Install | Purpose |
|---|---|---|
| SwiftLint | `brew install swiftlint` | Linter |
| SwiftFormat | `brew install swiftformat` | Formatter |
| Periphery | `brew install periphery` | Dead-code detection |
| xcbeautify | `brew install xcbeautify` | Pretty xcodebuild output |
| mobsfscan | `pip install mobsfscan` | Mobile security static scan |
| Proxyman | `brew install --cask proxyman` | HTTP debugging proxy |
| Maestro | already installed | E2E flow automation |
| AppAuth-iOS | SPM `https://github.com/openid/AppAuth-iOS` | OAuth (read-only check) |
| swift-snapshot-testing | SPM | Snapshot tests (recommendation) |
| xcodes | `brew install xcodes` | Xcode version manager |

Auto-install rule: `_ios-shared/scripts/install-tool.sh <name>` detects
presence with `command -v` (or `pip show`), prompts user yes/no, runs the
install, verifies, returns 0/1.
