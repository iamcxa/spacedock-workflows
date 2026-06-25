#!/usr/bin/env bash
# test-designer-skills-available.sh — Assert T5.1 designer-skills marketplace registration
# HOST ARTIFACTS: docs/ship-flow/ entities, .claude/settings.json, or plugins/spacebridge/ — not present in standalone clone.
# Run only from the dogfood host project. See lib/__tests__/integration/README.md
# Entity: #106 pipeline-render-fidelity-hardening Wave 2b T5.1
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-designer-skills-available.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SETTINGS_FILE="${SCRIPT_DIR}/../../../../.claude/settings.json"
README_FILE="${SCRIPT_DIR}/../../../../docs/ship-flow/README.md"

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

echo "=== designer-skills marketplace registration assertions ==="
echo ""

# --- T5.1: .claude/settings.json registration ---
check "settings.json exists" \
  "[ -f \"$SETTINGS_FILE\" ]"

check "designer-skills@julianoczkowski in enabledPlugins (DC-5.1)" \
  "grep -q 'designer-skills@julianoczkowski' \"$SETTINGS_FILE\""

check "designer-skills@julianoczkowski enabled (true)" \
  "grep -A1 'designer-skills@julianoczkowski' \"$SETTINGS_FILE\" | grep -q 'true'"

# --- T5.1: docs/ship-flow/README.md Quick Start ---
check "README Quick Start mentions designer-skills install" \
  "grep -q 'designer-skills@julianoczkowski' \"$README_FILE\""

check "README mentions /plugin install command for designer-skills" \
  "grep -E '/plugin install.*designer-skills' \"$README_FILE\""

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

echo "All assertions passed — designer-skills marketplace registration confirmed."
exit 0
