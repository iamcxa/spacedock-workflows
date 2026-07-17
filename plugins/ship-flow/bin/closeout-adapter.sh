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
  if [ -n "${SPACEDOCK_BIN:-}" ]; then
    printf '%s\n' "$SPACEDOCK_BIN"
    return 0
  fi

  # The status/merge-guard helper is the one `spacedock` Go binary on PATH,
  # invoked as `spacedock status <args>` (see run_status) or
  # `spacedock merge guard <args>` (see run_merge_guard). Resolve the full
  # path so the `-x "$STATUS_BIN"` executable check downstream passes, and so
  # both call sites share one validated binary (matches the ${SPACEDOCK_BIN:-
  # spacedock} launcher convention).
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
  printf 'debrief_due=%s\n' "${debrief_due:-}"
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
  # verdict is compared case-insensitively: the real `spacedock merge guard`
  # 0.25.0 writes the verdict verbatim as passed to `--verdict passed` (i.e.
  # lowercase `passed`), while some historical/stub writers used `PASSED`.
  local verdict_lc
  verdict_lc="$(read_frontmatter_field "$file" verdict | tr '[:upper:]' '[:lower:]')"
  [ "$(read_frontmatter_field "$file" status)" = "done" ] || return 1
  [ "$verdict_lc" = "passed" ] || return 1
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
  # head_ref is only available when this run went through a provider lookup
  # (fresh MERGED confirmation). On a sentinel-resume run (pr: already
  # pr-merge:{N}, provider lookup skipped) head_ref is empty, so this
  # cross-check is skipped rather than false-failing every resume.
  if [ -n "$head_ref" ] && [ "$branch" != "$head_ref" ]; then
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

# sentinel_pr_number - detect an already-persisted write-ahead sentinel
# (pr: pr-merge:{N}). A resumed run (dirty-tree/wrong-branch deferred a prior
# attempt after the sentinel was already committed) finds this instead of a
# bare PR ref and must skip the provider re-check entirely (A3: the sentinel
# IS the durable "confirmed MERGED" fact; re-probing gh/fixture again is
# unnecessary and would reject the already-normalized pr value).
sentinel_pr_number() {
  local raw="$1"
  if [[ "$raw" =~ ^pr-merge:([0-9]+)$ ]]; then
    printf '%s\n' "${BASH_REMATCH[1]}"
    return 0
  fi
  return 1
}

# run_merge_guard - delegate the terminal mutation to the single closeout
# authority (DC-2: this adapter never sets the terminal status or archives an
# entity via a raw status-tool call itself). Captures combined stdout+stderr
# and exit code for interpretation by the caller against the 4
# empirically-pinned outcomes.
run_merge_guard() {
  "$STATUS_BIN" merge guard "$entity_slug" --verdict passed --workflow-dir "$workflow_dir" 2>&1
}

# write_sentinel_ahead - write-ahead durability marker (A3). A plain
# sentinel-only field write always succeeds regardless of merge-hook
# registration; the path-scoped commit survives a dirty-tree-elsewhere or
# wrong-branch bail-out immediately after, so a later clean run resumes from
# the sentinel instead of re-probing the PR provider.
write_sentinel_ahead() {
  run_status --set "$entity_slug" "pr=pr-merge:${pr_number}" >/dev/null
  git -C "$repo_root" add -- "$entity_path" >/dev/null 2>&1 || true
  git -C "$repo_root" commit -m "closeout: record pr-merge sentinel for $entity_slug (PR #$pr_number merged)" \
      -- "$entity_path" >/dev/null 2>&1 || true
}

# current_branch_is_safe_for_commit - R2: the wrong-branch safety gate.
# Blocks committing the closeout ONLY when the repo's current checked-out
# branch is neither (a) the primary worktree's branch (the common case:
# main/master, where hook- and mod-driven closeout normally runs) nor (b)
# this entity's OWN registered worktree branch (self-closeout from inside a
# legitimate worktree-per-entity setup, where differing from main is expected
# and safe). A third, unrelated branch left checked out in a shared working
# copy is refused — this is deliberately NOT "block every non-main branch".
current_branch_is_safe_for_commit() {
  local current primary_root primary_branch worktree_abs entity_branch
  current="$(git -C "$repo_root" rev-parse --abbrev-ref HEAD 2>/dev/null || true)"
  [ -n "$current" ] && [ "$current" != "HEAD" ] || return 1

  primary_root="$(primary_worktree_root 2>/dev/null || true)"
  if [ -n "$primary_root" ]; then
    primary_branch="$(branch_for_worktree_path "$primary_root" 2>/dev/null || true)"
    if [ -n "$primary_branch" ] && [ "$current" = "$primary_branch" ]; then
      return 0
    fi
  fi

  if [ -n "$worktree_value" ]; then
    worktree_abs="$(absolute_worktree_path "$primary_root" "$worktree_value")"
    entity_branch="$(branch_for_worktree_path "$worktree_abs" 2>/dev/null || true)"
    if [ -n "$entity_branch" ] && [ "$current" = "$entity_branch" ]; then
      return 0
    fi
  fi

  return 1
}

# repo_dirty - the repo-root-wide dirty gate (R2/DC-4): catches genuinely
# unrelated uncommitted work anywhere in the repo. The entity's OWN
# registered worktree subtree is excluded from this scan -- a linked git
# worktree living inside the main tree (the normal worktree-per-entity
# layout) shows up as an untracked `??` path from the primary repo's own
# `git status` whenever it isn't (or can't be) gitignored, which would
# otherwise false-positive this gate on every legitimate in-flight entity.
# That subtree gets its own, purpose-built dirty check via
# preflight_worktree_cleanup right after this gate.
repo_dirty() {
  local porcelain
  if [ -n "$worktree_value" ]; then
    porcelain="$(git -C "$repo_root" status --porcelain -- . ":(exclude)${worktree_value}" 2>/dev/null || true)"
  else
    porcelain="$(git -C "$repo_root" status --porcelain 2>/dev/null || true)"
  fi
  [ -n "$porcelain" ]
}

# archive_pathspec_for_entity - compute the active->archive git pathspec for
# the entity's on-disk layout (folder `<slug>/index.md` vs flat `<slug>.md`),
# mirroring the archive-move convention `spacedock merge guard` itself uses.
# Sets archive_src / archive_dst.
archive_pathspec_for_entity() {
  case "$entity_path" in
    */index.md)
      archive_src="$(dirname "$entity_path")"
      archive_dst="${workflow_dir}/_archive/${entity_slug}"
      ;;
    *)
      archive_src="$entity_path"
      archive_dst="${workflow_dir}/_archive/$(basename "$entity_path")"
      ;;
  esac
}

# attempt_archive_commit_retry - R4 recovery. `spacedock merge guard`'s own
# terminal mutation (the filesystem move to _archive/ + terminalized
# frontmatter) is NOT rolled back if the caller's own archive-move commit
# subsequently fails (e.g. disk full, hook rejection) — merge guard's own
# contract already treats the archived state as idempotent-replay-safe ("archived
# entity is read-only"), so rolling the FS move back here would fight that
# contract and risk racing a concurrent writer. Instead, every path that finds
# an already-archived, coherent entity retries the pending commit here: a
# clean git state is a true no-op (nothing to commit); an uncommitted pending
# move is committed now. Either way, a later clean run converges without any
# separate rollback mechanism.
attempt_archive_commit_retry() {
  local dst
  case "$entity_path" in
    */index.md) dst="$(dirname "$entity_path")" ;;
    *) dst="$entity_path" ;;
  esac
  [ "$dry_run" = "no" ] || return 0
  git -C "$repo_root" add -- "$dst" >/dev/null 2>&1 || true
  if [ -n "$(git -C "$repo_root" status --porcelain -- "$dst" 2>/dev/null || true)" ]; then
    git -C "$repo_root" commit -m "done + archive: $entity_slug (recovered pending archive-move commit)" \
        -- "$dst" >/dev/null 2>&1 || true
  fi
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
head_ref=""
debrief_due=""

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
    # R4 recovery: the archive-move may already be on disk without a
    # completed git commit (a prior run's archive-move commit step failed
    # after `spacedock merge guard` had already finalized it). Retry that
    # commit before reporting the no-op -- a clean tree is a true no-op,
    # an uncommitted pending move is committed now.
    attempt_archive_commit_retry
    verdict="PROCEED"
    state_name="already_reconciled"
    terminal_action="already_reconciled"
    pr_state="MERGED"
    pr_number="$(sentinel_pr_number "$(read_frontmatter_field "$entity_path" pr)" 2>/dev/null || \
      normalize_pr_number "$(read_frontmatter_field "$entity_path" pr)" 2>/dev/null || true)"
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
worktree_value="$(read_frontmatter_field "$entity_path" worktree)"

sentinel_already_present="no"
if pr_number="$(sentinel_pr_number "$pr_raw")"; then
  # Resume: a prior run already wrote+committed the write-ahead sentinel (A3)
  # and was deferred by the dirty-tree/wrong-branch gate below. The sentinel
  # is itself the durable "confirmed MERGED" fact -- do not re-probe the PR
  # provider.
  sentinel_already_present="yes"
  pr_state="MERGED"
else
  pr_number="$(normalize_pr_number "$pr_raw" || true)"
  [ -n "$pr_number" ] || reject_input "invalid-pr" "entity pr field is not a recognizable PR number"

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
fi

# From here: pr_state=MERGED, pr_number validated -- either freshly confirmed
# via the PR provider, or resumed from an already-persisted sentinel.

if [ "$dry_run" = "yes" ]; then
  preflight_worktree_cleanup "$worktree_value"
  cleanup_branch_if_safe
  verdict="PROCEED"
  terminal_action="merge_guard_delegate"
  state_name="dry_run_planned"
  detail="dry-run: would record the pr-merge sentinel (if not already present) and delegate to spacedock merge guard"
  emit_report
  exit 0
fi

if ! current_branch_is_safe_for_commit; then
  verdict="PROCEED"
  terminal_action="deferred"
  state_name="closeout-deferred-wrong-branch"
  reason="wrong-branch"
  detail="repo HEAD is on a branch that is neither the primary worktree's branch nor this entity's own registered worktree branch; closeout deferred until a correctly-branched run"
  emit_report
  exit 0
fi

# Entity's OWN feature worktree/branch readiness (pre-existing mechanic,
# unrelated to the repo-root wrong-branch/dirty-tree gates below -- this
# checks the SEPARATE git worktree the entity itself was built in, if any).
# Deliberately ordered BEFORE the sentinel write-ahead: a prompt_captain here
# (not registered / branch mismatch / dirty) is a full captain escalation
# needing manual resolution, not an auto-resumable defer, so it must leave
# the workflow completely untouched (no sentinel, no commit) -- unlike the
# repo-root gates below, which write-ahead first because they auto-resume on
# their own once the caller re-runs after clearing the blocker.
preflight_worktree_cleanup "$worktree_value"

if [ "$sentinel_already_present" = "no" ]; then
  write_sentinel_ahead
fi

if repo_dirty; then
  verdict="PROCEED"
  terminal_action="deferred"
  state_name="closeout-deferred-dirty-tree"
  reason="dirty-worktree"
  detail="repo has uncommitted changes outside the sentinel write; closeout deferred until a clean run"
  emit_report
  exit 0
fi

merge_guard_rc=0
merge_guard_output="$(run_merge_guard)" || merge_guard_rc=$?

case "$merge_guard_output" in
  finalized:*)
    archive_pathspec_for_entity
    # spacedock merge guard (real binary, inside a git repo) performs the
    # archive move AND commits it itself ("archive <slug> (merge guard)"). A
    # move-without-commit variant (or a test stub) can instead leave the move
    # pending. Success is therefore defined by the resulting STATE -- the
    # archive-move is committed (nothing pending for the archive paths) -- NOT
    # by whether OUR own commit added anything. Defensively stage+commit any
    # pending move; a no-op commit when merge guard already committed is
    # expected and ignored.
    git -C "$repo_root" add -- "$archive_src" "$archive_dst" >/dev/null 2>&1 || true
    git -C "$repo_root" commit -m "done + archive: $entity_slug (PR #$pr_number merged via spacedock merge guard)" \
        -- "$archive_src" "$archive_dst" >/dev/null 2>&1 || true
    if [ -z "$(git -C "$repo_root" status --porcelain -- "$archive_src" "$archive_dst" 2>/dev/null || true)" ]; then
      remove_worktree_if_safe
      cleanup_branch_if_safe
      verdict="PROCEED"
      terminal_action="merge_guard_finalized"
      reason="merged-pr-reconciled"
      state_name="reconciled"
      detail="spacedock merge guard finalized $entity_slug (verdict passed) and archived it"
      debrief_due="$entity_slug"
      pr_state="MERGED"
      emit_report
      exit 0
    else
      # R4: the archive move is genuinely still pending (our commit was
      # rejected, e.g. a pre-commit hook). merge guard's own filesystem
      # mutation is NOT rolled back -- rolling back would fight its idempotent
      # read-only-replay contract ("archived entity is read-only") and risk
      # racing a concurrent writer. Re-run retries the commit (the
      # `*read-only*` branch below, or the archived-resolve fast path at the
      # top of this script) and converges cleanly without a separate rollback.
      verdict="PROCEED"
      terminal_action="archive_commit_pending"
      state_name="closeout-archive-commit-failed-recoverable"
      reason="archive-commit-failed"
      detail="spacedock merge guard finalized $entity_slug but the archive-move commit is still pending; on-disk state matches merge guard's output, re-run to retry the commit"
      emit_report
      exit 1
    fi
    ;;
  blocked:*)
    verdict="PROCEED"
    state_name="await-pr-sentinel-resume"
    reason="merge-guard-blocked"
    detail="spacedock merge guard reports the PR is still pending; no mutation attempted"
    emit_report
    exit 0
    ;;
  *"read-only"*)
    archive_pathspec_for_entity
    entity_path="$archive_dst"
    attempt_archive_commit_retry
    verdict="PROCEED"
    state_name="already_reconciled"
    terminal_action="already_reconciled"
    reason="merge-guard-archived-read-only"
    detail="spacedock merge guard reports the entity is already archived; treated as idempotent no-op"
    pr_state="MERGED"
    emit_report
    exit 0
    ;;
  *)
    verdict="REJECT"
    reason="state-driver-unavailable"
    state_name="state-driver-unavailable"
    detail="spacedock merge guard did not return a recognized outcome (rc=${merge_guard_rc}): ${merge_guard_output}"
    emit_report
    echo "state-driver unavailable: ${detail}" >&2
    exit 1
    ;;
esac
