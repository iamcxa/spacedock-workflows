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

assert_file_not_contains() {
  local desc="$1"
  local file="$2"
  local pattern="$3"
  if grep -Eq "$pattern" "$file"; then
    record_fail "$desc"
  else
    record_pass "$desc"
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
  local prompt_captain_required="${7:-false}"

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
  prompt_captain_required: ${prompt_captain_required}
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

for case_name in precondition-fail precondition-missing blocker-found prompt-captain-required open-decisions; do
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
    prompt-captain-required)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000500Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "[]" "true"
      ;;
    open-decisions)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000600Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" '["needs captain"]'
      ;;
  esac
  assert_failure_contains "self-approved receipt rejects ${case_name}" "captain" \
    bash "$HELPER" --entity-folder "$BAD_ENTITY_DIR" --receipt-file "$BAD_RECEIPT" --transition-slug verify-proceed-auto-advance
done

for case_name in single-quoted-true single-quoted-yes double-quoted-true numeric-one; do
  BAD_ENTITY_DIR="$(new_entity_dir)"
  BAD_RECEIPT="$(mktemp)"
  case "$case_name" in
    single-quoted-true)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000700Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "[]" "'true'"
      ;;
    single-quoted-yes)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000800Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "[]" "'yes'"
      ;;
    double-quoted-true)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000900Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "[]" '"true"'
      ;;
    numeric-one)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001000Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "[]" "1"
      ;;
  esac
  assert_failure_contains "self-approved receipt rejects prompt-captain-required ${case_name}" "captain" \
    bash "$HELPER" --entity-folder "$BAD_ENTITY_DIR" --receipt-file "$BAD_RECEIPT" --transition-slug verify-proceed-auto-advance
done

MISSING_OPEN_ENTITY_DIR="$(new_entity_dir)"
MISSING_OPEN_RECEIPT="$(mktemp)"
write_receipt "$MISSING_OPEN_RECEIPT" "fo-20260512T001100Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
sed -i.bak '/^open_decisions:/d' "$MISSING_OPEN_RECEIPT"
rm -f "${MISSING_OPEN_RECEIPT}.bak"
assert_failure_contains "self-approved receipt rejects missing open_decisions" "missing required top-level key: open_decisions" \
  bash "$HELPER" --entity-folder "$MISSING_OPEN_ENTITY_DIR" --receipt-file "$MISSING_OPEN_RECEIPT" --transition-slug verify-proceed-auto-advance

FOUND_OUTSIDE_ENTITY_DIR="$(new_entity_dir)"
FOUND_OUTSIDE_RECEIPT="$(mktemp)"
write_receipt "$FOUND_OUTSIDE_RECEIPT" "fo-20260512T001200Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
awk '
  /^evidence:/ {
    print
    print "  reviewer_text: found in historical evidence only"
    print "  unrelated_status: found"
    next
  }
  { print }
' "$FOUND_OUTSIDE_RECEIPT" > "${FOUND_OUTSIDE_RECEIPT}.next"
mv "${FOUND_OUTSIDE_RECEIPT}.next" "$FOUND_OUTSIDE_RECEIPT"
assert_success "found outside blocker_scan does not reject self-approved receipt" \
  bash "$HELPER" --entity-folder "$FOUND_OUTSIDE_ENTITY_DIR" --receipt-file "$FOUND_OUTSIDE_RECEIPT" --transition-slug verify-proceed-auto-advance

READ_FAIL_ENTITY_DIR="$(new_entity_dir)"
READ_FAIL_RECEIPT="$(mktemp)"
write_receipt "$READ_FAIL_RECEIPT" "fo-20260512T001300Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
printf '%s\n' '# FO Receipts' '' '## existing' > "$READ_FAIL_ENTITY_DIR/fo-receipts.md"
chmod 000 "$READ_FAIL_ENTITY_DIR/fo-receipts.md"
assert_failure_contains "append fails when existing ledger cannot be read" "read existing ledger" \
  bash "$HELPER" --entity-folder "$READ_FAIL_ENTITY_DIR" --receipt-file "$READ_FAIL_RECEIPT" --transition-slug verify-proceed-auto-advance
chmod 600 "$READ_FAIL_ENTITY_DIR/fo-receipts.md" 2>/dev/null || true
assert_file_contains "read failure preserves existing ledger content" "$READ_FAIL_ENTITY_DIR/fo-receipts.md" '^## existing$'
assert_file_not_contains "read failure does not append new receipt" "$READ_FAIL_ENTITY_DIR/fo-receipts.md" '^## fo-20260512T001300Z-verify-proceed-auto-advance$'

MOVE_FAIL_ENTITY_DIR="$(new_entity_dir)"
MOVE_FAIL_RECEIPT="$(mktemp)"
MOVE_FAIL_BIN="$(mktemp -d)"
TMP_DIRS+=("$MOVE_FAIL_BIN")
write_receipt "$MOVE_FAIL_RECEIPT" "fo-20260512T001400Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
cat > "$MOVE_FAIL_BIN/mv" <<'EOF'
#!/usr/bin/env bash
echo "forced mv failure" >&2
exit 1
EOF
chmod +x "$MOVE_FAIL_BIN/mv"
assert_failure_contains "append reports final ledger move failure" "move receipt ledger" \
  env PATH="$MOVE_FAIL_BIN:$PATH" bash "$HELPER" --entity-folder "$MOVE_FAIL_ENTITY_DIR" --receipt-file "$MOVE_FAIL_RECEIPT" --transition-slug verify-proceed-auto-advance

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
