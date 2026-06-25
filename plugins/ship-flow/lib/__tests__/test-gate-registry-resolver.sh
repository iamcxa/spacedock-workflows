#!/usr/bin/env bash
# test-gate-registry-resolver.sh - adopter gate registry resolution for task files.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

RESOLVER="${REPO_ROOT}/plugins/ship-flow/lib/resolve-gate-registry.py"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
README="${REPO_ROOT}/docs/ship-flow/README.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"

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

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

CONFIG="${TMP_DIR}/gates.yaml"

cat > "$CONFIG" <<'YAML'
schema_version: "1.0"
gate_routes:
  - name: l5-router
    signals: [apps/deno-api/src/routers/**]
    layer: L5
    gates: [router-status-envelope, auth-tenant-guard, focused-router-spec]
    reviewer_questions: [router returns canonical status/envelope, auth and tenant guards remain load-bearing]
    evidence_required: [focused router spec output, F1 drift probe when helper wire-in changes]
  - name: l4-contract
    signals: [packages/api-contract/src/**/*.schemas.ts]
    layer: L4
    gates: [zod-strict-parse, contract-roundtrip]
    reviewer_questions: [schema remains strict and router compatible]
    evidence_required: [contract round-trip test output]
  - name: l2-domain
    signals: [domains/**/src/domain/**/*.ts]
    layer: L2
    gates: [decider-red-green, event-kind-exhaustiveness]
    reviewer_questions: [decider rejection behavior is covered before implementation]
    evidence_required: [focused domain decider spec output]
YAML

echo "=== test-gate-registry-resolver.sh ==="
echo ""

check "resolver matches L5 router files and emits gates" \
  "python3 '${RESOLVER}' --config '${CONFIG}' --files 'apps/deno-api/src/routers/service-router.ts' > '${TMP_DIR}/router.out' && grep -q '^status=ok$' '${TMP_DIR}/router.out' && grep -q '^matched_routes=l5-router$' '${TMP_DIR}/router.out' && grep -q '^layers=L5$' '${TMP_DIR}/router.out' && grep -q '^required_gates=router-status-envelope,auth-tenant-guard,focused-router-spec$' '${TMP_DIR}/router.out'"

check "resolver merges multiple matched routes with stable unique gates" \
  "python3 '${RESOLVER}' --config '${CONFIG}' --files 'apps/deno-api/src/routers/service-router.ts,packages/api-contract/src/catalog/service.schemas.ts' > '${TMP_DIR}/multi.out' && grep -q '^matched_routes=l5-router,l4-contract$' '${TMP_DIR}/multi.out' && grep -q '^layers=L5,L4$' '${TMP_DIR}/multi.out' && grep -q '^required_gates=router-status-envelope,auth-tenant-guard,focused-router-spec,zod-strict-parse,contract-roundtrip$' '${TMP_DIR}/multi.out'"

check "resolver emits reviewer questions and evidence requirements" \
  "python3 '${RESOLVER}' --config '${CONFIG}' --files 'domains/catalog/src/domain/service/decider.ts' > '${TMP_DIR}/domain.out' && grep -q '^reviewer_questions=decider rejection behavior is covered before implementation$' '${TMP_DIR}/domain.out' && grep -q '^evidence_required=focused domain decider spec output$' '${TMP_DIR}/domain.out'"

check "resolver reports no_match without failing when no route matches" \
  "python3 '${RESOLVER}' --config '${CONFIG}' --files 'docs/ship-flow/example/plan.md' > '${TMP_DIR}/none.out' && grep -q '^status=no_match$' '${TMP_DIR}/none.out' && grep -q '^required_gates=$' '${TMP_DIR}/none.out'"

check_not "resolver rejects missing gate config" \
  "python3 '${RESOLVER}' --config '${TMP_DIR}/missing-gates.yaml' --files 'apps/deno-api/src/routers/service-router.ts'"

check "missing gate config reports config_missing" \
  "! python3 '${RESOLVER}' --config '${TMP_DIR}/missing-gates.yaml' --files 'apps/deno-api/src/routers/service-router.ts' 2>'${TMP_DIR}/missing.err' && grep -q '^status=config_missing$' '${TMP_DIR}/missing.err'"

check "ship-plan documents adopter gate registry resolution into domain_acceptance_checklist" \
  "grep -q 'resolve-gate-registry.py' '${PLAN_SKILL}' && grep -q 'required_gates' '${PLAN_SKILL}' && grep -q 'domain_acceptance_checklist' '${PLAN_SKILL}'"

check "ship-verify documents required gate evidence audit" \
  "grep -q 'resolve-gate-registry.py' '${VERIFY_SKILL}' && grep -q 'required_gates' '${VERIFY_SKILL}' && grep -q 'Evidence Required' '${VERIFY_SKILL}'"

check "schema documents gate registry handoff fields" \
  "grep -q 'gate_registry' '${SCHEMA}' && grep -q 'required_gates' '${SCHEMA}' && grep -q 'evidence_required' '${SCHEMA}'"

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
