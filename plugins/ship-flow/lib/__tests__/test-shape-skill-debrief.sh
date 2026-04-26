#!/usr/bin/env bash
set -euo pipefail
WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
SKILL="$WDIR/plugins/ship-flow/skills/ship-shape/SKILL.md"
fail=0
count=$(grep -c "_debriefs" "$SKILL" || true)
[ "$count" -ge 2 ] || { echo "FAIL: _debriefs count=$count (need ≥2)"; fail=1; }
grep -q "recent_warnings" "$SKILL" || { echo "FAIL: recent_warnings not in ship-shape SKILL"; fail=1; }
# verify frontmatter block exists (first 10 lines contain ---)
head -10 "$SKILL" | grep -q "^---" || { echo "FAIL: no frontmatter block"; fail=1; }
[ $fail -eq 0 ] && echo "PASS: ship-shape SKILL debrief integration present"
exit $fail
