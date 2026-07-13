#!/usr/bin/env bash
# test-density-classify.sh — TDD scaffold for density-classify.sh (pitch-101 Task 1)
# All 5 cases should FAIL (red) before Task 4 lands density-classify.sh.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
CLASSIFIER="${LIB_DIR}/density-classify.sh"
FAIL=0

assert_eq() {
  local expected="$1" got="$2" name="$3"
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected='$expected', got='$got')"; FAIL=1; fi
}

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

assert_empty_file() {
  local file="$1" name="$2"
  if [ ! -s "$file" ]; then echo "OK $name"
  else echo "FAIL $name (expected empty file, got $(wc -c < "$file" | tr -d ' ') bytes)"; FAIL=1; fi
}

# ── fixture helpers ────────────────────────────────────────────────────────────

# high-density fixture: CLAUDE.md hits ≥1, skill match ≥1, precedent ≥2, canonical match
make_high_density_fixture() {
  local dir
  dir="$(mktemp -d)"
  # CLAUDE.md with ship-flow keyword (area pattern match)
  cat > "$dir/CLAUDE.md" <<'EOF'
# ship-flow
## Ship-Flow Pipeline
Workflow at docs/ship-flow/. Use ship-flow skills.
EOF
  # fake archived precedents (≥2)
  mkdir -p "$dir/docs/ship-flow/_archive"
  echo "slug: density-test-1" > "$dir/docs/ship-flow/_archive/001-density-test-1.md"
  echo "slug: density-test-2" > "$dir/docs/ship-flow/_archive/002-density-test-2.md"
  # canonical doc with matching section
  mkdir -p "$dir/plugins/ship-flow/references"
  cat > "$dir/ARCHITECTURE.md" <<'EOF'
<!-- section:constraints -->
## Constraints
ship-flow pipeline constraints apply.
<!-- /section:constraints -->
EOF
  # entity file pointing to fixture dir
  cat > "$dir/index.md" <<EOF
---
id: "101"
slug: density-test-high
workflow_dir: docs/ship-flow
---
EOF
  echo "$dir"
}

# low-density fixture: exactly 1 signal — S3 has ≥2 archived precedents, rest zero
make_low_density_fixture() {
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/CLAUDE.md" <<'EOF'
# Generic Project
No relevant workflow guidance here.
EOF
  # S3: 2 archive entries → exactly 1 signal fires
  mkdir -p "$dir/docs/ship-flow/_archive"
  echo "slug: past-1" > "$dir/docs/ship-flow/_archive/001-past-1.md"
  echo "slug: past-2" > "$dir/docs/ship-flow/_archive/002-past-2.md"
  cat > "$dir/ARCHITECTURE.md" <<'EOF'
# Architecture
No relevant sections.
EOF
  cat > "$dir/index.md" <<EOF
---
id: "999"
slug: density-test-low
workflow_dir: docs/ship-flow
---
EOF
  echo "$dir"
}

# vacuum fixture: no signals at all (empty dirs, minimal files)
make_vacuum_fixture() {
  local dir
  dir="$(mktemp -d)"
  touch "$dir/CLAUDE.md"
  mkdir -p "$dir/docs/ship-flow/_archive"
  touch "$dir/ARCHITECTURE.md"
  cat > "$dir/index.md" <<EOF
---
id: "998"
slug: density-test-vacuum
workflow_dir: docs/ship-flow
---
EOF
  echo "$dir"
}

# ── red checks (all should fail before Task 4 lands) ──────────────────────────

# Case (a): high-density fixture → stdout 'high'
HIGH_DIR="$(make_high_density_fixture)"
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL T1-a: density-classify.sh not found (expected red before Task 4)"; FAIL=1
else
  GOT="$(bash "$CLASSIFIER" --entity="$HIGH_DIR/index.md" 2>/dev/null)"
  assert_eq "high" "$GOT" "T1-a: high-density fixture → stdout 'high'"
fi

# Case (b): low-density fixture → stdout 'low'
LOW_DIR="$(make_low_density_fixture)"
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL T1-b: density-classify.sh not found (expected red before Task 4)"; FAIL=1
else
  GOT="$(bash "$CLASSIFIER" --entity="$LOW_DIR/index.md" 2>/dev/null)"
  assert_eq "low" "$GOT" "T1-b: low-density fixture → stdout 'low'"
fi

# Case (c): vacuum fixture → stdout 'vacuum'
VAC_DIR="$(make_vacuum_fixture)"
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL T1-c: density-classify.sh not found (expected red before Task 4)"; FAIL=1
else
  GOT="$(bash "$CLASSIFIER" --entity="$VAC_DIR/index.md" 2>/dev/null)"
  assert_eq "vacuum" "$GOT" "T1-c: vacuum fixture → stdout 'vacuum'"
fi

# Case (d): determinism — 3 sequential calls produce identical output
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL T1-d: density-classify.sh not found (expected red before Task 4)"; FAIL=1
else
  R1="$(bash "$CLASSIFIER" --entity="$HIGH_DIR/index.md" 2>/dev/null)"
  R2="$(bash "$CLASSIFIER" --entity="$HIGH_DIR/index.md" 2>/dev/null)"
  R3="$(bash "$CLASSIFIER" --entity="$HIGH_DIR/index.md" 2>/dev/null)"
  UNIQUE="$(printf '%s\n%s\n%s\n' "$R1" "$R2" "$R3" | sort -u | wc -l | tr -d ' ')"
  assert_eq "1" "$UNIQUE" "T1-d: determinism (3 runs same result)"
fi

# Case (e): --is-high exits 0 on high fixture, exits 1 on low fixture
if [ ! -f "$CLASSIFIER" ]; then
  echo "FAIL T1-e: density-classify.sh not found (expected red before Task 4)"; FAIL=1
else
  assert_exit 0 "bash '$CLASSIFIER' --is-high --entity='$HIGH_DIR/index.md'" "T1-e: --is-high exits 0 on high fixture"
  assert_exit 1 "bash '$CLASSIFIER' --is-high --entity='$LOW_DIR/index.md'" "T1-e: --is-high exits 1 on low fixture"
fi

# Case (f): nested fixture decoys across all four traversals do not add signals
CLEAN_TWIN_DIR="$(make_vacuum_fixture)"
DECOY_TWIN_DIR="$(make_vacuum_fixture)"
mkdir -p "$DECOY_TWIN_DIR/docs/ship-flow/__tests__/test-fixtures/nested"
cat > "$DECOY_TWIN_DIR/docs/ship-flow/__tests__/test-fixtures/nested/CLAUDE.md" <<'EOF'
## Ship-Flow Pipeline
EOF
mkdir -p "$DECOY_TWIN_DIR/plugins/test-fixtures/__tests__/nested"
cat > "$DECOY_TWIN_DIR/plugins/test-fixtures/__tests__/nested/SKILL.md" <<'EOF'
ship-flow
EOF
mkdir -p "$DECOY_TWIN_DIR/docs/ship-flow/_archive/__tests__/test-fixtures"
echo "slug: archive-decoy" > "$DECOY_TWIN_DIR/docs/ship-flow/_archive/__tests__/test-fixtures/001-decoy.md"
mkdir -p "$DECOY_TWIN_DIR/docs/ship-flow/done/test-fixtures/__tests__"
echo "slug: done-decoy" > "$DECOY_TWIN_DIR/docs/ship-flow/done/test-fixtures/__tests__/002-decoy.md"

CLEAN_STDERR="$(mktemp)"
CLEAN_GOT="$(bash "$CLASSIFIER" --entity="$CLEAN_TWIN_DIR/index.md" 2>"$CLEAN_STDERR")"
CLEAN_STATUS=$?
assert_eq "0" "$CLEAN_STATUS" "T1-f: clean twin exits 0"
assert_empty_file "$CLEAN_STDERR" "T1-f: clean twin stderr is empty"
assert_eq "vacuum" "$CLEAN_GOT" "T1-f: clean twin classifies as vacuum"

DECOY_STDERR="$(mktemp)"
DECOY_GOT="$(bash "$CLASSIFIER" --entity="$DECOY_TWIN_DIR/index.md" 2>"$DECOY_STDERR")"
DECOY_STATUS=$?
assert_eq "0" "$DECOY_STATUS" "T1-f: decoy twin exits 0"
assert_empty_file "$DECOY_STDERR" "T1-f: decoy twin stderr is empty"
assert_eq "vacuum" "$DECOY_GOT" "T1-f: decoy twin classifies as vacuum"
assert_eq "$CLEAN_GOT" "$DECOY_GOT" "T1-f: nested fixture decoys do not change classification"

# Case (g): a repo root beneath marker-named ancestors remains discoverable
MARKER_BASE="$(mktemp -d)"
MARKER_DIR="$MARKER_BASE/__tests__/test-fixtures/repo"
mkdir -p "$MARKER_DIR/docs/ship-flow/_archive" "$MARKER_DIR/plugins/ship-flow/skills/sample"
cat > "$MARKER_DIR/CLAUDE.md" <<'EOF'
## Ship-Flow Pipeline
EOF
cat > "$MARKER_DIR/plugins/ship-flow/skills/sample/SKILL.md" <<'EOF'
ship-flow
EOF
echo "slug: marker-positive-1" > "$MARKER_DIR/docs/ship-flow/_archive/001-marker-positive.md"
echo "slug: marker-positive-2" > "$MARKER_DIR/docs/ship-flow/_archive/002-marker-positive.md"
cat > "$MARKER_DIR/ARCHITECTURE.md" <<'EOF'
<!-- section:ship-flow -->
## ship-flow
<!-- /section:ship-flow -->
EOF
cat > "$MARKER_DIR/index.md" <<'EOF'
---
id: "997"
slug: density-test-marker-ancestor
workflow_dir: docs/ship-flow
---
EOF

MARKER_STDERR="$(mktemp)"
MARKER_GOT="$(bash "$CLASSIFIER" --entity="$MARKER_DIR/index.md" 2>"$MARKER_STDERR")"
MARKER_STATUS=$?
assert_eq "0" "$MARKER_STATUS" "T1-g: marker-ancestor fixture exits 0"
assert_empty_file "$MARKER_STDERR" "T1-g: marker-ancestor fixture stderr is empty"
assert_eq "high" "$MARKER_GOT" "T1-g: marker-ancestor fixture retains high classification"

# Cleanup
rm -rf "$HIGH_DIR" "$LOW_DIR" "$VAC_DIR" "$CLEAN_TWIN_DIR" "$DECOY_TWIN_DIR" "$MARKER_BASE" 2>/dev/null || true
rm -f "$CLEAN_STDERR" "$DECOY_STDERR" "$MARKER_STDERR" 2>/dev/null || true

exit "$FAIL"
