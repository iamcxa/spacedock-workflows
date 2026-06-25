#!/usr/bin/env bash
# integration/test-science-officer-em-upward-report-surfaces-dogfood.sh
#
# Host artifacts needed:
#   docs/ship-flow/_mods/science-officer-em.md — adopted workflow SO mod
#   docs/ship-flow/README.md — adopted workflow README
#
# Why not standalone: these files only exist in the adopted host project.

set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../../.." && pwd)"

PASS=0; FAIL=0

check() {
  local desc="$1" cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "PASS: ${desc}"; PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"; FAIL=$((FAIL + 1))
  fi
}

require_profile_surface() {
  local label="$1"
  local file="$2"
  local path="${ROOT}/${file}"
  check "${label}: profile names upward report block" "grep -q 'science_officer_em_upward_report' '$path'"
  check "${label}: profile names judgment fields" "grep -q 'em_judgment' '$path' && grep -q 'evidence_synthesis' '$path' && grep -q 'risk_tradeoff_call' '$path' && grep -q 'fo_boundary' '$path'"
  check "${label}: profile rejects status-only relay" "grep -qi 'status-only relay' '$path'"
}

require_readme_surface() {
  local label="$1"
  local file="$2"
  local path="${ROOT}/${file}"
  check "${label}: README names 130.3 upward report schema" "grep -qi '130.3' '$path' && grep -qi 'upward report schema' '$path'"
  check "${label}: README rejects self-attestation gates" "grep -qi 'output-shape' '$path' && grep -qi 'not worker self-attestation' '$path'"
}

echo "=== integration: SO/EM upward report surfaces — dogfood docs ==="
require_profile_surface "workflow profile" "docs/ship-flow/_mods/science-officer-em.md"
require_readme_surface "workflow docs" "docs/ship-flow/README.md"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then exit 1; fi
