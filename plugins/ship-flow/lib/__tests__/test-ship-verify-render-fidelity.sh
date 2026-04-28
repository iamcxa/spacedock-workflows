#!/usr/bin/env bash
# test-ship-verify-render-fidelity.sh — Assert T6.3 mandatory browser render verify in ship-verify SKILL.md
# Entity: #106 pipeline-render-fidelity-hardening Wave 3 T6.3
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-ship-verify-render-fidelity.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SKILL_FILE="${SCRIPT_DIR}/../../../../plugins/ship-flow/skills/ship-verify/SKILL.md"
SCHEMA_FILE="${SCRIPT_DIR}/../../../../plugins/ship-flow/references/entity-body-schema.yaml"

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

echo "=== ship-verify Render Fidelity assertions (T6.3) ==="
echo ""

# --- T6.3: ship-verify SKILL.md Step 4.5 ---
check "Step 4.5 Render Fidelity section present in SKILL.md" \
  "grep -q 'Step 4.5.*Render Fidelity\|Render Fidelity.*T6.3' \"$SKILL_FILE\""

check "mandatory for UI-type entities stated" \
  "grep -qiE 'mandatory.*UI-type|UI-type.*mandatory' \"$SKILL_FILE\""

check "preflight dev server gate (BLOCKER if fails)" \
  "grep -qE 'Preflight gate.*BLOCKER|dev server.*BLOCKER|worktree-dev-server' \"$SKILL_FILE\""

check "e2e-pipeline:ui-verify invocation mentioned" \
  "grep -q 'e2e-pipeline:ui-verify' \"$SKILL_FILE\""

check "### Render Fidelity subsection emission in verify.md" \
  "grep -q '### Render Fidelity' \"$SKILL_FILE\""

check "render_fidelity_status field emitted (pass|fail|not-applicable)" \
  "grep -qE 'render_fidelity_status.*pass|fail|not-applicable' \"$SKILL_FILE\""

check "fake/stub button detection mentioned" \
  "grep -qiE 'fake.*button|stub.*interactive|div.*onClick.*button' \"$SKILL_FILE\""

# --- T6.3: entity-body-schema.yaml render_fidelity block ---
check "render_fidelity block in entity-body-schema.yaml" \
  "grep -q 'render_fidelity:' \"$SCHEMA_FILE\""

check "render-fidelity section_tag in schema" \
  "grep -q 'render-fidelity' \"$SCHEMA_FILE\""

check "render_fidelity_status enum in schema (pass|fail|not-applicable)" \
  "grep -qE 'pass.*fail.*not-applicable|render_fidelity_status.*enum' \"$SCHEMA_FILE\""

check "component_table with Expected token column in schema" \
  "grep -q 'Expected token' \"$SCHEMA_FILE\""

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "All assertions passed — ship-verify Render Fidelity T6.3 wired."
exit 0
