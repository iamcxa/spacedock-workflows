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

_entity_is_terminal() {
  local f="$1"
  grep -qE '^(status:[[:space:]]*(done|ship|shipped)|completed:|shipped:|verdict:[[:space:]]*PASSED)' "$f" 2>/dev/null
}

# ---- Check functions (stubs in T3; bodies filled in T6/T7/T8) ----

check_skill_count() {
  # DC-6 — Principle 2: stage skill count ≤ 7; utility skills uncapped.
  # Explicit allowlists — catches unclassified additions immediately.
  local STAGE_SKILLS=(ship-shape ship-design ship ship-plan ship-execute ship-verify ship-review)
  local UTILITY_SKILLS=(add-todos ship-onboard ship-runtime-detect domain-registry ui-verify test-driven-development verify-reviewer-panel doc-sync distill-reference codex-gate harvest-decide memory-cleanup ship-epic ship-project science-officer-em)
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
  local f bn label has_tags
  for f in "$docs_dir"/*.md "$docs_dir"/*/index.md; do
    [ -f "$f" ] || continue
    bn="$(basename "$f")"
    label="$bn"
    [ "$bn" = "index.md" ] && label="$(basename "$(dirname "$f")")/index.md"
    [ "$bn" = "README.md" ] && continue
    case "$f" in *_archive*) continue ;; esac
    if _entity_is_terminal "$f"; then
      echo "SKIP [Principle 5a]: $label — terminal historical entity; section-tag coverage checked on active entities" >&2
      continue
    fi
    # Grandfather: skip entities with zero section tags (pre-049 baseline).
    has_tags=$(grep -c '^<!-- section:[a-z]' "$f" 2>/dev/null) || has_tags=0
    if [ "$has_tags" = "0" ]; then
      echo "WARN [Principle 5a]: $label — pre-049 baseline (no section tags; grandfather skip). Add tags on next edit." >&2
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
  # Mapping: ship-shape→shape.md, ship-plan→plan.md, ship-execute→execute.md,
  #          ship-verify→verify.md, ship-review→review.md, ship→ship.md
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local fail=0
  declare -A ARTIFACT_MAP
  ARTIFACT_MAP=(
    [ship-shape]=shape.md
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
  # the INVARIANTS.md § "Layer A delegation table" carries BOTH:
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
      echo "ERROR [layer-a-table-parity]: ${sk}/SKILL.md missing canonical \`## Layer A delegation (Principle 6 Rule B)\` H2 heading — the INVARIANTS.md § \"Layer A delegation table\" declares a concrete Layer A delegate for this stage" >&2
      fail=1
    fi
    if [ "${has_desc:-0}" = "0" ]; then
      echo "ERROR [layer-a-table-parity]: ${sk}/SKILL.md frontmatter \`description:\` lacks \`Layer A delegation: ...\` prefix — required for structural parity with the INVARIANTS.md § \"Layer A delegation table\"" >&2
      fail=1
    fi
  done
  for sk in "${ALLOW_EXCEPTION[@]}"; do
    local skill_file="${skills_dir}/${sk}/SKILL.md"
    [ -f "$skill_file" ] || continue
    has_h2=$({ grep -cE "^## Layer A delegation" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    has_exception=$({ grep -cE "Layer A exception" "$skill_file" 2>/dev/null || true; } | tr -d ' ')
    if [ "${has_h2:-0}" = "0" ] && [ "${has_exception:-0}" = "0" ]; then
      echo "ERROR [layer-a-table-parity]: ${sk}/SKILL.md is a multi-mode stage but has neither \`## Layer A delegation\` H2 nor a documented \`Layer A exception\` annotation — INVARIANTS.md § \"Rule B (3-Layer Skill Architecture)\" EXCEPTION clause requires one form" >&2
      fail=1
    fi
  done
  return "$fail"
}


check_pm_skill_receipts() {
  # Named-only guard for post-107 shape receipt artifacts. Historical shapes did
  # not emit this block, so the default invariant suite does not call this check.
  local docs_dir="${ROOT}/docs/ship-flow"
  local validator="${ROOT}/plugins/ship-flow/lib/validate-pm-skill-receipts.sh"
  [ -d "$docs_dir" ] || return 0
  if [ ! -f "$validator" ]; then
    echo "ERROR [pm-skill-receipts]: validator not found at $validator" >&2
    return 1
  fi

  local fail=0
  local f
  for f in "$docs_dir"/*/shape.md "$docs_dir"/*.md; do
    [ -f "$f" ] || continue
    case "$f" in *_archive*|*_debriefs*|*_mods*) continue ;; esac
    if grep -q '^<!-- section:pm-skill-receipts -->$' "$f" 2>/dev/null; then
      bash "$validator" "$f" >/dev/null || {
        echo "ERROR [pm-skill-receipts]: invalid receipt artifact: ${f#"$ROOT"/}" >&2
        fail=1
      }
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
  local f bn slug label
  for f in "$docs_dir"/*.md "$docs_dir"/*/index.md; do
    [ -f "$f" ] || continue
    bn="$(basename "$f")"
    label="$bn"
    [ "$bn" = "index.md" ] && label="$(basename "$(dirname "$f")")/index.md"
    [ "$bn" = "README.md" ] && continue
    case "$f" in *_archive*|*_debriefs*|*_mods*) continue ;; esac
    _entity_is_terminal "$f" && continue
    # Check grandfather allowlist by basename without .md
    if [ "$bn" = "index.md" ]; then
      slug="$(basename "$(dirname "$f")")"
    else
      slug="${bn%.md}"
    fi
    local grandfathered=0
    for gf in "${GRANDFATHER_STRUCTURAL_PARITY[@]}"; do
      [ "$slug" = "$gf" ] && grandfathered=1 && break
    done
    if [ "$grandfathered" = "1" ]; then
      echo "SKIP [structural-parity-dc]: $label — grandfathered pre-#048 (no structural-parity DC required)" >&2
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
      echo "ERROR [structural-parity-dc]: $label is ui-type/has Design Reference but no structural-parity DC signal (add column-count/class-presence/prop-type check). See INVARIANTS.md §UI-entity grep-DCs" >&2
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
  for entity in "$ROOT"/docs/*/*.md "$ROOT"/docs/*/*/index.md; do
    [ -f "$entity" ] || continue
    local bn
    bn="$(basename "$entity")"
    case "$bn" in
      README.md|ROADMAP.md|PRODUCT.md|ARCHITECTURE.md|INVARIANTS.md) continue ;;
    esac
    case "$entity" in
      */_archive/*|*/_debriefs/*|*/_mods/*) continue ;;
    esac
    _entity_is_terminal "$entity" && continue
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

# Helper: locate the entity index file (folder layout: <dir>/index.md; flat: <dir>.md)
_entity_index_for_dir() {
  local d="$1"
  if [ -f "${d%/}/index.md" ]; then echo "${d%/}/index.md"
  elif [ -f "${d%/}.md" ]; then echo "${d%/}.md"
  else echo ""
  fi
}

_handoff_source_for_dir() {
  local d="$1"
  if [ -f "${d%/}/design.md" ]; then echo "${d%/}/design.md"
  else _entity_index_for_dir "$d"
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
  for f in "$docs_dir"/*.md "$docs_dir"/*/index.md; do
    [ -f "$f" ] || continue
    grep -qE '^pattern:[[:space:]]*pitch' "$f" || continue
    _entity_is_terminal "$f" && continue
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
  for f in "$docs_dir"/*.md "$docs_dir"/*/shape.md "$docs_dir"/*/index.md; do
    [ -f "$f" ] || continue
    grep -qE '^appetite:[[:space:]]*(medium-batch|big-batch)' "$f" || continue
    _entity_is_terminal "$f" && continue
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
  # C4 — PR #44 G10 + Step 1.6 trigger expansion + 2026-05-24 handoff integrity:
  # when entity is design-bearing (affects_ui=true OR domain set OR
  # design_required=true OR contract_decision_required=true), the handoff block
  # must exist at canonical level (### Hand-off to Plan), and either be marked
  # design-skipped or have a matching ## Plan Imported Design DCs section in
  # plan.md.
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 d plan entity handoff handoff_name
  local scan_dirs=("$docs_dir"/*/)
  if [ -n "$FIXTURE" ]; then
    scan_dirs+=("$docs_dir"/_archive/*/)
  fi
  for d in "${scan_dirs[@]}"; do
    [ -d "$d" ] || continue
    plan="${d}plan.md"
    [ -f "$plan" ] || continue
    entity=$(_entity_index_for_dir "$d")
    [ -n "$entity" ] || continue
    # Trigger: any design-bearing signal (ship-plan SKILL.md Step 1.6).
    # Domain regex accepts unquoted (a-z), double-quoted ("x..."), and
    # single-quoted ('x...') YAML — empty quoted form ("" / '') is rejected
    # so it stays semantically equivalent to unset.
    if ! grep -qE '^affects_ui:[[:space:]]*true' "$entity" \
      && ! grep -qE "^domain:[[:space:]]*([a-zA-Z]|\"[^\"]|'[^'])" "$entity" \
      && ! grep -qE '^design_required:[[:space:]]*true' "$entity" \
      && ! grep -qE '^contract_decision_required:[[:space:]]*true' "$entity"; then
      continue
    fi
    handoff=$(_handoff_source_for_dir "$d")
    [ -n "$handoff" ] || continue
    handoff_name="$(basename "$d")$(basename "$handoff")"
    # Handoff integrity: must have '### Hand-off to Plan' at canonical H3.
    if ! grep -qE '^### Hand-off to Plan' "$handoff"; then
      if grep -qE '^(## |# )Hand-off to Plan' "$handoff"; then
        echo "FAIL C4 plan-imported-design-dcs-emitted: '$handoff_name' has 'Hand-off to Plan' at wrong header level (canonical is '### Hand-off to Plan' — H3). Design-bearing entity. See ship-plan/SKILL.md ### Step 1.6." >&2
      else
        echo "FAIL C4 plan-imported-design-dcs-emitted: '$handoff_name' has no '### Hand-off to Plan' block, but entity is design-bearing. Emit the block (with design-skipped: true if intentionally bypassed). See ship-plan/SKILL.md ### Step 1.6." >&2
      fi
      fail=1
      continue
    fi
    if grep -qE '^[[:space:]]*-?[[:space:]]*design-skipped:[[:space:]]*true' "$handoff"; then
      if grep -qE '^[[:space:]]*-?[[:space:]]*captain-approved-design-bypass:[[:space:]]*true' "$handoff"; then
        continue
      fi
      echo "FAIL C4 plan-imported-design-dcs-emitted: '$handoff_name' has 'design-skipped: true' without 'captain-approved-design-bypass: true', but entity is design-bearing. See ship-plan/SKILL.md ### Step 1.6." >&2
      fail=1
      continue
    fi
    if ! grep -qE '^## Plan Imported Design DCs' "$plan"; then
      echo "FAIL C4 plan-imported-design-dcs-emitted: '$(basename "$d")plan.md' missing '## Plan Imported Design DCs' (design-bearing entity + hand-off non-skipped). See ship-plan/SKILL.md ### Step 1.6." >&2
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
  local fail=0 d verify entity handoff
  for d in "$docs_dir"/*/; do
    verify="${d}verify.md"
    [ -f "$verify" ] || continue
    entity=$(_entity_index_for_dir "$d")
    [ -n "$entity" ] || continue
    handoff=$(_handoff_source_for_dir "$d")
    [ -n "$handoff" ] || continue
    grep -qE '^affects_ui:[[:space:]]*true' "$entity" || continue
    grep -qE '^[[:space:]]*-?[[:space:]]*design-skipped:[[:space:]]*true' "$handoff" && continue
    grep -qE 'render_fidelity_targets:|^[[:space:]]*-[[:space:]]+selector:' "$handoff" || continue
    if ! grep -qE '^#### Mechanical UI Parity' "$verify"; then
      echo "FAIL C5 verify-mechanical-ui-parity-emitted: '$(basename "$d")verify.md' missing '#### Mechanical UI Parity' (affects_ui=true + render_fidelity_targets present). See ship-verify/SKILL.md ## Step 3.6." >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C5 verify-mechanical-ui-parity-emitted"
  return "$fail"
}

check_will_get_triple() {
  # C6 — entity 109: every Will-get W<n> bullet in shape.md must have a matching
  # W<n> dogfood-check line in Layer 2 ### Will-get dogfood checks.
  # Skip silently if shape.md has no ## Layer 1 header (pre-109 entities).
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 f entity wn
  for f in "$docs_dir"/*/shape.md; do
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
  # C7 — entity 109: Layer 1 section of shape.md MUST NOT contain rubric/7-factor/score tokens.
  # Skip silently if shape.md has no ## Layer 1 header (pre-109 entities).
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || return 0
  local fail=0 f entity layer1
  for f in "$docs_dir"/*/shape.md; do
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

check_principle_numbering() {
  # C9 — INVARIANTS.md: every `^### Principle N:` heading must use a unique N.
  # Pitch-113.2 incident: T3.1 added "Principle 7: Domain Registry" while file
  # already had "Principle 7: Metadata-driven portability" — duplicate-N silently
  # passed because no grep-DC asserted uniqueness. Verifier-side strengthen +
  # this assertion prevents recurrence. Fixture override: FIXTURE_INVARIANTS=path.
  local invariants_file="${FIXTURE_INVARIANTS:-${ROOT}/plugins/ship-flow/INVARIANTS.md}"
  [ -f "$invariants_file" ] || return 0
  local dups
  dups="$(grep -oE '^### Principle [0-9]+:' "$invariants_file" \
    | awk '{print $3}' | tr -d ':' | sort | uniq -d)"
  if [ -n "$dups" ]; then
    local n
    while IFS= read -r n; do
      echo "ERROR [Principle 5/numbering]: INVARIANTS.md has duplicate '### Principle $n:' headings. See plugins/ship-flow/INVARIANTS.md — each Principle N must use a unique N." >&2
    done <<< "$dups"
    return 1
  fi
  echo "OK C9 principle-numbering"
  return 0
}

# ---- C10-C13: 2026-05-13 Phase 1/2B/3A merge enforcement ----
# Elevates Hermetic Dependency Policy + Multi-Specialist Panel + FO Receipt
# contracts from stage-SKILL-internal invariants to plugin-level CI checks.

# Helper: read `started:` from entity index.md (folder layout) or flat <slug>.md.
# Echoes the started value (cut to YYYY-MM-DD) or empty when no field is present.
# Used by C11/C12/C13 grace filter.
_entity_started_date() {
  local entity_dir="$1"
  local idx line
  idx=$(_entity_index_for_dir "$entity_dir")
  if [ -z "$idx" ] || [ ! -f "$idx" ]; then
    echo ""
    return 0
  fi
  # grep returning 1 (no match) is normal — pre-2026-05-13 entities often lack
  # started:. `|| true` keeps set -euo pipefail from aborting the caller.
  line=$({ grep -m1 '^started:' "$idx" 2>/dev/null || true; })
  [ -z "$line" ] && { echo ""; return 0; }
  echo "$line" | sed -E 's/^started:[[:space:]]*"?([^"]*)"?[[:space:]]*$/\1/' | cut -c1-10
}

check_hermetic_no_gstack() {
  # C10 — Principle 12: stage SKILLs + lib/*.sh must not reference
  # `~/.claude/skills/gstack/`, `~/.agents/skills/gstack/`, `$D`, `$B`,
  # generic gstack-* runtime binaries, or gstack-owned persistence filenames
  # as RUNTIME paths. Lines containing policy-negation tokens (DO NOT, MUST NOT,
  # NEVER, forbidden, reference-only) are filtered out — those are prose that
  # documents the forbidden boundary, not runtime invocation.
  #
  # WARN-level v1 (additive, non-breaking). Future hardening: tighten to FAIL
  # once SKILL.md documentation references settle (TODO: re-evaluate 2026-06-01).
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  local lib_dir="${ROOT}/plugins/ship-flow/lib"
  [ -d "$skills_dir" ] || { echo "OK C10 hermetic-no-gstack (skills dir absent — skip)"; return 0; }

  # Forbidden patterns:
  #   1. ~/.claude/skills/gstack/ literal substring
  #   2. ~/.agents/skills/gstack/ literal substring
  #   3. $D / $B envvar (followed by a non-identifier char to avoid $DEBUG, $BAR etc.)
  #   4. generic gstack-* runtime binaries and gstack-owned state names
  # shellcheck disable=SC2088,SC2016  # Literal regex — tilde and $vars are intentional
  local pattern='~/\.(claude|agents)/skills/gstack/|\$D[^a-zA-Z_0-9]|\$B[^a-zA-Z_0-9]|gstack-[a-zA-Z0-9_.-]+'
  # Lines that mention forbidden patterns AS POLICY (allowed).
  local negation_tokens='DO NOT|MUST NOT|NEVER|forbidden|reference-only|do not'

  local hits warn_count=0
  # Scan stage SKILLs (*.md, prose-as-command surface).
  local f
  for f in "$skills_dir"/*/SKILL.md; do
    [ -f "$f" ] || continue
    hits=$(grep -nE "$pattern" "$f" 2>/dev/null || true)
    [ -z "$hits" ] && continue
    # Filter out policy-negation lines.
    hits=$(echo "$hits" | grep -vE "$negation_tokens" || true)
    [ -z "$hits" ] && continue
    while IFS= read -r line; do
      [ -z "$line" ] && continue
      echo "WARN C10 hermetic-no-gstack: ${f#"$ROOT"/}:$line — Principle 12 forbidden GStack runtime reference. See plugins/ship-flow/INVARIANTS.md#principle-12" >&2
      warn_count=$((warn_count + 1))
    done <<< "$hits"
  done
  # Scan lib/*.sh (runtime shell, no documentation-allow exception).
  if [ -d "$lib_dir" ]; then
    for f in "$lib_dir"/*.sh; do
      [ -f "$f" ] || continue
      hits=$(grep -nE "$pattern" "$f" 2>/dev/null || true)
      [ -z "$hits" ] && continue
      hits=$(echo "$hits" | grep -vE "$negation_tokens" || true)
      [ -z "$hits" ] && continue
      while IFS= read -r line; do
        [ -z "$line" ] && continue
        echo "WARN C10 hermetic-no-gstack: ${f#"$ROOT"/}:$line — Principle 12 forbidden GStack runtime reference in lib shell. See plugins/ship-flow/INVARIANTS.md#principle-12" >&2
        warn_count=$((warn_count + 1))
      done <<< "$hits"
    done
  fi

  if [ "$warn_count" = "0" ]; then
    echo "OK C10 hermetic-no-gstack"
  else
    echo "OK C10 hermetic-no-gstack ($warn_count warnings — non-blocking in v1; future hardening tightens to FAIL)"
  fi
  return 0
}

check_panel_coverage_header() {
  # C11 — Principle 14: every completed verify.md MUST contain exactly one
  # `## Panel Coverage` H2 section (placed after Verdict). Grace filter skips
  # entities whose started: predates 2026-05-13 or that lack a started: field
  # (pre-Phase 2B-5 baseline). Blocked / failed verify rounds are also skipped —
  # panel coverage is only required on completed verify rounds.
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || { echo "OK C11 panel-coverage-header (docs dir absent — skip)"; return 0; }
  local fail=0 d verify entity started status_line
  for d in "$docs_dir"/*/; do
    verify="${d}verify.md"
    [ -f "$verify" ] || continue
    entity="$(basename "$d")"
    # Grace filter: pre-2026-05-13 (or no started: field) → skip.
    started="$(_entity_started_date "$d")"
    if [ -z "$started" ] || [[ "$started" < "2026-05-13" ]]; then
      continue
    fi
    # Skip blocked / failed verify rounds (panel coverage required only on completed rounds).
    status_line=$(grep -m1 -E '^status:[[:space:]]*(blocked|failed)' "$verify" 2>/dev/null || true)
    [ -n "$status_line" ] && continue
    local n
    n=$({ grep -cE '^## Panel Coverage$' "$verify" 2>/dev/null || true; } | tr -d ' ')
    if [ "${n:-0}" != "1" ]; then
      echo "FAIL C11 panel-coverage-header: '$entity/verify.md' missing or duplicated ## Panel Coverage section (got $n, expected 1). See plugins/ship-flow/INVARIANTS.md#principle-14" >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C11 panel-coverage-header"
  return "$fail"
}

check_deferred_to_todo_footer() {
  # C12 — Principle 14: every completed verify.md MUST contain exactly one
  # `## Deferred to TODO` H2 section (placed as final H2 in verify.md). N=0
  # case still emits the section (explicit "0 findings this round."). Same
  # grace filter + skip conditions as C11.
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || { echo "OK C12 deferred-to-todo-footer (docs dir absent — skip)"; return 0; }
  local fail=0 d verify entity started status_line
  for d in "$docs_dir"/*/; do
    verify="${d}verify.md"
    [ -f "$verify" ] || continue
    entity="$(basename "$d")"
    started="$(_entity_started_date "$d")"
    if [ -z "$started" ] || [[ "$started" < "2026-05-13" ]]; then
      continue
    fi
    status_line=$(grep -m1 -E '^status:[[:space:]]*(blocked|failed)' "$verify" 2>/dev/null || true)
    [ -n "$status_line" ] && continue
    local n
    n=$({ grep -cE '^## Deferred to TODO$' "$verify" 2>/dev/null || true; } | tr -d ' ')
    if [ "${n:-0}" != "1" ]; then
      echo "FAIL C12 deferred-to-todo-footer: '$entity/verify.md' missing or duplicated ## Deferred to TODO section (got $n, expected 1). See plugins/ship-flow/INVARIANTS.md#principle-14" >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C12 deferred-to-todo-footer"
  return "$fail"
}

check_fo_receipt_on_proceed() {
  # C13 — Principle 13: every verify.md with status: passed MUST have a sibling
  # fo-receipts.md whose mtime >= verify.md mtime AND whose ## ledger entries
  # contain a suitable self-approved verify/proceed/PR-ready receipt. Later
  # merge-gate receipts may be blocked without invalidating the earlier proceed
  # receipt. Grace filter skips pre-2026-05-13 entities (pre-Step 6.0 era).
  local docs_dir="${ROOT}/docs/ship-flow"
  [ -d "$docs_dir" ] || { echo "OK C13 fo-receipt-on-proceed (docs dir absent — skip)"; return 0; }
  local fail=0 d verify receipt entity started
  for d in "$docs_dir"/*/; do
    verify="${d}verify.md"
    [ -f "$verify" ] || continue
    entity="$(basename "$d")"
    # Grace filter.
    started="$(_entity_started_date "$d")"
    if [ -z "$started" ] || [[ "$started" < "2026-05-13" ]]; then
      continue
    fi
    # Only enforce when verify.md verdict is passed.
    grep -qE '^status:[[:space:]]*passed' "$verify" 2>/dev/null || continue
    receipt="${d}fo-receipts.md"
    if [ ! -f "$receipt" ]; then
      echo "FAIL C13 fo-receipt-on-proceed: '$entity' verify.md status passed but fo-receipts.md missing. See plugins/ship-flow/INVARIANTS.md#principle-13 + ship-verify/SKILL.md Step 6.0." >&2
      fail=1
      continue
    fi
    # mtime check: receipt must be at or after verify.md.
    local v_mtime r_mtime
    v_mtime=$(_file_mtime_epoch "$verify")
    r_mtime=$(_file_mtime_epoch "$receipt")
    if [ "${r_mtime:-0}" -lt "${v_mtime:-0}" ]; then
      echo "FAIL C13 fo-receipt-on-proceed: '$entity' fo-receipts.md mtime ($r_mtime) predates verify.md mtime ($v_mtime) — receipt staged before verdict finalized. See INVARIANTS.md#principle-13 failure mode 4." >&2
      fail=1
      continue
    fi
    if ! _fo_receipts_has_self_approved_proceed "$receipt"; then
      echo "FAIL C13 fo-receipt-on-proceed: '$entity' fo-receipts.md missing a self-approved verify/proceed/PR-ready ledger entry (verify status passed → Phase G PROCEED → receipt must be self-approved). See INVARIANTS.md#principle-13." >&2
      fail=1
    fi
  done
  [ "$fail" = "0" ] && echo "OK C13 fo-receipt-on-proceed"
  return "$fail"
}

_file_mtime_epoch() {
  local path="$1" out
  out="$(stat -c %Y "$path" 2>/dev/null || true)"
  case "$out" in
    ''|*[!0-9]*) ;;
    *) printf '%s\n' "$out"; return 0 ;;
  esac
  out="$(stat -f %m "$path" 2>/dev/null || true)"
  case "$out" in
    ''|*[!0-9]*) printf '0\n' ;;
    *) printf '%s\n' "$out" ;;
  esac
}

_fo_receipts_has_self_approved_proceed() {
  local receipt="$1"
  awk '
    function finish_entry() {
      if (entry_has_decision && entry_has_signal) {
        found = 1
      }
    }
    /^## / {
      finish_entry()
      entry_has_decision = 0
      entry_has_signal = 0
      next
    }
    /^[[:space:]]*decision:[[:space:]]*self-approved[[:space:]]*$/ {
      entry_has_decision = 1
    }
    /^[[:space:]]*trigger:/ && ($0 ~ /verify-proceed|pr-creation-autonomy|pr-ready/) {
      entry_has_signal = 1
    }
    /^[[:space:]]*verdict:/ && ($0 ~ /PR_READY|PROCEED|VERIFY_PROCEED|READY_FOR_PR/) {
      entry_has_signal = 1
    }
    END {
      finish_entry()
      exit(found ? 0 : 1)
    }
  ' "$receipt" 2>/dev/null
}

_frontmatter_status_at_rev_path() {
  local rev="$1"
  local path="$2"
  { git show "${rev}:${path}" 2>/dev/null || true; } | awk '
    BEGIN{d=0}
    /^---[[:space:]]*$/ {d++; next}
    d==1 && /^status:[[:space:]]*/ {
      sub(/^status:[[:space:]]*/, "", $0)
      gsub(/[[:space:]]+$/, "", $0)
      print
      exit
    }
    d>=2 {exit}
  '
}

# Returns 0 (true) when the entity at <rev>:<path> has a stage-artifact-links
# BODY TABLE but NO stage_outputs frontmatter — the shape-confirm.sh format.
# On such an entity advance-stage.sh / render-stage-links are DESTRUCTIVE (they
# rebuild the body table FROM stage_outputs, nuking the populated table), so a
# manual status edit is the SAFE path and is exempt from C14's signature
# requirement. Once an entity carries stage_outputs, advance-stage.sh is safe
# and the requirement applies. Principle 15 amendment — #117 dogfood finding.
_entity_bodytable_no_stage_outputs() {
  local rev="$1" path="$2" content
  content="$( { git show "${rev}:${path}" 2>/dev/null || true; } )"
  printf '%s\n' "$content" | grep -q '<!-- section:stage-artifact-links -->' || return 1
  if printf '%s\n' "$content" | awk '
      BEGIN{d=0}
      /^---[[:space:]]*$/ {d++; next}
      d==1 && /^stage_outputs:[[:space:]]*$/ {print "y"; exit}
      d>=2 {exit}
    ' | grep -q y; then
    return 1   # has stage_outputs → advance-stage.sh is safe → NOT exempt
  fi
  return 0     # table present, no stage_outputs → destructive case → exempt
}

# C14: Entity status mutation must go through lib/advance-stage.sh
# ----------------------------------------------------------------
# Scans commits on the current branch ahead of merge-base with origin/main.
# For each commit modifying an entity index.md (folder layout) or flat
# <id>-<slug>.md, if the frontmatter status value changes between the
# commit's first parent and the commit, the commit message MUST contain the
# substring ": advance status to " (injected by lib/advance-stage.sh line 122
# when invoked legitimately).
#
# Source pitch: enforce-advance-stage-primitive-only (sharp 2026-05-15).
# Source evidence: pitch-106 commit 898d006c — direct YAML edit bypassed
# advance-stage.sh, would have nuked entity body table per MEMORY
# "advance-stage destructive on legacy body tables".
# Sibling: plugins/ship-flow/INVARIANTS.md Principle 15.
check_entity_status_via_advance_stage_only() {
  local entity_status_paths=(
    ':(glob)docs/*/*/index.md'
    ':(glob)docs/*/*-*.md'
  )

  # Bound scan to current-branch commits only (merge-base..HEAD).
  # Pre-existing main-history commits are out of scope per plan T3.
  local merge_base
  if ! merge_base="$(git merge-base origin/main HEAD 2>/dev/null)"; then
    # No origin/main reference — likely a fresh test fixture without it; PASS.
    echo "OK C14 entity-status-via-advance-stage-only (no origin/main; skipping)"
    return 0
  fi

  # Range may be empty when HEAD == merge-base; that's a clean PASS.
  if [ "$merge_base" = "$(git rev-parse HEAD)" ]; then
    echo "OK C14 entity-status-via-advance-stage-only (no branch commits to scan)"
    return 0
  fi

  local violations=0
  local commits
  commits="$(git log --format=%H "${merge_base}..HEAD" -- "${entity_status_paths[@]}" 2>/dev/null)"

  local sha
  for sha in $commits; do
    # Mutation = frontmatter status changed between first parent and this commit.
    # Body-level `status:` examples are ignored; pure additions have no parent
    # frontmatter status and are exempt.
    local has_status_mutation=0
    local path before_status after_status
    local mutated_paths=()
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      before_status="$(_frontmatter_status_at_rev_path "${sha}^" "$path")"
      after_status="$(_frontmatter_status_at_rev_path "$sha" "$path")"
      if [ -n "$before_status" ] && [ -n "$after_status" ] && [ "$before_status" != "$after_status" ]; then
        has_status_mutation=1
        mutated_paths+=("$path")
      fi
    done < <(git diff-tree --no-commit-id --name-only -r "$sha" -- "${entity_status_paths[@]}" 2>/dev/null || true)

    if [ "$has_status_mutation" = "0" ]; then
      continue
    fi

    # Body-table exemption (Principle 15 amendment, #117 dogfood finding):
    # shape-confirm.sh creates entities with a stage-artifact-links body table
    # and no stage_outputs frontmatter; advance-stage.sh is destructive on them,
    # so a manual status edit is the SAFE path and is exempt. The signature
    # requirement still applies once the entity carries stage_outputs.
    #
    # FIX 1 (per-path): check ALL mutated paths — only skip the commit when
    # EVERY mutated path is exempt.  A single non-exempt path falls through to
    # the signature check, preventing the break-and-single-representative bypass.
    #
    # FIX 2 (parent-state): pass ${sha}^ (parent) so the helper sees the entity
    # BEFORE the commit.  A commit that BOTH strips stage_outputs AND bumps
    # status must NOT be read as exempt just because the after-state lacks
    # stage_outputs.
    local all_exempt=1 mp
    for mp in "${mutated_paths[@]}"; do
      if ! _entity_bodytable_no_stage_outputs "${sha}^" "$mp"; then
        all_exempt=0
        break
      fi
    done
    [ "$all_exempt" = "1" ] && continue

    # Check commit message for advance-stage.sh signature.
    local msg
    msg="$(git log -1 --format=%B "$sha")"
    case "$msg" in
      *": advance status to "*) continue ;;
      *)
        violations=$((violations + 1))
        echo "FAIL C14 entity-status-via-advance-stage-only: commit ${sha:0:8} mutated entity status: without advance-stage.sh signature. See plugins/ship-flow/INVARIANTS.md#principle-15." >&2
        echo "       commit msg head: $(echo "$msg" | head -1)" >&2
        ;;
    esac
  done

  if [ "$violations" -gt 0 ]; then
    return 1
  fi
  echo "OK C14 entity-status-via-advance-stage-only"
  return 0
}

check_stage_metrics_contract() {
  # Stage reports must keep a lightweight metrics envelope for later aggregation.
  # This prose-level check prevents silent SKILL contract drift without adding an
  # artifact parser or metrics aggregator in this slice.
  local skills_dir="${ROOT}/plugins/ship-flow/skills"
  [ -d "$skills_dir" ] || return 0
  local stage_skills=(ship-shape ship-design ship-plan ship-execute ship-verify ship-review)
  local fail=0 sk f

  for sk in "${stage_skills[@]}"; do
    f="${skills_dir}/${sk}/SKILL.md"
    if [ ! -f "$f" ]; then
      echo "ERROR [stage-metrics-contract]: missing stage skill ${sk}/SKILL.md" >&2
      fail=1
      continue
    fi
    if ! grep -qF "Require a \`### Metrics\` subsection" "$f"; then
      echo "ERROR [stage-metrics-contract]: ${sk}/SKILL.md missing required ### Metrics subsection contract" >&2
      fail=1
    fi
    if ! grep -qF "\`duration_minutes:\`" "$f"; then
      echo "ERROR [stage-metrics-contract]: ${sk}/SKILL.md missing duration_minutes metric" >&2
      fail=1
    fi
    if ! grep -qF "\`iteration_count:\`" "$f"; then
      echo "ERROR [stage-metrics-contract]: ${sk}/SKILL.md missing iteration_count metric" >&2
      fail=1
    fi
    if ! grep -qF "\`status:\`" "$f"; then
      echo "ERROR [stage-metrics-contract]: ${sk}/SKILL.md missing status metric" >&2
      fail=1
    fi
  done

  return "$fail"
}

check_visible_surface_map_contract() {
  local fail=0
  local schema="${ROOT}/plugins/ship-flow/references/entity-body-schema.yaml"
  local importer="${ROOT}/plugins/ship-flow/lib/import-design-dcs.sh"
  local validator="${ROOT}/plugins/ship-flow/lib/validate-handoff-schema.sh"
  local helper="${ROOT}/plugins/ship-flow/lib/check-visible-surface-coverage.sh"
  local design_skill="${ROOT}/plugins/ship-flow/skills/ship-design/SKILL.md"
  local plan_skill="${ROOT}/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local verify_skill="${ROOT}/plugins/ship-flow/skills/ship-verify/SKILL.md"
  local import_test="${ROOT}/plugins/ship-flow/lib/__tests__/test-import-design-dcs.sh"
  local contract_test="${ROOT}/plugins/ship-flow/lib/__tests__/test-visible-surface-map-contract.sh"
  local coverage_test="${ROOT}/plugins/ship-flow/lib/__tests__/test-visible-surface-coverage.sh"

  require_grep() {
    local path="$1" pattern="$2" label="$3"
    if [ ! -f "$path" ]; then
      echo "ERROR [visible-surface-map-contract]: missing ${label}: ${path}" >&2
      fail=1
      return
    fi
    if ! grep -qE "$pattern" "$path"; then
      echo "ERROR [visible-surface-map-contract]: ${label} missing pattern: ${pattern}" >&2
      fail=1
    fi
  }

  require_grep "$schema" 'name: visible_surface_map' "entity-body-schema"
  require_grep "$schema" 'region, control, state_indicator, semantic_badge' "visible surface type enum"
  require_grep "$validator" 'visible_surface_map\[\]' "handoff validator"
  require_grep "$importer" 'Imported visible_surface_map' "design DC importer"
  require_grep "$helper" 'render_fidelity_targets_passed=true' "visible surface coverage helper"
  require_grep "$design_skill" 'visible_surface_map\[\].*id.*surface_type.*selector_hint' "ship-design handoff contract"
  require_grep "$plan_skill" 'visible_surface_map\[\].*structural/mockup-parity' "ship-plan import contract"
  require_grep "$verify_skill" 'Visible surface coverage audit' "ship-verify coverage step"
  require_grep "$verify_skill" 'implementation-only extra UI' "ship-verify route contract"
  require_grep "$contract_test" 'test-visible-surface-map-contract' "contract grep test"
  require_grep "$coverage_test" 'render_fidelity_targets_passed=true' "closed-list coverage fixture"

  if [ "$fail" = "0" ]; then
    if ! bash "$import_test" >/dev/null; then
      echo "ERROR [visible-surface-map-contract]: import/validator behavior fixture failed" >&2
      fail=1
    fi
    if ! bash "$coverage_test" >/dev/null; then
      echo "ERROR [visible-surface-map-contract]: visible surface coverage behavior fixture failed" >&2
      fail=1
    fi
  fi

  return "$fail"
}

# C15: artifact-verbosity — Principle 8 stage-report line caps as a CI BLOCKER.
# Source: 129.2-wire-artifact-verbosity-blocker (design.md, CAPTAIN-APPROVED).
# Sibling: plugins/ship-flow/INVARIANTS.md Principle 8 (cap table @ :290-298).
#
# Appended as an ISOLATED function (entity 129.1 edits this file in parallel —
# minimize conflict surface: pure append + two registration lines, no reorg).
#
# Scope: the 5 stage-report artifacts only — plan/execute/verify/review/ship.md.
# shape.md, design.md, index.md are NOT capped (Principle 8 omits them).
#
# Measurement = BODY content: count lines AFTER (1) stripping a leading
# ---…--- YAML frontmatter block, (2) dropping ^<!-- /?section: marker lines,
# (3) excluding lines inside <details>…</details> blocks. Blank lines are
# counted (real body whitespace; trimming invites gaming). CRLF is normalised
# (CR stripped) so endings do not mis-count.
# Backstop: raw total is ALSO capped at 2x the body cap, so a single giant
# <details> cannot defeat the cap.
#
# Grandfather = branch-scope: only stage artifacts ADDED or MODIFIED in
# merge_base(origin/main, HEAD)..HEAD are scanned (exact C14 mechanism).
# Pre-existing over-cap files on main are never scanned. Fixture mode
# ($FIXTURE set) bypasses the git-range gate and scans the fixture dir directly.

# Return the body cap for a stage artifact basename; empty string = not capped.
_artifact_body_cap() {
  case "$1" in
    plan.md) echo 200 ;;
    execute.md) echo 150 ;;
    verify.md) echo 120 ;;
    review.md) echo 100 ;;
    ship.md) echo 60 ;;
    *) echo "" ;;
  esac
}

# Measure body-content line count of a stage artifact.
# Reads the file from $1, prints the body line count.
_artifact_body_line_count() {
  local file="$1"
  # awk body-content measurement. Excludes:
  #   (1) a single leading ---…--- YAML frontmatter block,
  #   (2) ^<!-- /?section: marker lines,
  #   (3) BALANCED <details>…</details> blocks whose open/close tags are each on
  #       their OWN line (anchored at line start, ignoring leading whitespace).
  # Hardening (cross-review cycle 1):
  #   - ANCHORING: only a standalone `<details>` tag line opens a block. A
  #     mid-line mention ("see the <details> below") is ordinary body — it does
  #     NOT enter details-mode (closes the accidental-bypass hole).
  #   - BALANCE: lines inside a candidate block are BUFFERED, not dropped. They
  #     are only excluded once a matching standalone `</details>` close is seen.
  #     If EOF is reached with a block still open (unterminated/unbalanced), the
  #     buffered lines are COUNTED — an unterminated <details> cannot smuggle
  #     body under the budget (err toward RED).
  # Hardening (cross-review cycle 2):
  #   - FRONTMATTER BALANCE: the leading ---…--- block is also BUFFERED, not
  #     skipped. It is excluded only when a closing --- is found; if EOF is
  #     reached with frontmatter still open (first line --- but no close), the
  #     buffered lines are COUNTED — an unterminated frontmatter cannot smuggle
  #     the whole body under the budget (err toward RED). Same class as <details>.
  awk '
    BEGIN { in_fm = 0; in_details = 0; count = 0; pending = 0; fm_pending = 0 }
    {
      sub(/\r$/, "")          # normalise CRLF
    }
    # Leading frontmatter: only if the very first line is exactly ---.
    # BUFFER it (fm_pending) rather than drop, so an unterminated block counts.
    NR == 1 && $0 == "---" { in_fm = 1; fm_pending = 1; next }
    in_fm == 1 {
      if ($0 == "---") { in_fm = 0; fm_pending = 0; next }  # balanced → exclude
      fm_pending++
      next
    }
    # While buffering a candidate <details> block:
    in_details == 1 {
      # A standalone </details> close line balances the block → drop buffered.
      if ($0 ~ /^[[:space:]]*<\/details>[[:space:]]*$/) {
        in_details = 0
        pending = 0          # discard buffered (excluded) lines
        next
      }
      # Nested standalone <details> open inside an open block: keep depth simple
      # — still buffering, just accumulate (a nested open does not re-balance).
      pending++
      next
    }
    # section markers (open or close) are excluded
    /^<!--[[:space:]]*\/?section:/ { next }
    # Standalone <details> open tag → start buffering. The open anchor is
    # SYMMETRIC with the close anchor: the tag must be alone on its line —
    # `<details` followed by optional attributes then `>` with nothing after.
    # This rejects (cross-review cycle 3, gemini):
    #   - single-line `<details>text</details>` (content after `>` → no match;
    #     would otherwise open a block that a LATER standalone </details> closes,
    #     swallowing the lines between),
    #   - custom elements like `<details-list>` (char after `details` must be `>`
    #     or whitespace, never `-`).
    # A real standalone `<details>` / `<details open>` on its own line still matches.
    /^[[:space:]]*<details([[:space:]][^>]*)?>[[:space:]]*$/ { in_details = 1; pending = 1; next }
    # Ordinary body line.
    { count++ }
    END {
      # Unbalanced/unterminated block left open at EOF: count the buffered lines
      # (including the opening tag line) so smuggled content cannot hide.
      if (in_details == 1) { count += pending }
      # Unterminated frontmatter (first line --- but never closed): same — count
      # the buffered lines so the whole body cannot be smuggled into a fake block.
      if (in_fm == 1) { count += fm_pending }
      print count
    }
  ' "$file"
}

# Raw total line count, CR-normalised (so CRLF files count the same as LF).
_artifact_raw_line_count() {
  awk 'END { print NR }' "$1"
}

# Known limitations (accepted — pitch 129.2, captain-approved 2026-06-04). C15 is a
# verbosity LINT (discipline nudge), not a security boundary; the awk body-count
# heuristic is intentionally not a markdown-grade tokenizer. Residual edge cases:
#   1. A standalone `<details>`/`</details>` line INSIDE a fenced code block (```) is
#      treated as a real collapsible block and excluded from the body count. Exploiting
#      it requires deliberately fencing collapsible markers, and the content stays
#      VISIBLE in the rendered artifact — so it can dodge the line cap but not hide text.
#   2. Nested `<details>` close is not depth-aware (first standalone `</details>` ends
#      the block), so a legitimately nested block is only partially excluded and may
#      OVER-count toward RED. This errs SAFE (false-RED, never a bypass).
#   3. Scans the COMMITTED PR diff (merge-base..HEAD), identical to C14 and every other
#      check-invariants check — a CI/PR gate, NOT a pre-commit staged linter. An over-cap
#      stage artifact is caught at CI once committed (which is when it reaches a PR);
#      staged-but-uncommitted local state is intentionally not scanned (by design).
#   4. Paths with spaces / non-ASCII are git-quoted in --name-status output and would be
#      skipped; ship-flow stage artifacts use fixed kebab filenames (plan.md/execute.md/…
#      under kebab-slug entity dirs) so this does not trigger. Harden with `git diff -z` if needed.
# 1-2 need a real Markdown parser; 3 is intentional CI-gate scope; 4 is non-triggering for
# fixed filenames — all out of scope for a bash verbosity LINT. Honest-author path fully
# covered; see docs/ship-flow/129.2-* stage report.
check_artifact_verbosity() {
  local violations=0
  local candidates=()
  # Path prefix to strip from absolute file paths when printing the failure
  # message. Fixture mode strips $ROOT; git mode strips the git top-level
  # (which is where `git diff` paths are rooted — NOT $ROOT, which points at the
  # installed plugin location and would be the wrong repo under test fixtures).
  local strip_prefix="${ROOT}/"

  if [ -n "$FIXTURE" ]; then
    # Fixture mode: scan all stage artifacts under the fixture dir directly
    # (git history is absent in fixtures — same dual-path as other checks).
    # Prune _archive/ _debriefs/ _mods/ — terminal/non-stage trees that the
    # approved scope table (design.md:87) marks NOT capped.
    local f
    while IFS= read -r f; do
      [ -n "$f" ] || continue
      candidates+=("$f")
    done < <(find "${ROOT}/docs/ship-flow" \
               \( -path '*/_archive/*' -o -path '*/_debriefs/*' -o -path '*/_mods/*' \) -prune \
               -o -type f \
               \( -name plan.md -o -name execute.md -o -name verify.md \
                  -o -name review.md -o -name ship.md \) -print 2>/dev/null | sort)
  else
    # Branch-scope grandfather (mirror C14): scan only stage artifacts that the
    # current branch's commits add or modify (merge_base..HEAD).
    local merge_base
    if ! merge_base="$(git merge-base origin/main HEAD 2>/dev/null)"; then
      echo "OK C15 artifact-verbosity (no origin/main; skipping)"
      return 0
    fi
    if [ "$merge_base" = "$(git rev-parse HEAD)" ]; then
      echo "OK C15 artifact-verbosity (no branch commits to scan)"
      return 0
    fi
    # git diff paths are relative to the repo top-level; resolve files against
    # it (not $ROOT) so working-tree reads hit the repo actually under check.
    local git_top
    git_top="$(git rev-parse --show-toplevel 2>/dev/null)" || git_top=""
    [ -n "$git_top" ] && strip_prefix="${git_top}/"
    # --name-status -M --diff-filter=AMR (not --name-only AM): rename records
    # carry the moved content. For A/M the candidate is the path; for R the
    # candidate is the DESTINATION (the file as it now lives). This closes the
    # rename-into-active bypass: `git mv` of an over-cap stage artifact into an
    # active stage path is an R record that --diff-filter=AM never measures.
    # Scope exclusion is applied to the DESTINATION:
    #   - the negative :(glob,exclude) pathspecs already drop records whose dest
    #     is under _archive/_debriefs/_mods/ (archiving an over-cap entity stays
    #     excluded — verified: git suppresses the record when dest is excluded),
    #   - we ALSO re-check the dest in shell (belt-and-suspenders, legible) so a
    #     dest under a terminal tree can never be measured even if the rename
    #     pathspec semantics shift across git versions.
    local status rest rel
    while IFS=$'\t' read -r status rest; do
      [ -n "$status" ] || continue
      case "$status" in
        R*)
          # R<score>\t<src>\t<dst> — rest holds "<src>\t<dst>".
          # The candidate is the DESTINATION (the file as it now lives).
          rel="${rest##*$'\t'}"
          ;;
        A|M)
          rel="$rest"
          ;;
        *)
          continue ;;
      esac
      [ -n "$rel" ] || continue
      # Shell-side scope exclusion on the resolved (destination) path.
      case "$rel" in
        docs/ship-flow/_archive/*|docs/ship-flow/_debriefs/*|docs/ship-flow/_mods/*)
          continue ;;
      esac
      # Measure the file at its current working-tree HEAD state. A path in the
      # AMR set may still be missing in the working tree (e.g. later removed) —
      # guard for that. Also guard empty git_top (cross-review cycle 3, gemini):
      # without it `[ -f "/${rel}" ]` would query the filesystem ROOT, a
      # spurious path. An empty git_top means we can't resolve the file safely.
      [ -n "$git_top" ] && [ -f "${git_top}/${rel}" ] && candidates+=("${git_top}/${rel}")
    # Negative pathspecs exclude _archive/ _debriefs/ _mods/ (terminal/non-stage
    # trees, NOT capped per design.md:87 scope table) — the **/plan.md glob would
    # otherwise also match docs/ship-flow/_archive/<id>/plan.md.
    # `top` magic (cross-review cycle 3, gemini): without it git resolves the
    # pathspecs relative to CWD, so running the gate from a subdirectory (local
    # / pre-commit) matches no files → silent false-PASS. `top` roots them at the
    # repo top, matching where --show-toplevel-relative reads expect them. Output
    # paths stay top-relative regardless of cwd, so ${git_top}/${rel} holds.
    done < <(git diff --name-status -M --diff-filter=AMR "$merge_base" HEAD -- \
               ':(top,glob)docs/ship-flow/**/plan.md' \
               ':(top,glob)docs/ship-flow/**/execute.md' \
               ':(top,glob)docs/ship-flow/**/verify.md' \
               ':(top,glob)docs/ship-flow/**/review.md' \
               ':(top,glob)docs/ship-flow/**/ship.md' \
               ':(top,glob,exclude)docs/ship-flow/_archive/**' \
               ':(top,glob,exclude)docs/ship-flow/_debriefs/**' \
               ':(top,glob,exclude)docs/ship-flow/_mods/**' 2>/dev/null)
  fi

  local file base cap rel_display body_lines raw_lines raw_cap
  for file in "${candidates[@]}"; do
    [ -f "$file" ] || continue
    base="$(basename "$file")"
    cap="$(_artifact_body_cap "$base")"
    [ -n "$cap" ] || continue
    rel_display="${file#"$strip_prefix"}"

    body_lines="$(_artifact_body_line_count "$file")"
    raw_lines="$(_artifact_raw_line_count "$file")"
    raw_cap=$((cap * 2))

    if [ "$body_lines" -gt "$cap" ]; then
      violations=$((violations + 1))
      echo "FAIL C15 artifact-verbosity: '${rel_display}' body content is ${body_lines} lines (cap ${cap} for ${base}). Move raw evidence into <details> or link to commits/PR. See plugins/ship-flow/INVARIANTS.md#principle-8." >&2
    elif [ "$raw_lines" -gt "$raw_cap" ]; then
      violations=$((violations + 1))
      echo "FAIL C15 artifact-verbosity: '${rel_display}' raw total is ${raw_lines} lines (raw cap ${raw_cap} = 2x ${cap} body cap for ${base}); body is under cap but a single oversized <details> defeats the budget. Link out instead of inlining. See plugins/ship-flow/INVARIANTS.md#principle-8." >&2
    fi
  done

  if [ "$violations" -gt 0 ]; then
    return 1
  fi
  echo "OK C15 artifact-verbosity"
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
    pitch-assumptions) check_pitch_assumptions; exit $? ;;
    stage-artifact-path) check_stage_artifact_path; exit $? ;;
    layer-a-delegation) check_layer_a_delegation; exit $? ;;
    team-fallback-documented) check_team_fallback_documented; exit $? ;;
    cross-review-gate) check_cross_review_gate; exit $? ;;
    layer-a-table-parity) check_layer_a_table_parity; exit $? ;;
    pm-skill-receipts) check_pm_skill_receipts; exit $? ;;
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
    principle-numbering) check_principle_numbering; exit $? ;;
    hermetic-no-gstack) check_hermetic_no_gstack; exit $? ;;
    panel-coverage-header) check_panel_coverage_header; exit $? ;;
    deferred-to-todo-footer) check_deferred_to_todo_footer; exit $? ;;
    fo-receipt-on-proceed) check_fo_receipt_on_proceed; exit $? ;;
    entity-status-via-advance-stage-only) check_entity_status_via_advance_stage_only; exit $? ;;
    stage-metrics-contract) check_stage_metrics_contract; exit $? ;;
    visible-surface-map-contract) check_visible_surface_map_contract; exit $? ;;
    artifact-verbosity) check_artifact_verbosity; exit $? ;;
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
# C9: pitch-113.2 — INVARIANTS.md duplicate Principle-number detection (2026-04-29)
check_principle_numbering || FAIL=1
# C10-C13: Phase 1/2B/3A merge enforcement (2026-05-13) — Hermetic Dependency Policy,
# Multi-Specialist Panel output contract, FO Receipt persistence
check_hermetic_no_gstack || FAIL=1
check_panel_coverage_header || FAIL=1
check_deferred_to_todo_footer || FAIL=1
check_fo_receipt_on_proceed || FAIL=1
# C14: entity-status mutation must go through lib/advance-stage.sh
# Source: pitch enforce-advance-stage-primitive-only (sharp 2026-05-15)
check_entity_status_via_advance_stage_only || FAIL=1
check_stage_metrics_contract || FAIL=1
check_visible_surface_map_contract || FAIL=1
# C15: Principle 8 stage-report verbosity caps (branch-scope grandfather)
# Source: 129.2-wire-artifact-verbosity-blocker (2026-06-04)
check_artifact_verbosity || FAIL=1

exit $FAIL
