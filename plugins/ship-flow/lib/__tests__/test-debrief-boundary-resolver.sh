#!/usr/bin/env bash
# test-debrief-boundary-resolver.sh — 114.2 read-only debrief boundary resolver contract
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-debrief-boundary-resolver.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${PLUGIN_ROOT}/../.." &> /dev/null && pwd)"
RESOLVER="${PLUGIN_ROOT}/bin/debrief-boundary-resolver.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/debrief-boundary-resolver"

PASS=0
FAIL=0
ERRORS=()

hash_tree() {
  local path="$1"
  find "$path" -type f -print | sort | while IFS= read -r file; do
    shasum -a 256 "$file"
  done | shasum -a 256 | awk '{print $1}'
}

record_pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

record_fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

assert_exit() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected exit ${expected}, got ${actual})"
  fi
}

assert_contains() {
  local desc="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "$pattern" "$file"; then
    record_pass "$desc"
  else
    record_fail "$desc (missing pattern: ${pattern})"
  fi
}

assert_not_contains() {
  local desc="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "$pattern" "$file"; then
    record_fail "$desc (unexpected pattern: ${pattern})"
  else
    record_pass "$desc"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

WORKFLOW_COPY="${TMP_DIR}/workflow"
cp -R "${FIXTURE_ROOT}/workflow" "$WORKFLOW_COPY"
DRAFT_COPY="${TMP_DIR}/draft.md"
cp "${FIXTURE_ROOT}/drafts/mixed-session.md" "$DRAFT_COPY"

WORKFLOW_BEFORE="$(hash_tree "$WORKFLOW_COPY")"
DRAFT_BEFORE="$(shasum -a 256 "$DRAFT_COPY" | awk '{print $1}')"

echo "=== test-debrief-boundary-resolver.sh ==="
echo ""

RC=0
"${RESOLVER}" "$WORKFLOW_COPY" "$DRAFT_COPY" > "${TMP_DIR}/mixed.out" 2>&1 || RC=$?
assert_exit "mixed fixture exits 0" 0 "$RC"
assert_contains "local note stays in debrief" '^DEBRIEF_ONLY line=1 reason=local-note text="Remember that ship-flow execute evidence should include exact command names\."' "${TMP_DIR}/mixed.out"
assert_contains "follow-up candidate routes to entity" '^FOLLOW_UP_ENTITY line=2 reason=follow-up-keyword text="Follow up: add stale worktree cleanup planner after the resolver dogfood\."' "${TMP_DIR}/mixed.out"
assert_contains "existing entity match points at slug" '^EXISTING_ENTITY line=3 reason=existing-entity-match slug=114\.1-workflow-doctor-sync-dry-run text="Workflow doctor dry-run already covers read-only sync drift checks\."' "${TMP_DIR}/mixed.out"
assert_contains "spacedock issue candidate routes to issue" '^SPACEDOCK_ISSUE line=4 reason=spacedock-framework-issue text="Spacedock plugin bug: ensign runtime loses packaged skill lookup context\."' "${TMP_DIR}/mixed.out"
assert_not_contains "successful run does not ask for captain input" '^AMBIGUOUS ' "${TMP_DIR}/mixed.out"

WORKFLOW_AFTER="$(hash_tree "$WORKFLOW_COPY")"
DRAFT_AFTER="$(shasum -a 256 "$DRAFT_COPY" | awk '{print $1}')"
if [ "$WORKFLOW_BEFORE" = "$WORKFLOW_AFTER" ] && [ "$DRAFT_BEFORE" = "$DRAFT_AFTER" ]; then
  record_pass "resolver leaves workflow and draft unchanged"
else
  record_fail "resolver leaves workflow and draft unchanged"
fi

RC=0
"${RESOLVER}" "$WORKFLOW_COPY" "${FIXTURE_ROOT}/drafts/ambiguous-session.md" > "${TMP_DIR}/ambiguous.out" 2>&1 || RC=$?
assert_exit "ambiguous fixture exits 1" 1 "$RC"
assert_contains "ambiguous output requests captain input" '^AMBIGUOUS line=1 reason=captain-input-required candidates=FOLLOW_UP_ENTITY,SPACEDOCK_ISSUE text="Need to fix Spacedock follow-up routing later\."' "${TMP_DIR}/ambiguous.out"

RC=0
"${RESOLVER}" "${REPO_ROOT}/docs/ship-flow" "$DRAFT_COPY" > "${TMP_DIR}/real-workflow.out" 2>&1 || RC=$?
assert_exit "real workflow mixed fixture exits 0" 0 "$RC"
assert_contains "real workflow local note does not false-match existing entity" '^DEBRIEF_ONLY line=1 reason=local-note text="Remember that ship-flow execute evidence should include exact command names\."' "${TMP_DIR}/real-workflow.out"
assert_contains "real workflow explicit coverage still matches existing entity" '^EXISTING_ENTITY line=3 reason=existing-entity-match slug=114\.1-workflow-doctor-sync-dry-run text="Workflow doctor dry-run already covers read-only sync drift checks\."' "${TMP_DIR}/real-workflow.out"
assert_not_contains "real workflow avoids broad stage-wiring false positive" '^EXISTING_ENTITY line=1 reason=existing-entity-match slug=099-ship-flow-stage-wiring' "${TMP_DIR}/real-workflow.out"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
exit 0
