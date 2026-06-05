#!/usr/bin/env bash
# test-pr-merge-fo-receipts.sh - pr-merge FO receipt writer contract.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." >/dev/null 2>&1 && pwd)"
PR_MERGE_MOD="${REPO_ROOT}/docs/ship-flow/_mods/pr-merge.md"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

line_no() {
  local pattern="$1"
  awk -v pattern="$pattern" 'index($0, pattern) { print NR; exit }' "$PR_MERGE_MOD"
}

echo "=== test-pr-merge-fo-receipts.sh ==="
echo ""

check "pr-merge version remains 0.11.6" \
  "grep -q '^version: 0.11.6$' '${PR_MERGE_MOD}'"

check "merge hook names the shared FO receipt helper" \
  "awk '/^## Hook: merge/{in_hook=1} /^## Hook:/{if(in_hook && \$0 !~ /^## Hook: merge/) in_hook=0} in_hook && /plugins\\/ship-flow\\/lib\\/write-fo-receipt.sh/{found=1} END{exit found ? 0 : 1}' '${PR_MERGE_MOD}'"

PRECONDITION_LINE="$(line_no 'no open VETO, BLOCKING, or unresolved execute/verify feedback')"
PRIVACY_LINE="$(line_no 'passed the privacy pre-flight check')"
HELPER_LINE="$(line_no 'plugins/ship-flow/lib/write-fo-receipt.sh')"
PUSH_LINE="$(line_no 'git push origin {branch}')"
GH_CREATE_LINE="$(line_no 'gh pr create --base main')"

check "receipt helper appears after v0.11.4 preconditions" \
  "[ -n '${PRECONDITION_LINE}' ] && [ -n '${HELPER_LINE}' ] && [ '${HELPER_LINE:-0}' -gt '${PRECONDITION_LINE:-0}' ]"

check "receipt helper appears after privacy pre-flight requirement" \
  "[ -n '${PRIVACY_LINE}' ] && [ -n '${HELPER_LINE}' ] && [ '${HELPER_LINE:-0}' -gt '${PRIVACY_LINE:-0}' ]"

check "receipt helper appears before git push side effect" \
  "[ -n '${HELPER_LINE}' ] && [ -n '${PUSH_LINE}' ] && [ '${HELPER_LINE:-99999}' -lt '${PUSH_LINE:-0}' ]"

check "receipt helper appears before gh pr create side effect" \
  "[ -n '${HELPER_LINE}' ] && [ -n '${GH_CREATE_LINE}' ] && [ '${HELPER_LINE:-99999}' -lt '${GH_CREATE_LINE:-0}' ]"

check "PR receipt example records review-to-pr transition trigger" \
  "grep -q 'from: review' '${PR_MERGE_MOD}' && grep -q 'to: pr' '${PR_MERGE_MOD}' && grep -q 'trigger: pr-creation-autonomy' '${PR_MERGE_MOD}'"

check "PR receipt example records self-approved PR_READY rule source" \
  "grep -q 'decision: self-approved' '${PR_MERGE_MOD}' && grep -q 'verdict: PR_READY' '${PR_MERGE_MOD}' && grep -q 'rule_source: docs/ship-flow/_mods/pr-merge.md v0.11.4' '${PR_MERGE_MOD}'"

check "negative PR routes stay captain or review gated" \
  "grep -qi 'missing.*ambiguous' '${PR_MERGE_MOD}' && grep -qi 'dirty' '${PR_MERGE_MOD}' && grep -qi 'stale.*branch\\|branch.*current' '${PR_MERGE_MOD}' && grep -qi 'privacy pre-flight' '${PR_MERGE_MOD}' && grep -qi 'unresolved.*feedback' '${PR_MERGE_MOD}' && grep -qi 'merge approval' '${PR_MERGE_MOD}' && grep -qi 'auto-merge' '${PR_MERGE_MOD}' && grep -qi 'captain\\|review-gated' '${PR_MERGE_MOD}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
