#!/usr/bin/env bash
# test-workflow-doctor.sh — 114.1 read-only workflow doctor dry-run contract
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-workflow-doctor.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
DOCTOR="${PLUGIN_ROOT}/bin/workflow-doctor.sh"
TEMPLATE="${PLUGIN_ROOT}/workflow-template.yaml"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/workflow-doctor"

PASS=0
FAIL=0
ERRORS=()

hash_dir() {
  local dir="$1"
  find "$dir" -type f -print | sort | while IFS= read -r file; do
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

run_doctor() {
  local fixture="$1"
  local output_file="$2"
  local exit_file="$3"
  local rc=0
  "${DOCTOR}" "${FIXTURE_ROOT}/${fixture}" > "${output_file}" 2>&1 || rc=$?
  printf '%s\n' "$rc" > "${exit_file}"
}

assert_exit() {
  local desc="$1"
  local expected="$2"
  local exit_file="$3"
  local actual
  actual="$(cat "$exit_file")"
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

assert_read_only() {
  local desc="$1"
  local fixture="$2"
  local before="$3"
  local after
  after="$(hash_dir "${FIXTURE_ROOT}/${fixture}")"
  if [ "$before" = "$after" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (fixture hash changed)"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== test-workflow-doctor.sh ==="
echo ""

echo "Block 1: shipped template starts adopters on current workflow semantics"
if grep -qE '^id-style:[[:space:]]*slug[[:space:]]*$' "$TEMPLATE"; then
  record_pass "workflow-template.yaml declares id-style slug"
else
  record_fail "workflow-template.yaml declares id-style slug"
fi
if awk '
  /^[[:space:]]*-[[:space:]]*name:[[:space:]]*design[[:space:]]*$/ { in_design = 1; next }
  in_design && /^[[:space:]]*-[[:space:]]*name:[[:space:]]*/ { exit }
  in_design && /^[[:space:]]*skip-when:[[:space:]]*/ { found = 1; exit }
  END { exit found }
' "$TEMPLATE"; then
  record_pass "workflow-template.yaml has no skip-when (W3 — design always runs)"
else
  record_fail "workflow-template.yaml has no skip-when (W3 — design always runs)"
fi

echo ""
echo "Block 2: healthy current workflow is non-blocking and read-only"
HEALTHY_BEFORE="$(hash_dir "${FIXTURE_ROOT}/healthy-current")"
run_doctor "healthy-current" "${TMP_DIR}/healthy.out" "${TMP_DIR}/healthy.exit"
assert_exit "healthy current exits 0" 0 "${TMP_DIR}/healthy.exit"
assert_not_contains "healthy current emits no BLOCKER findings" '^BLOCKER ' "${TMP_DIR}/healthy.out"
assert_not_contains "healthy current does not report stale shipped-template drift" '^RECOMMENDED workflow-template\.yaml' "${TMP_DIR}/healthy.out"
assert_contains "healthy current reports missing parallelism contract as sync recommendation" '^RECOMMENDED README\.parallelism-contract' "${TMP_DIR}/healthy.out"
assert_contains "healthy current reports missing reviewer panel handoff as sync recommendation" '^RECOMMENDED README\.verify-reviewer-panel' "${TMP_DIR}/healthy.out"
assert_contains "healthy current reports missing manifest artifacts as sync recommendation" '^RECOMMENDED README\.manifest-artifacts' "${TMP_DIR}/healthy.out"
assert_read_only "healthy current fixture remains unchanged" "healthy-current" "$HEALTHY_BEFORE"

echo ""
echo "Block 3: stale pre-113 workflow reports blockers and exits non-zero"
STALE_BEFORE="$(hash_dir "${FIXTURE_ROOT}/stale-pre-113")"
run_doctor "stale-pre-113" "${TMP_DIR}/stale.out" "${TMP_DIR}/stale.exit"
assert_exit "stale pre-113 exits 1" 1 "${TMP_DIR}/stale.exit"
assert_contains "stale pre-113 reports BLOCKER id-style" '^BLOCKER id-style' "${TMP_DIR}/stale.out"
assert_contains "stale pre-113 reports BLOCKER design.skip-when" '^BLOCKER design\.skip-when' "${TMP_DIR}/stale.out"
assert_read_only "stale pre-113 fixture remains unchanged" "stale-pre-113" "$STALE_BEFORE"

echo ""
echo "Block 4: project-local README content is preserved as non-blocking"
LOCAL_BEFORE="$(hash_dir "${FIXTURE_ROOT}/project-local-readme")"
run_doctor "project-local-readme" "${TMP_DIR}/project-local.out" "${TMP_DIR}/project-local.exit"
assert_exit "project-local README exits 0" 0 "${TMP_DIR}/project-local.exit"
assert_contains "project-local README reports PROJECT_LOCAL" '^PROJECT_LOCAL README' "${TMP_DIR}/project-local.out"
assert_not_contains "project-local README emits no BLOCKER findings" '^BLOCKER ' "${TMP_DIR}/project-local.out"
assert_read_only "project-local README fixture remains unchanged" "project-local-readme" "$LOCAL_BEFORE"

echo ""
echo "Block 5: synced README does not emit SOT drift recommendations"
SYNCED_BEFORE="$(hash_dir "${FIXTURE_ROOT}/synced-current")"
run_doctor "synced-current" "${TMP_DIR}/synced.out" "${TMP_DIR}/synced.exit"
assert_exit "synced current exits 0" 0 "${TMP_DIR}/synced.exit"
assert_not_contains "synced current emits no README parallelism recommendation" '^RECOMMENDED README\.parallelism-contract' "${TMP_DIR}/synced.out"
assert_not_contains "synced current emits no README reviewer panel recommendation" '^RECOMMENDED README\.verify-reviewer-panel' "${TMP_DIR}/synced.out"
assert_not_contains "synced current emits no README manifest recommendation" '^RECOMMENDED README\.manifest-artifacts' "${TMP_DIR}/synced.out"
assert_read_only "synced current fixture remains unchanged" "synced-current" "$SYNCED_BEFORE"

echo ""
echo "Block 6: write modes are intentionally unavailable"
WRITE_BEFORE="$(hash_dir "${FIXTURE_ROOT}/healthy-current")"
"${DOCTOR}" --fix "${FIXTURE_ROOT}/healthy-current" > "${TMP_DIR}/fix.out" 2>&1 && FIX_RC=0 || FIX_RC=$?
printf '%s\n' "$FIX_RC" > "${TMP_DIR}/fix.exit"
assert_exit "--fix exits 2" 2 "${TMP_DIR}/fix.exit"
assert_contains "--fix explains there is no write mode" 'read-only|No auto-fix|write mode' "${TMP_DIR}/fix.out"
assert_read_only "--fix leaves fixture unchanged" "healthy-current" "$WRITE_BEFORE"

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
