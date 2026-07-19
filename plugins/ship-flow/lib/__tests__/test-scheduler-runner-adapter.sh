#!/usr/bin/env bash
# test-scheduler-runner-adapter.sh - AC-3: bounded runner adapter, carrier-swap seam
#
# design.md §6: `scheduler-runner-adapter.sh run --entity --workdir --timeout
# [--env K=V]` emits exactly one JSON line {"exit_class","sentinel","receipt"} on
# stdout, exit code mapping 0/124(timeout)/1(error). Tests substitute the real
# `claude -p` invocation via SHIP_FLOW_SCHEDULER_RUNNER_CMD (a test-only seam) so
# success/timeout/error are exercised hermetically, without a real spawn — the
# timeout case genuinely waits out the real `timeout` wrapper (bash 3.2+ has no
# cheap way to fake SIGTERM-under-timeout without doing so).

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/lib/scheduler-runner-adapter.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/ship-flow-scheduler"

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

WORKDIR="$(mktemp -d)"
trap 'rm -rf "$WORKDIR"' EXIT

run_success_case() {
  SHIP_FLOW_SCHEDULER_RUNNER_CMD="bash ${FIXTURE_ROOT}/runner/stub-runner-success.sh" \
    run_capture "$HELPER" run --entity fixture-success --workdir "$WORKDIR" --timeout 30
  assert_exit "success: exit_class success -> exit 0" 0 "$EXIT_CODE"
  assert_contains "success: exit_class=success" '"exit_class":"success"' "$OUT"
  assert_contains "success: sentinel captured" '"sentinel":"SHIP_FLOW_TERMINAL' "$OUT"
  assert_contains "success: receipt path present" '"receipt":"[^"]+\.txt"' "$OUT"
}

run_error_case() {
  SHIP_FLOW_SCHEDULER_RUNNER_CMD="bash ${FIXTURE_ROOT}/runner/stub-runner-error.sh" \
    run_capture "$HELPER" run --entity fixture-error --workdir "$WORKDIR" --timeout 30
  assert_exit "error: exit_class error -> exit 1" 1 "$EXIT_CODE"
  assert_contains "error: exit_class=error" '"exit_class":"error"' "$OUT"
  assert_contains "error: sentinel is null (no terminal marker)" '"sentinel":null' "$OUT"
}

run_timeout_case() {
  SHIP_FLOW_SCHEDULER_RUNNER_CMD="bash ${FIXTURE_ROOT}/runner/stub-runner-timeout.sh" \
    run_capture "$HELPER" run --entity fixture-timeout --workdir "$WORKDIR" --timeout 1
  assert_exit "timeout: exit_class timeout -> exit 124" 124 "$EXIT_CODE"
  assert_contains "timeout: exit_class=timeout" '"exit_class":"timeout"' "$OUT"
}

run_tick_surfaces_timeout_as_blocked_case() {
  # AC-3's "timeout -> blocked, no retry" is a tick-level contract; exercise it
  # end to end through the real tick with --runner gh so it actually calls this
  # adapter (not the --runner fixture stub-json bypass T2 uses).
  local wf
  wf="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/eligible-entity" "${wf}/eligible-entity"
  SHIP_FLOW_SCHEDULER_RUNNER_CMD="bash ${FIXTURE_ROOT}/runner/stub-runner-timeout.sh" \
    run_capture "${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh" tick \
      --workflow-dir "$wf" --controller-worktree "$wf" \
      --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
      --runner gh --timeout 1 \
      --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "tick surfaces timeout: exit 0 (blocked is a recorded outcome)" 0 "$EXIT_CODE"
  assert_contains "tick surfaces timeout: blocked event" '"event":"blocked"' "$OUT"
  assert_contains "tick surfaces timeout: source=run-timeout" '"source":"run-timeout"' "$OUT"
}

echo "=== test-scheduler-runner-adapter.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_success_case
  run_error_case
  run_timeout_case
  if [ -x "${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh" ]; then
    run_tick_surfaces_timeout_as_blocked_case
  else
    echo "  NOTE: bin/ship-flow-scheduler.sh not yet built — skipping tick-level blocked surfacing (covered again once T2 lands)"
  fi
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
