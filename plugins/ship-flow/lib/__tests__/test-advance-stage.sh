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
  local status="${1:-sharp}"
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/index.md" <<EOF
---
id: "test-wiring"
title: "Test entity"
status: ${status}
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
  # Create a dummy plan.md artifact
  echo "# Plan" > "$dir/plan.md"
  (cd "$dir" && git init -q && git add -- index.md plan.md && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

setup_registered_fixture() {
  local status="${1:-plan}"
  local stage_file="${2:-plan.md}"
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/index.md" <<EOF
---
id: "test-wiring"
title: "Test entity"
status: ${status}
stage_outputs:
  plan: ${stage_file}
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| plan | [${stage_file}](${stage_file}) |
<!-- /section:stage-artifact-links -->
EOF
  echo "# Plan" > "$dir/plan.md"
  echo "# Old Plan" > "$dir/old-plan.md"
  (cd "$dir" && git init -q && git add -- index.md plan.md old-plan.md && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

setup_body_drift_fixture() {
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/index.md" <<'EOF'
---
id: "test-wiring"
title: "Test entity"
status: plan
stage_outputs:
  plan: plan.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| plan | [old-plan.md](old-plan.md) |
<!-- /section:stage-artifact-links -->
EOF
  echo "# Plan" > "$dir/plan.md"
  echo "# Old Plan" > "$dir/old-plan.md"
  (cd "$dir" && git init -q && git add -- index.md plan.md old-plan.md && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

setup_render_failure_fixture() {
  local dir
  dir="$(mktemp -d)"
  cat > "$dir/index.md" <<'EOF'
---
id: "test-wiring"
title: "Test entity"
status: sharp
---

No stage artifact links section exists here.
EOF
  echo "# Plan" > "$dir/plan.md"
  (cd "$dir" && git init -q && git add -- index.md plan.md && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$dir"
}

echo "--- Case 1: success path — advances status + writes stage_outputs + re-renders body ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
printf 'do not stage me\n' > unrelated.md
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-1a exit 0"
COMMITS_AFTER="$(git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-1b exactly one commit created"
else echo "FAIL Case-1b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
if grep -q '^status: plan$' index.md; then echo "OK Case-1c status advanced to plan"
else echo "FAIL Case-1c status not advanced"; FAIL=1; fi
if grep -qE '^\s+plan:[[:space:]]*plan\.md' index.md; then echo "OK Case-1d stage_outputs.plan written"
else echo "FAIL Case-1d stage_outputs.plan missing"; FAIL=1; fi
if grep -q "| plan | \[plan.md\](plan.md) |" index.md; then echo "OK Case-1e body table updated"
else echo "FAIL Case-1e body table not updated"; FAIL=1; fi
if [ "$(git status --porcelain -- unrelated.md)" = "?? unrelated.md" ]; then echo "OK Case-1f unrelated file remains unstaged"
else echo "FAIL Case-1f unrelated file was staged or committed"; FAIL=1; fi
COMMIT_FILES="$(git show --name-only --format= HEAD)"
if [ "$COMMIT_FILES" = "index.md" ]; then echo "OK Case-1g commit pathspec contains only index.md"
else echo "FAIL Case-1g unexpected commit files: $COMMIT_FILES"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 2: stale hash returns exit 6 ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
assert_exit 6 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$WRONG_HASH' --commit-as='plan(test): advance status to plan'" \
  "Case-2 stale hash returns exit 6"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 3: downstream helper failure leaves entity unchanged and uncommitted ---"
TMP="$(setup_render_failure_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 10 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-3a render failure exits 10"
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-3b entity content unchanged"
else echo "FAIL Case-3b entity content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-3c no commit created"
else echo "FAIL Case-3c unexpected commit created"; FAIL=1; fi
PORCELAIN="$(git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-3d entity not left dirty"
else echo "FAIL Case-3d entity left dirty: $PORCELAIN"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 4: idempotent on already-advanced entity (no diff) ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
# First advance
bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" >/dev/null 2>&1
H2="$(sha256_of index.md)"
# Second advance with same args — should be no-op (exit 0, no new diff)
BEFORE_COMMITS="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H2' --commit-as='plan(test): advance status to plan'" \
  "Case-4a second advance exits 0"
AFTER_COMMITS="$(git rev-list --count HEAD)"
if [ "$BEFORE_COMMITS" = "$AFTER_COMMITS" ]; then echo "OK Case-4b no new commit (idempotent)"
else echo "FAIL Case-4b unexpected new commit"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 5: partial idempotency still registers artifact in one commit ---"
TMP="$(setup_fixture plan)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-5a partial idempotency exits 0"
COMMITS_AFTER="$(git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-5b partial idempotency creates one commit"
else echo "FAIL Case-5b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
if grep -qE '^\s+plan:[[:space:]]*plan\.md' index.md; then echo "OK Case-5c stage_outputs.plan written"
else echo "FAIL Case-5c stage_outputs.plan missing"; FAIL=1; fi
if grep -q "| plan | \[plan.md\](plan.md) |" index.md; then echo "OK Case-5d body table updated"
else echo "FAIL Case-5d body table not updated"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 6: absolute entity path from outside repo commits in entity repo ---"
TMP="$(setup_fixture)"
OUTSIDE="$(mktemp -d)"
pushd "$OUTSIDE" >/dev/null || exit 1
H="$(sha256_of "$TMP/index.md")"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity='$TMP/index.md' --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-6a absolute entity exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-6b absolute entity creates one commit"
else echo "FAIL Case-6b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
PORCELAIN="$(cd "$TMP" && git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-6c absolute entity not left dirty"
else echo "FAIL Case-6c absolute entity left dirty: $PORCELAIN"; FAIL=1; fi
COMMIT_FILES="$(cd "$TMP" && git show --name-only --format= HEAD)"
if [ "$COMMIT_FILES" = "index.md" ]; then echo "OK Case-6d absolute entity commit pathspec contains only index.md"
else echo "FAIL Case-6d unexpected commit files: $COMMIT_FILES"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP" "$OUTSIDE"

echo
echo "--- Case 7: full idempotency still honors stale hash ---"
TMP="$(setup_registered_fixture plan plan.md)"
pushd "$TMP" >/dev/null || exit 1
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 6 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$WRONG_HASH' --commit-as='plan(test): advance status to plan'" \
  "Case-7a stale full-idempotency exits 6"
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-7b stale full-idempotency creates no commit"
else echo "FAIL Case-7b unexpected commit created"; FAIL=1; fi
PORCELAIN="$(git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-7c stale full-idempotency leaves entity clean"
else echo "FAIL Case-7c stale full-idempotency left dirty: $PORCELAIN"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 8: matching status with wrong stage file is corrected in one commit ---"
TMP="$(setup_registered_fixture plan old-plan.md)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-8a wrong stage file exits 0"
COMMITS_AFTER="$(git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-8b wrong stage file creates one commit"
else echo "FAIL Case-8b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
if grep -qE '^\s+plan:[[:space:]]*plan\.md' index.md && ! grep -qE '^\s+plan:[[:space:]]*old-plan\.md' index.md; then echo "OK Case-8c stage_outputs.plan corrected"
else echo "FAIL Case-8c stage_outputs.plan not corrected"; FAIL=1; fi
if grep -q "| plan | \[plan.md\](plan.md) |" index.md && ! grep -q "old-plan.md" index.md; then echo "OK Case-8d body table corrected"
else echo "FAIL Case-8d body table not corrected"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 9: matching status and stage file with stale body table is corrected in one commit ---"
TMP="$(setup_body_drift_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-9a stale body table exits 0"
COMMITS_AFTER="$(git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-9b stale body table creates one commit"
else echo "FAIL Case-9b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
if grep -q "| plan | \[plan.md\](plan.md) |" index.md && ! grep -q "old-plan.md" index.md; then echo "OK Case-9c body table corrected"
else echo "FAIL Case-9c body table not corrected"; FAIL=1; fi
if grep -qE '^\s+plan:[[:space:]]*plan\.md' index.md; then echo "OK Case-9d stage_outputs.plan preserved"
else echo "FAIL Case-9d stage_outputs.plan missing"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 10: not-a-git-repo emits warning + exits 0 ---"
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
WARNING_OUT="$(bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "0" ]; then echo "OK Case-10a exits 0 outside git repo"
else echo "FAIL Case-10a unexpected exit $GOT_RC"; FAIL=1; fi
if echo "$WARNING_OUT" | grep -qi "warn\|skip"; then echo "OK Case-10b warning emitted"
else echo "FAIL Case-10b no warning in output"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP_NONGIT"

echo
echo "--- Case 10c: non-git idempotent advance preserves mode metadata ---"
TMP_NONGIT="$(mktemp -d)"
cat > "$TMP_NONGIT/index.md" <<'EOF'
---
id: "test"
title: "Test"
status: plan
stage_outputs:
  plan: plan.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| plan | [plan.md](plan.md) |
<!-- /section:stage-artifact-links -->
EOF
echo "# Plan" > "$TMP_NONGIT/plan.md"
chmod +x "$TMP_NONGIT/index.md"
pushd "$TMP_NONGIT" >/dev/null || exit 1
H="$(sha256_of index.md)"
WARNING_OUT="$(bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "0" ]; then echo "OK Case-10c-a exits 0 outside git repo"
else echo "FAIL Case-10c-a unexpected exit $GOT_RC"; FAIL=1; fi
if echo "$WARNING_OUT" | grep -qi "warn\|skip"; then echo "OK Case-10c-b warning emitted"
else echo "FAIL Case-10c-b no warning in output"; FAIL=1; fi
if [ -x index.md ]; then echo "OK Case-10c-c executable mode preserved"
else echo "FAIL Case-10c-c executable mode lost"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP_NONGIT"

echo
echo "--- Case 11: status mutation with C14-invalid commit message is refused before mutation ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 1 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): generic advance'" \
  "Case-11a invalid commit message exits 1"
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-11b entity content unchanged"
else echo "FAIL Case-11b entity content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-11c no commit created"
else echo "FAIL Case-11c unexpected commit created"; FAIL=1; fi
PORCELAIN="$(git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-11d entity not left dirty"
else echo "FAIL Case-11d entity left dirty: $PORCELAIN"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 12: git add failure restores entity and returns nonzero ---"
TMP="$(setup_fixture)"
GIT_WRAPPER_DIR="$(mktemp -d)"
REAL_GIT="$(command -v git)"
cat > "$GIT_WRAPPER_DIR/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [ "\$arg" = "add" ]; then
    echo "simulated git add failure" >&2
    exit 99
  fi
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$GIT_WRAPPER_DIR/git"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
ADD_FAIL_OUT="$(PATH="$GIT_WRAPPER_DIR:$PATH" bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "8" ]; then echo "OK Case-12a git add failure exits 8"
else echo "FAIL Case-12a expected exit 8, got $GOT_RC"; FAIL=1; fi
if echo "$ADD_FAIL_OUT" | grep -qi "git add failed"; then echo "OK Case-12b git add failure error is readable"
else echo "FAIL Case-12b missing readable git add error: $ADD_FAIL_OUT"; FAIL=1; fi
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-12c entity content unchanged"
else echo "FAIL Case-12c entity content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-12d no commit created"
else echo "FAIL Case-12d unexpected commit created"; FAIL=1; fi
PORCELAIN="$(git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-12e entity not left dirty"
else echo "FAIL Case-12e entity left dirty: $PORCELAIN"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 13: git commit failure restores entity and clears staged entry ---"
TMP="$(setup_fixture)"
GIT_WRAPPER_DIR="$(mktemp -d)"
REAL_GIT="$(command -v git)"
cat > "$GIT_WRAPPER_DIR/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [ "\$arg" = "commit" ]; then
    echo "simulated git commit failure" >&2
    exit 98
  fi
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$GIT_WRAPPER_DIR/git"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
COMMIT_FAIL_OUT="$(PATH="$GIT_WRAPPER_DIR:$PATH" bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "8" ]; then echo "OK Case-13a git commit failure exits 8"
else echo "FAIL Case-13a expected exit 8, got $GOT_RC"; FAIL=1; fi
if echo "$COMMIT_FAIL_OUT" | grep -qi "commit failed"; then echo "OK Case-13b git commit failure error is readable"
else echo "FAIL Case-13b missing readable commit error: $COMMIT_FAIL_OUT"; FAIL=1; fi
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-13c entity content unchanged"
else echo "FAIL Case-13c entity content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-13d no commit created"
else echo "FAIL Case-13d unexpected commit created"; FAIL=1; fi
PORCELAIN="$(git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-13e entity not left dirty or staged"
else echo "FAIL Case-13e entity left dirty or staged: $PORCELAIN"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 14: git add failure preserves pre-existing staged entity diff ---"
TMP="$(setup_fixture)"
GIT_WRAPPER_DIR="$(mktemp -d)"
REAL_GIT="$(command -v git)"
cat > "$GIT_WRAPPER_DIR/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [ "\$arg" = "add" ]; then
    echo "simulated git add failure" >&2
    exit 99
  fi
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$GIT_WRAPPER_DIR/git"
pushd "$TMP" >/dev/null || exit 1
printf '\nPre-staged entity note.\n' >> index.md
git add -- index.md
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
git diff --cached --binary -- index.md > "$BEFORE_INDEX_PATCH"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
ADD_FAIL_OUT="$(PATH="$GIT_WRAPPER_DIR:$PATH" bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "8" ]; then echo "OK Case-14a git add failure exits 8"
else echo "FAIL Case-14a expected exit 8, got $GOT_RC"; FAIL=1; fi
if echo "$ADD_FAIL_OUT" | grep -qi "git add failed"; then echo "OK Case-14b git add failure error is readable"
else echo "FAIL Case-14b missing readable git add error: $ADD_FAIL_OUT"; FAIL=1; fi
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-14c entity worktree content restored"
else echo "FAIL Case-14c entity worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-14d no commit created"
else echo "FAIL Case-14d unexpected commit created"; FAIL=1; fi
git diff --cached --binary -- index.md > "$AFTER_INDEX_PATCH"
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-14e pre-existing staged diff preserved"
else echo "FAIL Case-14e pre-existing staged diff changed"; FAIL=1; fi
if git diff --quiet -- index.md; then echo "OK Case-14f no unstaged entity diff"
else echo "FAIL Case-14f entity has unstaged diff"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 15: git commit failure preserves pre-existing staged entity diff ---"
TMP="$(setup_fixture)"
GIT_WRAPPER_DIR="$(mktemp -d)"
REAL_GIT="$(command -v git)"
cat > "$GIT_WRAPPER_DIR/git" <<EOF
#!/usr/bin/env bash
for arg in "\$@"; do
  if [ "\$arg" = "commit" ]; then
    echo "simulated git commit failure" >&2
    exit 98
  fi
done
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$GIT_WRAPPER_DIR/git"
pushd "$TMP" >/dev/null || exit 1
printf '\nPre-staged entity note.\n' >> index.md
git add -- index.md
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
git diff --cached --binary -- index.md > "$BEFORE_INDEX_PATCH"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
COMMIT_FAIL_OUT="$(PATH="$GIT_WRAPPER_DIR:$PATH" bash "${LIB_DIR}/advance-stage.sh" --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "8" ]; then echo "OK Case-15a git commit failure exits 8"
else echo "FAIL Case-15a expected exit 8, got $GOT_RC"; FAIL=1; fi
if echo "$COMMIT_FAIL_OUT" | grep -qi "commit failed"; then echo "OK Case-15b git commit failure error is readable"
else echo "FAIL Case-15b missing readable commit error: $COMMIT_FAIL_OUT"; FAIL=1; fi
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-15c entity worktree content restored"
else echo "FAIL Case-15c entity worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-15d no commit created"
else echo "FAIL Case-15d unexpected commit created"; FAIL=1; fi
git diff --cached --binary -- index.md > "$AFTER_INDEX_PATCH"
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-15e pre-existing staged diff preserved"
else echo "FAIL Case-15e pre-existing staged diff changed"; FAIL=1; fi
if git diff --quiet -- index.md; then echo "OK Case-15f no unstaged entity diff"
else echo "FAIL Case-15f entity has unstaged diff"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 16: idempotent advance preserves pre-existing staged entity diff ---"
TMP="$(setup_registered_fixture plan plan.md)"
pushd "$TMP" >/dev/null || exit 1
printf '\nPre-staged entity note.\n' >> index.md
git add -- index.md
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
git diff --cached --binary -- index.md > "$BEFORE_INDEX_PATCH"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-16a idempotent advance exits 0"
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-16b entity worktree content preserved"
else echo "FAIL Case-16b entity worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-16c no commit created"
else echo "FAIL Case-16c unexpected commit created"; FAIL=1; fi
git diff --cached --binary -- index.md > "$AFTER_INDEX_PATCH"
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-16d pre-existing staged diff preserved"
else echo "FAIL Case-16d pre-existing staged diff changed"; FAIL=1; fi
if git diff --quiet -- index.md; then echo "OK Case-16e no unstaged entity diff"
else echo "FAIL Case-16e entity has unstaged diff"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 17: idempotent advance preserves pre-existing unstaged entity diff ---"
TMP="$(setup_registered_fixture plan plan.md)"
pushd "$TMP" >/dev/null || exit 1
printf '\nPre-existing unstaged entity note.\n' >> index.md
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
BEFORE_WORKTREE_PATCH="$TMP/before-worktree.patch"
AFTER_WORKTREE_PATCH="$TMP/after-worktree.patch"
git diff --binary -- index.md > "$BEFORE_WORKTREE_PATCH"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-17a idempotent advance exits 0"
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-17b entity worktree content preserved"
else echo "FAIL Case-17b entity worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-17c no commit created"
else echo "FAIL Case-17c unexpected commit created"; FAIL=1; fi
git diff --binary -- index.md > "$AFTER_WORKTREE_PATCH"
if cmp -s "$BEFORE_WORKTREE_PATCH" "$AFTER_WORKTREE_PATCH"; then echo "OK Case-17d pre-existing unstaged diff preserved"
else echo "FAIL Case-17d pre-existing unstaged diff changed"; FAIL=1; fi
if git diff --cached --quiet -- index.md; then echo "OK Case-17e no staged entity diff"
else echo "FAIL Case-17e entity has staged diff"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 18: idempotent advance restores staged table diff after render no-op ---"
TMP="$(setup_registered_fixture plan plan.md)"
pushd "$TMP" >/dev/null || exit 1
perl -0pi -e 's/\| plan \| \[plan\.md\]\(plan\.md\) \|/\| plan \| \[old-plan.md\]\(old-plan.md\) \|/' index.md
git add -- index.md
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
git diff --cached --binary -- index.md > "$BEFORE_INDEX_PATCH"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-18a idempotent advance exits 0"
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-18b entity worktree content preserved"
else echo "FAIL Case-18b entity worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-18c no commit created"
else echo "FAIL Case-18c unexpected commit created"; FAIL=1; fi
git diff --cached --binary -- index.md > "$AFTER_INDEX_PATCH"
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-18d pre-existing staged table diff preserved"
else echo "FAIL Case-18d pre-existing staged table diff changed"; FAIL=1; fi
if git diff --quiet -- index.md; then echo "OK Case-18e no unstaged entity diff"
else echo "FAIL Case-18e entity has unstaged diff"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 19: idempotent advance preserves pre-existing unstaged mode-only entity diff ---"
TMP="$(setup_registered_fixture plan plan.md)"
pushd "$TMP" >/dev/null || exit 1
chmod +x index.md
H="$(sha256_of index.md)"
BEFORE_SUMMARY="$TMP/before-summary.txt"
AFTER_SUMMARY="$TMP/after-summary.txt"
git diff --summary -- index.md > "$BEFORE_SUMMARY"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-19a idempotent advance exits 0"
if [ -x index.md ]; then echo "OK Case-19b executable mode preserved"
else echo "FAIL Case-19b executable mode lost"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-19c no commit created"
else echo "FAIL Case-19c unexpected commit created"; FAIL=1; fi
git diff --summary -- index.md > "$AFTER_SUMMARY"
if cmp -s "$BEFORE_SUMMARY" "$AFTER_SUMMARY"; then echo "OK Case-19d pre-existing unstaged mode diff preserved"
else echo "FAIL Case-19d pre-existing unstaged mode diff changed"; FAIL=1; fi
if git diff --cached --quiet -- index.md; then echo "OK Case-19e no staged entity diff"
else echo "FAIL Case-19e entity has staged diff"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 20: idempotent advance preserves pre-existing staged mode-only entity diff ---"
TMP="$(setup_registered_fixture plan plan.md)"
pushd "$TMP" >/dev/null || exit 1
chmod +x index.md
git add -- index.md
H="$(sha256_of index.md)"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
git diff --cached --binary -- index.md > "$BEFORE_INDEX_PATCH"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-20a idempotent advance exits 0"
if [ -x index.md ]; then echo "OK Case-20b executable mode preserved"
else echo "FAIL Case-20b executable mode lost"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-20c no commit created"
else echo "FAIL Case-20c unexpected commit created"; FAIL=1; fi
git diff --cached --binary -- index.md > "$AFTER_INDEX_PATCH"
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-20d pre-existing staged mode diff preserved"
else echo "FAIL Case-20d pre-existing staged mode diff changed"; FAIL=1; fi
if git diff --quiet -- index.md; then echo "OK Case-20e no unstaged entity diff"
else echo "FAIL Case-20e entity has unstaged diff"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 21: post-add no-diff restores pre-existing unstaged table diff ---"
TMP="$(setup_registered_fixture plan plan.md)"
pushd "$TMP" >/dev/null || exit 1
perl -0pi -e 's/\| plan \| \[plan\.md\]\(plan\.md\) \|/\| plan \| \[old-plan.md\]\(old-plan.md\) \|/' index.md
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
BEFORE_WORKTREE_PATCH="$TMP/before-worktree.patch"
AFTER_WORKTREE_PATCH="$TMP/after-worktree.patch"
git diff --binary -- index.md > "$BEFORE_WORKTREE_PATCH"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-21a post-add no-diff advance exits 0"
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-21b entity worktree content preserved"
else echo "FAIL Case-21b entity worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-21c no commit created"
else echo "FAIL Case-21c unexpected commit created"; FAIL=1; fi
git diff --binary -- index.md > "$AFTER_WORKTREE_PATCH"
if cmp -s "$BEFORE_WORKTREE_PATCH" "$AFTER_WORKTREE_PATCH"; then echo "OK Case-21d pre-existing unstaged table diff preserved"
else echo "FAIL Case-21d pre-existing unstaged table diff changed"; FAIL=1; fi
if git diff --cached --quiet -- index.md; then echo "OK Case-21e no staged entity diff"
else echo "FAIL Case-21e entity has staged diff"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 22: missing entity exits 3 ---"
assert_exit 3 \
  "bash '${LIB_DIR}/advance-stage.sh' --entity=/nonexistent/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='abc123' --commit-as='x'" \
  "Case-22 missing entity exits 3"

exit $FAIL
