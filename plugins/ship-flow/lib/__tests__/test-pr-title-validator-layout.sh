#!/usr/bin/env bash
# test-pr-title-validator-layout.sh — validate source and installed plugin layouts.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." >/dev/null 2>&1 && pwd)"
VALIDATOR="${PLUGIN_ROOT}/bin/validate-pr-title.sh"
RULE_LIB="${PLUGIN_ROOT}/lib/pr-title-format.sh"
TITLE='fix(ship-flow): resolve installed title validator helper'
FAIL=0

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

assert_exit() {
  local expected="$1" actual="$2" name="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name (expected exit $expected, got $actual)"
    FAIL=1
  fi
}

assert_exact() {
  local expected="$1" actual="$2" name="$3"
  if [ "$actual" = "$expected" ]; then
    echo "PASS: $name"
  else
    echo "FAIL: $name"
    printf '  expected: %s\n  actual:   %s\n' "$expected" "$actual"
    FAIL=1
  fi
}

run_validator() {
  local validator="$1" stdout_file="$2" stderr_file="$3"
  bash "$validator" "$TITLE" >"$stdout_file" 2>"$stderr_file"
}

echo "=== test-pr-title-validator-layout.sh ==="
echo

run_validator "$VALIDATOR" "$TMP/source.out" "$TMP/source.err"
assert_exit 0 "$?" "source checkout layout accepts a valid title"
assert_exact "PR title format ok: ${TITLE}" "$(cat "$TMP/source.out")" \
  "source checkout uses the shared title rule"
assert_exact "" "$(cat "$TMP/source.err")" \
  "source checkout emits no diagnostic"

mkdir -p "$TMP/installed/bin" "$TMP/installed/lib"
cp "$VALIDATOR" "$TMP/installed/bin/validate-pr-title.sh"
cp "$RULE_LIB" "$TMP/installed/lib/pr-title-format.sh"

run_validator "$TMP/installed/bin/validate-pr-title.sh" \
  "$TMP/installed.out" "$TMP/installed.err"
assert_exit 0 "$?" "installed plugin layout accepts a valid title"
assert_exact "PR title format ok: ${TITLE}" "$(cat "$TMP/installed.out")" \
  "installed plugin layout uses its packaged shared title rule"
assert_exact "" "$(cat "$TMP/installed.err")" \
  "installed plugin layout emits no diagnostic"

rm "$TMP/installed/lib/pr-title-format.sh"
run_validator "$TMP/installed/bin/validate-pr-title.sh" \
  "$TMP/missing.out" "$TMP/missing.err"
assert_exit 1 "$?" "missing shared title rule fails closed"
assert_exact "" "$(cat "$TMP/missing.out")" \
  "missing shared title rule emits no success output"
assert_exact "ERROR: PR title format helper not found" "$(cat "$TMP/missing.err")" \
  "missing shared title rule emits one clear diagnostic"

echo
if [ "$FAIL" -ne 0 ]; then
  echo "Result: FAIL"
  exit 1
fi

echo "Result: PASS"
