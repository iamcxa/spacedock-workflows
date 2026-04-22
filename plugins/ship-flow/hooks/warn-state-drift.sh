#!/usr/bin/env bash
# ship-flow-hook-version: 1.0.0
# Ship-flow FO state-drift — SessionStart hook
#
# Surfaces entities whose PR is merged on GitHub but whose entity frontmatter
# still has `status: ship` — the "FO state drift" pattern observed 3 times
# the week of 2026-04-20 (catch-up commits f6029c4c, f7a8cacb, plus #030+#037
# hanging at session-start 2026-04-22). Non-blocking advisory.
#
# Triggers on: SessionStart (matcher: "")
# Action:      Advisory — injects additionalContext via hookSpecificOutput
# Exit:        Always 0 (never blocks session start)
# Timeout:     5s set by hooks.json; internal per-PR check capped at 2s

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

# --- 2. gh required for PR merge check ------------------------------------
command -v gh >/dev/null 2>&1 || exit 0

# --- 3. Scan entities for status: ship + pr: #N ---------------------------
drift_lines=""
drift_count=0

# Enumerate entity files — maxdepth 1 = skip _archive/ sub-dir
while IFS= read -r -d '' entity_file; do
  case "$(basename "$entity_file")" in README.md|000-*) continue ;; esac

  status=$(awk '/^---$/{c++; next} c==1 && /^status:/{print $2; exit}' \
            "$entity_file" 2>/dev/null | tr -d '"' | tr -d "'")
  [ "$status" = "ship" ] || continue

  pr=$(awk '/^---$/{c++; next} c==1 && /^pr:/{print $2; exit}' \
        "$entity_file" 2>/dev/null | tr -d '"' | tr -d "'")
  [ -n "$pr" ] && [ "$pr" != "empty" ] && [ "$pr" != "null" ] || continue

  pr_num="${pr##\#}"
  case "$pr_num" in ''|*[!0-9]*) continue ;; esac

  # Check merge state — 2s cap; silent on network/auth failure
  state=$(timeout 2 gh pr view "$pr_num" --json state -q .state 2>/dev/null || true)
  [ "$state" = "MERGED" ] || continue

  slug=$(basename "$entity_file" .md)
  id=$(awk '/^---$/{c++; next} c==1 && /^id:/{print $2; exit}' \
        "$entity_file" 2>/dev/null | tr -d '"' | tr -d "'")
  drift_lines+="  - #${id:-?} \`$slug\` — PR #$pr_num MERGED, entity still at \`status: ship\`"$'\n'
  drift_count=$((drift_count + 1))
done < <(find "$workflow_dir" -maxdepth 1 -type f -name '*.md' -print0 2>/dev/null)

[ "$drift_count" -eq 0 ] && exit 0

# --- 4. Emit structured advisory ------------------------------------------
plural=$([ "$drift_count" -eq 1 ] && echo "entity" || echo "entities")
msg="[ship-flow] FO state-drift: $drift_count $plural with merged PR still at \`status: ship\`:
$drift_lines
Before new execute work, run the Step 3c \`done + archive\` sequence from \`plugins/ship-flow/skills/ship-execute/SKILL.md\` for each. Pattern: PR async-merged while FO session was elsewhere — see week 2026-04-20 debrief Issue #3."

# JSON-escape via python (robust across shells)
esc=$(printf '%s' "$msg" | python3 -c 'import sys,json; print(json.dumps(sys.stdin.read()))' 2>/dev/null)
[ -z "$esc" ] && exit 0

printf '{"hookSpecificOutput":{"hookEventName":"SessionStart","additionalContext":%s}}\n' "$esc"
exit 0
