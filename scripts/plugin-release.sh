#!/usr/bin/env bash
# scripts/plugin-release.sh
# ABOUTME: Thin release peer — delegates to plugins/ship-flow/scripts/bump-version.sh.
#
# Usage: scripts/plugin-release.sh ship-flow <new-version>
# Example: scripts/plugin-release.sh ship-flow 0.7.0
#
# bump-version.sh already resolves repo_root as $shipflow_root/../.. which equals
# the yangon repo root in this standalone layout — the triple-bump path math is correct
# with no adjustment needed. This wrapper simply dispatches to that script.
set -euo pipefail

plugin="${1:-}"
version="${2:-}"

if [ -z "$plugin" ] || [ -z "$version" ]; then
  echo "Usage: scripts/plugin-release.sh <plugin-name> <new-version>" >&2
  echo "Example: scripts/plugin-release.sh ship-flow 0.7.0" >&2
  exit 1
fi

script_dir="$(cd "$(dirname "$0")" && pwd)"
repo_root="$(cd "$script_dir/.." && pwd)"

case "$plugin" in
  ship-flow)
    exec bash "$repo_root/plugins/ship-flow/scripts/bump-version.sh" "$version"
    ;;
  *)
    echo "ERROR: unknown plugin '$plugin'. Known plugins: ship-flow" >&2
    exit 1
    ;;
esac
