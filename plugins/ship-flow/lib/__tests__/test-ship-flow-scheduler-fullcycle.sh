#!/usr/bin/env bash
# test-ship-flow-scheduler-fullcycle.sh - AC-5: fixture full-cycle proof
#
# design.md §10 "full-cycle" row: dispatch -> PR-ready -> merged -> reconcile ->
# dag-waves --ready next-ready, exercised end to end via T2/T3/T4/T5's landed
# pieces. Three tick invocations against one evolving fixture git repo:
#   1. dispatch fires on the eligible parent entity.
#   2. (the test manually applies the "PR opened + verdict PASSED" mutation a
#      real /ship run would have written — the tick itself never writes
#      frontmatter, design.md §3/Rule 3) reconcile fires once the linked PR
#      fixture reports MERGED, and — because the entity carries parent_pitch —
#      the SAME invocation's follow-through recomputes readiness and names the
#      newly-ready sibling (the "advance" half of AC-5).
#   3. a third tick actually dispatches the now-ready child.
#
# Leg 2 drives a REAL merged-pr-closeout-reconciler.sh PROCEED (not a stub):
# via build-landing-fixture.sh, mirroring test-merged-pr-closeout-
# reconciler.sh's own proven prepare_full_d1_repo recipe. A bare fixture PR
# env (missing landing_anchor/source_commits/pr_commit_count) can never reach
# PROCEED — that shape is the reconciler's OWN suite's deliberately-incomplete
# negative fixture, asserted elsewhere to REJECT.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/ship-flow-scheduler"
# shellcheck disable=SC1091
source "${FIXTURE_ROOT}/build-landing-fixture.sh"

PASS=0
FAIL=0
ERRORS=()

record_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
record_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"
  else record_fail "$desc (expected exit ${expected}, got ${actual})"; fi
}

assert_contains() {
  local desc="$1" pattern="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qE "$pattern"; then record_pass "$desc"
  else record_fail "$desc (missing pattern: ${pattern})"; fi
}

OUT=""
EXIT_CODE=0
run_capture() { OUT="$("$@" 2>&1)"; EXIT_CODE=$?; }

write_fixture_status_bin() {
  local bin="$1"
  cat > "$bin" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
workflow_dir=""; include_archived=no; cmd=""; ref=""; slug=""
[ "${1:-}" = status ] && shift
while [ "$#" -gt 0 ]; do
  case "$1" in
    --workflow-dir) workflow_dir="$2"; shift 2 ;;
    --archived) include_archived=yes; shift ;;
    --resolve) cmd=resolve; ref="$2"; shift 2 ;;
    --set) cmd=set; slug="$2"; shift 2; break ;;
    --archive) cmd=archive; slug="$2"; shift 2 ;;
    *) echo "unknown status arg: $1" >&2; exit 2 ;;
  esac
done
[ -n "$workflow_dir" ] || exit 2
update_frontmatter_field() {
  local file="$1" field="$2" value="$3" tmp="${1}.tmp"
  awk -v field="$field" -v value="$value" '
    /^---[[:space:]]*$/ { fence++; print; next }
    fence == 1 { prefix = field ":"; if (index($0, prefix) == 1) { print field ": " value; next } }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}
case "$cmd" in
  resolve)
    raw="${ref#archive:}"
    if [ "$include_archived" = yes ]; then
      path="${workflow_dir}/_archive/${raw}/index.md"
    else
      path="${workflow_dir}/${raw}/index.md"
    fi
    [ -f "$path" ] || exit 1
    printf 'slug=%s path=%s\n' "$raw" "$path"
    ;;
  set)
    path="${workflow_dir}/${slug}/index.md"
    [ -f "$path" ] || exit 1
    for pair in "$@"; do
      case "$pair" in
        *=*) key="${pair%%=*}"; value="${pair#*=}" ;;
        completed) key=completed; value=2026-07-19T00:00:00Z ;;
        *) echo "unsupported set pair: $pair" >&2; exit 2 ;;
      esac
      update_frontmatter_field "$path" "$key" "$value"
    done
    ;;
  archive)
    path="${workflow_dir}/${slug}/index.md"
    [ -f "$path" ] || exit 1
    update_frontmatter_field "$path" archived 2026-07-19T00:01:00Z
    mkdir -p "${workflow_dir}/_archive"
    mv "${workflow_dir}/${slug}" "${workflow_dir}/_archive/${slug}"
    ;;
  *) echo "missing status command" >&2; exit 2 ;;
esac
EOF
  chmod +x "$bin"
}

set_frontmatter_field() {
  local file="$1" field="$2" value="$3" tmp="${1}.tmp"
  awk -v field="$field" -v value="$value" '
    /^---[[:space:]]*$/ { fence++; print; next }
    fence == 1 { prefix = field ":"; if (index($0, prefix) == 1) { print field ": " value; next } }
    { print }
  ' "$file" > "$tmp"
  mv "$tmp" "$file"
}

run_fullcycle_case() {
  local repo status_bin parent_path child_path fixture_env events_log
  repo="$(mktemp -d)"
  scaffold_landing_repo "$repo"
  commit_entity_dir "$repo" fullcycle-parent-entity "${FIXTURE_ROOT}/fullcycle/fullcycle-parent-entity"
  commit_entity_dir "$repo" fullcycle-child-entity "${FIXTURE_ROOT}/fullcycle/fullcycle-child-entity"
  status_bin="$(mktemp -d)/status-fixture"
  write_fixture_status_bin "$status_bin"
  events_log="$(mktemp -d)/events.jsonl"

  # --- Leg 1: dispatch ---
  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "${repo}/docs/ship-flow" --controller-worktree "${repo}/docs/ship-flow" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  assert_exit "leg 1 (dispatch): tick exit 0" 0 "$EXIT_CODE"
  assert_contains "leg 1 (dispatch): dispatch event for the parent" '"event":"dispatch".*"entity":"fullcycle-parent-entity"' "$OUT"

  # --- Simulate what a completed /ship run writes (the tick itself never
  # writes entity frontmatter — design.md §3/Rule 3): pr/worktree/verdict.
  # land_entity below stages+commits this edit along with review.md/ship.md,
  # producing a REAL merged-PR fixture (landing_anchor/source_commits/
  # pr_commit_count) via build-landing-fixture.sh — a bare fixture env
  # (missing those fields) can never reach a real reconcile PROCEED.
  parent_path="${repo}/docs/ship-flow/fullcycle-parent-entity/index.md"
  set_frontmatter_field "$parent_path" pr 131
  set_frontmatter_field "$parent_path" worktree ".worktrees/fullcycle-parent-entity"
  set_frontmatter_field "$parent_path" verdict PASSED
  fixture_env="$(mktemp -d)/pr-fullcycle-parent-merged.env"
  land_entity "$repo" fullcycle-parent-entity 131 "Fullcycle parent fixture entity (dispatch target)" "$fixture_env"

  # --- Leg 2: reconcile (merged) + advance (next-ready) ---
  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "${repo}/docs/ship-flow" --controller-worktree "${repo}/docs/ship-flow" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --pr-fixture "$fixture_env" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  assert_exit "leg 2 (reconcile+advance): tick exit 0" 0 "$EXIT_CODE"
  assert_contains "leg 2: reconcile event, terminal_state=reconciled" '"event":"reconcile".*"terminal_state":"reconciled"' "$OUT"
  assert_contains "leg 2: advance names the next-ready child" '"event":"advance".*"dispatched":"fullcycle-child-entity"' "$OUT"

  # --- Simulate the child becoming genuinely ready (F3, feedback cycle 1,
  # BLOCKING): the tick itself never authors shape.md or approves gh issues
  # (design.md §3/Rule 3) — a captain/agent does that once dag-waves marks
  # the child ready (leg 2's `advance` event above). This models that real
  # "shape it, get the linked issue sd:approved" step; the committed
  # gh/issue-fullcycle-child-entity.env fixture (state OPEN + sd:approved)
  # only starts counting once `issue:` is non-empty, matching a real shape
  # pass writing both facts together. Left uncommitted (a dirty working tree
  # is harmless here — dispatch never touches the reconciler's dirty-tree
  # guard, unlike reconcile).
  child_path="${repo}/docs/ship-flow/fullcycle-child-entity/index.md"
  set_frontmatter_field "$child_path" status shape
  set_frontmatter_field "$child_path" issue 902
  cp "${FIXTURE_ROOT}/fullcycle/fullcycle-parent-entity/shape.md" "${repo}/docs/ship-flow/fullcycle-child-entity/shape.md"

  # --- Leg 3 (F3, feedback cycle 1, BLOCKING): a THIRD tick, with the parent
  # now archived (no PR-bearing active entity left), must actually DISPATCH
  # the child — the real "NEXT tick dispatches the next entity" half of AC-5
  # that leg 2's `advance` event alone only NAMES, never proves.
  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "${repo}/docs/ship-flow" --controller-worktree "${repo}/docs/ship-flow" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  assert_exit "leg 3 (dispatch the next entity): tick exit 0" 0 "$EXIT_CODE"
  assert_contains "leg 3: dispatch event for the child" '"event":"dispatch".*"entity":"fullcycle-child-entity"' "$OUT"

  rm -rf "$repo"
}

echo "=== test-ship-flow-scheduler-fullcycle.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_fullcycle_case
fi

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
if [ ${FAIL} -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do echo "  - $err"; done
  echo ""
  echo "Not all assertions passed"
  exit 1
fi
echo "All assertions passed"
exit 0
