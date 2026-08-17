#!/usr/bin/env bash
# ui-impl-scan.sh — Aggregate static scan for UI implementation passes.
set -eu
ROOT="${1:-$PWD}"
cd "$ROOT"

# Hit targets
SMALL_FRAMES=$(grep -rn --include='*.swift' -E '\.frame\(width: [12][0-9]?, height: [12][0-9]?\)' . 2>/dev/null | wc -l | tr -d ' ')

# Dynamic Type
FIXED_FONTS=$(grep -rn --include='*.swift' '\.font(\.system(size:' . 2>/dev/null | wc -l | tr -d ' ')
SEMANTIC_FONTS=$(grep -rn --include='*.swift' -E '\.font\(\.(title|headline|body|caption|footnote|callout|subheadline)' . 2>/dev/null | wc -l | tr -d ' ')

# Dark mode
HARD_WHITE=$(grep -rn --include='*.swift' 'Color\.white' . 2>/dev/null | grep -vE 'shadow|fill\(Color\.white' | wc -l | tr -d ' ')
COLORSCHEME=$(grep -rln --include='*.swift' 'colorScheme\|preferredColorScheme' . 2>/dev/null | wc -l | tr -d ' ')

# Size classes
SIZE_CLASS_AWARE=$(grep -rln --include='*.swift' 'horizontalSizeClass\|NavigationSplitView' . 2>/dev/null | wc -l | tr -d ' ')

# SF Symbols vs custom
SFSYMBOLS=$(grep -rn --include='*.swift' 'Image(systemName:' . 2>/dev/null | wc -l | tr -d ' ')
CUSTOM_ICONS=$(grep -rn --include='*.swift' 'Image("' . 2>/dev/null | grep -v 'systemName' | wc -l | tr -d ' ')

# View body perf
LARGE_FILES=$(find . -name "*.swift" -type f -exec wc -l {} \; 2>/dev/null | awk '$1 > 500' | wc -l | tr -d ' ')
SELF_ID=$(grep -rn --include='*.swift' 'ForEach(.*,\s*id:\s*\\.self)' . 2>/dev/null | wc -l | tr -d ' ')

# Motion
ANIMATIONS=$(grep -rn --include='*.swift' '\.animation(\|withAnimation' . 2>/dev/null | wc -l | tr -d ' ')
REDUCE_MOTION_AWARE=$(grep -rln --include='*.swift' 'accessibilityReduceMotion' . 2>/dev/null | wc -l | tr -d ' ')

# RTL / Locale
STRING_CATALOG=$(find . -name "*.xcstrings" 2>/dev/null | wc -l | tr -d ' ')
HARDCODED_TEXT=$(grep -rn --include='*.swift' 'Text("[A-Z]' . 2>/dev/null | wc -l | tr -d ' ')

cat <<EOF
{
  "small_frames": $SMALL_FRAMES,
  "fixed_size_fonts": $FIXED_FONTS,
  "semantic_fonts": $SEMANTIC_FONTS,
  "hardcoded_white_count": $HARD_WHITE,
  "colorscheme_aware_files": $COLORSCHEME,
  "size_class_aware_files": $SIZE_CLASS_AWARE,
  "sf_symbol_count": $SFSYMBOLS,
  "custom_icon_count": $CUSTOM_ICONS,
  "files_over_500_lines": $LARGE_FILES,
  "foreach_self_id_count": $SELF_ID,
  "animation_calls": $ANIMATIONS,
  "reduce_motion_aware_files": $REDUCE_MOTION_AWARE,
  "string_catalog_count": $STRING_CATALOG,
  "hardcoded_text_calls": $HARDCODED_TEXT
}
EOF
