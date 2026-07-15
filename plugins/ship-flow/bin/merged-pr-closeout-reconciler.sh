#!/usr/bin/env bash
# merged-pr-closeout-reconciler.sh - reconcile one merged PR into terminal ship-flow state

set -euo pipefail

STATUS_BIN="${STATUS_BIN:-}"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/.." &>/dev/null && pwd)"
LANDING_RESOLVER="${PLUGIN_ROOT}/lib/resolve-landing-envelope.sh"
BUNDLE_APPLIER="${PLUGIN_ROOT}/lib/apply-closeout-bundle.sh"
RECEIPT_VALIDATOR="${PLUGIN_ROOT}/lib/validate-closeout-receipt.py"
DEBRIEF_VALIDATOR="${PLUGIN_ROOT}/lib/__tests__/validate-debrief-schema.sh"

source_object_store=""
source_object_binding=""
source_object_store_ref="refs/ship-flow/closeout-source"
source_object_target_repos=()
source_object_target_refs=()
source_object_target_tips=()

# shellcheck disable=SC2329 # Invoked indirectly by the EXIT trap.
cleanup_source_object_acquisition() {
  local status=$? index=0
  trap - EXIT HUP INT QUIT TERM
  while [ "$index" -lt "${#source_object_target_repos[@]}" ]; do
    git -C "${source_object_target_repos[$index]}" update-ref -d \
      "${source_object_target_refs[$index]}" "${source_object_target_tips[$index]}" >/dev/null 2>&1 || true
    index=$((index + 1))
  done
  [ -z "$source_object_store" ] || rm -rf "$source_object_store"
  exit "$status"
}

trap cleanup_source_object_acquisition EXIT
trap 'exit 129' HUP
trap 'exit 130' INT
trap 'exit 131' QUIT
trap 'exit 143' TERM

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
  echo "Usage: merged-pr-closeout-reconciler.sh --workflow-dir <dir> --entity <ref> [--closeout-mode direct|pull-request] [--pr-provider gh|fixture] [--pr-fixture <path>] [--dry-run]" >&2
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
    NR == 1 {
      if ($0 != "---") { invalid=1; exit }
      in_frontmatter=1
      next
    }
    in_frontmatter && $0 == "---" { closed=1; in_frontmatter=0; exit }
    in_frontmatter {
      prefix = key ":"
      if (!found && index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^["'\''"]|["'\''"]$/, "", value)
        found=1
      }
    }
    END { if (!invalid && closed && found) print value }
  ' "$file"
}

valid_frontmatter() {
  awk '
    NR == 1 { if ($0 != "---") exit 1; opened=1; next }
    opened && $0 == "---" { closed=1; exit }
    END { if (!closed) exit 1 }
  ' "$1" >/dev/null
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
  repository="$(awk -F= '$1=="repository"{sub(/^[^=]*=/, ""); print; exit}' "$fixture")"
  landing_anchor="$(awk -F= '$1=="landing_anchor"{print $2; exit}' "$fixture")"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$fixture")"
  pr_commit_count="$(awk -F= '$1=="pr_commit_count"{print $2; exit}' "$fixture")"

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
  repository="$(gh repo view --json nameWithOwner --jq '.nameWithOwner')"
  output="$(gh pr view "$pr_number" --repo "$repository" \
    --json number,state,mergedAt,headRefName,baseRefName,url,mergeCommit,commits \
    --jq '["provider=gh", "number=\(.number)", "state=\(.state)", "merged_at=\(.mergedAt // "")", "head_ref=\(.headRefName // "")", "base_ref=\(.baseRefName // "")", "url=\(.url // "")", "landing_anchor=\(.mergeCommit.oid // "")", "source_commits=\([.commits[].oid] | join(","))", "pr_commit_count=\(.commits | length)"] | .[]')"
  provider="gh"
  provider_number="$(printf '%s\n' "$output" | awk -F= '$1=="number"{print $2; exit}')"
  pr_state="$(printf '%s\n' "$output" | awk -F= '$1=="state"{print $2; exit}')"
  merged_at="$(printf '%s\n' "$output" | awk -F= '$1=="merged_at"{print $2; exit}')"
  head_ref="$(printf '%s\n' "$output" | awk -F= '$1=="head_ref"{print $2; exit}')"
  base_ref="$(printf '%s\n' "$output" | awk -F= '$1=="base_ref"{print $2; exit}')"
  pr_url="$(printf '%s\n' "$output" | awk -F= '$1=="url"{print $2; exit}')"
  : "$pr_url"
  landing_anchor="$(printf '%s\n' "$output" | awk -F= '$1=="landing_anchor"{print $2; exit}')"
  source_commits="$(printf '%s\n' "$output" | awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}')"
  pr_commit_count="$(printf '%s\n' "$output" | awk -F= '$1=="pr_commit_count"{print $2; exit}')"
  if [ "$provider_number" != "$pr_number" ]; then
    reject_input "pr-number-mismatch" "gh PR number does not match entity"
  fi
}

normalize_github_remote_repository() {
  local value="$1" path
  value="${value%/}"
  case "$value" in
    https://github.com/*) path="${value#https://github.com/}" ;;
    git@github.com:*) path="${value#git@github.com:}" ;;
    ssh://git@github.com/*) path="${value#ssh://git@github.com/}" ;;
    ssh://github.com/*) path="${value#ssh://github.com/}" ;;
    *) return 1 ;;
  esac
  path="${path%.git}"
  case "$path" in
    */*) [ "${path#*/}" = "${path##*/}" ] || return 1 ;;
    *) return 1 ;;
  esac
  [[ "$path" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]] || return 1
  printf '%s\n' "$path"
}

resolve_provider_source_remote() {
  local candidate raw normalized normalized_fold repository_fold remotes
  source_remote_name=""
  source_remote_url=""
  remotes="$(git -C "$repo_root" remote)"
  repository_fold="$(printf '%s' "$repository" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
  for candidate in origin $remotes; do
    [ -n "$candidate" ] || continue
    [ "$candidate" != origin ] || git -C "$repo_root" config --get remote.origin.url >/dev/null 2>&1 || continue
    [ "$candidate" = origin ] || [ "$candidate" != "$source_remote_name" ] || continue
    raw="$(git -C "$repo_root" config --get "remote.${candidate}.url" 2>/dev/null || true)"
    [ -n "$raw" ] || continue
    normalized="$(normalize_github_remote_repository "$raw" 2>/dev/null || true)"
    normalized_fold="$(printf '%s' "$normalized" | LC_ALL=C tr '[:upper:]' '[:lower:]')"
    [ -n "$normalized" ] && [ "$normalized_fold" = "$repository_fold" ] || continue
    source_remote_name="$candidate"
    source_remote_url="$(git -C "$repo_root" remote get-url "$candidate" 2>/dev/null || true)"
    [ -n "$source_remote_url" ] || continue
    return 0
  done
  return 1
}

validate_source_object_set() {
  local target_repo="$1" expected_tip="$2" ordered_oids="$3" expected_count="$4"
  local source_oids=() source_oid first_parent
  IFS=',' read -r -a source_oids <<< "$ordered_oids"
  [ "${#source_oids[@]}" -eq "$expected_count" ] || return 1
  for source_oid in "${source_oids[@]}"; do
    [[ "$source_oid" =~ ^[0-9a-f]{40}$ ]] || return 1
    git -C "$target_repo" cat-file -e "${source_oid}^{commit}" 2>/dev/null || return 1
    git -C "$target_repo" merge-base --is-ancestor "$source_oid" "$expected_tip" 2>/dev/null || return 1
  done
  first_parent="$(git -C "$target_repo" rev-parse --verify "${source_oids[0]}^1" 2>/dev/null || true)"
  [ -n "$first_parent" ] && git -C "$target_repo" cat-file -e "${first_parent}^{commit}" 2>/dev/null
}

materialize_acquired_source_objects() {
  local target_repo="$1" binding_hash target_ref import_out import_rc=0 expected_tip imported_tip="" index=0 nonce
  local source_oids=()
  IFS=',' read -r -a source_oids <<< "$source_commits"
  expected_tip="${source_oids[$((${#source_oids[@]} - 1))]}"

  if [ "$pr_provider" = fixture ]; then
    validate_source_object_set "$target_repo" "$expected_tip" "$source_commits" "$pr_commit_count" ||
      reject_input landing-patch-equivalence-failed "authoritative implementation PR source objects are unavailable"
    return 0
  fi

  while [ "$index" -lt "${#source_object_target_repos[@]}" ]; do
    if [ "${source_object_target_repos[$index]}" = "$target_repo" ] &&
       [ "$(git -C "$target_repo" rev-parse --verify "${source_object_target_refs[$index]}^{commit}" 2>/dev/null || true)" = "$expected_tip" ]; then
      validate_source_object_set "$target_repo" "$expected_tip" "$source_commits" "$pr_commit_count" ||
        reject_input landing-patch-equivalence-failed "cached implementation PR source objects do not match provider OIDs"
      return 0
    fi
    index=$((index + 1))
  done

  binding_hash="$(printf '%s' "$source_object_binding" | git hash-object --stdin)"
  nonce="${source_object_store##*/}"
  target_ref="refs/ship-flow/closeout-source/${binding_hash}/$$-${nonce}-${#source_object_target_refs[@]}"
  git check-ref-format "$target_ref" >/dev/null 2>&1 ||
    reject_input landing-patch-equivalence-failed "temporary implementation PR source-object ref is invalid"
  if git -C "$target_repo" show-ref --verify --quiet "$target_ref"; then
    reject_input landing-patch-equivalence-failed "temporary implementation PR source-object ref already exists"
  fi
  # Register the absent, collision-resistant ref before fetch so an EXIT trap
  # can remove an update that completed immediately before an interrupt. The
  # expected-old CAS prevents cleanup from deleting a differently valued ref.
  source_object_target_repos+=("$target_repo")
  source_object_target_refs+=("$target_ref")
  source_object_target_tips+=("$expected_tip")
  import_out="$(mktemp)"
  git -C "$target_repo" fetch -q --force --no-tags --no-write-fetch-head --recurse-submodules=no \
    "$source_object_store" "+${source_object_store_ref}:${target_ref}" >"$import_out" 2>&1 || import_rc=$?
  rm -f "$import_out"
  imported_tip="$(git -C "$target_repo" rev-parse --verify "${target_ref}^{commit}" 2>/dev/null || true)"
  if [ "$import_rc" -ne 0 ]; then
    reject_input landing-patch-equivalence-failed "authoritative implementation PR source objects could not be materialized"
  fi
  [ "$imported_tip" = "$expected_tip" ] ||
    reject_input landing-patch-equivalence-failed "materialized implementation PR source ref tip does not match provider OIDs"
  validate_source_object_set "$target_repo" "$expected_tip" "$source_commits" "$pr_commit_count" ||
    reject_input landing-patch-equivalence-failed "materialized implementation PR source objects do not match provider OIDs"
}

acquire_source_objects() {
  local target_repo="$1" binding expected_tip fetch_depth fetch_out fetch_rc=0 fetched_tip
  local source_oids=()
  [[ "$pr_commit_count" =~ ^[1-9][0-9]*$ ]] ||
    reject_input landing-patch-equivalence-failed "authoritative implementation PR commit count is invalid"
  IFS=',' read -r -a source_oids <<< "$source_commits"
  [ "${#source_oids[@]}" -eq "$pr_commit_count" ] ||
    reject_input landing-patch-equivalence-failed "authoritative implementation PR source OID count does not match provider count"
  expected_tip="${source_oids[$((${#source_oids[@]} - 1))]}"
  binding="${repository}|${pr_number}|${source_commits}|${pr_commit_count}"

  if [ "$pr_provider" = fixture ]; then
    [ -z "$source_object_binding" ] || [ "$source_object_binding" = "$binding" ] ||
      reject_input landing-patch-equivalence-failed "implementation PR source-object binding changed during reconciliation"
    source_object_binding="$binding"
    materialize_acquired_source_objects "$target_repo"
    return 0
  fi

  if [ -n "$source_object_binding" ] && [ "$source_object_binding" != "$binding" ]; then
    reject_input landing-patch-equivalence-failed "implementation PR source-object binding changed during reconciliation"
  fi
  if [ -z "$source_object_store" ]; then
    resolve_provider_source_remote ||
      reject_input landing-patch-equivalence-failed "no configured GitHub remote matches the authoritative provider repository"
    source_object_store="$(mktemp -d "${TMPDIR:-/tmp}/ship-flow-closeout-source.XXXXXX")"
    git init -q --bare "$source_object_store" ||
      reject_input landing-patch-equivalence-failed "temporary implementation PR source-object store could not be initialized"
    fetch_depth=$((pr_commit_count + 1))
    [ "$fetch_depth" -gt "$pr_commit_count" ] ||
      reject_input landing-patch-equivalence-failed "authoritative implementation PR commit count exceeds fetch bounds"
    fetch_out="$(mktemp)"
    env GIT_ALTERNATE_OBJECT_DIRECTORIES='' git -C "$source_object_store" -c fetch.recurseSubmodules=false \
      fetch -q --force --no-tags --no-write-fetch-head --depth="$fetch_depth" "$source_remote_url" \
      "+refs/pull/${pr_number}/head:${source_object_store_ref}" >"$fetch_out" 2>&1 || fetch_rc=$?
    rm -f "$fetch_out"
    if [ "$fetch_rc" -ne 0 ]; then
      reject_input landing-patch-equivalence-failed "authoritative implementation PR source ref is unavailable"
    fi
    fetched_tip="$(env GIT_ALTERNATE_OBJECT_DIRECTORIES='' git -C "$source_object_store" rev-parse --verify "${source_object_store_ref}^{commit}" 2>/dev/null || true)"
    [ "$fetched_tip" = "$expected_tip" ] ||
      reject_input landing-patch-equivalence-failed "implementation PR source ref tip does not match provider OIDs"
    (unset GIT_ALTERNATE_OBJECT_DIRECTORIES; validate_source_object_set "$source_object_store" "$expected_tip" "$source_commits" "$pr_commit_count") ||
      reject_input landing-patch-equivalence-failed "implementation PR source ref does not contain the exact provider OIDs"
    source_object_binding="$binding"
  fi
  materialize_acquired_source_objects "$target_repo"
}

prepare_receipt_source_commits() {
  local receipt_path="$1" receipt_strategy receipt_pr structural_out structural_rc=0
  structural_out="$(mktemp)"
  python3 "$RECEIPT_VALIDATOR" --receipt "$receipt_path" --allow-any-path >"$structural_out" 2>&1 || structural_rc=$?
  if [ "$structural_rc" -ne 0 ]; then cat "$structural_out"; rm -f "$structural_out"; return "$structural_rc"; fi
  rm -f "$structural_out"
  IFS=$'\t' read -r receipt_strategy receipt_pr < <(python3 - "$receipt_path" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
print(r["landing_proof"]["strategy"],r["identity"]["implementation_pr"],sep="\t")
PY
)
  [ "$receipt_strategy" = squash ] || return 0
  if [ -z "${source_commits:-}" ] || [ "${pr_number:-}" != "$receipt_pr" ]; then
    pr_number="$receipt_pr"
    case "$pr_provider" in
      fixture) read_provider_fixture "$pr_fixture" ;;
      gh) read_provider_gh ;;
    esac
  fi
  [ "$pr_state" = MERGED ] || prompt_captain pr-not-merged "implementation PR source commits require authoritative MERGED provider state"
  acquire_source_objects "$repo_root"
}

validate_receipt_normal() {
  local receipt_path="$1"
  shift
  prepare_receipt_source_commits "$receipt_path" || return $?
  if [ -n "${source_commits:-}" ]; then
    python3 "$RECEIPT_VALIDATOR" --receipt "$receipt_path" --source-commits "$source_commits" "$@"
  else
    python3 "$RECEIPT_VALIDATOR" --receipt "$receipt_path" "$@"
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

sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'; fi
}

require_landing_contract() {
  [ -n "${landing_anchor:-}" ] || reject_input landing-anchor-missing "merged PR provider response is missing the landing anchor"
  [ -n "${source_commits:-}" ] && [ -n "${pr_commit_count:-}" ] ||
    reject_input landing-pr-commit-count-mismatch "merged PR provider response is missing the ordered source commits or commit count"
  [ -n "${repository:-}" ] && [ -n "${base_ref:-}" ] ||
    reject_input closeout-stage-artifacts-incoherent "merged PR provider response is missing repository or base-ref identity"
}

validate_roadmap_title() {
  local title="$1"
  python3 - "$title" <<'PY' >/dev/null || reject_input closeout-stage-artifacts-incoherent "entity title contains an unsafe ROADMAP table delimiter or control character"
import sys
value=sys.argv[1]
raise SystemExit(1 if "|" in value or any(ord(char)<32 or ord(char)==127 for char in value) else 0)
PY
}

registry_field() {
  local registry="$1" field="$2"
  [ -f "$registry" ] || return 0
  awk -F= -v field="$field" '$1==field{sub(/^[^=]*=/, ""); print; exit}' "$registry"
}

set_registry_field() {
  local registry="$1" field="$2" value="$3"
  python3 - "$registry" "$field" "$value" <<'PY'
import pathlib,sys
path,key,value=pathlib.Path(sys.argv[1]),sys.argv[2],sys.argv[3]
rows=[]; replaced=False
if path.exists():
    for line in path.read_text().splitlines():
        if line.split("=",1)[0]==key:
            if not replaced: rows.append(f"{key}={value}"); replaced=True
        else: rows.append(line)
if not replaced: rows.append(f"{key}={value}")
path.parent.mkdir(parents=True,exist_ok=True)
path.write_text("\n".join(rows)+"\n")
PY
}

fail_once() {
  local stage="$1" marker="${SHIP_FLOW_CLOSEOUT_FAIL_ONCE_MARKER:-}"
  [ "${SHIP_FLOW_CLOSEOUT_FAIL_ONCE:-}" = "$stage" ] || return 0
  [ -n "$marker" ] || reject_input closeout-checkpoint-conflict "fail-once seam requires a marker path"
  if [ ! -e "$marker" ]; then
    mkdir -p "$(dirname "$marker")"; touch "$marker"
    prompt_captain closeout-checkpoint-conflict "injected one-time failure during ${stage}"
  fi
}

read_closeout_pr_fixture() {
  local fixture="$1" registry="${SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY:-}" registered_number registered_head
  closeout_pr_number="$(awk -F= '$1=="closeout_pr_number"{print $2; exit}' "$fixture")"
  closeout_pr_state="$(awk -F= '$1=="closeout_pr_state"{print $2; exit}' "$fixture")"
  closeout_pr_head="$(awk -F= '$1=="closeout_pr_head"{sub(/^[^=]*=/, ""); print; exit}' "$fixture")"
  [ -n "$closeout_pr_number" ] && [ -n "$closeout_pr_state" ] && [ -n "$closeout_pr_head" ] ||
    reject_input closeout-sentinel-invalid "fixture is missing closeout PR checkpoint fields"
  closeout_pr_remote_oid=""; closeout_pr_is_draft="true"
  if [ -n "$registry" ] && [ -f "$registry" ]; then
    registered_number="$(registry_field "$registry" number)"
    registered_head="$(registry_field "$registry" head)"
    if [ -n "$registered_number" ]; then
      closeout_pr_number="$registered_number"
      closeout_pr_head="$registered_head"
    fi
    closeout_pr_remote_oid="$(registry_field "$registry" remote_oid)"
    closeout_pr_is_draft="$(registry_field "$registry" is_draft)"
    [ -n "$closeout_pr_is_draft" ] || closeout_pr_is_draft=true
  fi
}

read_closeout_pr_gh() {
  local number="$1" output
  command -v gh >/dev/null 2>&1 || reject_input missing-gh "gh CLI is not available"
  output="$(gh pr view "$number" --json number,state,headRefName,headRefOid,isDraft --jq '[.number,.state,.headRefName,.headRefOid,.isDraft] | join("|")')" ||
    prompt_captain closeout-pr-awaiting-merge "deterministic closeout PR cannot be resolved"
  IFS='|' read -r closeout_pr_number closeout_pr_state closeout_pr_head closeout_pr_remote_oid closeout_pr_is_draft <<<"$output"
}

scan_closeout_receipts() {
  local scan_output scan_count receipt_path receipt_relative phase mode expected_head recorded_pr expected_proof validator_out validator_rc=0 active_candidate terminal_sha="" terminal_ready=no
  scan_output="$(python3 - "$workflow_dir" "$entity_ref" <<'PY'
import json,pathlib,sys
root,ref=pathlib.Path(sys.argv[1]),sys.argv[2]
matches=[]
for path in sorted((root/"_closeouts").glob("*.json")):
    try: receipt=json.loads(path.read_text())
    except Exception: continue
    identity=receipt.get("identity",{})
    transaction=receipt.get("transaction",{})
    if (receipt.get("mode")=="pull_request" and identity.get("entity_slug")==ref
            and transaction.get("phase") in ("awaiting_closeout_pr","applied","complete")):
        matches.append(path)
print(len(matches))
if len(matches)==1: print(matches[0])
PY
)"
  scan_count="$(printf '%s\n' "$scan_output" | sed -n '1p')"
  [ "$scan_count" = 0 ] && return 0
  [ "$scan_count" = 1 ] || reject_input closeout-sentinel-multiple "multiple receipt-only closeout candidates match the entity"
  receipt_path="$(printf '%s\n' "$scan_output" | sed -n '2p')"
  receipt_path="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$receipt_path")"
  validator_out="$(mktemp)"
  validate_receipt_normal "$receipt_path" --repo-root "$repo_root" >"$validator_out" 2>&1 || validator_rc=$?
  if [ "$validator_rc" -ne 0 ]; then cat "$validator_out"; rm -f "$validator_out"; exit "$validator_rc"; fi
  rm -f "$validator_out"
  IFS=$'\t' read -r mode phase recorded_pr expected_head expected_proof < <(python3 - "$receipt_path" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); t=r["transaction"]
print(r["mode"],t["phase"],t["closeout_pr"] or "",r["deterministic_closeout_head"],r["proof_hash"],sep="\t")
PY
)
  [ "$mode" = pull_request ] || return 0
  [ -n "$recorded_pr" ] || reject_input closeout-checkpoint-conflict "receipt-only PR recovery lacks a closeout PR number"
  case "$pr_provider" in
    fixture) read_closeout_pr_fixture "$pr_fixture" ;;
    gh) read_closeout_pr_gh "$recorded_pr" ;;
  esac
  if [ "$phase" = awaiting_closeout_pr ]; then
    case "$closeout_pr_state" in
      MERGED) reject_input closeout-sentinel-missing "closeout PR is MERGED but authoritative landed sentinel bytes are absent" ;;
      CLOSED) prompt_captain closeout-pr-awaiting-merge "deterministic closeout PR closed without landing terminal bytes" ;;
      OPEN) ;;
      *) prompt_captain closeout-pr-awaiting-merge "deterministic closeout PR state is unsupported" ;;
    esac
    active_candidate="$workflow_dir/$entity_ref/index.md"
    receipt_relative="$(python3 - "$repo_root" "$receipt_path" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[2]).resolve().relative_to(pathlib.Path(sys.argv[1]).resolve()).as_posix())
PY
)"
    if optional_terminal_head_matches "$expected_head" "$receipt_relative" "$recorded_pr" "$expected_proof"; then
      terminal_sha="$(git -C "$repo_root" rev-parse "$expected_head")"
      if [ "$closeout_pr_number" = "$recorded_pr" ] && [ "$closeout_pr_head" = "$expected_head" ] && [ "$closeout_pr_remote_oid" = "$terminal_sha" ] && [ "$closeout_pr_is_draft" = false ]; then
        terminal_ready=yes
      fi
    fi
    if [ "$terminal_ready" != yes ]; then
      [ -f "$active_candidate" ] && return 0
      reject_input closeout-sentinel-invalid "awaiting receipt lost its active entity before exact remote terminal OID and non-draft publication"
    fi
    verdict="PROCEED"; pr_number="$recorded_pr"; pr_state="$closeout_pr_state"
    terminal_action="none"; reason="closeout-pr-awaiting-merge"; state_name="closeout_pr_awaiting_merge"
    detail="receipt checkpoint and deterministic closeout PR are awaiting authoritative merged sentinel bytes"
    emit_report
    exit 0
  fi
  [ "$closeout_pr_number" = "$recorded_pr" ] || reject_input closeout-sentinel-identity-mismatch "resolved closeout PR number differs from receipt"
  [ "$closeout_pr_head" = "$expected_head" ] || reject_input closeout-sentinel-identity-mismatch "resolved closeout PR head differs from deterministic receipt head"
  [ "$closeout_pr_state" = MERGED ] || prompt_captain closeout-pr-awaiting-merge "landed receipt claims an unmerged closeout PR"
  validator_out="$(mktemp)"; validator_rc=0
  validate_receipt_normal "$receipt_path" --repo-root "$repo_root" --verify-outputs >"$validator_out" 2>&1 || validator_rc=$?
  if [ "$validator_rc" -ne 0 ]; then cat "$validator_out"; rm -f "$validator_out"; exit "$validator_rc"; fi
  rm -f "$validator_out"
  verdict="PROCEED"; pr_number="$recorded_pr"; pr_state="MERGED"
  terminal_action="already_reconciled"; reason="closeout-pr-terminal-noop"; state_name="closeout_pr_terminal_noop"
  detail="one landed receipt validates deterministic head, identity, manifest, and proof hash"
  emit_report
  exit 0
}

classify_archived_ship() {
  local marker_output
  marker_output="$(python3 - "$1" <<'PY'
import pathlib,re,sys
lines=pathlib.Path(sys.argv[1]).read_text().splitlines()
sections=[i for i,line in enumerate(lines) if line.strip()=="### Closeout"]
if not sections:
    print("legacy\n\n"); raise SystemExit
if len(sections)!=1:
    print("invalid\n\n"); raise SystemExit
start=sections[0]+1
end=next((i for i in range(start,len(lines)) if re.match(r"^#{1,3} ",lines[i])),len(lines))
values={"closeout_id":[],"receipt":[]}
for line in lines[start:end]:
    match=re.match(r"^(closeout_id|receipt):[ \t]*(.*?)[ \t]*$",line)
    if match: values[match.group(1)].append(match.group(2))
if not values["closeout_id"] and not values["receipt"]:
    print("legacy\n\n"); raise SystemExit
if len(values["closeout_id"])!=1 or len(values["receipt"])!=1:
    print("invalid\n\n"); raise SystemExit
cid,receipt=values["closeout_id"][0],values["receipt"][0]
safe=bool(re.fullmatch(r"[0-9a-f]{64}",cid) and re.fullmatch(r"[^\s]+/_closeouts/[0-9a-f]{64}\.json",receipt))
parts=pathlib.PurePosixPath(receipt)
safe=safe and not parts.is_absolute() and all(part not in ("", ".", "..") for part in parts.parts) and parts.name==cid+".json"
print(("receipt" if safe else "invalid")+"\n"+cid+"\n"+receipt)
PY
)" || reject_input closeout-sentinel-invalid "final ship closeout markers cannot be parsed"
  archived_marker_mode="$(printf '%s\n' "$marker_output" | sed -n '1p')"
  archived_marker_id="$(printf '%s\n' "$marker_output" | sed -n '2p')"
  archived_marker_receipt="$(printf '%s\n' "$marker_output" | sed -n '3p')"
}

validate_archived_direct_receipt() {
  local archived_relative workflow_relative match_output match_count receipt_path validator_out validator_rc=0 receipt_archive
  archived_relative="$(python3 - "$repo_root" "$entity_path" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[2]).resolve().relative_to(pathlib.Path(sys.argv[1]).resolve()).as_posix())
PY
)" || reject_input closeout-sentinel-invalid "archived entity is outside the repository"
  workflow_relative="$(python3 - "$repo_root" "$workflow_dir" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[2]).resolve().relative_to(pathlib.Path(sys.argv[1]).resolve()).as_posix())
PY
)" || reject_input closeout-sentinel-invalid "workflow is outside the repository"
  match_output="$(python3 - "$workflow_dir" "$workflow_relative" "$entity_slug" "$pr_number" <<'PY'
import json,pathlib,sys
root,workflow,slug,pr=pathlib.Path(sys.argv[1]),sys.argv[2],sys.argv[3],int(sys.argv[4])
matches=[]
for path in sorted((root/"_closeouts").glob("*.json")):
    try: receipt=json.loads(path.read_text())
    except Exception: continue
    identity=receipt.get("identity",{})
    if identity.get("workflow")==workflow and identity.get("entity_slug")==slug and identity.get("implementation_pr")==pr:
        matches.append(path)
print(len(matches))
if len(matches)==1: print(matches[0])
PY
)"
  match_count="$(printf '%s\n' "$match_output" | sed -n '1p')"
  [ "$match_count" = 1 ] || {
    if [ "$match_count" = 0 ]; then reject_input closeout-sentinel-missing "archived direct entity has no identity-matching receipt"
    else reject_input closeout-sentinel-invalid "archived direct entity has multiple identity-matching receipts"; fi
  }
  receipt_path="$(printf '%s\n' "$match_output" | sed -n '2p')"
  receipt_path="$(python3 -c 'import pathlib,sys; print(pathlib.Path(sys.argv[1]).resolve())' "$receipt_path")"
  validator_out="$(mktemp)"
  validate_receipt_normal "$receipt_path" --repo-root "$repo_root" --verify-outputs >"$validator_out" 2>&1 || validator_rc=$?
  if [ "$validator_rc" -ne 0 ]; then cat "$validator_out"; rm -f "$validator_out"; exit "$validator_rc"; fi
  rm -f "$validator_out"
  receipt_archive="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["outputs"]["archived_entity"]["path"])' "$receipt_path")"
  [ "$receipt_archive" = "$archived_relative" ] || reject_input closeout-sentinel-identity-mismatch "receipt archived output does not match resolved archived entity"
  archived_receipt_id="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["closeout_id"])' "$receipt_path")"
  archived_receipt_relative="$(python3 - "$repo_root" "$receipt_path" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[2]).resolve().relative_to(pathlib.Path(sys.argv[1]).resolve()).as_posix())
PY
)"
  archived_ship="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["outputs"]["ship"]["path"])' "$receipt_path")"
  archived_ship="$repo_root/$archived_ship"
}

resolve_merge_method_intent() {
  local ship_file="$1"
  awk '
    $0 == "### Verdict" { in_verdict=1; next }
    in_verdict && /^#/ { exit }
    in_verdict && /^merge_method_intent:/ {
      sub(/^merge_method_intent:[[:space:]]*/, ""); gsub(/^"|"$/, ""); print; exit
    }
  ' "$ship_file"
}

resolve_closeout_ownership() {
  local candidate candidate_pr normalized owner slug
  local matches=0 owners=0 owner_path="" participants=()
  while IFS= read -r candidate; do
    valid_frontmatter "$candidate" || reject_input closeout-stage-artifacts-incoherent "ownership candidate has malformed frontmatter"
    candidate_pr="$(read_frontmatter_field "$candidate" pr)"
    normalized="$(normalize_pr_number "$candidate_pr" || true)"
    [ "$normalized" = "$pr_number" ] || continue
    matches=$((matches + 1))
    owner="$(read_frontmatter_field "$candidate" closeout_owner)"
    if [ "$owner" = true ]; then owners=$((owners + 1)); owner_path="$candidate"; fi
  done < <(find "$workflow_dir" -mindepth 2 -maxdepth 2 -type f -name index.md ! -path '*/_*/*' | sort)
  [ "$matches" -gt 0 ] || reject_input closeout-owner-not-unique "implementation PR has no owning entity"
  if [ "$matches" -eq 1 ]; then
    owner_path="$entity_path"
  elif [ "$owners" -ne 1 ]; then
    reject_input closeout-owner-not-unique "shared implementation PR must declare exactly one closeout owner"
  fi
  [ "$owner_path" = "$entity_path" ] || reject_input closeout-indirect-landing-unowned "requested entity is not the declared closeout owner"
  while IFS= read -r candidate; do
    [ "$candidate" = "$owner_path" ] && continue
    candidate_pr="$(read_frontmatter_field "$candidate" pr)"
    normalized="$(normalize_pr_number "$candidate_pr" || true)"
    [ "$normalized" = "$pr_number" ] || continue
    slug="$(basename "$(dirname "$candidate")")"
    participants+=("$slug")
  done < <(find "$workflow_dir" -mindepth 2 -maxdepth 2 -type f -name index.md ! -path '*/_*/*' | sort)
  ownership_match_count="$matches"
  ownership_participants=""
  if [ "${#participants[@]}" -gt 0 ]; then
    ownership_participants="$(IFS=,; printf '%s' "${participants[*]}")"
  fi
}

prepare_direct_bundle() {
  local bundle_root="$1" envelope_file="$2" title="$3" merge_intent="$4"
  python3 - "$repo_root" "$workflow_dir" "$entity_path" "$bundle_root" "$envelope_file" "$repository" "$pr_number" "$merged_at" "$title" "$merge_intent" "$ownership_match_count" "$ownership_participants" "$source_commits" <<'PY'
import hashlib,json,pathlib,re,sys
repo,workflow,entity,bundle,envelope=map(lambda value: pathlib.Path(value).resolve(),sys.argv[1:6])
repository,pr_number,merged_at,title,merge_intent,match_count,participants_csv,source_commits_csv=sys.argv[6:]
workflow_rel=workflow.relative_to(repo).as_posix(); slug=entity.parent.name
env={}
for line in envelope.read_text().splitlines():
    if "=" in line:
        key,value=line.split("=",1); env[key]=value
env["source_commits"]=source_commits_csv
def h(path): return hashlib.sha256(path.read_bytes()).hexdigest()
def write(rel,text):
    path=bundle/rel; path.parent.mkdir(parents=True,exist_ok=True); path.write_text(text); return path
date=merged_at[:10]
used=set()
for path in (workflow/"_debriefs").glob(f"{date}-[0-9][0-9].md"):
    match=re.fullmatch(rf"{re.escape(date)}-([0-9]{{2}})\.md",path.name)
    if match: used.add(int(match.group(1)))
sequence=next((number for number in range(1,100) if number not in used),None)
if sequence is None: raise SystemExit("no canonical debrief sequence is available")
debrief_rel=f"{workflow_rel}/_debriefs/{date}-{sequence:02d}.md"
archive_rel=f"{workflow_rel}/_archive/{slug}/index.md"
ship_rel=f"{workflow_rel}/_archive/{slug}/ship.md"
source_ship=entity.parent/"ship.md"
source_lines=source_ship.read_text().splitlines()
try: todo_start=source_lines.index("## Todo Closeout Digest")+1
except ValueError: raise SystemExit("ship.md is missing Todo Closeout Digest")
todo_end=next((i for i in range(todo_start,len(source_lines)) if re.match(r"^#{2,3} ",source_lines[i])),len(source_lines))
todo_lines=source_lines[todo_start:todo_end]
while todo_lines and not todo_lines[0].strip(): todo_lines.pop(0)
while todo_lines and not todo_lines[-1].strip(): todo_lines.pop()
if not todo_lines: raise SystemExit("Todo Closeout Digest is empty")
todo="\n".join(todo_lines)
first=env["first_landing_commit"]; last=env["last_landing_commit"]
debrief=f'''---
schema_version: 1
session-date: {date}
sequence: {sequence}
first-commit: {first[:7]}
last-commit: {last[:7]}
duration: automated closeout
session-type: ship
---

# {title} debrief

## Shipped

- {title} via implementation PR #{pr_number}.

## Filed (backlog)

- None.

## Issues — Spacedock

- None.

## Issues — Workflow

- None.

## Non-PR commits (workflow-only)

- One atomic closeout commit.

## Observations

- Landing method: {env['strategy']} ({env['method_source']}).

## Decisions

- Receipt-bound terminal projection applied.

## What's Next

- Post-merge cleanup may retry independently.

## Reconciliation

- Provider merged at: {env['provider_merged_at']}
- Landing anchor: {env['landing_anchor']}
- Base ref: {env['base_ref']}
- Base before: {env['base_before']}
- Strategy: {env['strategy']}
- Strategy evidence: {env['strategy_evidence']}
- Method source: {env['method_source']}
- PR commit count: {env['pr_commit_count']}
- Ordered source commits: {env['source_commits']}
- Source commit patch IDs: {env['source_commit_patch_ids']}
- Source patch digest: {env['source_patch_digest']}
- Ordered landing commits: {env['landing_commits']}
- Landing commit patch IDs: {env['landing_commit_patch_ids']}
- Landing patch digest: {env['landing_patch_digest']}
- First landing commit: {first}
- Last landing commit: {last}

## Todo Closure

{todo}
'''
debrief_path=write(debrief_rel,debrief)
lines=entity.read_text().splitlines(keepends=True)
fields={"status":"done","completed":merged_at,"verdict":"PASSED","worktree":"","archived":merged_at}
fences=[i for i,line in enumerate(lines) if line.strip()=="---"]
if len(fences)<2 or fences[0]!=0: raise SystemExit("malformed entity frontmatter")
end=fences[1]
for key,value in fields.items():
    found=False
    for i in range(1,end):
        if lines[i].startswith(key+":"):
            lines[i]=f"{key}: {value}\n"; found=True; break
    if not found: lines.insert(end,f"{key}: {value}\n"); end+=1
archive_path=write(archive_rel,"".join(lines))
identity={"provider":"github","repository":repository,"workflow":workflow_rel,"entity_slug":slug,"implementation_pr":int(pr_number)}
cid=hashlib.sha256("\0".join(("v1","github",repository,workflow_rel,slug,pr_number)).encode()).hexdigest()
receipt_rel=f"{workflow_rel}/_closeouts/{cid}.json"
source_worktree=""
for line in entity.read_text().splitlines():
    if line.startswith("worktree:"):
        source_worktree=line.split(":",1)[1].strip().strip('"').strip("'"); break
ship=f'''# Ship

## Todo Closeout Digest

{todo}

### Verdict
pr: "#{pr_number}"
merge_method_intent: {merge_intent or 'absent'}

### Closeout
status: applied
closeout_id: {cid}
receipt: {receipt_rel}
landing_method: {env['strategy']}
landing_anchor: {env['landing_anchor']}
base_ref: {env['base_ref']}
base_before: {env['base_before']}
first_landing_commit: {first}
last_landing_commit: {last}
landing_commits: {env['landing_commits']}
source_commit_patch_ids: {env['source_commit_patch_ids']}
source_patch_digest: {env['source_patch_digest']}
landing_commit_patch_ids: {env['landing_commit_patch_ids']}
landing_patch_digest: {env['landing_patch_digest']}
source_worktree: {source_worktree}
'''
# proof_hash deliberately stays receipt-only: it binds these exact ship bytes.
ship_path=write(ship_rel,ship)
roadmap=(repo/"ROADMAP.md").read_text().splitlines(); row=f"| {slug} | {title} | {date} |"
def bounds(name):
    opens=[i for i,line in enumerate(roadmap) if line.strip()==f"<!-- section:{name} -->"]
    closes=[i for i,line in enumerate(roadmap) if line.strip()==f"<!-- /section:{name} -->"]
    if len(opens)!=1 or len(closes)!=1 or opens[0]>=closes[0]: raise SystemExit(f"ROADMAP {name} bounds invalid")
    return opens[0],closes[0]
def identity_rows(start,end):
    found=[]
    for i in range(start+1,end):
        line=roadmap[i].strip()
        if not (line.startswith("|") and line.endswith("|")): continue
        cells=[cell.strip() for cell in line[1:-1].split("|")]
        if cells and cells[0]==slug: found.append(i)
    return found
now_open,now_close=bounds("now"); shipped_open,shipped_close=bounds("shipped")
now_rows=identity_rows(now_open,now_close); shipped_rows=identity_rows(shipped_open,shipped_close)
if len(now_rows)!=1: raise SystemExit("ROADMAP Now must contain exactly one identity row")
if shipped_rows: raise SystemExit("ROADMAP Shipped already contains identity row")
out=roadmap[:now_rows[0]]+roadmap[now_rows[0]+1:]
if now_rows[0]<shipped_close: shipped_close-=1
out.insert(shipped_close,row)
write("ROADMAP.md","\n".join(out)+"\n")
arrays={"source_commit_patch_ids","landing_commits","landing_commit_patch_ids"}; ints={"schema_version","implementation_pr","pr_commit_count"}
# source_commits is provider/rendering input, not part of the canonical D1 receipt proof.
landing={key:(value.split(",") if key in arrays else int(value) if key in ints else value) for key,value in env.items() if key != "source_commits"}
participants=[] if not participants_csv else participants_csv.split(",")
receipt={"schema_version":1,"kind":"ship-flow.closeout","closeout_id":cid,"identity":identity,
 "ownership_proof":{"unique_entity_matches":int(match_count),"participant_entities":participants,"source_hashes":{"index":h(entity),"review":h(entity.parent/"review.md"),"ship":h(entity.parent/"ship.md")}},
 "mode":"direct","merge_method_intent":merge_intent or None,"deterministic_closeout_head":"ship-closeout/"+cid,"landing_proof":landing,
 "transaction":{"phase":"applied","generation":2,"closeout_pr":None,"main_commit":env["landing_anchor"]},
 "outputs":{"debrief":{"path":debrief_rel,"sha256":h(debrief_path)},"ship":{"path":ship_rel,"sha256":h(ship_path)},"archived_entity":{"path":archive_rel,"sha256":h(archive_path)},"roadmap_row":{"identity":slug,"sha256":hashlib.sha256(row.encode()).hexdigest()}}}
payload={key:receipt[key] for key in ("identity","ownership_proof","landing_proof","outputs")}
receipt["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
write(receipt_rel,json.dumps(receipt,sort_keys=True,indent=2)+"\n")
print(receipt_rel)
PY
}

reconcile_direct_bundle() {
  local review_file="$workflow_dir/$entity_slug/review.md" ship_file="$workflow_dir/$entity_slug/ship.md"
  [ -f "$review_file" ] || reject_input closeout-review-missing "review.md is required for terminal closeout"
  [ -f "$ship_file" ] || reject_input closeout-ship-missing "ship.md is required for terminal closeout"
  resolve_closeout_ownership
  local merge_intent envelope_file envelope_rc=0 bundle_root receipt_relative render_rc=0 debrief_relative apply_out apply_rc=0 title active_relative active_rc=0
  local landing_args
  merge_intent="$(resolve_merge_method_intent "$ship_file")"
  title="$(read_frontmatter_field "$entity_path" title)"; [ -n "$title" ] || title="$entity_slug"
  validate_roadmap_title "$title"
  envelope_file="$(mktemp)"
  landing_args=(--repo-dir "$repo_root" --repository "$repository" --base-ref "$base_ref" --implementation-pr "$pr_number" --provider-merged-at "$merged_at" --landing-anchor "$landing_anchor" --source-commits "$source_commits" --pr-commit-count "$pr_commit_count")
  [ -n "$merge_intent" ] && landing_args+=(--merge-method-intent "$merge_intent")
  "$LANDING_RESOLVER" "${landing_args[@]}" >"$envelope_file" 2>&1 || envelope_rc=$?
  if [ "$envelope_rc" -ne 0 ]; then cat "$envelope_file"; rm -f "$envelope_file"; exit "$envelope_rc"; fi
  bundle_root="$(mktemp -d)"
  receipt_relative="$(prepare_direct_bundle "$bundle_root" "$envelope_file" "$title" "$merge_intent")" || render_rc=$?
  rm -f "$envelope_file"
  if [ "$render_rc" -ne 0 ]; then rm -rf "$bundle_root"; reject_input closeout-stage-artifacts-incoherent "failed to render coherent closeout bundle"; fi
  debrief_relative="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["outputs"]["debrief"]["path"])' "$bundle_root/$receipt_relative")" || {
    rm -rf "$bundle_root"; reject_input closeout-stage-artifacts-incoherent "rendered receipt cannot identify its debrief"
  }
  if ! "$DEBRIEF_VALIDATOR" "$bundle_root/$debrief_relative" >/dev/null; then
    rm -rf "$bundle_root"; reject_input closeout-stage-artifacts-incoherent "rendered debrief fails schema validation"
  fi
  active_relative="$(python3 - "$repo_root" "$entity_path" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[2]).resolve().parent.relative_to(pathlib.Path(sys.argv[1]).resolve()).as_posix())
PY
)" || active_rc=$?
  if [ "$active_rc" -ne 0 ]; then rm -rf "$bundle_root"; reject_input closeout-entity-outside-repo "active entity is outside the repository"; fi
  terminal_action="closeout_bundle"
  if [ "$dry_run" = yes ]; then
    rm -rf "$bundle_root"
    state_name="closeout_bundle_planned"; detail="coherent direct closeout bundle planned"
    return 0
  fi
  apply_out="$(mktemp)"
  "$BUNDLE_APPLIER" --repo-root "$repo_root" --bundle-root "$bundle_root" --receipt-relative "$receipt_relative" --active-entity-relative "$active_relative" --if-head "$(git -C "$repo_root" rev-parse HEAD)" --if-roadmap-hash "$(sha256_file "$repo_root/ROADMAP.md")" --commit-as "ship(${entity_slug}): advance status to done" --source-commits "$source_commits" >"$apply_out" 2>&1 || apply_rc=$?
  rm -rf "$bundle_root"
  if [ "$apply_rc" -ne 0 ]; then cat "$apply_out"; rm -f "$apply_out"; exit "$apply_rc"; fi
  rm -f "$apply_out"
  state_name="reconciled"; detail="merged PR reconciled as one receipt-bound terminal Git bundle"
}

checkpoint_optional_receipt() {
  local source="$1" receipt_relative="$2" phase="$3" generation="$4" bound_pr="$5"
  local target="$repo_root/$receipt_relative" previous="" transition_tmp validator_out validator_rc=0
  transition_tmp="$(mktemp)"
  python3 - "$source" "$transition_tmp" "$phase" "$generation" "$bound_pr" <<'PY'
import json,pathlib,sys
source,target,phase,generation,bound_pr=sys.argv[1:]
r=json.load(open(source)); r["mode"]="pull_request"
r["transaction"]={"phase":phase,"generation":int(generation),
                  "closeout_pr":None if bound_pr=="null" else int(bound_pr),
                  "main_commit":None}
pathlib.Path(target).write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  if [ -f "$target" ]; then
    previous="$(mktemp)"; cp "$target" "$previous"
    if cmp -s "$target" "$transition_tmp"; then rm -f "$transition_tmp" "$previous"; return 0; fi
  fi
  validator_out="$(mktemp)"
  if [ -n "$previous" ]; then
    python3 "$RECEIPT_VALIDATOR" --receipt "$transition_tmp" --previous "$previous" --allow-any-path >"$validator_out" 2>&1 || validator_rc=$?
  else
    python3 "$RECEIPT_VALIDATOR" --receipt "$transition_tmp" --allow-any-path >"$validator_out" 2>&1 || validator_rc=$?
  fi
  if [ "$validator_rc" -ne 0 ]; then cat "$validator_out"; rm -f "$validator_out" "$transition_tmp" ${previous:+"$previous"}; exit "$validator_rc"; fi
  rm -f "$validator_out" ${previous:+"$previous"}
  mkdir -p "$(dirname "$target")"; cp "$transition_tmp" "$target"; rm -f "$transition_tmp"
  git -C "$repo_root" add -- "$receipt_relative"
  git -C "$repo_root" commit -qm "closeout(${entity_slug}): checkpoint ${phase}" -- "$receipt_relative"
}

ensure_initial_closeout_head() {
  local deterministic_head="$1" receipt_relative="$2" registry="${SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY:-}" seed_root seed_sha
  if git -C "$repo_root" show-ref --verify --quiet "refs/heads/$deterministic_head"; then
    seed_sha="$(git -C "$repo_root" rev-parse "$deterministic_head")"
  else
    seed_root="$(mktemp -d)"; git clone -q "$repo_root" "$seed_root"
    git -C "$seed_root" config user.email "$(git -C "$repo_root" config user.email)"
    git -C "$seed_root" config user.name "$(git -C "$repo_root" config user.name)"
    git -C "$seed_root" rm -q -- "$receipt_relative"
    git -C "$seed_root" commit -qm "closeout(${entity_slug}): seed deterministic head" -- "$receipt_relative"
    seed_sha="$(git -C "$seed_root" rev-parse HEAD)"
    git -C "$repo_root" fetch -q "$seed_root" main
    git -C "$repo_root" update-ref "refs/heads/$deterministic_head" "$seed_sha"
    rm -rf "$seed_root"
  fi
  closeout_pr_local_oid="$seed_sha"
  if [ "$pr_provider" = fixture ]; then
    [ -n "$registry" ] || reject_input closeout-checkpoint-conflict "fixture optional PR flow requires a registry"
    set_registry_field "$registry" head "$deterministic_head"
    set_registry_field "$registry" local_oid "$seed_sha"
    if [ "$(registry_field "$registry" remote_oid)" != "$seed_sha" ]; then
      fail_once seed-push
      set_registry_field "$registry" remote_oid "$seed_sha"
      [ -z "${SHIP_FLOW_CLOSEOUT_PR_LOG:-}" ] || printf 'seed-push %s\n' "$seed_sha" >>"$SHIP_FLOW_CLOSEOUT_PR_LOG"
    fi
  else
    fail_once seed-push
    git -C "$repo_root" push origin "$deterministic_head" >/dev/null
  fi
  closeout_pr_remote_oid="$seed_sha"
}

require_open_closeout_pr() {
  case "$closeout_pr_state" in
    OPEN) return 0 ;;
    CLOSED) prompt_captain closeout-pr-awaiting-merge "discovered deterministic closeout PR is closed" ;;
    MERGED) reject_input closeout-sentinel-missing "discovered deterministic closeout PR is merged without authoritative landed sentinel bytes" ;;
    *) prompt_captain closeout-pr-awaiting-merge "discovered deterministic closeout PR state is unsupported" ;;
  esac
}

resolve_or_create_closeout_pr() {
  local deterministic_head="$1" title="$2" receipt_relative="$3" registry="${SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY:-}" found count created_url created_tail registered_number
  if [ "$pr_provider" = fixture ]; then
    read_closeout_pr_fixture "$pr_fixture"
    [ "$closeout_pr_head" = "$deterministic_head" ] || reject_input closeout-sentinel-identity-mismatch "fixture closeout PR head is not deterministic"
    registered_number="$(registry_field "$registry" number)"
    if [ -n "$registered_number" ]; then
      [ "$registered_number" = "$closeout_pr_number" ] || reject_input closeout-checkpoint-conflict "fixture registry PR differs from provider"
      [ "$(registry_field "$registry" head)" = "$deterministic_head" ] || reject_input closeout-sentinel-identity-mismatch "fixture registry head differs from deterministic head"
      require_open_closeout_pr
      closeout_pr_local_oid="$(git -C "$repo_root" rev-parse "$deterministic_head")"
      set_registry_field "$registry" local_oid "$closeout_pr_local_oid"
      closeout_pr_remote_oid="$(registry_field "$registry" remote_oid)"
      closeout_pr_is_draft="$(registry_field "$registry" is_draft)"
      [[ "$closeout_pr_remote_oid" =~ ^[0-9a-f]{40}$ ]] || reject_input closeout-checkpoint-conflict "fixture registry lacks provider head OID"
      case "$closeout_pr_is_draft" in true|false) ;; *) reject_input closeout-checkpoint-conflict "fixture registry lacks provider draft state" ;; esac
      [ -z "${SHIP_FLOW_CLOSEOUT_PR_LOG:-}" ] || printf 'reuse %s %s\n' "$closeout_pr_number" "$deterministic_head" >>"$SHIP_FLOW_CLOSEOUT_PR_LOG"
    else
      ensure_initial_closeout_head "$deterministic_head" "$receipt_relative"
      set_registry_field "$registry" number "$closeout_pr_number"
      set_registry_field "$registry" state OPEN
      set_registry_field "$registry" is_draft true
      closeout_pr_is_draft=true
      [ -z "${SHIP_FLOW_CLOSEOUT_PR_LOG:-}" ] || printf 'create %s %s\n' "$closeout_pr_number" "$deterministic_head" >>"$SHIP_FLOW_CLOSEOUT_PR_LOG"
    fi
    return 0
  fi
  found="$(gh pr list --head "$deterministic_head" --state all --json number,state,headRefName,headRefOid,isDraft --jq '.[] | [.number,.state,.headRefName,.headRefOid,.isDraft] | join("|")')"
  count="$(printf '%s\n' "$found" | awk 'NF{n++} END{print n+0}')"
  [ "$count" -le 1 ] || reject_input closeout-checkpoint-conflict "multiple PRs use the deterministic closeout head"
  if [ "$count" = 1 ]; then
    IFS='|' read -r closeout_pr_number closeout_pr_state closeout_pr_head closeout_pr_remote_oid closeout_pr_is_draft <<<"$found"
    [ "$closeout_pr_head" = "$deterministic_head" ] || reject_input closeout-sentinel-identity-mismatch "resolved PR head differs from deterministic head"
    [[ "$closeout_pr_remote_oid" =~ ^[0-9a-f]{40}$ ]] || reject_input closeout-checkpoint-conflict "resolved PR omits its exact head SHA"
    case "$closeout_pr_is_draft" in true|false) ;; *) reject_input closeout-checkpoint-conflict "resolved PR omits its draft state" ;; esac
    require_open_closeout_pr
    return 0
  fi
  ensure_initial_closeout_head "$deterministic_head" "$receipt_relative"
  created_url="$(gh pr create --draft --head "$deterministic_head" --base "$base_ref" --title "Close out: $title" --body "Receipt-bound post-merge closeout for implementation PR #${pr_number}.")"
  created_url="${created_url%/}"; created_tail="${created_url##*/}"
  closeout_pr_number="$(normalize_pr_number "$created_tail" || true)"
  [ -n "$closeout_pr_number" ] || reject_input closeout-checkpoint-conflict "created closeout PR number cannot be parsed"
  closeout_pr_state=OPEN; closeout_pr_is_draft=true
}

optional_terminal_head_matches() {
  local deterministic_head="$1" receipt_relative="$2" expected_pr="$3" expected_proof="$4" shown exported
  shown="$(git -C "$repo_root" show "${deterministic_head}:${receipt_relative}" 2>/dev/null || true)"
  [ -n "$shown" ] || return 1
  printf '%s' "$shown" | python3 -c 'import json,sys; r=json.load(sys.stdin); t=r["transaction"]; raise SystemExit(0 if r["mode"]=="pull_request" and t["phase"]=="applied" and t["closeout_pr"]==int(sys.argv[1]) and r["proof_hash"]==sys.argv[2] else 1)' "$expected_pr" "$expected_proof" || return 1
  exported="$(mktemp -d)"
  git -C "$repo_root" archive "$deterministic_head" | tar -x -C "$exported"
  validate_receipt_normal "$exported/$receipt_relative" --repo-root "$exported" --landing-proof-repo-root "$repo_root" --verify-outputs >/dev/null 2>&1 || { rm -rf "$exported"; return 1; }
  rm -rf "$exported"
}

build_optional_terminal_head() {
  local bundle_root="$1" receipt_relative="$2" active_relative="$3" deterministic_head="$4" bound_pr="$5"
  local expected_proof clone_root apply_out apply_rc=0 terminal_sha registry="${SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY:-}"
  expected_proof="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["proof_hash"])' "$bundle_root/$receipt_relative")"
  if optional_terminal_head_matches "$deterministic_head" "$receipt_relative" "$bound_pr" "$expected_proof"; then
    terminal_sha="$(git -C "$repo_root" rev-parse "$deterministic_head")"
  else
    clone_root="$(mktemp -d)"; git clone -q "$repo_root" "$clone_root"
    git -C "$clone_root" config user.email "$(git -C "$repo_root" config user.email)"
    git -C "$clone_root" config user.name "$(git -C "$repo_root" config user.name)"
    materialize_acquired_source_objects "$clone_root"
    git -C "$clone_root" rm -q -- "$receipt_relative"
    git -C "$clone_root" commit -qm "closeout(${entity_slug}): promote prepared receipt" -- "$receipt_relative"
    apply_out="$(mktemp)"
    [ -z "${SHIP_FLOW_CLOSEOUT_BUNDLE_LOG:-}" ] || printf 'apply %s\n' "$deterministic_head" >>"$SHIP_FLOW_CLOSEOUT_BUNDLE_LOG"
    "$BUNDLE_APPLIER" --repo-root "$clone_root" --bundle-root "$bundle_root" --receipt-relative "$receipt_relative" --active-entity-relative "$active_relative" --if-head "$(git -C "$clone_root" rev-parse HEAD)" --if-roadmap-hash "$(sha256_file "$clone_root/ROADMAP.md")" --commit-as "ship(${entity_slug}): advance status to done" --source-commits "$source_commits" >"$apply_out" 2>&1 || apply_rc=$?
    if [ "$apply_rc" -ne 0 ]; then cat "$apply_out"; rm -f "$apply_out"; rm -rf "$clone_root"; exit "$apply_rc"; fi
    rm -f "$apply_out"
    python3 - "$clone_root/$receipt_relative" "$bound_pr" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text()); r["mode"]="pull_request"
r["transaction"]={"phase":"applied","generation":3,"closeout_pr":int(sys.argv[2]),
                  "main_commit":r["landing_proof"]["landing_anchor"]}
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
    python3 "$RECEIPT_VALIDATOR" --receipt "$clone_root/$receipt_relative" --allow-any-path >/dev/null
    git -C "$clone_root" add -- "$receipt_relative"
    git -C "$clone_root" commit -qm "closeout(${entity_slug}): bind pull request sentinel" -- "$receipt_relative"
    terminal_sha="$(git -C "$clone_root" rev-parse HEAD)"
    git -C "$repo_root" fetch -q "$clone_root" main
    git -C "$repo_root" update-ref "refs/heads/$deterministic_head" "$terminal_sha"
    rm -rf "$clone_root"
  fi
  closeout_pr_local_oid="$terminal_sha"
  [ "$pr_provider" != fixture ] || set_registry_field "$registry" local_oid "$terminal_sha"
  optional_terminal_head_matches "$deterministic_head" "$receipt_relative" "$bound_pr" "$expected_proof" || reject_input closeout-sentinel-invalid "terminal deterministic head failed exact output validation"
  if [ "$closeout_pr_remote_oid" != "$terminal_sha" ]; then
    [[ "$closeout_pr_remote_oid" =~ ^[0-9a-f]{40}$ ]] || reject_input closeout-checkpoint-conflict "provider closeout head OID is unavailable for force-with-lease"
    fail_once terminal-push
    if [ "$pr_provider" = gh ]; then
      git -C "$repo_root" push --force-with-lease="refs/heads/${deterministic_head}:${closeout_pr_remote_oid}" origin "$deterministic_head" >/dev/null
    else
      [ -z "${SHIP_FLOW_CLOSEOUT_PR_LOG:-}" ] || printf 'force-with-lease %s %s\n' "$closeout_pr_remote_oid" "$terminal_sha" >>"$SHIP_FLOW_CLOSEOUT_PR_LOG"
      set_registry_field "$registry" remote_oid "$terminal_sha"
    fi
    closeout_pr_remote_oid="$terminal_sha"
  fi
  if [ "$closeout_pr_is_draft" = true ]; then
    fail_once ready
    if [ "$pr_provider" = gh ]; then
      gh pr ready "$bound_pr" >/dev/null
    else
      [ -z "${SHIP_FLOW_CLOSEOUT_PR_LOG:-}" ] || printf 'ready %s %s\n' "$bound_pr" "$terminal_sha" >>"$SHIP_FLOW_CLOSEOUT_PR_LOG"
      set_registry_field "$registry" is_draft false
    fi
    closeout_pr_is_draft=false
  fi
  [ "$closeout_pr_remote_oid" = "$terminal_sha" ] && [ "$closeout_pr_is_draft" = false ] || reject_input closeout-checkpoint-conflict "provider closeout PR is not published at the exact terminal OID and ready"
}

reconcile_pull_request_bundle() {
  local review_file="$workflow_dir/$entity_slug/review.md" ship_file="$workflow_dir/$entity_slug/ship.md"
  local merge_intent title envelope_file envelope_rc=0 bundle_root receipt_relative render_rc=0
  local debrief_relative active_relative deterministic_head prepared_source bound_pr landing_args current_receipt existing_phase existing_pr existing_proof rendered_proof resolved_pr
  [ -f "$review_file" ] || reject_input closeout-review-missing "review.md is required for terminal closeout"
  [ -f "$ship_file" ] || reject_input closeout-ship-missing "ship.md is required for terminal closeout"
  [ "$(git -C "$repo_root" symbolic-ref --quiet --short HEAD || true)" = main ] || reject_input closeout-main-not-authoritative "pull-request checkpoint requires authoritative main"
  [ -z "$(git -C "$repo_root" status --porcelain --untracked-files=all)" ] || reject_input closeout-checkpoint-conflict "authoritative main worktree is not clean"
  resolve_closeout_ownership
  merge_intent="$(resolve_merge_method_intent "$ship_file")"; title="$(read_frontmatter_field "$entity_path" title)"; [ -n "$title" ] || title="$entity_slug"
  validate_roadmap_title "$title"
  envelope_file="$(mktemp)"
  landing_args=(--repo-dir "$repo_root" --repository "$repository" --base-ref "$base_ref" --implementation-pr "$pr_number" --provider-merged-at "$merged_at" --landing-anchor "$landing_anchor" --source-commits "$source_commits" --pr-commit-count "$pr_commit_count")
  [ -n "$merge_intent" ] && landing_args+=(--merge-method-intent "$merge_intent")
  "$LANDING_RESOLVER" "${landing_args[@]}" >"$envelope_file" 2>&1 || envelope_rc=$?
  if [ "$envelope_rc" -ne 0 ]; then cat "$envelope_file"; rm -f "$envelope_file"; exit "$envelope_rc"; fi
  bundle_root="$(mktemp -d)"; receipt_relative="$(prepare_direct_bundle "$bundle_root" "$envelope_file" "$title" "$merge_intent")" || render_rc=$?; rm -f "$envelope_file"
  [ "$render_rc" -eq 0 ] || { rm -rf "$bundle_root"; reject_input closeout-stage-artifacts-incoherent "failed to render coherent closeout bundle"; }
  debrief_relative="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["outputs"]["debrief"]["path"])' "$bundle_root/$receipt_relative")"
  "$DEBRIEF_VALIDATOR" "$bundle_root/$debrief_relative" >/dev/null || { rm -rf "$bundle_root"; reject_input closeout-stage-artifacts-incoherent "rendered debrief fails schema validation"; }
  active_relative="$(python3 - "$repo_root" "$entity_path" <<'PY'
import pathlib,sys
print(pathlib.Path(sys.argv[2]).resolve().parent.relative_to(pathlib.Path(sys.argv[1]).resolve()).as_posix())
PY
)"
  deterministic_head="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["deterministic_closeout_head"])' "$bundle_root/$receipt_relative")"
  prepared_source="$bundle_root/$receipt_relative"
  rendered_proof="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["proof_hash"])' "$prepared_source")"
  current_receipt="$repo_root/$receipt_relative"; existing_phase=""; existing_pr=""; existing_proof=""
  if [ -f "$current_receipt" ]; then
    IFS='|' read -r existing_phase existing_pr existing_proof < <(python3 - "$current_receipt" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); t=r["transaction"]
print(t["phase"],t["closeout_pr"] or "",r["proof_hash"],sep="|")
PY
)
    [ "$existing_proof" = "$rendered_proof" ] || { rm -rf "$bundle_root"; reject_input closeout-proof-hash-mismatch "existing optional checkpoint differs from rendered terminal proof"; }
    case "$existing_phase" in
      prepared|awaiting_closeout_pr) ;;
      *) rm -rf "$bundle_root"; reject_input closeout-checkpoint-conflict "active optional flow has an unsupported receipt phase" ;;
    esac
  fi
  terminal_action="closeout_pull_request"
  if [ "$dry_run" = yes ]; then rm -rf "$bundle_root"; state_name="closeout_pr_planned"; detail="prepared checkpoint and deterministic closeout PR planned"; return 0; fi
  if [ "$existing_phase" != awaiting_closeout_pr ]; then
    checkpoint_optional_receipt "$prepared_source" "$receipt_relative" prepared 1 null
    if [ "${SHIP_FLOW_CLOSEOUT_FAILPOINT:-}" = after-prepared ]; then rm -rf "$bundle_root"; prompt_captain closeout-checkpoint-conflict "injected failure after prepared receipt checkpoint"; fi
    resolve_or_create_closeout_pr "$deterministic_head" "$title" "$receipt_relative"
    bound_pr="$closeout_pr_number"
    if [ "${SHIP_FLOW_CLOSEOUT_FAILPOINT:-}" = after-pr-create ]; then rm -rf "$bundle_root"; prompt_captain closeout-checkpoint-conflict "injected failure after exact-head PR creation"; fi
    checkpoint_optional_receipt "$prepared_source" "$receipt_relative" awaiting_closeout_pr 2 "$bound_pr"
  else
    bound_pr="$existing_pr"
    resolve_or_create_closeout_pr "$deterministic_head" "$title" "$receipt_relative"
    resolved_pr="$closeout_pr_number"
    [ "$resolved_pr" = "$bound_pr" ] || { rm -rf "$bundle_root"; reject_input closeout-checkpoint-conflict "existing awaiting receipt PR differs from exact-head provider PR"; }
  fi
  if [ "${SHIP_FLOW_CLOSEOUT_FAILPOINT:-}" = after-awaiting ]; then rm -rf "$bundle_root"; prompt_captain closeout-checkpoint-conflict "injected failure after awaiting receipt checkpoint"; fi
  build_optional_terminal_head "$bundle_root" "$receipt_relative" "$active_relative" "$deterministic_head" "$bound_pr"
  if [ "${SHIP_FLOW_CLOSEOUT_FAILPOINT:-}" = after-terminal-head ]; then rm -rf "$bundle_root"; prompt_captain closeout-checkpoint-conflict "injected failure after terminal head preparation"; fi
  rm -rf "$bundle_root"
  verdict="PROCEED"; pr_number="$bound_pr"; pr_state="OPEN"; reason="closeout-pr-awaiting-merge"; state_name="closeout_pr_awaiting_merge"
  detail="prepared checkpoint, exact deterministic head, and one bound closeout PR await merge"
}

workflow_dir=""
entity_ref=""
closeout_mode="direct"
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
repository=""
landing_anchor=""
source_commits=""
pr_commit_count=""
ownership_match_count=""
ownership_participants=""
archived_ship=""
archived_marker_mode="legacy"
archived_marker_id=""
archived_marker_receipt=""
archived_receipt_id=""
archived_receipt_relative=""
closeout_pr_number=""
closeout_pr_state=""
closeout_pr_head=""
closeout_pr_local_oid=""
closeout_pr_remote_oid=""
closeout_pr_is_draft=""

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
    --closeout-mode)
      [ "$#" -ge 2 ] || reject_usage "missing-closeout-mode" "--closeout-mode requires direct or pull-request"
      closeout_mode="$2"
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
case "$closeout_mode" in
  direct|pull-request) ;;
  *) reject_usage "unsupported-closeout-mode" "--closeout-mode must be direct or pull-request" ;;
esac
if [ "$pr_provider" = "fixture" ] && [ -z "$pr_fixture" ]; then
  reject_usage "missing-pr-fixture" "--pr-fixture is required for fixture provider"
fi

repo_root="$(git -C "$workflow_dir" rev-parse --show-toplevel 2>/dev/null || true)"
[ -n "$repo_root" ] || reject_input "workflow-dir-not-in-git" "workflow directory is not in a git repository"

# Receipt-only crash recovery must run before ordinary active/archive entity
# lookup because the terminal projection intentionally removes the active path.
scan_closeout_receipts

active_resolve="$(resolve_entity "$entity_ref" no || true)"
if [ -z "$active_resolve" ]; then
  archived_resolve="$(resolve_entity "archive:${entity_ref}" yes || true)"
  if [ -z "$archived_resolve" ]; then
    reject_input "entity-not-found" "entity reference could not be resolved"
  fi
  entity_slug="$(resolve_line_field slug "$archived_resolve")"
  entity_path="$(resolve_line_field path "$archived_resolve")"
  if coherent_terminal_file "$entity_path"; then
    pr_number="$(normalize_pr_number "$(read_frontmatter_field "$entity_path" pr)" || true)"
    [ -n "$pr_number" ] || reject_input invalid-pr "archived entity PR is invalid"
    archived_ship_candidate="$(dirname "$entity_path")/ship.md"
    if [ -f "$archived_ship_candidate" ]; then
      classify_archived_ship "$archived_ship_candidate"
    else
      archived_marker_mode="legacy"
    fi
    case "$archived_marker_mode" in
      invalid)
        reject_input closeout-sentinel-invalid "final ship has incomplete or malformed closeout markers"
        ;;
      receipt)
        validate_archived_direct_receipt
        [ "$archived_marker_id" = "$archived_receipt_id" ] && [ "$archived_marker_receipt" = "$archived_receipt_relative" ] ||
          reject_input closeout-sentinel-identity-mismatch "final ship closeout markers do not match validated receipt identity"
      case "$pr_provider" in
        fixture) read_provider_fixture "$pr_fixture" ;;
        gh) read_provider_gh ;;
      esac
      [ "$pr_state" = MERGED ] || prompt_captain pr-not-merged "archived closeout provider no longer reports MERGED"
      worktree_value="$(awk -F: '$1=="source_worktree"{sub(/^[^:]*:[[:space:]]*/, ""); print; exit}' "$archived_ship")"
      if [ -n "$worktree_value" ]; then
        preflight_worktree_cleanup "$worktree_value"
        if [ -z "${cleanup_branch:-}" ] && git -C "$repo_root" show-ref --verify --quiet "refs/heads/$head_ref"; then
          cleanup_branch="$head_ref"
          branch_cleanup="planned"
        fi
        remove_worktree_if_safe
        cleanup_branch_if_safe
      fi
        ;;
      legacy) ;;
      *) reject_input closeout-sentinel-invalid "final ship closeout marker classification failed" ;;
    esac
    verdict="PROCEED"
    state_name="already_reconciled"
    terminal_action="already_reconciled"
    pr_state="MERGED"
    detail="archived entity receipt and terminal outputs are coherent; cleanup retried where applicable"
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

require_landing_contract
acquire_source_objects "$repo_root"

if [ "$closeout_mode" = pull-request ]; then
  reconcile_pull_request_bundle
  emit_report
  exit 0
fi

preflight_worktree_cleanup "$worktree_value"
terminal_action="set_done"

reconcile_direct_bundle
remove_worktree_if_safe
cleanup_branch_if_safe
verdict="PROCEED"
reason="merged-pr-reconciled"
emit_report
exit 0
