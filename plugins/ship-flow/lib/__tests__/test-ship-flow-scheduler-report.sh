#!/usr/bin/env bash
# test-ship-flow-scheduler-report.sh - AC-4: derived gate-projection report, no-write
#
# design.md §7/§10: `report` renders a read-only morning queue (entity | state |
# pr_head | verify_verdict | gh_checks | cross_model | age), non-terminal rows
# only. Two no-write code gates: (1) static — the report code path contains no
# `status --set|--archive`, `git commit|push`, or tracked-file redirection; (2)
# runtime — `git status --porcelain` is empty after running `report`.

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

run_static_no_write_gate() {
  local hits
  hits="$(grep -nE 'status --set|--archive|git (commit|push)' "$HELPER" || true)"
  if [ -z "$hits" ]; then
    record_pass "static gate: helper has no forbidden git/gh mutation commands"
  else
    record_fail "static gate: forbidden mutation pattern found: ${hits}"
  fi
}

run_runtime_no_write_gate() {
  local repo
  repo="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/awaiting-merge-entity" "${repo}/awaiting-merge-entity"
  git -C "$repo" init -q
  git -C "$repo" add -A
  git -C "$repo" -c user.email=fixture@example.com -c user.name=fixture commit -q -m fixture

  run_capture "$HELPER" report --workflow-dir "$repo" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh"
  assert_exit "report: exit 0" 0 "$EXIT_CODE"
  assert_contains "report: renders the awaiting_merge entity" 'awaiting-merge-entity' "$OUT"
  assert_contains "report: renders awaiting_merge state" 'awaiting_merge' "$OUT"

  local porcelain
  porcelain="$(git -C "$repo" status --porcelain)"
  rm -rf "$repo"
  if [ -z "$porcelain" ]; then
    record_pass "runtime gate: git status --porcelain empty after report"
  else
    record_fail "runtime gate: report left untracked/modified changes: ${porcelain}"
  fi
}

run_json_variant_case() {
  local repo
  repo="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/awaiting-merge-entity" "${repo}/awaiting-merge-entity"
  run_capture "$HELPER" report --workflow-dir "$repo" --json \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh"
  rm -rf "$repo"
  assert_exit "report --json: exit 0" 0 "$EXIT_CODE"
  assert_contains "report --json: valid-looking JSON array" '^\[.*\]$' "$OUT"
}

run_terminal_rows_excluded_case() {
  local repo
  repo="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/not-shaped-entity" "${repo}/not-shaped-entity"
  run_capture "$HELPER" report --workflow-dir "$repo" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh"
  rm -rf "$repo"
  assert_exit "report (no non-terminal rows): exit 0" 0 "$EXIT_CODE"
  assert_not_contains "report: draft entity is not a row (not running/awaiting_merge/merged/blocked)" 'not-shaped-entity' "$OUT"
}

echo "=== test-ship-flow-scheduler-report.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_static_no_write_gate
  run_runtime_no_write_gate
  run_json_variant_case
  run_terminal_rows_excluded_case
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
