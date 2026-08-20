#!/usr/bin/env bash
# detect-project.sh — Phase 0 auto-detection.
#
# Examines the current working directory and writes a JSON description of
# the SwiftUI iOS project: scheme, bundle id, deployment target, token
# file, default tabs, and whether a UI-test target exists.
#
# Usage:
#   detect-project.sh > swiftui-ux-audit/.detect.json
#
# Exits non-zero with a human-readable message if cwd is not a SwiftUI iOS
# project.

set -eu

PROJECT_ROOT="${1:-$PWD}"
cd "$PROJECT_ROOT"

# --- 1. is this a SwiftUI iOS project? --------------------------------------
PROJECT_TYPE=""
if   [ -f "project.yml" ];                                      then PROJECT_TYPE="xcodegen"
elif compgen -G "*.xcworkspace"  > /dev/null;                   then PROJECT_TYPE="xcworkspace"
elif compgen -G "*.xcodeproj"    > /dev/null;                   then PROJECT_TYPE="xcodeproj"
elif [ -f "Package.swift" ] && grep -q "\.iOS(" Package.swift;  then PROJECT_TYPE="spm"
fi
if [ -z "$PROJECT_TYPE" ]; then
    echo '{"error":"Not a SwiftUI iOS project. For web projects use /ux-audit."}'
    exit 2
fi

# --- 2. scheme --------------------------------------------------------------
SCHEME=""
if [ "$PROJECT_TYPE" = "xcodegen" ]; then
    # Take lines AFTER `schemes:` and grab the first one with 2-space indent
    # that looks like a key (`  Name:`).
    SCHEME=$(awk '/^schemes:/{found=1; next} found && /^  [A-Za-z]/{print; exit}' project.yml \
             | awk -F: '{print $1}' | xargs)
fi
if [ -z "$SCHEME" ]; then
    # Try xcodebuild -list
    LIST_JSON=$(xcodebuild -list -json 2>/dev/null || true)
    if [ -n "$LIST_JSON" ]; then
        SCHEME=$(printf '%s' "$LIST_JSON" | python3 -c 'import json,sys
d=json.load(sys.stdin)
schemes=(d.get("project") or d.get("workspace") or {}).get("schemes",[])
print(schemes[0] if schemes else "")' 2>/dev/null || echo "")
    fi
fi

# --- 3. bundle id -----------------------------------------------------------
BUNDLE_ID=""
if [ -f "project.yml" ]; then
    BUNDLE_ID=$(grep -E 'PRODUCT_BUNDLE_IDENTIFIER' project.yml | head -1 | awk -F: '{print $2}' | xargs)
fi
if [ -z "$BUNDLE_ID" ]; then
    PLIST=$(find . -name "Info.plist" -not -path '*/Tests/*' -not -path '*/UITests/*' -not -path '*/.derived/*' | head -1)
    if [ -n "$PLIST" ]; then
        BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST" 2>/dev/null || true)
        # Strip variable placeholders like $(PRODUCT_BUNDLE_IDENTIFIER)
        case "$BUNDLE_ID" in *\$*) BUNDLE_ID="" ;; esac
    fi
fi

# --- 4. deployment target ---------------------------------------------------
DEPLOYMENT_TARGET=""
if [ -f "project.yml" ]; then
    # Inline form first:  IPHONEOS_DEPLOYMENT_TARGET: 17.0
    DEPLOYMENT_TARGET=$(grep -E 'IPHONEOS_DEPLOYMENT_TARGET:|deploymentTarget:' project.yml \
                       | head -1 | awk -F: '{print $2}' | tr -d ' "')
    # Nested form:
    #   deploymentTarget:
    #     iOS: "17.0"
    if [ -z "$DEPLOYMENT_TARGET" ]; then
        DEPLOYMENT_TARGET=$(awk '/deploymentTarget:/{f=1;next} f && /iOS:/{print;exit}' project.yml \
                           | awk -F: '{print $2}' | tr -d ' "')
    fi
fi

# --- 5. design-token file(s) ------------------------------------------------
# Many projects split tokens across multiple files (Theme + Typography +
# Animations + Spacing). We collect every Swift file whose name suggests a
# design-system role AND that contains token-shaped declarations.
TOKEN_FILES_RAW=$(find . \
    \( -name "Theme.swift" -o \
       -name "Tokens.swift" -o \
       -name "DesignTokens.swift" -o \
       -iname "*Theme*.swift" -o \
       -iname "*Token*.swift" -o \
       -iname "*DesignSystem*.swift" -o \
       -iname "*Typography*.swift" -o \
       -iname "*Animations*.swift" -o \
       -iname "*Spacing*.swift" -o \
       -iname "*Palette*.swift" \) \
    -not -path '*/.derived/*' \
    -not -path '*/.build/*' \
    -not -path '*/build/*' \
    -not -path '*Tests*' \
    -not -path '*UITests*' \
    2>/dev/null)

TOKEN_FILES_LIST=""
while IFS= read -r f; do
    [ -z "$f" ] && continue
    # Must contain at least one token-shaped declaration to count
    if grep -qE 'static let .+(Color|Font|CGFloat|Animation)' "$f" 2>/dev/null; then
        clean="${f#./}"
        TOKEN_FILES_LIST="${TOKEN_FILES_LIST}${clean}|"
    fi
done <<<"$TOKEN_FILES_RAW"

# Primary = first match for the convenience field
TOKEN_FILE="${TOKEN_FILES_LIST%%|*}"

# JSON array of all detected token files
TOKEN_FILES_JSON=$(python3 - <<PY
import json
raw="""$TOKEN_FILES_LIST"""
items=[p for p in raw.split("|") if p.strip()]
print(json.dumps(items))
PY
)

# --- 6. tab inventory -------------------------------------------------------
TABS_JSON="[]"
ENTRY=$(grep -rl '@main' --include='*.swift' . | head -1 || true)
CONTENT_VIEW=$(find . -name "ContentView.swift" -not -path '*/.derived/*' | head -1 || true)
if [ -n "$CONTENT_VIEW" ]; then
    # Try to pull enum case labels for selectedTab. Heuristic: lines like `case home` inside an enum block
    TABS=$(grep -E '^\s*case [a-z][a-zA-Z]+' "$CONTENT_VIEW" 2>/dev/null | sed -E 's/.*case ([a-zA-Z]+).*/\1/' | head -8 | tr '\n' ',' | sed 's/,$//')
    if [ -n "$TABS" ]; then
        TABS_JSON=$(printf '%s' "$TABS" | python3 -c 'import sys,json;print(json.dumps([t for t in sys.stdin.read().split(",") if t]))')
    fi
fi

# --- 7. UI-test target ------------------------------------------------------
# Distinguish "registered in project" from "directory only exists".
UITEST_REGISTERED="False"
UITEST_DIR_EXISTS="False"
if [ -f "project.yml" ] && grep -qE 'bundle\.ui-testing' project.yml; then
    UITEST_REGISTERED="True"
fi
if find . -name "*UITests" -type d \
        -not -path '*/.derived/*' \
        -not -path '*/swiftui-ux-audit/*' 2>/dev/null | grep -q .; then
    UITEST_DIR_EXISTS="True"
fi
# Convenience boolean: only true if the target is actually buildable.
HAS_UITEST="$UITEST_REGISTERED"

# --- emit JSON --------------------------------------------------------------
python3 <<PY
import json
print(json.dumps({
  "project_root":      "${PROJECT_ROOT}",
  "project_type":      "${PROJECT_TYPE}",
  "scheme":            "${SCHEME}",
  "bundle_id":         "${BUNDLE_ID}",
  "deployment_target": "${DEPLOYMENT_TARGET}",
  "token_file":        "${TOKEN_FILE}",
  "token_files":       ${TOKEN_FILES_JSON},
  "tabs":              ${TABS_JSON},
  "has_uitest_target": ${HAS_UITEST},
  "uitest_dir_exists": ${UITEST_DIR_EXISTS}
}, indent=2))
PY
