#!/usr/bin/env bash
# test-check-invariants-c18.sh — adversarial fixture tests for C18
# refusal-observability-record (INVARIANTS.md Principle 18).
# Pattern: test-check-invariants-c16.sh / test-check-invariants-c17.sh
# (assert helpers + FIXTURE_INVARIANTS override).
#
# Entity: tick-refusal-scan-head-block (#82), verify feedback cycle 1, F3
# (codex adversarial): C18's original `[ -f "$invariants_file" ] || return 0`
# fail-OPEN skip meant a missing target file silently PASSED — a false
# negative that never read a single rule sentence. Case B below is the
# RED-driving case: it failed (exit 0, expected 1) against the pre-fix
# check-invariants.sh and now passes fail-closed.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/../.."
CHECK_SCRIPT="${PLUGIN_DIR}/bin/check-invariants.sh"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

assert_stderr_contains() {
  local needle="$1" cmd="$2" name="$3"
  local err; err="$(eval "$cmd" 2>&1 >/dev/null)"
  if echo "$err" | grep -qF "$needle"; then echo "OK $name"
  else echo "FAIL $name (stderr missing: $needle)"; FAIL=1; fi
}

# The two load-bearing sentences C18 pins (verbatim, no backticks — plain grep -F).
S1="A scheduler tick's single bounded action is reconcile > dispatch > advance > no-op; a Precedence-2 dispatch-scan beat's \`refusal\` events are scan-time observability records emitted BEFORE the beat's action, never the action itself."
S2="The events log (\`.ship-flow-scheduler-events.jsonl\`) is read only to derive skip-past / dedup windows (blocked-backoff, refusal-dedup); it is never read to compute entity eligibility or to mutate canonical state, and it remains the rollup's only input."

# Case A (live) — the real INVARIANTS.md must carry the pinned rule.
assert_exit 0 "bash '$CHECK_SCRIPT' --check refusal-observability-record" "A-live-invariants-green"

# Case B (F3 — the RED case) — FIXTURE_INVARIANTS points at a path that does
# not exist -> MUST fail closed (exit 1), not silently pass.
fixB="$(mktemp -u)/does-not-exist-invariants.md"
assert_exit 1 "FIXTURE_INVARIANTS='$fixB' bash '$CHECK_SCRIPT' --check refusal-observability-record" "B-missing-file-fail-closed"
assert_stderr_contains "target file missing" "FIXTURE_INVARIANTS='$fixB' bash '$CHECK_SCRIPT' --check refusal-observability-record" "B-stderr-names-missing-file"

# Case C — fixture with both pinned sentences present -> PASS.
fixC="$(mktemp)"
printf '### Principle 18\n\n**Rule**: %s %s\n' "$S1" "$S2" > "$fixC"
assert_exit 0 "FIXTURE_INVARIANTS='$fixC' bash '$CHECK_SCRIPT' --check refusal-observability-record" "C-fixture-both-present-pass"

# Case D — fixture with neither sentence -> FAIL, stderr names Principle 18.
fixD="$(mktemp)"
printf '# unrelated doc\n\nno refusal-observability rule here\n' > "$fixD"
assert_exit 1 "FIXTURE_INVARIANTS='$fixD' bash '$CHECK_SCRIPT' --check refusal-observability-record" "D-fixture-neither-fail"
assert_stderr_contains "Principle 18" "FIXTURE_INVARIANTS='$fixD' bash '$CHECK_SCRIPT' --check refusal-observability-record" "D-stderr-names-principle-18"

rm -f "$fixC" "$fixD"
echo "---"
if [ "$FAIL" = 0 ]; then echo "ALL C18 TESTS PASS"; else echo "SOME C18 TESTS FAILED"; fi
exit $FAIL
