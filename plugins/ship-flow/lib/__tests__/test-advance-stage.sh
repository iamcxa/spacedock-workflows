#!/usr/bin/env bash
# test-advance-stage.sh — tests for advance-stage.sh (TDD: written before implementation)
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

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'
  else shasum -a 256 "$1" | awk '{print $1}'
  fi
}

cd "$REPO_ROOT" || exit 1

setup_fixture() {
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/index.md" <<'EOF'
---
id: "test-wiring"
title: "Test entity"
status: sharp
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| spec | [spec.md](spec.md) |
<!-- /section:stage-artifact-links -->
EOF
  # Create a dummy plan.md artifact
  echo "# Plan" > "$dir/plan.md"
  (cd "$dir" && git init -q && git add . && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

echo "--- Case 1: success path — advances status + writes stage_outputs + re-renders body ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance'" \
  "Case-1a exit 0"
if grep -q '^status: plan$' index.md; then echo "OK Case-1b status advanced to plan"
else echo "FAIL Case-1b status not advanced"; FAIL=1; fi
if grep -qE '^\s+plan:[[:space:]]*plan\.md' index.md; then echo "OK Case-1c stage_outputs.plan written"
else echo "FAIL Case-1c stage_outputs.plan missing"; FAIL=1; fi
if grep -q "| plan | \[plan.md\](plan.md) |" index.md; then echo "OK Case-1d body table updated"
else echo "FAIL Case-1d body table not updated"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 2: stale hash returns exit 6 ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
assert_exit 6 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$WRONG_HASH' --commit-as='plan(test): advance'" \
  "Case-2 stale hash returns exit 6"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 3: idempotent on already-advanced entity (no diff) ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
# First advance
bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): first advance" >/dev/null 2>&1
H2="$(sha256_of index.md)"
# Second advance with same args — should be no-op (exit 0, no new diff)
BEFORE_COMMITS="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H2' --commit-as='plan(test): second advance'" \
  "Case-3a second advance exits 0"
AFTER_COMMITS="$(git rev-list --count HEAD)"
if [ "$BEFORE_COMMITS" = "$AFTER_COMMITS" ]; then echo "OK Case-3b no new commit (idempotent)"
else echo "FAIL Case-3b unexpected new commit"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 4: not-a-git-repo emits warning + exits 0 ---"
TMP_NONGIT="$(mktemp -d)"
cat > "$TMP_NONGIT/index.md" <<'EOF'
---
id: "test"
title: "Test"
status: sharp
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
<!-- /section:stage-artifact-links -->
EOF
echo "# Plan" > "$TMP_NONGIT/plan.md"
pushd "$TMP_NONGIT" >/dev/null || exit 1
H="$(sha256_of index.md)"
WARNING_OUT="$(bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): no-git" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "0" ]; then echo "OK Case-4a exits 0 outside git repo"
else echo "FAIL Case-4a unexpected exit $GOT_RC"; FAIL=1; fi
if echo "$WARNING_OUT" | grep -qi "warn\|skip"; then echo "OK Case-4b warning emitted"
else echo "FAIL Case-4b no warning in output"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP_NONGIT"

echo
echo "--- Case 5: missing entity exits 3 ---"
assert_exit 3 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=/nonexistent/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='abc123' --commit-as='x'" \
  "Case-5 missing entity exits 3"

exit $FAIL
