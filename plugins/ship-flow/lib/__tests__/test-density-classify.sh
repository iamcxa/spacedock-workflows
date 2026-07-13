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

assert_file_contains() {
  local file="$1" expected="$2" name="$3"
  if grep -Fq -- "$expected" "$file"; then echo "OK $name"
  else echo "FAIL $name (expected '$expected' in $file)"; FAIL=1; fi
}

assert_file_not_contains() {
  local file="$1" unexpected="$2" name="$3"
  if grep -Fq -- "$unexpected" "$file"; then
    echo "FAIL $name (unexpected '$unexpected' in $file)"; FAIL=1
  else echo "OK $name"; fi
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

TEST_TMP_ROOT="$(mktemp -d)"
REAL_FIND="$(command -v find)"
FAKE_FIND_BIN="$TEST_TMP_ROOT/fake-find-bin"
mkdir -p "$FAKE_FIND_BIN"
cat >"$FAKE_FIND_BIN/find" <<'EOF'
#!/usr/bin/env bash
set -u

{
  printf 'CALL'
  printf '\t%s' "$@"
  printf '\n'
} >>"${SHIP_FLOW_TEST_FIND_LOG:?}"

if [ "${1:-}" = "${SHIP_FLOW_TEST_FAIL_ROOT:-}" ]; then
  printf '%s\n' "${SHIP_FLOW_TEST_PARTIAL:-partial-find-result}"
  printf 'fake-find: injected %s traversal failure\n' "${SHIP_FLOW_TEST_CASE:-unknown}" >&2
  exit 23
fi

exec "${SHIP_FLOW_TEST_REAL_FIND:?}" "$@"
EOF
chmod +x "$FAKE_FIND_BIN/find"

run_density_with_find_failure() {
  local root="$1" family="$2" fail_root="$3" mode="$4"
  local stdout_file="$5" stderr_file="$6" log_file="$7"

  : >"$log_file"
  if [ "$mode" = "--is-high" ]; then
    PATH="$FAKE_FIND_BIN:$PATH" \
      SHIP_FLOW_TEST_REAL_FIND="$REAL_FIND" \
      SHIP_FLOW_TEST_FIND_LOG="$log_file" \
      SHIP_FLOW_TEST_FAIL_ROOT="$fail_root" \
      SHIP_FLOW_TEST_CASE="$family" \
      bash "$CLASSIFIER" --is-high --entity="$root/index.md" \
      >"$stdout_file" 2>"$stderr_file"
  else
    PATH="$FAKE_FIND_BIN:$PATH" \
      SHIP_FLOW_TEST_REAL_FIND="$REAL_FIND" \
      SHIP_FLOW_TEST_FIND_LOG="$log_file" \
      SHIP_FLOW_TEST_FAIL_ROOT="$fail_root" \
      SHIP_FLOW_TEST_CASE="$family" \
      bash "$CLASSIFIER" --entity="$root/index.md" \
      >"$stdout_file" 2>"$stderr_file"
  fi
  RUN_DENSITY_STATUS=$?
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

# Case (f): nested fixture decoys do not add signals
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

ARCHIVE_DECOY_DIR="$(make_vacuum_fixture)"
mkdir -p "$ARCHIVE_DECOY_DIR/docs/ship-flow/_archive/__tests__/test-fixtures"
echo "slug: archive-decoy-1" > "$ARCHIVE_DECOY_DIR/docs/ship-flow/_archive/__tests__/test-fixtures/001-decoy.md"
echo "slug: archive-decoy-2" > "$ARCHIVE_DECOY_DIR/docs/ship-flow/_archive/__tests__/test-fixtures/002-decoy.md"
ARCHIVE_DECOY_STDOUT="$(mktemp)"
ARCHIVE_DECOY_STDERR="$(mktemp)"
bash "$CLASSIFIER" --entity="$ARCHIVE_DECOY_DIR/index.md" \
  >"$ARCHIVE_DECOY_STDOUT" 2>"$ARCHIVE_DECOY_STDERR"
ARCHIVE_DECOY_STATUS=$?
assert_eq "0" "$ARCHIVE_DECOY_STATUS" "T1-f: archive-only decoys exit 0"
assert_empty_file "$ARCHIVE_DECOY_STDERR" "T1-f: archive-only decoys emit empty stderr"
assert_eq "vacuum" "$(<"$ARCHIVE_DECOY_STDOUT")" "T1-f: two archive-only decoys remain vacuum"

DONE_DECOY_DIR="$(make_vacuum_fixture)"
mkdir -p "$DONE_DECOY_DIR/docs/ship-flow/done/test-fixtures/__tests__"
echo "slug: done-decoy-1" > "$DONE_DECOY_DIR/docs/ship-flow/done/test-fixtures/__tests__/001-decoy.md"
echo "slug: done-decoy-2" > "$DONE_DECOY_DIR/docs/ship-flow/done/test-fixtures/__tests__/002-decoy.md"
DONE_DECOY_STDOUT="$(mktemp)"
DONE_DECOY_STDERR="$(mktemp)"
bash "$CLASSIFIER" --entity="$DONE_DECOY_DIR/index.md" \
  >"$DONE_DECOY_STDOUT" 2>"$DONE_DECOY_STDERR"
DONE_DECOY_STATUS=$?
assert_eq "0" "$DONE_DECOY_STATUS" "T1-f: done-only decoys exit 0"
assert_empty_file "$DONE_DECOY_STDERR" "T1-f: done-only decoys emit empty stderr"
assert_eq "vacuum" "$(<"$DONE_DECOY_STDOUT")" "T1-f: two done-only decoys remain vacuum"

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

# Case (h): every traversal failure is visible and rejects partial data
ERROR_DIR="$(make_vacuum_fixture)"
mkdir -p "$ERROR_DIR/plugins" "$ERROR_DIR/docs/ship-flow/done"

S1_STDOUT="$TEST_TMP_ROOT/s1.stdout"
S1_STDERR="$TEST_TMP_ROOT/s1.stderr"
S1_LOG="$TEST_TMP_ROOT/s1.log"
run_density_with_find_failure \
  "$ERROR_DIR" "S1" "$ERROR_DIR/docs/ship-flow" "primary" \
  "$S1_STDOUT" "$S1_STDERR" "$S1_LOG"
assert_eq "2" "$RUN_DENSITY_STATUS" "T1-h: S1 traversal failure exits 2"
assert_empty_file "$S1_STDOUT" "T1-h: S1 traversal failure rejects partial classification"
assert_file_contains "$S1_STDERR" "fake-find: injected S1 traversal failure" "T1-h: S1 preserves raw stderr"
assert_file_contains "$S1_STDERR" "ERROR: density traversal S1 workflow CLAUDE.md failed (rc 23)" "T1-h: S1 emits traversal context"
assert_file_not_contains "$S1_LOG" "$ERROR_DIR/plugins" "T1-h: S1 failure stops later traversals"

S2_STDOUT="$TEST_TMP_ROOT/s2.stdout"
S2_STDERR="$TEST_TMP_ROOT/s2.stderr"
S2_LOG="$TEST_TMP_ROOT/s2.log"
run_density_with_find_failure \
  "$ERROR_DIR" "S2" "$ERROR_DIR/plugins" "--is-high" \
  "$S2_STDOUT" "$S2_STDERR" "$S2_LOG"
assert_eq "2" "$RUN_DENSITY_STATUS" "T1-h: S2 --is-high traversal failure exits 2, not 1"
assert_empty_file "$S2_STDOUT" "T1-h: S2 traversal failure rejects partial classification"
assert_file_contains "$S2_STDERR" "fake-find: injected S2 traversal failure" "T1-h: S2 preserves raw stderr"
assert_file_contains "$S2_STDERR" "ERROR: density traversal S2 plugin skills failed (rc 23)" "T1-h: S2 emits traversal context"
assert_file_not_contains "$S2_LOG" "$ERROR_DIR/docs/ship-flow/_archive" "T1-h: S2 failure stops later traversals"

ARCHIVE_STDOUT="$TEST_TMP_ROOT/archive.stdout"
ARCHIVE_STDERR="$TEST_TMP_ROOT/archive.stderr"
ARCHIVE_LOG="$TEST_TMP_ROOT/archive.log"
run_density_with_find_failure \
  "$ERROR_DIR" "archive" "$ERROR_DIR/docs/ship-flow/_archive" "primary" \
  "$ARCHIVE_STDOUT" "$ARCHIVE_STDERR" "$ARCHIVE_LOG"
assert_eq "2" "$RUN_DENSITY_STATUS" "T1-h: archive traversal failure exits 2"
assert_empty_file "$ARCHIVE_STDOUT" "T1-h: archive traversal failure rejects partial classification"
assert_file_contains "$ARCHIVE_STDERR" "fake-find: injected archive traversal failure" "T1-h: archive preserves raw stderr"
assert_file_contains "$ARCHIVE_STDERR" "ERROR: density traversal S3 archive precedents failed (rc 23)" "T1-h: archive emits traversal context"
assert_file_not_contains "$ARCHIVE_LOG" "$ERROR_DIR/docs/ship-flow/done" "T1-h: archive failure stops done traversal"

DONE_STDOUT="$TEST_TMP_ROOT/done.stdout"
DONE_STDERR="$TEST_TMP_ROOT/done.stderr"
DONE_LOG="$TEST_TMP_ROOT/done.log"
run_density_with_find_failure \
  "$ERROR_DIR" "done" "$ERROR_DIR/docs/ship-flow/done" "primary" \
  "$DONE_STDOUT" "$DONE_STDERR" "$DONE_LOG"
assert_eq "2" "$RUN_DENSITY_STATUS" "T1-h: done traversal failure exits 2"
assert_empty_file "$DONE_STDOUT" "T1-h: done traversal failure rejects partial classification"
assert_file_contains "$DONE_STDERR" "fake-find: injected done traversal failure" "T1-h: done preserves raw stderr"
assert_file_contains "$DONE_STDERR" "ERROR: density traversal S3 done precedents failed (rc 23)" "T1-h: done emits traversal context"

# Cleanup
rm -rf \
  "$HIGH_DIR" "$LOW_DIR" "$VAC_DIR" "$CLEAN_TWIN_DIR" "$DECOY_TWIN_DIR" \
  "$ARCHIVE_DECOY_DIR" "$DONE_DECOY_DIR" "$MARKER_BASE" "$ERROR_DIR" \
  "$TEST_TMP_ROOT" 2>/dev/null || true
rm -f \
  "$CLEAN_STDERR" "$DECOY_STDERR" "$ARCHIVE_DECOY_STDOUT" \
  "$ARCHIVE_DECOY_STDERR" "$DONE_DECOY_STDOUT" "$DONE_DECOY_STDERR" \
  "$MARKER_STDERR" 2>/dev/null || true

exit "$FAIL"
