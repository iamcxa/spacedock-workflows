#!/usr/bin/env bash
# test-check-harvest-exempt.sh - TDD tests for check-harvest-exempt.sh helper.
# Tests the ship-review harvest gate exemption check (ship-review Step 8).

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${SCRIPT_DIR}/../../../.." &> /dev/null && pwd)"

HELPER="${REPO_ROOT}/plugins/ship-flow/lib/check-harvest-exempt.sh"

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

check_not() {
  local desc="$1"
  local cmd="$2"
  if eval "$cmd" > /dev/null 2>&1; then
    echo "  FAIL: $desc"
    FAIL=$((FAIL + 1))
    ERRORS+=("$desc")
  else
    echo "  PASS: $desc"
    PASS=$((PASS + 1))
  fi
}

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

# Fixture 1: entity WITHOUT harvest_required flag (old entity — should be exempt)
NO_FLAG_ENTITY="${TMP_DIR}/no-flag-index.md"
cat > "$NO_FLAG_ENTITY" <<'EOF'
---
id: "042"
title: "Some old entity"
status: review
stage: review
---

## Shape

Some content here.
EOF

# Fixture 2: entity WITH harvest_required: true (new entity — gate applies)
FLAGGED_ENTITY="${TMP_DIR}/flagged-index.md"
cat > "$FLAGGED_ENTITY" <<'EOF'
---
id: "099"
title: "New harvest-required entity"
status: review
stage: review
harvest_required: true
---

## Shape

Some content here.
EOF

# Fixture 3: entity where harvest_required: true appears only in body (NOT frontmatter)
# The helper must parse only the frontmatter block — body mentions should not trigger.
BODY_ONLY_ENTITY="${TMP_DIR}/body-only-index.md"
cat > "$BODY_ONLY_ENTITY" <<'EOF'
---
id: "055"
title: "Entity with flag only in body"
status: review
stage: review
---

## Notes

harvest_required: true appears here in the body, not in frontmatter.
EOF

# Fixture 4: entity with harvest_required: false (explicitly opted out)
OPTED_OUT_ENTITY="${TMP_DIR}/opted-out-index.md"
cat > "$OPTED_OUT_ENTITY" <<'EOF'
---
id: "066"
title: "Entity with harvest_required false"
status: review
stage: review
harvest_required: false
---

## Shape

Content here.
EOF

# Fixture 5: nonexistent path
NONEXISTENT_PATH="${TMP_DIR}/does-not-exist.md"

echo "=== test-check-harvest-exempt.sh ==="
echo ""

# --- Core semantics ---

check "helper exists and is executable" \
  "test -x '${HELPER}'"

check "no-flag entity prints 'exempt'" \
  "bash '${HELPER}' '${NO_FLAG_ENTITY}' | grep -q '^exempt$'"

check "no-flag entity exits 0 (gate skips BLOCKER)" \
  "bash '${HELPER}' '${NO_FLAG_ENTITY}'"

check_not "flagged entity does NOT print 'exempt'" \
  "bash '${HELPER}' '${FLAGGED_ENTITY}' 2>/dev/null | grep -q '^exempt$'"

check_not "flagged entity exits non-zero (gate applies BLOCKER)" \
  "bash '${HELPER}' '${FLAGGED_ENTITY}'"

check "flagged entity prints 'not-exempt'" \
  "bash '${HELPER}' '${FLAGGED_ENTITY}' > '${TMP_DIR}/flagged.out' 2>&1; grep -q '^not-exempt$' '${TMP_DIR}/flagged.out'"

# --- Fail-safe: nonexistent file ---

check_not "nonexistent path exits non-zero (fail safe)" \
  "bash '${HELPER}' '${NONEXISTENT_PATH}'"

check "nonexistent path prints 'not-exempt'" \
  "bash '${HELPER}' '${NONEXISTENT_PATH}' > '${TMP_DIR}/nonexistent.out' 2>&1; grep -q '^not-exempt$' '${TMP_DIR}/nonexistent.out'"

# --- Precision: body-only mentions must NOT trigger the flag ---

check "body-only harvest_required mention is treated as exempt (frontmatter-only parse)" \
  "bash '${HELPER}' '${BODY_ONLY_ENTITY}' | grep -q '^exempt$'"

check "body-only entity exits 0 (only frontmatter block is parsed)" \
  "bash '${HELPER}' '${BODY_ONLY_ENTITY}'"

# --- harvest_required: false is treated same as absent (exempt) ---

check "harvest_required: false entity is treated as exempt" \
  "bash '${HELPER}' '${OPTED_OUT_ENTITY}' | grep -q '^exempt$'"

check "harvest_required: false exits 0" \
  "bash '${HELPER}' '${OPTED_OUT_ENTITY}'"

# --- CRLF fixture: Windows-style line endings must NOT be treated as exempt ---
# A CRLF file whose first line is "---\r" fails the byte-exact "---" comparison,
# causing the parser to hit the "no frontmatter → exempt" branch even when
# harvest_required: true is present.  This is fail-OPEN — the worst direction.
# Fix: strip trailing \r immediately after read.

CRLF_FLAGGED_ENTITY="${TMP_DIR}/crlf-flagged-index.md"
printf -- '---\r\nid: "crlf-entity"\r\ntitle: "CRLF Entity"\r\nstatus: review\r\nharvest_required: true\r\n---\r\n\r\n## Body\r\n\r\nSome content\r\n' > "$CRLF_FLAGGED_ENTITY"

CRLF_UNFLAGGED_ENTITY="${TMP_DIR}/crlf-unflagged-index.md"
printf -- '---\r\nid: "crlf-unflagged"\r\ntitle: "CRLF No Flag"\r\nstatus: review\r\n---\r\n\r\n## Body\r\n\r\nSome content\r\n' > "$CRLF_UNFLAGGED_ENTITY"

check_not "CRLF flagged entity exits non-zero (CRLF fail-OPEN bug repro)" \
  "bash '${HELPER}' '${CRLF_FLAGGED_ENTITY}'"

check "CRLF flagged entity prints 'not-exempt'" \
  "bash '${HELPER}' '${CRLF_FLAGGED_ENTITY}' > '${TMP_DIR}/crlf-flagged.out' 2>&1; grep -q '^not-exempt$' '${TMP_DIR}/crlf-flagged.out'"

check "CRLF unflagged entity is exempt (LF control passing)" \
  "bash '${HELPER}' '${CRLF_UNFLAGGED_ENTITY}' | grep -q '^exempt$'"

check "CRLF unflagged entity exits 0" \
  "bash '${HELPER}' '${CRLF_UNFLAGGED_ENTITY}'"

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
