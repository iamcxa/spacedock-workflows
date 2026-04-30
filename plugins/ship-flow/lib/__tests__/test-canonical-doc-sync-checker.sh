#!/usr/bin/env bash
# test-canonical-doc-sync-checker.sh — read-only canonical docs closeout checker
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-canonical-doc-sync-checker.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
CHECKER="${PLUGIN_ROOT}/bin/canonical-doc-sync-checker.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/canonical-doc-sync-checker"

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

run_checker() {
  local fixture="$1"
  local output_file="$2"
  local exit_file="$3"
  local rc=0
  "${CHECKER}" "${FIXTURE_ROOT}/${fixture}" > "${output_file}" 2>&1 || rc=$?
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

echo "=== test-canonical-doc-sync-checker.sh ==="
echo ""

echo "Block 1: complete review output passes"
COMPLETE_BEFORE="$(hash_dir "${FIXTURE_ROOT}/complete")"
run_checker "complete" "${TMP_DIR}/complete.out" "${TMP_DIR}/complete.exit"
assert_exit "complete exits 0" 0 "${TMP_DIR}/complete.exit"
assert_contains "complete emits PASS for ARCHITECTURE.md" '^PASS ARCHITECTURE\.md' "${TMP_DIR}/complete.out"
assert_contains "complete emits PASS for PRODUCT.md" '^PASS PRODUCT\.md' "${TMP_DIR}/complete.out"
assert_contains "complete emits PASS for ROADMAP.md" '^PASS ROADMAP\.md' "${TMP_DIR}/complete.out"
assert_not_contains "complete emits no blockers" '^BLOCKER ' "${TMP_DIR}/complete.out"
assert_read_only "complete fixture remains unchanged" "complete" "$COMPLETE_BEFORE"

echo ""
echo "Block 2: missing canonical section blocks"
MISSING_SECTION_BEFORE="$(hash_dir "${FIXTURE_ROOT}/missing-section")"
run_checker "missing-section" "${TMP_DIR}/missing-section.out" "${TMP_DIR}/missing-section.exit"
assert_exit "missing section exits 1" 1 "${TMP_DIR}/missing-section.exit"
assert_contains "missing section reports BLOCKER" '^BLOCKER canonical-docs-section: missing ## Canonical Docs Update' "${TMP_DIR}/missing-section.out"
assert_read_only "missing section fixture remains unchanged" "missing-section" "$MISSING_SECTION_BEFORE"

echo ""
echo "Block 3: missing required doc line blocks"
MISSING_DOC_BEFORE="$(hash_dir "${FIXTURE_ROOT}/missing-required-doc")"
run_checker "missing-required-doc" "${TMP_DIR}/missing-doc.out" "${TMP_DIR}/missing-doc.exit"
assert_exit "missing required doc exits 1" 1 "${TMP_DIR}/missing-doc.exit"
assert_contains "missing required doc reports ROADMAP blocker" '^BLOCKER ROADMAP\.md: missing canonical docs outcome' "${TMP_DIR}/missing-doc.out"
assert_read_only "missing required doc fixture remains unchanged" "missing-required-doc" "$MISSING_DOC_BEFORE"

echo ""
echo "Block 4: weak skip rationale is recommended, not blocking"
WEAK_SKIP_BEFORE="$(hash_dir "${FIXTURE_ROOT}/weak-skip-rationale")"
run_checker "weak-skip-rationale" "${TMP_DIR}/weak-skip.out" "${TMP_DIR}/weak-skip.exit"
assert_exit "weak skip exits 0" 0 "${TMP_DIR}/weak-skip.exit"
assert_contains "weak skip reports RECOMMENDED" '^RECOMMENDED PRODUCT\.md: weak skip rationale' "${TMP_DIR}/weak-skip.out"
assert_not_contains "weak skip emits no PRODUCT blocker" '^BLOCKER PRODUCT\.md' "${TMP_DIR}/weak-skip.out"
assert_read_only "weak skip fixture remains unchanged" "weak-skip-rationale" "$WEAK_SKIP_BEFORE"

echo ""
echo "Block 5: shaped child requires umbrella closeout outcome"
SHAPED_CHILD_BEFORE="$(hash_dir "${FIXTURE_ROOT}/shaped-child-missing-umbrella")"
run_checker "shaped-child-missing-umbrella" "${TMP_DIR}/shaped-child.out" "${TMP_DIR}/shaped-child.exit"
assert_exit "shaped child missing umbrella exits 1" 1 "${TMP_DIR}/shaped-child.exit"
assert_contains "shaped child reports umbrella blocker" '^BLOCKER umbrella-closeout: missing Umbrella closeout outcome' "${TMP_DIR}/shaped-child.out"
assert_read_only "shaped child fixture remains unchanged" "shaped-child-missing-umbrella" "$SHAPED_CHILD_BEFORE"

echo ""
echo "Block 6: umbrella entity requires umbrella closeout outcome"
UMBRELLA_BEFORE="$(hash_dir "${FIXTURE_ROOT}/umbrella-missing-closeout")"
run_checker "umbrella-missing-closeout" "${TMP_DIR}/umbrella.out" "${TMP_DIR}/umbrella.exit"
assert_exit "umbrella missing closeout exits 1" 1 "${TMP_DIR}/umbrella.exit"
assert_contains "umbrella reports closeout blocker" '^BLOCKER umbrella-closeout: missing Umbrella closeout outcome' "${TMP_DIR}/umbrella.out"
assert_read_only "umbrella fixture remains unchanged" "umbrella-missing-closeout" "$UMBRELLA_BEFORE"

echo ""
echo "Block 7: internal utility skips are accepted when specific"
INTERNAL_BEFORE="$(hash_dir "${FIXTURE_ROOT}/internal-utility-skip")"
run_checker "internal-utility-skip" "${TMP_DIR}/internal.out" "${TMP_DIR}/internal.exit"
assert_exit "internal utility exits 0" 0 "${TMP_DIR}/internal.exit"
assert_contains "internal utility emits PASS for specific ARCHITECTURE skip" '^PASS ARCHITECTURE\.md' "${TMP_DIR}/internal.out"
assert_not_contains "internal utility emits no recommended findings" '^RECOMMENDED ' "${TMP_DIR}/internal.out"
assert_not_contains "internal utility emits no blockers" '^BLOCKER ' "${TMP_DIR}/internal.out"
assert_read_only "internal utility fixture remains unchanged" "internal-utility-skip" "$INTERNAL_BEFORE"

echo ""
echo "Block 8: write modes are intentionally unavailable"
"${CHECKER}" --fix "${FIXTURE_ROOT}/complete" > "${TMP_DIR}/fix.out" 2>&1 && FIX_RC=0 || FIX_RC=$?
printf '%s\n' "$FIX_RC" > "${TMP_DIR}/fix.exit"
assert_exit "--fix exits 2" 2 "${TMP_DIR}/fix.exit"
assert_contains "--fix explains dry-run only" 'read-only|dry-run|No write mode' "${TMP_DIR}/fix.out"
assert_read_only "--fix leaves fixture unchanged" "complete" "$COMPLETE_BEFORE"

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
