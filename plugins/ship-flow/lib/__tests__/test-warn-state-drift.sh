#!/usr/bin/env bash
# test-warn-state-drift.sh - SessionStart state-drift hook contract
# Expected runtime: ~22-25s (many git-fixture operations). Allow >=30s timeout in CI runners.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/warn-state-drift.sh"

PASS=0
FAIL=0
ERRORS=()
TMP_DIR=""
CASE_FILTER=""
CASE_FILTERS=()

record_pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

record_fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

assert_exit() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected exit ${expected}, got ${actual})"
  fi
}

assert_contains() {
  local desc="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "$pattern" "$file"; then
    record_pass "$desc"
  else
    record_fail "$desc (missing pattern: ${pattern})"
  fi
}

assert_not_contains() {
  local desc="$1"
  local pattern="$2"
  local file="$3"
  if grep -qE "$pattern" "$file"; then
    record_fail "$desc (unexpected pattern: ${pattern})"
  else
    record_pass "$desc"
  fi
}

assert_file_exists() {
  local desc="$1"
  local file="$2"
  if [ -f "$file" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (missing file: ${file})"
  fi
}

assert_path_missing() {
  local desc="$1"
  local path="$2"
  if [ ! -e "$path" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (path still exists: ${path})"
  fi
}

assert_path_exists() {
  local desc="$1"
  local path="$2"
  if [ -e "$path" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (missing path: ${path})"
  fi
}

assert_equals() {
  local desc="$1"
  local expected="$2"
  local actual="$3"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected ${expected}, got ${actual})"
  fi
}

latest_commit_name_only() {
  local repo="$1"
  git -C "$repo" show --name-only --format= HEAD | sed '/^$/d'
}

latest_commit_name_status_no_renames() {
  local repo="$1"
  git -C "$repo" show --name-status --no-renames --format= HEAD | sed '/^$/d'
}

set_pr_states() {
  local pr="$1"
  local states="$2"
  printf '%s\n' "$states" > "$TMP_DIR/gh-state/${pr}.state"
  rm -f "$TMP_DIR/gh-state/${pr}.count"
}

frontmatter_field() {
  local file="$1"
  local field="$2"
  [ -f "$file" ] || return 1
  awk -v field="$field" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = field ":"
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

assert_frontmatter_equals() {
  local desc="$1"
  local file="$2"
  local field="$3"
  local expected="$4"
  local actual
  actual="$(frontmatter_field "$file" "$field")"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected ${field}=${expected}, got ${actual})"
  fi
}

assert_frontmatter_nonempty() {
  local desc="$1"
  local file="$2"
  local field="$3"
  local actual
  actual="$(frontmatter_field "$file" "$field")"
  if [ -n "$actual" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (${field} was empty)"
  fi
}

hash_tree() {
  local path="$1"
  if [ ! -d "$path" ]; then
    echo "missing"
    return
  fi
  find "$path" -type f -print | sort | while IFS= read -r file; do
    shasum -a 256 "$file"
  done | shasum -a 256 | awk '{print $1}'
}

write_workflow_readme() {
  local workflow_dir="$1"
  local auto_fix="${2:-off}"
  cat > "${workflow_dir}/README.md" <<EOF
---
commissioned-by: spacedock@0.22.0
auto_fix: ${auto_fix}
id-style: slug
stages:
  states:
    - name: ship
      next: done
    - name: done
      terminal: true
---

# Fixture Workflow
EOF
}

write_flat_entity() {
  local workflow_dir="$1"
  local slug="$2"
  local status="$3"
  local pr="$4"
  local worktree="${5:-}"

  cat > "${workflow_dir}/${slug}.md" <<EOF
---
id: ${slug}
title: "${slug}"
status: ${status}
pr: ${pr}
worktree: ${worktree}
completed:
verdict:
---

# ${slug}
EOF
}

write_folder_entity() {
  local workflow_dir="$1"
  local slug="$2"
  local status="$3"
  local pr="$4"
  local worktree="${5:-}"

  mkdir -p "${workflow_dir}/${slug}"
  cat > "${workflow_dir}/${slug}/index.md" <<EOF
---
id: ${slug}
title: "${slug}"
status: ${status}
pr: ${pr}
worktree: ${worktree}
completed:
verdict:
---

# ${slug}
EOF
}

setup_repo() {
  local repo="$1"
  local auto_fix="${2:-off}"
  git init -q "$repo"
  git -C "$repo" config user.email test@example.test
  git -C "$repo" config user.name "Ship Flow Test"
  mkdir -p "${repo}/docs/ship-flow"
  write_workflow_readme "${repo}/docs/ship-flow" "$auto_fix"
  echo "fixture" > "${repo}/README.md"
  git -C "$repo" add -- README.md docs/ship-flow/README.md
  git -C "$repo" commit -qm initial -- README.md docs/ship-flow/README.md
}

write_fixture_gh() {
  local bin_dir="$1"
  cat > "${bin_dir}/gh" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

[ "${1:-}" = "pr" ] && [ "${2:-}" = "view" ] || exit 2
pr="${3:-}"
shift 3 || true
state_file="${GH_STATE_DIR}/${pr}.state"
[ -f "$state_file" ] || exit 1
count_file="${GH_STATE_DIR}/${pr}.count"
count=0
[ -f "$count_file" ] && count="$(cat "$count_file")"
count=$((count + 1))
printf '%s' "$count" > "$count_file"
states="$(cat "$state_file")"
state="$(printf '%s\n' "$states" | awk -v n="$count" -F, '{ if (n <= NF) print $n; else print $NF }')"

# Mirror the REAL gh CLI's own output-shape split between the two flag forms
# this fixture is exercised with: the hook's own lighter Rule-A/re-probe scan
# passes `--json state -q .state` (bare state string, unchanged shape); the
# closeout-adapter.sh delegate this hook now calls passes `--json
# number,state,mergedAt,headRefName,baseRefName,url --jq '[...]'`
# (multi-field, one `key=value` per line — see read_provider_gh in
# bin/closeout-adapter.sh).
has_jq=0
for arg in "$@"; do
  [ "$arg" = "--jq" ] && has_jq=1
done

if [ "$has_jq" = "1" ]; then
  merged_at=""
  [ "$state" = "MERGED" ] && merged_at="2026-05-06T00:00:00Z"
  printf 'provider=gh\n'
  printf 'number=%s\n' "$pr"
  printf 'state=%s\n' "$state"
  printf 'merged_at=%s\n' "$merged_at"
  printf 'head_ref=fixture-head-%s\n' "$pr"
  printf 'base_ref=main\n'
  printf 'url=https://github.com/example/repo/pull/%s\n' "$pr"
else
  printf '%s\n' "$state"
fi
EOF
  chmod +x "${bin_dir}/gh"
}

write_fixture_status_bin() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

# --- merge guard <slug> --verdict <v> --workflow-dir <dir> ----------------
# Faithful encoding of the REAL installed spacedock `merge guard` contract
# (same fixture logic as test-closeout-adapter.sh's write_fixture_status_bin
# -- see 6.1-closeout-adapter-single-authority plan.md), extended to resolve
# EITHER a flat `<slug>.md` OR a folder `<slug>/index.md` entity since this
# hook's own fixtures write both shapes (write_flat_entity / write_folder_entity).
if [ "${1:-}" = merge ] && [ "${2:-}" = guard ]; then
  shift 2
  mg_slug="${1:-}"
  shift || true
  mg_workflow_dir=""
  mg_verdict=""
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --verdict) mg_verdict="$2"; shift 2 ;;
      --workflow-dir) mg_workflow_dir="$2"; shift 2 ;;
      --json|--quiet) shift ;;
      *) shift ;;
    esac
  done
  [ -n "$mg_workflow_dir" ] || { echo "Error: --workflow-dir required" >&2; exit 2; }
  [ -n "$mg_verdict" ] || { echo "Error: --verdict required" >&2; exit 2; }

  mg_frontmatter_field() {
    local file="$1" field="$2"
    awk -v field="$field" '
      /^---[[:space:]]*$/ { fence++; next }
      fence == 1 {
        prefix = field ":"
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
  mg_update_frontmatter_field() {
    local file="$1" field="$2" value="$3"
    local tmp="${file}.tmp"
    awk -v field="$field" -v value="$value" '
      /^---[[:space:]]*$/ { fence++; print; next }
      fence == 1 {
        prefix = field ":"
        if (index($0, prefix) == 1) {
          print field ": " value
          next
        }
      }
      { print }
    ' "$file" > "$tmp"
    mv "$tmp" "$file"
  }

  mg_active_path=""
  if [ -f "${mg_workflow_dir}/${mg_slug}.md" ]; then
    mg_active_path="${mg_workflow_dir}/${mg_slug}.md"
  elif [ -f "${mg_workflow_dir}/${mg_slug}/index.md" ]; then
    mg_active_path="${mg_workflow_dir}/${mg_slug}/index.md"
  fi
  mg_archived_path=""
  if [ -f "${mg_workflow_dir}/_archive/${mg_slug}.md" ]; then
    mg_archived_path="${mg_workflow_dir}/_archive/${mg_slug}.md"
  elif [ -f "${mg_workflow_dir}/_archive/${mg_slug}/index.md" ]; then
    mg_archived_path="${mg_workflow_dir}/_archive/${mg_slug}/index.md"
  fi

  if [ -n "$mg_archived_path" ]; then
    echo "Error: archived entity is read-only: ${mg_slug}" >&2
    exit 1
  fi
  if [ -z "$mg_active_path" ]; then
    echo "Error: entity not found: ${mg_slug}" >&2
    exit 1
  fi

  mg_pr="$(mg_frontmatter_field "$mg_active_path" pr)"
  case "$mg_pr" in
    pr-merge:*)
      mg_update_frontmatter_field "$mg_active_path" status done
      mg_update_frontmatter_field "$mg_active_path" verdict PASSED
      mg_update_frontmatter_field "$mg_active_path" completed 2026-05-06T00:00:00Z
      mg_update_frontmatter_field "$mg_active_path" worktree ""
      mkdir -p "${mg_workflow_dir}/_archive"
      case "$mg_active_path" in
        */index.md)
          mv "$(dirname "$mg_active_path")" "${mg_workflow_dir}/_archive/${mg_slug}"
          ;;
        *)
          mv "$mg_active_path" "${mg_workflow_dir}/_archive/${mg_slug}.md"
          ;;
      esac
      echo "finalized: ${mg_slug} -> done (verdict ${mg_verdict}), archived."
      exit 0
      ;;
    *)
      echo "blocked: PR ${mg_pr} is pending — mod-block left intact, never finalize on an open PR. When gh reports it MERGED, record the sentinel (pr=pr-merge:{number}) and re-run \`merge guard ${mg_slug}\`."
      exit 0
      ;;
  esac
fi

# `spacedock dispatch trunk --workflow-dir DIR` — trunk resolver the adapter's
# wrong-branch safety gate calls. Real 0.25.0 emits a bare branch name (default
# `main`); these fixtures init on `main`.
if [ "${1:-}" = dispatch ] && [ "${2:-}" = trunk ]; then
  echo main
  exit 0
fi

workflow_dir=""
include_archived=no
cmd=""
slug=""
ref=""

# Repoint: invoked as `spacedock status <args>` — skip leading subcommand.
[ "${1:-}" = status ] && shift

while [ "$#" -gt 0 ]; do
  case "$1" in
    --workflow-dir)
      workflow_dir="$2"
      shift 2
      ;;
    --archived)
      include_archived=yes
      shift
      ;;
    --resolve)
      cmd=resolve
      ref="$2"
      shift 2
      ;;
    --set)
      cmd=set
      slug="$2"
      shift 2
      break
      ;;
    --archive)
      cmd=archive
      slug="$2"
      shift 2
      ;;
    *)
      echo "unknown status arg: $1" >&2
      exit 2
      ;;
  esac
done

[ -n "$workflow_dir" ] || exit 2
[ -n "$cmd" ] || exit 2

entity_path_for_slug() {
  local slug_value="$1"
  if [ -f "${workflow_dir}/${slug_value}.md" ]; then
    printf '%s\n' "${workflow_dir}/${slug_value}.md"
    return
  fi
  if [ -f "${workflow_dir}/${slug_value}/index.md" ]; then
    printf '%s\n' "${workflow_dir}/${slug_value}/index.md"
    return
  fi
  return 1
}

archived_entity_path_for_slug() {
  local slug_value="$1"
  if [ -f "${workflow_dir}/_archive/${slug_value}.md" ]; then
    printf '%s\n' "${workflow_dir}/_archive/${slug_value}.md"
    return
  fi
  if [ -f "${workflow_dir}/_archive/${slug_value}/index.md" ]; then
    printf '%s\n' "${workflow_dir}/_archive/${slug_value}/index.md"
    return
  fi
  return 1
}

update_frontmatter_field() {
  local file="$1"
  local field="$2"
  local value="$3"
  local tmp="${file}.tmp"
  awk -v field="$field" -v value="$value" '
    /^---[[:space:]]*$/ { fence++; print; next }
    fence == 1 {
      prefix = field ":"
      if (index($0, prefix) == 1) {
        print field ": " value
        next
      }
    }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

case "$cmd" in
  resolve)
    slug_value="${ref#archive:}"
    if [ "$include_archived" = yes ]; then
      path="$(archived_entity_path_for_slug "$slug_value")" || exit 1
    else
      path="$(entity_path_for_slug "$slug_value")" || exit 1
    fi
    printf 'slug=%s path=%s\n' "$slug_value" "$path"
    ;;
  set)
    [ -n "$slug" ] || exit 2
    path="$(entity_path_for_slug "$slug")"
    for pair in "$@"; do
      key="${pair%%=*}"
      value="${pair#*=}"
      update_frontmatter_field "$path" "$key" "$value"
    done
    ;;
  archive)
    [ -n "$slug" ] || exit 2
    path="$(entity_path_for_slug "$slug")"
    mkdir -p "${workflow_dir}/_archive"
    case "$path" in
      "${workflow_dir}/${slug}.md")
        mv "$path" "${workflow_dir}/_archive/${slug}.md"
        ;;
      "${workflow_dir}/${slug}/index.md")
        mv "${workflow_dir}/${slug}" "${workflow_dir}/_archive/${slug}"
        ;;
      *)
        exit 2
        ;;
    esac
    ;;
esac
EOF
  chmod +x "$bin"
}

run_hook() {
  local repo="$1"
  local output="$2"
  shift 2
  local rc=0
  (
    cd "$repo"
    env -i \
      PATH="${HOOK_PATH:-$PATH}" \
      HOME="${TEST_HOME:-$TMP_DIR/home}" \
      GH_STATE_DIR="${GH_STATE_DIR:-$TMP_DIR/gh-state}" \
      SHIP_FLOW_STATUS_BIN="${SHIP_FLOW_STATUS_BIN:-}" \
      SHIP_FLOW_CLOSEOUT_ADAPTER_BIN="${SHIP_FLOW_CLOSEOUT_ADAPTER_BIN:-}" \
      "$HOOK" "$@" > "$output" 2>&1
  ) || rc=$?
  echo "$rc"
}

should_run_case() {
  local case_name="$1"
  if [ ${#CASE_FILTERS[@]} -eq 0 ]; then
    return 0
  fi
  local selected
  for selected in "${CASE_FILTERS[@]}"; do
    [ "$selected" = "$case_name" ] && return 0
  done
  return 1
}

run_harness_smoke_case() {
  local repo="$TMP_DIR/harness-smoke-repo"
  setup_repo "$repo" off
  local rc
  rc="$(run_hook "$repo" "$TMP_DIR/harness-smoke.out")"
  assert_exit "harness smoke exits success" 0 "$rc"
  if [ ! -s "$TMP_DIR/harness-smoke.out" ]; then
    record_pass "harness smoke emits no drift output"
  else
    record_fail "harness smoke emits no drift output"
  fi
}

run_auto_fix_off_case() {
  local repo="$TMP_DIR/auto-fix-off-repo"
  setup_repo "$repo" off
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#131"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md
  git -C "$repo" commit -qm "add flat merged entity" -- docs/ship-flow/flat-merged.md
  set_pr_states 131 "MERGED"

  local before after rc
  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_hook "$repo" "$TMP_DIR/auto-fix-off.out")"
  after="$(hash_tree "${repo}/docs/ship-flow")"

  assert_exit "auto_fix off exits success" 0 "$rc"
  assert_contains "auto_fix off reports Rule A pending" 'Rule A.*merged PR still at `status: ship`' "$TMP_DIR/auto-fix-off.out"
  assert_not_contains "auto_fix off does not auto-fix" 'Auto-fixed' "$TMP_DIR/auto-fix-off.out"
  assert_path_exists "auto_fix off keeps active flat entity" "${repo}/docs/ship-flow/flat-merged.md"
  assert_path_missing "auto_fix off does not archive flat entity" "${repo}/docs/ship-flow/_archive/flat-merged.md"
  if [ "$before" = "$after" ]; then
    record_pass "auto_fix off leaves workflow unchanged"
  else
    record_fail "auto_fix off leaves workflow unchanged"
  fi
}

run_delegates_to_adapter_case() {
  local repo="$TMP_DIR/delegates-to-adapter-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#501"
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#502"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add two rule-a entities" \
    -- docs/ship-flow/flat-merged.md docs/ship-flow/folder-merged
  set_pr_states 501 "MERGED"
  set_pr_states 502 "MERGED"

  # Spy/stub closeout-adapter.sh: records its invocation argv, then emits a
  # canned finalized-shaped emit_report so the hook classifies it as
  # auto-fixed without exercising the real adapter's own git/merge-guard
  # side effects (those are covered by run_execute_merged_case et al, which
  # exercise the REAL adapter). This case only asserts the CALL SHAPE.
  local spy_log="$TMP_DIR/adapter-spy.log"
  local spy_bin="$TMP_DIR/adapter-spy.sh"
  cat > "$spy_bin" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$spy_log"
slug=""
prev=""
for arg in "\$@"; do
  [ "\$prev" = "--entity" ] && slug="\$arg"
  prev="\$arg"
done
printf 'verdict=PROCEED\n'
printf 'entity=%s\n' "\$slug"
printf 'terminal_action=merge_guard_finalized\n'
printf 'state=reconciled\n'
printf 'debrief_due=%s\n' "\$slug"
exit 0
EOF
  chmod +x "$spy_bin"

  local rc
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  SHIP_FLOW_CLOSEOUT_ADAPTER_BIN="$spy_bin"
  rc="$(run_hook "$repo" "$TMP_DIR/delegates-to-adapter.out")"
  SHIP_FLOW_CLOSEOUT_ADAPTER_BIN=""
  SHIP_FLOW_STATUS_BIN=""

  assert_exit "delegates-to-adapter exits success" 0 "$rc"

  local spy_calls
  spy_calls="$(wc -l < "$spy_log" 2>/dev/null | tr -d ' ')"
  assert_equals "closeout-adapter invoked once per Rule-A record" "2" "${spy_calls:-0}"
  assert_contains "adapter invocation carries --workflow-dir" '\-\-workflow-dir' "$spy_log"
  assert_contains "adapter invocation carries --entity flat-merged" '\-\-entity flat-merged' "$spy_log"
  assert_contains "adapter invocation carries --entity folder-merged" '\-\-entity folder-merged' "$spy_log"
  assert_contains "adapter invocation carries --pr-provider gh" '\-\-pr-provider gh' "$spy_log"
  assert_contains "delegates-to-adapter reports auto-fixed" 'Auto-fixed' "$TMP_DIR/delegates-to-adapter.out"
  assert_contains "delegates-to-adapter reports debrief due" 'Debrief due' "$TMP_DIR/delegates-to-adapter.out"
}

run_execute_merged_case() {
  local repo="$TMP_DIR/execute-merged-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#131"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md
  git -C "$repo" commit -qm "add flat merged entity" -- docs/ship-flow/flat-merged.md
  set_pr_states 131 "MERGED"

  local rc
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/execute-merged.out")"
  SHIP_FLOW_STATUS_BIN=""

  assert_exit "execute merged exits success" 0 "$rc"
  assert_contains "execute merged reports auto-fixed" 'Auto-fixed' "$TMP_DIR/execute-merged.out"
  assert_file_exists "execute merged archives flat entity" "${repo}/docs/ship-flow/_archive/flat-merged.md"
  assert_path_missing "execute merged removes active flat entity" "${repo}/docs/ship-flow/flat-merged.md"
  assert_frontmatter_equals "execute merged status done" "${repo}/docs/ship-flow/_archive/flat-merged.md" status done
  assert_frontmatter_equals "execute merged verdict passed" "${repo}/docs/ship-flow/_archive/flat-merged.md" verdict PASSED
  assert_frontmatter_nonempty "execute merged completed stamped" "${repo}/docs/ship-flow/_archive/flat-merged.md" completed
  assert_frontmatter_equals "execute merged worktree cleared" "${repo}/docs/ship-flow/_archive/flat-merged.md" worktree ""
  assert_contains "execute merged creates closeout commit" 'docs/ship-flow/_archive/flat-merged.md' <(latest_commit_name_only "$repo")
}

run_dirty_tree_case() {
  local repo="$TMP_DIR/dirty-tree-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#131"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md
  git -C "$repo" commit -qm "add flat merged entity" -- docs/ship-flow/flat-merged.md
  echo "dirty" > "${repo}/dirty.txt"
  set_pr_states 131 "MERGED"

  local before after rc
  before="$(hash_tree "${repo}/docs/ship-flow")"
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/dirty-tree.out")"
  SHIP_FLOW_STATUS_BIN=""
  after="$(hash_tree "${repo}/docs/ship-flow")"

  assert_exit "dirty tree exits success" 0 "$rc"
  assert_contains "dirty tree reports blocked reason" 'working tree has uncommitted changes' "$TMP_DIR/dirty-tree.out"
  assert_path_exists "dirty tree keeps active entity" "${repo}/docs/ship-flow/flat-merged.md"
  assert_path_missing "dirty tree does not archive entity" "${repo}/docs/ship-flow/_archive/flat-merged.md"
  assert_equals "dirty tree leaves workflow unchanged" "$before" "$after"
}

run_missing_helper_case() {
  local repo="$TMP_DIR/missing-helper-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#131"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md
  git -C "$repo" commit -qm "add flat merged entity" -- docs/ship-flow/flat-merged.md
  set_pr_states 131 "MERGED"

  local before after rc
  before="$(hash_tree "${repo}/docs/ship-flow")"
  # Hermetic PATH: tool symlinks but no spacedock, so `command -v spacedock`
  # returns empty and the auto-fix is blocked on a missing status binary.
  HOOK_PATH="$NOSPACEDOCK_BIN"
  rc="$(run_hook "$repo" "$TMP_DIR/missing-helper.out")"
  unset HOOK_PATH
  after="$(hash_tree "${repo}/docs/ship-flow")"

  assert_exit "missing helper exits success" 0 "$rc"
  assert_contains "missing helper reports blocked reason" 'spacedock status binary not found' "$TMP_DIR/missing-helper.out"
  assert_path_missing "missing helper does not archive entity" "${repo}/docs/ship-flow/_archive/flat-merged.md"
  assert_equals "missing helper leaves workflow unchanged" "$before" "$after"
}

run_reprobe_not_merged_case() {
  local repo="$TMP_DIR/reprobe-not-merged-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#131"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md
  git -C "$repo" commit -qm "add flat merged entity" -- docs/ship-flow/flat-merged.md
  set_pr_states 131 "MERGED,OPEN"

  local before after rc
  before="$(hash_tree "${repo}/docs/ship-flow")"
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/reprobe-not-merged.out")"
  SHIP_FLOW_STATUS_BIN=""
  after="$(hash_tree "${repo}/docs/ship-flow")"

  assert_exit "re-probe not merged exits success" 0 "$rc"
  # The re-probe now lives inside closeout-adapter.sh's own read_provider_gh
  # (2nd `gh pr view` call, same fixture PR-state sequence "MERGED,OPEN" as
  # before): the adapter itself reports the still-open PR as a non-fatal
  # `pr_open_noop` no-op, which this hook surfaces as auto-fix-blocked.
  assert_contains "re-probe not merged reports blocked reason" 'pr_open_noop.*PR is still open' "$TMP_DIR/reprobe-not-merged.out"
  assert_path_missing "re-probe not merged does not archive entity" "${repo}/docs/ship-flow/_archive/flat-merged.md"
  assert_equals "re-probe not merged leaves workflow unchanged" "$before" "$after"
}

run_rule_b_folder_drift_case() {
  local repo="$TMP_DIR/rule-b-folder-drift-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-drift" "plan" ""
  echo "# Execute artifact" > "${repo}/docs/ship-flow/folder-drift/execute.md"
  git -C "$repo" add -- docs/ship-flow/folder-drift
  git -C "$repo" commit -qm "add rule b drift entity" -- docs/ship-flow/folder-drift

  local before after rc
  before="$(hash_tree "${repo}/docs/ship-flow")"
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/rule-b-folder-drift.out")"
  SHIP_FLOW_STATUS_BIN=""
  after="$(hash_tree "${repo}/docs/ship-flow")"

  assert_exit "Rule B exits success" 0 "$rc"
  assert_contains "Rule B reports folder drift" 'Rule B.*status: plan.*execute' "$TMP_DIR/rule-b-folder-drift.out"
  assert_path_missing "Rule B does not archive folder" "${repo}/docs/ship-flow/_archive/folder-drift/index.md"
  assert_equals "Rule B leaves workflow unchanged" "$before" "$after"
}

run_unsafe_pr_states_case() {
  local repo="$TMP_DIR/unsafe-pr-states-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "open-pr" "ship" "#201"
  write_flat_entity "${repo}/docs/ship-flow" "closed-pr" "ship" "#202"
  write_flat_entity "${repo}/docs/ship-flow" "empty-pr" "ship" ""
  write_flat_entity "${repo}/docs/ship-flow" "invalid-pr" "ship" "not-a-pr"
  git -C "$repo" add -- docs/ship-flow/open-pr.md docs/ship-flow/closed-pr.md docs/ship-flow/empty-pr.md docs/ship-flow/invalid-pr.md
  git -C "$repo" commit -qm "add unsafe pr entities" -- docs/ship-flow/open-pr.md docs/ship-flow/closed-pr.md docs/ship-flow/empty-pr.md docs/ship-flow/invalid-pr.md
  set_pr_states 201 "OPEN"
  set_pr_states 202 "CLOSED"

  local before after rc
  before="$(hash_tree "${repo}/docs/ship-flow")"
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/unsafe-pr-states.out")"
  SHIP_FLOW_STATUS_BIN=""
  after="$(hash_tree "${repo}/docs/ship-flow")"

  assert_exit "unsafe PR states exit success" 0 "$rc"
  assert_contains "open PR warning-only reason" 'open-pr.*PR #201 state=OPEN' "$TMP_DIR/unsafe-pr-states.out"
  assert_contains "closed PR warning-only reason" 'closed-pr.*PR #202 state=CLOSED' "$TMP_DIR/unsafe-pr-states.out"
  assert_contains "empty PR warning-only reason" 'empty-pr.*missing PR number' "$TMP_DIR/unsafe-pr-states.out"
  assert_contains "invalid PR warning-only reason" 'invalid-pr.*invalid PR value' "$TMP_DIR/unsafe-pr-states.out"
  assert_path_missing "open PR not archived" "${repo}/docs/ship-flow/_archive/open-pr.md"
  assert_path_missing "closed PR not archived" "${repo}/docs/ship-flow/_archive/closed-pr.md"
  assert_path_missing "empty PR not archived" "${repo}/docs/ship-flow/_archive/empty-pr.md"
  assert_path_missing "invalid PR not archived" "${repo}/docs/ship-flow/_archive/invalid-pr.md"
  assert_equals "unsafe PR states leave workflow unchanged" "$before" "$after"
}

run_flat_and_folder_case() {
  local repo="$TMP_DIR/flat-and-folder-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#301"
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#302"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add flat and folder merged entities" -- docs/ship-flow/flat-merged.md docs/ship-flow/folder-merged
  set_pr_states 301 "MERGED"
  set_pr_states 302 "MERGED"

  local rc
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/flat-and-folder.out")"
  SHIP_FLOW_STATUS_BIN=""

  assert_exit "flat and folder exits success" 0 "$rc"
  assert_contains "flat and folder reports flat auto-fix" 'flat-merged.*PR #301' "$TMP_DIR/flat-and-folder.out"
  assert_contains "flat and folder reports folder auto-fix" 'folder-merged.*PR #302' "$TMP_DIR/flat-and-folder.out"
  assert_file_exists "flat entity archived as flat md" "${repo}/docs/ship-flow/_archive/flat-merged.md"
  assert_file_exists "folder entity archived as folder index" "${repo}/docs/ship-flow/_archive/folder-merged/index.md"
  assert_path_missing "flat active path removed" "${repo}/docs/ship-flow/flat-merged.md"
  assert_path_missing "folder active path removed" "${repo}/docs/ship-flow/folder-merged"
}

run_pathspec_only_commit_case() {
  local repo="$TMP_DIR/pathspec-only-commit-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#401"
  echo "keep" > "${repo}/tracked.txt"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md tracked.txt
  git -C "$repo" commit -qm "add pathspec entity and tracked file" -- docs/ship-flow/flat-merged.md tracked.txt
  set_pr_states 401 "MERGED"

  local rc names
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/pathspec-only-commit.out")"
  SHIP_FLOW_STATUS_BIN=""
  names="$(latest_commit_name_status_no_renames "$repo")"

  assert_exit "pathspec-only commit exits success" 0 "$rc"
  assert_contains "pathspec-only commit reports auto-fixed" 'Auto-fixed' "$TMP_DIR/pathspec-only-commit.out"
  assert_contains "pathspec-only commit includes active flat delete" '^D[[:space:]]+docs/ship-flow/flat-merged.md$' <(printf '%s\n' "$names")
  assert_contains "pathspec-only commit includes archive destination" '^A[[:space:]]+docs/ship-flow/_archive/flat-merged.md$' <(printf '%s\n' "$names")
  assert_not_contains "pathspec-only commit excludes unrelated tracked file" 'tracked.txt' <(printf '%s\n' "$names")
  if [ -z "$(git -C "$repo" status --porcelain -- tracked.txt)" ]; then
    record_pass "pathspec-only leaves unrelated tracked file untouched"
  else
    record_fail "pathspec-only leaves unrelated tracked file untouched"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --case)
      CASE_FILTER="$2"
      CASE_FILTERS+=("$2")
      shift 2
      ;;
    *)
      echo "unsupported argument: $1" >&2
      exit 2
      ;;
  esac
done

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
mkdir -p "$TMP_DIR/bin" "$TMP_DIR/home" "$TMP_DIR/gh-state"
write_fixture_gh "$TMP_DIR/bin"
write_fixture_status_bin "$TMP_DIR/status-fixture"
PATH="$TMP_DIR/bin:$PATH"

# Hermetic "no spacedock" PATH: symlink every tool the hook needs, but
# deliberately omit `spacedock`, so the auto-fix discovery (`command -v
# spacedock`) returns empty even on hosts where spacedock is installed.
#
# Resolution strategy: `command -pv` first (canonical OS PATH, bypasses shell
# function wrappers and version-manager shims), then `command -v` as fallback
# for tools that live only in Homebrew/pyenv (e.g. timeout on macOS). Only
# accept absolute paths — a non-absolute result means a shell function or
# broken shim whose symlink would be self-referencing and unusable.
#
# Why this matters for cwd-independence (the portability bug fixed here):
#   - Claude Code wraps grep/find as shell functions; `command -v grep` → "grep"
#     (not an absolute path) → `ln -sf grep /nospacedock/grep` creates a
#     self-referencing symlink → every grep call inside the hook silently fails
#   - `command -v python3` → pyenv shim; shim calls grep+cut to resolve version;
#     grep broken in hermetic env → pyenv shim spins in an infinite loop → hang
#   - Both failures are cwd-independent bugs that only surface when the test's
#     surrounding shell session happens to have these function/shim wrappers
#     active, which differs across invocation contexts.
NOSPACEDOCK_BIN="$TMP_DIR/nospacedock-bin"
mkdir -p "$NOSPACEDOCK_BIN"
for tool in bash sh env git awk grep tr basename dirname find sort tail head timeout date python3 mktemp cat sed; do
  # Prefer standard-PATH canonical binary; fall back to full PATH for
  # Homebrew-only tools (e.g. timeout, bash 5.x). Skip if not absolute.
  tool_path="$(command -pv "$tool" 2>/dev/null || command -v "$tool" 2>/dev/null || true)"
  [[ "$tool_path" == /* ]] && ln -sf "$tool_path" "$NOSPACEDOCK_BIN/$tool"
done
# Fake gh from the fixture (no spacedock) so PR re-probe still works.
ln -sf "$TMP_DIR/bin/gh" "$NOSPACEDOCK_BIN/gh"

echo "=== test-warn-state-drift.sh ==="
echo ""

if [ ! -x "$HOOK" ]; then
  record_fail "hook exists and is executable (${HOOK})"
else
  record_pass "hook exists and is executable"
  should_run_case harness-smoke && run_harness_smoke_case
  should_run_case auto-fix-off && run_auto_fix_off_case
  should_run_case delegates-to-adapter && run_delegates_to_adapter_case
  should_run_case execute-merged && run_execute_merged_case
  should_run_case dirty-tree && run_dirty_tree_case
  should_run_case missing-helper && run_missing_helper_case
  should_run_case reprobe-not-merged && run_reprobe_not_merged_case
  should_run_case rule-b-folder-drift && run_rule_b_folder_drift_case
  should_run_case unsafe-pr-states && run_unsafe_pr_states_case
  should_run_case flat-and-folder && run_flat_and_folder_case
  should_run_case pathspec-only-commit && run_pathspec_only_commit_case
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi

echo "All assertions passed"
exit 0
