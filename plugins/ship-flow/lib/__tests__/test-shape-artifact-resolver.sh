#!/usr/bin/env bash
# test-shape-artifact-resolver.sh - shape.md/spec.md compatibility resolver contract
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
FIXTURE_DIR="${SCRIPT_DIR}/fixtures/shape-artifact"
RESOLVER="${LIB_DIR}/resolve-shape-artifact.sh"
FAIL=0
CASE_FILTER=""

for arg in "$@"; do
  case "$arg" in
    --case=*) CASE_FILTER="${arg#--case=}" ;;
    --case) shift; CASE_FILTER="${1:-}" ;;
    *) echo "Unknown option: $arg" >&2; exit 2 ;;
  esac
done

run_case() {
  local case_name="$1"
  shift
  if [ -n "$CASE_FILTER" ] && [ "$CASE_FILTER" != "$case_name" ]; then
    return 0
  fi
  "$@"
}

expect_path() {
  local case_name="$1"
  local fixture="$2"
  local expected="$3"
  local actual

  if actual="$(bash "$RESOLVER" "$fixture" 2>&1)"; then
    if [ "$actual" = "$expected" ]; then
      echo "OK ${case_name}: resolved ${expected}"
    else
      echo "FAIL ${case_name}: expected ${expected}, got ${actual}"
      FAIL=1
    fi
  else
    echo "FAIL ${case_name}: resolver exited non-zero: ${actual}"
    FAIL=1
  fi
}

expect_missing() {
  local case_name="$1"
  local fixture="$2"
  local output

  if output="$(bash "$RESOLVER" "$fixture" 2>&1)"; then
    echo "FAIL ${case_name}: expected missing artifact failure, got success: ${output}"
    FAIL=1
    return
  fi

  if printf '%s\n' "$output" | grep -q "missing shape artifact"; then
    echo "OK ${case_name}: missing artifact failed clearly"
  else
    echo "FAIL ${case_name}: missing error was not clear: ${output}"
    FAIL=1
  fi
}

run_case "spec-only" expect_path \
  "spec-only" \
  "${FIXTURE_DIR}/spec-only" \
  "${FIXTURE_DIR}/spec-only/spec.md"

run_case "shape-only" expect_path \
  "shape-only" \
  "${FIXTURE_DIR}/shape-only" \
  "${FIXTURE_DIR}/shape-only/shape.md"

run_case "both-files" expect_path \
  "both-files" \
  "${FIXTURE_DIR}/both-files" \
  "${FIXTURE_DIR}/both-files/shape.md"

run_case "missing" expect_missing \
  "missing" \
  "${FIXTURE_DIR}/missing"

exit "$FAIL"
