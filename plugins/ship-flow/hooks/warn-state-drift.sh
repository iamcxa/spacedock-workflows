#!/usr/bin/env bash
# ship-flow-hook-version: 1.2.0
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
# Auto-fix (v1.2.0, D1 from strengthening-roadmap-2026-05.md):
#
#   Workflow README frontmatter MAY declare `auto_fix: off | execute`
#   (default: `off`). When `execute`, this hook auto-runs the `done + archive`
#   sequence for each Rule A entity that passes a safety re-probe (working
#   tree clean + PR.state == MERGED still holds at exec time). Rule B is
#   NEVER auto-fixed (status-update semantics nuanced; surfaces as WARN).
#
#   Safety guards (any fail → skip auto-fix, fall back to WARN):
#     - working tree clean (uncommitted changes block all auto-fixes)
#     - spacedock status binary discoverable in expected paths
#     - per-entity PR state re-probe matches MERGED
#
#   Output reformats: ✅ Auto-fixed (N) / ⚠️ Auto-fix blocked (M reason) /
#   🔴 Rule A pending (K, auto_fix off or blocked) / 🔴 Rule B (P).
#
# Also extended to scan folder entities (<slug>/index.md at depth 2), which
# v1.0 missed entirely (maxdepth 1 -type f only caught flat .md files).
#
# Triggers on: SessionStart (matcher: "")
# Action:      Advisory by default; optional autonomous fix per workflow config
# Exit:        Always 0
# Timeout:     10s set by hooks.json; Rule A per-PR check capped at 2s;
#              Rule B is local-fs-only (no network) so cheap regardless of
#              entity count. Auto-fix loop adds 2s per entity (re-probe) +
#              ~100ms per entity (status binary + git commit).

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
# Values: off | execute (advise reserved for future; treat as off for v1.2.0).
auto_fix=$(awk '/^---$/{c++; next} c==1 && /^auto_fix:/{print $2; exit}' \
  "$workflow_dir/README.md" 2>/dev/null | tr -d '"' | tr -d "'")
auto_fix="${auto_fix:-off}"

# --- 1c. Safety probe: working tree clean? --------------------------------
# Auto-fix path requires clean tree (atomic commits, no contamination).
git_clean=1
if [ -n "$(git status --porcelain 2>/dev/null)" ]; then
  git_clean=0
fi

# --- 1d. Locate spacedock status binary (needed for auto-fix) -------------
# Same discovery path as commission/bin/status — try plugin cache first.
status_bin=""
if [ "$auto_fix" = "execute" ]; then
  if [ -n "${SHIP_FLOW_STATUS_BIN:-}" ] && [ -x "$SHIP_FLOW_STATUS_BIN" ]; then
    status_bin="$SHIP_FLOW_STATUS_BIN"
  fi
  for candidate in \
      "$HOME"/.claude/plugins/cache/spacedock/spacedock/*/skills/commission/bin/status \
      "$HOME"/.codex/plugins/cache/spacedock/spacedock/*/skills/commission/bin/status; do
    [ -n "$status_bin" ] && break
    [ -x "$candidate" ] && status_bin="$candidate" && break
  done
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
# Per-Rule-A entity records for auto-fix loop. Newline-separated, pipe-
# delimited fields: slug|pr_num|entity_file|stage_dir
# stage_dir is empty for flat .md entities.
rule_a_records=""
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
  local status pr id slug
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
        rule_a_lines+="  - #${id:-?} \`$slug\` — PR #$pr_num MERGED, entity still at \`status: ship\`"$'\n'
        rule_a_count=$((rule_a_count + 1))
        # Record for D1 auto-fix loop (consumed in section 4b below)
        rule_a_records+="$slug|$pr_num|$entity_file|$stage_dir"$'\n'
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
#   - status binary discoverable
#   - at least one Rule A entity detected
# Any pre-condition fails → all Rule A entities flow into "pending" path.
# Per-entity re-probe (PR.state == MERGED) catches detect-time → exec-time race.
auto_fixed_lines=""
auto_fixed_count=0
auto_fix_blocked_lines=""
auto_fix_blocked_count=0
auto_fix_reason=""

if [ "$rule_a_count" -gt 0 ] && [ "$auto_fix" = "execute" ]; then
  if [ "$git_clean" = "0" ]; then
    auto_fix_reason="working tree has uncommitted changes"
  elif [ -z "$status_bin" ]; then
    auto_fix_reason="spacedock status binary not found in expected paths"
  fi

  if [ -z "$auto_fix_reason" ]; then
    # All pre-conditions met. Iterate Rule A entities.
    while IFS='|' read -r slug pr_num entity_file stage_dir; do
      [ -z "$slug" ] && continue

      # Per-entity re-probe (paranoia: detect → exec gap; PR may have unmerged)
      state=$(timeout 2 gh pr view "$pr_num" --json state -q .state 2>/dev/null || true)
      if [ "$state" != "MERGED" ]; then
        auto_fix_blocked_lines+="  - \`$slug\` — re-probe says state=${state:-unknown}, not MERGED (race?); manual fix required"$'\n'
        auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
        continue
      fi

      ts=$(date -u +%FT%TZ)

      # status --set (advance to done + verdict + completed)
      if ! "$status_bin" --workflow-dir "$workflow_dir" \
           --set "$slug" status=done verdict=PASSED completed="$ts" \
           >/dev/null 2>&1; then
        auto_fix_blocked_lines+="  - \`$slug\` — status --set failed"$'\n'
        auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
        continue
      fi

      # status --archive (move to _archive/)
      if ! "$status_bin" --workflow-dir "$workflow_dir" \
           --archive "$slug" >/dev/null 2>&1; then
        auto_fix_blocked_lines+="  - \`$slug\` — status --archive failed after set"$'\n'
        auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
        continue
      fi

      # Determine src + dst pathspec for explicit-pathspec commit
      if [ -n "$stage_dir" ]; then
        src="$stage_dir"
        dst="$workflow_dir/_archive/$slug"
      else
        src="$entity_file"
        dst="$workflow_dir/_archive/$(basename "$entity_file")"
      fi

      if git add -- "$src" "$dst" 2>/dev/null && \
         git commit -m "done + archive: $slug (PR #$pr_num merged, auto-fix from SessionStart hook)" \
             -- "$src" "$dst" >/dev/null 2>&1; then
        auto_fixed_lines+="  - \`$slug\` — PR #$pr_num → status=done verdict=PASSED + archived + committed"$'\n'
        auto_fixed_count=$((auto_fixed_count + 1))
      else
        auto_fix_blocked_lines+="  - \`$slug\` — commit failed (status updated, archive moved, but \`git commit\` errored)"$'\n'
        auto_fix_blocked_count=$((auto_fix_blocked_count + 1))
      fi
    done <<< "$rule_a_records"

    # Subtract auto-fixed from rule_a_lines for clean "pending" reporting
    if [ "$auto_fixed_count" -gt 0 ]; then
      # Rebuild rule_a_lines from records that did NOT auto-fix successfully
      # Simpler approach: zero out rule_a_lines + count, since blocked entities
      # are already tracked in auto_fix_blocked_lines.
      rule_a_lines=""
      rule_a_count=0
    fi
  else
    # Pre-condition failed — surface single blanket reason, no per-entity loop
    auto_fix_blocked_lines+="  - auto-fix skipped for all $rule_a_count Rule A entities ($auto_fix_reason)"$'\n'
    auto_fix_blocked_count=$rule_a_count
    rule_a_lines=""
    rule_a_count=0
  fi
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

✅ **Auto-fixed** ($auto_fixed_count $plural, via \`auto_fix: execute\` workflow config):
$auto_fixed_lines
No action needed — entities are now at \`status: done\` and moved to \`_archive/\`. Each had its own atomic commit on this branch."
fi

# Auto-fix blocked section (D1) — Rule A entities where execute path tripped a guard
if [ "$auto_fix_blocked_count" -gt 0 ]; then
  plural=$([ "$auto_fix_blocked_count" -eq 1 ] && echo "entity" || echo "entities")
  msg+="

⚠️ **Auto-fix blocked** ($auto_fix_blocked_count $plural — execute mode set but pre-condition or re-probe failed):
$auto_fix_blocked_lines
Resolve the blocking reason (commit/stash uncommitted work; verify status binary; re-check PR state) and re-trigger SessionStart, or run the manual \`done + archive\` sequence from \`plugins/ship-flow/skills/ship-execute/SKILL.md\` for each entity."
fi

# Rule A pending section — auto_fix off OR all entities blocked above
if [ "$rule_a_count" -gt 0 ]; then
  plural=$([ "$rule_a_count" -eq 1 ] && echo "entity" || echo "entities")
  msg+="

🔴 **Rule A** — $rule_a_count $plural with merged PR still at \`status: ship\`:
$rule_a_lines
Before new execute work, run the \`done + archive\` sequence from \`plugins/ship-flow/skills/ship-execute/SKILL.md\` for each. To enable autonomous fix in future sessions, set \`auto_fix: execute\` in workflow README frontmatter (D1, see \`plugins/ship-flow/_plans/strengthening-roadmap-2026-05.md\`)."
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
