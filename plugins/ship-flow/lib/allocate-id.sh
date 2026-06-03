#!/usr/bin/env bash
# allocate-id.sh — ship-flow native, worktree-aware, reservation-based atomic
# numeric-prefix allocator for the `<N>-<slug>` + `.N`-children entity scheme.
#
# WHY this exists (not a wrapper over spacedock): spacedock v1 refuses
# `status --next-id` for `id-style: slug`, and ship-flow's hybrid scheme
# (numeric top-level prefix + slug + dotted children) needs the numeric. So
# ship-flow OWNS allocation. The documented pain it fixes (see todos
# upstream-next-id-atomic-reservation / spacedock-status-folder-layout-blind /
# ship-flow-renumber-skill-atomic / spacedock-next-id-archive-awareness):
#   - worktree-blind: a plain `max+1` on the main checkout misses entities that
#     only exist in sibling git worktrees (unmerged) → ID race.
#   - non-atomic: read-then-write gap lets two sessions pick the same number.
#   - archive-blind / dotted-blind: must count `_archive/` and treat `118.1` as
#     contributing top-level `118`, not a new number.
#
# Returns the next TOP-LEVEL number on stdout. Children (`<id>.N`) are derived by
# the caller. Reservation-based: writes a reservation BEFORE returning so a second
# allocation before the entity materializes does not collide.
#
# Testability: pure functions are source-able (guarded main does not run on
# source). No test-only env hooks — the seam is functions + on-disk fixtures +
# real git worktrees (see lib/__tests__/test-allocate-id.sh).
#
# `set -euo pipefail` is enabled inside main() (when executed), NOT at top level,
# so sourcing this library does not mutate the caller's shell options.

# collect_prefixes <dir>... — space-separated, sorted-unique top-level integer
# prefixes across the given workflow dirs. Scans each dir's immediate children
# AND its `_archive/` children; a name's leading digits (stopping at `-` or `.`)
# are the prefix, so `118.1-child` contributes `118`. Non-numeric names ignored.
collect_prefixes() {
  local dir entry base num out=""
  for dir in "$@"; do
    [ -d "$dir" ] || continue
    for entry in "$dir"/* "$dir"/_archive/*; do
      [ -e "$entry" ] || continue
      base="$(basename "$entry")"
      num="$(printf '%s' "$base" | grep -oE '^[0-9]+' || true)"
      [ -n "$num" ] || continue
      out="$out $((10#$num))"
    done
  done
  # word-split $out into lines; sort -un drops dups + orders numerically
  # shellcheck disable=SC2086  # intentional word-split of the space list
  printf '%s\n' $out | sort -un | tr '\n' ' '
}

# scan_max_prefix <dir>... — highest top-level integer prefix (0 if none).
scan_max_prefix() {
  local prefixes max=0 n
  prefixes="$(collect_prefixes "$@")"
  for n in $prefixes; do
    [ "$n" -gt "$max" ] && max="$n"
  done
  echo "$max"
}

# reservations_max <file> — highest number in column 1 (0 if missing/empty).
reservations_max() {
  local f="$1" max=0 n
  [ -f "$f" ] || { echo 0; return 0; }
  while read -r n _; do
    [ -n "$n" ] || continue
    case "$n" in (*[!0-9]*) continue ;; esac
    n=$((10#$n))
    [ "$n" -gt "$max" ] && max="$n"
  done < "$f"
  echo "$max"
}

# compute_next <max_existing> <max_reserved> — max(a,b)+1.
compute_next() {
  if [ "$1" -ge "$2" ]; then echo $(( $1 + 1 )); else echo $(( $2 + 1 )); fi
}

# prune_reservations <file> <ttl> <now> <materialized-space-list>
# Drop reservations that are stale (now-ts > ttl) OR already materialized as a
# real entity. Rewrites the file in place. No-op if the file is absent.
prune_reservations() {
  local f="$1" ttl="$2" now="$3" materialized="$4" tmp n ts rest age keep
  [ -f "$f" ] || return 0
  tmp="$(mktemp)"
  while read -r n ts rest; do
    [ -n "$n" ] || continue
    keep=1
    case " $materialized " in (*" $n "*) keep=0 ;; esac
    if [ "$keep" = 1 ]; then
      case "$ts" in (""|*[!0-9]*) ts=0 ;; esac
      age=$(( now - ts ))
      [ "$age" -gt "$ttl" ] && keep=0
    fi
    [ "$keep" = 1 ] && printf '%s %s %s\n' "$n" "$ts" "$rest" >> "$tmp"
  done < "$f"
  mv "$tmp" "$f"
}

# worktree_workflow_dirs <relative-workflow-path> — echo each existing
# `<worktree>/<rel>` across ALL git worktrees (the worktree-aware scan scope).
worktree_workflow_dirs() {
  local rel="$1" key val
  git worktree list --porcelain 2>/dev/null | while read -r key val; do
    [ "$key" = "worktree" ] || continue
    [ -d "$val/$rel" ] && echo "$val/$rel"
  done
}

# acquire_lock <lockdir> — portable mkdir lock with dead-holder reclaim.
# Records the holder PID in <lockdir>/pid. NEVER steals a LIVE lock: it reclaims
# only when the recorded holder PID is provably dead (handles a crashed/Ctrl-C'd
# allocation), and against a live/unknown holder it gives up after a bounded wait
# (returns 3) rather than steal — so two allocations can never both proceed and
# collide. mkdir atomicity decides the winner if two processes reclaim at once.
acquire_lock() {
  local lock="$1" waited=0 holder
  while ! mkdir "$lock" 2>/dev/null; do
    holder="$(cat "$lock/pid" 2>/dev/null || true)"
    if [ -n "$holder" ] && ! kill -0 "$holder" 2>/dev/null; then
      rm -rf "$lock" 2>/dev/null || true     # holder dead → stale → reclaim, retry mkdir
      continue
    fi
    sleep 0.2
    waited=$(( waited + 1 ))
    if [ "$waited" -gt 150 ]; then           # ~30s vs a live/unknown holder → do NOT steal
      echo "ERROR: id-allocation lock busy ($lock); holder pid=${holder:-unknown}. If stale: rm -rf '$lock'" >&2
      return 3
    fi
  done
  echo "$$" > "$lock/pid" 2>/dev/null || true
  return 0
}

# allocate_id <workflow-dir> — atomic, worktree-aware, reservation-based.
# Echoes the next top-level number.
allocate_id() {
  local wf="$1"
  command -v git >/dev/null 2>&1 || { echo "ERROR: git required" >&2; return 2; }
  local common rel lock res
  common="$(cd "$(git rev-parse --git-common-dir)" 2>/dev/null && pwd)" || return 2
  # In-repo path of the workflow dir, computed by git so it is robust to symlinked
  # paths (e.g. macOS /var -> /private/var, where pwd and show-toplevel disagree and
  # a naive prefix-strip would leave rel absolute → worktree scan would silently miss
  # sibling worktrees and fall back to the main checkout only).
  rel="$(cd "$wf" 2>/dev/null && git rev-parse --show-prefix 2>/dev/null)" \
    || { echo "ERROR: workflow dir not in a git repo: $wf" >&2; return 2; }
  rel="${rel%/}"
  lock="$common/ship-flow-id.lock"
  res="$common/ship-flow-id-reservations"

  # Serialize concurrent allocations so the read-compute-reserve sequence is
  # uninterrupted. Released explicitly after the reservation is written; if the
  # process aborts mid-section (set -e under main → process exit), the lock is
  # left behind but its holder PID is now dead, so the NEXT allocation reclaims
  # it via acquire_lock's dead-holder check (no trap needed — a global RETURN
  # trap would re-fire on every later function return with $lock out of scope).
  acquire_lock "$lock" || return 3

  local dirs=() d max_existing materialized now max_res next
  while IFS= read -r d; do [ -n "$d" ] && dirs+=("$d"); done < <(worktree_workflow_dirs "$rel")
  [ ${#dirs[@]} -gt 0 ] || dirs=("$wf")

  max_existing="$(scan_max_prefix "${dirs[@]}")"
  materialized="$(collect_prefixes "${dirs[@]}")"
  now="$(date +%s)"
  prune_reservations "$res" 7200 "$now" "$materialized"
  max_res="$(reservations_max "$res")"
  next="$(compute_next "$max_existing" "$max_res")"
  printf '%s %s %s\n' "$next" "$now" "$$" >> "$res"
  rm -rf "$lock" 2>/dev/null || true   # release
  echo "$next"
}

main() {
  set -euo pipefail
  local wf="${1:-}"
  if [ -z "$wf" ]; then
    echo "Usage: allocate-id.sh <workflow-dir>" >&2
    echo "Example: allocate-id.sh docs/ship-flow" >&2
    exit 2
  fi
  [ -d "$wf" ] || { echo "ERROR: workflow dir not found: $wf" >&2; exit 2; }
  allocate_id "$wf"
}

if [ "${BASH_SOURCE[0]:-}" = "${0}" ]; then
  main "$@"
fi
