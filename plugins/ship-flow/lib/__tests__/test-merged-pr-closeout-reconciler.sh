#!/usr/bin/env bash
# test-merged-pr-closeout-reconciler.sh - merged PR closeout reconciler contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/bin/merged-pr-closeout-reconciler.sh"
STATUS_BIN="${STATUS_BIN:-/Users/kent/.codex/plugins/cache/spacedock/spacedock/0.10.2/skills/commission/bin/status}"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/merged-pr-closeout-reconciler"

PASS=0
FAIL=0
ERRORS=()

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

frontmatter_field() {
  local file="$1"
  local field="$2"
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
  cat > "${workflow_dir}/README.md" <<'EOF'
---
commissioned-by: spacedock@0.10.2
id-style: slug
stages:
  states:
    - name: ship
      next: done
      worktree: true
    - name: done
      terminal: true
      worktree: false
---

# Fixture Workflow
EOF
}

write_pr_merge_mod() {
  local workflow_dir="$1"
  mkdir -p "${workflow_dir}/_mods"
  cat > "${workflow_dir}/_mods/pr-merge.md" <<'EOF'
---
name: pr-merge
standing: true
---

## Agent Prompt

Fixture merge hook.
EOF
}

write_fixture_status_bin() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

workflow_dir=""
include_archived=no
cmd=""
ref=""
where_expr=""
slug=""

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
    --where)
      cmd=where
      where_expr="$2"
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

frontmatter_field() {
  local file="$1"
  local field="$2"
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

resolve_path() {
  local raw="$1"
  raw="${raw#archive:}"
  if [ "$include_archived" = yes ]; then
    printf '%s/_archive/%s/index.md\n' "$workflow_dir" "$raw"
  else
    printf '%s/%s/index.md\n' "$workflow_dir" "$raw"
  fi
}

case "$cmd" in
  resolve)
    path="$(resolve_path "$ref")"
    [ -f "$path" ] || exit 1
    slug_value="${ref#archive:}"
    printf 'slug=%s path=%s\n' "$slug_value" "$path"
    ;;
  where)
    slug_value="$(printf '%s\n' "$where_expr" | sed -E 's/^slug[[:space:]]*=[[:space:]]*//')"
    path="${workflow_dir}/_archive/${slug_value}/index.md"
    [ -f "$path" ] || exit 1
    printf 'slug=%s path=%s status=%s\n' "$slug_value" "$path" "$(frontmatter_field "$path" status)"
    ;;
  set)
    path="${workflow_dir}/${slug}/index.md"
    [ -f "$path" ] || exit 1
    for pair in "$@"; do
      case "$pair" in
        *=*)
          key="${pair%%=*}"
          value="${pair#*=}"
          ;;
        completed)
          key=completed
          value=2026-05-06T00:00:00Z
          ;;
        *)
          echo "unsupported set pair: $pair" >&2
          exit 2
          ;;
      esac
      update_frontmatter_field "$path" "$key" "$value"
    done
    ;;
  archive)
    path="${workflow_dir}/${slug}/index.md"
    [ -f "$path" ] || exit 1
    update_frontmatter_field "$path" archived 2026-05-06T00:01:00Z
    mkdir -p "${workflow_dir}/_archive"
    mv "${workflow_dir}/${slug}" "${workflow_dir}/_archive/${slug}"
    ;;
  *)
    echo "missing status command" >&2
    exit 2
    ;;
esac
EOF
  chmod +x "$bin"
}

write_entity() {
  local workflow_dir="$1"
  local slug="$2"
  local status="$3"
  local pr="$4"
  local worktree="$5"
  local completed="${6:-}"
  local verdict="${7:-}"
  local archived="${8:-}"

  mkdir -p "${workflow_dir}/${slug}"
  cat > "${workflow_dir}/${slug}/index.md" <<EOF
---
title: "Merged fixture entity"
status: ${status}
pr: ${pr}
worktree: ${worktree}
completed: ${completed}
verdict: ${verdict}
archived: ${archived}
---

# Merged fixture entity
EOF
}

setup_repo() {
  local repo="$1"
  git init -q "$repo"
  git -C "$repo" config user.email test@example.test
  git -C "$repo" config user.name "Ship Flow Test"
  mkdir -p "${repo}/docs/ship-flow"
  write_workflow_readme "${repo}/docs/ship-flow"
  write_pr_merge_mod "${repo}/docs/ship-flow"
  echo "fixture" > "${repo}/README.md"
  git -C "$repo" add README.md docs/ship-flow/README.md docs/ship-flow/_mods/pr-merge.md
  git -C "$repo" commit -qm initial
}

run_helper() {
  local repo="$1"
  local output="$2"
  shift 2
  local rc=0
  STATUS_BIN="$STATUS_BIN" "$HELPER" --workflow-dir "${repo}/docs/ship-flow" "$@" > "$output" 2>&1 || rc=$?
  echo "$rc"
}

run_helper_without_status_override() {
  local repo="$1"
  local output="$2"
  local home_dir="$3"
  shift 3
  local rc=0
  env -u STATUS_BIN HOME="$home_dir" "$HELPER" --workflow-dir "${repo}/docs/ship-flow" "$@" > "$output" 2>&1 || rc=$?
  echo "$rc"
}

run_helper_with_path() {
  local repo="$1"
  local output="$2"
  local path_value="$3"
  shift 3
  local rc=0
  PATH="$path_value" STATUS_BIN="$STATUS_BIN" "$HELPER" --workflow-dir "${repo}/docs/ship-flow" "$@" > "$output" 2>&1 || rc=$?
  echo "$rc"
}

run_runtime_regression_cases() {
  local repo="$TMP_DIR/default-status-repo"
  local fake_home="$TMP_DIR/fake-home"
  local cache_status="${fake_home}/.codex/plugins/cache/spacedock/spacedock/0.11.2/skills/commission/bin/status"
  setup_repo "$repo"
  mkdir -p "$(dirname "$cache_status")"
  write_fixture_status_bin "$cache_status"
  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add default status entity"

  local rc
  rc="$(run_helper_without_status_override "$repo" "$TMP_DIR/default-status.out" "$fake_home" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
    --dry-run)"
  assert_exit "default status helper resolves from active plugin cache" 0 "$rc"
  assert_not_contains "default status helper does not report missing helper" '^reason=missing-status-helper$' "$TMP_DIR/default-status.out"
  assert_not_contains "helper source does not pin stale 0.10.2 cache path" 'spacedock/0\.10\.2/skills/commission/bin/status' "$HELPER"

  local pipe_repo="$TMP_DIR/pipefail-repo"
  local worktree_path="${pipe_repo}/.worktrees/ship-merged-fixture-entity"
  setup_repo "$pipe_repo"
  mkdir -p "$worktree_path"
  write_entity "${pipe_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$pipe_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$pipe_repo" commit -qm "add pipefail entity"

  local fake_bin="$TMP_DIR/fake-bin"
  mkdir -p "$fake_bin"
  cat > "${fake_bin}/git" <<EOF
#!/usr/bin/env bash
set -euo pipefail
REAL_GIT="$(command -v git)"
REPO="$pipe_repo"
TARGET="$worktree_path"
repo_arg=""
if [ "\${1:-}" = "-C" ]; then
  repo_arg="\$2"
  shift 2
fi
if [ "\${1:-}" = "worktree" ] && [ "\${2:-}" = "list" ] && [ "\${3:-}" = "--porcelain" ]; then
  printf 'worktree %s\nHEAD fixture-main\nbranch refs/heads/main\n\n' "\$REPO"
  i=0
  while [ "\$i" -lt 3000 ]; do
    printf 'worktree %s/.worktrees/noise-%04d\nHEAD fixture-noise-%04d\nbranch refs/heads/noise-%04d\n\n' "\$REPO" "\$i" "\$i" "\$i"
    i=\$((i + 1))
  done
  printf 'worktree %s\nHEAD fixture-target\nbranch refs/heads/ship-merged-fixture-entity\n\n' "\$TARGET"
  exit 0
fi
if [ "\$repo_arg" = "\$TARGET" ] && [ "\${1:-}" = "status" ] && [ "\${2:-}" = "--porcelain" ]; then
  exit 0
fi
if [ -n "\$repo_arg" ]; then
  exec "\$REAL_GIT" -C "\$repo_arg" "\$@"
fi
exec "\$REAL_GIT" "\$@"
EOF
  chmod +x "${fake_bin}/git"

  rc="$(run_helper_with_path "$pipe_repo" "$TMP_DIR/pipefail-dry-run.out" "${fake_bin}:$PATH" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
    --dry-run)"
  assert_exit "dry-run survives large worktree list under pipefail" 0 "$rc"
  assert_contains "dry-run large worktree list plans cleanup" '^worktree_cleanup=planned$' "$TMP_DIR/pipefail-dry-run.out"
  assert_contains "dry-run large worktree list plans branch cleanup" '^branch_cleanup=planned$' "$TMP_DIR/pipefail-dry-run.out"
}

run_merged_fixture_case() {
  local repo="$TMP_DIR/merged-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add merged entity"

  local rc
  rc="$(run_helper "$repo" "$TMP_DIR/merged.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"

  assert_exit "merged fixture exits success" 0 "$rc"
  assert_contains "merged fixture proceeds" '^verdict=PROCEED$' "$TMP_DIR/merged.out"
  assert_contains "merged fixture reports PR state" '^pr_state=MERGED$' "$TMP_DIR/merged.out"
  assert_contains "merged fixture terminal action" '^terminal_action=set_done$' "$TMP_DIR/merged.out"
  assert_file_exists "merged fixture archives folder index" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md"
  assert_frontmatter_equals "archived entity status done" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" status done
  assert_frontmatter_nonempty "archived entity completed stamped" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" completed
  assert_frontmatter_equals "archived entity verdict passed" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" verdict PASSED
  assert_frontmatter_equals "archived entity worktree cleared" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" worktree ""

  local archived_rc=0
  "$STATUS_BIN" --workflow-dir "${repo}/docs/ship-flow" --archived --where "slug = merged-fixture-entity" > "$TMP_DIR/archived-status.out" 2>&1 || archived_rc=$?
  assert_exit "archived status query succeeds" 0 "$archived_rc"
  assert_contains "archived status query finds slug" 'merged-fixture-entity' "$TMP_DIR/archived-status.out"
}

run_refusal_cases() {
  local repo="$TMP_DIR/refusal-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add refusal entity"

  local before rc after
  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/open.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-open.env")"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "open PR exits success no-op" 0 "$rc"
  assert_contains "open PR reports noop" '^state=pr_open_noop$' "$TMP_DIR/open.out"
  if [ "$before" = "$after" ]; then
    record_pass "open PR leaves workflow unchanged"
  else
    record_fail "open PR leaves workflow unchanged"
  fi

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/closed.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-closed.env")"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "closed PR prompts captain" 1 "$rc"
  assert_contains "closed PR reports prompt" '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/closed.out"
  if [ "$before" = "$after" ]; then
    record_pass "closed PR leaves workflow unchanged"
  else
    record_fail "closed PR leaves workflow unchanged"
  fi

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/unknown.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-unknown.env")"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "unknown PR prompts captain" 1 "$rc"
  assert_contains "unknown PR reports prompt" '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/unknown.out"
  if [ "$before" = "$after" ]; then
    record_pass "unknown PR leaves workflow unchanged"
  else
    record_fail "unknown PR leaves workflow unchanged"
  fi

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/mismatch.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-mismatch.env")"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "PR mismatch rejects fixture" 2 "$rc"
  assert_contains "PR mismatch reports reason" '^reason=pr-number-mismatch$' "$TMP_DIR/mismatch.out"
  if [ "$before" = "$after" ]; then
    record_pass "PR mismatch leaves workflow unchanged"
  else
    record_fail "PR mismatch leaves workflow unchanged"
  fi
}

run_usage_and_dry_run_cases() {
  local repo="$TMP_DIR/usage-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add usage entity"

  local rc before after
  for flag in --tracker --linear --dashboard --create-pr --merge --force-merge --delete-remote-branch; do
    rc="$(run_helper "$repo" "${TMP_DIR}/unsupported-${flag#--}.out" \
      --entity merged-fixture-entity \
      --pr-provider fixture \
      --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
      "$flag")"
    assert_exit "unsupported ${flag} exits usage" 2 "$rc"
    assert_contains "unsupported ${flag} rejected" '^verdict=REJECT$' "${TMP_DIR}/unsupported-${flag#--}.out"
  done

  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/dry-run.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
    --dry-run)"
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "dry-run merged exits success" 0 "$rc"
  assert_contains "dry-run plans terminal action" '^terminal_action=set_done$' "$TMP_DIR/dry-run.out"
  if [ "$before" = "$after" ]; then
    record_pass "dry-run leaves workflow unchanged"
  else
    record_fail "dry-run leaves workflow unchanged"
  fi

  local active_done_repo="$TMP_DIR/dry-run-active-done-repo"
  setup_repo "$active_done_repo"
  write_entity "${active_done_repo}/docs/ship-flow" "merged-fixture-entity" "done" "#131" "" "2026-05-06T00:00:00Z" "PASSED"
  git -C "$active_done_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$active_done_repo" commit -qm "add active done entity"
  before="$(hash_tree "${active_done_repo}/docs/ship-flow")"
  rc="$(run_helper "$active_done_repo" "$TMP_DIR/dry-run-active-done.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env" \
    --dry-run)"
  after="$(hash_tree "${active_done_repo}/docs/ship-flow")"
  assert_exit "dry-run active done exits success" 0 "$rc"
  assert_contains "dry-run active done reports planned archive" '^state=already_done_archive_planned$' "$TMP_DIR/dry-run-active-done.out"
  assert_contains "dry-run active done does not claim archived now" '^detail=active terminal entity archive planned$' "$TMP_DIR/dry-run-active-done.out"
  if [ "$before" = "$after" ]; then
    record_pass "dry-run active done leaves workflow unchanged"
  else
    record_fail "dry-run active done leaves workflow unchanged"
  fi
}

run_cleanup_cases() {
  local repo="$TMP_DIR/cleanup-repo"
  setup_repo "$repo"
  mkdir -p "${repo}/.worktrees"

  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add cleanup entity"
  git -C "$repo" worktree add "${repo}/.worktrees/ship-merged-fixture-entity" -b ship-merged-fixture-entity >/dev/null 2>&1

  local rc
  rc="$(run_helper "$repo" "$TMP_DIR/cleanup.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit "clean worktree cleanup exits success" 0 "$rc"
  assert_contains "clean worktree removed" '^worktree_cleanup=removed$' "$TMP_DIR/cleanup.out"
  assert_contains "clean branch deleted" '^branch_cleanup=deleted$' "$TMP_DIR/cleanup.out"
  assert_path_missing "clean worktree path removed" "${repo}/.worktrees/ship-merged-fixture-entity"
  if git -C "$repo" show-ref --verify --quiet refs/heads/ship-merged-fixture-entity; then
    record_fail "clean branch deleted from repo"
  else
    record_pass "clean branch deleted from repo"
  fi

  local dirty_repo="$TMP_DIR/dirty-repo"
  setup_repo "$dirty_repo"
  mkdir -p "${dirty_repo}/.worktrees"
  write_entity "${dirty_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$dirty_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$dirty_repo" commit -qm "add dirty entity"
  git -C "$dirty_repo" worktree add "${dirty_repo}/.worktrees/ship-merged-fixture-entity" -b ship-merged-fixture-entity >/dev/null 2>&1
  echo "dirty" > "${dirty_repo}/.worktrees/ship-merged-fixture-entity/dirty.txt"
  local before after
  before="$(hash_tree "${dirty_repo}/docs/ship-flow")"
  rc="$(run_helper "$dirty_repo" "$TMP_DIR/dirty.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  after="$(hash_tree "${dirty_repo}/docs/ship-flow")"
  assert_exit "dirty worktree prompts captain" 1 "$rc"
  assert_contains "dirty worktree blocks cleanup" '^reason=dirty-worktree$' "$TMP_DIR/dirty.out"
  if [ "$before" = "$after" ]; then
    record_pass "dirty worktree leaves workflow unchanged"
  else
    record_fail "dirty worktree leaves workflow unchanged"
  fi

  local mismatch_repo="$TMP_DIR/mismatch-repo"
  setup_repo "$mismatch_repo"
  mkdir -p "${mismatch_repo}/.worktrees"
  write_entity "${mismatch_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/not-derived"
  git -C "$mismatch_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$mismatch_repo" commit -qm "add mismatch entity"
  git -C "$mismatch_repo" worktree add "${mismatch_repo}/.worktrees/not-derived" -b unexpected-branch >/dev/null 2>&1
  before="$(hash_tree "${mismatch_repo}/docs/ship-flow")"
  rc="$(run_helper "$mismatch_repo" "$TMP_DIR/branch-mismatch.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  after="$(hash_tree "${mismatch_repo}/docs/ship-flow")"
  assert_exit "branch mismatch prompts captain" 1 "$rc"
  assert_contains "branch mismatch reports reason" '^reason=branch-mismatch$' "$TMP_DIR/branch-mismatch.out"
  if [ "$before" = "$after" ]; then
    record_pass "branch mismatch leaves workflow unchanged"
  else
    record_fail "branch mismatch leaves workflow unchanged"
  fi

  local derived_repo="$TMP_DIR/derived-branch-repo"
  setup_repo "$derived_repo"
  mkdir -p "${derived_repo}/.worktrees"
  write_entity "${derived_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/not-pr-head"
  git -C "$derived_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$derived_repo" commit -qm "add derived branch entity"
  git -C "$derived_repo" worktree add "${derived_repo}/.worktrees/not-pr-head" -b not-pr-head >/dev/null 2>&1
  before="$(hash_tree "${derived_repo}/docs/ship-flow")"
  rc="$(run_helper "$derived_repo" "$TMP_DIR/derived-branch-mismatch.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  after="$(hash_tree "${derived_repo}/docs/ship-flow")"
  assert_exit "derived branch mismatch prompts captain" 1 "$rc"
  assert_contains "derived branch mismatch reports reason" '^reason=branch-mismatch$' "$TMP_DIR/derived-branch-mismatch.out"
  assert_path_exists "derived branch mismatch keeps worktree path" "${derived_repo}/.worktrees/not-pr-head"
  if [ "$before" = "$after" ]; then
    record_pass "derived branch mismatch leaves workflow unchanged"
  else
    record_fail "derived branch mismatch leaves workflow unchanged"
  fi

  local failure_repo="$TMP_DIR/archive-failure-repo"
  setup_repo "$failure_repo"
  mkdir -p "${failure_repo}/.worktrees"
  write_entity "${failure_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$failure_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$failure_repo" commit -qm "add archive failure entity"
  git -C "$failure_repo" worktree add "${failure_repo}/.worktrees/ship-merged-fixture-entity" -b ship-merged-fixture-entity >/dev/null 2>&1
  local failing_status="$TMP_DIR/failing-status"
  cat > "$failing_status" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  case "\$arg" in
    --archive) exit 43 ;;
  esac
done
exec "$STATUS_BIN" "\$@"
EOF
  chmod +x "$failing_status"
  local original_status="$STATUS_BIN"
  STATUS_BIN="$failing_status"
  rc="$(run_helper "$failure_repo" "$TMP_DIR/archive-failure.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  STATUS_BIN="$original_status"
  assert_exit "archive failure exits before cleanup" 43 "$rc"
  assert_path_exists "archive failure keeps worktree path" "${failure_repo}/.worktrees/ship-merged-fixture-entity"
  if git -C "$failure_repo" show-ref --verify --quiet refs/heads/ship-merged-fixture-entity; then
    record_pass "archive failure keeps worktree branch"
  else
    record_fail "archive failure keeps worktree branch"
  fi

  local missing_repo="$TMP_DIR/missing-repo"
  setup_repo "$missing_repo"
  write_entity "${missing_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/missing-local"
  git -C "$missing_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$missing_repo" commit -qm "add missing-local entity"
  rc="$(run_helper "$missing_repo" "$TMP_DIR/missing-local.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit "missing local worktree still reconciles" 0 "$rc"
  assert_contains "missing local worktree reported" '^worktree_cleanup=missing-local$' "$TMP_DIR/missing-local.out"

  local skipped_repo="$TMP_DIR/skipped-branch-repo"
  setup_repo "$skipped_repo"
  mkdir -p "${skipped_repo}/.worktrees"
  write_entity "${skipped_repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ".worktrees/ship-merged-fixture-entity"
  git -C "$skipped_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$skipped_repo" commit -qm "add skipped branch entity"
  git -C "$skipped_repo" worktree add "${skipped_repo}/.worktrees/ship-merged-fixture-entity" -b ship-merged-fixture-entity >/dev/null 2>&1
  echo "branch only" > "${skipped_repo}/.worktrees/ship-merged-fixture-entity/branch-only.txt"
  git -C "${skipped_repo}/.worktrees/ship-merged-fixture-entity" add branch-only.txt
  git -C "${skipped_repo}/.worktrees/ship-merged-fixture-entity" commit -qm "branch only"
  rc="$(run_helper "$skipped_repo" "$TMP_DIR/branch-skipped.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit "unmerged branch cleanup skipped but reconciles" 0 "$rc"
  assert_contains "unmerged branch cleanup skipped" '^branch_cleanup=skipped$' "$TMP_DIR/branch-skipped.out"
  if git -C "$skipped_repo" show-ref --verify --quiet refs/heads/ship-merged-fixture-entity; then
    record_pass "unmerged branch remains after skipped cleanup"
  else
    record_fail "unmerged branch remains after skipped cleanup"
  fi
}

run_idempotency_cases() {
  local active_done_repo="$TMP_DIR/active-done-repo"
  setup_repo "$active_done_repo"
  write_entity "${active_done_repo}/docs/ship-flow" "merged-fixture-entity" "done" "#131" "" "2026-05-06T00:00:00Z" "PASSED"
  git -C "$active_done_repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$active_done_repo" commit -qm "add active done entity"
  local rc
  rc="$(run_helper "$active_done_repo" "$TMP_DIR/active-done.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit "active done coherent archives now" 0 "$rc"
  assert_contains "active done reports archived now" '^state=already_done_archived_now$' "$TMP_DIR/active-done.out"
  assert_file_exists "active done archived file exists" "${active_done_repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md"

  local archived_repo="$TMP_DIR/archived-repo"
  setup_repo "$archived_repo"
  mkdir -p "${archived_repo}/docs/ship-flow/_archive/merged-fixture-entity"
  cat > "${archived_repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" <<'EOF'
---
title: "Archived fixture entity"
status: done
pr: "#131"
worktree:
completed: 2026-05-06T00:00:00Z
verdict: PASSED
archived: 2026-05-06T00:01:00Z
---

# Archived fixture entity
EOF
  git -C "$archived_repo" add docs/ship-flow/_archive/merged-fixture-entity/index.md
  git -C "$archived_repo" commit -qm "add archived entity"
  local before after
  before="$(hash_tree "${archived_repo}/docs/ship-flow")"
  rc="$(run_helper "$archived_repo" "$TMP_DIR/already-archived.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  after="$(hash_tree "${archived_repo}/docs/ship-flow")"
  assert_exit "already archived coherent exits success" 0 "$rc"
  assert_contains "already archived reported" '^state=already_reconciled$' "$TMP_DIR/already-archived.out"
  if [ "$before" = "$after" ]; then
    record_pass "already archived leaves workflow unchanged"
  else
    record_fail "already archived leaves workflow unchanged"
  fi
}

run_scope_guard() {
  assert_not_contains "helper has no forbidden git/gh mutation commands" 'git branch -D|git push --delete|gh pr (create|merge)|git merge' "$HELPER"
}

run_doc_scope_cases() {
  local pr_merge_doc="${PLUGIN_ROOT}/../../docs/ship-flow/_mods/pr-merge.md"
  assert_contains "pr merge doc scopes v1 provider support" 'v1 reconciler supports GitHub `gh` and fixture-backed tests only' "$pr_merge_doc"
  assert_not_contains "pr merge doc does not advertise GitLab closeout state checks" 'glab mr view|If `MERGED` .*GitLab|If `MERGED` \(GitHub\) or `merged` \(GitLab\)' "$pr_merge_doc"
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT
write_fixture_status_bin "${TMP_DIR}/status-fixture"
if [ ! -x "$STATUS_BIN" ]; then
  STATUS_BIN="${TMP_DIR}/status-fixture"
fi

echo "=== test-merged-pr-closeout-reconciler.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_runtime_regression_cases
  run_merged_fixture_case
  run_refusal_cases
  run_usage_and_dry_run_cases
  run_cleanup_cases
  run_idempotency_cases
  run_scope_guard
  run_doc_scope_cases
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
