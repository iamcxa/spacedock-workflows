#!/usr/bin/env bash
# test-registry-resolve.sh — DC-2 runner for #113.2 domain-registry-skill
# Tests lib/registry-resolve.sh: happy path + M1-M5 degradation surfaces + adopter override
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-registry-resolve.sh
#
# Expected before T2.1 (RED): all assertions fail (script absent)
# Expected after T2.1+T2.2 (GREEN): all assertions pass

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REGISTRY_SCRIPT="${SCRIPT_DIR}/../registry-resolve.sh"
FIXTURES="${SCRIPT_DIR}/fixtures/registry"

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

# check_exit: assert command exits with specific code
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

# check_stderr: assert stderr contains pattern
check_stderr() {
  local desc="$1"
  local pattern="$2"
  local cmd="$3"
  local stderr_out
  stderr_out=$(eval "$cmd" 2>&1 >/dev/null || true)
  if echo "$stderr_out" | grep -qE "$pattern"; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc (stderr did not contain '$pattern')"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

# check_stdout: assert stdout contains pattern
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

echo "=== registry-resolve.sh assertions (DC-2, #113.2) ==="
echo ""

# Assertion 1: script exists and is executable
check "script exists at lib/registry-resolve.sh and is executable" \
  "test -x \"$REGISTRY_SCRIPT\""

# Assertion 2: --help flag prints usage including 'registry-resolve'
check_stdout "--help flag prints usage containing 'registry-resolve'" \
  "registry-resolve" \
  "\"$REGISTRY_SCRIPT\" --help"

# Assertion 3: --list happy-path returns schema domain
check_stdout "--list with happy-path config returns 'schema' domain" \
  "^schema" \
  "\"$REGISTRY_SCRIPT\" --list --config=\"${FIXTURES}/happy-path/defaults.yaml\""

# Assertion 4: --classify happy-path spec returns matched domain 'schema'
check_stdout "--classify happy-path spec.md returns matched=schema" \
  "matched=schema" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/happy-path/spec.md\" --config=\"${FIXTURES}/happy-path/defaults.yaml\""

# Assertion 5: M1 path — exit 10 + stderr specialist_missing
check_exit "M1: --validate with missing specialist anchor exits 10" \
  10 \
  "\"$REGISTRY_SCRIPT\" --validate --domain=schema --config=\"${FIXTURES}/m1-specialist-missing/defaults.yaml\""

check_stderr "M1: stderr contains status=specialist_missing" \
  "status=specialist_missing" \
  "\"$REGISTRY_SCRIPT\" --validate --domain=schema --config=\"${FIXTURES}/m1-specialist-missing/defaults.yaml\""

# Assertion 6: M2 path — exit 11 + stderr knowledge_module_missing
check_exit "M2: --validate with missing knowledge module exits 11" \
  11 \
  "\"$REGISTRY_SCRIPT\" --validate --domain=schema --config=\"${FIXTURES}/m2-knowledge-missing/defaults.yaml\""

check_stderr "M2: stderr contains status=knowledge_module_missing" \
  "status=knowledge_module_missing" \
  "\"$REGISTRY_SCRIPT\" --validate --domain=schema --config=\"${FIXTURES}/m2-knowledge-missing/defaults.yaml\""

# Assertion 7: M3 path — exit 0 + stdout partial_coverage + missing=saga
check_exit "M3: --classify with partial domain coverage exits 0" \
  0 \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/m3-partial-coverage/spec.md\" --config=\"${FIXTURES}/m3-partial-coverage/defaults.yaml\""

check_stdout "M3: stdout contains partial_coverage" \
  "partial_coverage" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/m3-partial-coverage/spec.md\" --config=\"${FIXTURES}/m3-partial-coverage/defaults.yaml\""

check_stdout "M3: stdout contains missing=saga" \
  "missing=.*saga" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/m3-partial-coverage/spec.md\" --config=\"${FIXTURES}/m3-partial-coverage/defaults.yaml\""

# Assertion 8: M4 path — exit 20 + stderr parse_error
check_exit "M4: malformed YAML config exits 20" \
  20 \
  "\"$REGISTRY_SCRIPT\" --validate --config=\"${FIXTURES}/m4-parse-error/defaults.yaml\""

check_stderr "M4: stderr contains parse_error" \
  "parse_error" \
  "\"$REGISTRY_SCRIPT\" --validate --config=\"${FIXTURES}/m4-parse-error/defaults.yaml\""

# Assertion 9: M5 path — exit 21 + stderr invalid_trigger_config
check_exit "M5: empty trigger_patterns AND spec_keywords exits 21" \
  21 \
  "\"$REGISTRY_SCRIPT\" --validate --config=\"${FIXTURES}/m5-invalid-trigger/defaults.yaml\""

check_stderr "M5: stderr contains invalid_trigger_config" \
  "invalid_trigger_config" \
  "\"$REGISTRY_SCRIPT\" --validate --config=\"${FIXTURES}/m5-invalid-trigger/defaults.yaml\""

# Assertion 10: adopter override — returned anchor matches project override, not plugin default
check_stdout "adopter override: --domain=schema returns adopter anchor (not plugin default)" \
  "designer_section_anchor=ship-design#adopter-project-schema-designer" \
  "\"$REGISTRY_SCRIPT\" --domain=schema --config=\"${FIXTURES}/adopter-override/defaults.yaml\" --adopter-config=\"${FIXTURES}/adopter-override/project-domains.yaml\""

# --- Summary ---
echo ""
echo "Results: $PASS passed, $FAIL failed"
if [ $FAIL -gt 0 ]; then
  echo ""
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "All assertions passed — registry-resolve DC-2 verified."
exit 0
