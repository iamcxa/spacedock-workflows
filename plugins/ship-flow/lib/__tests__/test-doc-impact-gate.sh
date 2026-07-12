#!/usr/bin/env bash
# test-doc-impact-gate.sh — mechanical doc-coupling gate (AC-2)
#
# Usage:
#   bash plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
CHECKER="${PLUGIN_ROOT}/bin/doc-impact-gate.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/doc-impact-gate"
FIXTURE_MAP="${FIXTURE_ROOT}/coupling-map.yaml"

PASS=0
FAIL=0
ERRORS=()

hash_dir() {
  local dir="$1"
  find "$dir" -type f -print | sort | while IFS= read -r file; do
    shasum -a 256 "$file"
  done | shasum -a 256 | awk '{print $1}'
}

record_pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

record_fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

run_checker() {
  # run_checker <changed-fixture> <declaration> <output-file> <exit-file> [extra-args...]
  local changed="$1" declaration="$2" output_file="$3" exit_file="$4"
  shift 4
  local rc=0
  "${CHECKER}" \
    "--changed=${FIXTURE_ROOT}/${changed}" \
    "--declaration=${declaration}" \
    "--coupling-map=${FIXTURE_MAP}" \
    "$@" \
    > "${output_file}" 2>&1 || rc=$?
  printf '%s\n' "$rc" > "${exit_file}"
}

assert_exit() {
  local desc="$1" expected="$2" exit_file="$3"
  local actual
  actual="$(cat "$exit_file")"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected exit ${expected}, got ${actual})"
  fi
}

assert_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then
    record_pass "$desc"
  else
    record_fail "$desc (missing pattern: ${pattern})"
  fi
}

assert_not_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then
    record_fail "$desc (unexpected pattern: ${pattern})"
  else
    record_pass "$desc"
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

echo "=== test-doc-impact-gate.sh ==="
echo ""

echo "Block 1: coupled doc touched — pass, no blocker"
FIXTURE_BEFORE="$(hash_dir "$FIXTURE_ROOT")"
run_checker "changed-doc-touched.txt" "" "${TMP_DIR}/touched.out" "${TMP_DIR}/touched.exit"
assert_exit "coupled doc touched exits 0" 0 "${TMP_DIR}/touched.exit"
assert_contains "coupled doc touched emits PASS for skill-readme" '^PASS skill-readme' "${TMP_DIR}/touched.out"
assert_not_contains "coupled doc touched emits no blockers" '^BLOCKER ' "${TMP_DIR}/touched.out"

echo ""
echo "Block 2: src touched, doc not touched, no declaration — blocker"
run_checker "changed-doc-not-touched.txt" "" "${TMP_DIR}/no-decl.out" "${TMP_DIR}/no-decl.exit"
assert_exit "no declaration exits 1" 1 "${TMP_DIR}/no-decl.exit"
assert_contains "no declaration reports BLOCKER doc-impact for skill-readme" "^BLOCKER doc-impact: skill-readme — changed fixtures/skills/\*/SKILL\.md but coupled doc fixtures/README\.md not touched and no 'doc-impact: none — <reason>' declaration found" "${TMP_DIR}/no-decl.out"

echo ""
echo "Block 3: src touched, doc not touched, weak declaration — still blocker"
run_checker "changed-doc-not-touched.txt" "doc-impact: none — skip" "${TMP_DIR}/weak-decl.out" "${TMP_DIR}/weak-decl.exit"
assert_exit "weak declaration exits 1" 1 "${TMP_DIR}/weak-decl.exit"
assert_contains "weak declaration reports BLOCKER doc-impact" '^BLOCKER doc-impact: skill-readme' "${TMP_DIR}/weak-decl.out"

echo ""
echo "Block 4: src touched, doc not touched, concrete declaration — pass"
# codex-gate round-2 P1-2: the marker must be a standalone line, so this
# fixture puts the surrounding PR prose on its own line (a real PR body is
# multi-line) rather than sharing a line with "doc-impact:".
run_checker "changed-doc-not-touched.txt" "$(printf 'Some PR prose.\ndoc-impact: none — covered by follow-up PR #42 already merged upstream.')" "${TMP_DIR}/good-decl.out" "${TMP_DIR}/good-decl.exit"
assert_exit "concrete declaration exits 0" 0 "${TMP_DIR}/good-decl.exit"
assert_contains "concrete declaration emits PASS for skill-readme" '^PASS skill-readme: doc-impact declaration accepted' "${TMP_DIR}/good-decl.out"
assert_not_contains "concrete declaration emits no blockers" '^BLOCKER ' "${TMP_DIR}/good-decl.out"

echo ""
echo "Block 4b: codex-gate P1-2 — unanchored 'none' prose is not a waiver"
run_checker "changed-doc-not-touched.txt" "doc-impact: none of these docs are affected by my change I promise" "${TMP_DIR}/p1-2-fo-repro.out" "${TMP_DIR}/p1-2-fo-repro.exit"
assert_exit "FO repro prose ('none of these docs...') is rejected same as no declaration" 1 "${TMP_DIR}/p1-2-fo-repro.exit"
assert_contains "FO repro prose reports BLOCKER doc-impact for skill-readme" '^BLOCKER doc-impact: skill-readme' "${TMP_DIR}/p1-2-fo-repro.out"

run_checker "changed-doc-not-touched.txt" "doc-impact: nonetheless we changed nothing doc-related" "${TMP_DIR}/p1-2-nonetheless.out" "${TMP_DIR}/p1-2-nonetheless.exit"
assert_exit "'nonetheless' (no separator after 'none') is rejected same as no declaration" 1 "${TMP_DIR}/p1-2-nonetheless.exit"

run_checker "changed-doc-not-touched.txt" "doc-impact: none: valid colon-separated reason text here" "${TMP_DIR}/p1-2-colon.out" "${TMP_DIR}/p1-2-colon.exit"
assert_exit "anchored colon separator is still accepted" 0 "${TMP_DIR}/p1-2-colon.exit"

run_checker "changed-doc-not-touched.txt" "doc-impact: none | valid pipe-separated reason text here" "${TMP_DIR}/p1-2-pipe.out" "${TMP_DIR}/p1-2-pipe.exit"
assert_exit "anchored pipe separator is still accepted" 0 "${TMP_DIR}/p1-2-pipe.exit"

run_checker "changed-doc-not-touched.txt" "doc-impact: none -- valid double-dash-separated reason text" "${TMP_DIR}/p1-2-dashdash.out" "${TMP_DIR}/p1-2-dashdash.exit"
assert_exit "anchored double-dash separator is still accepted" 0 "${TMP_DIR}/p1-2-dashdash.exit"

echo ""
echo "Block 4c: codex-gate round-2 P1-2 residual — marker must be line-anchored, not just anywhere"
# FO repro: a PR-template example line ("Example only: ...") sharing a line
# with the marker must NOT count as a real waiver.
run_checker "changed-doc-not-touched.txt" "Example only: doc-impact: none — this is documentation" "${TMP_DIR}/p1-2-template.out" "${TMP_DIR}/p1-2-template.exit"
assert_exit "template-prefixed declaration is rejected same as no declaration" 1 "${TMP_DIR}/p1-2-template.exit"
assert_contains "template-prefixed declaration reports BLOCKER doc-impact for skill-readme" '^BLOCKER doc-impact: skill-readme' "${TMP_DIR}/p1-2-template.out"

# A marker quoted/attributed inside surrounding prose on the same line must
# likewise NOT count — indistinguishable from prefixed template prose.
run_checker "changed-doc-not-touched.txt" 'He argued: "doc-impact: none — this is fine" but reviewers disagreed.' "${TMP_DIR}/p1-2-quoted.out" "${TMP_DIR}/p1-2-quoted.exit"
assert_exit "quoted-context declaration is rejected same as no declaration" 1 "${TMP_DIR}/p1-2-quoted.exit"
assert_contains "quoted-context declaration reports BLOCKER doc-impact for skill-readme" '^BLOCKER doc-impact: skill-readme' "${TMP_DIR}/p1-2-quoted.out"

# Control: leading whitespace before the marker (e.g. an indented paragraph)
# stays anchored — only non-whitespace prefixes are rejected.
run_checker "changed-doc-not-touched.txt" "   doc-impact: none — indented but still a standalone line" "${TMP_DIR}/p1-2-indented.out" "${TMP_DIR}/p1-2-indented.exit"
assert_exit "leading-whitespace-only prefix is still accepted" 0 "${TMP_DIR}/p1-2-indented.exit"

echo ""
echo "Block 5: unrelated changes — no coupling triggered, silent pass"
run_checker "changed-unrelated.txt" "" "${TMP_DIR}/unrelated.out" "${TMP_DIR}/unrelated.exit"
assert_exit "unrelated changes exit 0" 0 "${TMP_DIR}/unrelated.exit"
assert_not_contains "unrelated changes emit no blockers" '^BLOCKER ' "${TMP_DIR}/unrelated.out"
assert_not_contains "unrelated changes emit no passes (no coupling row touched)" '^PASS ' "${TMP_DIR}/unrelated.out"

echo ""
echo "Block 6: write modes are rejected exactly like canonical-doc-sync-checker.sh"
for flag in --fix --write --apply --sync --repair; do
  "${CHECKER}" "$flag" "--changed=${FIXTURE_ROOT}/changed-unrelated.txt" > "${TMP_DIR}/flag.out" 2>&1 && FLAG_RC=0 || FLAG_RC=$?
  printf '%s\n' "$FLAG_RC" > "${TMP_DIR}/flag.exit"
  assert_exit "${flag} exits 2" 2 "${TMP_DIR}/flag.exit"
done

echo ""
echo "Block 7: --changed is required"
"${CHECKER}" "--declaration=x" > "${TMP_DIR}/missing-changed.out" 2>&1 && MISSING_RC=0 || MISSING_RC=$?
printf '%s\n' "$MISSING_RC" > "${TMP_DIR}/missing-changed.exit"
assert_exit "missing --changed exits 2" 2 "${TMP_DIR}/missing-changed.exit"

echo ""
echo "Block 8: checker is read-only"
FIXTURE_AFTER="$(hash_dir "$FIXTURE_ROOT")"
if [ "$FIXTURE_BEFORE" = "$FIXTURE_AFTER" ]; then
  record_pass "fixture directory unchanged across all runs"
else
  record_fail "fixture directory unchanged across all runs (hash changed)"
fi

echo ""
echo "Block 9: codex-gate P1-3 — single-quote inline arrays parse identically to double-quote"
"${CHECKER}" \
  "--changed=${FIXTURE_ROOT}/changed-doc-not-touched.txt" \
  "--declaration=" \
  "--coupling-map=${FIXTURE_ROOT}/coupling-map-single-quote.yaml" \
  > "${TMP_DIR}/single-quote.out" 2>&1 && SQ_RC=0 || SQ_RC=$?
printf '%s\n' "$SQ_RC" > "${TMP_DIR}/single-quote.exit"
assert_exit "single-quote coupling map: no declaration exits 1 (row parsed, not silently skipped)" 1 "${TMP_DIR}/single-quote.exit"
assert_contains "single-quote coupling map reports BLOCKER for skill-readme" '^BLOCKER doc-impact: skill-readme' "${TMP_DIR}/single-quote.out"

echo ""
echo "Block 10: codex-gate P1-3 — non-canonical indentation parses identically to 4-space"
"${CHECKER}" \
  "--changed=${FIXTURE_ROOT}/changed-doc-not-touched.txt" \
  "--declaration=" \
  "--coupling-map=${FIXTURE_ROOT}/coupling-map-indent-variant.yaml" \
  > "${TMP_DIR}/indent-variant.out" 2>&1 && IV_RC=0 || IV_RC=$?
printf '%s\n' "$IV_RC" > "${TMP_DIR}/indent-variant.exit"
assert_exit "indent-variant coupling map: no declaration exits 1 (row parsed, not silently skipped)" 1 "${TMP_DIR}/indent-variant.exit"
assert_contains "indent-variant coupling map reports BLOCKER for skill-readme" '^BLOCKER doc-impact: skill-readme' "${TMP_DIR}/indent-variant.out"

echo ""
echo "Block 11: codex-gate P1-3 — block-array layout fails CLOSED, not silently skipped"
"${CHECKER}" \
  "--changed=${FIXTURE_ROOT}/changed-doc-not-touched.txt" \
  "--declaration=" \
  "--coupling-map=${FIXTURE_ROOT}/coupling-map-block-array.yaml" \
  > "${TMP_DIR}/block-array.out" 2>&1 && BA_RC=0 || BA_RC=$?
printf '%s\n' "$BA_RC" > "${TMP_DIR}/block-array.exit"
assert_exit "block-array coupling map hard-errors (exit 2), not silent exit 0" 2 "${TMP_DIR}/block-array.exit"
assert_contains "block-array hard-error names the unparseable row" 'skill-readme' "${TMP_DIR}/block-array.out"

echo ""
echo "Block 12: codex-gate round-2 P1-3 residual — flow-style map (zero rows) fails CLOSED, not silent exit 0"
"${CHECKER}" \
  "--changed=${FIXTURE_ROOT}/changed-doc-not-touched.txt" \
  "--declaration=" \
  "--coupling-map=${FIXTURE_ROOT}/coupling-map-flow-style.yaml" \
  > "${TMP_DIR}/flow-style.out" 2>&1 && FS_RC=0 || FS_RC=$?
printf '%s\n' "$FS_RC" > "${TMP_DIR}/flow-style.exit"
assert_exit "flow-style coupling map hard-errors (exit 2), not silent exit 0" 2 "${TMP_DIR}/flow-style.exit"
assert_contains "flow-style hard-error names the couplings map" "coupling-map-flow-style\.yaml" "${TMP_DIR}/flow-style.out"

echo ""
echo "Block 13: codex-gate round-2 P1-3 residual — zero-rows map ('couplings: []') fails CLOSED, not silent exit 0"
"${CHECKER}" \
  "--changed=${FIXTURE_ROOT}/changed-doc-not-touched.txt" \
  "--declaration=" \
  "--coupling-map=${FIXTURE_ROOT}/coupling-map-zero-rows.yaml" \
  > "${TMP_DIR}/zero-rows.out" 2>&1 && ZR_RC=0 || ZR_RC=$?
printf '%s\n' "$ZR_RC" > "${TMP_DIR}/zero-rows.exit"
assert_exit "zero-rows coupling map hard-errors (exit 2), not silent exit 0" 2 "${TMP_DIR}/zero-rows.exit"
assert_contains "zero-rows hard-error names the couplings map" "coupling-map-zero-rows\.yaml" "${TMP_DIR}/zero-rows.out"

echo ""
echo "Block 14: codex-gate round-2 P1-3 residual — unrecognized line inside couplings block fails CLOSED, naming the line"
"${CHECKER}" \
  "--changed=${FIXTURE_ROOT}/changed-doc-not-touched.txt" \
  "--declaration=" \
  "--coupling-map=${FIXTURE_ROOT}/coupling-map-unrecognized-line.yaml" \
  > "${TMP_DIR}/unrecognized-line.out" 2>&1 && UL_RC=0 || UL_RC=$?
printf '%s\n' "$UL_RC" > "${TMP_DIR}/unrecognized-line.exit"
assert_exit "unrecognized-line coupling map hard-errors (exit 2), not silent exit 0" 2 "${TMP_DIR}/unrecognized-line.exit"
assert_contains "unrecognized-line hard-error names the offending line" 'unexpected_field' "${TMP_DIR}/unrecognized-line.out"

echo ""
echo "Block 15: codex-gate round-3 P1 — missing or misspelled 'couplings:' key fails CLOSED, not silent exit 0"
"${CHECKER}" \
  "--changed=${FIXTURE_ROOT}/changed-doc-not-touched.txt" \
  "--declaration=" \
  "--coupling-map=${FIXTURE_ROOT}/coupling-map-missing-key.yaml" \
  > "${TMP_DIR}/missing-key.out" 2>&1 && MK_RC=0 || MK_RC=$?
printf '%s\n' "$MK_RC" > "${TMP_DIR}/missing-key.exit"
assert_exit "missing-key coupling map hard-errors (exit 2), not silent exit 0" 2 "${TMP_DIR}/missing-key.exit"
assert_contains "missing-key hard-error names the couplings map" "coupling-map-missing-key\.yaml" "${TMP_DIR}/missing-key.out"

"${CHECKER}" \
  "--changed=${FIXTURE_ROOT}/changed-doc-not-touched.txt" \
  "--declaration=" \
  "--coupling-map=${FIXTURE_ROOT}/coupling-map-misspelled-key.yaml" \
  > "${TMP_DIR}/misspelled-key.out" 2>&1 && MSK_RC=0 || MSK_RC=$?
printf '%s\n' "$MSK_RC" > "${TMP_DIR}/misspelled-key.exit"
assert_exit "misspelled-key ('coupling:' singular) coupling map hard-errors (exit 2), not silent exit 0" 2 "${TMP_DIR}/misspelled-key.exit"
assert_contains "misspelled-key hard-error names the couplings map" "coupling-map-misspelled-key\.yaml" "${TMP_DIR}/misspelled-key.out"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "${FAIL}" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
