#!/usr/bin/env bash
# Test: pitch 116 W3 invariant — no skip-when: in ship-flow source files
# (excluding stale-pre-113 fixture which is intentionally stale)
set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1" cmd="$2"
  if eval "$cmd" >/dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS+1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL+1))
    ERRORS+=("$desc")
  fi
}

echo "=== test-w3-skip-when-absent.sh ==="
echo "Block 1: pitch 116 W3 invariant — no skip-when in ship-flow source files"

check "plugins/ship-flow/workflow-template.yaml has no skip-when" \
  "! grep -q 'skip-when' '${REPO_ROOT}/plugins/ship-flow/workflow-template.yaml'"

check "docs/ship-flow/README.md design stage block has no skip-when" \
  "! grep -A6 'name: design' '${REPO_ROOT}/docs/ship-flow/README.md' | grep -q 'skip-when:'"

check "plugins/ship-flow/skills/ship-design/SKILL.md has no skip-when (post-pitch-116)" \
  "! grep -q 'skip-when:' '${REPO_ROOT}/plugins/ship-flow/skills/ship-design/SKILL.md'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do echo "  - ${err}"; done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi
echo "All assertions passed"
