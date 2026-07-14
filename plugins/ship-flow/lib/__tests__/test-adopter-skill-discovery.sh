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

REAL_FIND="$(command -v find)"
FAKE_FIND_BIN="${TMP_ROOT}/fake-find-bin"
mkdir -p "${FAKE_FIND_BIN}"
cat >"${FAKE_FIND_BIN}/find" <<'EOF'
#!/usr/bin/env bash
set -u

{
  printf 'CALL'
  printf '\t%s' "$@"
  printf '\n'
} >>"${SHIP_FLOW_TEST_FIND_LOG:?}"

if [ "${1:-}" = "${SHIP_FLOW_TEST_FAIL_ROOT:-}" ]; then
  for arg in "$@"; do
    if [ "$arg" = "${SHIP_FLOW_TEST_FAIL_NEEDLE:-}" ]; then
      printf '%s\n' "${SHIP_FLOW_TEST_PARTIAL:-partial-find-result}"
      printf 'fake-find: injected %s traversal failure\n' "${SHIP_FLOW_TEST_CASE:-unknown}" >&2
      exit 23
    fi
  done
fi

exec "${SHIP_FLOW_TEST_REAL_FIND:?}" "$@"
EOF
chmod +x "${FAKE_FIND_BIN}/find"

run_discovery_with_find_failure() {
  local root="$1"
  local family="$2"
  local needle="$3"
  local stdout_file="$4"
  local stderr_file="$5"
  local log_file="$6"

  : >"${log_file}"
  if PATH="${FAKE_FIND_BIN}:${PATH}" \
    SHIP_FLOW_TEST_REAL_FIND="${REAL_FIND}" \
    SHIP_FLOW_TEST_FIND_LOG="${log_file}" \
    SHIP_FLOW_TEST_FAIL_ROOT="${root}" \
    SHIP_FLOW_TEST_FAIL_NEEDLE="${needle}" \
    SHIP_FLOW_TEST_CASE="${family}" \
    "${DISCOVERY_SCRIPT}" --root="${root}" >"${stdout_file}" 2>"${stderr_file}"; then
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

echo "Block 2.7: traversal failures reject partial data and stop later probes"
ERROR_ROOT="${TMP_ROOT}/error-root"
mkdir -p "${ERROR_ROOT}"

HAS_PATH_STDOUT="${TMP_ROOT}/has-path.stdout"
HAS_PATH_STDERR="${TMP_ROOT}/has-path.stderr"
HAS_PATH_LOG="${TMP_ROOT}/has-path.log"
run_discovery_with_find_failure \
  "${ERROR_ROOT}" \
  "has_path" \
  "${ERROR_ROOT}/apps/refine-app/*" \
  "${HAS_PATH_STDOUT}" \
  "${HAS_PATH_STDERR}" \
  "${HAS_PATH_LOG}"
HAS_PATH_STATUS="${RUN_DISCOVERY_STATUS}"

check "has_path traversal failure exits 2" \
  "[ '${HAS_PATH_STATUS}' -eq 2 ]"
check "has_path traversal failure rejects partial output" \
  "[ ! -s '${HAS_PATH_STDOUT}' ]"
check "has_path traversal failure preserves raw and contextual diagnostics" \
  "grep -Fq 'fake-find: injected has_path traversal failure' '${HAS_PATH_STDERR}' && grep -Fq 'ERROR: adopter discovery has_path traversal failed (rc 23): apps/refine-app/*' '${HAS_PATH_STDERR}'"
check "has_path traversal failure stops its dependency alternative and later routes" \
  "! grep -Fq -- $'\\tpackage.json\\t' '${HAS_PATH_LOG}' && ! grep -Fq -- '${ERROR_ROOT}/apps/expo-app/*' '${HAS_PATH_LOG}'"

HAS_DEPENDENCY_STDOUT="${TMP_ROOT}/has-dependency.stdout"
HAS_DEPENDENCY_STDERR="${TMP_ROOT}/has-dependency.stderr"
HAS_DEPENDENCY_LOG="${TMP_ROOT}/has-dependency.log"
run_discovery_with_find_failure \
  "${ERROR_ROOT}" \
  "has_dependency" \
  "package.json" \
  "${HAS_DEPENDENCY_STDOUT}" \
  "${HAS_DEPENDENCY_STDERR}" \
  "${HAS_DEPENDENCY_LOG}"
HAS_DEPENDENCY_STATUS="${RUN_DISCOVERY_STATUS}"

check "has_dependency traversal failure exits 2" \
  "[ '${HAS_DEPENDENCY_STATUS}' -eq 2 ]"
check "has_dependency traversal failure rejects partial output" \
  "[ ! -s '${HAS_DEPENDENCY_STDOUT}' ]"
check "has_dependency traversal failure preserves raw and contextual diagnostics" \
  "grep -Fq 'fake-find: injected has_dependency traversal failure' '${HAS_DEPENDENCY_STDERR}' && grep -Fq 'ERROR: adopter discovery has_dependency traversal failed (rc 23): \"@refinedev/' '${HAS_DEPENDENCY_STDERR}'"
check "has_dependency traversal failure stops later route probes" \
  "! grep -Fq -- '${ERROR_ROOT}/apps/expo-app/*' '${HAS_DEPENDENCY_LOG}'"

HAS_FILE_NAME_STDOUT="${TMP_ROOT}/has-file-name.stdout"
HAS_FILE_NAME_STDERR="${TMP_ROOT}/has-file-name.stderr"
HAS_FILE_NAME_LOG="${TMP_ROOT}/has-file-name.log"
run_discovery_with_find_failure \
  "${ERROR_ROOT}" \
  "has_file_name" \
  "app.json" \
  "${HAS_FILE_NAME_STDOUT}" \
  "${HAS_FILE_NAME_STDERR}" \
  "${HAS_FILE_NAME_LOG}"
HAS_FILE_NAME_STATUS="${RUN_DISCOVERY_STATUS}"

check "has_file_name traversal failure exits 2" \
  "[ '${HAS_FILE_NAME_STATUS}' -eq 2 ]"
check "has_file_name traversal failure rejects partial output" \
  "[ ! -s '${HAS_FILE_NAME_STDOUT}' ]"
check "has_file_name traversal failure preserves raw and contextual diagnostics" \
  "grep -Fq 'fake-find: injected has_file_name traversal failure' '${HAS_FILE_NAME_STDERR}' && grep -Fq 'ERROR: adopter discovery has_file_name traversal failed (rc 23): app.json' '${HAS_FILE_NAME_STDERR}'"
check "has_file_name traversal failure stops its dependency alternative and later routes" \
  "[ \"\$(grep -Fc $'\\tpackage.json\\t' '${HAS_FILE_NAME_LOG}')\" -eq 1 ] && ! grep -Fq -- '${ERROR_ROOT}/apps/supabase/migrations/*' '${HAS_FILE_NAME_LOG}'"

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
