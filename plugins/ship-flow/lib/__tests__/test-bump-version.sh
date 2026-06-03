#!/usr/bin/env bash
# test-bump-version.sh — unit test for the ship-flow release bump script.
# Sources plugins/ship-flow/scripts/bump-version.sh (functions only; guarded main
# does NOT run on source) and exercises its pure functions + gate-ordering against
# throwaway fixture trees. NO test-only env hooks in the production script — the
# seam is plain source-able functions + on-disk fixtures (CLAUDE.md slash-command
# authoring discipline).
#
# Asserts (handoff contract):
#   A. bump writes the new version to all 3 release files (plugin.json, marketplace
#      ship-flow entry, README H1) AND they match; sibling marketplace entries and
#      non-H1 body text are left untouched; assert_versions_match reflects synced
#      vs desynced state.
#   B. the release gate blocks on red WITHOUT mutating any release file (gate-first).
set -uo pipefail   # NOT -e: this test drives failure paths and checks them explicitly.

WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
SCRIPT="$WDIR/plugins/ship-flow/scripts/bump-version.sh"

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1"; fail=1; }
check_eq()   { if [ "$2" = "$3" ]; then pass "$1"; else die "$1 (expected '$3', got '$2')"; fi; }
check_grep() { if grep -qE "$2" "$3"; then pass "$1"; else die "$1"; fi; }

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: bump script not found: $SCRIPT"
  exit 1
fi

# shellcheck source=/dev/null
source "$SCRIPT"
set +e   # the sourced script enables `set -e`; restore explicit-check mode for the test.

make_fixture() {  # <dir> <version>
  local d="$1" v="$2"
  mkdir -p "$d/.claude-plugin"
  cat >"$d/.claude-plugin/plugin.json" <<EOF
{ "name": "ship-flow", "version": "$v" }
EOF
  cat >"$d/.claude-plugin/marketplace.json" <<EOF
{ "plugins": [
  { "name": "spacebridge", "version": "$v" },
  { "name": "ship-flow", "version": "$v" }
] }
EOF
  cat >"$d/README.md" <<EOF
# Ship-Flow — Auditable Autonomous Workflow for Claude 4.7 (v$v)

body line that mentions (v$v) but is NOT the H1 — must stay untouched.
EOF
}

# ---------------------------------------------------------------------------
# Test A — bump writes all 3, they match, decoy untouched, body line untouched
# ---------------------------------------------------------------------------
TMPA="$(mktemp -d)"
make_fixture "$TMPA" "0.0.1"
PJ="$TMPA/.claude-plugin/plugin.json"
MP="$TMPA/.claude-plugin/marketplace.json"
RD="$TMPA/README.md"

bump_all_versions "$PJ" "$MP" "$RD" "9.9.9"

check_eq "plugin.json bumped"                    "$(jq -r '.version' "$PJ")"                                          "9.9.9"
check_eq "marketplace ship-flow entry bumped"    "$(jq -r '.plugins[] | select(.name=="ship-flow") | .version' "$MP")"   "9.9.9"
check_eq "marketplace spacebridge decoy untouched" "$(jq -r '.plugins[] | select(.name=="spacebridge") | .version' "$MP")" "0.0.1"
check_grep "README H1 bumped"          '^# Ship-Flow .*\(v9\.9\.9\)$'        "$RD"
check_grep "README body line untouched" 'body line that mentions \(v0\.0\.1\)' "$RD"

if assert_versions_match "$PJ" "$MP" "$RD"; then
  pass "assert_versions_match true when synced"
else
  die "assert_versions_match returned false on a synced fixture"
fi

# Desync plugin.json only — assert_versions_match must now fail.
tmp=$(mktemp); jq '.version="1.2.3"' "$PJ" >"$tmp" && mv "$tmp" "$PJ"
if assert_versions_match "$PJ" "$MP" "$RD"; then
  die "assert_versions_match true on a desynced fixture (should be false)"
else
  pass "assert_versions_match false when desynced"
fi

# ---------------------------------------------------------------------------
# Test B — red gate blocks the release WITHOUT mutating any file (gate-first)
# ---------------------------------------------------------------------------
TMPB="$(mktemp -d)"
make_fixture "$TMPB" "0.0.1"
PJB="$TMPB/.claude-plugin/plugin.json"
MPB="$TMPB/.claude-plugin/marketplace.json"
RDB="$TMPB/README.md"

# Override the gate to simulate a red invariant/test run. run_release calls
# release_gate by name, so bash late-binding picks up this stub (not the real one).
# shellcheck disable=SC2329  # invoked indirectly by run_release via late binding
release_gate() { echo "[stub] release gate RED"; return 1; }

if run_release "$TMPB" "$PJB" "$MPB" "$RDB" "9.9.9"; then
  die "run_release succeeded despite a red gate"
else
  pass "run_release aborted on a red gate"
fi

check_eq "red gate left plugin.json unmutated"   "$(jq -r '.version' "$PJB")"                                         "0.0.1"
check_eq "red gate left marketplace unmutated"   "$(jq -r '.plugins[] | select(.name=="ship-flow") | .version' "$MPB")" "0.0.1"
check_grep "red gate left README unmutated" '^# Ship-Flow .*\(v0\.0\.1\)$' "$RDB"

# ---------------------------------------------------------------------------
# Test C — transactional bump: a selector that silently no-ops (marketplace
# missing the ship-flow entry) aborts WITHOUT half-bumping any file.
# Regression for PR #191 codex finding: gate-before-mutation is not enough; the
# three-file bump itself must be all-or-nothing or a failed release leaves a
# half-bumped working tree.
# ---------------------------------------------------------------------------
TMPC="$(mktemp -d)"
mkdir -p "$TMPC/.claude-plugin"
cat >"$TMPC/.claude-plugin/plugin.json" <<EOF
{ "name": "ship-flow", "version": "0.0.1" }
EOF
# marketplace has NO ship-flow entry — the jq select-assign silently no-ops (exit 0).
cat >"$TMPC/.claude-plugin/marketplace.json" <<EOF
{ "plugins": [ { "name": "spacebridge", "version": "0.0.1" } ] }
EOF
cat >"$TMPC/README.md" <<EOF
# Ship-Flow — Auditable Autonomous Workflow for Claude 4.7 (v0.0.1)
EOF
PJC="$TMPC/.claude-plugin/plugin.json"
MPC="$TMPC/.claude-plugin/marketplace.json"
RDC="$TMPC/README.md"

if bump_all_versions "$PJC" "$MPC" "$RDC" "9.9.9"; then
  die "bump_all_versions succeeded despite a no-op marketplace selector"
else
  pass "bump_all_versions aborts when the ship-flow marketplace entry is absent"
fi
check_eq "aborted bump left plugin.json unmutated" "$(jq -r '.version' "$PJC")" "0.0.1"
check_grep "aborted bump left README unmutated" '^# Ship-Flow .*\(v0\.0\.1\)$' "$RDC"

rm -rf "$TMPA" "$TMPB" "$TMPC"
if [ $fail -eq 0 ]; then
  echo "ALL PASS: test-bump-version"
else
  echo "SOME FAILED: test-bump-version"
fi
exit $fail
