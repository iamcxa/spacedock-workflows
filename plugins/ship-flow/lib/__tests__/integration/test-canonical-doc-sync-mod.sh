#!/usr/bin/env bash
# test-canonical-doc-sync-mod.sh — contract coverage for canonical doc closeout rules
# HOST ARTIFACTS: docs/ship-flow/ entities, .claude/settings.json, or plugins/spacebridge/ — not present in standalone clone.
# Run only from the dogfood host project. See lib/__tests__/integration/README.md

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
MOD_FILE="${REPO_ROOT}/docs/ship-flow/_mods/canonical-doc-sync.md"
REVIEW_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-review/SKILL.md"
SCHEMA_FILE="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
DOC_FORMAT="${REPO_ROOT}/plugins/ship-flow/references/doc-format.md"

PASS=0
FAIL=0
ERRORS=()

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

echo "=== test-canonical-doc-sync-mod.sh ==="
echo ""

echo "Block 1: mod exists and names all canonical docs"
check "canonical-doc-sync mod exists" \
  "[ -f '${MOD_FILE}' ]"
check "mod covers ARCHITECTURE, PRODUCT, and ROADMAP" \
  "grep -q 'ARCHITECTURE.md' '${MOD_FILE}' && grep -q 'PRODUCT.md' '${MOD_FILE}' && grep -q 'ROADMAP.md' '${MOD_FILE}'"

echo "Block 2: architecture timing is explicit"
check "mod says ARCHITECTURE updates on architecture-impact or durable architecture changes" \
  "grep -q 'architecture-impact' '${MOD_FILE}' && grep -q 'durable architecture' '${MOD_FILE}'"
check "mod says architecture skips internal-only prompt/test/report changes" \
  "grep -q 'prompt text' '${MOD_FILE}' && grep -q 'workflow reports' '${MOD_FILE}'"

echo "Block 3: umbrella closeout is explicit"
check "mod defines umbrella-closeout hook" \
  "grep -q 'Hook: umbrella-closeout' '${MOD_FILE}'"
check "mod defines last-open-child trigger" \
  "grep -q 'last open child' '${MOD_FILE}'"
check "mod requires parent ROADMAP closeout exactly once" \
  "grep -q 'exactly once for the parent umbrella' '${MOD_FILE}'"
check "mod requires parent PRODUCT closeout exactly once when capability changes" \
  "grep -q 'PRODUCT.md.*exactly once for the parent umbrella' '${MOD_FILE}'"
check "mod allows follow-up PR when final child merged before closeout" \
  "grep -q 'follow-up PR' '${MOD_FILE}'"

echo "Block 4: ship-review and schema consume the mod"
check "ship-review references canonical-doc-sync mod" \
  "grep -q 'canonical-doc-sync' '${REVIEW_SKILL}'"
check "ship-review requires umbrella closeout check" \
  "grep -q 'umbrella closeout' '${REVIEW_SKILL}'"
check "entity schema exposes umbrella closeout in review output" \
  "grep -q 'umbrella_closeout' '${SCHEMA_FILE}'"
check "doc-format documents umbrella shipped rows" \
  "grep -q 'Umbrella Shipped Row' '${DOC_FORMAT}'"
check "doc-format documents architecture update timing" \
  "grep -q 'Architecture Patch' '${DOC_FORMAT}' && grep -q 'durable architecture change' '${DOC_FORMAT}'"

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

echo "All assertions passed — canonical doc sync mod wired."
exit 0
