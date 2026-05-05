#!/usr/bin/env bash
# test-frontmatter-helpers.sh — DC-22..DC-26 for status + stage-output atomic helpers
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
  cat > "$dir/test.md" <<'EOF'
---
id: "test-fm"
title: "Test entity"
status: draft
priority: P2
---

### Problem

Fixture body.
EOF
  (cd "$dir" && git init -q && git add test.md && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

echo "--- DC-22: update-entity-status success ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of test.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/update-entity-status.sh' --entity=test.md --new-status=plan --if-hash='$H' --no-commit" \
  "DC-22a success with valid hash"
if grep -q '^status: plan$' test.md; then echo "OK DC-22b status updated to plan"
else echo "FAIL DC-22b status not updated"; FAIL=1; fi
if grep -q '^priority: P2$' test.md; then echo "OK DC-22c other fields preserved"
else echo "FAIL DC-22c priority lost"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-23: update-entity-status stale hash → exit 6 ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
assert_exit 6 \
  "bash '${LIB_DIR}/update-entity-status.sh' --entity=test.md --new-status=plan --if-hash='$WRONG_HASH' --no-commit" \
  "DC-23a stale hash rejected"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-24: update-entity-status missing --if-hash → exit 7 ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
assert_exit 7 \
  "bash '${LIB_DIR}/update-entity-status.sh' --entity=test.md --new-status=plan --no-commit" \
  "DC-24a missing --if-hash rejected"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-25: update-entity-status with --commit-as stages only entity file ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
echo "noise" > noise.txt
H="$(sha256_of test.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/update-entity-status.sh' --entity=test.md --new-status=plan --if-hash='$H' --commit-as='test: DC-25'" \
  "DC-25a commit succeeds"
COMMIT_FILES="$(git show --name-only --format='' HEAD | grep -c '.')"
if [ "$COMMIT_FILES" = "1" ] && git show --name-only --format='' HEAD | grep -q '^test.md$'; then
  echo "OK DC-25b commit scoped to test.md only"
else
  echo "FAIL DC-25b commit scope leak (files=$COMMIT_FILES)"; FAIL=1
fi
if [ -f noise.txt ] && ! git ls-files --error-unmatch noise.txt >/dev/null 2>&1; then
  echo "OK DC-25c noise.txt not tracked (not in commit)"
else echo "FAIL DC-25c noise.txt leaked"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-26: register-stage-output appends stage_outputs.<stage> ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
mkdir -p stages && echo "spec content" > stages/shape.md
H="$(sha256_of test.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/register-stage-output.sh' --entity=test.md --stage=sharp --file=stages/shape.md --if-hash='$H' --no-commit" \
  "DC-26a register-stage-output success"
if grep -qE '^[[:space:]]*sharp:[[:space:]]*stages/spec\.md' test.md; then
  echo "OK DC-26b stage_outputs.sharp entry present"
else echo "FAIL DC-26b stage_outputs.sharp entry missing"; FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

exit $FAIL
