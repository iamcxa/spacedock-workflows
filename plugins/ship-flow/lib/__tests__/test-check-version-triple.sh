#!/usr/bin/env bash
# test-check-version-triple.sh — regression coverage for root README version drift

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
CHECKER="${SCRIPT_DIR}/../../../../scripts/check-version-triple.sh"
TMP_ROOT="$(mktemp -d)"

trap 'rm -rf "${TMP_ROOT}"' EXIT INT TERM

PASS=0
FAIL=0

pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
}

FIXTURE_ROOT="${TMP_ROOT}/repo"
mkdir -p \
  "${FIXTURE_ROOT}/scripts" \
  "${FIXTURE_ROOT}/plugins/ship-flow/.claude-plugin" \
  "${FIXTURE_ROOT}/plugins/ship-flow" \
  "${FIXTURE_ROOT}/.claude-plugin"

cp "${CHECKER}" "${FIXTURE_ROOT}/scripts/check-version-triple.sh"

cat >"${FIXTURE_ROOT}/plugins/ship-flow/.claude-plugin/plugin.json" <<'EOF'
{
  "name": "ship-flow",
  "version": "9.8.7",
  "repository": "https://github.com/iamcxa/spacedock-workflows"
}
EOF

cat >"${FIXTURE_ROOT}/.claude-plugin/marketplace.json" <<'EOF'
{
  "plugins": [
    {
      "name": "ship-flow",
      "version": "9.8.7"
    }
  ]
}
EOF

cat >"${FIXTURE_ROOT}/plugins/ship-flow/README.md" <<'EOF'
# Ship-Flow — Staged Feature Delivery (v9.8.7)
EOF

run_checker() {
  local output_file="$1"

  if bash "${FIXTURE_ROOT}/scripts/check-version-triple.sh" >"${output_file}" 2>&1; then
    CHECKER_STATUS=0
  else
    CHECKER_STATUS=$?
  fi
}

assert_clean_readme_passes() {
  local output_file="${TMP_ROOT}/clean.out"

  printf '%s\n' \
    '# Fixture repository' \
    '' \
    'Compatibility and adoption guidance follows the canonical product document.' \
    >"${FIXTURE_ROOT}/README.md"

  run_checker "${output_file}"
  if [ "${CHECKER_STATUS}" -eq 0 ]; then
    pass "clean root README passes"
  else
    fail "clean root README passes (exit ${CHECKER_STATUS})"
    sed 's/^/    /' "${output_file}"
  fi
}

assert_version_drift_fails() {
  local label="$1"
  local drift="$2"
  local output_file="${TMP_ROOT}/${label}.out"

  printf '# Fixture repository\n\nCompatibility claim: %s\n' "${drift}" \
    >"${FIXTURE_ROOT}/README.md"

  run_checker "${output_file}"
  if [ "${CHECKER_STATUS}" -ne 0 ] && \
    grep -Fq 'FAIL: root README contains version-shaped literal' "${output_file}"; then
    pass "${label} root README drift is rejected"
  else
    fail "${label} root README drift is rejected (exit ${CHECKER_STATUS})"
    sed 's/^/    /' "${output_file}"
  fi
}

echo "=== test-check-version-triple.sh ==="
assert_clean_readme_passes
assert_version_drift_fails "bare-semver" "0.7.0"
assert_version_drift_fails "v-prefixed-minor" "v0.7"
assert_version_drift_fails "x-series" "0.7.x"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -ne 0 ]; then
  exit 1
fi
