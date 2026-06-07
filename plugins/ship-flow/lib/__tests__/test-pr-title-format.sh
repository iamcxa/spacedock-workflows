#!/usr/bin/env bash
# test-pr-title-format.sh - PR title validator and pr-merge preflight contract.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." >/dev/null 2>&1 && pwd)"
VALIDATOR="${REPO_ROOT}/plugins/ship-flow/bin/validate-pr-title.sh"
RULE_LIB="${REPO_ROOT}/plugins/ship-flow/lib/pr-title-format.sh"
PR_MERGE_MOD="${REPO_ROOT}/docs/ship-flow/_mods/pr-merge.md"
WORKFLOW="${REPO_ROOT}/.github/workflows/pr-title-format.yml"

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

echo "=== test-pr-title-format.sh ==="
echo ""

check "shared PR title regex source exists" \
  "[ -f '${RULE_LIB}' ] && grep -q '^PR_TITLE_REGEX=' '${RULE_LIB}'"

check "positive conventional ship-flow title passes" \
  "'${VALIDATOR}' 'fix(ship-flow): repair merged PR closeout runtime'"

check "proper noun subject starts with uppercase and passes" \
  "'${VALIDATOR}' 'fix(ci): GitHub Actions workflow fails'"

check "acronym subject starts with uppercase and passes" \
  "'${VALIDATOR}' 'feat(auth): OAuth2 device code flow'"

check "type without required scope fails" \
  "! '${VALIDATOR}' 'fix: GitHub Actions workflow fails'"

check "sentence-case non-conventional title fails" \
  "! '${VALIDATOR}' 'Merged PR closeout reconciler runtime fix'"

check "type outside documented allowlist fails" \
  "! '${VALIDATOR}' 'style(ship-flow): adjust markdown formatting'"

check "validator reports expected format on failure" \
  "'${VALIDATOR}' 'Merged PR closeout reconciler runtime fix' 2>&1 | grep -q 'type(scope): subject'"

check "GitHub workflow validates pull request title through shared helper" \
  "[ -f '${WORKFLOW}' ] && grep -q 'pull_request:' '${WORKFLOW}' && grep -q 'plugins/ship-flow/bin/validate-pr-title.sh' '${WORKFLOW}' && grep -q 'github.event.pull_request.title' '${WORKFLOW}'"

PREFLIGHT_LINE="$(line_no 'plugins/ship-flow/bin/validate-pr-title.sh')"
GH_CREATE_LINE="$(line_no 'gh pr create --base main')"

check "pr-merge preflight calls shared title validator before gh pr create" \
  "[ -n '${PREFLIGHT_LINE}' ] && [ -n '${GH_CREATE_LINE}' ] && [ '${PREFLIGHT_LINE:-99999}' -lt '${GH_CREATE_LINE:-0}' ]"

check "pr-merge documents PR and commit subjects as one Conventional Commits contract" \
  "grep -q 'PR title MUST use Conventional Commits' '${PR_MERGE_MOD}' && grep -q 'worktree head commit subject MUST use the same Conventional Commits format' '${PR_MERGE_MOD}' && grep -q 'squash commit subject MUST use the same Conventional Commits format' '${PR_MERGE_MOD}'"

check "pr-merge documents type allowlist and kebab-case scope guidance" \
  "grep -q 'feat|fix|docs|test|refactor|perf|build|ci|chore|revert' '${PR_MERGE_MOD}' && grep -q 'scope SHOULD be kebab-case' '${PR_MERGE_MOD}' && grep -q 'ai-review' '${PR_MERGE_MOD}' && grep -q 'ship-flow' '${PR_MERGE_MOD}' && grep -q 'daemon' '${PR_MERGE_MOD}'"

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
