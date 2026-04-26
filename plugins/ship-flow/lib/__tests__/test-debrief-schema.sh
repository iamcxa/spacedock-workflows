#!/usr/bin/env bash
set -euo pipefail
WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
VALIDATOR="$WDIR/plugins/ship-flow/lib/__tests__/validate-debrief-schema.sh"
fail=0

# (a) schema file exists
test -f "$WDIR/plugins/ship-flow/references/debrief-schema.yaml" || { echo "FAIL: debrief-schema.yaml missing"; fail=1; }

# (b) schema_version = 1 (requires yq)
if command -v yq &>/dev/null; then
  ver=$(yq '.schema_version' "$WDIR/plugins/ship-flow/references/debrief-schema.yaml" 2>/dev/null || echo "")
  [ "$ver" = "1" ] || { echo "FAIL: schema_version=$ver (need 1)"; fail=1; }
else
  grep -q "schema_version: 1" "$WDIR/plugins/ship-flow/references/debrief-schema.yaml" || { echo "FAIL: schema_version not 1"; fail=1; }
fi

# (c) all debriefs validate
for f in "$WDIR/docs/ship-flow/_debriefs/"*.md; do
  bash "$VALIDATOR" "$f" || fail=1
done
CARLOVE="/Users/kent/Project/carlove/docs/ship-flow/_debriefs/2026-04-25-01.md"
[ -f "$CARLOVE" ] && bash "$VALIDATOR" "$CARLOVE" || { echo "WARN: carlove debrief not found (skipping)"; }

# (d) migration template exists
test -f "$WDIR/plugins/ship-flow/_mods/migrate-debrief-vN-to-vN+1.md.template" || { echo "FAIL: migration template missing"; fail=1; }

# (e) README mentions debrief-schema
grep -q "debrief-schema" "$WDIR/plugins/ship-flow/README.md" || { echo "FAIL: debrief-schema not in README"; fail=1; }

[ $fail -eq 0 ] && echo "PASS: all debrief-schema tests passed"
exit $fail
