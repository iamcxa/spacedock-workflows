#!/usr/bin/env bash
# integration/test-check-pr-mergeable-dogfood.sh
#
# Host artifacts needed:
#   docs/ship-flow/_mods/pr-merge.md — adopted workflow pr-merge mod (v0.11.6+)
#
# Why not standalone: pr-merge.md only exists in the adopted host project.
# Runs the case_docs function from test-check-pr-mergeable.sh with the live mod.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../../.." &> /dev/null && pwd)"
PR_MERGE_DOC="${REPO_ROOT}/docs/ship-flow/_mods/pr-merge.md"

PASS=0; FAIL=0; ERRORS=()

record_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
record_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

assert_contains() {
  local name="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then record_pass "$name"
  else record_fail "$name (missing pattern: $pattern)"; fi
}
assert_not_contains() {
  local name="$1" pattern="$2" file="$3"
  if ! grep -qE "$pattern" "$file"; then record_pass "$name"
  else record_fail "$name (unexpected pattern: $pattern)"; fi
}

echo "=== integration: check-pr-mergeable docs ==="

assert_contains "pr-merge doc names helper" 'check-pr-mergeable\.sh' "$PR_MERGE_DOC"
assert_contains "pr-merge doc calls itself policy mirror" 'policy mirror' "$PR_MERGE_DOC"
assert_contains "pr-merge doc includes clean mapping" "0[[:space:]]*\\|[[:space:]]*\`?clean\`?" "$PR_MERGE_DOC"
assert_contains "pr-merge doc includes conflicting mapping" "10[[:space:]]*\\|[[:space:]]*\`?conflicting\`?" "$PR_MERGE_DOC"
assert_contains "pr-merge doc includes dirty mapping" "11[[:space:]]*\\|[[:space:]]*\`?dirty\`?" "$PR_MERGE_DOC"
assert_contains "pr-merge doc includes unknown mapping" "12[[:space:]]*\\|[[:space:]]*\`?unknown\`?" "$PR_MERGE_DOC"
assert_contains "pr-merge doc includes timeout mapping" "20[[:space:]]*\\|[[:space:]]*\`?timeout\`?" "$PR_MERGE_DOC"
assert_contains "pr-merge doc includes gh-failure mapping" "30[[:space:]]*\\|[[:space:]]*\`?gh-failure\`?" "$PR_MERGE_DOC"
assert_contains "pr-merge doc includes usage mapping" "2[[:space:]]*\\|[[:space:]]*\`?usage-error\`?" "$PR_MERGE_DOC"
assert_not_contains "pr-merge doc does not add a GitLab helper path" 'check-pr-mergeable\.sh.*glab|glab.*check-pr-mergeable\.sh|GitLab mergeability helper' "$PR_MERGE_DOC"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -ne 0 ]; then
  printf ' - %s\n' "${ERRORS[@]}"
  exit 1
fi
echo "All assertions passed"
