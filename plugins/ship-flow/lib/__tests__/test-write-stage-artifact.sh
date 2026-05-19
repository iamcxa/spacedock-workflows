#!/usr/bin/env bash
# test-write-stage-artifact.sh — regressions for write-stage-artifact.sh
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
WRITER="${LIB_DIR}/write-stage-artifact.sh"
FAIL=0

assert_exit() {
  local expected="$1" actual="$2" name="$3"
  if [ "$actual" = "$expected" ]; then
    echo "OK $name"
  else
    echo "FAIL $name (expected exit $expected, got $actual)"
    FAIL=1
  fi
}

assert_contains() {
  local file="$1" pattern="$2" name="$3"
  if grep -q "$pattern" "$file"; then
    echo "OK $name"
  else
    echo "FAIL $name"
    FAIL=1
  fi
}

assert_exact_line_count() {
  local expected="$1" file="$2" line="$3" name="$4"
  local actual
  actual="$(grep -Fxc -- "$line" "$file" 2>/dev/null || true)"
  if [ "$actual" = "$expected" ]; then
    echo "OK $name"
  else
    echo "FAIL $name (expected $expected, got $actual)"
    FAIL=1
  fi
}

setup_repo() {
  local dir
  dir="$(mktemp -d)"
  mkdir -p "$dir/docs/ship-flow"
  printf 'fixture\n' > "$dir/README.md"
  (
    cd "$dir" || exit 1
    git init -q
    git add -- README.md
    git -c user.email=test@test -c user.name=test commit -qm "init"
  )
  echo "$dir"
}

run_writer() {
  local repo="$1" stage="$2" entity="$3" content="$4" stderr_file="$5"
  (
    cd "$repo" || exit 1
    bash "$WRITER" \
      --stage="$stage" \
      --entity="$entity" \
      --content="$content" \
      --workflow-dir=docs/ship-flow
  ) > /dev/null 2> "$stderr_file"
}

echo "--- Case 1: direct same-file self-feed is refused before write ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/plan.md"
printf 'original artifact\n' > "$OUT"
BEFORE="$(cat "$OUT")"
ERR="$TMP/stderr.txt"
run_writer "$TMP" plan test-entity "$OUT" "$ERR"
RC=$?
assert_exit 4 "$RC" "Case-1a direct same-file exits 4"
assert_contains "$ERR" "Self-feed loop refused" "Case-1b direct same-file error is readable"
AFTER="$(cat "$OUT")"
if [ "$AFTER" = "$BEFORE" ]; then echo "OK Case-1c output unchanged"
else echo "FAIL Case-1c output changed"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 2: symlink/realpath alias self-feed is refused before write ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/execute.md"
printf 'original artifact\n' > "$OUT"
ln -s "$OUT" "$TMP/alias.md"
BEFORE="$(cat "$OUT")"
ERR="$TMP/stderr.txt"
run_writer "$TMP" execute test-entity "$TMP/alias.md" "$ERR"
RC=$?
assert_exit 4 "$RC" "Case-2a symlink alias exits 4"
assert_contains "$ERR" "Self-feed loop refused" "Case-2b symlink alias error is readable"
AFTER="$(cat "$OUT")"
if [ "$AFTER" = "$BEFORE" ]; then echo "OK Case-2c output unchanged"
else echo "FAIL Case-2c output changed"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 3: oversized content is refused before write ---"
TMP="$(setup_repo)"
CONTENT="$TMP/oversized.md"
printf '0123456789012345678901234567890123456789\n' > "$CONTENT"
ERR="$TMP/stderr.txt"
(
  cd "$TMP" || exit 1
  SHIP_FLOW_STAGE_ARTIFACT_MAX_BYTES=32 bash "$WRITER" \
    --stage=verify \
    --entity=test-entity \
    --content="$CONTENT" \
    --workflow-dir=docs/ship-flow
) > /dev/null 2> "$ERR"
RC=$?
assert_exit 5 "$RC" "Case-3a oversized content exits 5"
assert_contains "$ERR" "content exceeds max" "Case-3b oversized content error is readable"
if [ ! -e "$TMP/docs/ship-flow/test-entity/verify.md" ]; then echo "OK Case-3c output not created"
else echo "FAIL Case-3c output was created"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 4: bare content is wrapped exactly once ---"
TMP="$(setup_repo)"
CONTENT="$TMP/bare.md"
printf '# Verify\n\nBare content.\n' > "$CONTENT"
ERR="$TMP/stderr.txt"
run_writer "$TMP" verify test-entity "$CONTENT" "$ERR"
RC=$?
OUT="$TMP/docs/ship-flow/test-entity/verify.md"
assert_exit 0 "$RC" "Case-4a bare content exits 0"
assert_exact_line_count 1 "$OUT" "<!-- section:verify-report -->" "Case-4b opener emitted once"
assert_exact_line_count 1 "$OUT" "<!-- /section:verify-report -->" "Case-4c closer emitted once"
rm -rf "$TMP"

echo
echo "--- Case 5: exactly pre-wrapped content passes through without double-wrap ---"
TMP="$(setup_repo)"
CONTENT="$TMP/prewrapped.md"
cat > "$CONTENT" <<'EOF'
<!-- section:review-report -->
# Review

Already wrapped.
<!-- /section:review-report -->
EOF
ERR="$TMP/stderr.txt"
run_writer "$TMP" review test-entity "$CONTENT" "$ERR"
RC=$?
OUT="$TMP/docs/ship-flow/test-entity/review.md"
assert_exit 0 "$RC" "Case-5a pre-wrapped content exits 0"
assert_exact_line_count 1 "$OUT" "<!-- section:review-report -->" "Case-5b opener remains single"
assert_exact_line_count 1 "$OUT" "<!-- /section:review-report -->" "Case-5c closer remains single"
if cmp -s "$CONTENT" "$OUT"; then echo "OK Case-5d pre-wrapped content is byte-identical"
else echo "FAIL Case-5d pre-wrapped content changed"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 5b: writer commits without global git identity ---"
TMP="$(setup_repo)"
NO_ID_HOME="$(mktemp -d)"
NO_ID_XDG="$(mktemp -d)"
CONTENT="$TMP/no-identity.md"
printf '# Execute\n\nNo global git identity.\n' > "$CONTENT"
ERR="$TMP/stderr.txt"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
(
  cd "$TMP" || exit 1
  env -u GIT_AUTHOR_NAME \
      -u GIT_AUTHOR_EMAIL \
      -u GIT_COMMITTER_NAME \
      -u GIT_COMMITTER_EMAIL \
      -u EMAIL \
      HOME="$NO_ID_HOME" \
      XDG_CONFIG_HOME="$NO_ID_XDG" \
      GIT_CONFIG_NOSYSTEM=1 \
      bash "$WRITER" \
        --stage=execute \
        --entity=test-entity \
        --content="$CONTENT" \
        --workflow-dir=docs/ship-flow
) > /dev/null 2> "$ERR"
RC=$?
OUT="$TMP/docs/ship-flow/test-entity/execute.md"
assert_exit 0 "$RC" "Case-5b-a no-global-identity write exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-5b-b no-global-identity creates one commit"
else echo "FAIL Case-5b-b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
if [ -z "$(cd "$TMP" && git status --porcelain -- docs/ship-flow/test-entity/execute.md)" ]; then echo "OK Case-5b-c no-global-identity output committed cleanly"
else echo "FAIL Case-5b-c no-global-identity output left dirty"; FAIL=1; fi
AUTHOR="$(cd "$TMP" && git log -1 --format='%an <%ae>')"
if [ "$AUTHOR" = "Ship-flow <author@example.com>" ]; then echo "OK Case-5b-d no-global-identity author fallback used"
else echo "FAIL Case-5b-d unexpected author: $AUTHOR"; FAIL=1; fi
if [ -f "$OUT" ]; then echo "OK Case-5b-e no-global-identity output exists"
else echo "FAIL Case-5b-e no-global-identity output missing"; FAIL=1; fi
rm -rf "$TMP" "$NO_ID_HOME" "$NO_ID_XDG"

malformed_case() {
  local name="$1" body="$2"
  local tmp content err out rc
  tmp="$(setup_repo)"
  content="$tmp/malformed.md"
  printf '%s\n' "$body" > "$content"
  err="$tmp/stderr.txt"
  run_writer "$tmp" execute test-entity "$content" "$err"
  rc=$?
  out="$tmp/docs/ship-flow/test-entity/execute.md"
  assert_exit 9 "$rc" "${name} exits 9"
  assert_contains "$err" "malformed stage wrapper" "${name} error is readable"
  if [ ! -e "$out" ]; then echo "OK ${name} output not created"
  else echo "FAIL ${name} output was created"; FAIL=1; fi
  rm -rf "$tmp"
}

echo
echo "--- Case 6: malformed wrappers are refused before write ---"
malformed_case "Case-6a opener-only" "<!-- section:execute-report -->
# Execute"
malformed_case "Case-6b closer-only" "# Execute
<!-- /section:execute-report -->"
malformed_case "Case-6c duplicate-wrapper" "<!-- section:execute-report -->
# Execute
<!-- section:execute-report -->
duplicate
<!-- /section:execute-report -->
<!-- /section:execute-report -->"
malformed_case "Case-6d wrong-stage-wrapper" "<!-- section:plan-report -->
# Plan
<!-- /section:plan-report -->"
malformed_case "Case-6e whitespace-padded-wrapper" $'  <!-- section:execute-report -->  \n# Execute\n  <!-- /section:execute-report -->  '
malformed_case "Case-6f inline-opener-wrapper" $'# Execute\nA prose line with <!-- section:execute-report --> inside it.'
malformed_case "Case-6g inline-closer-wrapper" $'# Execute\nA prose line with <!-- /section:execute-report --> inside it.'
malformed_case "Case-6h inline-opener-wrapper-internal-space" $'# Execute\nA prose line with <!-- section:execute-report   --> inside it.'
malformed_case "Case-6i inline-closer-wrapper-internal-space" $'# Execute\nA prose line with <!--   /section:execute-report --> inside it.'
malformed_case "Case-6j inline-opener-wrapper-section-colon-space" $'# Execute\nA prose line with <!-- section :execute-report --> inside it.'
malformed_case "Case-6k inline-closer-wrapper-section-colon-space" $'# Execute\nA prose line with <!-- / section : execute-report --> inside it.'

echo
echo "--- Case 7: invalid max-size config is refused before write ---"
TMP="$(setup_repo)"
CONTENT="$TMP/content.md"
printf '# Plan\n\nContent.\n' > "$CONTENT"
ERR="$TMP/stderr.txt"
(
  cd "$TMP" || exit 1
  SHIP_FLOW_STAGE_ARTIFACT_MAX_BYTES=not-a-number bash "$WRITER" \
    --stage=plan \
    --entity=test-entity \
    --content="$CONTENT" \
    --workflow-dir=docs/ship-flow
) > /dev/null 2> "$ERR"
RC=$?
assert_exit 1 "$RC" "Case-7a invalid max-size exits 1"
assert_contains "$ERR" "invalid max size" "Case-7b invalid max-size error is readable"
if [ ! -e "$TMP/docs/ship-flow/test-entity/plan.md" ]; then echo "OK Case-7c output not created"
else echo "FAIL Case-7c output was created"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 8: absolute workflow-dir works when invoked from outside repo ---"
TMP="$(setup_repo)"
OUTSIDE="$(mktemp -d)"
CONTENT="$OUTSIDE/content.md"
printf '# Ship\n\nOutside invocation.\n' > "$CONTENT"
ERR="$OUTSIDE/stderr.txt"
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
(
  cd "$OUTSIDE" || exit 1
  bash "$WRITER" \
    --stage=ship \
    --entity=test-entity \
    --content="$CONTENT" \
    --workflow-dir="$TMP/docs/ship-flow"
) > /dev/null 2> "$ERR"
RC=$?
assert_exit 0 "$RC" "Case-8a outside invocation exits 0"
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
COMMIT_DELTA=$(( COMMITS_AFTER - COMMITS_BEFORE ))
if [ "$COMMIT_DELTA" = "1" ]; then echo "OK Case-8b outside invocation creates one commit"
else echo "FAIL Case-8b expected one commit, got $COMMIT_DELTA"; FAIL=1; fi
if [ -f "$TMP/docs/ship-flow/test-entity/ship.md" ]; then echo "OK Case-8c output exists"
else echo "FAIL Case-8c output missing"; FAIL=1; fi
if [ -z "$(cd "$TMP" && git status --porcelain -- docs/ship-flow/test-entity/ship.md)" ]; then echo "OK Case-8d output committed cleanly"
else echo "FAIL Case-8d output left dirty"; FAIL=1; fi
COMMIT_FILES="$(cd "$TMP" && git show --name-only --format= HEAD)"
if [ "$COMMIT_FILES" = "docs/ship-flow/test-entity/ship.md" ]; then echo "OK Case-8e commit pathspec contains only artifact"
else echo "FAIL Case-8e unexpected commit files: $COMMIT_FILES"; FAIL=1; fi
rm -rf "$TMP" "$OUTSIDE"

echo
echo "--- Case 9: git add failure removes artifact and returns 8 ---"
TMP="$(setup_repo)"
CONTENT="$TMP/content.md"
printf '# Verify\n\nAdd failure.\n' > "$CONTENT"
ERR="$TMP/stderr.txt"
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
(
  cd "$TMP" || exit 1
  PATH="$GIT_WRAPPER_DIR:$PATH" bash "$WRITER" \
    --stage=verify \
    --entity=test-entity \
    --content="$CONTENT" \
    --workflow-dir=docs/ship-flow
) > /dev/null 2> "$ERR"
RC=$?
OUT="$TMP/docs/ship-flow/test-entity/verify.md"
assert_exit 8 "$RC" "Case-9a git add failure exits 8"
assert_contains "$ERR" "git add failed" "Case-9b git add failure error is readable"
if [ ! -e "$OUT" ]; then echo "OK Case-9c artifact removed"
else echo "FAIL Case-9c artifact still exists"; FAIL=1; fi
PORCELAIN="$(cd "$TMP" && git status --porcelain -- docs/ship-flow/test-entity/verify.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-9d artifact not dirty or staged"
else echo "FAIL Case-9d artifact left dirty or staged: $PORCELAIN"; FAIL=1; fi
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 10: git commit failure removes artifact and clears staged entry ---"
TMP="$(setup_repo)"
CONTENT="$TMP/content.md"
printf '# Review\n\nCommit failure.\n' > "$CONTENT"
ERR="$TMP/stderr.txt"
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
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
(
  cd "$TMP" || exit 1
  PATH="$GIT_WRAPPER_DIR:$PATH" bash "$WRITER" \
    --stage=review \
    --entity=test-entity \
    --content="$CONTENT" \
    --workflow-dir=docs/ship-flow
) > /dev/null 2> "$ERR"
RC=$?
OUT="$TMP/docs/ship-flow/test-entity/review.md"
assert_exit 8 "$RC" "Case-10a git commit failure exits 8"
assert_contains "$ERR" "commit failed" "Case-10b git commit failure error is readable"
if [ ! -e "$OUT" ]; then echo "OK Case-10c artifact removed"
else echo "FAIL Case-10c artifact still exists"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-10d no commit created"
else echo "FAIL Case-10d unexpected commit created"; FAIL=1; fi
PORCELAIN="$(cd "$TMP" && git status --porcelain -- docs/ship-flow/test-entity/review.md)"
if [ -z "$PORCELAIN" ]; then echo "OK Case-10e artifact not dirty or staged"
else echo "FAIL Case-10e artifact left dirty or staged: $PORCELAIN"; FAIL=1; fi
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 11: idempotent writer preserves pre-existing staged artifact diff ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/verify.md"
cat > "$OUT" <<'EOF'
<!-- section:verify-report -->
# Verify

Committed artifact.
<!-- /section:verify-report -->
EOF
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/verify.md
  git -c user.email=test@test -c user.name=test commit -qm "add verify artifact"
)
CONTENT="$TMP/content.md"
cat > "$CONTENT" <<'EOF'
<!-- section:verify-report -->
# Verify

Committed artifact.
<!-- /section:verify-report -->
EOF
printf '\nPre-staged artifact note.\n' >> "$OUT"
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/verify.md
)
ERR="$TMP/stderr.txt"
BEFORE_CONTENT="$(cat "$OUT")"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/verify.md > "$BEFORE_INDEX_PATCH")
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
run_writer "$TMP" verify test-entity "$CONTENT" "$ERR"
RC=$?
assert_exit 0 "$RC" "Case-11a idempotent writer exits 0"
assert_contains "$ERR" "no diff after write" "Case-11b idempotent writer warning is readable"
AFTER_CONTENT="$(cat "$OUT")"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-11c artifact worktree content preserved"
else echo "FAIL Case-11c artifact worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-11d no commit created"
else echo "FAIL Case-11d unexpected commit created"; FAIL=1; fi
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/verify.md > "$AFTER_INDEX_PATCH")
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-11e pre-existing staged diff preserved"
else echo "FAIL Case-11e pre-existing staged diff changed"; FAIL=1; fi
if (cd "$TMP" && git diff --quiet -- docs/ship-flow/test-entity/verify.md); then echo "OK Case-11f no unstaged artifact diff"
else echo "FAIL Case-11f artifact has unstaged diff"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 12: idempotent writer preserves pre-existing unstaged artifact diff ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/verify.md"
cat > "$OUT" <<'EOF'
<!-- section:verify-report -->
# Verify

Committed artifact.
<!-- /section:verify-report -->
EOF
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/verify.md
  git -c user.email=test@test -c user.name=test commit -qm "add verify artifact"
)
perl -0pi -e 's/\n<!-- \/section:verify-report -->/\nPre-existing unstaged artifact note.\n<!-- \/section:verify-report -->/' "$OUT"
CONTENT="$TMP/content.md"
cp "$OUT" "$CONTENT"
ERR="$TMP/stderr.txt"
BEFORE_CONTENT="$(cat "$OUT")"
BEFORE_WORKTREE_PATCH="$TMP/before-worktree.patch"
AFTER_WORKTREE_PATCH="$TMP/after-worktree.patch"
(cd "$TMP" && git diff --binary -- docs/ship-flow/test-entity/verify.md > "$BEFORE_WORKTREE_PATCH")
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
run_writer "$TMP" verify test-entity "$CONTENT" "$ERR"
RC=$?
assert_exit 0 "$RC" "Case-12a idempotent writer exits 0"
assert_contains "$ERR" "no diff after write" "Case-12b idempotent writer warning is readable"
AFTER_CONTENT="$(cat "$OUT")"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-12c artifact worktree content preserved"
else echo "FAIL Case-12c artifact worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-12d no commit created"
else echo "FAIL Case-12d unexpected commit created"; FAIL=1; fi
(cd "$TMP" && git diff --binary -- docs/ship-flow/test-entity/verify.md > "$AFTER_WORKTREE_PATCH")
if cmp -s "$BEFORE_WORKTREE_PATCH" "$AFTER_WORKTREE_PATCH"; then echo "OK Case-12e pre-existing unstaged diff preserved"
else echo "FAIL Case-12e pre-existing unstaged diff changed"; FAIL=1; fi
if (cd "$TMP" && git diff --cached --quiet -- docs/ship-flow/test-entity/verify.md); then echo "OK Case-12f no staged artifact diff"
else echo "FAIL Case-12f artifact has staged diff"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 13: idempotent writer preserves pre-existing staged artifact diff matching content ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/review.md"
cat > "$OUT" <<'EOF'
<!-- section:review-report -->
# Review

Committed artifact.
<!-- /section:review-report -->
EOF
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/review.md
  git -c user.email=test@test -c user.name=test commit -qm "add review artifact"
)
perl -0pi -e 's/\n<!-- \/section:review-report -->/\nPre-existing staged artifact note.\n<!-- \/section:review-report -->/' "$OUT"
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/review.md
)
CONTENT="$TMP/content.md"
cp "$OUT" "$CONTENT"
ERR="$TMP/stderr.txt"
BEFORE_CONTENT="$(cat "$OUT")"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/review.md > "$BEFORE_INDEX_PATCH")
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
run_writer "$TMP" review test-entity "$CONTENT" "$ERR"
RC=$?
assert_exit 0 "$RC" "Case-13a idempotent writer exits 0"
assert_contains "$ERR" "no diff after write" "Case-13b idempotent writer warning is readable"
AFTER_CONTENT="$(cat "$OUT")"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-13c artifact worktree content preserved"
else echo "FAIL Case-13c artifact worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-13d no commit created"
else echo "FAIL Case-13d unexpected commit created"; FAIL=1; fi
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/review.md > "$AFTER_INDEX_PATCH")
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-13e pre-existing staged diff preserved"
else echo "FAIL Case-13e pre-existing staged diff changed"; FAIL=1; fi
if (cd "$TMP" && git diff --quiet -- docs/ship-flow/test-entity/review.md); then echo "OK Case-13f no unstaged artifact diff"
else echo "FAIL Case-13f artifact has unstaged diff"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 14: git add failure preserves pre-existing staged artifact diff ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/verify.md"
printf 'committed artifact\n' > "$OUT"
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/verify.md
  git -c user.email=test@test -c user.name=test commit -qm "add verify artifact"
)
printf 'pre-staged artifact\n' > "$OUT"
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/verify.md
)
CONTENT="$TMP/content.md"
printf '# Verify\n\nAdd failure.\n' > "$CONTENT"
ERR="$TMP/stderr.txt"
BEFORE_CONTENT="$(cat "$OUT")"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/verify.md > "$BEFORE_INDEX_PATCH")
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
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
(
  cd "$TMP" || exit 1
  PATH="$GIT_WRAPPER_DIR:$PATH" bash "$WRITER" \
    --stage=verify \
    --entity=test-entity \
    --content="$CONTENT" \
    --workflow-dir=docs/ship-flow
) > /dev/null 2> "$ERR"
RC=$?
assert_exit 8 "$RC" "Case-14a git add failure exits 8"
assert_contains "$ERR" "git add failed" "Case-14b git add failure error is readable"
AFTER_CONTENT="$(cat "$OUT")"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-14c artifact worktree content restored"
else echo "FAIL Case-14c artifact worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-14d no commit created"
else echo "FAIL Case-14d unexpected commit created"; FAIL=1; fi
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/verify.md > "$AFTER_INDEX_PATCH")
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-14e pre-existing staged diff preserved"
else echo "FAIL Case-14e pre-existing staged diff changed"; FAIL=1; fi
if (cd "$TMP" && git diff --quiet -- docs/ship-flow/test-entity/verify.md); then echo "OK Case-14f no unstaged artifact diff"
else echo "FAIL Case-14f artifact has unstaged diff"; FAIL=1; fi
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 15: git commit failure preserves pre-existing staged artifact diff ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/review.md"
printf 'committed artifact\n' > "$OUT"
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/review.md
  git -c user.email=test@test -c user.name=test commit -qm "add review artifact"
)
printf 'pre-staged artifact\n' > "$OUT"
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/review.md
)
CONTENT="$TMP/content.md"
printf '# Review\n\nCommit failure.\n' > "$CONTENT"
ERR="$TMP/stderr.txt"
BEFORE_CONTENT="$(cat "$OUT")"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/review.md > "$BEFORE_INDEX_PATCH")
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
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
(
  cd "$TMP" || exit 1
  PATH="$GIT_WRAPPER_DIR:$PATH" bash "$WRITER" \
    --stage=review \
    --entity=test-entity \
    --content="$CONTENT" \
    --workflow-dir=docs/ship-flow
) > /dev/null 2> "$ERR"
RC=$?
assert_exit 8 "$RC" "Case-15a git commit failure exits 8"
assert_contains "$ERR" "commit failed" "Case-15b git commit failure error is readable"
AFTER_CONTENT="$(cat "$OUT")"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-15c artifact worktree content restored"
else echo "FAIL Case-15c artifact worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-15d no commit created"
else echo "FAIL Case-15d unexpected commit created"; FAIL=1; fi
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/review.md > "$AFTER_INDEX_PATCH")
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-15e pre-existing staged diff preserved"
else echo "FAIL Case-15e pre-existing staged diff changed"; FAIL=1; fi
if (cd "$TMP" && git diff --quiet -- docs/ship-flow/test-entity/review.md); then echo "OK Case-15f no unstaged artifact diff"
else echo "FAIL Case-15f artifact has unstaged diff"; FAIL=1; fi
rm -rf "$TMP" "$GIT_WRAPPER_DIR"

echo
echo "--- Case 16: idempotent writer preserves pre-existing unstaged mode-only artifact diff ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/verify.md"
cat > "$OUT" <<'EOF'
<!-- section:verify-report -->
# Verify

Committed artifact.
<!-- /section:verify-report -->
EOF
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/verify.md
  git -c user.email=test@test -c user.name=test commit -qm "add verify artifact"
  chmod +x docs/ship-flow/test-entity/verify.md
)
CONTENT="$TMP/content.md"
cp "$OUT" "$CONTENT"
ERR="$TMP/stderr.txt"
BEFORE_SUMMARY="$TMP/before-summary.txt"
AFTER_SUMMARY="$TMP/after-summary.txt"
(cd "$TMP" && git diff --summary -- docs/ship-flow/test-entity/verify.md > "$BEFORE_SUMMARY")
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
run_writer "$TMP" verify test-entity "$CONTENT" "$ERR"
RC=$?
assert_exit 0 "$RC" "Case-16a idempotent writer exits 0"
assert_contains "$ERR" "no diff after write" "Case-16b idempotent writer warning is readable"
if [ -x "$OUT" ]; then echo "OK Case-16c executable mode preserved"
else echo "FAIL Case-16c executable mode lost"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-16d no commit created"
else echo "FAIL Case-16d unexpected commit created"; FAIL=1; fi
(cd "$TMP" && git diff --summary -- docs/ship-flow/test-entity/verify.md > "$AFTER_SUMMARY")
if cmp -s "$BEFORE_SUMMARY" "$AFTER_SUMMARY"; then echo "OK Case-16e pre-existing unstaged mode diff preserved"
else echo "FAIL Case-16e pre-existing unstaged mode diff changed"; FAIL=1; fi
if (cd "$TMP" && git diff --cached --quiet -- docs/ship-flow/test-entity/verify.md); then echo "OK Case-16f no staged artifact diff"
else echo "FAIL Case-16f artifact has staged diff"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 17: idempotent writer preserves pre-existing staged mode-only artifact diff ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/review.md"
cat > "$OUT" <<'EOF'
<!-- section:review-report -->
# Review

Committed artifact.
<!-- /section:review-report -->
EOF
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/review.md
  git -c user.email=test@test -c user.name=test commit -qm "add review artifact"
  chmod +x docs/ship-flow/test-entity/review.md
  git add -- docs/ship-flow/test-entity/review.md
)
CONTENT="$TMP/content.md"
cp "$OUT" "$CONTENT"
ERR="$TMP/stderr.txt"
BEFORE_INDEX_PATCH="$TMP/before-index.patch"
AFTER_INDEX_PATCH="$TMP/after-index.patch"
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/review.md > "$BEFORE_INDEX_PATCH")
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
run_writer "$TMP" review test-entity "$CONTENT" "$ERR"
RC=$?
assert_exit 0 "$RC" "Case-17a idempotent writer exits 0"
assert_contains "$ERR" "no diff after write" "Case-17b idempotent writer warning is readable"
if [ -x "$OUT" ]; then echo "OK Case-17c executable mode preserved"
else echo "FAIL Case-17c executable mode lost"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-17d no commit created"
else echo "FAIL Case-17d unexpected commit created"; FAIL=1; fi
(cd "$TMP" && git diff --cached --binary -- docs/ship-flow/test-entity/review.md > "$AFTER_INDEX_PATCH")
if cmp -s "$BEFORE_INDEX_PATCH" "$AFTER_INDEX_PATCH"; then echo "OK Case-17e pre-existing staged mode diff preserved"
else echo "FAIL Case-17e pre-existing staged mode diff changed"; FAIL=1; fi
if (cd "$TMP" && git diff --quiet -- docs/ship-flow/test-entity/review.md); then echo "OK Case-17f no unstaged artifact diff"
else echo "FAIL Case-17f artifact has unstaged diff"; FAIL=1; fi
rm -rf "$TMP"

echo
echo "--- Case 18: post-add no-diff restores pre-existing unstaged artifact diff ---"
TMP="$(setup_repo)"
mkdir -p "$TMP/docs/ship-flow/test-entity"
OUT="$TMP/docs/ship-flow/test-entity/verify.md"
cat > "$OUT" <<'EOF'
<!-- section:verify-report -->
# Verify

Committed artifact.
<!-- /section:verify-report -->
EOF
(
  cd "$TMP" || exit 1
  git add -- docs/ship-flow/test-entity/verify.md
  git -c user.email=test@test -c user.name=test commit -qm "add verify artifact"
)
perl -0pi -e 's/Committed artifact\./Caller unstaged artifact edit./' "$OUT"
CONTENT="$TMP/content.md"
cat > "$CONTENT" <<'EOF'
<!-- section:verify-report -->
# Verify

Committed artifact.
<!-- /section:verify-report -->
EOF
ERR="$TMP/stderr.txt"
BEFORE_CONTENT="$(cat "$OUT")"
BEFORE_WORKTREE_PATCH="$TMP/before-worktree.patch"
AFTER_WORKTREE_PATCH="$TMP/after-worktree.patch"
(cd "$TMP" && git diff --binary -- docs/ship-flow/test-entity/verify.md > "$BEFORE_WORKTREE_PATCH")
COMMITS_BEFORE="$(cd "$TMP" && git rev-list --count HEAD)"
run_writer "$TMP" verify test-entity "$CONTENT" "$ERR"
RC=$?
assert_exit 0 "$RC" "Case-18a post-add no-diff exits 0"
assert_contains "$ERR" "no diff after write" "Case-18b post-add no-diff warning is readable"
AFTER_CONTENT="$(cat "$OUT")"
if [ "$AFTER_CONTENT" = "$BEFORE_CONTENT" ]; then echo "OK Case-18c artifact worktree content preserved"
else echo "FAIL Case-18c artifact worktree content changed"; FAIL=1; fi
COMMITS_AFTER="$(cd "$TMP" && git rev-list --count HEAD)"
if [ "$COMMITS_AFTER" = "$COMMITS_BEFORE" ]; then echo "OK Case-18d no commit created"
else echo "FAIL Case-18d unexpected commit created"; FAIL=1; fi
(cd "$TMP" && git diff --binary -- docs/ship-flow/test-entity/verify.md > "$AFTER_WORKTREE_PATCH")
if cmp -s "$BEFORE_WORKTREE_PATCH" "$AFTER_WORKTREE_PATCH"; then echo "OK Case-18e pre-existing unstaged diff preserved"
else echo "FAIL Case-18e pre-existing unstaged diff changed"; FAIL=1; fi
if (cd "$TMP" && git diff --cached --quiet -- docs/ship-flow/test-entity/verify.md); then echo "OK Case-18f no staged artifact diff"
else echo "FAIL Case-18f artifact has staged diff"; FAIL=1; fi
rm -rf "$TMP"

exit $FAIL
