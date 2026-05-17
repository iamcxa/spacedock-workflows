#!/usr/bin/env bash
# test-distill-reference-contract.sh — distill-reference utility skill contract.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

SKILL="${REPO_ROOT}/plugins/ship-flow/skills/distill-reference/SKILL.md"
AXES="${REPO_ROOT}/plugins/ship-flow/skills/distill-reference/references/comparison-axes.md"
REPORT_TEMPLATE="${REPO_ROOT}/plugins/ship-flow/skills/distill-reference/references/report-template.md"
CANDIDATE_CAPTURE="${REPO_ROOT}/plugins/ship-flow/skills/distill-reference/references/candidate-capture.md"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: ${desc}"
    FAIL=$((FAIL + 1))
    ERRORS+=("${desc}")
  fi
}

echo "=== test-distill-reference-contract.sh ==="
echo ""

echo "Block 1: utility skill surface"
check "distill-reference skill exists" \
  "test -f '${SKILL}'"
check "skill frontmatter exposes user-invocable utility command" \
  "grep -q '^name: distill-reference' '${SKILL}' && grep -q '^user-invocable: true' '${SKILL}' && grep -q '<source-path-or-url>' '${SKILL}'"
check "skill is documented as utility/meta skill, not stage skill" \
  "grep -q 'utility' '${SKILL}' && grep -q 'not a stage skill' '${SKILL}'"
check "skill declares the command and core options" \
  "grep -q '/ship-flow:distill-reference <source-path-or-url>' '${SKILL}' && grep -q -- '--target ship-flow' '${SKILL}' && grep -q -- '--report-name' '${SKILL}' && grep -q -- '--file-todos' '${SKILL}'"

echo "Block 2: reference files"
check "comparison axes reference exists" \
  "test -f '${AXES}'"
check "report template reference exists" \
  "test -f '${REPORT_TEMPLATE}'"
check "candidate capture reference exists" \
  "test -f '${CANDIDATE_CAPTURE}'"
check "skill links all references" \
  "grep -q 'references/comparison-axes.md' '${SKILL}' && grep -q 'references/report-template.md' '${SKILL}' && grep -q 'references/candidate-capture.md' '${SKILL}'"

echo "Block 3: comparison axes"
for axis in granularity autonomy_stance subagent_dispatch evidence_model gate_philosophy state_persistence hermetic_fit; do
  check "axis ${axis} is defined" "grep -q '${axis}' '${AXES}'"
done

echo "Block 4: report template sections"
for section in "Source Identity" "Source Availability" "Source Read List" "Target Map" "Comparison Axes" "Gap Scoring" "Candidates" "Rejected Imports" "Follow-up Status" "Hermeticity Audit"; do
  check "report template includes ${section}" "grep -q '## ${section}' '${REPORT_TEMPLATE}'"
done
check "report template separates reusable format from first report instance" \
  "grep -q 'docs/ship-flow/_distillations/<yyyy-mm-dd>--<report-name>.md' '${REPORT_TEMPLATE}' && ! grep -q '2026-05-17--gstack-gsd' '${REPORT_TEMPLATE}'"
check "report template avoids raw pipe-delimited enum cells" \
  "! grep -Eq 'read\\|missing|high\\|medium|proposed\\|filed|PASS\\|FAIL' '${REPORT_TEMPLATE}'"
check "report template documents report-name override and follow-up null exception" \
  "grep -q -- '--report-name' '${REPORT_TEMPLATE}' && grep -q 'proposed_followup: null' '${REPORT_TEMPLATE}'"

echo "Block 5: candidate capture schema"
for field in id title source_axis target_area fit_score source_evidence ship_flow_baseline proposed_change hermeticity_note verification_idea proposed_followup status; do
  check "candidate field ${field} is defined" "grep -q '${field}' '${CANDIDATE_CAPTURE}'"
done
check "candidate target_area includes top-level ship skill" \
  "awk -F: '/^target_area:/ { split(\$2, parts, \"|\"); for (i in parts) { gsub(/^[[:space:]]+|[[:space:]]+$/, \"\", parts[i]); if (parts[i] == \"ship\") found=1 } } END { exit found ? 0 : 1 }' '${CANDIDATE_CAPTURE}' && grep -q 'ship-shape' '${CANDIDATE_CAPTURE}'"
check "already-owned candidates may omit follow-up draft explicitly" \
  "grep -q 'proposed_followup: null' '${CANDIDATE_CAPTURE}' && grep -q 'already-owned' '${CANDIDATE_CAPTURE}'"
check "--file-todos requires established todo frontmatter" \
  "grep -q 'tid:' '${CANDIDATE_CAPTURE}' && grep -q 'captured_at:' '${CANDIDATE_CAPTURE}' && grep -q 'status: pending' '${CANDIDATE_CAPTURE}'"
for status in proposed filed rejected already-owned; do
  check "candidate status ${status} is defined" "grep -q '${status}' '${CANDIDATE_CAPTURE}'"
done

echo "Block 6: hermeticity policy"
check "skill marks GStack/GSD as reference-only" \
  "grep -q 'reference-only' '${SKILL}' && grep -q 'GStack/GSD' '${SKILL}'"
check "skill forbids load-bearing GStack runtime references" \
  "grep -q 'MUST NOT.*~/.claude/skills/gstack/' '${SKILL}' && grep -q 'MUST NOT.*\$B' '${SKILL}' && grep -q 'MUST NOT.*\$D' '${SKILL}' && grep -q 'MUST NOT.*gstack-\\*' '${SKILL}'"
check "skill validates report-name as safe slug" \
  "grep -q -- '--report-name.*safe slug' '${SKILL}' && grep -q 'kebab-case' '${SKILL}' && grep -q 'no .*\\.\\.' '${SKILL}'"
check "skill defines report path with report-name" \
  "grep -q 'docs/ship-flow/_distillations/<yyyy-mm-dd>--<report-name>.md' '${SKILL}' && grep -q 'validated report-name' '${SKILL}'"
check "skill defines report path collision policy" \
  "grep -q 'collision' '${SKILL}' && grep -q 'must not overwrite' '${SKILL}'"
check "skill tells reports to avoid local absolute paths" \
  "grep -q 'stable source aliases' '${SKILL}' && grep -q 'local absolute' '${SKILL}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
