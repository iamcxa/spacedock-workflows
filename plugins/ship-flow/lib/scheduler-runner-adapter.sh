#!/usr/bin/env bash
# scheduler-runner-adapter.sh — the ONLY seam that knows about `claude -p` +
# launchd (design.md §6). Carrier-swap boundary: a later carrier (e.g.
# crewdock) replaces this file's body — spawn into a container, park/resume,
# scavenging — while preserving the CLI + JSON contract below; the tick
# (bin/ship-flow-scheduler.sh) never changes.
#
# Usage:
#   scheduler-runner-adapter.sh run --entity <ref> --workdir <path> \
#       --timeout <sec> [--env K=V]...
#
# Output: exactly one JSON line on stdout:
#   {"exit_class":"success|timeout|error","sentinel":"<marker>|null","receipt":"<abs path>"}
# Exit code maps 0 / 124 (timeout) / 1 (error) from the underlying run.
#
# Test-only seam: when $SHIP_FLOW_SCHEDULER_RUNNER_CMD is set, it replaces the
# real `claude -p "/ship <entity>"` invocation (run via `bash -c`) so
# success/timeout/error can be exercised hermetically. Unset in production —
# the real carrier always spawns `claude -p`.

set -uo pipefail

usage() {
  echo "Usage: scheduler-runner-adapter.sh run --entity <ref> --workdir <path> --timeout <sec> [--env K=V]..." >&2
}

ACTION="${1:-}"
[ "$#" -gt 0 ] && shift
[ "$ACTION" = "run" ] || { usage; exit 2; }

ENTITY=""
WORKDIR=""
TIMEOUT=""
ENV_PAIRS=()
while [ $# -gt 0 ]; do
  case "$1" in
    --entity) ENTITY="${2:-}"; shift 2 ;;
    --workdir) WORKDIR="${2:-}"; shift 2 ;;
    --timeout) TIMEOUT="${2:-}"; shift 2 ;;
    --env) ENV_PAIRS+=("${2:-}"); shift 2 ;;
    *) usage; exit 2 ;;
  esac
done
[ -n "$ENTITY" ] && [ -n "$WORKDIR" ] && [ -n "$TIMEOUT" ] || { usage; exit 2; }
[ -d "$WORKDIR" ] || { echo "scheduler-runner-adapter: no such workdir: $WORKDIR" >&2; exit 2; }

RECEIPT_DIR="${WORKDIR}/.ship-flow-scheduler-receipts"
mkdir -p "$RECEIPT_DIR"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)-$$"
SAFE_ENTITY="$(printf '%s' "$ENTITY" | tr -c 'A-Za-z0-9_.-' '_')"
RECEIPT="${RECEIPT_DIR}/${STAMP}-${SAFE_ENTITY}.txt"

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
  ( cd "$WORKDIR" && run_cmd timeout "$TIMEOUT" claude -p "/ship ${ENTITY}" --output-format text ) > "$RECEIPT" 2>&1
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

json_str_or_null() {
  if [ -z "${1:-}" ]; then printf 'null'; else printf '"%s"' "$(printf '%s' "$1" | sed 's/\\/\\\\/g; s/"/\\"/g')"; fi
}

printf '{"exit_class":"%s","sentinel":%s,"receipt":%s}\n' \
  "$EXIT_CLASS" "$(json_str_or_null "$SENTINEL")" "$(json_str_or_null "$RECEIPT")"

case "$EXIT_CLASS" in
  success) exit 0 ;;
  timeout) exit 124 ;;
  *) exit 1 ;;
esac
