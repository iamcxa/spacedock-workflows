#!/usr/bin/env bash
# test-render-stage-links.sh — tests for render-stage-links.sh (TDD: written before implementation)
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
stage_outputs:
  plan: plan.md
  execute: execute.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| spec | [spec.md](spec.md) |
<!-- /section:stage-artifact-links -->
EOF
  (cd "$dir" && git init -q && git add index.md && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

setup_fixture_no_section() {
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/index.md" <<'EOF'
---
id: "test-wiring"
title: "Test entity"
status: sharp
stage_outputs:
  plan: plan.md
---

Some body content without stage-artifact-links section.
EOF
  (cd "$dir" && git init -q && git add index.md && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

echo "--- Case (a): renders fresh table from frontmatter stage_outputs ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/render-stage-links.sh' --entity=index.md --if-hash='$H' --no-commit" \
  "Case-a exit 0"
if grep -q "| plan | \[plan.md\](plan.md) |" index.md; then echo "OK Case-a plan row present"
else echo "FAIL Case-a plan row missing"; FAIL=1; fi
if grep -q "| execute | \[execute.md\](execute.md) |" index.md; then echo "OK Case-a execute row present"
else echo "FAIL Case-a execute row missing"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case (b): replaces existing stage-artifact-links block in place ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/render-stage-links.sh' --entity=index.md --if-hash='$H' --no-commit" \
  "Case-b exit 0"
# The old spec row should be replaced by derived rows from frontmatter
if grep -q "| plan | \[plan.md\](plan.md) |" index.md; then echo "OK Case-b new rows present"
else echo "FAIL Case-b new rows missing"; FAIL=1; fi
# verify markers still present (in-place replacement)
if grep -q "<!-- section:stage-artifact-links -->" index.md && grep -q "<!-- /section:stage-artifact-links -->" index.md; then
  echo "OK Case-b markers preserved"
else echo "FAIL Case-b markers missing"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case (c): idempotent (running twice on same input → no diff) ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
bash "${LIB_DIR}/render-stage-links.sh" --entity=index.md --if-hash="$H" --no-commit >/dev/null 2>&1
H2="$(sha256_of index.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/render-stage-links.sh' --entity=index.md --if-hash='$H2' --no-commit" \
  "Case-c second run exit 0"
# Content after two runs should be same as after one run
CONTENT_AFTER_1="$(cat index.md)"
H3="$(sha256_of index.md)"
[ "$H2" = "$H3" ] && echo "OK Case-c idempotent (no diff)" || { echo "FAIL Case-c not idempotent"; FAIL=1; }
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case (d): --if-hash CAS rejects stale → exit 6 ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
assert_exit 6 \
  "bash '${LIB_DIR}/render-stage-links.sh' --entity=index.md --if-hash='$WRONG_HASH' --no-commit" \
  "Case-d stale hash rejected"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case (e): --commit-as stages only entity file ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
echo "noise" > noise.txt
H="$(sha256_of index.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/render-stage-links.sh' --entity=index.md --if-hash='$H' --commit-as='test: render-stage-links commit scope'" \
  "Case-e commit succeeds"
COMMIT_FILES="$(git show --name-only --format='' HEAD | grep -c '.' || true)"
if [ "$COMMIT_FILES" = "1" ] && git show --name-only --format='' HEAD | grep -q '^index.md$'; then
  echo "OK Case-e commit scoped to index.md only"
else
  echo "FAIL Case-e commit scope leak (files=$COMMIT_FILES)"; FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

exit $FAIL
