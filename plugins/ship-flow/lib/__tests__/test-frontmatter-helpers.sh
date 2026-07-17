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
priority: P2
status: draft
stage_outputs: {}
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
if awk '/^status: plan$/{getline a; getline b; exit !(a=="stage_outputs: {}" && b=="---")} END{if(!a)exit 1}' test.md; then
  echo "OK DC-22d status writer preserves exact authority tail"
else echo "FAIL DC-22d status writer malformed authority tail"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo; echo "--- DC-22e: status update preserves an absent final LF and all other bytes ---"; TMP="$(mktemp -d)"
printf '%s' $'---\nid: "no-lf"\nstatus: draft\nstage_outputs: {}\n---\nbody without final LF' > "$TMP/test.md"
printf '%s' $'---\nid: "no-lf"\nstatus: plan\nstage_outputs: {}\n---\nbody without final LF' > "$TMP/expected.md"
H="$(sha256_of "$TMP/test.md")"
assert_exit 0 "bash '${LIB_DIR}/update-entity-status.sh' --entity='$TMP/test.md' --new-status=plan --if-hash='$H' --no-commit" "DC-22e no-final-LF update succeeds"
if cmp -s "$TMP/expected.md" "$TMP/test.md"; then echo "OK DC-22f EOF convention and every non-status byte preserved"; else echo "FAIL DC-22f writer changed non-status or EOF bytes"; FAIL=1; fi; rm -rf "$TMP"

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
H="$(sha256_of test.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/register-stage-output.sh' --entity=test.md --stage=shape --file=shape.md --if-hash='$H' --no-commit" \
  "DC-26a register-stage-output success"
if awk '/^status: draft$/{getline a; getline b; getline c; exit !(a=="stage_outputs:" && b=="  shape: shape.md" && c=="---")} END{if(!a)exit 1}' test.md; then
  echo "OK DC-26b exact empty map expands to canonical shape row"
else echo "FAIL DC-26b canonical stage_outputs.shape missing"; FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- DC-26c: both writers reject Contract-1/body-only input unchanged ---"
TMP="$(mktemp -d)"
cat > "$TMP/legacy.md" <<'EOF'
---
id: "legacy"
status: draft
---
<!-- section:stage-artifact-links -->
| Stage | File |
| shape | [shape.md](shape.md) |
EOF
cp "$TMP/legacy.md" "$TMP/legacy-status.md"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of legacy.md)"; BEFORE="$(sha256_of legacy.md)"
assert_exit 10 \
  "bash '${LIB_DIR}/register-stage-output.sh' --entity=legacy.md --stage=shape --file=shape.md --if-hash='$H' --no-commit" \
  "DC-26c register rejects body-only entity"
if [ "$(sha256_of legacy.md)" = "$BEFORE" ]; then echo "OK DC-26d register rejection preserves bytes"; else echo "FAIL DC-26d register changed body-only entity"; FAIL=1; fi
H_STATUS="$(sha256_of legacy-status.md)"; BEFORE_STATUS="$H_STATUS"
assert_exit 10 \
  "bash '${LIB_DIR}/update-entity-status.sh' --entity=legacy-status.md --new-status=plan --if-hash='$H_STATUS' --no-commit" \
  "DC-26e status update rejects body-only entity"
if [ "$(sha256_of legacy-status.md)" = "$BEFORE_STATUS" ]; then echo "OK DC-26f status rejection preserves bytes"; else echo "FAIL DC-26f status changed body-only entity"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

exit $FAIL
