# Pass 04 — App Intents / Shortcuts

**Weight:** 1×

## What this audits
- `AppIntent` types
- `AppShortcutsProvider`
- Parameter validation
- Phrases registered in `AppShortcuts.app`
- Spotlight integration via Donate API

## Tier 0
```bash
grep -rln --include='*.swift' 'AppIntent\|@Parameter\|AppShortcutsProvider\|AppShortcut' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | Primary user actions exposed as App Intents + Shortcuts. Donations to Spotlight. |
| 4 | A few intents; partial coverage |
| 3 | Intents declared but not surfaced (no AppShortcutsProvider) |
| 2 | Intents broken (parameters undefined, no localized phrases) |
| 1 | N/A — score 1 only if intents would clearly add user value but are absent |

## Recommended fix (Pookoo example)
```swift
struct AddTripIntent: AppIntent {
    static var title: LocalizedStringResource = "Add Trip"

    @Parameter(title: "Destination")
    var destination: String

    func perform() async throws -> some IntentResult {
        await AppState.shared.addTrip(destination: destination)
        return .result(dialog: "Added \(destination) to your trips.")
    }
}
```

## What NOT to flag
- Apps where Siri / Shortcuts integration genuinely doesn't add value
