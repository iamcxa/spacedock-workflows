#!/usr/bin/env bash
# test-context-routing-manifest.sh - context-routing-manifest contract fixtures.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

FIXTURES="${SCRIPT_DIR}/fixtures/context-routing-manifest"
EXTRACT="${REPO_ROOT}/plugins/ship-flow/lib/extract-section.sh"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
REVIEWER_PANEL="${REPO_ROOT}/plugins/ship-flow/skills/verify-reviewer-panel/SKILL.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
README="${REPO_ROOT}/docs/ship-flow/README.md"
PRODUCT="${REPO_ROOT}/PRODUCT.md"
ARCHITECTURE="${REPO_ROOT}/ARCHITECTURE.md"

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

check_not() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

count_section_open() {
  local file="$1"
  grep -c '<!-- section:context-routing-manifest -->' "$file"
}

count_section_close() {
  local file="$1"
  grep -c '<!-- /section:context-routing-manifest -->' "$file"
}

has_receipt_for_manifest() {
  local file="$1"
  grep -q '^## Context Routing Receipt' "$file" &&
    grep -q 'domain_matches:' "$file" &&
    grep -q 'required_skills:' "$file" &&
    grep -q 'domain_acceptance_checklist' "$file"
}

has_verify_manifest_lens() {
  local file="$1"
  grep -q '^### Verify Check Manifest' "$file" &&
    grep -q 'context-routing-manifest extraction: present' "$file" &&
    grep -q 'manifest_required_skill:' "$file"
}

extraction_has_manifest_root() {
  local file="$1"
  local extracted
  extracted="$("${EXTRACT}" "$file" context-routing-manifest)"
  printf '%s\n' "$extracted" | grep -q '^context-routing-manifest:'
}

echo "=== test-context-routing-manifest.sh ==="
echo ""

check "plan-positive has exactly one context-routing-manifest opening tag" \
  "test \"\$(count_section_open '${FIXTURES}/plan-positive/plan.md')\" -eq 1"

check "plan-positive has exactly one context-routing-manifest closing tag" \
  "test \"\$(count_section_close '${FIXTURES}/plan-positive/plan.md')\" -eq 1"

check "plan-positive extraction returns context-routing-manifest root" \
  "extraction_has_manifest_root '${FIXTURES}/plan-positive/plan.md'"

check "plan-positive receipt maps manifest rows to handoff checklist" \
  "has_receipt_for_manifest '${FIXTURES}/plan-positive/plan.md'"

check_not "plan-missing-receipt is rejected by receipt validator" \
  "has_receipt_for_manifest '${FIXTURES}/plan-missing-receipt/plan.md'"

check "verify-positive plan extraction returns context-routing-manifest root" \
  "extraction_has_manifest_root '${FIXTURES}/verify-positive/plan.md'"

check "verify-positive verify manifest maps extracted row to review lens" \
  "has_verify_manifest_lens '${FIXTURES}/verify-positive/verify.md'"

check_not "verify-empty-extraction plan is rejected by extraction guard" \
  "extraction_has_manifest_root '${FIXTURES}/verify-empty-extraction/plan.md'"

check_not "verify-prose-only evidence is rejected by manifest lens validator" \
  "has_verify_manifest_lens '${FIXTURES}/verify-prose-only/verify.md'"

check "ship-plan requires exactly one standalone context-routing-manifest section" \
  "grep -q 'context-routing-manifest' '${PLAN_SKILL}' && grep -q 'Context Routing Receipt' '${PLAN_SKILL}' && grep -q 'exactly one standalone' '${PLAN_SKILL}'"

check "schema describes plan context routing receipt and manifest block" \
  "grep -q 'context_routing_manifest' '${SCHEMA}' && grep -q 'Context Routing Receipt' '${SCHEMA}' && grep -q 'future_provider_boundary' '${SCHEMA}'"

check "ship-verify requires extracted context-routing-manifest input" \
  "grep -q 'extract-section.sh <plan.md> context-routing-manifest' '${VERIFY_SKILL}' && grep -q 'prose-only inference' '${VERIFY_SKILL}'"

check "fallback reviewer panel preserves context routing manifest lens fields" \
  "grep -q 'context-routing-manifest' '${REVIEWER_PANEL}' && grep -q 'manifest_required_skill' '${REVIEWER_PANEL}'"

check "README documents context-routing-manifest contract" \
  "grep -q 'context-routing-manifest' '${README}' && grep -q 'Context Routing Receipt' '${README}' && grep -q 'prose-only' '${README}'"

check "PRODUCT documents deterministic local context routing capability" \
  "grep -q 'deterministic local context router' '${PRODUCT}' && grep -q 'context-routing-manifest' '${PRODUCT}'"

check "ARCHITECTURE documents local registry authority and append-only providers" \
  "grep -q 'local registry remains authoritative' '${ARCHITECTURE}' && grep -q 'append-only' '${ARCHITECTURE}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
