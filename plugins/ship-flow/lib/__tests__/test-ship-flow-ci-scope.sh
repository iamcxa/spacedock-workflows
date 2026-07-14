#!/usr/bin/env bash
# test-ship-flow-ci-scope.sh - ship-flow CI full-suite path scoping.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/ship-flow-invariants.yml"
DOC_WORKFLOW="${REPO_ROOT}/.github/workflows/ship-flow-doc-impact.yml"

PASS=0
FAIL=0
ERRORS=()
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

echo "=== test-ship-flow-ci-scope.sh ==="
echo ""

check "workflow triggers when ship-flow workflow changes" \
  "grep -q \"'.github/workflows/ship-flow-invariants.yml'\" '${WORKFLOW}'"

check "source invariant PRs retain their path filter" \
  "awk '/^  pull_request:/{in_pr=1; next} in_pr && /^jobs:/{in_pr=0} in_pr && /paths:/{found=1} END{exit !found}' '${WORKFLOW}'"

check "repo-local adopter map has a lightweight job outside plugin full-suite gating" \
  "test -f '${DOC_WORKFLOW}' && grep -q '^  doc_impact:' '${DOC_WORKFLOW}' && grep -qF '.claude/ship-flow/doc-coupling.yaml' '${DOC_WORKFLOW}' && ! grep -q '^  doc_impact:' '${WORKFLOW}'"

check "dedicated doc-impact workflow is broad while both workflows use read-only contents permissions" \
  "awk '/^  pull_request:/{in_pr=1; next} in_pr && /^jobs:/{in_pr=0} in_pr && /paths:/{bad=1} END{exit bad}' '${DOC_WORKFLOW}' && grep -A1 '^permissions:' '${WORKFLOW}' | grep -q 'contents: read' && grep -A1 '^permissions:' '${DOC_WORKFLOW}' | grep -q 'contents: read'"

check "workflow detects changed-file scope before full suite" \
  "grep -q 'id: ship_flow_scope' '${WORKFLOW}' && grep -q 'git diff --no-renames --name-only' '${WORKFLOW}'"

# The scope diff needs the PR base SHA and HEAD~1 — neither exists at depth 1,
# so every checkout step must fetch full history. Scoped awk (not bare grep):
# a commented-out `# fetch-depth: 0` or a mention outside a checkout step must
# NOT satisfy this assertion.
check "every checkout step fetches full history (fetch-depth: 0) for the scope diff" \
  "awk '/- uses: actions\\/checkout/{if (in_step && !has_fd) bad=1; in_step=1; has_fd=0; steps++; next} in_step && /^      - /{if (!has_fd) bad=1; in_step=0} in_step && /^[[:space:]]*fetch-depth:[[:space:]]*0([[:space:]]|$)/{has_fd=1} END{if (in_step && !has_fd) bad=1; exit !(steps >= 1 && !bad)}' '${WORKFLOW}'"

check "branch-creation push scope conservatively scans every tracked file" \
  "grep -qF -- 'CHANGED=\$(git ls-files)' '${WORKFLOW}'"

echo "Block 1.5: PR scope uses the merge base when the base branch advanced"
DIFF_REPO="${TMP_DIR}/diverged"
git init -q "$DIFF_REPO"
git -C "$DIFF_REPO" config user.email ci-scope@example.com
git -C "$DIFF_REPO" config user.name ci-scope-test
git -C "$DIFF_REPO" branch -M main
printf 'common\n' > "${DIFF_REPO}/README.md"
git -C "$DIFF_REPO" add README.md
git -C "$DIFF_REPO" commit -qm common
git -C "$DIFF_REPO" switch -qc pr
git -C "$DIFF_REPO" switch -q main
mkdir -p "${DIFF_REPO}/plugins/ship-flow"
printf 'base-only\n' > "${DIFF_REPO}/plugins/ship-flow/base-only.sh"
git -C "$DIFF_REPO" add plugins/ship-flow/base-only.sh
git -C "$DIFF_REPO" commit -qm base-advanced
BASE_SHA="$(git -C "$DIFF_REPO" rev-parse HEAD)"
git -C "$DIFF_REPO" switch -q pr
mkdir -p "${DIFF_REPO}/docs"
printf 'pr-only\n' > "${DIFF_REPO}/docs/pr-only.md"
git -C "$DIFF_REPO" add docs/pr-only.md
git -C "$DIFF_REPO" commit -qm pr-change

git -C "$DIFF_REPO" diff --name-only "$BASE_SHA" HEAD > "${TMP_DIR}/two-dot.txt"
git -C "$DIFF_REPO" diff --name-only "$BASE_SHA"...HEAD > "${TMP_DIR}/three-dot.txt"

check "two-dot reproduction includes the base-only plugin file" \
  "grep -qx 'plugins/ship-flow/base-only.sh' '${TMP_DIR}/two-dot.txt'"
check "merge-base diff includes only the PR-authored file" \
  "grep -qx 'docs/pr-only.md' '${TMP_DIR}/three-dot.txt' && ! grep -q 'base-only' '${TMP_DIR}/three-dot.txt'"
check "workflow computes changed scope from the merge base" \
  "grep -qF -- 'git diff --no-renames --name-only \"\$BASE\"...HEAD' '${WORKFLOW}'"

echo "Block 1.6: push scope compares the exact before/after trees"
COMMON_SHA="$(git -C "$DIFF_REPO" merge-base main pr)"
git -C "$DIFF_REPO" switch -q --detach "$COMMON_SHA"
git -C "$DIFF_REPO" switch -qc push-old
mkdir -p "${DIFF_REPO}/plugins/ship-flow"
printf 'removed by replacement push\n' > "${DIFF_REPO}/plugins/ship-flow/removed.sh"
git -C "$DIFF_REPO" add plugins/ship-flow/removed.sh
git -C "$DIFF_REPO" commit -qm push-old-plugin
PUSH_BEFORE_SHA="$(git -C "$DIFF_REPO" rev-parse HEAD)"
git -C "$DIFF_REPO" switch -q --detach "$COMMON_SHA"
git -C "$DIFF_REPO" switch -qc push-new
printf 'replacement push\n' >> "${DIFF_REPO}/README.md"
git -C "$DIFF_REPO" add README.md
git -C "$DIFF_REPO" commit -qm push-new-readme

git -C "$DIFF_REPO" diff --name-only "$PUSH_BEFORE_SHA" HEAD > "${TMP_DIR}/push-two-dot.txt"
git -C "$DIFF_REPO" diff --name-only "$PUSH_BEFORE_SHA"...HEAD > "${TMP_DIR}/push-three-dot.txt"

check "push two-dot reproduction includes the removed plugin file" \
  "grep -qx 'plugins/ship-flow/removed.sh' '${TMP_DIR}/push-two-dot.txt'"
check "push three-dot reproduction loses the removed plugin file" \
  "! grep -q 'removed.sh' '${TMP_DIR}/push-three-dot.txt'"
check "workflow uses merge-base diff only for pull requests" \
  "grep -qF -- 'if [ \"\$EVENT_NAME\" = \"pull_request\" ]; then' '${WORKFLOW}' && grep -qF -- 'git diff --no-renames --name-only \"\$BASE\"...HEAD' '${WORKFLOW}'"
check "workflow uses exact before-to-head diff for pushes" \
  "grep -qF -- 'git diff --no-renames --name-only \"\$BASE\" HEAD' '${WORKFLOW}'"
check "workflow fails closed when a nonzero event base is unavailable" \
  "grep -qF -- 'git cat-file -e \"\${BASE}^{commit}\"' '${WORKFLOW}' && grep -qF -- 'exit 1' '${WORKFLOW}'"

git -C "$DIFF_REPO" switch -q --detach "$COMMON_SHA"
git -C "$DIFF_REPO" switch -qc branch-create
mkdir -p "${DIFF_REPO}/plugins/ship-flow"
printf 'new plugin file\n' > "${DIFF_REPO}/plugins/ship-flow/new.sh"
git -C "$DIFF_REPO" add plugins/ship-flow/new.sh
git -C "$DIFF_REPO" commit -qm branch-create-plugin
printf 'later docs commit\n' >> "${DIFF_REPO}/README.md"
git -C "$DIFF_REPO" add README.md
git -C "$DIFF_REPO" commit -qm branch-create-readme
git -C "$DIFF_REPO" diff --name-only HEAD~1 HEAD > "${TMP_DIR}/branch-create-head-one.txt"
git -C "$DIFF_REPO" ls-files > "${TMP_DIR}/branch-create-all.txt"

check "HEAD~1 reproduction misses an earlier branch-creation plugin change" \
  "! grep -q 'plugins/ship-flow/new.sh' '${TMP_DIR}/branch-create-head-one.txt'"
check "conservative branch-creation scan includes the plugin file" \
  "grep -qx 'plugins/ship-flow/new.sh' '${TMP_DIR}/branch-create-all.txt'"

check "event-specific diffs preserve rename sources without a HEAD~1 or silent fallback" \
  "test \"\$(awk '/id: ship_flow_scope/{in_scope=1} in_scope && /PLUGIN_CHANGED=false/{in_scope=0} in_scope{print}' '${WORKFLOW}' | grep -oF 'git diff --no-renames --name-only' | wc -l | tr -d ' ')\" -eq 2 && ! grep -qF 'CHANGED=\$(git diff --no-renames --name-only HEAD~1' '${WORKFLOW}' && ! grep -qF '2>/dev/null || git diff' '${WORKFLOW}'"

check "full suite is limited to plugin or workflow changes" \
  "awk '/Run full ship-flow shell test suite/{in_step=1} in_step && /^      - name: / && !/Run full ship-flow shell test suite/{in_step=0} in_step && /if: steps\\.ship_flow_scope\\.outputs\\.full_suite == '\\''true'\\''/{found=1} END{exit !found}' '${WORKFLOW}'"

check "docs-only PRs keep lightweight gate without full suite" \
  "grep -q 'docs_only_lightweight=true' '${WORKFLOW}' && grep -q 'full_suite=false' '${WORKFLOW}'"

check "doc-impact gate is centralized in the lightweight job and reads PR body via env indirection" \
  "grep -qF 'name: Run doc-impact contribution gate' '${DOC_WORKFLOW}' && grep -qF \"if: steps.doc_impact_scope.outputs.gate_required == 'true'\" '${DOC_WORKFLOW}' && grep -qF 'PR_BODY: \${{ github.event.pull_request.body }}' '${DOC_WORKFLOW}'"

check "doc-impact resolves one merge base for changed paths and base-map tree lookups" \
  "grep -q 'MERGE_BASE=.*git merge-base.*PR_BASE_SHA.*HEAD' '${DOC_WORKFLOW}' && grep -q 'git diff --no-renames --name-only.*MERGE_BASE.*\.\.\.HEAD' '${DOC_WORKFLOW}' && test \"\$(grep -o '\${MERGE_BASE}:' '${DOC_WORKFLOW}' | wc -l | tr -d ' ')\" -ge 2"

# codex-gate P1-1: on push(main) the declaration source (PR body) is
# structurally absent, so the step must not evaluate on push events at all —
# scoped to the doc-impact-gate step's own `if:` line, not any other step.
check "doc-impact job does not evaluate on push events where PR declaration is absent" \
  "awk '/^  doc_impact:/{in_job=1; next} in_job && /^    if:/{line=\$0; found=1} END{exit !(found && line ~ /event_name/ && line ~ /pull_request/)}' '${DOC_WORKFLOW}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
