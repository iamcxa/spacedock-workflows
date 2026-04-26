#!/usr/bin/env bash
# Validates a debrief .md file against debrief-schema.yaml v1 conventions
set -euo pipefail
FILE="${1:-}"
[ -n "$FILE" ] || { echo "Usage: validate-debrief-schema.sh <debrief-file>"; exit 1; }
[ -f "$FILE" ] || { echo "FAIL: file not found: $FILE"; exit 1; }
fail=0
REQUIRED_SECTIONS=("## Shipped" "## Filed (backlog)" "## Issues — Workflow" "## Issues — Spacedock" "## Non-PR commits (workflow-only)" "## Observations" "## Decisions" "## What's Next")
for section in "${REQUIRED_SECTIONS[@]}"; do
  grep -qF "$section" "$FILE" || { echo "FAIL: missing section '$section' in $FILE"; fail=1; }
done
[ $fail -eq 0 ] && echo "PASS: $FILE"
exit $fail
