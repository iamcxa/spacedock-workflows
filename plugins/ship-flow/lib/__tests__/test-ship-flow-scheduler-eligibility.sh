#!/usr/bin/env bash
# test-ship-flow-scheduler-eligibility.sh - fail-closed dual-key eligibility (AC-2)
#
# design.md §2/§3: an entity is `eligible` iff frontmatter status is shaped (not
# draft, not terminal) AND the linked gh issue is OPEN with label `sd:approved`
# AND a DoR mechanical pass AND no live worktree AND no open/merged PR. Any single
# failed key fails closed: a `refusal` event, matching reason code, zero adapter
# spawn (AC-2's "zero worker tokens").

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

# run_capture <cmd...> — sets OUT / EXIT_CODE without tripping this file's own
# error handling (nonzero exits are data here, not script failures).
OUT=""
EXIT_CODE=0
run_capture() {
  OUT="$("$@" 2>&1)"
  EXIT_CODE=$?
}

# one_entity_workflow <entity-name> — copies a single fixture entity folder into
# an isolated TMP workflow dir so each case scans exactly one candidate.
one_entity_workflow() {
  local entity="$1" dir
  dir="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/${entity}" "${dir}/${entity}"
  printf '%s\n' "$dir"
}

run_refusal_case() {
  local desc="$1" entity="$2" expected_reason="$3"
  local wf
  wf="$(one_entity_workflow "$entity")"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "${desc}: tick exit 0 (refusal is a recorded outcome, not a fault)" 0 "$EXIT_CODE"
  assert_contains "${desc}: emits refusal event" '"event":"refusal"' "$OUT"
  assert_contains "${desc}: reason=${expected_reason}" "\"reason\":\"${expected_reason}\"" "$OUT"
  assert_contains "${desc}: outcome=refused" '"outcome":"refused"' "$OUT"
}

run_dedup_case() {
  local desc="$1" entity="$2" expected_reason="$3"
  local wf
  wf="$(one_entity_workflow "$entity")"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "${desc}: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "${desc}: no dispatch event" '"event":"(refusal|no-op)"' "$OUT"
  assert_contains "${desc}: reason names the dedup key" "\"reason\":\"${expected_reason}\"" "$OUT"
}

run_live_worktree_dedup_case() {
  # F1 (feedback cycle 1, BLOCKING, AC-1): a crash after the real worktree was
  # created on disk but before `/ship` wrote `worktree:` into frontmatter must
  # still dedup-exclude the entity. The fixture's frontmatter worktree/pr are
  # BOTH empty; only a LIVE directory at the conventional path proves it.
  local desc="worktree-exists dedup (live filesystem, no frontmatter record)"
  local wf
  wf="$(one_entity_workflow worktree-live-only-entity)"
  mkdir -p "${wf}/.worktrees/spacedock-ensign-worktree-live-only-entity"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "${desc}: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "${desc}: no dispatch event" '"event":"(refusal|no-op)"' "$OUT"
  assert_contains "${desc}: reason=worktree-exists" '"reason":"worktree-exists"' "$OUT"
}

run_live_pr_dedup_case() {
  # F1 (feedback cycle 1, BLOCKING, AC-1): same crash window, but the
  # already-created artifact is a PR, not a worktree. frontmatter `pr:` is
  # empty; only a live gh lookup keyed by the entity's conventional branch
  # (independent of any recorded PR number) proves it.
  local desc="pr-exists dedup (live gh lookup, no frontmatter record)"
  local wf
  wf="$(one_entity_workflow pr-live-only-entity)"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "${desc}: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "${desc}: no dispatch event" '"event":"(refusal|no-op)"' "$OUT"
  assert_contains "${desc}: reason=pr-exists" '"reason":"pr-exists"' "$OUT"
}

write_gh_error_stub() {
  # W1 (feedback cycle 2, WARNING → fixed): a fake `gh` binary on PATH that
  # answers `issue view` (so the issue key still resolves normally) but FAILS
  # `pr list` with a nonzero exit — modeling a real gh error (auth/network),
  # not "no PR found". `pr_exists_for_slug`'s real-gh branch must surface this
  # as UNKNOWN (fail-closed), never NONE (fail-open/dispatch-allowed).
  local dir="$1"
  mkdir -p "$dir"
  cat > "${dir}/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  printf 'OPEN\tsd:approved\n'
  exit 0
fi
if [ "$1" = "pr" ] && [ "$2" = "list" ]; then
  echo "gh: authentication failed" >&2
  exit 1
fi
echo "unexpected gh invocation: $*" >&2
exit 98
EOF
  chmod +x "${dir}/gh"
}

run_gh_error_fail_closed_case() {
  # W1 (feedback cycle 2, WARNING): pr_exists_for_slug's real-gh branch must
  # fail CLOSED (UNKNOWN -> dedup-excluded) when the `gh pr list` invocation
  # itself errors, mirroring gh_pr_state's `|| printf UNKNOWN` pattern. Reuses
  # the pr-live-only-entity fixture (shaped, issue OPEN + sd:approved, empty
  # frontmatter worktree/pr) so the eligibility scan reaches the live-gh
  # lookup, but exercises the REAL (non-fixture) gh code path via a PATH stub
  # instead of --gh-provider fixture.
  local desc="gh-error on live PR lookup fails closed (no dispatch)"
  local wf fakebin
  wf="$(one_entity_workflow pr-live-only-entity)"
  fakebin="$(mktemp -d)"
  write_gh_error_stub "$fakebin"
  PATH="${fakebin}:$PATH" run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf" "$fakebin"
  assert_exit "${desc}: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "${desc}: no dispatch event" '"event":"(refusal|no-op)"' "$OUT"
  assert_contains "${desc}: reason=pr-exists (fail-closed on gh error)" '"reason":"pr-exists"' "$OUT"
}

run_closed_pr_live_dedup_case() {
  # W2 (feedback cycle 2, WARNING): the live-PR dedup case-arm must also
  # exclude on CLOSED (not just OPEN/MERGED/UNKNOWN) — a closed-unmerged PR on
  # the entity's conventional branch is still dedup ground truth from a prior
  # dispatch, not a green light for a fresh one.
  local desc="pr-exists dedup (live gh lookup, CLOSED state)"
  local wf
  wf="$(one_entity_workflow pr-closed-live-only-entity)"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "${desc}: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "${desc}: no dispatch event" '"event":"(refusal|no-op)"' "$OUT"
  assert_contains "${desc}: reason=pr-exists" '"reason":"pr-exists"' "$OUT"
}

run_eligible_case() {
  local wf
  wf="$(one_entity_workflow eligible-entity)"
  run_capture "$HELPER" tick --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"
  assert_exit "eligible entity: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "eligible entity: dispatch event emitted" '"event":"dispatch"' "$OUT"
  assert_contains "eligible entity: names the entity" '"entity":"eligible-entity"' "$OUT"
}

echo "=== test-ship-flow-scheduler-eligibility.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_refusal_case "not-shaped" not-shaped-entity "not-shaped"
  run_refusal_case "issue-closed" issue-closed-entity "issue-closed"
  run_refusal_case "not-sd-approved" not-approved-entity "not-sd-approved"
  run_dedup_case "worktree-exists dedup" worktree-exists-entity "worktree-exists"
  run_dedup_case "pr-exists dedup" pr-exists-entity "pr-exists"
  run_live_worktree_dedup_case
  run_live_pr_dedup_case
  run_gh_error_fail_closed_case
  run_closed_pr_live_dedup_case
  run_eligible_case
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
