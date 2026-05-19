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
CONTEXT_FIXTURES="${SCRIPT_DIR}/fixtures/context-routing-manifest"

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
check_stdout "--classify happy-path shape.md returns matched=schema" \
  "matched=schema" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/happy-path/shape.md\" --config=\"${FIXTURES}/happy-path/defaults.yaml\""

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
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/m3-partial-coverage/shape.md\" --config=\"${FIXTURES}/m3-partial-coverage/defaults.yaml\""

check_stdout "M3: stdout contains partial_coverage" \
  "partial_coverage" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/m3-partial-coverage/shape.md\" --config=\"${FIXTURES}/m3-partial-coverage/defaults.yaml\""

check_stdout "M3: stdout contains missing=saga" \
  "missing=.*saga" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/m3-partial-coverage/shape.md\" --config=\"${FIXTURES}/m3-partial-coverage/defaults.yaml\""

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

# Assertion 11: adopter override — project-level skill routing fields are emitted
check_stdout "adopter override: --domain=schema emits required_skills from project registry" \
  "required_skills=project-db,fmodel" \
  "\"$REGISTRY_SCRIPT\" --domain=schema --config=\"${FIXTURES}/adopter-override/defaults.yaml\" --adopter-config=\"${FIXTURES}/adopter-override/project-domains.yaml\""

check_stdout "adopter override: --domain=schema emits plan skill_hints from project registry" \
  "skill_hints.plan=project-db,fmodel" \
  "\"$REGISTRY_SCRIPT\" --domain=schema --config=\"${FIXTURES}/adopter-override/defaults.yaml\" --adopter-config=\"${FIXTURES}/adopter-override/project-domains.yaml\""

check_stdout "adopter override: --classify emits required_skills for matched domain" \
  "required_skills=project-db,fmodel" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/happy-path/shape.md\" --config=\"${FIXTURES}/adopter-override/defaults.yaml\" --adopter-config=\"${FIXTURES}/adopter-override/project-domains.yaml\""

check_stdout "adopter override: --classify emits stage skill_hints for matched domain" \
  "skill_hints.execute=fmodel" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/happy-path/shape.md\" --config=\"${FIXTURES}/adopter-override/defaults.yaml\" --adopter-config=\"${FIXTURES}/adopter-override/project-domains.yaml\""

# Assertion 12: live plugin defaults now expose the schema-designer specialist (113.3)
check_exit "live defaults: schema domain validates with specialist anchor present" \
  0 \
  "\"$REGISTRY_SCRIPT\" --validate --domain=schema"

check_stdout "live defaults: schema domain resolves to ship-design#schema-designer" \
  "designer_section_anchor=ship-design#schema-designer" \
  "\"$REGISTRY_SCRIPT\" --domain=schema"

check "live defaults: list exposes portable contract/interface domains" \
  "missing=0; for dom in agent-contract api-vocabulary selector-grammar tool-protocol dsl message-format; do \"$REGISTRY_SCRIPT\" --list | grep -qx \"\$dom\" || missing=1; done; [ \"\$missing\" -eq 0 ]"

check_stdout "live defaults: selector-grammar resolves to contract-interface designer anchor" \
  "designer_section_anchor=ship-design#contract-interface-designer" \
  "\"$REGISTRY_SCRIPT\" --domain=selector-grammar"

check "live defaults: all portable contract domains use contract-interface designer anchor" \
  "missing=0; for dom in agent-contract api-vocabulary selector-grammar tool-protocol dsl message-format; do out=\$(\"$REGISTRY_SCRIPT\" --domain=\"\$dom\"); case \"\$out\" in *designer_section_anchor=ship-design#contract-interface-designer*) ;; *) missing=1 ;; esac; done; [ \"\$missing\" -eq 0 ]"

check_stdout "live defaults: selector grammar fixture classifies as selector-grammar" \
  "matched=selector-grammar" \
  "\"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/contract-domains/selector-grammar.md\""

check "live defaults: selector grammar fixture does not match schema" \
  "! \"$REGISTRY_SCRIPT\" --classify \"${FIXTURES}/contract-domains/selector-grammar.md\" | grep -q 'matched=.*schema'"

check_stdout "context manifest: --domain emits typed context-routing-manifest envelope" \
  "^context-routing-manifest:" \
  "\"$REGISTRY_SCRIPT\" --domain=schema --context-routing-manifest --config=\"${CONTEXT_FIXTURES}/registry-positive/defaults.yaml\""

check_stdout "context manifest: domain output preserves local registry rows" \
  "authoritative_for_routing: true" \
  "\"$REGISTRY_SCRIPT\" --domain=schema --context-routing-manifest --config=\"${CONTEXT_FIXTURES}/registry-positive/defaults.yaml\""

check_stdout "context manifest: classify preserves matched domain and required skills" \
  "skill: project-db" \
  "\"$REGISTRY_SCRIPT\" --classify \"${CONTEXT_FIXTURES}/registry-positive/shape.md\" --context-routing-manifest --config=\"${CONTEXT_FIXTURES}/registry-positive/defaults.yaml\""

check_stdout "context manifest: future provider hints are optional append-only" \
  "status: optional_append_only" \
  "\"$REGISTRY_SCRIPT\" --classify \"${CONTEXT_FIXTURES}/registry-positive/shape.md\" --context-routing-manifest --config=\"${CONTEXT_FIXTURES}/registry-positive/defaults.yaml\""

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
