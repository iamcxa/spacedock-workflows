#!/usr/bin/env bash
# test-check-invariants-c16.sh — adversarial fixture tests for C16
# review-surface-shape-not-plan (INVARIANTS.md Principle 17).
# Pattern: test-check-invariants-c15.sh (assert helpers) + C9's FIXTURE_INVARIANTS
#          file-override (check_principle_numbering).
#
# Entity: 7-review-surface-shape-not-plan (GitHub issue #60).
# C16 is Tier B (Principle 16): it pins the load-bearing Principle 17 rule TEXT
# in INVARIANTS.md (discoverability + regression-proofing), NOT FO runtime
# behavior. The two pinned sentences must be present verbatim; a mutated/removed
# rule (even with the heading intact) must FAIL.

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

# The two load-bearing sentences C16 pins (verbatim, no backticks — plain grep -F).
S1="The human review surface is the shape/spec (and design.md when its conditional gate fires) -- never plan.md or execute.md."
S2="The FO MUST NOT offer plan.md or execute.md as a human-review artifact."

# Case A (live) — the real INVARIANTS.md must carry the pinned rule.
assert_exit 0 "bash '$CHECK_SCRIPT' --check review-surface-shape-not-plan" "A-live-invariants-green"

# Case B — fixture with both pinned sentences present -> PASS.
fixB="$(mktemp)"
printf '### Principle 17\n\n**Rule**: %s %s\n' "$S1" "$S2" > "$fixB"
assert_exit 0 "FIXTURE_INVARIANTS='$fixB' bash '$CHECK_SCRIPT' --check review-surface-shape-not-plan" "B-fixture-both-present-pass"

# Case C — fixture with neither sentence -> FAIL, stderr names Principle 17.
fixC="$(mktemp)"
printf '# unrelated doc\n\nno review-surface rule here\n' > "$fixC"
assert_exit 1 "FIXTURE_INVARIANTS='$fixC' bash '$CHECK_SCRIPT' --check review-surface-shape-not-plan" "C-fixture-neither-fail"
assert_stderr_contains "Principle 17" "FIXTURE_INVARIANTS='$fixC' bash '$CHECK_SCRIPT' --check review-surface-shape-not-plan" "C-stderr-names-principle-17"

# Case D (mutation) — heading present but both sentences reworded away -> FAIL.
# Proves C16 greps the load-bearing sentences, not just the heading.
fixD="$(mktemp)"
printf '### Principle 17: The human review surface is the shape/spec, never plan.md\n\n**Rule**: The review surface is the spec, not the plan. Do not show the captain the plan.\n' > "$fixD"
assert_exit 1 "FIXTURE_INVARIANTS='$fixD' bash '$CHECK_SCRIPT' --check review-surface-shape-not-plan" "D-heading-only-reworded-fail"

# Case E (AND-semantics) — exactly ONE pinned sentence present -> FAIL.
# Guards against an AND->OR regression of the check that cases A-D would ALL
# still pass (both-present, neither, heading-only never isolate one sentence).
fixE="$(mktemp)"
printf '### Principle 17\n\n**Rule**: %s\n' "$S1" > "$fixE"
assert_exit 1 "FIXTURE_INVARIANTS='$fixE' bash '$CHECK_SCRIPT' --check review-surface-shape-not-plan" "E-one-sentence-only-fail"

rm -f "$fixB" "$fixC" "$fixD" "$fixE"
echo "---"
if [ "$FAIL" = 0 ]; then echo "ALL C16 TESTS PASS"; else echo "SOME C16 TESTS FAILED"; fi
exit $FAIL
