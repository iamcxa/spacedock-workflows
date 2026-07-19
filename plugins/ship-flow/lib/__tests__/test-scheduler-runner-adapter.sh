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

run_tick_id_marker_case() {
  # AC-1a: an explicit --tick-id reaches the spawned child as
  # SHIP_FLOW_SCHEDULER_TICK_ID (env), in both the hermetic and production
  # branches identically (design.md AC-1 delta).
  SHIP_FLOW_SCHEDULER_RUNNER_CMD="bash ${FIXTURE_ROOT}/runner/stub-runner-echo-tick-id.sh" \
    run_capture "$HELPER" run --entity fixture-tick-id --workdir "$WORKDIR" --timeout 30 --tick-id T-42
  assert_exit "tick-id: exit 0 (success)" 0 "$EXIT_CODE"
  local receipt
  receipt="$(printf '%s' "$OUT" | sed -n 's/.*"receipt":"\([^"]*\)".*/\1/p')"
  local receipt_body=""
  [ -n "$receipt" ] && [ -f "$receipt" ] && receipt_body="$(cat "$receipt")"
  assert_contains "tick-id: TICK_ID_SEEN=T-42 in receipt" 'TICK_ID_SEEN=T-42' "$receipt_body"
}

run_print_spawn_prompt_case() {
  # AC-1b: --print-spawn is a hermetic mode -- prints the resolved
  # prompt/spawn as JSON and execs nothing (no receipt file created).
  local receipt_dir before_count after_count
  receipt_dir="${WORKDIR}/.ship-flow-scheduler-receipts"
  before_count="$(find "$receipt_dir" -name '*.txt' 2>/dev/null | wc -l | tr -d ' ')"
  run_capture "$HELPER" run --entity fixture-print-spawn --workdir "$WORKDIR" --timeout 30 --print-spawn
  after_count="$(find "$receipt_dir" -name '*.txt' 2>/dev/null | wc -l | tr -d ' ')"
  assert_exit "print-spawn: exit 0" 0 "$EXIT_CODE"
  assert_contains "print-spawn: prompt field present" '"prompt":"/ship fixture-print-spawn"' "$OUT"
  if [ "$before_count" = "$after_count" ]; then record_pass "print-spawn: no receipt file created"
  else record_fail "print-spawn: no receipt file created (count went ${before_count} -> ${after_count})"; fi
  # AC-2: the resolved spawn goes through the launcher, not raw claude.
  assert_contains "print-spawn: spawn uses --plugin-dir" '\-\-plugin-dir' "$OUT"
  assert_contains "print-spawn: spawn passes through -- -p --output-format text" '\-\- -p --output-format text' "$OUT"
  assert_contains "print-spawn: spawn resolves \${SPACEDOCK_BIN:-spacedock}" '(spacedock|SPACEDOCK_BIN)' "$OUT"
}

run_print_spawn_delegation_case() {
  # AC-1b: delegation line + tick_id echoed when --tick-id present.
  run_capture "$HELPER" run --entity fixture-print-spawn --workdir "$WORKDIR" --timeout 30 --print-spawn --tick-id T-9
  assert_exit "print-spawn delegation: exit 0" 0 "$EXIT_CODE"
  assert_contains "print-spawn delegation: tick_id=T-9 present" 'tick_id=T-9' "$OUT"
  assert_contains "print-spawn delegation: delegation marker text present" 'ship-flow-scheduler tick delegation' "$OUT"
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

run_tick_threads_tick_id_case() {
  # AC-1c: the tick's own computed tick_id (cmd_tick, date -u +%Y%m%dT%H%M%SZ)
  # threads into the adapter call for a real --runner gh dispatch -- not just
  # the adapter's standalone --tick-id support proven above.
  local wf receipt receipt_body
  wf="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/eligible-entity" "${wf}/eligible-entity"
  SHIP_FLOW_SCHEDULER_RUNNER_CMD="bash ${FIXTURE_ROOT}/runner/stub-runner-echo-tick-id.sh" \
    run_capture "${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh" tick \
      --workflow-dir "$wf" --controller-worktree "$wf" \
      --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
      --runner gh --timeout 30 \
      --events-log "${wf}/events.jsonl"
  receipt="$(printf '%s' "$OUT" | sed -n 's/.*"receipt":"\([^"]*\)".*/\1/p')"
  receipt_body=""
  [ -n "$receipt" ] && [ -f "$receipt" ] && receipt_body="$(cat "$receipt")"
  rm -rf "$wf"
  assert_exit "tick threads tick_id: exit 0" 0 "$EXIT_CODE"
  assert_contains "tick threads tick_id: TICK_ID_SEEN shaped like a tick id" 'TICK_ID_SEEN=[0-9]{8}T[0-9]{6}Z' "$receipt_body"
}

run_tick_preflight_accepts_spacedock_bin_case() {
  # AC-2: with the launcher path, `command -v spacedock` alone must also
  # satisfy the --runner gh preflight (not just `command -v claude`). A
  # genuinely hermetic PATH (excludes /opt/homebrew/bin, /usr/local/bin,
  # ~/.local/bin -- where a real claude/spacedock might live on a dev
  # machine) with ONLY a stub `spacedock` proves the widened check, not the
  # developer's own PATH.
  local fake_bin_dir wf
  fake_bin_dir="$(mktemp -d)"
  cat > "${fake_bin_dir}/spacedock" <<'STUB'
#!/usr/bin/env bash
exit 0
STUB
  chmod +x "${fake_bin_dir}/spacedock"
  wf="$(mktemp -d)"
  PATH="${fake_bin_dir}:/usr/bin:/bin" \
    run_capture "${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh" tick \
      --workflow-dir "$wf" --controller-worktree "$wf" \
      --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
      --runner gh --timeout 30 \
      --events-log "${wf}/events.jsonl"
  rm -rf "$fake_bin_dir" "$wf"
  assert_exit "preflight accepts spacedock-only PATH: exit 0 (not 3)" 0 "$EXIT_CODE"
}

run_tick_derives_timeout_from_time_budget_case() {
  # AC-3a: an entity's declared time_budget (frontmatter) overrides the
  # timeout used for its own dispatch. 2h30m -> 9000s.
  local wf
  wf="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/time-budget-entity" "${wf}/time-budget-entity"
  run_capture "${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh" tick \
    --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "derive timeout from time_budget: exit 0" 0 "$EXIT_CODE"
  assert_contains "derive timeout from time_budget: timeout_sec=9000" '"timeout_sec":9000' "$OUT"
}

run_tick_defaults_timeout_without_time_budget_case() {
  # AC-3a: no time_budget declared + no --timeout flag passed -> the
  # generous 5400s default (cmd_tick's own compiled default, bumped from
  # the prior 900s so omitted-flag production ticks get real headroom).
  local wf
  wf="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/eligible-entity" "${wf}/eligible-entity"
  run_capture "${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh" tick \
    --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "default timeout without time_budget: exit 0" 0 "$EXIT_CODE"
  assert_contains "default timeout without time_budget: timeout_sec=5400" '"timeout_sec":5400' "$OUT"
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
  run_tick_id_marker_case
  run_print_spawn_prompt_case
  run_print_spawn_delegation_case
  if [ -x "${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh" ]; then
    run_tick_surfaces_timeout_as_blocked_case
    run_tick_threads_tick_id_case
    run_tick_preflight_accepts_spacedock_bin_case
    run_tick_derives_timeout_from_time_budget_case
    run_tick_defaults_timeout_without_time_budget_case
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
