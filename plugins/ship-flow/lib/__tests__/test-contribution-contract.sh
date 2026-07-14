#!/usr/bin/env bash
# test-contribution-contract.sh — contribution contract docs and FO wiring.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
PLUGIN_ROOT="${REPO_ROOT}/plugins/ship-flow"

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

extract_fo_resolver() {
  awk '
    /# contribution-contract-resolver:start/ { found=1; next }
    /# contribution-contract-resolver:end/ { exit }
    found { print }
  ' "${PLUGIN_ROOT}/_mods/contribution-contract.md"
}

run_fo_resolver() {
  local repo="$1" output="$2" rc_file="$3" plugin_root="${4:-}" rc=0
  (cd "$repo" && BASE_REF=HEAD CLAUDE_PLUGIN_ROOT="$plugin_root" bash "$FO_RESOLVER") > "$output" 2>&1 || rc=$?
  printf '%s\n' "$rc" > "$rc_file"
}

commit_fo_repo() {
  local repo="$1"
  (
    cd "$repo"
    git init -q
    git config user.email ship-flow-test@example.invalid
    git config user.name ship-flow-test
    git add .
    git commit -qm 'test: establish FO resolver fixture'
  )
}

echo "=== test-contribution-contract.sh ==="
echo ""

check "plugin contribution guide exists" "test -f '${PLUGIN_ROOT}/CONTRIBUTING.md'"
check "guide defines both explicit directions and legacy default" \
  "grep -q 'source-to-doc' '${PLUGIN_ROOT}/CONTRIBUTING.md' && grep -q 'doc-to-source' '${PLUGIN_ROOT}/CONTRIBUTING.md' && grep -qi 'legacy.*source-to-doc' '${PLUGIN_ROOT}/CONTRIBUTING.md'"
check "guide freezes supported schema versions and the 1.0 compatibility boundary" \
  "grep -q 'Supported schema versions are \`1.0\` and \`1.1\`' '${PLUGIN_ROOT}/CONTRIBUTING.md' && grep -q 'Version \`1.0\` rejects \`directions\` and \`exemptGlobs\`' '${PLUGIN_ROOT}/CONTRIBUTING.md' && grep -qi 'missing, duplicate, malformed, or unknown.*exit 2' '${PLUGIN_ROOT}/CONTRIBUTING.md'"
check "guide defines row-scoped exemptions and scoped declaration grammar" \
  "grep -q 'exemptGlobs' '${PLUGIN_ROOT}/CONTRIBUTING.md' && grep -qF 'contribution-impact: none [<row>:doc-to-source]' '${PLUGIN_ROOT}/CONTRIBUTING.md'"
check "guide names delete and rename fail-closed policy" \
  "grep -Eqi 'delet(e|ion).*rename|rename.*delet(e|ion)' '${PLUGIN_ROOT}/CONTRIBUTING.md' && grep -qi 'fail closed' '${PLUGIN_ROOT}/CONTRIBUTING.md'"

check "canonical contribution mod exists" "test -f '${PLUGIN_ROOT}/_mods/contribution-contract.md'"
check "mod declares pre-review hook and checker invocation" \
  "grep -q 'pre-review-spend' '${PLUGIN_ROOT}/_mods/contribution-contract.md' && grep -q 'doc-impact-gate.sh' '${PLUGIN_ROOT}/_mods/contribution-contract.md'"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
FO_RESOLVER="${TMP_DIR}/fo-resolver.sh"
extract_fo_resolver > "$FO_RESOLVER"
check "FO resolver is an executable contract block" \
  "test -s '${FO_RESOLVER}' && bash -n '${FO_RESOLVER}'"

ADOPTER_REPO="${TMP_DIR}/adopter"
mkdir -p "$ADOPTER_REPO/.claude/ship-flow" "$ADOPTER_REPO/plugins/ship-flow/bin"
touch "$ADOPTER_REPO/.claude/ship-flow/doc-coupling.yaml" "$ADOPTER_REPO/.claude/ship-flow/doc-impact-gate.sh" "$ADOPTER_REPO/plugins/ship-flow/bin/doc-impact-gate.sh"
commit_fo_repo "$ADOPTER_REPO"
run_fo_resolver "$ADOPTER_REPO" "${TMP_DIR}/fo-adopter.out" "${TMP_DIR}/fo-adopter.rc"
check "FO resolves adopter map only to its adjacent checker" \
  "test \"\$(cat '${TMP_DIR}/fo-adopter.rc')\" = 0 && grep -q 'checker=.claude/ship-flow/doc-impact-gate.sh' '${TMP_DIR}/fo-adopter.out' && grep -q 'map=.claude/ship-flow/doc-coupling.yaml' '${TMP_DIR}/fo-adopter.out'"

rm "$ADOPTER_REPO/.claude/ship-flow/doc-impact-gate.sh"
run_fo_resolver "$ADOPTER_REPO" "${TMP_DIR}/fo-missing.out" "${TMP_DIR}/fo-missing.rc"
check "FO fails closed when adopter map exists without adjacent checker despite plugin fallback" \
  "test \"\$(cat '${TMP_DIR}/fo-missing.rc')\" = 2 && grep -qi 'BLOCKED.*adopted checker' '${TMP_DIR}/fo-missing.out'"

SOURCE_REPO="${TMP_DIR}/source"
mkdir -p "$SOURCE_REPO/plugins/ship-flow/bin" "$SOURCE_REPO/plugins/ship-flow/references"
touch "$SOURCE_REPO/plugins/ship-flow/bin/doc-impact-gate.sh"
printf '%s\n' 'schema_version: "1.0"' 'couplings:' '  - name: source-row' '    srcGlobs: ["src/**"]' '    docPaths: ["docs/source.md"]' > "$SOURCE_REPO/plugins/ship-flow/references/doc-coupling-map.yaml"
commit_fo_repo "$SOURCE_REPO"
run_fo_resolver "$SOURCE_REPO" "${TMP_DIR}/fo-source.out" "${TMP_DIR}/fo-source.rc"
check "FO source-repo fallback uses canonical checker with its default map" \
  "test \"\$(cat '${TMP_DIR}/fo-source.rc')\" = 0 && grep -q 'checker=plugins/ship-flow/bin/doc-impact-gate.sh' '${TMP_DIR}/fo-source.out' && grep -q 'map=plugin-default' '${TMP_DIR}/fo-source.out'"
run_fo_resolver "$SOURCE_REPO" "${TMP_DIR}/fo-source-absolute.out" "${TMP_DIR}/fo-source-absolute.rc" "$SOURCE_REPO/plugins/ship-flow"
check "FO absolute plugin root keeps the Git tree lookup repo-relative" \
  "test \"\$(cat '${TMP_DIR}/fo-source-absolute.rc')\" = 0 && grep -q 'checker=${SOURCE_REPO}/plugins/ship-flow/bin/doc-impact-gate.sh' '${TMP_DIR}/fo-source-absolute.out' && test -s '${SOURCE_REPO}/.context/ship-flow/base-doc-coupling.yaml' && grep -q 'SOURCE_MAP_TREE=plugins/ship-flow/references/doc-coupling-map.yaml' '${PLUGIN_ROOT}/_mods/contribution-contract.md'"

MARKETPLACE_REPO="${TMP_DIR}/marketplace-adopter"
MARKETPLACE_PLUGIN="${TMP_DIR}/marketplace-plugin"
mkdir -p "$MARKETPLACE_REPO" "$MARKETPLACE_PLUGIN/bin" "$MARKETPLACE_PLUGIN/references"
printf 'adopter without repo-owned Ship Flow source\n' > "$MARKETPLACE_REPO/README.md"
touch "$MARKETPLACE_PLUGIN/bin/doc-impact-gate.sh"
printf '%s\n' 'schema_version: "1.0"' 'couplings:' '  - name: marketplace-row' '    srcGlobs: ["src/**"]' '    docPaths: ["docs/source.md"]' > "$MARKETPLACE_PLUGIN/references/doc-coupling-map.yaml"
commit_fo_repo "$MARKETPLACE_REPO"
run_fo_resolver "$MARKETPLACE_REPO" "${TMP_DIR}/fo-marketplace.out" "${TMP_DIR}/fo-marketplace.rc" "$MARKETPLACE_PLUGIN"
check "FO blocks marketplace-installed plugin fallback when adopter has no map" \
  "test \"\$(cat '${TMP_DIR}/fo-marketplace.rc')\" = 2 && grep -qi 'BLOCKED.*source repo' '${TMP_DIR}/fo-marketplace.out'"
check "FO requires an explicit PR base and passes effective base/head map semantics" \
  "grep -q 'BASE_REF' '${PLUGIN_ROOT}/_mods/contribution-contract.md' && grep -q 'git merge-base.*BASE_REF' '${PLUGIN_ROOT}/_mods/contribution-contract.md' && grep -q -- '--base-coupling-map' '${PLUGIN_ROOT}/_mods/contribution-contract.md' && grep -q -- '--head-map-absent' '${PLUGIN_ROOT}/_mods/contribution-contract.md' && ! grep -q 'origin/main' '${PLUGIN_ROOT}/_mods/contribution-contract.md'"
check "contributor and FO commands preserve rename source paths" \
  "grep -q 'git diff --no-renames --name-only' '${PLUGIN_ROOT}/CONTRIBUTING.md' && grep -q 'git diff --no-renames --name-only' '${PLUGIN_ROOT}/_mods/contribution-contract.md'"
check "onboarding and contribution docs require the self-contained adopter checker bundle" \
  "grep -qF '.claude/ship-flow/doc-impact-gate.sh' '${PLUGIN_ROOT}/CONTRIBUTING.md' && grep -qF '.claude/ship-flow/doc-impact-gate.sh' '${PLUGIN_ROOT}/skills/ship-onboard/SKILL.md' && grep -qF 'references/ship-flow-doc-impact-workflow.yml' '${PLUGIN_ROOT}/skills/ship-onboard/SKILL.md' && test -f '${PLUGIN_ROOT}/references/ship-flow-doc-impact-workflow.yml' && grep -qi 'without.*plugin tree\|without relying on a vendored plugin tree' '${PLUGIN_ROOT}/CONTRIBUTING.md' '${PLUGIN_ROOT}/skills/ship-onboard/SKILL.md'"
check "mod keeps adopter content out of generic plugin" \
  "grep -qi 'adopter.*owns' '${PLUGIN_ROOT}/_mods/contribution-contract.md' && grep -qi 'generic.*mechanism' '${PLUGIN_ROOT}/_mods/contribution-contract.md'"

check "production map declares version 1.1 bidirectional contribution row" \
  "grep -q 'schema_version: \"1.1\"' '${PLUGIN_ROOT}/references/doc-coupling-map.yaml' && grep -q 'name: contribution-contract' '${PLUGIN_ROOT}/references/doc-coupling-map.yaml' && grep -q 'directions: \[\"source-to-doc\", \"doc-to-source\"\]' '${PLUGIN_ROOT}/references/doc-coupling-map.yaml'"
check "Helm adopter fixture uses an explicit narrow exemption list" \
  "grep -q 'exemptGlobs:' '${PLUGIN_ROOT}/lib/__tests__/fixtures/doc-impact-gate/coupling-map-bidirectional.yaml' && grep -q 'helm-adopter.*/generated/\*\*' '${PLUGIN_ROOT}/lib/__tests__/fixtures/doc-impact-gate/coupling-map-bidirectional.yaml'"

check "doc-sync skill audits inverse edges and contribution guide" \
  "grep -qi 'inverse' '${PLUGIN_ROOT}/skills/doc-sync/SKILL.md' && grep -q 'CONTRIBUTING.md' '${PLUGIN_ROOT}/skills/doc-sync/SKILL.md'"
check "ship-review follows the mod resolver before review spend and blocks on failure" \
  "grep -q '_mods/contribution-contract.md' '${PLUGIN_ROOT}/skills/ship-review/SKILL.md' && grep -qi 'checker-resolution block' '${PLUGIN_ROOT}/skills/ship-review/SKILL.md' && grep -qi 'explicit.*base\|pass.*base' '${PLUGIN_ROOT}/skills/ship-review/SKILL.md' && grep -qi 'before.*review.*spend' '${PLUGIN_ROOT}/skills/ship-review/SKILL.md' && grep -qi 'BLOCKED' '${PLUGIN_ROOT}/skills/ship-review/SKILL.md'"
check "doc-sync context maps the contribution surfaces" \
  "grep -q 'CONTRIBUTING.md' '${PLUGIN_ROOT}/references/doc-sync-context.md' && grep -q '_mods/contribution-contract.md' '${PLUGIN_ROOT}/references/doc-sync-context.md'"
check "root README links the plugin contribution guide" \
  "grep -q 'plugins/ship-flow/CONTRIBUTING.md' '${REPO_ROOT}/README.md'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "All assertions passed"
