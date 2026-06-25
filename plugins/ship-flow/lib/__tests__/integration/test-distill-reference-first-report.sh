#!/usr/bin/env bash
# test-distill-reference-first-report.sh — first GStack/GSD report contract.
# HOST ARTIFACTS: docs/ship-flow/ entities, .claude/settings.json, or plugins/spacebridge/ — not present in standalone clone.
# Run only from the dogfood host project. See lib/__tests__/integration/README.md

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
REPORT="${REPO_ROOT}/docs/ship-flow/_distillations/2026-05-17--gstack-gsd.md"
ACTIVE_ENTITY="${REPO_ROOT}/docs/ship-flow/distill-reference-skill-meta-capability.md"
ARCHIVED_ENTITY="${REPO_ROOT}/docs/ship-flow/_archive/distill-reference-skill-meta-capability.md"
if [ -f "${ACTIVE_ENTITY}" ]; then
  ENTITY="${ACTIVE_ENTITY}"
else
  ENTITY="${ARCHIVED_ENTITY}"
fi

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

check_each_candidate_has_field() {
  local field="$1"
  if awk -v field="${field}:" '
    /^### Candidate:/ {
      if (in_block && !found) {
        exit 1
      }
      in_block=1
      found=0
      count++
      next
    }
    in_block && /^## / {
      if (!found) {
        exit 1
      }
      in_block=0
    }
    in_block && index($0, field) {
      found=1
    }
    END {
      if (count == 0) {
        exit 1
      }
      if (in_block && !found) {
        exit 1
      }
    }
  ' "${REPORT}" > /dev/null 2>&1; then
    echo "  PASS: every candidate block includes ${field}"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: every candidate block includes ${field}"
    FAIL=$((FAIL + 1))
    ERRORS+=("every candidate block includes ${field}")
  fi
}

echo "=== test-distill-reference-first-report.sh ==="
echo ""

echo "Block 1: report structure"
check "first GStack/GSD report exists" \
  "test -f '${REPORT}'"
for section in "Source Identity" "Source Availability" "Source Read List" "Target Map" "Comparison Axes" "Gap Scoring" "Candidates" "Rejected Imports" "Follow-up Status" "Hermeticity Audit"; do
  check "report includes ${section}" "grep -q '## ${section}' '${REPORT}'"
done

echo "Block 2: source availability"
check "report names targeted GStack source family" \
  "grep -q 'GStack plan/review/QA/design-review' '${REPORT}'"
check "report names targeted GSD UI source family" \
  "grep -q 'gsd-ui' '${REPORT}'"
check "report records GSD UI source availability, not inferred findings" \
  "grep -Eq 'gsd-ui.*(missing|unavailable|source_unavailable)' '${REPORT}' && grep -q 'Do not infer' '${REPORT}'"
check "report lists ship-flow-owned snapshots" \
  "grep -q 'plugins/ship-flow/lib/review-checklists/' '${REPORT}' && grep -q 'plugins/ship-flow/lib/design-methodology/' '${REPORT}'"

echo "Block 3: candidate capture"
candidate_count="$(grep -c '^### Candidate' "${REPORT}" 2>/dev/null || true)"
check "report includes at least three candidate sections" \
  "test '${candidate_count}' -ge 3"
for field in target_area fit_score source_evidence ship_flow_baseline proposed_change hermeticity_note proposed_followup; do
  check_each_candidate_has_field "${field}"
done
check_each_candidate_has_field "verification_idea"
check "already-owned candidate has no fake follow-up slug" \
  "! grep -q 'slug: none' '${REPORT}' && grep -q 'proposed_followup: null' '${REPORT}'"

echo "Block 3b: evidence hygiene"
check "target map evidence uses auditable path-line references" \
  "awk -F'|' '/^## Target Map$/{in_map=1; next} in_map && /^## /{in_map=0} in_map && /^\\|/ && \$2 ~ /plugins\\/ship-flow\\// { if (\$4 !~ /:[0-9]+/) bad=1 } END{exit bad ? 1 : 0}' '${REPORT}'"
check "source read list evidence uses auditable path-line references" \
  "awk -F'|' '/^## Source Read List$/{in_list=1; next} in_list && /^## /{in_list=0} in_list && /^\\|/ && \$2 ~ /gstack:/ { if (\$4 !~ /:[0-9]+/) bad=1 } END{exit bad ? 1 : 0}' '${REPORT}'"
check "report avoids local absolute maintainer paths" \
  "! grep -q '/Users/kent' '${REPORT}'"

echo "Block 4: reusable capability split"
check "first report is an instance, not the reusable skill contract" \
  "grep -q 'report_instance: first-gstack-gsd' '${REPORT}' && grep -q 'reusable_skill: plugins/ship-flow/skills/distill-reference/SKILL.md' '${REPORT}'"
check "report marks duplicated snapshots as already-owned or rejected imports" \
  "grep -q 'already-owned' '${REPORT}' && grep -q 'Rejected Imports' '${REPORT}'"
check "entity frontmatter includes dashboard id" \
  "awk 'BEGIN{in_fm=0} /^---$/{in_fm++; next} in_fm==1 && /^id:[[:space:]]*\"?129\"?/ {found=1} END{exit found ? 0 : 1}' '${ENTITY}'"
check "entity resolves from active or archived location" \
  "test -f '${ENTITY}'"
check "entity stage notes avoid local absolute maintainer paths" \
  "! grep -q '/Users/kent' '${ENTITY}'"

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
