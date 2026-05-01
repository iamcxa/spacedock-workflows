#!/usr/bin/env bash
# test-adopter-skill-discovery.sh — 115.5 adopter-level skill routing discovery

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
DISCOVERY_SCRIPT="${SCRIPT_DIR}/../discover-adopter-skills.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/adopter-skill-discovery/carlove-like"
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

echo "=== test-adopter-skill-discovery.sh ==="
echo ""

echo "Block 1: helper exists and emits a machine-readable routing envelope"
check "discover-adopter-skills.sh exists and is executable" \
  "[ -x '${DISCOVERY_SCRIPT}' ]"
check_stdout "output declares skill_routing schema version" \
  "^schema_version: \"1.0\"" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""
check_stdout "output records source as discovered" \
  "source: discovered" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""

echo "Block 2: carlove-like stack surfaces route to adopter project skills"
check_stdout "Refine web files route to refine/gotchas/antd/react/tailwind skills" \
  "skills: \\[refine-expert, refine-gotchas, antd-expert, react-patterns, tailwind-expert\\]" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""
check_stdout "Expo mobile files route to expo/nativewind/accessibility skills" \
  "skills: \\[expo-rnr-nativewind, expo-accessibility, react-patterns\\]" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""
check_stdout "Supabase migration/schema files route to project-db and migration-helper" \
  "skills: \\[project-db, migration-helper\\]" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""
check_stdout "fmodel files route to fmodel" \
  "skills: \\[fmodel\\]" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""
check_stdout "ts-rest contract/router files route to ts-rest and api-guide" \
  "skills: \\[ts-rest, api-guide\\]" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""
check_stdout "Supabase edge functions route separately from plain migrations" \
  "skills: \\[project-supabase-edge-functions, deno-test\\]" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""

echo "Block 3: output is suitable for adopter config"
check_stdout "output names the target adopter config path" \
  "target_path: .claude/ship-flow/skill-routing.yaml" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""
check_stdout "output keeps domain registry separate from surface routing" \
  "boundary: domain registry required_skills stay in domains.yaml; file-signal skills live here" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${FIXTURE_ROOT}\""

echo "Block 4: stage skills wire discovery into adopt/shape/plan"
check "ship-onboard instructs first-time adopters to run discover-adopter-skills.sh" \
  "grep -q 'discover-adopter-skills\\.sh' '${PLUGIN_ROOT}/skills/ship-onboard/SKILL.md'"
check "ship-shape documents missing adopter skill routing preflight" \
  "grep -q '.claude/ship-flow/skill-routing.yaml' '${PLUGIN_ROOT}/skills/ship-shape/SKILL.md' && grep -q 'discover-adopter-skills\\.sh' '${PLUGIN_ROOT}/skills/ship-shape/SKILL.md'"
check "ship-plan merges adopter skill-routing.yaml into skills_needed derivation" \
  "grep -q '.claude/ship-flow/skill-routing.yaml' '${PLUGIN_ROOT}/skills/ship-plan/SKILL.md'"

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
