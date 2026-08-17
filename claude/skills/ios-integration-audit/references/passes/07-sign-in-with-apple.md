# Pass 07 — Sign in with Apple

**Weight:** 2×

## What this audits
**App Store Review Guideline 4.8.0** requires Sign in with Apple if the
app offers any other social/SSO login (Google, Facebook, Apple ID, etc).

- `AuthenticationServices` import
- `ASAuthorizationAppleIDProvider`
- Nonce + state for replay protection
- Token storage (defers to /ios-security-audit)

## Tier 0
```bash
grep -rln --include='*.swift' 'ASAuthorizationAppleIDProvider\|SignInWithAppleButton' <project-root>

# Check for other social logins
grep -rln --include='*.swift' 'GoogleSignIn\|GIDSignIn\|FBSDK\|FacebookLogin\|Auth0' <project-root>
```

## Scoring
| Score | Criteria |
|---|---|
| 5 | SiwA present + other social logins also present (compliant) |
| 4 | SiwA only (no other social) |
| 3 | No social logins, no SiwA (compliant by absence) |
| 2 | SiwA present but broken (nonce missing) |
| 1 | Other social logins present, SiwA absent → App Store reject |

## Pookoo
No social logins. Score 5/5 by absence. Sign in with Apple is N/A here
since the app uses Gmail OAuth purely for email scraping, not for
account sign-in.

## What NOT to flag
- Anonymous-only apps
- Enterprise apps with SSO via internal IdP
- Apps that use Sign in with Apple but no other social (this is correct)
