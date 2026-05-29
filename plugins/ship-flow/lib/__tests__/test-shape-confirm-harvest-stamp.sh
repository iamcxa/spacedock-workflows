#!/usr/bin/env bash
# test-shape-confirm-harvest-stamp.sh — assert that shape-confirm.sh heredocs
# carry `harvest_required: true` in all three entity frontmatter blocks.
#
# Tests (no file-system side effects; asserts on SOURCE of shape-confirm.sh):
#   1. Total occurrences of `harvest_required: true` in shape-confirm.sh >= 3
#   2. The shaped-child heredoc (contains `pattern: shaped-child`) carries it
#   3. The folder-layout pitch heredoc (contains `layout: folder`) carries it
#   4. The flat-layout pitch heredoc (contains `pattern: pitch` but NOT
#      `layout: folder`) carries it

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

SHAPE_CONFIRM="${REPO_ROOT}/plugins/ship-flow/lib/shape-confirm.sh"

PASS=0
FAIL=0
ERRORS=()

check() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  else
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  fi
}

echo "=== test-shape-confirm-harvest-stamp.sh ==="
echo ""

# ── Helper: extract the body of a heredoc that starts with `cat > ... <<EOF`
# and ends at the next standalone `EOF` line.
# We use awk to collect each heredoc body as one blob, then check those blobs.
# Strategy: iterate through ALL heredocs in the file; for each one that matches
# a pattern keyword, assert it also contains `harvest_required: true`.

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Extract each <<EOF ... EOF block into numbered files
awk '
  /cat >.*<<EOF/ { in_here=1; block_idx++; next }
  /^EOF$/ && in_here { in_here=0; next }
  in_here { print >> (TMPDIR "/block_" block_idx ".txt") }
' TMPDIR="$TMP_DIR" "$SHAPE_CONFIRM"

# ── Test 1: total count of `harvest_required: true` in shape-confirm.sh >= 3
check "shape-confirm.sh contains at least 3 occurrences of 'harvest_required: true'" \
  "[ \"\$(grep -c 'harvest_required: true' '${SHAPE_CONFIRM}')\" -ge 3 ]"

# ── Test 2: shaped-child heredoc contains `harvest_required: true`
# Find the block that has `pattern: shaped-child`
CHILD_BLOCK=""
for f in "$TMP_DIR"/block_*.txt; do
  [ -f "$f" ] || continue
  if grep -q 'pattern: shaped-child' "$f"; then
    CHILD_BLOCK="$f"
    break
  fi
done

check "shaped-child heredoc contains 'harvest_required: true'" \
  "[ -n '${CHILD_BLOCK}' ] && grep -q 'harvest_required: true' '${CHILD_BLOCK}'"

# ── Test 3: folder-layout pitch heredoc (has `layout: folder`) contains it
FOLDER_PITCH_BLOCK=""
for f in "$TMP_DIR"/block_*.txt; do
  [ -f "$f" ] || continue
  if grep -q 'layout: folder' "$f" && grep -q 'pattern: pitch' "$f"; then
    FOLDER_PITCH_BLOCK="$f"
    break
  fi
done

check "folder-layout pitch heredoc contains 'harvest_required: true'" \
  "[ -n '${FOLDER_PITCH_BLOCK}' ] && grep -q 'harvest_required: true' '${FOLDER_PITCH_BLOCK}'"

# ── Test 4: flat-layout pitch heredoc (has `pattern: pitch`, no `layout: folder`) contains it
FLAT_PITCH_BLOCK=""
for f in "$TMP_DIR"/block_*.txt; do
  [ -f "$f" ] || continue
  if grep -q 'pattern: pitch' "$f" && ! grep -q 'layout: folder' "$f" && ! grep -q 'pattern: shaped-child' "$f"; then
    FLAT_PITCH_BLOCK="$f"
    break
  fi
done

check "flat-layout pitch heredoc contains 'harvest_required: true'" \
  "[ -n '${FLAT_PITCH_BLOCK}' ] && grep -q 'harvest_required: true' '${FLAT_PITCH_BLOCK}'"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for err in "${ERRORS[@]}"; do
    echo "  - ${err}"
  done
  exit 1
fi

echo "All assertions passed"
