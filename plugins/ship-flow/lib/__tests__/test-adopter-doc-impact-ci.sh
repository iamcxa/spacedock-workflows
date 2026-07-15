#!/usr/bin/env bash
# test-adopter-doc-impact-ci.sh — broad PR discovery + repo-local map behavior.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
WORKFLOW="${REPO_ROOT}/.github/workflows/ship-flow-doc-impact.yml"
FIXTURE_SOURCE="${REPO_ROOT}/.github/fixtures/ship-flow-adopter"
CANONICAL_CHECKER="${REPO_ROOT}/plugins/ship-flow/bin/doc-impact-gate.sh"
ADOPTER_WORKFLOW_TEMPLATE="${REPO_ROOT}/plugins/ship-flow/references/ship-flow-doc-impact-workflow.yml"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1" command="$2"
  if eval "$command" > /dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

run_fixture_gate() {
  local changed="$1" output="$2" rc_file="$3" declaration="${4:-}" rc=0
  (
    cd "$FIXTURE"
    bash .claude/ship-flow/doc-impact-gate.sh \
      "--changed=${changed}" \
      "--declaration=${declaration}"
  ) > "$output" 2>&1 || rc=$?
  printf '%s\n' "$rc" > "$rc_file"
}

extract_ci_discovery_step() {
  # The sed replacement intentionally emits a variable for the extracted
  # runtime script instead of expanding it while this test is parsed.
  # shellcheck disable=SC2016
  awk '
    /- name: Discover repo-local contribution contract/ { in_step=1; next }
    in_step && /^      - name:/ { exit }
    in_step && /^        run: \|/ { in_run=1; next }
    in_step && in_run { sub(/^          /, ""); print }
  ' "$WORKFLOW" | sed \
    -e 's/PR_BASE_SHA="${{ github.event.pull_request.base.sha }}"/PR_BASE_SHA="${TEST_BASE_SHA}"/' \
    -e 's#/tmp/ship_flow_doc_impact_changed_files.txt#${TEST_CHANGED_FILE}#g'
}

extract_adopter_caller() {
  local workflow="$1"
  # shellcheck disable=SC2016
  awk '
    /- name: Run adopted contribution contract/ { in_step=1; next }
    in_step && /^      - name:/ { exit }
    in_step && /^        run: \|/ { in_run=1; next }
    in_step && in_run { sub(/^          /, ""); print }
  ' "$workflow" | sed 's/PR_BASE_SHA="${{ github.event.pull_request.base.sha }}"/PR_BASE_SHA="${TEST_BASE_SHA}"/'
}

init_boundary_repo() {
  local repo="$1" with_adopted_checker="$2"
  mkdir -p "$repo"
  cp -R "${FIXTURE_SOURCE}/." "$repo/"
  mkdir -p "$repo/plugins/ship-flow/bin"
  cp "$CANONICAL_CHECKER" "$repo/plugins/ship-flow/bin/doc-impact-gate.sh"
  if [ "$with_adopted_checker" = "true" ]; then
    cp "$CANONICAL_CHECKER" "$repo/.claude/ship-flow/doc-impact-gate.sh"
  fi
  (
    cd "$repo"
    git init -q
    git config user.email ship-flow-test@example.invalid
    git config user.name ship-flow-test
    git add .
    git commit -qm 'test: establish boundary fixture'
  )
}

run_ci_discovery() {
  local repo="$1" base="$2" output="$3" rc_file="$4" rc=0
  (
    cd "$repo"
    TEST_BASE_SHA="$base" TEST_CHANGED_FILE="${output}.changed" GITHUB_OUTPUT="${output}.github" bash "$CI_DISCOVERY_SCRIPT"
  ) > "$output" 2>&1 || rc=$?
  printf '%s\n' "$rc" > "$rc_file"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FIXTURE="${TMP_DIR}/adopter-repo"
mkdir -p "$FIXTURE"
cp -R "${FIXTURE_SOURCE}/." "$FIXTURE/"
cp "$CANONICAL_CHECKER" "$FIXTURE/.claude/ship-flow/doc-impact-gate.sh"
chmod +x "$FIXTURE/.claude/ship-flow/doc-impact-gate.sh"
mkdir -p "$FIXTURE/.github/workflows"
cp "$ADOPTER_WORKFLOW_TEMPLATE" "$FIXTURE/.github/workflows/ship-flow-doc-impact.yml"
CI_DISCOVERY_SCRIPT="${TMP_DIR}/ci-discovery.sh"
extract_ci_discovery_step > "$CI_DISCOVERY_SCRIPT"
bash -n "$CI_DISCOVERY_SCRIPT"

echo "=== test-adopter-doc-impact-ci.sh ==="
echo ""

check "realistic adopter fixture lives outside plugins/ship-flow" \
  "test -f '${FIXTURE_SOURCE}/.claude/ship-flow/doc-coupling.yaml' && case '${FIXTURE_SOURCE}' in *plugins/ship-flow*) exit 1;; esac"
check "adopted fixture is self-contained and has no plugin source tree" \
  "test -f '${FIXTURE}/.claude/ship-flow/doc-impact-gate.sh' && test -f '${FIXTURE}/.github/workflows/ship-flow-doc-impact.yml' && test ! -e '${FIXTURE}/plugins/ship-flow'"
check "pull requests are not paths-filtered because adopter map globs are repository-defined" \
  "awk '/^  pull_request:/{in_pr=1; next} in_pr && /^jobs:/{in_pr=0} in_pr && /paths:/{bad=1} END{exit bad}' '${WORKFLOW}'"
check "workflow has a lightweight doc-impact job independent from plugin full-suite scope" \
  "grep -q '^  doc_impact:' '${WORKFLOW}' && grep -qF '.claude/ship-flow/doc-coupling.yaml' '${WORKFLOW}' && grep -qF '.claude/ship-flow/doc-impact-gate.sh' '${WORKFLOW}'"
check "workflow falls back to plugin checker only for its source repo and fails when adopter bundle is incomplete" \
  "grep -qF 'plugins/ship-flow/bin/doc-impact-gate.sh' '${WORKFLOW}' && grep -q 'map.*checker.*absent\|checker.*required' '${WORKFLOW}'"
check "lightweight job preserves rename sources and reads PR declaration through env" \
  "awk '/^  doc_impact:/{in_job=1} in_job && /^  [a-zA-Z0-9_-]+:/{if (seen) in_job=0; seen=1} in_job && /git diff --no-renames --name-only/{names=1} in_job && /git diff --no-renames --name-status/{status=1} in_job && /PR_BODY:.*github.event.pull_request.body/{body=1} END{exit !(names && status && body)}' '${WORKFLOW}'"
check "CI extracts the effective base map and passes base/head semantics to the checker" \
  "grep -qF 'git show \"\${MERGE_BASE}:\${ADOPTER_MAP}\"' '${WORKFLOW}' && grep -qF -- '--base-coupling-map=\$BASE_COUPLING_MAP' '${WORKFLOW}' && grep -qF -- '--head-map-absent' '${WORKFLOW}'"
MAP_WITH_PLUGIN_REPO="${TMP_DIR}/map-with-plugin-repo"
init_boundary_repo "$MAP_WITH_PLUGIN_REPO" false
(
  cd "$MAP_WITH_PLUGIN_REPO"
  printf '\n' >> apps/contracts/application.schema.json
  git add apps/contracts/application.schema.json
  git commit -qm 'test: change adopter contract source'
)
MAP_WITH_PLUGIN_BASE="$(git -C "$MAP_WITH_PLUGIN_REPO" rev-parse HEAD~1)"
run_ci_discovery "$MAP_WITH_PLUGIN_REPO" "$MAP_WITH_PLUGIN_BASE" "${TMP_DIR}/map-with-plugin.out" "${TMP_DIR}/map-with-plugin.rc"
check "map-present checker-missing fails closed even when a plugin checker exists" \
  "test \"\$(cat '${TMP_DIR}/map-with-plugin.rc')\" = 1 && grep -q 'adopted checker is absent' '${TMP_DIR}/map-with-plugin.out'"

CHECKER_REMOVAL_REPO="${TMP_DIR}/checker-removal-repo"
init_boundary_repo "$CHECKER_REMOVAL_REPO" true
(
  cd "$CHECKER_REMOVAL_REPO"
  rm .claude/ship-flow/doc-impact-gate.sh
  git add -u
  git commit -qm 'test: remove adopted checker'
)
CHECKER_REMOVAL_BASE="$(git -C "$CHECKER_REMOVAL_REPO" rev-parse HEAD~1)"
run_ci_discovery "$CHECKER_REMOVAL_REPO" "$CHECKER_REMOVAL_BASE" "${TMP_DIR}/checker-removal.out" "${TMP_DIR}/checker-removal.rc"
check "removing the adjacent adopted checker is a changed-path fail-closed boundary" \
  "test \"\$(cat '${TMP_DIR}/checker-removal.rc')\" = 1 && grep -qF '.claude/ship-flow/doc-impact-gate.sh' '${TMP_DIR}/checker-removal.out.changed' && grep -q 'adopted checker is absent' '${TMP_DIR}/checker-removal.out'"

MAP_REMOVAL_REPO="${TMP_DIR}/map-removal-repo"
init_boundary_repo "$MAP_REMOVAL_REPO" true
(
  cd "$MAP_REMOVAL_REPO"
  rm .claude/ship-flow/doc-coupling.yaml
  git add -u
  git commit -qm 'test: remove adopter coupling map'
)
MAP_REMOVAL_BASE="$(git -C "$MAP_REMOVAL_REPO" rev-parse HEAD~1)"
run_ci_discovery "$MAP_REMOVAL_REPO" "$MAP_REMOVAL_BASE" "${TMP_DIR}/map-removal.out" "${TMP_DIR}/map-removal.rc"
check "map deletion reaches checker with extracted base map and explicit absent-head mode" \
  "test \"\$(cat '${TMP_DIR}/map-removal.rc')\" = 0 && grep -q '^gate_required=true$' '${TMP_DIR}/map-removal.out.github' && grep -q '^head_map_absent=true$' '${TMP_DIR}/map-removal.out.github' && base_map=\$(sed -n 's/^base_coupling_map=//p' '${TMP_DIR}/map-removal.out.github') && test -s \"\$base_map\""

SOURCE_FALLBACK_REPO="${TMP_DIR}/source-fallback-repo"
mkdir -p "$SOURCE_FALLBACK_REPO/plugins/ship-flow/bin" "$SOURCE_FALLBACK_REPO/.github/workflows"
cp "$CANONICAL_CHECKER" "$SOURCE_FALLBACK_REPO/plugins/ship-flow/bin/doc-impact-gate.sh"
printf 'name: baseline\n' > "$SOURCE_FALLBACK_REPO/.github/workflows/contract.yml"
(
  cd "$SOURCE_FALLBACK_REPO"
  git init -q
  git config user.email ship-flow-test@example.invalid
  git config user.name ship-flow-test
  git add .
  git commit -qm 'test: establish source fallback fixture'
  printf 'name: changed\n' > .github/workflows/contract.yml
  git add .github/workflows/contract.yml
  git commit -qm 'test: change source contract workflow'
)
SOURCE_FALLBACK_BASE="$(git -C "$SOURCE_FALLBACK_REPO" rev-parse HEAD~1)"
run_ci_discovery "$SOURCE_FALLBACK_REPO" "$SOURCE_FALLBACK_BASE" "${TMP_DIR}/source-fallback.out" "${TMP_DIR}/source-fallback.rc"
check "no-map source repo resolves its canonical checker even for non-plugin contract paths" \
  "test \"\$(cat '${TMP_DIR}/source-fallback.rc')\" = 0 && grep -q '^gate_required=true$' '${TMP_DIR}/source-fallback.out.github' && grep -q '^checker=plugins/ship-flow/bin/doc-impact-gate.sh$' '${TMP_DIR}/source-fallback.out.github' && grep -q '^coupling_map=$' '${TMP_DIR}/source-fallback.out.github'"

run_fixture_gate changed-code-only.txt "${TMP_DIR}/code-only.out" "${TMP_DIR}/code-only.rc"
check "adopter-only code change reaches source-to-doc blocker" \
  "test \"\$(cat '${TMP_DIR}/code-only.rc')\" = 1 && grep -q '^BLOCKER doc-impact: adopter-ledger-contract' '${TMP_DIR}/code-only.out'"

run_fixture_gate changed-doc-only.txt "${TMP_DIR}/doc-only.out" "${TMP_DIR}/doc-only.rc"
check "adopter-only contract doc change reaches inverse blocker" \
  "test \"\$(cat '${TMP_DIR}/doc-only.rc')\" = 1 && grep -q '^BLOCKER contribution-impact: adopter-ledger-contract \\[doc-to-source\\]' '${TMP_DIR}/doc-only.out'"

run_fixture_gate changed-paired.txt "${TMP_DIR}/paired.out" "${TMP_DIR}/paired.rc"
check "paired adopter-only change passes both declared directions" \
  "test \"\$(cat '${TMP_DIR}/paired.rc')\" = 0 && grep -q '^PASS adopter-ledger-contract: coupled doc touched' '${TMP_DIR}/paired.out' && grep -q '^PASS contribution-impact: adopter-ledger-contract \\[doc-to-source\\]' '${TMP_DIR}/paired.out'"

run_fixture_gate changed-code-only.txt "${TMP_DIR}/fallback-strong-waiver.out" "${TMP_DIR}/fallback-strong-waiver.rc" \
  "doc-impact: none — generated provider schema remains byte-identical to the reviewed contract"
check "self-contained adopter fallback accepts a concrete source-to-doc waiver" \
  "test \"\$(cat '${TMP_DIR}/fallback-strong-waiver.rc')\" = 0 && grep -q 'declaration accepted' '${TMP_DIR}/fallback-strong-waiver.out'"

run_fixture_gate changed-code-only.txt "${TMP_DIR}/fallback-weak-waiver.out" "${TMP_DIR}/fallback-weak-waiver.rc" \
  "doc-impact: none — skip"
check "self-contained adopter fallback rejects a weak source-to-doc waiver" \
  "test \"\$(cat '${TMP_DIR}/fallback-weak-waiver.rc')\" = 1 && grep -q '^BLOCKER doc-impact:' '${TMP_DIR}/fallback-weak-waiver.out'"

CALLER_REPO="${TMP_DIR}/caller-repo"
mkdir -p "$CALLER_REPO"
cp -R "$FIXTURE/." "$CALLER_REPO/"
(
  cd "$CALLER_REPO"
  git init -q
  git config user.email ship-flow-test@example.invalid
  git config user.name ship-flow-test
  git add .
  git commit -qm 'test: establish adopter workflow fixture'
  printf '\n' >> apps/contracts/application.schema.json
  printf '\nPaired update.\n' >> docs/contracts/ledger.md
  git add apps/contracts/application.schema.json docs/contracts/ledger.md
  git commit -qm 'test: make paired adopter change'
)
ADOPTER_CALLER="${TMP_DIR}/adopter-caller.sh"
extract_adopter_caller "$CALLER_REPO/.github/workflows/ship-flow-doc-impact.yml" > "$ADOPTER_CALLER"
CALLER_BASE="$(git -C "$CALLER_REPO" rev-parse HEAD~1)"
CALLER_RC=0
(cd "$CALLER_REPO" && TEST_BASE_SHA="$CALLER_BASE" PR_BODY='' bash "$ADOPTER_CALLER") > "${TMP_DIR}/caller.out" 2>&1 || CALLER_RC=$?
printf '%s\n' "$CALLER_RC" > "${TMP_DIR}/caller.rc"
check "installed no-plugin-tree adopter workflow executes its local checker without runtime fetch" \
  "test \"\$(cat '${TMP_DIR}/caller.rc')\" = 0 && ! grep -Eqi 'curl|wget|https?://' '${ADOPTER_CALLER}' && grep -q '^PASS adopter-ledger-contract' '${TMP_DIR}/caller.out'"

ADVANCED_REPO="${TMP_DIR}/advanced-base-repo"
mkdir -p "$ADVANCED_REPO"
cp -R "$FIXTURE/." "$ADVANCED_REPO/"
(
  cd "$ADVANCED_REPO"
  git init -q
  git config user.email ship-flow-test@example.invalid
  git config user.name ship-flow-test
  git add .
  git commit -qm 'test: establish common adopter contract'
  git branch -M main
  git switch -qc pr
  git switch -q main
  printf '%s\n' \
    '  - name: base-only-row' \
    '    srcGlobs: ["base-only/**"]' \
    '    docPaths: ["docs/base-only.md"]' >> .claude/ship-flow/doc-coupling.yaml
  git add .claude/ship-flow/doc-coupling.yaml
  git commit -qm 'test: advance base with a base-only coupling row'
  git switch -q pr
  printf '\n' >> apps/contracts/application.schema.json
  printf '\nPR paired update.\n' >> docs/contracts/ledger.md
  git add apps/contracts/application.schema.json docs/contracts/ledger.md
  git commit -qm 'test: make PR-only paired change'
)
ADVANCED_BASE_SHA="$(git -C "$ADVANCED_REPO" rev-parse main)"
ADVANCED_CALLER="${TMP_DIR}/advanced-caller.sh"
extract_adopter_caller "$ADVANCED_REPO/.github/workflows/ship-flow-doc-impact.yml" > "$ADVANCED_CALLER"
ADVANCED_RC=0
(cd "$ADVANCED_REPO" && TEST_BASE_SHA="$ADVANCED_BASE_SHA" PR_BODY='' bash "$ADVANCED_CALLER") > "${TMP_DIR}/advanced.out" 2>&1 || ADVANCED_RC=$?
printf '%s\n' "$ADVANCED_RC" > "${TMP_DIR}/advanced.rc"
check "base-only map additions after divergence are excluded by merge-base map lookup" \
  "test \"\$(cat '${TMP_DIR}/advanced.rc')\" = 0 && grep -q '^PASS adopter-ledger-contract' '${TMP_DIR}/advanced.out' && ! grep -q 'base-only-row' '${TMP_DIR}/advanced.out'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do echo "  - $err"; done
  exit 1
fi
echo "All assertions passed"
