#!/usr/bin/env bash
set -euo pipefail
WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL="$WDIR/plugins/ship-flow/skills/ship-plan/SKILL.md"
fail=0
count=$(grep -c "_debriefs" "$SKILL" || true)
[ "$count" -ge 2 ] || { echo "FAIL: _debriefs count=$count (need ≥2)"; fail=1; }
grep -qi "debrief" "$SKILL" || { echo "FAIL: debrief not in ship-plan SKILL"; fail=1; }
head -10 "$SKILL" | grep -q "^---" || { echo "FAIL: no frontmatter block"; fail=1; }
[ $fail -eq 0 ] && echo "PASS: ship-plan SKILL debrief integration present"
exit $fail
