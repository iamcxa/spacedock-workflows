#!/usr/bin/env bash
# Stub `claude -p` replacement for scheduler-runner-adapter.sh tests (AC-1
# delegation marker path). Echoes the tick-id env var the adapter is supposed
# to propagate, plus the existing terminal sentinel line so success detection
# still passes.
echo "TICK_ID_SEEN=${SHIP_FLOW_SCHEDULER_TICK_ID:-}"
echo "SHIP_FLOW_TERMINAL verdict=PASSED pr=999 state=awaiting_merge"
exit 0
