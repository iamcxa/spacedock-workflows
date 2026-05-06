#!/usr/bin/env bash
# Validates a debrief .md file against debrief-schema.yaml v1 conventions
set -euo pipefail
FILE="${1:-}"
[ -n "$FILE" ] || { echo "Usage: validate-debrief-schema.sh <debrief-file>"; exit 1; }
[ -f "$FILE" ] || { echo "FAIL: file not found: $FILE"; exit 1; }
fail=0
REQUIRED_SECTIONS=("## Shipped" "## Filed (backlog)" "## Issues — Workflow" "## Issues — Spacedock" "## Non-PR commits (workflow-only)" "## Observations" "## Decisions" "## What's Next")

schema_version="$(
  awk '
    NR == 1 && $0 == "---" { in_fm=1; next }
    in_fm && $0 == "---" { exit }
    in_fm && $1 == "schema_version:" {
      print $2
      exit
    }
  ' "$FILE"
)"

if [ -n "$schema_version" ] && [ "$schema_version" != "1" ]; then
  echo "FAIL: unsupported schema_version '$schema_version' in $FILE"
  fail=1
fi

for section in "${REQUIRED_SECTIONS[@]}"; do
  grep -qF "$section" "$FILE" || { echo "FAIL: missing section '$section' in $FILE"; fail=1; }
done
if [ $fail -eq 0 ]; then
  if [ -z "$schema_version" ]; then
    echo "WARN legacy-v1: missing schema_version treated as schema_version 1 in $FILE"
  fi
  echo "PASS: $FILE"
fi
exit $fail
