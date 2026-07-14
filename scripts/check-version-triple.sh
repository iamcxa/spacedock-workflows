#!/usr/bin/env bash
# check-version-triple.sh — verify version consistency across the three canonical sites
# for the ship-flow plugin, that repository points to the standalone repo, and
# that the root README does not duplicate release-version claims.
# Exits 0 (PASS) only when all checks pass.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

PLUGIN_JSON="$REPO_ROOT/plugins/ship-flow/.claude-plugin/plugin.json"
README="$REPO_ROOT/plugins/ship-flow/README.md"
MARKETPLACE_JSON="$REPO_ROOT/.claude-plugin/marketplace.json"
ROOT_README="$REPO_ROOT/README.md"

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

# --- Keep root documentation independent of any particular release ---
VERSION_LITERAL_PATTERN='(^|[^[:alnum:]_])v?[0-9]+\.[0-9]+(\.([0-9]+|x))?([^[:alnum:]_]|$)'
if ROOT_README_VERSION_LINES=$(grep -nE -- "$VERSION_LITERAL_PATTERN" "$ROOT_README"); then
  echo "FAIL: root README contains version-shaped literal"
  echo "$ROOT_README_VERSION_LINES"
  FAIL=1
else
  echo "OK  : root README is version-independent"
fi

if [ "$FAIL" -eq 0 ]; then
  echo "PASS: all checks OK"
  exit 0
else
  exit 1
fi
