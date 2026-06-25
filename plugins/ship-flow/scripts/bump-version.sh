#!/usr/bin/env bash
# plugins/ship-flow/scripts/bump-version.sh
# ABOUTME: Atomic ship-flow version bump — plugin.json + marketplace.json ship-flow entry + README H1.
# Invoked via the repo-local maintainer /plugin-release command (`/plugin-release ship-flow <ver>`)
# or directly from shell.
#
# ship-flow is a DEFINITION-layer plugin: it ships no built artifact (no ui-dist).
# Its release gate is therefore correctness-of-definition, not a build:
#   bin/check-invariants.sh  +  the lib/__tests__ shell suite  must be green.
# The gate runs BEFORE any version mutation; a red gate aborts with zero file changes.
#
# Testability: the bump/assert/gate steps are plain source-able functions so
# plugins/ship-flow/lib/__tests__/test-bump-version.sh can drive them against
# throwaway fixtures. There are deliberately NO test-only env hooks in this script
# (CLAUDE.md slash-command authoring discipline) — the seam is the functions + fixtures.
set -euo pipefail

# ---------------------------------------------------------------------------
# Pure, source-able functions (no global state; safe to source from tests)
# ---------------------------------------------------------------------------

validate_semver() {  # <version>
  echo "$1" | grep -qE '^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?$'
}

# Pure renderers: read <src>, write the bumped content to stdout. No mutation —
# the transactional bump_all_versions builds all three to temp files first, so a
# selector that silently no-ops (missing/renamed marketplace entry, drifted H1
# token) is caught BEFORE any file is swapped, never half-bumping the tree.
render_plugin_json() {  # <plugin.json> <version>
  jq --arg v "$2" '.version = $v' "$1"
}

render_marketplace() {  # <marketplace.json> <version> — only the ship-flow entry
  jq --arg v "$2" '(.plugins[] | select(.name == "ship-flow") | .version) = $v' "$1"
}

render_readme_h1() {  # <README.md> <version> — only the H1 "(vX.Y.Z)" token
  sed -E "/^# Ship-Flow/ s/\(v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?\)/(v$2)/" "$1"
}

bump_all_versions() {  # <plugin.json> <marketplace.json> <README.md> <version>
  local pj="$1" mp="$2" rd="$3" v="$4" pj_tmp mp_tmp rd_tmp
  pj_tmp=$(mktemp); mp_tmp=$(mktemp); rd_tmp=$(mktemp)

  render_plugin_json "$pj" "$v" > "$pj_tmp"
  render_marketplace "$mp" "$v" > "$mp_tmp"
  render_readme_h1  "$rd" "$v" > "$rd_tmp"

  # Pre-swap gate: every rendered copy MUST carry the new version. plugin.json is a
  # direct assignment (always lands), so assert_versions_match passing means the
  # marketplace ship-flow entry and the README H1 token both resolved to $v too.
  # Any silent no-op fails here → remove all temps → zero files changed.
  if [ "$(jq -r '.version' "$pj_tmp")" != "$v" ] || ! assert_versions_match "$pj_tmp" "$mp_tmp" "$rd_tmp"; then
    rm -f "$pj_tmp" "$mp_tmp" "$rd_tmp"
    echo "ERROR: version $v did not apply to all of plugin.json / marketplace.json (ship-flow entry) / README H1 — no files changed." >&2
    return 1
  fi

  # All three known-good — swap in place (each mv is atomic).
  mv "$pj_tmp" "$pj" && mv "$mp_tmp" "$mp" && mv "$rd_tmp" "$rd"
}

assert_versions_match() {  # <plugin.json> <marketplace.json> <README.md>
  local pj_v mkt_v rd_v
  pj_v=$(jq -r '.version' "$1")
  mkt_v=$(jq -r '.plugins[] | select(.name == "ship-flow") | .version' "$2")
  rd_v=$(grep -E '^# Ship-Flow' "$3" \
          | grep -oE '\(v[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.-]+)?\)' \
          | head -1 | sed -E 's/^\(v//; s/\)$//')
  [ -n "$pj_v" ] && [ "$pj_v" = "$mkt_v" ] && [ "$pj_v" = "$rd_v" ]
}

release_gate() {  # <ship-flow plugin root>
  local root="$1" t
  echo "[bump-version] Release gate 1/2: bin/check-invariants.sh"
  bash "$root/bin/check-invariants.sh"
  echo "[bump-version] Release gate 2/2: lib/__tests__ shell suite (CI mode)"
  # Run the suite exactly as CI does — with the standard CI=true env set. The repo
  # convention is that work-in-progress harnesses (agent-output-dependent tests, and
  # intentional-RED in-progress-entity tests) skip-pass under CI=true instead of
  # exiting non-zero; bare-mode non-zero exits are "needs real work" signals, not gate
  # failures. CI=true is the standard CI variable the tests already key off — NOT a
  # bespoke test hook. A test that fails even under CI=true aborts the release (set -e).
  for t in "$root"/lib/__tests__/test-*.sh; do
    echo "  == $(basename "$t") =="
    CI=true bash "$t"
  done
  # bin node tests gate — requires node >= 18 (--test runner built-in)
  if command -v node >/dev/null 2>&1; then
    echo "  == bin/*.test.mjs (node --test) =="
    node --test "$root"/bin/*.test.mjs
  else
    echo "  SKIP: bin/*.test.mjs — node not found on PATH"
  fi
}

run_release() {  # <plugin root> <plugin.json> <marketplace.json> <README.md> <version>
  local root="$1" pj="$2" mp="$3" rd="$4" v="$5"
  # Gate FIRST, explicit check — must block in ANY caller context, not via set -e.
  if ! release_gate "$root"; then
    echo "ERROR: release gate failed — aborting before any version mutation." >&2
    return 1
  fi
  # bump_all_versions is transactional: it validates all three rendered copies
  # before swapping any in, so a failure here leaves zero files changed.
  if ! bump_all_versions "$pj" "$mp" "$rd" "$v"; then
    return 1
  fi
  # Post-swap sanity re-check on the on-disk files (defense in depth).
  if ! assert_versions_match "$pj" "$mp" "$rd"; then
    echo "ERROR: post-bump version mismatch across plugin.json / marketplace.json / README H1." >&2
    return 1
  fi
}

release_commit_subject() {  # <version>
  printf 'chore(ship-flow): release %s\n' "$1"
}

# ---------------------------------------------------------------------------
# Entry point (runs only when executed, not when sourced)
# ---------------------------------------------------------------------------

main() {
  local new_version="${1:-}"
  if [ -z "$new_version" ]; then
    echo "Usage: bump-version.sh <new-version>" >&2
    echo "Example: bump-version.sh 0.7.0" >&2
    exit 1
  fi
  if ! validate_semver "$new_version"; then
    echo "ERROR: '$new_version' is not a valid semver version" >&2
    exit 1
  fi
  if ! command -v jq >/dev/null 2>&1; then
    echo "ERROR: jq required but not installed. Install: brew install jq (macOS) or apt-get install jq (Linux)" >&2
    exit 1
  fi

  local script_dir shipflow_root repo_root plugin_json marketplace_json readme old_version commit_subject
  script_dir="$(cd "$(dirname "$0")" && pwd)"
  shipflow_root="$(cd "$script_dir/.." && pwd)"
  repo_root="$(cd "$shipflow_root/../.." && pwd)"
  plugin_json="$shipflow_root/.claude-plugin/plugin.json"
  marketplace_json="$repo_root/.claude-plugin/marketplace.json"
  readme="$shipflow_root/README.md"

  old_version=$(jq -r '.version' "$plugin_json")
  echo "[bump-version] ship-flow $old_version → $new_version"
  echo "[bump-version] (definition-layer plugin — no ui-dist/artifact build)"

  run_release "$shipflow_root" "$plugin_json" "$marketplace_json" "$readme" "$new_version"

  # Stage ONLY the release paths, explicit pathspec (no -A; parallel-session defense).
  cd "$repo_root" || exit 1
  git add -- "$plugin_json" "$marketplace_json" "$readme"

  echo ""
  echo "=== Staged changes ==="
  git diff --cached --stat
  echo ""
  commit_subject="$(release_commit_subject "$new_version")"
  read -r -p "Commit as '$commit_subject'? [Enter to commit, Ctrl-C to abort] "

  git commit -m "$commit_subject" -- "$plugin_json" "$marketplace_json" "$readme"
  echo "[bump-version] Committed. Run 'git push' manually when ready to release."
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  main "$@"
fi
