#!/usr/bin/env bash
# closeout-adapter.sh - reconcile one merged PR into terminal ship-flow state

set -euo pipefail

STATUS_BIN="${STATUS_BIN:-}"

resolve_status_bin() {
  if [ -n "${STATUS_BIN:-}" ]; then
    printf '%s\n' "$STATUS_BIN"
    return 0
  fi
  if [ -n "${SHIP_FLOW_STATUS_BIN:-}" ]; then
    printf '%s\n' "$SHIP_FLOW_STATUS_BIN"
    return 0
  fi

  # The status helper is the `spacedock` Go binary on PATH, invoked as
  # `spacedock status <args>` (see run_status). Resolve the full path so the
  # `-x "$STATUS_BIN"` executable check downstream passes.
  command -v spacedock 2>/dev/null || return 1
}

usage() {
  echo "Usage: closeout-adapter.sh --workflow-dir <dir> --entity <ref> [--pr-provider gh|fixture] [--pr-fixture <path>] [--dry-run]" >&2
}

emit_report() {
  printf 'verdict=%s\n' "$verdict"
  printf 'entity=%s\n' "${entity_slug:-}"
  printf 'pr=%s\n' "${pr_number:-}"
  printf 'pr_state=%s\n' "${pr_state:-UNKNOWN}"
  printf 'terminal_action=%s\n' "${terminal_action:-none}"
  printf 'worktree_cleanup=%s\n' "${worktree_cleanup:-not_applicable}"
  printf 'branch_cleanup=%s\n' "${branch_cleanup:-not_applicable}"
  printf 'reason=%s\n' "${reason:-}"
  printf 'state=%s\n' "${state_name:-}"
  printf 'detail=%s\n' "${detail:-}"
}

reject_usage() {
  verdict="REJECT"
  reason="${1:-usage}"
  detail="${2:-invalid arguments}"
  emit_report
  usage
  exit 2
}

prompt_captain() {
  verdict="PROMPT_CAPTAIN"
  reason="$1"
  detail="$2"
  emit_report
  exit 1
}

reject_input() {
  verdict="REJECT"
  reason="$1"
  detail="$2"
  emit_report
  exit 2
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
        gsub(/^["'\''"]|["'\''"]$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

resolve_line_field() {
  local key="$1"
  local line="$2"
  awk -v key="$key" -v line="$line" '
    BEGIN {
      n = split(line, parts, /[[:space:]]+/)
      prefix = key "="
      for (i = 1; i <= n; i++) {
        if (index(parts[i], prefix) == 1) {
          print substr(parts[i], length(prefix) + 1)
          exit
        }
      }
    }
  '
}

normalize_pr_number() {
  local raw="$1"
  raw="${raw##*#}"
  if [[ "$raw" =~ ^[0-9]+$ ]]; then
    printf '%s\n' "$raw"
    return 0
  fi
  return 1
}

coherent_terminal_file() {
  local file="$1"
  [ "$(read_frontmatter_field "$file" status)" = "done" ] || return 1
  [ "$(read_frontmatter_field "$file" verdict)" = "PASSED" ] || return 1
  [ -n "$(read_frontmatter_field "$file" completed)" ] || return 1
  [ -z "$(read_frontmatter_field "$file" worktree)" ] || return 1
}

run_status() {
  "$STATUS_BIN" status --workflow-dir "$workflow_dir" "$@"
}

resolve_entity() {
  local ref="$1"
  local include_archived="$2"
  local output
  if [ "$include_archived" = "yes" ]; then
    output="$(run_status --archived --resolve "$ref" 2>/dev/null || true)"
  else
    output="$(run_status --resolve "$ref" 2>/dev/null || true)"
  fi
  if [ -z "$output" ]; then
    return 1
  fi
  printf '%s\n' "$output"
}

read_provider_fixture() {
  local fixture="$1"
  [ -f "$fixture" ] || reject_input "missing-pr-fixture" "fixture file not found"

  provider="$(awk -F= '$1=="provider"{print $2; exit}' "$fixture")"
  provider_number="$(awk -F= '$1=="number"{print $2; exit}' "$fixture")"
  pr_state="$(awk -F= '$1=="state"{print $2; exit}' "$fixture")"
  merged_at="$(awk -F= '$1=="merged_at"{print $2; exit}' "$fixture")"
  head_ref="$(awk -F= '$1=="head_ref"{print $2; exit}' "$fixture")"
  base_ref="$(awk -F= '$1=="base_ref"{print $2; exit}' "$fixture")"
  pr_url="$(awk -F= '$1=="url"{print $2; exit}' "$fixture")"

  if [ "$provider" != "fixture" ] || [ -z "$provider_number" ] || [ -z "$pr_state" ]; then
    reject_input "invalid-pr-fixture" "fixture missing required provider fields"
  fi
  if [ "$provider_number" != "$pr_number" ]; then
    reject_input "pr-number-mismatch" "fixture PR number does not match entity"
  fi
}

read_provider_gh() {
  command -v gh >/dev/null 2>&1 || reject_input "missing-gh" "gh CLI is not available"
  local output
  output="$(gh pr view "$pr_number" \
    --json number,state,mergedAt,headRefName,baseRefName,url \
    --jq '["provider=gh", "number=\(.number)", "state=\(.state)", "merged_at=\(.mergedAt // "")", "head_ref=\(.headRefName // "")", "base_ref=\(.baseRefName // "")", "url=\(.url // "")"] | .[]')"
  provider="gh"
  provider_number="$(printf '%s\n' "$output" | awk -F= '$1=="number"{print $2; exit}')"
  pr_state="$(printf '%s\n' "$output" | awk -F= '$1=="state"{print $2; exit}')"
  merged_at="$(printf '%s\n' "$output" | awk -F= '$1=="merged_at"{print $2; exit}')"
  head_ref="$(printf '%s\n' "$output" | awk -F= '$1=="head_ref"{print $2; exit}')"
  base_ref="$(printf '%s\n' "$output" | awk -F= '$1=="base_ref"{print $2; exit}')"
  pr_url="$(printf '%s\n' "$output" | awk -F= '$1=="url"{print $2; exit}')"
  if [ "$provider_number" != "$pr_number" ]; then
    reject_input "pr-number-mismatch" "gh PR number does not match entity"
  fi
}

primary_worktree_root() {
  local worktree_list
  worktree_list="$(git -C "$repo_root" worktree list --porcelain)" || return 1
  awk '/^worktree / { sub(/^worktree /, ""); print; exit }' <<< "$worktree_list"
}

absolute_worktree_path() {
  local primary_root="$1"
  local worktree="$2"
  case "$worktree" in
    /*) printf '%s\n' "$worktree" ;;
    *) printf '%s/%s\n' "$primary_root" "$worktree" ;;
  esac
}

branch_for_worktree_path() {
  local target_path="$1"
  local worktree_list
  worktree_list="$(git -C "$repo_root" worktree list --porcelain)" || return 1
  awk -v target="$target_path" '
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
  ' <<< "$worktree_list"
}

preflight_worktree_cleanup() {
  local worktree_value="$1"
  cleanup_branch=""
  cleanup_worktree_abs=""
  if [ -z "$worktree_value" ]; then
    worktree_cleanup="not_applicable"
    return 0
  fi

  local primary_root worktree_abs branch dirty
  primary_root="$(primary_worktree_root)"
  [ -n "$primary_root" ] || prompt_captain "git-worktree-metadata-unavailable" "unable to read primary worktree"
  worktree_abs="$(absolute_worktree_path "$primary_root" "$worktree_value")"

  if [ ! -d "$worktree_abs" ]; then
    worktree_cleanup="missing-local"
    branch_cleanup="not_applicable"
    return 0
  fi

  branch="$(branch_for_worktree_path "$worktree_abs")"
  [ -n "$branch" ] || prompt_captain "worktree-not-registered" "local worktree path is not registered"
  if [ "$branch" != "$head_ref" ]; then
    prompt_captain "branch-mismatch" "registered worktree branch does not match PR head"
  fi

  dirty="$(git -C "$worktree_abs" status --porcelain)"
  if [ -n "$dirty" ]; then
    prompt_captain "dirty-worktree" "local worktree has uncommitted changes"
  fi

  if [ "$dry_run" = "yes" ]; then
    worktree_cleanup="planned"
    cleanup_branch="$branch"
    cleanup_worktree_abs="$worktree_abs"
    return 0
  fi

  worktree_cleanup="planned"
  cleanup_branch="$branch"
  cleanup_worktree_abs="$worktree_abs"
}

remove_worktree_if_safe() {
  if [ -z "${cleanup_worktree_abs:-}" ]; then
    return 0
  fi
  if git -C "$repo_root" worktree remove "$cleanup_worktree_abs" >/dev/null 2>&1; then
    worktree_cleanup="removed"
  else
    prompt_captain "worktree-remove-failed" "git worktree remove failed"
  fi
}

archive_active_entity() {
  if [ "$dry_run" = "yes" ]; then
    return 0
  fi
  run_status --archive "$entity_slug" >/dev/null
}

verify_archived_entity() {
  run_status --archived --resolve "archive:${entity_slug}" >/dev/null
}

set_terminal_fields() {
  if [ "$dry_run" = "yes" ]; then
    return 0
  fi
  run_status --set "$entity_slug" status=done completed verdict=PASSED worktree= >/dev/null
}

cleanup_branch_if_safe() {
  if [ -z "${cleanup_branch:-}" ]; then
    if [ "$branch_cleanup" = "not_applicable" ]; then
      return 0
    fi
    return 0
  fi
  if [ "$dry_run" = "yes" ]; then
    branch_cleanup="planned"
    return 0
  fi
  if git -C "$repo_root" branch -d "$cleanup_branch" >/dev/null 2>&1; then
    branch_cleanup="deleted"
  else
    branch_cleanup="skipped"
  fi
}

workflow_dir=""
entity_ref=""
pr_provider="gh"
pr_fixture=""
dry_run="no"
verdict=""
entity_slug=""
pr_number=""
pr_state="UNKNOWN"
terminal_action="none"
worktree_cleanup="not_applicable"
branch_cleanup="not_applicable"
reason=""
state_name=""
detail=""
cleanup_branch=""
cleanup_worktree_abs=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workflow-dir)
      [ "$#" -ge 2 ] || reject_usage "missing-workflow-dir" "--workflow-dir requires a path"
      workflow_dir="$2"
      shift 2
      ;;
    --entity)
      [ "$#" -ge 2 ] || reject_usage "missing-entity" "--entity requires a reference"
      entity_ref="$2"
      shift 2
      ;;
    --pr-provider)
      [ "$#" -ge 2 ] || reject_usage "missing-pr-provider" "--pr-provider requires gh or fixture"
      pr_provider="$2"
      shift 2
      ;;
    --pr-fixture)
      [ "$#" -ge 2 ] || reject_usage "missing-pr-fixture" "--pr-fixture requires a path"
      pr_fixture="$2"
      shift 2
      ;;
    --dry-run)
      dry_run="yes"
      shift
      ;;
    --*)
      reject_usage "unsupported-argument" "unsupported argument: $1"
      ;;
    *)
      reject_usage "unexpected-argument" "unexpected argument: $1"
      ;;
  esac
done

[ -n "$workflow_dir" ] || reject_usage "missing-workflow-dir" "--workflow-dir is required"
[ -n "$entity_ref" ] || reject_usage "missing-entity" "--entity is required"
[ -d "$workflow_dir" ] || reject_input "workflow-dir-not-found" "workflow directory not found"
STATUS_BIN="$(resolve_status_bin || true)"
[ -x "$STATUS_BIN" ] || reject_input "missing-status-helper" "status helper is not executable"
case "$pr_provider" in
  gh|fixture) ;;
  *) reject_usage "unsupported-pr-provider" "--pr-provider must be gh or fixture" ;;
esac
if [ "$pr_provider" = "fixture" ] && [ -z "$pr_fixture" ]; then
  reject_usage "missing-pr-fixture" "--pr-fixture is required for fixture provider"
fi

repo_root="$(git -C "$workflow_dir" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || reject_input "workflow-dir-not-in-git" "workflow directory is not in a git repository"

active_resolve="$(resolve_entity "$entity_ref" no || true)"
if [ -z "$active_resolve" ]; then
  archived_resolve="$(resolve_entity "archive:${entity_ref}" yes || true)"
  if [ -z "$archived_resolve" ]; then
    reject_input "entity-not-found" "entity reference could not be resolved"
  fi
  entity_slug="$(resolve_line_field slug "$archived_resolve")"
  entity_path="$(resolve_line_field path "$archived_resolve")"
  if coherent_terminal_file "$entity_path"; then
    verdict="PROCEED"
    state_name="already_reconciled"
    terminal_action="already_reconciled"
    pr_state="MERGED"
    pr_number="$(normalize_pr_number "$(read_frontmatter_field "$entity_path" pr)" || true)"
    detail="archived entity is already terminal and coherent"
    emit_report
    exit 0
  fi
  prompt_captain "archived-terminal-incoherent" "archived entity is missing coherent terminal fields"
fi

entity_slug="$(resolve_line_field slug "$active_resolve")"
entity_path="$(resolve_line_field path "$active_resolve")"
pr_raw="$(read_frontmatter_field "$entity_path" pr)"
[ -n "$pr_raw" ] || reject_input "missing-pr" "entity has no pr field"
pr_number="$(normalize_pr_number "$pr_raw" || true)"
[ -n "$pr_number" ] || reject_input "invalid-pr" "entity pr field is not a recognizable PR number"
worktree_value="$(read_frontmatter_field "$entity_path" worktree)"

if coherent_terminal_file "$entity_path"; then
  terminal_action="archive"
  if [ "$dry_run" = "no" ]; then
    archive_active_entity
    verify_archived_entity
    state_name="already_done_archived_now"
    detail="active terminal entity archived"
  else
    state_name="already_done_archive_planned"
    detail="active terminal entity archive planned"
  fi
  verdict="PROCEED"
  pr_state="MERGED"
  emit_report
  exit 0
fi

case "$pr_provider" in
  fixture) read_provider_fixture "$pr_fixture" ;;
  gh) read_provider_gh ;;
esac

case "$pr_state" in
  OPEN)
    verdict="PROCEED"
    state_name="pr_open_noop"
    reason="pr-open"
    detail="PR is still open"
    emit_report
    exit 0
    ;;
  MERGED)
    [ -n "$merged_at" ] || reject_input "merged-at-missing" "merged PR state requires merged_at"
    ;;
  CLOSED|UNKNOWN|"")
    prompt_captain "pr-not-merged" "PR is not merged"
    ;;
  *)
    prompt_captain "pr-state-unsupported" "PR state is not supported"
    ;;
esac

preflight_worktree_cleanup "$worktree_value"
terminal_action="set_done"

if [ "$dry_run" = "no" ]; then
  set_terminal_fields
  archive_active_entity
  verify_archived_entity
  remove_worktree_if_safe
fi

cleanup_branch_if_safe

verdict="PROCEED"
reason="merged-pr-reconciled"
state_name="reconciled"
detail="merged PR reconciled to terminal archived entity state"
emit_report
exit 0
