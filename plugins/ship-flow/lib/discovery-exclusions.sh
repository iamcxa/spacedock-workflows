#!/usr/bin/env bash
# discovery-exclusions.sh — shared fixture-tree pruning for discovery consumers

ship_flow_discovery_find() {
  local requested_root="$1"
  shift

  find "$requested_root" -mindepth 1 \
    \( -type d \( -name __tests__ -o -name test-fixtures \) -prune \) -o \
    "$@"
}
