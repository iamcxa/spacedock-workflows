#!/usr/bin/env bash
# Output-shape checks for 130.3 upward-facing EM report surfaces.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

PASS=0
FAIL=0

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

require_stage_surface() {
  local label="$1"
  local file="$2"
  local path="${ROOT}/${file}"

  check "${label}: file exists" "test -f '$path'"
  check "${label}: renders upward report contract" "grep -q 'render-science-officer-em-upward-report-contract.sh' '$path'"
  check "${label}: names upward report block" "grep -q 'science_officer_em_upward_report' '$path'"
  check "${label}: names required fields" "grep -q 'em_judgment' '$path' && grep -q 'evidence_synthesis' '$path' && grep -q 'risk_tradeoff_call' '$path' && grep -q 'recommendation' '$path' && grep -q 'route' '$path' && grep -q 'confidence' '$path' && grep -q 'fo_boundary' '$path'"
  check "${label}: names route enum" "grep -q 'proceed' '$path' && grep -q 'narrow' '$path' && grep -q 'return' '$path' && grep -q 'block' '$path' && grep -q 'costly_no' '$path'"
  check "${label}: rejects relay and digest output" "perl -0ne 'exit(/status-only\\s+relay/is && /worker\\s+transcript/is && /checklist\\s+digest/is ? 0 : 1)' '$path'"
  check "${label}: rejects self-attestation gate" "grep -qi 'output-shape' '$path' && grep -qi 'not worker self-attestation' '$path'"
  check "${label}: preserves FO/EM boundary" "perl -0ne 'exit(/FO\\s+owns\\s+workflow\\s+mechanics/is && /EM\\s+owns\\s+judgment\\s+and\\s+recommendation/is ? 0 : 1)' '$path'"
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

echo "=== Science Officer (EM) upward report surfaces ==="

require_profile_surface "plugin profile" "plugins/ship-flow/_mods/science-officer-em.md"
require_profile_surface "workflow profile" "docs/ship-flow/_mods/science-officer-em.md"
require_stage_surface "ship-verify synthesis" "plugins/ship-flow/skills/ship-verify/SKILL.md"
require_stage_surface "ship-review closeout" "plugins/ship-flow/skills/ship-review/SKILL.md"
require_stage_surface "ship-final summary" "plugins/ship-flow/skills/ship/SKILL.md"
require_readme_surface "workflow docs" "docs/ship-flow/README.md"
require_readme_surface "plugin docs" "plugins/ship-flow/README.md"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
