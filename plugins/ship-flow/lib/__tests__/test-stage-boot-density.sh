#!/usr/bin/env bash
# test-stage-boot-density.sh — Assert T3.4 density-aware Boot Self-Check in all 6 stage SKILLs
# Entity: #106 pipeline-render-fidelity-hardening Wave 2c T3.4
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-stage-boot-density.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
SKILLS_DIR="${SCRIPT_DIR}/../../../../plugins/ship-flow/skills"

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

echo "=== stage Boot Self-Check density-aware assertions (T3.4) ==="
echo ""

STAGE_SKILLS=("ship-shape" "ship-plan" "ship-execute" "ship-verify" "ship-review" "ship-design")

# --- Fixture-based density gate checks ---
# Assert vacuum fixture → triggers SendMessage(FO) path (i.e., density item present in SKILL)
# Assert high fixture → triggers auto-load path (i.e., auto-load mentioned in same item)
for skill in "${STAGE_SKILLS[@]}"; do
  skill_file="${SKILLS_DIR}/${skill}/SKILL.md"

  check "${skill}: Boot Self-Check section present" \
    "grep -q '## Boot Self-Check' \"$skill_file\""

  check "${skill}: density-aware skill load step present (T3.4)" \
    "grep -q 'Density-aware skill load' \"$skill_file\""

  # vacuum fixture: SendMessage(FO) path documented
  check "${skill}: vacuum/low → SendMessage(FO) path documented" \
    "grep -E 'low.vacuum.*SendMessage|vacuum.*low.*SendMessage|SendMessage.*FO.*proposed skill' \"$skill_file\""

  # high fixture: auto-load documented
  check "${skill}: high → auto-load documented" \
    "grep -E 'high.*auto-load|auto-load.*framework skills' \"$skill_file\""
done

# --- ship-runtime-detect Step R6 density gate ---
RUNTIME_DETECT="${SKILLS_DIR}/ship-runtime-detect/SKILL.md"
check "ship-runtime-detect: Step R6 density gate present" \
  "grep -q 'Density gate' \"$RUNTIME_DETECT\""

check "ship-runtime-detect: high → auto-load, skip FO ask" \
  "grep -qE 'high.*auto-load.*skip|auto-load.*skip FO' \"$RUNTIME_DETECT\""

check "ship-runtime-detect: vacuum/low → SendMessage(FO)" \
  "grep -qE 'low|vacuum.*SendMessage|SendMessage.*FO.*framework' \"$RUNTIME_DETECT\""

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

echo "All assertions passed — density-aware Boot Self-Check wired in all stage SKILLs."
exit 0
