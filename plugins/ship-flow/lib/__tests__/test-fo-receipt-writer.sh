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
CAPTURE_DIR="$(mktemp -d)"
TMP_DIRS+=("$CAPTURE_DIR")

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
  local out err
  shift
  out="$(mktemp "$CAPTURE_DIR/out.XXXXXX")"
  err="$(mktemp "$CAPTURE_DIR/err.XXXXXX")"
  if "$@" >"$out" 2>"$err"; then
    record_pass "$desc"
  else
    record_fail "$desc"
    sed 's/^/    stderr: /' "$err"
  fi
}

assert_failure_contains() {
  local desc="$1"
  local expected="$2"
  local out err
  shift 2
  out="$(mktemp "$CAPTURE_DIR/out.XXXXXX")"
  err="$(mktemp "$CAPTURE_DIR/err.XXXXXX")"
  if "$@" >"$out" 2>"$err"; then
    record_fail "$desc"
    sed 's/^/    stdout: /' "$out"
  elif grep -qi "$expected" "$err"; then
    record_pass "$desc"
  else
    record_fail "$desc"
    sed 's/^/    stderr: /' "$err"
  fi
}

assert_failure_contains_without_hang() {
  local desc="$1"
  local expected="$2"
  local out err pid waited
  shift 2
  out="$(mktemp)"
  err="$(mktemp)"

  "$@" >"$out" 2>"$err" &
  pid="$!"
  waited=0
  while kill -0 "$pid" 2>/dev/null && [ "$waited" -lt 20 ]; do
    sleep 0.1
    waited=$((waited + 1))
  done

  if kill -0 "$pid" 2>/dev/null; then
    kill "$pid" 2>/dev/null || true
    wait "$pid" 2>/dev/null || true
    record_fail "$desc"
    echo "    stderr: command timed out waiting for missing option value failure"
  elif wait "$pid"; then
    record_fail "$desc"
    sed 's/^/    stdout: /' "$out"
  elif grep -qi "$expected" "$err"; then
    record_pass "$desc"
  else
    record_fail "$desc"
    sed 's/^/    stderr: /' "$err"
  fi

  rm -f "$out" "$err"
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

file_mode() {
  local file="$1"
  if stat -f '%OLp' "$file" >/dev/null 2>&1; then
    stat -f '%OLp' "$file"
  else
    stat -c '%a' "$file"
  fi
}

assert_file_mode() {
  local desc="$1"
  local file="$2"
  local expected="$3"
  local actual
  actual="$(file_mode "$file")"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc"
    echo "    expected mode: $expected"
    echo "    actual mode:   $actual"
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
assert_file_mode "new ledger is normalized to mode 644" "$ENTITY_DIR/fo-receipts.md" "644"
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

for case_name in open-decisions-mapping open-decisions-list open-decisions-scalar; do
  BAD_ENTITY_DIR="$(new_entity_dir)"
  BAD_RECEIPT="$(mktemp)"
  write_receipt "$BAD_RECEIPT" "fo-20260512T000610Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
  case "$case_name" in
    open-decisions-mapping)
      sed -i.bak '/^open_decisions:/c\
open_decisions:\
  owner: captain
' "$BAD_RECEIPT"
      ;;
    open-decisions-list)
      sed -i.bak '/^open_decisions:/c\
open_decisions:\
  - needs captain
' "$BAD_RECEIPT"
      ;;
    open-decisions-scalar)
      sed -i.bak '/^open_decisions:/c\
open_decisions:\
  needs captain
' "$BAD_RECEIPT"
      ;;
  esac
  rm -f "${BAD_RECEIPT}.bak"
  assert_failure_contains "self-approved receipt rejects ${case_name}" "captain" \
    bash "$HELPER" --entity-folder "$BAD_ENTITY_DIR" --receipt-file "$BAD_RECEIPT" --transition-slug verify-proceed-auto-advance
done

for case_name in open-decisions-empty open-decisions-null; do
  BAD_ENTITY_DIR="$(new_entity_dir)"
  BAD_RECEIPT="$(mktemp)"
  write_receipt "$BAD_RECEIPT" "fo-20260512T000615Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
  case "$case_name" in
    open-decisions-empty)
      sed -i.bak '/^open_decisions:/c\
open_decisions:
' "$BAD_RECEIPT"
      ;;
    open-decisions-null)
      sed -i.bak '/^open_decisions:/c\
open_decisions: null
' "$BAD_RECEIPT"
      ;;
  esac
  rm -f "${BAD_RECEIPT}.bak"
  assert_failure_contains "self-approved receipt rejects ${case_name}" "captain" \
    bash "$HELPER" --entity-folder "$BAD_ENTITY_DIR" --receipt-file "$BAD_RECEIPT" --transition-slug verify-proceed-auto-advance
done

for case_name in empty-list empty-map none false no zero quoted-empty-list quoted-empty-map quoted-none quoted-false quoted-no quoted-zero; do
  SAFE_ENTITY_DIR="$(new_entity_dir)"
  SAFE_RECEIPT="$(mktemp)"
  case "$case_name" in
    empty-list)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000620Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "[]"
      ;;
    empty-map)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000621Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "{}"
      ;;
    none)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000622Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "none"
      ;;
    false)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000623Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "false"
      ;;
    no)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000624Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "no"
      ;;
    zero)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000625Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "0"
      ;;
    quoted-empty-list)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000626Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" '"[]"'
      ;;
    quoted-empty-map)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000627Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "'{}'"
      ;;
    quoted-none)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000628Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" '"none"'
      ;;
    quoted-false)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000629Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "'false'"
      ;;
    quoted-no)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000630Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" '"no"'
      ;;
    quoted-zero)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T000631Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none" "'0'"
      ;;
  esac
  assert_success "self-approved receipt accepts open_decisions safe sentinel ${case_name}" \
    bash "$HELPER" --entity-folder "$SAFE_ENTITY_DIR" --receipt-file "$SAFE_RECEIPT" --transition-slug verify-proceed-auto-advance
done

for case_name in quoted-precondition-fail quoted-precondition-missing; do
  BAD_ENTITY_DIR="$(new_entity_dir)"
  BAD_RECEIPT="$(mktemp)"
  case "$case_name" in
    quoted-precondition-fail)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000650Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" '"fail"'
      ;;
    quoted-precondition-missing)
      write_receipt "$BAD_RECEIPT" "fo-20260512T000660Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "'missing'"
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

for case_name in missing ambiguous present path-payload text-payload quoted-missing quoted-ambiguous quoted-present; do
  BAD_ENTITY_DIR="$(new_entity_dir)"
  BAD_RECEIPT="$(mktemp)"
  case "$case_name" in
    missing)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001010Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "missing"
      ;;
    ambiguous)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001020Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "ambiguous"
      ;;
    present)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001030Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "present"
      ;;
    path-payload)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001040Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "/tmp/evidence.txt"
      ;;
    text-payload)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001050Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" '"needs captain evidence review"'
      ;;
    quoted-missing)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001060Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" '"missing"'
      ;;
    quoted-ambiguous)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001070Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "'ambiguous'"
      ;;
    quoted-present)
      write_receipt "$BAD_RECEIPT" "fo-20260512T001080Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" '"present"'
      ;;
  esac
  assert_failure_contains "self-approved receipt rejects blocker_scan ${case_name}" "captain" \
    bash "$HELPER" --entity-folder "$BAD_ENTITY_DIR" --receipt-file "$BAD_RECEIPT" --transition-slug verify-proceed-auto-advance
done

for case_name in empty null; do
  BAD_ENTITY_DIR="$(new_entity_dir)"
  BAD_RECEIPT="$(mktemp)"
  write_receipt "$BAD_RECEIPT" "fo-20260512T001081Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
  case "$case_name" in
    empty)
      sed -i.bak '/^blocker_scan:/,/^open_decisions:/c\
blocker_scan:\
open_decisions: []
' "$BAD_RECEIPT"
      ;;
    null)
      sed -i.bak '/^blocker_scan:/,/^open_decisions:/c\
blocker_scan: null\
open_decisions: []
' "$BAD_RECEIPT"
      ;;
  esac
  rm -f "${BAD_RECEIPT}.bak"
  assert_failure_contains "self-approved receipt rejects empty/null blocker_scan ${case_name}" "captain" \
    bash "$HELPER" --entity-folder "$BAD_ENTITY_DIR" --receipt-file "$BAD_RECEIPT" --transition-slug verify-proceed-auto-advance
done

for case_name in none false no zero quoted-none quoted-false quoted-no quoted-zero; do
  SAFE_ENTITY_DIR="$(new_entity_dir)"
  SAFE_RECEIPT="$(mktemp)"
  case "$case_name" in
    none)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T001085Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "none"
      ;;
    false)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T001086Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "false"
      ;;
    no)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T001087Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "no"
      ;;
    zero)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T001088Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "0"
      ;;
    quoted-none)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T001089Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" '"none"'
      ;;
    quoted-false)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T001090Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "'false'"
      ;;
    quoted-no)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T001091Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" '"no"'
      ;;
    quoted-zero)
      write_receipt "$SAFE_RECEIPT" "fo-20260512T001092Z-verify-proceed-auto-advance" "verify-proceed-auto-advance" "pass" "'0'"
      ;;
  esac
  assert_success "self-approved receipt accepts blocker_scan safe sentinel ${case_name}" \
    bash "$HELPER" --entity-folder "$SAFE_ENTITY_DIR" --receipt-file "$SAFE_RECEIPT" --transition-slug verify-proceed-auto-advance
done

SAFE_BLOCKER_MAP_ENTITY_DIR="$(new_entity_dir)"
SAFE_BLOCKER_MAP_RECEIPT="$(mktemp)"
write_receipt "$SAFE_BLOCKER_MAP_RECEIPT" "fo-20260512T001093Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
sed -i.bak '/^blocker_scan:/,/^open_decisions:/c\
blocker_scan: {}\
open_decisions: []
' "$SAFE_BLOCKER_MAP_RECEIPT"
rm -f "${SAFE_BLOCKER_MAP_RECEIPT}.bak"
assert_success "self-approved receipt accepts blocker_scan explicit empty-map sentinel" \
  bash "$HELPER" --entity-folder "$SAFE_BLOCKER_MAP_ENTITY_DIR" --receipt-file "$SAFE_BLOCKER_MAP_RECEIPT" --transition-slug verify-proceed-auto-advance

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

MODE_PRESERVE_ENTITY_DIR="$(new_entity_dir)"
MODE_PRESERVE_RECEIPT="$(mktemp)"
write_receipt "$MODE_PRESERVE_RECEIPT" "fo-20260512T001350Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
printf '%s\n' '# FO Receipts' '' '## existing' > "$MODE_PRESERVE_ENTITY_DIR/fo-receipts.md"
chmod 640 "$MODE_PRESERVE_ENTITY_DIR/fo-receipts.md"
assert_success "append preserves existing ledger mode" \
  bash "$HELPER" --entity-folder "$MODE_PRESERVE_ENTITY_DIR" --receipt-file "$MODE_PRESERVE_RECEIPT" --transition-slug verify-proceed-auto-advance
assert_file_mode "existing ledger remains mode 640 after append" "$MODE_PRESERVE_ENTITY_DIR/fo-receipts.md" "640"

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

READ_PAYLOAD_FAIL_ENTITY_DIR="$(new_entity_dir)"
READ_PAYLOAD_FAIL_RECEIPT="$(mktemp)"
READ_PAYLOAD_FAIL_BIN="$(mktemp -d)"
TMP_DIRS+=("$READ_PAYLOAD_FAIL_BIN")
write_receipt "$READ_PAYLOAD_FAIL_RECEIPT" "fo-20260512T001450Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
cat > "$READ_PAYLOAD_FAIL_BIN/cat" <<'EOF'
#!/usr/bin/env bash
echo "forced receipt payload read failure" >&2
exit 1
EOF
chmod +x "$READ_PAYLOAD_FAIL_BIN/cat"
assert_failure_contains "append reports receipt payload read failure" "append receipt payload" \
  env PATH="$READ_PAYLOAD_FAIL_BIN:$PATH" bash "$HELPER" --entity-folder "$READ_PAYLOAD_FAIL_ENTITY_DIR" --receipt-file "$READ_PAYLOAD_FAIL_RECEIPT" --transition-slug verify-proceed-auto-advance

MISSING_VALUE_ENTITY_DIR="$(new_entity_dir)"
MISSING_VALUE_RECEIPT="$(mktemp)"
write_receipt "$MISSING_VALUE_RECEIPT" "fo-20260512T001500Z-verify-proceed-auto-advance" "verify-proceed-auto-advance"
assert_failure_contains_without_hang "missing --entity-folder value fails fast" "Missing value for --entity-folder" \
  bash "$HELPER" --entity-folder
assert_failure_contains_without_hang "missing --receipt-file value fails fast" "Missing value for --receipt-file" \
  bash "$HELPER" --entity-folder "$MISSING_VALUE_ENTITY_DIR" --receipt-file
assert_failure_contains_without_hang "missing --transition-slug value fails fast" "Missing value for --transition-slug" \
  bash "$HELPER" --entity-folder "$MISSING_VALUE_ENTITY_DIR" --receipt-file "$MISSING_VALUE_RECEIPT" --transition-slug

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
