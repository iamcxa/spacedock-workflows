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
  # DC-6 — Principle 2: skill count ≤ 7
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  local n=0
  if [ -d "$skills_dir" ]; then
    # shellcheck disable=SC2012  # ls is fine here; no weird filenames expected in skills/
    n=$(ls -1 "$skills_dir"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$n" -gt 7 ]; then
    echo "ERROR [Principle 2]: skill count > 7 (got $n). See plugins/ship-flow/INVARIANTS.md#principle-2" >&2
    return 1
  fi
  return 0
}

check_preamble_regrowth() {
  # DC-7 — Principle 1 + 6: known preambles should not appear in ≥ 2 SKILL.md files
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local signatures=(
    "## Runtime Detection Preamble"
    "### Step R1: Detect Stacks"
  )
  local fail=0
  local sig n
  for sig in "${signatures[@]}"; do
    n=$(grep -lF "$sig" "$skills_dir"/*/SKILL.md 2>/dev/null | wc -l | tr -d ' ')
    if [ "$n" -ge 2 ]; then
      echo "ERROR [Principle 1/6]: preamble '$sig' appears in $n SKILL.md files (≥ 2). Consolidate via 046f preamble-extraction. See plugins/ship-flow/INVARIANTS.md#principle-1" >&2
      fail=1
    fi
  done
  return "$fail"
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
  # DC-10 — Principle 5c: Read(docs/ship-flow/*.md) in SKILL.md needs `# justification:` within ±2 lines
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local pattern='Read[[:space:]]*\([^)]*docs/ship-flow/[^)]*\.md'
  local fail=0
  local f line_num start end
  for f in "$skills_dir"/*/SKILL.md; do
    [ -f "$f" ] || continue
    # Find line numbers of matches
    local hits
    hits=$(grep -nE "$pattern" "$f" 2>/dev/null | cut -d: -f1 || true)
    [ -z "$hits" ] && continue
    while IFS= read -r line_num; do
      [ -z "$line_num" ] && continue
      start=$((line_num - 2))
      end=$((line_num + 2))
      [ "$start" -lt 1 ] && start=1
      if ! sed -n "${start},${end}p" "$f" | grep -qF '# justification:'; then
        echo "ERROR [Principle 5c]: direct Read/Edit on entity file at $f:$line_num (no '# justification:' within ±2 lines). Use lib/extract-section.sh or add justification comment." >&2
        fail=1
      fi
    done <<< "$hits"
  done
  return "$fail"
}

check_fan_out_reviewer() {
  # DC-11 — Principle 3: ship-verify Agent() dispatches > 2 without `# opt-in:` fail
  local verify_skill="${ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
  [ -f "$verify_skill" ] || return 0
  local total opt_in unconditional
  # Use `grep -c` with `|| var=0` fallback — `grep -c X || echo 0` would print "0\n0"
  # when grep returns 1 (no match), breaking arithmetic. Pattern below handles both cases.
  total=$(grep -cE '^[[:space:]]*Agent[[:space:]]*\(' "$verify_skill" 2>/dev/null) || total=0
  opt_in=$(grep -cE '#[[:space:]]*opt-in:' "$verify_skill" 2>/dev/null) || opt_in=0
  unconditional=$((total - opt_in))
  if [ "$unconditional" -gt 2 ]; then
    echo "ERROR [Principle 3]: ship-verify SKILL.md has $unconditional unconditional Agent() dispatches (cap: 2). See plugins/ship-flow/INVARIANTS.md#principle-3. Mark extras with adjacent '# opt-in: <reason>' comment." >&2
    return 1
  fi
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
