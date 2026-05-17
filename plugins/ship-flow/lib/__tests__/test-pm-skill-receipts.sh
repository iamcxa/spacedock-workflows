#!/usr/bin/env bash
# test-pm-skill-receipts.sh — PM-skill receipt validator fixtures
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
REPO_ROOT="$(cd "${LIB_DIR}/../../.." && pwd)"
VALIDATOR="${LIB_DIR}/validate-pm-skill-receipts.sh"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1
  got=$?
  if [ "$got" = "$expected" ]; then
    echo "OK $name"
  else
    echo "FAIL $name (expected exit $expected, got $got)"
    FAIL=1
  fi
}

assert_stderr_contains() {
  local needle="$1" cmd="$2" name="$3"
  local err
  err="$(eval "$cmd" 2>&1 >/dev/null)"
  if echo "$err" | grep -qF "$needle"; then
    echo "OK $name"
  else
    echo "FAIL $name (stderr missing: $needle)"
    FAIL=1
  fi
}

write_shape() {
  local path="$1" body="$2"
  cat > "$path" <<EOF
# Receipt Fixture Shape

## Problem

Static docs can say \`Skill: problem-framing-canvas\` without proving the shape worker emitted a receipt.

${body}
EOF
}

valid_receipt_block() {
  cat <<'EOF'
<!-- section:pm-skill-receipts -->
```yaml
pm_skill_receipts:
  stage: ship-shape
  mode: mode-a
  appetite: small-batch
  compose_guard: passed
  receipts:
    - phase: intake-problem
      delegate: problem-framing-canvas
      required: true
      status: invoked
      evidence: "Skill: problem-framing-canvas"
      fallback: null
      rationale: "Feeds the Problem block."
    - phase: scope-decompose
      delegate: opportunity-solution-tree
      required: true
      status: unavailable
      evidence: null
      fallback: inline
      rationale: "Skill unavailable; inline fallback recorded before compose."
    - phase: assumption-extract
      delegate: pol-probe-advisor
      required: true
      status: invoked
      evidence: "Skill: pol-probe-advisor"
      fallback: null
      rationale: "Filters critical assumptions."
    - phase: acceptance-outcome
      delegate: press-release
      required: true
      status: skipped
      evidence: null
      fallback: null
      rationale: "Small-scope skip rule matched before compose."
```
<!-- /section:pm-skill-receipts -->
EOF
}

run_fixture() {
  local body="$1"
  local shape="$TMP/shape.md"
  write_shape "$shape" "$body"
  bash "$VALIDATOR" "$shape"
}

replace_first() {
  local from="$1" to="$2"
  awk -v from="$from" -v to="$to" '
    !done && index($0, from) { sub(from, to); done = 1 }
    { print }
  '
}

case_valid() {
  run_fixture "$(valid_receipt_block)"
}

case_missing() {
  run_fixture ""
}

case_duplicate() {
  local body
  body="$(valid_receipt_block)

$(valid_receipt_block)"
  run_fixture "$body"
}

case_invalid_status() {
  run_fixture "$(valid_receipt_block | replace_first 'status: invoked' 'status: maybe')"
}

case_wrong_stage() {
  run_fixture "$(valid_receipt_block | replace_first 'stage: ship-shape' 'stage: ship-plan')"
}

case_wrong_mode() {
  run_fixture "$(valid_receipt_block | replace_first 'mode: mode-a' 'mode: mode-b')"
}

case_wrong_compose_guard() {
  run_fixture "$(valid_receipt_block | replace_first 'compose_guard: passed' 'compose_guard: failed')"
}

case_missing_appetite() {
  run_fixture "$(valid_receipt_block | grep -v 'appetite: small-batch')"
}

case_invalid_appetite() {
  run_fixture "$(valid_receipt_block | replace_first 'appetite: small-batch' 'appetite: weekend')"
}

case_optional_invalid_status() {
  run_fixture "$(valid_receipt_block | awk '
    /^```$/ && !inserted {
      print "    - phase: intake-problem-supplement"
      print "      delegate: jobs-to-be-done"
      print "      required: false"
      print "      status: maybe"
      print "      evidence: \"Skill: jobs-to-be-done\""
      print "      fallback: null"
      print "      rationale: \"Optional JTBD supplement.\""
      inserted = 1
    }
    { print }
  ')"
}

case_missing_delegate() {
  run_fixture "$(valid_receipt_block | grep -v 'delegate: press-release')"
}

case_required_delegate_wrong_phase() {
  run_fixture "$(valid_receipt_block | replace_first 'phase: scope-decompose' 'phase: intake-problem')"
}

case_required_delegate_not_required() {
  run_fixture "$(valid_receipt_block | replace_first 'required: true' 'required: false')"
}

case_invoked_without_evidence() {
  run_fixture "$(valid_receipt_block | replace_first 'evidence: "Skill: problem-framing-canvas"' 'evidence: null')"
}

case_unavailable_without_fallback() {
  run_fixture "$(valid_receipt_block | replace_first 'fallback: inline' 'fallback: null')"
}

case_skipped_without_rationale() {
  run_fixture "$(valid_receipt_block | replace_first 'Small-scope skip rule matched before compose.' ' ')"
}

case_medium_pol_skipped() {
  run_fixture "$(valid_receipt_block | awk '
    /appetite: small-batch/ { sub("small-batch", "medium-batch") }
    /delegate: pol-probe-advisor/ { in_pol = 1 }
    in_pol && /status: invoked/ { sub("status: invoked", "status: skipped") }
    in_pol && /evidence: "Skill: pol-probe-advisor"/ { sub("evidence: \"Skill: pol-probe-advisor\"", "evidence: null") }
    /delegate: press-release/ { in_pol = 0 }
    { print }
  ')"
}

cd "$REPO_ROOT" || exit 1

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

echo "--- PM receipt validator: valid artifact passes ---"
assert_exit 0 \
  "case_valid" \
  "valid receipt block"

echo
echo "--- PM receipt validator: missing and duplicate blocks fail ---"
assert_exit 1 \
  "case_missing" \
  "missing receipt block fails"
assert_stderr_contains "missing section:pm-skill-receipts" \
  "case_missing" \
  "missing receipt block reports reason"

assert_exit 1 \
  "case_duplicate" \
  "duplicate receipt blocks fail"
assert_stderr_contains "duplicate section:pm-skill-receipts" \
  "case_duplicate" \
  "duplicate receipt blocks report reason"

echo
echo "--- PM receipt validator: root contract fails closed ---"
assert_exit 1 \
  "case_wrong_stage" \
  "wrong stage fails"
assert_stderr_contains "pm_skill_receipts.stage must be ship-shape" \
  "case_wrong_stage" \
  "wrong stage reports reason"

assert_exit 1 \
  "case_wrong_mode" \
  "wrong mode fails"
assert_stderr_contains "pm_skill_receipts.mode must be mode-a" \
  "case_wrong_mode" \
  "wrong mode reports reason"

assert_exit 1 \
  "case_wrong_compose_guard" \
  "wrong compose_guard fails"
assert_stderr_contains "pm_skill_receipts.compose_guard must be passed" \
  "case_wrong_compose_guard" \
  "wrong compose_guard reports reason"

assert_exit 1 \
  "case_missing_appetite" \
  "missing appetite fails"
assert_stderr_contains "pm_skill_receipts.appetite must be one of: small-batch, medium-batch, big-batch" \
  "case_missing_appetite" \
  "missing appetite reports reason"

assert_exit 1 \
  "case_invalid_appetite" \
  "invalid appetite fails"
assert_stderr_contains "pm_skill_receipts.appetite must be one of: small-batch, medium-batch, big-batch" \
  "case_invalid_appetite" \
  "invalid appetite reports reason"

echo
echo "--- PM receipt validator: enum, delegate, and evidence semantics fail closed ---"
assert_exit 1 \
  "case_invalid_status" \
  "invalid status fails"
assert_stderr_contains "invalid status" \
  "case_invalid_status" \
  "invalid status reports reason"

assert_exit 1 \
  "case_optional_invalid_status" \
  "optional supplement invalid status fails"
assert_stderr_contains "invalid status for delegate jobs-to-be-done" \
  "case_optional_invalid_status" \
  "optional supplement invalid status reports reason"

assert_exit 1 \
  "case_missing_delegate" \
  "missing required delegate fails"
assert_stderr_contains "missing required delegate: press-release" \
  "case_missing_delegate" \
  "missing required delegate reports reason"

assert_exit 1 \
  "case_required_delegate_wrong_phase" \
  "required delegate wrong phase fails"
assert_stderr_contains "required delegate opportunity-solution-tree must have phase scope-decompose" \
  "case_required_delegate_wrong_phase" \
  "required delegate wrong phase reports reason"

assert_exit 1 \
  "case_required_delegate_not_required" \
  "required delegate required=false fails"
assert_stderr_contains "required delegate problem-framing-canvas must set required: true" \
  "case_required_delegate_not_required" \
  "required delegate required=false reports reason"

assert_exit 1 \
  "case_invoked_without_evidence" \
  "invoked without evidence fails"
assert_stderr_contains "invoked delegate problem-framing-canvas missing evidence" \
  "case_invoked_without_evidence" \
  "invoked without evidence reports reason"

assert_exit 1 \
  "case_unavailable_without_fallback" \
  "unavailable without fallback fails"
assert_stderr_contains "unavailable delegate opportunity-solution-tree missing fallback" \
  "case_unavailable_without_fallback" \
  "unavailable without fallback reports reason"

assert_exit 1 \
  "case_skipped_without_rationale" \
  "skipped without rationale fails"
assert_stderr_contains "skipped delegate press-release missing rationale" \
  "case_skipped_without_rationale" \
  "skipped without rationale reports reason"

echo
echo "--- PM receipt validator: medium/big POL probe skip is rejected ---"
assert_exit 1 \
  "case_medium_pol_skipped" \
  "medium-batch pol-probe skip fails"
assert_stderr_contains "pol-probe-advisor cannot be skipped for medium-batch" \
  "case_medium_pol_skipped" \
  "medium-batch pol-probe skip reports reason"

exit "$FAIL"
