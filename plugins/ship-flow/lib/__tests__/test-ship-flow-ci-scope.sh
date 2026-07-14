#!/usr/bin/env bash
# test-ship-flow-ci-scope.sh - ship-flow CI full-suite path scoping.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/ship-flow-invariants.yml"

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

check "workflow detects changed-file scope before full suite" \
  "grep -q 'id: ship_flow_scope' '${WORKFLOW}' && grep -q 'git diff --name-only' '${WORKFLOW}'"

# The scope diff needs the PR base SHA and HEAD~1 — neither exists at depth 1,
# so every checkout step must fetch full history. Scoped awk (not bare grep):
# a commented-out `# fetch-depth: 0` or a mention outside a checkout step must
# NOT satisfy this assertion.
check "every checkout step fetches full history (fetch-depth: 0) for the scope diff" \
  "awk '/- uses: actions\\/checkout/{if (in_step && !has_fd) bad=1; in_step=1; has_fd=0; steps++; next} in_step && /^      - /{if (!has_fd) bad=1; in_step=0} in_step && /^[[:space:]]*fetch-depth:[[:space:]]*0([[:space:]]|$)/{has_fd=1} END{if (in_step && !has_fd) bad=1; exit !(steps >= 1 && !bad)}' '${WORKFLOW}'"

check "scope diff keeps a HEAD~1 fallback for unusable base SHAs" \
  "grep -qF -- 'git diff --name-only HEAD~1 HEAD' '${WORKFLOW}'"

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
  "grep -qF -- 'git diff --name-only \"\$BASE\"...HEAD' '${WORKFLOW}'"

check "full suite is limited to plugin or workflow changes" \
  "awk '/Run full ship-flow shell test suite/{in_step=1} in_step && /^      - name: / && !/Run full ship-flow shell test suite/{in_step=0} in_step && /if: steps\\.ship_flow_scope\\.outputs\\.full_suite == '\\''true'\\''/{found=1} END{exit !found}' '${WORKFLOW}'"

check "docs-only PRs keep lightweight gate without full suite" \
  "grep -q 'docs_only_lightweight=true' '${WORKFLOW}' && grep -q 'full_suite=false' '${WORKFLOW}'"

check "doc-impact-gate step gated on plugin_changed, reads PR body via env indirection (no direct interpolation)" \
  "grep -qF 'name: doc-impact-gate' '${WORKFLOW}' && grep -qF \"if: steps.ship_flow_scope.outputs.plugin_changed == 'true'\" '${WORKFLOW}' && grep -qF 'PR_BODY: \${{ github.event.pull_request.body }}' '${WORKFLOW}'"

# codex-gate P1-1: on push(main) the declaration source (PR body) is
# structurally absent, so the step must not evaluate on push events at all —
# scoped to the doc-impact-gate step's own `if:` line, not any other step.
check "doc-impact-gate step does not evaluate on push events (PR body is structurally absent there)" \
  "awk '/^      - name: doc-impact-gate/{in_step=1; next} in_step && /^      - name: /{in_step=0} in_step && /^        if:/{line=\$0} END{exit !(line ~ /event_name/ && line ~ /pull_request/)}' '${WORKFLOW}'"

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
