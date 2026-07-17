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
  git init -q -b main "$repo"
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

prepare_full_d1_squash_repo() {
  local repo="$1" fixture="$2"
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
  git -C "$repo" commit -qm 'fixture: add squash roadmap'
  base="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -qb ship-merged-fixture-entity "$base"
  write_entity "$repo/docs/ship-flow" merged-fixture-entity ship '#131' ''
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' >"$repo/docs/ship-flow/merged-fixture-entity/review.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/index.md docs/ship-flow/merged-fixture-entity/review.md
  git -C "$repo" commit -qm 'implementation: add squash reviewed entity'
  source_one="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' \
    '- Preserve squash source proof.' '' '### Verdict' \
    'merge_method_intent: squash' 'pr: "#131"' \
    >"$repo/docs/ship-flow/merged-fixture-entity/ship.md"
  git -C "$repo" add -- docs/ship-flow/merged-fixture-entity/ship.md
  git -C "$repo" commit -qm 'implementation: add squash ship evidence'
  source_two="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" checkout -q main
  git -C "$repo" merge --squash -q ship-merged-fixture-entity >/dev/null
  git -C "$repo" commit -qm 'fixture: squash implementation landing'
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

run_feedback_r2_f1_case() {
  local legacy_repo="$TMP_DIR/feedback-r2-f1-legacy-repo"
  local fixture="${FIXTURE_ROOT}/pr-merged.env"
  local output="$TMP_DIR/feedback-r2-f1-legacy.out"
  local registry="$TMP_DIR/feedback-r2-f1.registry"
  local pr_log="$TMP_DIR/feedback-r2-f1-pr.log"
  local bundle_log="$TMP_DIR/feedback-r2-f1-bundle.log"
  local before_head before_tree rc

  setup_repo "$legacy_repo"
  write_entity "$legacy_repo/docs/ship-flow" merged-fixture-entity 'done' '#131' '' '2026-05-06T00:00:00Z' PASSED
  git -C "$legacy_repo" add -- docs/ship-flow/merged-fixture-entity/index.md
  git -C "$legacy_repo" commit -qm 'fixture: active legacy terminal entity'
  before_head="$(git -C "$legacy_repo" rev-parse HEAD)"
  before_tree="$(hash_tree "$legacy_repo/docs/ship-flow")"

  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" \
    SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" \
    run_helper "$legacy_repo" "$output" \
      --entity merged-fixture-entity \
      --pr-provider fixture \
      --pr-fixture "$fixture" \
      --closeout-mode pull-request)"

  assert_exit 'active legacy done/PASSED without native proof rejects' 2 "$rc"
  assert_contains 'active legacy terminal reports stable landing reason' '^reason=landing-anchor-missing$' "$output"
  assert_contains 'active legacy terminal does not proceed' '^verdict=REJECT$' "$output"
  assert_file_exists 'active legacy terminal keeps active index' "$legacy_repo/docs/ship-flow/merged-fixture-entity/index.md"
  assert_path_missing 'active legacy terminal creates no index-only archive' "$legacy_repo/docs/ship-flow/_archive/merged-fixture-entity"
  assert_path_missing 'active legacy terminal creates no native receipt' "$legacy_repo/docs/ship-flow/_closeouts"
  if [ "$before_head" = "$(git -C "$legacy_repo" rev-parse HEAD)" ] && \
     [ "$before_tree" = "$(hash_tree "$legacy_repo/docs/ship-flow")" ]; then
    record_pass 'active legacy terminal preserves HEAD and workflow bytes'
  else
    record_fail 'active legacy terminal preserves HEAD and workflow bytes'
  fi
  if [ ! -e "$registry" ] && [ ! -e "$pr_log" ] && [ ! -e "$bundle_log" ]; then
    record_pass 'active legacy terminal creates no closeout provider or bundle side effects'
  else
    record_fail 'active legacy terminal creates no closeout provider or bundle side effects'
  fi

  local native_repo="$TMP_DIR/feedback-r2-f1-native-repo"
  local native_fixture="$TMP_DIR/feedback-r2-f1-native.env"
  local native_head native_tree
  prepare_full_d1_repo "$native_repo" "$native_fixture"
  rc="$(run_helper "$native_repo" "$TMP_DIR/feedback-r2-f1-native-first.out" \
    --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$native_fixture")"
  assert_exit 'native terminal fixture applies once' 0 "$rc"
  native_head="$(git -C "$native_repo" rev-parse HEAD)"
  native_tree="$(hash_tree "$native_repo/docs/ship-flow")"
  rc="$(run_helper "$native_repo" "$TMP_DIR/feedback-r2-f1-native-rerun.out" \
    --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$native_fixture")"
  assert_exit 'coherent native terminal rerun exits success' 0 "$rc"
  assert_contains 'coherent native terminal rerun reports already reconciled' '^state=already_reconciled$' "$TMP_DIR/feedback-r2-f1-native-rerun.out"
  if [ "$native_head" = "$(git -C "$native_repo" rev-parse HEAD)" ] && \
     [ "$native_tree" = "$(hash_tree "$native_repo/docs/ship-flow")" ]; then
    record_pass 'coherent native terminal rerun is a byte and commit no-op'
  else
    record_fail 'coherent native terminal rerun is a byte and commit no-op'
  fi
}

run_feedback_r2_b2_integration_case() {
  local direct_repo="$TMP_DIR/feedback-r2-b2-direct-repo"
  local direct_fixture="$TMP_DIR/feedback-r2-b2-direct.env"
  local missing_repo="$TMP_DIR/feedback-r2-b2-missing-repo"
  local missing_fixture="$TMP_DIR/feedback-r2-b2-missing.env"
  local before_head before_tree landed_head rc receipt

  prepare_full_d1_squash_repo "$direct_repo" "$direct_fixture"
  git clone -q "$direct_repo" "$missing_repo"
  grep -v '^source_commits=' "$direct_fixture" >"$missing_fixture"
  before_head="$(git -C "$missing_repo" rev-parse HEAD)"
  before_tree="$(hash_tree "$missing_repo/docs/ship-flow")"
  rc="$(run_helper "$missing_repo" "$TMP_DIR/feedback-r2-b2-missing.out" \
    --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$missing_fixture")"
  assert_exit 'squash closeout without provider source commits rejects' 2 "$rc"
  assert_contains 'missing provider source commits reports stable reason' '^reason=landing-pr-commit-count-mismatch$' "$TMP_DIR/feedback-r2-b2-missing.out"
  if [ "$before_head" = "$(git -C "$missing_repo" rev-parse HEAD)" ] && \
     [ "$before_tree" = "$(hash_tree "$missing_repo/docs/ship-flow")" ]; then
    record_pass 'missing provider source commits preserve HEAD and workflow bytes'
  else
    record_fail 'missing provider source commits preserve HEAD and workflow bytes'
  fi
  assert_file_exists 'missing provider source commits keep active entity' "$missing_repo/docs/ship-flow/merged-fixture-entity/index.md"
  assert_path_missing 'missing provider source commits create no archive' "$missing_repo/docs/ship-flow/_archive/merged-fixture-entity"

  rc="$(run_helper "$direct_repo" "$TMP_DIR/feedback-r2-b2-direct.out" \
    --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$direct_fixture")"
  assert_exit 'integrated squash direct closeout exits success' 0 "$rc"
  assert_contains 'integrated squash direct closeout uses native bundle' '^terminal_action=closeout_bundle$' "$TMP_DIR/feedback-r2-b2-direct.out"
  receipt="$(find "$direct_repo/docs/ship-flow/_closeouts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
  if [ -n "$receipt" ]; then record_pass 'integrated squash direct closeout lands receipt'; else record_fail 'integrated squash direct closeout lands receipt'; fi
  landed_head="$(git -C "$direct_repo" rev-parse HEAD)"
  rc="$(run_helper "$direct_repo" "$TMP_DIR/feedback-r2-b2-direct-rerun.out" \
    --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$direct_fixture")"
  assert_exit 'integrated squash archived direct replay exits success' 0 "$rc"
  assert_contains 'integrated squash archived direct replay is reconciled' '^state=already_reconciled$' "$TMP_DIR/feedback-r2-b2-direct-rerun.out"
  if [ "$landed_head" = "$(git -C "$direct_repo" rev-parse HEAD)" ]; then
    record_pass 'integrated squash archived direct replay creates no commit'
  else
    record_fail 'integrated squash archived direct replay creates no commit'
  fi

  local optional_repo="$TMP_DIR/feedback-r2-b2-optional-repo"
  local optional_fixture="$TMP_DIR/feedback-r2-b2-optional.env"
  local registry="$TMP_DIR/feedback-r2-b2-optional.registry"
  local pr_log="$TMP_DIR/feedback-r2-b2-optional.pr.log"
  local bundle_log="$TMP_DIR/feedback-r2-b2-optional.bundle.log"
  local cid deterministic_head open_head merged_head
  prepare_full_d1_squash_repo "$optional_repo" "$optional_fixture"
  cid="$(python3 - <<'PY'
import hashlib
print(hashlib.sha256(b"\0".join((b"v1",b"github",b"example/repo",b"docs/ship-flow",b"merged-fixture-entity",b"131"))).hexdigest())
PY
)"
  deterministic_head="ship-closeout/$cid"
  printf '%s\n' 'closeout_pr_number=141' 'closeout_pr_state=OPEN' "closeout_pr_head=$deterministic_head" >>"$optional_fixture"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper "$optional_repo" "$TMP_DIR/feedback-r2-b2-optional.out" \
      --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$optional_fixture" --closeout-mode pull-request)"
  assert_exit 'integrated squash optional closeout prepares terminal head' 0 "$rc"
  assert_contains 'integrated squash optional closeout awaits merge' '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/feedback-r2-b2-optional.out"
  if git -C "$optional_repo" show-ref --verify --quiet "refs/heads/$deterministic_head"; then record_pass 'integrated squash optional terminal head exists'; else record_fail 'integrated squash optional terminal head exists'; fi
  open_head="$(git -C "$optional_repo" rev-parse HEAD)"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper "$optional_repo" "$TMP_DIR/feedback-r2-b2-optional-rerun.out" \
      --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$optional_fixture" --closeout-mode pull-request)"
  assert_exit 'integrated squash receipt-only OPEN replay exits success' 0 "$rc"
  assert_contains 'integrated squash receipt-only OPEN replay awaits merge' '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/feedback-r2-b2-optional-rerun.out"
  assert_contains 'integrated squash receipt-only OPEN report retains closeout PR identity' '^pr=141$' "$TMP_DIR/feedback-r2-b2-optional-rerun.out"
  if [ "$open_head" = "$(git -C "$optional_repo" rev-parse HEAD)" ]; then record_pass 'integrated squash receipt-only OPEN replay creates no commit'; else record_fail 'integrated squash receipt-only OPEN replay creates no commit'; fi
  if git -C "$optional_repo" show "$deterministic_head:docs/ship-flow/_closeouts/$cid.json" 2>/dev/null | \
    python3 -c 'import json,sys; raise SystemExit(0 if json.load(sys.stdin)["transaction"]["phase"]=="applied" else 1)'; then
    git -C "$optional_repo" merge -q --no-ff "$deterministic_head" -m 'fixture: squash closeout PR merged'
    perl -0pi -e 's/closeout_pr_state=OPEN/closeout_pr_state=MERGED/' "$optional_fixture"
    merged_head="$(git -C "$optional_repo" rev-parse HEAD)"
    rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" SHIP_FLOW_CLOSEOUT_PR_LOG="$pr_log" \
      SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper "$optional_repo" "$TMP_DIR/feedback-r2-b2-optional-merged.out" \
        --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$optional_fixture" --closeout-mode pull-request)"
    assert_exit 'integrated squash receipt-only MERGED replay exits success' 0 "$rc"
    assert_contains 'integrated squash receipt-only MERGED replay is terminal no-op' '^reason=closeout-pr-terminal-noop$' "$TMP_DIR/feedback-r2-b2-optional-merged.out"
    assert_contains 'integrated squash receipt-only MERGED report retains closeout PR identity' '^pr=141$' "$TMP_DIR/feedback-r2-b2-optional-merged.out"
    if [ "$merged_head" = "$(git -C "$optional_repo" rev-parse HEAD)" ]; then record_pass 'integrated squash receipt-only MERGED replay creates no commit'; else record_fail 'integrated squash receipt-only MERGED replay creates no commit'; fi
  else
    record_fail 'integrated squash receipt-only MERGED replay exits success'
    record_fail 'integrated squash receipt-only MERGED replay is terminal no-op'
    record_fail 'integrated squash receipt-only MERGED report retains closeout PR identity'
    record_fail 'integrated squash receipt-only MERGED replay creates no commit'
  fi
}

write_feedback_r3_b1_gh() {
  local bin="$1"
  cat >"$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${SHIP_FLOW_R3_PROVIDER_FILE:?missing provider metadata}"
: "${SHIP_FLOW_R3_GH_LOG:?missing gh log}"
printf '%s\n' "$*" >>"$SHIP_FLOW_R3_GH_LOG"
[ -z "${SHIP_FLOW_R3_GH_PWD_LOG:-}" ] || printf 'pwd=%s args=%s\n' "$PWD" "$*" >>"$SHIP_FLOW_R3_GH_PWD_LOG"

field() {
  awk -F= -v key="$1" '$1==key{sub(/^[^=]*=/, ""); print; exit}' "$SHIP_FLOW_R3_PROVIDER_FILE"
}

require_repo_binding() {
  local expected="${SHIP_FLOW_R3_EXPECT_REPOSITORY:-$(field repository)}" seen="" previous=""
  for arg in "$@"; do
    if [ "$previous" = --repo ]; then seen="$arg"; break; fi
    previous="$arg"
  done
  if [ -z "$seen" ] || [ "$seen" != "$expected" ]; then
    printf 'provider repository binding mismatch: expected=%s actual=%s args=%s\n' \
      "$expected" "${seen:-missing}" "$*" >&2
    exit 64
  fi
  [ -z "${SHIP_FLOW_R3_GH_REPO_LOG:-}" ] || printf 'repo=%s args=%s\n' "$seen" "$*" >>"$SHIP_FLOW_R3_GH_REPO_LOG"
}

if [ "${1:-}" = pr ] && [ "${2:-}" = view ] && [ "${3:-}" = 131 ]; then
  require_repo_binding "$@"
  printf '%s\n' \
    'provider=gh' \
    "number=$(field number)" \
    "state=$(field state)" \
    "merged_at=$(field merged_at)" \
    "head_ref=$(field head_ref)" \
    "base_ref=$(field base_ref)" \
    "url=$(field url)" \
    "landing_anchor=$(field landing_anchor)" \
    "source_commits=$(field source_commits)" \
    "pr_commit_count=$(field pr_commit_count)"
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = view ] && [ "${3:-}" = 141 ]; then
  number="$(field closeout_pr_number)"; state="$(field closeout_pr_state)"
  head="$(field closeout_pr_head)"; remote_oid="$(field closeout_pr_remote_oid)"
  is_draft="$(field closeout_pr_is_draft)"
  require_repo_binding "$@"
  [ -n "$number" ] || number=141
  [ -n "$state" ] || state=OPEN
  [ -n "$head" ] || head="${SHIP_FLOW_R3_CLOSEOUT_HEAD:-}"
  if [ -z "$remote_oid" ] && [ -n "${SHIP_FLOW_R3_CLOSEOUT_ORIGIN:-}" ] && [ -n "$head" ]; then
    remote_oid="$(git -C "$SHIP_FLOW_R3_CLOSEOUT_ORIGIN" rev-parse --verify "refs/heads/$head" 2>/dev/null || true)"
  fi
  [ -n "$is_draft" ] || is_draft=true
  printf '%s|%s|%s|%s|%s\n' \
    "$number" "$state" "$head" "$remote_oid" "$is_draft"
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = list ]; then
  require_repo_binding "$@"
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = create ]; then
  require_repo_binding "$@"
  printf '%s\n' 'https://github.com/example/repo/pull/141'
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = ready ] && [ "${3:-}" = 141 ]; then
  require_repo_binding "$@"
  exit 0
fi

if [ "${1:-}" = repo ] && [ "${2:-}" = view ]; then
  if [ -n "${SHIP_FLOW_R3_EXPECT_GH_PWD:-}" ] && [ "$PWD" != "$SHIP_FLOW_R3_EXPECT_GH_PWD" ]; then
    printf '%s\n' wrong/repository
    exit 0
  fi
  field repository
  exit 0
fi

echo "unsupported fake gh invocation: $*" >&2
exit 2
EOF
  chmod +x "$bin"
}

prepare_feedback_r3_b1_main_only_clone() {
  local label="$1"
  local source_repo="$TMP_DIR/${label}-source"
  local source_fixture="$TMP_DIR/${label}-source.env"
  local origin="$TMP_DIR/${label}-origin.git"
  local clone="$TMP_DIR/${label}-main-only"
  local source_tip

  prepare_full_d1_squash_repo "$source_repo" "$source_fixture"
  source_tip="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); n=split($0,oids,","); print oids[n]; exit}' "$source_fixture")"
  git clone -q --bare "$source_repo" "$origin"
  git -C "$origin" config ship-flow.closeoutFixtureRepository example/repo
  git -C "$origin" update-ref refs/pull/131/head "$source_tip"
  git -C "$origin" update-ref -d refs/heads/ship-merged-fixture-entity
  git -C "$origin" symbolic-ref HEAD refs/heads/main

  git clone -q --single-branch --branch main --no-tags "$origin" "$clone"
  git -C "$clone" config user.email test@example.test
  git -C "$clone" config user.name 'Ship Flow Test'
  git -C "$clone" config remote.origin.url https://github.com/example/repo.git
  git -C "$clone" config "url.file://${origin}.insteadOf" https://github.com/example/repo.git
  # A local-path clone may hard-link unreachable objects that a network
  # single-branch clone would never receive. Prune that local transport residue
  # so this is a true main-only object database, not only a main-only ref set.
  rm -f "$clone/.git/FETCH_HEAD"
  git -C "$clone" reflog expire --expire=now --all
  git -C "$clone" gc -q --prune=now
  cp "$source_fixture" "$TMP_DIR/${label}-provider.env"

  printf '%s\n' "$origin|$clone|$TMP_DIR/${label}-provider.env"
}

assert_feedback_r3_b1_objects_missing() {
  local desc="$1" repo="$2" source_commits="$3" oid missing=no
  local old_ifs="$IFS"
  IFS=','
  for oid in $source_commits; do
    if git -C "$repo" cat-file -e "${oid}^{commit}" 2>/dev/null; then
      missing=no
      break
    fi
    missing=yes
  done
  IFS="$old_ifs"
  if [ "$missing" = yes ]; then record_pass "$desc"; else record_fail "$desc"; fi
}

assert_feedback_r3_b1_objects_present() {
  local desc="$1" repo="$2" source_commits="$3" oid present=yes
  local old_ifs="$IFS"
  IFS=','
  for oid in $source_commits; do
    if ! git -C "$repo" cat-file -e "${oid}^{commit}" 2>/dev/null; then
      present=no
      break
    fi
  done
  IFS="$old_ifs"
  if [ "$present" = yes ]; then record_pass "$desc"; else record_fail "$desc"; fi
}

assert_feedback_r3_b1_acquisition_cleanup() {
  local label="$1" repo="$2" expected_preexisting="$3"
  local namespace=refs/ship-flow/closeout-source preexisting leftovers
  preexisting="$namespace/preexisting"
  leftovers="$(git -C "$repo" for-each-ref --format='%(refname)' "$namespace" | grep -v "^${preexisting}$" || true)"
  if [ "$(git -C "$repo" rev-parse --verify "$preexisting")" = "$expected_preexisting" ]; then record_pass "$label preserves the unrelated acquisition ref"; else record_fail "$label preserves the unrelated acquisition ref"; fi
  if [ -z "$leftovers" ]; then record_pass "$label removes every process-scoped acquisition ref"; else record_fail "$label removes every process-scoped acquisition ref"; fi
  if [ ! -e "$repo/.git/shallow" ]; then record_pass "$label leaves no shallow repository marker"; else record_fail "$label leaves no shallow repository marker"; fi
  if [ ! -e "$repo/.git/FETCH_HEAD" ]; then record_pass "$label leaves FETCH_HEAD absent"; else record_fail "$label leaves FETCH_HEAD absent"; fi
}

run_feedback_r3_b1_main_only_case() {
  local setup origin repo provider source_commits source_tip before_head after_head
  local remote_before remote_after rc gh_bin_dir="$TMP_DIR/feedback-r3-b1-bin"
  local gh_log="$TMP_DIR/feedback-r3-b1-gh.log"
  local registry cid deterministic_head terminal_oid receipt phase preexisting_oid
  mkdir -p "$gh_bin_dir"
  write_feedback_r3_b1_gh "$gh_bin_dir/gh"

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r3-b1-direct)"
  IFS='|' read -r origin repo provider <<<"$setup"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
  source_tip="${source_commits##*,}"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  preexisting_oid="$before_head"
  git -C "$repo" update-ref refs/ship-flow/closeout-source/preexisting "$preexisting_oid"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"

  assert_feedback_r3_b1_objects_missing 'R3 main-only clone starts without authoritative source commit objects' "$repo" "$source_commits"
  if [ "$(git -C "$origin" rev-parse refs/pull/131/head)" = "$source_tip" ] && \
     ! git -C "$origin" show-ref --verify --quiet refs/heads/ship-merged-fixture-entity; then
    record_pass 'R3 bare origin exposes exact PR head after implementation branch cleanup'
  else
    record_fail 'R3 bare origin exposes exact PR head after implementation branch cleanup'
  fi
  if [ "$(git -C "$repo" config --get remote.origin.url)" = https://github.com/example/repo.git ]; then
    record_pass 'R3 provider repository identity is bound to origin'
  else
    record_fail 'R3 provider repository identity is bound to origin'
  fi

  rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-b1-direct.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh)"
  if [ "$rc" != 0 ]; then sed 's/^/    r3-direct: /' "$TMP_DIR/feedback-r3-b1-direct.out"; fi
  assert_exit 'R3 main-only direct closeout acquires exact PR source objects' 0 "$rc"
  assert_contains 'R3 direct closeout uses provider-bound implementation PR' '^pr=131$' "$TMP_DIR/feedback-r3-b1-direct.out"
  assert_contains 'R3 direct closeout reaches native bundle after acquisition' '^terminal_action=closeout_bundle$' "$TMP_DIR/feedback-r3-b1-direct.out"
  assert_feedback_r3_b1_objects_present 'R3 direct closeout materializes every provider source commit object' "$repo" "$source_commits"
  after_head="$(git -C "$repo" rev-parse HEAD)"
  if [ "$rc" = 0 ]; then
    if [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ] && \
       [ "$(git -C "$repo" rev-parse "${after_head}^1")" = "$before_head" ]; then
      record_pass 'R3 acquisition preserves main checkout and base lineage'
    else
      record_fail 'R3 acquisition preserves main checkout and base lineage'
    fi
  elif [ "$after_head" = "$before_head" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then
    record_pass 'R3 rejected acquisition preserves main checkout and base HEAD'
  else
    record_fail 'R3 rejected acquisition preserves main checkout and base HEAD'
  fi
  remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$remote_before" = "$remote_after" ]; then record_pass 'R3 direct acquisition performs no remote write'; else record_fail 'R3 direct acquisition performs no remote write'; fi
  assert_feedback_r3_b1_acquisition_cleanup 'R3 direct acquisition cleanup' "$repo" "$preexisting_oid"
  assert_contains 'R3 fake gh observed exact implementation PR query' '^pr view 131 ' "$gh_log"

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r3-b1-mismatch)"
  IFS='|' read -r origin repo provider <<<"$setup"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
  git -C "$origin" update-ref refs/pull/131/head "$(git -C "$origin" rev-parse refs/heads/main)"
  git -C "$origin" reflog expire --expire=now --all
  git -C "$origin" gc -q --prune=now
  before_head="$(git -C "$repo" rev-parse HEAD)"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-b1-mismatch.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh)"
  assert_exit 'R3 mismatched exact PR ref fails closed' 2 "$rc"
  assert_contains 'R3 mismatched exact PR ref reports REJECT' '^verdict=REJECT$' "$TMP_DIR/feedback-r3-b1-mismatch.out"
  assert_contains 'R3 mismatched exact PR ref reports canonical reason' '^reason=landing-patch-equivalence-failed$' "$TMP_DIR/feedback-r3-b1-mismatch.out"
  assert_feedback_r3_b1_objects_missing 'R3 mismatched exact PR ref cannot materialize provider source objects' "$repo" "$source_commits"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then
    record_pass 'R3 mismatched exact PR ref preserves base HEAD and checkout'
  else
    record_fail 'R3 mismatched exact PR ref preserves base HEAD and checkout'
  fi
  remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$remote_before" = "$remote_after" ]; then record_pass 'R3 mismatched exact PR ref performs no remote write'; else record_fail 'R3 mismatched exact PR ref performs no remote write'; fi

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r3-b1-optional-construct)"
  IFS='|' read -r origin repo provider <<<"$setup"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  preexisting_oid="$before_head"
  git -C "$repo" update-ref refs/ship-flow/closeout-source/preexisting "$preexisting_oid"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-prepared \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-b1-optional-construct.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$rc" != 1 ]; then sed 's/^/    r3-optional-construct: /' "$TMP_DIR/feedback-r3-b1-optional-construct.out"; fi
  assert_exit 'R3 main-only optional construction reaches hermetic prepared checkpoint' 1 "$rc"
  assert_contains 'R3 optional construction stops at the requested pre-push failpoint' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r3-b1-optional-construct.out"
  assert_feedback_r3_b1_objects_present 'R3 optional construction acquires every provider source commit before rendering' "$repo" "$source_commits"
  receipt="$(find "$repo/docs/ship-flow/_closeouts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
  phase="$(if [ -f "$receipt" ]; then python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["transaction"]["phase"])' "$receipt"; fi)"
  if [ "$phase" = prepared ]; then record_pass 'R3 optional construction validates and records a prepared receipt'; else record_fail 'R3 optional construction validates and records a prepared receipt'; fi
  after_head="$(git -C "$repo" rev-parse HEAD)"
  if [ "$rc" = 1 ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ] && \
     [ "$(git -C "$repo" rev-parse "${after_head}^1")" = "$before_head" ]; then
    record_pass 'R3 optional acquisition preserves checkout and adds only the prepared checkpoint'
  elif [ "$after_head" = "$before_head" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then
    record_pass 'R3 rejected optional acquisition preserves base HEAD and checkout'
  else
    record_fail 'R3 optional acquisition preserves authoritative main lineage'
  fi
  remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$remote_before" = "$remote_after" ]; then record_pass 'R3 optional acquisition reaches no push or PR-create side effect'; else record_fail 'R3 optional acquisition reaches no push or PR-create side effect'; fi
  assert_feedback_r3_b1_acquisition_cleanup 'R3 optional nonzero cleanup' "$repo" "$preexisting_oid"

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r3-b1-replay)"
  IFS='|' read -r origin repo provider <<<"$setup"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
  git -C "$repo" fetch -q --no-tags origin refs/pull/131/head
  rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-b1-replay-seed.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh)"
  assert_exit 'R3 replay fixture seeds one native receipt while source objects are present' 0 "$rc"
  rm -f "$repo/.git/FETCH_HEAD"
  git -C "$repo" reflog expire --expire=now --all
  git -C "$repo" gc -q --prune=now
  assert_feedback_r3_b1_objects_missing 'R3 replay fixture prunes source objects after branch cleanup' "$repo" "$source_commits"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-b1-replay.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh)"
  if [ "$rc" != 0 ]; then sed 's/^/    r3-replay: /' "$TMP_DIR/feedback-r3-b1-replay.out"; fi
  assert_exit 'R3 archived receipt replay reacquires exact PR source objects' 0 "$rc"
  assert_contains 'R3 archived receipt replay validates as already reconciled' '^state=already_reconciled$' "$TMP_DIR/feedback-r3-b1-replay.out"
  assert_feedback_r3_b1_objects_present 'R3 archived receipt replay rematerializes every source object' "$repo" "$source_commits"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then
    record_pass 'R3 archived receipt replay preserves base HEAD and checkout'
  else
    record_fail 'R3 archived receipt replay preserves base HEAD and checkout'
  fi
  remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$remote_before" = "$remote_after" ]; then record_pass 'R3 replay acquisition performs no remote write'; else record_fail 'R3 replay acquisition performs no remote write'; fi

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r3-b1-optional-replay)"
  IFS='|' read -r origin repo provider <<<"$setup"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
  git -C "$repo" fetch -q --no-tags origin refs/pull/131/head
  cid="$(python3 - <<'PY'
import hashlib
print(hashlib.sha256(b"\0".join((b"v1",b"github",b"example/repo",b"docs/ship-flow",b"merged-fixture-entity",b"131"))).hexdigest())
PY
)"
  deterministic_head="ship-closeout/$cid"
  printf '%s\n' 'closeout_pr_number=141' 'closeout_pr_state=OPEN' \
    "closeout_pr_head=$deterministic_head" >>"$provider"
  registry="$TMP_DIR/feedback-r3-b1-optional-replay.registry"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" \
    run_helper "$repo" "$TMP_DIR/feedback-r3-b1-optional-replay-seed.out" \
      --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$provider" --closeout-mode pull-request)"
  assert_exit 'R3 optional replay fixture seeds exact OPEN receipt candidate' 0 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"
  git -C "$repo" checkout -q "$deterministic_head"
  python3 - "$receipt" "file://${origin}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -qm 'fixture: bind R3 terminal publication endpoint'
  git -C "$repo" checkout -q main
  python3 - "$receipt" "file://${origin}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -q --amend --no-edit
  terminal_oid="$(git -C "$repo" rev-parse "$deterministic_head")"
  printf '%s\n' "closeout_pr_remote_oid=$terminal_oid" 'closeout_pr_is_draft=false' >>"$provider"
  rm -f "$repo/.git/FETCH_HEAD"
  git -C "$repo" reflog expire --expire=now --all
  git -C "$repo" gc -q --prune=now
  assert_feedback_r3_b1_objects_missing 'R3 optional OPEN replay starts after source-object pruning' "$repo" "$source_commits"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-b1-optional-open.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    r3-optional-open: /' "$TMP_DIR/feedback-r3-b1-optional-open.out"; fi
  assert_exit 'R3 receipt-only OPEN replay reacquires exact PR source objects' 0 "$rc"
  assert_contains 'R3 receipt-only OPEN replay retains awaiting state' '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/feedback-r3-b1-optional-open.out"
  assert_feedback_r3_b1_objects_present 'R3 receipt-only OPEN replay rematerializes every source object' "$repo" "$source_commits"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then
    record_pass 'R3 receipt-only OPEN replay preserves base HEAD and checkout'
  else
    record_fail 'R3 receipt-only OPEN replay preserves base HEAD and checkout'
  fi
  remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$remote_before" = "$remote_after" ]; then record_pass 'R3 receipt-only OPEN acquisition performs no remote write'; else record_fail 'R3 receipt-only OPEN acquisition performs no remote write'; fi

  python3 - "$receipt" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"].pop("publication_endpoint",None)
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -q --amend --no-edit
  if ! git -C "$repo" merge -q --no-ff "$deterministic_head" -m 'fixture: land optional terminal head' >/dev/null 2>&1; then
    [ "$(git -C "$repo" diff --name-only --diff-filter=U)" = "${receipt#"$repo/"}" ] || exit 1
    git -C "$repo" checkout -q --theirs -- "${receipt#"$repo/"}"
    git -C "$repo" add -- "${receipt#"$repo/"}"
    git -C "$repo" commit -qm 'fixture: land optional terminal head'
  fi
  perl -0pi -e 's/closeout_pr_state=OPEN/closeout_pr_state=MERGED/' "$provider"
  rm -f "$repo/.git/FETCH_HEAD"
  git -C "$repo" reflog expire --expire=now --all
  git -C "$repo" gc -q --prune=now
  assert_feedback_r3_b1_objects_missing 'R3 receipt-only MERGED replay re-prunes source objects' "$repo" "$source_commits"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-b1-optional-merged.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    r3-optional-merged: /' "$TMP_DIR/feedback-r3-b1-optional-merged.out"; fi
  assert_exit 'R3 receipt-only MERGED replay reacquires exact PR source objects' 0 "$rc"
  assert_contains 'R3 receipt-only MERGED replay remains terminal no-op' '^reason=closeout-pr-terminal-noop$' "$TMP_DIR/feedback-r3-b1-optional-merged.out"
  assert_feedback_r3_b1_objects_present 'R3 receipt-only MERGED replay rematerializes every source object' "$repo" "$source_commits"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then
    record_pass 'R3 receipt-only MERGED replay preserves base HEAD and checkout'
  else
    record_fail 'R3 receipt-only MERGED replay preserves base HEAD and checkout'
  fi
  remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$remote_before" = "$remote_after" ]; then record_pass 'R3 receipt-only MERGED acquisition performs no remote write'; else record_fail 'R3 receipt-only MERGED acquisition performs no remote write'; fi
}

write_feedback_r3_review_git_wrapper() {
  local bin="$1"
  cat >"$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

atomic_ref=""
seen_update=no
has_zero=no
zero=0000000000000000000000000000000000000000
for arg in "$@"; do
  if [ "$seen_update" = yes ] && [ -z "$atomic_ref" ]; then atomic_ref="$arg"; fi
  [ "$arg" != update-ref ] || seen_update=yes
  [ "$arg" != "$zero" ] || has_zero=yes
done
case "$atomic_ref" in refs/ship-flow/closeout-source/*) ;; *) atomic_ref="" ;; esac
[ "$has_zero" = yes ] || atomic_ref=""

if [ "${SHIP_FLOW_R3_GIT_MODE:-}" = collision ] && [ -n "$atomic_ref" ]; then
  "$SHIP_FLOW_R3_REAL_GIT" -C "$SHIP_FLOW_R3_TARGET_REPO" update-ref "$atomic_ref" "$SHIP_FLOW_R3_COLLISION_OID"
  printf '%s\n' "$atomic_ref" >"$SHIP_FLOW_R3_GIT_MARKER"
fi

"$SHIP_FLOW_R3_REAL_GIT" "$@"
rc=$?
if [ "$rc" = 0 ] && [ "${SHIP_FLOW_R3_GIT_MODE:-}" = signal ] && [ -n "$atomic_ref" ]; then
  printf '%s\n' "$atomic_ref" >"$SHIP_FLOW_R3_GIT_MARKER"
  kill -s "$SHIP_FLOW_R3_SIGNAL" "$PPID"
fi
exit "$rc"
EOF
  chmod +x "$bin"
}

run_feedback_r3_review_blockers_case() {
  local gh_bin_dir="$TMP_DIR/feedback-r3-review-gh-bin" gh_log="$TMP_DIR/feedback-r3-review-gh.log"
  local git_bin_dir="$TMP_DIR/feedback-r3-review-git-bin" real_git setup origin repo provider
  local source_commits before_head after_head remote_before remote_after rc outside pwd_log
  local collision_oid collision_ref marker preexisting_oid leftovers expected signal label raw
  mkdir -p "$gh_bin_dir" "$git_bin_dir"
  write_feedback_r3_b1_gh "$gh_bin_dir/gh"
  write_feedback_r3_review_git_wrapper "$git_bin_dir/git"
  real_git="$(command -v git)"

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r3-review-gh-cwd)"
  IFS='|' read -r origin repo provider <<<"$setup"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  outside="$TMP_DIR/feedback-r3-review-outside"; pwd_log="$TMP_DIR/feedback-r3-review-gh-pwd.log"; mkdir -p "$outside"
  rc="$(cd "$outside" && SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    SHIP_FLOW_R3_GH_PWD_LOG="$pwd_log" SHIP_FLOW_R3_EXPECT_GH_PWD="$repo" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-review-gh-cwd.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request --dry-run)"
  assert_exit 'R3 gh lookup binds itself to repo_root from an unrelated CWD' 0 "$rc"
  assert_contains 'R3 repo-bound gh lookup reaches planned closeout' '^state=closeout_pr_planned$' "$TMP_DIR/feedback-r3-review-gh-cwd.out"
  assert_contains 'R3 fake gh observes repo_root for repository discovery' "^pwd=${repo} args=repo view " "$pwd_log"
  assert_feedback_r3_b1_objects_present 'R3 repo-bound gh lookup acquires provider source objects' "$repo" "$source_commits"
  after_head="$(git -C "$repo" rev-parse HEAD)"; remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$after_head" = "$before_head" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then record_pass 'R3 repo-bound gh lookup preserves HEAD and checkout'; else record_fail 'R3 repo-bound gh lookup preserves HEAD and checkout'; fi
  if [ "$remote_after" = "$remote_before" ]; then record_pass 'R3 repo-bound gh lookup performs no remote write'; else record_fail 'R3 repo-bound gh lookup performs no remote write'; fi

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r3-review-collision)"
  IFS='|' read -r origin repo provider <<<"$setup"
  before_head="$(git -C "$repo" rev-parse HEAD)"; collision_oid="$before_head"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"; marker="$TMP_DIR/feedback-r3-review-collision.marker"
  rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    SHIP_FLOW_R3_GIT_MODE=collision SHIP_FLOW_R3_REAL_GIT="$real_git" SHIP_FLOW_R3_TARGET_REPO="$repo" \
    SHIP_FLOW_R3_COLLISION_OID="$collision_oid" SHIP_FLOW_R3_GIT_MARKER="$marker" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-review-collision.out" "$git_bin_dir:$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request --dry-run)"
  assert_exit 'R3 atomic target-ref collision fails closed' 2 "$rc"
  assert_contains 'R3 atomic target-ref collision reports canonical reason' '^reason=landing-patch-equivalence-failed$' "$TMP_DIR/feedback-r3-review-collision.out"
  collision_ref="$(if [ -f "$marker" ]; then sed -n '1p' "$marker"; fi)"
  if [ -n "$collision_ref" ]; then record_pass 'R3 collision wrapper reached atomic create'; else record_fail 'R3 collision wrapper reached atomic create'; fi
  if [ -n "$collision_ref" ] && [ "$(git -C "$repo" rev-parse --verify "$collision_ref" 2>/dev/null || true)" = "$collision_oid" ]; then record_pass 'R3 collision preserves the independently created ref value'; else record_fail 'R3 collision preserves the independently created ref value'; fi
  after_head="$(git -C "$repo" rev-parse HEAD)"; remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$after_head" = "$before_head" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then record_pass 'R3 collision preserves HEAD and checkout'; else record_fail 'R3 collision preserves HEAD and checkout'; fi
  if [ "$remote_after" = "$remote_before" ]; then record_pass 'R3 collision performs no remote write'; else record_fail 'R3 collision performs no remote write'; fi
  if [ ! -e "$repo/.git/shallow" ] && [ ! -e "$repo/.git/FETCH_HEAD" ]; then record_pass 'R3 collision leaves no shallow or FETCH_HEAD residue'; else record_fail 'R3 collision leaves no shallow or FETCH_HEAD residue'; fi

  while IFS='|' read -r signal expected; do
    label="$(printf '%s' "$signal" | tr '[:upper:]' '[:lower:]')"
    setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r3-review-signal-$label")"
    IFS='|' read -r origin repo provider <<<"$setup"
    before_head="$(git -C "$repo" rev-parse HEAD)"; preexisting_oid="$before_head"
    git -C "$repo" update-ref refs/ship-flow/closeout-source/preexisting "$preexisting_oid"
    remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"; marker="$TMP_DIR/feedback-r3-review-signal-$label.marker"
    rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
      SHIP_FLOW_R3_GIT_MODE=signal SHIP_FLOW_R3_REAL_GIT="$real_git" SHIP_FLOW_R3_SIGNAL="$signal" \
      SHIP_FLOW_R3_GIT_MARKER="$marker" \
      run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-review-signal-$label.out" "$git_bin_dir:$gh_bin_dir:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request --dry-run)"
    assert_exit "R3 real $signal exits with signal contract" "$expected" "$rc"
    if [ -s "$marker" ]; then record_pass "R3 real $signal fires immediately after acquisition ref creation"; else record_fail "R3 real $signal fires immediately after acquisition ref creation"; fi
    leftovers="$(git -C "$repo" for-each-ref --format='%(refname)' refs/ship-flow/closeout-source | grep -v '^refs/ship-flow/closeout-source/preexisting$' || true)"
    if [ -z "$leftovers" ]; then record_pass "R3 real $signal removes the process-scoped acquisition ref"; else record_fail "R3 real $signal removes the process-scoped acquisition ref"; fi
    if [ "$(git -C "$repo" rev-parse --verify refs/ship-flow/closeout-source/preexisting)" = "$preexisting_oid" ]; then record_pass "R3 real $signal preserves the unrelated ref"; else record_fail "R3 real $signal preserves the unrelated ref"; fi
    after_head="$(git -C "$repo" rev-parse HEAD)"; remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
    if [ "$after_head" = "$before_head" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then record_pass "R3 real $signal preserves HEAD and checkout"; else record_fail "R3 real $signal preserves HEAD and checkout"; fi
    if [ "$remote_after" = "$remote_before" ]; then record_pass "R3 real $signal performs no remote write"; else record_fail "R3 real $signal performs no remote write"; fi
    if [ ! -e "$repo/.git/shallow" ] && [ ! -e "$repo/.git/FETCH_HEAD" ]; then record_pass "R3 real $signal leaves no shallow or FETCH_HEAD residue"; else record_fail "R3 real $signal leaves no shallow or FETCH_HEAD residue"; fi
  done <<'EOF'
HUP|129
INT|130
QUIT|131
TERM|143
EOF

  while IFS='|' read -r label raw; do
    setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r3-review-remote-$label")"
    IFS='|' read -r origin repo provider <<<"$setup"
    git -C "$repo" config remote.origin.url "$raw"
    git -C "$repo" config "url.file://${origin}.insteadOf" "$raw"
    source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
    before_head="$(git -C "$repo" rev-parse HEAD)"; remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
    rc="$(SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
      run_helper_with_path "$repo" "$TMP_DIR/feedback-r3-review-remote-$label.out" "$gh_bin_dir:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request --dry-run)"
    assert_exit "R3 mixed-case $label GitHub remote acquires" 0 "$rc"
    assert_contains "R3 mixed-case $label remote reaches bounded planned state" '^state=closeout_pr_planned$' "$TMP_DIR/feedback-r3-review-remote-$label.out"
    assert_feedback_r3_b1_objects_present "R3 mixed-case $label remote materializes provider objects" "$repo" "$source_commits"
    after_head="$(git -C "$repo" rev-parse HEAD)"; remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
    if [ "$after_head" = "$before_head" ] && [ "$(git -C "$repo" symbolic-ref --short HEAD)" = main ]; then record_pass "R3 mixed-case $label remote preserves HEAD and checkout"; else record_fail "R3 mixed-case $label remote preserves HEAD and checkout"; fi
    if [ "$remote_after" = "$remote_before" ]; then record_pass "R3 mixed-case $label remote performs no remote write"; else record_fail "R3 mixed-case $label remote performs no remote write"; fi
  done <<'EOF'
https|HTTPS://GitHub.com/Example/Repo.git
scp|git@GitHub.com:Example/Repo.git
ssh|SSH://git@GitHub.com/Example/Repo.git
EOF
}

run_feedback_r4_foreign_cwd_case() {
  local gh_bin_dir="$TMP_DIR/feedback-r4-gh-bin" gh_log="$TMP_DIR/feedback-r4-gh.log"
  local repo_log="$TMP_DIR/feedback-r4-gh-repo.log" outside="$TMP_DIR/feedback-r4-outside"
  local setup origin repo provider source_commits before_head remote_before remote_after rc
  local receipt deterministic_head terminal_oid registry label expected_reason negative_provider bad_oid
  mkdir -p "$gh_bin_dir" "$outside"
  write_feedback_r3_b1_gh "$gh_bin_dir/gh"

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r4-foreign-optional)"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  rc="$(cd "$outside" && SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    SHIP_FLOW_R3_GH_REPO_LOG="$repo_log" SHIP_FLOW_R3_CLOSEOUT_ORIGIN="$origin" SHIP_FLOW_R3_CLOSEOUT_HEAD="$deterministic_head" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r4-optional.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    r4-optional: /' "$TMP_DIR/feedback-r4-optional.out"; fi
  assert_exit 'R4 foreign-CWD non-dry-run optional construction succeeds' 0 "$rc"
  assert_contains 'R4 foreign-CWD optional construction awaits merge' '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/feedback-r4-optional.out"
  assert_feedback_r3_b1_objects_present 'R4 foreign-CWD optional construction retains exact implementation source objects' "$repo" "$source_commits"
  assert_contains 'R4 implementation PR view binds provider repository' '^repo=example/repo args=pr view 131 --repo example/repo ' "$repo_log"
  assert_contains 'R4 optional PR list binds provider repository' '^repo=example/repo args=pr list ' "$repo_log"
  assert_contains 'R4 optional PR create binds provider repository' '^repo=example/repo args=pr create ' "$repo_log"
  assert_contains 'R4 optional PR ready binds provider repository' '^repo=example/repo args=pr ready 141 ' "$repo_log"

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r4-foreign-receipt)"
  IFS='|' read -r origin repo provider <<<"$setup"
  git -C "$repo" fetch -q --no-tags origin refs/pull/131/head
  deterministic_head="ship-closeout/$(python3 - <<'PY'
import hashlib
print(hashlib.sha256(b"\0".join((b"v1",b"github",b"example/repo",b"docs/ship-flow",b"merged-fixture-entity",b"131"))).hexdigest())
PY
)"
  printf '%s\n' 'closeout_pr_number=141' 'closeout_pr_state=OPEN' \
    "closeout_pr_head=$deterministic_head" >>"$provider"
  registry="$TMP_DIR/feedback-r4-foreign-receipt.registry"
  rc="$(SHIP_FLOW_CLOSEOUT_FIXTURE_REGISTRY="$registry" \
    run_helper "$repo" "$TMP_DIR/feedback-r4-receipt-seed.out" \
      --entity merged-fixture-entity --pr-provider fixture --pr-fixture "$provider" --closeout-mode pull-request)"
  assert_exit 'R4 receipt fixture seeds an exact OPEN replay candidate' 0 "$rc"
  receipt="$(find "$repo/docs/ship-flow/_closeouts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
  git -C "$repo" checkout -q "$deterministic_head"
  python3 - "$receipt" "file://${origin}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -qm 'fixture: bind R4 terminal publication endpoint'
  git -C "$repo" checkout -q main
  python3 - "$receipt" "file://${origin}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -q --amend --no-edit
  terminal_oid="$(git -C "$repo" rev-parse "$deterministic_head")"
  printf '%s\n' "closeout_pr_remote_oid=$terminal_oid" 'closeout_pr_is_draft=false' >>"$provider"
  rm -f "$repo/.git/FETCH_HEAD"
  git -C "$repo" reflog expire --expire=now --all
  git -C "$repo" gc -q --prune=now
  before_head="$(git -C "$repo" rev-parse HEAD)"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  rc="$(cd "$outside" && SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    SHIP_FLOW_R3_GH_REPO_LOG="$repo_log" SHIP_FLOW_R3_CLOSEOUT_ORIGIN="$origin" SHIP_FLOW_R3_CLOSEOUT_HEAD="$deterministic_head" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r4-open.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R4 foreign-CWD receipt-only OPEN replay succeeds' 0 "$rc"
  assert_contains 'R4 foreign-CWD receipt-only OPEN replay awaits merge' '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/feedback-r4-open.out"
  assert_contains 'R4 receipt-only OPEN view binds provider repository' '^repo=example/repo args=pr view 141 ' "$repo_log"
  remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$remote_before" = "$remote_after" ]; then
    record_pass 'R4 foreign-CWD receipt-only OPEN replay is mutation-free'
  else
    record_fail 'R4 foreign-CWD receipt-only OPEN replay is mutation-free'
  fi

  python3 - "$receipt" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"].pop("publication_endpoint",None)
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -q --amend --no-edit
  if ! git -C "$repo" merge -q --no-ff "$deterministic_head" -m 'fixture: land R4 optional terminal head' >/dev/null 2>&1; then
    [ "$(git -C "$repo" diff --name-only --diff-filter=U)" = "${receipt#"$repo/"}" ] || exit 1
    git -C "$repo" checkout -q --theirs -- "${receipt#"$repo/"}"
    git -C "$repo" add -- "${receipt#"$repo/"}"
    git -C "$repo" commit -qm 'fixture: land R4 optional terminal head'
  fi
  perl -0pi -e 's/closeout_pr_state=OPEN/closeout_pr_state=MERGED/' "$provider"
  before_head="$(git -C "$repo" rev-parse HEAD)"
  remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  rc="$(cd "$outside" && SHIP_FLOW_R3_PROVIDER_FILE="$provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
    SHIP_FLOW_R3_GH_REPO_LOG="$repo_log" SHIP_FLOW_R3_CLOSEOUT_ORIGIN="$origin" SHIP_FLOW_R3_CLOSEOUT_HEAD="$deterministic_head" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r4-merged.out" "$gh_bin_dir:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R4 foreign-CWD receipt-only MERGED replay succeeds' 0 "$rc"
  assert_contains 'R4 foreign-CWD receipt-only MERGED replay is terminal no-op' '^reason=closeout-pr-terminal-noop$' "$TMP_DIR/feedback-r4-merged.out"
  assert_contains 'R4 receipt-only MERGED view binds provider repository' '^repo=example/repo args=pr view 141 ' "$repo_log"
  remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$remote_before" = "$remote_after" ]; then
    record_pass 'R4 foreign-CWD receipt-only MERGED replay is mutation-free'
  else
    record_fail 'R4 foreign-CWD receipt-only MERGED replay is mutation-free'
  fi

  while IFS='|' read -r label expected_reason; do
    setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r4-negative-$label")"
    IFS='|' read -r origin repo negative_provider <<<"$setup"
    case "$label" in
      repository) perl -0pi -e 's#repository=example/repo#repository=wrong/repository#' "$negative_provider" ;;
      pr) perl -0pi -e 's/number=131\n/number=132\n/' "$negative_provider" ;;
      head)
        bad_oid="$(git -C "$repo" rev-parse HEAD)"
        perl -0pi -e "s/source_commits=[^\n]*/source_commits=$bad_oid,$bad_oid/" "$negative_provider"
        ;;
      count) perl -0pi -e 's/pr_commit_count=2\n/pr_commit_count=3\n/' "$negative_provider" ;;
    esac
    before_head="$(git -C "$repo" rev-parse HEAD)"
    remote_before="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
    rc="$(cd "$outside" && SHIP_FLOW_R3_PROVIDER_FILE="$negative_provider" SHIP_FLOW_R3_GH_LOG="$gh_log" \
      SHIP_FLOW_R3_GH_REPO_LOG="$repo_log" \
      run_helper_with_path "$repo" "$TMP_DIR/feedback-r4-negative-$label.out" "$gh_bin_dir:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    assert_exit "R4 wrong provider $label fails closed" 2 "$rc"
    assert_contains "R4 wrong provider $label reports stable reason" "^reason=${expected_reason}$" "$TMP_DIR/feedback-r4-negative-$label.out"
    remote_after="$(git -C "$origin" for-each-ref --format='%(refname) %(objectname)' | sort)"
    if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$remote_before" = "$remote_after" ]; then
      record_pass "R4 wrong provider $label preserves local and remote refs"
    else
      record_fail "R4 wrong provider $label preserves local and remote refs"
    fi
  done <<'EOF'
repository|landing-patch-equivalence-failed|
pr|pr-number-mismatch|
head|landing-patch-equivalence-failed|
count|landing-patch-equivalence-failed|
EOF
}

write_feedback_r5_b1_gh() {
  local bin="$1"
  cat >"$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${SHIP_FLOW_R5_PROVIDER_FILE:?missing implementation provider metadata}"
: "${SHIP_FLOW_R5_REGISTRY:?missing closeout PR registry}"
: "${SHIP_FLOW_R5_LOG:?missing provider call log}"
: "${SHIP_FLOW_R5_ORIGIN:?missing local bare origin}"

printf 'call %s\n' "$*" >>"$SHIP_FLOW_R5_LOG"
[ -z "${SHIP_FLOW_R7_TIMELINE:-}" ] || printf 'provider %s\n' "$*" >>"$SHIP_FLOW_R7_TIMELINE"

provider_field() {
  awk -F= -v key="$1" '$1==key{sub(/^[^=]*=/, ""); print; exit}' "$SHIP_FLOW_R5_PROVIDER_FILE"
}

registry_field() {
  [ -f "$SHIP_FLOW_R5_REGISTRY" ] || return 0
  awk -F= -v key="$1" '$1==key{sub(/^[^=]*=/, ""); print; exit}' "$SHIP_FLOW_R5_REGISTRY"
}

set_registry_field() {
  local key="$1" value="$2" tmp="${SHIP_FLOW_R5_REGISTRY}.tmp"
  mkdir -p "$(dirname "$SHIP_FLOW_R5_REGISTRY")"
  if [ -f "$SHIP_FLOW_R5_REGISTRY" ]; then
    awk -F= -v key="$key" '$1!=key{print}' "$SHIP_FLOW_R5_REGISTRY" >"$tmp"
  else
    : >"$tmp"
  fi
  printf '%s=%s\n' "$key" "$value" >>"$tmp"
  mv "$tmp" "$SHIP_FLOW_R5_REGISTRY"
}

require_repo_binding() {
  local seen="" previous="" arg
  for arg in "$@"; do
    if [ "$previous" = --repo ]; then seen="$arg"; break; fi
    previous="$arg"
  done
  [ "$seen" = "$(provider_field repository)" ] || exit 64
}

fail_once() {
  local seam="$1"
  [ "${SHIP_FLOW_R5_FAILURE:-}" = "$seam" ] || return 0
  [ -n "${SHIP_FLOW_R5_FAILURE_MARKER:-}" ] || exit 65
  if [ ! -e "$SHIP_FLOW_R5_FAILURE_MARKER" ]; then
    : >"$SHIP_FLOW_R5_FAILURE_MARKER"
    printf 'failure %s\n' "$seam" >>"$SHIP_FLOW_R5_LOG"
    return 71
  fi
}

closeout_remote_oid() {
  local head
  head="$(registry_field head)"
  [ -n "$head" ] || return 0
  git -C "$SHIP_FLOW_R5_ORIGIN" rev-parse --verify "refs/heads/$head" 2>/dev/null || true
}

emit_closeout_record() {
  local number head state
  number="$(registry_field number)"; head="$(registry_field head)"
  [ -n "$number" ] || return 0
  state="$(registry_field state)"; [ -n "$state" ] || state=OPEN
  printf '%s|%s|%s|%s|%s\n' \
    "$number" "$state" "$head" "$(closeout_remote_oid)" "$(registry_field is_draft)"
}

if [ "${1:-}" = repo ] && [ "${2:-}" = view ]; then
  provider_field repository
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = view ] && [ "${3:-}" = 131 ]; then
  require_repo_binding "$@"
  printf '%s\n' \
    'provider=gh' \
    "number=$(provider_field number)" \
    "state=$(provider_field state)" \
    "merged_at=$(provider_field merged_at)" \
    "head_ref=$(provider_field head_ref)" \
    "base_ref=$(provider_field base_ref)" \
    "url=$(provider_field url)" \
    "landing_anchor=$(provider_field landing_anchor)" \
    "source_commits=$(provider_field source_commits)" \
    "pr_commit_count=$(provider_field pr_commit_count)"
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = view ] && [ "${3:-}" = 141 ]; then
  require_repo_binding "$@"
  if [ "${SHIP_FLOW_R10_REFRESH_FAILURE:-}" = after-terminal-once ] && \
     grep -q '^terminal-push ' "${SHIP_FLOW_R6_GIT_LOG:?missing git log for refresh seam}" && \
     [ ! -e "${SHIP_FLOW_R10_REFRESH_FAILURE_MARKER:?missing refresh failure marker}" ]; then
    : >"$SHIP_FLOW_R10_REFRESH_FAILURE_MARKER"
    printf 'failure refresh-after-terminal\n' >>"$SHIP_FLOW_R5_LOG"
    exit 71
  fi
  emit_closeout_record
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = list ]; then
  require_repo_binding "$@"
  if [ -n "${SHIP_FLOW_R6_SIGNAL:-}" ]; then
    [ -n "${SHIP_FLOW_R6_SIGNAL_MARKER:-}" ] || exit 65
    printf '%s\n' "$SHIP_FLOW_R6_SIGNAL" >"$SHIP_FLOW_R6_SIGNAL_MARKER"
    kill -s "$SHIP_FLOW_R6_SIGNAL" "$PPID"
    exit 0
  fi
  fail_once list-before || exit $?
  emit_closeout_record
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = create ]; then
  local_head=""; previous=""
  require_repo_binding "$@"
  for arg in "$@"; do
    if [ "$previous" = --head ]; then local_head="$arg"; break; fi
    previous="$arg"
  done
  fail_once create-before || exit $?
  set_registry_field number 141
  set_registry_field state OPEN
  set_registry_field head "$local_head"
  set_registry_field is_draft true
  printf 'effect create 141 %s\n' "$local_head" >>"$SHIP_FLOW_R5_LOG"
  fail_once create-after || exit $?
  printf '%s\n' 'https://github.com/example/repo/pull/141'
  exit 0
fi

if [ "${1:-}" = pr ] && [ "${2:-}" = ready ] && [ "${3:-}" = 141 ]; then
  require_repo_binding "$@"
  fail_once ready-before || exit $?
  set_registry_field is_draft false
  printf 'effect ready 141 %s\n' "$(closeout_remote_oid)" >>"$SHIP_FLOW_R5_LOG"
  fail_once ready-after || exit $?
  exit 0
fi

printf 'unsupported fake gh invocation: %s\n' "$*" >&2
exit 2
EOF
  chmod +x "$bin"
}

feedback_r5_deterministic_head() {
  printf 'ship-closeout/%s\n' "$(python3 - <<'PY'
import hashlib
print(hashlib.sha256(b"\0".join((b"v1",b"github",b"example/repo",b"docs/ship-flow",b"merged-fixture-entity",b"131"))).hexdigest())
PY
)"
}

write_feedback_r6_git_wrapper() {
  local bin="$1"
  cat >"$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${SHIP_FLOW_R6_REAL_GIT:?missing real git path}"
: "${SHIP_FLOW_R6_GIT_LOG:?missing git invocation log}"

is_push=no
is_terminal=no
is_ls_remote=no
is_fetch=no
is_update_ref=no
last_arg=""
for arg in "$@"; do
  [ "$arg" != push ] || is_push=yes
  [ "$arg" != send-pack ] || is_push=yes
  [ "$arg" != ls-remote ] || is_ls_remote=yes
  [ "$arg" != fetch ] || is_fetch=yes
  [ "$arg" != update-ref ] || is_update_ref=yes
  case "$arg" in
    --force-with-lease=refs/heads/*:) is_terminal=no ;;
    --force-with-lease=*) is_terminal=yes ;;
  esac
  last_arg="$arg"
done
[ "$is_fetch" != yes ] || printf 'source-fetch <%s>\n' "$*" >>"$SHIP_FLOW_R6_GIT_LOG"
[ "$is_update_ref" != yes ] || printf 'source-update-ref <%s>\n' "$*" >>"$SHIP_FLOW_R6_GIT_LOG"
if [ "$is_ls_remote" = yes ]; then
  printf 'remote-inspection <%s>\n' "$last_arg" >>"$SHIP_FLOW_R6_GIT_LOG"
  case "${SHIP_FLOW_R6_LS_REMOTE_MODE:-}" in
    failure) exit 71 ;;
    malformed) printf 'not-an-object-id\t%s\n' "$last_arg"; exit 0 ;;
  esac
fi
  if [ "$is_push" = yes ]; then
  if [ "$is_terminal" = yes ]; then kind=terminal-push; else kind=seed-push; fi
  printf '%s' "$kind" >>"$SHIP_FLOW_R6_GIT_LOG"
  printf ' <%s>' "$@" >>"$SHIP_FLOW_R6_GIT_LOG"
  printf '\n' >>"$SHIP_FLOW_R6_GIT_LOG"
  [ -z "${SHIP_FLOW_R7_TIMELINE:-}" ] || printf 'git %s\n' "$kind" >>"$SHIP_FLOW_R7_TIMELINE"
  if [ "$kind" = seed-push ] && [ "${SHIP_FLOW_R7_RACE_MODE:-}" = create-competitor ] && \
     [ ! -e "${SHIP_FLOW_R7_RACE_MARKER:?missing race marker}" ]; then
    repo=""; previous=""
    for arg in "$@"; do
      if [ "$previous" = -C ]; then repo="$arg"; break; fi
      previous="$arg"
    done
    : "${repo:?seed push omitted repository binding}"
    : "${SHIP_FLOW_R7_ORIGIN:?missing race origin}"
    : "${SHIP_FLOW_R7_REMOTE_REF:?missing race remote ref}"
    : "${SHIP_FLOW_R7_COMPETITOR_OID:?missing competing OID}"
    : "${SHIP_FLOW_R7_LOCAL_HEAD:?missing deterministic local head}"
    : "${SHIP_FLOW_R7_SNAPSHOT:?missing pre-push snapshot}"
    : "${SHIP_FLOW_R7_TIMELINE:?missing race timeline}"
    receipt="$(find "$repo/docs/ship-flow/_closeouts" -type f -name '*.json' -print -quit)"
    printf 'head=%s\ntree=%s\nreceipt_hash=%s\nlocal_seed=%s\n' \
      "$("$SHIP_FLOW_R6_REAL_GIT" -C "$repo" rev-parse HEAD)" \
      "$("$SHIP_FLOW_R6_REAL_GIT" -C "$repo" rev-parse 'HEAD^{tree}')" \
      "$("$SHIP_FLOW_R6_REAL_GIT" hash-object "$receipt")" \
      "$("$SHIP_FLOW_R6_REAL_GIT" -C "$repo" rev-parse "refs/heads/$SHIP_FLOW_R7_LOCAL_HEAD")" \
      >"$SHIP_FLOW_R7_SNAPSHOT"
    "$SHIP_FLOW_R6_REAL_GIT" -C "$SHIP_FLOW_R7_ORIGIN" update-ref \
      "$SHIP_FLOW_R7_REMOTE_REF" "$SHIP_FLOW_R7_COMPETITOR_OID"
    : >"$SHIP_FLOW_R7_RACE_MARKER"
    printf 'race-create %s %s\n' "$SHIP_FLOW_R7_REMOTE_REF" "$SHIP_FLOW_R7_COMPETITOR_OID" \
      >>"$SHIP_FLOW_R7_TIMELINE"
  fi
  if [ "$kind" = terminal-push ] && [ "${SHIP_FLOW_R10_TERMINAL_RACE_MODE:-}" = create-competitor ] && \
     [ ! -e "${SHIP_FLOW_R10_TERMINAL_RACE_MARKER:?missing terminal race marker}" ]; then
    : "${SHIP_FLOW_R10_TERMINAL_RACE_ORIGIN:?missing terminal race origin}"
    : "${SHIP_FLOW_R10_TERMINAL_RACE_REF:?missing terminal race ref}"
    : "${SHIP_FLOW_R10_TERMINAL_RACE_OID:?missing terminal race oid}"
    "$SHIP_FLOW_R6_REAL_GIT" -C "$SHIP_FLOW_R10_TERMINAL_RACE_ORIGIN" update-ref \
      "$SHIP_FLOW_R10_TERMINAL_RACE_REF" "$SHIP_FLOW_R10_TERMINAL_RACE_OID"
    : >"$SHIP_FLOW_R10_TERMINAL_RACE_MARKER"
    [ -z "${SHIP_FLOW_R7_TIMELINE:-}" ] || printf 'terminal-race-create %s %s\n' \
      "$SHIP_FLOW_R10_TERMINAL_RACE_REF" "$SHIP_FLOW_R10_TERMINAL_RACE_OID" >>"$SHIP_FLOW_R7_TIMELINE"
  fi
fi

if [ -n "${SHIP_FLOW_R10_TRANSPORT_LITERAL:-}" ]; then
  get_url=no
  for arg in "$@"; do [ "$arg" != --get-url ] || get_url=yes; done
  if [ "$get_url" != yes ]; then
    mapped=()
    for arg in "$@"; do
      if [ "$arg" = "$SHIP_FLOW_R10_TRANSPORT_LITERAL" ]; then
        mapped+=("file://${SHIP_FLOW_R10_TRANSPORT_ORIGIN:?missing transport origin}")
      else
        mapped+=("$arg")
      fi
    done
    set -- "${mapped[@]}"
  fi
fi

exec "$SHIP_FLOW_R6_REAL_GIT" "$@"
EOF
  chmod +x "$bin"
}

write_feedback_r6_mktemp_wrapper() {
  local bin="$1"
  cat >"$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

: "${SHIP_FLOW_R6_REAL_MKTEMP:?missing real mktemp path}"
: "${SHIP_FLOW_R6_TEMP_ROOT:?missing scoped temp root}"
export TMPDIR="$SHIP_FLOW_R6_TEMP_ROOT"
if [ "$#" = 0 ]; then
  exec "$SHIP_FLOW_R6_REAL_MKTEMP" "$SHIP_FLOW_R6_TEMP_ROOT/ship-flow-r6-file.XXXXXX"
fi
if [ "$#" = 1 ] && [ "$1" = -d ]; then
  exec "$SHIP_FLOW_R6_REAL_MKTEMP" -d "$SHIP_FLOW_R6_TEMP_ROOT/ship-flow-r6-dir.XXXXXX"
fi
if [ "$#" = 2 ] && [ "$1" = -d ]; then
  case "$2" in
    */ship-flow-closeout-source.XXXXXX)
      exec "$SHIP_FLOW_R6_REAL_MKTEMP" -d "$SHIP_FLOW_R6_TEMP_ROOT/ship-flow-closeout-source.XXXXXX"
      ;;
  esac
fi
exec "$SHIP_FLOW_R6_REAL_MKTEMP" "$@"
EOF
  chmod +x "$bin"
}

prepare_feedback_r6_temp_root() {
  local root="$1"
  mkdir -p "$root"
  printf '%s\n' caller-owned >"$root/caller-owned.keep"
}

assert_feedback_r6_temp_ownership() {
  local desc="$1" root="$2" residue
  if [ -d "$root" ] && [ "$(sed -n '1p' "$root/caller-owned.keep" 2>/dev/null || true)" = caller-owned ]; then
    record_pass "$desc preserves caller-owned temp parent and sentinel"
  else
    record_fail "$desc preserves caller-owned temp parent and sentinel"
  fi
  residue="$(find "$root" -mindepth 1 ! -path "$root/caller-owned.keep" -print 2>/dev/null || true)"
  if [ -z "$residue" ]; then
    record_pass "$desc removes every internally-created temp artifact"
  else
    record_fail "$desc removes every internally-created temp artifact"
  fi
}

feedback_r5_receipt_path() {
  find "$1/docs/ship-flow/_closeouts" -type f -name '*.json' -print -quit 2>/dev/null || true
}

assert_feedback_r5_receipt() {
  local desc="$1" repo="$2" expected_phase="$3" expected_pr="$4"
  local receipt relative committed="$TMP_DIR/feedback-r5-committed-receipt.json"
  receipt="$(feedback_r5_receipt_path "$repo")"
  if [ ! -f "$receipt" ]; then record_fail "$desc (receipt missing)"; return; fi
  if python3 - "$receipt" "$expected_phase" "$expected_pr" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); t=r["transaction"]
expected=None if sys.argv[3]=="null" else int(sys.argv[3])
raise SystemExit(0 if t["phase"]==sys.argv[2] and t["closeout_pr"]==expected else 1)
PY
  then record_pass "$desc has exact phase and PR binding"; else record_fail "$desc has exact phase and PR binding"; fi
  relative="${receipt#"$repo/"}"
  git -C "$repo" show "HEAD:$relative" >"$committed" 2>/dev/null || : >"$committed"
  if cmp -s "$receipt" "$committed" && [ -z "$(git -C "$repo" status --porcelain --untracked-files=all)" ]; then
    record_pass "$desc bytes equal committed HEAD and worktree is clean"
  else
    record_fail "$desc bytes equal committed HEAD and worktree is clean"
  fi
}

assert_feedback_r5_ref_shape() {
  local desc="$1" repo="$2" origin="$3" deterministic_head="$4" expected="$5"
  local local_count remote_count local_oid="" remote_oid=""
  local_count="$(git -C "$repo" for-each-ref --format='%(refname)' "refs/heads/$deterministic_head" | awk 'NF{n++} END{print n+0}')"
  remote_count="$(git -C "$origin" for-each-ref --format='%(refname)' "refs/heads/$deterministic_head" | awk 'NF{n++} END{print n+0}')"
  if [ "$expected" = absent ]; then
    if [ "$local_count" = 0 ] && [ "$remote_count" = 0 ]; then record_pass "$desc has no deterministic local or remote ref"; else record_fail "$desc has no deterministic local or remote ref"; fi
    return
  fi
  local_oid="$(git -C "$repo" rev-parse --verify "refs/heads/$deterministic_head" 2>/dev/null || true)"
  remote_oid="$(git -C "$origin" rev-parse --verify "refs/heads/$deterministic_head" 2>/dev/null || true)"
  if [ "$local_count" = 1 ] && [ "$remote_count" = 1 ] && [ "$local_oid" = "$remote_oid" ] && [ -n "$local_oid" ]; then
    record_pass "$desc binds one identical deterministic local and remote ref"
  else
    record_fail "$desc binds one identical deterministic local and remote ref"
  fi
}

assert_feedback_r5_count() {
  local desc="$1" pattern="$2" file="$3" expected="$4" actual
  actual="$(grep -cE "$pattern" "$file" 2>/dev/null || true)"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"; else record_fail "$desc (expected $expected, got $actual)"; fi
}

feedback_r5_expected_receipt_tree() {
  local repo="$1" base_head="$2" checkpoint_head="$3" receipt="$4" relative blob index expected
  relative="${receipt#"$repo/"}"
  blob="$(git -C "$repo" rev-parse "${checkpoint_head}:${relative}")"
  index="$(mktemp)"; rm -f "$index"
  GIT_INDEX_FILE="$index" git -C "$repo" read-tree "$base_head"
  GIT_INDEX_FILE="$index" git -C "$repo" update-index --add --cacheinfo "100644,$blob,$relative"
  expected="$(GIT_INDEX_FILE="$index" git -C "$repo" write-tree)"
  rm -f "$index"
  printf '%s\n' "$expected"
}

run_feedback_r5_failure_scenario() {
  local seam="$1" expected_phase="$2" expected_first_ref="$3"
  local expected_first_main_commits="$4" expected_rerun_main_commits="$5"
  local expected_first_create_effects="$6" expected_first_ready_effects="$7"
  local expected_final_list_calls="$8" expected_final_create_calls="$9" expected_final_ready_calls="${10}"
  local expected_final_create_effects="${11}" expected_final_ready_effects="${12}"
  local setup origin repo provider gh_bin git_bin registry log marker git_log real_git real_mktemp deterministic_head receipt expected_failure_state
  local first_temp_root rerun_temp_root expected_first_seed_pushes expected_first_terminal_pushes
  local base_head first_head first_tree expected_first_tree first_receipt_hash first_ref_oid="" rc
  local rerun_head rerun_tree expected_rerun_tree rerun_receipt_hash bound_push_url publication_refspec

  setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r5-$seam")"
  IFS='|' read -r origin repo provider <<<"$setup"
  gh_bin="$TMP_DIR/feedback-r5-$seam-gh-bin"; git_bin="$TMP_DIR/feedback-r5-$seam-git-bin"
  registry="$TMP_DIR/feedback-r5-$seam.registry"
  log="$TMP_DIR/feedback-r5-$seam.log"; marker="$TMP_DIR/feedback-r5-$seam.marker"
  git_log="$TMP_DIR/feedback-r5-$seam-git.log"; deterministic_head="$(feedback_r5_deterministic_head)"
  bound_push_url="$(git -C "$repo" remote get-url --push --all origin)"
  publication_refspec="<${deterministic_head}:refs/heads/${deterministic_head}>"
  first_temp_root="$TMP_DIR/feedback-r5-$seam-first-tmp"; rerun_temp_root="$TMP_DIR/feedback-r5-$seam-rerun-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$log"; : >"$git_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"
  write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"
  prepare_feedback_r6_temp_root "$first_temp_root"
  prepare_feedback_r6_temp_root "$rerun_temp_root"
  real_git="$(command -v git)"
  real_mktemp="$(command -v mktemp)"
  base_head="$(git -C "$repo" rev-parse HEAD)"
  if [ "$expected_phase" = prepared ]; then
    expected_failure_state=closeout_pr_prepared; expected_first_terminal_pushes=0
  else
    expected_failure_state=closeout_pr_awaiting_merge; expected_first_terminal_pushes=1
  fi
  if [ "$expected_first_ref" = absent ]; then expected_first_seed_pushes=0; else expected_first_seed_pushes=1; fi

  rc="$(TMPDIR="$first_temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R5_FAILURE="$seam" \
    SHIP_FLOW_R5_FAILURE_MARKER="$marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$first_temp_root" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r5-$seam-first.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  first_head="$(git -C "$repo" rev-parse HEAD)"; first_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  receipt="$(feedback_r5_receipt_path "$repo")"; first_receipt_hash="$(shasum -a 256 "$receipt" 2>/dev/null | awk '{print $1}')"
  expected_first_tree="$(feedback_r5_expected_receipt_tree "$repo" "$base_head" "$first_head" "$receipt")"
  [ "$expected_first_ref" = absent ] || first_ref_oid="$(git -C "$repo" rev-parse "refs/heads/$deterministic_head" 2>/dev/null || true)"

  assert_exit "R5 $seam first provider failure routes through stable retry" 1 "$rc"
  assert_contains "R5 $seam first failure reports PROMPT_CAPTAIN" '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/feedback-r5-$seam-first.out"
  assert_contains "R5 $seam first failure reports stable checkpoint reason" '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r5-$seam-first.out"
  assert_contains "R5 $seam first failure reports its safe checkpoint state" "^state=${expected_failure_state}$" "$TMP_DIR/feedback-r5-$seam-first.out"
  assert_feedback_r5_receipt "R5 $seam first checkpoint" "$repo" "$expected_phase" "$(if [ "$expected_phase" = prepared ]; then printf null; else printf 141; fi)"
  if [ "$(git -C "$repo" rev-list --count "$base_head..$first_head")" = "$expected_first_main_commits" ] && \
     [ "$first_tree" = "$expected_first_tree" ]; then
    record_pass "R5 $seam first failure preserves the exact documented main checkpoint"
  else
    record_fail "R5 $seam first failure preserves the exact documented main checkpoint"
  fi
  assert_feedback_r5_ref_shape "R5 $seam first failure" "$repo" "$origin" "$deterministic_head" "$expected_first_ref"
  assert_feedback_r5_count "R6 $seam first failure has exact seed push invocation count" '^seed-push ' "$git_log" "$expected_first_seed_pushes"
  assert_feedback_r5_count "R6 $seam first failure has exact terminal force-with-lease invocation count" '^terminal-push ' "$git_log" "$expected_first_terminal_pushes"
  assert_feedback_r5_count "R5 $seam first failure has exact create side-effect count" '^effect create ' "$log" "$expected_first_create_effects"
  assert_feedback_r5_count "R5 $seam first failure has exact ready side-effect count" '^effect ready ' "$log" "$expected_first_ready_effects"
  assert_feedback_r6_temp_ownership "R6 $seam first failure" "$first_temp_root"

  rc="$(TMPDIR="$rerun_temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R5_FAILURE="$seam" \
    SHIP_FLOW_R5_FAILURE_MARKER="$marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$rerun_temp_root" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r5-$seam-rerun.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  rerun_head="$(git -C "$repo" rev-parse HEAD)"; rerun_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  receipt="$(feedback_r5_receipt_path "$repo")"; rerun_receipt_hash="$(shasum -a 256 "$receipt" 2>/dev/null | awk '{print $1}')"
  expected_rerun_tree="$(feedback_r5_expected_receipt_tree "$repo" "$base_head" "$rerun_head" "$receipt")"

  assert_exit "R5 $seam rerun converges" 0 "$rc"
  assert_contains "R5 $seam rerun awaits the one closeout PR" '^verdict=PROCEED$' "$TMP_DIR/feedback-r5-$seam-rerun.out"
  assert_contains "R5 $seam rerun reports awaiting reason" '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/feedback-r5-$seam-rerun.out"
  assert_contains "R5 $seam rerun reports awaiting state" '^state=closeout_pr_awaiting_merge$' "$TMP_DIR/feedback-r5-$seam-rerun.out"
  assert_feedback_r5_receipt "R5 $seam rerun checkpoint" "$repo" awaiting_closeout_pr 141
  if [ "$(git -C "$repo" rev-list --count "$base_head..$rerun_head")" = "$expected_rerun_main_commits" ] && \
     [ "$rerun_tree" = "$expected_rerun_tree" ]; then
    record_pass "R5 $seam rerun has the exact bounded main history and tree"
  else
    record_fail "R5 $seam rerun has the exact bounded main history and tree"
  fi
  if [ "$expected_phase" != awaiting_closeout_pr ] || \
     { [ "$first_head" = "$rerun_head" ] && [ "$first_tree" = "$rerun_tree" ] && [ "$first_receipt_hash" = "$rerun_receipt_hash" ]; }; then
    record_pass "R5 $seam rerun does not duplicate an already durable checkpoint"
  else
    record_fail "R5 $seam rerun does not duplicate an already durable checkpoint"
  fi
  assert_feedback_r5_ref_shape "R5 $seam rerun" "$repo" "$origin" "$deterministic_head" present
  if [ "$expected_first_ref" = absent ] || [ -z "$first_ref_oid" ] || \
     [ "$first_ref_oid" = "$(git -C "$repo" rev-parse "refs/heads/$deterministic_head")" ] || \
     [ "$(git -C "$repo" rev-list --count "$first_ref_oid..refs/heads/$deterministic_head")" -gt 0 ]; then
    record_pass "R5 $seam rerun reuses or monotonically advances the deterministic head"
  else
    record_fail "R5 $seam rerun reuses or monotonically advances the deterministic head"
  fi
  assert_feedback_r5_count "R6 $seam rerun has one total seed push invocation" '^seed-push ' "$git_log" 1
  assert_feedback_r5_count "R6 $seam rerun has one total terminal force-with-lease invocation" '^terminal-push ' "$git_log" 1
  if awk -v destination="$bound_push_url" -v refspec="$publication_refspec" \
    '$1=="seed-push" && index($0,destination) && index($0,refspec){found=1} END{exit !found}' "$git_log"; then
    record_pass "R8 $seam seed publication binds the single authoritative destination and full ref"
  else
    record_fail "R8 $seam seed publication binds the single authoritative destination and full ref"
  fi
  if awk -v destination="$bound_push_url" -v refspec="$publication_refspec" \
    '$1=="terminal-push" && index($0,destination) && index($0,refspec){found=1} END{exit !found}' "$git_log"; then
    record_pass "R8 $seam terminal publication reuses the authoritative destination and OID lease ref"
  else
    record_fail "R8 $seam terminal publication reuses the authoritative destination and OID lease ref"
  fi
  assert_feedback_r5_count "R5 $seam rerun has exact list call count" '^call pr list ' "$log" "$expected_final_list_calls"
  assert_feedback_r5_count "R5 $seam rerun has exact create call count" '^call pr create ' "$log" "$expected_final_create_calls"
  assert_feedback_r5_count "R5 $seam rerun has exact ready call count" '^call pr ready ' "$log" "$expected_final_ready_calls"
  assert_feedback_r5_count "R5 $seam rerun creates one provider PR" '^effect create ' "$log" "$expected_final_create_effects"
  assert_feedback_r5_count "R5 $seam rerun performs one provider ready transition" '^effect ready ' "$log" "$expected_final_ready_effects"
  if [ "$(awk -F= '$1=="number"{print $2; exit}' "$registry")" = 141 ] && \
     [ "$(awk -F= '$1=="head"{print $2; exit}' "$registry")" = "$deterministic_head" ] && \
     [ "$(awk -F= '$1=="is_draft"{print $2; exit}' "$registry")" = false ]; then
    record_pass "R5 $seam rerun registry binds one exact ready PR"
  else
    record_fail "R5 $seam rerun registry binds one exact ready PR"
  fi
  assert_feedback_r6_temp_ownership "R6 $seam normal rerun" "$rerun_temp_root"
}

run_feedback_r5_b1_provider_retry_case() {
  # seam | first receipt | first ref | first/final main commits |
  # first create/ready effects | final list/create/ready calls | final create/ready effects
  run_feedback_r5_failure_scenario list-before prepared absent 1 2 0 0 2 1 1 1 1
  run_feedback_r5_failure_scenario create-before prepared present 1 2 0 0 2 2 1 1 1
  run_feedback_r5_failure_scenario create-after prepared present 1 2 1 0 2 1 1 1 1
  run_feedback_r5_failure_scenario ready-before awaiting_closeout_pr present 2 2 1 0 2 1 2 1 1
  run_feedback_r5_failure_scenario ready-after awaiting_closeout_pr present 2 2 1 1 1 1 1 1 1
  run_feedback_r6_seed_remote_case missing
  run_feedback_r6_seed_remote_case different
  run_feedback_r6_seed_remote_case ls-remote-failure
  run_feedback_r6_seed_remote_case ls-remote-malformed
  run_feedback_r6_bundle_cleanup_signal_case
}

run_feedback_r6_seed_remote_case() {
  local mode="$1" setup origin repo provider deterministic_head gh_bin git_bin registry provider_log marker git_log real_git real_mktemp
  local first_temp_root retry_temp_root first_head first_tree first_receipt_hash receipt seed_oid remote_oid rc
  setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r6-remote-$mode")"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"
  gh_bin="$TMP_DIR/feedback-r6-remote-$mode-gh-bin"; git_bin="$TMP_DIR/feedback-r6-remote-$mode-git-bin"
  registry="$TMP_DIR/feedback-r6-remote-$mode.registry"; provider_log="$TMP_DIR/feedback-r6-remote-$mode-provider.log"
  marker="$TMP_DIR/feedback-r6-remote-$mode.marker"; git_log="$TMP_DIR/feedback-r6-remote-$mode-git.log"
  first_temp_root="$TMP_DIR/feedback-r6-remote-$mode-first-tmp"
  retry_temp_root="$TMP_DIR/feedback-r6-remote-$mode-retry-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"
  write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"
  prepare_feedback_r6_temp_root "$first_temp_root"
  prepare_feedback_r6_temp_root "$retry_temp_root"
  real_git="$(command -v git)"
  real_mktemp="$(command -v mktemp)"

  rc="$(TMPDIR="$first_temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R5_FAILURE=create-before \
    SHIP_FLOW_R5_FAILURE_MARKER="$marker" SHIP_FLOW_R6_REAL_GIT="$real_git" SHIP_FLOW_R6_GIT_LOG="$git_log" \
    SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$first_temp_root" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r6-remote-$mode-first.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit "R6 $mode precondition stops after the first seed push" 1 "$rc"
  assert_feedback_r5_count "R6 $mode precondition invokes one seed push" '^seed-push ' "$git_log" 1
  assert_feedback_r5_count "R6 $mode precondition invokes no terminal push" '^terminal-push ' "$git_log" 0
  assert_feedback_r5_receipt "R6 $mode precondition" "$repo" prepared null
  assert_feedback_r6_temp_ownership "R6 $mode precondition" "$first_temp_root"
  first_head="$(git -C "$repo" rev-parse HEAD)"; first_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  receipt="$(feedback_r5_receipt_path "$repo")"
  first_receipt_hash="$(shasum -a 256 "$receipt" | awk '{print $1}')"
  seed_oid="$(git -C "$repo" rev-parse "refs/heads/$deterministic_head")"
  remote_oid="$(git -C "$origin" rev-parse "refs/heads/$deterministic_head")"
  if [ "$seed_oid" = "$remote_oid" ]; then
    record_pass "R6 $mode precondition binds the exact seed OID remotely"
  else
    record_fail "R6 $mode precondition binds the exact seed OID remotely"
  fi

  case "$mode" in
    missing)
      git -C "$origin" update-ref -d "refs/heads/$deterministic_head" "$seed_oid"
      ;;
    different)
      remote_oid="$(git -C "$origin" rev-parse refs/heads/main)"
      git -C "$origin" update-ref "refs/heads/$deterministic_head" "$remote_oid" "$seed_oid"
      ;;
    ls-remote-failure|ls-remote-malformed) ;;
  esac

  rc="$(TMPDIR="$retry_temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R5_FAILURE=create-before \
    SHIP_FLOW_R5_FAILURE_MARKER="$marker" SHIP_FLOW_R6_REAL_GIT="$real_git" SHIP_FLOW_R6_GIT_LOG="$git_log" \
    SHIP_FLOW_R6_LS_REMOTE_MODE="${mode#ls-remote-}" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$retry_temp_root" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r6-remote-$mode-retry.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$mode" = missing ]; then
    assert_exit 'R6 missing remote seed ref retry converges' 0 "$rc"
    assert_contains 'R6 missing remote seed ref retry awaits one PR' '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/feedback-r6-remote-$mode-retry.out"
    assert_feedback_r5_count 'R6 missing remote seed ref permits exactly one retry seed push' '^seed-push ' "$git_log" 2
    assert_feedback_r5_count 'R6 missing remote seed ref retains one terminal force-with-lease push' '^terminal-push ' "$git_log" 1
    assert_feedback_r5_receipt 'R6 missing remote seed ref retry' "$repo" awaiting_closeout_pr 141
    assert_feedback_r5_ref_shape 'R6 missing remote seed ref retry' "$repo" "$origin" "$deterministic_head" present
  else
    assert_exit "R6 $mode retry fails closed" 1 "$rc"
    assert_contains "R6 $mode retry reports PROMPT_CAPTAIN" '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/feedback-r6-remote-$mode-retry.out"
    assert_contains "R6 $mode retry reports stable checkpoint reason" '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r6-remote-$mode-retry.out"
    assert_contains "R6 $mode retry reports prepared checkpoint state" '^state=closeout_pr_prepared$' "$TMP_DIR/feedback-r6-remote-$mode-retry.out"
    assert_feedback_r5_count "R6 $mode retry performs no illegal seed push" '^seed-push ' "$git_log" 1
    assert_feedback_r5_count "R6 $mode retry performs no terminal push" '^terminal-push ' "$git_log" 0
    assert_feedback_r5_receipt "R6 $mode retry" "$repo" prepared null
    if [ "$first_head" = "$(git -C "$repo" rev-parse HEAD)" ] && \
       [ "$first_tree" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] && \
       [ "$first_receipt_hash" = "$(shasum -a 256 "$receipt" | awk '{print $1}')" ]; then
      record_pass "R6 $mode retry preserves exact durable checkpoint bytes and history"
    else
      record_fail "R6 $mode retry preserves exact durable checkpoint bytes and history"
    fi
    if [ "$seed_oid" = "$(git -C "$repo" rev-parse "refs/heads/$deterministic_head")" ]; then
      record_pass "R6 $mode retry preserves the exact local seed ref"
    else
      record_fail "R6 $mode retry preserves the exact local seed ref"
    fi
    if [ "$mode" = different ]; then
      if [ "$remote_oid" = "$(git -C "$origin" rev-parse "refs/heads/$deterministic_head")" ]; then
        record_pass 'R6 different remote OID is never overwritten'
      else
        record_fail 'R6 different remote OID is never overwritten'
      fi
    elif [ "$seed_oid" = "$(git -C "$origin" rev-parse "refs/heads/$deterministic_head")" ]; then
      record_pass 'R6 failed remote inspection leaves the remote seed ref unchanged'
    else
      record_fail 'R6 failed remote inspection leaves the remote seed ref unchanged'
    fi
  fi
  assert_feedback_r6_temp_ownership "R6 $mode retry" "$retry_temp_root"
}

run_feedback_r6_bundle_cleanup_signal_case() {
  local signal expected label setup origin repo provider gh_bin git_bin provider_log git_log marker temp_root real_git real_mktemp rc
  while IFS='|' read -r signal expected; do
    label="$(printf '%s' "$signal" | tr '[:upper:]' '[:lower:]')"
    setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r6-signal-$label")"
    IFS='|' read -r origin repo provider <<<"$setup"
    gh_bin="$TMP_DIR/feedback-r6-signal-$label-gh-bin"; git_bin="$TMP_DIR/feedback-r6-signal-$label-git-bin"
    provider_log="$TMP_DIR/feedback-r6-signal-$label-provider.log"; git_log="$TMP_DIR/feedback-r6-signal-$label-git.log"
    marker="$TMP_DIR/feedback-r6-signal-$label.marker"; temp_root="$TMP_DIR/feedback-r6-signal-$label-tmp"
    mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"
    write_feedback_r5_b1_gh "$gh_bin/gh"
    write_feedback_r6_git_wrapper "$git_bin/git"
    write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"
    prepare_feedback_r6_temp_root "$temp_root"
    real_git="$(command -v git)"
    real_mktemp="$(command -v mktemp)"
    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$TMP_DIR/feedback-r6-signal-$label.registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_SIGNAL="$signal" \
      SHIP_FLOW_R6_SIGNAL_MARKER="$marker" SHIP_FLOW_R6_REAL_GIT="$real_git" SHIP_FLOW_R6_GIT_LOG="$git_log" \
      SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
      run_helper_with_path "$repo" "$TMP_DIR/feedback-r6-signal-$label.out" "$git_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    assert_exit "R6 real $signal during provider lookup exits with signal contract" "$expected" "$rc"
    if [ "$(sed -n '1p' "$marker" 2>/dev/null || true)" = "$signal" ]; then
      record_pass "R6 real $signal fires after optional bundle creation"
    else
      record_fail "R6 real $signal fires after optional bundle creation"
    fi
    assert_feedback_r5_receipt "R6 real $signal durable checkpoint" "$repo" prepared null
    assert_feedback_r5_count "R6 real $signal performs no push" '^(seed|terminal)-push ' "$git_log" 0
    assert_feedback_r6_temp_ownership "R6 real $signal" "$temp_root"
  done <<'EOF'
HUP|129
INT|130
QUIT|131
TERM|143
EOF
}

run_feedback_r7_atomic_seed_race_case() {
  local setup origin repo provider deterministic_head remote_ref gh_bin git_bin registry provider_log git_log timeline
  local failure_marker race_marker snapshot temp_root real_git real_mktemp competitor_oid unrelated_ref unrelated_oid
  local receipt snapshot_head snapshot_tree snapshot_receipt_hash snapshot_seed rc provider_after_race
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r7-atomic-seed-race)"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"
  remote_ref="refs/heads/$deterministic_head"
  gh_bin="$TMP_DIR/feedback-r7-race-gh-bin"; git_bin="$TMP_DIR/feedback-r7-race-git-bin"
  registry="$TMP_DIR/feedback-r7-race.registry"; provider_log="$TMP_DIR/feedback-r7-race-provider.log"
  git_log="$TMP_DIR/feedback-r7-race-git.log"; timeline="$TMP_DIR/feedback-r7-race.timeline"
  failure_marker="$TMP_DIR/feedback-r7-race-provider.marker"; race_marker="$TMP_DIR/feedback-r7-race.marker"
  snapshot="$TMP_DIR/feedback-r7-race.snapshot"; temp_root="$TMP_DIR/feedback-r7-race-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$timeline"
  write_feedback_r5_b1_gh "$gh_bin/gh"
  write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"
  prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"
  competitor_oid="$(git -C "$origin" rev-parse refs/heads/main)"
  unrelated_ref=refs/heads/r7-unrelated; unrelated_oid="$competitor_oid"
  git -C "$origin" update-ref "$unrelated_ref" "$unrelated_oid"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R5_FAILURE=create-before \
    SHIP_FLOW_R5_FAILURE_MARKER="$failure_marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_R7_RACE_MODE=create-competitor \
    SHIP_FLOW_R7_RACE_MARKER="$race_marker" SHIP_FLOW_R7_ORIGIN="$origin" \
    SHIP_FLOW_R7_REMOTE_REF="$remote_ref" SHIP_FLOW_R7_COMPETITOR_OID="$competitor_oid" \
    SHIP_FLOW_R7_LOCAL_HEAD="$deterministic_head" SHIP_FLOW_R7_SNAPSHOT="$snapshot" \
    SHIP_FLOW_R7_TIMELINE="$timeline" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r7-race.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"

  assert_exit 'R7 interleaving seed winner routes through stable retry' 1 "$rc"
  assert_contains 'R7 interleaving seed winner reports PROMPT_CAPTAIN' '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/feedback-r7-race.out"
  assert_contains 'R7 interleaving seed winner reports stable checkpoint reason' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r7-race.out"
  assert_contains 'R7 interleaving seed winner reports prepared checkpoint state' '^state=closeout_pr_prepared$' "$TMP_DIR/feedback-r7-race.out"
  assert_feedback_r5_receipt 'R7 interleaving seed winner checkpoint' "$repo" prepared null
  receipt="$(feedback_r5_receipt_path "$repo")"
  snapshot_head="$(awk -F= '$1=="head"{print $2}' "$snapshot")"
  snapshot_tree="$(awk -F= '$1=="tree"{print $2}' "$snapshot")"
  snapshot_receipt_hash="$(awk -F= '$1=="receipt_hash"{print $2}' "$snapshot")"
  snapshot_seed="$(awk -F= '$1=="local_seed"{print $2}' "$snapshot")"
  if [ "$snapshot_head" = "$(git -C "$repo" rev-parse HEAD)" ] && \
     [ "$snapshot_tree" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] && \
     [ "$snapshot_receipt_hash" = "$(git hash-object "$receipt")" ] && \
     [ "$snapshot_seed" = "$(git -C "$repo" rev-parse "refs/heads/$deterministic_head")" ]; then
    record_pass 'R7 rejected seed publication preserves exact local checkpoint and seed bytes'
  else
    record_fail 'R7 rejected seed publication preserves exact local checkpoint and seed bytes'
  fi
  if [ "$competitor_oid" = "$(git -C "$origin" rev-parse "$remote_ref")" ]; then
    record_pass 'R7 rejected seed publication preserves the competing remote ref'
  else
    record_fail 'R7 rejected seed publication preserves the competing remote ref'
  fi
  if [ "$unrelated_oid" = "$(git -C "$origin" rev-parse "$unrelated_ref")" ]; then
    record_pass 'R7 rejected seed publication preserves unrelated remote refs'
  else
    record_fail 'R7 rejected seed publication preserves unrelated remote refs'
  fi
  provider_after_race="$(awk 'seen && /^provider /{print} /^race-create /{seen=1}' "$timeline")"
  if [ -z "$provider_after_race" ]; then
    record_pass 'R7 rejected seed publication performs no later provider operation'
  else
    record_fail 'R7 rejected seed publication performs no later provider operation'
  fi
  assert_feedback_r5_count 'R7 race attempts exactly one seed publication' '^seed-push ' "$git_log" 1
  assert_contains 'R7 seed publication uses an expected-absence lease' "force-with-lease=${remote_ref}:" "$git_log"
  assert_contains 'R7 seed publication uses an explicit full-ref destination' "<${deterministic_head}:${remote_ref}>" "$git_log"
  assert_feedback_r5_count 'R7 rejected seed publication performs no terminal push' '^terminal-push ' "$git_log" 0
  assert_feedback_r5_count 'R7 rejected seed publication performs no provider create' '^call pr create ' "$provider_log" 0
  assert_feedback_r5_count 'R7 rejected seed publication performs no provider ready' '^call pr ready ' "$provider_log" 0
  assert_feedback_r6_temp_ownership 'R7 rejected seed publication' "$temp_root"
}

run_feedback_r8_multi_pushurl_case() {
  local setup endpoint_a endpoint_b repo provider deterministic_head remote_ref gh_bin git_bin registry
  local provider_log git_log bundle_log failure_marker temp_root real_git real_mktemp receipt
  local before_head before_tree before_receipt_hash before_a before_b after_a after_b rc
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r8-multi-pushurl)"
  IFS='|' read -r endpoint_a repo provider <<<"$setup"
  endpoint_b="$TMP_DIR/feedback-r8-endpoint-b.git"
  git clone -q --bare "$endpoint_a" "$endpoint_b"
  deterministic_head="$(feedback_r5_deterministic_head)"
  remote_ref="refs/heads/$deterministic_head"
  git -C "$endpoint_a" update-ref -d "$remote_ref"
  git -C "$endpoint_b" update-ref "$remote_ref" "$(git -C "$endpoint_b" rev-parse refs/heads/main)"

  gh_bin="$TMP_DIR/feedback-r8-gh-bin"; git_bin="$TMP_DIR/feedback-r8-git-bin"
  registry="$TMP_DIR/feedback-r8.registry"; provider_log="$TMP_DIR/feedback-r8-provider.log"
  git_log="$TMP_DIR/feedback-r8-git.log"; bundle_log="$TMP_DIR/feedback-r8-bundle.log"
  failure_marker="$TMP_DIR/feedback-r8-provider.marker"; temp_root="$TMP_DIR/feedback-r8-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"
  write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"
  prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R5_FAILURE=create-before \
    SHIP_FLOW_R5_FAILURE_MARKER="$failure_marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" \
    SHIP_FLOW_CLOSEOUT_FAILPOINT=after-prepared run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r8-prepare.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R8 fixture establishes a prepared checkpoint before destination rejection' 1 "$rc"
  assert_contains 'R8 prepared checkpoint uses stable conflict routing' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r8-prepare.out"
  receipt="$(feedback_r5_receipt_path "$repo")"
  python3 - "$receipt" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"].pop("publication_endpoint",None)
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -q --amend --no-edit
  before_head="$(git -C "$repo" rev-parse HEAD)"
  before_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  before_receipt_hash="$(git hash-object "$receipt")"

  git -C "$repo" config --unset-all remote.origin.pushurl 2>/dev/null || true
  git -C "$repo" config --add remote.origin.pushurl "$endpoint_a"
  git -C "$repo" config --add remote.origin.pushurl "$endpoint_b"
  before_a="$(git -C "$endpoint_a" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
  before_b="$(git -C "$endpoint_b" rev-parse --verify "$remote_ref")"
  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R5_FAILURE=create-before \
    SHIP_FLOW_R5_FAILURE_MARKER="$failure_marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r8-reject.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  after_a="$(git -C "$endpoint_a" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
  after_b="$(git -C "$endpoint_b" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"

  assert_exit 'R8 ambiguous push destination routes through stable retry' 1 "$rc"
  assert_contains 'R8 ambiguous push destination reports PROMPT_CAPTAIN' '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/feedback-r8-reject.out"
  assert_contains 'R8 ambiguous push destination reports stable checkpoint reason' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r8-reject.out"
  assert_contains 'R8 ambiguous push destination reports prepared checkpoint state' '^state=closeout_pr_prepared$' "$TMP_DIR/feedback-r8-reject.out"
  assert_feedback_r5_receipt 'R8 ambiguous push destination checkpoint' "$repo" prepared null
  if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && \
     [ "$before_tree" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] && \
     [ "$before_receipt_hash" = "$(git hash-object "$receipt")" ] && \
     ! git -C "$repo" show-ref --verify --quiet "$remote_ref"; then
    record_pass 'R8 destination rejection preserves exact local checkpoint and creates no local seed'
  else
    record_fail 'R8 destination rejection preserves exact local checkpoint and creates no local seed'
  fi
  if [ "$before_a" = "$after_a" ] && [ "$before_b" = "$after_b" ]; then
    record_pass "R8 destination rejection preserves both endpoints exactly (A=$after_a B=$after_b)"
  else
    record_fail "R8 destination rejection preserves both endpoints exactly (A ${before_a}->${after_a}, B ${before_b}->${after_b})"
  fi
  assert_feedback_r5_count 'R8 ambiguous destination performs no seed publication' '^seed-push ' "$git_log" 0
  assert_feedback_r5_count 'R8 ambiguous destination performs no terminal publication' '^terminal-push ' "$git_log" 0
  assert_feedback_r5_count 'R8 ambiguous destination performs no provider list' '^call pr list ' "$provider_log" 0
  assert_feedback_r5_count 'R8 ambiguous destination performs no provider create' '^call pr create ' "$provider_log" 0
  assert_feedback_r5_count 'R8 ambiguous destination performs no provider ready' '^call pr ready ' "$provider_log" 0
  assert_feedback_r5_count 'R8 ambiguous destination performs no bundle application' '^apply ' "$bundle_log" 0
  assert_feedback_r6_temp_ownership 'R8 ambiguous destination rejection' "$temp_root"
}

run_feedback_r8_invalid_destination_matrix() {
  local setup origin repo provider deterministic_head remote_ref gh_bin git_bin registry provider_log git_log bundle_log
  local failure_marker temp_root real_git real_mktemp receipt before_head before_tree before_receipt_hash mode rc
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r8-invalid-destinations)"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"
  remote_ref="refs/heads/$deterministic_head"
  gh_bin="$TMP_DIR/feedback-r8-invalid-gh-bin"; git_bin="$TMP_DIR/feedback-r8-invalid-git-bin"
  registry="$TMP_DIR/feedback-r8-invalid.registry"; provider_log="$TMP_DIR/feedback-r8-invalid-provider.log"
  git_log="$TMP_DIR/feedback-r8-invalid-git.log"; bundle_log="$TMP_DIR/feedback-r8-invalid-bundle.log"
  failure_marker="$TMP_DIR/feedback-r8-invalid-provider.marker"; temp_root="$TMP_DIR/feedback-r8-invalid-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"
  write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"
  prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R5_FAILURE=create-before \
    SHIP_FLOW_R5_FAILURE_MARKER="$failure_marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" \
    SHIP_FLOW_CLOSEOUT_FAILPOINT=after-prepared run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r8-invalid-prepare.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R8 invalid-destination matrix establishes one prepared checkpoint' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"
  python3 - "$receipt" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"].pop("publication_endpoint",None)
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -q --amend --no-edit
  before_head="$(git -C "$repo" rev-parse HEAD)"
  before_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  before_receipt_hash="$(git hash-object "$receipt")"
  git -C "$repo" remote add upstream https://github.com/example/repo.git

  for mode in missing malformed unresolvable; do
    git -C "$repo" config --unset-all remote.origin.pushurl 2>/dev/null || true
    git -C "$repo" config --unset-all remote.origin.url 2>/dev/null || true
    case "$mode" in
      missing) ;;
      malformed)
        git -C "$repo" config remote.origin.url "$origin"
        git -C "$repo" config --add remote.origin.pushurl '::malformed-closeout-destination'
        ;;
      unresolvable)
        git -C "$repo" config remote.origin.url "$origin"
        git -C "$repo" config --add remote.origin.pushurl "$TMP_DIR/feedback-r8-does-not-exist.git"
        ;;
    esac
    : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R5_FAILURE=create-before \
      SHIP_FLOW_R5_FAILURE_MARKER="$failure_marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
      SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
      SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" \
      run_helper_with_path "$repo" "$TMP_DIR/feedback-r8-invalid-$mode.out" "$git_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"

    assert_exit "R8 $mode destination routes through stable retry" 1 "$rc"
    assert_contains "R8 $mode destination reports PROMPT_CAPTAIN" '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/feedback-r8-invalid-$mode.out"
    assert_contains "R8 $mode destination reports stable checkpoint reason" '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r8-invalid-$mode.out"
    assert_contains "R8 $mode destination reports prepared checkpoint state" '^state=closeout_pr_prepared$' "$TMP_DIR/feedback-r8-invalid-$mode.out"
    if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && \
       [ "$before_tree" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] && \
       [ "$before_receipt_hash" = "$(git hash-object "$receipt")" ] && \
       ! git -C "$repo" show-ref --verify --quiet "$remote_ref"; then
      record_pass "R8 $mode destination preserves exact checkpoint and creates no local seed"
    else
      record_fail "R8 $mode destination preserves exact checkpoint and creates no local seed"
    fi
    assert_feedback_r5_count "R8 $mode destination performs no publication" '^(seed|terminal)-push ' "$git_log" 0
    assert_feedback_r5_count "R8 $mode destination performs no provider operation" '^call pr (list|create|ready) ' "$provider_log" 0
    assert_feedback_r5_count "R8 $mode destination performs no bundle application" '^apply ' "$bundle_log" 0
    assert_feedback_r6_temp_ownership "R8 $mode destination rejection" "$temp_root"
  done
}

run_feedback_r9_alias_and_rewrite_case() {
  local mode setup endpoint_a endpoint_b repo provider deterministic_head remote_ref gh_bin git_bin registry
  local provider_log git_log bundle_log failure_marker temp_root real_git real_mktemp receipt
  local before_head before_tree before_receipt_hash before_a before_b after_a after_b rc
  for mode in nested-remote chained-rewrite non-provider-local; do
    setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r9-${mode}")"
    IFS='|' read -r endpoint_a repo provider <<<"$setup"
    endpoint_b="$TMP_DIR/feedback-r9-${mode}-endpoint-b.git"
    git clone -q --bare "$endpoint_a" "$endpoint_b"
    deterministic_head="$(feedback_r5_deterministic_head)"
    remote_ref="refs/heads/$deterministic_head"
    git -C "$endpoint_a" update-ref -d "$remote_ref"
    git -C "$endpoint_b" update-ref -d "$remote_ref"

    gh_bin="$TMP_DIR/feedback-r9-${mode}-gh-bin"; git_bin="$TMP_DIR/feedback-r9-${mode}-git-bin"
    registry="$TMP_DIR/feedback-r9-${mode}.registry"; provider_log="$TMP_DIR/feedback-r9-${mode}-provider.log"
    git_log="$TMP_DIR/feedback-r9-${mode}-git.log"; bundle_log="$TMP_DIR/feedback-r9-${mode}-bundle.log"
    failure_marker="$TMP_DIR/feedback-r9-${mode}-provider.marker"; temp_root="$TMP_DIR/feedback-r9-${mode}-tmp"
    mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
    write_feedback_r5_b1_gh "$gh_bin/gh"
    write_feedback_r6_git_wrapper "$git_bin/git"
    write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"
    prepare_feedback_r6_temp_root "$temp_root"
    real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R5_FAILURE=create-before \
      SHIP_FLOW_R5_FAILURE_MARKER="$failure_marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
      SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
      SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" \
      SHIP_FLOW_CLOSEOUT_FAILPOINT=after-prepared run_helper_with_path "$repo" \
        "$TMP_DIR/feedback-r9-${mode}-prepare.out" "$git_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    assert_exit "R9 $mode fixture establishes one prepared checkpoint" 1 "$rc"
    receipt="$(feedback_r5_receipt_path "$repo")"
    python3 - "$receipt" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"].pop("publication_endpoint",None)
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
    git -C "$repo" add -- "${receipt#"$repo/"}"
    git -C "$repo" commit -q --amend --no-edit
    before_head="$(git -C "$repo" rev-parse HEAD)"
    before_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
    before_receipt_hash="$(git hash-object "$receipt")"

    git -C "$repo" remote add provider-source https://github.com/example/repo.git
    git -C "$repo" config --unset-all remote.origin.pushurl 2>/dev/null || true
    case "$mode" in
      nested-remote)
        git -C "$endpoint_b" update-ref "$remote_ref" "$(git -C "$endpoint_b" rev-parse refs/heads/main)"
        git -C "$repo" remote add nested-publication "$endpoint_a"
        git -C "$repo" config --add remote.nested-publication.pushurl "$endpoint_a"
        git -C "$repo" config --add remote.nested-publication.pushurl "$endpoint_b"
        git -C "$repo" config remote.origin.url nested-publication
        ;;
      chained-rewrite)
        git -C "$repo" config remote.origin.url https://github.com/example/repo.git
        git -C "$repo" config "url.file://${endpoint_a}.pushInsteadOf" https://github.com/example/repo.git
        git -C "$repo" config "url.file://${endpoint_b}.pushInsteadOf" "file://${endpoint_a}"
        ;;
      non-provider-local)
        git -C "$endpoint_b" update-ref refs/pull/131/head "$(git -C "$endpoint_a" rev-parse refs/pull/131/head)"
        git -C "$endpoint_b" config --unset-all ship-flow.closeoutFixtureRepository 2>/dev/null || true
        git -C "$repo" config --unset-all "url.file://${endpoint_a}.insteadOf" 2>/dev/null || true
        git -C "$repo" config remote.origin.url https://github.com/example/repo.git
        git -C "$repo" config "url.file://${endpoint_b}.insteadOf" https://github.com/example/repo.git
        ;;
    esac
    before_a="$(git -C "$endpoint_a" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
    before_b="$(git -C "$endpoint_b" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
    : >"$provider_log"; : >"$git_log"; : >"$bundle_log"

    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R5_FAILURE=create-before \
      SHIP_FLOW_R5_FAILURE_MARKER="$failure_marker" SHIP_FLOW_R6_REAL_GIT="$real_git" \
      SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
      SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" \
      run_helper_with_path "$repo" "$TMP_DIR/feedback-r9-${mode}-reject.out" "$git_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    after_a="$(git -C "$endpoint_a" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
    after_b="$(git -C "$endpoint_b" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"

    assert_exit "R9 $mode routes through stable retry" 1 "$rc"
    assert_contains "R9 $mode reports PROMPT_CAPTAIN" '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/feedback-r9-${mode}-reject.out"
    assert_contains "R9 $mode reports checkpoint conflict" '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r9-${mode}-reject.out"
    assert_contains "R9 $mode reports prepared state" '^state=closeout_pr_prepared$' "$TMP_DIR/feedback-r9-${mode}-reject.out"
    if [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && \
       [ "$before_tree" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] && \
       [ "$before_receipt_hash" = "$(git hash-object "$receipt")" ] && \
       ! git -C "$repo" show-ref --verify --quiet "$remote_ref"; then
      record_pass "R9 $mode preserves exact prepared checkpoint and creates no local seed"
    else
      record_fail "R9 $mode preserves exact prepared checkpoint and creates no local seed"
    fi
    if [ "$before_a" = "$after_a" ] && [ "$before_b" = "$after_b" ]; then
      record_pass "R9 $mode preserves every concrete endpoint ref"
    else
      record_fail "R9 $mode preserves every concrete endpoint ref (A ${before_a}->${after_a}, B ${before_b}->${after_b})"
    fi
    assert_feedback_r5_count "R9 $mode performs no publication" '^(seed|terminal)-push ' "$git_log" 0
    assert_feedback_r5_count "R9 $mode performs no provider operation" '^call pr (list|create|ready) ' "$provider_log" 0
    assert_feedback_r5_count "R9 $mode performs no bundle application" '^apply ' "$bundle_log" 0
    assert_feedback_r6_temp_ownership "R9 $mode rejection" "$temp_root"
  done
}

run_feedback_r9_bound_endpoint_drift_case() {
  local setup provider_endpoint endpoint_b endpoint_c repo provider deterministic_head remote_ref gh_bin git_bin registry
  local provider_log git_log bundle_log timeline temp_root real_git real_mktemp receipt bound_endpoint seed_oid terminal_oid rc post_terminal_query
  local legacy_head legacy_tree legacy_receipt_hash legacy_a legacy_b legacy_c
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r9-bound-endpoint-drift)"
  IFS='|' read -r provider_endpoint repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"; remote_ref="refs/heads/$deterministic_head"
  gh_bin="$TMP_DIR/feedback-r9-drift-gh-bin"; git_bin="$TMP_DIR/feedback-r9-drift-git-bin"
  registry="$TMP_DIR/feedback-r9-drift.registry"; provider_log="$TMP_DIR/feedback-r9-drift-provider.log"
  git_log="$TMP_DIR/feedback-r9-drift-git.log"; bundle_log="$TMP_DIR/feedback-r9-drift-bundle.log"
  timeline="$TMP_DIR/feedback-r9-drift.timeline"
  temp_root="$TMP_DIR/feedback-r9-drift-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"; : >"$timeline"
  write_feedback_r5_b1_gh "$gh_bin/gh"
  write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"
  prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$provider_endpoint" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_R7_TIMELINE="$timeline" \
    SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r9-drift-awaiting.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R9 drift fixture establishes awaiting checkpoint before terminal publication' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"
  seed_oid="$(git -C "$provider_endpoint" rev-parse "$remote_ref")"
  bound_endpoint="file://${provider_endpoint}"
  if python3 - "$receipt" "$bound_endpoint" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
raise SystemExit(0 if r["transaction"].get("publication_endpoint")==sys.argv[2] else 1)
PY
  then record_pass 'R9 awaiting checkpoint persists the provider-bound leaf endpoint'; else record_fail 'R9 awaiting checkpoint persists the provider-bound leaf endpoint'; fi

  endpoint_b="$TMP_DIR/feedback-r9-drift-endpoint-b.git"; endpoint_c="$TMP_DIR/feedback-r9-drift-endpoint-c.git"
  git clone -q --bare "$provider_endpoint" "$endpoint_b"
  git clone -q --bare "$provider_endpoint" "$endpoint_c"
  git -C "$repo" remote add provider-source https://github.com/example/repo.git
  git -C "$repo" remote add drift-publication "$endpoint_b"
  git -C "$repo" config --add remote.drift-publication.pushurl "$endpoint_b"
  git -C "$repo" config --add remote.drift-publication.pushurl "$endpoint_c"
  git -C "$repo" config remote.origin.url drift-publication
  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"; : >"$timeline"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$provider_endpoint" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_R7_TIMELINE="$timeline" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r9-drift-rerun.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  terminal_oid="$(git -C "$repo" rev-parse "$deterministic_head")"
  assert_exit 'R9 endpoint drift retry converges through the persisted provider leaf' 0 "$rc"
  assert_contains 'R9 endpoint drift retry awaits merge' '^reason=closeout-pr-awaiting-merge$' "$TMP_DIR/feedback-r9-drift-rerun.out"
  if [ "$(git -C "$provider_endpoint" rev-parse "$remote_ref")" = "$terminal_oid" ] && \
     [ "$(git -C "$endpoint_b" rev-parse "$remote_ref")" = "$seed_oid" ] && \
     [ "$(git -C "$endpoint_c" rev-parse "$remote_ref")" = "$seed_oid" ]; then
    record_pass 'R9 retry publishes terminal bytes only to the persisted provider endpoint'
  else
    record_fail 'R9 retry publishes terminal bytes only to the persisted provider endpoint'
  fi
  post_terminal_query="$(awk '/^git terminal-push$/{seen=1; next} seen && /^provider pr view 141 /{print; exit}' "$timeline")"
  if [ -n "$post_terminal_query" ]; then record_pass 'R9 terminal publication re-queries the bound provider PR'; else record_fail 'R9 terminal publication re-queries the bound provider PR'; fi
  assert_contains 'R9 provider becomes ready only while reporting the terminal OID' "^effect ready 141 ${terminal_oid}$" "$provider_log"
  assert_feedback_r5_count 'R9 endpoint drift performs one terminal publication' '^terminal-push ' "$git_log" 1
  assert_feedback_r5_count 'R9 endpoint drift performs one ready side effect' '^effect ready ' "$provider_log" 1
  assert_feedback_r5_receipt 'R9 endpoint drift preserves awaiting checkpoint' "$repo" awaiting_closeout_pr 141
  if python3 - "$receipt" "$bound_endpoint" <<'PY'
import json,sys
r=json.load(open(sys.argv[1]))
raise SystemExit(0 if r["transaction"].get("publication_endpoint")==sys.argv[2] else 1)
PY
  then record_pass 'R9 retry preserves the exact bound endpoint bytes'; else record_fail 'R9 retry preserves the exact bound endpoint bytes'; fi
  assert_feedback_r6_temp_ownership 'R9 endpoint drift retry' "$temp_root"

  python3 - "$receipt" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"].pop("publication_endpoint",None)
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -q --amend --no-edit
  legacy_head="$(git -C "$repo" rev-parse HEAD)"; legacy_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  legacy_receipt_hash="$(git hash-object "$receipt")"
  legacy_a="$(git -C "$provider_endpoint" rev-parse "$remote_ref")"
  legacy_b="$(git -C "$endpoint_b" rev-parse "$remote_ref")"
  legacy_c="$(git -C "$endpoint_c" rev-parse "$remote_ref")"
  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"; : >"$timeline"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$provider_endpoint" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_R7_TIMELINE="$timeline" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r9-legacy-awaiting.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R9 legacy awaiting checkpoint routes through stable retry' 1 "$rc"
  assert_contains 'R9 legacy awaiting checkpoint reports PROMPT_CAPTAIN' '^verdict=PROMPT_CAPTAIN$' "$TMP_DIR/feedback-r9-legacy-awaiting.out"
  assert_contains 'R9 legacy awaiting checkpoint reports checkpoint conflict' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r9-legacy-awaiting.out"
  assert_contains 'R9 legacy awaiting checkpoint reports prepared recovery state' '^state=closeout_pr_prepared$' "$TMP_DIR/feedback-r9-legacy-awaiting.out"
  if [ "$legacy_head" = "$(git -C "$repo" rev-parse HEAD)" ] && \
     [ "$legacy_tree" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] && \
     [ "$legacy_receipt_hash" = "$(git hash-object "$receipt")" ] && \
     [ "$legacy_a" = "$(git -C "$provider_endpoint" rev-parse "$remote_ref")" ] && \
     [ "$legacy_b" = "$(git -C "$endpoint_b" rev-parse "$remote_ref")" ] && \
     [ "$legacy_c" = "$(git -C "$endpoint_c" rev-parse "$remote_ref")" ]; then
    record_pass 'R9 legacy awaiting rejection preserves checkpoint and every endpoint ref'
  else
    record_fail 'R9 legacy awaiting rejection preserves checkpoint and every endpoint ref'
  fi
  assert_feedback_r5_count 'R9 legacy awaiting performs no closeout provider query or mutation' '^call pr (view 141|list|create|ready) ' "$provider_log" 0
  assert_feedback_r5_count 'R9 legacy awaiting performs no publication' '^(seed|terminal)-push ' "$git_log" 0
  assert_feedback_r5_count 'R9 legacy awaiting performs no bundle application' '^apply ' "$bundle_log" 0
}

run_feedback_r10_endpoint_authority_case() {
  local setup endpoint_a endpoint_b repo provider deterministic_head remote_ref gh_bin git_bin registry
  local provider_log git_log bundle_log temp_root real_git real_mktemp receipt global_config source_commits rc
  local before_b after_b before_receipt_hash before_head before_tree seed_a terminal_b

  # R10-B1: a matching ambient marker must not authorize an endpoint whose own
  # repository config carries no fixture identity.
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r10-ambient-marker)"
  IFS='|' read -r endpoint_a repo provider <<<"$setup"
  endpoint_b="$TMP_DIR/feedback-r10-ambient-endpoint-b.git"
  git clone -q --bare "$endpoint_a" "$endpoint_b"
  git -C "$endpoint_b" config --local --unset-all ship-flow.closeoutFixtureRepository 2>/dev/null || true
  deterministic_head="$(feedback_r5_deterministic_head)"; remote_ref="refs/heads/$deterministic_head"
  git -C "$endpoint_b" update-ref -d "$remote_ref"
  git -C "$repo" config --unset-all "url.file://${endpoint_a}.insteadOf" 2>/dev/null || true
  git -C "$repo" config remote.origin.url "file://${endpoint_b}"
  git -C "$repo" remote add provider-source https://github.com/example/repo.git
  git -C "$repo" config "url.file://${endpoint_a}.insteadOf" https://github.com/example/repo.git
  global_config="$TMP_DIR/feedback-r10-ambient-global.config"
  git config --file "$global_config" ship-flow.closeoutFixtureRepository example/repo
  gh_bin="$TMP_DIR/feedback-r10-ambient-gh-bin"; git_bin="$TMP_DIR/feedback-r10-ambient-git-bin"
  registry="$TMP_DIR/feedback-r10-ambient.registry"; provider_log="$TMP_DIR/feedback-r10-ambient-provider.log"
  git_log="$TMP_DIR/feedback-r10-ambient-git.log"; bundle_log="$TMP_DIR/feedback-r10-ambient-bundle.log"
  temp_root="$TMP_DIR/feedback-r10-ambient-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"
  before_b="$(git -C "$endpoint_b" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
  before_head="$(git -C "$repo" rev-parse HEAD)"; before_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  rc="$(GIT_CONFIG_GLOBAL="$global_config" TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" \
    SHIP_FLOW_R5_REGISTRY="$registry" SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" \
    SHIP_FLOW_R6_REAL_GIT="$real_git" SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" \
    SHIP_FLOW_R6_TEMP_ROOT="$temp_root" SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r10-ambient.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  after_b="$(git -C "$endpoint_b" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
  assert_exit 'R10 ambient marker leakage fails closed before endpoint effects' 1 "$rc"
  assert_contains 'R10 ambient marker leakage reports checkpoint conflict' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r10-ambient.out"
  assert_contains 'R10 ambient marker leakage reports prepared state' '^state=closeout_pr_prepared$' "$TMP_DIR/feedback-r10-ambient.out"
  if [ "$before_b" = "$after_b" ] && [ "$before_head" = "$(git -C "$repo" rev-parse HEAD)" ] && \
     [ "$before_tree" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ]; then
    record_pass 'R10 ambient marker leakage preserves endpoint and durable repository bytes'
  else
    record_fail "R10 ambient marker leakage preserves endpoint and durable repository bytes (B ${before_b}->${after_b})"
  fi
  assert_feedback_r5_count 'R10 ambient marker leakage performs no publication' '^(seed|terminal)-push ' "$git_log" 0
  assert_feedback_r5_count 'R10 ambient marker leakage performs no closeout provider effect' '^effect (create|ready) ' "$provider_log" 0
  assert_feedback_r5_count 'R10 ambient marker leakage performs no bundle application' '^apply ' "$bundle_log" 0

  # R10-B2: an awaiting checkpoint whose endpoint bytes are changed to a
  # provider-inequivalent repository must fail before terminal publication.
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r10-awaiting-provider)"
  IFS='|' read -r endpoint_a repo provider <<<"$setup"
  endpoint_b="$TMP_DIR/feedback-r10-awaiting-endpoint-b.git"; git clone -q --bare "$endpoint_a" "$endpoint_b"
  git -C "$endpoint_b" config --local ship-flow.closeoutFixtureRepository wrong/repository
  deterministic_head="$(feedback_r5_deterministic_head)"; remote_ref="refs/heads/$deterministic_head"
  gh_bin="$TMP_DIR/feedback-r10-awaiting-gh-bin"; git_bin="$TMP_DIR/feedback-r10-awaiting-git-bin"
  registry="$TMP_DIR/feedback-r10-awaiting.registry"; provider_log="$TMP_DIR/feedback-r10-awaiting-provider.log"
  git_log="$TMP_DIR/feedback-r10-awaiting-git.log"; bundle_log="$TMP_DIR/feedback-r10-awaiting-bundle.log"
  temp_root="$TMP_DIR/feedback-r10-awaiting-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r10-awaiting-seed.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R10 altered-awaiting fixture establishes the durable predecessor' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"
  python3 - "$receipt" "file://${endpoint_b}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
  git -C "$repo" add -- "${receipt#"$repo/"}"
  git -C "$repo" commit -q --amend --no-edit
  source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
  rm -f "$repo/.git/FETCH_HEAD"
  git -C "$repo" reflog expire --expire=now --all
  git -C "$repo" gc -q --prune=now
  assert_feedback_r3_b1_objects_missing 'R10 provider-mismatched awaiting precondition prunes provider source objects' "$repo" "$source_commits"
  before_receipt_hash="$(git hash-object "$receipt")"; before_b="$(git -C "$endpoint_b" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
  seed_a="$(git -C "$endpoint_a" rev-parse "$remote_ref")"
  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r10-awaiting-reject.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  terminal_b="$(git -C "$endpoint_b" rev-parse --verify "$remote_ref" 2>/dev/null || printf absent)"
  assert_exit 'R10 provider-mismatched awaiting endpoint fails before terminal publication' 1 "$rc"
  assert_contains 'R10 provider-mismatched awaiting endpoint reports checkpoint conflict' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r10-awaiting-reject.out"
  assert_contains 'R10 provider-mismatched awaiting endpoint reports prepared state' '^state=closeout_pr_prepared$' "$TMP_DIR/feedback-r10-awaiting-reject.out"
  if [ "$before_b" = "$terminal_b" ] && [ "$seed_a" = "$(git -C "$endpoint_a" rev-parse "$remote_ref")" ] && \
     [ "$before_receipt_hash" = "$(git hash-object "$receipt")" ]; then
    record_pass 'R10 provider-mismatched awaiting endpoint preserves both endpoint refs and predecessor bytes'
  else
    record_fail "R10 provider-mismatched awaiting endpoint preserves both endpoint refs and predecessor bytes (B ${before_b}->${terminal_b})"
  fi
  assert_feedback_r5_count 'R10 provider-mismatched awaiting endpoint performs no publication' '^(seed|terminal)-push ' "$git_log" 0
  assert_feedback_r5_count 'R10 provider-mismatched awaiting endpoint rejects before source acquisition' '^source-(fetch|update-ref) ' "$git_log" 0
  assert_feedback_r5_count 'R10 provider-mismatched awaiting endpoint performs no closeout provider operation' '^call pr (view 141|list|create|ready) ' "$provider_log" 0
  assert_feedback_r5_count 'R10 provider-mismatched awaiting endpoint performs no bundle application' '^apply ' "$bundle_log" 0
}

run_feedback_r10_terminal_predecessor_case() {
  local mode setup endpoint_a endpoint_b repo provider deterministic_head remote_ref gh_bin git_bin registry
  local provider_log git_log bundle_log temp_root real_git real_mktemp receipt relative rc
  local awaiting_hash remote_before remote_after head_before tree_before
  for mode in ${SHIP_FLOW_R10_TERMINAL_MODES:-reused landed forged-landed forged-main-landed stale-main-landed}; do
    setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r10-terminal-${mode}")"
    IFS='|' read -r endpoint_a repo provider <<<"$setup"
    endpoint_b="$TMP_DIR/feedback-r10-terminal-${mode}-endpoint-b.git"
    git clone -q --bare "$endpoint_a" "$endpoint_b"
    git -C "$endpoint_b" config --local ship-flow.closeoutFixtureRepository example/repo
    deterministic_head="$(feedback_r5_deterministic_head)"; remote_ref="refs/heads/$deterministic_head"
    gh_bin="$TMP_DIR/feedback-r10-terminal-${mode}-gh-bin"; git_bin="$TMP_DIR/feedback-r10-terminal-${mode}-git-bin"
    registry="$TMP_DIR/feedback-r10-terminal-${mode}.registry"
    provider_log="$TMP_DIR/feedback-r10-terminal-${mode}-provider.log"
    git_log="$TMP_DIR/feedback-r10-terminal-${mode}-git.log"
    bundle_log="$TMP_DIR/feedback-r10-terminal-${mode}-bundle.log"
    temp_root="$TMP_DIR/feedback-r10-terminal-${mode}-tmp"
    mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
    write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
    write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
    real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R6_REAL_GIT="$real_git" \
      SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
      SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
      run_helper_with_path "$repo" "$TMP_DIR/feedback-r10-terminal-${mode}-awaiting.out" "$git_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    assert_exit "R10 ${mode} fixture establishes awaiting predecessor" 1 "$rc"
    receipt="$(feedback_r5_receipt_path "$repo")"; relative="${receipt#"$repo/"}"
    awaiting_hash="$(git hash-object "$receipt")"
    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R6_REAL_GIT="$real_git" \
      SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
      SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
        "$TMP_DIR/feedback-r10-terminal-${mode}-built.out" "$git_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    assert_exit "R10 ${mode} fixture publishes one valid terminal head" 0 "$rc"
    if [ "$rc" != 0 ]; then
      sed "s/^/    R10 ${mode} build: /" "$TMP_DIR/feedback-r10-terminal-${mode}-built.out"
      continue
    fi

    if [ "$mode" = reused ]; then
      git -C "$repo" checkout -q "$deterministic_head"
      python3 - "$repo/$relative" "file://${endpoint_b}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
      git -C "$repo" add -- "$relative"
      git -C "$repo" commit -q --amend --no-edit
      git -C "$repo" checkout -q main
    else
      if [ "$mode" = forged-landed ] || [ "$mode" = forged-main-landed ]; then
        git -C "$repo" checkout -q "$deterministic_head"
        cp "$repo/$relative" "$TMP_DIR/feedback-r10-${mode}-applied-a.json"
        git -C "$repo" reset -q --hard main
        python3 - "$repo/$relative" "file://${endpoint_b}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
        git -C "$repo" add -- "$relative"
        git -C "$repo" commit -qm 'fixture: forge nearest awaiting endpoint'
        cp "$repo/$relative" "$TMP_DIR/feedback-r10-${mode}-awaiting-b.json"
        cp "$TMP_DIR/feedback-r10-${mode}-applied-a.json" "$repo/$relative"
        python3 - "$repo/$relative" "file://${endpoint_b}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
        git -C "$repo" add -- "$relative"
        git -C "$repo" commit -qm 'fixture: forge matching applied endpoint'
        cp "$repo/$relative" "$TMP_DIR/feedback-r10-${mode}-applied-b.json"
        terminal_oid="$(git -C "$repo" rev-parse HEAD)"
        git -C "$repo" push -q "file://${endpoint_a}" "+$terminal_oid:$remote_ref"
        python3 - "$registry" "$terminal_oid" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); oid=sys.argv[2]; rows=[]
for line in p.read_text().splitlines():
    rows.append("remote_oid="+oid if line.startswith("remote_oid=") else line)
p.write_text("\n".join(rows)+"\n")
PY
        : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
        rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
          SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R6_REAL_GIT="$real_git" \
          SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
          SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
            "$TMP_DIR/feedback-r10-forged-off-main.out" "$git_bin:$gh_bin:$PATH" \
            --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
        assert_exit 'R10 forged terminal branch invocation rejects before receipt recovery' 2 "$rc"
        assert_contains 'R10 forged terminal branch invocation requires authoritative main' '^reason=closeout-main-not-authoritative$' "$TMP_DIR/feedback-r10-forged-off-main.out"
        git -C "$repo" checkout -q main
      fi
      if [ "$mode" = forged-main-landed ]; then
        cp "$TMP_DIR/feedback-r10-${mode}-awaiting-b.json" "$repo/$relative"
        git -C "$repo" add -- "$relative"
        git -C "$repo" commit -qm 'fixture: rebase forged awaiting endpoint onto main'
        cp "$TMP_DIR/feedback-r10-${mode}-applied-b.json" "$repo/$relative"
        git -C "$repo" add -- "$relative"
        git -C "$repo" commit -qm 'fixture: rebase forged applied endpoint onto main'
      else
        if ! git -C "$repo" merge -q --no-ff "$deterministic_head" -m 'fixture: land R10 optional terminal head' >/dev/null 2>&1; then
          [ "$(git -C "$repo" diff --name-only --diff-filter=U)" = "$relative" ] || exit 1
          git -C "$repo" checkout -q --theirs -- "$relative"
          git -C "$repo" add -- "$relative"
          git -C "$repo" commit -qm 'fixture: land R10 optional terminal head'
        fi
      fi
      receipt="$repo/$relative"
      if [ "$mode" = landed ]; then
        python3 - "$receipt" "file://${endpoint_b}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
        git -C "$repo" add -- "$relative"
        git -C "$repo" commit -q --amend --no-edit
      fi
      if [ "$mode" = stale-main-landed ]; then
        for filler in $(seq 1 33); do
          git -C "$repo" commit -q --allow-empty -m "fixture: stale main predecessor filler $filler"
        done
      fi
      if [ "$mode" = forged-main-landed ]; then
        if [ "$(git -C "$repo" show "HEAD^:$relative" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transaction"]["phase"])')" = awaiting_closeout_pr ] && \
           [ "$(git -C "$repo" show "HEAD^^:$relative" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transaction"]["phase"])')" = awaiting_closeout_pr ]; then
          record_pass 'R10 forged main fixture carries two awaiting predecessor versions'
        else
          record_fail 'R10 forged main fixture carries two awaiting predecessor versions'
        fi
        if [ "$(git -C "$repo" show "HEAD^:$relative" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transaction"].get("publication_endpoint"))')" != \
             "$(git -C "$repo" show "HEAD^^:$relative" | python3 -c 'import json,sys; print(json.load(sys.stdin)["transaction"].get("publication_endpoint"))')" ]; then
          record_pass 'R10 forged main fixture binds distinct predecessor endpoints'
        else
          record_fail 'R10 forged main fixture binds distinct predecessor endpoints'
        fi
      fi
      python3 - "$registry" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); rows=[]
for line in p.read_text().splitlines():
    rows.append("state=MERGED" if line.startswith("state=") else line)
p.write_text("\n".join(rows)+"\n")
PY
    fi

    head_before="$(git -C "$repo" rev-parse HEAD)"; tree_before="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
    remote_before="$(git -C "$endpoint_a" rev-parse "$remote_ref")"
    : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$endpoint_a" SHIP_FLOW_R6_REAL_GIT="$real_git" \
      SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
      SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
        "$TMP_DIR/feedback-r10-terminal-${mode}-reject.out" "$git_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    remote_after="$(git -C "$endpoint_a" rev-parse "$remote_ref")"
    assert_exit "R10 endpoint-only ${mode} terminal alteration fails closed" 1 "$rc"
    assert_contains "R10 endpoint-only ${mode} alteration reports checkpoint conflict" '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r10-terminal-${mode}-reject.out"
    if [ "$mode" = forged-main-landed ]; then
      if ! grep -Eq '^detail=multiple distinct durable awaiting predecessors exist on authoritative main$' \
        "$TMP_DIR/feedback-r10-terminal-${mode}-reject.out"; then
        sed 's/^/    R10 forged-main: /' "$TMP_DIR/feedback-r10-terminal-${mode}-reject.out"
      fi
      assert_contains 'R10 forged main history rejects distinct awaiting predecessors as ambiguous' \
        '^detail=multiple distinct durable awaiting predecessors exist on authoritative main$' \
        "$TMP_DIR/feedback-r10-terminal-${mode}-reject.out"
    fi
    if [ "$head_before" = "$(git -C "$repo" rev-parse HEAD)" ] && \
       [ "$tree_before" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] && [ "$remote_before" = "$remote_after" ]; then
      record_pass "R10 endpoint-only ${mode} alteration preserves repository and provider ref bytes"
    else
      record_fail "R10 endpoint-only ${mode} alteration preserves repository and provider ref bytes"
    fi
    if [ "$mode" = reused ] && [ "$awaiting_hash" = "$(git hash-object "$receipt")" ]; then
      record_pass 'R10 reused terminal rejection preserves the exact awaiting predecessor bytes'
    elif [ "$mode" = landed ] || [ "$mode" = forged-landed ] || [ "$mode" = forged-main-landed ] || [ "$mode" = stale-main-landed ]; then
      record_pass 'R10 landed terminal rejection leaves the landed receipt commit unchanged'
    else
      record_fail 'R10 reused terminal rejection preserves the exact awaiting predecessor bytes'
    fi
    assert_feedback_r5_count "R10 endpoint-only ${mode} alteration performs no publication" '^(seed|terminal)-push ' "$git_log" 0
    assert_feedback_r5_count "R10 endpoint-only ${mode} alteration performs no ready effect" '^effect ready ' "$provider_log" 0
    assert_feedback_r5_count "R10 endpoint-only ${mode} alteration performs no bundle application" '^apply ' "$bundle_log" 0
  done
}

run_feedback_r10_terminal_race_case() {
  local setup origin repo provider deterministic_head remote_ref gh_bin git_bin registry provider_log git_log bundle_log timeline
  local temp_root real_git real_mktemp receipt receipt_hash awaiting_head awaiting_tree seed_oid competitor_oid race_marker rc
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r10-terminal-race)"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"; remote_ref="refs/heads/$deterministic_head"
  gh_bin="$TMP_DIR/feedback-r10-terminal-race-gh-bin"; git_bin="$TMP_DIR/feedback-r10-terminal-race-git-bin"
  registry="$TMP_DIR/feedback-r10-terminal-race.registry"; provider_log="$TMP_DIR/feedback-r10-terminal-race-provider.log"
  git_log="$TMP_DIR/feedback-r10-terminal-race-git.log"; bundle_log="$TMP_DIR/feedback-r10-terminal-race-bundle.log"
  timeline="$TMP_DIR/feedback-r10-terminal-race.timeline"; temp_root="$TMP_DIR/feedback-r10-terminal-race-tmp"
  race_marker="$TMP_DIR/feedback-r10-terminal-race.marker"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"; : >"$timeline"
  write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r10-terminal-race-awaiting.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R10 terminal race fixture establishes awaiting predecessor' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"; receipt_hash="$(git hash-object "$receipt")"
  awaiting_head="$(git -C "$repo" rev-parse HEAD)"; awaiting_tree="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  seed_oid="$(git -C "$origin" rev-parse "$remote_ref")"
  competitor_oid="$(git -C "$origin" rev-parse refs/heads/main)"
  [ "$competitor_oid" != "$seed_oid" ] || { record_fail 'R10 terminal race competitor differs from seed'; return; }
  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"; : >"$timeline"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_R7_TIMELINE="$timeline" \
    SHIP_FLOW_R10_TERMINAL_RACE_MODE=create-competitor SHIP_FLOW_R10_TERMINAL_RACE_MARKER="$race_marker" \
    SHIP_FLOW_R10_TERMINAL_RACE_ORIGIN="$origin" SHIP_FLOW_R10_TERMINAL_RACE_REF="$remote_ref" \
    SHIP_FLOW_R10_TERMINAL_RACE_OID="$competitor_oid" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r10-terminal-race-reject.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R10 real terminal receive-pack race routes through stable retry' 1 "$rc"
  assert_contains 'R10 terminal race reports checkpoint conflict' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r10-terminal-race-reject.out"
  assert_contains 'R10 terminal race reports awaiting state' '^state=closeout_pr_awaiting_merge$' "$TMP_DIR/feedback-r10-terminal-race-reject.out"
  if [ "$(git -C "$origin" rev-parse "$remote_ref")" = "$competitor_oid" ]; then record_pass 'R10 terminal lease rejection preserves the competing endpoint ref'; else record_fail 'R10 terminal lease rejection preserves the competing endpoint ref'; fi
  if [ "$awaiting_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$awaiting_tree" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ] && \
     [ "$receipt_hash" = "$(git hash-object "$receipt")" ]; then record_pass 'R10 terminal lease rejection preserves exact awaiting checkpoint bytes'; else record_fail 'R10 terminal lease rejection preserves exact awaiting checkpoint bytes'; fi
  assert_feedback_r5_count 'R10 terminal race performs exactly one leased publication attempt' '^terminal-push ' "$git_log" 1
  assert_feedback_r5_count 'R10 terminal race performs no post-rejection provider refresh' '^call pr view 141 ' "$provider_log" 1
  assert_feedback_r5_count 'R10 terminal race performs no ready effect' '^effect ready ' "$provider_log" 0
}

run_feedback_r10_refresh_and_legacy_case() {
  local mode setup origin endpoint_b repo provider deterministic_head gh_bin git_bin registry provider_log git_log bundle_log temp_root
  local real_git real_mktemp receipt receipt_hash head_before terminal_oid marker source_commits rc hydrated_head hydrated_hash
  for mode in refresh legacy; do
    setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r10-${mode}")"
    IFS='|' read -r origin repo provider <<<"$setup"
    deterministic_head="$(feedback_r5_deterministic_head)"
    gh_bin="$TMP_DIR/feedback-r10-${mode}-gh-bin"; git_bin="$TMP_DIR/feedback-r10-${mode}-git-bin"
    registry="$TMP_DIR/feedback-r10-${mode}.registry"; provider_log="$TMP_DIR/feedback-r10-${mode}-provider.log"
    git_log="$TMP_DIR/feedback-r10-${mode}-git.log"; bundle_log="$TMP_DIR/feedback-r10-${mode}-bundle.log"
    temp_root="$TMP_DIR/feedback-r10-${mode}-tmp"; marker="$TMP_DIR/feedback-r10-${mode}.marker"
    mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
    write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
    write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
    real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"
    if [ "$mode" = refresh ]; then
      rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
        SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
        SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
        SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
        run_helper_with_path "$repo" "$TMP_DIR/feedback-r10-refresh-awaiting.out" "$git_bin:$gh_bin:$PATH" \
          --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
      assert_exit 'R10 refresh fixture establishes awaiting predecessor' 1 "$rc"
      receipt="$(feedback_r5_receipt_path "$repo")"; receipt_hash="$(git hash-object "$receipt")"; head_before="$(git -C "$repo" rev-parse HEAD)"
      rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
        SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
        SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
        SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_R10_REFRESH_FAILURE=after-terminal-once \
        SHIP_FLOW_R10_REFRESH_FAILURE_MARKER="$marker" run_helper_with_path "$repo" \
          "$TMP_DIR/feedback-r10-refresh-fail.out" "$git_bin:$gh_bin:$PATH" \
          --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
      terminal_oid="$(git -C "$origin" rev-parse "refs/heads/$deterministic_head")"
      assert_exit 'R10 post-terminal provider refresh failure routes through stable retry' 1 "$rc"
      assert_contains 'R10 refresh failure retains awaiting state' '^state=closeout_pr_awaiting_merge$' "$TMP_DIR/feedback-r10-refresh-fail.out"
      if [ "$head_before" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$receipt_hash" = "$(git hash-object "$receipt")" ]; then record_pass 'R10 refresh failure preserves exact awaiting checkpoint'; else record_fail 'R10 refresh failure preserves exact awaiting checkpoint'; fi
      assert_feedback_r5_count 'R10 refresh failure publishes terminal exactly once' '^terminal-push ' "$git_log" 1
      assert_feedback_r5_count 'R10 refresh failure performs no ready effect' '^effect ready ' "$provider_log" 0
      rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
        SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
        SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
        SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_R10_REFRESH_FAILURE=after-terminal-once \
        SHIP_FLOW_R10_REFRESH_FAILURE_MARKER="$marker" run_helper_with_path "$repo" \
          "$TMP_DIR/feedback-r10-refresh-retry.out" "$git_bin:$gh_bin:$PATH" \
          --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
      assert_exit 'R10 refresh retry converges' 0 "$rc"
      if [ "$(git -C "$origin" rev-parse "refs/heads/$deterministic_head")" = "$terminal_oid" ]; then record_pass 'R10 refresh retry preserves exact terminal endpoint OID'; else record_fail 'R10 refresh retry preserves exact terminal endpoint OID'; fi
      assert_feedback_r5_count 'R10 refresh retry performs no second terminal push' '^terminal-push ' "$git_log" 1
      assert_feedback_r5_count 'R10 refresh retry performs ready exactly once' '^effect ready ' "$provider_log" 1
    else
      rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
        SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R5_FAILURE=list-before \
        SHIP_FLOW_R5_FAILURE_MARKER="$marker" SHIP_FLOW_R6_REAL_GIT="$real_git" SHIP_FLOW_R6_GIT_LOG="$git_log" \
        SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
        run_helper_with_path "$repo" "$TMP_DIR/feedback-r10-legacy-prepared.out" "$git_bin:$gh_bin:$PATH" \
          --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
      assert_exit 'R10 legacy fixture establishes prepared checkpoint' 1 "$rc"
      receipt="$(feedback_r5_receipt_path "$repo")"
      python3 - "$receipt" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text()); r["transaction"].pop("publication_endpoint",None)
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
      git -C "$repo" add -- "${receipt#"$repo/"}"; git -C "$repo" commit -q --amend --no-edit
      : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
      rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
        SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
        SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
        SHIP_FLOW_CLOSEOUT_FAILPOINT=after-prepared run_helper_with_path "$repo" \
          "$TMP_DIR/feedback-r10-legacy-hydrate.out" "$git_bin:$gh_bin:$PATH" \
          --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
      assert_exit 'R10 legacy prepared hydration stops at durable hydrated checkpoint' 1 "$rc"
      hydrated_head="$(git -C "$repo" rev-parse HEAD)"; hydrated_hash="$(git hash-object "$receipt")"
      if python3 - "$receipt" "file://${origin}" <<'PY'
import json,sys
r=json.load(open(sys.argv[1])); t=r["transaction"]
raise SystemExit(0 if (t["phase"],t["generation"],t.get("publication_endpoint"))==("prepared",1,sys.argv[2]) else 1)
PY
      then record_pass 'R10 legacy prepared checkpoint hydrates the provider endpoint in place'; else record_fail 'R10 legacy prepared checkpoint hydrates the provider endpoint in place'; fi
      assert_feedback_r5_count 'R10 legacy hydration performs no publication' '^(seed|terminal)-push ' "$git_log" 0
      assert_feedback_r5_count 'R10 legacy hydration performs no closeout provider operation' '^call pr (list|create|ready) ' "$provider_log" 0
      assert_feedback_r5_count 'R10 legacy hydration performs no bundle application' '^apply ' "$bundle_log" 0
      rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
        SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
        SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
        SHIP_FLOW_CLOSEOUT_FAILPOINT=after-prepared run_helper_with_path "$repo" \
          "$TMP_DIR/feedback-r10-legacy-replay.out" "$git_bin:$gh_bin:$PATH" \
          --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
      assert_exit 'R10 hydrated prepared replay stops at the same failpoint' 1 "$rc"
      if [ "$hydrated_head" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$hydrated_hash" = "$(git hash-object "$receipt")" ]; then record_pass 'R10 hydrated prepared replay is commit and byte idempotent'; else record_fail 'R10 hydrated prepared replay is commit and byte idempotent'; fi

      endpoint_b="$TMP_DIR/feedback-r10-legacy-wrong-endpoint.git"
      git clone -q --bare "$origin" "$endpoint_b"
      git -C "$endpoint_b" config --local ship-flow.closeoutFixtureRepository wrong/repository
      python3 - "$receipt" "file://${endpoint_b}" <<'PY'
import json,pathlib,sys
p=pathlib.Path(sys.argv[1]); r=json.loads(p.read_text())
r["transaction"]["publication_endpoint"]=sys.argv[2]
p.write_text(json.dumps(r,sort_keys=True,indent=2)+"\n")
PY
      git -C "$repo" add -- "${receipt#"$repo/"}"; git -C "$repo" commit -q --amend --no-edit
      source_commits="$(awk -F= '$1=="source_commits"{sub(/^[^=]*=/, ""); print; exit}' "$provider")"
      rm -f "$repo/.git/FETCH_HEAD"
      git -C "$repo" reflog expire --expire=now --all
      git -C "$repo" gc -q --prune=now
      assert_feedback_r3_b1_objects_missing 'R10 invalid prepared endpoint precondition prunes provider source objects' "$repo" "$source_commits"
      : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
      rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
        SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
        SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
        SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
          "$TMP_DIR/feedback-r10-invalid-prepared.out" "$git_bin:$gh_bin:$PATH" \
          --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
      assert_exit 'R10 invalid prepared endpoint fails closed' 1 "$rc"
      assert_contains 'R10 invalid prepared endpoint reports checkpoint conflict' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r10-invalid-prepared.out"
      assert_feedback_r5_count 'R10 invalid prepared endpoint rejects before source acquisition' '^source-(fetch|update-ref) ' "$git_log" 0
      assert_feedback_r5_count 'R10 invalid prepared endpoint performs no bundle application' '^apply ' "$bundle_log" 0
    fi
  done
}

run_feedback_r10_transport_matrix() {
  local label literal setup origin repo provider deterministic_head remote_ref gh_bin git_bin registry provider_log git_log
  local bundle_log temp_root real_git real_mktemp receipt terminal_oid persisted rc
  while IFS='|' read -r label literal; do
    setup="$(prepare_feedback_r3_b1_main_only_clone "feedback-r10-transport-${label}")"
    IFS='|' read -r origin repo provider <<<"$setup"
    git -C "$repo" config --local --unset-all "url.file://${origin}.insteadOf" 2>/dev/null || true
    git -C "$repo" config --local remote.origin.url "$literal"
    deterministic_head="$(feedback_r5_deterministic_head)"; remote_ref="refs/heads/$deterministic_head"
    gh_bin="$TMP_DIR/feedback-r10-transport-${label}-gh-bin"; git_bin="$TMP_DIR/feedback-r10-transport-${label}-git-bin"
    registry="$TMP_DIR/feedback-r10-transport-${label}.registry"
    provider_log="$TMP_DIR/feedback-r10-transport-${label}-provider.log"
    git_log="$TMP_DIR/feedback-r10-transport-${label}-git.log"
    bundle_log="$TMP_DIR/feedback-r10-transport-${label}-bundle.log"
    temp_root="$TMP_DIR/feedback-r10-transport-${label}-tmp"
    mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
    write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
    write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
    real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"
    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
      SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
      SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_R10_TRANSPORT_LITERAL="$literal" \
      SHIP_FLOW_R10_TRANSPORT_ORIGIN="$origin" run_helper_with_path "$repo" \
        "$TMP_DIR/feedback-r10-transport-${label}.out" "$git_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    if [ "$rc" != 0 ]; then sed "s/^/    R10 ${label}: /" "$TMP_DIR/feedback-r10-transport-${label}.out"; fi
    assert_exit "R10 ${label} fake transport completes non-dry-run closeout publication" 0 "$rc"
    receipt="$(feedback_r5_receipt_path "$repo")"
    persisted="$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["transaction"].get("publication_endpoint", ""))' "$receipt")"
    if [ "$persisted" = "$literal" ]; then record_pass "R10 ${label} preserves the exact provider spelling in the awaiting checkpoint"; else record_fail "R10 ${label} preserves the exact provider spelling in the awaiting checkpoint"; fi
    terminal_oid="$(git -C "$repo" rev-parse "$deterministic_head" 2>/dev/null || true)"
    if [ -n "$terminal_oid" ] && [ "$(git -C "$origin" rev-parse "$remote_ref" 2>/dev/null || true)" = "$terminal_oid" ]; then
      record_pass "R10 ${label} actual local receive-pack reaches the exact terminal endpoint ref"
    else
      record_fail "R10 ${label} actual local receive-pack reaches the exact terminal endpoint ref"
    fi
    assert_feedback_r5_count "R10 ${label} performs one expected-absence seed receive-pack" '^seed-push ' "$git_log" 1
    assert_feedback_r5_count "R10 ${label} performs one leased terminal receive-pack" '^terminal-push ' "$git_log" 1
    assert_feedback_r5_count "R10 ${label} readies only after provider convergence" '^effect ready ' "$provider_log" 1
  done <<'EOF'
https|HTTPS://GitHub.com/Example/Repo.git
ssh|SSH://git@GitHub.com/Example/Repo.git
scp|git@GitHub.com:Example/Repo.git
EOF
}

land_feedback_terminal_head() {
  local repo="$1" deterministic_head="$2" relative="$3"
  if ! git -C "$repo" merge -q --no-ff "$deterministic_head" \
    -m 'fixture: land optional terminal head' >/dev/null 2>&1; then
    [ "$(git -C "$repo" diff --name-only --diff-filter=U)" = "$relative" ] || return 1
    git -C "$repo" checkout -q --theirs -- "$relative"
    git -C "$repo" add -- "$relative"
    git -C "$repo" commit -qm 'fixture: land optional terminal head'
  fi
}

set_feedback_registry_merge() {
  local registry="$1" remote_oid="$2"
  python3 - "$registry" "$remote_oid" <<'PY'
import pathlib,sys
p=pathlib.Path(sys.argv[1]); oid=sys.argv[2]; rows=[]
for line in p.read_text().splitlines():
    if line.startswith("state="): rows.append("state=MERGED")
    elif line.startswith("remote_oid="): rows.append("remote_oid="+oid)
    else: rows.append(line)
p.write_text("\n".join(rows)+"\n")
PY
}

run_feedback_r11_mature_main_case() {
  local setup origin repo provider deterministic_head remote_ref gh_bin git_bin registry provider_log git_log
  local bundle_log temp_root real_git real_mktemp receipt relative awaiting_oid terminal_oid head_before tree_before rc filler
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r11-mature-main)"
  IFS='|' read -r origin repo provider <<<"$setup"
  for filler in $(seq 1 40); do
    git -C "$repo" commit -q --allow-empty -m "fixture: mature main filler $filler"
  done
  deterministic_head="$(feedback_r5_deterministic_head)"; remote_ref="refs/heads/$deterministic_head"
  gh_bin="$TMP_DIR/feedback-r11-mature-main-gh-bin"; git_bin="$TMP_DIR/feedback-r11-mature-main-git-bin"
  registry="$TMP_DIR/feedback-r11-mature-main.registry"; provider_log="$TMP_DIR/feedback-r11-mature-main-provider.log"
  git_log="$TMP_DIR/feedback-r11-mature-main-git.log"; bundle_log="$TMP_DIR/feedback-r11-mature-main-bundle.log"
  temp_root="$TMP_DIR/feedback-r11-mature-main-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r11-mature-main-awaiting.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R11 mature-main fixture establishes awaiting predecessor' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"; relative="${receipt#"$repo/"}"; awaiting_oid="$(git -C "$repo" rev-parse HEAD)"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r11-mature-main-built.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R11 mature-main fixture publishes one terminal head' 0 "$rc"
  terminal_oid="$(git -C "$repo" rev-parse "$deterministic_head")"
  land_feedback_terminal_head "$repo" "$deterministic_head" "$relative"
  set_feedback_registry_merge "$registry" "$terminal_oid"
  git -C "$repo" tag "$deterministic_head" "$awaiting_oid"
  if [ "$(git -C "$repo" rev-parse "refs/tags/$deterministic_head")" != \
       "$(git -C "$repo" rev-parse "refs/heads/$deterministic_head")" ]; then
    record_pass 'R11 mature-main precondition carries a colliding nonterminal tag'
  else
    record_fail 'R11 mature-main precondition carries a colliding nonterminal tag'
  fi
  if [ "$(git -C "$repo" rev-parse HEAD^1)" = "$awaiting_oid" ]; then
    record_pass 'R11 mature-main precondition keeps the unique awaiting predecessor at HEAD^1'
  else
    record_fail 'R11 mature-main precondition keeps the unique awaiting predecessor at HEAD^1'
  fi
  head_before="$(git -C "$repo" rev-parse HEAD)"; tree_before="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r11-mature-main-recovery.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R11 mature main accepts its unique nearby awaiting predecessor' 0 "$rc"
  assert_contains 'R11 mature main converges to terminal no-op' '^reason=closeout-pr-terminal-noop$' "$TMP_DIR/feedback-r11-mature-main-recovery.out"
  if [ "$head_before" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$tree_before" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ]; then
    record_pass 'R11 mature-main recovery preserves repository bytes'
  else
    record_fail 'R11 mature-main recovery preserves repository bytes'
  fi
  assert_feedback_r5_count 'R11 mature-main recovery performs no publication' '^(seed|terminal)-push ' "$git_log" 0
  assert_feedback_r5_count 'R11 mature-main recovery performs no provider effect' '^effect (create|ready) ' "$provider_log" 0
  assert_feedback_r5_count 'R11 mature-main recovery performs no bundle application' '^apply ' "$bundle_log" 0
}

run_feedback_r11_provider_oid_case() {
  local setup origin repo provider deterministic_head gh_bin git_bin registry provider_log git_log bundle_log
  local temp_root real_git real_mktemp receipt relative awaiting_oid terminal_oid unrelated_terminal_oid terminal_tree head_before tree_before rc
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r11-provider-oid)"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"
  gh_bin="$TMP_DIR/feedback-r11-provider-oid-gh-bin"; git_bin="$TMP_DIR/feedback-r11-provider-oid-git-bin"
  registry="$TMP_DIR/feedback-r11-provider-oid.registry"; provider_log="$TMP_DIR/feedback-r11-provider-oid-provider.log"
  git_log="$TMP_DIR/feedback-r11-provider-oid-git.log"; bundle_log="$TMP_DIR/feedback-r11-provider-oid-bundle.log"
  temp_root="$TMP_DIR/feedback-r11-provider-oid-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r11-provider-oid-awaiting.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R11 provider-OID fixture establishes awaiting predecessor' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"; relative="${receipt#"$repo/"}"; awaiting_oid="$(git -C "$repo" rev-parse HEAD)"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r11-provider-oid-built.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R11 provider-OID fixture publishes one terminal head' 0 "$rc"
  terminal_oid="$(git -C "$repo" rev-parse "$deterministic_head")"
  land_feedback_terminal_head "$repo" "$deterministic_head" "$relative"
  set_feedback_registry_merge "$registry" "$awaiting_oid"
  git -C "$origin" update-ref "refs/heads/$deterministic_head" "$awaiting_oid" "$terminal_oid"
  head_before="$(git -C "$repo" rev-parse HEAD)"; tree_before="$(git -C "$repo" rev-parse 'HEAD^{tree}')"
  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r11-provider-oid-reject.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$terminal_oid" != "$(git -C "$origin" rev-parse "refs/heads/$deterministic_head")" ]; then
    record_pass 'R11 provider-OID divergence fixture uses distinct terminal and provider OIDs'
  else
    record_fail 'R11 provider-OID divergence fixture uses distinct terminal and provider OIDs'
  fi
  assert_exit 'R11 landed recovery rejects provider/local terminal OID divergence' 1 "$rc"
  assert_contains 'R11 provider/local divergence reports checkpoint conflict' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r11-provider-oid-reject.out"
  if [ "$head_before" = "$(git -C "$repo" rev-parse HEAD)" ] && [ "$tree_before" = "$(git -C "$repo" rev-parse 'HEAD^{tree}')" ]; then
    record_pass 'R11 provider-OID rejection preserves repository bytes'
  else
    record_fail 'R11 provider-OID rejection preserves repository bytes'
  fi
  assert_feedback_r5_count 'R11 provider-OID rejection performs no publication' '^(seed|terminal)-push ' "$git_log" 0
  assert_feedback_r5_count 'R11 provider-OID rejection performs no provider effect' '^effect (create|ready) ' "$provider_log" 0
  assert_feedback_r5_count 'R11 provider-OID rejection performs no bundle application' '^apply ' "$bundle_log" 0

  terminal_tree="$(git -C "$repo" rev-parse "${terminal_oid}^{tree}")"
  unrelated_terminal_oid="$(printf '%s\n' 'fixture: provider terminal tree without awaiting ancestry' | \
    git -C "$repo" commit-tree "$terminal_tree")"
  git -C "$origin" fetch -q "$repo" "$unrelated_terminal_oid"
  git -C "$origin" update-ref "refs/heads/$deterministic_head" "$unrelated_terminal_oid" "$awaiting_oid"
  git -C "$repo" update-ref -d "refs/heads/$deterministic_head" "$terminal_oid"
  if ! git -C "$repo" merge-base --is-ancestor "$awaiting_oid" "$unrelated_terminal_oid"; then
    record_pass 'R11 ancestry fixture reuses valid terminal bytes outside awaiting lineage'
  else
    record_fail 'R11 ancestry fixture reuses valid terminal bytes outside awaiting lineage'
  fi
  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r11-provider-ancestry-reject.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R11 provider terminal bytes outside awaiting ancestry fail closed' 1 "$rc"
  assert_contains 'R11 provider ancestry rejection names the durable checkpoint relation' \
    '^detail=landed closeout provider head does not descend from its durable awaiting checkpoint$' \
    "$TMP_DIR/feedback-r11-provider-ancestry-reject.out"
  assert_feedback_r5_count 'R11 provider ancestry rejection performs no publication' '^(seed|terminal)-push ' "$git_log" 0
  assert_feedback_r5_count 'R11 provider ancestry rejection performs no provider effect' '^effect (create|ready) ' "$provider_log" 0
  assert_feedback_r5_count 'R11 provider ancestry rejection performs no bundle application' '^apply ' "$bundle_log" 0
}

write_feedback_r11_mktemp_signal_wrapper() {
  local bin="$1"
  cat >"$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
: "${SHIP_FLOW_R11_REAL_MKTEMP:?missing real mktemp path}"
: "${SHIP_FLOW_R11_TEMP_ROOT:?missing scoped temp root}"
export TMPDIR="$SHIP_FLOW_R11_TEMP_ROOT"
args=("$@")
if [ "$#" = 0 ]; then
  args=("$SHIP_FLOW_R11_TEMP_ROOT/ship-flow-r11-file.XXXXXX")
elif [ "$#" = 1 ] && [ "$1" = -d ]; then
  args=(-d "$SHIP_FLOW_R11_TEMP_ROOT/ship-flow-r11-dir.XXXXXX")
fi
created="$("$SHIP_FLOW_R11_REAL_MKTEMP" "${args[@]}")"
is_validator_candidate=no
if [ "$#" = 0 ]; then
  is_validator_candidate=yes
elif [ "$#" = 1 ]; then
  case "$1" in */ship-flow-closeout-validator.*/validator.XXXXXX) is_validator_candidate=yes ;; esac
fi
if [ "$is_validator_candidate" = yes ] && [ -n "${SHIP_FLOW_R11_SIGNAL:-}" ]; then
  count=0
  [ ! -f "${SHIP_FLOW_R11_SIGNAL_COUNTER:?missing signal counter}" ] || \
    count="$(sed -n '1p' "$SHIP_FLOW_R11_SIGNAL_COUNTER")"
  count=$((count + 1)); printf '%s\n' "$count" >"$SHIP_FLOW_R11_SIGNAL_COUNTER"
  if [ "$count" = "${SHIP_FLOW_R11_SIGNAL_OCCURRENCE:?missing signal occurrence}" ]; then
    printf '%s\n' "$created"
    printf '%s|%s\n' "$SHIP_FLOW_R11_SIGNAL" "$count" >"${SHIP_FLOW_R11_SIGNAL_MARKER:?missing signal marker}"
    kill -s "$SHIP_FLOW_R11_SIGNAL" "$PPID"
    exit 0
  fi
fi
printf '%s\n' "$created"
EOF
  chmod +x "$bin"
}

write_feedback_r11_validator_root_signal_wrappers() {
  local dir="$1"
  cat >"$dir/mktemp" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
created="$("${SHIP_FLOW_R11_REAL_MKTEMP:?missing real mktemp}" "$@")"
if [ "$#" = 2 ] && [ "$1" = -d ]; then
  case "$2" in */ship-flow-closeout-validator.XXXXXX)
    printf '%s\n' "${SHIP_FLOW_R11_SIGNAL:?missing signal}" >"${SHIP_FLOW_R11_SIGNAL_MARKER:?missing marker}"
    kill -s "$SHIP_FLOW_R11_SIGNAL" "$PPID"
    exit 0
    ;;
  esac
fi
printf '%s\n' "$created"
EOF
  cat >"$dir/mkdir" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
"${SHIP_FLOW_R11_REAL_MKDIR:?missing real mkdir}" "$@"
for arg in "$@"; do
  case "$arg" in */ship-flow-closeout-validator.*)
    printf '%s\n' "${SHIP_FLOW_R11_SIGNAL:?missing signal}" >"${SHIP_FLOW_R11_SIGNAL_MARKER:?missing marker}"
    kill -s "$SHIP_FLOW_R11_SIGNAL" "$PPID"
    ;;
  esac
done
EOF
  chmod +x "$dir/mktemp" "$dir/mkdir"
}

run_feedback_r11_validator_signal_case() {
  local setup origin seed_repo provider gh_bin registry provider_log initial_tmp real_mktemp rc receipt
  local occurrence seam signal expected label repo mktemp_bin temp_root counter marker output
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r11-validator-signal-seed)"
  IFS='|' read -r origin seed_repo provider <<<"$setup"
  gh_bin="$TMP_DIR/feedback-r11-validator-signal-gh-bin"; registry="$TMP_DIR/feedback-r11-validator-signal.registry"
  provider_log="$TMP_DIR/feedback-r11-validator-signal-provider.log"; initial_tmp="$TMP_DIR/feedback-r11-validator-signal-seed-tmp"
  mkdir -p "$gh_bin"; : >"$provider_log"; prepare_feedback_r6_temp_root "$initial_tmp"
  write_feedback_r5_b1_gh "$gh_bin/gh"
  rc="$(TMPDIR="$initial_tmp" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$seed_repo" "$TMP_DIR/feedback-r11-validator-signal-seed.out" "$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R11 validator-signal fixture establishes awaiting checkpoint' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$seed_repo")"
  [ -f "$receipt" ] || { record_fail 'R11 validator-signal fixture has a receipt'; return; }
  real_mktemp="$(command -v mktemp)"

  while IFS='|' read -r occurrence seam; do
    while IFS='|' read -r signal expected; do
      label="$(printf '%s-%s' "$seam" "$signal" | tr '[:upper:]' '[:lower:]')"
      repo="$seed_repo"
      mktemp_bin="$TMP_DIR/feedback-r11-validator-${label}-mktemp-bin"
      temp_root="$TMP_DIR/feedback-r11-validator-${label}-tmp"
      counter="$TMP_DIR/feedback-r11-validator-${label}.counter"
      marker="$TMP_DIR/feedback-r11-validator-${label}.marker"
      output="$TMP_DIR/feedback-r11-validator-${label}.out"
      mkdir -p "$mktemp_bin"; prepare_feedback_r6_temp_root "$temp_root"
      write_feedback_r11_mktemp_signal_wrapper "$mktemp_bin/mktemp"
      rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
        SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R11_REAL_MKTEMP="$real_mktemp" \
        SHIP_FLOW_R11_TEMP_ROOT="$temp_root" \
        SHIP_FLOW_R11_SIGNAL="$signal" SHIP_FLOW_R11_SIGNAL_OCCURRENCE="$occurrence" \
        SHIP_FLOW_R11_SIGNAL_COUNTER="$counter" SHIP_FLOW_R11_SIGNAL_MARKER="$marker" \
        run_helper_with_path "$repo" "$output" "$mktemp_bin:$gh_bin:$PATH" \
          --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
      assert_exit "R11 $signal during $seam validator exits with signal contract" "$expected" "$rc"
      if [ "$(sed -n '1p' "$marker" 2>/dev/null || true)" = "$signal|$occurrence" ]; then
        record_pass "R11 $signal reaches the $seam validator seam"
      else
        record_fail "R11 $signal reaches the $seam validator seam"
      fi
      assert_feedback_r6_temp_ownership "R11 $signal during $seam validator" "$temp_root"
    done <<'EOF'
HUP|129
INT|130
QUIT|131
TERM|143
EOF
  done <<'EOF'
1|receipt structural
2|receipt normal
3|active preflight
EOF

  while IFS='|' read -r signal expected; do
    label="$(printf '%s' "$signal" | tr '[:upper:]' '[:lower:]')"
    mktemp_bin="$TMP_DIR/feedback-r11-validator-root-${label}-bin"
    temp_root="$TMP_DIR/feedback-r11-validator-root-${label}-tmp"
    marker="$TMP_DIR/feedback-r11-validator-root-${label}.marker"
    output="$TMP_DIR/feedback-r11-validator-root-${label}.out"
    mkdir -p "$mktemp_bin"; prepare_feedback_r6_temp_root "$temp_root"
    write_feedback_r11_validator_root_signal_wrappers "$mktemp_bin"
    rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
      SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" \
      SHIP_FLOW_R11_REAL_MKTEMP="$(command -v mktemp)" SHIP_FLOW_R11_REAL_MKDIR="$(command -v mkdir)" \
      SHIP_FLOW_R11_SIGNAL="$signal" SHIP_FLOW_R11_SIGNAL_MARKER="$marker" \
      run_helper_with_path "$seed_repo" "$output" "$mktemp_bin:$gh_bin:$PATH" \
        --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
    assert_exit "R11 $signal during validator-root creation exits with signal contract" "$expected" "$rc"
    if [ "$(sed -n '1p' "$marker" 2>/dev/null || true)" = "$signal" ]; then
      record_pass "R11 $signal reaches validator-root creation"
    else
      record_fail "R11 $signal reaches validator-root creation"
    fi
    assert_feedback_r6_temp_ownership "R11 $signal during validator-root creation" "$temp_root"
  done <<'EOF'
HUP|129
INT|130
QUIT|131
TERM|143
EOF
}

run_feedback_r12_b1_tag_dwim_case() {
  local setup origin repo provider deterministic_head gh_bin git_bin registry provider_log git_log bundle_log
  local temp_root real_git real_mktemp receipt relative awaiting_oid terminal_oid_before rc
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r12-b1-tag-dwim)"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"
  gh_bin="$TMP_DIR/feedback-r12-b1-gh-bin"; git_bin="$TMP_DIR/feedback-r12-b1-git-bin"
  registry="$TMP_DIR/feedback-r12-b1.registry"; provider_log="$TMP_DIR/feedback-r12-b1-provider.log"
  git_log="$TMP_DIR/feedback-r12-b1-git.log"; bundle_log="$TMP_DIR/feedback-r12-b1-bundle.log"
  temp_root="$TMP_DIR/feedback-r12-b1-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r12-b1-awaiting.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R12-B1 fixture establishes an awaiting predecessor' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"; relative="${receipt#"$repo/"}"; awaiting_oid="$(git -C "$repo" rev-parse HEAD)"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r12-b1-built.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R12-B1 fixture publishes one terminal head' 0 "$rc"
  terminal_oid_before="$(git -C "$repo" rev-parse "$deterministic_head")"

  # A same-name tag pointing at the durable awaiting checkpoint (different
  # OID, different tree, different phase) collides with the deterministic
  # closeout branch. Git's own DWIM prefers refs/tags/<name> over
  # refs/heads/<name> for a bare short name.
  git -C "$repo" tag "$deterministic_head" "$awaiting_oid"
  if [ "$(git -C "$repo" rev-parse "refs/tags/$deterministic_head")" != \
       "$(git -C "$repo" rev-parse "refs/heads/$deterministic_head")" ]; then
    record_pass 'R12-B1 precondition carries a colliding same-name tag with a different OID'
  else
    record_fail 'R12-B1 precondition carries a colliding same-name tag with a different OID'
  fi

  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r12-b1-replay.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    r12-b1-replay: /' "$TMP_DIR/feedback-r12-b1-replay.out"; fi
  assert_exit 'R12-B1 OPEN replay under a colliding same-name tag resolves the exact branch, not the tag' 0 "$rc"
  if [ "$(git -C "$repo" rev-parse --verify "refs/heads/${deterministic_head}^{commit}")" = "$terminal_oid_before" ]; then
    record_pass 'R12-B1 OPEN replay leaves the exact deterministic branch OID unchanged'
  else
    record_fail 'R12-B1 OPEN replay leaves the exact deterministic branch OID unchanged'
  fi
  assert_feedback_r5_count 'R12-B1 OPEN replay under tag collision performs no rebuild' '^apply ' "$bundle_log" 0
  assert_feedback_r5_count 'R12-B1 OPEN replay under tag collision performs no publication' '^(seed|terminal)-push ' "$git_log" 0
}

# R12-B1 was closed at the four bare-resolution READ sites (rev-parse/cat-file/
# show/archive). FO triage folded in the two remaining SRC sites in the
# `git send-pack` refspecs `<src>:<dst>` (ensure_initial_closeout_head's seed
# push and build_optional_terminal_head's terminal force-with-lease push),
# where `<src>` was still a bare `${deterministic_head}`. Unlike the READ
# sites (which silently DWIM to a same-name tag), git's push/send-pack SRC
# resolution fails the ambiguity closed ("src refspec ... matches more than
# one") -- so the pre-fix defect is a spurious captain-prompt failure under a
# colliding tag, not silent misdirection. This case proves the fully-qualified
# fix removes that ambiguity at both send-pack call sites: the push succeeds
# and the exact branch OID (never the tag OID) lands on the remote.
run_feedback_r12_b1_send_pack_src_case() {
  local setup origin repo provider deterministic_head gh_bin git_bin registry provider_log git_log bundle_log
  local temp_root real_git real_mktemp tag_oid seed_oid remote_seed_oid terminal_oid remote_terminal_oid rc awaiting_out terminal_out

  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r12-b1-send-pack-src)"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"
  gh_bin="$TMP_DIR/feedback-r12-b1-sp-gh-bin"; git_bin="$TMP_DIR/feedback-r12-b1-sp-git-bin"
  registry="$TMP_DIR/feedback-r12-b1-sp.registry"; provider_log="$TMP_DIR/feedback-r12-b1-sp-provider.log"
  git_log="$TMP_DIR/feedback-r12-b1-sp-git.log"; bundle_log="$TMP_DIR/feedback-r12-b1-sp-bundle.log"
  temp_root="$TMP_DIR/feedback-r12-b1-sp-tmp"
  awaiting_out="$TMP_DIR/feedback-r12-b1-sp-awaiting.out"; terminal_out="$TMP_DIR/feedback-r12-b1-sp-terminal.out"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

  # Same-name tag with a DIFFERENT OID than the (not-yet-created) deterministic
  # closeout branch, present in $repo_root before the branch ever exists.
  tag_oid="$(git -C "$repo" rev-parse HEAD)"
  git -C "$repo" tag "$deterministic_head" "$tag_oid"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$repo" "$awaiting_out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R12-B1 send-pack SRC initial-head run reaches the injected awaiting checkpoint' 1 "$rc"
  # A pre-fix ambiguous-refspec push failure surfaces as the *push* detail
  # message, not this injected-stop detail -- so this line only holds once the
  # send-pack SRC actually succeeded under the colliding tag.
  assert_contains 'R12-B1 send-pack SRC initial-head push succeeded (reached the injected stop, not a push failure)' \
    '^detail=injected failure after awaiting receipt checkpoint$' "$awaiting_out"
  assert_feedback_r5_count 'R12-B1 send-pack SRC initial-head run invokes exactly one seed push' '^seed-push ' "$git_log" 1
  seed_oid="$(git -C "$repo" rev-parse "refs/heads/${deterministic_head}")"
  remote_seed_oid="$(git -C "$origin" rev-parse "refs/heads/${deterministic_head}" 2>/dev/null || true)"
  if [ -n "$remote_seed_oid" ] && [ "$seed_oid" = "$remote_seed_oid" ] && [ "$seed_oid" != "$tag_oid" ]; then
    record_pass 'R12-B1 initial-head send-pack publishes the exact branch OID, never the colliding tag OID'
  else
    record_fail 'R12-B1 initial-head send-pack publishes the exact branch OID, never the colliding tag OID'
  fi

  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$terminal_out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    r12-b1-send-pack-src-terminal: /' "$terminal_out"; fi
  assert_exit 'R12-B1 send-pack SRC terminal-apply run completes to one bound closeout PR' 0 "$rc"
  assert_feedback_r5_count 'R12-B1 send-pack SRC terminal-apply run invokes exactly one terminal push' '^terminal-push ' "$git_log" 1
  terminal_oid="$(git -C "$repo" rev-parse "refs/heads/${deterministic_head}")"
  remote_terminal_oid="$(git -C "$origin" rev-parse "refs/heads/${deterministic_head}" 2>/dev/null || true)"
  if [ -n "$remote_terminal_oid" ] && [ "$terminal_oid" = "$remote_terminal_oid" ] && \
     [ "$terminal_oid" != "$tag_oid" ] && [ "$terminal_oid" != "$seed_oid" ]; then
    record_pass 'R12-B1 terminal-apply send-pack publishes the exact branch OID, never the colliding tag OID'
  else
    record_fail 'R12-B1 terminal-apply send-pack publishes the exact branch OID, never the colliding tag OID'
  fi
  if [ "$(git -C "$repo" rev-parse "refs/tags/${deterministic_head}")" = "$tag_oid" ]; then
    record_pass 'R12-B1 send-pack SRC case leaves the colliding tag untouched throughout'
  else
    record_fail 'R12-B1 send-pack SRC case leaves the colliding tag untouched throughout'
  fi
}

run_feedback_r12_b2_ancestry_case() {
  local setup origin repo provider deterministic_head gh_bin git_bin registry provider_log git_log bundle_log
  local temp_root real_git real_mktemp receipt relative awaiting_oid terminal_oid rc
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r12-b2-ancestry)"
  IFS='|' read -r origin repo provider <<<"$setup"
  deterministic_head="$(feedback_r5_deterministic_head)"
  gh_bin="$TMP_DIR/feedback-r12-b2-gh-bin"; git_bin="$TMP_DIR/feedback-r12-b2-git-bin"
  registry="$TMP_DIR/feedback-r12-b2.registry"; provider_log="$TMP_DIR/feedback-r12-b2-provider.log"
  git_log="$TMP_DIR/feedback-r12-b2-git.log"; bundle_log="$TMP_DIR/feedback-r12-b2-bundle.log"
  temp_root="$TMP_DIR/feedback-r12-b2-tmp"
  mkdir -p "$gh_bin" "$git_bin"; : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  write_feedback_r5_b1_gh "$gh_bin/gh"; write_feedback_r6_git_wrapper "$git_bin/git"
  write_feedback_r6_mktemp_wrapper "$git_bin/mktemp"; prepare_feedback_r6_temp_root "$temp_root"
  real_git="$(command -v git)"; real_mktemp="$(command -v mktemp)"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r12-b2-awaiting.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R12-B2 fixture establishes awaiting predecessor A' 1 "$rc"
  receipt="$(feedback_r5_receipt_path "$repo")"; relative="${receipt#"$repo/"}"; awaiting_oid="$(git -C "$repo" rev-parse HEAD)"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r12-b2-built.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R12-B2 fixture publishes terminal head T built from A' 0 "$rc"
  terminal_oid="$(git -C "$repo" rev-parse "$deterministic_head")"

  # Concurrent main movement after T was built from A: a later main-only
  # commit B does not touch the receipt path, so it silently inherits the
  # exact same awaiting bytes as A while never being an ancestor of T.
  git -C "$repo" commit -q --allow-empty -m 'fixture: concurrent main movement after terminal was built from A'
  if ! git -C "$repo" merge-base --is-ancestor "$(git -C "$repo" rev-parse HEAD)" "$terminal_oid"; then
    record_pass 'R12-B2 precondition B carries identical awaiting bytes but is not an ancestor of T'
  else
    record_fail 'R12-B2 precondition B carries identical awaiting bytes but is not an ancestor of T'
  fi

  land_feedback_terminal_head "$repo" "$deterministic_head" "$relative"
  set_feedback_registry_merge "$registry" "$terminal_oid"
  if [ "$(git -C "$repo" rev-parse 'HEAD^2')" = "$terminal_oid" ]; then
    record_pass 'R12-B2 precondition lands T as the second parent of the terminal merge, after B'
  else
    record_fail 'R12-B2 precondition lands T as the second parent of the terminal merge, after B'
  fi

  : >"$provider_log"; : >"$git_log"; : >"$bundle_log"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$provider_log" SHIP_FLOW_R5_ORIGIN="$origin" SHIP_FLOW_R6_REAL_GIT="$real_git" \
    SHIP_FLOW_R6_GIT_LOG="$git_log" SHIP_FLOW_R6_REAL_MKTEMP="$real_mktemp" SHIP_FLOW_R6_TEMP_ROOT="$temp_root" \
    SHIP_FLOW_CLOSEOUT_BUNDLE_LOG="$bundle_log" run_helper_with_path "$repo" \
      "$TMP_DIR/feedback-r12-b2-recovery.out" "$git_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  if [ "$rc" != 0 ]; then sed 's/^/    r12-b2-recovery: /' "$TMP_DIR/feedback-r12-b2-recovery.out"; fi
  assert_exit 'R12-B2 landed recovery accepts the true ancestor A despite a newer non-ancestor carrier B' 0 "$rc"
  assert_contains 'R12-B2 landed recovery converges to terminal no-op' '^reason=closeout-pr-terminal-noop$' "$TMP_DIR/feedback-r12-b2-recovery.out"
  assert_feedback_r5_count 'R12-B2 recovery performs no publication' '^(seed|terminal)-push ' "$git_log" 0
  assert_feedback_r5_count 'R12-B2 recovery performs no provider effect' '^effect (create|ready) ' "$provider_log" 0
  assert_feedback_r5_count 'R12-B2 recovery performs no bundle application' '^apply ' "$bundle_log" 0
}

write_feedback_r12_w1_broken_validator_root_mkdir() {
  local bin="$1"
  cat >"$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
for arg in "$@"; do
  case "$arg" in
    */ship-flow-closeout-validator.*) exit 1 ;;
  esac
done
exec "${SHIP_FLOW_R12_REAL_MKDIR:?missing real mkdir}" "$@"
EOF
  chmod +x "$bin"
}

run_feedback_r12_w1_validator_root_case() {
  local setup origin repo provider gh_bin mkdir_bin registry temp_root real_mkdir rc
  setup="$(prepare_feedback_r3_b1_main_only_clone feedback-r12-w1-validator-root)"
  IFS='|' read -r origin repo provider <<<"$setup"
  gh_bin="$TMP_DIR/feedback-r12-w1-gh-bin"; mkdir -p "$gh_bin"
  write_feedback_r5_b1_gh "$gh_bin/gh"
  temp_root="$TMP_DIR/feedback-r12-w1-tmp"; prepare_feedback_r6_temp_root "$temp_root"
  registry="$TMP_DIR/feedback-r12-w1.registry"

  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$TMP_DIR/feedback-r12-w1-provider.log" SHIP_FLOW_R5_ORIGIN="$origin" \
    SHIP_FLOW_CLOSEOUT_FAILPOINT=after-awaiting \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r12-w1-awaiting.out" "$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R12-W1 fixture establishes an awaiting receipt-only checkpoint' 1 "$rc"

  mkdir_bin="$TMP_DIR/feedback-r12-w1-mkdir-bin"; mkdir -p "$mkdir_bin"
  real_mkdir="$(command -v mkdir)"
  write_feedback_r12_w1_broken_validator_root_mkdir "$mkdir_bin/mkdir"
  rc="$(TMPDIR="$temp_root" SHIP_FLOW_R5_PROVIDER_FILE="$provider" SHIP_FLOW_R5_REGISTRY="$registry" \
    SHIP_FLOW_R5_LOG="$TMP_DIR/feedback-r12-w1-provider2.log" SHIP_FLOW_R5_ORIGIN="$origin" \
    SHIP_FLOW_R12_REAL_MKDIR="$real_mkdir" \
    run_helper_with_path "$repo" "$TMP_DIR/feedback-r12-w1-broken-root.out" "$mkdir_bin:$gh_bin:$PATH" \
      --entity merged-fixture-entity --pr-provider gh --closeout-mode pull-request)"
  assert_exit 'R12-W1 validator root creation failure fails closed with the REJECT contract' 2 "$rc"
  assert_contains 'R12-W1 validator root creation failure reports a stable reason' '^reason=closeout-checkpoint-conflict$' "$TMP_DIR/feedback-r12-w1-broken-root.out"
  assert_not_contains 'R12-W1 validator root creation failure never surfaces a raw mktemp error' 'mktemp:' "$TMP_DIR/feedback-r12-w1-broken-root.out"
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
  assert_exit "dry-run active legacy done rejects" 2 "$rc"
  assert_contains "dry-run active legacy done reports stable landing reason" '^reason=landing-anchor-missing$' "$TMP_DIR/dry-run-active-done.out"
  assert_file_exists "dry-run active legacy done keeps active index" "$active_done_repo/docs/ship-flow/merged-fixture-entity/index.md"
  assert_path_missing "dry-run active legacy done creates no archive" "$active_done_repo/docs/ship-flow/_archive/merged-fixture-entity"
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
  local before_head before_tree rc
  before_head="$(git -C "$active_done_repo" rev-parse HEAD)"
  before_tree="$(hash_tree "$active_done_repo/docs/ship-flow")"
  rc="$(run_helper "$active_done_repo" "$TMP_DIR/active-done.out" \
    --entity merged-fixture-entity \
    --pr-provider fixture \
    --pr-fixture "${FIXTURE_ROOT}/pr-merged.env")"
  assert_exit "active legacy done rejects" 2 "$rc"
  assert_contains "active legacy done reports stable landing reason" '^reason=landing-anchor-missing$' "$TMP_DIR/active-done.out"
  assert_file_exists "active legacy done keeps active index" "${active_done_repo}/docs/ship-flow/merged-fixture-entity/index.md"
  assert_path_missing "active legacy done creates no archive" "${active_done_repo}/docs/ship-flow/_archive/merged-fixture-entity"
  if [ "$before_head" = "$(git -C "$active_done_repo" rev-parse HEAD)" ] && \
     [ "$before_tree" = "$(hash_tree "$active_done_repo/docs/ship-flow")" ]; then
    record_pass "active legacy done preserves HEAD and workflow bytes"
  else
    record_fail "active legacy done preserves HEAD and workflow bytes"
  fi

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
  if [ "$rc" != 1 ]; then sed 's/^/    optional-merged-tampered: /' "$TMP_DIR/optional-merged-tampered.out"; fi
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
  if [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r12-b1-b2-w1 ]; then
    case "${SHIP_FLOW_R12_ONLY:-all}" in
      tag-dwim) run_feedback_r12_b1_tag_dwim_case ;;
      send-pack-src) run_feedback_r12_b1_send_pack_src_case ;;
      ancestry) run_feedback_r12_b2_ancestry_case ;;
      validator-root) run_feedback_r12_w1_validator_root_case ;;
      all)
        run_feedback_r12_b1_tag_dwim_case
        run_feedback_r12_b1_send_pack_src_case
        run_feedback_r12_b2_ancestry_case
        run_feedback_r12_w1_validator_root_case
        ;;
      *) record_fail "unknown SHIP_FLOW_R12_ONLY selection" ;;
    esac
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r11-b1-b2-b3 ]; then
    case "${SHIP_FLOW_R11_ONLY:-all}" in
      history) run_feedback_r11_mature_main_case ;;
      provider) run_feedback_r11_provider_oid_case ;;
      signals) run_feedback_r11_validator_signal_case ;;
      all)
        run_feedback_r11_mature_main_case
        run_feedback_r11_provider_oid_case
        run_feedback_r11_validator_signal_case
        ;;
      *) record_fail "unknown SHIP_FLOW_R11_ONLY selection" ;;
    esac
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r10-b1-b2 ]; then
    if [ "${SHIP_FLOW_R10_ONLY:-}" = terminal ]; then
      run_feedback_r10_terminal_predecessor_case
    else
      run_feedback_r10_endpoint_authority_case
      run_feedback_r10_terminal_predecessor_case
      run_feedback_r10_terminal_race_case
      run_feedback_r10_refresh_and_legacy_case
      run_feedback_r10_transport_matrix
    fi
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r9-b1-b2 ]; then
    run_feedback_r9_alias_and_rewrite_case
    run_feedback_r9_bound_endpoint_drift_case
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r8-b1 ]; then
    run_feedback_r8_multi_pushurl_case
    run_feedback_r8_invalid_destination_matrix
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r7-b1 ]; then
    run_feedback_r7_atomic_seed_race_case
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r5-b1 ]; then
    run_feedback_r5_b1_provider_retry_case
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r4-b1 ]; then
    run_feedback_r4_foreign_cwd_case
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r3-b1 ]; then
    run_feedback_r3_b1_main_only_case
    run_feedback_r3_review_blockers_case
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r2-b2-integration ]; then
    run_feedback_r2_b2_integration_case
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-r2-f1 ]; then
    run_feedback_r2_f1_case
  elif [ "${SHIP_FLOW_CLOSEOUT_CASE:-}" = feedback-f1 ]; then
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
