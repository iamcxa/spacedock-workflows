#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/../.." &>/dev/null && pwd)"
SKILL="$ROOT/skills/ship/SKILL.md"
PASS=0; FAIL=0
check(){ if eval "$2"; then echo "  PASS: $1"; PASS=$((PASS+1)); else echo "  FAIL: $1"; FAIL=$((FAIL+1)); fi; }
echo "=== ship closeout intent contract ==="
check "ship invokes sole closeout intent producer before merge" "grep -q 'persist-closeout-intent.sh' \"$SKILL\""
check "closeout intent persists after ship finalization and before merge-state progression" "python3 - \"$SKILL\" <<'PY'
import pathlib,sys
t=pathlib.Path(sys.argv[1]).read_text()
assert t.index('### Step 6.6 — Finalize') < t.index('### Step 6.6a — Persist closeout owner') < t.index('### Step 6.7 — Post-create merge-state check')
PY"
check "ship documents exactly-one owner for shared PR" "grep -q 'exactly one.*closeout owner' \"$SKILL\""
check "ship pairs every participant with a read-first hash" "grep -q -- '--participant-entity.*--participant-if-hash' \"$SKILL\""
check "ship requires mirror slug title and normalized PR identity" "grep -q 'mirror.*slug.*title.*normalized implementation PR' \"$SKILL\""
check "merge intent is optional and only discriminates valid proof" "grep -q 'optional.*merge_method_intent.*proof-valid' \"$SKILL\""
check "sentinel landed bytes are validated before entity resolution" "grep -q 'landed bytes.*before ordinary entity resolution' \"$SKILL\""
echo "Results: $PASS passed, $FAIL failed"; [ "$FAIL" -eq 0 ]
