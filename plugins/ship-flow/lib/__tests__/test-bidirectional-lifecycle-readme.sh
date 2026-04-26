#!/usr/bin/env bash
set -euo pipefail
WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
README="$WDIR/plugins/ship-flow/README.md"
fail=0

grep -q "## Bidirectional lifecycle" "$README" || { echo "FAIL: ## Bidirectional lifecycle section missing"; fail=1; }
grep -q "mermaid" "$README" || { echo "FAIL: no mermaid in README"; fail=1; }
grep -q "workflow-adopt" "$README" || { echo "FAIL: workflow-adopt not cited"; fail=1; }
grep -q "workflow-sync" "$README" || { echo "FAIL: workflow-sync not cited"; fail=1; }
grep -q "debrief-promote" "$README" || { echo "FAIL: debrief-promote not cited"; fail=1; }
grep -q "_debriefs/" "$README" || { echo "FAIL: _debriefs/ not in README"; fail=1; }

[ $fail -eq 0 ] && echo "PASS: bidirectional lifecycle section present"
exit $fail
