#!/usr/bin/env bash
# stale-worktree-cleanup-planner.sh - read-only dry-run planner for stale ship-flow worktrees
#
# Usage:
#   bash plugins/ship-flow/bin/stale-worktree-cleanup-planner.sh --status-boot <file>

set -euo pipefail

usage() {
  echo "Usage: stale-worktree-cleanup-planner.sh --status-boot <file>" >&2
  echo "Read-only dry-run only. No worktree, branch, remote, PR, or workflow writes are available." >&2
}

if [ "$#" -ne 2 ] || [ "$1" != "--status-boot" ]; then
  usage
  exit 2
fi

STATUS_BOOT_FILE="$2"

if [ ! -f "$STATUS_BOOT_FILE" ]; then
  echo "BLOCKER status-boot-file: file not found: ${STATUS_BOOT_FILE}"
  exit 2
fi

needs_captain=0

field_value() {
  local key="$1"
  local line="$2"
  awk -v key="$key" -v line="$line" '
    BEGIN {
      n = split(line, fields, /[[:space:]]+/)
      prefix = key "="
      for (i = 1; i <= n; i++) {
        if (index(fields[i], prefix) == 1) {
          value = substr(fields[i], length(prefix) + 1)
          print value
          exit
        }
      }
    }
  '
}

is_done_status() {
  case "$1" in
    done|ship|shipped|completed|closed)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

is_pending_pr() {
  case "$1" in
    OPEN|PENDING|DRAFT|READY|open|pending|draft|ready)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

emit_record() {
  local classification="$1"
  local entity="$2"
  local reason="$3"
  local worktree="$4"
  local branch="$5"
  printf '%s entity=%s reason=%s worktree="%s" branch="%s"\n' "$classification" "$entity" "$reason" "$worktree" "$branch"
}

emit_dry_run() {
  local entity="$1"
  local command="$2"
  printf 'DRY_RUN entity=%s command="%s"\n' "$entity" "$command"
}

while IFS= read -r line || [ -n "$line" ]; do
  case "$line" in
    ""|\#*)
      continue
      ;;
    ORPHAN\ *|WORKTREE\ *)
      ;;
    *)
      continue
      ;;
  esac

  entity="$(field_value entity "$line")"
  status="$(field_value status "$line")"
  worktree="$(field_value worktree "$line")"
  branch="$(field_value branch "$line")"
  local_state="$(field_value local "$line")"
  branch_state="$(field_value branch_state "$line")"
  pr_state="$(field_value pr_state "$line")"
  active="$(field_value active "$line")"

  if [ -z "$entity" ] || [ -z "$worktree" ] || [ -z "$branch" ]; then
    emit_record "NEEDS_CAPTAIN" "${entity:-unknown}" "missing-required-fields" "${worktree:-unknown}" "${branch:-unknown}"
    needs_captain=1
    continue
  fi

  if [ "$local_state" = "missing" ]; then
    emit_record "MISSING_LOCAL" "$entity" "worktree-missing" "$worktree" "$branch"
    emit_dry_run "$entity" "git worktree prune"
    continue
  fi

  if [ "$active" = "yes" ]; then
    emit_record "KEEP_ACTIVE" "$entity" "active-stage-local-exists" "$worktree" "$branch"
    continue
  fi

  if is_pending_pr "$pr_state"; then
    emit_record "KEEP_ACTIVE" "$entity" "pr-pending" "$worktree" "$branch"
    continue
  fi

  if [ "$branch_state" != "merged" ]; then
    emit_record "NEEDS_CAPTAIN" "$entity" "branch-has-unmerged-commits" "$worktree" "$branch"
    needs_captain=1
    continue
  fi

  if is_done_status "$status"; then
    emit_record "CLEANUP_CANDIDATE" "$entity" "entity-done-local-exists" "$worktree" "$branch"
    emit_dry_run "$entity" "git worktree remove '${worktree}'"
    emit_dry_run "$entity" "git branch -d '${branch}'"
  else
    emit_record "KEEP_ACTIVE" "$entity" "nonterminal-status-local-exists" "$worktree" "$branch"
  fi
done < "$STATUS_BOOT_FILE"

exit "$needs_captain"
