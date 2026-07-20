#!/usr/bin/env bash
# test-ship-flow-scheduler-refusal-batch.sh - AC-1/AC-2/AC-3: two-phase
# batch-emit + reason-scoped dedup (design.md §3, plan.md Task 1).
#
# Precedence-2 head-block bug: the pre-fix loop only ever remembers the FIRST
# case-1|2 (refusal) outcome, and a later case-0 (eligible) hit returns
# immediately without ever emitting even that one — so every OTHER entity's
# refusal reason is silently discarded (the finale's 66/119 duplicate
# `not-shaped` beats masking `dor-stale-shape` on a different entity). Fix:
# two-phase collect-then-act — Phase 1 scans every entity and queues every
# non-deduped refusal, Phase 2 emits all queued refusals in scan order, THEN
# the beat's one primary action (dispatch, else no-op).

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

# assert_before <desc> <pattern_a> <pattern_b> <haystack> — proves ordering
# across lines (AC-3 pins "refusals before dispatch", which assert_contains
# alone cannot express). Uses the LAST line matching pattern_a and the FIRST
# line matching pattern_b: when pattern_b matches exactly one line (the
# beat's single primary action), "last A before first B" proves ALL A-lines
# precede B, not just one.
assert_before() {
  local desc="$1" pattern_a="$2" pattern_b="$3" haystack="$4"
  local line_a line_b
  line_a="$(printf '%s' "$haystack" | grep -nE "$pattern_a" | tail -1 | cut -d: -f1)"
  line_b="$(printf '%s' "$haystack" | grep -nE "$pattern_b" | head -1 | cut -d: -f1)"
  if [ -n "$line_a" ] && [ -n "$line_b" ] && [ "$line_a" -lt "$line_b" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (pattern_a last-line=${line_a:-none}, pattern_b first-line=${line_b:-none})"
  fi
}

OUT=""
EXIT_CODE=0
run_capture() { OUT="$("$@" 2>&1)"; EXIT_CODE=$?; }

# three_entity_workflow <a> <b> <c> — mirrors two_entity_workflow
# (test-ship-flow-scheduler-backoff.sh:123-130), one more fixture arg.
three_entity_workflow() {
  local entity_a="$1" entity_b="$2" entity_c="$3" dir
  dir="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/${entity_a}" "${dir}/${entity_a}"
  cp -R "${FIXTURE_ROOT}/workflow/${entity_b}" "${dir}/${entity_b}"
  cp -R "${FIXTURE_ROOT}/workflow/${entity_c}" "${dir}/${entity_c}"
  git -C "$dir" init -q 2>/dev/null || true
  printf '%s\n' "$dir"
}

one_entity_workflow() {
  local entity="$1" dir
  dir="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/${entity}" "${dir}/${entity}"
  git -C "$dir" init -q 2>/dev/null || true
  printf '%s\n' "$dir"
}

# set_frontmatter_field <file> <field> <value> — mirrors
# test-ship-flow-scheduler-fullcycle.sh:118-126.
set_frontmatter_field() {
  local file="$1" field="$2" value="$3" tmp="${1}.tmp"
  awk -v field="$field" -v value="$value" '
    /^---[[:space:]]*$/ { fence++; print; next }
    fence == 1 { prefix = field ":"; if (index($0, prefix) == 1) { print field ": " value; next } }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

run_batch_refusal_no_eligible_case() {
  # AC-1: 3 refusing + 0 eligible -> 3 distinct refusal events (one per
  # entity) + one trailing no-op nothing-eligible. Pre-fix, only the FIRST
  # case-1 outcome is ever recorded and emitted.
  local wf
  wf="$(three_entity_workflow not-shaped-entity issue-closed-entity not-approved-entity)"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "AC-1 no-eligible: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "AC-1 no-eligible: not-shaped refusal" '"event":"refusal".*"entity":"not-shaped-entity".*"reason":"not-shaped"' "$OUT"
  assert_contains "AC-1 no-eligible: issue-closed refusal" '"event":"refusal".*"entity":"issue-closed-entity".*"reason":"issue-closed"' "$OUT"
  assert_contains "AC-1 no-eligible: not-sd-approved refusal" '"event":"refusal".*"entity":"not-approved-entity".*"reason":"not-sd-approved"' "$OUT"
  assert_contains "AC-1 no-eligible: trailing no-op nothing-eligible" '"event":"no-op".*"reason":"nothing-eligible"' "$OUT"
  local refusal_count
  refusal_count="$(printf '%s\n' "$OUT" | grep -c '"event":"refusal"')"
  if [ "$refusal_count" = 3 ]; then record_pass "AC-1 no-eligible: exactly 3 refusal lines"
  else record_fail "AC-1 no-eligible: exactly 3 refusal lines (got ${refusal_count})"; fi
}

run_batch_refusal_with_dispatch_case() {
  # AC-3: 2 refusing + 1 eligible -> 2 refusal events THEN 1 dispatch, in
  # that order. list_entities sorts alphabetically and eligible-entity sorts
  # FIRST ('e' < 'n') -- the strongest disproof of the head-block bug:
  # pre-fix, the loop's `return 0` on the first case-0 hit fires on the very
  # first iteration, so today's actual output is 1 dispatch line and ZERO
  # refusal lines (the two refusing entities are never even scanned).
  local wf
  wf="$(three_entity_workflow not-shaped-entity not-approved-entity eligible-entity)"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "AC-3 with-dispatch: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "AC-3 with-dispatch: not-shaped refusal" '"event":"refusal".*"entity":"not-shaped-entity".*"reason":"not-shaped"' "$OUT"
  assert_contains "AC-3 with-dispatch: not-sd-approved refusal" '"event":"refusal".*"entity":"not-approved-entity".*"reason":"not-sd-approved"' "$OUT"
  assert_contains "AC-3 with-dispatch: dispatch for eligible-entity" '"event":"dispatch".*"entity":"eligible-entity"' "$OUT"
  local refusal_count
  refusal_count="$(printf '%s\n' "$OUT" | grep -c '"event":"refusal"')"
  if [ "$refusal_count" = 2 ]; then record_pass "AC-3 with-dispatch: exactly 2 refusal lines"
  else record_fail "AC-3 with-dispatch: exactly 2 refusal lines (got ${refusal_count})"; fi
  assert_before "AC-3 with-dispatch: both refusals precede the dispatch" '"event":"refusal"' '"event":"dispatch"' "$OUT"
}

run_refusal_dedup_window_case() {
  # AC-2: 1 refusing entity, 3 sequential ticks sharing one --events-log
  # within the window -> tick 1 refusal, ticks 2/3 no-op refusal-deduped, NO
  # re-emitted refusal line. Pre-fix, entity_in_backoff only matches
  # event=blocked, so every tick re-emits the identical refusal -- the
  # literal finale spam.
  #
  # DC-4 sub-case (same case): a REASON CHANGE between ticks must re-emit --
  # dedup is reason-scoped, not a blanket slug-only suppression. Mutating
  # frontmatter status: (empty) -> shape flips EVAL_REASON from `not-shaped`
  # to `issue-missing` (no issue-not-shaped-entity.env gh fixture exists), a
  # real state change, not spam.
  local wf events_log entity_path
  wf="$(one_entity_workflow not-shaped-entity)"
  events_log="${wf}/events.jsonl"
  entity_path="${wf}/not-shaped-entity/index.md"

  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  assert_exit "AC-2 dedup: tick 1 exit 0" 0 "$EXIT_CODE"
  assert_contains "AC-2 dedup: tick 1 emits refusal not-shaped" '"event":"refusal".*"reason":"not-shaped"' "$OUT"

  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  assert_exit "AC-2 dedup: tick 2 exit 0" 0 "$EXIT_CODE"
  assert_contains "AC-2 dedup: tick 2 no-op refusal-deduped" '"event":"no-op".*"reason":"refusal-deduped"' "$OUT"
  assert_not_contains "AC-2 dedup: tick 2 emits NO refusal line" '"event":"refusal"' "$OUT"

  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  assert_exit "AC-2 dedup: tick 3 exit 0" 0 "$EXIT_CODE"
  assert_contains "AC-2 dedup: tick 3 no-op refusal-deduped" '"event":"no-op".*"reason":"refusal-deduped"' "$OUT"
  assert_not_contains "AC-2 dedup: tick 3 emits NO refusal line" '"event":"refusal"' "$OUT"

  set_frontmatter_field "$entity_path" status shape

  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  assert_exit "AC-2 dedup (DC-4 reason-change): tick 4 exit 0" 0 "$EXIT_CODE"
  assert_contains "AC-2 dedup (DC-4 reason-change): tick 4 emits FRESH refusal issue-missing" '"event":"refusal".*"reason":"issue-missing"' "$OUT"

  rm -rf "$wf"
}

run_events_log_append_failure_swallow_case() {
  # F2 (verify feedback cycle 1, codex adversarial): pins the deliberate
  # parity choice documented at emit_event's append site and in design.md
  # §5 -- events-log append failures are swallowed (pre-existing, unchanged
  # by the two-phase batching rewrite; not a new failure mode this entity
  # introduced). Pointing --events-log at a path whose PARENT DIRECTORY
  # does not exist makes every emit_event append in the beat fail, but the
  # tick must still complete normally: exit 0, the full refusal batch AND
  # the trailing primary event still reach stdout unchanged, and the
  # broken log path is never created (sanity check that the append
  # genuinely failed rather than being skipped for some other reason).
  #
  # No RED->GREEN pair: unlike Task 1's mechanism cases, this pins EXISTING
  # emit_event behavior with zero code change (mirrors Task 2's rollup pin
  # -- design.md §5 / execute.md cycle-2 record the adjudication).
  local wf broken_log
  wf="$(three_entity_workflow not-shaped-entity issue-closed-entity not-approved-entity)"
  broken_log="${wf}/no-such-dir/events.jsonl"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$broken_log"
  assert_exit "F2 append-failure swallow: tick exit 0 despite broken --events-log" 0 "$EXIT_CODE"
  local refusal_count
  refusal_count="$(printf '%s\n' "$OUT" | grep -c '"event":"refusal"')"
  if [ "$refusal_count" = 3 ]; then record_pass "F2 append-failure swallow: all 3 refusals still on stdout"
  else record_fail "F2 append-failure swallow: all 3 refusals still on stdout (got ${refusal_count})"; fi
  assert_contains "F2 append-failure swallow: trailing no-op nothing-eligible still emitted" '"event":"no-op".*"reason":"nothing-eligible"' "$OUT"
  if [ -f "$broken_log" ]; then
    record_fail "F2 append-failure swallow: broken log path was NOT created (sanity: append genuinely failed)"
  else
    record_pass "F2 append-failure swallow: broken log path was NOT created (sanity: append genuinely failed)"
  fi
  rm -rf "$wf"
}

echo "=== test-ship-flow-scheduler-refusal-batch.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_batch_refusal_no_eligible_case
  run_batch_refusal_with_dispatch_case
  run_refusal_dedup_window_case
  run_events_log_append_failure_swallow_case
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
