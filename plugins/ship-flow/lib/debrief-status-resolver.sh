#!/usr/bin/env bash
set -euo pipefail

print0=false
workflow_dir=""
spacedock_plugin_dir=""
status_args=()

usage() {
  cat <<'EOF'
Usage: debrief-status-resolver.sh [--print0] --workflow-dir <dir> [--spacedock-plugin-dir <dir>] -- [status args...]
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --print0)
      print0=true
      shift
      ;;
    --workflow-dir)
      workflow_dir="${2:-}"
      shift 2
      ;;
    --spacedock-plugin-dir)
      spacedock_plugin_dir="${2:-}"
      shift 2
      ;;
    --)
      shift
      status_args=("$@")
      break
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: unknown argument: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

if [ -z "$workflow_dir" ]; then
  echo "ERROR: --workflow-dir is required" >&2
  usage >&2
  exit 2
fi

# --spacedock-plugin-dir is a deprecated no-op (parsed for backward compat
# with callers/tests that still pass it). The packaged python
# commission/bin/status was removed in spacedock 0.19.4; the status helper is
# now the `spacedock` Go binary on PATH, invoked as `spacedock status <args>`.
: "${spacedock_plugin_dir:=}"  # referenced so set -u / shellcheck stay happy

local_status="$workflow_dir/status"
if [ -x "$local_status" ]; then
  argv=("$local_status" "${status_args[@]}")
else
  status_bin="${SHIP_FLOW_STATUS_BIN:-spacedock}"
  if ! command -v "$status_bin" >/dev/null 2>&1; then
    echo "ERROR: no workflow status helper and \`$status_bin\` not found on PATH" >&2
    exit 1
  fi
  argv=("$status_bin" "status" "--workflow-dir" "$workflow_dir" "${status_args[@]}")
fi

if [ "$print0" = true ]; then
  printf '%s\0' "${argv[@]}"
else
  exec "${argv[@]}"
fi
