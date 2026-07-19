#!/usr/bin/env bash
# test-ship-flow-scheduler-reconcile.sh - AC-5: reconcile + advance actions
#
# design.md §4/§10: precedence puts `reconcile` first ("a merged PR exists"). The
# tick's reconcile action shells out to the EXISTING
# merged-pr-closeout-reconciler.sh unmodified (reuse, not reimplementation) —
# this file reuses that script's OWN `fixtures/merged-pr-closeout-reconciler/*.env`
# PR fixtures directly, per plan.md T1 ("no duplication"). A `PROMPT_CAPTAIN`
# verdict (exit 1) must surface as a terminal `blocked` event
# (source=reconciler-prompt-captain), never a crash, never a retry. A `PROCEED`
# verdict must emit `reconcile` (terminal_state=reconciled) followed by `advance`
# naming the next ready entity from a fixture DAG.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/bin/ship-flow-scheduler.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/ship-flow-scheduler"
RECONCILER_FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/merged-pr-closeout-reconciler"

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

assert_not_contains() {
  local desc="$1" pattern="$2" haystack="$3"
  if printf '%s' "$haystack" | grep -qE "$pattern"; then record_fail "$desc (unexpected pattern: ${pattern})"
  else record_pass "$desc"; fi
}

assert_eq() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"
  else record_fail "$desc (expected '${expected}', got '${actual}')"; fi
}

OUT=""
EXIT_CODE=0
run_capture() { OUT="$("$@" 2>&1)"; EXIT_CODE=$?; }

# write_fixture_status_bin — hermetic `spacedock status` stand-in (CI has no real
# `spacedock` binary on PATH; the reconciler needs `--resolve`/`--set`/`--archive`).
# Trimmed copy of the same helper in test-merged-pr-closeout-reconciler.sh.
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

one_entity_workflow() {
  local entity="$1" dir
  dir="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/${entity}" "${dir}/${entity}"
  git -C "$dir" init -q 2>/dev/null || true
  printf '%s\n' "$dir"
}

run_prompt_captain_case() {
  local wf status_bin
  wf="$(one_entity_workflow prompt-captain-entity)"
  status_bin="$(mktemp -d)/status-fixture"
  write_fixture_status_bin "$status_bin"

  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --pr-fixture "${RECONCILER_FIXTURE_ROOT}/pr-closed.env" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"

  assert_exit "PROMPT_CAPTAIN: tick exit 0 (blocked is a recorded outcome)" 0 "$EXIT_CODE"
  assert_contains "PROMPT_CAPTAIN: blocked event" '"event":"blocked"' "$OUT"
  assert_contains "PROMPT_CAPTAIN: source=reconciler-prompt-captain" '"source":"reconciler-prompt-captain"' "$OUT"
}

run_proceed_case() {
  local wf status_bin
  wf="$(one_entity_workflow merged-entity)"
  status_bin="$(mktemp -d)/status-fixture"
  write_fixture_status_bin "$status_bin"

  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --pr-fixture "${RECONCILER_FIXTURE_ROOT}/pr-merged.env" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"

  assert_exit "PROCEED: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "PROCEED: reconcile event" '"event":"reconcile"' "$OUT"
  assert_contains "PROCEED: terminal_state=reconciled" '"terminal_state":"reconciled"' "$OUT"
}

run_reconcile_then_advance_case() {
  local wf status_bin
  wf="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/advance-epic/." "${wf}/"
  git -C "$wf" init -q 2>/dev/null || true
  status_bin="$(mktemp -d)/status-fixture"
  write_fixture_status_bin "$status_bin"

  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --pr-fixture "${RECONCILER_FIXTURE_ROOT}/pr-merged.env" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  rm -rf "$wf"

  assert_exit "reconcile+advance: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "reconcile+advance: reconcile event present" '"event":"reconcile"' "$OUT"
  assert_contains "reconcile+advance: advance event present" '"event":"advance"' "$OUT"
  assert_contains "reconcile+advance: advance names the ready sibling" '"dispatched":"epic-child-entity"' "$OUT"
}

run_unknown_gh_state_case() {
  # F4 (feedback cycle 1, WARNING): a transient gh lookup failure (modeled by
  # the fixture provider reporting UNKNOWN for a slug with no matching
  # pr-<slug>.env) must surface as a warning no-op, never escalate through
  # the reconciler into a spurious PROMPT_CAPTAIN, and must leave the
  # entity's frontmatter untouched (nothing to unwind on the next tick).
  local wf status_bin status_before status_after
  wf="$(one_entity_workflow unknown-pr-state-entity)"
  status_bin="$(mktemp -d)/status-fixture"
  write_fixture_status_bin "$status_bin"
  status_before="$(grep '^status:' "${wf}/unknown-pr-state-entity/index.md")"

  # --pr-fixture keeps this hermetic even in the pre-fix (RED) path, where the
  # tick still funnels UNKNOWN into run_reconcile_action -> the REAL
  # merged-pr-closeout-reconciler.sh, which would otherwise fall back to a
  # live (real, non-hermetic) `gh pr view` call.
  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --pr-fixture "${RECONCILER_FIXTURE_ROOT}/pr-unknown.env" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "${wf}/events.jsonl"
  status_after="$(grep '^status:' "${wf}/unknown-pr-state-entity/index.md")"
  rm -rf "$wf"

  assert_exit "UNKNOWN gh state: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "UNKNOWN gh state: no-op event" '"event":"no-op"' "$OUT"
  assert_contains "UNKNOWN gh state: reason=gh-state-unknown" '"reason":"gh-state-unknown"' "$OUT"
  assert_not_contains "UNKNOWN gh state: never escalates to blocked" '"event":"blocked"' "$OUT"
  assert_eq "UNKNOWN gh state: entity status unchanged (no mutation)" "$status_before" "$status_after"
}

echo "=== test-ship-flow-scheduler-reconcile.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_prompt_captain_case
  run_proceed_case
  run_reconcile_then_advance_case
  run_unknown_gh_state_case
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
