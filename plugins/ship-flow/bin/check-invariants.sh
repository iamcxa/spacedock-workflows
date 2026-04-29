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
  # DC-6 — Principle 2: stage skill count ≤ 7; utility skills uncapped.
  # Explicit allowlists — catches unclassified additions immediately.
  local STAGE_SKILLS=(ship-shape ship-design ship ship-plan ship-execute ship-verify ship-review)
  local UTILITY_SKILLS=(add-todos ship-onboard ship-runtime-detect)
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0

  local fail=0
  local stage_count=0
  local sk

  # Walk every skill directory and classify
  for sk_dir in "$skills_dir"/*/; do
    sk="$(basename "$sk_dir")"
    [ -f "${sk_dir}SKILL.md" ] || continue

    local in_stage=0 in_utility=0
    for s in "${STAGE_SKILLS[@]}";   do [ "$sk" = "$s" ] && in_stage=1   && break; done
    for u in "${UTILITY_SKILLS[@]}"; do [ "$sk" = "$u" ] && in_utility=1 && break; done

    if [ "$in_stage" = "1" ]; then
      stage_count=$((stage_count + 1))
    elif [ "$in_utility" = "0" ]; then
      echo "ERROR [Principle 2]: unclassified skill '$sk' — add to STAGE_SKILLS or UTILITY_SKILLS in check-invariants.sh. See plugins/ship-flow/INVARIANTS.md#principle-2" >&2
      fail=1
    fi
  done

  if [ "$stage_count" -gt 7 ]; then
    echo "ERROR [Principle 2]: stage skill count > 7 (got $stage_count; cap is 7). See plugins/ship-flow/INVARIANTS.md#principle-2" >&2
    fail=1
  fi
  return "$fail"
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
  # (pre-049 baseline). New sharp-created entities always have tags (per ship-shape/ship-plan skills).
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

check_stage_artifact_path() {
  # Verify every stage SKILL.md references its declared artifact filename.
  # Mapping: ship-shape→spec.md, ship-plan→plan.md, ship-execute→execute.md,
  #          ship-verify→verify.md, ship-review→review.md, ship→ship.md
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local fail=0
  declare -A ARTIFACT_MAP
  ARTIFACT_MAP=(
    [ship-shape]=spec.md
    [ship-plan]=plan.md
    [ship-execute]=execute.md
    [ship-verify]=verify.md
    [ship-review]=review.md
    [ship]=ship.md
  )
  local sk artifact n
  for sk in "${!ARTIFACT_MAP[@]}"; do
    local skill_file="${skills_dir}/${sk}/SKILL.md"
    [ -f "$skill_file" ] || continue
    artifact="${ARTIFACT_MAP[$sk]}"
    n=$({ grep -cF "$artifact" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    if [ "${n:-0}" = "0" ]; then
      echo "ERROR [stage-artifact-path]: ${sk}/SKILL.md does not mention its artifact '${artifact}'" >&2
      fail=1
    fi
  done
  return "$fail"
}

check_layer_a_delegation() {
  # Verify every stage SKILL.md either:
  #  (a) contains an explicit plugin-qualified skill invocation pattern
  #      (`Skill: plugin:skill-name` OR `Skill(plugin:skill-name)`), backticks optional
  #  OR
  #  (b) contains an explicit escape annotation:
  #      'no Layer A' / 'pure orchestrat' (matches 'pure orchestration')
  #
  # Rationale: pitch 088 strengthens the prose-only check that passed on bare
  # mentions of "Layer A" without ever naming or invoking an atomic skill.
  # Prose presence with no invocation = cargo-cult compliance; opus 4.7 will
  # skip the delegate when the prompt doesn't feel like it needs a sub-skill.
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local STAGE_SKILLS=(ship-shape ship-design ship ship-plan ship-execute ship-verify ship-review)
  local fail=0
  local sk
  for sk in "${STAGE_SKILLS[@]}"; do
    local skill_file="${skills_dir}/${sk}/SKILL.md"
    [ -f "$skill_file" ] || continue
    local has_invocation has_escape
    # Invocation pattern: optional backtick, "Skill", colon-or-paren, optional space,
    # plugin-name (lowercase kebab), colon, then something (skill-name).
    has_invocation=$({ grep -cE '`?Skill[:(] ?[a-z][a-z0-9-]+:' "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    has_escape=$({ grep -cEi 'no Layer A|pure orchestrat' "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    if [ "${has_invocation:-0}" = "0" ] && [ "${has_escape:-0}" = "0" ]; then
      echo "ERROR [layer-a-delegation]: ${sk}/SKILL.md has no Layer A delegation — neither a plugin-qualified Skill invocation (e.g., 'Skill: superpowers:writing-plans') nor an explicit 'no Layer A — pure orchestration' escape annotation" >&2
      fail=1
    fi
  done
  return "$fail"
}

check_team_fallback_documented() {
  # Verify every stage SKILL.md references a fallback path for teammate/subagent unavailability.
  # Mirrors check_layer_a_delegation convention; prose-level grep — can't verify
  # the prose gets executed, but prose presence > prose absence for an unproven primitive.
  # Accepts: "fresh subagent" | "fresh Agent" | "team unavailable" | "phantom"
  # | "fallback" | explicit "no TeamCreate" annotation (any case).
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local STAGE_SKILLS=(ship-shape ship-design ship ship-plan ship-execute ship-verify ship-review)
  local fail=0
  local sk n
  for sk in "${STAGE_SKILLS[@]}"; do
    local skill_file="${skills_dir}/${sk}/SKILL.md"
    [ -f "$skill_file" ] || continue
    n=$({ grep -cEi -e "fresh.subagent|fresh.Agent|team.unavailable|phantom|fallback|no TeamCreate" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    if [ "${n:-0}" = "0" ]; then
      echo "ERROR [team-fallback-documented]: ${sk}/SKILL.md has no TeamCreate/SendMessage fallback reference (add one of: 'fresh subagent', 'fresh Agent', 'team unavailable', 'phantom', 'fallback', or a 'no TeamCreate — pure inline orchestration' annotation; see INVARIANTS.md Principle 6 Rule A Fallback)" >&2
      fail=1
    fi
  done
  return "$fail"
}

check_cross_review_gate() {
  # Verify every stage SKILL.md has a cross-review gate with N-factor rubric.
  # Requires: cross-review mention + "[5-9]-factor rubric" + "Feasibility" (case-insensitive).
  # Accepts 5/6/7/8/9-factor variants per pitch-106 INVARIANTS FM#4 amendment
  # (base 5 + stage-specific extensions like Reverse-audit, Render Fidelity).
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local STAGE_SKILLS=(ship-shape ship-design ship ship-plan ship-execute ship-verify ship-review)
  local fail=0
  local sk
  for sk in "${STAGE_SKILLS[@]}"; do
    local skill_file="${skills_dir}/${sk}/SKILL.md"
    [ -f "$skill_file" ] || continue
    local has_gate has_rubric has_feasibility
    has_gate=$({ grep -ciE "cross-review gate|cross.review" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    has_rubric=$({ grep -cE "[5-9]-factor rubric" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    has_feasibility=$({ grep -ciF "feasibility" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    if [ "${has_gate:-0}" = "0" ] || [ "${has_rubric:-0}" = "0" ] || [ "${has_feasibility:-0}" = "0" ]; then
      echo "ERROR [cross-review-gate]: ${sk}/SKILL.md missing cross-review gate section or N-factor rubric (needs cross-review + '[5-9]-factor rubric' + 'Feasibility')" >&2
      fail=1
    fi
  done
  return "$fail"
}

check_layer_a_table_parity() {
  # Verify every stage SKILL.md that declares a concrete Layer A delegate in
  # the INVARIANTS.md master table (lines 157-168) carries BOTH:
  #   (1) the canonical H2 heading `## Layer A delegation (Principle 6 Rule B)`
  #   (2) a description-frontmatter prefix `description: "... Layer A delegation: ..."`
  #
  # Exception: SKILLs whose master-table row lists the delegate as "—" (pure
  # orchestration — `ship`) are exempt. Multi-mode stages (ship-shape 3 rows)
  # pass if they carry an explicit `Layer A exception` annotation in lieu of
  # the canonical H2 — mirrors Mode A/B/C documented-exception pattern.
  #
  # Rationale (#097): master-table-to-SKILL.md structural drift is the failure
  # mode that 088.1's invocation-strict check_layer_a_delegation could not
  # detect (prose-level invocation presence passes even when the canonical
  # declaration section is missing).
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  # Stages that MUST carry canonical H2 + description-prefix (concrete delegate).
  local REQUIRE_CANONICAL=(ship-plan ship-execute ship-verify ship-review)
  # Stages that MAY use `Layer A exception` annotation instead (multi-mode).
  local ALLOW_EXCEPTION=(ship-shape)
  # Stages that are exempt entirely (master-table cell is "—").
  # Currently: ship (pure orchestration). Kept explicit for audit trail.
  local fail=0
  local sk has_h2 has_desc has_exception
  for sk in "${REQUIRE_CANONICAL[@]}"; do
    local skill_file="${skills_dir}/${sk}/SKILL.md"
    [ -f "$skill_file" ] || continue
    has_h2=$({ grep -cE "^## Layer A delegation" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    has_desc=$({ grep -cE '^description:.*Layer A delegation:' "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    if [ "${has_h2:-0}" = "0" ]; then
      echo "ERROR [layer-a-table-parity]: ${sk}/SKILL.md missing canonical \`## Layer A delegation (Principle 6 Rule B)\` H2 heading — INVARIANTS.md:157-168 master table declares a concrete Layer A delegate for this stage" >&2
      fail=1
    fi
    if [ "${has_desc:-0}" = "0" ]; then
      echo "ERROR [layer-a-table-parity]: ${sk}/SKILL.md frontmatter \`description:\` lacks \`Layer A delegation: ...\` prefix — required for structural parity with INVARIANTS.md:157-168 master table" >&2
      fail=1
    fi
  done
  for sk in "${ALLOW_EXCEPTION[@]}"; do
    local skill_file="${skills_dir}/${sk}/SKILL.md"
    [ -f "$skill_file" ] || continue
    has_h2=$({ grep -cE "^## Layer A delegation" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    has_exception=$({ grep -cE "Layer A exception" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    if [ "${has_h2:-0}" = "0" ] && [ "${has_exception:-0}" = "0" ]; then
      echo "ERROR [layer-a-table-parity]: ${sk}/SKILL.md is a multi-mode stage but has neither \`## Layer A delegation\` H2 nor a documented \`Layer A exception\` annotation — INVARIANTS.md:161-163 requires one form" >&2
      fail=1
    fi
  done
  return "$fail"
}


check_verdict_flip_whitelist() {
  # Verify ship/SKILL.md contains a verdict-flip block with:
  #   1. is_high_density or verdict.flip/verdict_flip reference
  #   2. WHITELIST with >=1 boolean predicate row (reason_* pattern)
  #   3. No enum-string gates (verdict_mode: ask|skip|auto anti-pattern)
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  local skill_file="${skills_dir}/ship/SKILL.md"
  [ -f "$skill_file" ] || { echo "ERROR [verdict-flip-whitelist]: ship/SKILL.md not found" >&2; return 1; }
  local fail=0

  # Check 1: verdict-flip/is_high_density present
  if ! grep -qE 'verdict.flip|verdict_flip|is_high_density' "$skill_file" 2>/dev/null; then
    echo "ERROR [verdict-flip-whitelist]: ship/SKILL.md missing verdict-flip block (no verdict-flip or is_high_density pattern)" >&2
    fail=1
  fi

  # Check 2: WHITELIST with >=1 boolean predicate row
  WHITELIST_ROWS=$({ awk '/^\*\*WHITELIST\*\*/,/^##/' "$skill_file" 2>/dev/null | { grep -E '^[[:space:]]*-[[:space:]]+.reason_[a-zA-Z0-9_]+' 2>/dev/null || true; } | wc -l | tr -d ' '; })
  if [ "${WHITELIST_ROWS:-0}" -lt 1 ]; then
    echo "ERROR [verdict-flip-whitelist]: ship/SKILL.md WHITELIST has 0 boolean predicate rows (need >= 1 reason_* row)" >&2
    fail=1
  fi

  # Check 3: no enum-string gates
  if grep -A50 'Verdict-flip transformation' "$skill_file" 2>/dev/null | grep -qE '(reason|verdict)[[:space:]]*[:=][[:space:]]*["'"'"']?(ask|skip|auto)'; then
    echo "ERROR [verdict-flip-whitelist]: ship/SKILL.md verdict-flip block contains enum-string gate (Principle 4 violation)" >&2
    fail=1
  fi

  return "$fail"
}

check_structural_parity_dc() {
  # Scan active entity .md files. For entities declaring type=ui or containing
  # ## Design Reference, verify at least one DC mentions structural parity.
  # Parity signals: structural|parity|column count|pill-stage--|prop-type|DOM structure
  #
  # Grandfather allowlist: pre-#048 entities that have ## Design Reference but predate
  # the structural-parity-dc invariant. These are skipped with SKIP log, not ERROR.
  local GRANDFATHER_STRUCTURAL_PARITY=(
    design-stage-integration
    pipeline-graph-visual-fix
    war-room-command-palette
  )
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0
  local f bn slug
  for f in "$docs_dir"/*.md; do
    [ -f "$f" ] || continue
    bn="$(basename "$f")"
    [ "$bn" = "README.md" ] && continue
    case "$f" in *_archive*|*_debriefs*|*_mods*) continue ;; esac
    # Check grandfather allowlist by basename without .md
    slug="${bn%.md}"
    local grandfathered=0
    for gf in "${GRANDFATHER_STRUCTURAL_PARITY[@]}"; do
      [ "$slug" = "$gf" ] && grandfathered=1 && break
    done
    if [ "$grandfathered" = "1" ]; then
      echo "SKIP [structural-parity-dc]: $bn — grandfathered pre-#048 (no structural-parity DC required)" >&2
      continue
    fi
    # Trigger condition: type: ui in frontmatter OR ## Design Reference in body
    local is_ui=0
    if grep -qE "^type:[[:space:]]*ui" "$f" 2>/dev/null; then
      is_ui=1
    elif grep -qF "## Design Reference" "$f" 2>/dev/null; then
      is_ui=1
    fi
    [ "$is_ui" = "0" ] && continue
    # Check for structural parity DC signal
    local has_parity
    has_parity=$({ grep -ciE "structural|parity|column count|pill-stage--|prop-type|DOM structure" "$f" 2>/dev/null || true; } | tr -d ' ')
    if [ "${has_parity:-0}" = "0" ]; then
      echo "ERROR [structural-parity-dc]: $bn is ui-type/has Design Reference but no structural-parity DC signal (add column-count/class-presence/prop-type check). See INVARIANTS.md §UI-entity grep-DCs" >&2
      fail=1
    fi
  done
  return "$fail"
}

check_pitch_assumptions() {
  # DC-10 — Phase 1 (ship-flow distillation): entities with pattern=pitch
  # must have >=1 assumption with criticality=critical. Warning-only in
  # Phase 1; promoted to blocking in Phase 2 when shape skill requires.
  local warn_count=0
  if ! command -v yq >/dev/null 2>&1; then
    echo "WARN [Principle 5c]: yq not installed — skipping pitch-assumption check" >&2
    return 0
  fi
  local entity
  # Iterate all workflow-entity .md files under $ROOT/docs/*/*.md, skipping known non-entities
  for entity in "$ROOT"/docs/*/*.md; do
    [ -f "$entity" ] || continue
    local bn
    bn="$(basename "$entity")"
    case "$bn" in
      README.md|ROADMAP.md|PRODUCT.md|ARCHITECTURE.md|INVARIANTS.md) continue ;;
    esac
    case "$entity" in
      */_archive/*|*/_debriefs/*|*/_mods/*) continue ;;
    esac
    # Extract frontmatter (first --- block)
    local fm
    fm="$(mktemp)"
    awk '/^---$/{c++; if(c==2){exit}; next} c==1{print}' "$entity" > "$fm"
    local pattern
    pattern="$({ yq '.pattern // "single"' "$fm" 2>/dev/null || echo single; } | tr -d '"' | head -1)"
    if [ "$pattern" = "pitch" ]; then
      local critical_count
      critical_count="$({ yq '[.stated_assumptions[]? | select(.criticality == "critical")] | length' "$fm" 2>/dev/null || echo 0; } | head -1)"
      if [ -z "$critical_count" ] || [ "$critical_count" = "null" ]; then
        critical_count=0
      fi
      if [ "$critical_count" = "0" ]; then
        echo "WARN [Principle 5c]: $entity pattern=pitch but has 0 critical assumptions. See plugins/ship-flow/INVARIANTS.md#principle-5" >&2
        warn_count=$((warn_count + 1))
      fi
    fi
    rm -f "$fm"
  done
  if [ "$warn_count" = "0" ]; then
    echo "OK DC-10 pitch-assumption invariant (0 warnings)"
  else
    echo "OK DC-10 pitch-assumption invariant ($warn_count warnings — non-blocking in Phase 1)"
  fi
  return 0
}

check_workflow_dir_portability() {
  # DC-1.4 (T1.4): Operational instructions in stage SKILLs must not hard-code
  # "docs/ship-flow/" as a literal path — they must use $WORKFLOW_DIR or
  # relative resolution from README frontmatter.
  # Exceptions: References sections (after "## References"), comments,
  # example blocks (inside ``` fenced code showing path *templates*).
  local skill_dir="${ROOT}/plugins/ship-flow/skills"
  local fail=0
  # Pattern: operational mention of docs/ship-flow/ NOT in a References section
  # Strategy: flag lines containing literal "docs/ship-flow/" that are NOT
  # inside fenced code blocks showing templates AND NOT in ## References sections.
  # Simplified heuristic: grep for operational uses (Resolve, Read, bash, git add)
  # that also contain "docs/ship-flow/" without $WORKFLOW_DIR nearby.
  local operational_pattern='(bash|Resolve|git add|git commit|write-stage-artifact|extract-section|patch-map|density-classify).*docs/ship-flow/'
  local violations=0
  for skill_file in "${skill_dir}"/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    # Exclude lines inside ## References section and fenced code blocks showing template paths
    local matches
    matches=$(grep -nE "$operational_pattern" "$skill_file" 2>/dev/null || true)
    [ -z "$matches" ] && continue
    matches=$(echo "$matches" | \
      grep -v "# template\|<entity>\|<id>-<slug>\|<slug[0-9]*>\|<NNN>\|\.\.\." || true)
    [ -z "$matches" ] && continue
    # shellcheck disable=SC2016  # intentional literal-$WORKFLOW_DIR match (do not expand)
    matches=$(echo "$matches" | grep -v '\$WORKFLOW_DIR' || true)
    [ -z "$matches" ] && continue
    local match_count
    match_count=$(echo "$matches" | wc -l | tr -d ' ')
    if [ "$match_count" -gt 0 ]; then
      echo "WARN [DC-1.4 workflow-dir-portability]: $skill_file has $match_count operational hard-coded 'docs/ship-flow/' path(s) — use \$WORKFLOW_DIR" >&2
      violations=$((violations + 1))
    fi
  done
  if [ "$violations" -gt 0 ]; then
    echo "FAIL DC-1.4 workflow-dir-portability ($violations skill files with hard-coded paths)"
    return 1
  fi
  echo "OK DC-1.4 workflow-dir-portability (0 violations)"
  return 0
}

check_ask_fallback_coverage() {
  # DC-3.3 (T3.3): Every stage SKILL must contain SendMessage(FO) ask-fallback
  # in its Boot Self-Check section — so missing context triggers FO escalation
  # rather than silent guessing (WORKFLOW_DIR unset, unknown framework, etc.).
  local skill_dir="${ROOT}/plugins/ship-flow/skills"
  local stage_skills=("ship-shape" "ship-plan" "ship-execute" "ship-verify" "ship-review" "ship-design")
  local fail=0
  for skill in "${stage_skills[@]}"; do
    local skill_file="${skill_dir}/${skill}/SKILL.md"
    [ -f "$skill_file" ] || { echo "WARN [DC-3.3 ask-fallback]: $skill_file not found" >&2; fail=1; continue; }
    if ! grep -qE 'SendMessage.*FO|SendMessage\(FO\)' "$skill_file" 2>/dev/null; then
      echo "FAIL [DC-3.3 ask-fallback]: $skill_file missing SendMessage(FO) ask-fallback pattern" >&2
      fail=1
    fi
  done
  if [ "$fail" -gt 0 ]; then
    echo "FAIL DC-3.3 ask-fallback-coverage"
    return 1
  fi
  echo "OK DC-3.3 ask-fallback-coverage (all ${#stage_skills[@]} stage SKILLs have SendMessage(FO))"
  return 0
}

check_reverse_audit_prompts() {
  # DC-3.2 (#106 T3.2 + review-stage Fix 2 Path A): Every applicable stage SKILL
  # MUST contain a "Reverse-audit prompt template" section so cross-review
  # reverse-audit (factor 6) has concrete prior-stage section names to audit.
  # Threshold: ≥4 of 5 applicable stage SKILLs (ship-design exempt — no upstream
  # stage to reverse-audit; ship-shape exempt — first stage in pipeline).
  local skill_dir="${ROOT}/plugins/ship-flow/skills"
  local applicable_skills=("ship-plan" "ship-execute" "ship-verify" "ship-review" "ship-design")
  local hits=0
  local missing=()
  for skill in "${applicable_skills[@]}"; do
    local skill_file="${skill_dir}/${skill}/SKILL.md"
    [ -f "$skill_file" ] || { missing+=("${skill} (file absent)"); continue; }
    if grep -qiE 'Reverse-audit prompt template' "$skill_file" 2>/dev/null; then
      hits=$((hits + 1))
    else
      missing+=("${skill}")
    fi
  done
  if [ "$hits" -lt 4 ]; then
    echo "FAIL DC-3.2 reverse-audit-prompts: $hits of ${#applicable_skills[@]} stage SKILLs have prompt templates (≥4 required)"
    [ ${#missing[@]} -gt 0 ] && echo "  Missing: ${missing[*]}" >&2
    return 1
  fi
  echo "OK DC-3.2 reverse-audit-prompts ($hits of ${#applicable_skills[@]} stage SKILLs have Reverse-audit prompt template)"
  return 0
}

# ---- C1-C5: 2026-04-29 tooling bundle (PR #43 + #44 mechanical enforcement) ----

# Helper: locate the entity index file (folder layout: <dir>/README.md; flat: <dir>.md)
_entity_index_for_dir() {
  local d="$1"
  if [ -f "${d%/}/README.md" ]; then echo "${d%/}/README.md"
  elif [ -f "${d%/}.md" ]; then echo "${d%/}.md"
  else echo ""
  fi
}

# Helper: directive non-trivial — title ≥80 chars OR not in escape-hatch keyword list
_directive_non_trivial() {
  local f="$1"
  local title
  title=$(grep -m1 '^title:' "$f" 2>/dev/null | sed -E 's/^title:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/')
  [ -z "$title" ] && return 0  # no title → assume non-trivial (better safe)
  if [ "${#title}" -ge 80 ]; then return 0; fi
  # title <80 chars — escape-hatch if matches keyword
  if echo "$title" | grep -qiE '\b(fix|typo|rename|bump|patch|bugfix|hotfix)\b'; then
    return 1  # trivial (escape hatch)
  fi
  return 0
}

check_pre_mortem_emitted() {
  # C1 — PR #43: every non-trivial pitch must emit pre_mortem field in frontmatter.
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 f
  for f in "$docs_dir"/*.md "$docs_dir"/*/README.md; do
    [ -f "$f" ] || continue
    grep -qE '^pattern:[[:space:]]*pitch' "$f" || continue
    _directive_non_trivial "$f" || continue
    if ! grep -qE '^pre_mortem:' "$f"; then
      echo "FAIL C1 pre-mortem-emitted: '$(basename "$(dirname "$f")")' (or $(basename "$f")) missing pre_mortem field. See ship-shape/SKILL.md ### Pre-mortem (mandatory on non-trivial pitch)." >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C1 pre-mortem-emitted"
  return "$fail"
}

check_pol_probe_invoked() {
  # C2 — PR #44: every medium-batch | big-batch pitch must invoke pol-probe-advisor.
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 f
  for f in "$docs_dir"/*.md "$docs_dir"/*/spec.md "$docs_dir"/*/README.md; do
    [ -f "$f" ] || continue
    grep -qE '^appetite:[[:space:]]*(medium-batch|big-batch)' "$f" || continue
    if ! grep -qE 'pol-probe-advisor' "$f"; then
      echo "FAIL C2 pol-probe-invoked: '$(basename "$f")' (medium/big-batch) missing pol-probe-advisor invocation. See ship-shape/SKILL.md PM-Skill Framing — pol-probe-advisor MANDATORY for medium-batch | big-batch (pitch-103 critical-assumption misfilter precedent)." >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C2 pol-probe-invoked"
  return "$fail"
}

check_no_design_constraints_dual_write() {
  # C3 — PR #44 G8 dedup: design.md must NOT have retired '### Constraints for Plan Stage'.
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 f
  for f in "$docs_dir"/*/design.md; do
    [ -f "$f" ] || continue
    if grep -qE '^### Constraints for Plan Stage' "$f"; then
      echo "FAIL C3 no-design-constraints-dual-write: '$(basename "$(dirname "$f")")/design.md' has retired '### Constraints for Plan Stage' (G8 dedup). Run lib/migrate-design-constraints.sh '$f'." >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C3 no-design-constraints-dual-write"
  return "$fail"
}

check_plan_imported_design_dcs_emitted() {
  # C4 — PR #44 G10: when affects_ui=true + hand-off non-skipped, plan.md must have ## Plan Imported Design DCs.
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 d plan readme
  for d in "$docs_dir"/*/; do
    plan="${d}plan.md"
    [ -f "$plan" ] || continue
    readme=$(_entity_index_for_dir "$d")
    [ -n "$readme" ] || continue
    grep -qE '^affects_ui:[[:space:]]*true' "$readme" || continue
    grep -qE '^### Hand-off to Plan' "$readme" || continue
    grep -qE '^[[:space:]]*-?[[:space:]]*design-skipped:[[:space:]]*true' "$readme" && continue
    if ! grep -qE '^## Plan Imported Design DCs' "$plan"; then
      echo "FAIL C4 plan-imported-design-dcs-emitted: '$(basename "$d")plan.md' missing '## Plan Imported Design DCs' (affects_ui=true + design hand-off non-skipped). See ship-plan/SKILL.md ### Step 1.6." >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C4 plan-imported-design-dcs-emitted"
  return "$fail"
}

check_verify_mechanical_ui_parity_emitted() {
  # C5 — PR #44 Step 3.6: when affects_ui=true + render_fidelity_targets non-empty, verify.md must have #### Mechanical UI Parity.
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 d verify readme
  for d in "$docs_dir"/*/; do
    verify="${d}verify.md"
    [ -f "$verify" ] || continue
    readme=$(_entity_index_for_dir "$d")
    [ -n "$readme" ] || continue
    grep -qE '^affects_ui:[[:space:]]*true' "$readme" || continue
    grep -qE '^[[:space:]]*-?[[:space:]]*design-skipped:[[:space:]]*true' "$readme" && continue
    grep -qE 'render_fidelity_targets:|^[[:space:]]*-[[:space:]]+selector:' "$readme" || continue
    if ! grep -qE '^#### Mechanical UI Parity' "$verify"; then
      echo "FAIL C5 verify-mechanical-ui-parity-emitted: '$(basename "$d")verify.md' missing '#### Mechanical UI Parity' (affects_ui=true + render_fidelity_targets present). See ship-verify/SKILL.md ## Step 3.6." >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C5 verify-mechanical-ui-parity-emitted"
  return "$fail"
}

check_will_get_triple() {
  # C6 — entity 109: every Will-get W<n> bullet in spec.md must have a matching
  # W<n> dogfood-check line in Layer 2 ### Will-get dogfood checks.
  # Skip silently if spec.md has no ## Layer 1 header (pre-109 entities).
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 f entity wn
  for f in "$docs_dir"/*/spec.md; do
    [ -f "$f" ] || continue
    # Skip silently if no Layer 1 section (pre-109 format)
    grep -qE '^## Layer 1' "$f" || continue
    entity="$(basename "$(dirname "$f")")"
    # Extract W<n> ids from ### Will get section (between ## Layer 1 and ## Layer 2 or EOF)
    local layer1
    layer1="$(awk '/^## Layer 1/,/^## Layer 2/' "$f" 2>/dev/null || true)"
    local wids
    wids="$(echo "$layer1" | grep -oE '\*\*W[0-9]+\*\*:' | grep -oE 'W[0-9]+')" || true
    [ -z "$wids" ] && continue
    # Extract dogfood-check section content (skip header line; stop at next ### or ##)
    local checks
    checks="$(awk 'found && /^(##|---)/ {exit} /^### Will-get dogfood checks/ {found=1; next} found' "$f" 2>/dev/null || true)"
    for wn in $wids; do
      if ! echo "$checks" | grep -qE "\*\*${wn}\*\*:"; then
        echo "FAIL C6 will-get-triple: '$entity' ${wn} has no matching dogfood check in '### Will-get dogfood checks'. See ship-shape/SKILL.md Layer 1 discipline rule 1." >&2
        fail=1
      fi
    done
  done
  [ "$fail" = "0" ] && echo "OK C6 will-get-triple"
  return "$fail"
}

check_no_rubric_token() {
  # C7 — entity 109: Layer 1 section of spec.md MUST NOT contain rubric/7-factor/score tokens.
  # Skip silently if spec.md has no ## Layer 1 header (pre-109 entities).
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 f entity layer1
  for f in "$docs_dir"/*/spec.md; do
    [ -f "$f" ] || continue
    # Skip silently if no Layer 1 section (pre-109 format)
    grep -qE '^## Layer 1' "$f" || continue
    entity="$(basename "$(dirname "$f")")"
    # Extract Layer 1 content (between ## Layer 1 and ## Layer 2 or EOF)
    layer1="$(awk '/^## Layer 1/,/^## Layer 2/' "$f" 2>/dev/null || true)"
    if echo "$layer1" | grep -iqE '\brubric\b|\b7-factor\b|\bscore\b'; then
      echo "FAIL C7 no-rubric-token: '$entity' Layer 1 contains rubric/7-factor/score token. See ship-shape/SKILL.md Layer 1 discipline rule 3." >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C7 no-rubric-token"
  return "$fail"
}

_check_context_manifest_section_completeness() {
  # Sub-function: verify all 6 Context Manifest fields are present and non-empty.
  # Called from check_context_manifest_emitted after section presence is confirmed.
  # Returns 0 if all fields non-empty, 1 if any field missing or empty.
  local f="$1" label="$2" fail=0
  for field in "Skills loaded" "INVARIANTS sections read" "Architecture docs consulted" "Domains touched" "Lens dispatched" "Lens findings integrated"; do
    if ! grep -qE "\*\*${field}\*\*:[[:space:]]*\S" "$f"; then
      echo "WARN C8 context-manifest-completeness: '$label' manifest field '$field' missing or empty." >&2
      fail=1
    fi
  done
  return "$fail"
}

check_context_manifest_emitted() {
  # C8 — entity 110: every non-blocked plan.md MUST contain ## Context Manifest section.
  # Skip plan.md files with status: blocked (blocked plans legitimately skip manifest).
  # Grace filter: skip plan.md files whose started: field predates 2026-04-29 (pre-110 plans).
  # Fixture override: if FIXTURE_PLAN set, check only that single file (for DC-6/DC-7 tests).
  if [ -n "${FIXTURE_PLAN:-}" ]; then
    local f="$FIXTURE_PLAN"
    if grep -qE '^## Plan Report' "$f" && grep -qE 'status:[[:space:]]*blocked' "$f"; then
      echo "OK C8 context-manifest-emitted (blocked plan skipped)"
      return 0
    fi
    if ! grep -qE '^## Context Manifest' "$f"; then
      echo "FAIL C8 context-manifest-emitted: '$(basename "$f")' missing ## Context Manifest section. See ship-plan/SKILL.md Step 6." >&2
      return 1
    fi
    _check_context_manifest_section_completeness "$f" "$(basename "$f")" || true
    echo "OK C8 context-manifest-emitted"
    return 0
  fi
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 f entity
  for f in "$docs_dir"/*/plan.md; do
    [ -f "$f" ] || continue
    entity="$(basename "$(dirname "$f")")"
    # Grace filter: skip pre-110 plans (no started: field or started before 2026-04-29)
    local started
    started="$(grep -m1 'started[*]*:' "$f" 2>/dev/null | sed 's/.*started[^:]*:[[:space:]]*//' || true)"
    if [ -z "$started" ] || [[ "$started" < "2026-04-29" ]]; then
      continue
    fi
    # Skip blocked plans
    if grep -qE 'status:[[:space:]]*blocked' "$f"; then
      continue
    fi
    if ! grep -qE '^## Context Manifest' "$f"; then
      echo "FAIL C8 context-manifest-emitted: '$entity/plan.md' missing ## Context Manifest section. See ship-plan/SKILL.md Step 6." >&2
      fail=1
    else
      _check_context_manifest_section_completeness "$f" "$entity/plan.md" || true
    fi
  done
  [ "$fail" = "0" ] && echo "OK C8 context-manifest-emitted"
  return "$fail"
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
    pitch-assumptions) check_pitch_assumptions; exit $? ;;
    stage-artifact-path) check_stage_artifact_path; exit $? ;;
    layer-a-delegation) check_layer_a_delegation; exit $? ;;
    team-fallback-documented) check_team_fallback_documented; exit $? ;;
    cross-review-gate) check_cross_review_gate; exit $? ;;
    layer-a-table-parity) check_layer_a_table_parity; exit $? ;;
    structural-parity-dc) check_structural_parity_dc; exit $? ;;
    verdict-flip-whitelist) check_verdict_flip_whitelist; exit $? ;;
    workflow-dir-portability) check_workflow_dir_portability; exit $? ;;
    ask-fallback-coverage) check_ask_fallback_coverage; exit $? ;;
    reverse-audit-prompts) check_reverse_audit_prompts; exit $? ;;
    pre-mortem-emitted) check_pre_mortem_emitted; exit $? ;;
    pol-probe-invoked) check_pol_probe_invoked; exit $? ;;
    no-design-constraints-dual-write) check_no_design_constraints_dual_write; exit $? ;;
    plan-imported-design-dcs-emitted) check_plan_imported_design_dcs_emitted; exit $? ;;
    verify-mechanical-ui-parity-emitted) check_verify_mechanical_ui_parity_emitted; exit $? ;;
    will-get-triple) check_will_get_triple; exit $? ;;
    no-rubric-token) check_no_rubric_token; exit $? ;;
    context-manifest-emitted) check_context_manifest_emitted; exit $? ;;
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

# Full run — all checks
check_skill_count || FAIL=1
check_preamble_regrowth || FAIL=1
check_section_tag_coverage || FAIL=1
check_flow_map_coverage || FAIL=1
check_direct_read_static || FAIL=1
check_fan_out_reviewer || FAIL=1
check_boolean_gate || FAIL=1
check_rid_placeholder || FAIL=1
check_pitch_assumptions || FAIL=1
check_stage_artifact_path || FAIL=1
check_layer_a_delegation || FAIL=1
check_team_fallback_documented || FAIL=1
check_cross_review_gate || FAIL=1
check_layer_a_table_parity || FAIL=1
check_structural_parity_dc || FAIL=1
check_workflow_dir_portability || FAIL=1
check_ask_fallback_coverage || FAIL=1
# C1-C5: PR #43 + PR #44 mechanical enforcement (2026-04-29)
check_pre_mortem_emitted || FAIL=1
check_pol_probe_invoked || FAIL=1
check_no_design_constraints_dual_write || FAIL=1
check_plan_imported_design_dcs_emitted || FAIL=1
check_verify_mechanical_ui_parity_emitted || FAIL=1
# C6-C7: entity 109 outcome-card layer enforcement (2026-04-29)
check_will_get_triple || FAIL=1
check_no_rubric_token || FAIL=1
# C8: entity 110 context manifest enforcement (2026-04-29)
check_context_manifest_emitted || FAIL=1

exit $FAIL
