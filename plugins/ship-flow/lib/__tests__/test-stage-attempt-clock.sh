#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${HERE}/../fo-stage-attempt.sh"
FAIL=0
ok() { printf 'OK %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAIL=1; }

if [ ! -f "$HELPER" ]; then
  bad "fo-stage-attempt.sh is missing: FO fresh/resume identity and boot-bound monotonic clock behavior are not implemented"
  exit "$FAIL"
fi
if [ ! -x "$HELPER" ]; then bad "fo-stage-attempt.sh is not executable"; exit "$FAIL"; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/stage-attempt-clock.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
ENTITY='docs/clock-flow/item/index.md'
REF='refs/heads/main'
BOOT="$TMP/boot-id"
printf '%s\n' 'aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee' > "$BOOT"
mkdir -p "$REPO/docs/clock-flow/item"
printf '%s\n' '---' 'id: item' 'status: plan' 'stage_outputs: {}' '---' > "$REPO/$ENTITY"
(
  cd "$REPO" || exit 1
  git init -q -b main
  git config user.name test
  git config user.email test@example.invalid
  git add -- docs
  git commit -qm fixture
)
HEAD_OID="$(git -C "$REPO" rev-parse HEAD)"

begin() {
  local stage="$1" ordinal="$2" used="$3" token="$4" ns="$5" started="$6"
  (
    cd "$REPO" || exit 1
    STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS="$ns" \
      bash "$HELPER" begin --entity="$ENTITY" --stage="$stage" --stage-run-id="$HEAD_OID" \
        --ref="$REF" --attempt-before="$HEAD_OID" --worker-id=clock-worker \
        --lease-token="$token" --attempt-ordinal="$ordinal" --fresh-continuations-used="$used" \
        --attempt-started-at="$started"
  )
}

for SPEC in 'plan:1200' 'execute:1800'; do
  STAGE="${SPEC%%:*}"; BUDGET="${SPEC#*:}"
  begin "$STAGE" 0 0 "$STAGE-token" 1000000000 2026-07-22T02:00:00Z > "$TMP/$STAGE.begin" 2> "$TMP/$STAGE.err"
  RC=$?
  if [ "$RC" = 0 ] && grep -q "budget_seconds=$BUDGET" "$TMP/$STAGE.begin"; then ok "$STAGE fresh attempt receives FO budget $BUDGET"; else bad "$STAGE fresh begin/budget (rc=$RC)"; fi
  (
    cd "$REPO" || exit 1
    STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=$((1000000000 + BUDGET * 1000000000)) \
      bash "$HELPER" elapsed --entity="$ENTITY" --stage="$STAGE"
  ) > "$TMP/$STAGE.boundary" 2>&1
  RC=$?
  if [ "$RC" = 0 ] && grep -qx "stage-attempt-v1 elapsed_seconds=$BUDGET expired=no" "$TMP/$STAGE.boundary"; then ok "$STAGE strict boundary is not expired at budget"; else bad "$STAGE exact budget clock boundary"; fi
  (
    cd "$REPO" || exit 1
    STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=$((1000000000 + (BUDGET + 1) * 1000000000)) \
      bash "$HELPER" elapsed --entity="$ENTITY" --stage="$STAGE"
  ) > "$TMP/$STAGE.over" 2>&1
  RC=$?
  if [ "$RC" = 0 ] && grep -qx "stage-attempt-v1 elapsed_seconds=$((BUDGET + 1)) expired=yes" "$TMP/$STAGE.over"; then ok "$STAGE expires only at threshold plus one"; else bad "$STAGE threshold-plus-one clock"; fi
  (
    cd "$REPO" || exit 1
    bash "$HELPER" interrupt --entity="$ENTITY" --stage="$STAGE" --observed-at=2026-07-22T02:30:01Z >/dev/null
  ) || bad "$STAGE fixture interrupt"
done

begin plan 1 1 fresh-token 9000000000 2026-07-22T03:00:00Z > "$TMP/fresh.out" 2> "$TMP/fresh.err"
RC=$?
if [ "$RC" = 0 ] && grep -q 'attempt_ordinal=1' "$TMP/fresh.out" && grep -q 'fresh_continuations_used=1' "$TMP/fresh.out"; then ok "fresh continuation increments ordinal and continuation count exactly once"; else bad "fresh continuation identity (rc=$RC)"; fi

(
  cd "$REPO" || exit 1
  bash "$HELPER" suspend --entity="$ENTITY" --stage=plan --lease-token=fresh-token
) > "$TMP/suspend.out" 2>&1
RC=$?
WAL_BEFORE="$(find "$(git -C "$REPO" rev-parse --git-common-dir)" -name '*.wal' -type f -maxdepth 3 -exec cat {} \; 2>/dev/null || true)"
(
  cd "$REPO" || exit 1
  STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=11000000000 \
    bash "$HELPER" resume --entity="$ENTITY" --stage=plan --lease-token=fresh-token
) > "$TMP/resume.out" 2>&1
RESUME_RC=$?
WAL_AFTER="$(find "$(git -C "$REPO" rev-parse --git-common-dir)" -name '*.wal' -type f -maxdepth 3 -exec cat {} \; 2>/dev/null || true)"
if [ "$RC" = 0 ] && [ "$RESUME_RC" = 0 ] && printf '%s' "$WAL_BEFORE" | grep -q ' state=suspended ' && printf '%s' "$WAL_AFTER" | grep -q ' state=open ' && printf '%s' "$WAL_AFTER" | grep -q 'attempt_ordinal=1 .*fresh_continuations_used=1'; then
  ok "same-boot suspend/resume preserves attempt identity, origin, budget, ordinal, and continuation count"
else bad "same-boot suspend/resume exact preservation"; fi

clock_fault() {
  local label="$1" source_mode="$2" resume_ns="$3" diagnostic="$4"
  local repo="$TMP/$label-repo" source="$TMP/$label-boot" entity='docs/clock-fault/item/index.md' head rc
  mkdir -p "$repo/docs/clock-fault/item"
  printf '%s\n' '---' 'id: item' 'status: plan' 'stage_outputs: {}' '---' > "$repo/$entity"
  (
    cd "$repo" || exit 1
    git init -q -b main
    git config user.name test
    git config user.email test@example.invalid
    git add -- docs
    git commit -qm fixture
  )
  head="$(git -C "$repo" rev-parse HEAD)"
  printf '%s\n' '22222222-3333-4444-5555-666666666666' > "$source"
  (
    cd "$repo" || exit 1
    STAGE_ATTEMPT_BOOT_ID_SOURCE="$source" STAGE_ATTEMPT_MONOTONIC_NS=5000000000 \
      bash "$HELPER" begin --entity="$entity" --stage=plan --stage-run-id="$head" --ref=refs/heads/main \
        --attempt-before="$head" --worker-id="$label-worker" --lease-token="$label-token" \
        --attempt-ordinal=0 --fresh-continuations-used=0 --attempt-started-at=2026-07-22T03:10:00Z >/dev/null
    bash "$HELPER" suspend --entity="$entity" --stage=plan --lease-token="$label-token" >/dev/null
  ) || { bad "$label clock fixture setup"; return; }
  case "$source_mode" in
    missing) rm -f "$source" ;;
    unparseable) printf '%s\n' 'not a boot identity' > "$source" ;;
    foreign) printf '%s\n' 'ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb' > "$source" ;;
    same) ;;
  esac
  (
    cd "$repo" || exit 1
    STAGE_ATTEMPT_BOOT_ID_SOURCE="$source" STAGE_ATTEMPT_MONOTONIC_NS="$resume_ns" \
      bash "$HELPER" resume --entity="$entity" --stage=plan --lease-token="$label-token"
  ) > "$TMP/$label.out" 2>&1
  rc=$?
  if [ "$rc" != 0 ] && grep -q 'outcome=interrupted' "$TMP/$label.out" && grep -Fq "$diagnostic" "$TMP/$label.out"; then
    ok "$label fails closed as interrupted without wall-clock fallback"
  else bad "$label interrupted clock contract (rc=$rc)"; fi
}

clock_fault missing-clock-source missing 6000000000 'stage-attempt-v1[5]: clock identity loss; terminalized interrupted'
clock_fault unparseable-clock-source unparseable 6000000000 'stage-attempt-v1[5]: clock identity loss; terminalized interrupted'
clock_fault changed-boot-identity foreign 6000000000 'stage-attempt-v1[5]: clock identity loss; terminalized interrupted'
clock_fault monotonic-regression same 4000000000 'stage-attempt-v1[5]: monotonic regression; terminalized interrupted'

exit "$FAIL"
