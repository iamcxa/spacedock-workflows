#!/usr/bin/env bash
# ship-flow-hook-version: 1.1.0
# Ship-flow FO state-drift — SessionStart hook
#
# Two drift detectors, both advisory-only (never blocks session start):
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
# Also extended to scan folder entities (<slug>/index.md at depth 2), which
# v1.0 missed entirely (maxdepth 1 -type f only caught flat .md files).
#
# Triggers on: SessionStart (matcher: "")
# Action:      Advisory — injects additionalContext via hookSpecificOutput
# Exit:        Always 0
# Timeout:     10s set by hooks.json; Rule A per-PR check capped at 2s;
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
rule_b_lines=""
rule_b_count=0
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

  # Rule A — status=ship + PR merged
  if [ "$status" = "ship" ] && [ "$have_gh" = "1" ] && \
     [ -n "$pr" ] && [ "$pr" != "empty" ] && [ "$pr" != "null" ]; then
    local pr_num="${pr##\#}"
    case "$pr_num" in ''|*[!0-9]*) : ;;
    *)
      local state
      state=$(timeout 2 gh pr view "$pr_num" --json state -q .state 2>/dev/null || true)
      if [ "$state" = "MERGED" ]; then
        rule_a_lines+="  - #${id:-?} \`$slug\` — PR #$pr_num MERGED, entity still at \`status: ship\`"$'\n'
        rule_a_count=$((rule_a_count + 1))
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

# --- 5. Emit structured advisory (only if anything drifted) --------------
[ "$rule_a_count" -eq 0 ] && [ "$rule_b_count" -eq 0 ] && exit 0

msg="[ship-flow] FO state-drift detected:"
if [ "$rule_a_count" -gt 0 ]; then
  plural=$([ "$rule_a_count" -eq 1 ] && echo "entity" || echo "entities")
  msg+="

**Rule A** — $rule_a_count $plural with merged PR still at \`status: ship\`:
$rule_a_lines
Before new execute work, run the \`done + archive\` sequence from \`plugins/ship-flow/skills/ship-execute/SKILL.md\` for each."
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
