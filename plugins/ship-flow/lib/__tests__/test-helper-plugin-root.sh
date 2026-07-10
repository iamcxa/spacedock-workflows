#!/usr/bin/env bash
# test-helper-plugin-root.sh - stage-skill helper invocations must resolve
# through "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}" so installed-plugin
# (marketplace cache) adopters are not silently degraded to manual fallback.
#
# Ratchet list: seeded with the top-5 measured-pain helpers from the carlove
# 2026-07-08 joint audit (validate-tdd-ledger 9 entities, canonical-doc-sync
# 8, check-harvest-exempt 4, check-guidance-receipt bounce evidence). Append
# helpers here as later sweep slices convert the remaining bare paths; flip
# to a blanket lib|bin rule when the sweep completes.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
SKILLS_DIR="${REPO_ROOT}/plugins/ship-flow/skills"

HELPERS=(
  "validate-tdd-ledger.py"
  "check-guidance-receipt.sh"
  "canonical-doc-sync-checker.sh"
  "check-harvest-exempt.sh"
)

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

echo "=== test-helper-plugin-root.sh ==="
echo ""

for helper in "${HELPERS[@]}"; do
  # No bare repo-root-relative invocation may remain: every reference to the
  # helper path must carry the CLAUDE_PLUGIN_ROOT fallback on the same line.
  check "${helper}: no bare plugins/ship-flow/(lib|bin) reference in skills" \
    "! grep -rn 'plugins/ship-flow/\\(lib\\|bin\\)/${helper}' '${SKILLS_DIR}' | grep -v 'CLAUDE_PLUGIN_ROOT' | grep -q ."

  # Guard against fixing by deletion: the helper must still be invoked
  # somewhere in skills, in the fallback form.
  check "${helper}: fallback-form invocation still present in skills" \
    "grep -rn 'CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/\\(lib\\|bin\\)/${helper}' '${SKILLS_DIR}' | grep -q ."
done

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo ""
  echo "Bare helper paths break installed-plugin adopters (no plugins/"
  echo "ship-flow checkout at repo root). Rewrite the invocation as:"
  echo '  bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/<helper>" ...'
  exit 1
fi

echo "All assertions passed"
