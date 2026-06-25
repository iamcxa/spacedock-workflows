#!/usr/bin/env bash
# check-version-triple.sh — verify version consistency across the three canonical sites
# for the ship-flow plugin, and that repository points to the standalone repo.
# Exits 0 (PASS) only when all three versions match AND repository is clean.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLUGIN_JSON="$REPO_ROOT/plugins/ship-flow/.claude-plugin/plugin.json"
README="$REPO_ROOT/plugins/ship-flow/README.md"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"

FAIL=0

# --- Extract versions ---
V_PLUGIN=$(jq -r '.version' "$PLUGIN_JSON")
V_MARKETPLACE=$(jq -r '.plugins[] | select(.name=="ship-flow") | .version' "$MARKETPLACE_JSON")
# README H1 token: "# Ship-Flow ... (vX.Y.Z)"
V_README=$(grep -m1 '^# ' "$README" | grep -oE '\(v[^)]+\)' | tr -d '(v)')

echo "plugin.json version   : $V_PLUGIN"
echo "marketplace.json version: $V_MARKETPLACE"
echo "README H1 version     : $V_README"

# --- Check all three match ---
if [ "$V_PLUGIN" != "$V_MARKETPLACE" ] || [ "$V_PLUGIN" != "$V_README" ]; then
  echo "FAIL: version mismatch across sites"
  FAIL=1
else
  echo "OK  : versions match ($V_PLUGIN)"
fi

# --- Check repository field ---
REPO=$(jq -r '.repository' "$PLUGIN_JSON")
echo "plugin.json repository: $REPO"

if echo "$REPO" | grep -qE '(spacedock-dev|/spacebridge$)'; then
  echo "FAIL: repository still points to spacedock-dev/spacebridge"
  FAIL=1
else
  echo "OK  : repository is clean"
fi

if [ "$FAIL" -eq 0 ]; then
  echo "PASS: all checks OK"
  exit 0
else
  exit 1
fi
