#!/usr/bin/env bash
# test-check-invariants-c17.sh — adversarial fixture tests for C17
# ship-shape-design-always-runs (INVARIANTS Principle 11 "Design Stage Required").
# Pattern: test-check-invariants-c16.sh (assert helpers + FIXTURE override).
#
# Entity: #63. C17 pins the ship-shape SKILL prose so it can never drift back to
# the pre-pitch-116 "skip design → plan" guidance that Principle 11 removed and
# C14's transition graph rejects (no shape→plan edge). Tier B (text presence).

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

# Case A (live) — the real ship-shape SKILL must carry no stale skip guidance.
assert_exit 0 "bash '$CHECK_SCRIPT' --check ship-shape-design-always-runs" "A-live-shape-skill-green"

# Case B — fixture with the stale FO auto-skip instruction -> FAIL.
fixB="$(mktemp)"
printf 'When ANY trigger fires, FO advances to design; otherwise auto-skip to `plan` per skip-when.\n' > "$fixB"
assert_exit 1 "FIXTURE_SHAPE_SKILL='$fixB' bash '$CHECK_SCRIPT' --check ship-shape-design-always-runs" "B-stale-auto-skip-fail"
assert_stderr_contains "Principle 11" "FIXTURE_SHAPE_SKILL='$fixB' bash '$CHECK_SCRIPT' --check ship-shape-design-always-runs" "B-stderr-names-principle-11"

# Case C — fixture with corrected prose (design always runs) -> PASS.
fixC="$(mktemp)"
printf 'The FO always advances to design; trivial-pass entities walk ship-design Phase 0. No shape->plan skip.\n' > "$fixC"
assert_exit 0 "FIXTURE_SHAPE_SKILL='$fixC' bash '$CHECK_SCRIPT' --check ship-shape-design-always-runs" "C-corrected-prose-pass"

# Case D — fixture telling SHAPE to emit the design-skipped Hand-off to Plan -> FAIL.
fixD="$(mktemp)"
printf 'omit ui_surfaces; emit stub `### Hand-off to Plan` with `design-skipped: true` (single field).\n' > "$fixD"
assert_exit 1 "FIXTURE_SHAPE_SKILL='$fixD' bash '$CHECK_SCRIPT' --check ship-shape-design-always-runs" "D-stale-shape-emits-plan-handoff-fail"

rm -f "$fixB" "$fixC" "$fixD"
echo "---"
if [ "$FAIL" = 0 ]; then echo "ALL C17 TESTS PASS"; else echo "SOME C17 TESTS FAILED"; fi
exit $FAIL
