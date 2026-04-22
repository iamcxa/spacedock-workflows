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
  # DC-7 — Principle 1 + 6: known preambles must not appear in ≥ 2 SKILL.md files.
  # Post-046f: allowlist removed, ship-runtime-detect is canonical source. All signatures
  # hard-enforced. Add new signatures here as shared preambles get introduced — makes
  # regrowth visible the moment someone copies a preamble into a second SKILL.md.
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local signatures=(
    "## Runtime Detection Preamble"
    "### Step R1: Detect Stacks"
    "## Verify Stage Preamble"
    "## Journey Code Trace Preamble"
  )
  local fail=0
  local sig n
  for sig in "${signatures[@]}"; do
    # `{ grep || true; }` guards against set -euo pipefail:
    # grep -lF returns rc=1 on no-match, which pipefail propagates through
    # the pipeline and (without the guard) aborts the function via set -e.
    # The outer brace group ensures the pipeline itself exits 0, so n receives
    # exactly one clean integer from wc (e.g. "0" or "3"), not "0\n0".
    n=$({ grep -lF "$sig" "$skills_dir"/*/SKILL.md 2>/dev/null || true; } | wc -l | tr -d ' ')
    if [ "$n" -ge 2 ]; then
      echo "ERROR [Principle 1/6]: preamble '$sig' appears in $n SKILL.md files (≥ 2). See plugins/ship-flow/INVARIANTS.md#principle-1" >&2
      fail=1
    fi
  done
  return "$fail"
}

check_section_tag_coverage() {
  # DC-8 — Principle 5a: every H2/H3 in active entity must be wrapped in <!-- section:tag --> pair.
  # Stack-based awk walker; nesting allowed (sharp-output → problem → scope).
  #
  # Grandfather rule: pre-049 entities were never tagged — flagging all 42 of them would be
  # massive scope creep for 046e. Rule: entity is ENFORCED only if it already contains ≥ 1
  # section tag (demonstrating adoption intent). Entities with zero tags are skipped with WARN
  # (pre-049 baseline). New sharp-created entities always have tags (per ship-sharp/ship-plan skills).
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0
  local f bn has_tags
  for f in "$docs_dir"/*.md; do
    [ -f "$f" ] || continue
    bn="$(basename "$f")"
    [ "$bn" = "README.md" ] && continue
    case "$f" in *_archive*) continue ;; esac
    # Grandfather: skip entities with zero section tags (pre-049 baseline).
    has_tags=$(grep -c '^<!-- section:[a-z]' "$f" 2>/dev/null) || has_tags=0
    if [ "$has_tags" = "0" ]; then
      echo "WARN [Principle 5a]: $bn — pre-049 baseline (no section tags; grandfather skip). Add tags on next edit." >&2
      continue
    fi
    # awk semantics:
    #   - Headers BEFORE the first <!-- section: --> tag are intro/prose zone (allowed)
    #   - Headers INSIDE a tag pair are wrapped (allowed, nested)
    #   - Headers AFTER first tag but outside any pair = orphan (flagged)
    #   - Unclosed tags at EOF = structural error (flagged)
    # Spacedock-protocol whitelist (2026-04-22, post-#078 CI-fail harvest):
    #   Spacedock ensign-shared-core.md:46-51 instructs ensigns to append untagged
    #   "## Stage Report: {stage}" at entity-file end (protocol-owned, plugin-agnostic).
    #   Ship-flow accepts this as a known-ok orphan pattern rather than forcing spacedock
    #   to adopt ship-flow's section-tag convention (ship-flow portability goal — don't
    #   impose on engine). Whitelist covers the H2 + any nested H3s under it.
    local errors
    errors=$(awk '
      /^<!-- section:[a-z]/ { seen_tag = 1; top++; in_stage_report = 0; next }
      /^<!-- \/section:[a-z]/ { if (top > 0) top--; next }
      /^## Stage Report:/ { in_stage_report = 1; next }
      /^## / || /^### / {
        if (in_stage_report && /^### /) next
        if (/^## /) in_stage_report = 0
        if (seen_tag && top == 0) print FILENAME ":" NR ": orphan header: " $0
      }
      END {
        if (top > 0) print FILENAME ": EOF with " top " unclosed section tag(s)"
      }
    ' "$f" 2>&1)
    if [ -n "$errors" ]; then
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "ERROR [Principle 5a]: $line. See plugins/ship-flow/INVARIANTS.md#principle-5" >&2
      done <<< "$errors"
      fail=1
    fi
  done
  return "$fail"
}

check_flow_map_coverage() {
  # DC-9 — Principle 5b: canonical docs in flow-map-schema.yaml must extract non-empty
  # via lib/extract-map.sh; sections with requires_diagram: true must contain ```mermaid block.
  # NOTE: schema parsing is hardcoded against current schema (ARCHITECTURE.md, 6 sections).
  # When schema gains more active maps, update the loop below.
  local schema="${ROOT}/plugins/ship-flow/references/flow-map-schema.yaml"
  local extract_map="${ROOT}/plugins/ship-flow/lib/extract-map.sh"
  if [ ! -f "$schema" ]; then
    echo "WARN [Principle 5b]: flow-map-schema.yaml not found at $schema — skip" >&2
    return 0
  fi
  if [ ! -x "$extract_map" ]; then
    echo "WARN [Principle 5b]: extract-map.sh not found or not executable — skip" >&2
    return 0
  fi
  local fail=0
  # ARCHITECTURE.md — 6 sections (context/containers/components require mermaid; rest are prose-only)
  local arch_path="${ROOT}/ARCHITECTURE.md"
  if [ ! -f "$arch_path" ]; then
    echo "WARN [Principle 5b]: ARCHITECTURE.md not found at $arch_path — skip" >&2
    return 0
  fi
  local tag content
  for tag in context containers components constraints dependencies decisions; do
    content=$(cd "$ROOT" && "$extract_map" "ARCHITECTURE.md" "$tag" 2>&1) || {
      echo "ERROR [Principle 5b]: ARCHITECTURE.md §$tag — extract-map.sh failed" >&2
      fail=1; continue
    }
    if [ -z "$content" ]; then
      echo "ERROR [Principle 5b]: ARCHITECTURE.md §$tag — empty content" >&2
      fail=1; continue
    fi
    case "$tag" in
      context|containers|components)
        # Detect mermaid fenced code block (literal: backtick-backtick-backtick mermaid)
        if ! echo "$content" | grep -q '^```mermaid'; then
          echo "ERROR [Principle 5b]: ARCHITECTURE.md §$tag — requires_diagram: true but mermaid fenced block not found" >&2
          fail=1
        fi
        ;;
    esac
  done
  return "$fail"
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
  # DC-12 — Principle 4: captain-interrupt decisions must be boolean, not enum.
  # Tier A: grep for enum-string gate values. Spike on current repo (2026-04-21) returned 0 hits,
  # so Tier A is primary. Tier B fallback (design-review checklist only) reserved if grep
  # proves brittle — see plugins/ship-flow/INVARIANTS.md §Captain-Gate Checklist.
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  # Pattern: "prompt_captain: ask" / "interrupt_captain: skip" / "captain_gate: auto" etc.
  local pattern_a='(prompt_captain|interrupt_captain|captain_gate)[[:space:]]*[:=][[:space:]]*"?(ask|skip|auto|yes|no)'
  local pattern_b='\bgate\b[[:space:]]*:[[:space:]]*"?(ask|skip|continue|block)'
  local hits_a hits_b
  hits_a=$(grep -rnE "$pattern_a" "$skills_dir" 2>/dev/null) || hits_a=""
  hits_b=$(grep -rnE "$pattern_b" "$skills_dir" 2>/dev/null) || hits_b=""
  if [ -z "$hits_a" ] && [ -z "$hits_b" ]; then
    echo "boolean-gate: no enum gate found in plugins/ship-flow/skills/" >&2
    return 0
  fi
  echo "ERROR [Principle 4]: enum-string captain-gate values found — boolean gate required:" >&2
  [ -n "$hits_a" ] && echo "$hits_a" >&2
  [ -n "$hits_b" ] && echo "$hits_b" >&2
  echo "See plugins/ship-flow/INVARIANTS.md#principle-4 + §Captain-Gate Checklist for refactor guidance." >&2
  return 1
}

check_rid_placeholder() {
  # DC-13 — map-3 R-ID coverage placeholder. Intentional skip until spec-of-spec v1 ships.
  # The "intentional" word in the stderr line IS the test assertion (DC-13 grep).
  echo "map-3 R-ID coverage: skipped — spec-of-spec v1 not yet shipped (placeholder, intentional)" >&2
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
