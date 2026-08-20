# Pass 04 — Maestro Flows

**Weight:** 3×

## What this audits
E2E flow coverage via Maestro YAML. Each user-critical flow should
have one flow file that exercises it end-to-end.

## Tier 0
```bash
find <project-root> -path '*/flows/*.yaml' -o -path '*.maestro*'
```

Per detected flow:
- Maestro `--dry-run` syntax check
- Categorize: launch, login/onboarding, primary feature, secondary feature

## Tier 1 (runs flows)
```bash
maestro test flows/ --device <UDID> --output report.xml
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | Flow for every critical user journey; all green; CI-run |
| 4 | Flows for primary journeys; secondary partial |
| 3 | A few flows but missing critical ones (e.g. payment, signup) |
| 2 | 1-2 flows of low coverage |
| 1 | No flows |

## Common findings
| Finding | Severity |
|---|---|
| No flows at all | **High** |
| Flow exists but uses `tapOn: <visual coordinate>` (brittle) | **Medium** |
| Flow lacks `assertVisible:` checkpoints (would silently pass on regression) | **Medium** |
| Flow depends on network state without `runFlow: setup.yaml` | **Medium** |

## Recommended fix
Start with one flow per primary tab. Pookoo example:

```yaml
# flows/home.yaml
appId: com.pookoo.app
---
- launchApp
- assertVisible: "Pookoo"        # greeting
- tapOn: "Add Trip"
- assertVisible: "New Trip"
- inputText: "Test Tokyo"
- tapOn: "Save"
- assertVisible: "Test Tokyo"
- takeScreenshot: home-add-trip
```

## Pookoo-specific
Zero flows. Bootstrap 5: home, flights, journal, scan-boarding-pass, settings.

## What NOT to flag
- Flows under `.maestro-experimental/` (intentional)
- Flows that legitimately need a logged-in fixture
