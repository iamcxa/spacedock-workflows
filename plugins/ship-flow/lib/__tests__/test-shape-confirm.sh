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
echo "--- DC-33: acceptance_outcome rendered into spec.md (folder layout) ---"
TMP="$(setup_fixture)"
PROP="$TMP/proposal.json"
sample_proposal > "$PROP"
pushd "$TMP" >/dev/null || exit 1
assert_exit 0 \
  "bash '${LIB_DIR}/shape-confirm.sh' --proposal='$PROP' --layout=folder" \
  "DC-33a happy path folder layout"
if grep -q "Captain receives a working shape-confirm" docs/ship-flow/090-test-pitch/spec.md 2>/dev/null; then
  echo "OK DC-33b acceptance_outcome rendered into spec.md"
else
  echo "FAIL DC-33b acceptance_outcome missing from spec.md"
  FAIL=1
fi
if grep -q "## Acceptance Outcome" docs/ship-flow/090-test-pitch/spec.md 2>/dev/null; then
  echo "OK DC-33c spec.md has Acceptance Outcome section heading"
else
  echo "FAIL DC-33c spec.md missing Acceptance Outcome heading"
  FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

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
    "dag_mermaid": "graph LR\n  A --> B"
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

exit "$FAIL"
