#!/usr/bin/env bash
# test-fo-receipt-writer.sh - FO autonomous gate receipt writer contract.

set -u

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd)"
LIB_DIR="$(cd -- "${SCRIPT_DIR}/.." >/dev/null 2>&1 && pwd)"
HELPER="${LIB_DIR}/write-fo-receipt.sh"

PASS=0
FAIL=0
ERRORS=()
TMP_DIRS=()

record_pass() {
  echo "  PASS: $1"
  PASS=$((PASS + 1))
}

record_fail() {
  echo "  FAIL: $1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

assert_success() {
  local desc="$1"
  shift
  if "$@" >/tmp/fo-receipt-test.out 2>/tmp/fo-receipt-test.err; then
    record_pass "$desc"
  else
    record_fail "$desc"
    sed 's/^/    stderr: /' /tmp/fo-receipt-test.err
  fi
}

assert_failure_contains() {
  local desc="$1"
  local expected="$2"
  shift 2
  if "$@" >/tmp/fo-receipt-test.out 2>/tmp/fo-receipt-test.err; then
    record_fail "$desc"
    sed 's/^/    stdout: /' /tmp/fo-receipt-test.out
  elif grep -qi "$expected" /tmp/fo-receipt-test.err; then
    record_pass "$desc"
  else
    record_fail "$desc"
    sed 's/^/    stderr: /' /tmp/fo-receipt-test.err
  fi
}

assert_file_contains() {
  local desc="$1"
  local file="$2"
  local pattern="$3"
  if grep -Eq "$pattern" "$file"; then
    record_pass "$desc"
  else
    record_fail "$desc"
  fi
}

new_entity_dir() {
  local dir
  dir="$(mktemp -d)"
  TMP_DIRS+=("$dir")
  mkdir -p "$dir/entity"
  cat > "$dir/entity/index.md" <<'EOF'
---
title: Test entity
status: verify
---

# Test entity
EOF
  printf '%s\n' "$dir/entity"
}

write_receipt() {
  local file="$1"
  local receipt_id="$2"
  local transition_slug="$3"
  local precondition_status="${4:-pass}"
  local blocker_value="${5:-none}"
  local open_decisions="${6:-[]}"

  cat > "$file" <<EOF
receipt_id: ${receipt_id}
created_at: "2026-05-12T00:00:00Z"
actor: "first-officer"
transition:
  from: verify
  to: review
  trigger: ${transition_slug}
decision: self-approved
verdict: PROCEED
rule_source: plugins/ship-flow/skills/ship-verify/SKILL.md
evidence:
  verify_artifact: verify.md
preconditions:
  - name: required verify claims
    status: ${precondition_status}
blocker_scan:
  veto: ${blocker_value}
open_decisions: ${open_decisions}
next_action: "advance to review"
EOF
}

cleanup() {
  rm -f /tmp/fo-receipt-test.out /tmp/fo-receipt-test.err
  for dir in "${TMP_DIRS[@]}"; do
    rm -rf "$dir"
  done
}
trap cleanup EXIT

echo "=== test-fo-receipt-writer.sh ==="
echo ""

ENTITY_DIR="$(new_entity_dir)"
RECEIPT_FILE="$(mktemp)"
write_receipt "$RECEIPT_FILE" "fo-20260512T000000Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
assert_success "folder-layout entity creates fo-receipts.md" \
  bash "$HELPER" --entity-folder "$ENTITY_DIR" --receipt-file "$RECEIPT_FILE" --transition-slug verify-proceed-auto-advance
assert_file_contains "ledger starts with FO Receipts title" "$ENTITY_DIR/fo-receipts.md" '^# FO Receipts$'
assert_file_contains "ledger includes receipt heading from receipt_id" "$ENTITY_DIR/fo-receipts.md" '^## fo-[0-9TZ]+-verify-proceed-auto-advance$'
assert_file_contains "ledger includes fenced yaml receipt block" "$ENTITY_DIR/fo-receipts.md" '^```yaml receipt$'
FIRST_KEY="$(awk '/^```yaml receipt$/{getline; print; exit}' "$ENTITY_DIR/fo-receipts.md" 2>/dev/null)"
if [ "$FIRST_KEY" = "receipt_id: fo-20260512T000000Z-verify-proceed-auto-advance" ]; then
  record_pass "first YAML key inside receipt fence is receipt_id"
else
  record_fail "first YAML key inside receipt fence is receipt_id"
fi

SECOND_RECEIPT="$(mktemp)"
write_receipt "$SECOND_RECEIPT" "fo-20260512T000100Z-pr-creation-autonomy" "pr-creation-autonomy"
assert_success "second append succeeds" \
  bash "$HELPER" --entity-folder "$ENTITY_DIR" --receipt-file "$SECOND_RECEIPT" --transition-slug pr-creation-autonomy
if grep -n '^## fo-' "$ENTITY_DIR/fo-receipts.md" | awk -F: 'NR==1{first=$2} NR==2{second=$2} END{exit !(first ~ /verify-proceed-auto-advance/ && second ~ /pr-creation-autonomy/)}'; then
  record_pass "second append preserves first block and appends chronologically"
else
  record_fail "second append preserves first block and appends chronologically"
fi

FLAT_DIR="$(mktemp -d)"
TMP_DIRS+=("$FLAT_DIR")
FLAT_ENTITY="$FLAT_DIR/flat-entity.md"
printf '%s\n' '---' 'title: Flat entity' '---' > "$FLAT_ENTITY"
assert_failure_contains "flat entity target exits non-zero with captain-route diagnostic" "captain" \
  bash "$HELPER" --entity-folder "$FLAT_ENTITY" --receipt-file "$RECEIPT_FILE" --transition-slug verify-proceed-auto-advance

for case_name in precondition-fail precondition-missing blocker-found open-decisions; do
  BAD_ENTITY_DIR="$(new_entity_dir)"
  BAD_RECEIPT="$(mktemp)"
  case "$case_name" in
    precondition-fail)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000200Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "fail"
      ;;
    precondition-missing)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000300Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "missing"
      ;;
    blocker-found)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000400Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "found"
      ;;
    open-decisions)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000500Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" '["needs captain"]'
      ;;
  esac
  assert_failure_contains "self-approved receipt rejects ${case_name}" "captain" \
    bash "$HELPER" --entity-folder "$BAD_ENTITY_DIR" --receipt-file "$BAD_RECEIPT" --transition-slug verify-proceed-auto-advance
done

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
