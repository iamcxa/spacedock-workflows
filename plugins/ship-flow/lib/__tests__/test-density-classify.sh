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

# Cleanup
rm -rf "$HIGH_DIR" "$LOW_DIR" "$VAC_DIR" 2>/dev/null || true

exit "$FAIL"
