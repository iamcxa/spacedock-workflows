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

echo
if [ "$FAIL" = 0 ]; then echo "ALL PASS"; else echo "SOME FAILED"; fi
exit "$FAIL"
