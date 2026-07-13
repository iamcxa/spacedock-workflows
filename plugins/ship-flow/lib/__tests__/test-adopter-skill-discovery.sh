#!/usr/bin/env bash
# test-adopter-skill-discovery.sh — 115.5 adopter-level skill routing discovery

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
DISCOVERY_SCRIPT="${SCRIPT_DIR}/../discover-adopter-skills.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/adopter-skill-discovery/carlove-like"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
TMP_ROOT="$(mktemp -d)"

trap 'rm -rf "${TMP_ROOT}"' EXIT INT TERM

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

check_stdout_not() {
  local desc="$1"
  local pattern="$2"
  local cmd="$3"
  local stdout_out
  stdout_out=$(eval "$cmd" 2>/dev/null || true)
  if echo "$stdout_out" | grep -qE "$pattern"; then
    echo "  FAIL: $desc (stdout unexpectedly contained '$pattern')"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

run_discovery() {
  local root="$1"
  local stdout_file="$2"
  local stderr_file="$3"

  if "${DISCOVERY_SCRIPT}" --root="${root}" >"${stdout_file}" 2>"${stderr_file}"; then
    RUN_DISCOVERY_STATUS=0
  else
    RUN_DISCOVERY_STATUS=$?
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

echo "Block 2.5: discovery ignores historical worktrees and archives"
IGNORED_ONLY_ROOT="${SCRIPT_DIR}/fixtures/adopter-skill-discovery/ignored-only"
check_stdout_not "ignored worktree/archive paths do not create Refine routes" \
  "name: refine-web" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${IGNORED_ONLY_ROOT}\""
check_stdout_not "ignored worktree/archive paths do not create Expo routes" \
  "name: expo-mobile" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${IGNORED_ONLY_ROOT}\""
check_stdout_not "ignored worktree/archive paths do not create Supabase routes" \
  "name: supabase-schema" \
  "\"${DISCOVERY_SCRIPT}\" --root=\"${IGNORED_ONLY_ROOT}\""
check "discovery helper explicitly prunes heavy generated/history directories" \
  "grep -q '.claude/worktrees' '${DISCOVERY_SCRIPT}' && grep -q '.worktrees' '${DISCOVERY_SCRIPT}' && grep -q 'docs/ship-flow/_archive' '${DISCOVERY_SCRIPT}'"

echo "Block 2.6: discovery ignores nested fixture decoys without rejecting marker ancestors"
CLEAN_TWIN_ROOT="${TMP_ROOT}/clean"
DECOY_TWIN_ROOT="${TMP_ROOT}/decoy"
mkdir -p \
  "${CLEAN_TWIN_ROOT}" \
  "${DECOY_TWIN_ROOT}/__tests__" \
  "${DECOY_TWIN_ROOT}/test-fixtures"
printf '%s\n' \
  '{' \
  '  "dependencies": {' \
  '    "@refinedev/core": "5.0.0"' \
  '  }' \
  '}' >"${DECOY_TWIN_ROOT}/__tests__/package.json"
printf '%s\n' \
  '{' \
  '  "dependencies": {' \
  '    "expo": "latest"' \
  '  }' \
  '}' >"${DECOY_TWIN_ROOT}/test-fixtures/package.json"

CLEAN_STDOUT="${TMP_ROOT}/clean.stdout"
CLEAN_STDERR="${TMP_ROOT}/clean.stderr"
DECOY_STDOUT="${TMP_ROOT}/decoy.stdout"
DECOY_STDERR="${TMP_ROOT}/decoy.stderr"

run_discovery "${CLEAN_TWIN_ROOT}" "${CLEAN_STDOUT}" "${CLEAN_STDERR}"
CLEAN_STATUS="${RUN_DISCOVERY_STATUS}"
run_discovery "${DECOY_TWIN_ROOT}" "${DECOY_STDOUT}" "${DECOY_STDERR}"
DECOY_STATUS="${RUN_DISCOVERY_STATUS}"

check "clean twin exits successfully" \
  "[ '${CLEAN_STATUS}' -eq 0 ]"
check "clean twin emits empty stderr" \
  "[ ! -s '${CLEAN_STDERR}' ]"
check "decoy twin exits successfully" \
  "[ '${DECOY_STATUS}' -eq 0 ]"
check "decoy twin emits empty stderr" \
  "[ ! -s '${DECOY_STDERR}' ]"
check "nested fixture decoys leave full YAML byte-identical to clean twin" \
  "cmp -s '${CLEAN_STDOUT}' '${DECOY_STDOUT}'"

MARKER_ANCESTOR_STDOUT="${TMP_ROOT}/marker-ancestor.stdout"
MARKER_ANCESTOR_STDERR="${TMP_ROOT}/marker-ancestor.stderr"
run_discovery "${FIXTURE_ROOT}" "${MARKER_ANCESTOR_STDOUT}" "${MARKER_ANCESTOR_STDERR}"
MARKER_ANCESTOR_STATUS="${RUN_DISCOVERY_STATUS}"

check "existing marker-ancestor fixture exits successfully" \
  "[ '${MARKER_ANCESTOR_STATUS}' -eq 0 ]"
check "existing marker-ancestor fixture emits empty stderr" \
  "[ ! -s '${MARKER_ANCESTOR_STDERR}' ]"
check "existing marker-ancestor fixture remains discoverable" \
  "grep -q 'name: refine-web' '${MARKER_ANCESTOR_STDOUT}' && grep -q 'name: expo-mobile' '${MARKER_ANCESTOR_STDOUT}'"

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
