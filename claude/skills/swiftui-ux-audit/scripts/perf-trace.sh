#!/usr/bin/env bash
# perf-trace.sh — cold-launch + frame-drop measurement via xcrun xctrace.
#
# Produces two .trace bundles and a JSON summary the skill consumes.
#
# Usage:
#   perf-trace.sh <UDID> <bundle.id> [<runs>]

set -eu

UDID="${1:?UDID required}"
BUNDLE_ID="${2:?bundle id required}"
RUNS="${3:-5}"

OUT_DIR="${PWD}/swiftui-ux-audit/.trace"
mkdir -p "$OUT_DIR"

# Cold launch: terminate, uninstall-cache-clear is excessive; just terminate.
TIMINGS=()
for i in $(seq 1 "$RUNS"); do
    xcrun simctl terminate "$UDID" "$BUNDLE_ID" 2>/dev/null || true
    START=$(python3 -c 'import time;print(time.time())')
    xcrun simctl launch "$UDID" "$BUNDLE_ID" >/dev/null
    END=$(python3 -c 'import time;print(time.time())')
    ELAPSED=$(python3 -c "print($END - $START)")
    TIMINGS+=("$ELAPSED")
    sleep 1
done

# Median of timings
MEDIAN=$(python3 -c "import statistics;print(statistics.median([float(x) for x in '${TIMINGS[*]}'.split()]))")

# Frame-drop trace: attach for 10 seconds. xctrace requires a SwiftUI or
# Time-Profiler template; we use SwiftUI when available.
TEMPLATE="Time Profiler"
if xcrun xctrace list templates 2>/dev/null | grep -q "SwiftUI"; then
    TEMPLATE="SwiftUI"
fi

xcrun xctrace record \
  --template "$TEMPLATE" \
  --output "$OUT_DIR/scroll.trace" \
  --device "$UDID" \
  --attach "$BUNDLE_ID" \
  --time-limit 10s \
  >/dev/null 2>&1 || true

# Frame-drop parsing requires opening the .trace bundle; xctrace's JSON
# export is fragile across Xcode versions. We surface the .trace path and
# a placeholder count for the skill to interpret.
python3 <<PY
import json
print(json.dumps({
  "cold_launch_sec_median": $MEDIAN,
  "cold_launch_sec_samples": [$(IFS=,; echo "${TIMINGS[*]}")],
  "trace_path": "$OUT_DIR/scroll.trace",
  "frame_drops": null,
  "frame_drops_note": "Open scroll.trace in Instruments to read SwiftUI hitches; xctrace JSON export not yet stable."
}, indent=2))
PY
