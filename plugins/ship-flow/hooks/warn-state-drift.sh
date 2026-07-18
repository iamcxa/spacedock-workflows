#!/usr/bin/env bash
# ship-flow-hook-version: 1.3.0
# Ship-flow FO state-drift — SessionStart hook
#
# Two drift detectors, both advisory-by-default (never blocks session start):
#
#   Rule A: entity at `status: ship` whose `pr: #N` is MERGED on GitHub
#           (original rule, week 2026-04-20 observation — 3 instances)
#
#   Rule B: entity at `status ∈ {sharp, plan, execute, verify, review}` that
#           has a later-stage sibling .md file on disk (e.g., status=sharp
#           but ship.md exists). Added 2026-04-25 after finding 13/17 folder
#           entities stuck at status=sharp despite all having shipped via
#           merged PRs. Root cause: ship-* SKILLs write stage artifacts but
#           don't invoke the frontmatter helpers (see entity 099-ship-flow-
#           stage-wiring). Rule B is the detection safety-net.
#
# Auto-fix (v1.3.0; D1 originated in strengthening-roadmap-2026-05.md):
#
#   Workflow README frontmatter MAY declare `auto_fix: off | execute`
#   (default: `off`). When `execute`, this hook delegates at most one canonical
#   folder Rule A entity to the receipt-bound closeout reconciler after a
#   safety re-probe. Additional folders remain pending for the next session;
#   flat legacy entities are warning-only. Rule B is NEVER auto-fixed.
#
#   Safety guards (any fail → skip auto-fix, fall back to WARN):
#     - working tree clean (uncommitted changes block all auto-fixes)
#     - receipt-bound closeout reconciler discoverable in the plugin
#     - per-entity PR state re-probe matches MERGED
#
#   Output reformats: ✅ Auto-fixed / reconciled (N) /
#   ⚠️ Auto-fix blocked (M reason) /
#   🔴 Rule A pending (K, auto_fix off or blocked) / 🔴 Rule B (P).
#
# Also extended to scan folder entities (<slug>/index.md at depth 2), which
# v1.0 missed entirely (maxdepth 1 -type f only caught flat .md files).
#
# Triggers on: SessionStart (matcher: "")
# Action:      Advisory by default; optional autonomous fix per workflow config
# Exit:        Always 0
# Timeout:     120s set by hooks.json; Rule A per-PR checks cap at 2s and the
#              single reconciler child caps at 90s.
#              Rule B is local-fs-only (no network) so cheap regardless of
#              entity count.

set -uo pipefail

# --- 1. Only run inside a ship-flow-commissioned repo ----------------------
workflow_dir=""
for candidate in docs/ship-flow .planning/ship-flow; do
  if [ -f "$candidate/README.md" ] && \
     grep -q '^commissioned-by: spacedock@' "$candidate/README.md" 2>/dev/null; then
    workflow_dir="$candidate"
    break
  fi
done
[ -z "$workflow_dir" ] && exit 0

# --- 1b. Read auto_fix config from workflow README frontmatter (D1) -------
# Default: off (status quo for all adopters who don't opt in).
# Values: off | execute (advise reserved for future; treat as off for v1.3.0).
auto_fix=$(awk '/^---$/{c++; next} c==1 && /^auto_fix:/{print $2; exit}' \
  "$workflow_dir/README.md" 2>/dev/null | tr -d '"' | tr -d "'")
auto_fix="${auto_fix:-off}"

# --- 1c. Safety probe: working tree clean? --------------------------------
# Auto-fix path requires clean tree (atomic commits, no contamination).
git_clean=1
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  git_clean=0
fi

# --- 1d. Locate the receipt-bound closeout reconciler ---------------------
# The reconciler owns every terminal mutation and its receipt sentinel.
# SHIP_FLOW_CLOSEOUT_RECONCILER_BIN is a test-only seam following the
# existing executable override convention used by SHIP_FLOW_STATUS_BIN.
hook_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
reconciler_bin=""
if [ "$auto_fix" = "execute" ]; then
  if [ -n "${SHIP_FLOW_CLOSEOUT_RECONCILER_BIN:-}" ] && [ -x "$SHIP_FLOW_CLOSEOUT_RECONCILER_BIN" ]; then
    reconciler_bin="$SHIP_FLOW_CLOSEOUT_RECONCILER_BIN"
  else
    reconciler_bin="$hook_dir/../bin/merged-pr-closeout-reconciler.sh"
    [ -x "$reconciler_bin" ] || reconciler_bin=""
  fi
fi

# Stage order (for Rule B later-stage detection)
# sharp → plan → execute → verify → review → ship → done
# A stage file whose name is strictly after the entity's `status:` = drift.
later_stages_for() {
  case "$1" in
    sharp)   echo "plan execute verify review ship" ;;
    plan)    echo "execute verify review ship" ;;
    execute) echo "verify review ship" ;;
    verify)  echo "review ship" ;;
    review)  echo "ship" ;;
    *)       echo "" ;;
  esac
}

# --- 2. Prep accumulators -------------------------------------------------
rule_a_lines=""
rule_a_count=0
# Every merged Rule-A record, used to rebuild the pending section after the
# single selected folder entity is classified: slug|id|pr_num|kind.
rule_a_pending_records=""
# Canonical folder Rule-A candidates. Newline-separated, pipe-
# delimited fields: slug|pr_num|entity_file|stage_dir
rule_a_records=""
rule_a_candidate_count=0
rule_b_lines=""
rule_b_count=0
unsafe_pr_lines=""
unsafe_pr_count=0
have_gh=0
command -v gh >/dev/null 2>&1 && have_gh=1

# check_entity <path-to-entity-md> <stage_dir-or-empty>
# Applies Rule A + Rule B to one entity file.
# stage_dir="" means flat .md (skip Rule B — no siblings to check).
check_entity() {
  local entity_file="$1"
  local stage_dir="$2"
  local status pr id slug pending_kind
  status=$(awk '/^---$/{c++; next} c==1 && /^status:/{print $2; exit}' "$entity_file" 2>/dev/null | tr -d '"' | tr -d "'")
  pr=$(awk '/^---$/{c++; next} c==1 && /^pr:/{print $2; exit}' "$entity_file" 2>/dev/null | tr -d '"' | tr -d "'")
  id=$(awk '/^---$/{c++; next} c==1 && /^id:/{print $2; exit}' "$entity_file" 2>/dev/null | tr -d '"' | tr -d "'")
  if [ -n "$stage_dir" ]; then
    slug=$(basename "$stage_dir")
  else
    slug=$(basename "$entity_file" .md)
  fi

  # Rule A — status=ship + PR merged. Other status=ship PR states are
  # warning-only: visible to captain, never terminal-mutated by this hook.
  if [ "$status" = "ship" ]; then
    if [ -z "$pr" ] || [ "$pr" = "empty" ] || [ "$pr" = "null" ]; then
      unsafe_pr_lines+="  - #${id:-?} \`$slug\` — missing PR number; no auto-fix attempted"$'\n'
      unsafe_pr_count=$((unsafe_pr_count + 1))
      return
    fi
    local pr_num="${pr##\#}"
    case "$pr_num" in
    ''|*[!0-9]*)
      unsafe_pr_lines+="  - #${id:-?} \`$slug\` — invalid PR value \`${pr}\`; no auto-fix attempted"$'\n'
      unsafe_pr_count=$((unsafe_pr_count + 1))
      ;;
    *)
      local state
      state=""
      [ "$have_gh" = "1" ] && state=$(timeout 2 gh pr view "$pr_num" --json state -q .state 2>/dev/null || true)
      if [ "$state" = "MERGED" ]; then
        if [ -n "$stage_dir" ]; then
          pending_kind=folder
          rule_a_lines+="  - #${id:-?} \`$slug\` — PR #$pr_num MERGED, canonical folder entity still at \`status: ship\`"$'\n'
        else
          pending_kind=flat
          rule_a_lines+="  - #${id:-?} \`$slug\` — PR #$pr_num MERGED, flat legacy entity; warning-only, no reconciler call"$'\n'
        fi
        rule_a_count=$((rule_a_count + 1))
        rule_a_pending_records+="$slug|${id:-?}|$pr_num|$pending_kind"$'\n'
        # The receipt reconciler requires canonical folder artifacts. Flat
        # legacy entities remain visible but are never auto-fix candidates.
        if [ -n "$stage_dir" ]; then
          rule_a_records+="$slug|$pr_num|$entity_file|$stage_dir"$'\n'
          rule_a_candidate_count=$((rule_a_candidate_count + 1))
        fi
      elif [ -n "$state" ]; then
        unsafe_pr_lines+="  - #${id:-?} \`$slug\` — PR #$pr_num state=${state}; warning-only, no auto-fix attempted"$'\n'
        unsafe_pr_count=$((unsafe_pr_count + 1))
      fi ;;
    esac
  fi

  # Rule B — status precedes an on-disk later-stage sibling (folder entities only)
  if [ -n "$stage_dir" ] && [ -n "$status" ]; then
    local later found_later stage
    later=$(later_stages_for "$status")
    if [ -n "$later" ]; then
      found_later=""
      for stage in $later; do
        if [ -f "$stage_dir/$stage.md" ]; then
          found_later="$found_later $stage"
        fi
      done
      if [ -n "$found_later" ]; then
        rule_b_lines+="  - #${id:-?} \`$slug\` — \`status: $status\` but sibling(s) present:${found_later}"$'\n'
        rule_b_count=$((rule_b_count + 1))
      fi
    fi
  fi
}

# --- 3. Scan flat .md entities at depth 1 (legacy / simple entities) -----
while IFS= read -r -d '' f; do
  case "$(basename "$f")" in README.md|000-*) continue ;; esac
  check_entity "$f" ""
done < <(find "$workflow_dir" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)

# --- 4. Scan folder entities at depth 2 (<slug>/index.md) ----------------
while IFS= read -r -d '' f; do
  parent=$(basename "$(dirname "$f")")
  case "$parent" in _archive|_debriefs|_mods|todos) continue ;; esac
  check_entity "$f" "$(dirname "$f")"
done < <(find "$workflow_dir" -mindepth 2 -maxdepth 2 -type f -name 'index.md' -print0 2>/dev/null)

# --- 4b. Auto-fix execution (D1, Rule A only) ----------------------------
# Pre-conditions for execute path:
#   - workflow declares `auto_fix: execute` in README frontmatter
#   - working tree clean (atomic commits, no parallel-session contamination)
#   - receipt-bound closeout reconciler discoverable
#   - at least one canonical folder Rule A entity detected
# At most one folder entity is classified per SessionStart. Flat legacy and
# additional folder records remain in the generic pending section.
# Per-entity re-probe (PR.state == MERGED) catches detect-time → exec-time race.
auto_fixed_lines=""
auto_fixed_count=0
auto_fix_blocked_lines=""
auto_fix_blocked_count=0
auto_fix_reason=""

if [ "$rule_a_candidate_count" -gt 0 ] && [ "$auto_fix" = "execute" ]; then
  selected_record="$(printf '%s\n' "$rule_a_records" | sed -n '1p')"
  IFS='|' read -r slug pr_num entity_file stage_dir <<< "$selected_record"

  if [ "$git_clean" = "0" ]; then
    auto_fix_reason="working tree has uncommitted changes"
  elif [ -z "$reconciler_bin" ]; then
    auto_fix_reason="merged PR closeout reconciler is not executable"
  fi

  if [ -z "$auto_fix_reason" ]; then
    # Per-entity re-probe (paranoia: detect → exec gap; PR may have unmerged)
    state=$(timeout 2 gh pr view "$pr_num" --json state -q .state 2>/dev/null || true)
    if [ "$state" != "MERGED" ]; then
      auto_fix_blocked_lines+="  - \`$slug\` — re-probe says state=${state:-unknown}, not MERGED (race?); manual fix required"$'\n'
      auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
    else
      reconcile_rc=0
      reconcile_output="$(timeout 90 "$reconciler_bin" \
        --workflow-dir "$workflow_dir" \
        --entity "$slug" \
        --closeout-mode direct 2>&1)" || reconcile_rc=$?
      reconcile_verdict="$(printf '%s\n' "$reconcile_output" | awk -F= '$1=="verdict"{print substr($0,index($0,"=")+1); exit}')"
      reconcile_state="$(printf '%s\n' "$reconcile_output" | awk -F= '$1=="state"{print substr($0,index($0,"=")+1); exit}')"
      reconcile_action="$(printf '%s\n' "$reconcile_output" | awk -F= '$1=="terminal_action"{print substr($0,index($0,"=")+1); exit}')"
      reconcile_reason="$(printf '%s\n' "$reconcile_output" | awk -F= '$1=="reason"{print substr($0,index($0,"=")+1); exit}')"

      if [ "$reconcile_rc" = "124" ]; then
        auto_fix_blocked_lines+="  - \`$slug\` — reconciler timed out (state=${reconcile_state:-unknown}, action=${reconcile_action:-unknown}, reason=timeout, exit=124)"$'\n'
        auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
      else
        case "$reconcile_rc:$reconcile_verdict:$reconcile_state:$reconcile_action" in
        0:PROCEED:reconciled:closeout_bundle)
          auto_fixed_lines+="  - \`$slug\` — PR #$pr_num reconciled through the receipt-bound closeout transaction"$'\n'
          auto_fixed_count=$((auto_fixed_count + 1))
          ;;
        0:PROCEED:already_reconciled:already_reconciled)
          auto_fixed_lines+="  - \`$slug\` — receipt already reconciled; replay made no terminal mutation"$'\n'
          auto_fixed_count=$((auto_fixed_count + 1))
          ;;
        0:PROCEED:pr_open_noop:none)
          auto_fix_blocked_lines+="  - \`$slug\` — PR became OPEN during reconciliation; no terminal mutation was applied"$'\n'
          auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
          ;;
        0:PROCEED:closeout_pr_awaiting_merge:none)
          auto_fix_blocked_lines+="  - \`$slug\` — receipt-bound closeout PR is awaiting merge; no direct terminal mutation was applied"$'\n'
          auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
          ;;
        *)
          if [ -n "$reconcile_verdict" ] && [ -n "$reconcile_reason" ]; then
            auto_fix_blocked_lines+="  - \`$slug\` — reconciler failed (verdict=$reconcile_verdict, reason=$reconcile_reason, exit=$reconcile_rc)"$'\n'
          else
            auto_fix_blocked_lines+="  - \`$slug\` — reconciler returned an incomplete structured result (state=${reconcile_state:-unknown}, action=${reconcile_action:-unknown}, exit=$reconcile_rc)"$'\n'
          fi
          auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
          ;;
        esac
      fi
    fi
  else
    auto_fix_blocked_lines+="  - \`$slug\` — auto-fix skipped ($auto_fix_reason)"$'\n'
    auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
  fi

  # The selected folder is represented above. Rebuild pending from flat
  # legacy records and deferred folders only.
  rule_a_lines=""
  rule_a_count=0
  selected_pending_skipped=0
  while IFS='|' read -r pending_slug pending_id pending_pr pending_kind; do
    [ -z "$pending_slug" ] && continue
    if [ "$selected_pending_skipped" = "0" ] && \
       [ "$pending_kind" = folder ] && \
       [ "$pending_slug" = "$slug" ] && \
       [ "$pending_pr" = "$pr_num" ]; then
      selected_pending_skipped=1
      continue
    fi
    if [ "$pending_kind" = flat ]; then
      rule_a_lines+="  - #${pending_id:-?} \`$pending_slug\` — PR #$pending_pr MERGED, flat legacy entity; warning-only, no reconciler call"$'\n'
    else
      rule_a_lines+="  - #${pending_id:-?} \`$pending_slug\` — PR #$pending_pr MERGED, canonical folder entity still at \`status: ship\`"$'\n'
    fi
    rule_a_count=$((rule_a_count + 1))
  done <<< "$rule_a_pending_records"
fi

# --- 5. Emit structured advisory (only if anything drifted) --------------
[ "$rule_a_count" -eq 0 ] && [ "$rule_b_count" -eq 0 ] && \
  [ "$unsafe_pr_count" -eq 0 ] && \
  [ "$auto_fixed_count" -eq 0 ] && [ "$auto_fix_blocked_count" -eq 0 ] && exit 0

msg="[ship-flow] FO state-drift report:"

# Auto-fixed section (D1) — show successes first
if [ "$auto_fixed_count" -gt 0 ]; then
  plural=$([ "$auto_fixed_count" -eq 1 ] && echo "entity" || echo "entities")
  msg+="

✅ **Auto-fixed / reconciled** ($auto_fixed_count $plural, via \`auto_fix: execute\` workflow config):
$auto_fixed_lines
No action needed — the receipt-bound reconciler completed the terminal transaction or verified its coherent receipt replay."
fi

# Auto-fix blocked section (D1) — Rule A entities where execute path tripped a guard
if [ "$auto_fix_blocked_count" -gt 0 ]; then
  plural=$([ "$auto_fix_blocked_count" -eq 1 ] && echo "entity" || echo "entities")
  msg+="

⚠️ **Auto-fix blocked** ($auto_fix_blocked_count $plural — execute mode set but pre-condition or re-probe failed):
$auto_fix_blocked_lines
Resolve the blocking reason (commit/stash uncommitted work; verify the closeout reconciler and status helper; re-check PR state) and re-trigger SessionStart, or run the receipt-bound reconciler directly for each entity."
fi

# Rule A pending section — auto_fix off OR all entities blocked above
if [ "$rule_a_count" -gt 0 ]; then
  plural=$([ "$rule_a_count" -eq 1 ] && echo "entity" || echo "entities")
  msg+="

🔴 **Rule A** — $rule_a_count $plural with merged PR still at \`status: ship\`:
$rule_a_lines
With \`auto_fix: execute\`, canonical folder entities are reconciled one per SessionStart and remaining folders stay pending for the next session. Flat legacy entries are warning-only: migrate them to the canonical folder artifact contract before reconciliation."
fi
if [ "$unsafe_pr_count" -gt 0 ]; then
  plural=$([ "$unsafe_pr_count" -eq 1 ] && echo "entity" || echo "entities")
  msg+="

⚠️ **Warning-only PR states** — $unsafe_pr_count $plural at \`status: ship\` but outside Rule A:
$unsafe_pr_lines
No terminal mutation was attempted. Rule A auto-fix is limited to parseable PRs whose provider state is \`MERGED\`."
fi
if [ "$rule_b_count" -gt 0 ]; then
  plural=$([ "$rule_b_count" -eq 1 ] && echo "entity" || echo "entities")
  msg+="

**Rule B** — $rule_b_count $plural with \`status:\` earlier than on-disk stage artifacts:
$rule_b_lines
Root cause: ship-* SKILLs don't invoke \`lib/update-entity-status.sh\` after writing stage .md files. Tracked at \`docs/ship-flow/099-ship-flow-stage-wiring/\`. Interim fix: advance status manually with \`bash plugins/ship-flow/lib/update-entity-status.sh --entity=<index.md> --new-status=<correct> --if-hash=<sha> --commit-as='docs(ship-flow): catch up #NNN status'\`."
fi

# JSON-escape via python (robust across shells)
esc=$(printf '%s' "$msg" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null)
[ -z "$esc" ] && exit 0

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$esc"
exit 0
