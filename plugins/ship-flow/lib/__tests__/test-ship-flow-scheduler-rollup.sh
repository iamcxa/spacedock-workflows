#!/usr/bin/env bash
# test-ship-flow-scheduler-rollup.sh - AC-6: deterministic daily rollup
#
# design.md §8/§10: `rollup --events-log <path> --date <YYYY-MM-DD>` reads a
# fixed day's JSONL events and emits deterministic markdown (dispatches,
# durations, gate waits, failures, costs, interventions) with no wall-clock in
# the body. Feeding the same fixed fixture events log twice must produce
# byte-identical output.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/ship-flow-scheduler"
EVENTS_LOG="${FIXTURE_ROOT}/rollup/events-2026-07-19.jsonl"

PASS=0
FAIL=0
ERRORS=()

record_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
record_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"
  else record_fail "$desc (expected exit ${expected}, got ${actual})"; fi
}

assert_contains() {
  local desc="$1" pattern="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qE "$pattern"; then record_pass "$desc"
  else record_fail "$desc (missing pattern: ${pattern})"; fi
}

OUT=""
EXIT_CODE=0
run_capture() { OUT="$("$@" 2>&1)"; EXIT_CODE=$?; }

run_determinism_case() {
  local run1 run2
  run_capture "$HELPER" rollup --events-log "$EVENTS_LOG" --date 2026-07-19
  assert_exit "rollup: exit 0" 0 "$EXIT_CODE"
  run1="$OUT"
  assert_contains "rollup: echoes the requested date" '2026-07-19' "$run1"
  assert_contains "rollup: dispatches count" 'dispatch' "$run1"
  assert_contains "rollup: failures/interventions count" 'blocked' "$run1"

  run_capture "$HELPER" rollup --events-log "$EVENTS_LOG" --date 2026-07-19
  run2="$OUT"

  if [ "$run1" = "$run2" ]; then
    record_pass "rollup: byte-identical across two runs of the same fixed events log"
  else
    record_fail "rollup: output differs across identical runs (non-deterministic)"
  fi
}

run_no_events_for_date_case() {
  run_capture "$HELPER" rollup --events-log "$EVENTS_LOG" --date 2099-01-01
  assert_exit "rollup: no events for date -> exit 3 (env/no-events)" 3 "$EXIT_CODE"
}

run_usage_case() {
  run_capture "$HELPER" rollup --events-log "$EVENTS_LOG"
  assert_exit "rollup: missing --date -> exit 2 (usage)" 2 "$EXIT_CODE"
}

echo "=== test-ship-flow-scheduler-rollup.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_determinism_case
  run_no_events_for_date_case
  run_usage_case
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
