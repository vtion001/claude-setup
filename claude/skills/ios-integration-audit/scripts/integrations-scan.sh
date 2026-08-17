#!/usr/bin/env bash
# integrations-scan.sh — Inventory all OAuth / push / deep-link / etc integrations.
set -eu
ROOT="${1:-$PWD}"
cd "$ROOT"

PLIST=$(find . -maxdepth 4 -name "Info.plist" -path "*/Pookoo/*" -o -name "Info.plist" -maxdepth 3 2>/dev/null | head -1)
PLIST="${PLIST:-Info.plist}"

OAUTH_ASWEB=$(grep -rln --include='*.swift' 'ASWebAuthenticationSession' . 2>/dev/null | wc -l | tr -d ' ')
OAUTH_PKCE=$(grep -rln --include='*.swift' 'code_challenge\|code_verifier' . 2>/dev/null | wc -l | tr -d ' ')
WK_FOR_OAUTH=$(grep -rln --include='*.swift' 'WKWebView' . 2>/dev/null \
    | xargs grep -l -i 'oauth\|authorize' 2>/dev/null | wc -l | tr -d ' ')
SIWA=$(grep -rln --include='*.swift' 'ASAuthorizationAppleIDProvider\|SignInWithAppleButton' . 2>/dev/null | wc -l | tr -d ' ')
OTHER_SOCIAL=$(grep -rln --include='*.swift' 'GoogleSignIn\|GIDSignIn\|FBSDK\|FacebookLogin\|Auth0' . 2>/dev/null | wc -l | tr -d ' ')
UNIVERSAL=$(grep -rln --include='*.entitlements' 'associated-domains' . 2>/dev/null | wc -l | tr -d ' ')
URL_SCHEMES=""
APS_ENV=""
if [ -f "$PLIST" ]; then
    URL_SCHEMES=$(python3 -c "import plistlib;p=plistlib.load(open('$PLIST','rb'));types=p.get('CFBundleURLTypes',[]);schemes=[s for t in types for s in t.get('CFBundleURLSchemes',[])];print(','.join(schemes))" 2>/dev/null || echo "")
    APS_ENV=$(grep -A 1 'aps-environment' "$PLIST" 2>/dev/null | tail -1 | sed 's/[<>/]/ /g' | xargs || echo "")
fi
APP_INTENTS=$(grep -rln --include='*.swift' 'AppIntent\|AppShortcutsProvider' . 2>/dev/null | wc -l | tr -d ' ')
WIDGETS=$(grep -rln --include='*.swift' 'Widget\b\|TimelineProvider' . 2>/dev/null | wc -l | tr -d ' ')
STOREKIT=$(grep -rln --include='*.swift' 'import StoreKit\|Transaction\.currentEntitlements' . 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
{
  "oasis_aswebauth_files": $OAUTH_ASWEB,
  "oauth_pkce_files": $OAUTH_PKCE,
  "wkwebview_for_oauth": $WK_FOR_OAUTH,
  "sign_in_with_apple": $SIWA,
  "other_social_login": $OTHER_SOCIAL,
  "universal_links": $UNIVERSAL,
  "url_schemes": "$URL_SCHEMES",
  "aps_environment": "$APS_ENV",
  "app_intents_files": $APP_INTENTS,
  "widgetkit_files": $WIDGETS,
  "storekit_files": $STOREKIT
}
EOF
