#!/usr/bin/env bash
# test-stale-worktree-cleanup-planner.sh - 114.3 read-only stale worktree cleanup planner contract
# HOST ARTIFACTS: docs/ship-flow/ entities, .claude/settings.json, or plugins/spacebridge/ — not present in standalone clone.
# Run only from the dogfood host project. See lib/__tests__/integration/README.md
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-stale-worktree-cleanup-planner.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${PLUGIN_ROOT}/../.." &> /dev/null && pwd)"
PLANNER="${PLUGIN_ROOT}/bin/stale-worktree-cleanup-planner.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/stale-worktree-cleanup-planner"
STATUS_BOOT_FIXTURE="${FIXTURE_ROOT}/status-boot.txt"

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

echo "=== test-stale-worktree-cleanup-planner.sh ==="
echo ""

FIXTURE_BEFORE="$(hash_tree "$FIXTURE_ROOT")"
WORKFLOW_BEFORE="$(hash_tree "${REPO_ROOT}/docs/ship-flow")"
BRANCHES_BEFORE="$(git -C "$REPO_ROOT" branch --list | shasum -a 256 | awk '{print $1}')"
WORKTREES_BEFORE="$(git -C "$REPO_ROOT" worktree list | shasum -a 256 | awk '{print $1}')"
WORKFLOW_FIXTURE_REPO="${TMP_DIR}/workflow-repo"

RC=0
"${PLANNER}" --status-boot "$STATUS_BOOT_FIXTURE" > "${TMP_DIR}/planner.out" 2>&1 || RC=$?

assert_exit "ambiguous branch safety exits non-zero" 1 "$RC"
assert_contains "safe stale row is cleanup candidate" '^CLEANUP_CANDIDATE entity=114\.1-workflow-doctor-sync-dry-run reason=entity-done-local-exists worktree="\.worktrees/ship-114\.1-workflow-doctor-sync-dry-run" branch="ship-114\.1-workflow-doctor-sync-dry-run"' "${TMP_DIR}/planner.out"
assert_contains "safe stale row prints dry-run worktree command" '^DRY_RUN entity=114\.1-workflow-doctor-sync-dry-run command="git worktree remove '\''\.worktrees/ship-114\.1-workflow-doctor-sync-dry-run'\''"' "${TMP_DIR}/planner.out"
assert_contains "safe stale row prints dry-run branch command" '^DRY_RUN entity=114\.1-workflow-doctor-sync-dry-run command="git branch -d '\''ship-114\.1-workflow-doctor-sync-dry-run'\''"' "${TMP_DIR}/planner.out"
assert_contains "missing local row is classified separately" '^MISSING_LOCAL entity=114\.0-old-planner reason=worktree-missing worktree="\.worktrees/ship-114\.0-old-planner" branch="ship-114\.0-old-planner"' "${TMP_DIR}/planner.out"
assert_contains "active execute row is kept" '^KEEP_ACTIVE entity=114\.3-stale-worktree-cleanup-planner reason=active-stage-local-exists worktree="\.worktrees/ship-114\.3-stale-worktree-cleanup-planner" branch="ship-114\.3-stale-worktree-cleanup-planner"' "${TMP_DIR}/planner.out"
assert_contains "PR-pending row is kept" '^KEEP_ACTIVE entity=113\.3-schema-designer-specialist reason=pr-pending worktree="\.worktrees/ship-113\.3-schema-designer-specialist" branch="ship-113\.3-schema-designer-specialist"' "${TMP_DIR}/planner.out"
assert_contains "ambiguous branch safety asks captain" '^NEEDS_CAPTAIN entity=112\.9-local-only-branch reason=branch-has-unmerged-commits worktree="\.worktrees/ship-112\.9-local-only-branch" branch="ship-112\.9-local-only-branch"' "${TMP_DIR}/planner.out"
assert_not_contains "planner never emits executable destructive command lines" '^(git worktree remove|git branch -d|git branch -D|git push --delete)' "${TMP_DIR}/planner.out"

git init -q "$WORKFLOW_FIXTURE_REPO"
git -C "$WORKFLOW_FIXTURE_REPO" config user.email t@t
git -C "$WORKFLOW_FIXTURE_REPO" config user.name t
echo "fixture" > "${WORKFLOW_FIXTURE_REPO}/README.md"
git -C "$WORKFLOW_FIXTURE_REPO" add README.md
git -C "$WORKFLOW_FIXTURE_REPO" commit -qm initial
mkdir -p "${WORKFLOW_FIXTURE_REPO}/docs/ship-flow/114.3-stale-worktree-cleanup-planner" "${WORKFLOW_FIXTURE_REPO}/.worktrees"
cat > "${WORKFLOW_FIXTURE_REPO}/docs/ship-flow/114.3-stale-worktree-cleanup-planner/index.md" <<'EOF'
---
id: "114.3"
status: execute
worktree: ".worktrees/ship-114.3-stale-worktree-cleanup-planner"
---

# 114.3 Stale Worktree Cleanup Planner
EOF
git -C "$WORKFLOW_FIXTURE_REPO" add docs/ship-flow/114.3-stale-worktree-cleanup-planner/index.md
git -C "$WORKFLOW_FIXTURE_REPO" commit -qm "add workflow fixture"
git -C "$WORKFLOW_FIXTURE_REPO" worktree add \
  "${WORKFLOW_FIXTURE_REPO}/.worktrees/ship-114.3-stale-worktree-cleanup-planner" \
  -b ship-114.3-stale-worktree-cleanup-planner >/dev/null 2>&1

RC=0
"${PLANNER}" --workflow-dir "${WORKFLOW_FIXTURE_REPO}/docs/ship-flow" > "${TMP_DIR}/workflow.out" 2>&1 || RC=$?
assert_contains "real workflow mode scans frontmatter worktree rows" '^KEEP_ACTIVE entity=114\.3-stale-worktree-cleanup-planner reason=nonterminal-status-local-exists worktree="\.worktrees/ship-114\.3-stale-worktree-cleanup-planner" branch="ship-114\.3-stale-worktree-cleanup-planner"' "${TMP_DIR}/workflow.out"
assert_not_contains "real workflow mode does not require normalized ORPHAN rows" 'Usage: stale-worktree-cleanup-planner\.sh --status-boot <file>' "${TMP_DIR}/workflow.out"
assert_not_contains "real workflow mode never emits executable destructive command lines" '^(git worktree remove|git branch -d|git branch -D|git push --delete)' "${TMP_DIR}/workflow.out"

FIXTURE_AFTER="$(hash_tree "$FIXTURE_ROOT")"
if [ "$FIXTURE_BEFORE" = "$FIXTURE_AFTER" ]; then
  record_pass "planner leaves status fixture unchanged"
else
  record_fail "planner leaves status fixture unchanged"
fi

WORKFLOW_AFTER="$(hash_tree "${REPO_ROOT}/docs/ship-flow")"
BRANCHES_AFTER="$(git -C "$REPO_ROOT" branch --list | shasum -a 256 | awk '{print $1}')"
WORKTREES_AFTER="$(git -C "$REPO_ROOT" worktree list | shasum -a 256 | awk '{print $1}')"
if [ "$WORKFLOW_BEFORE" = "$WORKFLOW_AFTER" ]; then
  record_pass "planner leaves workflow files unchanged"
else
  record_fail "planner leaves workflow files unchanged"
fi
if [ "$BRANCHES_BEFORE" = "$BRANCHES_AFTER" ]; then
  record_pass "planner leaves branches unchanged"
else
  record_fail "planner leaves branches unchanged"
fi
if [ "$WORKTREES_BEFORE" = "$WORKTREES_AFTER" ]; then
  record_pass "planner leaves git worktree list unchanged"
else
  record_fail "planner leaves git worktree list unchanged"
fi

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
