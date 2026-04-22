#!/usr/bin/env bash
# test-map-layer.sh — DC-1..DC-11 runner for #059 flow-map-schema-v1
# Pattern: verify-contract.sh (repo root) — FAIL=0, exit $FAIL
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
REPO_ROOT="$(cd "${LIB_DIR}/../../.." && pwd)"
FAIL=0

# Load map-helpers for sha256_of (available after Task 3 ships)
[ -f "${LIB_DIR}/map-helpers.sh" ] && source "${LIB_DIR}/map-helpers.sh"

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}
assert_stdout_matches() {
  local pattern="$1" cmd="$2" name="$3"
  local out; out="$(eval "$cmd" 2>&1)"
  if echo "$out" | grep -qE "$pattern"; then echo "OK $name"
  else echo "FAIL $name (stdout/stderr did not match /$pattern/)"; FAIL=1; fi
}
assert_stderr_contains() {
  local needle="$1" cmd="$2" name="$3"
  local err; err="$(eval "$cmd" 2>&1 >/dev/null)"
  if echo "$err" | grep -qF "$needle"; then echo "OK $name"
  else echo "FAIL $name (stderr missing: $needle)"; FAIL=1; fi
}

cd "$REPO_ROOT" || exit 1
ARCH="ARCHITECTURE.md"

# DC-1: extract-map content
assert_stdout_matches 'System boundary' \
  "${LIB_DIR}/extract-map.sh ${ARCH} context" 'DC-1 extract-map content'

# DC-2: extract-map hash
assert_stdout_matches '^[a-f0-9]{64}$' \
  "${LIB_DIR}/extract-map.sh ${ARCH} context --emit-hash-only" 'DC-2 extract-map hash'

# DC-3: round-trip (no-commit)
dc3() {
  local tag=context H BODY TMP RE H2
  H="$(${LIB_DIR}/extract-map.sh ${ARCH} $tag --emit-hash-only)" || return 1
  BODY="$(${LIB_DIR}/extract-map.sh ${ARCH} $tag | sed '1d;$d')"
  TMP="$(mktemp)"
  printf '%s\nDC3-MARKER\n' "$BODY" > "$TMP"
  "${LIB_DIR}/patch-map.sh" "${ARCH}" "$tag" --if-hash="$H" --no-commit < "$TMP" || { rm -f "$TMP"; return 1; }
  RE="$(${LIB_DIR}/extract-map.sh ${ARCH} $tag)"
  rm -f "$TMP"
  # Restore original
  H2="$(${LIB_DIR}/extract-map.sh ${ARCH} $tag --emit-hash-only)"
  printf '%s\n' "$BODY" | "${LIB_DIR}/patch-map.sh" "${ARCH}" "$tag" --if-hash="$H2" --no-commit
  echo "$RE" | grep -q 'DC3-MARKER'
}
if dc3 2>/dev/null; then echo "OK DC-3 round-trip"; else echo "FAIL DC-3 round-trip"; FAIL=1; fi

# DC-4: no --if-hash → exit 7
assert_exit 7 \
  "echo foo | ${LIB_DIR}/patch-map.sh ${ARCH} context" 'DC-4 no-if-hash exit 7'
assert_stderr_contains 'extract-map' \
  "echo foo | ${LIB_DIR}/patch-map.sh ${ARCH} context" 'DC-4 hint mentions extract-map'

# DC-5: wrong hash → exit 6
assert_exit 6 \
  "echo foo | ${LIB_DIR}/patch-map.sh ${ARCH} context --if-hash=deadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeefdeadbeef" 'DC-5 wrong-hash exit 6'

# DC-6: bad tag → exit 2
if type sha256_of >/dev/null 2>&1; then
  H="$(sha256_of "${ARCH}")"
else
  H="nohash"
fi
assert_exit 2 \
  "echo foo | ${LIB_DIR}/patch-map.sh ${ARCH} bogus-tag --if-hash=$H" 'DC-6 bad-tag exit 2'

# DC-7: no mermaid → exit 9 (patching containers with plain text)
if type sha256_of >/dev/null 2>&1; then
  H="$(sha256_of "${ARCH}")"
else
  H="nohash"
fi
assert_exit 9 \
  "echo 'plain text no diagram' | ${LIB_DIR}/patch-map.sh ${ARCH} containers --if-hash=$H --no-commit" 'DC-7 no-mermaid exit 9'

# DC-8: atomic commit stages only map file (fixture with mktemp -d + git init)
dc8() {
  local fx; fx="$(mktemp -d)"
  (
    cd "$fx" || return 1
    git init -q
    git config user.email t@t; git config user.name t
    mkdir -p plugins/ship-flow/lib/__tests__ plugins/ship-flow/references
    cp "${REPO_ROOT}/ARCHITECTURE.md" ARCHITECTURE.md
    cp "${REPO_ROOT}/plugins/ship-flow/references/flow-map-schema.yaml" plugins/ship-flow/references/
    cp "${REPO_ROOT}/plugins/ship-flow/lib/map-helpers.sh" plugins/ship-flow/lib/
    cp "${REPO_ROOT}/plugins/ship-flow/lib/extract-map.sh" plugins/ship-flow/lib/
    cp "${REPO_ROOT}/plugins/ship-flow/lib/patch-map.sh" plugins/ship-flow/lib/
    chmod +x plugins/ship-flow/lib/*.sh
    git add -A; git commit -qm initial
    echo "unrelated dirty content" > unrelated.md
    H="$(plugins/ship-flow/lib/extract-map.sh ARCHITECTURE.md context --emit-hash-only)"
    BODY="$(plugins/ship-flow/lib/extract-map.sh ARCHITECTURE.md context | sed '1d;$d')"
    printf '%s\nDC8-MARKER\n' "$BODY" | plugins/ship-flow/lib/patch-map.sh ARCHITECTURE.md context --if-hash="$H" --commit-as="docs(architecture): dc8 test" >/dev/null 2>&1 || return 1
    local count; count="$(git show HEAD --stat | awk '/files? changed/{print $1}')"
    [ "$count" = "1" ]
  )
  local rc=$?
  rm -rf "$fx"
  return $rc
}
if dc8 2>/dev/null; then echo "OK DC-8 atomic staging"; else echo "FAIL DC-8 atomic staging"; FAIL=1; fi

# DC-9: full 6-section round-trip byte-identical
dc9() {
  local before after; before="$(mktemp)"; after="$(mktemp)"
  cp "${REPO_ROOT}/${ARCH}" "$before"
  for tag in context containers components constraints dependencies decisions; do
    local H BODY
    H="$(${LIB_DIR}/extract-map.sh ${ARCH} $tag --emit-hash-only)" || return 1
    BODY="$(${LIB_DIR}/extract-map.sh ${ARCH} $tag | sed '1d;$d')"
    printf '%s\n' "$BODY" | "${LIB_DIR}/patch-map.sh" "${ARCH}" "$tag" --if-hash="$H" --no-commit || return 1
  done
  cp "${REPO_ROOT}/${ARCH}" "$after"
  diff -q "$before" "$after" >/dev/null
  local rc=$?
  rm -f "$before" "$after"
  return $rc
}
if dc9 2>/dev/null; then echo "OK DC-9 full round-trip byte-identical"; else echo "FAIL DC-9 full round-trip byte-identical"; FAIL=1; fi

# DC-10: cross-platform sha256 (uses $(uname -s))
if type sha256_of >/dev/null 2>&1 && [ -n "$(sha256_of "${REPO_ROOT}/${ARCH}")" ]; then
  echo "OK DC-10 sha256 on $(uname -s)"
else
  echo "FAIL DC-10 sha256 (map-helpers.sh missing or sha256_of failed)"; FAIL=1
fi

# DC-11: shellcheck clean on all new .sh files
if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck -S warning \
       "${LIB_DIR}/map-helpers.sh" \
       "${LIB_DIR}/extract-map.sh" \
       "${LIB_DIR}/patch-map.sh" \
       "${SCRIPT_DIR}/test-map-layer.sh" >/dev/null 2>&1; then
    echo "OK DC-11 shellcheck clean"
  else echo "FAIL DC-11 shellcheck warnings"; FAIL=1; fi
else
  echo "SKIP DC-11 shellcheck (not installed)"
fi

# DC-12 (078): resolve_map_path with plugin slug → plugins/{slug}/{map}
if type resolve_map_path >/dev/null 2>&1; then
  result_12="$(resolve_map_path "ship-flow" "ARCHITECTURE.md")"
  if [ "$result_12" = "plugins/ship-flow/ARCHITECTURE.md" ]; then
    echo "OK DC-12 resolve_map_path plugin-scoped"
  else
    echo "FAIL DC-12 resolve_map_path plugin-scoped (got: $result_12)"; FAIL=1
  fi
else
  echo "FAIL DC-12 resolve_map_path not defined in map-helpers.sh"; FAIL=1
fi

# DC-13 (078): resolve_map_path with empty slug → repo-root fallback
if type resolve_map_path >/dev/null 2>&1; then
  result_13="$(resolve_map_path "" "ARCHITECTURE.md")"
  if [ "$result_13" = "ARCHITECTURE.md" ]; then
    echo "OK DC-13 resolve_map_path repo-root fallback"
  else
    echo "FAIL DC-13 resolve_map_path repo-root fallback (got: $result_13)"; FAIL=1
  fi
else
  echo "FAIL DC-13 resolve_map_path not defined in map-helpers.sh"; FAIL=1
fi

# DC-14: --mode=append adds row to ROADMAP shipped section
echo
echo "--- DC-14: --mode=append ROADMAP.shipped ---"
TMPDIR_DC14="$(mktemp -d)"
cp ROADMAP.md "$TMPDIR_DC14/ROADMAP.md"
pushd "$TMPDIR_DC14" >/dev/null || exit
ORIG_HASH_14="$(sha256sum ROADMAP.md 2>/dev/null | awk '{print $1}' || shasum -a 256 ROADMAP.md | awk '{print $1}')"
assert_exit 0 \
  "echo '| 999 | test-dc14 | Why shipped | 2026-04-22 | PR |' | bash '${LIB_DIR}/patch-map.sh' --if-hash='$ORIG_HASH_14' --mode=append --section=shipped --no-commit ROADMAP.md" \
  "DC-14a --mode=append with valid hash"
assert_stdout_matches "test-dc14" \
  "bash '${LIB_DIR}/extract-map.sh' ROADMAP.md shipped" \
  "DC-14b appended row visible in shipped section"
# Stale hash should fail
assert_exit 6 \
  "echo '| 998 | stale-test | x | 2026-04-22 | PR |' | bash '${LIB_DIR}/patch-map.sh' --if-hash='$ORIG_HASH_14' --mode=append --section=shipped --no-commit ROADMAP.md" \
  "DC-14c stale hash rejected"
popd >/dev/null || exit
rm -rf "$TMPDIR_DC14"

# DC-15: --mode=remove-row filters rows matching --match substring
echo
echo "--- DC-15: --mode=remove-row ROADMAP.now ---"
TMPDIR_DC15="$(mktemp -d)"
cp ROADMAP.md "$TMPDIR_DC15/ROADMAP.md"
pushd "$TMPDIR_DC15" >/dev/null || exit
# Inject a known row into now section via a raw write (bypass patch-map for fixture setup)
awk '/<!-- section:now -->/{print; print ""; print "| 888 | dc15-removable | test | 2026-04-22 |"; next}1' ROADMAP.md > ROADMAP.md.tmp && mv ROADMAP.md.tmp ROADMAP.md
HASH_15="$(sha256sum ROADMAP.md 2>/dev/null | awk '{print $1}' || shasum -a 256 ROADMAP.md | awk '{print $1}')"
assert_exit 0 \
  "bash '${LIB_DIR}/patch-map.sh' --if-hash='$HASH_15' --mode=remove-row --match=dc15-removable --section=now --no-commit ROADMAP.md </dev/null" \
  "DC-15a remove-row by substring match"
# Row gone from section
if bash "${LIB_DIR}/extract-map.sh" ROADMAP.md now | grep -q 'dc15-removable'; then
  echo "FAIL DC-15b row still present after remove-row"; FAIL=1
else
  echo "OK DC-15b row removed"
fi
# remove-row without --match → exit 11
assert_exit 11 \
  "bash '${LIB_DIR}/patch-map.sh' --if-hash='$HASH_15' --mode=remove-row --section=now --no-commit ROADMAP.md </dev/null" \
  "DC-15c --mode=remove-row without --match fails"
popd >/dev/null || exit
rm -rf "$TMPDIR_DC15"

# DC-16: --mode=append works on PRODUCT.capabilities (different file, same primitive)
echo
echo "--- DC-16: --mode=append PRODUCT.capabilities ---"
TMPDIR_DC16="$(mktemp -d)"
cp PRODUCT.md "$TMPDIR_DC16/PRODUCT.md"
pushd "$TMPDIR_DC16" >/dev/null || exit
HASH_16="$(sha256sum PRODUCT.md 2>/dev/null | awk '{print $1}' || shasum -a 256 PRODUCT.md | awk '{print $1}')"
assert_exit 0 \
  "echo '- DC-16 capability — proves append works (#999)' | bash '${LIB_DIR}/patch-map.sh' --if-hash='$HASH_16' --mode=append --section=capabilities --no-commit PRODUCT.md" \
  "DC-16a --mode=append PRODUCT.capabilities"
assert_stdout_matches "DC-16 capability" \
  "bash '${LIB_DIR}/extract-map.sh' PRODUCT.md capabilities" \
  "DC-16b appended bullet visible"
popd >/dev/null || exit
rm -rf "$TMPDIR_DC16"

exit $FAIL
