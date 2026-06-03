#!/usr/bin/env bash
# test-dag-waves.sh — wave-layering + ready-set computation for the ship-flow
# wave orchestrator (pitch 118 / Option B). Pure-algorithm cases drive via
# --stdin; one fixture-dir case drives the index.md adapter.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
LIB="${LIB_DIR}/dag-waves.sh"
FAIL=0

assert_out() {
  # assert_out <name> <expected-stdout> <stdin> <args...>
  local name="$1" expected="$2" input="$3"; shift 3
  local got
  got="$(printf '%s' "$input" | bash "$LIB" "$@" 2>/dev/null)"
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name"; echo "  expected: [$expected]"; echo "  got:      [$got]"; FAIL=1; fi
}

assert_exit() {
  # assert_exit <name> <expected-exit> <stdin> <args...>
  local name="$1" expected="$2" input="$3"; shift 3
  local got
  printf '%s' "$input" | bash "$LIB" "$@" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

# ---- Fixtures (id<TAB>status<TAB>comma-deps) ----
LINEAR="$(printf '118.1\tplan\t\n118.2\tplan\t118.1\n')"
LINEAR_D1="$(printf '118.1\tdone\t\n118.2\tplan\t118.1\n')"
LINEAR_DONE="$(printf '118.1\tdone\t\n118.2\tdone\t118.1\n')"
INDEP="$(printf 'a\tplan\t\nb\tplan\t\n')"
DIAMOND="$(printf 'a\tplan\t\nb\tplan\ta\nc\tplan\ta\nd\tplan\tb,c\n')"
CYCLE="$(printf 'a\tplan\tb\nb\tplan\ta\n')"
MISSING="$(printf 'a\tplan\tz\n')"

echo "--- DC-1: --layers linear → two waves in dependency order ---"
assert_out "layers-linear" "$(printf '118.1\n118.2')" "$LINEAR" --layers --stdin

echo "--- DC-2: --layers independent → single wave (sorted) ---"
assert_out "layers-indep" "a b" "$INDEP" --layers --stdin

echo "--- DC-3: --layers diamond → a / b c / d ---"
assert_out "layers-diamond" "$(printf 'a\nb c\nd')" "$DIAMOND" --layers --stdin

echo "--- DC-4: --layers cycle → non-zero exit ---"
assert_exit "layers-cycle" 2 "$CYCLE" --layers --stdin

echo "--- DC-5: --layers missing dep ref → closure error (exit 3) ---"
assert_exit "layers-missing" 3 "$MISSING" --layers --stdin

echo "--- DC-6: --ready both plan → only the dependency-free child ---"
assert_out "ready-wave1" "118.1" "$LINEAR" --ready --stdin

echo "--- DC-7: --ready dep done → the dependent child unblocks ---"
assert_out "ready-wave2" "118.2" "$LINEAR_D1" --ready --stdin

echo "--- DC-8: --ready all done → empty ---"
assert_out "ready-empty" "" "$LINEAR_DONE" --ready --stdin

echo "--- DC-9: --ready independent both plan → both ready ---"
assert_out "ready-indep" "a b" "$INDEP" --ready --stdin

echo "--- DC-10: index.md adapter reads parent_pitch children + status + depends-on ---"
FX="$(mktemp -d)"
mkdir -p "$FX/118-epic" "$FX/118.1-core" "$FX/118.2-adapter"
cat > "$FX/118-epic/index.md" <<'EOF'
---
id: "118"
status: epic
pattern: pitch
children:
  - 118.1-core
  - 118.2-adapter
---
EOF
cat > "$FX/118.1-core/index.md" <<'EOF'
---
id: "118.1"
status: plan
pattern: shaped-child
parent_pitch: "118"
---
EOF
cat > "$FX/118.2-adapter/index.md" <<'EOF'
---
id: "118.2"
status: plan
pattern: shaped-child
parent_pitch: "118"
depends-on: ["118.1"]
---
EOF
assert_out "adapter-ready" "118.1" "" --ready --from-workflow "$FX" --epic 118
assert_out "adapter-layers" "$(printf '118.1\n118.2')" "" --layers --from-workflow "$FX" --epic 118
rm -rf "$FX"

echo "--- DC-11: adapter accepts BOTH depends-on (hyphen) AND depends_on (underscore) — corpus mixes them ---"
FX2="$(mktemp -d)"
mkdir -p "$FX2/e-epic" "$FX2/e.1-core" "$FX2/e.2-under" "$FX2/e.3-block"
cat > "$FX2/e-epic/index.md" <<'EOF'
---
id: "e"
status: epic
parent_pitch: ""
---
EOF
cat > "$FX2/e.1-core/index.md" <<'EOF'
---
id: "e.1"
status: plan
parent_pitch: "e"
---
EOF
cat > "$FX2/e.2-under/index.md" <<'EOF'
---
id: "e.2"
status: plan
parent_pitch: "e"
depends_on: ["e.1"]
---
EOF
cat > "$FX2/e.3-block/index.md" <<'EOF'
---
id: "e.3"
status: plan
parent_pitch: "e"
depends_on:
  - "e.1"
  - "e.2"
---
EOF
# e.2 (underscore inline) depends e.1; e.3 (underscore block) depends e.1+e.2.
# Wave1 ready = e.1 only (e.2/e.3 must be HELD — proves underscore parsed).
assert_out "adapter-ready-underscore" "e.1" "" --ready --from-workflow "$FX2" --epic e
assert_out "adapter-layers-underscore" "$(printf 'e.1\ne.2\ne.3')" "" --layers --from-workflow "$FX2" --epic e
rm -rf "$FX2"

echo "--- DC-12: scalar 'none' depends → treated as no-deps (benign) ---"
FX3="$(mktemp -d)"
mkdir -p "$FX3/n-epic" "$FX3/n.1-a" "$FX3/n.2-b"
printf -- '---\nid: "n"\nstatus: epic\nparent_pitch: ""\n---\n' > "$FX3/n-epic/index.md"
printf -- '---\nid: "n.1"\nstatus: plan\nparent_pitch: "n"\ndepends_on: none\n---\n' > "$FX3/n.1-a/index.md"
printf -- '---\nid: "n.2"\nstatus: plan\nparent_pitch: "n"\ndepends-on: []\n---\n' > "$FX3/n.2-b/index.md"
assert_out "scalar-none-noop" "n.1 n.2" "" --ready --from-workflow "$FX3" --epic n
rm -rf "$FX3"

echo "--- DC-13: unparseable prose depends → FAIL CLOSED (closure exit 3), not silent no-deps ---"
FX4="$(mktemp -d)"
mkdir -p "$FX4/p-epic" "$FX4/p.1-a" "$FX4/p.2-b"
printf -- '---\nid: "p"\nstatus: epic\nparent_pitch: ""\n---\n' > "$FX4/p-epic/index.md"
printf -- '---\nid: "p.1"\nstatus: plan\nparent_pitch: "p"\n---\n' > "$FX4/p.1-a/index.md"
printf -- '---\nid: "p.2"\nstatus: plan\nparent_pitch: "p"\ndepends_on: p.1 (mechanism-sanity)\n---\n' > "$FX4/p.2-b/index.md"
assert_exit "prose-fail-closed" 3 "" --layers --from-workflow "$FX4" --epic p
rm -rf "$FX4"

echo "--- DC-14: duplicate id (corpus collision) → FAIL CLOSED (exit 4), not silent dup output ---"
DUP_IN="$(printf '108.1\tship\t\n108.1\tplan\t\n108.2\tplan\t108.1\n')"
assert_exit "dup-id-fail-closed" 4 "$DUP_IN" --layers --stdin

echo
if [ "$FAIL" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit "$FAIL"
