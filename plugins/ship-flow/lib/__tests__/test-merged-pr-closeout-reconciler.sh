#!/usr/bin/env bash
# test-merged-pr-closeout-reconciler.sh - merged PR closeout reconciler contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/bin/merged-pr-closeout-reconciler.sh"
STATUS_BIN="${STATUS_BIN:-}"
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
commissioned-by: spacedock@0.22.0
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
  # NOTE: the prior cache-glob version-selection cases ("resolves from active
  # plugin cache" / "chooses newest spacedock version across cache roots") were
  # removed in the status-helper repoint. The reconciler no longer discovers a
  # packaged python `commission/bin/status` from the plugin cache; the status
  # helper is now the `spacedock` Go binary, discovered via `command -v
  # spacedock` (with SHIP_FLOW_STATUS_BIN/STATUS_BIN override). The override
  # path is covered hermetically below; the STATUS_BIN override path is
  # exercised throughout the rest of this suite via run_helper.

  # SHIP_FLOW_STATUS_BIN override is honored by resolve_status_bin, with no
  # host dependency. Source the helper's resolver in a sandbox subshell.
  local resolver_out resolver_rc=0
  resolver_out="$(
    SHIP_FLOW_STATUS_BIN="/fixture/path/spacedock" STATUS_BIN="" \
      bash -c '
        set -euo pipefail
        eval "$(sed -n "/^resolve_status_bin()/,/^}/p" "$1")"
        resolve_status_bin
      ' _ "$HELPER"
  )" || resolver_rc=$?
  assert_exit "resolve_status_bin honors SHIP_FLOW_STATUS_BIN override" 0 "$resolver_rc"
  if [ "$resolver_out" = "/fixture/path/spacedock" ]; then
    record_pass "resolve_status_bin returns SHIP_FLOW_STATUS_BIN override path"
  else
    record_fail "resolve_status_bin returns SHIP_FLOW_STATUS_BIN override path (got: ${resolver_out})"
  fi

  local rc
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
  assert_frontmatter_equals "archived entity status done" "${repo}/docs/ship-flow/_archive/merged-fixture-entity/index.md" status "done"
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
  cat > "${archived_repo}/docs/ship-flow/_archive/merged-fixture-entity/ship.md" <<'EOF'
# Ship

## Todo Closeout Digest

- Legacy archive without receipt markers.

### Verdict
pr: "#131"
EOF
  git -C "$archived_repo" add docs/ship-flow/_archive/merged-fixture-entity/index.md docs/ship-flow/_archive/merged-fixture-entity/ship.md
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

  local incomplete_repo="$TMP_DIR/archived-incomplete-marker-repo" incomplete_head
  git clone -q "$archived_repo" "$incomplete_repo"
  printf '%s\n' '' '### Closeout' 'closeout_id: aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa' >>"$incomplete_repo/docs/ship-flow/_archive/merged-fixture-entity/ship.md"
  git -C "$incomplete_repo" add -- docs/ship-flow/_archive/merged-fixture-entity/ship.md
  git -C "$incomplete_repo" commit -qm 'fixture: incomplete closeout marker'
  incomplete_head="$(git -C "$incomplete_repo" rev-parse HEAD)"
  rc="$(run_helper "$incomplete_repo" "$TMP_DIR/archived-incomplete-marker.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit 'archived incomplete closeout marker rejects' 2 "$rc"
  assert_contains 'archived incomplete closeout marker is sentinel-invalid' '^reason=closeout-sentinel-invalid$' "$TMP_DIR/archived-incomplete-marker.out"
  if [ "$incomplete_head" = "$(git -C "$incomplete_repo" rev-parse HEAD)" ]; then record_pass 'archived incomplete marker preserves HEAD'; else record_fail 'archived incomplete marker preserves HEAD'; fi
}

run_direct_transaction_case() {
  local repo="$TMP_DIR/direct-transaction-repo"
  setup_repo "$repo"
  printf '%s\n' '.worktrees/' >"$repo/.gitignore"
  printf '%s\n' '# Roadmap' '| merged-fixture-entity | Outside sections must survive |' '' '## Now' '<!-- section:now -->' '| Entity | Title |' '| --- | --- |' '| merged-fixture-entity | Merged fixture entity |' '| neighbor | mentions merged-fixture-entity in another cell |' '<!-- /section:now -->' '' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '<!-- /section:shipped -->' >"$repo/ROADMAP.md"
  mkdir -p "$repo/docs/ship-flow/_debriefs"
  printf '%s\n' 'landed session one' >"$repo/docs/ship-flow/_debriefs/2026-07-15-01.md"
  git -C "$repo" add -- .gitignore ROADMAP.md docs/ship-flow/_debriefs/2026-07-15-01.md
  git -C "$repo" commit -qm 'fixture: add roadmap'
  local base source_one source_two anchor fixture
  base="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -qb implementation-topic "$base"
  write_entity "$repo/docs/ship-flow" merged-fixture-entity ship '#131' '.worktrees/cleanup-topic'
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' >"$repo/docs/ship-flow/merged-fixture-entity/review.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/index.md docs/ship-flow/merged-fixture-entity/review.md
  git -C "$repo" commit -qm 'implementation: add reviewed entity'
  source_one="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' '- Captured during this ship: preserve this exact todo evidence.' '- Deferred follow-up: retain the cleanup retry contract.' '' '### Token Summary' '' 'Budget: focused' '' '### Verdict' 'merge_method_intent: rebase' 'pr: "#131"' >"$repo/docs/ship-flow/merged-fixture-entity/ship.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/ship.md
  git -C "$repo" commit -qm 'implementation: add ship evidence'
  source_two="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -q main
  git -C "$repo" cherry-pick "$source_one" "$source_two" >/dev/null
  anchor="$(git -C "$repo" rev-parse HEAD)"
  fixture="$TMP_DIR/pr-direct.env"
  printf '%s\n' 'provider=fixture' 'number=131' 'state=MERGED' 'merged_at=2026-07-15T00:00:00Z' \
    'head_ref=cleanup-topic' 'base_ref=main' 'url=https://github.com/example/repo/pull/131' \
    'repository=example/repo' "landing_anchor=$anchor" "source_commits=$source_one,$source_two" 'pr_commit_count=2' >"$fixture"

  local before_head rc receipt debrief landed_head
  before_head="$(git -C "$repo" rev-parse HEAD)"
  rc="$(run_helper "$repo" "$TMP_DIR/direct.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  if [ "$rc" != 0 ]; then sed 's/^/    helper: /' "$TMP_DIR/direct.out"; fi
  assert_exit 'direct transaction exits success' 0 "$rc"
  assert_contains 'direct transaction reports bundle action' '^terminal_action=closeout_bundle$' "$TMP_DIR/direct.out"
  assert_contains 'direct transaction reports reconciled state' '^state=reconciled$' "$TMP_DIR/direct.out"
  if [ "$(git -C "$repo" rev-list --count "${before_head}..HEAD")" = 1 ]; then record_pass 'direct transaction creates exactly one terminal commit'; else record_fail 'direct transaction creates exactly one terminal commit'; fi
  if [ "$(git -C "$repo" log -1 --format=%s)" = 'ship(merged-fixture-entity): advance status to done' ]; then record_pass 'direct transaction commit carries one exact C14 receipt'; else record_fail 'direct transaction commit carries one exact C14 receipt'; fi
  assert_path_missing 'direct transaction removes active entity' "$repo/docs/ship-flow/merged-fixture-entity"
  assert_file_exists 'direct transaction lands archived entity' "$repo/docs/ship-flow/_archive/merged-fixture-entity/index.md"
  assert_file_exists 'direct transaction lands final ship' "$repo/docs/ship-flow/_archive/merged-fixture-entity/ship.md"
  debrief="$repo/docs/ship-flow/_debriefs/2026-07-15-02.md"
  receipt="$(find "$repo/docs/ship-flow/_closeouts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
  assert_file_exists 'direct transaction allocates first free canonical debrief' "$debrief"
  if [ -f "$debrief" ] && [ "$(frontmatter_field "$debrief" sequence)" = 2 ]; then record_pass 'direct debrief sequence matches canonical filename'; else record_fail 'direct debrief sequence matches canonical filename'; fi
  if [ -f "$debrief" ] && bash "$PLUGIN_ROOT/lib/__tests__/validate-debrief-schema.sh" "$debrief" >/dev/null; then record_pass 'direct transaction lands schema-valid debrief'; else record_fail 'direct transaction lands schema-valid debrief'; fi
  if [ -n "$receipt" ]; then record_pass 'direct transaction lands closeout receipt'; else record_fail 'direct transaction lands closeout receipt'; fi
  if [ -n "$receipt" ] && python3 "$PLUGIN_ROOT/lib/validate-closeout-receipt.py" --receipt "$receipt" --repo-root "$repo" --verify-outputs >/dev/null; then record_pass 'direct receipt validates exact terminal outputs'; else record_fail 'direct receipt validates exact terminal outputs'; fi
  if [ "$(grep -c '^| merged-fixture-entity | Merged fixture entity | 2026-07-15 |$' "$repo/ROADMAP.md")" = 1 ]; then record_pass 'direct transaction lands exactly one Shipped row'; else record_fail 'direct transaction lands exactly one Shipped row'; fi
  assert_not_contains 'direct transaction removes exact Now identity row' '^\| merged-fixture-entity \| Merged fixture entity \|$' "$repo/ROADMAP.md"
  assert_contains 'direct ROADMAP preserves slug outside bounded sections' '^\| merged-fixture-entity \| Outside sections must survive \|$' "$repo/ROADMAP.md"
  assert_contains 'direct ROADMAP preserves slug in another Now cell' '^\| neighbor \| mentions merged-fixture-entity in another cell \|$' "$repo/ROADMAP.md"
  if [ -f "$debrief" ]; then
    assert_contains 'direct debrief preserves todo digest content' '^- Captured during this ship: preserve this exact todo evidence\.$' "$debrief"
    assert_contains 'direct debrief records full landing anchor' "$anchor" "$debrief"
    assert_contains 'direct debrief records full ordered source commits' "$source_one,$source_two" "$debrief"
  fi
  local final_ship="$repo/docs/ship-flow/_archive/merged-fixture-entity/ship.md"
  if [ -f "$final_ship" ]; then
    assert_contains 'direct final ship records receipt path' '^receipt: docs/ship-flow/_closeouts/[0-9a-f]{64}\.json$' "$final_ship"
    assert_contains 'direct final ship preserves source worktree' '^source_worktree: \.worktrees/cleanup-topic$' "$final_ship"
    assert_contains 'direct final ship carries full landing anchor' "$anchor" "$final_ship"
    assert_contains 'direct final ship carries todo digest' '^- Deferred follow-up: retain the cleanup retry contract\.$' "$final_ship"
    # proof_hash cannot be embedded here: the receipt proof binds these exact ship bytes.
    assert_not_contains 'direct final ship omits circular receipt proof hash' '^proof_hash:' "$final_ship"
  fi
  if [ -f "$receipt" ] && [ -f "$debrief" ] && [ -f "$final_ship" ] && python3 - "$receipt" "$debrief" "$final_ship" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); debrief=open(sys.argv[2]).read(); ship=open(sys.argv[3]).read(); landing=r["landing_proof"]
def joined(value): return ",".join(value) if isinstance(value,list) else str(value)
debrief_fields={
 "Provider merged at":"provider_merged_at","Landing anchor":"landing_anchor","Base ref":"base_ref","Base before":"base_before",
 "Strategy":"strategy","Strategy evidence":"strategy_evidence","Method source":"method_source","PR commit count":"pr_commit_count",
 "Ordered source commits":"source_commits","Source commit patch IDs":"source_commit_patch_ids","Source patch digest":"source_patch_digest",
 "Ordered landing commits":"landing_commits","Landing commit patch IDs":"landing_commit_patch_ids","Landing patch digest":"landing_patch_digest",
 "First landing commit":"first_landing_commit","Last landing commit":"last_landing_commit"}
for label,key in debrief_fields.items(): assert f"- {label}: {joined(landing[key])}" in debrief
ship_fields={"closeout_id":r["closeout_id"],"receipt":f'{r["identity"]["workflow"]}/_closeouts/{r["closeout_id"]}.json'}
for key in ("landing_anchor","base_ref","base_before","first_landing_commit","last_landing_commit","landing_commits","source_patch_digest","landing_patch_digest"):
    ship_fields[key]=joined(landing[key])
for key,value in ship_fields.items(): assert f"{key}: {value}" in ship
assert "proof_hash:" not in ship
PY
  then record_pass 'direct projections carry the complete non-circular landing envelope'; else record_fail 'direct projections carry the complete non-circular landing envelope'; fi
  if [ -f "$repo/docs/ship-flow/_archive/merged-fixture-entity/index.md" ]; then
    assert_frontmatter_equals 'direct archived status done' "$repo/docs/ship-flow/_archive/merged-fixture-entity/index.md" status "done"
    assert_frontmatter_equals 'direct archived verdict PASSED' "$repo/docs/ship-flow/_archive/merged-fixture-entity/index.md" verdict PASSED
  else
    record_fail 'direct archived status done (archived entity missing)'
    record_fail 'direct archived verdict PASSED (archived entity missing)'
  fi

  landed_head="$(git -C "$repo" rev-parse HEAD)"
  rc="$(run_helper "$repo" "$TMP_DIR/direct-rerun.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  if [ "$rc" != 0 ]; then sed 's/^/    rerun: /' "$TMP_DIR/direct-rerun.out"; fi
  assert_exit 'direct transaction rerun exits success' 0 "$rc"
  if [ "$landed_head" = "$(git -C "$repo" rev-parse HEAD)" ]; then record_pass 'direct transaction rerun is commit no-op'; else record_fail 'direct transaction rerun is commit no-op'; fi

  local variant variant_repo variant_head variant_receipt
  for variant in missing-receipt multiple-receipts tampered-receipt tampered-debrief tampered-ship tampered-roadmap tampered-archive wrong-archive-binding; do
    variant_repo="$TMP_DIR/direct-${variant}-repo"
    git clone -q "$repo" "$variant_repo"
    variant_receipt="$(find "$variant_repo/docs/ship-flow/_closeouts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
    case "$variant" in
      missing-receipt) rm -f "$variant_receipt" ;;
      multiple-receipts) cp "$variant_receipt" "${variant_receipt%.json}-duplicate.json" ;;
      tampered-receipt) python3 - "$variant_receipt" <<'PY'
import json,sys
p=sys.argv[1]; r=json.load(open(p)); r["proof_hash"]="0"*64; open(p,"w").write(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
        ;;
      tampered-debrief) printf '%s\n' 'tampered' >>"$variant_repo/docs/ship-flow/_debriefs/2026-07-15-02.md" ;;
      tampered-ship) printf '%s\n' 'tampered' >>"$variant_repo/docs/ship-flow/_archive/merged-fixture-entity/ship.md" ;;
      tampered-roadmap) perl -0pi -e 's/Merged fixture entity \| 2026-07-15/Merged fixture entity tampered | 2026-07-15/' "$variant_repo/ROADMAP.md" ;;
      tampered-archive) printf '%s\n' 'tampered' >>"$variant_repo/docs/ship-flow/_archive/merged-fixture-entity/index.md" ;;
      wrong-archive-binding) mkdir -p "$variant_repo/docs/ship-flow/_archive/other"; cp "$variant_repo/docs/ship-flow/_archive/merged-fixture-entity/index.md" "$variant_repo/docs/ship-flow/_archive/other/index.md"; python3 - "$variant_receipt" <<'PY'
import hashlib,json,sys
p=sys.argv[1]; r=json.load(open(p)); other=p.rsplit("/docs/",1)[0]+"/docs/ship-flow/_archive/other/index.md"
r["outputs"]["archived_entity"]={"path":"docs/ship-flow/_archive/other/index.md","sha256":hashlib.sha256(open(other,"rb").read()).hexdigest()}
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
open(p,"w").write(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
        ;;
    esac
    variant_head="$(git -C "$variant_repo" rev-parse HEAD)"
    rc="$(run_helper "$variant_repo" "$TMP_DIR/${variant}.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
    if [ "$rc" != 0 ]; then record_pass "archived ${variant} sentinel stops"; else record_fail "archived ${variant} sentinel stops"; fi
    if [ "$variant_head" = "$(git -C "$variant_repo" rev-parse HEAD)" ]; then record_pass "archived ${variant} keeps HEAD"; else record_fail "archived ${variant} keeps HEAD"; fi
  done

  local duplicate duplicate_repo duplicate_head duplicate_tree
  for duplicate in duplicate-now prior-shipped; do
    duplicate_repo="$TMP_DIR/direct-${duplicate}-repo"
    git clone -q "$repo" "$duplicate_repo"
    git -C "$duplicate_repo" reset -q --hard "$before_head"
    python3 - "$duplicate_repo/ROADMAP.md" "$duplicate" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); mode=sys.argv[2]; lines=p.read_text().splitlines()
marker="<!-- /section:now -->" if mode=="duplicate-now" else "<!-- /section:shipped -->"
row="| merged-fixture-entity | Duplicate identity |" if mode=="duplicate-now" else "| merged-fixture-entity | Already shipped | 2026-07-14 |"
lines.insert(lines.index(marker),row); p.write_text("\n".join(lines)+"\n")
PY
    git -C "$duplicate_repo" add -- ROADMAP.md
    git -C "$duplicate_repo" commit -qm "fixture: ${duplicate}"
    duplicate_head="$(git -C "$duplicate_repo" rev-parse HEAD)"; duplicate_tree="$(hash_tree "$duplicate_repo/docs/ship-flow")"
    local render_tmp="$TMP_DIR/${duplicate}-tmp"
    mkdir -p "$render_tmp"
    rc="$(export TMPDIR="$render_tmp"; run_helper "$duplicate_repo" "$TMP_DIR/${duplicate}.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
    if [ "$rc" != 0 ]; then record_pass "direct ${duplicate} identity stops"; else record_fail "direct ${duplicate} identity stops"; fi
    if [ "$duplicate_head" = "$(git -C "$duplicate_repo" rev-parse HEAD)" ] && [ "$duplicate_tree" = "$(hash_tree "$duplicate_repo/docs/ship-flow")" ]; then record_pass "direct ${duplicate} preserves HEAD and workflow"; else record_fail "direct ${duplicate} preserves HEAD and workflow"; fi
    if [ -z "$(find "$render_tmp" -mindepth 1 -print -quit)" ]; then record_pass "direct ${duplicate} render failure removes temporary artifacts"; else record_fail "direct ${duplicate} render failure removes temporary artifacts"; fi
  done

  local malformed_repo="$TMP_DIR/direct-malformed-owner-repo" malformed_head malformed_tree
  git clone -q "$repo" "$malformed_repo"
  git -C "$malformed_repo" reset -q --hard "$before_head"
  mkdir -p "$malformed_repo/docs/ship-flow/body-fence-candidate"
  printf '%s\n' '# Malformed candidate' '' '---' 'pr: "#131"' 'closeout_owner: true' '---' >"$malformed_repo/docs/ship-flow/body-fence-candidate/index.md"
  git -C "$malformed_repo" add -- docs/ship-flow/body-fence-candidate/index.md
  git -C "$malformed_repo" commit -qm 'fixture: body fence cannot open frontmatter'
  malformed_head="$(git -C "$malformed_repo" rev-parse HEAD)"; malformed_tree="$(hash_tree "$malformed_repo/docs/ship-flow")"
  rc="$(run_helper "$malformed_repo" "$TMP_DIR/malformed-owner.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'malformed ownership candidate rejects' 2 "$rc"
  assert_contains 'malformed ownership candidate reports stage incoherence' '^reason=closeout-stage-artifacts-incoherent$' "$TMP_DIR/malformed-owner.out"
  if [ "$malformed_head" = "$(git -C "$malformed_repo" rev-parse HEAD)" ] && [ "$malformed_tree" = "$(hash_tree "$malformed_repo/docs/ship-flow")" ]; then record_pass 'malformed ownership candidate preserves bytes and HEAD'; else record_fail 'malformed ownership candidate preserves bytes and HEAD'; fi

  local unsafe_title_repo="$TMP_DIR/direct-unsafe-title-repo" unsafe_title_head unsafe_title_tree
  git clone -q "$repo" "$unsafe_title_repo"
  git -C "$unsafe_title_repo" reset -q --hard "$before_head"
  perl -0pi -e 's/title: "Merged fixture entity"/title: "Merged | fixture entity"/' "$unsafe_title_repo/docs/ship-flow/merged-fixture-entity/index.md"
  git -C "$unsafe_title_repo" add -- docs/ship-flow/merged-fixture-entity/index.md
  git -C "$unsafe_title_repo" commit -qm 'fixture: unsafe ROADMAP title delimiter'
  unsafe_title_head="$(git -C "$unsafe_title_repo" rev-parse HEAD)"; unsafe_title_tree="$(hash_tree "$unsafe_title_repo/docs/ship-flow")"
  rc="$(run_helper "$unsafe_title_repo" "$TMP_DIR/unsafe-title.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'unsafe table title rejects before rendering' 2 "$rc"
  assert_contains 'unsafe table title reports stage incoherence' '^reason=closeout-stage-artifacts-incoherent$' "$TMP_DIR/unsafe-title.out"
  if [ "$unsafe_title_head" = "$(git -C "$unsafe_title_repo" rev-parse HEAD)" ] && [ "$unsafe_title_tree" = "$(hash_tree "$unsafe_title_repo/docs/ship-flow")" ]; then record_pass 'unsafe table title preserves bytes and HEAD'; else record_fail 'unsafe table title preserves bytes and HEAD'; fi

  local empty_worktree_repo="$TMP_DIR/direct-empty-worktree-repo" empty_worktree_head
  git clone -q "$repo" "$empty_worktree_repo"
  git -C "$empty_worktree_repo" reset -q --hard "$before_head"
  python3 - "$empty_worktree_repo/docs/ship-flow/merged-fixture-entity/index.md" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); p.write_text(p.read_text().replace("worktree: .worktrees/cleanup-topic","worktree:"))
PY
  git -C "$empty_worktree_repo" add -- docs/ship-flow/merged-fixture-entity/index.md
  git -C "$empty_worktree_repo" commit -qm 'fixture: direct entity has no source worktree'
  rc="$(run_helper "$empty_worktree_repo" "$TMP_DIR/empty-worktree-first.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'direct empty-worktree transaction exits success' 0 "$rc"
  empty_worktree_head="$(git -C "$empty_worktree_repo" rev-parse HEAD)"
  rc="$(run_helper "$empty_worktree_repo" "$TMP_DIR/empty-worktree-rerun.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'archived empty-worktree rerun exits success' 0 "$rc"
  assert_contains 'archived empty-worktree cleanup is not applicable' '^worktree_cleanup=not_applicable$' "$TMP_DIR/empty-worktree-rerun.out"
  if [ "$empty_worktree_head" = "$(git -C "$empty_worktree_repo" rev-parse HEAD)" ]; then record_pass 'archived empty-worktree rerun is commit no-op'; else record_fail 'archived empty-worktree rerun is commit no-op'; fi

  local cleanup_repo="$TMP_DIR/direct-cleanup-retry-repo" cleanup_path cleanup_bin cleanup_marker cleanup_head real_git
  git clone -q "$repo" "$cleanup_repo"
  git -C "$cleanup_repo" reset -q --hard "$before_head"
  cleanup_path="$cleanup_repo/.worktrees/cleanup-topic"
  mkdir -p "$cleanup_repo/.worktrees"
  git -C "$cleanup_repo" worktree add -q -b cleanup-topic "$cleanup_path" "$before_head"
  cleanup_bin="$TMP_DIR/fail-once-git-bin"; cleanup_marker="$TMP_DIR/worktree-remove-failed-once"; real_git="$(command -v git)"
  mkdir -p "$cleanup_bin"
  cat >"$cleanup_bin/git" <<'EOF'
#!/usr/bin/env bash
if [[ " $* " == *" worktree remove "* ]] && [ ! -e "$CLEANUP_FAIL_MARKER" ]; then touch "$CLEANUP_FAIL_MARKER"; exit 1; fi
exec "$REAL_GIT" "$@"
EOF
  chmod +x "$cleanup_bin/git"
  rc="$(PATH="$cleanup_bin:$PATH" REAL_GIT="$real_git" CLEANUP_FAIL_MARKER="$cleanup_marker" run_helper "$cleanup_repo" "$TMP_DIR/cleanup-first.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  if [ "$rc" != 1 ]; then sed 's/^/    cleanup-first: /' "$TMP_DIR/cleanup-first.out"; fi
  assert_exit 'direct first cleanup failure stops after terminal commit' 1 "$rc"
  cleanup_head="$(git -C "$cleanup_repo" rev-parse HEAD)"
  if [ "$(git -C "$cleanup_repo" rev-list --count "${before_head}..HEAD")" = 1 ]; then record_pass 'direct cleanup failure keeps one terminal commit'; else record_fail 'direct cleanup failure keeps one terminal commit'; fi
  assert_path_exists 'direct cleanup failure leaves worktree for retry' "$cleanup_path"
  rc="$(PATH="$cleanup_bin:$PATH" REAL_GIT="$real_git" CLEANUP_FAIL_MARKER="$cleanup_marker" run_helper "$cleanup_repo" "$TMP_DIR/cleanup-second.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  if [ "$rc" != 0 ]; then sed 's/^/    cleanup-second: /' "$TMP_DIR/cleanup-second.out"; fi
  assert_exit 'archived rerun retries cleanup successfully' 0 "$rc"
  if [ "$cleanup_head" = "$(git -C "$cleanup_repo" rev-parse HEAD)" ]; then record_pass 'cleanup retry creates no terminal commit'; else record_fail 'cleanup retry creates no terminal commit'; fi
  assert_path_missing 'cleanup retry removes registered worktree' "$cleanup_path"
  if git -C "$cleanup_repo" show-ref --verify --quiet refs/heads/cleanup-topic; then record_fail 'cleanup retry deletes head branch'; else record_pass 'cleanup retry deletes head branch'; fi

  local fault_repo="$TMP_DIR/direct-fault-repo" fault_before
  git clone -q "$repo" "$fault_repo"
  git -C "$fault_repo" reset -q --hard "$before_head"
  fault_before="$(hash_tree "$fault_repo/docs/ship-flow")"
  rc="$(SHIP_FLOW_CLOSEOUT_FAILPOINT=before-commit run_helper "$fault_repo" "$TMP_DIR/direct-fault.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'direct injected pre-commit fault stops' 1 "$rc"
  assert_contains 'direct injected fault reports stable conflict' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/direct-fault.out"
  if [ "$fault_before" = "$(hash_tree "$fault_repo/docs/ship-flow")" ] && [ "$before_head" = "$(git -C "$fault_repo" rev-parse HEAD)" ]; then record_pass 'direct injected fault restores coherent tree and HEAD'; else record_fail 'direct injected fault restores coherent tree and HEAD'; fi
  if [ -f "$fault_repo/docs/ship-flow/merged-fixture-entity/index.md" ]; then
    assert_frontmatter_equals 'direct injected fault keeps active status nonterminal' "$fault_repo/docs/ship-flow/merged-fixture-entity/index.md" status ship
    assert_frontmatter_equals 'direct injected fault exposes no PASSED verdict' "$fault_repo/docs/ship-flow/merged-fixture-entity/index.md" verdict ''
  else
    record_fail 'direct injected fault keeps active status nonterminal (active entity missing)'
    record_fail 'direct injected fault exposes no PASSED verdict (active entity missing)'
  fi

  local conflict_repo="$TMP_DIR/direct-projection-conflict-repo" conflict_before
  git clone -q "$repo" "$conflict_repo"
  git -C "$conflict_repo" reset -q --hard "$before_head"
  mkdir -p "$conflict_repo/docs/ship-flow/_archive/merged-fixture-entity"
  printf '%s\n' 'conflicting projection' >"$conflict_repo/docs/ship-flow/_archive/merged-fixture-entity/ship.md"
  git -C "$conflict_repo" add -- docs/ship-flow/_archive/merged-fixture-entity/ship.md
  git -C "$conflict_repo" commit -qm 'fixture: pre-existing closeout projection'
  conflict_before="$(hash_tree "$conflict_repo/docs/ship-flow")"
  rc="$(run_helper "$conflict_repo" "$TMP_DIR/direct-projection-conflict.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'direct projection conflict stops' 1 "$rc"
  assert_contains 'direct projection conflict reports stable drift' '^reason=closeout-projection-source-drift$' "$TMP_DIR/direct-projection-conflict.out"
  if [ "$conflict_before" = "$(hash_tree "$conflict_repo/docs/ship-flow")" ]; then record_pass 'direct projection conflict preserves tree'; else record_fail 'direct projection conflict preserves tree'; fi
}

run_scope_guard() {
  assert_not_contains "helper has no forbidden git/gh mutation commands" 'git branch -D|git push --delete|gh pr (create|merge)|git merge' "$HELPER"
}

run_doc_scope_cases() {
  # Dogfood check — only runs when docs/ship-flow/_mods/pr-merge.md exists (adopted host).
  # In fresh-clone standalone mode this function is intentionally skipped.
  local pr_merge_doc="${PLUGIN_ROOT}/../../docs/ship-flow/_mods/pr-merge.md"
  if [ ! -f "$pr_merge_doc" ]; then
    echo "  NOTE: pr-merge.md absent (fresh clone) — skipping dogfood doc scope assertions"
    return 0
  fi
  # shellcheck disable=SC2016 # Backticks are literal documentation text and regex syntax.
  assert_contains "pr merge doc scopes v1 provider support" 'v1 reconciler supports GitHub `gh` and fixture-backed tests only' "$pr_merge_doc"
  # shellcheck disable=SC2016 # Backticks are literal documentation text and regex syntax.
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
  if [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = direct-transaction ]; then
    run_direct_transaction_case
  fi
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
