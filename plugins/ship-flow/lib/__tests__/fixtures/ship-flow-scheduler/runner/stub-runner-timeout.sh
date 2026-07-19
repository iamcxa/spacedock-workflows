#!/usr/bin/env bash
# Stub `claude -p` replacement for scheduler-runner-adapter.sh tests (timeout path).
# The adapter always wraps the run in a real `timeout <sec>`, so a long sleep here
# is genuinely killed — no need to fake exit 124.
sleep 30
