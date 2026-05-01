#!/usr/bin/env bash
# test-sync-workflow-sot.sh - SOT-driven workflow template/plugin README sync.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
SYNC="${REPO_ROOT}/plugins/ship-flow/lib/sync-workflow-sot.sh"

PASS=0
FAIL=0
ERRORS=()

record_pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

record_fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

assert_success() {
  local desc="$1"
  shift
  if "$@" > /dev/null 2>&1; then
    record_pass "$desc"
  else
    record_fail "$desc"
  fi
}

assert_failure_output() {
  local desc="$1"
  local pattern="$2"
  shift 2
  local out
  set +e
  out="$("$@" 2>&1)"
  local status=$?
  set -e
  if [ "$status" -ne 0 ] && printf '%s\n' "$out" | grep -q "$pattern"; then
    record_pass "$desc"
  else
    record_fail "$desc"
  fi
}

echo "=== test-sync-workflow-sot.sh ==="
echo ""

assert_success "sync-workflow-sot.sh exists and is executable" test -x "$SYNC"

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

SOT="${TMP_DIR}/README.md"
TEMPLATE="${TMP_DIR}/workflow-template.yaml"
PLUGIN_README="${TMP_DIR}/plugin-README.md"

cp "${REPO_ROOT}/docs/ship-flow/README.md" "$SOT"
cp "${REPO_ROOT}/plugins/ship-flow/workflow-template.yaml" "$TEMPLATE"
cp "${REPO_ROOT}/plugins/ship-flow/README.md" "$PLUGIN_README"

perl -0pi -e 's/skip-when: "![^"]+"/skip-when: "!affects_ui && !domain"/' "$TEMPLATE"
perl -0pi -e 's/feedback-to: "execute\|design\|plan\|follow-up"/feedback-to: execute/' "$TEMPLATE"
perl -0pi -e 's/skip-when: !affects_ui && !domain && !design_required/skip-when: !affects_ui && !domain/' "$PLUGIN_README"

assert_failure_output "check mode reports template drift without writing" "DRIFT template.design.skip-when" \
  "$SYNC" --check --sot "$SOT" --template "$TEMPLATE" --plugin-readme "$PLUGIN_README"

if grep -q 'skip-when: "!affects_ui && !domain"$' "$TEMPLATE"; then
  record_pass "check mode leaves template unchanged"
else
  record_fail "check mode leaves template unchanged"
fi

assert_success "write mode updates derived files from dogfood SOT" \
  "$SYNC" --write --sot "$SOT" --template "$TEMPLATE" --plugin-readme "$PLUGIN_README"

assert_success "check mode passes after write mode" \
  "$SYNC" --check --sot "$SOT" --template "$TEMPLATE" --plugin-readme "$PLUGIN_README"

assert_success "live repo SOT-derived files are in sync" \
  "$SYNC" --check

if grep -q 'sync-workflow-sot.sh --check' "${REPO_ROOT}/plugins/ship-flow/README.md" &&
  grep -q 'sync-workflow-sot.sh --write' "${REPO_ROOT}/plugins/ship-flow/README.md"; then
  record_pass "plugin README documents check/write SOT sync commands"
else
  record_fail "plugin README documents check/write SOT sync commands"
fi

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
