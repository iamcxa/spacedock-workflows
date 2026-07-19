#!/usr/bin/env bash
# scheduler-lease.sh — mkdir-atomic controller lease for ship-flow-scheduler tick
# (concurrency=1, design.md §5/Rule 9). Sourced by bin/ship-flow-scheduler.sh —
# not a standalone CLI. Pattern reused from lib/fo-completion-lease.sh
# (mkdir-atomic dir lease); record fields narrowed to the scheduler's own
# pid/start_ts/tick_id/entity.

scheduler_lease_dir() {
  printf '%s/.ship-flow-scheduler.lease\n' "$1"
}

scheduler_lease_field() {
  local record="$1" key="$2"
  grep "^${key}=" "$record" 2>/dev/null | head -1 | cut -d= -f2-
}

# Portable RFC3339(Z) -> epoch: macOS `date -j` first, GNU `date -d` fallback.
scheduler_lease_epoch() {
  local ts="$1"
  date -u -j -f '%Y-%m-%dT%H:%M:%SZ' "$ts" +%s 2>/dev/null \
    || date -u -d "$ts" +%s 2>/dev/null \
    || echo 0
}

scheduler_lease_write_record() {
  local record="$1" tick_id="$2" entity="$3" token="$4"
  printf 'pid=%s\nstart_ts=%s\ntick_id=%s\nentity=%s\ntoken=%s\n' \
    "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tick_id" "$entity" "$token" > "$record"
}

# scheduler_lease_new_token — a per-acquisition ownership token (pid + epoch +
# $RANDOM composite; uniqueness within one machine's concurrency=1 lease is all
# this needs, not cryptographic strength).
scheduler_lease_new_token() {
  printf '%s-%s-%s\n' "$$" "$(date -u +%s)" "$RANDOM"
}

# scheduler_lease_acquire <controller-worktree> <tick_id> <max_run_timeout_sec> [entity]
# Exit 0 = acquired (fresh or reclaimed from a provably-dead holder); on
#          success also sets SCHEDULER_LEASE_TOKEN to this acquisition's
#          ownership token (pass it to scheduler_lease_release).
# Exit 1 = held by a live holder (caller emits no-op reason=lease-held).
#
# F2 fix (feedback cycle 1, BLOCKING, concurrency=1): reclaim is gated on
# holder LIVENESS ONLY — `max_timeout` no longer participates in the reclaim
# decision (age is not proof of death; a still-alive holder is never stolen
# from, however old its record). A slow/unbounded reconcile is instead bounded
# at its call site (bin/ship-flow-scheduler.sh wraps it in `timeout`), so a
# holder that overruns is forcibly ended — it becomes reclaimable via the
# SAME dead-pid path, not a separate age heuristic. `max_timeout` is kept as a
# parameter for call-site compatibility (and documents the intended bound)
# but is otherwise unused here now. SCHEDULER_LEASE_TOKEN (below) is an
# intentional implicit global — the caller (bin/ship-flow-scheduler.sh, a
# separate file) reads it after a successful acquire to pass the token on to
# scheduler_lease_release; shellcheck can't see that cross-file use.
# shellcheck disable=SC2034
scheduler_lease_acquire() {
  local worktree="$1" tick_id="$2" max_timeout="${3:-}" entity="${4:-}"
  local dir record pid token

  dir="$(scheduler_lease_dir "$worktree")"
  record="${dir}/record"
  token="$(scheduler_lease_new_token)"

  if mkdir "$dir" 2>/dev/null; then
    scheduler_lease_write_record "$record" "$tick_id" "$entity" "$token"
    SCHEDULER_LEASE_TOKEN="$token"
    printf '%s\n' "$dir"
    return 0
  fi

  if [ ! -f "$record" ]; then
    # Torn lease (dir with no record, e.g. a hard kill mid-write) — reclaim.
    scheduler_lease_write_record "$record" "$tick_id" "$entity" "$token"
    SCHEDULER_LEASE_TOKEN="$token"
    printf '%s\n' "$dir"
    return 0
  fi

  pid="$(scheduler_lease_field "$record" pid)"

  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then
    return 1
  fi

  rm -f "$record"
  scheduler_lease_write_record "$record" "$tick_id" "$entity" "$token"
  SCHEDULER_LEASE_TOKEN="$token"
  printf '%s\n' "$dir"
  return 0
}

# scheduler_lease_release <controller-worktree> [token]
# F2 fix: with a token, refuse (exit 1, record untouched) unless it matches
# the record's own token — an unconditional release could otherwise delete a
# successor's lease out from under it (e.g. this holder's own timeout wrapper
# fired, a peer reclaimed as dead, and this process's EXIT trap then runs).
# No token (or no matching `token=` field, e.g. a pre-fix record) falls back
# to the old unconditional release — callers not yet passing a token, or a
# genuinely ownerless torn record, are not blocked from cleaning up.
scheduler_lease_release() {
  local worktree="$1" token="${2:-}"
  local dir record held_token

  dir="$(scheduler_lease_dir "$worktree")"
  record="${dir}/record"

  if [ -n "$token" ] && [ -f "$record" ]; then
    held_token="$(scheduler_lease_field "$record" token)"
    if [ -n "$held_token" ] && [ "$held_token" != "$token" ]; then
      return 1
    fi
  fi

  rm -f "$record"
  rmdir "$dir" 2>/dev/null || true
  return 0
}
