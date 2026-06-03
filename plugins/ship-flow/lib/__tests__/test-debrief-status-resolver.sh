#!/usr/bin/env bash
set -euo pipefail

WDIR="$(cd "$(dirname "$0")/../../../.." && pwd)"
RESOLVER="$WDIR/plugins/ship-flow/lib/debrief-status-resolver.sh"
FIXTURES="$WDIR/plugins/ship-flow/lib/__tests__/fixtures/debrief-status-resolver"
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

PASS=0
FAIL=0
ERRORS=()

check_argv() {
  local desc="$1"
  local outfile="$2"
  shift 2
  if python3 - "$outfile" "$@" <<'PY'
import sys
path = sys.argv[1]
expected = sys.argv[2:]
actual = open(path, "rb").read().split(b"\0")
if actual and actual[-1] == b"":
    actual = actual[:-1]
actual = [item.decode() for item in actual]
if actual != expected:
    print("expected:", repr(expected))
    print("actual:  ", repr(actual))
    sys.exit(1)
PY
  then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

echo "=== test-debrief-status-resolver.sh ==="
echo ""

LOCAL_WORKFLOW="$FIXTURES/local-status/workflow"
PACKAGED_WORKFLOW="$FIXTURES/no-local-status/workflow"
PACKAGED_PLUGIN="$FIXTURES/packaged-spacedock"

LOCAL_OUT="$TMP_DIR/local.argv0"
PACKAGED_OUT="$TMP_DIR/packaged.argv0"

"$RESOLVER" --print0 --workflow-dir "$LOCAL_WORKFLOW" --spacedock-plugin-dir "$PACKAGED_PLUGIN" -- --next > "$LOCAL_OUT"
check_argv "local executable status helper is preferred" "$LOCAL_OUT" \
  "$LOCAL_WORKFLOW/status" \
  "--next"

# Fallback path: no local status helper → invoke the `spacedock` Go binary as
# `spacedock status <args>`. Hermetic: inject a fake binary via
# SHIP_FLOW_STATUS_BIN so the resolver's `command -v` check passes regardless
# of host PATH. --spacedock-plugin-dir is now a deprecated no-op (still parsed).
FAKE_STATUS_BIN="$TMP_DIR/fake-spacedock"
cat > "$FAKE_STATUS_BIN" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
chmod +x "$FAKE_STATUS_BIN"

SHIP_FLOW_STATUS_BIN="$FAKE_STATUS_BIN" "$RESOLVER" --print0 --workflow-dir "$PACKAGED_WORKFLOW" --spacedock-plugin-dir "$PACKAGED_PLUGIN" -- --resolve "entity one" --fields "status,title" --all-fields > "$PACKAGED_OUT"
check_argv "spacedock status fallback preserves argv boundaries" "$PACKAGED_OUT" \
  "$FAKE_STATUS_BIN" \
  "status" \
  "--workflow-dir" \
  "$PACKAGED_WORKFLOW" \
  "--resolve" \
  "entity one" \
  "--fields" \
  "status,title" \
  "--all-fields"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - $err"
  done
  exit 1
fi

echo "PASS: debrief status resolver tests passed"
