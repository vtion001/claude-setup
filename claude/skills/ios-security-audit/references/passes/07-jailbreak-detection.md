# Pass 07 — Jailbreak Detection (Optional, MASVS L2)

**Weight:** 1× (L1 apps: Low priority; L2 apps: upgrade to 2×)
**MASVS:** MASVS-RESILIENCE-1 (L2)
**MSTG:** MSTG-RESILIENCE-1, MSTG-RESILIENCE-2

## What this audits

For apps handling high-value data (banking, payment, government, healthcare),
does the app detect jailbroken devices and refuse to operate, or degrade
gracefully?

For most consumer apps this pass is **not applicable** — only flag if the
project's CLAUDE.md or threat model declares L2.

## Tier 0 — static

```bash
# Look for jailbreak-detection libraries or patterns
grep -rn --include='*.swift' \
  -E 'IOSSecuritySuite|jailbreakStatus|isJailbroken|/Applications/Cydia\.app|/private/var/lib/apt|/bin/bash|fork\(\)' \
  <project-root>
```

## Scoring (1–5)

For **L1** apps (default): always 5 if not applicable. Add a note in the
report explaining this is L2-only.

For **L2** apps:

| Score | Criteria |
|---|---|
| 5 | IOSSecuritySuite or equivalent. Detection on launch + before sensitive ops. Behavior: refuse + telemetry. Hardened against bypass (multiple checks). |
| 4 | Detection present. Behavior: warn user + telemetry. |
| 3 | Single-check detection (easy to bypass). |
| 2 | Detection logic exists but result is logged only, never enforced. |
| 1 | No detection in an L2 app. |

## Common findings + severity (L2 only)

| Finding | Severity |
|---|---|
| No jailbreak detection in L2 app | **High** |
| Single-check detection (only checks for `Cydia.app`) | **Medium** |
| Detection but no enforcement | **High** |
| Detection bypass-able via simple Frida hook (no signature/integrity) | **Medium** |

## Recommended fixes

For L2 apps, use **IOSSecuritySuite**:

```swift
import IOSSecuritySuite

if IOSSecuritySuite.amIJailbroken() {
    // L2 + sensitive: refuse to launch sensitive flows
    // L1 + best-effort: log + degrade
    presentJailbreakWarning()
    return
}
```

Combine with `IOSSecuritySuite.amIDebugged()` and
`IOSSecuritySuite.amIReverseEngineered()` for defense in depth.

## What NOT to flag

- Consumer apps (food delivery, social, productivity) — jailbreak
  detection is annoying for power users and offers limited security gain
- Apps without an explicit L2 threat model
- Detection that's overly aggressive (rejects users with developer-mode
  enabled on a non-jailbroken device)
