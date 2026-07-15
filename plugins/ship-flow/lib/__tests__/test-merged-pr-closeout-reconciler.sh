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

prepare_full_d1_repo() {
  local repo="$1" fixture="$2" worktree_value="${3:-}"
  local base source_one source_two anchor
  setup_repo "$repo"
  printf '%s\n' '.worktrees/' >"$repo/.gitignore"
  printf '%s\n' '# Roadmap' '' '## Now' '<!-- section:now -->' \
    '| Entity | Title |' '| --- | --- |' \
    '| merged-fixture-entity | Merged fixture entity |' \
    '<!-- /section:now -->' '' '## Shipped' '<!-- section:shipped -->' \
    '| Entity | Title | Shipped |' '| --- | --- | --- |' \
    '<!-- /section:shipped -->' >"$repo/ROADMAP.md"
  git -C "$repo" add -- .gitignore ROADMAP.md
  git -C "$repo" commit -qm 'fixture: add roadmap'
  base="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -qb ship-merged-fixture-entity "$base"
  write_entity "$repo/docs/ship-flow" merged-fixture-entity ship '#131' "$worktree_value"
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' >"$repo/docs/ship-flow/merged-fixture-entity/review.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/index.md docs/ship-flow/merged-fixture-entity/review.md
  git -C "$repo" commit -qm 'implementation: add reviewed entity'
  source_one="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' \
    '- Preserve cleanup safety evidence.' '' '### Verdict' \
    'merge_method_intent: rebase' 'pr: "#131"' \
    >"$repo/docs/ship-flow/merged-fixture-entity/ship.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/ship.md
  git -C "$repo" commit -qm 'implementation: add ship evidence'
  source_two="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -q main
  git -C "$repo" cherry-pick "$source_one" "$source_two" >/dev/null
  anchor="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' 'provider=fixture' 'number=131' 'state=MERGED' \
    'merged_at=2026-07-15T00:00:00Z' \
    'head_ref=ship-merged-fixture-entity' 'base_ref=main' \
    'url=https://github.com/example/repo/pull/131' 'repository=example/repo' \
    "landing_anchor=$anchor" "source_commits=$source_one,$source_two" \
    'pr_commit_count=2' >"$fixture"
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

run_helper_for_workflow() {
  local repo="$1" workflow="$2" output="$3"
  shift 3
  local rc=0
  STATUS_BIN="$STATUS_BIN" "$HELPER" --workflow-dir "${repo}/${workflow}" "$@" >"$output" 2>&1 || rc=$?
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
  assert_exit "incomplete dry-run rejects before cleanup preflight" 2 "$rc"
  assert_contains "incomplete dry-run reports stable anchor reason" '^reason=landing-anchor-missing$' "$TMP_DIR/pipefail-dry-run.out"
  assert_not_contains "incomplete dry-run does not plan cleanup" '^(worktree_cleanup|branch_cleanup)=planned$' "$TMP_DIR/pipefail-dry-run.out"
}

run_incomplete_landing_contract_case() {
  local repo="$TMP_DIR/merged-repo"
  setup_repo "$repo"
  write_entity "${repo}/docs/ship-flow" "merged-fixture-entity" "ship" "#131" ""
  git -C "$repo" add docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm "add merged entity"

  local before_head before_tree rc
  before_head="$(git -C "$repo" rev-parse HEAD)"
  before_tree="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/merged.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"

  assert_exit "merged fixture without landing anchor rejects" 2 "$rc"
  assert_contains "incomplete landing envelope reports stable anchor reason" '^reason=landing-anchor-missing$' "$TMP_DIR/merged.out"
  assert_contains "incomplete landing envelope does not proceed" '^verdict=REJECT$' "$TMP_DIR/merged.out"
  assert_file_exists "incomplete landing envelope keeps active entity" "${repo}/docs/ship-flow/merged-fixture-entity/index.md"
  assert_path_missing "incomplete landing envelope creates no archive" "${repo}/docs/ship-flow/_archive/merged-fixture-entity"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$before_tree" = "$(hash_tree "${repo}/docs/ship-flow")" ]; then
    record_pass "incomplete landing envelope preserves HEAD and workflow bytes"
  else
    record_fail "incomplete landing envelope preserves HEAD and workflow bytes"
  fi
}

run_missing_landing_field_matrix() {
  local template_repo="$TMP_DIR/missing-field-template" template_fixture="$TMP_DIR/missing-field-template.env"
  local field expected repo fixture output before_head before_tree after_tree rc
  prepare_full_d1_repo "$template_repo" "$template_fixture"
  while IFS='|' read -r field expected; do
    repo="$TMP_DIR/missing-${field}-repo"
    fixture="$TMP_DIR/missing-${field}.env"
    output="$TMP_DIR/missing-${field}.out"
    git clone -q "$template_repo" "$repo"
    grep -v "^${field}=" "$template_fixture" >"$fixture"
    before_head="$(git -C "$repo" rev-parse HEAD)"
    before_tree="$(hash_tree "$repo/docs/ship-flow")"
    rc="$(run_helper "$repo" "$output" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
    assert_exit "missing ${field} rejects" 2 "$rc"
    assert_contains "missing ${field} reports ${expected}" "^reason=${expected}$" "$output"
    assert_contains "missing ${field} reports REJECT" '^verdict=REJECT$' "$output"
    after_tree="$(hash_tree "$repo/docs/ship-flow")"
    if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$before_tree" = "$after_tree" ]; then
      record_pass "missing ${field} preserves HEAD and workflow bytes"
    else
      record_fail "missing ${field} preserves HEAD and workflow bytes"
    fi
    assert_file_exists "missing ${field} keeps active entity" "$repo/docs/ship-flow/merged-fixture-entity/index.md"
    assert_path_missing "missing ${field} creates no archive" "$repo/docs/ship-flow/_archive/merged-fixture-entity"
  done <<'EOF'
merged_at|merged-at-missing
landing_anchor|landing-anchor-missing
source_commits|landing-pr-commit-count-mismatch
pr_commit_count|landing-pr-commit-count-mismatch
repository|closeout-stage-artifacts-incoherent
base_ref|closeout-stage-artifacts-incoherent
EOF

  repo="$TMP_DIR/missing-anchor-pr-repo"
  fixture="$TMP_DIR/missing-anchor-pr.env"
  output="$TMP_DIR/missing-anchor-pr.out"
  local registry="$TMP_DIR/missing-anchor-pr.registry" pr_log="$TMP_DIR/missing-anchor-pr.log"
  git clone -q "$template_repo" "$repo"
  grep -v '^landing_anchor=' "$template_fixture" >"$fixture"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  before_tree="$(hash_tree "$repo/docs/ship-flow")"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" run_helper "$repo" "$output" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'pull-request missing landing_anchor rejects' 2 "$rc"
  assert_contains 'pull-request missing landing_anchor reports stable reason' '^reason=landing-anchor-missing$' "$output"
  assert_contains 'pull-request missing landing_anchor reports REJECT' '^verdict=REJECT$' "$output"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && \
     [ "$before_tree" = "$(hash_tree "$repo/docs/ship-flow")" ] && \
     [ ! -e "$registry" ] && [ ! -e "$pr_log" ]; then
    record_pass 'pull-request missing landing_anchor precedes repository and provider side effects'
  else
    record_fail 'pull-request missing landing_anchor precedes repository and provider side effects'
  fi
}

run_cleanup_safety_contract_cases() {
  local repo fixture output worktree rc before_head before_tree

  repo="$TMP_DIR/full-d1-dirty-repo"
  fixture="$TMP_DIR/full-d1-dirty.env"
  worktree="$repo/.worktrees/ship-merged-fixture-entity"
  prepare_full_d1_repo "$repo" "$fixture" '.worktrees/ship-merged-fixture-entity'
  git -C "$repo" worktree add "$worktree" ship-merged-fixture-entity >/dev/null 2>&1
  printf '%s\n' dirty >"$worktree/dirty.txt"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  before_tree="$(hash_tree "$repo/docs/ship-flow")"
  output="$TMP_DIR/full-d1-dirty.out"
  rc="$(run_helper "$repo" "$output" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'full-D1 dirty worktree prompts captain' 1 "$rc"
  assert_contains 'full-D1 dirty worktree reports stable reason' '^reason=dirty-worktree$' "$output"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$before_tree" = "$(hash_tree "$repo/docs/ship-flow")" ]; then
    record_pass 'full-D1 dirty worktree preserves HEAD and workflow bytes'
  else
    record_fail 'full-D1 dirty worktree preserves HEAD and workflow bytes'
  fi
  assert_path_exists 'full-D1 dirty worktree remains registered' "$worktree"

  repo="$TMP_DIR/full-d1-branch-mismatch-repo"
  fixture="$TMP_DIR/full-d1-branch-mismatch.env"
  worktree="$repo/.worktrees/not-pr-head"
  prepare_full_d1_repo "$repo" "$fixture" '.worktrees/not-pr-head'
  git -C "$repo" worktree add -b unexpected-branch "$worktree" main >/dev/null 2>&1
  before_head="$(git -C "$repo" rev-parse HEAD)"
  before_tree="$(hash_tree "$repo/docs/ship-flow")"
  output="$TMP_DIR/full-d1-branch-mismatch.out"
  rc="$(run_helper "$repo" "$output" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'full-D1 branch mismatch prompts captain' 1 "$rc"
  assert_contains 'full-D1 branch mismatch reports stable reason' '^reason=branch-mismatch$' "$output"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$before_tree" = "$(hash_tree "$repo/docs/ship-flow")" ]; then
    record_pass 'full-D1 branch mismatch preserves HEAD and workflow bytes'
  else
    record_fail 'full-D1 branch mismatch preserves HEAD and workflow bytes'
  fi
  assert_path_exists 'full-D1 branch mismatch keeps worktree' "$worktree"

  repo="$TMP_DIR/full-d1-missing-local-repo"
  fixture="$TMP_DIR/full-d1-missing-local.env"
  prepare_full_d1_repo "$repo" "$fixture" '.worktrees/missing-local'
  output="$TMP_DIR/full-d1-missing-local.out"
  rc="$(run_helper "$repo" "$output" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'full-D1 missing local worktree still reconciles' 0 "$rc"
  assert_contains 'full-D1 missing local worktree is reported' '^worktree_cleanup=missing-local$' "$output"
  assert_contains 'full-D1 missing local worktree uses atomic bundle' '^terminal_action=closeout_bundle$' "$output"

  repo="$TMP_DIR/full-d1-apply-failure-repo"
  fixture="$TMP_DIR/full-d1-apply-failure.env"
  worktree="$repo/.worktrees/ship-merged-fixture-entity"
  prepare_full_d1_repo "$repo" "$fixture" '.worktrees/ship-merged-fixture-entity'
  git -C "$repo" worktree add "$worktree" ship-merged-fixture-entity >/dev/null 2>&1
  before_head="$(git -C "$repo" rev-parse HEAD)"
  before_tree="$(hash_tree "$repo/docs/ship-flow")"
  output="$TMP_DIR/full-d1-apply-failure.out"
  rc="$(SHIP_FLOW_CLOSEOUT_FAILPOINT=before-commit run_helper "$repo" "$output" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'full-D1 apply failure stops before cleanup' 1 "$rc"
  assert_contains 'full-D1 apply failure reports stable reason' '^reason=closeout-checkpoint-conflict$' "$output"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$before_tree" = "$(hash_tree "$repo/docs/ship-flow")" ]; then
    record_pass 'full-D1 apply failure preserves HEAD and workflow bytes'
  else
    record_fail 'full-D1 apply failure preserves HEAD and workflow bytes'
  fi
  assert_path_exists 'full-D1 apply failure keeps cleanup worktree' "$worktree"
  if git -C "$repo" show-ref --verify --quiet refs/heads/ship-merged-fixture-entity; then
    record_pass 'full-D1 apply failure keeps cleanup branch'
  else
    record_fail 'full-D1 apply failure keeps cleanup branch'
  fi

  repo="$TMP_DIR/full-d1-unmerged-branch-repo"
  fixture="$TMP_DIR/full-d1-unmerged-branch.env"
  worktree="$repo/.worktrees/ship-merged-fixture-entity"
  prepare_full_d1_repo "$repo" "$fixture" '.worktrees/ship-merged-fixture-entity'
  git -C "$repo" worktree add "$worktree" ship-merged-fixture-entity >/dev/null 2>&1
  printf '%s\n' 'branch-only evidence' >"$worktree/branch-only.txt"
  git -C "$worktree" add -- branch-only.txt
  git -C "$worktree" commit -qm 'fixture: retain unmerged branch'
  output="$TMP_DIR/full-d1-unmerged-branch.out"
  rc="$(run_helper "$repo" "$output" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture")"
  assert_exit 'full-D1 unmerged branch still reconciles' 0 "$rc"
  assert_contains 'full-D1 unmerged branch cleanup is skipped' '^branch_cleanup=skipped$' "$output"
  assert_path_missing 'full-D1 unmerged branch worktree is removed' "$worktree"
  if git -C "$repo" show-ref --verify --quiet refs/heads/ship-merged-fixture-entity; then
    record_pass 'full-D1 unmerged branch is preserved'
  else
    record_fail 'full-D1 unmerged branch is preserved'
  fi
}

run_pull_request_roadmap_validation_case() {
  local repo="$TMP_DIR/pull-request-roadmap-validation-repo" fixture="$TMP_DIR/pr-pull-request-roadmap-validation.env"
  local registry="$TMP_DIR/pull-request-roadmap-validation.registry" pr_log="$TMP_DIR/pull-request-roadmap-validation.pr.log"
  local base source_one source_two anchor rc before_head before_tree
  setup_repo "$repo"
  printf '%s\n' '# Roadmap' '' '## Now' '<!-- section:now -->' '| Entity | Title |' '| --- | --- |' '| merged-fixture-entity | Merged fixture entity |' '<!-- /section:now -->' '' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '<!-- /section:shipped -->' >"$repo/ROADMAP.md"
  git -C "$repo" add -- ROADMAP.md
  git -C "$repo" commit -qm 'fixture: add roadmap'
  base="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -qb implementation-topic "$base"
  write_entity "$repo/docs/ship-flow" merged-fixture-entity ship '#131' ''
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' >"$repo/docs/ship-flow/merged-fixture-entity/review.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/index.md docs/ship-flow/merged-fixture-entity/review.md
  git -C "$repo" commit -qm 'implementation: add reviewed entity'
  source_one="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' '- Pull-request validation proof.' '' '### Verdict' 'merge_method_intent: rebase' 'pr: "#131"' >"$repo/docs/ship-flow/merged-fixture-entity/ship.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/ship.md
  git -C "$repo" commit -qm 'implementation: add ship evidence'
  source_two="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -q main
  git -C "$repo" cherry-pick "$source_one" "$source_two" >/dev/null
  anchor="$(git -C "$repo" rev-parse HEAD)"
  perl -0pi -e 's/title: "Merged fixture entity"/title: "Merged | fixture entity"/' "$repo/docs/ship-flow/merged-fixture-entity/index.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/index.md
  git -C "$repo" commit -qm 'fixture: unsafe ROADMAP title delimiter'
  printf '%s\n' 'provider=fixture' 'number=131' 'state=MERGED' 'merged_at=2026-07-15T00:00:00Z' \
    'head_ref=implementation-topic' 'base_ref=main' 'url=https://github.com/example/repo/pull/131' 'repository=example/repo' \
    "landing_anchor=$anchor" "source_commits=$source_one,$source_two" 'pr_commit_count=2' \
    'closeout_pr_number=141' 'closeout_pr_state=OPEN' 'closeout_pr_head=unused-before-validation' >"$fixture"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  before_tree="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" run_helper "$repo" "$TMP_DIR/pull-request-unsafe-title.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit "pull-request mode rejects unsafe ROADMAP title" 2 "$rc"
  assert_contains "pull-request unsafe title reports stage incoherence" '^reason=closeout-stage-artifacts-incoherent$' "$TMP_DIR/pull-request-unsafe-title.out"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$before_tree" = "$(hash_tree "${repo}/docs/ship-flow")" ] && [ ! -e "$registry" ] && [ ! -e "$pr_log" ]; then
    record_pass "pull-request ROADMAP validation precedes checkpoints and provider effects"
  else
    record_fail "pull-request ROADMAP validation precedes checkpoints and provider effects"
  fi
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
  assert_exit "dry-run incomplete landing rejects" 2 "$rc"
  assert_contains "dry-run incomplete landing reports stable anchor reason" '^reason=landing-anchor-missing$' "$TMP_DIR/dry-run.out"
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

# Historical sequential-closeout fixture retained for archaeology; the default
# suite no longer invokes it because incomplete landing proof now fails closed.
# shellcheck disable=SC2329
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
  if [ -f "$receipt" ] && [ -f "$debrief" ] && [ -f "$final_ship" ] && python3 - "$receipt" "$debrief" "$final_ship" "$source_one,$source_two" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); debrief=open(sys.argv[2]).read(); ship=open(sys.argv[3]).read(); expected_sources=sys.argv[4]; landing=r["landing_proof"]
def joined(value): return ",".join(value) if isinstance(value,list) else str(value)
debrief_fields={
 "Provider merged at":"provider_merged_at","Landing anchor":"landing_anchor","Base ref":"base_ref","Base before":"base_before",
 "Strategy":"strategy","Strategy evidence":"strategy_evidence","Method source":"method_source","PR commit count":"pr_commit_count",
 "Source commit patch IDs":"source_commit_patch_ids","Source patch digest":"source_patch_digest",
 "Ordered landing commits":"landing_commits","Landing commit patch IDs":"landing_commit_patch_ids","Landing patch digest":"landing_patch_digest",
 "First landing commit":"first_landing_commit","Last landing commit":"last_landing_commit"}
for label,key in debrief_fields.items(): assert f"- {label}: {joined(landing[key])}" in debrief
assert f"- Ordered source commits: {expected_sources}" in debrief
assert "source_commits" not in landing
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
  assert_not_contains "helper has no forbidden merge/delete mutation commands" 'git branch -D|git push --delete|gh pr merge|git merge' "$HELPER"
}

case_selected() {
  [ -z "${SHIP_FLOW_CLOSEOUT_CASE:-}" ] && return 0
  case ",${SHIP_FLOW_CLOSEOUT_CASE:-}," in
    *",$1,"*) return 0 ;;
    *) return 1 ;;
  esac
}

run_optional_pr_red_case() {
  local repo="$TMP_DIR/optional-pr-red-repo" rc before after fixture cid
  local landing_fixture="$TMP_DIR/optional-pr-red-landing.env" envelope="$TMP_DIR/optional-pr-red-envelope.out"
  local landing_anchor source_commits pr_commit_count
  prepare_full_d1_repo "$repo" "$landing_fixture"
  landing_anchor="$(awk -F= '$1=="landing_anchor"{print $2; exit}' "$landing_fixture")"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$landing_fixture")"
  pr_commit_count="$(awk -F= '$1=="pr_commit_count"{print $2; exit}' "$landing_fixture")"
  "$PLUGIN_ROOT/lib/resolve-landing-envelope.sh" \
    --repo-dir "$repo" --repository example/repo --base-ref main \
    --implementation-pr 131 --provider-merged-at 2026-05-06T00:00:00Z \
    --landing-anchor "$landing_anchor" --source-commits "$source_commits" \
    --pr-commit-count "$pr_commit_count" >"$envelope"
  mkdir -p "$repo/docs/ship-flow/_closeouts"
  cid="$(python3 - "$repo/docs/ship-flow/_closeouts" "$repo" "$envelope" <<'PY'
import hashlib,json,pathlib,sys
root,repo,envelope=map(pathlib.Path,sys.argv[1:]); h="a"*64
identity={"provider":"github","repository":"example/repo","workflow":"docs/ship-flow","entity_slug":"merged-fixture-entity","implementation_pr":131}
cid=hashlib.sha256(b"\0".join((b"v1",b"github",b"example/repo",b"docs/ship-flow",b"merged-fixture-entity",b"131"))).hexdigest()
raw={}
for line in envelope.read_text().splitlines():
    if "=" in line:
        key,value=line.split("=",1); raw[key]=value
arrays={"source_commit_patch_ids","landing_commits","landing_commit_patch_ids"}
ints={"schema_version","implementation_pr","pr_commit_count"}
landing={key:(value.split(",") if key in arrays else int(value) if key in ints else value) for key,value in raw.items()}
entity=repo/"docs/ship-flow/merged-fixture-entity"
def file_hash(name): return hashlib.sha256((entity/name).read_bytes()).hexdigest()
r={"schema_version":1,"kind":"ship-flow.closeout","closeout_id":cid,"identity":identity,
"ownership_proof":{"unique_entity_matches":1,"participant_entities":[],"source_hashes":{"index":file_hash("index.md"),"review":file_hash("review.md"),"ship":file_hash("ship.md")}},
"mode":"pull_request","merge_method_intent":None,"deterministic_closeout_head":"ship-closeout/"+cid,
"landing_proof":landing,
"transaction":{"phase":"awaiting_closeout_pr","generation":2,"closeout_pr":141,"main_commit":None},
"outputs":{"debrief":{"path":"docs/ship-flow/_debriefs/2026-05-06-01.md","sha256":h},"ship":{"path":"docs/ship-flow/_archive/merged-fixture-entity/ship.md","sha256":h},"archived_entity":{"path":"docs/ship-flow/_archive/merged-fixture-entity/index.md","sha256":h},"roadmap_row":{"identity":"merged-fixture-entity","sha256":h}}}
payload={k:r[k] for k in ("identity","ownership_proof","landing_proof","outputs")}
r["proof_hash"]=hashlib.sha256(json.dumps(payload,sort_keys=True,separators=(",",":"),ensure_ascii=False).encode()).hexdigest()
(root/(cid+".json")).write_text(json.dumps(r,sort_keys=True,indent=2)+"\n"); print(cid)
PY
)"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/index.md docs/ship-flow/_closeouts
  git -C "$repo" commit -qm "fixture: optional PR awaiting checkpoint"
  git -C "$repo" rm -qr -- docs/ship-flow/merged-fixture-entity
  git -C "$repo" commit -qm "fixture: lose active entity after checkpoint"
  fixture="$TMP_DIR/pr-optional-open-dynamic.env"
  printf '%s\n' 'provider=fixture' 'number=131' 'state=MERGED' 'merged_at=2026-05-06T00:00:00Z' \
    'head_ref=ship-merged-fixture-entity' 'base_ref=main' 'url=https://github.com/example/repo/pull/131' \
    'closeout_pr_number=141' 'closeout_pr_state=OPEN' "closeout_pr_head=ship-closeout/${cid}" >"$fixture"
  before="$(hash_tree "${repo}/docs/ship-flow")"
  rc="$(run_helper "$repo" "$TMP_DIR/optional-pr-red.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "$fixture" \
    --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    optional: /' "$TMP_DIR/optional-pr-red.out"; fi
  after="$(hash_tree "${repo}/docs/ship-flow")"
  assert_exit "awaiting receipt with absent active entity rejects invalid terminal head" 2 "$rc"
  assert_contains "absent active entity requires valid exact terminal head" '^reason=closeout-sentinel-invalid$' "$TMP_DIR/optional-pr-red.out"
  if [ "$before" = "$after" ]; then
    record_pass "optional PR preflight failure preserves workflow bytes"
  else
    record_fail "optional PR preflight failure preserves workflow bytes"
  fi
  perl -0pi -e 's/closeout_pr_state=OPEN/closeout_pr_state=MERGED/' "$fixture"
  rc="$(run_helper "$repo" "$TMP_DIR/optional-awaiting-merged.out" \
    --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit "awaiting receipt cannot claim terminal MERGED without landed bytes" 2 "$rc"
  assert_contains "awaiting MERGED reports missing landed sentinel" '^reason=closeout-sentinel-missing$' "$TMP_DIR/optional-awaiting-merged.out"
}

run_optional_creation_red_contract() {
  assert_contains "optional PR flow has a dedicated checkpoint/create owner" '^reconcile_pull_request_bundle\(\)' "$HELPER"
  assert_contains "optional PR flow exposes prepared checkpoint crash recovery" 'SHIP_FLOW_CLOSEOUT_FAILPOINT.*after-prepared' "$HELPER"
  assert_contains "optional PR flow searches the exact deterministic head" 'gh pr list .*--head.*deterministic' "$HELPER"
  assert_contains "optional PR provider query binds exact head OID" 'headRefOid' "$HELPER"
  assert_contains "optional PR provider query binds draft state" 'isDraft' "$HELPER"
  assert_contains "optional PR flow can create the single exact-head PR" 'gh pr create .*--head' "$HELPER"
}

run_optional_creation_case() {
  local repo="$TMP_DIR/optional-creation-repo" fixture="$TMP_DIR/pr-optional-create.env"
  local registry="$TMP_DIR/optional-pr-registry" pr_log="$TMP_DIR/optional-pr.log" bundle_log="$TMP_DIR/optional-bundle.log"
  local base source_one source_two anchor cid deterministic_head rc receipt before_rerun merged_head seed_sha terminal_sha
  local rejected_repo rejected_fixture rejected_registry rejected_log rejected_bundle rejected_before rejected_seed registry_before state expected_rc expected_reason
  setup_repo "$repo"
  printf '%s\n' '.worktrees/' >"$repo/.gitignore"
  printf '%s\n' '# Roadmap' '' '## Now' '<!-- section:now -->' '| Entity | Title |' '| --- | --- |' '| merged-fixture-entity | Merged fixture entity |' '<!-- /section:now -->' '' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '<!-- /section:shipped -->' >"$repo/ROADMAP.md"
  mkdir -p "$repo/docs/ship-flow/_debriefs"
  git -C "$repo" add -- .gitignore ROADMAP.md
  git -C "$repo" commit -qm 'fixture: optional roadmap'
  base="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -qb implementation-topic "$base"
  write_entity "$repo/docs/ship-flow" merged-fixture-entity ship '#131' ''
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' >"$repo/docs/ship-flow/merged-fixture-entity/review.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/index.md docs/ship-flow/merged-fixture-entity/review.md
  git -C "$repo" commit -qm 'implementation: optional reviewed entity'
  source_one="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' '- Optional closeout proof is retained.' '' '### Verdict' 'merge_method_intent: rebase' 'pr: "#131"' >"$repo/docs/ship-flow/merged-fixture-entity/ship.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/ship.md
  git -C "$repo" commit -qm 'implementation: optional ship evidence'
  source_two="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -q main
  git -C "$repo" cherry-pick "$source_one" "$source_two" >/dev/null
  anchor="$(git -C "$repo" rev-parse HEAD)"
  cid="$(python3 - <<'PY'
import hashlib
print(hashlib.sha256(b"\0".join((b"v1",b"github",b"example/repo",b"docs/ship-flow",b"merged-fixture-entity",b"131"))).hexdigest())
PY
)"
  deterministic_head="ship-closeout/$cid"
  printf '%s\n' 'provider=fixture' 'number=131' 'state=MERGED' 'merged_at=2026-07-15T00:00:00Z' \
    'head_ref=implementation-topic' 'base_ref=main' 'url=https://github.com/example/repo/pull/131' 'repository=example/repo' \
    "landing_anchor=$anchor" "source_commits=$source_one,$source_two" 'pr_commit_count=2' \
    'closeout_pr_number=141' 'closeout_pr_state=OPEN' "closeout_pr_head=$deterministic_head" >"$fixture"

  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-prepared run_helper "$repo" "$TMP_DIR/optional-after-prepared.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'optional injected after-prepared stop' 1 "$rc"
  receipt="$repo/docs/ship-flow/_closeouts/$cid.json"
  assert_file_exists 'optional prepared receipt committed before create' "$receipt"
  if [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["transaction"]["phase"])' "$receipt")" = prepared ]; then record_pass 'optional first checkpoint phase is prepared'; else record_fail 'optional first checkpoint phase is prepared'; fi
  if [ ! -e "$registry" ] && [ ! -e "$pr_log" ]; then record_pass 'optional prepared crash precedes external create'; else record_fail 'optional prepared crash precedes external create'; fi
  assert_file_exists 'optional prepared crash keeps active entity' "$repo/docs/ship-flow/merged-fixture-entity/index.md"

  for state in CLOSED MERGED; do
    rejected_repo="$TMP_DIR/optional-discovered-${state}-repo"
    rejected_fixture="$TMP_DIR/optional-discovered-${state}.env"
    rejected_registry="$TMP_DIR/optional-discovered-${state}.registry"
    rejected_log="$TMP_DIR/optional-discovered-${state}.pr.log"
    rejected_bundle="$TMP_DIR/optional-discovered-${state}.bundle.log"
    git clone -q "$repo" "$rejected_repo"
    git -C "$rejected_repo" config user.email test@example.test
    git -C "$rejected_repo" config user.name 'Ship Flow Test'
    git -C "$rejected_repo" checkout -qb "$deterministic_head"
    git -C "$rejected_repo" rm -q -- "docs/ship-flow/_closeouts/$cid.json"
    git -C "$rejected_repo" commit -qm 'fixture: discovered closeout seed'
    rejected_seed="$(git -C "$rejected_repo" rev-parse HEAD)"
    git -C "$rejected_repo" checkout -q main
    cp "$fixture" "$rejected_fixture"
    perl -0pi -e "s/closeout_pr_state=OPEN/closeout_pr_state=${state}/" "$rejected_fixture"
    printf 'number=141\nhead=%s\nstate=%s\nlocal_oid=%s\nremote_oid=%s\nis_draft=true\n' "$deterministic_head" "$state" "$rejected_seed" "$rejected_seed" >"$rejected_registry"
    rejected_before="$(git -C "$rejected_repo" rev-parse HEAD)"
    registry_before="$(git hash-object "$rejected_registry")"
    if [ "$state" = CLOSED ]; then expected_rc=1; expected_reason=closeout-pr-awaiting-merge; else expected_rc=2; expected_reason=closeout-sentinel-missing; fi
    rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$rejected_registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$rejected_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$rejected_bundle" run_helper "$rejected_repo" "$TMP_DIR/optional-discovered-${state}.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$rejected_fixture" --closeout-mode pull-request)"
    assert_exit "optional discovered ${state} PR stops before recovery mutation" "$expected_rc" "$rc"
    assert_contains "optional discovered ${state} PR reports stable reason" "^reason=${expected_reason}$" "$TMP_DIR/optional-discovered-${state}.out"
    if [ "$rejected_before" = "$(git -C "$rejected_repo" rev-parse HEAD)" ] && [ "$rejected_seed" = "$(git -C "$rejected_repo" rev-parse "$deterministic_head")" ] && [ "$registry_before" = "$(git hash-object "$rejected_registry")" ] && [ ! -e "$rejected_log" ] && [ ! -e "$rejected_bundle" ] && [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["transaction"]["phase"])' "$rejected_repo/docs/ship-flow/_closeouts/$cid.json")" = prepared ]; then
      record_pass "optional discovered ${state} PR preserves checkpoint, refs, provider bytes, and logs"
    else
      record_fail "optional discovered ${state} PR preserves checkpoint, refs, provider bytes, and logs"
    fi
  done

  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAIL_ONCE=seed-push SHIP_FLOW_CLOSEOUT_FAIL_ONCE_MARKER="$TMP_DIR/optional-seed-push.once" run_helper "$repo" "$TMP_DIR/optional-seed-push-fail.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'optional seed publication fails once before PR creation' 1 "$rc"
  if [ "$(awk -F= '$1=="remote_oid"{print $2; exit}' "$registry" 2>/dev/null || true)" = "" ] && [ ! -e "$pr_log" ]; then record_pass 'optional failed seed publication records no remote OID or PR'; else record_fail 'optional failed seed publication records no remote OID or PR'; fi

  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAIL_ONCE=seed-push SHIP_FLOW_CLOSEOUT_FAIL_ONCE_MARKER="$TMP_DIR/optional-seed-push.once" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-pr-create run_helper "$repo" "$TMP_DIR/optional-after-create.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  if [ "$rc" != 1 ]; then sed 's/^/    optional-after-create: /' "$TMP_DIR/optional-after-create.out"; fi
  assert_exit 'optional injected after-create stop' 1 "$rc"
  if [ "$(grep -c '^create 141 ' "$pr_log" 2>/dev/null || true)" = 1 ]; then record_pass 'optional exact-head PR created once'; else record_fail 'optional exact-head PR created once'; fi
  if [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["transaction"]["phase"])' "$receipt")" = prepared ]; then record_pass 'optional after-create crash leaves prepared checkpoint'; else record_fail 'optional after-create crash leaves prepared checkpoint'; fi
  seed_sha="$(git -C "$repo" rev-parse "$deterministic_head")"
  if git -C "$repo" diff-tree --no-commit-id --name-status -r "$seed_sha" | grep -q "^D[[:space:]]*docs/ship-flow/_closeouts/$cid.json$"; then record_pass 'optional deterministic seed has a real receipt-deletion tree diff'; else record_fail 'optional deterministic seed has a real receipt-deletion tree diff'; fi
  if [ "$(awk -F= '$1=="local_oid"{print $2; exit}' "$registry")" = "$seed_sha" ] && [ "$(awk -F= '$1=="remote_oid"{print $2; exit}' "$registry")" = "$seed_sha" ] && [ "$(awk -F= '$1=="is_draft"{print $2; exit}' "$registry")" = true ]; then record_pass 'optional registry binds seed local and remote OID as draft'; else record_fail 'optional registry binds seed local and remote OID as draft'; fi

  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting run_helper "$repo" "$TMP_DIR/optional-after-awaiting.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'optional injected after-awaiting stop' 1 "$rc"
  if [ "$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["transaction"]["phase"])' "$receipt")" = awaiting_closeout_pr ]; then record_pass 'optional awaiting checkpoint binds PR before terminal head'; else record_fail 'optional awaiting checkpoint binds PR before terminal head'; fi
  if [ ! -e "$bundle_log" ]; then record_pass 'optional after-awaiting crash precedes bundle application'; else record_fail 'optional after-awaiting crash precedes bundle application'; fi

  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAIL_ONCE=terminal-push SHIP_FLOW_CLOSEOUT_FAIL_ONCE_MARKER="$TMP_DIR/optional-terminal-push.once" run_helper "$repo" "$TMP_DIR/optional-terminal-push-fail.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'optional terminal publication fails once after local terminal update' 1 "$rc"
  terminal_sha="$(git -C "$repo" rev-parse "$deterministic_head")"
  if [ "$terminal_sha" != "$seed_sha" ] && [ "$(awk -F= '$1=="local_oid"{print $2; exit}' "$registry")" = "$terminal_sha" ] && [ "$(awk -F= '$1=="remote_oid"{print $2; exit}' "$registry")" = "$seed_sha" ] && [ "$(awk -F= '$1=="is_draft"{print $2; exit}' "$registry")" = true ]; then record_pass 'optional failed terminal publication preserves remote seed and draft'; else record_fail 'optional failed terminal publication preserves remote seed and draft'; fi

  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAIL_ONCE=ready SHIP_FLOW_CLOSEOUT_FAIL_ONCE_MARKER="$TMP_DIR/optional-ready.once" run_helper "$repo" "$TMP_DIR/optional-ready-fail.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'optional ready transition fails once after terminal publication' 1 "$rc"
  if [ "$(awk -F= '$1=="remote_oid"{print $2; exit}' "$registry")" = "$terminal_sha" ] && [ "$(awk -F= '$1=="is_draft"{print $2; exit}' "$registry")" = true ]; then record_pass 'optional failed ready transition retains published terminal draft'; else record_fail 'optional failed ready transition retains published terminal draft'; fi

  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAIL_ONCE=ready SHIP_FLOW_CLOSEOUT_FAIL_ONCE_MARKER="$TMP_DIR/optional-ready.once" run_helper "$repo" "$TMP_DIR/optional-open.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    optional-create: /' "$TMP_DIR/optional-open.out"; fi
  assert_exit 'optional creation resumes to awaiting' 0 "$rc"
  assert_contains 'optional creation reports awaiting' '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/optional-open.out"
  if [ "$(grep -c '^create 141 ' "$pr_log")" = 1 ]; then record_pass 'optional reentry does not duplicate PR'; else record_fail 'optional reentry does not duplicate PR'; fi
  if [ "$(grep -c '^apply ' "$bundle_log")" = 1 ]; then record_pass 'optional terminal head invokes bundle exactly once'; else record_fail 'optional terminal head invokes bundle exactly once'; fi
  if grep -q "^force-with-lease ${seed_sha} " "$pr_log"; then record_pass 'optional terminal update uses known seed force-with-lease'; else record_fail 'optional terminal update uses known seed force-with-lease'; fi
  if [ "$(grep -c '^ready 141 ' "$pr_log")" = 1 ]; then record_pass 'optional PR becomes ready only after terminal validation'; else record_fail 'optional PR becomes ready only after terminal validation'; fi
  if [ "$(awk -F= '$1=="local_oid"{print $2; exit}' "$registry")" = "$terminal_sha" ] && [ "$(awk -F= '$1=="remote_oid"{print $2; exit}' "$registry")" = "$terminal_sha" ] && [ "$(awk -F= '$1=="is_draft"{print $2; exit}' "$registry")" = false ]; then record_pass 'optional registry reaches exact remote terminal OID and non-draft'; else record_fail 'optional registry reaches exact remote terminal OID and non-draft'; fi
  if python3 - "$receipt" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); t=r["transaction"]
raise SystemExit(0 if r["mode"]=="pull_request" and t=={"phase":"awaiting_closeout_pr","generation":2,"closeout_pr":141,"main_commit":None} else 1)
PY
  then record_pass 'optional main checkpoint binds one awaiting PR'; else record_fail 'optional main checkpoint binds one awaiting PR'; fi
  assert_file_exists 'optional OPEN keeps active entity nonterminal' "$repo/docs/ship-flow/merged-fixture-entity/index.md"
  if git -C "$repo" show "$deterministic_head:docs/ship-flow/_closeouts/$cid.json" | python3 -c 'import json,sys; r=json.load(sys.stdin); t=r["transaction"]; raise SystemExit(0 if r["mode"]=="pull_request" and t["phase"]=="applied" and t["closeout_pr"]==141 and t["main_commit"]==r["landing_proof"]["landing_anchor"] else 1)'; then record_pass 'optional deterministic head carries applied sentinel'; else record_fail 'optional deterministic head carries applied sentinel'; fi

  before_rerun="$(git -C "$repo" rev-parse HEAD)"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper "$repo" "$TMP_DIR/optional-open-rerun.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'optional OPEN rerun exits no-op' 0 "$rc"
  if [ "$before_rerun" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$(grep -c '^apply ' "$bundle_log")" = 1 ] && [ "$(grep -c '^create 141 ' "$pr_log")" = 1 ]; then record_pass 'optional OPEN rerun is byte and side-effect no-op'; else record_fail 'optional OPEN rerun is byte and side-effect no-op'; fi

  git -C "$repo" merge -q --no-ff "$deterministic_head" -m 'fixture: deterministic closeout PR merged'
  perl -0pi -e 's/closeout_pr_state=OPEN/closeout_pr_state=MERGED/' "$fixture"
  merged_head="$(git -C "$repo" rev-parse HEAD)"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper "$repo" "$TMP_DIR/optional-merged.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    optional-merged: /' "$TMP_DIR/optional-merged.out"; fi
  assert_exit 'optional merged sentinel exits terminal no-op' 0 "$rc"
  assert_contains 'optional merged sentinel classifies before entity lookup' '^reason=closeout-pr-terminal-noop$' "$TMP_DIR/optional-merged.out"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper "$repo" "$TMP_DIR/optional-merged-second.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'optional merged sentinel second invocation exits no-op' 0 "$rc"
  assert_contains 'optional merged sentinel never recursively creates closeout' '^reason=closeout-pr-terminal-noop$' "$TMP_DIR/optional-merged-second.out"
  if [ "$merged_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$(grep -c '^apply ' "$bundle_log")" = 1 ] && [ "$(grep -c '^create 141 ' "$pr_log")" = 1 ]; then record_pass 'optional merged first and second classification add no terminal commit or PR'; else record_fail 'optional merged first and second classification add no terminal commit or PR'; fi

  local tampered_repo="$TMP_DIR/optional-merged-tampered-repo" tampered_receipt tampered_ship tampered_head
  git clone -q "$repo" "$tampered_repo"
  tampered_receipt="$tampered_repo/docs/ship-flow/_closeouts/$cid.json"
  tampered_ship="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["outputs"]["ship"]["path"])' "$tampered_receipt")"
  printf '%s\n' 'tampered sentinel output' >>"$tampered_repo/$tampered_ship"
  tampered_head="$(git -C "$tampered_repo" rev-parse HEAD)"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" run_helper "$tampered_repo" "$TMP_DIR/optional-merged-tampered.out" --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$fixture" --closeout-mode pull-request)"
  assert_exit 'optional tampered landed sentinel rejects' 1 "$rc"
  assert_contains 'optional tampered landed sentinel reports payload mismatch' '^reason=closeout-sentinel-payload-mismatch$' "$TMP_DIR/optional-merged-tampered.out"
  if [ "$tampered_head" = "$(git -C "$tampered_repo" rev-parse HEAD)" ]; then record_pass 'optional tampered sentinel preserves HEAD'; else record_fail 'optional tampered sentinel preserves HEAD'; fi
}

run_recursion_red_case() {
  if python3 - "$HELPER" <<'PY'
import pathlib,sys
text=pathlib.Path(sys.argv[1]).read_text()
scan=text.find("scan_closeout_receipts")
lookup=text.find('active_resolve="$(resolve_entity')
raise SystemExit(0 if 0 <= scan < lookup else 1)
PY
  then
    record_pass "receipt-only sentinel scan precedes ordinary entity lookup"
  else
    record_fail "receipt-only sentinel scan precedes ordinary entity lookup"
  fi
}

run_pr40_pr41_red_case() {
  local fixture value
  for fixture in pr40-rewritten-landing.env pr41-manual-outcome.env; do
    if [ -f "${FIXTURE_ROOT}/${fixture}" ]; then
      record_pass "frozen ${fixture} dogfood fixture exists"
    else
      record_fail "frozen ${fixture} dogfood fixture exists"
    fi
  done
  value="$(awk -F= '$1=="landing_anchor"{print $2; exit}' "${FIXTURE_ROOT}/pr40-rewritten-landing.env")"
  if [ "$value" = d6d3ce4195fec956f74d0ede3192d2380746f561 ]; then record_pass 'PR40 fixture freezes rewritten landing anchor'; else record_fail 'PR40 fixture freezes rewritten landing anchor'; fi
  value="$(awk -F= '$1=="original_head"{print $2; exit}' "${FIXTURE_ROOT}/pr40-rewritten-landing.env")"
  if [ "$value" = 987ddba6b22ac51bf59ec9c35936e06846c75613 ]; then record_pass 'PR40 fixture rejects original head as landing'; else record_fail 'PR40 fixture rejects original head as landing'; fi
  value="$(awk -F= '$1=="landing_anchor"{print $2; exit}' "${FIXTURE_ROOT}/pr41-manual-outcome.env")"
  if [ "$value" = 6c5a94b6ca3b25ec5c43d161d7e323eafaa0dbc2 ]; then record_pass 'PR41 fixture freezes manual landing anchor'; else record_fail 'PR41 fixture freezes manual landing anchor'; fi
  value="$(awk -F= '$1=="original_head"{print $2; exit}' "${FIXTURE_ROOT}/pr41-manual-outcome.env")"
  if [ "$value" = 49af1c2631440c698c96d957b1ab2fdb4247607f ]; then record_pass 'PR41 fixture rejects original head as landing'; else record_fail 'PR41 fixture rejects original head as landing'; fi
}

run_frozen_dogfood_case() {
  local label="$1" slug="$2" frozen="$3" workflow="docs/dogfood-flow"
  local repo="$TMP_DIR/dogfood-${1}-repo"
  local dynamic="$TMP_DIR/dogfood-${label}.env" original count sources rc before first_head receipt expected_anchor expected_first expected_last
  git clone -q "$(git -C "$PLUGIN_ROOT" rev-parse --show-toplevel)" "$repo"
  git -C "$repo" config user.email test@example.test
  git -C "$repo" config user.name 'Ship Flow Test'
  git -C "$repo" checkout -q -B main HEAD
  rm -rf "${repo:?}/${workflow:?}"
  mkdir -p "$repo/$workflow/_mods" "$repo/$workflow/_debriefs"
  write_workflow_readme "$repo/$workflow"
  write_pr_merge_mod "$repo/$workflow"
  printf '%s\n' '# Roadmap' '' '## Now' '<!-- section:now -->' '| Entity | Title |' '| --- | --- |' "| $slug | Merged fixture entity |" '<!-- /section:now -->' '' '## Shipped' '<!-- section:shipped -->' '| Entity | Title | Shipped |' '| --- | --- | --- |' '<!-- /section:shipped -->' >"$repo/ROADMAP.md"
  write_entity "$repo/$workflow" "$slug" ship "#$(awk -F= '$1=="number"{print $2; exit}' "$frozen")" ''
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' >"$repo/$workflow/$slug/review.md"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' "- Frozen ${label} closeout evidence retained." '' '### Verdict' 'merge_method_intent: rebase' >"$repo/$workflow/$slug/ship.md"
  git -C "$repo" add -- ROADMAP.md "$workflow"
  git -C "$repo" commit -qm "fixture: frozen ${label} closeout source"
  original="$(awk -F= '$1=="original_head"{print $2; exit}' "$frozen")"
  count="$(awk -F= '$1=="pr_commit_count"{print $2; exit}' "$frozen")"
  sources="$(git -C "$repo" rev-list --reverse --first-parent --max-count="$count" "$original" | paste -sd, -)"
  cp "$frozen" "$dynamic"; printf 'source_commits=%s\n' "$sources" >>"$dynamic"
  before="$(git -C "$repo" rev-parse HEAD)"
  rc="$(run_helper_for_workflow "$repo" "$workflow" "$TMP_DIR/dogfood-${label}-first.out" --entity "$slug" --pr-provider fixture --pr-fixture "$dynamic")"
  if [ "$rc" != 0 ]; then sed "s/^/    ${label}: /" "$TMP_DIR/dogfood-${label}-first.out"; fi
  assert_exit "${label} frozen first invocation terminalizes" 0 "$rc"
  first_head="$(git -C "$repo" rev-parse HEAD)"
  if [ "$(git -C "$repo" rev-list --count "${before}..${first_head}")" = 1 ]; then record_pass "${label} first invocation creates one terminal commit"; else record_fail "${label} first invocation creates one terminal commit"; fi
  if [ "$(git -C "$repo" log -1 --format=%s)" = "ship(${slug}): advance status to done" ]; then record_pass "${label} first invocation uses one C14 bundle receipt"; else record_fail "${label} first invocation uses one C14 bundle receipt"; fi
  receipt="$(find "$repo/$workflow/_closeouts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
  expected_anchor="$(awk -F= '$1=="landing_anchor"{print $2; exit}' "$frozen")"; expected_first="$(awk -F= '$1=="first_landing_commit"{print $2; exit}' "$frozen")"; expected_last="$(awk -F= '$1=="last_landing_commit"{print $2; exit}' "$frozen")"
  if [ -f "$receipt" ] && python3 - "$receipt" "$expected_anchor" "$expected_first" "$expected_last" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); landing=r["landing_proof"]
raise SystemExit(0 if landing["landing_anchor"]==sys.argv[2] and landing["first_landing_commit"]==sys.argv[3] and landing["last_landing_commit"]==sys.argv[4] else 1)
PY
  then record_pass "${label} receipt freezes true rewritten landing boundaries"; else record_fail "${label} receipt freezes true rewritten landing boundaries"; fi
  rc="$(run_helper_for_workflow "$repo" "$workflow" "$TMP_DIR/dogfood-${label}-second.out" --entity "$slug" --pr-provider fixture --pr-fixture "$dynamic")"
  assert_exit "${label} frozen second invocation exits no-op" 0 "$rc"
  if [ "$first_head" = "$(git -C "$repo" rev-parse HEAD)" ]; then record_pass "${label} second invocation is byte/hash no-op"; else record_fail "${label} second invocation is byte/hash no-op"; fi
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
  assert_contains "pr merge doc assigns terminal projection to the reconciler only" 'reconciler owns terminal projection and idempotency; this mod only schedules calls and reports outcomes' "$pr_merge_doc"
  assert_not_contains "pr merge doc does not prescribe a second terminal status mutation" 'spacedock status .*status=\{terminal\}' "$pr_merge_doc"
  assert_not_contains "pr merge doc does not prescribe a second archive mutation" 'spacedock status .*--archive' "$pr_merge_doc"
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
  if [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-f1 ]; then
    run_incomplete_landing_contract_case
    run_missing_landing_field_matrix
    run_cleanup_safety_contract_cases
    run_pull_request_roadmap_validation_case
    run_doc_scope_cases
  else
  run_runtime_regression_cases
  run_incomplete_landing_contract_case
  run_missing_landing_field_matrix
  run_cleanup_safety_contract_cases
  run_refusal_cases
  run_usage_and_dry_run_cases
  run_idempotency_cases
  if [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = direct-transaction ]; then
    run_direct_transaction_case
  fi
  if case_selected optional-pr; then
    run_optional_pr_red_case
    run_optional_creation_red_contract
    run_optional_creation_case
  fi
  case_selected recursion && run_recursion_red_case
  if case_selected pr40-pr41; then
    run_pr40_pr41_red_case
    run_frozen_dogfood_case pr40 dogfood-pr40 "${FIXTURE_ROOT}/pr40-rewritten-landing.env"
    run_frozen_dogfood_case pr41 dogfood-pr41 "${FIXTURE_ROOT}/pr41-manual-outcome.env"
  fi
  run_scope_guard
  run_doc_scope_cases
  fi
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
