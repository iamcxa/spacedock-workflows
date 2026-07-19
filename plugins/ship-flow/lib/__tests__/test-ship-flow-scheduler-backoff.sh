#!/usr/bin/env bash
# test-ship-flow-scheduler-backoff.sh - AC-4: blocked-backoff (no head-block)
#
# design.md AC-4: a perpetually-blocked entity must not consume the tick's
# single action on every cycle, starving everything behind it in list order
# (the cited Wave-0 incident: precedence-1's reconcile loop `return 0`s on
# the FIRST non-OPEN-PR entity). entity_in_backoff derives "was this entity
# blocked recently" purely from --events-log (Rule 3: no new store), and the
# fix is a `continue` (skip-past), never a retry (Rule 4) -- the blocked
# entity is simply not re-acted-on again until its backoff window elapses.

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

OUT=""
EXIT_CODE=0
run_capture() { OUT="$("$@" 2>&1)"; EXIT_CODE=$?; }

# write_fixture_status_bin — hermetic `spacedock status` stand-in (mirrors
# test-ship-flow-scheduler-reconcile.sh's own copy; the reconciler needs
# --resolve/--set/--archive even on a PROMPT_CAPTAIN verdict).
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

two_entity_workflow() {
  local entity_a="$1" entity_b="$2" dir
  dir="$(mktemp -d)"
  cp -R "${FIXTURE_ROOT}/workflow/${entity_a}" "${dir}/${entity_a}"
  cp -R "${FIXTURE_ROOT}/workflow/${entity_b}" "${dir}/${entity_b}"
  git -C "$dir" init -q 2>/dev/null || true
  printf '%s\n' "$dir"
}

# seed_blocked_event <events-log> <slug> <ts> — one blocked/
# reconciler-prompt-captain line for <slug>, matching emit_event's shape
# closely enough for entity_in_backoff's own grep/sed extraction (entity,
# event, ts).
seed_blocked_event() {
  local events_log="$1" slug="$2" ts="$3"
  printf '{"schema":"ship-flow-scheduler/v0","ts":"%s","tick_id":"seed","event":"blocked","entity":"%s","outcome":"blocked","reason":"reconciler-prompt-captain","detail":{"source":"reconciler-prompt-captain","receipt":null,"reconciler_reason":null}}\n' \
    "$ts" "$slug" > "$events_log"
}

run_head_block_skip_past_case() {
  # AC-4 case 1: prompt-captain-entity was blocked moments ago (within the
  # backoff window). Precedence-1's loop must skip past it (continue, not
  # return 0) so eligible-entity (precedence-2) still gets dispatched this
  # tick -- the actual cited Wave-0 incident.
  local wf events_log status_bin now_ts
  wf="$(two_entity_workflow prompt-captain-entity eligible-entity)"
  events_log="${wf}/events.jsonl"
  now_ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  seed_blocked_event "$events_log" "prompt-captain-entity" "$now_ts"
  status_bin="$(mktemp -d)/status-fixture"
  write_fixture_status_bin "$status_bin"

  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --pr-fixture "${RECONCILER_FIXTURE_ROOT}/pr-closed.env" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  rm -rf "$wf"

  assert_exit "head-block skip-past: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "head-block skip-past: dispatch event" '"event":"dispatch"' "$OUT"
  assert_contains "head-block skip-past: entity=eligible-entity" '"entity":"eligible-entity"' "$OUT"
  assert_not_contains "head-block skip-past: no re-emitted reconciler-prompt-captain this tick" '"reconciler-prompt-captain"' "$OUT"
}

run_window_expiry_case() {
  # AC-4 case 2: prompt-captain-entity's last blocked record is far outside
  # the backoff window -- it becomes eligible for reconcile again (the fix
  # must not OVER-suppress once the window elapses). Passes even pre-fix
  # (no backoff check regresses this); proves the guard is window-bounded,
  # not a blanket always-skip.
  local wf events_log status_bin
  wf="$(one_entity_workflow prompt-captain-entity)"
  events_log="${wf}/events.jsonl"
  seed_blocked_event "$events_log" "prompt-captain-entity" "2020-01-01T00:00:00Z"
  status_bin="$(mktemp -d)/status-fixture"
  write_fixture_status_bin "$status_bin"

  STATUS_BIN="$status_bin" run_capture "$HELPER" tick \
    --workflow-dir "$wf" --controller-worktree "$wf" \
    --gh-provider fixture --gh-fixture-dir "${FIXTURE_ROOT}/gh" \
    --pr-fixture "${RECONCILER_FIXTURE_ROOT}/pr-closed.env" \
    --runner fixture --runner-fixture "${FIXTURE_ROOT}/runner/dispatch-success.json" \
    --events-log "$events_log"
  rm -rf "$wf"

  assert_exit "window expiry: tick exit 0" 0 "$EXIT_CODE"
  assert_contains "window expiry: blocked event" '"event":"blocked"' "$OUT"
  assert_contains "window expiry: source=reconciler-prompt-captain" '"source":"reconciler-prompt-captain"' "$OUT"
}

echo "=== test-ship-flow-scheduler-backoff.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "helper exists and is executable (${HELPER})"
else
  record_pass "helper exists and is executable"
  run_head_block_skip_past_case
  run_window_expiry_case
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
