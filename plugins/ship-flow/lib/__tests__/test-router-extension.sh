#!/usr/bin/env bash
# test-router-extension.sh — DC-runner for #113.1 router-extension
# Tests ship-design SKILL.md Phase 0 router: registry integration, HALT-with-options, trigger broadening
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-router-extension.sh
#
# Expected before T1.2 (RED): assertions 1-5 fail (SKILL.md unedited)
# Expected after T1.2 (partial-GREEN): assertions 1-5 pass, 6-7 still RED until W2
# Expected after W2 (GREEN): all 7 assertions pass
# Expected after W3 (final GREEN): all 7 pass + test-router-extension exits 0

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

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

echo "=== test-router-extension.sh ==="
echo ""

# --- Assertion 1: DC-1 — ship-design Phase 0 cites registry-resolve.sh ---
echo "Block 1: Phase 0 cites registry-resolve.sh (DC-1)"
check "ship-design SKILL.md mentions registry-resolve.sh" \
  "grep -qE 'registry-resolve\.sh' '${PLUGIN_ROOT}/skills/ship-design/SKILL.md'"

# --- Assertion 2: DC-2 — M1 HALT-with-options: all 3 options present ---
echo "Block 2: M1 HALT surfaces all 3 options (DC-2)"
check "ship-design SKILL.md has specialist_missing surface" \
  "grep -qE 'specialist_missing' '${PLUGIN_ROOT}/skills/ship-design/SKILL.md'"
check "ship-design SKILL.md has skip/generalist-marker/file-specialist-first options" \
  "grep -qE 'skip.*generalist-marker.*file-specialist-first|generalist-marker.*file-specialist-first' '${PLUGIN_ROOT}/skills/ship-design/SKILL.md'"

# --- Assertion 3: DC-3 — M2 knowledge_module_missing also halts ---
echo "Block 3: M2 knowledge_module_missing path present (DC-3)"
check "ship-design SKILL.md mentions knowledge_module_missing" \
  "grep -qE 'knowledge_module_missing' '${PLUGIN_ROOT}/skills/ship-design/SKILL.md'"

# --- Assertion 4: DC-4 — Trigger condition includes domain: frontmatter ---
echo "Block 4: Trigger condition includes domain: trigger (DC-4)"
check "ship-design SKILL.md trigger lists domain frontmatter" \
  "grep -qE 'domain:.*frontmatter|domain.*set.*shape|when.*domain.*set|domain.*set_at.*shape' '${PLUGIN_ROOT}/skills/ship-design/SKILL.md'"

# --- Assertion 5: DC-5 — backward compat: UI path preserved ---
echo "Block 5: Backward compat — UI trigger path preserved (DC-5)"
check "ship-design SKILL.md still has affects_ui:true trigger" \
  "grep -qE 'affects_ui:.*true' '${PLUGIN_ROOT}/skills/ship-design/SKILL.md'"
check "ship-design SKILL.md still has Category 0 path" \
  "grep -qE 'Category 0|category 0' '${PLUGIN_ROOT}/skills/ship-design/SKILL.md'"

# --- Assertion 6: DC-6 — entity-body-schema has domain: field with set_at: shape ---
echo "Block 6: entity-body-schema has domain: field (DC-6)"
check "entity-body-schema.yaml has domain field with set_at: shape" \
  "awk '/^[[:space:]]*domain:/{p=1} p && /set_at:[[:space:]]*shape/{found=1; exit} p && /^[[:space:]]*[a-z_]+:[[:space:]]*$/{p=0} END{exit !found}' '${PLUGIN_ROOT}/references/entity-body-schema.yaml'"

# --- Assertion 7: DC-7 — ship-shape cites registry-resolve --classify ---
echo "Block 7: ship-shape SKILL.md cites registry-resolve --classify (DC-7)"
check "ship-shape SKILL.md mentions registry-resolve --classify" \
  "grep -qE 'registry-resolve.*--classify|registry-resolve\.sh.*--classify' '${PLUGIN_ROOT}/skills/ship-shape/SKILL.md'"

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
