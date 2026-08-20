# Pass 10 — Code Obfuscation & Resilience (Optional, MASVS L2)

**Weight:** 1× (L1 apps: skip; L2 apps: 2×)
**MASVS:** MASVS-RESILIENCE-2, MASVS-RESILIENCE-3, MASVS-RESILIENCE-4
**MSTG:** MSTG-RESILIENCE-9 through MSTG-RESILIENCE-13

## What this audits

For L2 apps: how hard is the binary to reverse-engineer and modify?

- Symbol stripping (release builds)
- String encryption for sensitive constants
- Anti-debugging / `ptrace` deny
- Anti-tampering (code-signing self-check)
- Anti-emulator detection (less relevant on iOS than Android)

## Tier 0 — static

```bash
# Check release build symbol strip setting
grep -rn -E 'STRIP_INSTALLED_PRODUCT|STRIP_STYLE|DEPLOYMENT_POSTPROCESSING' \
  project.yml *.xcconfig 2>/dev/null

# Check for hardcoded sensitive strings (overlap with pass 01 but framed differently)
grep -rn --include='*.swift' \
  -E '"[A-Za-z0-9_+/=\-]{32,}"' \
  <project-root> | grep -v "// pragma: allowlist secret"
```

## Scoring (1–5)

For **L1** apps (default): always 5 if not applicable. Add note: L2 only.

For **L2** apps:

| Score | Criteria |
|---|---|
| 5 | Symbols stripped. Sensitive strings encrypted. Anti-debug present. Self-integrity check via `SecCodeCopyDesignatedRequirement`. |
| 4 | Symbols stripped. Strings mostly encrypted. Anti-debug missing. |
| 3 | Symbols stripped (only). No string encryption. |
| 2 | Symbols present in release build. |
| 1 | Symbols present AND sensitive strings visible AND no integrity checks. |

## Recommended fixes

For L2 apps:
- Set `STRIP_INSTALLED_PRODUCT = YES` and `STRIP_STYLE = all` in release
- Encrypt sensitive constants at build time; decrypt at use
- Use `IOSSecuritySuite.amIDebugged()` for anti-debug
- Validate the app's own code signature in release builds

## What NOT to flag

- L1 apps (most consumer apps)
- Symbol presence in debug builds (intentional, not a finding)
- Open-source apps (transparency is desirable)
