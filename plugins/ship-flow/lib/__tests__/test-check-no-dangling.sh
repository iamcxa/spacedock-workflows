#!/usr/bin/env bash
# test-check-no-dangling.sh - mislocated-canonical-mod resolver contract (AC-2)
#
# Drives run_mislocated_canonical_mods() — the twin-exists + qualifier-aware
# resolver added to scripts/check-no-dangling.sh — against 11 fixture cases
# covering the RED detection case plus every load-bearing scoping constraint
# (a: backtick-fenced only, b: full-logical-unit unwrap, c: qualifier
# vocabulary, d: same-file self-reference exclusion) and a final green-on-the-
# real-repo case. Before the resolver function exists, every case records a
# single uniform skip-fail so the assertion count matches the post-fix run
# (only PASS/FAIL flips, not the count).
#
# shellcheck disable=SC2329  # build_case* functions are invoked indirectly via variable ($build_fn) in assert_case

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"
HELPER="${REPO_ROOT}/scripts/check-no-dangling.sh"

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

# ---------------------------------------------------------------------------
# Fixture builders — each writes a scratch tree under $1 (a fresh mktemp -d).
# ---------------------------------------------------------------------------

build_case1_unqualified() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
See the reference at `docs/ship-flow/_mods/foo.md` for details.
MDEOF
  echo "plugin-canonical twin" > "${root}/plugins/ship-flow/_mods/foo.md"
}

build_case2_fixed() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
See `plugins/ship-flow/_mods/foo.md` (plugin-canonical); adopter override `docs/ship-flow/_mods/foo.md` when present.
MDEOF
  echo "plugin-canonical twin" > "${root}/plugins/ship-flow/_mods/foo.md"
}

build_case3_qualified() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
Read this: if a workflow override exists at `docs/ship-flow/_mods/foo.md`, read it.
MDEOF
  echo "plugin-canonical twin" > "${root}/plugins/ship-flow/_mods/foo.md"
}

build_case4_wrapped_qualifier() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
Load `plugins/ship-flow/_mods/foo.md` before answering; if a
workflow override exists at `docs/ship-flow/_mods/foo.md`, read
that first.
MDEOF
  echo "plugin-canonical twin" > "${root}/plugins/ship-flow/_mods/foo.md"
}

build_case5_no_twin() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
See the reference at `docs/ship-flow/_mods/bar.md` for details.
MDEOF
}

build_case6_agents_override() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
If the repo has `docs/ship-flow/_mods/foo.md`, read that override first.
MDEOF
  echo "plugin-canonical twin" > "${root}/plugins/ship-flow/_mods/foo.md"
}

build_case7_json_noise() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
```json
{
  "requiredFiles": [
    "docs/ship-flow/_mods/foo.md"
  ]
}
```
MDEOF
  echo "plugin-canonical twin" > "${root}/plugins/ship-flow/_mods/foo.md"
}

build_case8_self_reference() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/_mods/foo.md" <<'MDEOF'
> Plugin-canonical copy. Adopting repos copy this to
> `docs/ship-flow/_mods/foo.md` and MAY append a repo-specific
> worked example.
MDEOF
}

build_case9_missing_everywhere_red() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow" "${root}/docs/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
See the reference at `docs/ship-flow/_mods/baz.md` for details.
MDEOF
}

build_case10_missing_everywhere_qualified() {
  local root="$1"
  mkdir -p "${root}/plugins/ship-flow" "${root}/docs/ship-flow/_mods"
  cat > "${root}/plugins/ship-flow/scanned.md" <<'MDEOF'
If the repo has `docs/ship-flow/_mods/baz.md`, read that override first.
MDEOF
}

# ---------------------------------------------------------------------------
# Case runner — one uniform PASS/FAIL per case (RED-skip and GREEN paths
# must record the same number of assertions; only the verdict flips).
# ---------------------------------------------------------------------------

assert_case() {
  local case_num="$1"
  local desc="$2"
  local build_fn="$3"
  local expected_exit="$4"
  local expected_violations="$5" # empty string = don't check count

  local root
  root="$(mktemp -d /tmp/check-no-dangling-fixture-XXXXXX)"
  "$build_fn" "$root"

  local actual_output="" actual_exit=0
  if actual_output="$(run_mislocated_canonical_mods "$root" 2>&1)"; then
    actual_exit=0
  else
    actual_exit=$?
  fi

  local actual_violations
  actual_violations=$(printf '%s\n' "$actual_output" | grep -cE '^  VIOLATION \[(mislocated|missing-everywhere)-canonical-mod\]' || true)

  rm -rf "$root"

  if [[ "$actual_exit" != "$expected_exit" ]]; then
    record_fail "case ${case_num} (${desc}): expected exit ${expected_exit}, got ${actual_exit} (output: ${actual_output})"
    return
  fi
  if [[ -n "$expected_violations" && "$actual_violations" != "$expected_violations" ]]; then
    record_fail "case ${case_num} (${desc}): expected ${expected_violations} violation line(s), got ${actual_violations} (output: ${actual_output})"
    return
  fi
  record_pass "case ${case_num} (${desc})"
}

assert_case11_real_repo() {
  local actual_output="" actual_exit=0
  if actual_output="$(run_mislocated_canonical_mods "$REPO_ROOT" 2>&1)"; then
    actual_exit=0
  else
    actual_exit=$?
  fi
  if [[ "$actual_exit" == "0" ]]; then
    record_pass "case 11 (green-on-real-repo-after-fix)"
  else
    record_fail "case 11 (green-on-real-repo-after-fix): expected exit 0, got ${actual_exit} (output: ${actual_output})"
  fi
}

echo "=== test-check-no-dangling.sh ==="
echo ""

EXISTENCE_DESC="resolver function run_mislocated_canonical_mods defined in check-no-dangling.sh"

if grep -q '^run_mislocated_canonical_mods()' "$HELPER" 2>/dev/null; then
  record_pass "$EXISTENCE_DESC"

  # shellcheck source=/dev/null
  source "$HELPER"

  assert_case 1 "RED-unqualified" build_case1_unqualified 1 1
  assert_case 2 "GREEN-fixed" build_case2_fixed 0 ""
  assert_case 3 "GREEN-qualified" build_case3_qualified 0 ""
  assert_case 4 "GREEN-wrapped-qualifier" build_case4_wrapped_qualifier 0 ""
  assert_case 5 "GREEN-no-twin" build_case5_no_twin 0 ""
  assert_case 6 "GREEN-agents-override" build_case6_agents_override 0 ""
  assert_case 7 "GREEN-json-noise" build_case7_json_noise 0 ""
  assert_case 8 "GREEN-self-reference" build_case8_self_reference 0 ""
  assert_case 9 "RED-missing-everywhere-unqualified" build_case9_missing_everywhere_red 1 1
  assert_case 10 "GREEN-missing-everywhere-qualified" build_case10_missing_everywhere_qualified 0 ""
  assert_case11_real_repo
else
  record_fail "$EXISTENCE_DESC"
  for case_desc in \
    "1 (RED-unqualified)" \
    "2 (GREEN-fixed)" \
    "3 (GREEN-qualified)" \
    "4 (GREEN-wrapped-qualifier)" \
    "5 (GREEN-no-twin)" \
    "6 (GREEN-agents-override)" \
    "7 (GREEN-json-noise)" \
    "8 (GREEN-self-reference)" \
    "9 (RED-missing-everywhere-unqualified)" \
    "10 (GREEN-missing-everywhere-qualified)" \
    "11 (green-on-real-repo-after-fix)"; do
    record_fail "case ${case_desc}: resolver function not yet defined"
  done
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [[ ${FAIL} -gt 0 ]]; then
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
