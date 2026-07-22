#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${HERE}/.."
REPO_ROOT="$(git -C "$HERE" rev-parse --show-toplevel)"
HELPER="${LIB}/fo-stage-attempt.sh"
PIN='d939cf9ba5794640a5830440f89bbb82d0b1f16e'
ENTITY='docs/ship-flow/shape-confirm-instance-awareness.md'
LEDGER='docs/ship-flow/shape-confirm-instance-awareness/tdd-ledger.jsonl'
BLOCK1='23aa88f981b8182a1600199bc4e572df508c4ecd00f1befc62f1d60070b57ffc'
BLOCK2='c6cd94e5e8e60443286297193fdff62612a12b67b860b4e5768b82cc08afd00c'
LEDGER_SHA='cf0ee9f001554c8d26216130a40fe6ecf7f39450022c68bf264cdef24cfadffb'
FAIL=0
ok() { printf 'OK %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAIL=1; }
sha256_stream() { if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi; }

if [ ! -f "$HELPER" ]; then
  bad "fo-stage-attempt.sh is missing: pinned #21 immutable hashes, 5580-second legacy seed, and one typed continuation are not implemented"
  exit "$FAIL"
fi
if [ ! -x "$HELPER" ]; then bad "fo-stage-attempt.sh is not executable"; exit "$FAIL"; fi
if ! git -C "$REPO_ROOT" cat-file -e "$PIN^{commit}" 2>/dev/null; then bad "pinned #21 commit is unavailable"; exit "$FAIL"; fi

hash_block() { git -C "$REPO_ROOT" show "$PIN:$ENTITY" | sed -n "$1,${2}p" | sha256_stream; }
hash_path() { git -C "$REPO_ROOT" show "$PIN:$1" | sha256_stream; }
if [ "$(hash_block 607 635)" = "$BLOCK1" ]; then ok "pinned #21 32-minute report block hash is exact"; else bad "pinned #21 32-minute report block drift"; fi
if [ "$(hash_block 637 664)" = "$BLOCK2" ]; then ok "pinned #21 61-minute report block hash is exact"; else bad "pinned #21 61-minute report block drift"; fi
if [ "$(hash_path "$LEDGER")" = "$LEDGER_SHA" ] && [ "$(git -C "$REPO_ROOT" show "$PIN:$LEDGER" | wc -l | tr -d ' ')" = 5 ]; then ok "pinned #21 five-record plan ledger hash is exact"; else bad "pinned #21 ledger drift"; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/stage-attempt-21.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
git clone -q --no-hardlinks "$REPO_ROOT" "$TMP/repo"
git -C "$TMP/repo" checkout -q --detach "$PIN"
git -C "$TMP/repo" switch -q -c stage-attempt-21-test
BEFORE_ENTITY="$(git -C "$TMP/repo" show "HEAD:$ENTITY" | sha256_stream)"
BEFORE_LEDGER="$(git -C "$TMP/repo" show "HEAD:$LEDGER" | sha256_stream)"
(
  cd "$TMP/repo" || exit 1
  bash "$HELPER" seed-legacy --entity="$ENTITY" --stage=plan --stage-run-id="$PIN" \
    --ref=refs/heads/stage-attempt-21-test --report-block=607:635 --report-block=637:664 \
    --ledger="$LEDGER" --cumulative-elapsed-seconds=5580 --observed-at=2026-07-22T04:30:00Z
) > "$TMP/seed.out" 2> "$TMP/seed.err"
RC=$?
HISTORY="$TMP/repo/docs/ship-flow/shape-confirm-instance-awareness.attempt-history-v1.log"
if [ "$RC" = 0 ] && [ -f "$HISTORY" ] && grep -q '^stage-attempt-v1 disposition=legacy-unscoped ' "$HISTORY" && grep -q ' cumulative_elapsed_seconds=5580 precision=minute-reported ' "$HISTORY"; then ok "#21 seeds one exact legacy-unscoped 5580-second baseline"; else bad "#21 legacy seed (rc=$RC)"; fi

AFTER_ENTITY="$(git -C "$TMP/repo" show "HEAD:$ENTITY" | sha256_stream)"
AFTER_LEDGER="$(git -C "$TMP/repo" show "HEAD:$LEDGER" | sha256_stream)"
if [ "$BEFORE_ENTITY" = "$AFTER_ENTITY" ] && [ "$BEFORE_LEDGER" = "$AFTER_LEDGER" ] && [ "$(hash_block 607 635)" = "$BLOCK1" ] && [ "$(hash_block 637 664)" = "$BLOCK2" ]; then ok "legacy seed leaves both receipts and all five ledger records byte-identical"; else bad "#21 seed mutated historical bytes"; fi

DISPATCH="$TMP/dispatch.count"; : > "$DISPATCH"
(
  cd "$TMP/repo" || exit 1
  STAGE_ATTEMPT_DISPATCH_COUNT_FILE="$DISPATCH" bash "$HELPER" continue --entity="$ENTITY" --stage=plan \
    --stage-run-id="$PIN" --ref=refs/heads/stage-attempt-21-test --prior-outcome=partial \
    --prior-elapsed-seconds=5580 --fresh-continuations-used=0 --worker-id=issue-21-worker \
    --lease-token=issue-21-token --attempt-started-at=2026-07-22T04:31:00Z
) > "$TMP/continue.out" 2> "$TMP/continue.err"
RC=$?
FIRST_DISPATCH_COUNT="$(wc -l < "$DISPATCH" | tr -d ' ')"
FIRST_DISPATCH_SHA="$(sha256_stream < "$DISPATCH")"
if [ "$RC" = 0 ] && [ "$FIRST_DISPATCH_COUNT" = 1 ] && grep -q 'fresh_continuations_used=1' "$TMP/continue.out" && grep -q 'budget_seconds=1200' "$TMP/continue.out"; then ok "legacy partial grants exactly one typed plan continuation despite cumulative 5580 seconds"; else bad "#21 typed continuation (rc=$RC dispatches=$FIRST_DISPATCH_COUNT)"; fi
cp "$DISPATCH" "$TMP/first-dispatch.evidence"
: > "$DISPATCH"

LINES_BEFORE="$(wc -l < "$HISTORY" | tr -d ' ')"
(
  cd "$TMP/repo" || exit 1
  STAGE_ATTEMPT_DISPATCH_COUNT_FILE="$DISPATCH" bash "$HELPER" continue --entity="$ENTITY" --stage=plan \
    --stage-run-id="$PIN" --ref=refs/heads/stage-attempt-21-test --prior-outcome=partial \
    --prior-elapsed-seconds=1 --fresh-continuations-used=1 --worker-id=issue-21-worker \
    --lease-token=issue-21-token-2 --attempt-started-at=2026-07-22T04:31:01Z
) > "$TMP/exhausted.out" 2>&1
RC=$?
LINES_AFTER="$(wc -l < "$HISTORY" | tr -d ' ')"
if [ "$RC" != 0 ] && [ "$LINES_AFTER" = $((LINES_BEFORE + 1)) ] && grep -q 'route=return reason=attempt-count-exhausted' "$TMP/exhausted.out" && [ ! -s "$DISPATCH" ] && [ "$FIRST_DISPATCH_SHA" = "$(sha256_stream < "$TMP/first-dispatch.evidence")" ]; then ok "#21 second fresh request adds one route-out with zero additional dispatch (exactly one total)"; else bad "#21 bounded route-out (rc=$RC before=$LINES_BEFORE after=$LINES_AFTER second_dispatch_bytes=$(wc -c < "$DISPATCH" | tr -d ' '))"; fi

exit "$FAIL"
