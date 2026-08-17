# /ios-security-audit — Report Template

Extends `~/.claude/skills/_ios-shared/report-template-shared.md`. Adds
security-specific sections.

## Additional sections in `report.md`

### Threat Model Summary
Brief statement of the assumed threat model (L1 default, L2 if user
declares). Drives the weighting and severity calibration.

### MASVS Conformance Matrix

| Control | Score | Status |
|---|---|---|
| MASVS-STORAGE-1 | 1/5 | ❌ FAIL — see F-001, F-002 |
| MASVS-NETWORK-1 | 4/5 | ✅ PASS with note |
| ... | | |

(One row per MASVS control covered by the 10 passes.)

### Severity Distribution
```
Critical:  ████████  3
High:      ██████    2
Medium:    ████      1
Low:       ██        1
```

### Migration Estimate

For each Critical / High finding, an effort estimate:
- **S (small)**: ≤ 4 hours
- **M (medium)**: 1-2 days
- **L (large)**: 1 week+
- **XL**: requires architecture change

Total estimated effort: <hours/days> across all Critical + High.

### Remediation Sequence (recommended)

Suggested order to address findings, balancing severity + dependency:

1. F-XXX (Critical) — independent, ship first
2. F-YYY (Critical) — depends on F-XXX
3. F-ZZZ (High) — independent

(Helps the team plan a security sprint instead of treating findings as a
flat list.)

### Compliance Notes

If the app is subject to specific regulations, callouts here:
- **App Store Review Guidelines 5.1.x** — privacy + data handling
- **GDPR** (if EU users) — secure storage requirements
- **PCI DSS** (if payment data) — encryption at rest + in transit
- **HIPAA** (if health data) — Keychain + ATS minimums

---

## scorecard.md additions

Add a "MASVS L1 baseline" line above the score box:

```
╔════════════════════════════════════════╗
║  SEC-iOS:           NN / 100           ║
║  Implied MASVS:     L1 / L1+ / L2       ║
║  Critical findings: N                  ║
║  Required for ship: N                  ║
╚════════════════════════════════════════╝
```
