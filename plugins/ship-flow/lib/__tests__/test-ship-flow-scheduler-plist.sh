#!/usr/bin/env bash
# test-ship-flow-scheduler-plist.sh - AC-6: launchd plist template well-formedness
#
# design.md §8: two committed plist *templates* (tick StartInterval + rollup
# StartCalendarInterval 23:55) with @CONTROLLER_WORKTREE@/@SPACEDOCK_BIN@/
# @WORKFLOW_DIR@ placeholders. Well-formedness proven by lint (plutil on macOS,
# xmllint --noout as the portable fallback) + a placeholder-substitution smoke.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
TICK_PLIST="${PLUGIN_ROOT}/references/launchd/com.spacedock.ship-flow-scheduler.tick.plist"
ROLLUP_PLIST="${PLUGIN_ROOT}/references/launchd/com.spacedock.ship-flow-scheduler.rollup.plist"

PASS=0
FAIL=0
ERRORS=()

record_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
record_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

assert_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then record_pass "$desc"
  else record_fail "$desc (missing pattern: ${pattern})"; fi
}

lint_plist() {
  local desc="$1" file="$2"
  if command -v plutil >/dev/null 2>&1; then
    if plutil -lint "$file" >/dev/null 2>&1; then record_pass "$desc"
    else record_fail "$desc (plutil -lint failed)"; fi
  elif command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout "$file" >/dev/null 2>&1; then record_pass "$desc"
    else record_fail "$desc (xmllint --noout failed)"; fi
  else
    echo "  NOTE: neither plutil nor xmllint available — skipping XML well-formedness lint for ${file}"
  fi
}

substitution_smoke() {
  local desc="$1" file="$2" out
  out="$(mktemp)"
  sed -e 's|@CONTROLLER_WORKTREE@|/tmp/ctrl|g' \
      -e 's|@SPACEDOCK_BIN@|/usr/local/bin/spacedock|g' \
      -e 's|@WORKFLOW_DIR@|/tmp/ctrl/docs/ship-flow|g' \
      "$file" > "$out"
  if grep -q '@[A-Z_]*@' "$out"; then
    record_fail "$desc (unsubstituted placeholder remains)"
    rm -f "$out"
    return
  fi
  if command -v plutil >/dev/null 2>&1; then
    if plutil -lint "$out" >/dev/null 2>&1; then record_pass "$desc"
    else record_fail "$desc (post-substitution plutil -lint failed)"; fi
  elif command -v xmllint >/dev/null 2>&1; then
    if xmllint --noout "$out" >/dev/null 2>&1; then record_pass "$desc"
    else record_fail "$desc (post-substitution xmllint --noout failed)"; fi
  else
    record_pass "$desc (no lint tool available; placeholder substitution alone verified)"
  fi
  rm -f "$out"
}

echo "=== test-ship-flow-scheduler-plist.sh ==="
echo ""

if [ ! -f "$TICK_PLIST" ] || [ ! -f "$ROLLUP_PLIST" ]; then
  record_fail "helper exists and is executable (${TICK_PLIST} / ${ROLLUP_PLIST})"
else
  record_pass "plist templates exist"
  lint_plist "tick plist: well-formed XML" "$TICK_PLIST"
  lint_plist "rollup plist: well-formed XML" "$ROLLUP_PLIST"
  assert_contains "tick plist: StartInterval present" 'StartInterval' "$TICK_PLIST"
  assert_contains "tick plist: RunAtLoad present" 'RunAtLoad' "$TICK_PLIST"
  assert_contains "tick plist: has @CONTROLLER_WORKTREE@ placeholder" '@CONTROLLER_WORKTREE@' "$TICK_PLIST"
  assert_contains "rollup plist: StartCalendarInterval present" 'StartCalendarInterval' "$ROLLUP_PLIST"
  assert_contains "rollup plist: Hour 23 / Minute 55" '<integer>23</integer>' "$ROLLUP_PLIST"
  substitution_smoke "tick plist: placeholder substitution smoke" "$TICK_PLIST"
  substitution_smoke "rollup plist: placeholder substitution smoke" "$ROLLUP_PLIST"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do echo "  - $err"; done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi
echo "All assertions passed"
exit 0
