# /ios-backend-audit — Report Template

Extends `_ios-shared/report-template-shared.md`. Adds:

## Concurrency Model Summary
- Services using `actor`: X
- Services using `@MainActor`: Y
- Services using neither (legacy): Z
- Swift 6 strict mode enabled: yes/no

## Persistence Inventory
| Type | Count | Notes |
|---|---|---|
| UserDefaults keys | N | Total data size ~K KB |
| SwiftData @Model | N | |
| Core Data | N | |
| FileManager writes | N | Directory: Documents / Caches / Application Support |
| Keychain | (deferred to security audit) | |

## Cross-skill notes
- Token storage findings → /ios-security-audit pass 01
- OAuth flow correctness → /ios-integration-audit pass 01
