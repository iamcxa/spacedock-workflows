#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${HERE}/../fo-stage-attempt.sh"
FAIL=0
ok() { printf 'OK %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAIL=1; }
sha256_stream() { if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi; }
sha256_file() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
hex() { LC_ALL=C od -An -v -t x1 | tr -d ' \n'; }

if [ ! -f "$HELPER" ]; then
  bad "fo-stage-attempt.sh is missing: executable returned/WAL/checkpoint/history-CAS/replay/dirty-state ordering is not implemented"
  exit "$FAIL"
fi
if [ ! -x "$HELPER" ]; then bad "fo-stage-attempt.sh is not executable"; exit "$FAIL"; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/stage-attempt-history.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
REF='refs/heads/main'

# Globals populated by prepare_case. Each scenario gets a fresh repository so
# no RED can be explained by a previous live WAL, route, ref, index, or dirt.
CASE_REPO=''; CASE_ENTITY=''; CASE_ARTIFACT=''; CASE_HEAD=''; CASE_COMMON=''
CASE_WAL=''; CASE_RETURNED=''; CASE_BUNDLE=''; CASE_HISTORY=''; CASE_TRACKED=''
CASE_LEASE=''; CASE_CHECKPOINT=''; CASE_MARKER=''

prepare_case() {
  local name="$1" layout="$2" outcome="$3" entity_hex ref_hex worker_hex lease_sha key attempt_id terminal_id completion_line completion_sha
  CASE_REPO="$TMP/$name-repo"
  CASE_MARKER="$TMP/$name.checkpoint"
  mkdir -p "$CASE_REPO/docs/history-flow"
  if [ "$layout" = folder ]; then
    mkdir -p "$CASE_REPO/docs/history-flow/$name"
    CASE_ENTITY="docs/history-flow/$name/index.md"
    CASE_ARTIFACT="docs/history-flow/$name/plan.md"
    if [ "$outcome" = passed ]; then
      printf '%s\n' '---' "id: $name" 'status: plan' 'stage_outputs:' '  plan: plan.md' '---' > "$CASE_REPO/$CASE_ENTITY"
    else
      printf '%s\n' '---' "id: $name" 'status: plan' 'stage_outputs: {}' '---' > "$CASE_REPO/$CASE_ENTITY"
    fi
    CASE_HISTORY="$CASE_REPO/docs/history-flow/$name/attempt-history-v1.log"
  else
    CASE_ENTITY="docs/history-flow/$name.md"
    CASE_ARTIFACT="docs/history-flow/$name-plan.md"
    printf '%s\n' '---' "id: $name" 'status: plan' 'stage_outputs: {}' '---' > "$CASE_REPO/$CASE_ENTITY"
    CASE_HISTORY="$CASE_REPO/docs/history-flow/$name.attempt-history-v1.log"
  fi
  printf '# Plan\n' > "$CASE_REPO/$CASE_ARTIFACT"
  (
    cd "$CASE_REPO" || exit 1
    git init -q -b main
    git config user.name test
    git config user.email test@example.invalid
    git add -- docs
    git commit -qm fixture
  )
  CASE_HEAD="$(git -C "$CASE_REPO" rev-parse HEAD)"
  CASE_COMMON="$(git -C "$CASE_REPO" rev-parse --git-common-dir)"; case "$CASE_COMMON" in /*) ;; *) CASE_COMMON="$CASE_REPO/$CASE_COMMON" ;; esac
  printf '%s\n' '11111111-2222-3333-4444-555555555555' > "$TMP/$name.boot"
  (
    cd "$CASE_REPO" || exit 1
    STAGE_ATTEMPT_BOOT_ID_SOURCE="$TMP/$name.boot" STAGE_ATTEMPT_MONOTONIC_NS=1000000000 \
      bash "$HELPER" begin --entity="$CASE_ENTITY" --stage=plan --stage-run-id="$CASE_HEAD" --ref="$REF" \
        --attempt-before="$CASE_HEAD" --worker-id=history-worker --lease-token="$name-token" \
        --attempt-ordinal=0 --fresh-continuations-used=0 --attempt-started-at=2026-07-22T01:00:00Z
  ) > "$TMP/$name.begin" 2> "$TMP/$name.begin.err" || { bad "$name begin fixture"; return 1; }
  CASE_WAL="$(find "$CASE_COMMON/spacedock-stage-attempt-v1" -name '*.wal' -type f -print -quit 2>/dev/null || true)"
  [ -n "$CASE_WAL" ] || { bad "$name WAL fixture"; return 1; }
  CASE_RETURNED="${CASE_WAL%.wal}.returned"
  key="$(basename "${CASE_WAL%.wal}")"
  attempt_id="$(sed -n 's/.* attempt_id=\([^ ]*\) .*/\1/p' "$CASE_WAL")"
  terminal_id="sev1-$(printf 'stage-attempt-v1-terminal\0%s\0%s\0%s' "$key" "$CASE_HEAD" "$attempt_id" | sha256_stream)"
  if [ "$layout" = folder ]; then CASE_TRACKED="$CASE_REPO/docs/history-flow/$name/attempt-return-v1.$terminal_id.receipt"
  else CASE_TRACKED="$CASE_REPO/docs/history-flow/$name.attempt-return-v1.$terminal_id.receipt"; fi
  entity_hex="$(printf '%s' "$CASE_ENTITY" | hex)"; ref_hex="$(printf '%s' "$REF" | hex)"; worker_hex="$(printf '%s' history-worker | hex)"; lease_sha="$(printf '%s' "$name-token" | sha256_stream)"
  CASE_BUNDLE="$TMP/$name.bundle"
  if [ "$outcome" = passed ]; then
    completion_line="completion-v1 disposition=already-registered ref=$REF before=$CASE_HEAD completion=$CASE_HEAD entity=$CASE_ENTITY stage=plan artifact=plan.md"
    completion_sha="$(printf '%s\n' "$completion_line" | sha256_stream)"
  else
    completion_line=''; completion_sha=none
  fi
  printf 'stage-attempt-v1 entity_stage_key=%s entity_path_hex=%s stage=plan stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_completion_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=0 attempt_started_at=2026-07-22T01:00:00Z budget_seconds=1200 attempt_elapsed_seconds=10 fresh_continuations_used=0 outcome=%s artifact_path_hex=%s artifact_oid=%s completion_receipt_sha256=%s terminal_event_id=%s\n' \
    "$key" "$entity_hex" "$CASE_HEAD" "$ref_hex" "$CASE_HEAD" "$CASE_HEAD" "$worker_hex" "$lease_sha" "$attempt_id" "$outcome" "$(basename "$CASE_ARTIFACT" | hex)" "$(git -C "$CASE_REPO" rev-parse "HEAD:$CASE_ARTIFACT")" "$completion_sha" "$terminal_id" > "$CASE_BUNDLE"
  if [ "$outcome" = passed ]; then printf 'completion-v1-begin\n%s\ncompletion-v1-end\n' "$completion_line" >> "$CASE_BUNDLE"; fi
  CASE_LEASE="$CASE_COMMON/completion-v1.lease/returned"
  CASE_CHECKPOINT="$TMP/$name-checkpoint.sh"
  cat > "$CASE_CHECKPOINT" <<'EOF'
#!/usr/bin/env bash
set -u
[ -f "$STAGE_ATTEMPT_RETURNED" ] && cmp -s "$STAGE_ATTEMPT_BUNDLE" "$STAGE_ATTEMPT_RETURNED" || exit 31
grep -q ' state=returned ' "$STAGE_ATTEMPT_WAL" || exit 32
[ ! -e "$STAGE_ATTEMPT_HISTORY" ] || exit 33
[ "$(git rev-parse "$STAGE_ATTEMPT_REF")" = "$STAGE_ATTEMPT_WORKER_COMPLETION" ] || exit 34
[ -f "$STAGE_ATTEMPT_COMPLETION_LEASE" ] || exit 35
printf 'checkpoint-before-history\n' > "$STAGE_ATTEMPT_CHECKPOINT_MARKER"
rm -rf "$(dirname "$STAGE_ATTEMPT_COMPLETION_LEASE")"
EOF
  chmod +x "$CASE_CHECKPOINT"
}

accept_case() {
  local name="$1" failpoint="${2:-}"
  (
    cd "$CASE_REPO" || exit 1
    STAGE_ATTEMPT_FAILPOINT="$failpoint" bash "$HELPER" accept-return --entity="$CASE_ENTITY" --stage=plan --lease-token="$name-token" --bundle="$CASE_BUNDLE"
  ) > "$TMP/$name.accept" 2>&1
}

terminal_case() {
  local name="$1" failpoint="${2:-}" checkpoint_cmd="${3:-$CASE_CHECKPOINT}"
  (
    cd "$CASE_REPO" || exit 1
    STAGE_ATTEMPT_FAILPOINT="$failpoint" \
    STAGE_ATTEMPT_COMPLETION_CHECKPOINT_CMD="$checkpoint_cmd" \
    STAGE_ATTEMPT_RETURNED="$CASE_RETURNED" STAGE_ATTEMPT_BUNDLE="$CASE_BUNDLE" \
    STAGE_ATTEMPT_WAL="$CASE_WAL" STAGE_ATTEMPT_HISTORY="$CASE_HISTORY" \
    STAGE_ATTEMPT_REF="$REF" STAGE_ATTEMPT_WORKER_COMPLETION="$CASE_HEAD" \
    STAGE_ATTEMPT_COMPLETION_LEASE="$CASE_LEASE" STAGE_ATTEMPT_CHECKPOINT_MARKER="$CASE_MARKER" \
      bash "$HELPER" terminal --entity="$CASE_ENTITY" --stage=plan --lease-token="$name-token" --finished-at=2026-07-22T01:00:10Z
  ) > "$TMP/$name.terminal" 2>&1
}

add_dirt() {
  printf 'staged dirt\n' > "$CASE_REPO/staged.txt"
  git -C "$CASE_REPO" add -- staged.txt
  printf 'unstaged dirt\n' > "$CASE_REPO/unstaged.txt"
}

# Passed folder: returned bytes and WAL are durable before checkpoint; the
# injected checkpoint refuses if history/ref ordering is wrong. Terminal CAS
# may then add only history+tracked sidecar and path-only reconcile them.
prepare_case passed-order folder passed || exit "$FAIL"
accept_case passed-order; RC=$?
if [ "$RC" = 0 ] && cmp -s "$CASE_BUNDLE" "$CASE_RETURNED" && grep -q " state=returned .*returned_bundle_sha256=$(sha256_file "$CASE_BUNDLE")$" "$CASE_WAL"; then ok "passed folder persists exact returned bytes before WAL returned"; else bad "passed returned-sidecar then WAL ordering (rc=$RC)"; fi
mkdir -p "$(dirname "$CASE_LEASE")"; printf 'completion lease\n' > "$CASE_LEASE"
add_dirt
DIRT_BEFORE="$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all -- staged.txt unstaged.txt)"; STAGED_BEFORE="$(git -C "$CASE_REPO" ls-files -s -- staged.txt)"; REF_BEFORE="$(git -C "$CASE_REPO" rev-parse "$REF")"
terminal_case passed-order; RC=$?
REF_AFTER="$(git -C "$CASE_REPO" rev-parse "$REF")"
CHANGED="$(git -C "$CASE_REPO" diff-tree --no-commit-id --name-only -r "$REF_BEFORE" "$REF_AFTER" | sort)"
EXPECTED_CHANGED="$(printf '%s\n%s\n' "${CASE_HISTORY#"$CASE_REPO/"}" "${CASE_TRACKED#"$CASE_REPO/"}" | sort)"
if [ "$RC" = 0 ] && [ -f "$CASE_MARKER" ] && [ ! -e "$CASE_LEASE" ] && [ "$REF_AFTER" != "$REF_BEFORE" ] && [ "$CHANGED" = "$EXPECTED_CHANGED" ] && cmp -s "$CASE_BUNDLE" "$CASE_TRACKED" && [ "$(git -C "$CASE_REPO" show "$REF_AFTER:${CASE_HISTORY#"$CASE_REPO/"}" | wc -l | tr -d ' ')" = 1 ] && [ "$STAGED_BEFORE" = "$(git -C "$CASE_REPO" ls-files -s -- staged.txt)" ] && [ "$DIRT_BEFORE" = "$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all -- staged.txt unstaged.txt)" ] && [ ! -e "$CASE_WAL" ] && [ ! -e "$CASE_RETURNED" ]; then
  ok "checkpoint/reconcile/lease cleanup precedes exact history+sidecar CAS, path-only reconcile, and common-dir cleanup"
else bad "passed-folder terminal ordering/CAS/reconcile (rc=$RC changed=$CHANGED)"; fi
COUNT_BEFORE="$(git -C "$CASE_REPO" rev-list --count "$REF")"
terminal_case passed-order; RC=$?
if [ "$RC" = 0 ] && grep -q 'disposition=already-recorded' "$TMP/passed-order.terminal" && [ "$COUNT_BEFORE" = "$(git -C "$CASE_REPO" rev-list --count "$REF")" ]; then ok "tracked exact return replay is already-recorded with no duration or commit duplication"; else bad "passed exact replay (rc=$RC)"; fi

# Non-passed folders and every flat entity bypass completion registration.
BYPASS="$TMP/checkpoint-must-not-run.sh"; BYPASS_COUNT="$TMP/checkpoint.calls"
cat > "$BYPASS" <<'EOF'
#!/usr/bin/env bash
printf 'called\n' >> "$STAGE_ATTEMPT_BYPASS_COUNT"
exit 99
EOF
chmod +x "$BYPASS"; : > "$BYPASS_COUNT"
for SPEC in partial-folder:folder:partial failed-flat:flat:failed; do
  NAME="${SPEC%%:*}"; REST="${SPEC#*:}"; LAYOUT="${REST%%:*}"; OUTCOME="${REST#*:}"
  prepare_case "$NAME" "$LAYOUT" "$OUTCOME" || continue
  accept_case "$NAME" || { bad "$NAME accept"; continue; }
  (
    export STAGE_ATTEMPT_BYPASS_COUNT="$BYPASS_COUNT"
    terminal_case "$NAME" '' "$BYPASS"
  ); RC=$?
  if [ "$RC" = 0 ] && [ ! -s "$BYPASS_COUNT" ] && [ -f "$CASE_HISTORY" ] && [ -f "$CASE_TRACKED" ]; then ok "$NAME terminalizes without completion registration"; else bad "$NAME completion bypass (rc=$RC calls=$(wc -l < "$BYPASS_COUNT" | tr -d ' '))"; fi
done

# A crash after the atomic sidecar write leaves the sole permitted provisional
# state. Exact recovery adopts it under the lock without dispatch; any byte
# mismatch preserves both authorities and refuses.
prepare_case provisional-adopt folder partial || exit "$FAIL"
accept_case provisional-adopt after-returned-write; RC=$?
DISPATCH_COUNT="$TMP/provisional-adopt.dispatch"; : > "$DISPATCH_COUNT"
(
  cd "$CASE_REPO" || exit 1
  STAGE_ATTEMPT_DISPATCH_COUNT_FILE="$DISPATCH_COUNT" \
    bash "$HELPER" recover --entity="$CASE_ENTITY" --stage=plan --lease-token=provisional-adopt-token
) > "$TMP/provisional-adopt.recover" 2>&1
RECOVER_RC=$?
if [ "$RC" != 0 ] && [ "$RECOVER_RC" = 0 ] && [ ! -s "$DISPATCH_COUNT" ] && cmp -s "$CASE_BUNDLE" "$CASE_RETURNED" && grep -q " state=returned .*returned_bundle_sha256=$(sha256_file "$CASE_BUNDLE")$" "$CASE_WAL"; then
  ok "matching provisional sidecar is adopted by WAL flip with zero dispatch"
else bad "matching provisional adoption (fault=$RC recover=$RECOVER_RC)"; fi

prepare_case provisional-mismatch folder partial || exit "$FAIL"
accept_case provisional-mismatch after-returned-write >/dev/null 2>&1
printf 'foreign-byte\n' >> "$CASE_RETURNED"
WAL_HASH="$(sha256_file "$CASE_WAL")"; RETURNED_HASH="$(sha256_file "$CASE_RETURNED")"; REF_SNAPSHOT="$(git -C "$CASE_REPO" rev-parse "$REF")"; INDEX_SNAPSHOT="$(git -C "$CASE_REPO" write-tree)"; WORK_SNAPSHOT="$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)"
(
  cd "$CASE_REPO" || exit 1
  STAGE_ATTEMPT_DISPATCH_COUNT_FILE="$TMP/provisional-mismatch.dispatch" \
    bash "$HELPER" recover --entity="$CASE_ENTITY" --stage=plan --lease-token=provisional-mismatch-token
) > "$TMP/provisional-mismatch.recover" 2>&1
RC=$?
if [ "$RC" != 0 ] && [ "$WAL_HASH" = "$(sha256_file "$CASE_WAL")" ] && [ "$RETURNED_HASH" = "$(sha256_file "$CASE_RETURNED")" ] && [ "$REF_SNAPSHOT" = "$(git -C "$CASE_REPO" rev-parse "$REF")" ] && [ "$INDEX_SNAPSHOT" = "$(git -C "$CASE_REPO" write-tree)" ] && [ "$WORK_SNAPSHOT" = "$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)" ]; then
  ok "mismatched provisional sidecar refuses and preserves WAL/ref/index/worktree"
else bad "mismatched provisional refusal (rc=$RC)"; fi

# Reusing a terminal event key with different exact bytes is a conflict, never
# an already-recorded replay. Recreate only in-flight authority and prove every
# tracked/live surface remains unchanged on refusal.
prepare_case conflicting-replay folder partial || exit "$FAIL"
OPEN_WAL="$TMP/conflicting-replay.open.wal"; cp "$CASE_WAL" "$OPEN_WAL"
accept_case conflicting-replay || bad "conflicting replay accept fixture"
terminal_case conflicting-replay '' "$BYPASS" || bad "conflicting replay terminal fixture"
CONFLICT_BUNDLE="$TMP/conflicting-replay-different.bundle"
sed 's/attempt_elapsed_seconds=10/attempt_elapsed_seconds=11/' "$CASE_BUNDLE" > "$CONFLICT_BUNDLE"
CONFLICT_HASH="$(sha256_file "$CONFLICT_BUNDLE")"
sed -e 's/ state=open / state=returned /' -e "s/ returned_bundle_sha256=none$/ returned_bundle_sha256=$CONFLICT_HASH/" "$OPEN_WAL" > "$CASE_WAL"
cp "$CONFLICT_BUNDLE" "$CASE_RETURNED"; CASE_BUNDLE="$CONFLICT_BUNDLE"
WAL_HASH="$(sha256_file "$CASE_WAL")"; RETURNED_HASH="$(sha256_file "$CASE_RETURNED")"; HISTORY_HASH="$(sha256_file "$CASE_HISTORY")"; TRACKED_HASH="$(sha256_file "$CASE_TRACKED")"; REF_SNAPSHOT="$(git -C "$CASE_REPO" rev-parse "$REF")"; INDEX_SNAPSHOT="$(git -C "$CASE_REPO" write-tree)"; WORK_SNAPSHOT="$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)"
terminal_case conflicting-replay '' "$BYPASS"; RC=$?
if [ "$RC" != 0 ] && [ "$WAL_HASH" = "$(sha256_file "$CASE_WAL")" ] && [ "$RETURNED_HASH" = "$(sha256_file "$CASE_RETURNED")" ] && [ "$HISTORY_HASH" = "$(sha256_file "$CASE_HISTORY")" ] && [ "$TRACKED_HASH" = "$(sha256_file "$CASE_TRACKED")" ] && [ "$REF_SNAPSHOT" = "$(git -C "$CASE_REPO" rev-parse "$REF")" ] && [ "$INDEX_SNAPSHOT" = "$(git -C "$CASE_REPO" write-tree)" ] && [ "$WORK_SNAPSHOT" = "$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)" ]; then
  ok "same terminal event key with different bytes fails closed and preserves every surface"
else bad "conflicting terminal replay preservation (rc=$RC)"; fi

# Every load-bearing boundary is executed as a real failpoint in a fresh repo;
# the failed call must retain authoritative evidence and unrelated live state.
for POINT in after-returned-write after-wal-flip before-completion-checkpoint after-completion-checkpoint before-history-cas after-history-cas before-path-reconcile; do
  NAME="fault-${POINT}"
  prepare_case "$NAME" folder passed || continue
  add_dirt
  REF_SNAPSHOT="$(git -C "$CASE_REPO" rev-parse "$REF")"; INDEX_SNAPSHOT="$(git -C "$CASE_REPO" ls-files -s -- staged.txt)"; STAGED_SHA="$(sha256_file "$CASE_REPO/staged.txt")"; UNSTAGED_SHA="$(sha256_file "$CASE_REPO/unstaged.txt")"
  if [ "$POINT" = after-returned-write ] || [ "$POINT" = after-wal-flip ]; then
    accept_case "$NAME" "$POINT"; RC=$?
  else
    accept_case "$NAME" || { bad "$NAME accept fixture"; continue; }
    mkdir -p "$(dirname "$CASE_LEASE")"; printf 'completion lease\n' > "$CASE_LEASE"
    terminal_case "$NAME" "$POINT"; RC=$?
  fi
  if [ "$RC" != 0 ] && [ -f "$CASE_RETURNED" ] && cmp -s "$CASE_BUNDLE" "$CASE_RETURNED" && [ "$INDEX_SNAPSHOT" = "$(git -C "$CASE_REPO" ls-files -s -- staged.txt)" ] && [ "$STAGED_SHA" = "$(sha256_file "$CASE_REPO/staged.txt")" ] && [ "$UNSTAGED_SHA" = "$(sha256_file "$CASE_REPO/unstaged.txt")" ]; then
    case "$POINT" in
      after-returned-write) grep -q ' state=open ' "$CASE_WAL" || bad "$POINT must retain open WAL" ;;
      after-wal-flip) grep -q ' state=returned ' "$CASE_WAL" || bad "$POINT must retain returned WAL" ;;
      before-completion-checkpoint) [ ! -e "$CASE_MARKER" ] || bad "$POINT ran checkpoint" ;;
      after-completion-checkpoint|before-history-cas) [ "$(git -C "$CASE_REPO" rev-parse "$REF")" = "$REF_SNAPSHOT" ] || bad "$POINT moved ref early" ;;
      after-history-cas|before-path-reconcile) [ "$(git -C "$CASE_REPO" rev-parse "$REF")" != "$REF_SNAPSHOT" ] || bad "$POINT did not reach ref CAS" ;;
    esac
    ok "behavioral failpoint $POINT preserves evidence, index, and unrelated dirt"
  else bad "behavioral failpoint $POINT preservation (rc=$RC)"; fi
done

# Fail-closed filesystem/ref cases are behavioral, not source-token checks.
prepare_case stale-ref folder partial || exit "$FAIL"; accept_case stale-ref || bad "stale-ref accept"
printf 'move ref\n' > "$CASE_REPO/ref-move"; git -C "$CASE_REPO" add -- ref-move; git -C "$CASE_REPO" commit -qm 'move ref'
RETURNED_HASH="$(sha256_file "$CASE_RETURNED")"; terminal_case stale-ref; RC=$?
if [ "$RC" != 0 ] && [ "$RETURNED_HASH" = "$(sha256_file "$CASE_RETURNED")" ]; then ok "stale ref CAS fails closed and retains exact return"; else bad "stale ref CAS (rc=$RC)"; fi

prepare_case dirty-history folder partial || exit "$FAIL"; accept_case dirty-history || bad "dirty-history accept"
printf 'foreign history\n' > "$CASE_HISTORY"; TARGET_HASH="$(sha256_file "$CASE_HISTORY")"; REF_SNAPSHOT="$(git -C "$CASE_REPO" rev-parse "$REF")"; terminal_case dirty-history; RC=$?
if [ "$RC" != 0 ] && [ "$TARGET_HASH" = "$(sha256_file "$CASE_HISTORY")" ] && [ "$REF_SNAPSHOT" = "$(git -C "$CASE_REPO" rev-parse "$REF")" ]; then ok "dirty target ledger refuses without overwrite or ref movement"; else bad "dirty target ledger refusal (rc=$RC)"; fi

prepare_case live-index-lock folder partial || exit "$FAIL"; accept_case live-index-lock || bad "index-lock accept"
INDEX_SNAPSHOT="$(git -C "$CASE_REPO" write-tree)"; : > "$CASE_COMMON/index.lock"; terminal_case live-index-lock; RC=$?; rm -f "$CASE_COMMON/index.lock"
if [ "$RC" != 0 ] && [ "$INDEX_SNAPSHOT" = "$(git -C "$CASE_REPO" write-tree)" ] && [ -f "$CASE_RETURNED" ]; then ok "live index.lock fails closed without consuming returned evidence or live index"; else bad "live index.lock preservation (rc=$RC)"; fi

prepare_case returned-without-sidecar folder partial || exit "$FAIL"; accept_case returned-without-sidecar || bad "returned-without-sidecar accept"; rm -f "$CASE_RETURNED"; WAL_HASH="$(sha256_file "$CASE_WAL")"
(cd "$CASE_REPO" && bash "$HELPER" recover --entity="$CASE_ENTITY" --stage=plan --lease-token=returned-without-sidecar-token) > "$TMP/returned-without-sidecar.recover" 2>&1; RC=$?
if [ "$RC" != 0 ] && [ "$WAL_HASH" = "$(sha256_file "$CASE_WAL")" ]; then ok "returned WAL without sidecar refuses and preserves WAL"; else bad "returned-without-sidecar refusal (rc=$RC)"; fi

prepare_case sidecar-without-wal folder partial || exit "$FAIL"; accept_case sidecar-without-wal || bad "sidecar-without-wal accept"; rm -f "$CASE_WAL"; RETURNED_HASH="$(sha256_file "$CASE_RETURNED")"
(cd "$CASE_REPO" && bash "$HELPER" recover --entity="$CASE_ENTITY" --stage=plan --lease-token=sidecar-without-wal-token) > "$TMP/sidecar-without-wal.recover" 2>&1; RC=$?
if [ "$RC" != 0 ] && [ "$RETURNED_HASH" = "$(sha256_file "$CASE_RETURNED")" ]; then ok "orphan sidecar refuses and preserves exact bytes"; else bad "sidecar-without-WAL refusal (rc=$RC)"; fi

prepare_case sibling-worktree folder partial || exit "$FAIL"
git -C "$CASE_REPO" worktree add -q "$TMP/sibling" -b sibling-test
WAL_HASH="$(sha256_file "$CASE_WAL")"
(
  cd "$TMP/sibling" || exit 1
  STAGE_ATTEMPT_BOOT_ID_SOURCE="$TMP/sibling-worktree.boot" STAGE_ATTEMPT_MONOTONIC_NS=2000000000 \
    bash "$HELPER" begin --entity="$CASE_ENTITY" --stage=plan --stage-run-id="$(git rev-parse HEAD)" --ref=refs/heads/sibling-test \
      --attempt-before="$(git rev-parse HEAD)" --worker-id=sibling --lease-token=sibling-token --attempt-ordinal=0 \
      --fresh-continuations-used=0 --attempt-started-at=2026-07-22T01:00:01Z
) > "$TMP/sibling.begin" 2>&1; RC=$?
if [ "$RC" != 0 ] && [ "$WAL_HASH" = "$(sha256_file "$CASE_WAL")" ]; then ok "same entity+stage sibling with different run contends on common-Git-dir key"; else bad "sibling exclusion (rc=$RC)"; fi

exit "$FAIL"
