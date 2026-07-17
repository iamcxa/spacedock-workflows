#!/usr/bin/env bash
# test-shape-confirm.sh — DC-27..DC-30 for shape-confirm.sh atomic orchestrator
# Fixtures mirror test-frontmatter-helpers.sh isolation pattern.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
REPO_ROOT="$(cd "${LIB_DIR}/../../.." && pwd)"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

assert_stderr_contains() {
  local needle="$1" cmd="$2" name="$3"
  local err
  err="$(eval "$cmd" 2>&1 >/dev/null)"
  if echo "$err" | grep -qF "$needle"; then
    echo "OK $name"
  else
    echo "FAIL $name (stderr missing: $needle)"
    FAIL=1
  fi
}

# Fixture: isolated workflow tree in mktemp git repo with ROADMAP.md already section-marked
setup_fixture() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/docs/ship-flow/todos"
  # Minimal ROADMAP.md with section markers (Phase 0 state)
  cat > "$dir/ROADMAP.md" <<'EOF'
# Roadmap

<!-- section:next -->
## Next

| Entity | Size | Why it matters | Depends on |
|--------|------|----------------|------------|
<!-- /section:next -->

<!-- section:later -->
## Later

| Entity | Size | Why it matters | Triggered by |
|--------|------|----------------|--------------|
<!-- /section:later -->

<!-- section:not-doing -->
## Not Doing

| Entity | Reason |
|--------|--------|
<!-- /section:not-doing -->
EOF
  # Minimal schema (needed by patch-map.sh)
  mkdir -p "$dir/plugins/ship-flow/references"
  cat > "$dir/plugins/ship-flow/references/flow-map-schema.yaml" <<'EOF'
maps:
  ROADMAP.md:
    path: "ROADMAP.md"
    sections:
      - section_tag: next
        title: "Next"
        purpose: "test"
        requires_diagram: false
      - section_tag: later
        title: "Later"
        purpose: "test"
        requires_diagram: false
      - section_tag: not-doing
        title: "Not Doing"
        purpose: "test"
        requires_diagram: false
EOF
  (cd "$dir" && git init -q && git add . && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

# Sample proposal JSON
sample_proposal() {
  cat <<'EOF'
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing shape-confirm.sh",
    "acceptance_outcome": "Captain receives a working shape-confirm test suite that exercises every JSON proposal field including this acceptance_outcome itself.",
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\n  A --> B",
    "pm_skill_receipts": {
      "stage": "ship-shape",
      "mode": "mode-a",
      "appetite": "small-batch",
      "compose_guard": "passed",
      "receipts": [
        {"phase": "intake-problem", "delegate": "problem-framing-canvas", "required": true, "status": "invoked", "evidence": "Skill: problem-framing-canvas", "fallback": null, "rationale": "Feeds the Problem block."},
        {"phase": "scope-decompose", "delegate": "opportunity-solution-tree", "required": true, "status": "unavailable", "evidence": null, "fallback": "inline", "rationale": "Skill unavailable; inline fallback recorded before compose."},
        {"phase": "assumption-extract", "delegate": "pol-probe-advisor", "required": true, "status": "invoked", "evidence": "Skill: pol-probe-advisor", "fallback": null, "rationale": "Filters critical assumptions."},
        {"phase": "acceptance-outcome", "delegate": "press-release", "required": true, "status": "skipped", "evidence": null, "fallback": null, "rationale": "Small-scope skip rule matched before compose."}
      ]
    }
  },
  "children": [
    {"id": "090.1", "slug": "child-a", "title": "Child A", "depends_on": []},
    {"id": "090.2", "slug": "child-b", "title": "Child B", "depends_on": ["090.1"]}
  ],
  "rabbit_holes": [
    {"slug": "rh-test", "claim": "Test rabbit hole"}
  ],
  "deleted_from_shape": [
    {"claim": "Do not build X", "reason": "Out of appetite"}
  ]
}
EOF
}

proposal_without_pm_skill_receipts() {
  cat <<'EOF'
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing shape-confirm.sh",
    "acceptance_outcome": "Captain receives a working shape-confirm test suite that exercises the missing PM-skill receipt guard before mutation.",
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\n  A --> B"
  },
  "children": [],
  "rabbit_holes": [],
  "deleted_from_shape": []
}
EOF
}

proposal_without_mode_a_receipts() {
  local shape_mode="$1"
  cat <<EOF
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing shape-confirm.sh mode-aware receipt handling",
    "acceptance_outcome": "Captain receives a truthful folder-layout shape artifact whose receipt block matches the selected ship-shape mode.",
    "shape_mode": "${shape_mode}",
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\\n  A --> B"
  },
  "children": [],
  "rabbit_holes": [],
  "deleted_from_shape": []
}
EOF
}

proposal_with_raw_shape_mode() {
  local raw_shape_mode="$1"
  cat <<EOF
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing shape-confirm.sh shape_mode type validation",
    "acceptance_outcome": "Captain receives a fail-closed shape proposal contract that rejects non-string mode values before any write occurs.",
    "shape_mode": ${raw_shape_mode},
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\\n  A --> B"
  },
  "children": [],
  "rabbit_holes": [],
  "deleted_from_shape": []
}
EOF
}

proposal_with_top_level_pm_skill_receipts() {
  cat <<'EOF'
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing shape-confirm.sh",
    "acceptance_outcome": "Captain receives a working shape-confirm test suite that accepts the legacy top-level PM-skill receipt location.",
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\n  A --> B"
  },
  "pm_skill_receipts": {
    "stage": "ship-shape",
    "mode": "mode-a",
    "appetite": "small-batch",
    "compose_guard": "passed",
    "receipts": [
      {"phase": "intake-problem", "delegate": "problem-framing-canvas", "required": true, "status": "invoked", "evidence": "Skill: problem-framing-canvas", "fallback": null, "rationale": "Feeds the Problem block."},
      {"phase": "scope-decompose", "delegate": "opportunity-solution-tree", "required": true, "status": "unavailable", "evidence": null, "fallback": "inline", "rationale": "Skill unavailable; inline fallback recorded before compose."},
      {"phase": "assumption-extract", "delegate": "pol-probe-advisor", "required": true, "status": "invoked", "evidence": "Skill: pol-probe-advisor", "fallback": null, "rationale": "Filters critical assumptions."},
      {"phase": "acceptance-outcome", "delegate": "press-release", "required": true, "status": "skipped", "evidence": null, "fallback": null, "rationale": "Small-scope skip rule matched before compose."}
    ]
  },
  "children": [],
  "rabbit_holes": [],
  "deleted_from_shape": []
}
EOF
}

proposal_without_acceptance_outcome() {
  cat <<'EOF'
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing shape-confirm.sh",
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\n  A --> B"
  },
  "children": [
    {"id": "090.1", "slug": "child-a", "title": "Child A", "depends_on": []},
    {"id": "090.2", "slug": "child-b", "title": "Child B", "depends_on": ["090.1"]}
  ],
  "rabbit_holes": [
    {"slug": "rh-test", "claim": "Test rabbit hole"}
  ],
  "deleted_from_shape": [
    {"claim": "Do not build X", "reason": "Out of appetite"}
  ]
}
EOF
}

proposal_with_short_acceptance_outcome() {
  cat <<'EOF'
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing shape-confirm.sh",
    "acceptance_outcome": "too short",
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\n  A --> B"
  },
  "children": [
    {"id": "090.1", "slug": "child-a", "title": "Child A", "depends_on": []},
    {"id": "090.2", "slug": "child-b", "title": "Child B", "depends_on": ["090.1"]}
  ],
  "rabbit_holes": [
    {"slug": "rh-test", "claim": "Test rabbit hole"}
  ],
  "deleted_from_shape": [
    {"claim": "Do not build X", "reason": "Out of appetite"}
  ]
}
EOF
}

cd "$REPO_ROOT" || exit 1

echo "--- DC-27: shape-confirm happy path — all artifacts written, single commit ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal.json"
sample_proposal > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 0 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP'" \
  "DC-27a shape-confirm exit 0"

# Verify pitch entity file
if [ -f "docs/ship-flow/090-test-pitch.md" ]; then echo "OK DC-27b pitch entity written"
else echo "FAIL DC-27b pitch entity missing"; FAIL=1; fi

# Verify children
if [ -f "docs/ship-flow/090.1-child-a.md" ] && [ -f "docs/ship-flow/090.2-child-b.md" ]; then
  echo "OK DC-27c children written"
else echo "FAIL DC-27c children missing"; FAIL=1; fi

# Verify rabbit hole todo
if [ -f "docs/ship-flow/todos/rh-test.md" ]; then echo "OK DC-27d rabbit hole todo written"
else echo "FAIL DC-27d rabbit hole todo missing"; FAIL=1; fi

# Verify ROADMAP has pitch in next, rabbit hole in later, delete in not-doing
if grep -q 'test-pitch' ROADMAP.md && grep -q 'rh-test' ROADMAP.md && grep -q 'Do not build X' ROADMAP.md; then
  echo "OK DC-27e ROADMAP updated with next/later/not-doing rows"
else echo "FAIL DC-27e ROADMAP incomplete"; FAIL=1; fi

# Verify single commit landed
COMMITS=$({ git log --oneline || true; } | wc -l | tr -d ' ')
if [ "$COMMITS" = "2" ]; then echo "OK DC-27f single commit (init + shape-confirm)"
else echo "FAIL DC-27f expected 2 commits, got $COMMITS"; FAIL=1; fi
if grep -q '^status: sharp$' docs/ship-flow/090-test-pitch.md && \
   ! grep -q '^stage_outputs:' docs/ship-flow/090-test-pitch.md; then
  echo "OK DC-27g legacy flat layout keeps sharp status without folder stage registry"
else
  echo "FAIL DC-27g flat-layout compatibility changed"; FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-28: shape-confirm --dry-run writes nothing ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal.json"
sample_proposal > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 0 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --dry-run" \
  "DC-28a dry-run exit 0"
if [ ! -f "docs/ship-flow/090-test-pitch.md" ]; then echo "OK DC-28b no files written on dry-run"
else echo "FAIL DC-28b files written on dry-run"; FAIL=1; fi
# Commit count unchanged
COMMITS=$({ git log --oneline || true; } | wc -l | tr -d ' ')
if [ "$COMMITS" = "1" ]; then echo "OK DC-28c no commit on dry-run"
else echo "FAIL DC-28c dry-run created commit"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-29: missing input file → exit 3 ---"
assert_exit 3 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal=/nonexistent/path.json" \
  "DC-29a missing input"

echo
echo "--- DC-30: malformed JSON → exit 1 ---"
TMP="$(setup_fixture)"
BAD_PROP="$TMP/bad.json"
echo "{ this is not valid json" > "$BAD_PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 1 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$BAD_PROP'" \
  "DC-30a malformed JSON"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-31: missing acceptance_outcome → exit 10 ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal.json"
proposal_without_acceptance_outcome > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 10 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP'" \
  "DC-31a acceptance_outcome empty rejected"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-32: short acceptance_outcome → exit 10 ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal.json"
proposal_with_short_acceptance_outcome > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 10 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP'" \
  "DC-32a acceptance_outcome short rejected"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-33: acceptance_outcome rendered into shape.md (folder layout) ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal.json"
sample_proposal > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 0 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder" \
  "DC-33a happy path folder layout"
if grep -q "Captain receives a working shape-confirm" docs/ship-flow/090-test-pitch/shape.md 2>/dev/null; then
  echo "OK DC-33b acceptance_outcome rendered into shape.md"
else
  echo "FAIL DC-33b acceptance_outcome missing from shape.md"
  FAIL=1
fi
if grep -q "## Acceptance Outcome" docs/ship-flow/090-test-pitch/shape.md 2>/dev/null; then
  echo "OK DC-33c shape.md has Acceptance Outcome section heading"
else
  echo "FAIL DC-33c shape.md missing Acceptance Outcome heading"
  FAIL=1
fi
PM_RECEIPT_COUNT=$(grep -c '^<!-- section:pm-skill-receipts -->$' docs/ship-flow/090-test-pitch/shape.md 2>/dev/null || true)
if [ "$PM_RECEIPT_COUNT" = "1" ]; then
  echo "OK DC-33e shape.md has exactly one PM-skill receipt section"
else
  echo "FAIL DC-33e shape.md expected one PM-skill receipt section, got $PM_RECEIPT_COUNT"
  FAIL=1
fi
if bash "${LIB_DIR}/validate-pm-skill-receipts.sh" docs/ship-flow/090-test-pitch/shape.md >/dev/null 2>&1; then
  echo "OK DC-33f rendered PM-skill receipt validates"
else
  echo "FAIL DC-33f rendered PM-skill receipt did not validate"
  FAIL=1
fi
FOLDER_INDEX="docs/ship-flow/090-test-pitch/index.md"
if grep -q '^status: shape$' "$FOLDER_INDEX"; then
  echo "OK DC-33g folder pitch starts at canonical shape status"
else
  echo "FAIL DC-33g folder pitch must start at canonical shape status"
  FAIL=1
fi
if awk '
  BEGIN { frontmatter=0; in_outputs=0 }
  /^---[[:space:]]*$/ { frontmatter++; if (frontmatter >= 2) exit; next }
  frontmatter != 1 { next }
  /^stage_outputs:[[:space:]]*$/ { in_outputs=1; next }
  in_outputs && /^[^[:space:]]/ { in_outputs=0 }
  in_outputs && /^[[:space:]]+shape:[[:space:]]*shape\.md[[:space:]]*$/ { found=1 }
  END { exit(found ? 0 : 1) }
' "$FOLDER_INDEX"; then
  echo "OK DC-33h folder pitch declares stage_outputs.shape"
else
  echo "FAIL DC-33h folder pitch must declare stage_outputs.shape: shape.md"
  FAIL=1
fi
legacy_spec_output="docs/ship-flow/090-test-pitch/spec.md"
if [ ! -f "$legacy_spec_output" ]; then
  echo "OK DC-33d canonical writer does not create legacy spec.md"
else
  echo "FAIL DC-33d canonical writer still created legacy spec.md"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-34: folder layout cascades to children as index.md ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal.json"
sample_proposal > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 0 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder" \
  "DC-34a folder layout happy path"
if [ -f "docs/ship-flow/090.1-child-a/index.md" ] && [ -f "docs/ship-flow/090.2-child-b/index.md" ]; then
  echo "OK DC-34b children written as folder index.md"
else
  echo "FAIL DC-34b children missing folder index.md"
  FAIL=1
fi
if [ ! -f "docs/ship-flow/090.1-child-a.md" ] && [ ! -f "docs/ship-flow/090.2-child-b.md" ]; then
  echo "OK DC-34c no flat child files in folder layout"
else
  echo "FAIL DC-34c folder layout still wrote flat child files"
  FAIL=1
fi
if awk '
  /^status: shape$/ { getline a; getline b; getline c; exit !(a=="stage_outputs:" && b=="  shape: shape.md" && c=="---") }
  END { if (!a) exit 1 }
' docs/ship-flow/090-test-pitch/index.md && \
   ! grep -q '^<!-- section:stage-artifact-links -->$' docs/ship-flow/090-test-pitch/index.md; then
  echo "OK DC-34d pitch has exact terminal shape authority tail and no body table"
else
  echo "FAIL DC-34d pitch authority tail/body-table disposition"; FAIL=1
fi
for child in docs/ship-flow/090.1-child-a/index.md docs/ship-flow/090.2-child-b/index.md; do
  if awk '
    /^status: sharp$/ { getline a; getline b; exit !(a=="stage_outputs: {}" && b=="---") }
    END { if (!a) exit 1 }
  ' "$child" && ! grep -q '^<!-- section:stage-artifact-links -->$' "$child"; then
    echo "OK DC-34e $(basename "$(dirname "$child")") has empty terminal authority tail"
  else
    echo "FAIL DC-34e $(basename "$(dirname "$child")") authority tail/body-table disposition"; FAIL=1
  fi
done
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-35: existing rabbit-hole todo is never silently overwritten ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal.json"
sample_proposal > "$PROP"
pushd "$TMP" >/dev/null || exit 1
cat > docs/ship-flow/todos/rh-test.md <<'EOF'
---
tid: rh-test
captured_at: 2026-01-01T00:00:00Z
status: pending
source_pitch: "088"
---

Original rabbit hole body that must survive.
EOF
BEFORE_HASH="$(git hash-object docs/ship-flow/todos/rh-test.md)"
assert_exit 10 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP'" \
  "DC-35a existing rabbit-hole todo rejects write"
AFTER_HASH="$(git hash-object docs/ship-flow/todos/rh-test.md)"
if [ "$BEFORE_HASH" = "$AFTER_HASH" ]; then
  echo "OK DC-35b existing rabbit-hole todo content preserved"
else
  echo "FAIL DC-35b existing rabbit-hole todo content changed"
  FAIL=1
fi
if [ ! -e "docs/ship-flow/090-test-pitch.md" ] && \
   [ ! -e "docs/ship-flow/090-test-pitch" ] && \
   [ ! -e "docs/ship-flow/090.1-child-a.md" ] && \
   [ ! -e "docs/ship-flow/090.1-child-a" ]; then
  echo "OK DC-35c duplicate todo refusal creates no pitch or child artifacts"
else
  echo "FAIL DC-35c duplicate todo refusal created pitch or child artifacts"
  FAIL=1
fi
COMMITS=$({ git log --oneline || true; } | wc -l | tr -d ' ')
if [ "$COMMITS" = "1" ]; then echo "OK DC-35d duplicate todo refusal creates no commit"
else echo "FAIL DC-35d duplicate todo refusal created commit(s), got $COMMITS"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-36: duplicate rabbit-hole todo preflight runs before write-phase mkdir ---"
mkdir_line="$(grep -n 'mkdir -p "$ENTITY_DIR" "$TODO_DIR"' "${LIB_DIR}/shape-confirm.sh" | head -n 1 | cut -d: -f1)"
duplicate_line="$(grep -n 'rabbit-hole todo already exists' "${LIB_DIR}/shape-confirm.sh" | head -n 1 | cut -d: -f1)"
if [ -n "$mkdir_line" ] && [ -n "$duplicate_line" ] && [ "$duplicate_line" -lt "$mkdir_line" ]; then
  echo "OK DC-36 duplicate todo preflight precedes write-phase mkdir"
else
  echo "FAIL DC-36 duplicate todo preflight must precede write-phase mkdir"
  FAIL=1
fi

echo
echo "--- DC-37: missing PM-skill receipts reject before mutation ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-no-receipts.json"
proposal_without_pm_skill_receipts > "$PROP"
EXPLICIT_MODE_A_PROP="$TMP/proposal-mode-a-no-receipts.json"
proposal_without_mode_a_receipts "mode-a" > "$EXPLICIT_MODE_A_PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 10 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder" \
  "DC-37a missing PM-skill receipts exit 10"
assert_stderr_contains "Error: pitch.pm_skill_receipts or top-level pm_skill_receipts is required for folder-layout Mode A shape proposals" \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder" \
  "DC-37a2 missing PM-skill receipts diagnostic names both accepted JSON locations"
assert_exit 10 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$EXPLICIT_MODE_A_PROP' --layout=folder" \
  "DC-37a3 explicit Mode A also rejects missing PM-skill receipts"
if [ ! -e "docs/ship-flow/090-test-pitch" ] && [ ! -e "docs/ship-flow/090-test-pitch.md" ]; then
  echo "OK DC-37b missing receipt refusal creates no pitch artifacts"
else
  echo "FAIL DC-37b missing receipt refusal created pitch artifacts"
  FAIL=1
fi
COMMITS=$({ git log --oneline || true; } | wc -l | tr -d ' ')
if [ "$COMMITS" = "1" ]; then echo "OK DC-37c missing receipt refusal creates no commit"
else echo "FAIL DC-37c missing receipt refusal created commit(s), got $COMMITS"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-38: top-level PM-skill receipts remain accepted ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-top-level-receipts.json"
proposal_with_top_level_pm_skill_receipts > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 0 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder" \
  "DC-38a top-level pm_skill_receipts accepted"
if bash "${LIB_DIR}/validate-pm-skill-receipts.sh" docs/ship-flow/090-test-pitch/shape.md >/dev/null 2>&1; then
  echo "OK DC-38b rendered top-level PM-skill receipt validates"
else
  echo "FAIL DC-38b rendered top-level PM-skill receipt did not validate"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-39: truthful non-Mode-A proposals do not fabricate Mode A receipts ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-mode-b.json"
proposal_without_mode_a_receipts "mode-b" > "$PROP"
pushd "$TMP" >/dev/null || exit 1
DRY_RUN_OUTPUT="$(bash "${LIB_DIR}/shape-confirm.sh" --proposal="$PROP" --layout=folder --dry-run 2>&1)"
DRY_RUN_EXIT=$?
if [ "$DRY_RUN_EXIT" = "0" ]; then
  echo "OK DC-39a Mode B folder dry-run succeeds without Mode A receipts"
else
  echo "FAIL DC-39a Mode B folder dry-run failed with exit $DRY_RUN_EXIT: $DRY_RUN_OUTPUT"
  FAIL=1
fi
if ! printf '%s\n' "$DRY_RUN_OUTPUT" | grep -Eq 'child: .*null|rabbit: .*null|seq:'; then
  echo "OK DC-39b zero arrays emit no phantom dry-run paths or seq boundary errors"
else
  echo "FAIL DC-39b zero arrays emitted a phantom dry-run path or seq boundary error"
  FAIL=1
fi
assert_exit 0 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder" \
  "DC-39c Mode B folder real write succeeds without Mode A receipts"
MODE_B_SHAPE="docs/ship-flow/090-test-pitch/shape.md"
if [ -f "$MODE_B_SHAPE" ] && ! grep -q 'section:pm-skill-receipts' "$MODE_B_SHAPE"; then
  echo "OK DC-39d Mode B shape.md omits the Mode A receipt block"
else
  echo "FAIL DC-39d Mode B shape.md missing or contains a fabricated Mode A receipt block"
  FAIL=1
fi
if [ "$(find docs/ship-flow -mindepth 1 -maxdepth 1 -type d ! -name todos | wc -l | tr -d ' ')" = "1" ] && \
   [ "$(find docs/ship-flow/todos -mindepth 1 -type f | wc -l | tr -d ' ')" = "0" ] && \
   ! grep -qF '| null |' ROADMAP.md; then
  echo "OK DC-39e zero arrays create no phantom child, todo, or ROADMAP rows"
else
  echo "FAIL DC-39e zero arrays created a phantom child, todo, or ROADMAP row"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-40: ship-shape mode contract rejects unknown values fail-closed ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-unknown-mode.json"
proposal_without_mode_a_receipts "mode-z" > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 10 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder --dry-run" \
  "DC-40a unknown shape mode exits 10"
assert_stderr_contains "Error: pitch.shape_mode must be one of: mode-a, mode-b, mode-c" \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder --dry-run" \
  "DC-40b unknown shape mode diagnostic names supported values"
if [ ! -e "docs/ship-flow/090-test-pitch" ]; then
  echo "OK DC-40c unknown shape mode rejects before mutation"
else
  echo "FAIL DC-40c unknown shape mode created pitch artifacts"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-40.1: non-string and null shape modes reject as invalid modes ---"
for case_name in false null number; do
  case "$case_name" in
    false) raw_shape_mode=false ;;
    null) raw_shape_mode=null ;;
    number) raw_shape_mode=7 ;;
  esac
  TMP="$(setup_fixture)"
  PROP="$TMP/proposal-${case_name}-mode.json"
  proposal_with_raw_shape_mode "$raw_shape_mode" > "$PROP"
  pushd "$TMP" >/dev/null || exit 1
  assert_exit 10 \
    "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder --dry-run" \
    "DC-40.1-${case_name} non-string/null shape mode exits 10"
  assert_stderr_contains "Error: pitch.shape_mode must be one of: mode-a, mode-b, mode-c" \
    "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder --dry-run" \
    "DC-40.1-${case_name}-diagnostic rejects before Mode A receipt handling"
  if [ ! -e "docs/ship-flow/090-test-pitch" ]; then
    echo "OK DC-40.1-${case_name}-mutation invalid shape mode creates no artifacts"
  else
    echo "FAIL DC-40.1-${case_name}-mutation invalid shape mode created artifacts"
    FAIL=1
  fi
  popd >/dev/null || exit 1
  rm -rf "$TMP"
done

echo
echo "--- DC-41: Mode C is an explicit non-A ship-shape mode ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-mode-c.json"
proposal_without_mode_a_receipts "mode-c" > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 0 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder --dry-run" \
  "DC-41 Mode C folder dry-run succeeds without Mode A receipts"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-42: visible ship-shape docs expose the proposal mode contract ---"
SHIP_SHAPE_SKILL="${LIB_DIR}/../skills/ship-shape/SKILL.md"
PLUGIN_README="${LIB_DIR}/../README.md"
if grep -qF '`pitch.shape_mode`' "$SHIP_SHAPE_SKILL" && \
   grep -qF '`mode-a | mode-b | mode-c`' "$SHIP_SHAPE_SKILL" && \
   grep -qF 'Absent defaults to `mode-a`' "$SHIP_SHAPE_SKILL"; then
  echo "OK DC-42a ship-shape proposal schema documents values and backward-compatible default"
else
  echo "FAIL DC-42a ship-shape proposal schema is missing shape_mode values/default"
  FAIL=1
fi
if grep -qF '`pitch.shape_mode`' "$PLUGIN_README" && \
   grep -qF 'Mode B/C' "$PLUGIN_README" && \
   grep -qF 'do not render' "$PLUGIN_README"; then
  echo "OK DC-42b plugin README documents mode-aware receipt behavior"
else
  echo "FAIL DC-42b plugin README is missing mode-aware receipt behavior"
  FAIL=1
fi

# ── DC-101.1-6: answers_density emitted in folder layout (pitch-101 Task 2) ──
echo
echo "--- DC-101.1-6: answers_density in folder layout ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-density.json"
cat > "$PROP" <<'ENDJSON'
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing answers_density emission",
    "acceptance_outcome": "shape-confirm.sh emits answers_density field when present in proposal JSON pitch object for both folder and flat layouts.",
    "answers_density": "medium",
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\n  A --> B",
    "pm_skill_receipts": {
      "stage": "ship-shape",
      "mode": "mode-a",
      "appetite": "small-batch",
      "compose_guard": "passed",
      "receipts": [
        {"phase": "intake-problem", "delegate": "problem-framing-canvas", "required": true, "status": "invoked", "evidence": "Skill: problem-framing-canvas", "fallback": null, "rationale": "Feeds the Problem block."},
        {"phase": "scope-decompose", "delegate": "opportunity-solution-tree", "required": true, "status": "unavailable", "evidence": null, "fallback": "inline", "rationale": "Skill unavailable; inline fallback recorded before compose."},
        {"phase": "assumption-extract", "delegate": "pol-probe-advisor", "required": true, "status": "invoked", "evidence": "Skill: pol-probe-advisor", "fallback": null, "rationale": "Filters critical assumptions."},
        {"phase": "acceptance-outcome", "delegate": "press-release", "required": true, "status": "skipped", "evidence": null, "fallback": null, "rationale": "Small-scope skip rule matched before compose."}
      ]
    }
  },
  "children": [],
  "rabbit_holes": [],
  "deleted_from_shape": []
}
ENDJSON
pushd "$TMP" >/dev/null || exit 1
bash "${LIB_DIR}/shape-confirm.sh" --proposal="$PROP" --layout=folder >/dev/null 2>&1
if grep -qE '^answers_density:[[:space:]]*"medium"' docs/ship-flow/090-test-pitch/index.md 2>/dev/null; then
  echo "OK DC-101.1-6: folder layout index.md contains answers_density: \"medium\""
else
  echo "FAIL DC-101.1-6: folder layout index.md missing answers_density line (expected red before Task 6)"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

# ── DC-101.1-7: answers_density emitted in flat layout (pitch-101 Task 2) ──
echo
echo "--- DC-101.1-7: answers_density in flat layout ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-density-flat.json"
cat > "$PROP" <<'ENDJSON'
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing answers_density emission flat layout",
    "acceptance_outcome": "shape-confirm.sh emits answers_density field when present in proposal JSON pitch object for both folder and flat layouts.",
    "answers_density": "medium",
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\n  A --> B"
  },
  "children": [],
  "rabbit_holes": [],
  "deleted_from_shape": []
}
ENDJSON
pushd "$TMP" >/dev/null || exit 1
bash "${LIB_DIR}/shape-confirm.sh" --proposal="$PROP" --layout=flat >/dev/null 2>&1
if grep -qE '^answers_density:[[:space:]]*"medium"' docs/ship-flow/090-test-pitch.md 2>/dev/null; then
  echo "OK DC-101.1-7: flat layout .md contains answers_density: \"medium\""
else
  echo "FAIL DC-101.1-7: flat layout .md missing answers_density line (expected red before Task 6)"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

# ── DC-129.4: pitch.pre_mortem emitted into pitch frontmatter (entity 129.4) ──
# Stop the recurring C1 (pre-mortem-emitted) fail: shape-confirm.sh must render
# proposal.pitch.pre_mortem into the pitch index.md/.md frontmatter so a freshly
# shaped non-trivial pitch passes check-invariants.sh C1 with zero manual lift.
proposal_with_pre_mortem() {
  cat <<'EOF'
{
  "pitch": {
    "id": "090",
    "slug": "test-pitch",
    "title": "Test pitch",
    "appetite": "2 days",
    "problem": "Testing pre_mortem emission into pitch frontmatter",
    "acceptance_outcome": "shape-confirm.sh emits pitch.pre_mortem into the pitch frontmatter so a freshly shaped non-trivial pitch passes C1.",
    "pre_mortem": {
      "category": "wrong-dcs",
      "one_liner": "We render pre_mortem with wrong indentation so C1 grep still fails on the freshly shaped pitch."
    },
    "stated_assumptions": [],
    "dag_mermaid": "graph LR\n  A --> B",
    "pm_skill_receipts": {
      "stage": "ship-shape",
      "mode": "mode-a",
      "appetite": "small-batch",
      "compose_guard": "passed",
      "receipts": [
        {"phase": "intake-problem", "delegate": "problem-framing-canvas", "required": true, "status": "invoked", "evidence": "Skill: problem-framing-canvas", "fallback": null, "rationale": "Feeds the Problem block."},
        {"phase": "scope-decompose", "delegate": "opportunity-solution-tree", "required": true, "status": "unavailable", "evidence": null, "fallback": "inline", "rationale": "Skill unavailable; inline fallback recorded before compose."},
        {"phase": "assumption-extract", "delegate": "pol-probe-advisor", "required": true, "status": "invoked", "evidence": "Skill: pol-probe-advisor", "fallback": null, "rationale": "Filters critical assumptions."},
        {"phase": "acceptance-outcome", "delegate": "press-release", "required": true, "status": "skipped", "evidence": null, "fallback": null, "rationale": "Small-scope skip rule matched before compose."}
      ]
    }
  },
  "children": [
    {"id": "090.1", "slug": "child-a", "title": "Child A", "depends_on": []}
  ],
  "rabbit_holes": [],
  "deleted_from_shape": []
}
EOF
}

echo
echo "--- DC-129.4-1: pitch.pre_mortem emitted into folder-layout index.md ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-pre-mortem.json"
proposal_with_pre_mortem > "$PROP"
pushd "$TMP" >/dev/null || exit 1
bash "${LIB_DIR}/shape-confirm.sh" --proposal="$PROP" --layout=folder >/dev/null 2>&1
PITCH_INDEX="docs/ship-flow/090-test-pitch/index.md"
if grep -qE '^pre_mortem:' "$PITCH_INDEX" 2>/dev/null; then
  echo "OK DC-129.4-1a folder index.md has pre_mortem: at column 0 (C1 grep target)"
else
  echo "FAIL DC-129.4-1a folder index.md missing ^pre_mortem: block"
  FAIL=1
fi
if grep -qE '^[[:space:]]+category:[[:space:]]*wrong-dcs' "$PITCH_INDEX" 2>/dev/null; then
  echo "OK DC-129.4-1b folder index.md pre_mortem.category rendered"
else
  echo "FAIL DC-129.4-1b folder index.md missing pre_mortem.category"
  FAIL=1
fi
if grep -qF 'We render pre_mortem with wrong indentation' "$PITCH_INDEX" 2>/dev/null; then
  echo "OK DC-129.4-1c folder index.md pre_mortem.one_liner rendered"
else
  echo "FAIL DC-129.4-1c folder index.md missing pre_mortem.one_liner"
  FAIL=1
fi
# DC2: check-invariants C1 passes on the freshly shaped pitch with zero manual edits
if bash "${LIB_DIR}/../bin/check-invariants.sh" --test-fixture "$(pwd)" --check pre-mortem-emitted >/dev/null 2>&1; then
  echo "OK DC-129.4-1d check-invariants C1 passes on freshly shaped pitch (no manual lift)"
else
  echo "FAIL DC-129.4-1d check-invariants C1 fails on freshly shaped pitch"
  FAIL=1
fi
# Child (shaped-child) must NOT carry pre_mortem — emission mirrors C1 pitch-only scope
if ! grep -qE '^pre_mortem:' docs/ship-flow/090.1-child-a/index.md 2>/dev/null; then
  echo "OK DC-129.4-1e shaped-child index.md does NOT carry pre_mortem (pitch-only scope)"
else
  echo "FAIL DC-129.4-1e shaped-child index.md wrongly stamped with pre_mortem"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-129.4-2: pitch.pre_mortem emitted into flat-layout .md ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-pre-mortem-flat.json"
proposal_with_pre_mortem > "$PROP"
pushd "$TMP" >/dev/null || exit 1
bash "${LIB_DIR}/shape-confirm.sh" --proposal="$PROP" --layout=flat >/dev/null 2>&1
PITCH_FLAT="docs/ship-flow/090-test-pitch.md"
if grep -qE '^pre_mortem:' "$PITCH_FLAT" 2>/dev/null; then
  echo "OK DC-129.4-2a flat .md has pre_mortem: at column 0"
else
  echo "FAIL DC-129.4-2a flat .md missing ^pre_mortem: block"
  FAIL=1
fi
if grep -qE '^[[:space:]]+category:[[:space:]]*wrong-dcs' "$PITCH_FLAT" 2>/dev/null && \
   grep -qF 'We render pre_mortem with wrong indentation' "$PITCH_FLAT" 2>/dev/null; then
  echo "OK DC-129.4-2b flat .md pre_mortem.category + one_liner rendered"
else
  echo "FAIL DC-129.4-2b flat .md missing pre_mortem.category or one_liner"
  FAIL=1
fi
if bash "${LIB_DIR}/../bin/check-invariants.sh" --test-fixture "$(pwd)" --check pre-mortem-emitted >/dev/null 2>&1; then
  echo "OK DC-129.4-2c check-invariants C1 passes on freshly shaped flat pitch"
else
  echo "FAIL DC-129.4-2c check-invariants C1 fails on freshly shaped flat pitch"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-129.4-3: trivial pitch (no pre_mortem in proposal) emits nothing ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal-no-pre-mortem.json"
sample_proposal > "$PROP"
pushd "$TMP" >/dev/null || exit 1
bash "${LIB_DIR}/shape-confirm.sh" --proposal="$PROP" --layout=folder >/dev/null 2>&1
if ! grep -qE '^pre_mortem:' docs/ship-flow/090-test-pitch/index.md 2>/dev/null; then
  echo "OK DC-129.4-3 proposal without pre_mortem emits no pre_mortem block"
else
  echo "FAIL DC-129.4-3 emitted pre_mortem block when proposal had none"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

exit "$FAIL"
