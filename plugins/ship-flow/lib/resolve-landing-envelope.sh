#!/usr/bin/env bash
# resolve-landing-envelope.sh - prove the exact landing set for one merged PR

set -euo pipefail

usage() {
  cat >&2 <<'EOF'
Usage: resolve-landing-envelope.sh \
  --repo-dir <git-worktree> \
  --repository <owner/name> \
  --base-ref <ref> \
  --implementation-pr <positive-integer> \
  --provider-merged-at <rfc3339> \
  --landing-anchor <40-hex> \
  --source-commits <40-hex[,40-hex...]> \
  --pr-commit-count <positive-integer> \
  [--merge-method-intent rebase|squash|merge_commit]
EOF
}

reject() {
  local reason="$1"
  local detail="$2"
  printf 'verdict=REJECT\n'
  printf 'reason=%s\n' "$reason"
  printf 'detail=%s\n' "$detail"
  exit 2
}

join_by_comma() {
  local output="" value
  for value in "$@"; do
    if [ -n "$output" ]; then
      output="${output},${value}"
    else
      output="$value"
    fi
  done
  printf '%s\n' "$output"
}

empty_patch_id() {
  if command -v shasum >/dev/null 2>&1; then
    printf 'ship-flow-empty-patch-v1\n' | shasum | awk '{print $1}'
  else
    printf 'ship-flow-empty-patch-v1\n' | sha1sum | awk '{print $1}'
  fi
}

commit_patch_id() {
  local repo="$1"
  local commit="$2"
  local parent_line
  local parent_fields=()
  local patch_id

  parent_line="$(git -C "$repo" rev-list --parents -n 1 "$commit")"
  read -r -a parent_fields <<< "$parent_line"
  if [ "${#parent_fields[@]}" -gt 2 ]; then
    patch_id="$(
      git -C "$repo" diff --no-ext-diff --binary "${commit}^1" "$commit" |
        git patch-id --stable |
        awk 'NR == 1 { print $1; exit }'
    )"
  else
    patch_id="$(
      git -C "$repo" show --format= --no-ext-diff --binary "$commit" |
        git patch-id --stable |
        awk 'NR == 1 { print $1; exit }'
    )"
  fi
  if [ -n "$patch_id" ]; then
    printf '%s\n' "$patch_id"
  else
    empty_patch_id
  fi
}

ordered_patch_ids() {
  local repo="$1"
  shift
  local ids=() commit patch_id
  for commit in "$@"; do
    patch_id="$(commit_patch_id "$repo" "$commit")"
    [ -n "$patch_id" ] || return 1
    ids+=("$patch_id")
  done
  join_by_comma "${ids[@]}"
}

sha256_text() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 | awk '{print $1}'
  else
    sha256sum | awk '{print $1}'
  fi
}

aggregate_patch_digest() {
  local repo="$1"
  local from="$2"
  local to="$3"
  local patch_id
  patch_id="$(
    git -C "$repo" diff --no-ext-diff --binary "$from" "$to" |
      git patch-id --stable |
      awk 'NR == 1 { print $1; exit }'
  )"
  [ -n "$patch_id" ] || return 1
  printf '%s\n' "$patch_id" | sha256_text
}

full_sha() {
  [[ "$1" =~ ^[0-9a-fA-F]{40}$ ]]
}

github_repository_identity() {
  local value="$1"
  local owner name

  case "$value" in
    */*)
      owner="${value%%/*}"
      name="${value#*/}"
      ;;
    *) return 1 ;;
  esac

  [ "${name#*/}" = "$name" ] || return 1
  [ "${#owner}" -le 39 ] && [ "${#name}" -le 100 ] || return 1
  [[ "$owner" =~ ^[A-Za-z0-9]([A-Za-z0-9-]*[A-Za-z0-9])?$ ]] || return 1
  [[ "$name" =~ ^[A-Za-z0-9._-]+$ ]] || return 1
  [ "$name" != "." ] && [ "$name" != ".." ]
}

rfc3339_time() {
  [[ "$1" =~ ^[0-9]{4}-(0[1-9]|1[0-2])-([0-2][0-9]|3[01])T([01][0-9]|2[0-3]):[0-5][0-9]:([0-5][0-9]|60)(\.[0-9]+)?(Z|[+-]([01][0-9]|2[0-3]):[0-5][0-9])$ ]]
}

register_candidate() {
  local strategy_name="$1"
  local proof_key="$2"
  local candidate_index=0

  # Exact anchor + fixed topology currently construct one landing set per
  # strategy, so same-strategy patch ambiguity is unreachable. Keep this
  # defensive branch at the registration boundary: a future range enumerator
  # must stop rather than silently choose between two equivalent proof sets.
  while [ "$candidate_index" -lt "${#candidates[@]}" ]; do
    if [ "${candidates[$candidate_index]}" = "$strategy_name" ]; then
      if [ "${candidate_proofs[$candidate_index]}" != "$proof_key" ]; then
        reject "landing-patch-equivalence-ambiguous" "same-strategy landing proof produced multiple candidate sets"
      fi
      return 0
    fi
    candidate_index=$((candidate_index + 1))
  done

  candidates+=("$strategy_name")
  candidate_proofs+=("$proof_key")
}

repo_dir=""
repository=""
base_ref=""
implementation_pr=""
provider_merged_at=""
landing_anchor=""
source_commits_raw=""
pr_commit_count=""
merge_method_intent=""

while [ "$#" -gt 0 ]; do
  case "$1" in
    --repo-dir)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      repo_dir="$2"
      shift 2
      ;;
    --repository)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      repository="$2"
      shift 2
      ;;
    --base-ref)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      base_ref="$2"
      shift 2
      ;;
    --implementation-pr)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      implementation_pr="$2"
      shift 2
      ;;
    --provider-merged-at)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      provider_merged_at="$2"
      shift 2
      ;;
    --landing-anchor)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      landing_anchor="$2"
      shift 2
      ;;
    --source-commits)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      source_commits_raw="$2"
      shift 2
      ;;
    --pr-commit-count)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      pr_commit_count="$2"
      shift 2
      ;;
    --merge-method-intent)
      [ "$#" -ge 2 ] || { usage; exit 2; }
      merge_method_intent="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      usage
      exit 2
      ;;
  esac
done

if [ -z "$repo_dir" ] || ! git -C "$repo_dir" rev-parse --git-dir >/dev/null 2>&1; then
  reject "landing-topology-unsupported" "repository is not a Git worktree"
fi
github_repository_identity "$repository" ||
  reject "landing-topology-unsupported" "repository identity must be a single-line owner/name identifier"
[ -n "$base_ref" ] || reject "landing-topology-unsupported" "base ref is required"
[ -n "$provider_merged_at" ] || reject "merged-at-missing" "provider merge time is required"
rfc3339_time "$provider_merged_at" ||
  reject "merged-at-missing" "provider merge time must be RFC3339"
[[ "$implementation_pr" =~ ^[1-9][0-9]*$ ]] ||
  reject "landing-topology-unsupported" "implementation PR must be a positive integer"
full_sha "$landing_anchor" || reject "landing-anchor-missing" "landing anchor must be a full 40-character SHA"
git -C "$repo_dir" cat-file -e "${landing_anchor}^{commit}" 2>/dev/null ||
  reject "landing-anchor-missing" "landing anchor commit is unavailable"
git -C "$repo_dir" rev-parse --verify "${base_ref}^{commit}" >/dev/null 2>&1 ||
  reject "landing-topology-unsupported" "base ref is unavailable"
git -C "$repo_dir" merge-base --is-ancestor "$landing_anchor" "$base_ref" 2>/dev/null ||
  reject "landing-anchor-unreachable" "landing anchor is not reachable from the named base"

[[ "$pr_commit_count" =~ ^[1-9][0-9]*$ ]] ||
  reject "landing-pr-commit-count-mismatch" "PR commit count must be a positive integer"

SOURCE_COMMITS=()
IFS=',' read -r -a SOURCE_COMMITS <<< "$source_commits_raw"
[ "${#SOURCE_COMMITS[@]}" -eq "$pr_commit_count" ] ||
  reject "landing-pr-commit-count-mismatch" "declared count does not match ordered source commits"

source_commit=""
for source_commit in "${SOURCE_COMMITS[@]}"; do
  full_sha "$source_commit" ||
    reject "landing-patch-equivalence-failed" "source commits must be full 40-character SHAs"
  git -C "$repo_dir" cat-file -e "${source_commit}^{commit}" 2>/dev/null ||
    reject "landing-patch-equivalence-failed" "source commit is unavailable"
done

case "$merge_method_intent" in
  ""|rebase|squash|merge_commit) ;;
  *) reject "landing-method-intent-mismatch" "merge method intent is not supported" ;;
esac

source_first="${SOURCE_COMMITS[0]}"
source_last="${SOURCE_COMMITS[$((${#SOURCE_COMMITS[@]} - 1))]}"
source_base="$(git -C "$repo_dir" rev-parse "${source_first}^" 2>/dev/null || true)"
[ -n "$source_base" ] ||
  reject "landing-topology-unsupported" "first source commit has no parent"
source_patch_ids="$(ordered_patch_ids "$repo_dir" "${SOURCE_COMMITS[@]}" || true)"
[ -n "$source_patch_ids" ] ||
  reject "landing-patch-equivalence-failed" "source commit patch identity is unavailable"
source_patch_digest="$(aggregate_patch_digest "$repo_dir" "$source_base" "$source_last" || true)"
[ -n "$source_patch_digest" ] ||
  reject "landing-patch-equivalence-failed" "source aggregate patch is empty"

parent_line="$(git -C "$repo_dir" rev-list --parents -n 1 "$landing_anchor")"
read -r -a parent_fields <<< "$parent_line"
parent_count=$((${#parent_fields[@]} - 1))
if [ "$parent_count" -ne 1 ] && [ "$parent_count" -ne 2 ]; then
  reject "landing-topology-unsupported" "landing anchor must have one or two parents"
fi

valid_rebase="no"
valid_squash="no"
valid_merge_commit="no"
count_problem="no"

rebase_commits=()
rebase_patch_ids=""
rebase_patch_digest=""
rebase_base_before=""

squash_commits=()
squash_patch_ids=""
squash_patch_digest=""
squash_base_before=""

merge_commits=()
merge_patch_ids=""
merge_patch_digest=""
merge_base_before=""

if [ "$parent_count" -eq 1 ]; then
  reverse_rebase_commits=()
  while IFS= read -r commit; do
    [ -n "$commit" ] && reverse_rebase_commits+=("$commit")
  done < <(git -C "$repo_dir" rev-list --first-parent --max-count="$pr_commit_count" "$landing_anchor")
  if [ "${#reverse_rebase_commits[@]}" -eq "$pr_commit_count" ]; then
    i=$((${#reverse_rebase_commits[@]} - 1))
    while [ "$i" -ge 0 ]; do
      rebase_commits+=("${reverse_rebase_commits[$i]}")
      i=$((i - 1))
    done
    rebase_base_before="$(git -C "$repo_dir" rev-parse --verify "${rebase_commits[0]}^1" 2>/dev/null || true)"
    if [ -n "$rebase_base_before" ]; then
      rebase_patch_ids="$(ordered_patch_ids "$repo_dir" "${rebase_commits[@]}" || true)"
      rebase_patch_digest="$(aggregate_patch_digest "$repo_dir" "$rebase_base_before" "$landing_anchor" || true)"
      if [ "$rebase_patch_ids" = "$source_patch_ids" ] && [ "$rebase_patch_digest" = "$source_patch_digest" ]; then
        valid_rebase="yes"
      fi
    else
      count_problem="yes"
    fi
  else
    count_problem="yes"
  fi

  squash_base_before="${parent_fields[1]}"
  squash_commits=("$landing_anchor")
  squash_patch_ids="$(ordered_patch_ids "$repo_dir" "$landing_anchor" || true)"
  squash_patch_digest="$(aggregate_patch_digest "$repo_dir" "$squash_base_before" "$landing_anchor" || true)"
  if [ -n "$squash_patch_ids" ] && [ "$squash_patch_digest" = "$source_patch_digest" ]; then
    valid_squash="yes"
  fi
else
  merge_base_before="${parent_fields[1]}"
  merge_topic_tip="${parent_fields[2]}"
  merge_source_base="$(git -C "$repo_dir" merge-base "$merge_base_before" "$source_last" 2>/dev/null || true)"
  [ -n "$merge_source_base" ] ||
    reject "landing-topology-unsupported" "source tip has no common base with the landing base"
  source_patch_digest="$(aggregate_patch_digest "$repo_dir" "$merge_source_base" "$source_last" || true)"
  [ -n "$source_patch_digest" ] ||
    reject "landing-patch-equivalence-failed" "source effective aggregate patch is empty"
  while IFS= read -r commit; do
    [ -n "$commit" ] && merge_commits+=("$commit")
  done < <(git -C "$repo_dir" rev-list --reverse --topo-order "${merge_base_before}..${merge_topic_tip}")
  if [ "${#merge_commits[@]}" -eq "$pr_commit_count" ]; then
    merge_patch_ids="$(ordered_patch_ids "$repo_dir" "${merge_commits[@]}" || true)"
    merge_patch_digest="$(aggregate_patch_digest "$repo_dir" "$merge_base_before" "$landing_anchor" || true)"
    if [ "$merge_patch_ids" = "$source_patch_ids" ] && [ "$merge_patch_digest" = "$source_patch_digest" ]; then
      valid_merge_commit="yes"
    fi
  else
    count_problem="yes"
  fi
fi

candidates=()
candidate_proofs=()
if [ "$valid_rebase" = "yes" ]; then
  register_candidate rebase "$(join_by_comma "${rebase_commits[@]}")|${rebase_patch_ids}|${rebase_patch_digest}"
fi
if [ "$valid_squash" = "yes" ]; then
  register_candidate squash "$(join_by_comma "${squash_commits[@]}")|${squash_patch_ids}|${squash_patch_digest}"
fi
if [ "$valid_merge_commit" = "yes" ]; then
  register_candidate merge_commit "$(join_by_comma "${merge_commits[@]}" "$landing_anchor")|${merge_patch_ids}|${merge_patch_digest}"
fi

if [ "${#candidates[@]}" -eq 0 ]; then
  if [ "$count_problem" = "yes" ]; then
    reject "landing-pr-commit-count-mismatch" "landing topology does not contain the declared commit count"
  fi
  reject "landing-patch-equivalence-failed" "landing patches do not equal the ordered source and aggregate proof"
fi

strategy=""
method_source="topology"
if [ "${#candidates[@]}" -gt 1 ]; then
  [ -n "$merge_method_intent" ] ||
    reject "landing-method-ambiguous" "multiple landing methods satisfy the proof"
  candidate=""
  for candidate in "${candidates[@]}"; do
    if [ "$candidate" = "$merge_method_intent" ]; then
      strategy="$candidate"
      method_source="intent-discriminator"
      break
    fi
  done
  [ -n "$strategy" ] ||
    reject "landing-method-intent-mismatch" "intent does not select a proof-valid method"
else
  strategy="${candidates[0]}"
  if [ -n "$merge_method_intent" ] && [ "$merge_method_intent" != "$strategy" ]; then
    reject "landing-method-intent-mismatch" "intent conflicts with the proof-valid method"
  fi
fi

case "$strategy" in
  rebase)
    base_before="$rebase_base_before"
    landing_commits=("${rebase_commits[@]}")
    landing_patch_ids="$rebase_patch_ids"
    landing_patch_digest="$rebase_patch_digest"
    ;;
  squash)
    base_before="$squash_base_before"
    landing_commits=("${squash_commits[@]}")
    landing_patch_ids="$squash_patch_ids"
    landing_patch_digest="$squash_patch_digest"
    ;;
  merge_commit)
    base_before="$merge_base_before"
    landing_commits=("${merge_commits[@]}" "$landing_anchor")
    landing_patch_ids="$merge_patch_ids"
    landing_patch_digest="$merge_patch_digest"
    ;;
esac

printf 'schema_version=1\n'
printf 'repository=%s\n' "$repository"
printf 'base_ref=%s\n' "$base_ref"
printf 'implementation_pr=%s\n' "$implementation_pr"
printf 'provider_merged_at=%s\n' "$provider_merged_at"
printf 'landing_anchor=%s\n' "$landing_anchor"
printf 'base_before=%s\n' "$base_before"
printf 'strategy=%s\n' "$strategy"
printf 'strategy_evidence=topology+ordered-patch-ids+aggregate-patch-digest\n'
printf 'pr_commit_count=%s\n' "$pr_commit_count"
printf 'source_commit_patch_ids=%s\n' "$source_patch_ids"
printf 'source_patch_digest=%s\n' "$source_patch_digest"
printf 'landing_commits=%s\n' "$(join_by_comma "${landing_commits[@]}")"
printf 'landing_commit_patch_ids=%s\n' "$landing_patch_ids"
printf 'landing_patch_digest=%s\n' "$landing_patch_digest"
printf 'first_landing_commit=%s\n' "${landing_commits[0]}"
printf 'last_landing_commit=%s\n' "${landing_commits[$((${#landing_commits[@]} - 1))]}"
printf 'method_source=%s\n' "$method_source"
