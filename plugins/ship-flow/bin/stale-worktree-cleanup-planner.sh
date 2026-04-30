#!/usr/bin/env bash
# stale-worktree-cleanup-planner.sh - read-only dry-run planner for stale ship-flow worktrees
#
# Usage:
#   bash plugins/ship-flow/bin/stale-worktree-cleanup-planner.sh --status-boot <file>
#   bash plugins/ship-flow/bin/stale-worktree-cleanup-planner.sh --workflow-dir <dir>

set -euo pipefail

usage() {
  echo "Usage: stale-worktree-cleanup-planner.sh --status-boot <file> | --workflow-dir <dir>" >&2
  echo "Read-only dry-run only. No worktree, branch, remote, PR, or workflow writes are available." >&2
}

if [ "$#" -ne 2 ]; then
  usage
  exit 2
fi

MODE="$1"
INPUT_PATH="$2"

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

read_frontmatter_field() {
  local file="$1"
  local key="$2"
  awk -v key="$key" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = key ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^["'\'']|["'\'']$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

primary_worktree_root() {
  local repo_root="$1"
  git -C "$repo_root" worktree list --porcelain | awk '/^worktree / { sub(/^worktree /, ""); print; exit }'
}

branch_for_worktree_path() {
  local repo_root="$1"
  local target_path="$2"
  git -C "$repo_root" worktree list --porcelain | awk -v target="$target_path" '
    /^worktree / {
      current = $0
      sub(/^worktree /, "", current)
      next
    }
    /^branch refs\/heads\// && current == target {
      branch = $0
      sub(/^branch refs\/heads\//, "", branch)
      print branch
      exit
    }
  '
}

base_ref_for_repo() {
  local repo_root="$1"
  if git -C "$repo_root" rev-parse --verify --quiet refs/remotes/origin/main >/dev/null; then
    echo "refs/remotes/origin/main"
  elif git -C "$repo_root" rev-parse --verify --quiet refs/heads/main >/dev/null; then
    echo "refs/heads/main"
  elif git -C "$repo_root" rev-parse --verify --quiet refs/remotes/origin/master >/dev/null; then
    echo "refs/remotes/origin/master"
  elif git -C "$repo_root" rev-parse --verify --quiet refs/heads/master >/dev/null; then
    echo "refs/heads/master"
  else
    echo "HEAD"
  fi
}

absolute_worktree_path() {
  local primary_root="$1"
  local worktree="$2"
  case "$worktree" in
    /*)
      printf '%s\n' "$worktree"
      ;;
    *)
      printf '%s/%s\n' "$primary_root" "$worktree"
      ;;
  esac
}

branch_state_for_workflow_row() {
  local repo_root="$1"
  local branch="$2"
  local base_ref="$3"
  if [ -z "$branch" ]; then
    echo "unknown"
  elif ! git -C "$repo_root" show-ref --verify --quiet "refs/heads/${branch}"; then
    echo "unknown"
  elif git -C "$repo_root" merge-base --is-ancestor "$branch" "$base_ref"; then
    echo "merged"
  else
    echo "unmerged"
  fi
}

classify_workflow_row() {
  local entity="$1"
  local status="$2"
  local worktree="$3"
  local branch="$4"
  local local_state="$5"
  local branch_state="$6"
  local pr="$7"

  if [ "$local_state" = "missing" ]; then
    emit_record "MISSING_LOCAL" "$entity" "worktree-missing" "$worktree" "${branch:-unknown}"
    return
  fi

  if [ -n "$pr" ] && ! is_done_status "$status"; then
    emit_record "KEEP_ACTIVE" "$entity" "pr-pending" "$worktree" "${branch:-unknown}"
    return
  fi

  if ! is_done_status "$status"; then
    emit_record "KEEP_ACTIVE" "$entity" "nonterminal-status-local-exists" "$worktree" "${branch:-unknown}"
    return
  fi

  if [ "$branch_state" = "unknown" ]; then
    emit_record "NEEDS_CAPTAIN" "$entity" "branch-safety-unknown" "$worktree" "${branch:-unknown}"
    needs_captain=1
    return
  fi

  if [ "$branch_state" != "merged" ]; then
    emit_record "NEEDS_CAPTAIN" "$entity" "branch-has-unmerged-commits" "$worktree" "$branch"
    needs_captain=1
    return
  fi

  emit_record "CLEANUP_CANDIDATE" "$entity" "entity-done-local-exists" "$worktree" "$branch"
  emit_dry_run "$entity" "git worktree remove '${worktree}'"
  emit_dry_run "$entity" "git branch -d '${branch}'"
}

run_status_boot_mode() {
  local status_boot_file="$1"
  if [ ! -f "$status_boot_file" ]; then
    echo "BLOCKER status-boot-file: file not found: ${status_boot_file}"
    exit 2
  fi

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
  done < "$status_boot_file"
}

run_workflow_dir_mode() {
  local workflow_dir="$1"
  if [ ! -d "$workflow_dir" ]; then
    echo "BLOCKER workflow-dir: directory not found: ${workflow_dir}"
    exit 2
  fi

  local repo_root primary_root base_ref
  repo_root="$(git -C "$workflow_dir" rev-parse --show-toplevel 2>/dev/null || true)"
  if [ -z "$repo_root" ]; then
    echo "BLOCKER workflow-dir: not inside a git repository: ${workflow_dir}"
    exit 2
  fi

  primary_root="$(primary_worktree_root "$repo_root")"
  if [ -z "$primary_root" ]; then
    echo "BLOCKER git-worktrees: unable to read git worktree metadata"
    exit 2
  fi

  base_ref="$(base_ref_for_repo "$repo_root")"

  local index_file entity status worktree pr worktree_abs branch local_state branch_state
  while IFS= read -r index_file; do
    entity="$(basename "$(dirname "$index_file")")"
    status="$(read_frontmatter_field "$index_file" status)"
    worktree="$(read_frontmatter_field "$index_file" worktree)"
    pr="$(read_frontmatter_field "$index_file" pr)"

    if [ -z "$worktree" ]; then
      continue
    fi

    worktree_abs="$(absolute_worktree_path "$primary_root" "$worktree")"
    branch="$(branch_for_worktree_path "$repo_root" "$worktree_abs")"
    if [ -d "$worktree_abs" ]; then
      local_state="present"
    else
      local_state="missing"
    fi
    branch_state="$(branch_state_for_workflow_row "$repo_root" "$branch" "$base_ref")"
    classify_workflow_row "$entity" "$status" "$worktree" "$branch" "$local_state" "$branch_state" "$pr"
  done < <(find "$workflow_dir" -mindepth 2 -maxdepth 2 -name index.md -type f | sort)
}

case "$MODE" in
  --status-boot)
    run_status_boot_mode "$INPUT_PATH"
    ;;
  --workflow-dir)
    run_workflow_dir_mode "$INPUT_PATH"
    ;;
  *)
    usage
    exit 2
    ;;
esac

exit "$needs_captain"
