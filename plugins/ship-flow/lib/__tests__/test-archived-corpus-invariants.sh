#!/usr/bin/env bash
# test-archived-corpus-invariants.sh — regression guard against drift
# introduced by new check-invariants gates landing on archived entities.
#
# Property: running `check-invariants.sh` against the live top-level
# docs/ship-flow corpus exits 0, and C4's directory walker can also reach
# nested `_archive/<entity>/` layouts under an explicit fixture. Any new gate
# that fails on historical top-level entities surfaces here at PR-time instead
# of becoming a CI red light next time someone touches plugins/ship-flow/** or
# docs/ship-flow/**. Nested `_archive` live backfill remains intentionally
# scoped out until the historical corpus is migrated.
#
# Background (2026-05-24): the C4 gate trigger expansion would have
# silently broken CI on 113.5/6/7 had the maintainer not been forced to
# verify blast radius. This test makes that verification mechanical and
# part of the standard test suite.
#
# Failure-mode triage:
#   - If a new gate is intentionally restrictive on archived entities,
#     either backfill the entities to comply OR scope the gate (e.g.,
#     `entity_created_after:` or `status != ship|done` clause).
#   - If a gate regresses on an active entity, that is the system working
#     as designed — fix the entity, not the test.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/../.."
CHECK_SCRIPT="${PLUGIN_DIR}/bin/check-invariants.sh"
FAIL=0

echo "=== test-archived-corpus-invariants ==="

fixture=$(mktemp -d)
mkdir -p "$fixture/docs/ship-flow/_archive/bad-archived/"
cat > "$fixture/docs/ship-flow/_archive/bad-archived/index.md" <<'EOF'
---
id: bad-archived
status: done
affects_ui: false
domain: schema
---
EOF
cat > "$fixture/docs/ship-flow/_archive/bad-archived/design.md" <<'EOF'
## Design Output

### Hand-off to Plan
design_constraints:
  - type: schema-contract
EOF
cat > "$fixture/docs/ship-flow/_archive/bad-archived/plan.md" <<'EOF'
# Plan
EOF

if bash "$CHECK_SCRIPT" --test-fixture "$fixture" --check plan-imported-design-dcs-emitted >/dev/null 2>&1; then
  echo "FAIL archive-fixture-covered (nested _archive entity was not checked)"
  FAIL=1
else
  echo "OK archive-fixture-covered (nested _archive entity fails C4 as expected)"
fi
rm -rf "$fixture"

# Capture both the exit code and the failing-check lines for actionable output.
OUTPUT=$(bash "$CHECK_SCRIPT" 2>&1) && exit_code=0 || exit_code=$?

if [ "$exit_code" = "0" ]; then
  echo "OK corpus-invariants-pass (exit 0 across all entities and checks)"
else
  echo "FAIL corpus-invariants-pass (exit $exit_code)"
  echo ""
  echo "--- failing lines (FAIL first, then WARN if room) ---"
  fail_lines=$(printf '%s\n' "$OUTPUT" | grep -E '^FAIL' | head -20)
  printf '%s\n' "$fail_lines"
  fail_count=$(printf '%s\n' "$fail_lines" | grep -c . || true)
  if [ "$fail_count" -lt 20 ]; then
    remaining=$((20 - fail_count))
    printf '%s\n' "$OUTPUT" | grep -E '^WARN' | head -"$remaining"
  fi
  echo "--- end preview ---"
  echo ""
  echo "Triage: a new gate may be hitting archived entities. See header"
  echo "comment in $(basename "$0") for resolution paths."
  FAIL=1
fi

if [ "$FAIL" = "0" ]; then
  echo ""
  echo "=== test-archived-corpus-invariants: ALL TESTS PASSED ==="
else
  echo ""
  echo "=== test-archived-corpus-invariants: FAILURES ABOVE ==="
fi
exit "$FAIL"
