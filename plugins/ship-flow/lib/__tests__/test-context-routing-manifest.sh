#!/usr/bin/env bash
# test-context-routing-manifest.sh - context-routing-manifest contract fixtures.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

FIXTURES="${SCRIPT_DIR}/fixtures/context-routing-manifest"
REGISTRY="${REPO_ROOT}/plugins/ship-flow/lib/registry-resolve.sh"
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
  awk '
    /^## Context Routing Receipt/ { in_receipt=1; next }
    in_receipt && /^## / { in_receipt=0 }
    in_receipt && /^\|/ {
      if ($0 ~ /`schema_version: 1`/ && $0 ~ /DAC-[0-9]/) schema_version=1
      if ($0 ~ /`domain_matches: schema`/ && $0 ~ /skills_needed/ && $0 ~ /DAC-[0-9]/) domain_match=1
      if ($0 ~ /`knowledge_modules: schema`/ && $0 ~ /DAC-[0-9]/) knowledge_module=1
      if ($0 ~ /`required_skills: project-db`/ && $0 ~ /skills_needed/ && $0 ~ /DAC-[0-9]/) required_skill=1
      if ($0 ~ /`stage_hints.plan: project-db`/ && $0 ~ /Reviewer questions/ && $0 ~ /DAC-[0-9]/) stage_hint=1
      if ($0 ~ /`consumer_obligations.plan`/ && $0 ~ /reviewer_questions/ && $0 ~ /DAC-[0-9]/) consumer_obligation=1
    }
    END { exit !(schema_version && domain_match && knowledge_module && required_skill && stage_hint && consumer_obligation) }
  ' "$file"
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

registry_manifest() {
  "${REGISTRY}" --domain=empty_lists \
    --config="${FIXTURES}/registry-empty-lists/defaults.yaml" \
    --context-routing-manifest
}

manifest_has_line() {
  local expected="$1"
  registry_manifest | awk -v expected="$expected" '$0 == expected { found=1 } END { exit !found }'
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

check_not "plan-loose-receipt is rejected when rows do not map receipt table" \
  "has_receipt_for_manifest '${FIXTURES}/plan-loose-receipt/plan.md'"

check "registry manifest emits typed empty knowledge_modules list" \
  "manifest_has_line '  knowledge_modules: []'"

check "registry manifest emits typed empty required_skills list" \
  "manifest_has_line '  required_skills: []'"

check "registry manifest emits typed empty stage hint lists" \
  "manifest_has_line '    plan: []' && manifest_has_line '    execute: []' && manifest_has_line '    verify: []'"

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
  "grep -q 'extract-section.sh\" <plan.md> context-routing-manifest' '${VERIFY_SKILL}' && grep -q 'prose-only inference' '${VERIFY_SKILL}'"

check "fallback reviewer panel preserves context routing manifest lens fields" \
  "grep -q 'context-routing-manifest' '${REVIEWER_PANEL}' && grep -q 'manifest_required_skill' '${REVIEWER_PANEL}'"

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
