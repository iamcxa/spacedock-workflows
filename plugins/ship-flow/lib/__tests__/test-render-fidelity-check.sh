#!/usr/bin/env bash
# test-render-fidelity-check.sh — RED harness for render-fidelity-check.md artifact
# Entity: #106 pipeline-render-fidelity-hardening Wave 0 T0.1
#
# Purpose: Assert render-fidelity-check.md schema sections exist in entity folder.
# At W0 (RED phase), no implementation exists yet → exits non-zero with EXPECTED FAIL message.
# At W4 (dogfood complete), artifact will satisfy all assertions → exits 0.
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-render-fidelity-check.sh
#   bash plugins/ship-flow/lib/__tests__/test-render-fidelity-check.sh --entity-dir <path>

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"

# --- Arg parsing ---
ENTITY_DIR="${SCRIPT_DIR}/../../../../docs/ship-flow/106-pipeline-render-fidelity-hardening"

while [[ $# -gt 0 ]]; do
  case "$1" in
    --entity-dir) ENTITY_DIR="$2"; shift 2 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

ARTIFACT="${ENTITY_DIR}/render-fidelity-check.md"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local result="$2"
  if [ "$result" = "0" ]; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

echo "=== render-fidelity-check.md schema assertions ==="
echo "Artifact: $ARTIFACT"
echo ""

# --- T1: Artifact must exist ---
if [ ! -f "$ARTIFACT" ]; then
  echo "EXPECTED FAIL — no implementation yet"
  echo ""
  echo "  render-fidelity-check.md does not exist at: $ARTIFACT"
  echo "  This is expected at W0 RED phase. W4 dogfood will create the artifact."
  exit 1
fi

echo "Artifact found. Running schema assertions..."
echo ""

# --- T2: Required H2 sections ---
check "## Indirection Mismatch section present" \
  "$(grep -cE "^## Indirection Mismatch" "$ARTIFACT" | grep -qE "^[1-9]" && echo 0 || echo 1)"

check "## Fake-Button Flag section present" \
  "$(grep -cE "^## Fake-Button Flag" "$ARTIFACT" | grep -qE "^[1-9]" && echo 0 || echo 1)"

check "## Sidebar Decision Question section present" \
  "$(grep -cE "^## Sidebar Decision Question" "$ARTIFACT" | grep -qE "^[1-9]" && echo 0 || echo 1)"

# --- T3: Each section has ≥1 entry ---
check "≥1 indirection mismatch entry" \
  "$(grep -cE "^- " "$ARTIFACT" | grep -qE "^[1-9]" && echo 0 || echo 1)"

# --- T4: Stage SHA citations exist ---
check "stage commit SHA cited (proves hardened SKILL fired)" \
  "$(grep -cE "[0-9a-f]{7,40}" "$ARTIFACT" | grep -qE "^[1-9]" && echo 0 || echo 1)"

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

echo "All assertions passed — render-fidelity-check.md schema valid."
exit 0
