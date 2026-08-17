# Pass 04 — Persistence Layer Choice

**Weight:** 3×

## What this audits
Is the right persistence mechanism used for the data shape?

| Data type | Recommended |
|---|---|
| User preferences, feature flags | UserDefaults |
| Small Codable graphs (< 100 KB) | UserDefaults (Codable + JSON) |
| Large structured data | SwiftData (iOS 17+) or GRDB |
| Existing legacy apps | Core Data |
| Sensitive data | Keychain (defers to /ios-security-audit) |
| Cache (purgeable) | FileManager `caches` |
| Documents (user-owned) | FileManager `documents` |

## Tier 0
```bash
grep -rln --include='*.swift' 'UserDefaults\|SwiftData\|@Model\|NSManagedObject\|GRDB\|import RealmSwift\|FileManager' <project-root>

# Size estimate: how big is the UserDefaults payload?
# Run app, then: defaults read <bundle-id> | wc -c
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | Right tool for the data; clean separation Service-layer |
| 4 | Right tools; minor inconsistency |
| 3 | Mostly UserDefaults for everything (works at current scale but won't scale) |
| 2 | Wrong tool: large Codable in UserDefaults; Core Data with one entity |
| 1 | Multiple persistence engines fighting; race conditions; data loss observed |

## Common findings
| Finding | Severity |
|---|---|
| Large array (50+ items) JSON-encoded into UserDefaults on every write | **Medium** |
| `JSONEncoder().encode(...)` on main thread for large data | **Medium** |
| No migration story (saved data fields not optional/defaulted) | **High** |
| Multiple stores for the same data type | **Medium** |

## Pookoo-specific
UserDefaults + FileManager. Works at current scale (~few KB per user).
Flag growth path: if `SocialTipStore` ever exceeds 100 KB, migrate to
SwiftData. Document this threshold in CLAUDE.md.

## What NOT to flag
- UserDefaults for genuine preferences
- Cache directories that handle purge gracefully
