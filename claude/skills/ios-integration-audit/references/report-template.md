# /ios-integration-audit — Report Template

Extends `_ios-shared/report-template-shared.md`. Adds:

## Integration Inventory
| Integration | Present | Status |
|---|---|---|
| OAuth flows | Y/N | Correct / Issues |
| Universal Links | Y/N | |
| Custom URL schemes | Y/N | Schemes: ... |
| Push notifications (APNs) | Y/N | |
| Local notifications | Y/N | |
| App Intents | Y/N | Count: N |
| WidgetKit | Y/N | Widgets: N |
| Live Activities | Y/N | |
| StoreKit 2 | Y/N | |
| Sign in with Apple | Y/N | Compliance: OK / Required-missing |
| App Clips | Y/N | |
| Share extensions | Y/N | |
| SharePlay | Y/N | |

## App Store Review Risk
Flagged items that would cause a rejection at review:
- e.g. "Google Sign-In present + no Sign in with Apple → Guideline 4.8.0"

## Opportunity tier
Integrations that would add user value but aren't present. Estimated
effort: S/M/L.
