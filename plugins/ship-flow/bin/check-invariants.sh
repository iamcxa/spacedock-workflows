#!/usr/bin/env bash
# check-invariants.sh — grep-enforce 6 cut principles + 3-map coverage
# Entity: #067 ship-flow-invariants (slot 046e)
# Sibling: plugins/ship-flow/INVARIANTS.md (principles rationale)
# Test: plugins/ship-flow/lib/__tests__/test-check-invariants.sh
#
# Exit codes:
#   0 — all checks pass
#   1 — one or more checks failed
#   2 — usage error
#
# Invocation:
#   check-invariants.sh                             # run all checks on current repo
#   check-invariants.sh --test-fixture <dir>        # run against mock dir (tests use)
#   check-invariants.sh --check <name>              # run single check by name
#   check-invariants.sh --map <section|flow|rid>    # run single map check
#   check-invariants.sh --spike-boolean-gate        # Tier A spike output only

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/.."
LIB_DIR="${PLUGIN_DIR}/lib"

# Source kebab-case validator + sha256_of from map-helpers
# shellcheck disable=SC1091
[ -f "${LIB_DIR}/map-helpers.sh" ] && source "${LIB_DIR}/map-helpers.sh"

# ---- Arg parsing ----
FIXTURE=""
SINGLE_CHECK=""
SINGLE_MAP=""
SPIKE_BOOLEAN_GATE=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --test-fixture) FIXTURE="$2"; shift 2 ;;
    --check) SINGLE_CHECK="$2"; shift 2 ;;
    --map) SINGLE_MAP="$2"; shift 2 ;;
    --spike-boolean-gate) SPIKE_BOOLEAN_GATE=1; shift ;;
    -h|--help)
      sed -n '1,20p' "${BASH_SOURCE[0]}"; exit 0 ;;
    *) echo "ERROR: unknown arg: $1" >&2; exit 2 ;;
  esac
done

# Root for scanning — fixture dir overrides default REPO_ROOT.
# Exported for check functions (filled in T6/T7/T8).
# shellcheck disable=SC2034  # used by check functions added in T6/T7/T8
if [ -n "$FIXTURE" ]; then
  ROOT="$FIXTURE"
else
  ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
fi
export ROOT

FAIL=0

# ---- Check functions (stubs in T3; bodies filled in T6/T7/T8) ----

check_skill_count() {
  # T6 impl target — DC-6
  echo "stub: check_skill_count (T6)"
  return 0
}

check_preamble_regrowth() {
  # T6 impl target — DC-7
  echo "stub: check_preamble_regrowth (T6)"
  return 0
}

check_section_tag_coverage() {
  # T7 impl target — DC-8 (map-1)
  echo "stub: check_section_tag_coverage (T7)"
  return 0
}

check_flow_map_coverage() {
  # T7 impl target — DC-9 (map-2)
  echo "stub: check_flow_map_coverage (T7)"
  return 0
}

check_direct_read_static() {
  # T6 impl target — DC-10
  echo "stub: check_direct_read_static (T6)"
  return 0
}

check_fan_out_reviewer() {
  # T6 impl target — DC-11
  echo "stub: check_fan_out_reviewer (T6)"
  return 0
}

check_boolean_gate() {
  # T8 impl target — DC-12 (Tier A spike or Tier B fallback)
  echo "stub: check_boolean_gate (T8)"
  return 0
}

check_rid_placeholder() {
  # T7 impl target — DC-13 (map-3 intentional skip)
  echo "stub: check_rid_placeholder (T7)"
  return 0
}

# ---- Dispatcher ----

# Single-check mode
if [ -n "$SINGLE_CHECK" ]; then
  case "$SINGLE_CHECK" in
    skill-count) check_skill_count; exit $? ;;
    preamble-regrowth) check_preamble_regrowth; exit $? ;;
    section-tag-coverage) check_section_tag_coverage; exit $? ;;
    flow-map-coverage) check_flow_map_coverage; exit $? ;;
    direct-read-static) check_direct_read_static; exit $? ;;
    fan-out-reviewer) check_fan_out_reviewer; exit $? ;;
    boolean-gate) check_boolean_gate; exit $? ;;
    rid-placeholder) check_rid_placeholder; exit $? ;;
    *) echo "ERROR: unknown check: $SINGLE_CHECK" >&2; exit 2 ;;
  esac
fi

# Single-map mode
if [ -n "$SINGLE_MAP" ]; then
  case "$SINGLE_MAP" in
    section) check_section_tag_coverage; exit $? ;;
    flow) check_flow_map_coverage; exit $? ;;
    rid) check_rid_placeholder; exit $? ;;
    *) echo "ERROR: unknown map: $SINGLE_MAP" >&2; exit 2 ;;
  esac
fi

# Spike-only mode (T8)
if [ "$SPIKE_BOOLEAN_GATE" = "1" ]; then
  check_boolean_gate
  exit $?
fi

# Full run — all 8 checks
check_skill_count || FAIL=1
check_preamble_regrowth || FAIL=1
check_section_tag_coverage || FAIL=1
check_flow_map_coverage || FAIL=1
check_direct_read_static || FAIL=1
check_fan_out_reviewer || FAIL=1
check_boolean_gate || FAIL=1
check_rid_placeholder || FAIL=1

exit $FAIL
