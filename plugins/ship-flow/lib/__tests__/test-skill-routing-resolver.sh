#!/usr/bin/env bash
# test-skill-routing-resolver.sh — 115.6 adopter skill-routing resolver

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
RESOLVER_SCRIPT="${SCRIPT_DIR}/../resolve-skill-routing.sh"
FIXTURE_CONFIG="${SCRIPT_DIR}/fixtures/skill-routing-resolver/skill-routing.yaml"
EXPANSION_FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/skill-routing-resolver/repo-with-matching-files"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"

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

check_stdout() {
  local desc="$1"
  local pattern="$2"
  local cmd="$3"
  local stdout_out
  stdout_out=$(eval "$cmd" 2>/dev/null || true)
  if echo "$stdout_out" | grep -qE "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (stdout did not contain '$pattern')"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

check_exit() {
  local desc="$1"
  local expected_exit="$2"
  local cmd="$3"
  local actual_exit=0
  eval "$cmd" > /dev/null 2>&1 || actual_exit=$?
  if [ "$actual_exit" -eq "$expected_exit" ]; then
    echo "  PASS: $desc (exit $expected_exit)"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (expected exit $expected_exit, got $actual_exit)"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

echo "=== test-skill-routing-resolver.sh ==="
echo ""

echo "Block 1: resolver CLI contract"
check "resolve-skill-routing.sh exists and is executable" \
  "[ -x '${RESOLVER_SCRIPT}' ]"
check_stdout "--help prints resolver name" \
  "resolve-skill-routing" \
  "\"${RESOLVER_SCRIPT}\" --help"

echo "Block 2: file signals resolve to minimal deduped skills"
check_stdout "Refine task resolves project UI skills" \
  "skills_needed=refine-expert,antd-expert,react-patterns,tailwind-expert" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='apps/refine-app/src/pages/customer-profile/list.tsx'"
check_stdout "Expo task resolves mobile skills" \
  "skills_needed=expo-rnr-nativewind,expo-accessibility,react-patterns" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='apps/expo-app/components/customer/CustomerCrmSummaryCard.tsx'"
check_stdout "Schema and migration task resolves DB skills once" \
  "skills_needed=project-db,migration-helper" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='domains/profile/src/schema/customer.table.ts,apps/supabase/migrations/001.sql'"
check_stdout "fmodel task resolves fmodel" \
  "skills_needed=fmodel" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='domains/profile/src/domain/customer/decider.ts'"
check_stdout "API task resolves ts-rest and api-guide" \
  "skills_needed=ts-rest,api-guide" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='packages/api-contract/src/admin/customer.schemas.ts,apps/deno-api/src/routers/customer-router.ts'"
check_stdout "Edge function task stays separate from migration skills" \
  "skills_needed=project-supabase-edge-functions,deno-test" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='apps/supabase/functions/customer/index.ts'"
check_stdout "Mixed task merges and dedupes skills in config order" \
  "skills_needed=refine-expert,antd-expert,react-patterns,tailwind-expert,expo-rnr-nativewind,expo-accessibility" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='apps/refine-app/src/a.tsx,apps/expo-app/components/a.tsx'"
check_stdout "Signals are not shell-expanded when matching files exist in cwd" \
  "skills_needed=refine-expert,antd-expert,react-patterns,tailwind-expert" \
  "cd '${EXPANSION_FIXTURE_ROOT}' && '${RESOLVER_SCRIPT}' --config='../skill-routing.yaml' --files='apps/refine-app/src/pages/customer-profile/list.tsx'"

echo "Block 3: no-match and missing-config behavior is explicit"
check_stdout "No matching route emits status=no_match and empty skills_needed" \
  "status=no_match" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='docs/readme.md'"
check_stdout "No matching route emits empty skills_needed" \
  "^skills_needed=$" \
  "\"${RESOLVER_SCRIPT}\" --config=\"${FIXTURE_CONFIG}\" --files='docs/readme.md'"
check_exit "Missing config exits 11" \
  11 \
  "\"${RESOLVER_SCRIPT}\" --config=\"${SCRIPT_DIR}/fixtures/skill-routing-resolver/missing.yaml\" --files='apps/refine-app/src/a.tsx'"

echo "Block 4: planner docs reference resolver"
check "ship-plan tells planner to call resolve-skill-routing.sh" \
  "grep -q 'resolve-skill-routing\\.sh' '${PLUGIN_ROOT}/skills/ship-plan/SKILL.md'"
check "skills-needed pipeline test covers adopter routing resolver" \
  "grep -q 'resolve-skill-routing.sh' '${SCRIPT_DIR}/test-skills-needed-pipeline.sh'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
exit 0
