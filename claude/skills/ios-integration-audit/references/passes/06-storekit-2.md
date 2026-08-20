# Pass 06 — StoreKit 2

**Weight:** 2×

## What this audits
For apps that monetize:
- StoreKit 2 (`Transaction.currentEntitlements`) not legacy StoreKit
- `.storekit` test config committed
- Server-side receipt validation (when applicable)
- Subscription state observation
- Restore Purchases entry point in UI

## Tier 0
```bash
grep -rln --include='*.swift' 'import StoreKit\|Transaction\.currentEntitlements\|Product\.products' <project-root>
ls *.storekit 2>/dev/null
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | StoreKit 2; `.storekit` config; entitlement observation; restore button |
| 4 | StoreKit 2 with minor gaps |
| 3 | Legacy StoreKit |
| 2 | IAP code present but Restore Purchases missing (App Store reject) |
| 1 | N/A — no IAP in the app, score 5 |

## What NOT to flag
- Free apps with no monetization
- B2B apps where billing is out-of-band
