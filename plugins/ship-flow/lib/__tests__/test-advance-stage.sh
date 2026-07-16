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

run_advance() {
  local script="$1" entity="" stage="" arg repo before gitdir token worker=test-worker
  shift
  for arg in "$@"; do
    case "$arg" in --entity=*) entity="${arg#--entity=}" ;; --stage-name=*) stage="${arg#--stage-name=}" ;; esac
  done
  repo="$(git rev-parse --show-toplevel 2>/dev/null)" || { command bash "$script" "$@"; return; }
  before="$(git -C "$repo" rev-parse HEAD)"; gitdir="$(git -C "$repo" rev-parse --absolute-git-dir)"; token="test-${before}"
  if [ ! -e "$gitdir/completion-v1.lease" ]; then
    (cd "$repo" && command bash "$LIB_DIR/fo-completion-lease.sh" acquire --entity="$entity" --stage="$stage" \
      --worker="$worker" --token="$token" --ref="$(git symbolic-ref -q HEAD)" --before="$before") >/dev/null || return
  fi
  command bash "$script" "$@" --lease-file="$gitdir/completion-v1.lease/record" --lease-token="$token" --worker-id="$worker"
}

cd "$REPO_ROOT" || exit 1

setup_fixture() {
  local status="${1:-plan}"
  local dir entity_dir
  dir="$(mktemp -d)"
  entity_dir="$dir/docs/test-wf/item"
  mkdir -p "$entity_dir"
  cat > "$dir/docs/test-wf/README.md" <<'EOF'
---
stages:
  states:
    - name: shape
    - name: design
    - name: plan
    - name: execute
    - name: verify
    - name: ship
---
EOF
  cat > "$entity_dir/index.md" <<EOF
---
id: "test-wiring"
title: "Test entity"
status: ${status}
stage_outputs:
  shape: shape.md
---

<!-- section:stage-artifact-links -->
| Stage | File |
|-------|------|
| shape | [shape.md](shape.md) |
<!-- /section:stage-artifact-links -->
EOF
  # Create a dummy plan.md artifact
  echo "# Shape" > "$entity_dir/shape.md"
  echo "# Plan" > "$entity_dir/plan.md"
  (cd "$dir" && git init -q -b main && git add -- docs && \
    git -c user.email=test@test -c user.name=test commit -qm "init")
  echo "$entity_dir"
}

setup_registered_fixture() {
  local status="${1:-plan}"
  local stage_file="${2:-plan.md}"
  local entity_dir
  entity_dir="$(setup_fixture "$status")"
  sed -i.bak -e "s/  shape: shape.md/  plan: ${stage_file}/" \
    -e "s#| shape | \[shape.md\](shape.md) |#| plan | [${stage_file}](${stage_file}) |#" "$entity_dir/index.md"
  rm -f "$entity_dir/index.md.bak"
  echo "# Old Plan" > "$entity_dir/old-plan.md"
  (cd "$entity_dir/../../.." && git add -- docs && git commit --amend -qm "init")
  echo "$entity_dir"
}

setup_body_drift_fixture() {
  local entity_dir
  entity_dir="$(setup_registered_fixture)"
  sed -i.bak 's#| plan | \[plan.md\](plan.md) |#| plan | [old-plan.md](old-plan.md) |#' "$entity_dir/index.md"
  rm -f "$entity_dir/index.md.bak"
  (cd "$entity_dir/../../.." && git add -- docs && git commit --amend -qm "init")
  echo "$entity_dir"
}

setup_render_failure_fixture() {
  local entity_dir
  entity_dir="$(setup_fixture)"
  perl -0pi -e 's/(  shape: shape.md\n)(---)/$1priority: invalid-tail\n$2/' "$entity_dir/index.md"
  (cd "$entity_dir/../../.." && git add -- docs && git commit --amend -qm "init")
  echo "$entity_dir"
}

echo "--- Case 1: success path — writes frontmatter authority and preserves opaque body ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-1a exit 0"
COMMITS_AFTER="$(git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-1b exactly one commit created"
else echo "FAIL Case-1b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
if grep -q '^status: plan$' index.md; then echo "OK Case-1c status advanced to plan"
else echo "FAIL Case-1c status not advanced"; FAIL=1; fi
if git show HEAD:docs/test-wf/item/index.md | grep -qE '^\s+plan:[[:space:]]*plan\.md'; then echo "OK Case-1d published stage_outputs.plan written"
else echo "FAIL Case-1d stage_outputs.plan missing"; FAIL=1; fi
if git show HEAD:docs/test-wf/item/index.md | grep -q "| shape | \[shape.md\](shape.md) |" && \
   ! git show HEAD:docs/test-wf/item/index.md | grep -q "| plan |"; then echo "OK Case-1e historical body table preserved"
else echo "FAIL Case-1e historical body table changed"; FAIL=1; fi
if [ -z "$(git ls-files --others --exclude-standard)" ]; then echo "OK Case-1f no unrelated untracked residue"
else echo "FAIL Case-1f unexpected worktree residue"; FAIL=1; fi
COMMIT_FILES="$(git show --name-only --format= HEAD)"
if [ "$COMMIT_FILES" = "docs/test-wf/item/index.md" ]; then echo "OK Case-1g commit pathspec contains only canonical entity"
else echo "FAIL Case-1g unexpected commit files: $COMMIT_FILES"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 2: stale hash returns exit 6 ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
assert_exit 6 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$WRONG_HASH' --commit-as='plan(test): advance status to plan'" \
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
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-3a malformed authority exits 5 before lease/CAS"
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
BEFORE="$(git rev-parse HEAD)"
BEFORE_TREE="$(git rev-parse 'HEAD^{tree}')"
# First advance
run_advance "${LIB_DIR}/advance-stage.sh" --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" >/dev/null 2>&1
COMPLETION="$(git rev-parse refs/heads/main)"
TOKEN="test-${BEFORE}"; WORKER=test-worker
bash "${LIB_DIR}/fo-completion-lease.sh" reclaim --entity=docs/test-wf/item/index.md --stage=plan --worker="$WORKER" \
  --token="$TOKEN" --ref=refs/heads/main --before="$BEFORE" >/dev/null
LEASE="$(git rev-parse --absolute-git-dir)/completion-v1.lease/returned"
bash "${LIB_DIR}/fo-reconcile-completion.sh" --disposition=published --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md \
  --ref=refs/heads/main --before="$BEFORE" --completion="$COMPLETION" --before-tree="$BEFORE_TREE" --lease-file="$LEASE" --lease-token="$TOKEN" --worker-id="$WORKER" >/dev/null
H2="$(sha256_of index.md)"
# Second advance with same args — should be no-op (exit 0, no new diff)
BEFORE_COMMITS="$(git rev-list --count HEAD)"
assert_exit 0 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H2' --commit-as='plan(test): advance status to plan'" \
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
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-5a partial idempotency exits 0"
COMMITS_AFTER="$(git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-5b partial idempotency creates one commit"
else echo "FAIL Case-5b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
if git show HEAD:docs/test-wf/item/index.md | grep -qE '^\s+plan:[[:space:]]*plan\.md'; then echo "OK Case-5c stage_outputs.plan written"
else echo "FAIL Case-5c stage_outputs.plan missing"; FAIL=1; fi
if git show HEAD:docs/test-wf/item/index.md | grep -q "| shape | \[shape.md\](shape.md) |" && \
   ! git show HEAD:docs/test-wf/item/index.md | grep -q "| plan |"; then echo "OK Case-5d historical body table preserved"
else echo "FAIL Case-5d historical body table changed"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 6: absolute entity path is outside the canonical input grammar ---"
TMP="$(setup_fixture)"
OUTSIDE="$(mktemp -d)"
pushd "$OUTSIDE" >/dev/null || exit 1
H="$(sha256_of "$TMP/index.md")"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
assert_exit 1 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity='$TMP/index.md' --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-6a absolute entity is rejected"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "0" ]; then echo "OK Case-6b absolute entity creates no commit"
else echo "FAIL Case-6b unexpected commit delta $COMMIT_DELTA"; FAIL=1; fi
PORCELAIN="$(cd "$TMP" && git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-6c absolute entity not left dirty"
else echo "FAIL Case-6c absolute entity left dirty: $PORCELAIN"; FAIL=1; fi
if [ "$(cd "$TMP" && git rev-parse HEAD)" = "$(cd "$TMP" && git rev-parse refs/heads/main)" ]; then echo "OK Case-6d branch ref unchanged"
else echo "FAIL Case-6d branch ref changed"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP" "$OUTSIDE"

echo
echo "--- Case 7: full idempotency still honors stale hash ---"
TMP="$(setup_registered_fixture plan plan.md)"
pushd "$TMP" >/dev/null || exit 1
WRONG_HASH="0000000000000000000000000000000000000000000000000000000000000000"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 6 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$WRONG_HASH' --commit-as='plan(test): advance status to plan'" \
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
echo "--- Case 8: matching status with wrong stage file is stale and rejected ---"
TMP="$(setup_registered_fixture plan old-plan.md)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-8a wrong stage file exits 10"
COMMITS_AFTER="$(git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "0" ]; then echo "OK Case-8b wrong stage file creates no commit"
else echo "FAIL Case-8b unexpected commit delta $COMMIT_DELTA"; FAIL=1; fi
if grep -qE '^\s+plan:[[:space:]]*old-plan\.md' index.md; then echo "OK Case-8c stale map preserved"
else echo "FAIL Case-8c stale map changed"; FAIL=1; fi
if grep -q "| plan | \[old-plan.md\](old-plan.md) |" index.md; then echo "OK Case-8d stale table preserved"
else echo "FAIL Case-8d stale table changed"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 9: historical body-table drift is ignored and preserved ---"
TMP="$(setup_body_drift_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-9a historical body table does not affect authority"
COMMITS_AFTER="$(git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "0" ]; then echo "OK Case-9b stale body table creates no commit"
else echo "FAIL Case-9b unexpected commit delta $COMMIT_DELTA"; FAIL=1; fi
if grep -q "| plan | \[old-plan.md\](old-plan.md) |" index.md; then echo "OK Case-9c historical body table preserved"
else echo "FAIL Case-9c historical body table changed"; FAIL=1; fi
if grep -qE '^\s+plan:[[:space:]]*plan\.md' index.md; then echo "OK Case-9d stage_outputs.plan preserved"
else echo "FAIL Case-9d stage_outputs.plan missing"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 10: not-a-git-repo fails closed ---"
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
WARNING_OUT="$(run_advance "${LIB_DIR}/advance-stage.sh" --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "1" ]; then echo "OK Case-10a missing lease fails before non-Git work"
else echo "FAIL Case-10a unexpected exit $GOT_RC"; FAIL=1; fi
if echo "$WARNING_OUT" | grep -qi "usage"; then echo "OK Case-10b typed usage error emitted"
else echo "FAIL Case-10b no typed error in output"; FAIL=1; fi
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
WARNING_OUT="$(run_advance "${LIB_DIR}/advance-stage.sh" --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "1" ]; then echo "OK Case-10c-a missing lease fails before non-Git work"
else echo "FAIL Case-10c-a unexpected exit $GOT_RC"; FAIL=1; fi
if echo "$WARNING_OUT" | grep -qi "usage"; then echo "OK Case-10c-b typed usage error emitted"
else echo "FAIL Case-10c-b no typed error in output"; FAIL=1; fi
if [ -x index.md ]; then echo "OK Case-10c-c executable mode preserved"
else echo "FAIL Case-10c-c executable mode lost"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP_NONGIT"

echo
echo "--- Case 11: commit-as is audit text, never stage-entry authority ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): generic advance'" \
  "Case-11a generic audit message may register current-stage completion"
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-11b entity content unchanged"
else echo "FAIL Case-11b entity content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ $((COMMITS_AFTER - COMMITS_BEFORE)) = 1 ]; then echo "OK Case-11c one completion commit published"
else echo "FAIL Case-11c expected one completion commit"; FAIL=1; fi
if git show HEAD:docs/test-wf/item/index.md | grep -q '^status: plan$'; then echo "OK Case-11d published status remains current"
else echo "FAIL Case-11d completion changed status"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 12: competing ref update wins and receives no receipt ---"
TMP="$(setup_fixture)"
GIT_WRAPPER_DIR="$(mktemp -d)"
REAL_GIT="$(command -v git)"
COMPETING_OID="$(cd "$TMP" && printf 'competitor\n' | git commit-tree 'HEAD^{tree}' -p HEAD)"
cat > "$GIT_WRAPPER_DIR/git" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "update-ref" ]; then
  "$REAL_GIT" update-ref "\$2" "$COMPETING_OID" "\$4"
  exit 99
fi
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$GIT_WRAPPER_DIR/git"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
ADD_FAIL_OUT="$(PATH="$GIT_WRAPPER_DIR:$PATH" run_advance "${LIB_DIR}/advance-stage.sh" --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "9" ]; then echo "OK Case-12a competing CAS exits 9"
else echo "FAIL Case-12a expected exit 9, got $GOT_RC"; FAIL=1; fi
if ! echo "$ADD_FAIL_OUT" | grep -q '^completion-v1 disposition='; then echo "OK Case-12b competing CAS emits no receipt"
else echo "FAIL Case-12b competing CAS emitted receipt: $ADD_FAIL_OUT"; FAIL=1; fi
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-12c entity content unchanged"
else echo "FAIL Case-12c entity content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$(git rev-parse refs/heads/main)" = "$COMPETING_OID" ]; then echo "OK Case-12d competing ref preserved"
else echo "FAIL Case-12d competing ref changed"; FAIL=1; fi
PORCELAIN="$(git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-12e entity not left dirty"
else echo "FAIL Case-12e entity left dirty: $PORCELAIN"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 13: update-ref nonzero with ours still yields verified receipt ---"
TMP="$(setup_fixture)"
GIT_WRAPPER_DIR="$(mktemp -d)"
REAL_GIT="$(command -v git)"
cat > "$GIT_WRAPPER_DIR/git" <<EOF
#!/usr/bin/env bash
if [ "\${1:-}" = "update-ref" ]; then
  "$REAL_GIT" "\$@"
  exit 98
fi
exec "$REAL_GIT" "\$@"
EOF
chmod +x "$GIT_WRAPPER_DIR/git"
pushd "$TMP" >/dev/null || exit 1
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
COMMIT_FAIL_OUT="$(PATH="$GIT_WRAPPER_DIR:$PATH" run_advance "${LIB_DIR}/advance-stage.sh" --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "0" ]; then echo "OK Case-13a verified published disposition exits 0"
else echo "FAIL Case-13a expected exit 0, got $GOT_RC"; FAIL=1; fi
if echo "$COMMIT_FAIL_OUT" | grep -q '^completion-v1 disposition=published '; then echo "OK Case-13b exactly typed receipt emitted"
else echo "FAIL Case-13b missing receipt: $COMMIT_FAIL_OUT"; FAIL=1; fi
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-13c entity content unchanged"
else echo "FAIL Case-13c entity content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ $((COMMITS_AFTER - COMMITS_BEFORE)) = 1 ]; then echo "OK Case-13d one completion commit published"
else echo "FAIL Case-13d expected one completion commit"; FAIL=1; fi
PORCELAIN="$(git status --porcelain -- index.md)"
if [ -n "$PORCELAIN" ]; then echo "OK Case-13e live entity intentionally remains at parent"
else echo "FAIL Case-13e expected parent-lag state"; FAIL=1; fi
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
ADD_FAIL_OUT="$(PATH="$GIT_WRAPPER_DIR:$PATH" run_advance "${LIB_DIR}/advance-stage.sh" --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "5" ]; then echo "OK Case-14a pre-staged entity exits 5 before publication"
else echo "FAIL Case-14a expected exit 5, got $GOT_RC"; FAIL=1; fi
if echo "$ADD_FAIL_OUT" | grep -qi "globally clean"; then echo "OK Case-14b eligibility error is readable"
else echo "FAIL Case-14b missing eligibility error: $ADD_FAIL_OUT"; FAIL=1; fi
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
COMMIT_FAIL_OUT="$(PATH="$GIT_WRAPPER_DIR:$PATH" run_advance "${LIB_DIR}/advance-stage.sh" --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash="$H" --commit-as="plan(test): advance status to plan" 2>&1)"
GOT_RC=$?
if [ "$GOT_RC" = "5" ]; then echo "OK Case-15a pre-staged entity exits 5 before publication"
else echo "FAIL Case-15a expected exit 5, got $GOT_RC"; FAIL=1; fi
if echo "$COMMIT_FAIL_OUT" | grep -qi "globally clean"; then echo "OK Case-15b eligibility error is readable"
else echo "FAIL Case-15b missing eligibility error: $COMMIT_FAIL_OUT"; FAIL=1; fi
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
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-16a staged no-op candidate fails closed"
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
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-17a unstaged no-op candidate fails closed"
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
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-18a staged table drift fails closed"
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
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-19a unstaged mode drift fails closed"
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
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-20a staged mode drift fails closed"
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
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='$H' --commit-as='plan(test): advance status to plan'" \
  "Case-21a unstaged table drift fails closed"
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
echo "--- Case 22: missing canonical entity fails closed ---"
TMP="$(setup_fixture)"
pushd "$TMP" >/dev/null || exit 1
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/missing/index.md --new-status=plan --stage-name=plan --stage-file=plan.md --if-hash='abc123' --commit-as='x'" \
  "Case-22 missing canonical entity exits 5"
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 23: design is a documented, idempotent completion target ---"
if grep -Fq -- 'design/design/design.md' "${LIB_DIR}/completion-v1.sh" && \
   grep -Fq -- 'ship/review/review.md' "${LIB_DIR}/completion-v1.sh"; then
  echo "OK Case-23a shared contract documents exhaustive design/review triples"
else
  echo "FAIL Case-23a helper usage does not document design"; FAIL=1
fi
TMP="$(setup_fixture design)"
pushd "$TMP" >/dev/null || exit 1
echo "# Design" > design.md
git add -- design.md
git commit -qm "fixture: add design artifact"
H="$(sha256_of index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 0 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=design --stage-name=design --stage-file=design.md --if-hash='$H' --commit-as='design(test): register completion'" \
  "Case-23b design completion exits 0"
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ $(( COMMITS_AFTER - COMMITS_BEFORE )) = "1" ]; then echo "OK Case-23c design completion creates one artifact commit"
else echo "FAIL Case-23c design completion expected one artifact commit"; FAIL=1; fi
if git show HEAD:docs/test-wf/item/index.md | grep -q '^status: design$' && \
   git show HEAD:docs/test-wf/item/index.md | grep -qE '^\s+design:[[:space:]]*design\.md' && \
   ! git show HEAD:docs/test-wf/item/index.md | grep -Fq '| design | [design.md](design.md) |'; then
  echo "OK Case-23d design completion is status-idempotent and records design.md"
else
  echo "FAIL Case-23d design completion wiring is incomplete"; FAIL=1
fi
popd >/dev/null || exit 1
rm -rf "$TMP"

echo
echo "--- Case 24: design completion keeps exit-10 rollback safe on flat/legacy layout ---"
TMP="$(setup_render_failure_fixture)"
pushd "$TMP" >/dev/null || exit 1
echo "# Design" > design.md
git add -- design.md
git commit -qm "fixture: add design artifact"
H="$(sha256_of index.md)"
BEFORE_CONTENT="$(cat index.md)"
COMMITS_BEFORE="$(git rev-list --count HEAD)"
assert_exit 5 \
  "run_advance '${LIB_DIR}/advance-stage.sh' --entity=docs/test-wf/item/index.md --new-status=design --stage-name=design --stage-file=design.md --if-hash='$H' --commit-as='design(test): advance status to design'" \
  "Case-24a malformed design authority exits 5"
AFTER_CONTENT="$(cat index.md)"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-24b legacy entity content rolled back"
else echo "FAIL Case-24b legacy entity content changed"; FAIL=1; fi
COMMITS_AFTER="$(git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-24c no completion commit created"
else echo "FAIL Case-24c unexpected completion commit created"; FAIL=1; fi
PORCELAIN="$(git status --porcelain -- index.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-24d legacy entity not left dirty"
else echo "FAIL Case-24d legacy entity left dirty: $PORCELAIN"; FAIL=1; fi
popd >/dev/null || exit 1
rm -rf "$TMP"

exit $FAIL
