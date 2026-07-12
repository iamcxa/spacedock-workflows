#!/usr/bin/env bash
# test-built-in-ui-verify.sh — ship-flow owns ui-verify as a built-in utility skill.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${PLUGIN_ROOT}/../.." &> /dev/null && pwd)"

SKILL_DIR="${PLUGIN_ROOT}/skills/ui-verify"
SKILL_FILE="${SKILL_DIR}/SKILL.md"
RUNNER="${SKILL_DIR}/bin/run.js"
VERIFY_SKILL="${PLUGIN_ROOT}/skills/ship-verify/SKILL.md"
PLAN_SKILL="${PLUGIN_ROOT}/skills/ship-plan/SKILL.md"
GENERATOR="${PLUGIN_ROOT}/lib/generate-ui-verify-spec.sh"
INVARIANTS="${PLUGIN_ROOT}/INVARIANTS.md"
CHECKER="${PLUGIN_ROOT}/bin/check-invariants.sh"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

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

echo "=== test-built-in-ui-verify.sh ==="
echo ""

echo "Block 1: built-in skill files"
check "ship-flow includes ui-verify SKILL.md" \
  "[ -f '${SKILL_FILE}' ]"
check "ui-verify has an executable Node runner" \
  "[ -x '${RUNNER}' ]"
check "ui-verify frontmatter is discoverable as a ship-flow utility" \
  "grep -q '^name: ui-verify$' '${SKILL_FILE}' && grep -q '^description: Use when' '${SKILL_FILE}'"
check "ui-verify documents computed-style and whole-page boundaries" \
  "grep -q 'getComputedStyle' '${SKILL_FILE}' && grep -q 'fragment-level' '${SKILL_FILE}' && grep -q 'whole-page' '${SKILL_FILE}'"
check "runner validates YAML/mapping and drives agent-browser" \
  "grep -q 'agent-browser' '${RUNNER}' && grep -q '.claude/e2e/mappings' '${RUNNER}' && grep -q 'getComputedStyle' '${RUNNER}'"
check "ui-verify documents bounded readiness and idempotent click schema" \
  "grep -q '^readiness:' '${SKILL_FILE}' && grep -q 'timeout_ms: 10000' '${SKILL_FILE}' && grep -q 'poll_ms: 100' '${SKILL_FILE}' && grep -q 'ensure: open' '${SKILL_FILE}' && grep -q 'postcondition:' '${SKILL_FILE}'"
check "ui-verify documents selector-union barrier and timeout diagnostics" \
  "tr '\n' ' ' < '${SKILL_FILE}' | grep -q 'same current document' && grep -q 'missing selectors' '${SKILL_FILE}' && grep -q 'navigation timing/type' '${SKILL_FILE}' && grep -q 'console and page-error' '${SKILL_FILE}'"

echo "Block 2: ship-flow routes use built-in skill"
check "ship-verify invokes ship-flow:ui-verify instead of external e2e-pipeline ui-verify" \
  "grep -q 'ship-flow:ui-verify' '${VERIFY_SKILL}' && ! grep -q 'e2e-pipeline:ui-verify' '${VERIFY_SKILL}'"
check "ship-plan names ship-flow ui-verify schema for generated specs" \
  "grep -q 'schema: ship-flow:ui-verify' '${PLAN_SKILL}'"
check "generator describes built-in ship-flow ui-verify target" \
  "grep -q 'ship-flow:ui-verify' '${GENERATOR}'"

echo "Block 3: utility skill classification"
check "check-invariants allowlists ui-verify as utility skill" \
  "grep -q 'ui-verify' '${CHECKER}'"
check "INVARIANTS utility inventory lists ui-verify" \
  "grep -q 'ui-verify' '${INVARIANTS}'"
check "skill-count still passes with built-in ui-verify" \
  "bash '${CHECKER}' --check skill-count"

echo ""
echo "Block 4: observable readiness behavior"

mkdir -p \
  "${TMP_DIR}/bin" \
  "${TMP_DIR}/node_modules/js-yaml" \
  "${TMP_DIR}/project/.claude/e2e/mappings"
cat > "${TMP_DIR}/node_modules/js-yaml/index.js" <<'JS_YAML'
'use strict';
exports.load = JSON.parse;
JS_YAML
cat > "${TMP_DIR}/project/.claude/e2e/mappings/test.yaml" <<'JSON'
{"base_url":"http://example.test"}
JSON
cat > "${TMP_DIR}/project/cold-click.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Cold click readiness",
  "readiness": {"timeout_ms": 5000, "poll_ms": 20},
  "setup": [
    {"action": "goto", "url": "/"},
    {"action": "click", "selector": ".open-panel"}
  ],
  "checks": [
    {
      "name": "panel color",
      "selector": ".panel",
      "expect": {"color": "rgb(1, 2, 3)"}
    }
  ]
}
JSON
cat > "${TMP_DIR}/project/already-open.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Idempotent open readiness",
  "readiness": {"timeout_ms": 5000, "poll_ms": 20},
  "setup": [
    {
      "action": "click",
      "selector": ".open-panel",
      "ensure": "open",
      "postcondition": ".panel"
    }
  ],
  "checks": [
    {
      "name": "panel color",
      "selector": ".panel",
      "expect": {"color": "rgb(1, 2, 3)"}
    }
  ]
}
JSON
cat > "${TMP_DIR}/project/selector-union.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Selector union readiness",
  "readiness": {"timeout_ms": 5000, "poll_ms": 20},
  "checks": [
    {"name": "first color", "selector": ".first", "expect": {"color": "rgb(1, 2, 3)"}},
    {"name": "second color", "selector": ".second", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/readiness-timeout.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Readiness timeout evidence",
  "readiness": {"timeout_ms": 1000, "poll_ms": 50},
  "checks": [
    {"name": "never ready", "selector": ".never-ready", "expect": {"color": "red"}},
    {"name": "also missing", "selector": ".also-missing", "expect": {"display": "block"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/click-timeout.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Click timeout evidence",
  "readiness": {"timeout_ms": 1000, "poll_ms": 50},
  "setup": [{"action": "click", "selector": ".never-click"}],
  "checks": [
    {"name": "unreached check", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/blocking-click.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Blocking click readiness",
  "readiness": {"timeout_ms": 500, "poll_ms": 20},
  "setup": [{"action": "click", "selector": ".blocking-target"}],
  "checks": [
    {"name": "unreached check", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/ref-click.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Reference click compatibility",
  "readiness": {"timeout_ms": 5000, "poll_ms": 20},
  "setup": [{"action": "click", "selector": "@e7"}],
  "checks": [
    {"name": "panel color", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/closed-open.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Closed idempotent open",
  "readiness": {"timeout_ms": 5000, "poll_ms": 20},
  "setup": [
    {"action": "click", "selector": ".open-panel", "ensure": "open", "postcondition": ".panel"}
  ],
  "checks": [
    {"name": "panel color", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/legacy-mismatch.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Legacy mismatch",
  "checks": [
    {"name": "panel mismatch", "selector": ".panel", "expect": {"color": "red"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/invalid-readiness.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Invalid readiness",
  "readiness": {"timeout_ms": 0},
  "checks": [
    {"name": "panel color", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/explicit-wait.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Explicit wait compatibility",
  "readiness": {"timeout_ms": 1000, "poll_ms": 20},
  "setup": [{"action": "wait", "ms": 1500}],
  "checks": [
    {"name": "panel color", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/shared-step-budget.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Shared click step budget",
  "readiness": {"timeout_ms": 1500, "poll_ms": 20},
  "setup": [
    {"action": "click", "selector": ".budget-target", "ensure": "open", "postcondition": ".budget-panel"}
  ],
  "checks": [
    {"name": "panel color", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/hanging-open.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Hanging open diagnostics",
  "readiness": {"timeout_ms": 500, "poll_ms": 20},
  "setup": [{"action": "goto", "url": "/slow"}],
  "checks": [
    {"name": "unreached", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/project/hanging-click.yaml" <<'JSON'
{
  "version": 1,
  "mapping": "test",
  "title": "Hanging click diagnostics",
  "readiness": {"timeout_ms": 500, "poll_ms": 20},
  "setup": [{"action": "click", "selector": ".hanging-click"}],
  "checks": [
    {"name": "unreached", "selector": ".panel", "expect": {"color": "rgb(1, 2, 3)"}}
  ]
}
JSON
cat > "${TMP_DIR}/bin/agent-browser" <<'FAKE_BROWSER'
#!/usr/bin/env bash
set -euo pipefail

STATE_FILE="${FAKE_BROWSER_STATE:?}"
LOG_FILE="${FAKE_BROWSER_LOG:?}"
command_name="${1:-}"
shift || true
printf '%s %s\n' "${command_name}" "$*" >> "${LOG_FILE}"

case "${command_name}" in
  open)
    if [[ "${FAKE_BROWSER_HANG_OPEN:-0}" == "1" ]]; then sleep 3; fi
    ;;
  wait)
    ;;
  get)
    printf '%s\n' 'http://example.test/current?filters=encoded'
    ;;
  eval)
    expression="${1:-}"
    if [[ "${FAKE_BROWSER_HANG_CLICK:-0}" == "1" && "${expression}" == *".hanging-click"* ]]; then
      printf '%s\n' '{"ready":true,"missing":[]}'
    elif [[ "${FAKE_BROWSER_STEP_BUDGET:-0}" == "1" && "${expression}" == *".budget-target"* ]]; then
      perl -MTime::HiRes=sleep -e 'sleep 1'
      printf '%s\n' '{"ready":true,"missing":[]}'
    elif [[ "${FAKE_BROWSER_STEP_BUDGET:-0}" == "1" && "${expression}" == *".budget-panel"* ]]; then
      state=""
      [[ -f "${STATE_FILE}" ]] && state="$(<"${STATE_FILE}")"
      if [[ "${state}" == "clicked" ]]; then
        printf 'post-attempted' > "${STATE_FILE}"
        perl -MTime::HiRes=sleep -e 'sleep 1'
        printf '%s\n' '{"ready":true,"missing":[]}'
      else
        printf '%s\n' '{"ready":false,"missing":[".budget-panel"]}'
      fi
    elif [[ "${FAKE_BROWSER_CLOSED_OPEN:-0}" == "1" && "${expression}" != *"getComputedStyle"* && "${expression}" == *".panel"* ]]; then
      if [[ -f "${STATE_FILE}" ]]; then
        printf '%s\n' '{"ready":true,"missing":[]}'
      else
        printf '%s\n' '{"ready":false,"missing":[".panel"]}'
      fi
    elif [[ "${FAKE_BROWSER_CLOSED_OPEN:-0}" == "1" && "${expression}" == *".open-panel"* ]]; then
      printf '%s\n' '{"ready":true,"missing":[]}'
    elif [[ "${FAKE_BROWSER_BLOCKING:-0}" == "1" && "${expression}" == *".blocking-target"* ]]; then
      if [[ ! -f "${STATE_FILE}" ]]; then
        printf 'blocked' > "${STATE_FILE}"
        sleep 3
      fi
      printf '%s\n' '{"ready":false,"missing":[".blocking-target"]}'
    elif [[ "${FAKE_BROWSER_TIMEOUT:-0}" == "1" && "${expression}" == *"performance.getEntriesByType"* ]]; then
      printf '%s\n' '{"type":"navigate","domContentLoadedEventEnd":123,"loadEventEnd":456}'
    elif [[ "${FAKE_BROWSER_TIMEOUT:-0}" == "1" && "${expression}" == *".never-ready"* ]]; then
      printf '%s\n' '{"ready":false,"missing":[".never-ready",".also-missing"]}'
    elif [[ "${FAKE_BROWSER_TIMEOUT:-0}" == "1" && "${expression}" == *".never-click"* ]]; then
      printf '%s\n' '{"ready":false,"missing":[".never-click"]}'
    elif [[ "${expression}" == *"getComputedStyle"* && "${expression}" != *".open-panel"* ]]; then
      if [[ "${FAKE_BROWSER_UNION:-0}" == "1" ]]; then
        attempts=0
        [[ -f "${STATE_FILE}" ]] && attempts="$(<"${STATE_FILE}")"
        if (( attempts < 3 )); then
          printf '%s\n' 'computed style probed before selector union was ready' >&2
          exit 1
        fi
      fi
      printf '%s\n' '{"matched":"DIV.panel","base":{"color":"rgb(1, 2, 3)"},"pseudo":{}}'
    elif [[ "${FAKE_BROWSER_UNION:-0}" == "1" && "${expression}" == *".first"* && "${expression}" == *".second"* ]]; then
      attempts=0
      [[ -f "${STATE_FILE}" ]] && attempts="$(<"${STATE_FILE}")"
      attempts=$((attempts + 1))
      printf '%s' "${attempts}" > "${STATE_FILE}"
      if (( attempts >= 3 )); then
        printf '%s\n' '{"ready":true,"missing":[]}'
      else
        printf '%s\n' '{"ready":false,"missing":[".second"]}'
      fi
    elif [[ "${expression}" == *".open-panel"* ]]; then
      attempts=0
      [[ -f "${STATE_FILE}" ]] && attempts="$(<"${STATE_FILE}")"
      attempts=$((attempts + 1))
      printf '%s' "${attempts}" > "${STATE_FILE}"
      if (( attempts >= 3 )); then
        printf '%s\n' '{"ready":true,"missing":[]}'
      else
        printf '%s\n' '{"ready":false,"missing":[".open-panel"]}'
      fi
    else
      printf '%s\n' '{"ready":true,"missing":[]}'
    fi
    ;;
  click)
    if [[ "${FAKE_BROWSER_HANG_CLICK:-0}" == "1" ]]; then sleep 3; exit 0; fi
    if [[ "${FAKE_BROWSER_STEP_BUDGET:-0}" == "1" ]]; then
      printf 'clicked' > "${STATE_FILE}"
      exit 0
    fi
    if [[ "${FAKE_BROWSER_CLOSED_OPEN:-0}" == "1" ]]; then
      printf 'open' > "${STATE_FILE}"
      exit 0
    fi
    if [[ "${FAKE_BROWSER_REF:-0}" == "1" && "${1:-}" == "@e7" ]]; then
      exit 0
    fi
    if [[ "${FAKE_BROWSER_ALREADY_OPEN:-0}" == "1" ]]; then
      printf '%s\n' 'click would close the already-open panel' >&2
      exit 1
    fi
    if [[ "${FAKE_BROWSER_CLICK_TIMEOUT:-0}" == "1" ]]; then
      printf '%s\n' 'target never became actionable' >&2
      exit 1
    fi
    attempts=0
    [[ -f "${STATE_FILE}" ]] && attempts="$(<"${STATE_FILE}")"
    attempts=$((attempts + 1))
    printf '%s' "${attempts}" > "${STATE_FILE}"
    if (( attempts < 3 )); then
      printf '%s\n' 'target not ready' >&2
      exit 1
    fi
    ;;
  snapshot)
    if [[ "${FAKE_BROWSER_REF:-0}" == "1" ]]; then
      printf '%s\n' 'button "Open panel" [ref=e7]'
    else
      printf '%s\n' 'document loading'
    fi
    ;;
  console)
    printf '%s\n' 'console-context: application still booting'
    ;;
  errors)
    printf '%s\n' 'page-error-context: chunk load pending'
    ;;
  screenshot)
    ;;
  *)
    printf 'unsupported fake command: %s\n' "${command_name}" >&2
    exit 1
    ;;
esac
FAKE_BROWSER
chmod +x "${TMP_DIR}/bin/agent-browser"

CLICK_OUTPUT="${TMP_DIR}/cold-click.out"
if (
  cd "${TMP_DIR}/project"
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_STATE="${TMP_DIR}/cold-click.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/cold-click.log" \
    node "${RUNNER}" cold-click.yaml --no-screenshot > "${CLICK_OUTPUT}" 2>&1
); then
  check "setup click polls until a cold target exists" \
    "grep -q '\[result\] PASS (1/1)' '${CLICK_OUTPUT}' && grep -q 'open-panel' '${TMP_DIR}/cold-click.log' && [ \"\$(grep -c '^click ' '${TMP_DIR}/cold-click.log')\" = 1 ]"
else
  echo "  FAIL: setup click polls until a cold target exists"
  sed 's/^/    /' "${CLICK_OUTPUT}"
  FAIL=$((FAIL + 1))
  ERRORS+=("setup click polls until a cold target exists")
fi

CLOSED_OUTPUT="${TMP_DIR}/closed-open.out"
if (
  cd "${TMP_DIR}/project"
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_CLOSED_OPEN=1 \
    FAKE_BROWSER_STATE="${TMP_DIR}/closed-open.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/closed-open.log" \
    node "${RUNNER}" closed-open.yaml --no-screenshot > "${CLOSED_OUTPUT}" 2>&1
); then
  check "ensure-open clicks once then waits for its postcondition when closed" \
    "grep -q '\[result\] PASS (1/1)' '${CLOSED_OUTPUT}' && [ \"\$(grep -c '^click ' '${TMP_DIR}/closed-open.log')\" = 1 ]"
else
  echo "  FAIL: ensure-open clicks once then waits for its postcondition when closed"
  sed 's/^/    /' "${CLOSED_OUTPUT}"
  FAIL=$((FAIL + 1))
  ERRORS+=("ensure-open clicks once then waits for its postcondition when closed")
fi

LEGACY_OUTPUT="${TMP_DIR}/legacy-mismatch.out"
LEGACY_STATUS="${TMP_DIR}/legacy-mismatch.status"
(
  cd "${TMP_DIR}/project"
  set +e
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_STATE="${TMP_DIR}/legacy-mismatch.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/legacy-mismatch.log" \
    node "${RUNNER}" legacy-mismatch.yaml --no-screenshot > "${LEGACY_OUTPUT}" 2>&1
  printf '%s' "$?" > "${LEGACY_STATUS}"
)
check "legacy YAML without readiness preserves computed-mismatch exit 1" \
  "[ \"\$(cat '${LEGACY_STATUS}')\" = 1 ] && grep -q '\[result\] FAIL (0/1)' '${LEGACY_OUTPUT}'"

INVALID_OUTPUT="${TMP_DIR}/invalid-readiness.out"
INVALID_STATUS="${TMP_DIR}/invalid-readiness.status"
(
  cd "${TMP_DIR}/project"
  set +e
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_STATE="${TMP_DIR}/invalid-readiness.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/invalid-readiness.log" \
    node "${RUNNER}" invalid-readiness.yaml --no-screenshot > "${INVALID_OUTPUT}" 2>&1
  printf '%s' "$?" > "${INVALID_STATUS}"
)
check "invalid readiness values remain runner errors" \
  "[ \"\$(cat '${INVALID_STATUS}')\" = 2 ] && grep -q 'readiness.timeout_ms must be a positive integer' '${INVALID_OUTPUT}'"

WAIT_OUTPUT="${TMP_DIR}/explicit-wait.out"
WAIT_START="$(perl -MTime::HiRes=time -e 'print time')"
if (
  cd "${TMP_DIR}/project"
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_STATE="${TMP_DIR}/explicit-wait.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/explicit-wait.log" \
    node "${RUNNER}" explicit-wait.yaml --no-screenshot > "${WAIT_OUTPUT}" 2>&1
); then
  WAIT_END="$(perl -MTime::HiRes=time -e 'print time')"
  check "explicit millisecond waits remain independent of readiness timeout" \
    "grep -q '\[result\] PASS (1/1)' '${WAIT_OUTPUT}' && ! grep -q '^wait 1500$' '${TMP_DIR}/explicit-wait.log' && perl -e 'exit !(($WAIT_END - $WAIT_START) >= 1.3)'"
else
  echo "  FAIL: explicit millisecond waits remain independent of readiness timeout"
  sed 's/^/    /' "${WAIT_OUTPUT}"
  FAIL=$((FAIL + 1))
  ERRORS+=("explicit millisecond waits remain independent of readiness timeout")
fi

BUDGET_OUTPUT="${TMP_DIR}/shared-step-budget.out"
BUDGET_STATUS="${TMP_DIR}/shared-step-budget.status"
BUDGET_START="$(perl -MTime::HiRes=time -e 'print time')"
(
  cd "${TMP_DIR}/project"
  set +e
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_STEP_BUDGET=1 \
    FAKE_BROWSER_STATE="${TMP_DIR}/shared-step-budget.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/shared-step-budget.log" \
    node "${RUNNER}" shared-step-budget.yaml --no-screenshot > "${BUDGET_OUTPUT}" 2>&1
  printf '%s' "$?" > "${BUDGET_STATUS}"
)
BUDGET_END="$(perl -MTime::HiRes=time -e 'print time')"
check "click target and postcondition share one step timeout budget" \
  "[ \"\$(cat '${BUDGET_STATUS}')\" = 2 ] && perl -e 'exit !(($BUDGET_END - $BUDGET_START) < 4)'"

for mode in open click; do
  DIRECT_OUTPUT="${TMP_DIR}/hanging-${mode}.out"
  DIRECT_STATUS="${TMP_DIR}/hanging-${mode}.status"
  (
    cd "${TMP_DIR}/project"
    set +e
    if [[ "${mode}" == "open" ]]; then
      FAKE_BROWSER_HANG_OPEN=1
      export FAKE_BROWSER_HANG_OPEN
    else
      FAKE_BROWSER_HANG_CLICK=1
      export FAKE_BROWSER_HANG_CLICK
    fi
    PATH="${TMP_DIR}/bin:${PATH}" \
      NODE_PATH="${TMP_DIR}/node_modules" \
      FAKE_BROWSER_STATE="${TMP_DIR}/hanging-${mode}.state" \
      FAKE_BROWSER_LOG="${TMP_DIR}/hanging-${mode}.log" \
      node "${RUNNER}" "hanging-${mode}.yaml" --no-screenshot > "${DIRECT_OUTPUT}" 2>&1
    printf '%s' "$?" > "${DIRECT_STATUS}"
  )
  check "hanging ${mode} command emits diagnostic evidence" \
    "[ \"\$(cat '${DIRECT_STATUS}')\" = 2 ] && grep -q 'current URL:' '${DIRECT_OUTPUT}' && grep -q 'missing selectors:' '${DIRECT_OUTPUT}' && grep -q 'navigation timing/type:' '${DIRECT_OUTPUT}' && grep -q 'console:' '${DIRECT_OUTPUT}' && grep -q 'page errors:' '${DIRECT_OUTPUT}'"
done
check "goto uses bounded document readiness instead of unbounded networkidle" \
  "! grep -q '^wait --load networkidle$' '${TMP_DIR}/cold-click.log'"

TIMEOUT_OUTPUT="${TMP_DIR}/readiness-timeout.out"
TIMEOUT_STATUS="${TMP_DIR}/readiness-timeout.status"
(
  cd "${TMP_DIR}/project"
  set +e
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_TIMEOUT=1 \
    FAKE_BROWSER_STATE="${TMP_DIR}/readiness-timeout.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/readiness-timeout.log" \
    node "${RUNNER}" readiness-timeout.yaml --no-screenshot > "${TIMEOUT_OUTPUT}" 2>&1
  printf '%s' "$?" > "${TIMEOUT_STATUS}"
)
check "check readiness timeout preserves failed-check exit code and emits browser evidence" \
  "[ \"\$(cat '${TIMEOUT_STATUS}')\" = 1 ] && grep -q '\[result\] FAIL (0/0)' '${TIMEOUT_OUTPUT}' && grep -q 'current URL: http://example.test/current?filters=encoded' '${TIMEOUT_OUTPUT}' && grep -q 'missing selectors: .never-ready, .also-missing' '${TIMEOUT_OUTPUT}' && grep -q 'navigation.*navigate' '${TIMEOUT_OUTPUT}' && grep -q 'console-context: application still booting' '${TIMEOUT_OUTPUT}' && grep -q 'page-error-context: chunk load pending' '${TIMEOUT_OUTPUT}'"

CLICK_TIMEOUT_OUTPUT="${TMP_DIR}/click-timeout.out"
CLICK_TIMEOUT_STATUS="${TMP_DIR}/click-timeout.status"
(
  cd "${TMP_DIR}/project"
  set +e
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_TIMEOUT=1 \
    FAKE_BROWSER_CLICK_TIMEOUT=1 \
    FAKE_BROWSER_STATE="${TMP_DIR}/click-timeout.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/click-timeout.log" \
    node "${RUNNER}" click-timeout.yaml --no-screenshot > "${CLICK_TIMEOUT_OUTPUT}" 2>&1
  printf '%s' "$?" > "${CLICK_TIMEOUT_STATUS}"
)
check "click timeout emits the same diagnostic evidence bundle" \
  "[ \"\$(cat '${CLICK_TIMEOUT_STATUS}')\" = 2 ] && grep -q 'current URL: http://example.test/current?filters=encoded' '${CLICK_TIMEOUT_OUTPUT}' && grep -q 'missing selectors: .never-click' '${CLICK_TIMEOUT_OUTPUT}' && grep -q 'navigation.*navigate' '${CLICK_TIMEOUT_OUTPUT}' && grep -q 'console-context: application still booting' '${CLICK_TIMEOUT_OUTPUT}' && grep -q 'page-error-context: chunk load pending' '${CLICK_TIMEOUT_OUTPUT}'"

BLOCKING_OUTPUT="${TMP_DIR}/blocking-click.out"
BLOCKING_STATUS="${TMP_DIR}/blocking-click.status"
BLOCKING_START="$(perl -MTime::HiRes=time -e 'print time')"
(
  cd "${TMP_DIR}/project"
  set +e
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_BLOCKING=1 \
    FAKE_BROWSER_STATE="${TMP_DIR}/blocking-click.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/blocking-click.log" \
    node "${RUNNER}" blocking-click.yaml --no-screenshot > "${BLOCKING_OUTPUT}" 2>&1
  printf '%s' "$?" > "${BLOCKING_STATUS}"
)
BLOCKING_END="$(perl -MTime::HiRes=time -e 'print time')"
check "readiness deadline bounds a blocking agent-browser child" \
  "[ \"\$(cat '${BLOCKING_STATUS}')\" = 2 ] && perl -e 'exit !(($BLOCKING_END - $BLOCKING_START) < 2)'"

REF_OUTPUT="${TMP_DIR}/ref-click.out"
if (
  cd "${TMP_DIR}/project"
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_REF=1 \
    FAKE_BROWSER_STATE="${TMP_DIR}/ref-click.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/ref-click.log" \
    node "${RUNNER}" ref-click.yaml --no-screenshot > "${REF_OUTPUT}" 2>&1
); then
  check "setup click preserves agent-browser reference locator compatibility" \
    "grep -q '\[result\] PASS (1/1)' '${REF_OUTPUT}' && [ \"\$(grep -c '^click @e7' '${TMP_DIR}/ref-click.log')\" = 1 ]"
else
  echo "  FAIL: setup click preserves agent-browser reference locator compatibility"
  sed 's/^/    /' "${REF_OUTPUT}"
  FAIL=$((FAIL + 1))
  ERRORS+=("setup click preserves agent-browser reference locator compatibility")
fi

UNION_OUTPUT="${TMP_DIR}/selector-union.out"
if (
  cd "${TMP_DIR}/project"
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_UNION=1 \
    FAKE_BROWSER_STATE="${TMP_DIR}/selector-union.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/selector-union.log" \
    node "${RUNNER}" selector-union.yaml --no-screenshot > "${UNION_OUTPUT}" 2>&1
); then
  check "checks wait for the declared selector union in one document" \
    "grep -q '\[result\] PASS (2/2)' '${UNION_OUTPUT}' && [ \"\$(grep -c '^eval ' '${TMP_DIR}/selector-union.log')\" -ge 5 ]"
else
  echo "  FAIL: checks wait for the declared selector union in one document"
  sed 's/^/    /' "${UNION_OUTPUT}"
  FAIL=$((FAIL + 1))
  ERRORS+=("checks wait for the declared selector union in one document")
fi

OPEN_OUTPUT="${TMP_DIR}/already-open.out"
if (
  cd "${TMP_DIR}/project"
  PATH="${TMP_DIR}/bin:${PATH}" \
    NODE_PATH="${TMP_DIR}/node_modules" \
    FAKE_BROWSER_ALREADY_OPEN=1 \
    FAKE_BROWSER_STATE="${TMP_DIR}/already-open.state" \
    FAKE_BROWSER_LOG="${TMP_DIR}/already-open.log" \
    node "${RUNNER}" already-open.yaml --no-screenshot > "${OPEN_OUTPUT}" 2>&1
); then
  check "ensure-open skips a click when its postcondition already exists" \
    "grep -q '\[result\] PASS (1/1)' '${OPEN_OUTPUT}' && ! grep -q '^click ' '${TMP_DIR}/already-open.log'"
else
  echo "  FAIL: ensure-open skips a click when its postcondition already exists"
  sed 's/^/    /' "${OPEN_OUTPUT}"
  FAIL=$((FAIL + 1))
  ERRORS+=("ensure-open skips a click when its postcondition already exists")
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed — ship-flow owns ui-verify."
exit 0
