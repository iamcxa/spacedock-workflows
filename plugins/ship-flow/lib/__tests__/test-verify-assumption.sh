#!/usr/bin/env bash
# test-verify-assumption.sh — DC-17..DC-21 for verify-assumption.sh
# Pattern: FAIL=0, exit $FAIL; mirrors test-map-layer.sh conventions.
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
REPO_ROOT="$(cd "${LIB_DIR}/../../.." && pwd)"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}
assert_stdout_matches() {
  local pattern="$1" cmd="$2" name="$3"
  local out; out="$(eval "$cmd" 2>&1)"
  if echo "$out" | grep -qE "$pattern"; then echo "OK $name"
  else echo "FAIL $name (stdout did not match /$pattern/)"; FAIL=1; fi
}

cd "$REPO_ROOT" || exit 1

# Fixture entity with 3 assumptions: PASS-critical, FAIL-important, TIMEOUT-nice-to-know
FIXTURE_DIR="$(mktemp -d)"
trap 'rm -rf "$FIXTURE_DIR"' EXIT INT TERM
FIXTURE="$FIXTURE_DIR/test-entity.md"
cat > "$FIXTURE" <<'FIXTURE_EOF'
---
id: "test-verify"
title: "Test fixture for verify-assumption.sh"
status: draft
pattern: pitch
appetite: "1 day"
stated_assumptions:
  - id: "A1"
    claim: "Always true"
    verified_by: codebase-grep
    verification: "true"
    confidence_at_shape: 100
    criticality: critical
  - id: "A2"
    claim: "Always false — should fail important"
    verified_by: codebase-grep
    verification: "false"
    confidence_at_shape: 50
    criticality: important
  - id: "A3"
    claim: "Slow command — exceeds timeout"
    verified_by: codebase-grep
    verification: "sleep 35"
    confidence_at_shape: 70
    criticality: nice-to-know
---

### Problem

Test fixture body.
FIXTURE_EOF

echo "--- DC-17: verify-assumption PASS case ---"
assert_exit 0 \
  "bash '${LIB_DIR}/verify-assumption.sh' --entity='$FIXTURE' --assumption=A1" \
  "DC-17a PASS exit 0"
assert_stdout_matches '"result":"pass"' \
  "bash '${LIB_DIR}/verify-assumption.sh' --entity='$FIXTURE' --assumption=A1" \
  "DC-17b PASS json result=pass"
assert_stdout_matches '"criticality":"critical"' \
  "bash '${LIB_DIR}/verify-assumption.sh' --entity='$FIXTURE' --assumption=A1" \
  "DC-17c PASS json criticality=critical"

echo
echo "--- DC-18: verify-assumption FAIL important case ---"
assert_exit 2 \
  "bash '${LIB_DIR}/verify-assumption.sh' --entity='$FIXTURE' --assumption=A2" \
  "DC-18a FAIL-important exit 2"
assert_stdout_matches '"result":"fail"' \
  "bash '${LIB_DIR}/verify-assumption.sh' --entity='$FIXTURE' --assumption=A2" \
  "DC-18b FAIL json result=fail"

echo
echo "--- DC-19: verify-assumption MALFORMED (missing assumption id) ---"
assert_exit 10 \
  "bash '${LIB_DIR}/verify-assumption.sh' --entity='$FIXTURE' --assumption=A999" \
  "DC-19a missing assumption → exit 10"

echo
echo "--- DC-20: verify-assumption missing entity file ---"
assert_exit 10 \
  "bash '${LIB_DIR}/verify-assumption.sh' --entity=/nonexistent/path.md --assumption=A1" \
  "DC-20a missing entity file → exit 10"

# DC-21 takes ~5s to test (we override to short timeout for CI speed)
echo
echo "--- DC-21: verify-assumption TIMEOUT (short --timeout to avoid 35s wait) ---"
assert_exit 11 \
  "bash '${LIB_DIR}/verify-assumption.sh' --entity='$FIXTURE' --assumption=A3 --timeout=2" \
  "DC-21a timeout → exit 11"

exit $FAIL
