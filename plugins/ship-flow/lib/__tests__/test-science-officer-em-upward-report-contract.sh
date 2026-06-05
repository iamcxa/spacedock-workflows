#!/usr/bin/env bash
# Contract test for 130.3 Science Officer (EM) upward reports.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"
VALIDATOR="${ROOT}/plugins/ship-flow/lib/science-officer-em-upward-report.mjs"
RENDERER="${ROOT}/plugins/ship-flow/lib/render-science-officer-em-upward-report-contract.sh"

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

node_check() {
  local desc="$1"
  local script="$2"
  if printf '%s\n' "$script" | node --input-type=module > /dev/null 2>&1; then
    echo "PASS: ${desc}"
    PASS=$((PASS + 1))
  else
    echo "FAIL: ${desc}"
    FAIL=$((FAIL + 1))
  fi
}

echo "=== Science Officer (EM) upward report contract ==="

check "validator module exists" "test -f '$VALIDATOR'"
check "renderer exists and is executable" "test -x '$RENDERER'"

node_check "valid report passes" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const result = validateScienceOfficerEmUpwardReport({
    science_officer_em_upward_report: {
      subject: { entity: '130.3-em-upward-judgment-report-contract', stage: 'verify', report_kind: 'verify-synthesis' },
      em_judgment: 'Proceed: the tested output shape now carries independent EM judgment rather than FO status relay.',
      evidence_synthesis: [
        'V1: contract fixture rejects status-only relay and worker digest.',
        'V2: verify/review/ship surfaces name route, confidence, risk, and FO boundary.'
      ],
      risk_tradeoff_call: 'Residual risk is limited to wording drift because enforcement is structural and fixture-backed.',
      recommendation: 'FO should advance to verify and ask the panel to inspect report output shape.',
      route: 'proceed',
      confidence: 'high',
      fo_boundary: 'FO owns workflow mechanics; EM owns judgment and recommendation.'
    }
  });
  if (!result.valid) throw new Error(result.errors.join('; '));
"

node_check "valid report can use green state as evidence" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const result = validateScienceOfficerEmUpwardReport({
    science_officer_em_upward_report: {
      subject: { entity: '130.3-em-upward-judgment-report-contract', stage: 'verify', report_kind: 'verify-synthesis' },
      em_judgment: 'Proceed: the validator change preserves judgment-bearing reports while allowing green gate state as one evidence input.',
      evidence_synthesis: [
        'V2 command output: upward report surfaces test returned 34 passed, 0 failed.',
        'verify.md Panel Coverage reviewer finding: all green, no blockers after output-shape review.'
      ],
      risk_tradeoff_call: 'Residual risk is acceptable because green/no-blocker text is evidence, not the EM judgment itself.',
      recommendation: 'FO should continue verify review and keep inspecting the structured report fields.',
      route: 'proceed',
      confidence: 'high',
      fo_boundary: 'FO owns workflow mechanics; EM owns judgment and recommendation.'
    }
  });
  if (!result.valid) throw new Error(result.errors.join('; '));
"

node_check "status-only relay fails" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const result = validateScienceOfficerEmUpwardReport({
    science_officer_em_upward_report: {
      status: 'passed',
      checklist: ['all green', 'no blockers']
    }
  });
  if (result.valid) throw new Error('status relay passed');
  if (!result.errors.some((error) => /em_judgment/.test(error))) throw new Error(result.errors.join('; '));
"

node_check "worker digest fails" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const result = validateScienceOfficerEmUpwardReport({
    science_officer_em_upward_report: {
      subject: { entity: '130.3', stage: 'execute', report_kind: 'stage-handoff' },
      em_judgment: 'Workers completed tasks and reviewers passed.',
      evidence_synthesis: ['worker said done', 'reviewer said pass'],
      risk_tradeoff_call: 'No blockers.',
      recommendation: 'Advance stage.',
      route: 'proceed',
      confidence: 'high',
      fo_boundary: 'FO can advance.'
    }
  });
  if (result.valid) throw new Error('worker digest passed');
  if (!result.errors.some((error) => /relay|digest|independent/i.test(error))) throw new Error(result.errors.join('; '));
"

node_check "weak evidence without source substance fails" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const result = validateScienceOfficerEmUpwardReport({
    science_officer_em_upward_report: {
      subject: { entity: '130.3', stage: 'verify', report_kind: 'verify-synthesis' },
      em_judgment: 'Proceed because the work appears acceptable.',
      evidence_synthesis: ['Reviewed the thing.', 'Looks adequate.'],
      risk_tradeoff_call: 'Risk appears low.',
      recommendation: 'Continue.',
      route: 'proceed',
      confidence: 'medium',
      fo_boundary: 'FO owns workflow mechanics; EM owns judgment and recommendation.'
    }
  });
  if (result.valid) throw new Error('weak evidence passed');
  if (!result.errors.some((error) => /evidence_synthesis|source|substance/i.test(error))) throw new Error(result.errors.join('; '));
"

node_check "weak evidence magic words and arbitrary filenames fail" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const weakEvidenceSets = [
    ['Review passed.', 'Tests passed.'],
    ['Check OK.', 'Finding clear.'],
    ['Test passed.', 'Review passed.'],
    ['Looked at notes.md.', 'Checked output.txt.']
  ];
  for (const evidence_synthesis of weakEvidenceSets) {
    const result = validateScienceOfficerEmUpwardReport({
      science_officer_em_upward_report: {
        subject: { entity: '130.3', stage: 'verify', report_kind: 'verify-synthesis' },
        em_judgment: 'Proceed because the report appears acceptable.',
        evidence_synthesis,
        risk_tradeoff_call: 'Risk appears low.',
        recommendation: 'Continue verify.',
        route: 'proceed',
        confidence: 'medium',
        fo_boundary: 'FO owns workflow mechanics; EM owns judgment and recommendation.'
      }
    });
    if (result.valid) throw new Error('weak evidence passed: ' + evidence_synthesis.join(' / '));
    if (!result.errors.some((error) => /evidence_synthesis|source|substance/i.test(error))) throw new Error(result.errors.join('; '));
  }
"

node_check "missing route fails" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const result = validateScienceOfficerEmUpwardReport({
    science_officer_em_upward_report: {
      subject: { entity: '130.3', stage: 'review', report_kind: 'review-closeout' },
      em_judgment: 'Return because the evidence does not prove output shape.',
      evidence_synthesis: ['review.md lacks report block', 'V2 surface test is absent'],
      risk_tradeoff_call: 'Advancing would make verify inspect the wrong surface.',
      recommendation: 'Return to execute for report wiring.',
      confidence: 'medium',
      fo_boundary: 'FO owns workflow mechanics; EM owns judgment and recommendation.'
    }
  });
  if (result.valid) throw new Error('missing route passed');
  if (!result.errors.some((error) => /route/.test(error))) throw new Error(result.errors.join('; '));
"

node_check "FO-owned mechanics report fails" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const result = validateScienceOfficerEmUpwardReport({
    science_officer_em_upward_report: {
      subject: { entity: '130.3', stage: 'ship', report_kind: 'ship-summary' },
      em_judgment: 'Proceed and have EM advance status, create PR, dispatch workers, and merge.',
      evidence_synthesis: ['V1 passed', 'V2 passed'],
      risk_tradeoff_call: 'Mechanics can be owned by EM.',
      recommendation: 'EM should mutate entity status and create the PR.',
      route: 'proceed',
      confidence: 'high',
      fo_boundary: 'EM owns worktrees and stage advancement.'
    }
  });
  if (result.valid) throw new Error('FO mechanics report passed');
  if (!result.errors.some((error) => /FO-owned|workflow mechanics|stage advancement/i.test(error))) throw new Error(result.errors.join('; '));
"

node_check "FO-owned mechanics responsibility wording fails" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const result = validateScienceOfficerEmUpwardReport({
    science_officer_em_upward_report: {
      subject: { entity: '130.3', stage: 'ship', report_kind: 'ship-summary' },
      em_judgment: 'Proceed because the report shape is otherwise complete.',
      evidence_synthesis: ['V1 command output: 12 passed, 0 failed.', 'PR #207 reviewer finding: no blocking validator gaps remain.'],
      risk_tradeoff_call: 'Mechanics responsibility wording would blur FO and EM ownership.',
      recommendation: 'Reject the report until FO-owned mechanics are removed from EM responsibility.',
      route: 'return',
      confidence: 'high',
      fo_boundary: 'FO owns workflow mechanics; EM owns judgment and recommendation. EM is responsible for PR creation and merge coordination.'
    }
  });
  if (result.valid) throw new Error('FO mechanics responsibility report passed');
  if (!result.errors.some((error) => /FO-owned|workflow mechanics|PR|merge/i.test(error))) throw new Error(result.errors.join('; '));
"

node_check "FO-owned mechanics role aliases and verbs fail" "
  import { validateScienceOfficerEmUpwardReport } from '$VALIDATOR';
  const boundaryClauses = [
    'FO owns workflow mechanics; EM owns judgment and recommendation. EM handles PR creation and merge coordination.',
    'FO owns workflow mechanics; EM owns judgment and recommendation. EM is assigned to PR creation and merge coordination.',
    'FO owns workflow mechanics; EM owns judgment and recommendation. Science Officer is responsible for PR creation and merge coordination.',
    'FO owns workflow mechanics; EM owns judgment and recommendation. Engineering manager owns PR creation and merge coordination.'
  ];
  for (const fo_boundary of boundaryClauses) {
    const result = validateScienceOfficerEmUpwardReport({
      science_officer_em_upward_report: {
        subject: { entity: '130.3', stage: 'ship', report_kind: 'ship-summary' },
        em_judgment: 'Proceed because the report shape is otherwise complete.',
        evidence_synthesis: ['V1 command output: 15 passed, 0 failed.', 'PR #207 reviewer finding: no blocking validator gaps remain.'],
        risk_tradeoff_call: 'Mechanics wording would blur FO and EM ownership.',
        recommendation: 'Reject the report until FO-owned mechanics are removed from EM responsibility.',
        route: 'return',
        confidence: 'high',
        fo_boundary
      }
    });
    if (result.valid) throw new Error('FO mechanics alias report passed: ' + fo_boundary);
    if (!result.errors.some((error) => /FO-owned|workflow mechanics|PR|merge/i.test(error))) throw new Error(result.errors.join('; '));
  }
"

contract="$("$RENDERER" 2>/dev/null || true)"
check "renderer emits contract heading" "grep -q '^### Science Officer (EM) Upward Report Contract$' <<<\"\$contract\""
check "renderer names required fields" "grep -q 'em_judgment' <<<\"\$contract\" && grep -q 'evidence_synthesis' <<<\"\$contract\" && grep -q 'risk_tradeoff_call' <<<\"\$contract\" && grep -q 'recommendation' <<<\"\$contract\" && grep -q 'route' <<<\"\$contract\" && grep -q 'confidence' <<<\"\$contract\" && grep -q 'fo_boundary' <<<\"\$contract\""
check "renderer emits route enum" "grep -q 'proceed' <<<\"\$contract\" && grep -q 'narrow' <<<\"\$contract\" && grep -q 'return' <<<\"\$contract\" && grep -q 'block' <<<\"\$contract\" && grep -q 'costly_no' <<<\"\$contract\""
check "renderer rejects relay and self-attestation" "grep -qi 'status-only relay' <<<\"\$contract\" && grep -qi 'worker self-attestation' <<<\"\$contract\""
check "renderer preserves FO/EM boundary" "grep -q 'FO owns workflow mechanics' <<<\"\$contract\" && grep -q 'EM owns judgment and recommendation' <<<\"\$contract\""

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  exit 1
fi
