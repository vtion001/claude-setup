# /ios-ui-impl-audit — Tech Stack

## Tools

| Tool | Install | What it does |
|---|---|---|
| **Instruments 26 — SwiftUI instrument** | bundled | View body recomputation tracing, hitch attribution (4 lanes) |
| **Accessibility Inspector** | bundled (Xcode → Open Developer Tool) | A11y audit + Dynamic Type preview |
| **xcbeautify** | `brew install xcbeautify` | Pretty xcodebuild output |
| **Maestro** | already installed | Device-class screenshot capture |
| **SwiftLens** | `pip install swiftlens` | Semantic Swift queries via SourceKit-LSP |

## MCP servers

| MCP | Use |
|---|---|
| **XcodeBuildMCP** | Build + simulator control + Instruments traces |
| **Figma Dev Mode MCP** | Cross-check implementation vs design source (Xcode 27 beta) |
| **SwiftLens MCP** | Find symbol references |
| **Apple Docs MCP** | NL queries against HIG paths |

## Standards

| Standard | URL |
|---|---|
| **Apple HIG — Accessibility** | https://developer.apple.com/design/human-interface-guidelines/foundations/accessibility |
| **Apple HIG — Layout** | https://developer.apple.com/design/human-interface-guidelines/foundations/layout |
| **Apple HIG — SF Symbols** | https://developer.apple.com/design/human-interface-guidelines/sf-symbols |
| **Apple HIG — Dark Mode** | https://developer.apple.com/design/human-interface-guidelines/dark-mode |
| **WCAG 2.5.5 (target size)** | https://www.w3.org/WAI/WCAG21/Understanding/target-size.html |
| **WCAG 2.2** | https://www.w3.org/TR/WCAG22/ |
| **Apple Reduce Motion** | https://developer.apple.com/documentation/swiftui/environmentvalues/accessibilityreducemotion |

## Reference reading

- **WWDC25 — Optimize SwiftUI performance with Instruments** — https://dev.to/arshtechpro/wwdc-2025-optimize-swiftui-performance-with-instruments-4o4j
- **WWDC24 — Build a great Lock Screen camera experience** (size-class patterns)
- **WWDC23 — Demystify SwiftUI performance** — search WWDC
- **Apple Accessibility on iOS Programming Guide**
- **Sundell — SwiftUI Dynamic Type** — https://www.swiftbysundell.com/

## Pookoo-specific baseline

Per exploration:
- **Dark mode**: not implemented (only "white background + green" — no ColorScheme adaptation)
- **Hit targets**: needs runtime check
- **Dynamic Type**: needs runtime check; SF Rounded design may clip at larger sizes
- **Size classes**: iPad supported per `supportedDestinations: [iphone, ipad]` — needs verification
- **SF Symbols**: extensively used — strong positive
- **Motion-reduce**: needs runtime check
- **RTL**: not internationalized — score N/A

First-run findings:
- **01-hit-targets**: needs Maestro runtime check
- **02-dynamic-type**: needs runtime check, likely Medium
- **03-dark-mode**: 1/5 (not implemented)
- **04-size-classes**: needs iPad runtime check, likely Medium
- **05-sf-symbols**: 5/5
- **06-view-body-perf**: needs Instruments trace
- **07-motion-reduce**: needs runtime check
- **08-rtl-locale**: N/A score 5 (not internationalized)
