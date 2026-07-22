#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${HERE}/../fo-stage-attempt.sh"
FAIL=0
ok() { printf 'OK %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAIL=1; }

if [ ! -f "$HELPER" ]; then
  bad "fo-stage-attempt.sh is missing: strict budget, exhausted/blocked/failed return-before-dispatch routes are not implemented"
  exit "$FAIL"
fi
if [ ! -x "$HELPER" ]; then bad "fo-stage-attempt.sh is not executable"; exit "$FAIL"; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/stage-attempt-route.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
REF='refs/heads/main'
mkdir -p "$REPO/docs/route-flow"
for LABEL in at-budget exhausted blocked failed passed interrupted; do
  mkdir -p "$REPO/docs/route-flow/$LABEL"
  printf '%s\n' '---' "id: $LABEL" 'status: plan' 'stage_outputs: {}' '---' > "$REPO/docs/route-flow/$LABEL/index.md"
done
(
  cd "$REPO" || exit 1
  git init -q -b main
  git config user.name test
  git config user.email test@example.invalid
  git add -- docs
  git commit -qm fixture
)
HEAD_OID="$(git -C "$REPO" rev-parse HEAD)"
COMMON="$(git -C "$REPO" rev-parse --git-common-dir)"; case "$COMMON" in /*) ;; *) COMMON="$REPO/$COMMON" ;; esac
DISPATCH="$TMP/dispatch.count"; ENVELOPE="$TMP/envelope"; ARTIFACT=''

run_continue() {
  local label="$1" outcome="$2" elapsed="$3" used="$4" entity="docs/route-flow/$1/index.md"
  ARTIFACT="$REPO/docs/route-flow/$label/plan.md"
  : > "$DISPATCH"; rm -f "$ENVELOPE" "$ARTIFACT"
  (
    cd "$REPO" || exit 1
    STAGE_ATTEMPT_DISPATCH_COUNT_FILE="$DISPATCH" \
      bash "$HELPER" continue --entity="$entity" --stage=plan --stage-run-id="$HEAD_OID" \
        --ref="$REF" --prior-outcome="$outcome" --prior-elapsed-seconds="$elapsed" \
        --fresh-continuations-used="$used" --worker-id=route-worker \
        --lease-token=route-token --attempt-started-at=2026-07-22T04:00:00Z \
        --envelope="$ENVELOPE" --artifact="$ARTIFACT"
  )
}

terminalize_active() {
  local label="$1" entity="docs/route-flow/$1/index.md"
  (
    cd "$REPO" || exit 1
    bash "$HELPER" interrupt --entity="$entity" --stage=plan --observed-at=2026-07-22T04:00:01Z
  ) > "$TMP/$label.cleanup" 2>&1
  local rc=$?
  local wal_count
  wal_count="$(find "$COMMON/spacedock-stage-attempt-v1" -name '*.wal' -type f 2>/dev/null | wc -l | tr -d ' ')"
  if [ "$rc" = 0 ] && [ "$wal_count" = 0 ]; then ok "$label allowed continuation terminalizes and cleans its WAL"; else bad "$label continuation cleanup (rc=$rc wal=$wal_count)"; fi
}

run_continue at-budget partial 1200 0 > "$TMP/at-budget.out" 2>&1
RC=$?
if [ "$RC" = 0 ] && [ -s "$DISPATCH" ]; then ok "elapsed equal to 1200 permits the one fresh plan continuation"; else bad "strict plan budget boundary (rc=$RC)"; fi
terminalize_active at-budget

run_continue exhausted partial 1201 1 > "$TMP/exhausted.out" 2>&1
RC=$?
WAL_COUNT="$(find "$COMMON/spacedock-stage-attempt-v1" -name '*.wal' -type f 2>/dev/null | wc -l | tr -d ' ')"
if [ "$RC" != 0 ] && grep -q 'stage-circuit-v1 disposition=route-out ' "$TMP/exhausted.out" && grep -q 'fresh_continuations_used=1 fresh_continuations_limit=1 route=return reason=attempt-count-exhausted' "$TMP/exhausted.out" && [ ! -s "$DISPATCH" ] && [ ! -e "$ENVELOPE" ] && [ ! -e "$ARTIFACT" ] && [ "$WAL_COUNT" = 0 ]; then
  ok "threshold plus one with exhausted continuation routes return before lease, envelope, artifact, or dispatch"
else bad "exhausted no-dispatch route (rc=$RC wal=$WAL_COUNT)"; fi

for OUTCOME in blocked failed; do
  run_continue "$OUTCOME" "$OUTCOME" 1 0 > "$TMP/$OUTCOME.out" 2>&1
  RC=$?
  if [ "$RC" != 0 ] && grep -q 'route=return' "$TMP/$OUTCOME.out" && [ ! -s "$DISPATCH" ] && [ ! -e "$ENVELOPE" ] && [ ! -e "$ARTIFACT" ]; then ok "$OUTCOME routes return immediately with zero dispatch side effects"; else bad "$OUTCOME immediate route (rc=$RC)"; fi
done

run_continue passed passed 1 0 > "$TMP/passed.out" 2>&1
RC=$?
if [ "$RC" != 0 ] && [ ! -s "$DISPATCH" ]; then ok "passed does not create a continuation"; else bad "passed incorrectly continued (rc=$RC)"; fi

run_continue interrupted interrupted 1 0 > "$TMP/interrupted.out" 2>&1
RC=$?
if [ "$RC" = 0 ] && [ -s "$DISPATCH" ]; then ok "interrupted permits exactly one fresh continuation"; else bad "interrupted continuation (rc=$RC)"; fi
terminalize_active interrupted

HISTORY="$REPO/docs/route-flow/exhausted/attempt-history-v1.log"
LINES_BEFORE=0; [ ! -f "$HISTORY" ] || LINES_BEFORE="$(wc -l < "$HISTORY" | tr -d ' ')"
run_continue exhausted partial 1201 1 > "$TMP/replay.out" 2>&1
RC=$?
LINES_AFTER=0; [ ! -f "$HISTORY" ] || LINES_AFTER="$(wc -l < "$HISTORY" | tr -d ' ')"
if [ "$RC" != 0 ] && [ "$LINES_BEFORE" = "$LINES_AFTER" ]; then ok "route-out replay is idempotent and adds no second route line"; else bad "route-out replay idempotency (before=$LINES_BEFORE after=$LINES_AFTER rc=$RC)"; fi

exit "$FAIL"
