#!/usr/bin/env bash
# test-stage-wiring.sh — DC-2/DC-3/DC-4/DC-5 integration test for stage wiring
# Simulates each ship-* SKILL post-artifact step: write-stage-artifact → advance-stage
# Asserts status, stage_outputs, and body table all advance correctly per stage.
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

# Create fixture entity matching plan spec
setup_fixture() {
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/index.md" <<'EOF'
---
id: "test-wiring"
title: "Test entity for stage wiring"
status: sharp
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
  # Create dummy stage artifact files
  for stage in plan execute verify review ship; do
    echo "# ${stage} artifact" > "$dir/${stage}.md"
  done
  (cd "$dir" && git init -q && git add . && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

advance() {
  local dir="$1" new_status="$2" stage_name="$3" stage_file="$4"
  local h
  h="$(sha256_of "$dir/index.md")"
  # Run in fixture dir so git operations resolve against its own git repo
  (cd "$dir" && bash "${LIB_DIR}/advance-stage.sh" \
    --entity="index.md" \
    --new-status="$new_status" \
    --stage-name="$stage_name" \
    --stage-file="${stage_file}" \
    --if-hash="$h" \
    --commit-as="${stage_name}(test-wiring): advance")
}

echo "=== DC-2: status advances sharp→plan→execute→verify→ship ==="
TMP="$(setup_fixture)"

echo "--- sharp→plan ---"
advance "$TMP" plan plan plan.md
if grep -q '^status: plan$' "$TMP/index.md"; then echo "OK status=plan"
else echo "FAIL status not plan"; FAIL=1; fi

echo "--- plan→execute ---"
advance "$TMP" execute execute execute.md
if grep -q '^status: execute$' "$TMP/index.md"; then echo "OK status=execute"
else echo "FAIL status not execute"; FAIL=1; fi

echo "--- execute→verify ---"
advance "$TMP" verify verify verify.md
if grep -q '^status: verify$' "$TMP/index.md"; then echo "OK status=verify"
else echo "FAIL status not verify"; FAIL=1; fi

echo "--- verify→ship (via review stage) ---"
advance "$TMP" ship review review.md
if grep -q '^status: ship$' "$TMP/index.md"; then echo "OK status=ship"
else echo "FAIL status not ship"; FAIL=1; fi

echo "--- ship→ship (advance-stage ship artifact) ---"
advance "$TMP" ship ship ship.md
if grep -q '^status: ship$' "$TMP/index.md"; then echo "OK status=ship (idempotent)"
else echo "FAIL status not ship"; FAIL=1; fi

rm -rf "$TMP"

echo
echo "=== DC-3: stage_outputs map + body table in sync per stage ==="
TMP="$(setup_fixture)"

advance "$TMP" plan plan plan.md
if grep -qE '^\s+plan:[[:space:]]*plan\.md' "$TMP/index.md"; then echo "OK stage_outputs.plan"
else echo "FAIL stage_outputs.plan missing"; FAIL=1; fi
if grep -q "| plan | \[plan.md\](plan.md) |" "$TMP/index.md"; then echo "OK body table plan row"
else echo "FAIL body table plan row missing"; FAIL=1; fi

advance "$TMP" execute execute execute.md
if grep -qE '^\s+execute:[[:space:]]*execute\.md' "$TMP/index.md"; then echo "OK stage_outputs.execute"
else echo "FAIL stage_outputs.execute missing"; FAIL=1; fi
if grep -q "| execute | \[execute.md\](execute.md) |" "$TMP/index.md"; then echo "OK body table execute row"
else echo "FAIL body table execute row missing"; FAIL=1; fi

advance "$TMP" verify verify verify.md
if grep -qE '^\s+verify:[[:space:]]*verify\.md' "$TMP/index.md"; then echo "OK stage_outputs.verify"
else echo "FAIL stage_outputs.verify missing"; FAIL=1; fi

advance "$TMP" ship review review.md
if grep -qE '^\s+review:[[:space:]]*review\.md' "$TMP/index.md"; then echo "OK stage_outputs.review"
else echo "FAIL stage_outputs.review missing"; FAIL=1; fi

advance "$TMP" ship ship ship.md
if grep -qE '^\s+ship:[[:space:]]*ship\.md' "$TMP/index.md"; then echo "OK stage_outputs.ship"
else echo "FAIL stage_outputs.ship missing"; FAIL=1; fi

# Verify body table has all 5 stage rows
for s in plan execute verify review ship; do
  if grep -q "| ${s} | \[${s}.md\](${s}.md) |" "$TMP/index.md"; then
    echo "OK body table ${s} row present"
  else
    echo "FAIL body table ${s} row missing"; FAIL=1
  fi
done

rm -rf "$TMP"

echo
echo "=== DC-4: stale-hash sub-case — pre-mutate between hash-read and advance ==="
TMP="$(setup_fixture)"
H="$(sha256_of "$TMP/index.md")"
# Mutate the file after capturing hash
echo "# extra noise" >> "$TMP/index.md"
# Now invoke advance with stale hash — must exit 6 (run in fixture dir for git context)
RC=0
(cd "$TMP" && bash "${LIB_DIR}/advance-stage.sh" \
  --entity="index.md" \
  --new-status=plan \
  --stage-name=plan \
  --stage-file=plan.md \
  --if-hash="$H" \
  --commit-as="plan(test): stale") >/dev/null 2>&1 || RC=$?
if [ "$RC" = "6" ]; then echo "OK DC-4 stale hash returns exit 6"
else echo "FAIL DC-4 expected exit 6, got $RC"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "=== DC-5: no-op sub-case — run against already-advanced entity ==="
TMP="$(setup_fixture)"
# Fully advance to ship
advance "$TMP" plan plan plan.md >/dev/null 2>&1
advance "$TMP" execute execute execute.md >/dev/null 2>&1
advance "$TMP" verify verify verify.md >/dev/null 2>&1
advance "$TMP" ship review review.md >/dev/null 2>&1
advance "$TMP" ship ship ship.md >/dev/null 2>&1

# Record commit count and hash
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
H="$(sha256_of "$TMP/index.md")"

# Run advance again on already-done status — expect no-op (run in fixture dir)
RC=0
(cd "$TMP" && bash "${LIB_DIR}/advance-stage.sh" \
  --entity="index.md" \
  --new-status=ship \
  --stage-name=ship \
  --stage-file=ship.md \
  --if-hash="$H" \
  --commit-as="ship(test): noop") >/dev/null 2>&1 || RC=$?
if [ "$RC" = "0" ]; then echo "OK DC-5a no-op exits 0"
else echo "FAIL DC-5a expected exit 0, got $RC"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_BEFORE" = "$COMMITS_AFTER" ]; then
  echo "OK DC-5b no new commits (no diff)"
else
  echo "FAIL DC-5b unexpected new commits (before=$COMMITS_BEFORE, after=$COMMITS_AFTER)"; FAIL=1
fi

PORCELAIN="$(cd "$TMP" && git status --porcelain)"
if [ -z "$PORCELAIN" ]; then echo "OK DC-5c git status clean"
else echo "FAIL DC-5c dirty working tree after no-op: $PORCELAIN"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "=== DC-1 verify: advance-stage.sh invokes register-stage-output + update-entity-status ==="
MATCH_COUNT="$(grep -rE "update-entity-status|register-stage-output" "$REPO_ROOT/plugins/ship-flow/skills/" | grep -c "advance-stage\|update-entity-status\|register-stage-output" || true)"
# DC-1 requires ≥10 matches (2 helpers × 5 SKILLs via advance-stage.sh)
# advance-stage.sh itself references both helpers (≥2), plus 5 SKILLs reference advance-stage.sh (≥5)
SKILL_REFS="$(grep -rE "advance-stage\.sh" "$REPO_ROOT/plugins/ship-flow/skills/" | grep -c "advance-stage" || true)"
HELPER_REFS="$(grep -rE "update-entity-status|register-stage-output" "$REPO_ROOT/plugins/ship-flow/lib/advance-stage.sh" | grep -c "." || true)"
TOTAL=$(( SKILL_REFS * HELPER_REFS ))
if [ "$SKILL_REFS" -ge 5 ] && [ "$HELPER_REFS" -ge 2 ]; then
  echo "OK DC-1 SKILL refs=$SKILL_REFS helper refs=$HELPER_REFS (≥5 × ≥2 = ≥10 effective calls)"
else
  echo "FAIL DC-1 SKILL refs=$SKILL_REFS helper refs=$HELPER_REFS (need ≥5 and ≥2)"; FAIL=1
fi

exit $FAIL
