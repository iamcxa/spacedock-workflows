#!/usr/bin/env bash
# test-verdict-flip.sh — TDD scaffold for ship/SKILL.md verdict-flip block (pitch-101 Task 10)
# Verifies the SKILL.md protocol spec is structurally correct (grep-based DCs).
# All cases should FAIL (red) before Task 10 lands the verdict-flip block in ship/SKILL.md.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
PLUGIN_DIR="${LIB_DIR}/.."
SHIP_SKILL="${PLUGIN_DIR}/skills/ship/SKILL.md"
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

# ── DC-12: verdict-flip block exists in ship/SKILL.md ────────────────────────

echo "--- DC-12: verdict-flip block in ship/SKILL.md ---"
if grep -qE 'verdict.flip|verdict_flip|is_high_density' "$SHIP_SKILL" 2>/dev/null; then
  echo "OK DC-12a: verdict-flip pattern present"
else
  echo "FAIL DC-12a: ship/SKILL.md missing verdict-flip pattern"; FAIL=1
fi

# DC-12b: PROMPT_CAPTAIN → PROCEED transition documented
VF_CONTEXT="$(grep -A50 'Verdict-flip transformation' "$SHIP_SKILL" 2>/dev/null)"
if echo "$VF_CONTEXT" | grep -q 'is_high_density' && echo "$VF_CONTEXT" | grep -q 'WHITELIST'; then
  echo "OK DC-12b: WHITELIST+is_high_density gate documented"
else
  echo "FAIL DC-12b: verdict-flip block missing WHITELIST+is_high_density gate"; FAIL=1
fi

# ── DC-13: whitelist is boolean-decomposed (≥1 row) ──────────────────────────

echo "--- DC-13: whitelist boolean predicates ---"
WHITELIST_ROWS=$({ awk '/^\*\*WHITELIST\*\*/,/^##/' "$SHIP_SKILL" 2>/dev/null | { grep -E '^[[:space:]]*-[[:space:]]+.reason_[a-zA-Z0-9_]+' 2>/dev/null || true; } | wc -l | tr -d ' '; })
if [ "$WHITELIST_ROWS" -ge 1 ]; then
  echo "OK DC-13a: whitelist has $WHITELIST_ROWS boolean predicate rows"
else
  echo "FAIL DC-13a: whitelist must have ≥1 boolean predicate row (got $WHITELIST_ROWS)"; FAIL=1
fi

# DC-13b: no enum-string gates in verdict-flip block (anti-pattern: verdict_mode: ask|skip|auto)
if grep -A50 'Verdict-flip transformation' "$SHIP_SKILL" 2>/dev/null | grep -qE '(reason|verdict)\s*[:=]\s*["'"'"']?(ask|skip|auto)'; then
  echo "FAIL DC-13b: enum-string gate found in verdict-flip block (Principle 4 violation)"; FAIL=1
else
  echo "OK DC-13b: no enum-string gates in verdict-flip block"
fi

# ── DC-14: decisions.md append uses explicit pathspec ────────────────────────

echo "--- DC-14: decisions.md explicit pathspec in ship/SKILL.md ---"
if grep -qE 'decisions\.md' "$SHIP_SKILL" 2>/dev/null; then
  echo "OK DC-14a: decisions.md referenced in ship/SKILL.md"
else
  echo "FAIL DC-14a: ship/SKILL.md missing decisions.md reference"; FAIL=1
fi

# ── Fixture: boolean gate semantics via density-classify.sh ──────────────────
# These tests verify the classifier (T4) correctly supports the gate logic.

echo "--- Fixture: density gate semantics ---"

# Make a high-density fixture
make_high_fixture() {
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/CLAUDE.md" <<'EOF'
# ship-flow
## Ship-Flow Pipeline
EOF
  mkdir -p "$dir/docs/ship-flow/_archive"
  echo "slug: p1" > "$dir/docs/ship-flow/_archive/001.md"
  echo "slug: p2" > "$dir/docs/ship-flow/_archive/002.md"
  mkdir -p "$dir/plugins/ship-flow/references"
  cat > "$dir/ARCHITECTURE.md" <<'EOF'
<!-- section:constraints -->
## Constraints
ship-flow constraints.
<!-- /section:constraints -->
EOF
  cat > "$dir/index.md" <<EOF
---
id: "999"
slug: vf-test-high
workflow_dir: docs/ship-flow
---
EOF
  echo "$dir"
}

# Make a low-density fixture
make_low_fixture() {
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/CLAUDE.md" <<'EOF'
# Generic
EOF
  mkdir -p "$dir/docs/ship-flow/_archive"
  echo "slug: p1" > "$dir/docs/ship-flow/_archive/001.md"
  echo "slug: p2" > "$dir/docs/ship-flow/_archive/002.md"
  touch "$dir/ARCHITECTURE.md"
  cat > "$dir/index.md" <<EOF
---
id: "998"
slug: vf-test-low
workflow_dir: docs/ship-flow
---
EOF
  echo "$dir"
}

if [ -f "$CLASSIFIER" ]; then
  HIGH_DIR="$(make_high_fixture)"
  LOW_DIR="$(make_low_fixture)"

  # T10 fixture case 1: high-density entity → is_high_density exits 0 (gate opens)
  assert_exit 0 "bash '$CLASSIFIER' --is-high --entity='$HIGH_DIR/index.md'" \
    "T10-fixture-1: high-density entity → is_high exits 0 (gate allows flip)"

  # T10 fixture case 2: low-density entity → is_high_density exits 1 (gate blocks)
  assert_exit 1 "bash '$CLASSIFIER' --is-high --entity='$LOW_DIR/index.md'" \
    "T10-fixture-2: low-density entity → is_high exits 1 (gate blocks flip)"

  rm -rf "$HIGH_DIR" "$LOW_DIR" 2>/dev/null || true
else
  echo "FAIL T10-fixture: density-classify.sh not found (T4 must land first)"; FAIL=1
fi

exit "$FAIL"
