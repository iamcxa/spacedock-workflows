#!/usr/bin/env bash
# test-carlove-adopter-smoke.sh — 113.6 pre-dogfood carlove-shaped adopter registry smoke
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-carlove-adopter-smoke.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REGISTRY_SCRIPT="${SCRIPT_DIR}/../registry-resolve.sh"
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/registry/carlove-adopter"
ADOPTER_CONFIG="${FIXTURE_DIR}/.claude/ship-flow/domains.yaml"
SPEC_FILE="${FIXTURE_DIR}/spec.md"
PATH_ONLY_FILE="${FIXTURE_DIR}/table-path-only.txt"

PASS=0
FAIL=0
ERRORS=()

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

echo "=== test-carlove-adopter-smoke.sh ==="
echo ""

echo "Block 1: carlove-shaped adopter config validates schema domain"
check_exit "plugin defaults + carlove adopter --validate --domain=schema exits 0" \
  0 \
  "\"${REGISTRY_SCRIPT}\" --validate --domain=schema --adopter-config=\"${ADOPTER_CONFIG}\""

echo "Block 2: carlove-shaped schema pitch classifies as schema"
check_stdout "carlove schema spec classifies to matched=schema" \
  "matched=schema" \
  "\"${REGISTRY_SCRIPT}\" --classify \"${SPEC_FILE}\" --adopter-config=\"${ADOPTER_CONFIG}\""
check_stdout "carlove table path-only fixture classifies to matched=schema via trigger_patterns" \
  "matched=schema" \
  "\"${REGISTRY_SCRIPT}\" --classify \"${PATH_ONLY_FILE}\" --adopter-config=\"${ADOPTER_CONFIG}\""

echo "Block 3: default schema designer anchor is preserved"
check_stdout "carlove adopter keeps designer_section_anchor=ship-design#schema-designer" \
  "designer_section_anchor=ship-design#schema-designer" \
  "\"${REGISTRY_SCRIPT}\" --domain=schema --adopter-config=\"${ADOPTER_CONFIG}\""

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
