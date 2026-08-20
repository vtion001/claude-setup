# /ios-code-review — Tech Stack

## Tools

| Tool | Install | What it does |
|---|---|---|
| **SwiftLint** | `brew install swiftlint` | 200+ configurable Swift style rules. Industry default. ([repo](https://github.com/realm/SwiftLint)) |
| **SwiftFormat** | `brew install swiftformat` | Opinionated Swift code formatter. ([repo](https://github.com/nicklockwood/SwiftFormat)) |
| **Periphery** | `brew install periphery` | Dead-code detection via SourceKit. ([repo](https://github.com/peripheryapp/periphery)) |
| **SwiftLens** | `pip install swiftlens` | SourceKit-LSP wrapper for semantic Swift analysis. ([repo](https://github.com/swiftlens/swiftlens)) |
| **xcbeautify** | `brew install xcbeautify` | Pretty xcodebuild output. ([repo](https://github.com/cpisciotta/xcbeautify)) |

## MCP servers

| MCP | Status | Use |
|---|---|---|
| **Swift LSP plugin** (Anthropic) | Published | https://claude.com/plugins/swift-lsp |
| **SwiftLens MCP** | Published | https://github.com/swiftlens/swiftlens |
| **cclsp** (generic LSP↔MCP bridge) | Published | Wrap any LSP for Claude |
| **XcodeBuildMCP** | Published | Runs builds, reads test results |

## Standards

| Standard | URL |
|---|---|
| **Swift API Design Guidelines** | https://www.swift.org/documentation/api-design-guidelines/ |
| **Swift Forum / Evolution proposals** | https://forums.swift.org/c/evolution/18 |
| **SwiftLint rule documentation** | https://realm.github.io/SwiftLint/rule-directory.html |
| **Apple's Swift documentation comments** | https://www.swift.org/documentation/docc/writing-symbol-documentation-in-your-source-files |

## Reference reading

- **Periphery 3.0 guide** (Swiftfy): https://medium.com/swiftfy/clean-your-dead-code-with-periphery-3-0-on-ios-dc6031aa50eb
- **MobileNativeFoundation dead-code consensus** (Lyft/Spotify/Airbnb): https://github.com/MobileNativeFoundation/discussions/discussions/156
- **SwiftLint config samples** (Realm, Airbnb, raywenderlich): see each repo's `.swiftlint.yml`
- **Swift API Design talks** — WWDC16 "Swift API Design Guidelines": https://developer.apple.com/videos/play/wwdc2016/403/
- **Swift Forums best practices** for new code

## Pookoo-specific baseline

Pookoo has NO `.swiftlint.yml` and NO `.swiftformat`. First-run findings:
- **01-swiftlint-rules**: 1/5 (no rules enforced)
- **02-swiftformat-config**: 2/5 (consistent style observed but no enforcement)
- **03-dead-code-periphery**: needs runtime — `EventKit` import flagged
  unused by `/ios-integration-audit`'s exploration
- **06-dependency-hygiene**: 5/5 (zero deps = nothing to flag)
