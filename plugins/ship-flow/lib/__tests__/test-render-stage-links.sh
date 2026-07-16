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
entity_type: epic
status: sharp
stage_outputs:
  plan: plan.md
  execute: execute.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
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

echo "--- Case (a): stdout-only derived table; epic and historical body are inert ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
EXPECTED='| Stage | File |
|-------|------|
| plan | [plan.md](plan.md) |
| execute | [execute.md](execute.md) |'
ERR="$(mktemp)"; RC=0
OUT="$(bash "${LIB_DIR}/render-stage-links.sh" --entity=index.md 2>"$ERR")" || RC=$?
if [ "$RC" = 0 ] && [ "$OUT" = "$EXPECTED" ] && [ ! -s "$ERR" ] && [ "$(sha256_of index.md)" = "$H" ]; then
  echo "OK Case-a exact stdout and entity bytes preserved"
else echo "FAIL Case-a derived view contract (rc=$RC out=$OUT err=$(cat "$ERR"))"; FAIL=1; fi
rm -f "$ERR"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case (b): persisted body section is not required ---"
TMP="$(setup_fixture_no_section)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
OUT="$(bash "${LIB_DIR}/render-stage-links.sh" --entity=index.md 2>/dev/null)"; RC=$?
if [ "$RC" = 0 ] && [ "$OUT" = '| Stage | File |
|-------|------|
| plan | [plan.md](plan.md) |' ] && [ "$(sha256_of index.md)" = "$H" ]; then
  echo "OK Case-b no body registry needed"
else echo "FAIL Case-b body-free render"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case (c): repeated reads are deterministic ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
RENDER_AFTER_1="$(bash "${LIB_DIR}/render-stage-links.sh" --entity=index.md 2>/dev/null)"
CONTENT_AFTER_1="$(cat index.md)"
H2="$(sha256_of index.md)"
assert_exit 0 \
  "bash '${LIB_DIR}/render-stage-links.sh' --entity=index.md" \
  "Case-c second read exit 0"
RENDER_AFTER_2="$(bash "${LIB_DIR}/render-stage-links.sh" --entity=index.md 2>/dev/null)"
CONTENT_AFTER_2="$(cat index.md)"
# Content after two runs should be same as after one run
H3="$(sha256_of index.md)"
# shellcheck disable=SC2015 # compact test assertion updates FAIL on mismatch
[ "$H2" = "$H3" ] && echo "OK Case-c idempotent (no diff)" || { echo "FAIL Case-c not idempotent"; FAIL=1; }
# shellcheck disable=SC2015 # compact test assertion updates FAIL on either condition
[ "$RENDER_AFTER_1" = "$RENDER_AFTER_2" ] && [ "$CONTENT_AFTER_1" = "$CONTENT_AFTER_2" ] && [ "$H" = "$H2" ] || { echo "FAIL Case-c changed output or entity"; FAIL=1; }
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case (d): legacy mutation options are rejected ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
assert_exit 1 \
  "bash '${LIB_DIR}/render-stage-links.sh' --entity=index.md --if-hash='$WRONG_HASH' --no-commit" \
  "Case-d stale mutation interface rejected"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case (e): empty map renders complete empty table ---"
TMP="$(setup_fixture_no_section)"
pushd "$TMP" >/dev/null || exit 1
echo "noise" > noise.txt
sed -i.bak '/  plan: plan.md/d; s/stage_outputs:/stage_outputs: {}/' index.md; rm -f index.md.bak
H="$(sha256_of index.md)"
OUT="$(bash "${LIB_DIR}/render-stage-links.sh" --entity=index.md 2>/dev/null)"; RC=$?
if [ "$RC" = 0 ] && [ "$OUT" = '| Stage | File |
|-------|------|' ] && [ "$(sha256_of index.md)" = "$H" ]; then echo "OK Case-e empty table"
else echo "FAIL Case-e empty table contract"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo; echo "--- Case (f): malformed authority and staging failures fail closed ---"
TMP="$(setup_fixture)"; pushd "$TMP" >/dev/null || exit 1; H="$(sha256_of index.md)"; ERR="$(mktemp)"; OUT="$(mktemp)"
sed -i.bak 's/execute: execute.md/execute: wrong.md/' index.md; rm -f index.md.bak; MALFORMED_H="$(sha256_of index.md)"; RC=0
bash "${LIB_DIR}/render-stage-links.sh" --entity=index.md >"$OUT" 2>"$ERR" || RC=$?; if [ "$RC" -ne 0 ] && [ ! -s "$OUT" ] && [ -s "$ERR" ] && [ "$(sha256_of index.md)" = "$MALFORMED_H" ]; then echo "OK Case-f malformed authority rejected"; else echo "FAIL Case-f malformed authority failed open"; FAIL=1; fi; rm -f "$OUT" "$ERR"
git checkout -q -- index.md; [ "$(sha256_of index.md)" = "$H" ] || exit 1; FAKE="$TMP/fake-bin"; mkdir "$FAKE"; for TOOL in mktemp cat; do
  printf '#!/bin/sh\nprintf "injected-%s failure\\n" >&2\nexit 91\n' "$TOOL" > "$FAKE/$TOOL"; chmod +x "$FAKE/$TOOL"; ERR="$TMP/$TOOL.err"; OUT="$TMP/$TOOL.out"; RC=0
  PATH="$FAKE:$PATH" bash "${LIB_DIR}/render-stage-links.sh" --entity=index.md >"$OUT" 2>"$ERR" || RC=$?
  if [ "$RC" -ne 0 ] && [ ! -s "$OUT" ] && grep -qF "injected-$TOOL failure" "$ERR" && [ "$(sha256_of index.md)" = "$H" ]; then echo "OK Case-f $TOOL failure propagated"; else echo "FAIL Case-f $TOOL failed open (rc=$RC)"; FAIL=1; fi; rm -f "$FAKE/$TOOL" "$OUT" "$ERR"
done; popd >/dev/null || exit 1; rm -rf "$TMP"

exit $FAIL
