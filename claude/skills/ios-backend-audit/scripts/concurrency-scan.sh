#!/usr/bin/env bash
# concurrency-scan.sh — Static scan for Swift concurrency patterns.
set -eu
ROOT="${1:-$PWD}"
cd "$ROOT"

MAIN_ACTOR=$(grep -rln --include='*.swift' '@MainActor' . 2>/dev/null | wc -l | tr -d ' ')
ACTORS=$(grep -rln --include='*.swift' '^actor \|^final actor ' . 2>/dev/null | wc -l | tr -d ' ')
SENDABLE=$(grep -rln --include='*.swift' ': Sendable\|@unchecked Sendable' . 2>/dev/null | wc -l | tr -d ' ')
TASK_USES=$(grep -rn --include='*.swift' '\bTask {\|Task\.detached' . 2>/dev/null | wc -l | tr -d ' ')
DISPATCH=$(grep -rln --include='*.swift' 'DispatchQueue\.main\|DispatchQueue\.global' . 2>/dev/null | wc -l | tr -d ' ')
FORCE_TRY=$(grep -rn --include='*.swift' 'try!.*await\|await.*try!' . 2>/dev/null | wc -l | tr -d ' ')

# @MainActor classes that do I/O
MAIN_ACTOR_IO=$(grep -rl --include='*.swift' '@MainActor' . 2>/dev/null \
    | xargs grep -l -E 'URLSession|URLRequest|FileManager|JSONDecoder().decode|JSONEncoder().encode' 2>/dev/null \
    | wc -l | tr -d ' ')

cat <<EOF
{
  "main_actor_files": $MAIN_ACTOR,
  "actor_files": $ACTORS,
  "sendable_annotated_files": $SENDABLE,
  "task_use_count": $TASK_USES,
  "dispatchqueue_files": $DISPATCH,
  "main_actor_files_doing_io": $MAIN_ACTOR_IO,
  "force_try_await_count": $FORCE_TRY
}
EOF
