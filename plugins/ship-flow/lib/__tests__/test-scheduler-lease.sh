#!/usr/bin/env bash
# test-scheduler-lease.sh - F2 (feedback cycle 1, BLOCKING, concurrency=1):
# lease reclaim must require a provably-dead holder — never age alone — and
# release must verify an ownership token before removing a record
# (lib/scheduler-lease.sh:60,74). Unit-level: sources the lib directly rather
# than going through the full `tick` CLI, since both bugs are pinned to
# scheduler-lease.sh's own two functions.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
LEASE_LIB="${PLUGIN_ROOT}/lib/scheduler-lease.sh"

PASS=0
FAIL=0
ERRORS=()

record_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
record_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"
  else record_fail "$desc (expected '${expected}', got '${actual}')"; fi
}

# shellcheck source=../scheduler-lease.sh
source "$LEASE_LIB"

run_stale_but_alive_not_reclaimed_case() {
  # A holder whose recorded age exceeds max_timeout but whose pid is still
  # alive (an unbounded reconcile still running) must NOT be reclaimed —
  # age alone is not proof of death.
  local wf holder_pid rc record_pid
  wf="$(mktemp -d)"
  sleep 30 &
  holder_pid=$!
  mkdir -p "$(scheduler_lease_dir "$wf")"
  printf 'pid=%s\nstart_ts=2020-01-01T00:00:00Z\ntick_id=old\nentity=nobody\ntoken=old-token\n' \
    "$holder_pid" > "$(scheduler_lease_dir "$wf")/record"

  scheduler_lease_acquire "$wf" "new-tick" 60 "" >/dev/null 2>&1
  rc=$?

  record_pid="$(scheduler_lease_field "$(scheduler_lease_dir "$wf")/record" pid)"
  kill "$holder_pid" 2>/dev/null || true
  wait "$holder_pid" 2>/dev/null || true

  assert_eq "stale-but-alive holder (age>timeout, pid alive): acquire refuses" 1 "$rc"
  assert_eq "stale-but-alive holder: record untouched (still names original pid)" "$holder_pid" "$record_pid"

  rm -rf "$wf"
}

run_dead_pid_still_reclaimed_case() {
  # Sanity: a genuinely dead holder (age-independent) must still be
  # reclaimable — the fix narrows the reclaim trigger to liveness, it must
  # not remove reclaim altogether.
  local wf rc
  wf="$(mktemp -d)"
  mkdir -p "$(scheduler_lease_dir "$wf")"
  printf 'pid=999999\nstart_ts=2020-01-01T00:00:00Z\ntick_id=old\nentity=nobody\ntoken=old-token\n' \
    > "$(scheduler_lease_dir "$wf")/record"

  scheduler_lease_acquire "$wf" "new-tick" 60 "" >/dev/null 2>&1
  rc=$?

  assert_eq "dead-pid holder: acquire reclaims (exit 0)" 0 "$rc"

  rm -rf "$wf"
}

run_wrong_token_release_refused_case() {
  local wf rc held_pid still_pid
  wf="$(mktemp -d)"
  scheduler_lease_acquire "$wf" "tick-a" 900 "" >/dev/null
  held_pid="$(scheduler_lease_field "$(scheduler_lease_dir "$wf")/record" pid)"

  scheduler_lease_release "$wf" "not-the-real-token"
  rc=$?
  still_pid="$(scheduler_lease_field "$(scheduler_lease_dir "$wf")/record" pid)"

  assert_eq "wrong-token release: refused (exit 1)" 1 "$rc"
  assert_eq "wrong-token release: lease record still present" "$held_pid" "$still_pid"

  # Sanity: the correct token DOES release it — the guard isn't a permanent
  # lock-out, only a mismatch refuses.
  scheduler_lease_release "$wf" "$SCHEDULER_LEASE_TOKEN"
  assert_eq "correct-token release: record removed" "" "$(scheduler_lease_field "$(scheduler_lease_dir "$wf")/record" pid)"

  rm -rf "$wf"
}

echo "=== test-scheduler-lease.sh ==="
echo ""

if [ ! -f "$LEASE_LIB" ]; then
  record_fail "lease lib exists (${LEASE_LIB})"
else
  record_pass "lease lib exists"
  run_stale_but_alive_not_reclaimed_case
  run_dead_pid_still_reclaimed_case
  run_wrong_token_release_refused_case
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
