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
  local record="$1" tick_id="$2" entity="$3"
  printf 'pid=%s\nstart_ts=%s\ntick_id=%s\nentity=%s\n' \
    "$$" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$tick_id" "$entity" > "$record"
}

# scheduler_lease_acquire <controller-worktree> <tick_id> <max_run_timeout_sec> [entity]
# Exit 0 = acquired (fresh or reclaimed from a dead/aged-out holder).
# Exit 1 = held by a live holder within the timeout window (caller emits
#          no-op reason=lease-held).
scheduler_lease_acquire() {
  local worktree="$1" tick_id="$2" max_timeout="$3" entity="${4:-}"
  local dir record pid start_ts now age

  dir="$(scheduler_lease_dir "$worktree")"
  record="${dir}/record"

  if mkdir "$dir" 2>/dev/null; then
    scheduler_lease_write_record "$record" "$tick_id" "$entity"
    printf '%s\n' "$dir"
    return 0
  fi

  if [ ! -f "$record" ]; then
    # Torn lease (dir with no record, e.g. a hard kill mid-write) — reclaim.
    scheduler_lease_write_record "$record" "$tick_id" "$entity"
    printf '%s\n' "$dir"
    return 0
  fi

  pid="$(scheduler_lease_field "$record" pid)"
  start_ts="$(scheduler_lease_field "$record" start_ts)"
  now="$(date -u +%s)"
  age=$(( now - $(scheduler_lease_epoch "$start_ts") ))

  if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && [ "$age" -le "$max_timeout" ]; then
    return 1
  fi

  rm -f "$record"
  scheduler_lease_write_record "$record" "$tick_id" "$entity"
  printf '%s\n' "$dir"
  return 0
}

# scheduler_lease_release <controller-worktree>
scheduler_lease_release() {
  local dir
  dir="$(scheduler_lease_dir "$1")"
  rm -f "${dir}/record"
  rmdir "$dir" 2>/dev/null || true
}
