# /ios-integration-audit — Scoring Rubric

Extends `_ios-shared/scoring-rubric-shared.md`. Acronym: **INT-iOS**.

## Pass Weights

Total: **14** (max raw 70).

| Pass | Weight | Rationale |
|---|---|---|
| 01-oauth-pkce | 3× | Wrong OAuth = security incident; PKCE is non-negotiable |
| 02-universal-links | 2× | Affects every share + cross-app workflow |
| 03-push-notifications | 2× | Engagement-critical when used |
| 04-app-intents | 1× | Newer; not adopted by every app |
| 05-widgetkit | 2× | Visibility + retention |
| 06-storekit-2 | 2× | Revenue if app monetizes |
| 07-sign-in-with-apple | 2× | App Store Review requirement when relevant |
