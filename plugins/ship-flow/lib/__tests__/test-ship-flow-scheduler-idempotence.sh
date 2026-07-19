#!/usr/bin/env bash
# test-ship-flow-scheduler-idempotence.sh - AC-1: idempotent tick
#
# Two rows from design.md §10:
#   1. Replay idempotence: a fixture with worktree+PR already present (models a
#      crash after those canonical artifacts were created) never re-dispatches,
#      on the first tick OR a replay.
#   2. Duplicate-dispatch refusal: a second invocation while the controller lease
#      is held emits `no-op reason=lease-held`, exit 0, no dispatch — the
#      concurrency=1 mechanism (design.md §5).

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh"
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

assert_not_contains() {
  local desc="$1" pattern="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qE "$pattern"; then record_fail "$desc (unexpected pattern: ${pattern})"
  else record_pass "$desc"; fi
}

OUT=""
EXIT_CODE=0
run_capture() { OUT="$("$@" 2>&1)"; EXIT_CODE=$?; }

one_entity_workflow() {
  local entity="$1" dir
  dir="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/${entity}" "${dir}/${entity}"
  printf '%s\n' "$dir"
}

run_replay_idempotence_case() {
  local wf run1 run2
  wf="$(one_entity_workflow already-dispatched-entity)"

  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  run1="$OUT"
  assert_exit "replay #1: tick exit 0" 0 "$EXIT_CODE"
  assert_not_contains "replay #1: never a dispatch event" '"event":"dispatch"' "$run1"

  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  run2="$OUT"
  assert_exit "replay #2: tick exit 0" 0 "$EXIT_CODE"
  assert_not_contains "replay #2 (crash-replay simulation): never a dispatch event" '"event":"dispatch"' "$run2"

  rm -rf "$wf"
}

run_lease_held_case() {
  local wf lease_dir holder_pid
  wf="$(one_entity_workflow eligible-entity)"
  lease_dir="${wf}/.ship-flow-scheduler.lease"
  mkdir -p "$lease_dir"
  # A genuinely live holder: a background sleep whose pid `kill -0` succeeds.
  sleep 30 &
  holder_pid=$!
  printf 'pid=%s\nstart_ts=%s\ntick_id=held-by-test\nentity=eligible-entity\n' \
    "$holder_pid" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" > "${lease_dir}/record"

  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"

  kill "$holder_pid" 2>/dev/null || true
  wait "$holder_pid" 2>/dev/null || true
  rm -rf "$wf"

  assert_exit "lease held: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "lease held: no-op event" '"event":"no-op"' "$OUT"
  assert_contains "lease held: reason=lease-held" '"reason":"lease-held"' "$OUT"
  assert_not_contains "lease held: never a dispatch event" '"event":"dispatch"' "$OUT"
}

run_stale_lease_reclaim_case() {
  local wf lease_dir
  wf="$(one_entity_workflow eligible-entity)"
  lease_dir="${wf}/.ship-flow-scheduler.lease"
  mkdir -p "$lease_dir"
  # Dead pid + an old start_ts — the tick must reclaim, not block forever.
  printf 'pid=999999\nstart_ts=2020-01-01T00:00:00Z\ntick_id=stale\nentity=nobody\n' \
    > "${lease_dir}/record"

  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"

  assert_exit "stale lease: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "stale lease: reclaims and dispatches the eligible entity" '"event":"dispatch"' "$OUT"
}

echo "=== test-ship-flow-scheduler-idempotence.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_replay_idempotence_case
  run_lease_held_case
  run_stale_lease_reclaim_case
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
