#!/usr/bin/env bash
# ship-flow-scheduler.sh - stateless, idempotent SD scheduler tick (L3 wedge v0)
#
# design.md is the authority for this file's contract (§1 CLI, §2 JSON events,
# §3 state projection, §4 idempotence, §5 lease, §6 adapter seam, §7 report,
# §8 rollup). One `tick` invocation performs exactly ONE bounded action
# (reconcile > dispatch > advance > no-op, with refusal as a dispatch-scan
# sub-outcome) and emits exactly one JSON Lines event to stdout + --events-log.
#
# The tick owns no canonical state (Rule 3): every projection is a fresh read
# of entity frontmatter + gh (or --gh-provider fixture). It never mutates
# entity frontmatter itself — that happens inside the real `/ship <entity>` run
# the adapter spawns, or inside the EXISTING merged-pr-closeout-reconciler.sh /
# dag-waves.sh it shells out to unmodified for reconcile/advance.

set -uo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/.." &> /dev/null && pwd)"
# shellcheck disable=SC1091
source "${PLUGIN_ROOT}/lib/scheduler-lease.sh"

RECONCILER="${PLUGIN_ROOT}/bin/merged-pr-closeout-reconciler.sh"
DAG_WAVES="${PLUGIN_ROOT}/lib/dag-waves.sh"
RUNNER_ADAPTER="${PLUGIN_ROOT}/lib/scheduler-runner-adapter.sh"

usage() {
  cat >&2 <<'USAGE'
Usage:
  ship-flow-scheduler.sh tick   --workflow-dir <dir> --controller-worktree <path>
                                 [--epic <id>] [--runner gh|fixture] [--runner-fixture <path>]
                                 [--gh-provider gh|fixture] [--gh-fixture-dir <dir>]
                                 [--pr-fixture <path>]
                                 [--events-log <path>] [--timeout <sec>] [--dry-run]
  ship-flow-scheduler.sh report --workflow-dir <dir> [--json]
                                 [--gh-provider gh|fixture] [--gh-fixture-dir <dir>]
  ship-flow-scheduler.sh rollup --events-log <path> --date <YYYY-MM-DD>
USAGE
}

# ---------------------------------------------------------------------------
# JSON helpers (fixed key order, printf-emitted — no jq on the emit path, per
# design.md §1's hermetic-bash constraint).
# ---------------------------------------------------------------------------

json_escape() {
  printf '%s' "${1:-}" | sed 's/\\/\\\\/g; s/"/\\"/g'
}

json_str_or_null() {
  if [ -z "${1:-}" ]; then printf 'null'; else printf '"%s"' "$(json_escape "$1")"; fi
}

# emit_event <event> <entity|""> <outcome> <reason|""> <detail-json-object>
emit_event() {
  local event="$1" entity="$2" outcome="$3" reason="$4" detail="$5"
  local ts tick_id line
  ts="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  tick_id="$(printf '%s' "$ts" | tr -d ':-')"
  line="$(printf '{"schema":"ship-flow-scheduler/v0","ts":"%s","tick_id":"%s","event":"%s","entity":%s,"outcome":"%s","reason":%s,"detail":%s}' \
    "$ts" "$tick_id" "$event" "$(json_str_or_null "$entity")" "$outcome" "$(json_str_or_null "$reason")" "$detail")"
  printf '%s\n' "$line"
  if [ -n "${EVENTS_LOG:-}" ]; then
    printf '%s\n' "$line" >> "$EVENTS_LOG"
  fi
}

# ---------------------------------------------------------------------------
# Frontmatter reads (dag-waves.sh / merged-pr-closeout-reconciler.sh convention)
# ---------------------------------------------------------------------------

read_frontmatter_field() {
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = key ":"
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

# list_entities <workflow-dir> — one path per line, sorted by slug, folder-based
# entities only (docs/ship-flow/<slug>/index.md — this plan's entity shape).
list_entities() {
  local dir="$1" f
  for f in "$dir"/*/index.md; do
    [ -f "$f" ] || continue
    printf '%s\n' "$f"
  done | sort
}

entity_slug_from_path() {
  basename "$(dirname "$1")"
}

# ---------------------------------------------------------------------------
# gh-provider abstraction: real `gh` or a hermetic fixture directory of
# issue-<slug>.env / pr-<slug>.env files (state=/labels=/number=/head_ref=...).
# This is a deliberate deviation from design.md §1's CLI surface, which only
# names --runner gh|fixture for the ADAPTER seam — eligibility/state-projection
# reads need their own hermetic seam for CI (no real gh network calls in
# fixture tests). One-line rationale recorded here since design.md didn't spell
# this out; the shape mirrors the reconciler's existing --pr-provider
# gh|fixture --pr-fixture convention.
# ---------------------------------------------------------------------------

gh_issue_state() {
  # prints "state=<OPEN|CLOSED|MISSING> labels=<comma-sep>"
  local slug="$1" issue="$2"
  if [ -z "$issue" ]; then
    printf 'state=MISSING labels=\n'
    return 0
  fi
  if [ "$GH_PROVIDER" = "fixture" ]; then
    local f="${GH_FIXTURE_DIR}/issue-${slug}.env"
    if [ ! -f "$f" ]; then
      printf 'state=MISSING labels=\n'
      return 0
    fi
    local state labels
    state="$(awk -F= '$1=="state"{print $2; exit}' "$f")"
    labels="$(awk -F= '$1=="labels"{print $2; exit}' "$f")"
    printf 'state=%s labels=%s\n' "${state:-MISSING}" "$labels"
    return 0
  fi
  command -v gh >/dev/null 2>&1 || { printf 'state=MISSING labels=\n'; return 0; }
  local out state labels
  out="$(gh issue view "$issue" --json state,labels --jq '"\(.state)\t\([.labels[].name] | join(","))"' 2>/dev/null || true)"
  if [ -z "$out" ]; then printf 'state=MISSING labels=\n'; return 0; fi
  state="$(printf '%s' "$out" | cut -f1)"
  labels="$(printf '%s' "$out" | cut -f2)"
  printf 'state=%s labels=%s\n' "$state" "$labels"
}

gh_pr_state() {
  # prints the PR state (OPEN|MERGED|CLOSED|UNKNOWN|NONE) for an entity that
  # has a `pr:` frontmatter field. --pr-fixture, when given, overrides
  # per-entity lookup (reused verbatim for the entity the tick is currently
  # evaluating for reconcile — see run_reconcile_action).
  local slug="$1" pr="$2"
  if [ -z "$pr" ]; then printf 'NONE\n'; return 0; fi
  if [ -n "${PR_FIXTURE:-}" ]; then
    awk -F= '$1=="state"{print $2; exit}' "$PR_FIXTURE"
    return 0
  fi
  if [ "$GH_PROVIDER" = "fixture" ]; then
    local f="${GH_FIXTURE_DIR}/pr-${slug}.env"
    [ -f "$f" ] || { printf 'UNKNOWN\n'; return 0; }
    awk -F= '$1=="state"{print $2; exit}' "$f"
    return 0
  fi
  command -v gh >/dev/null 2>&1 || { printf 'UNKNOWN\n'; return 0; }
  gh pr view "$pr" --json state --jq .state 2>/dev/null || printf 'UNKNOWN\n'
}

# ---------------------------------------------------------------------------
# Eligibility (design.md §2/§3, dual-key + DoR + dedup, fail-closed)
# ---------------------------------------------------------------------------

TERMINAL_STATUSES=" done "

is_shaped() {
  local status="$1"
  [ -n "$status" ] || return 1
  case "$TERMINAL_STATUSES" in *" ${status} "*) return 1 ;; esac
  return 0
}

# dor_pass <entity-dir> — narrowed mechanical check (design.md leaves the exact
# DoR mechanics undefined at v0): shape.md exists and is non-empty. This is a
# deliberate v0 narrowing of the four dor-* reason codes down to one concrete
# gate; the finer-grained codes remain valid refusal vocabulary for a
# follow-up, but this build only distinguishes "has a real shape.md" from not.
dor_pass() {
  local shape_md="${1}/shape.md"
  [ -s "$shape_md" ]
}

# evaluate_entity <path> — sets EVAL_* globals. Returns 0 for eligible,
# 1 for refused (EVAL_REASON set, EVAL_KEYS set), 2 for dedup-excluded
# (EVAL_REASON set to worktree-exists|pr-exists).
EVAL_REASON=""
EVAL_KEYS=""
evaluate_entity() {
  local path="$1" dir slug status worktree issue pr issue_info issue_state issue_labels
  dir="$(dirname "$path")"
  slug="$(entity_slug_from_path "$path")"
  status="$(read_frontmatter_field "$path" status)"
  worktree="$(read_frontmatter_field "$path" worktree)"
  issue="$(read_frontmatter_field "$path" issue)"
  pr="$(read_frontmatter_field "$path" pr)"

  local shaped=false issue_open=false sd_approved=false dor=false

  if is_shaped "$status"; then shaped=true; fi

  if [ "$shaped" = true ]; then
    issue_info="$(gh_issue_state "$slug" "$issue")"
    issue_state="$(printf '%s\n' "$issue_info" | sed -n 's/^state=\([A-Z]*\).*/\1/p')"
    issue_labels="$(printf '%s\n' "$issue_info" | sed -n 's/.*labels=//p')"
    [ "$issue_state" = "OPEN" ] && issue_open=true
    case ",${issue_labels}," in *,sd:approved,*) sd_approved=true ;; esac
    if dor_pass "$dir"; then dor=true; fi
  fi

  EVAL_KEYS="$(printf '{"shaped":%s,"issue_open":%s,"sd_approved":%s,"dor":%s}' "$shaped" "$issue_open" "$sd_approved" "$dor")"

  if [ "$shaped" != true ]; then EVAL_REASON="not-shaped"; return 1; fi
  if [ "$issue_open" != true ]; then
    if [ "${issue_state:-MISSING}" = "MISSING" ]; then EVAL_REASON="issue-missing"; else EVAL_REASON="issue-closed"; fi
    return 1
  fi
  if [ "$sd_approved" != true ]; then EVAL_REASON="not-sd-approved"; return 1; fi
  if [ "$dor" != true ]; then EVAL_REASON="dor-stale-shape"; return 1; fi

  if [ -n "$worktree" ]; then EVAL_REASON="worktree-exists"; return 2; fi
  if [ -n "$pr" ]; then EVAL_REASON="pr-exists"; return 2; fi

  EVAL_REASON=""
  return 0
}

# ---------------------------------------------------------------------------
# tick subcommand
# ---------------------------------------------------------------------------

cmd_tick() {
  local workflow_dir="" controller_worktree="" epic="" runner="fixture" runner_fixture=""
  local timeout_sec=900 dry_run=no
  GH_PROVIDER="gh"; GH_FIXTURE_DIR=""
  EVENTS_LOG=""
  PR_FIXTURE=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --workflow-dir) workflow_dir="${2:-}"; shift 2 ;;
      --controller-worktree) controller_worktree="${2:-}"; shift 2 ;;
      --epic) epic="${2:-}"; shift 2 ;;
      --runner) runner="${2:-}"; shift 2 ;;
      --runner-fixture) runner_fixture="${2:-}"; shift 2 ;;
      --gh-provider) GH_PROVIDER="${2:-}"; shift 2 ;;
      --gh-fixture-dir) GH_FIXTURE_DIR="${2:-}"; shift 2 ;;
      --pr-fixture) PR_FIXTURE="${2:-}"; shift 2 ;;
      --events-log) EVENTS_LOG="${2:-}"; shift 2 ;;
      --timeout) timeout_sec="${2:-}"; shift 2 ;;
      --dry-run) dry_run=yes; shift ;;
      *) usage; return 2 ;;
    esac
  done

  [ -n "$workflow_dir" ] && [ -n "$controller_worktree" ] || { usage; return 2; }
  [ -d "$workflow_dir" ] || { echo "ship-flow-scheduler: no such workflow-dir: $workflow_dir" >&2; return 3; }
  [ -d "$controller_worktree" ] || { echo "ship-flow-scheduler: no such controller-worktree: $controller_worktree" >&2; return 3; }
  if [ "$runner" = "gh" ] && ! command -v claude >/dev/null 2>&1; then
    echo "ship-flow-scheduler: claude CLI not available for --runner gh" >&2; return 3
  fi

  local tick_id
  tick_id="$(date -u +%Y%m%dT%H%M%SZ)"

  if ! scheduler_lease_acquire "$controller_worktree" "$tick_id" "$timeout_sec" "" >/dev/null; then
    emit_event no-op "" ok lease-held '{"reason":"lease-held"}'
    return 0
  fi
  # shellcheck disable=SC2064
  trap "scheduler_lease_release '$controller_worktree'" EXIT

  # --- Precedence 1: reconcile (a merged PR exists) ---
  local path slug pr_val pr_state
  for path in $(list_entities "$workflow_dir"); do
    slug="$(entity_slug_from_path "$path")"
    pr_val="$(read_frontmatter_field "$path" pr)"
    [ -n "$pr_val" ] || continue
    [ "$(read_frontmatter_field "$path" status)" != "done" ] || continue
    pr_state="$(gh_pr_state "$slug" "$pr_val")"
    if [ "$pr_state" = "MERGED" ]; then
      run_reconcile_action "$path" "$slug" "$dry_run" "$workflow_dir"
      return 0
    fi
  done

  # --- Precedence 2: dispatch (an eligible entity exists), else refusal ---
  local first_refusal_path="" first_refusal_reason="" first_refusal_keys=""
  for path in $(list_entities "$workflow_dir"); do
    evaluate_entity "$path"
    case $? in
      0)
        run_dispatch_action "$path" "$(entity_slug_from_path "$path")" "$runner" "$runner_fixture" "$timeout_sec" "$controller_worktree" "$dry_run"
        return 0
        ;;
      1 | 2)
        # Dedup exclusions (worktree-exists / pr-exists, case 2) are reported
        # via the same `refusal` event shape as dual-key/DoR failures (case 1)
        # — design.md §2 lists worktree-exists/pr-exists in the same
        # refusal-reason-code vocabulary, annotated "dedup keys".
        if [ -z "$first_refusal_path" ]; then
          first_refusal_path="$path"
          first_refusal_reason="$EVAL_REASON"
          first_refusal_keys="$EVAL_KEYS"
        fi
        ;;
    esac
  done

  if [ -n "$first_refusal_path" ]; then
    local detail
    detail="$(printf '{"keys":%s,"reason":"%s"}' "$first_refusal_keys" "$first_refusal_reason")"
    emit_event refusal "$(entity_slug_from_path "$first_refusal_path")" refused "$first_refusal_reason" "$detail"
    return 0
  fi

  # --- Precedence 3: advance (recompute readiness), else no-op ---
  if [ -n "$epic" ] && [ -x "$DAG_WAVES" ]; then
    run_advance_action "$workflow_dir" "$epic"
    return 0
  fi

  emit_event no-op "" ok nothing-eligible '{"reason":"nothing-eligible"}'
  return 0
}

run_dispatch_action() {
  local path="$1" slug="$2" runner="$3" runner_fixture="$4" timeout_sec="$5" controller_worktree="$6" dry_run="$7"
  local exit_class sentinel receipt pr_from_sentinel

  if [ "$dry_run" = "yes" ]; then
    emit_event dispatch "$slug" ok "" '{"runner":{"exit_class":"dry-run"},"pr":null}'
    return 0
  fi

  if [ "$runner" = "fixture" ]; then
    local json
    json="$(cat "$runner_fixture")"
    exit_class="$(printf '%s' "$json" | sed -n 's/.*"exit_class":"\([^"]*\)".*/\1/p')"
    sentinel="$(printf '%s' "$json" | sed -n 's/.*"sentinel":"\([^"]*\)".*/\1/p')"
    receipt="$(printf '%s' "$json" | sed -n 's/.*"receipt":"\([^"]*\)".*/\1/p')"
  else
    local out
    # Exit code is redundant with exit_class (parsed below) — the adapter
    # already maps 0/124/1 -> success/timeout/error in its own JSON output.
    out="$("$RUNNER_ADAPTER" run --entity "$slug" --workdir "$controller_worktree" --timeout "$timeout_sec" 2>&1)"
    exit_class="$(printf '%s' "$out" | sed -n 's/.*"exit_class":"\([^"]*\)".*/\1/p')"
    sentinel="$(printf '%s' "$out" | sed -n 's/.*"sentinel":"\([^"]*\)".*/\1/p')"
    receipt="$(printf '%s' "$out" | sed -n 's/.*"receipt":"\([^"]*\)".*/\1/p')"
  fi

  pr_from_sentinel="$(printf '%s' "$sentinel" | sed -n 's/.* pr=\([0-9]*\).*/\1/p')"

  if [ "$exit_class" != "success" ]; then
    local source
    case "$exit_class" in
      timeout) source="run-timeout" ;;
      *) source="run-error" ;;
    esac
    emit_event blocked "$slug" blocked "$source" "$(printf '{"source":"%s","receipt":%s}' "$source" "$(json_str_or_null "$receipt")")"
    return 0
  fi

  local detail
  detail="$(printf '{"runner":{"workdir":"%s","timeout_sec":%s,"exit_class":"%s","sentinel":%s,"receipt":%s},"pr":%s}' \
    "$(json_escape "$controller_worktree")" "$timeout_sec" "$exit_class" "$(json_str_or_null "$sentinel")" "$(json_str_or_null "$receipt")" "$(json_str_or_null "$pr_from_sentinel")")"
  emit_event dispatch "$slug" ok "" "$detail"
}

run_reconcile_action() {
  local path="$1" slug="$2" dry_run="$3" workflow_dir="$4"
  local out reconciler_exit verdict reason detail_str

  out="$(STATUS_BIN="${STATUS_BIN:-}" "$RECONCILER" --workflow-dir "$workflow_dir" --entity "$slug" \
    --pr-provider fixture --pr-fixture "${PR_FIXTURE}" 2>&1)"
  reconciler_exit=$?
  verdict="$(printf '%s\n' "$out" | awk -F= '$1=="verdict"{print $2; exit}')"
  reason="$(printf '%s\n' "$out" | awk -F= '$1=="reason"{print $2; exit}')"

  if [ "$verdict" = "PROMPT_CAPTAIN" ] || [ "$reconciler_exit" = "1" ]; then
    detail_str="$(printf '{"source":"reconciler-prompt-captain","receipt":null,"reconciler_reason":%s}' "$(json_str_or_null "$reason")")"
    emit_event blocked "$slug" blocked reconciler-prompt-captain "$detail_str"
    return 0
  fi

  local pr_val
  pr_val="$(read_frontmatter_field "$path" pr)"
  detail_str="$(printf '{"pr":%s,"reconciler_verdict":"%s","terminal_state":"reconciled"}' "$(json_str_or_null "$pr_val")" "${verdict:-PROCEED}")"
  emit_event reconcile "$slug" ok "" "$detail_str"

  local parent_pitch
  parent_pitch="$(read_frontmatter_field "$path" parent_pitch)"
  if [ -n "$parent_pitch" ] && [ -x "$DAG_WAVES" ]; then
    run_advance_action "$workflow_dir" "$parent_pitch"
  fi
}

run_advance_action() {
  local workflow_dir="$1" epic_id="$2"
  local ready_line next detail
  ready_line="$("$DAG_WAVES" --ready --from-workflow "$workflow_dir" --epic "$epic_id" 2>/dev/null || true)"
  next="$(printf '%s\n' "$ready_line" | awk '{print $1}')"
  local ready_json
  ready_json="$(printf '%s' "$ready_line" | awk '{ for (i=1;i<=NF;i++) printf "%s\"%s\"", (i>1?",":""), $i }')"
  detail="$(printf '{"ready_set":[%s],"dispatched":%s}' "$ready_json" "$(json_str_or_null "$next")")"
  emit_event advance "${next:-}" ok "" "$detail"
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

ACTION="${1:-}"
[ "$#" -gt 0 ] && shift

case "$ACTION" in
  tick) cmd_tick "$@"; exit $? ;;
  report) echo "ship-flow-scheduler: report not yet implemented" >&2; exit 2 ;;
  rollup) echo "ship-flow-scheduler: rollup not yet implemented" >&2; exit 2 ;;
  *) usage; exit 2 ;;
esac
