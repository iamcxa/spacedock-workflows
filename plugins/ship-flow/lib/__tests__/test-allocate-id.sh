#!/usr/bin/env bash
# test-allocate-id.sh — unit + integration test for the ship-flow native id allocator.
# Sources plugins/ship-flow/lib/allocate-id.sh (functions only; guarded main does NOT
# run on source) and exercises its pure functions + the worktree-aware, reservation-based
# allocation against real throwaway git repos. NO test-only env hooks in the production
# script — the seam is plain source-able functions + on-disk fixtures + real git worktrees.
#
# Contract (codex-validated Tier-1 design): ship-flow owns id allocation because spacedock
# v1 refuses `--next-id` for id-style:slug. The allocator returns the next TOP-LEVEL numeric
# prefix for the `<N>-<slug>` + `.N`-children scheme. It must be:
#   - worktree-aware  (max across ALL git worktrees, not just main — fixes the worktree-blind race)
#   - archive-aware   (counts docs/<wf>/_archive too)
#   - dotted-aware    (118.1-child contributes integer part 118, not a new top-level)
#   - atomic + reservation-based (writes a reservation BEFORE returning, so a second
#                                 allocation before the entity materializes does not collide)
set -uo pipefail   # NOT -e: this test drives failure/edge paths and checks them explicitly.

WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
SCRIPT="$WDIR/plugins/ship-flow/lib/allocate-id.sh"

fail=0
pass() { echo "PASS: $1"; }
die()  { echo "FAIL: $1"; fail=1; }
check_eq() { if [ "$2" = "$3" ]; then pass "$1"; else die "$1 (expected '$3', got '$2')"; fi; }

if [ ! -f "$SCRIPT" ]; then
  echo "FAIL: allocator not found: $SCRIPT"
  exit 1
fi
# shellcheck source=/dev/null
source "$SCRIPT"
set +e   # the sourced script enables `set -e`; restore explicit-check mode for the test.

# ---------------------------------------------------------------------------
# Pure function: scan_max_prefix <dir>...
# ---------------------------------------------------------------------------
TMP_SCAN="$(mktemp -d)"
mkdir -p "$TMP_SCAN/wf/001-alpha" "$TMP_SCAN/wf/118-beta" "$TMP_SCAN/wf/_archive/200-old" "$TMP_SCAN/wf/118.1-child"
: > "$TMP_SCAN/wf/005-gamma.md"
mkdir -p "$TMP_SCAN/wf/adoption-readiness-audit"   # non-numeric → ignored
check_eq "scan_max_prefix: max across folder+flat+archive (200 from _archive)" "$(scan_max_prefix "$TMP_SCAN/wf")" "200"

TMP_EMPTY="$(mktemp -d)"; mkdir -p "$TMP_EMPTY/wf"
check_eq "scan_max_prefix: empty workflow dir → 0" "$(scan_max_prefix "$TMP_EMPTY/wf")" "0"

# dotted child contributes integer part, not a new top-level
TMP_DOT="$(mktemp -d)"; mkdir -p "$TMP_DOT/wf/118-beta" "$TMP_DOT/wf/118.2-child"
check_eq "scan_max_prefix: dotted child 118.2 → integer part 118 (no inflation)" "$(scan_max_prefix "$TMP_DOT/wf")" "118"

# multiple dirs (simulating worktrees): max across all
check_eq "scan_max_prefix: max across multiple dirs (worktree simulation)" "$(scan_max_prefix "$TMP_DOT/wf" "$TMP_SCAN/wf")" "200"

# ---------------------------------------------------------------------------
# Pure function: reservations_max <file> + compute_next
# ---------------------------------------------------------------------------
RES="$(mktemp)"
printf '119 1700000000 a\n120 1700000001 b\n' > "$RES"
check_eq "reservations_max: highest reserved number" "$(reservations_max "$RES")" "120"
check_eq "reservations_max: missing file → 0" "$(reservations_max "$RES.nope")" "0"
check_eq "compute_next: max(existing,reserved)+1" "$(compute_next 118 120)" "121"
check_eq "compute_next: existing wins when higher" "$(compute_next 205 120)" "206"

# ---------------------------------------------------------------------------
# Pure function: prune_reservations <file> <ttl> <now> <materialized-space-list>
# drop lines that are stale (age>ttl) OR already materialized as entities
# ---------------------------------------------------------------------------
RES2="$(mktemp)"
printf '119 1000 fresh\n120 1000 materialized\n121 999999999999 future-fresh\n' > "$RES2"
# now huge so 119/120 are stale by ttl; but 120 also materialized; 121 ts in far future = fresh.
prune_reservations "$RES2" 3600 2000000000 "120"
remaining="$(awk '{print $1}' "$RES2" | sort -n | tr '\n' ',')"
check_eq "prune_reservations: drops stale + materialized, keeps fresh" "$remaining" "121,"

# ---------------------------------------------------------------------------
# Integration: allocate_id in a REAL git repo with a worktree.
# BASE holds BOTH the repo and the sibling worktree so the worktree path is
# unique per run (never a shared temp-root path that collides across runs).
# ---------------------------------------------------------------------------
BASE="$(mktemp -d)"
REPO="$BASE/repo"
mkdir -p "$REPO"
(
  cd "$REPO" || exit 1
  git init -q; git config user.email t@t; git config user.name t
  mkdir -p docs/wf/118-main-entity
  : > docs/wf/118-main-entity/index.md
  git add -A; git commit -qm init
  # second worktree carrying an unmerged higher entity (the worktree-blind race scenario)
  git worktree add -q "$BASE/wt-b" -b feat-b
  mkdir -p "$BASE/wt-b/docs/wf/119-worktree-entity"
  : > "$BASE/wt-b/docs/wf/119-worktree-entity/index.md"
) || die "integration fixture setup failed"

# allocate from the MAIN repo: must see 119 in the sibling worktree (worktree-aware) → 120
n1="$( cd "$REPO" && allocate_id docs/wf )"
check_eq "allocate_id: worktree-aware (sees unmerged 119 in sibling worktree) → 120" "$n1" "120"

# reservation lives in the SHARED git-common-dir (resolve it; may be relative to cwd)
COMMON="$( cd "$REPO" && cd "$(git rev-parse --git-common-dir)" && pwd )"
if [ -f "$COMMON/ship-flow-id-reservations" ]; then
  pass "allocate_id: reservation written to shared git-common-dir"
else
  die "no reservation file in git-common-dir ($COMMON)"
fi

# second allocation WITHOUT materializing 120: reservation must prevent collision → 121
n2="$( cd "$REPO" && allocate_id docs/wf )"
check_eq "allocate_id: reservation prevents collision (120 reserved, not yet materialized) → 121" "$n2" "121"

rm -rf "$TMP_SCAN" "$TMP_EMPTY" "$TMP_DOT" "$RES" "$RES2" "$BASE" 2>/dev/null
if [ $fail -eq 0 ]; then
  echo "ALL PASS: test-allocate-id"
else
  echo "SOME FAILED: test-allocate-id"
fi
exit $fail
