#!/usr/bin/env bash
set -euo pipefail
WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
README="$WDIR/plugins/ship-flow/README.md"
fail=0
grep -qE "[Bb]ad[- ]news[- ]early" "$README" || { echo "FAIL: bad-news-early not in README"; fail=1; }
grep -q "_debriefs" "$README" || { echo "FAIL: _debriefs not in README"; fail=1; }
[ $fail -eq 0 ] && echo "PASS: README motto + _debriefs present"
exit $fail
