#!/usr/bin/env bash
# test-warn-state-drift.sh - SessionStart state-drift hook contract
# Expected runtime: ~22-25s (many git-fixture operations). Allow >=30s timeout in CI runners.

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HOOK="${PLUGIN_ROOT}/hooks/warn-state-drift.sh"
HOOKS_JSON="${PLUGIN_ROOT}/hooks/hooks.json"
INVARIANTS_DOC="${PLUGIN_ROOT}/INVARIANTS.md"
PR_MERGE_PATHS_DOC="${PLUGIN_ROOT}/references/pr-merge-paths.md"

PASS=0
FAIL=0
ERRORS=()
TMP_DIR=""
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
archived:
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
archived:
---

# ${slug}
EOF
}

write_folder_closeout_evidence() {
  local workflow_dir="$1"
  local slug="$2"
  local pr="$3"
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' \
    > "${workflow_dir}/${slug}/review.md"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' \
    '- Preserve SessionStart closeout evidence.' '' '### Verdict' \
    'merge_method_intent: rebase' "pr: \"${pr}\"" \
    > "${workflow_dir}/${slug}/ship.md"
}

setup_repo() {
  local repo="$1"
  local auto_fix="${2:-off}"
  git init -q -b main "$repo"
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
state_file="${GH_STATE_DIR}/${pr}.state"
[ -f "$state_file" ] || exit 1
count_file="${GH_STATE_DIR}/${pr}.count"
count=0
[ -f "$count_file" ] && count="$(cat "$count_file")"
count=$((count + 1))
printf '%s' "$count" > "$count_file"
states="$(cat "$state_file")"
state="$(printf '%s\n' "$states" | awk -v n="$count" -F, '{ if (n <= NF) print $n; else print $NF }')"
printf '%s\n' "$state"
EOF
  chmod +x "${bin_dir}/gh"
}

write_fixture_status_bin() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

if [ -n "${SHIP_FLOW_STATUS_LOG:-}" ]; then
  printf '%s\n' "$*" >> "$SHIP_FLOW_STATUS_LOG"
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
  if [ "$include_archived" = yes ]; then
    if [ -f "${workflow_dir}/_archive/${slug_value}/index.md" ]; then
      printf '%s\n' "${workflow_dir}/_archive/${slug_value}/index.md"
      return
    fi
    if [ -f "${workflow_dir}/_archive/${slug_value}.md" ]; then
      printf '%s\n' "${workflow_dir}/_archive/${slug_value}.md"
      return
    fi
    return 1
  fi
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
    slug="${ref#archive:}"
    path="$(entity_path_for_slug "$slug")"
    printf 'slug=%s path=%s\n' "$slug" "$path"
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
    update_frontmatter_field "$path" archived "2026-07-15T00:01:00Z"
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

write_fixture_reconciler() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$SHIP_FLOW_RECONCILER_LOG"
fixture_state="${SHIP_FLOW_RECONCILER_STATE:-reconciled}"
fixture_reason="${SHIP_FLOW_RECONCILER_REASON:-merged-pr-reconciled}"
[ "$fixture_state" = "__EMPTY__" ] && fixture_state=""
[ "$fixture_reason" = "__EMPTY__" ] && fixture_reason=""
printf '%s\n' \
  "verdict=${SHIP_FLOW_RECONCILER_VERDICT:-PROCEED}" \
  "entity=${SHIP_FLOW_RECONCILER_ENTITY:-flat-merged}" \
  "pr=${SHIP_FLOW_RECONCILER_PR:-131}" \
  "pr_state=${SHIP_FLOW_RECONCILER_PR_STATE:-MERGED}" \
  "terminal_action=${SHIP_FLOW_RECONCILER_ACTION:-closeout_bundle}" \
  'worktree_cleanup=not_applicable' \
  'branch_cleanup=not_applicable' \
  "reason=$fixture_reason" \
  "state=$fixture_state" \
  "detail=${SHIP_FLOW_RECONCILER_DETAIL:-fixture reconciled}"
exit "${SHIP_FLOW_RECONCILER_EXIT:-0}"
EOF
  chmod +x "$bin"
}

write_fixture_mixed_reconciler() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$SHIP_FLOW_RECONCILER_LOG"
entity=""
pr=""
while [ "$#" -gt 0 ]; do
  case "$1" in
    --entity) entity="$2"; shift 2 ;;
    *) shift ;;
  esac
done

case "$entity" in
  flat-success)
    pr=301
    state=reconciled
    action=closeout_bundle
    reason=merged-pr-reconciled
    ;;
  flat-blocked)
    pr=302
    state=pr_open_noop
    action=none
    reason=pr-open
    ;;
  *) exit 2 ;;
esac

printf '%s\n' \
  'verdict=PROCEED' \
  "entity=$entity" \
  "pr=$pr" \
  'pr_state=MERGED' \
  "terminal_action=$action" \
  'worktree_cleanup=not_applicable' \
  'branch_cleanup=not_applicable' \
  "reason=$reason" \
  "state=$state" \
  'detail=mixed fixture result'
EOF
  chmod +x "$bin"
}

write_fixture_git_spy() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$SHIP_FLOW_GIT_LOG"
exec "$SHIP_FLOW_REAL_GIT" "$@"
EOF
  chmod +x "$bin"
}

write_fixture_actual_reconciler_wrapper() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail

printf '%s\n' "$*" >> "$SHIP_FLOW_RECONCILER_LOG"
exec "$SHIP_FLOW_ACTUAL_RECONCILER" "$@" \
  --pr-provider fixture \
  --pr-fixture "$SHIP_FLOW_ACTUAL_PROVIDER_FIXTURE"
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
      SHIP_FLOW_STATUS_LOG="${SHIP_FLOW_STATUS_LOG:-}" \
      SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="${SHIP_FLOW_CLOSEOUT_RECONCILER_BIN:-}" \
      SHIP_FLOW_RECONCILER_LOG="${SHIP_FLOW_RECONCILER_LOG:-$TMP_DIR/reconciler.log}" \
      SHIP_FLOW_RECONCILER_VERDICT="${SHIP_FLOW_RECONCILER_VERDICT:-}" \
      SHIP_FLOW_RECONCILER_STATE="${SHIP_FLOW_RECONCILER_STATE:-}" \
      SHIP_FLOW_RECONCILER_ACTION="${SHIP_FLOW_RECONCILER_ACTION:-}" \
      SHIP_FLOW_RECONCILER_REASON="${SHIP_FLOW_RECONCILER_REASON:-}" \
      SHIP_FLOW_RECONCILER_EXIT="${SHIP_FLOW_RECONCILER_EXIT:-}" \
      SHIP_FLOW_GIT_LOG="${SHIP_FLOW_GIT_LOG:-}" \
      SHIP_FLOW_REAL_GIT="${SHIP_FLOW_REAL_GIT:-}" \
      SHIP_FLOW_ACTUAL_RECONCILER="${SHIP_FLOW_ACTUAL_RECONCILER:-}" \
      SHIP_FLOW_ACTUAL_PROVIDER_FIXTURE="${SHIP_FLOW_ACTUAL_PROVIDER_FIXTURE:-}" \
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

run_doc_contract_case() {
  if python3 - "$HOOKS_JSON" <<'PY'
import json,sys
hooks=json.load(open(sys.argv[1]))["hooks"]["SessionStart"]
raise SystemExit(0 if hooks[0]["hooks"][0]["timeout"] == 120 else 1)
PY
  then
    record_pass "SessionStart hook timeout is 120 seconds"
  else
    record_fail "SessionStart hook timeout is 120 seconds"
  fi
  assert_contains "hook bounds each reconciler child to 90 seconds" \
    'timeout 90 "\$reconciler_bin"' "$HOOK"
  assert_contains "merge-path doc converges SessionStart on receipt-bound reconciler" \
    'delegates exactly one `--closeout-mode direct` call' \
    "$PR_MERGE_PATHS_DOC"
  assert_contains "merge-path doc names the receipt-bound reconciler target" \
    '`bin/merged-pr-closeout-reconciler.sh`' "$PR_MERGE_PATHS_DOC"
  assert_contains "merge-path doc records one canonical folder per SessionStart" \
    'at most one canonical folder entity per SessionStart' "$PR_MERGE_PATHS_DOC"
  assert_contains "merge-path doc records flat warning-only compatibility" \
    'Flat legacy `.md` entities remain warning-only' "$PR_MERGE_PATHS_DOC"
  assert_contains "merge-path doc keeps receipt as sole idempotency sentinel" \
    'The closeout receipt remains the sole idempotency sentinel' \
    "$PR_MERGE_PATHS_DOC"
  assert_not_contains "merge-path doc does not add a second sentinel or deferred terminal state" \
    'pr-merge:[0-9]+|debrief_due' "$PR_MERGE_PATHS_DOC"
  assert_contains "canonical invariants record receipt-bound SessionStart delegation" \
    'v1.3.0.*receipt-bound closeout reconciler' "$INVARIANTS_DOC"
  assert_contains "canonical invariants record 120/90 second bounds" \
    '120-second SessionStart budget.*90-second child bound' "$INVARIANTS_DOC"
  assert_contains "canonical invariants record one folder and flat warning-only" \
    'one canonical folder entity per SessionStart.*flat legacy entities remain warning-only' "$INVARIANTS_DOC"
  assert_contains "canonical invariants forbid hook-owned terminal mutation" \
    'never owns status, archive, staging, or commit mutation' "$INVARIANTS_DOC"
}

run_flat_merged_warning_only_case() {
  local repo="$TMP_DIR/flat-merged-warning-only-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-legacy" "ship" "#131"
  git -C "$repo" add -- docs/ship-flow/flat-legacy.md
  git -C "$repo" commit -qm "add flat legacy entity" -- docs/ship-flow/flat-legacy.md
  set_pr_states 131 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/flat-merged-warning-only.log"
  rc="$(run_hook "$repo" "$TMP_DIR/flat-merged-warning-only.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""

  assert_exit "flat merged warning-only exits advisory success" 0 "$rc"
  assert_path_missing "flat merged warning-only invokes zero reconciler calls" \
    "$TMP_DIR/flat-merged-warning-only.log"
  assert_contains "flat merged warning-only remains Rule A pending" \
    'flat-legacy.*PR #131 MERGED' "$TMP_DIR/flat-merged-warning-only.out"
  assert_contains "flat merged warning-only explains zero-call compatibility" \
    'flat legacy entity; warning-only, no reconciler call' \
    "$TMP_DIR/flat-merged-warning-only.out"
  assert_contains "flat merged warning-only requires migration before reconciliation" \
    'migrate them to the canonical folder artifact contract before reconciliation' \
    "$TMP_DIR/flat-merged-warning-only.out"
  assert_not_contains "flat merged warning-only is not given a direct reconciler instruction" \
    'Before new execute work, run .*merged-pr-closeout-reconciler.*for each' \
    "$TMP_DIR/flat-merged-warning-only.out"
  assert_path_exists "flat merged warning-only remains active" \
    "${repo}/docs/ship-flow/flat-legacy.md"
}

run_one_folder_per_session_case() {
  local repo="$TMP_DIR/one-folder-per-session-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-first" "ship" "#301"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-first" "#301"
  write_folder_entity "${repo}/docs/ship-flow" "folder-second" "ship" "#302"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-second" "#302"
  git -C "$repo" add -- docs/ship-flow/folder-first docs/ship-flow/folder-second
  git -C "$repo" commit -qm "add two canonical folder entities" -- docs/ship-flow/folder-first docs/ship-flow/folder-second
  set_pr_states 301 "MERGED"
  set_pr_states 302 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/one-folder-per-session.log"
  rc="$(run_hook "$repo" "$TMP_DIR/one-folder-per-session.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""

  assert_exit "one folder per SessionStart exits advisory success" 0 "$rc"
  assert_equals "one folder per SessionStart invokes exactly one reconciler" 1 \
    "$(wc -l < "$TMP_DIR/one-folder-per-session.log" | tr -d '[:space:]')"
  assert_contains "one folder per SessionStart defers the other folder" \
    'folder-second.*PR #302 MERGED' "$TMP_DIR/one-folder-per-session.out"
  assert_contains "one folder per SessionStart preserves Rule A pending section" \
    '\*\*Rule A\*\*' "$TMP_DIR/one-folder-per-session.out"
}

run_reconciler_timeout_case() {
  local repo="$TMP_DIR/reconciler-timeout-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-timeout" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-timeout" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-timeout
  git -C "$repo" commit -qm "add timeout folder entity" -- docs/ship-flow/folder-timeout
  set_pr_states 131 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/reconciler-timeout.log"
  SHIP_FLOW_RECONCILER_EXIT=124
  rc="$(run_hook "$repo" "$TMP_DIR/reconciler-timeout.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""
  SHIP_FLOW_RECONCILER_EXIT=""

  assert_exit "reconciler timeout remains advisory" 0 "$rc"
  assert_contains "reconciler timeout is a stable fail-closed classification" \
    'reconciler timed out \(state=.*action=.*reason=timeout, exit=124\)' \
    "$TMP_DIR/reconciler-timeout.out"
  assert_not_contains "reconciler timeout never claims success" \
    'Auto-fixed / reconciled' "$TMP_DIR/reconciler-timeout.out"
}

prepare_actual_reconciler_repo() {
  local repo="$1"
  local fixture="$2"
  local base source_one source_two anchor

  setup_repo "$repo" execute
  mkdir -p "$repo/docs/ship-flow/_mods"
  printf '%s\n' '---' 'name: pr-merge' 'standing: true' '---' '' \
    '## Agent Prompt' '' 'Fixture merge hook.' \
    > "$repo/docs/ship-flow/_mods/pr-merge.md"
  printf '%s\n' '# Roadmap' '' '## Now' '<!-- section:now -->' \
    '| Entity | Title |' '| --- | --- |' \
    '| folder-integrated | folder-integrated |' '<!-- /section:now -->' '' \
    '## Shipped' '<!-- section:shipped -->' \
    '| Entity | Title | Shipped |' '| --- | --- | --- |' \
    '<!-- /section:shipped -->' > "$repo/ROADMAP.md"
  git -C "$repo" add -- ROADMAP.md docs/ship-flow/_mods/pr-merge.md
  git -C "$repo" commit -qm "fixture: add closeout contract"
  base="$(git -C "$repo" rev-parse HEAD)"

  git -C "$repo" checkout -qb integration-topic "$base"
  write_folder_entity "$repo/docs/ship-flow" "folder-integrated" "ship" "#131"
  printf '%s\n' '# Review' '' '## Verdict' '' 'PASSED' \
    > "$repo/docs/ship-flow/folder-integrated/review.md"
  git -C "$repo" add -- docs/ship-flow/folder-integrated/index.md docs/ship-flow/folder-integrated/review.md
  git -C "$repo" commit -qm "implementation: add reviewed entity"
  source_one="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' '# Ship' '' '## Todo Closeout Digest' '' \
    '- Preserve actual SessionStart integration evidence.' '' \
    '### Verdict' 'merge_method_intent: rebase' 'pr: "#131"' \
    > "$repo/docs/ship-flow/folder-integrated/ship.md"
  git -C "$repo" add -- docs/ship-flow/folder-integrated/ship.md
  git -C "$repo" commit -qm "implementation: add ship evidence"
  source_two="$(git -C "$repo" rev-parse HEAD)"

  git -C "$repo" checkout -q main
  git -C "$repo" cherry-pick "$source_one" "$source_two" >/dev/null
  anchor="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' 'provider=fixture' 'number=131' 'state=MERGED' \
    'merged_at=2026-07-15T00:00:00Z' 'head_ref=integration-topic' \
    'base_ref=main' 'url=https://github.com/example/repo/pull/131' \
    'repository=example/repo' "landing_anchor=$anchor" \
    "source_commits=$source_one,$source_two" 'pr_commit_count=2' > "$fixture"
}

run_actual_reconciler_folder_case() {
  local repo="$TMP_DIR/actual-reconciler-folder-repo"
  local fixture="$TMP_DIR/actual-reconciler-provider.env"
  local before rc receipt
  prepare_actual_reconciler_repo "$repo" "$fixture"
  set_pr_states 131 "MERGED"
  before="$(git -C "$repo" rev-parse HEAD)"

  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/actual-reconciler-wrapper"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/actual-reconciler-folder.log"
  SHIP_FLOW_ACTUAL_RECONCILER="$PLUGIN_ROOT/bin/merged-pr-closeout-reconciler.sh"
  SHIP_FLOW_ACTUAL_PROVIDER_FIXTURE="$fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/actual-reconciler-folder.out")"
  SHIP_FLOW_STATUS_BIN=""
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""
  SHIP_FLOW_ACTUAL_RECONCILER=""
  SHIP_FLOW_ACTUAL_PROVIDER_FIXTURE=""

  if ! grep -q 'Auto-fixed / reconciled' "$TMP_DIR/actual-reconciler-folder.out"; then
    sed 's/^/    actual-reconciler: /' "$TMP_DIR/actual-reconciler-folder.out"
  fi
  assert_exit "actual reconciler folder hook exits advisory success" 0 "$rc"
  assert_contains "actual reconciler folder is classified as reconciled" \
    'Auto-fixed / reconciled' "$TMP_DIR/actual-reconciler-folder.out"
  assert_equals "actual reconciler folder creates exactly one terminal commit" 1 \
    "$(git -C "$repo" rev-list --count "$before..HEAD")"
  assert_path_missing "actual reconciler folder removes active entity" \
    "$repo/docs/ship-flow/folder-integrated"
  assert_file_exists "actual reconciler folder archives canonical index" \
    "$repo/docs/ship-flow/_archive/folder-integrated/index.md"
  receipt="$(find "$repo/docs/ship-flow/_closeouts" -type f -name '*.json' -print -quit 2>/dev/null || true)"
  if [ -n "$receipt" ]; then
    record_pass "actual reconciler folder lands receipt sentinel"
  else
    record_fail "actual reconciler folder lands receipt sentinel"
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

run_execute_merged_case() {
  local repo="$TMP_DIR/execute-merged-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
  set_pr_states 131 "MERGED"

  local before_head rc
  before_head="$(git -C "$repo" rev-parse HEAD)"
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/execute-merged.reconciler.log"
  rc="$(run_hook "$repo" "$TMP_DIR/execute-merged.out")"
  SHIP_FLOW_STATUS_BIN=""
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""

  assert_exit "execute merged exits success" 0 "$rc"
  assert_contains "execute merged reports reconciled" 'Auto-fixed / reconciled' "$TMP_DIR/execute-merged.out"
  assert_equals "execute merged leaves commit ownership to reconciler" "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_path_exists "execute merged leaves fixture entity active" "${repo}/docs/ship-flow/folder-merged/index.md"
}

run_reconciler_delegation_case() {
  local repo="$TMP_DIR/reconciler-delegation-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
  set_pr_states 131 "MERGED"

  local before_head rc calls
  before_head="$(git -C "$repo" rev-parse HEAD)"
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  SHIP_FLOW_STATUS_LOG="$TMP_DIR/reconciler-delegation.status.log"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/reconciler-delegation.log"
  SHIP_FLOW_GIT_LOG="$TMP_DIR/reconciler-delegation.git.log"
  SHIP_FLOW_REAL_GIT="$REAL_GIT"
  HOOK_PATH="$TMP_DIR/git-spy-bin:$PATH"
  rc="$(run_hook "$repo" "$TMP_DIR/reconciler-delegation.out")"
  SHIP_FLOW_STATUS_BIN=""
  SHIP_FLOW_STATUS_LOG=""
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""
  SHIP_FLOW_GIT_LOG=""
  SHIP_FLOW_REAL_GIT=""
  unset HOOK_PATH
  calls="$(wc -l < "$TMP_DIR/reconciler-delegation.log" 2>/dev/null || echo 0)"
  calls="$(printf '%s' "$calls" | tr -d '[:space:]')"

  assert_exit "reconciler delegation exits success" 0 "$rc"
  assert_equals "reconciler delegation invokes reconciler exactly once" 1 "$calls"
  assert_contains "reconciler delegation passes workflow, entity, and direct mode" \
    '^--workflow-dir docs/ship-flow --entity folder-merged --closeout-mode direct$' \
    "$TMP_DIR/reconciler-delegation.log"
  assert_contains "reconciler real success tuple is classified as reconciled" \
    'Auto-fixed / reconciled' "$TMP_DIR/reconciler-delegation.out"
  assert_not_contains "reconciler real success tuple is not classified as blocked" \
    'Auto-fix blocked' "$TMP_DIR/reconciler-delegation.out"
  assert_file_exists "reconciler delegation captures hook Git calls" \
    "$TMP_DIR/reconciler-delegation.git.log"
  assert_contains "reconciler delegation preserves Git status safety read" \
    '^status --porcelain$' "$TMP_DIR/reconciler-delegation.git.log"
  assert_not_contains "reconciler delegation never invokes git add" \
    '^add([[:space:]]|$)' "$TMP_DIR/reconciler-delegation.git.log"
  assert_not_contains "reconciler delegation never invokes git commit" \
    '^commit([[:space:]]|$)' "$TMP_DIR/reconciler-delegation.git.log"
  assert_path_missing "reconciler delegation never invokes raw status helper" "$TMP_DIR/reconciler-delegation.status.log"
  assert_equals "reconciler delegation hook never creates its own commit" "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  assert_path_exists "reconciler delegation leaves mutation ownership to spy" "${repo}/docs/ship-flow/folder-merged/index.md"
}

run_reconciler_open_noop_case() {
  local repo="$TMP_DIR/reconciler-open-noop-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
  set_pr_states 131 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/reconciler-open-noop.log"
  SHIP_FLOW_RECONCILER_STATE="pr_open_noop"
  SHIP_FLOW_RECONCILER_ACTION="none"
  SHIP_FLOW_RECONCILER_REASON="pr-open"
  rc="$(run_hook "$repo" "$TMP_DIR/reconciler-open-noop.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""
  SHIP_FLOW_RECONCILER_STATE=""
  SHIP_FLOW_RECONCILER_ACTION=""
  SHIP_FLOW_RECONCILER_REASON=""

  assert_exit "reconciler OPEN/no-op exits advisory success" 0 "$rc"
  assert_contains "reconciler OPEN/no-op is classified without terminal mutation" \
    'PR became OPEN during reconciliation; no terminal mutation was applied' \
    "$TMP_DIR/reconciler-open-noop.out"
  assert_not_contains "reconciler OPEN/no-op is not duplicated as Rule A pending" \
    '\*\*Rule A\*\*' "$TMP_DIR/reconciler-open-noop.out"
}

run_reconciler_structured_failure_case() {
  local repo="$TMP_DIR/reconciler-structured-failure-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
  set_pr_states 131 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/reconciler-structured-failure.log"
  SHIP_FLOW_RECONCILER_VERDICT="PROMPT_CAPTAIN"
  SHIP_FLOW_RECONCILER_STATE="__EMPTY__"
  SHIP_FLOW_RECONCILER_ACTION="none"
  SHIP_FLOW_RECONCILER_REASON="landing-anchor-unreachable"
  SHIP_FLOW_RECONCILER_EXIT="1"
  rc="$(run_hook "$repo" "$TMP_DIR/reconciler-structured-failure.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""
  SHIP_FLOW_RECONCILER_VERDICT=""
  SHIP_FLOW_RECONCILER_STATE=""
  SHIP_FLOW_RECONCILER_ACTION=""
  SHIP_FLOW_RECONCILER_REASON=""
  SHIP_FLOW_RECONCILER_EXIT=""

  assert_exit "reconciler structured failure remains advisory" 0 "$rc"
  assert_contains "reconciler structured failure reports machine reason" \
    'reconciler failed \(verdict=PROMPT_CAPTAIN, reason=landing-anchor-unreachable, exit=1\)' \
    "$TMP_DIR/reconciler-structured-failure.out"
  assert_not_contains "reconciler structured failure does not report human detail" \
    'fixture reconciled' "$TMP_DIR/reconciler-structured-failure.out"
  assert_not_contains "reconciler structured failure is not duplicated as Rule A pending" \
    '\*\*Rule A\*\*' "$TMP_DIR/reconciler-structured-failure.out"
}

run_reconciler_awaiting_case() {
  local repo="$TMP_DIR/reconciler-awaiting-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
  set_pr_states 131 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/reconciler-awaiting.log"
  SHIP_FLOW_RECONCILER_STATE="closeout_pr_awaiting_merge"
  SHIP_FLOW_RECONCILER_ACTION="none"
  SHIP_FLOW_RECONCILER_REASON="closeout-pr-awaiting-merge"
  rc="$(run_hook "$repo" "$TMP_DIR/reconciler-awaiting.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""
  SHIP_FLOW_RECONCILER_STATE=""
  SHIP_FLOW_RECONCILER_ACTION=""
  SHIP_FLOW_RECONCILER_REASON=""

  assert_exit "reconciler awaiting closeout PR remains advisory" 0 "$rc"
  assert_contains "reconciler awaiting closeout PR is classified explicitly" \
    'receipt-bound closeout PR is awaiting merge; no direct terminal mutation was applied' \
    "$TMP_DIR/reconciler-awaiting.out"
  assert_not_contains "reconciler awaiting closeout PR is not duplicated as Rule A pending" \
    '\*\*Rule A\*\*' "$TMP_DIR/reconciler-awaiting.out"
}

run_reconciler_replay_case() {
  local repo="$TMP_DIR/reconciler-replay-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
  set_pr_states 131 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/reconciler-replay.log"
  SHIP_FLOW_RECONCILER_STATE="already_reconciled"
  SHIP_FLOW_RECONCILER_ACTION="already_reconciled"
  SHIP_FLOW_RECONCILER_REASON="__EMPTY__"
  rc="$(run_hook "$repo" "$TMP_DIR/reconciler-replay.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""
  SHIP_FLOW_RECONCILER_STATE=""
  SHIP_FLOW_RECONCILER_ACTION=""
  SHIP_FLOW_RECONCILER_REASON=""

  assert_exit "reconciler replay exits advisory success" 0 "$rc"
  assert_contains "reconciler replay is classified as receipt no-op" \
    'receipt already reconciled; replay made no terminal mutation' \
    "$TMP_DIR/reconciler-replay.out"
}

run_dirty_tree_case() {
  local repo="$TMP_DIR/dirty-tree-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
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
  assert_path_exists "dirty tree keeps active entity" "${repo}/docs/ship-flow/folder-merged/index.md"
  assert_path_missing "dirty tree does not archive entity" "${repo}/docs/ship-flow/_archive/folder-merged/index.md"
  assert_equals "dirty tree leaves workflow unchanged" "$before" "$after"
}

run_missing_helper_case() {
  local repo="$TMP_DIR/missing-helper-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
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
  assert_contains "missing helper reports reconciler machine reason" \
    'reconciler failed \(verdict=REJECT, reason=missing-status-helper, exit=2\)' \
    "$TMP_DIR/missing-helper.out"
  assert_path_missing "missing helper does not archive entity" "${repo}/docs/ship-flow/_archive/folder-merged/index.md"
  assert_equals "missing helper leaves workflow unchanged" "$before" "$after"
}

run_reprobe_not_merged_case() {
  local repo="$TMP_DIR/reprobe-not-merged-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "folder-merged" "ship" "#131"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "folder-merged" "#131"
  git -C "$repo" add -- docs/ship-flow/folder-merged
  git -C "$repo" commit -qm "add canonical merged entity" -- docs/ship-flow/folder-merged
  set_pr_states 131 "MERGED,OPEN"

  local before after rc
  before="$(hash_tree "${repo}/docs/ship-flow")"
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  rc="$(run_hook "$repo" "$TMP_DIR/reprobe-not-merged.out")"
  SHIP_FLOW_STATUS_BIN=""
  after="$(hash_tree "${repo}/docs/ship-flow")"

  assert_exit "re-probe not merged exits success" 0 "$rc"
  assert_contains "re-probe not merged reports blocked reason" 're-probe says state=OPEN, not MERGED' "$TMP_DIR/reprobe-not-merged.out"
  assert_not_contains "re-probe not merged is not duplicated as Rule A pending" \
    '\*\*Rule A\*\*' "$TMP_DIR/reprobe-not-merged.out"
  assert_path_missing "re-probe not merged does not archive entity" "${repo}/docs/ship-flow/_archive/folder-merged/index.md"
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
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/flat-and-folder.reconciler.log"
  rc="$(run_hook "$repo" "$TMP_DIR/flat-and-folder.out")"
  SHIP_FLOW_STATUS_BIN=""
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""

  assert_exit "flat and folder exits success" 0 "$rc"
  assert_contains "flat and folder reports flat reconciliation" 'flat-merged.*PR #301' "$TMP_DIR/flat-and-folder.out"
  assert_contains "flat and folder reports folder reconciliation" 'folder-merged.*PR #302' "$TMP_DIR/flat-and-folder.out"
  assert_equals "flat and folder invoke only for canonical folder" 1 "$(wc -l < "$TMP_DIR/flat-and-folder.reconciler.log" | tr -d '[:space:]')"
  assert_path_exists "flat entity mutation remains reconciler-owned" "${repo}/docs/ship-flow/flat-merged.md"
  assert_path_exists "folder entity mutation remains reconciler-owned" "${repo}/docs/ship-flow/folder-merged/index.md"
}

run_flat_folder_same_slug_collision_case() {
  local repo="$TMP_DIR/flat-folder-same-slug-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "same-slug" "ship" "#301"
  write_folder_entity "${repo}/docs/ship-flow" "same-slug" "ship" "#302"
  git -C "$repo" add -- docs/ship-flow/same-slug.md docs/ship-flow/same-slug
  git -C "$repo" commit -qm "add flat and folder entities with the same slug" -- \
    docs/ship-flow/same-slug.md docs/ship-flow/same-slug
  set_pr_states 301 "MERGED"
  set_pr_states 302 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/flat-folder-same-slug.reconciler.log"
  rc="$(run_hook "$repo" "$TMP_DIR/flat-folder-same-slug.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""

  assert_exit "same-slug collision exits advisory success" 0 "$rc"
  assert_equals "same-slug collision invokes exactly one folder reconciler" 1 \
    "$(wc -l < "$TMP_DIR/flat-folder-same-slug.reconciler.log" | tr -d '[:space:]')"
  assert_contains "same-slug flat record remains warning-only pending" \
    'same-slug.*PR #301 MERGED, flat legacy entity; warning-only, no reconciler call' \
    "$TMP_DIR/flat-folder-same-slug.out"
  assert_not_contains "same-slug selected folder is not duplicated in pending" \
    'same-slug.*PR #302 MERGED, canonical folder entity still' \
    "$TMP_DIR/flat-folder-same-slug.out"
  assert_equals "same-slug selected folder appears exactly once" 1 \
    "$(grep -c 'same-slug.*PR #302' "$TMP_DIR/flat-folder-same-slug.out" || true)"
}

run_mixed_reconciler_outcomes_case() {
  local repo="$TMP_DIR/mixed-reconciler-outcomes-repo"
  setup_repo "$repo" execute
  write_folder_entity "${repo}/docs/ship-flow" "flat-success" "ship" "#301"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "flat-success" "#301"
  write_folder_entity "${repo}/docs/ship-flow" "flat-blocked" "ship" "#302"
  write_folder_closeout_evidence "${repo}/docs/ship-flow" "flat-blocked" "#302"
  git -C "$repo" add -- docs/ship-flow/flat-success docs/ship-flow/flat-blocked
  git -C "$repo" commit -qm "add mixed canonical entities" -- docs/ship-flow/flat-success docs/ship-flow/flat-blocked
  set_pr_states 301 "MERGED"
  set_pr_states 302 "MERGED"

  local rc
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/mixed-reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/mixed-reconciler-outcomes.log"
  rc="$(run_hook "$repo" "$TMP_DIR/mixed-reconciler-outcomes.out")"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""

  assert_exit "mixed reconciler outcomes exit advisory success" 0 "$rc"
  assert_contains "mixed reconciler outcomes classify the selected folder" \
    'Auto-fixed / reconciled|Auto-fix blocked' "$TMP_DIR/mixed-reconciler-outcomes.out"
  assert_equals "mixed reconciler outcomes invoke only one eligible record" 1 \
    "$(wc -l < "$TMP_DIR/mixed-reconciler-outcomes.log" | tr -d '[:space:]')"
  assert_contains "mixed reconciler outcomes defer the unselected folder" \
    '\*\*Rule A\*\*.*1 entity' "$TMP_DIR/mixed-reconciler-outcomes.out"
}

run_pathspec_only_commit_case() {
  local repo="$TMP_DIR/pathspec-only-commit-repo"
  setup_repo "$repo" execute
  write_flat_entity "${repo}/docs/ship-flow" "flat-merged" "ship" "#401"
  echo "keep" > "${repo}/tracked.txt"
  git -C "$repo" add -- docs/ship-flow/flat-merged.md tracked.txt
  git -C "$repo" commit -qm "add pathspec entity and tracked file" -- docs/ship-flow/flat-merged.md tracked.txt
  set_pr_states 401 "MERGED"

  local before_head rc
  before_head="$(git -C "$repo" rev-parse HEAD)"
  SHIP_FLOW_STATUS_BIN="$TMP_DIR/status-fixture"
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN="$TMP_DIR/reconciler-fixture"
  SHIP_FLOW_RECONCILER_LOG="$TMP_DIR/pathspec-only-commit.reconciler.log"
  rc="$(run_hook "$repo" "$TMP_DIR/pathspec-only-commit.out")"
  SHIP_FLOW_STATUS_BIN=""
  SHIP_FLOW_CLOSEOUT_RECONCILER_BIN=""
  SHIP_FLOW_RECONCILER_LOG=""

  assert_exit "pathspec-only commit exits success" 0 "$rc"
  assert_contains "pathspec-only flat entity remains pending" 'flat-merged.*PR #401 MERGED' "$TMP_DIR/pathspec-only-commit.out"
  assert_path_missing "pathspec-only flat entity invokes zero reconciler calls" "$TMP_DIR/pathspec-only-commit.reconciler.log"
  assert_equals "pathspec-only hook does not create a direct commit" "$before_head" "$(git -C "$repo" rev-parse HEAD)"
  if [ -z "$(git -C "$repo" status --porcelain -- tracked.txt)" ]; then
    record_pass "delegation leaves unrelated tracked file untouched"
  else
    record_fail "delegation leaves unrelated tracked file untouched"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --case)
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
REAL_GIT="$(command -v git)"
mkdir -p "$TMP_DIR/bin" "$TMP_DIR/git-spy-bin" "$TMP_DIR/home" "$TMP_DIR/gh-state"
write_fixture_gh "$TMP_DIR/bin"
write_fixture_status_bin "$TMP_DIR/status-fixture"
write_fixture_reconciler "$TMP_DIR/reconciler-fixture"
write_fixture_mixed_reconciler "$TMP_DIR/mixed-reconciler-fixture"
write_fixture_git_spy "$TMP_DIR/git-spy-bin/git"
write_fixture_actual_reconciler_wrapper "$TMP_DIR/actual-reconciler-wrapper"
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
  should_run_case doc-contract && run_doc_contract_case
  should_run_case flat-merged-warning-only && run_flat_merged_warning_only_case
  should_run_case one-folder-per-session && run_one_folder_per_session_case
  should_run_case reconciler-timeout && run_reconciler_timeout_case
  should_run_case actual-reconciler-folder && run_actual_reconciler_folder_case
  should_run_case auto-fix-off && run_auto_fix_off_case
  should_run_case execute-merged && run_execute_merged_case
  should_run_case reconciler-delegation && run_reconciler_delegation_case
  should_run_case reconciler-open-noop && run_reconciler_open_noop_case
  should_run_case reconciler-structured-failure && run_reconciler_structured_failure_case
  should_run_case reconciler-awaiting && run_reconciler_awaiting_case
  should_run_case reconciler-replay && run_reconciler_replay_case
  should_run_case dirty-tree && run_dirty_tree_case
  should_run_case missing-helper && run_missing_helper_case
  should_run_case reprobe-not-merged && run_reprobe_not_merged_case
  should_run_case rule-b-folder-drift && run_rule_b_folder_drift_case
  should_run_case unsafe-pr-states && run_unsafe_pr_states_case
  should_run_case flat-and-folder && run_flat_and_folder_case
  should_run_case flat-folder-same-slug && run_flat_folder_same_slug_collision_case
  should_run_case mixed-reconciler-outcomes && run_mixed_reconciler_outcomes_case
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
