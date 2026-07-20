#!/usr/bin/env bash
# Test-only stand-in for the real `spacedock` launcher binary (B1
# regression). Pointed to via $SPACEDOCK_BIN so the adapter's real (non
# SHIP_FLOW_SCHEDULER_RUNNER_CMD) exec branch runs THIS script directly as
# argv[0], proving SPAWN_ARGV reaches it as literal argv elements rather than
# being re-parsed by a shell. Echoes the terminal sentinel so success
# detection still passes; does nothing with its arguments beyond that (a
# real injection would execute during shell re-parsing, before this script
# ever runs, so this stub does not need to inspect argv itself).
echo "SHIP_FLOW_TERMINAL verdict=PASSED pr=999 state=awaiting_merge"
exit 0
