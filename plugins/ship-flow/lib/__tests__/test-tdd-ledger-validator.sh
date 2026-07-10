#!/usr/bin/env bash
# test-tdd-ledger-validator.sh - mechanical TDD ledger gate for plan artifacts.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

VALIDATOR="${REPO_ROOT}/plugins/ship-flow/lib/validate-tdd-ledger.py"
PLAN_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
EXECUTE_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-execute/SKILL.md"
VERIFY_SKILL="${REPO_ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
SCHEMA="${REPO_ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
README="${REPO_ROOT}/docs/ship-flow/README.md"

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

POSITIVE_PLAN="${TMP_DIR}/positive-plan.md"
MATCHING_LEDGER="${TMP_DIR}/matching-tdd-ledger.jsonl"
STALE_LEDGER="${TMP_DIR}/stale-tdd-ledger.jsonl"
MISSING_PLAN="${TMP_DIR}/missing-contract-plan.md"
WEAK_COMMAND_PLAN="${TMP_DIR}/weak-command-plan.md"
META_DRIFT_PLAN="${TMP_DIR}/meta-drift-plan.md"
PROSE_PLAN="${TMP_DIR}/prose-plan.md"
NARRATIVE_PLAN="${TMP_DIR}/narrative-plan.md"
READS_ONLY_DOCS_PLAN="${TMP_DIR}/reads-only-docs-plan.md"
EMPTY_PLAN="${TMP_DIR}/empty-plan.md"

cat > "$POSITIVE_PLAN" <<'PLAN'
# Plan

### Plan

#### T0.1 — Pre-flight docs

```yaml
task_id: T0.1
layer: 5
owned_paths:
  - docs/ship-flow/example/dogfood-evidence.md
TDD: skip -- docs-only/stage-artifact task; alternate validation is grep for generated headings.
```

#### T1.1 — L5 router rejection path

```yaml
task_id: T1.1
layer: L5
owned_paths:
  - apps/deno-api/src/routers/customer-router.ts
  - apps/deno-api/src/routers/__tests__/customer-router.spec.ts
tdd_contract:
  red_command: "cd apps/deno-api && deno test src/routers/__tests__/customer-router.spec.ts"
  expected_red_failure: "new rejection-path assertion fails before router handles domain rejection events"
  green_command: "cd apps/deno-api && deno test src/routers/__tests__/customer-router.spec.ts"
  refactor_check: "cd apps/deno-api && deno test src/routers/__tests__/customer-router.spec.ts"
```
PLAN

cat > "$MISSING_PLAN" <<'PLAN'
# Plan

### Plan

#### T1.1 — L4 contract round trip

```yaml
task_id: T1.1
layer: L4
owned_paths:
  - packages/api-contract/src/admin/customer.schemas.ts
  - packages/api-contract/src/admin/__tests__/customer.contract.spec.ts
```
PLAN

cat > "$WEAK_COMMAND_PLAN" <<'PLAN'
# Plan

### Plan

#### T1.1 — L3 adapter persistence

```yaml
task_id: T1.1
layer: L3
owned_paths:
  - domains/profile/src/infrastructure/adapter/customer-view-repository.adapter.ts
tdd_contract:
  red_command: "true"
  expected_red_failure: "adapter persistence assertion fails before implementation"
  green_command: "pnpm --filter @domain/profile test src/infrastructure/adapter/__tests__/customer-view-repository.adapter.spec.ts"
  refactor_check: "pnpm --filter @domain/profile test src/infrastructure/adapter/__tests__/customer-view-repository.adapter.spec.ts"
```
PLAN

cat > "$META_DRIFT_PLAN" <<'PLAN'
# Plan

### Plan

#### T3.1 — NEW helper + router wire-ins

```yaml
task_id: T3.1
layer: meta
owned_paths:
  - apps/deno-api/src/routers/catalog-rejection-helper.ts
  - apps/deno-api/src/routers/service-router.ts
tdd_contract:
  red_command: "bash -c '! test -f apps/deno-api/src/routers/catalog-rejection-helper.ts'"
  expected_red_failure: "helper file is absent before implementation"
  green_command: "cd apps/deno-api && deno test src/routers/__tests__/service-router.spec.ts"
  refactor_check: "cd apps/deno-api && deno test src/routers/__tests__/service-router.spec.ts"
```
PLAN

cat > "$PROSE_PLAN" <<'PLAN'
# Plan

## Wave 1

#### T2.1 — L4 prose contract

**Files:**
- packages/api-contract/src/admin/customer.schemas.ts

layer: L4

RED command: pnpm --filter @pkg/api-contract test src/admin/__tests__/customer.contract.spec.ts
Expected RED failure: field parity assertion fails before schema update.
GREEN command: pnpm --filter @pkg/api-contract test src/admin/__tests__/customer.contract.spec.ts
REFACTOR check: pnpm --filter @pkg/api-contract test src/admin/__tests__/customer.contract.spec.ts
PLAN

cat > "$NARRATIVE_PLAN" <<'PLAN'
# Plan

## T3.1 SOLO critical-path warning

This section mentions T3.1, W0, and L5, but it is narrative guidance and not a
task definition.

#### T1.1 — L5 router rejection path

```yaml
task_id: T1.1
layer: L5
owned_paths:
  - apps/deno-api/src/routers/customer-router.ts
  - apps/deno-api/src/routers/__tests__/customer-router.spec.ts
tdd_contract:
  red_command: "cd apps/deno-api && deno test src/routers/__tests__/customer-router.spec.ts"
  expected_red_failure: "new rejection-path assertion fails before router handles domain rejection events"
  green_command: "cd apps/deno-api && deno test src/routers/__tests__/customer-router.spec.ts"
  refactor_check: "cd apps/deno-api && deno test src/routers/__tests__/customer-router.spec.ts"
```
PLAN

cat > "$READS_ONLY_DOCS_PLAN" <<'PLAN'
# Plan

#### T0.1 — Pre-flight recon

```yaml
task_id: T0.1
layer: meta
reads:
  - apps/deno-api/src/routers/customer-router.ts
writes:
  - docs/ship-flow/example/plan.md
TDD: skip -- pre-flight docs-only/stage-artifact recon; alternate validation is grep for stage report evidence.
```
PLAN

cat > "$EMPTY_PLAN" <<'PLAN'
# Plan

## L5 Architecture Notes

This section mentions L5 and W0 but is not a task.
PLAN

echo "=== test-tdd-ledger-validator.sh ==="
echo ""

check "validator accepts a plan with executable tdd_contract and explicit skip" \
  "python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}'"

check "validator emits JSONL ledger with L5 effective layer" \
  "python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}' --emit-jsonl | grep -q '\"layer\": \"L5\"'"

check "validator JSONL records executable command quality and no layer drift" \
  "python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}' --emit-jsonl | grep -q '\"red_command\": \"executable\"' && python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}' --emit-jsonl | grep -q '\"layer_drift\": false'"

python3 "${VALIDATOR}" --plan "${POSITIVE_PLAN}" --emit-jsonl > "${MATCHING_LEDGER}"

check "validator accepts matching persisted tdd-ledger.jsonl gate" \
  "python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}' --require-ledger-jsonl '${MATCHING_LEDGER}'"

check_not "validator rejects missing persisted tdd-ledger.jsonl gate" \
  "python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}' --require-ledger-jsonl '${TMP_DIR}/missing-tdd-ledger.jsonl'"

check "missing persisted ledger failure reports missing ledger" \
  "! python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}' --require-ledger-jsonl '${TMP_DIR}/missing-tdd-ledger.jsonl' 2>'${TMP_DIR}/missing-ledger.err' && grep -q 'tdd-ledger.jsonl missing' '${TMP_DIR}/missing-ledger.err'"

check_not "validator rejects stale persisted tdd-ledger.jsonl gate" \
  "sed 's/\"task_id\": \"T1.1\"/\"task_id\": \"T9.9\"/' '${MATCHING_LEDGER}' > '${STALE_LEDGER}' && python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}' --require-ledger-jsonl '${STALE_LEDGER}'"

check "stale persisted ledger failure reports regeneration requirement" \
  "sed 's/\"task_id\": \"T1.1\"/\"task_id\": \"T9.9\"/' '${MATCHING_LEDGER}' > '${STALE_LEDGER}' && ! python3 '${VALIDATOR}' --plan '${POSITIVE_PLAN}' --require-ledger-jsonl '${STALE_LEDGER}' 2>'${TMP_DIR}/stale-ledger.err' && grep -q 'regenerate tdd-ledger.jsonl' '${TMP_DIR}/stale-ledger.err'"

check_not "validator rejects code-bearing task missing tdd_contract" \
  "python3 '${VALIDATOR}' --plan '${MISSING_PLAN}'"

check "missing contract failure reports exact missing fields" \
  "! python3 '${VALIDATOR}' --plan '${MISSING_PLAN}' 2>'${TMP_DIR}/missing.err' && grep -q 'missing tdd_contract fields' '${TMP_DIR}/missing.err'"

check_not "validator rejects low-confidence boolean RED command" \
  "python3 '${VALIDATOR}' --plan '${WEAK_COMMAND_PLAN}'"

check "weak command failure reports low confidence" \
  "! python3 '${VALIDATOR}' --plan '${WEAK_COMMAND_PLAN}' 2>'${TMP_DIR}/weak.err' && grep -q 'red_command is low_confidence' '${TMP_DIR}/weak.err'"

check_not "validator rejects meta declaration for code-bearing L5 task" \
  "python3 '${VALIDATOR}' --plan '${META_DRIFT_PLAN}'"

check "validator accepts prose RED/GREEN fields under ## wave headings" \
  "python3 '${VALIDATOR}' --plan '${PROSE_PLAN}' && python3 '${VALIDATOR}' --plan '${PROSE_PLAN}' --emit-jsonl | grep -q '\"task_id\": \"T2.1\"'"

check "validator ignores narrative T-id mentions outside task sections" \
  "python3 '${VALIDATOR}' --plan '${NARRATIVE_PLAN}' --emit-jsonl > '${TMP_DIR}/narrative.jsonl' && grep -q '\"task_id\": \"T1.1\"' '${TMP_DIR}/narrative.jsonl' && test \"\$(wc -l < '${TMP_DIR}/narrative.jsonl' | tr -d ' ')\" = '1'"

check "validator does not infer implementation layer from read-only paths on docs-only task" \
  "python3 '${VALIDATOR}' --plan '${READS_ONLY_DOCS_PLAN}' --emit-jsonl > '${TMP_DIR}/reads-only.jsonl' && grep -q '\"applicable\": false' '${TMP_DIR}/reads-only.jsonl' && grep -q '\"inferred_layer\": \"\"' '${TMP_DIR}/reads-only.jsonl'"

check_not "validator rejects empty plan without false-matching L5 or W0 as task id" \
  "python3 '${VALIDATOR}' --plan '${EMPTY_PLAN}'"

check "ship-plan requires validate-tdd-ledger before plan handoff" \
  "grep -q 'validate-tdd-ledger.py\" --plan' '${PLAN_SKILL}' && grep -q 'tdd-ledger.jsonl' '${PLAN_SKILL}' && grep -q -- '--require-ledger-jsonl' '${PLAN_SKILL}'"

check "ship-execute consumes validated tdd-ledger rather than prose-only inference" \
  "grep -q 'tdd-ledger.jsonl' '${EXECUTE_SKILL}' && grep -q 'prose-only TDD inference' '${EXECUTE_SKILL}' && grep -q -- '--require-ledger-jsonl' '${EXECUTE_SKILL}'"

check "ship-verify audits tdd-ledger schema and layer drift" \
  "grep -q 'validate-tdd-ledger.py\" --plan' '${VERIFY_SKILL}' && grep -q 'declared_layer' '${VERIFY_SKILL}' && grep -q 'inferred_layer' '${VERIFY_SKILL}' && grep -q -- '--require-ledger-jsonl' '${VERIFY_SKILL}'"

check "schema documents tdd-ledger and layer validation fields" \
  "grep -q 'tdd_ledger' '${SCHEMA}' && grep -q 'declared_layer' '${SCHEMA}' && grep -q 'inferred_layer' '${SCHEMA}' && grep -q 'command_quality' '${SCHEMA}'"

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
