#!/usr/bin/env bash
set -euo pipefail
WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
VALIDATOR="$WDIR/plugins/ship-flow/lib/__tests__/validate-debrief-schema.sh"
FIXTURES="$WDIR/plugins/ship-flow/lib/__tests__/fixtures/debrief-schema"
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

# (c) all debriefs validate (guard against absent dir in fresh clone)
if [ -d "$WDIR/docs/ship-flow/_debriefs" ]; then
  for f in "$WDIR/docs/ship-flow/_debriefs/"*.md; do
    [ -f "$f" ] || continue
    bash "$VALIDATOR" "$f" || fail=1
  done
else
  echo "NOTE: $WDIR/docs/ship-flow/_debriefs/ absent (fresh clone) — debrief dir not adopted yet"
fi

# (c2) schema_version policy fixtures
bash "$VALIDATOR" "$FIXTURES/v1-valid.md" || fail=1
legacy_out="$(bash "$VALIDATOR" "$FIXTURES/legacy-missing-version-valid.md" 2>&1)" || {
  echo "$legacy_out"
  fail=1
}
grep -q "WARN legacy-v1: missing schema_version treated as schema_version 1" <<<"$legacy_out" || {
  echo "FAIL: legacy-v1 warning missing"
  fail=1
}
if future_out="$(bash "$VALIDATOR" "$FIXTURES/future-version.md" 2>&1)"; then
  echo "$future_out"
  echo "FAIL: future schema_version should fail"
  fail=1
else
  grep -q "unsupported schema_version" <<<"$future_out" || {
    echo "$future_out"
    echo "FAIL: future schema_version failure missing unsupported-version message"
    fail=1
  }
fi
if empty_out="$(bash "$VALIDATOR" "$FIXTURES/explicit-empty-version.md" 2>&1)"; then
  echo "$empty_out"
  echo "FAIL: explicit empty schema_version should fail"
  fail=1
else
  grep -q "unsupported schema_version" <<<"$empty_out" || {
    echo "$empty_out"
    echo "FAIL: explicit empty schema_version failure missing unsupported-version message"
    fail=1
  }
fi
if missing_out="$(bash "$VALIDATOR" "$FIXTURES/missing-required-section.md" 2>&1)"; then
  echo "$missing_out"
  echo "FAIL: missing required section fixture should fail"
  fail=1
else
  grep -q "missing section" <<<"$missing_out" || {
    echo "$missing_out"
    echo "FAIL: missing section fixture did not report missing section"
    fail=1
  }
fi

# (d) migration template exists
test -f "$WDIR/plugins/ship-flow/_mods/migrate-debrief-vN-to-vN+1.md.template" || { echo "FAIL: migration template missing"; fail=1; }

# (e) README mentions debrief-schema
grep -q "debrief-schema" "$WDIR/plugins/ship-flow/README.md" || { echo "FAIL: debrief-schema not in README"; fail=1; }

[ $fail -eq 0 ] && echo "PASS: all debrief-schema tests passed"
exit $fail
