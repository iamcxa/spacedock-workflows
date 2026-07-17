#!/usr/bin/env bash
# test-issue-anchor-guard.sh — issue-anchor scope-drift guard (mod + resolver + SKILL wiring)
#
# Pins design.md CD2 "Test implications" + CD4 per-AC source-diff schema +
# CD5 anchor-availability cases (empty-string issue: treated as absent,
# gh-failure fails visible, no-issue fallback). DC-1..DC-8b per plan.md's
# Verification Spec.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
MOD="${PLUGIN_ROOT}/_mods/issue-anchor-guard.md"
SKILL="${PLUGIN_ROOT}/skills/ship-shape/SKILL.md"
DOC_COUPLING_MAP="${PLUGIN_ROOT}/references/doc-coupling-map.yaml"

PASS=0
FAIL=0
ERRORS=()

record_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
record_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"; else record_fail "$desc (expected exit ${expected}, got ${actual})"; fi
}

assert_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE -- "$pattern" "$file"; then record_pass "$desc"; else record_fail "$desc (missing pattern: ${pattern} in ${file})"; fi
}

assert_not_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE -- "$pattern" "$file"; then record_fail "$desc (unexpected pattern: ${pattern} in ${file})"; else record_pass "$desc"; fi
}

echo "=== test-issue-anchor-guard.sh ==="
echo ""

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# ---------------------------------------------------------------------------
# DC-1 / DC-2 — mod existence, Hook heading, extractable+syntactically-valid resolver
# ---------------------------------------------------------------------------

if [ -f "$MOD" ]; then
  record_pass "DC-1: mod file exists at plugins/ship-flow/_mods/issue-anchor-guard.md"
  if grep -q '^## Hook: pre-shape' "$MOD"; then
    record_pass "DC-1: mod declares '## Hook: pre-shape' heading"
  else
    record_fail "DC-1: mod declares '## Hook: pre-shape' heading"
  fi

  RESOLVER="${TMP_DIR}/resolver.sh"
  awk '
    /# issue-anchor-guard-resolver:start/ { found=1; next }
    /# issue-anchor-guard-resolver:end/ { exit }
    found { print }
  ' "$MOD" > "$RESOLVER"

  if [ -s "$RESOLVER" ]; then
    record_pass "DC-2: resolver block is extractable (non-empty)"
  else
    record_fail "DC-2: resolver block is extractable (non-empty)"
  fi
  if bash -n "$RESOLVER" 2>"${TMP_DIR}/bashn.err"; then
    record_pass "DC-2: extracted resolver block is valid shell (bash -n)"
  else
    record_fail "DC-2: extracted resolver block is valid shell (bash -n): $(cat "${TMP_DIR}/bashn.err")"
  fi
else
  record_fail "DC-1: mod file exists at plugins/ship-flow/_mods/issue-anchor-guard.md"
  record_fail "DC-1: mod declares '## Hook: pre-shape' heading"
  record_fail "DC-2: resolver block is extractable (non-empty)"
  record_fail "DC-2: extracted resolver block is valid shell (bash -n)"
  RESOLVER="${TMP_DIR}/resolver-missing.sh"
  printf '#!/usr/bin/env bash\necho "resolver missing" >&2\nexit 1\n' > "$RESOLVER"
fi

# ---------------------------------------------------------------------------
# Fixture builders — synthetic scratch repo per fixture (mirrors
# test-contribution-contract.sh's isolated-repo pattern)
# ---------------------------------------------------------------------------

new_repo() {
  local repo="$1"
  mkdir -p "${repo}/.context"
}

write_entity_index() {
  # write_entity_index <path> <status> <issue-line-or-empty-marker> <tracker>
  local path="$1" status="$2" issue_field="$3" tracker="$4"
  mkdir -p "$(dirname "$path")"
  {
    printf -- '---\n'
    printf 'id: "fx"\n'
    printf 'title: "Fixture entity"\n'
    printf 'status: %s\n' "$status"
    if [ -n "$issue_field" ]; then printf '%s\n' "$issue_field"; fi
    if [ -n "$tracker" ]; then printf 'tracker: %s\n' "$tracker"; fi
    printf -- '---\n\n'
    printf '## Body\n\nFixture body.\n'
  } > "$path"
}

write_fake_gh_ok() {
  local dir="$1" body="$2"
  mkdir -p "$dir"
  cat > "${dir}/gh" <<EOF
#!/usr/bin/env bash
if [ "\$1" = "issue" ] && [ "\$2" = "view" ]; then
  cat <<'BODY_EOF'
${body}
BODY_EOF
  exit 0
fi
echo "unexpected gh invocation: \$*" >&2
exit 98
EOF
  chmod +x "${dir}/gh"
}

write_fake_gh_failing() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "${dir}/gh" <<'EOF'
#!/usr/bin/env bash
if [ "$1" = "issue" ] && [ "$2" = "view" ]; then
  echo "error connecting to api.github.com: rate limit exceeded" >&2
  exit 1
fi
echo "unexpected gh invocation: $*" >&2
exit 98
EOF
  chmod +x "${dir}/gh"
}

run_resolver_emit() {
  # run_resolver_emit <repo> <entity-rel-path> <out-file> <rc-file> [fakebin]
  local repo="$1" entity_rel="$2" out="$3" rc_file="$4" fakebin="${5:-}"
  local rc=0
  if [ -n "$fakebin" ]; then
    (cd "$repo" && PATH="${fakebin}:$PATH" bash "$RESOLVER" emit "--entity-path=${entity_rel}") > "$out" 2>&1 || rc=$?
  else
    (cd "$repo" && bash "$RESOLVER" emit "--entity-path=${entity_rel}") > "$out" 2>&1 || rc=$?
  fi
  printf '%s\n' "$rc" > "$rc_file"
}

CANNED_BODY='## Acceptance

AC-1: Guard writes a five-field source-diff YAML for a re-shaped entity.
AC-2: Guard no-ops on a fresh shape with no later-stage artifacts.
AC-3: Guard never fakes an AC list when the tracker call fails.'

# ---------------------------------------------------------------------------
# DC-3 — fx-reshape-with-issue: full source-diff emission
# ---------------------------------------------------------------------------

REPO3="${TMP_DIR}/repo-dc3"
new_repo "$REPO3"
write_entity_index "${REPO3}/docs/ship-flow/fx-reshape-with-issue/index.md" "design" 'issue: "#49"' "gh"
: > "${REPO3}/docs/ship-flow/fx-reshape-with-issue/shape.md"
: > "${REPO3}/docs/ship-flow/fx-reshape-with-issue/design.md"
FAKEBIN3="${TMP_DIR}/fakebin-dc3"
write_fake_gh_ok "$FAKEBIN3" "$CANNED_BODY"
OUT3="${TMP_DIR}/dc3.out"; RC3="${TMP_DIR}/dc3.rc"
run_resolver_emit "$REPO3" "docs/ship-flow/fx-reshape-with-issue" "$OUT3" "$RC3" "$FAKEBIN3"
DIFF3="${REPO3}/.context/ship-flow/source-diff-fx.yaml"

assert_exit "DC-3: resolver exits 0 on re-shape-with-issue fixture" 0 "$(cat "$RC3")"
if [ -f "$DIFF3" ]; then
  record_pass "DC-3: source-diff YAML written to .context/ship-flow/source-diff-<id>.yaml"
  assert_contains "DC-3: source-diff carries schema_version" '^schema_version:' "$DIFF3"
  assert_contains "DC-3: source-diff carries entity_id" '^entity_id:' "$DIFF3"
  assert_contains "DC-3: source-diff carries issue_ref" '^issue_ref:' "$DIFF3"
  assert_contains "DC-3: source-diff carries issue_fetched_at" '^issue_fetched_at:' "$DIFF3"
  assert_contains "DC-3: source-diff carries original_issue_acs" '^original_issue_acs:' "$DIFF3"
  assert_contains "DC-3: source-diff carries verdict in enum" '^verdict: (proceed|narrow|return)$' "$DIFF3"
  AC_COUNT="$(grep -c 'met_by_existing_capability:' "$DIFF3" || true)"
  if [ "$AC_COUNT" -ge 3 ]; then
    record_pass "DC-3: original_issue_acs[] is non-empty with per-AC met_by_existing_capability (found $AC_COUNT rows for 3 canned ACs)"
  else
    record_fail "DC-3: original_issue_acs[] is non-empty with per-AC met_by_existing_capability (found $AC_COUNT rows, expected >= 3)"
  fi
else
  record_fail "DC-3: source-diff YAML written to .context/ship-flow/source-diff-<id>.yaml (missing: $DIFF3)"
  for d in "source-diff carries schema_version" "source-diff carries entity_id" "source-diff carries issue_ref" "source-diff carries issue_fetched_at" "source-diff carries original_issue_acs" "source-diff carries verdict in enum" "original_issue_acs[] is non-empty with per-AC met_by_existing_capability"; do
    record_fail "DC-3: $d"
  done
fi

# ---------------------------------------------------------------------------
# DC-4 — fx-fresh-shape: no-op on fresh shape
# ---------------------------------------------------------------------------

REPO4="${TMP_DIR}/repo-dc4"
new_repo "$REPO4"
write_entity_index "${REPO4}/docs/ship-flow/fx-fresh-shape/index.md" "sharp" "" ""
: > "${REPO4}/docs/ship-flow/fx-fresh-shape/shape.md"
OUT4="${TMP_DIR}/dc4.out"; RC4="${TMP_DIR}/dc4.rc"
run_resolver_emit "$REPO4" "docs/ship-flow/fx-fresh-shape" "$OUT4" "$RC4"
DIFF4="${REPO4}/.context/ship-flow/source-diff-fx.yaml"

assert_exit "DC-4: resolver exits 0 on fresh-shape fixture" 0 "$(cat "$RC4")"
if [ -f "$DIFF4" ]; then
  assert_contains "DC-4: writes guard_required: false" '^guard_required: false$' "$DIFF4"
  assert_not_contains "DC-4: no source-diff fields (no original_issue_acs)" '^original_issue_acs:' "$DIFF4"
else
  record_fail "DC-4: writes guard_required: false (marker file missing: $DIFF4)"
fi

# ---------------------------------------------------------------------------
# DC-5 — fx-reshape-no-issue: honors "never faked" AC by halting for captain
# ---------------------------------------------------------------------------

REPO5="${TMP_DIR}/repo-dc5"
new_repo "$REPO5"
write_entity_index "${REPO5}/docs/ship-flow/fx-reshape-no-issue/index.md" "design" "" ""
: > "${REPO5}/docs/ship-flow/fx-reshape-no-issue/design.md"
OUT5="${TMP_DIR}/dc5.out"; RC5="${TMP_DIR}/dc5.rc"
run_resolver_emit "$REPO5" "docs/ship-flow/fx-reshape-no-issue" "$OUT5" "$RC5"
DIFF5="${REPO5}/.context/ship-flow/source-diff-fx.yaml"

assert_exit "DC-5: resolver exits 0 on re-shape-no-issue fixture" 0 "$(cat "$RC5")"
if [ -f "$DIFF5" ]; then
  assert_contains "DC-5: writes no_issue_anchor: true" '^no_issue_anchor: true$' "$DIFF5"
  assert_contains "DC-5: writes captain_prompt marker" '^captain_prompt:' "$DIFF5"
  assert_not_contains "DC-5: never a fake diff (no original_issue_acs)" '^original_issue_acs:' "$DIFF5"
else
  record_fail "DC-5: writes no_issue_anchor: true (marker file missing: $DIFF5)"
  record_fail "DC-5: writes captain_prompt marker"
fi

# ---------------------------------------------------------------------------
# DC-6 — ship-shape SKILL.md pinned wiring block, present before Intake
# ---------------------------------------------------------------------------

if [ -f "$SKILL" ]; then
  SECTION_LINE="$(grep -n '<!-- section:issue-anchor-guard -->' "$SKILL" | head -1 | cut -d: -f1)"
  INTAKE_LINE="$(grep -n '^### Intake$' "$SKILL" | head -1 | cut -d: -f1)"
  if [ -n "$SECTION_LINE" ] && [ -n "$INTAKE_LINE" ] && [ "$SECTION_LINE" -lt "$INTAKE_LINE" ]; then
    record_pass "DC-6: ship-shape SKILL.md has <!-- section:issue-anchor-guard --> before ### Intake"
  else
    record_fail "DC-6: ship-shape SKILL.md has <!-- section:issue-anchor-guard --> before ### Intake (section_line=${SECTION_LINE:-absent}, intake_line=${INTAKE_LINE:-absent})"
  fi
  assert_contains "DC-6: SKILL.md references the mod path" '_mods/issue-anchor-guard\.md' "$SKILL"
else
  record_fail "DC-6: ship-shape SKILL.md has <!-- section:issue-anchor-guard --> before ### Intake (SKILL.md not found)"
  record_fail "DC-6: SKILL.md references the mod path"
fi

# ---------------------------------------------------------------------------
# DC-7 — non-hollow rule: validate mode rejects a crafted proceed+non-subset combo
# ---------------------------------------------------------------------------

HOLLOW_FIXTURE="${TMP_DIR}/hollow-source-diff.yaml"
cat > "$HOLLOW_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
issue_ref: "gh#49"
issue_fetched_at: "2026-07-17T00:00:00Z"
original_issue_acs:
  - text: "AC-1: some criterion"
    met_by_existing_capability: false
current_scope_delta:
  - "an extra feature the issue never asked for"
scope_subset_of_issue: false
goal_still_unmet: true
verdict: proceed
rationale: "hand-crafted hollow claim citing AC-1"
EOF
OUT7="${TMP_DIR}/dc7.out"; RC7=0
bash "$RESOLVER" validate "--file=${HOLLOW_FIXTURE}" > "$OUT7" 2>&1 || RC7=$?
if [ "$RC7" != "0" ]; then
  record_pass "DC-7: validate rejects verdict=proceed with scope_subset_of_issue=false (non-hollow rule)"
else
  record_fail "DC-7: validate rejects verdict=proceed with scope_subset_of_issue=false (non-hollow rule) (exited 0: $(cat "$OUT7"))"
fi

HONEST_FIXTURE="${TMP_DIR}/honest-source-diff.yaml"
cat > "$HONEST_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
issue_ref: "gh#49"
issue_fetched_at: "2026-07-17T00:00:00Z"
original_issue_acs:
  - text: "AC-1: some criterion"
    met_by_existing_capability: false
current_scope_delta: []
scope_subset_of_issue: true
goal_still_unmet: true
verdict: proceed
rationale: "honest claim citing AC-1"
EOF
OUT7B="${TMP_DIR}/dc7b.out"; RC7B=0
bash "$RESOLVER" validate "--file=${HONEST_FIXTURE}" > "$OUT7B" 2>&1 || RC7B=$?
assert_exit "DC-7: validate accepts a consistent proceed (scope_subset=true, goal_unmet=true)" 0 "$RC7B"

BAD_ENUM_FIXTURE="${TMP_DIR}/bad-enum-source-diff.yaml"
cat > "$BAD_ENUM_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
verdict: re-anchor
scope_subset_of_issue: true
goal_still_unmet: true
EOF
OUT7C="${TMP_DIR}/dc7c.out"; RC7C=0
bash "$RESOLVER" validate "--file=${BAD_ENUM_FIXTURE}" > "$OUT7C" 2>&1 || RC7C=$?
if [ "$RC7C" != "0" ]; then
  record_pass "DC-7: validate rejects a verdict value outside proceed/narrow/return (CD1 vocabulary lock)"
else
  record_fail "DC-7: validate rejects a verdict value outside proceed/narrow/return (CD1 vocabulary lock)"
fi

# ---------------------------------------------------------------------------
# DC-8a — empty-string issue: treated as absent, not truthy
# ---------------------------------------------------------------------------

REPO8A="${TMP_DIR}/repo-dc8a"
new_repo "$REPO8A"
write_entity_index "${REPO8A}/docs/ship-flow/fx-empty-issue/index.md" "design" 'issue: ""' "gh"
: > "${REPO8A}/docs/ship-flow/fx-empty-issue/design.md"
OUT8A="${TMP_DIR}/dc8a.out"; RC8A="${TMP_DIR}/dc8a.rc"
run_resolver_emit "$REPO8A" "docs/ship-flow/fx-empty-issue" "$OUT8A" "$RC8A"
DIFF8A="${REPO8A}/.context/ship-flow/source-diff-fx.yaml"

assert_exit "DC-8a: resolver exits 0 on empty-string issue fixture" 0 "$(cat "$RC8A")"
if [ -f "$DIFF8A" ]; then
  assert_contains "DC-8a: empty-string issue: treated identically to absent (no_issue_anchor: true)" '^no_issue_anchor: true$' "$DIFF8A"
else
  record_fail "DC-8a: empty-string issue: treated identically to absent (no_issue_anchor: true) (marker file missing: $DIFF8A)"
fi

# ---------------------------------------------------------------------------
# DC-8b — gh failure fails visible, never a fake-empty AC list
# ---------------------------------------------------------------------------

REPO8B="${TMP_DIR}/repo-dc8b"
new_repo "$REPO8B"
write_entity_index "${REPO8B}/docs/ship-flow/fx-gh-failure/index.md" "design" 'issue: "#49"' "gh"
: > "${REPO8B}/docs/ship-flow/fx-gh-failure/design.md"
FAKEBIN8B="${TMP_DIR}/fakebin-dc8b"
write_fake_gh_failing "$FAKEBIN8B"
OUT8B="${TMP_DIR}/dc8b.out"; RC8B="${TMP_DIR}/dc8b.rc"
run_resolver_emit "$REPO8B" "docs/ship-flow/fx-gh-failure" "$OUT8B" "$RC8B" "$FAKEBIN8B"
DIFF8B="${REPO8B}/.context/ship-flow/source-diff-fx.yaml"

if [ "$(cat "$RC8B")" != "0" ]; then
  record_pass "DC-8b: gh failure exits non-zero (never silently falls through)"
else
  record_fail "DC-8b: gh failure exits non-zero (never silently falls through)"
fi
if grep -qiE 'rate limit|gh issue view|BLOCKED|error' "$OUT8B"; then
  record_pass "DC-8b: gh failure prints a captain-visible error message"
else
  record_fail "DC-8b: gh failure prints a captain-visible error message (got: $(cat "$OUT8B"))"
fi
if [ ! -f "$DIFF8B" ]; then
  record_pass "DC-8b: no YAML written on gh failure (never a fake-empty AC list)"
else
  record_fail "DC-8b: no YAML written on gh failure (never a fake-empty AC list) (found: $DIFF8B)"
fi

# ---------------------------------------------------------------------------
# Doc-coupling row (T3) — bidirectional coupling for mod <-> SKILL.md
# ---------------------------------------------------------------------------

if [ -f "$DOC_COUPLING_MAP" ]; then
  assert_contains "T3: doc-coupling-map.yaml declares issue-anchor-guard row" 'name: issue-anchor-guard' "$DOC_COUPLING_MAP"
  assert_contains "T3: doc-coupling-map.yaml row is bidirectional" 'directions: \["source-to-doc", "doc-to-source"\]' "$DOC_COUPLING_MAP"
else
  record_fail "T3: doc-coupling-map.yaml declares issue-anchor-guard row (file not found)"
  record_fail "T3: doc-coupling-map.yaml row is bidirectional"
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "All assertions passed"
