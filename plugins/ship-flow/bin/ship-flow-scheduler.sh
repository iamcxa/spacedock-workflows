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

# Whitelist, fail-closed (AC-2): empty/draft (pre-shape) and done (terminal)
# are not shaped, and neither is any unrecognized status value.
is_shaped() {
  case "$1" in
    shape|design|plan|execute|verify|review|ship) return 0 ;;
    *) return 1 ;;
  esac
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

  # --- Precedence 1: reconcile (a merged PR exists, or a PR that closed
  # without merging needs a captain prompt — anything OTHER than "still
  # legitimately open" is reconcile-worthy; an OPEN PR is skipped here, it is
  # not yet actionable) ---
  local path slug pr_val pr_state
  for path in $(list_entities "$workflow_dir"); do
    slug="$(entity_slug_from_path "$path")"
    pr_val="$(read_frontmatter_field "$path" pr)"
    [ -n "$pr_val" ] || continue
    [ "$(read_frontmatter_field "$path" status)" != "done" ] || continue
    pr_state="$(gh_pr_state "$slug" "$pr_val")"
    if [ "$pr_state" != "OPEN" ]; then
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
  if [ -n "$epic" ] && [ -f "$DAG_WAVES" ]; then
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

  # Pre-read: on PROCEED the reconciler archives the entity (the folder moves
  # to _archive/), so any frontmatter needed after the call must be read now.
  local pr_val parent_pitch
  pr_val="$(read_frontmatter_field "$path" pr)"
  parent_pitch="$(read_frontmatter_field "$path" parent_pitch)"

  local provider_args=(--pr-provider gh)
  if [ -n "${PR_FIXTURE:-}" ]; then
    provider_args=(--pr-provider fixture --pr-fixture "$PR_FIXTURE")
  fi

  out="$(STATUS_BIN="${STATUS_BIN:-}" "$RECONCILER" --workflow-dir "$workflow_dir" --entity "$slug" \
    "${provider_args[@]}" 2>&1)"
  reconciler_exit=$?
  verdict="$(printf '%s\n' "$out" | awk -F= '$1=="verdict"{print $2; exit}')"
  reason="$(printf '%s\n' "$out" | awk -F= '$1=="reason"{print $2; exit}')"

  if [ "$verdict" = "PROMPT_CAPTAIN" ] || [ "$reconciler_exit" = "1" ]; then
    detail_str="$(printf '{"source":"reconciler-prompt-captain","receipt":null,"reconciler_reason":%s}' "$(json_str_or_null "$reason")")"
    emit_event blocked "$slug" blocked reconciler-prompt-captain "$detail_str"
    return 0
  fi

  if [ "$reconciler_exit" != "0" ] || [ "$verdict" != "PROCEED" ]; then
    # Fail closed: REJECT (exit 2) or a crashed/partial reconciler run is
    # never treated as a successful reconcile (Rule 4: no retry — terminal
    # blocked, visible in the morning report).
    detail_str="$(printf '{"source":"reconciler-error","receipt":null,"reconciler_reason":%s}' "$(json_str_or_null "${reason:-exit-${reconciler_exit}}")")"
    emit_event blocked "$slug" blocked reconciler-error "$detail_str"
    return 0
  fi

  detail_str="$(printf '{"pr":%s,"reconciler_verdict":"PROCEED","terminal_state":"reconciled"}' "$(json_str_or_null "$pr_val")")"
  emit_event reconcile "$slug" ok "" "$detail_str"

  if [ -n "$parent_pitch" ] && [ -f "$DAG_WAVES" ]; then
    run_advance_action "$workflow_dir" "$parent_pitch"
  fi
}

# emit_epic_tsv_line <file> <epic> — one "id<TAB>status<TAB>deps" line if the
# file's entity belongs to the epic. The frontmatter parse is copied VERBATIM
# from dag-waves.sh emit_from_workflow (same keys, both depends-on/depends_on,
# inline + block + scalar forms) — duplicated rather than patched in because
# the plan pins dag-waves.sh itself unchanged, and its --from-workflow mode
# cannot see _archive/: a just-reconciled parent has moved there, and without
# its done row the child's depends-on fails dag-waves' fail-closed closure
# check (exit 3). The readiness COMPUTATION still runs inside dag-waves via
# its documented --stdin mode; only the corpus read lives here.
emit_epic_tsv_line() {
  local f="$1" epic="$2"
  awk -v epic="$epic" '
    BEGIN { infm=0; id=""; st=""; deps=""; parent=""; indep=0 }
    /^---[[:space:]]*$/ { infm++; if (infm==2) exit; next }
    infm!=1 { next }
    /^id:/                { v=$0; sub(/^id:[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); id=v; next }
    /^status:/            { v=$0; sub(/^status:[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); st=v; next }
    /^(parent_pitch|parent):/ { v=$0; sub(/^[a-z_]+:[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); parent=v; next }
    /^depends[-_]on:[[:space:]]*\[/ { v=$0; sub(/^depends[-_]on:[[:space:]]*\[/,"",v); sub(/\].*$/,"",v); gsub(/["'\'' ]/,"",v); deps=v; next }
    /^depends[-_]on:[[:space:]]*$/  { indep=1; next }
    /^depends[-_]on:[[:space:]]*[^[:space:]]/ {
      v=$0; sub(/^depends[-_]on:[[:space:]]*/,"",v); sub(/[[:space:]]*$/,"",v)
      if (v=="none" || v=="[]" || v=="null" || v=="~") { deps=""; next }
      gsub(/["'\'' ]/,"",v); deps=v; next
    }
    indep==1 && /^[[:space:]]*-[[:space:]]*/ { v=$0; sub(/^[[:space:]]*-[[:space:]]*/,"",v); gsub(/["'\'' ]/,"",v); deps=(deps=="")?v:(deps","v); next }
    indep==1 { indep=0 }
    END {
      if (parent==epic && id!="") printf "%s\t%s\t%s\n", id, st, deps
    }
  ' "$f"
}

run_advance_action() {
  local workflow_dir="$1" epic_id="$2"
  local f line tsv="" map=""
  for f in "$workflow_dir"/*/index.md "$workflow_dir"/_archive/*/index.md; do
    [ -f "$f" ] || continue
    line="$(emit_epic_tsv_line "$f" "$epic_id")"
    [ -n "$line" ] || continue
    tsv="${tsv}${line}
"
    map="${map}${line%%$'\t'*} $(entity_slug_from_path "$f")
"
  done

  local ready_line=""
  if [ -n "$tsv" ]; then
    ready_line="$(printf '%s' "$tsv" | bash "$DAG_WAVES" --ready --stdin 2>/dev/null || true)"
  fi

  # dag-waves speaks entity ids; the event schema (design.md §2) speaks slugs.
  local ready_slugs="" rid slug
  for rid in $ready_line; do
    slug="$(printf '%s' "$map" | awk -v id="$rid" '$1==id{print $2; exit}')"
    ready_slugs="${ready_slugs}${ready_slugs:+ }${slug:-$rid}"
  done

  local next ready_json detail
  next="$(printf '%s\n' "$ready_slugs" | awk '{print $1}')"
  ready_json="$(printf '%s' "$ready_slugs" | awk '{ for (i=1;i<=NF;i++) printf "%s\"%s\"", (i>1?",":""), $i }')"
  detail="$(printf '{"ready_set":[%s],"dispatched":%s}' "$ready_json" "$(json_str_or_null "$next")")"
  emit_event advance "${next:-}" ok "" "$detail"
}

# ---------------------------------------------------------------------------
# report subcommand (design.md §7, AC-4) — read-only, no writable gate ledger.
# Rows limited to non-terminal projections this CLI signature can actually
# derive without a controller-worktree/lease input (design's `report` CLI
# takes only --workflow-dir [--json]): awaiting_merge and merged. `running`/
# `blocked` need lease/receipt state this subcommand's signature doesn't
# accept — a v0 narrowing, recorded rather than silently dropped.
# ---------------------------------------------------------------------------

entity_age_days() {
  local started="$1" started_epoch now_epoch
  [ -n "$started" ] || { printf 'n/a\n'; return 0; }
  started_epoch="$(scheduler_lease_epoch "$started")"
  [ "$started_epoch" != "0" ] || { printf 'n/a\n'; return 0; }
  now_epoch="$(date -u +%s)"
  printf '%s\n' "$(( (now_epoch - started_epoch) / 86400 ))"
}

pr_head_sha() {
  local slug="$1" pr="$2"
  [ -n "$pr" ] || { printf 'n/a\n'; return 0; }
  if [ "$GH_PROVIDER" = "fixture" ]; then
    local f="${GH_FIXTURE_DIR}/pr-${slug}.env"
    [ -f "$f" ] || { printf 'n/a\n'; return 0; }
    local sha
    sha="$(awk -F= '$1=="head_sha"{print $2; exit}' "$f")"
    printf '%s\n' "${sha:-n/a}"
    return 0
  fi
  command -v gh >/dev/null 2>&1 || { printf 'n/a\n'; return 0; }
  gh pr view "$pr" --json headRefOid --jq .headRefOid 2>/dev/null || printf 'n/a\n'
}

cmd_report() {
  local workflow_dir="" json_out=no
  GH_PROVIDER="gh"; GH_FIXTURE_DIR=""

  while [ $# -gt 0 ]; do
    case "$1" in
      --workflow-dir) workflow_dir="${2:-}"; shift 2 ;;
      --json) json_out=yes; shift ;;
      --gh-provider) GH_PROVIDER="${2:-}"; shift 2 ;;
      --gh-fixture-dir) GH_FIXTURE_DIR="${2:-}"; shift 2 ;;
      *) usage; return 2 ;;
    esac
  done
  [ -n "$workflow_dir" ] || { usage; return 2; }
  [ -d "$workflow_dir" ] || { echo "ship-flow-scheduler: no such workflow-dir: $workflow_dir" >&2; return 3; }

  local path slug pr_val status verdict pr_state state age head gh_checks cross_model
  local rows_md="" rows_json="" first=yes

  for path in $(list_entities "$workflow_dir"); do
    slug="$(entity_slug_from_path "$path")"
    pr_val="$(read_frontmatter_field "$path" pr)"
    [ -n "$pr_val" ] || continue
    status="$(read_frontmatter_field "$path" status)"
    [ "$status" != "done" ] || continue
    verdict="$(read_frontmatter_field "$path" verdict)"
    pr_state="$(gh_pr_state "$slug" "$pr_val")"

    state=""
    if [ "$pr_state" = "MERGED" ]; then
      state="merged"
    elif [ "$pr_state" = "OPEN" ] && [ "$verdict" = "PASSED" ]; then
      state="awaiting_merge"
    fi
    [ -n "$state" ] || continue

    age="$(entity_age_days "$(read_frontmatter_field "$path" started)")"
    head="$(pr_head_sha "$slug" "$pr_val")"
    gh_checks="n/a"
    cross_model="n/a"

    if [ "$json_out" = "yes" ]; then
      [ "$first" = yes ] || rows_json="${rows_json},"
      rows_json="${rows_json}$(printf '{"entity":"%s","state":"%s","pr_head":"%s","verify_verdict":%s,"gh_checks":"%s","cross_model":"%s","age":"%s"}' \
        "$(json_escape "$slug")" "$state" "$(json_escape "$head")" "$(json_str_or_null "$verdict")" "$gh_checks" "$cross_model" "$age")"
    else
      rows_md="${rows_md}| ${slug} | ${state} | ${head} | ${verdict:-n/a} | ${gh_checks} | ${cross_model} | ${age} |
"
    fi
    first=no
  done

  if [ "$json_out" = "yes" ]; then
    printf '[%s]\n' "$rows_json"
  else
    printf '| entity | state | pr_head | verify_verdict | gh_checks | cross_model | age |\n'
    printf '| --- | --- | --- | --- | --- | --- | --- |\n'
    printf '%s' "$rows_md"
  fi
  return 0
}

# ---------------------------------------------------------------------------
# rollup subcommand (design.md §8, AC-6) — deterministic daily counts from a
# day's JSONL events. No wall-clock in the body (only the echoed --date), no
# semantic synthesis (Rule 7 — lessons route through harvest-decide), sorted
# keys, byte-identical across runs on the same input.
# ---------------------------------------------------------------------------

cmd_rollup() {
  local events_log="" date_arg=""
  while [ $# -gt 0 ]; do
    case "$1" in
      --events-log) events_log="${2:-}"; shift 2 ;;
      --date) date_arg="${2:-}"; shift 2 ;;
      *) usage; return 2 ;;
    esac
  done
  [ -n "$events_log" ] && [ -n "$date_arg" ] || { usage; return 2; }
  [ -f "$events_log" ] || { echo "ship-flow-scheduler: no such events log: $events_log" >&2; return 3; }

  local day_events
  day_events="$(grep "\"ts\":\"${date_arg}T" "$events_log" || true)"
  if [ -z "$day_events" ]; then
    echo "ship-flow-scheduler: no events for date ${date_arg} in ${events_log}" >&2
    return 3
  fi

  printf '%s\n' "$day_events" | awk -v date="$date_arg" '
    function get(line, key,   v) {
      # first match of "key":"value" (string values only)
      if (match(line, "\"" key "\":\"[^\"]*\"") == 0) return ""
      v = substr(line, RSTART, RLENGTH)
      sub("^\"" key "\":\"", "", v); sub("\"$", "", v)
      return v
    }
    function ts_seconds(ts,   h, m, s) {
      # HH:MM:SS from RFC3339 -> seconds-of-day (same-day deltas only)
      h = substr(ts, 12, 2); m = substr(ts, 15, 2); s = substr(ts, 18, 2)
      return h * 3600 + m * 60 + s
    }
    {
      event = get($0, "event")
      entity = get($0, "entity")
      ts = get($0, "ts")
      counts[event]++
      total++
      if (event == "dispatch") {
        dispatches++
        # duration: detail.runner.timeout_sec is the bound, not the actual —
        # actual per-run duration needs receipt telemetry (cost/duration both
        # deferred with the cut-list rollup-cost follow-up). Record dispatch ts
        # for gate-wait computation instead.
        dispatch_ts[entity] = ts
      }
      if (event == "reconcile") {
        if (entity in dispatch_ts) {
          waits = waits sprintf("- %s: %ds dispatch->reconcile\n", entity, ts_seconds(ts) - ts_seconds(dispatch_ts[entity]))
          nwaits++
        }
      }
      if (event == "blocked") { failures++ ; interventions++ }
      if (event == "refusal") { interventions++ }
      reason = get($0, "reason")
      if (event == "blocked" && reason == "reconciler-prompt-captain") prompt_captains++
    }
    END {
      printf "# ship-flow-scheduler daily rollup — %s\n\n", date
      printf "## Counts\n\n"
      printf "- total events: %d\n", total
      n = asorti_portable(counts, keys)
      for (i = 1; i <= n; i++) printf "- %s: %d\n", keys[i], counts[keys[i]]
      printf "\n## Dispatches\n\n- dispatches: %d\n", dispatches
      printf "\n## Durations\n\n- per-dispatch runtime: n/a (receipt telemetry deferred)\n"
      printf "\n## Gate waits\n\n"
      if (nwaits > 0) printf "%s", waits
      else printf "- none observed\n"
      printf "\n## Failures\n\n- blocked: %d\n", failures
      printf "\n## Costs\n\n- costs: n/a (receipt cost extraction deferred)\n"
      printf "\n## Interventions\n\n- interventions (blocked + refusal): %d\n- reconciler PROMPT_CAPTAIN: %d\n", interventions, prompt_captains
    }
    # POSIX awk has no asorti; insertion-sort the keys (same portability rule
    # as dag-waves.sh).
    function asorti_portable(arr, out,   k, n, i, j, key) {
      n = 0
      for (k in arr) out[++n] = k
      for (i = 2; i <= n; i++) { key = out[i]; j = i - 1
        while (j >= 1 && out[j] > key) { out[j+1] = out[j]; j-- } out[j+1] = key }
      return n
    }
  '
  return 0
}

# ---------------------------------------------------------------------------
# main
# ---------------------------------------------------------------------------

ACTION="${1:-}"
[ "$#" -gt 0 ] && shift

case "$ACTION" in
  tick) cmd_tick "$@"; exit $? ;;
  report) cmd_report "$@"; exit $? ;;
  rollup) cmd_rollup "$@"; exit $? ;;
  *) usage; exit 2 ;;
esac
