#!/usr/bin/env bash
# Stub `claude -p` replacement for scheduler-runner-adapter.sh tests (error path).
# No SHIP_FLOW_TERMINAL sentinel line emitted; nonzero exit.
echo "boom: run failed" >&2
exit 1
