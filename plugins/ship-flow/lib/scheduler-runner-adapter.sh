#!/usr/bin/env bash
# scheduler-runner-adapter.sh — the ONLY seam that knows about `claude -p` +
# launchd (design.md §6). Carrier-swap boundary: a later carrier (e.g.
# crewdock) replaces this file's body — spawn into a container, park/resume,
# scavenging — while preserving the CLI + JSON contract below; the tick
# (bin/ship-flow-scheduler.sh) never changes.
#
# Usage:
#   scheduler-runner-adapter.sh run --entity <ref> --workdir <path> \
#       --timeout <sec> [--env K=V]... [--tick-id <id>] [--print-spawn]
#
# Output: exactly one JSON line on stdout:
#   {"exit_class":"success|timeout|error","sentinel":"<marker>|null","receipt":"<abs path>"}
# Exit code maps 0 / 124 (timeout) / 1 (error) from the underlying run.
#
# --tick-id <id> (AC-1): a mechanical delegation marker. Sets
# SHIP_FLOW_SCHEDULER_TICK_ID=<id> on the spawned child's env and appends a
# delegation line to the prompt naming the tick id + receipt basename, so the
# spawned `/ship` run can mechanically prove tick-delegation (retires the old
# decisions.md 30-min-receipt heuristic).
#
# --print-spawn (AC-1b/AC-2): hermetic mode — prints the resolved
# {"prompt":...,"spawn":...} as JSON and execs nothing (no receipt written).
# Lets tests assert the resolved spawn form without a real spawn.
#
# Test-only seam: when $SHIP_FLOW_SCHEDULER_RUNNER_CMD is set, it replaces the
# real `claude -p "/ship <entity>"` invocation (run via `bash -c`) so
# success/timeout/error can be exercised hermetically. Unset in production —
# the real carrier always spawns `claude -p` (see SPAWN_LINE below).

set -uo pipefail

usage() {
  echo "Usage: scheduler-runner-adapter.sh run --entity <ref> --workdir <path> --timeout <sec> [--env K=V]... [--tick-id <id>] [--print-spawn]" >&2
}

ACTION="${1:-}"
[ "$#" -gt 0 ] && shift
[ "$ACTION" = "run" ] || { usage; exit 2; }

ENTITY=""
WORKDIR=""
TIMEOUT=""
TICK_ID=""
PRINT_SPAWN=no
ENV_PAIRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --entity) ENTITY="${2:-}"; shift 2 ;;
    --workdir) WORKDIR="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --env) ENV_PAIRS+=("${2:-}"); shift 2 ;;
    --tick-id) TICK_ID="${2:-}"; shift 2 ;;
    --print-spawn) PRINT_SPAWN=yes; shift ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "$ENTITY" ] && [ -n "$WORKDIR" ] && [ -n "$TIMEOUT" ] || { usage; exit 2; }
[ -d "$WORKDIR" ] || { echo "scheduler-runner-adapter: no such workdir: $WORKDIR" >&2; exit 2; }

# AC-1: an explicit --tick-id becomes a machine-readable delegation marker on
# the spawned child (both the hermetic SHIP_FLOW_SCHEDULER_RUNNER_CMD branch
# and the real-claude branch see it identically, since both flow through
# run_cmd's env wrapper).
if [ -n "$TICK_ID" ]; then
  ENV_PAIRS+=("SHIP_FLOW_SCHEDULER_TICK_ID=${TICK_ID}")
fi

RECEIPT_DIR="${WORKDIR}/.ship-flow-scheduler-receipts"
mkdir -p "$RECEIPT_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
SAFE_ENTITY="$(printf '%s' "$ENTITY" | tr -c 'A-Za-z0-9_.-' '_')"
RECEIPT="${RECEIPT_DIR}/${STAMP}-${SAFE_ENTITY}.txt"

json_str_or_null() {
  if [ -z "${1:-}" ]; then printf 'null'; else printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; fi
}

# AC-1b: the prompt the spawned `/ship` run receives. A non-empty --tick-id
# appends a delegation line naming the tick id + receipt basename, so the
# spawned FO can mechanically tell "tick delegated me" apart from a manual
# hand-dispatch (retires the old decisions.md 30-min-receipt heuristic).
SHIP_PROMPT="/ship ${ENTITY}"
if [ -n "$TICK_ID" ]; then
  SHIP_PROMPT="${SHIP_PROMPT}
[ship-flow-scheduler tick delegation — tick_id=${TICK_ID} receipt=$(basename "$RECEIPT"); autonomous per Rule 1/10, not a manual hand-dispatch]"
fi

# AC-2: single source-of-truth spawn command string, resolved once and reused
# by both --print-spawn (hermetic inspection) and the real exec branch below
# — never two hand-written forms that can drift apart.
SPAWN_LINE="claude -p \"${SHIP_PROMPT}\" --output-format text"

if [ "$PRINT_SPAWN" = "yes" ]; then
  # Hermetic mode: print the resolved prompt/spawn, exec nothing. Raw
  # newlines inside SHIP_PROMPT/SPAWN_LINE are folded to spaces before JSON
  # encoding -- json_str_or_null only escapes backslash/quote, not literal
  # newlines, so an unfolded multi-line value would break JSONL.
  PROMPT_JSON="$(printf '%s' "$SHIP_PROMPT" | tr '\n' ' ')"
  SPAWN_JSON="$(printf '%s' "$SPAWN_LINE" | tr '\n' ' ')"
  printf '{"prompt":%s,"spawn":%s}\n' "$(json_str_or_null "$PROMPT_JSON")" "$(json_str_or_null "$SPAWN_JSON")"
  exit 0
fi

run_cmd() {
  if [ "${#ENV_PAIRS[@]}" -gt 0 ]; then
    env "${ENV_PAIRS[@]}" "$@"
  else
    "$@"
  fi
}

if [ -n "${SHIP_FLOW_SCHEDULER_RUNNER_CMD:-}" ]; then
  ( cd "$WORKDIR" && run_cmd timeout "$TIMEOUT" bash -c "$SHIP_FLOW_SCHEDULER_RUNNER_CMD" ) > "$RECEIPT" 2>&1
else
  ( cd "$WORKDIR" && run_cmd timeout "$TIMEOUT" bash -c "$SPAWN_LINE" ) > "$RECEIPT" 2>&1
fi
RUN_EXIT=$?

case "$RUN_EXIT" in
  0) EXIT_CLASS="success" ;;
  124) EXIT_CLASS="timeout" ;;
  *) EXIT_CLASS="error" ;;
esac

SENTINEL="$(grep -m1 -E '^SHIP_FLOW_TERMINAL ' "$RECEIPT" 2>/dev/null || true)"
if [ "$EXIT_CLASS" = "success" ] && [ -z "$SENTINEL" ]; then
  # A "successful" exit with no terminal marker is not trustworthy — the run
  # may have exited early without reaching a real terminal state.
  EXIT_CLASS="error"
fi

printf '{"exit_class":"%s","sentinel":%s,"receipt":%s}\n' \
  "$EXIT_CLASS" "$(json_str_or_null "$SENTINEL")" "$(json_str_or_null "$RECEIPT")"

case "$EXIT_CLASS" in
  success) exit 0 ;;
  timeout) exit 124 ;;
  *) exit 1 ;;
esac
