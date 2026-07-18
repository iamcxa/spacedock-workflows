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
# DC-6 — ship-shape SKILL.md pinned wiring block, GATED to run after Intake
# (corrected P1-r3-1, cycle 5): the guard must fire only once Intake has
# determined the directive matches an EXISTING entity (re-shape), never
# before Intake has had a chance to detect a brand-new free-text/todo shape.
# ---------------------------------------------------------------------------

if [ -f "$SKILL" ]; then
  SECTION_LINE="$(grep -n '<!-- section:issue-anchor-guard -->' "$SKILL" | head -1 | cut -d: -f1)"
  INTAKE_LINE="$(grep -n '^### Intake$' "$SKILL" | head -1 | cut -d: -f1)"
  if [ -n "$SECTION_LINE" ] && [ -n "$INTAKE_LINE" ] && [ "$SECTION_LINE" -gt "$INTAKE_LINE" ]; then
    record_pass "DC-6: ship-shape SKILL.md has <!-- section:issue-anchor-guard --> after ### Intake (P1-r3-1: gated on Intake's new-vs-existing detection)"
  else
    record_fail "DC-6: ship-shape SKILL.md has <!-- section:issue-anchor-guard --> after ### Intake (P1-r3-1: gated on Intake's new-vs-existing detection) (section_line=${SECTION_LINE:-absent}, intake_line=${INTAKE_LINE:-absent})"
  fi
  assert_contains "DC-6: SKILL.md references the mod path" '_mods/issue-anchor-guard\.md' "$SKILL"
else
  record_fail "DC-6: ship-shape SKILL.md has <!-- section:issue-anchor-guard --> after ### Intake (SKILL.md not found)"
  record_fail "DC-6: SKILL.md references the mod path"
fi

# ---------------------------------------------------------------------------
# DC-17 (P1-r3-1) — the guard invocation is GATED so it fires ONLY when
# Intake matched an EXISTING entity (the "Entity id" row — a re-shape of
# `/shape <entity-id>`); a brand-new free-text or todo-based /shape must
# never reach the resolver at all, so it can never hit "entity path not
# found". ship-shape/SKILL.md is prose an LLM executes (no runtime harness
# invokes it directly), so the end-to-end proof here is structural: the
# pinned section's own text names the gating condition (Entity id) and both
# excluded forms (Free text, Todo tid) plus the exact failure mode it
# prevents, so a future refactor cannot silently drop the gate without this
# test catching it. A companion resolver-level check confirms the
# defensive "entity path not found" BLOCK itself was never weakened to a
# silent no-op (that would mask a real caller bug; the SKILL.md gate above
# is what actually protects a genuine new-shape directive).
# ---------------------------------------------------------------------------

SKILL_SECTION="${TMP_DIR}/skill-issue-anchor-guard-section.txt"
if [ -f "$SKILL" ]; then
  awk '
    /<!-- section:issue-anchor-guard -->/ { found=1; next }
    /<!-- \/section:issue-anchor-guard -->/ { exit }
    found { print }
  ' "$SKILL" > "$SKILL_SECTION"
else
  : > "$SKILL_SECTION"
fi

assert_contains "DC-17: guard section text gates on Intake's Entity id match" 'Entity id' "$SKILL_SECTION"
assert_contains "DC-17: guard section text excludes the Free text intake form (never invoked for a brand-new free-text shape)" 'Free text' "$SKILL_SECTION"
assert_contains "DC-17: guard section text excludes the Todo tid intake form" 'Todo tid' "$SKILL_SECTION"
assert_contains "DC-17: guard section text names the 'entity path not found' failure mode this gate prevents" 'entity path not found' "$SKILL_SECTION"

REPO17="${TMP_DIR}/repo-dc17"
new_repo "$REPO17"
OUT17="${TMP_DIR}/dc17.out"; RC17="${TMP_DIR}/dc17.rc"
run_resolver_emit "$REPO17" "docs/ship-flow/99-brand-new-freetext-shape" "$OUT17" "$RC17"
if [ "$(cat "$RC17")" != "0" ]; then
  record_pass "DC-17: resolver's own defensive layer still fails closed on a genuinely nonexistent entity path (belt-and-braces; the SKILL.md gate is the primary protection for a real free-text/todo shape)"
else
  record_fail "DC-17: resolver's own defensive layer still fails closed on a genuinely nonexistent entity path"
fi
if grep -qi 'entity path not found' "$OUT17"; then
  record_pass "DC-17: the defensive-layer error names 'entity path not found' explicitly, matching the SKILL.md gate's own prose"
else
  record_fail "DC-17: the defensive-layer error names 'entity path not found' explicitly (got: $(cat "$OUT17"))"
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
# DC-10 (P1-1) — validate derives goal_still_unmet + verdict from the
# per-AC met_by_existing_capability rows; never trusts the
# independently-editable scalar fields alone. A proceed with zero/removed
# AC rows, or scalars inconsistent with the rows, must BLOCK.
# ---------------------------------------------------------------------------

EMPTY_ACS_FIXTURE="${TMP_DIR}/empty-acs-source-diff.yaml"
cat > "$EMPTY_ACS_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
issue_ref: "gh#49"
issue_fetched_at: "2026-07-17T00:00:00Z"
original_issue_acs: []
current_scope_delta: []
scope_subset_of_issue: true
goal_still_unmet: true
verdict: proceed
rationale: "claims proceed with zero AC rows to back it"
EOF
OUT10A="${TMP_DIR}/dc10a.out"; RC10A=0
bash "$RESOLVER" validate "--file=${EMPTY_ACS_FIXTURE}" > "$OUT10A" 2>&1 || RC10A=$?
if [ "$RC10A" != "0" ]; then
  record_pass "DC-10: validate BLOCKs a proceed with zero/removed original_issue_acs[] rows"
else
  record_fail "DC-10: validate BLOCKs a proceed with zero/removed original_issue_acs[] rows (exited 0: $(cat "$OUT10A"))"
fi

ALL_MET_FIXTURE="${TMP_DIR}/all-met-source-diff.yaml"
cat > "$ALL_MET_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
issue_ref: "gh#49"
issue_fetched_at: "2026-07-17T00:00:00Z"
original_issue_acs:
  - text: "AC-1: some criterion"
    met_by_existing_capability: true
  - text: "AC-2: another criterion"
    met_by_existing_capability: true
current_scope_delta: []
scope_subset_of_issue: true
goal_still_unmet: true
verdict: proceed
rationale: "falsely claims goal_still_unmet=true though every AC row is met_by_existing_capability=true"
EOF
OUT10B="${TMP_DIR}/dc10b.out"; RC10B=0
bash "$RESOLVER" validate "--file=${ALL_MET_FIXTURE}" > "$OUT10B" 2>&1 || RC10B=$?
if [ "$RC10B" != "0" ]; then
  record_pass "DC-10: validate BLOCKs goal_still_unmet=true when every per-AC row is met_by_existing_capability=true (derived=false)"
else
  record_fail "DC-10: validate BLOCKs goal_still_unmet=true when every per-AC row is met_by_existing_capability=true (derived=false) (exited 0: $(cat "$OUT10B"))"
fi

MULTI_ROW_FIXTURE="${TMP_DIR}/multi-row-source-diff.yaml"
cat > "$MULTI_ROW_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
issue_ref: "gh#49"
issue_fetched_at: "2026-07-17T00:00:00Z"
original_issue_acs:
  - text: "AC-1: some criterion"
    met_by_existing_capability: true
  - text: "AC-2: another criterion"
    met_by_existing_capability: false
current_scope_delta: []
scope_subset_of_issue: true
goal_still_unmet: true
verdict: proceed
rationale: "honest: AC-2 still unmet even though AC-1 is already covered"
EOF
OUT10C="${TMP_DIR}/dc10c.out"; RC10C=0
bash "$RESOLVER" validate "--file=${MULTI_ROW_FIXTURE}" > "$OUT10C" 2>&1 || RC10C=$?
assert_exit "DC-10: validate accepts a consistent multi-row proceed (derived from ANY-false-row aggregation, not just row 1)" 0 "$RC10C"

# ---------------------------------------------------------------------------
# DC-11 (P1-2) — AC parser captures a multiline continuation block, or
# fails closed (never accepts an empty anchor) when a matched AC heading
# has no substantive criterion text anywhere in its block.
# ---------------------------------------------------------------------------

MULTILINE_BODY='## Acceptance

AC-1: Guard writes a five-field source-diff YAML for a re-shaped entity.
AC-2:
  Guard no-ops on a fresh shape with no later-stage artifacts,
  even when invoked twice in a row.
AC-3: Guard never fakes an AC list when the tracker call fails.'

REPO11A="${TMP_DIR}/repo-dc11a"
new_repo "$REPO11A"
write_entity_index "${REPO11A}/docs/ship-flow/fx-multiline-ac/index.md" "design" 'issue: "#49"' "gh"
: > "${REPO11A}/docs/ship-flow/fx-multiline-ac/design.md"
FAKEBIN11A="${TMP_DIR}/fakebin-dc11a"
write_fake_gh_ok "$FAKEBIN11A" "$MULTILINE_BODY"
OUT11A="${TMP_DIR}/dc11a.out"; RC11A="${TMP_DIR}/dc11a.rc"
run_resolver_emit "$REPO11A" "docs/ship-flow/fx-multiline-ac" "$OUT11A" "$RC11A" "$FAKEBIN11A"
DIFF11A="${REPO11A}/.context/ship-flow/source-diff-fx.yaml"

assert_exit "DC-11: resolver exits 0 on a multiline-continuation AC body" 0 "$(cat "$RC11A")"
if [ -f "$DIFF11A" ]; then
  assert_contains "DC-11: multiline AC-2 continuation text is captured in original_issue_acs" 'no later-stage artifacts, even when invoked twice in a row' "$DIFF11A"
else
  record_fail "DC-11: multiline AC-2 continuation text is captured in original_issue_acs (missing: $DIFF11A)"
fi

EMPTY_HEADING_BODY='## Acceptance

AC-1: Guard writes a five-field source-diff YAML for a re-shaped entity.
AC-2:

AC-3: Guard never fakes an AC list when the tracker call fails.'

REPO11B="${TMP_DIR}/repo-dc11b"
new_repo "$REPO11B"
write_entity_index "${REPO11B}/docs/ship-flow/fx-empty-ac-heading/index.md" "design" 'issue: "#49"' "gh"
: > "${REPO11B}/docs/ship-flow/fx-empty-ac-heading/design.md"
FAKEBIN11B="${TMP_DIR}/fakebin-dc11b"
write_fake_gh_ok "$FAKEBIN11B" "$EMPTY_HEADING_BODY"
OUT11B="${TMP_DIR}/dc11b.out"; RC11B="${TMP_DIR}/dc11b.rc"
run_resolver_emit "$REPO11B" "docs/ship-flow/fx-empty-ac-heading" "$OUT11B" "$RC11B" "$FAKEBIN11B"
DIFF11B="${REPO11B}/.context/ship-flow/source-diff-fx.yaml"

if [ "$(cat "$RC11B")" != "0" ]; then
  record_pass "DC-11: resolver fails closed (non-zero) when a matched AC heading has no substantive criterion text"
else
  record_fail "DC-11: resolver fails closed (non-zero) when a matched AC heading has no substantive criterion text"
fi
if [ ! -f "$DIFF11B" ]; then
  record_pass "DC-11: no YAML written when an AC heading is empty (never an empty-but-accepted anchor)"
else
  record_fail "DC-11: no YAML written when an AC heading is empty (never an empty-but-accepted anchor) (found: $DIFF11B)"
fi
if grep -qiE 'AC-2|empty|no substantive|BLOCKED' "$OUT11B"; then
  record_pass "DC-11: empty-AC-heading failure prints a captain-visible error message"
else
  record_fail "DC-11: empty-AC-heading failure prints a captain-visible error message (got: $(cat "$OUT11B"))"
fi

EMPTY_HEADING_AT_EOF_BODY='## Acceptance

AC-1: Guard writes a five-field source-diff YAML for a re-shaped entity.
AC-2:'

REPO11C="${TMP_DIR}/repo-dc11c"
new_repo "$REPO11C"
write_entity_index "${REPO11C}/docs/ship-flow/fx-empty-ac-eof/index.md" "design" 'issue: "#49"' "gh"
: > "${REPO11C}/docs/ship-flow/fx-empty-ac-eof/design.md"
FAKEBIN11C="${TMP_DIR}/fakebin-dc11c"
write_fake_gh_ok "$FAKEBIN11C" "$EMPTY_HEADING_AT_EOF_BODY"
OUT11C="${TMP_DIR}/dc11c.out"; RC11C="${TMP_DIR}/dc11c.rc"
run_resolver_emit "$REPO11C" "docs/ship-flow/fx-empty-ac-eof" "$OUT11C" "$RC11C" "$FAKEBIN11C"
DIFF11C="${REPO11C}/.context/ship-flow/source-diff-fx.yaml"

if [ "$(cat "$RC11C")" != "0" ]; then
  record_pass "DC-11: resolver fails closed when the empty AC heading is the last line of the issue body (EOF, no trailing blank line)"
else
  record_fail "DC-11: resolver fails closed when the empty AC heading is the last line of the issue body (EOF, no trailing blank line)"
fi
if [ ! -f "$DIFF11C" ]; then
  record_pass "DC-11: no YAML written when the empty AC heading is at EOF"
else
  record_fail "DC-11: no YAML written when the empty AC heading is at EOF (found: $DIFF11C)"
fi

# ---------------------------------------------------------------------------
# DC-12 (P1-3) — issue-ref resolution preserves canonical owner/repo
# identity; a cross-repo or ambiguous reference fails VISIBLE BLOCK rather
# than being silently reduced to a bare #N and anchored to the wrong
# same-number local issue.
# ---------------------------------------------------------------------------

# Each fixture below is paired with a `gh` stub that WOULD succeed (return
# CANNED_BODY, exit 0) if the resolver ever invoked it -- proving a BLOCK
# here comes from the guard's own reference-parsing logic, not a real `gh`
# CLI 404/auth failure against the placeholder "other-org/other-repo" (which
# would be a network-dependent false pass/fail, not a deterministic test).

REPO12A="${TMP_DIR}/repo-dc12a"
new_repo "$REPO12A"
write_entity_index "${REPO12A}/docs/ship-flow/fx-cross-repo-url/index.md" "design" 'issue: "https://github.com/other-org/other-repo/issues/49"' "gh"
: > "${REPO12A}/docs/ship-flow/fx-cross-repo-url/design.md"
FAKEBIN12A="${TMP_DIR}/fakebin-dc12a"
write_fake_gh_ok "$FAKEBIN12A" "$CANNED_BODY"
OUT12A="${TMP_DIR}/dc12a.out"; RC12A="${TMP_DIR}/dc12a.rc"
run_resolver_emit "$REPO12A" "docs/ship-flow/fx-cross-repo-url" "$OUT12A" "$RC12A" "$FAKEBIN12A"
DIFF12A="${REPO12A}/.context/ship-flow/source-diff-fx.yaml"

if [ "$(cat "$RC12A")" != "0" ]; then
  record_pass "DC-12: resolver BLOCKs a cross-repo full-URL issue: reference (fail-visible, never silently reduced to local #N)"
else
  record_fail "DC-12: resolver BLOCKs a cross-repo full-URL issue: reference (fail-visible, never silently reduced to local #N)"
fi
if [ ! -f "$DIFF12A" ]; then
  record_pass "DC-12: no YAML written for a cross-repo full-URL reference"
else
  record_fail "DC-12: no YAML written for a cross-repo full-URL reference (found: $DIFF12A)"
fi
if grep -qiE 'cross-repo|other-org/other-repo|BLOCKED' "$OUT12A"; then
  record_pass "DC-12: cross-repo full-URL failure names the foreign owner/repo in its captain-visible message"
else
  record_fail "DC-12: cross-repo full-URL failure names the foreign owner/repo in its captain-visible message (got: $(cat "$OUT12A"))"
fi

REPO12B="${TMP_DIR}/repo-dc12b"
new_repo "$REPO12B"
write_entity_index "${REPO12B}/docs/ship-flow/fx-cross-repo-shorthand/index.md" "design" 'issue: "other-org/other-repo#49"' "gh"
: > "${REPO12B}/docs/ship-flow/fx-cross-repo-shorthand/design.md"
FAKEBIN12B="${TMP_DIR}/fakebin-dc12b"
write_fake_gh_ok "$FAKEBIN12B" "$CANNED_BODY"
OUT12B="${TMP_DIR}/dc12b.out"; RC12B="${TMP_DIR}/dc12b.rc"
run_resolver_emit "$REPO12B" "docs/ship-flow/fx-cross-repo-shorthand" "$OUT12B" "$RC12B" "$FAKEBIN12B"
DIFF12B="${REPO12B}/.context/ship-flow/source-diff-fx.yaml"

if [ "$(cat "$RC12B")" != "0" ]; then
  record_pass "DC-12: resolver BLOCKs a cross-repo 'owner/repo#N' shorthand reference"
else
  record_fail "DC-12: resolver BLOCKs a cross-repo 'owner/repo#N' shorthand reference"
fi
if [ ! -f "$DIFF12B" ]; then
  record_pass "DC-12: no YAML written for a cross-repo shorthand reference"
else
  record_fail "DC-12: no YAML written for a cross-repo shorthand reference (found: $DIFF12B)"
fi

REPO12C="${TMP_DIR}/repo-dc12c"
new_repo "$REPO12C"
write_entity_index "${REPO12C}/docs/ship-flow/fx-ambiguous-ref/index.md" "design" 'issue: "not-a-valid-ref"' "gh"
: > "${REPO12C}/docs/ship-flow/fx-ambiguous-ref/design.md"
FAKEBIN12C="${TMP_DIR}/fakebin-dc12c"
write_fake_gh_ok "$FAKEBIN12C" "$CANNED_BODY"
OUT12C="${TMP_DIR}/dc12c.out"; RC12C="${TMP_DIR}/dc12c.rc"
run_resolver_emit "$REPO12C" "docs/ship-flow/fx-ambiguous-ref" "$OUT12C" "$RC12C" "$FAKEBIN12C"
DIFF12C="${REPO12C}/.context/ship-flow/source-diff-fx.yaml"

if [ "$(cat "$RC12C")" != "0" ]; then
  record_pass "DC-12: resolver BLOCKs an ambiguous issue: reference that is neither a same-repo #N nor a recognized owner/repo form"
else
  record_fail "DC-12: resolver BLOCKs an ambiguous issue: reference that is neither a same-repo #N nor a recognized owner/repo form"
fi
if [ ! -f "$DIFF12C" ]; then
  record_pass "DC-12: no YAML written for an ambiguous reference"
else
  record_fail "DC-12: no YAML written for an ambiguous reference (found: $DIFF12C)"
fi

# ---------------------------------------------------------------------------
# DC-13 (P1-4) — the source-diff artifact is run-scoped/tombstoned: a later
# failure exit invalidates/removes any earlier file for the same entity, so
# a prior run's stale `proceed` can never be validated after a later
# gh-failure (or an overlapping re-shape).
# ---------------------------------------------------------------------------

REPO13="${TMP_DIR}/repo-dc13"
new_repo "$REPO13"
write_entity_index "${REPO13}/docs/ship-flow/fx-tombstone/index.md" "design" 'issue: "#49"' "gh"
: > "${REPO13}/docs/ship-flow/fx-tombstone/design.md"
FAKEBIN13_OK="${TMP_DIR}/fakebin-dc13-ok"
write_fake_gh_ok "$FAKEBIN13_OK" "$CANNED_BODY"
OUT13A="${TMP_DIR}/dc13a.out"; RC13A="${TMP_DIR}/dc13a.rc"
run_resolver_emit "$REPO13" "docs/ship-flow/fx-tombstone" "$OUT13A" "$RC13A" "$FAKEBIN13_OK"
DIFF13="${REPO13}/.context/ship-flow/source-diff-fx.yaml"
assert_exit "DC-13 setup: first emit run (stale-proceed producer) exits 0" 0 "$(cat "$RC13A")"
if [ ! -f "$DIFF13" ]; then
  record_fail "DC-13 setup: first emit run wrote a source-diff (prereq for the tombstone check)"
fi

FAKEBIN13_FAIL="${TMP_DIR}/fakebin-dc13-fail"
write_fake_gh_failing "$FAKEBIN13_FAIL"
OUT13B="${TMP_DIR}/dc13b.out"; RC13B="${TMP_DIR}/dc13b.rc"
run_resolver_emit "$REPO13" "docs/ship-flow/fx-tombstone" "$OUT13B" "$RC13B" "$FAKEBIN13_FAIL"

if [ "$(cat "$RC13B")" != "0" ]; then
  record_pass "DC-13: second (gh-failure) emit run on the same entity still exits non-zero"
else
  record_fail "DC-13: second (gh-failure) emit run on the same entity still exits non-zero"
fi
if [ ! -f "$DIFF13" ]; then
  record_pass "DC-13: a later gh-failure tombstones the earlier run's source-diff file (no stale proceed survives)"
else
  record_fail "DC-13: a later gh-failure tombstones the earlier run's source-diff file (no stale proceed survives) (file still present: $DIFF13)"
fi

OUT13C="${TMP_DIR}/dc13c.out"; RC13C=0
(cd "$REPO13" && bash "$RESOLVER" validate "--file=.context/ship-flow/source-diff-fx.yaml") > "$OUT13C" 2>&1 || RC13C=$?
if [ "$RC13C" != "0" ]; then
  record_pass "DC-13: validate BLOCKs against the tombstoned path — the stale proceed can never be validated after the later gh-failure"
else
  record_fail "DC-13: validate BLOCKs against the tombstoned path — the stale proceed can never be validated after the later gh-failure (exited 0: $(cat "$OUT13C"))"
fi

# ---------------------------------------------------------------------------
# DC-14 (P1-A, cycle 4) — validate STRUCTURALLY parses original_issue_acs[]
# via yq (not a fragile text scan): every row must have non-empty criterion
# text AND a real boolean met_by_existing_capability. Missing/empty/malformed
# rows must BLOCK; a text value that merely contains a substring resembling
# a "met_by_existing_capability:" key must never be miscounted as a phantom
# row (a fragile line-oriented text scan is fooled by this; a structural
# parse is not).
# ---------------------------------------------------------------------------

EMPTY_TEXT_FIXTURE="${TMP_DIR}/empty-text-source-diff.yaml"
cat > "$EMPTY_TEXT_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
issue_ref: "gh#49"
issue_fetched_at: "2026-07-17T00:00:00Z"
original_issue_acs:
  - text: ""
    met_by_existing_capability: false
current_scope_delta: []
scope_subset_of_issue: true
goal_still_unmet: true
verdict: proceed
rationale: "claims proceed backed by a row with empty criterion text"
EOF
OUT14A="${TMP_DIR}/dc14a.out"; RC14A=0
bash "$RESOLVER" validate "--file=${EMPTY_TEXT_FIXTURE}" > "$OUT14A" 2>&1 || RC14A=$?
if [ "$RC14A" != "0" ]; then
  record_pass "DC-14: validate BLOCKs a row with empty/missing criterion text (structural yq check, not just the boolean)"
else
  record_fail "DC-14: validate BLOCKs a row with empty/missing criterion text (structural yq check, not just the boolean) (exited 0: $(cat "$OUT14A"))"
fi

MALFORMED_BOOL_FIXTURE="${TMP_DIR}/malformed-bool-source-diff.yaml"
cat > "$MALFORMED_BOOL_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
issue_ref: "gh#49"
issue_fetched_at: "2026-07-17T00:00:00Z"
original_issue_acs:
  - text: "AC-1: some criterion"
    met_by_existing_capability: maybe
current_scope_delta: []
scope_subset_of_issue: true
goal_still_unmet: true
verdict: proceed
rationale: "claims proceed backed by a non-boolean met_by_existing_capability value"
EOF
OUT14B="${TMP_DIR}/dc14b.out"; RC14B=0
bash "$RESOLVER" validate "--file=${MALFORMED_BOOL_FIXTURE}" > "$OUT14B" 2>&1 || RC14B=$?
if [ "$RC14B" != "0" ]; then
  record_pass "DC-14: validate BLOCKs a row whose met_by_existing_capability is not a real boolean (e.g. 'maybe'), never silently coercing it to false"
else
  record_fail "DC-14: validate BLOCKs a row whose met_by_existing_capability is not a real boolean (exited 0: $(cat "$OUT14B"))"
fi

# A single real, well-formed row (met_by_existing_capability: true) whose text
# happens to contain a substring shaped like a YAML "met_by_existing_capability:"
# key. A line-oriented text scan over the whole original_issue_acs: block would
# match this substring as a SECOND (phantom) row and mis-derive goal_still_unmet
# as true; a structural yq parse addresses exactly one row (index 0) and must
# derive goal_still_unmet: false (verdict: return), matching the fixture.
DUPLICATE_COUNT_FIXTURE="${TMP_DIR}/duplicate-count-source-diff.yaml"
cat > "$DUPLICATE_COUNT_FIXTURE" <<'EOF'
schema_version: "1.0"
entity_id: "fx"
issue_ref: "gh#49"
issue_fetched_at: "2026-07-17T00:00:00Z"
original_issue_acs:
  - text: "AC-1: legit criterion mentions met_by_existing_capability: false as trivia"
    met_by_existing_capability: true
current_scope_delta: []
scope_subset_of_issue: true
goal_still_unmet: false
verdict: return
rationale: "AC-1 is fully met by existing capability; issue can be closed/deferred"
EOF
OUT14C="${TMP_DIR}/dc14c.out"; RC14C=0
bash "$RESOLVER" validate "--file=${DUPLICATE_COUNT_FIXTURE}" > "$OUT14C" 2>&1 || RC14C=$?
if [ "$RC14C" = "0" ]; then
  record_pass "DC-14: validate ACCEPTS a consistent single-row verdict=return even when the row's own text contains a met_by_existing_capability-shaped substring (structural parse, no phantom-row miscount)"
else
  record_fail "DC-14: validate ACCEPTS a consistent single-row verdict=return even when the row's own text contains a met_by_existing_capability-shaped substring (exited ${RC14C}: $(cat "$OUT14C"))"
fi

# ---------------------------------------------------------------------------
# DC-15 (P1-B, cycle 4) — a full GitHub issue URL whose owner/repo VERIFIES
# against the local git remote (origin) is canonicalized to a bare #N and
# ACCEPTED (so ship-shape/SKILL.md's advertised full-URL intake works
# end-to-end); an unverifiable/mismatched owner-repo still fails VISIBLE
# BLOCK exactly as before.
# ---------------------------------------------------------------------------

REPO15A="${TMP_DIR}/repo-dc15a"
new_repo "$REPO15A"
(cd "$REPO15A" && git init -q && git remote add origin https://github.com/acme/widgets.git)
write_entity_index "${REPO15A}/docs/ship-flow/fx-verified-same-repo-url/index.md" "design" 'issue: "https://github.com/acme/widgets/issues/49"' "gh"
: > "${REPO15A}/docs/ship-flow/fx-verified-same-repo-url/design.md"
FAKEBIN15A="${TMP_DIR}/fakebin-dc15a"
write_fake_gh_ok "$FAKEBIN15A" "$CANNED_BODY"
OUT15A="${TMP_DIR}/dc15a.out"; RC15A="${TMP_DIR}/dc15a.rc"
run_resolver_emit "$REPO15A" "docs/ship-flow/fx-verified-same-repo-url" "$OUT15A" "$RC15A" "$FAKEBIN15A"
DIFF15A="${REPO15A}/.context/ship-flow/source-diff-fx.yaml"

assert_exit "DC-15: resolver ACCEPTS a full GitHub issue URL verified against the local git remote (same owner/repo)" 0 "$(cat "$RC15A")"
if [ -f "$DIFF15A" ]; then
  assert_contains "DC-15: verified same-repo URL is canonicalized to issue_ref: \"gh#49\"" '^issue_ref: "gh#49"$' "$DIFF15A"
else
  record_fail "DC-15: verified same-repo URL is canonicalized to issue_ref: \"gh#49\" (missing: $DIFF15A)"
fi

REPO15B="${TMP_DIR}/repo-dc15b"
new_repo "$REPO15B"
(cd "$REPO15B" && git init -q && git remote add origin https://github.com/acme/widgets.git)
write_entity_index "${REPO15B}/docs/ship-flow/fx-unverified-cross-repo-url/index.md" "design" 'issue: "https://github.com/other-org/other-repo/issues/49"' "gh"
: > "${REPO15B}/docs/ship-flow/fx-unverified-cross-repo-url/design.md"
FAKEBIN15B="${TMP_DIR}/fakebin-dc15b"
write_fake_gh_ok "$FAKEBIN15B" "$CANNED_BODY"
OUT15B="${TMP_DIR}/dc15b.out"; RC15B="${TMP_DIR}/dc15b.rc"
run_resolver_emit "$REPO15B" "docs/ship-flow/fx-unverified-cross-repo-url" "$OUT15B" "$RC15B" "$FAKEBIN15B"
DIFF15B="${REPO15B}/.context/ship-flow/source-diff-fx.yaml"

if [ "$(cat "$RC15B")" != "0" ]; then
  record_pass "DC-15: resolver still BLOCKs a full GitHub URL whose owner/repo does NOT match the local git remote (genuinely cross-repo)"
else
  record_fail "DC-15: resolver still BLOCKs a full GitHub URL whose owner/repo does NOT match the local git remote (genuinely cross-repo)"
fi
if [ ! -f "$DIFF15B" ]; then
  record_pass "DC-15: no YAML written for an unverified cross-repo full-URL reference"
else
  record_fail "DC-15: no YAML written for an unverified cross-repo full-URL reference (found: $DIFF15B)"
fi

# ---------------------------------------------------------------------------
# DC-16 (P2-D, cycle 4) — the AC-block parser accepts ONLY properly-indented
# continuation lines and flushes (never silently absorbs) when unindented
# content begins, so a following section's prose can never masquerade as an
# AC's criterion text.
# ---------------------------------------------------------------------------

UNINDENTED_SECTION_BODY='## Acceptance

AC-1:
  Guard writes a five-field source-diff YAML for a re-shaped entity.
## Unrelated Section
This text must never be absorbed into AC-1.

AC-2: Guard no-ops on a fresh shape with no later-stage artifacts.
AC-3: Guard never fakes an AC list when the tracker call fails.'

REPO16A="${TMP_DIR}/repo-dc16a"
new_repo "$REPO16A"
write_entity_index "${REPO16A}/docs/ship-flow/fx-unindented-boundary/index.md" "design" 'issue: "#49"' "gh"
: > "${REPO16A}/docs/ship-flow/fx-unindented-boundary/design.md"
FAKEBIN16A="${TMP_DIR}/fakebin-dc16a"
write_fake_gh_ok "$FAKEBIN16A" "$UNINDENTED_SECTION_BODY"
OUT16A="${TMP_DIR}/dc16a.out"; RC16A="${TMP_DIR}/dc16a.rc"
run_resolver_emit "$REPO16A" "docs/ship-flow/fx-unindented-boundary" "$OUT16A" "$RC16A" "$FAKEBIN16A"
DIFF16A="${REPO16A}/.context/ship-flow/source-diff-fx.yaml"

assert_exit "DC-16: resolver exits 0 when AC-1's indented continuation is followed by an unindented section" 0 "$(cat "$RC16A")"
if [ -f "$DIFF16A" ]; then
  assert_contains "DC-16: AC-1 text captures only its own indented continuation" 'Guard writes a five-field source-diff YAML for a re-shaped entity\.' "$DIFF16A"
  assert_not_contains "DC-16: AC-1 text does NOT absorb the following unindented section heading" 'Unrelated Section' "$DIFF16A"
  assert_not_contains "DC-16: AC-1 text does NOT absorb the following unindented section's prose" 'never be absorbed' "$DIFF16A"
else
  record_fail "DC-16: AC-1 text captures only its own indented continuation (missing: $DIFF16A)"
  record_fail "DC-16: AC-1 text does NOT absorb the following unindented section heading"
  record_fail "DC-16: AC-1 text does NOT absorb the following unindented section's prose"
fi

EMPTY_VIA_UNINDENTED_BODY='## Acceptance

AC-1: Guard writes a five-field source-diff YAML for a re-shaped entity.
AC-2:
## Another Section
Some unrelated text that must never become AC-2 criterion text.

AC-3: Guard never fakes an AC list when the tracker call fails.'

REPO16B="${TMP_DIR}/repo-dc16b"
new_repo "$REPO16B"
write_entity_index "${REPO16B}/docs/ship-flow/fx-empty-then-unindented/index.md" "design" 'issue: "#49"' "gh"
: > "${REPO16B}/docs/ship-flow/fx-empty-then-unindented/design.md"
FAKEBIN16B="${TMP_DIR}/fakebin-dc16b"
write_fake_gh_ok "$FAKEBIN16B" "$EMPTY_VIA_UNINDENTED_BODY"
OUT16B="${TMP_DIR}/dc16b.out"; RC16B="${TMP_DIR}/dc16b.rc"
run_resolver_emit "$REPO16B" "docs/ship-flow/fx-empty-then-unindented" "$OUT16B" "$RC16B" "$FAKEBIN16B"
DIFF16B="${REPO16B}/.context/ship-flow/source-diff-fx.yaml"

if [ "$(cat "$RC16B")" != "0" ]; then
  record_pass "DC-16: resolver fails closed when a no-inline-text AC heading is immediately followed by an unindented section (never fabricates AC-2's criterion text from unrelated prose)"
else
  record_fail "DC-16: resolver fails closed when a no-inline-text AC heading is immediately followed by an unindented section (never fabricates AC-2's criterion text from unrelated prose)"
fi
if [ ! -f "$DIFF16B" ]; then
  record_pass "DC-16: no YAML written when the unindented-section boundary leaves AC-2 with no real criterion text"
else
  record_fail "DC-16: no YAML written when the unindented-section boundary leaves AC-2 with no real criterion text (found: $DIFF16B)"
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
