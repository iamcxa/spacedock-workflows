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

local_status="$workflow_dir/status"
if [ -x "$local_status" ]; then
  argv=("$local_status" "${status_args[@]}")
else
  if [ -z "$spacedock_plugin_dir" ]; then
    script_dir="$(cd "$(dirname "$0")" && pwd)"
    spacedock_plugin_dir="$(cd "$script_dir/../../spacedock" 2>/dev/null && pwd || true)"
  fi
  packaged_status="$spacedock_plugin_dir/skills/commission/bin/status"
  if [ ! -f "$packaged_status" ]; then
    echo "ERROR: no workflow status helper and packaged status not found: $packaged_status" >&2
    exit 1
  fi
  argv=("python3" "$packaged_status" "--workflow-dir" "$workflow_dir" "${status_args[@]}")
fi

if [ "$print0" = true ]; then
  printf '%s\0' "${argv[@]}"
else
  exec "${argv[@]}"
fi
