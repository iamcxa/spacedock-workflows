#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${HERE}/.."
HELPER="${LIB}/fo-stage-attempt.sh"
FAIL=0

ok() { printf 'OK %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAIL=1; }
sha256_stream() { if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'; else shasum -a 256 | awk '{print $1}'; fi; }
sha256_file() { if command -v sha256sum >/dev/null 2>&1; then sha256sum "$1" | awk '{print $1}'; else shasum -a 256 "$1" | awk '{print $1}'; fi; }
hex() { LC_ALL=C od -An -v -t x1 | tr -d ' \n'; }

if [ ! -f "$HELPER" ]; then
  bad "fo-stage-attempt.sh is missing: exact stage-attempt-v1 protocol, plan/execute allowlist, and completion-v1 framing are not implemented"
  exit "$FAIL"
fi
if [ ! -x "$HELPER" ]; then
  bad "fo-stage-attempt.sh is not executable"
  exit "$FAIL"
fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/stage-attempt-contract.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT
REPO="$TMP/repo"
ENTITY='docs/test-flow/item/index.md'
REF='refs/heads/main'
WORKER='contract-worker'
TOKEN='contract-secret-token'
STARTED='2026-07-22T01:02:03Z'
BOOT="$TMP/boot-id"
BOOT_VALUE='11111111-2222-3333-4444-555555555555'
printf '%s\n' "$BOOT_VALUE" > "$BOOT"

mkdir -p "$REPO/docs/test-flow/item"
cat > "$REPO/docs/test-flow/README.md" <<'EOF'
---
stages:
  states:
    - name: plan
    - name: execute
---
EOF
cat > "$REPO/$ENTITY" <<'EOF'
---
id: item
status: plan
stage_outputs:
  plan: plan.md
---
# Contract fixture
EOF
printf '# Plan\n' > "$REPO/docs/test-flow/item/plan.md"
cat > "$REPO/docs/test-flow/flat.md" <<'EOF'
---
id: flat
status: plan
stage_outputs: {}
---
# Flat contract fixture
EOF
printf '# Flat plan\n' > "$REPO/docs/test-flow/flat-plan.md"
(
  cd "$REPO" || exit 1
  git init -q -b main
  git config user.name test
  git config user.email test@example.invalid
  git add -- docs
  git commit -qm fixture
)
HEAD_OID="$(git -C "$REPO" rev-parse HEAD)"
GIT_COMMON="$(git -C "$REPO" rev-parse --git-common-dir)"
case "$GIT_COMMON" in /*) ;; *) GIT_COMMON="$REPO/$GIT_COMMON" ;; esac
ENTITY_HEX="$(printf '%s' "$ENTITY" | hex)"
REF_HEX="$(printf '%s' "$REF" | hex)"
WORKER_HEX="$(printf '%s' "$WORKER" | hex)"
KEY="$(printf 'stage-attempt-v1-key\0%s\0plan' "$ENTITY" | sha256_stream)"
LEASE_SHA="$(printf '%s' "$TOKEN" | sha256_stream)"
BOOT_SHA="$(printf '%s' "$BOOT_VALUE" | sha256_stream)"
ATTEMPT_HASH="$(printf 'stage-attempt-v1-attempt\0%s\0%s\0%s\0%s\0%s\0%s' "$KEY" "$HEAD_OID" "$REF" "$HEAD_OID" 0 "$TOKEN" | sha256_stream)"
ATTEMPT_ID="sa1-$ATTEMPT_HASH"
WAL="$GIT_COMMON/spacedock-stage-attempt-v1/$KEY.wal"
RETURNED="$GIT_COMMON/spacedock-stage-attempt-v1/$KEY.returned"

COMPLETION_BEFORE="$(sha256_file "$LIB/completion-v1.sh")"
(
  cd "$REPO" || exit 1
  STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=1000000000 \
    bash "$HELPER" begin --entity="$ENTITY" --stage=plan --stage-run-id="$HEAD_OID" \
      --ref="$REF" --attempt-before="$HEAD_OID" --worker-id="$WORKER" \
      --lease-token="$TOKEN" --attempt-ordinal=0 --fresh-continuations-used=0 \
      --attempt-started-at="$STARTED" > "$TMP/begin.out" 2> "$TMP/begin.err"
)
RC=$?
if [ "$RC" = 0 ] && [ -f "$WAL" ]; then ok "begin creates the canonical common-Git-dir WAL"; else bad "begin creates canonical WAL (rc=$RC)"; fi

EXPECTED_WAL="$TMP/expected.wal"
printf 'stage-attempt-wal-v1 entity_stage_key=%s entity_path_hex=%s stage=plan stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=0 attempt_started_at=%s boot_id_sha256=%s monotonic_started_ns=1000000000 budget_seconds=1200 state=open fresh_continuations_used=0 returned_bundle_sha256=none\n' \
  "$KEY" "$ENTITY_HEX" "$HEAD_OID" "$REF_HEX" "$HEAD_OID" "$WORKER_HEX" "$LEASE_SHA" "$ATTEMPT_ID" "$STARTED" "$BOOT_SHA" > "$EXPECTED_WAL"
if [ -f "$WAL" ] && cmp -s "$EXPECTED_WAL" "$WAL"; then ok "WAL bytes, field order, IDs, hashes, and trailing LF are exact"; else bad "WAL exact-byte contract"; [ -f "$WAL" ] && diff -u "$EXPECTED_WAL" "$WAL" || true; fi

for STAGE in shape design verify review ship PLAN Execute ''; do
  OUT="$TMP/allow-${STAGE:-empty}.out"
  (
    cd "$REPO" || exit 1
    STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=2000000000 \
      bash "$HELPER" begin --entity="$ENTITY" --stage="$STAGE" --stage-run-id="$HEAD_OID" \
        --ref="$REF" --attempt-before="$HEAD_OID" --worker-id="$WORKER" \
        --lease-token="reject-$STAGE" --attempt-ordinal=0 --fresh-continuations-used=0 \
        --attempt-started-at="$STARTED" > "$OUT" 2>&1
  )
  RC=$?
  if [ "$RC" != 0 ]; then ok "closed stage allowlist rejects '${STAGE:-empty}'"; else bad "closed stage allowlist accepted '${STAGE:-empty}'"; fi
done

TERMINAL_HASH="$(printf 'stage-attempt-v1-terminal\0%s\0%s\0%s' "$KEY" "$HEAD_OID" "$ATTEMPT_ID" | sha256_stream)"
TERMINAL_ID="sev1-$TERMINAL_HASH"
COMPLETION_LINE="completion-v1 disposition=already-registered ref=$REF before=$HEAD_OID completion=$HEAD_OID entity=$ENTITY stage=plan artifact=plan.md"
COMPLETION_SHA="$(printf '%s\n' "$COMPLETION_LINE" | sha256_stream)"
BUNDLE="$TMP/return.bundle"
printf 'stage-attempt-v1 entity_stage_key=%s entity_path_hex=%s stage=plan stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_completion_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=0 attempt_started_at=%s budget_seconds=1200 attempt_elapsed_seconds=17 fresh_continuations_used=0 outcome=passed artifact_path_hex=%s artifact_oid=%s completion_receipt_sha256=%s terminal_event_id=%s\ncompletion-v1-begin\n%s\ncompletion-v1-end\n' \
  "$KEY" "$ENTITY_HEX" "$HEAD_OID" "$REF_HEX" "$HEAD_OID" "$HEAD_OID" "$WORKER_HEX" "$LEASE_SHA" "$ATTEMPT_ID" "$STARTED" \
  "$(printf 'plan.md' | hex)" "$(git -C "$REPO" rev-parse HEAD:docs/test-flow/item/plan.md)" "$COMPLETION_SHA" "$TERMINAL_ID" "$COMPLETION_LINE" > "$BUNDLE"
(
  cd "$REPO" || exit 1
  bash "$HELPER" accept-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$BUNDLE" > "$TMP/return.out" 2> "$TMP/return.err"
)
RC=$?
if [ "$RC" = 0 ] && [ -f "$RETURNED" ] && cmp -s "$BUNDLE" "$RETURNED"; then ok "passed folder return persists the exact outer receipt and unchanged completion-v1 frame"; else bad "exact returned bundle persistence (rc=$RC)"; fi
if [ -f "$WAL" ] && grep -q " state=returned fresh_continuations_used=0 returned_bundle_sha256=$(sha256_file "$BUNDLE")$" "$WAL"; then ok "returned WAL binds the whole exact bundle digest"; else bad "returned WAL whole-bundle binding"; fi

reset_folder_open() {
  cp "$EXPECTED_WAL" "$WAL"
  rm -f "$RETURNED"
}

for KIND in extra-field missing-frame extra-frame bad-completion-hash cr-byte tab-byte; do
  reset_folder_open
  CASE="$TMP/$KIND.bundle"
  cp "$BUNDLE" "$CASE"
  case "$KIND" in
    extra-field) perl -0pi -e 's/ terminal_event_id=/ retry=yes terminal_event_id=/' "$CASE"; REASON=grammar ;;
    missing-frame) perl -0pi -e 's/completion-v1-begin\n//' "$CASE"; REASON=completion-frame ;;
    extra-frame) printf 'extra\n' >> "$CASE"; REASON=completion-frame ;;
    bad-completion-hash) perl -0pi -e 's/completion_receipt_sha256=[0-9a-f]{64}/completion_receipt_sha256=aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa/' "$CASE"; REASON=completion-hash ;;
    cr-byte) perl -0pi -e 's/stage=plan/stage=plan\r/' "$CASE"; REASON=ascii-grammar ;;
    tab-byte) perl -0pi -e 's/stage=plan/stage=\tplan/' "$CASE"; REASON=ascii-grammar ;;
  esac
  (
    cd "$REPO" || exit 1
    bash "$HELPER" validate-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$CASE" > "$TMP/$KIND.out" 2>&1
  )
  RC=$?
  if [ "$RC" != 0 ] && grep -Fq "stage-attempt-v1[2]: invalid returned bundle: $REASON" "$TMP/$KIND.out" && cmp -s "$EXPECTED_WAL" "$WAL" && [ ! -e "$RETURNED" ]; then
    ok "open-WAL return parser rejects $KIND for $REASON and preserves state"
  else bad "return parser fail-closed for $KIND/$REASON (rc=$RC)"; fi
done

reset_folder_open
PARTIAL="$TMP/folder-partial.bundle"
sed -e 's/attempt_elapsed_seconds=17/attempt_elapsed_seconds=18/' \
    -e 's/outcome=passed/outcome=partial/' \
    -e "s/completion_receipt_sha256=$COMPLETION_SHA/completion_receipt_sha256=none/" \
    "$BUNDLE" | sed '/^completion-v1-begin$/,$d' > "$PARTIAL"
(
  cd "$REPO" || exit 1
  bash "$HELPER" accept-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$PARTIAL" > "$TMP/partial.out" 2>&1
)
RC=$?
if [ "$RC" = 0 ] && cmp -s "$PARTIAL" "$RETURNED" && grep -q 'completion_receipt_sha256=none ' "$RETURNED"; then ok "non-passed folder accepts none with no completion frame"; else bad "non-passed folder no-frame acceptance (rc=$RC)"; fi
reset_folder_open
cp "$PARTIAL" "$TMP/partial-forbidden-frame.bundle"
printf 'completion-v1-begin\n%s\ncompletion-v1-end\n' "$COMPLETION_LINE" >> "$TMP/partial-forbidden-frame.bundle"
(
  cd "$REPO" || exit 1
  bash "$HELPER" validate-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$TMP/partial-forbidden-frame.bundle" > "$TMP/partial-forbidden.out" 2>&1
)
RC=$?
if [ "$RC" != 0 ] && grep -Fq 'stage-attempt-v1[2]: invalid returned bundle: forbidden-completion-frame' "$TMP/partial-forbidden.out" && cmp -s "$EXPECTED_WAL" "$WAL"; then ok "non-passed folder rejects every completion frame"; else bad "non-passed forbidden frame (rc=$RC)"; fi

FLAT_ENTITY='docs/test-flow/flat.md'
FLAT_ENTITY_HEX="$(printf '%s' "$FLAT_ENTITY" | hex)"
FLAT_KEY="$(printf 'stage-attempt-v1-key\0%s\0plan' "$FLAT_ENTITY" | sha256_stream)"
FLAT_ATTEMPT_HASH="$(printf 'stage-attempt-v1-attempt\0%s\0%s\0%s\0%s\0%s\0%s' "$FLAT_KEY" "$HEAD_OID" "$REF" "$HEAD_OID" 0 flat-token | sha256_stream)"
FLAT_ATTEMPT_ID="sa1-$FLAT_ATTEMPT_HASH"
FLAT_TERMINAL_ID="sev1-$(printf 'stage-attempt-v1-terminal\0%s\0%s\0%s' "$FLAT_KEY" "$HEAD_OID" "$FLAT_ATTEMPT_ID" | sha256_stream)"
(
  cd "$REPO" || exit 1
  STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=3000000000 \
    bash "$HELPER" begin --entity="$FLAT_ENTITY" --stage=plan --stage-run-id="$HEAD_OID" --ref="$REF" \
      --attempt-before="$HEAD_OID" --worker-id=flat-worker --lease-token=flat-token --attempt-ordinal=0 \
      --fresh-continuations-used=0 --attempt-started-at="$STARTED" > "$TMP/flat.begin" 2> "$TMP/flat.err"
)
RC=$?
FLAT_WAL="$GIT_COMMON/spacedock-stage-attempt-v1/$FLAT_KEY.wal"
FLAT_RETURNED="$GIT_COMMON/spacedock-stage-attempt-v1/$FLAT_KEY.returned"
FLAT_OPEN="$TMP/flat.open.wal"; [ ! -f "$FLAT_WAL" ] || cp "$FLAT_WAL" "$FLAT_OPEN"
FLAT_BUNDLE="$TMP/flat.bundle"
printf 'stage-attempt-v1 entity_stage_key=%s entity_path_hex=%s stage=plan stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_completion_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=0 attempt_started_at=%s budget_seconds=1200 attempt_elapsed_seconds=19 fresh_continuations_used=0 outcome=failed artifact_path_hex=%s artifact_oid=%s completion_receipt_sha256=none terminal_event_id=%s\n' \
  "$FLAT_KEY" "$FLAT_ENTITY_HEX" "$HEAD_OID" "$REF_HEX" "$HEAD_OID" "$HEAD_OID" "$(printf flat-worker | hex)" "$(printf flat-token | sha256_stream)" "$FLAT_ATTEMPT_ID" "$STARTED" "$(printf flat-plan.md | hex)" "$(git -C "$REPO" rev-parse HEAD:docs/test-flow/flat-plan.md)" "$FLAT_TERMINAL_ID" > "$FLAT_BUNDLE"
(
  cd "$REPO" || exit 1
  bash "$HELPER" accept-return --entity="$FLAT_ENTITY" --stage=plan --lease-token=flat-token --bundle="$FLAT_BUNDLE" > "$TMP/flat.return.out" 2>&1
)
ACCEPT_RC=$?
if [ "$RC" = 0 ] && [ "$ACCEPT_RC" = 0 ] && cmp -s "$FLAT_BUNDLE" "$FLAT_RETURNED"; then ok "flat entity accepts none with no completion frame"; else bad "flat no-frame acceptance (begin=$RC accept=$ACCEPT_RC)"; fi
cp "$FLAT_OPEN" "$FLAT_WAL"; rm -f "$FLAT_RETURNED"
cp "$FLAT_BUNDLE" "$TMP/flat-forbidden-frame.bundle"; printf 'completion-v1-begin\n%s\ncompletion-v1-end\n' "$COMPLETION_LINE" >> "$TMP/flat-forbidden-frame.bundle"
(
  cd "$REPO" || exit 1
  bash "$HELPER" validate-return --entity="$FLAT_ENTITY" --stage=plan --lease-token=flat-token --bundle="$TMP/flat-forbidden-frame.bundle" > "$TMP/flat-forbidden.out" 2>&1
)
RC=$?
if [ "$RC" != 0 ] && grep -Fq 'stage-attempt-v1[2]: invalid returned bundle: forbidden-completion-frame' "$TMP/flat-forbidden.out" && cmp -s "$FLAT_OPEN" "$FLAT_WAL"; then ok "flat entity rejects every completion frame"; else bad "flat forbidden frame (rc=$RC)"; fi

COMPLETION_AFTER="$(sha256_file "$LIB/completion-v1.sh")"
if [ "$COMPLETION_BEFORE" = "$COMPLETION_AFTER" ]; then ok "completion-v1 implementation bytes remain frozen"; else bad "completion-v1 implementation bytes changed"; fi

exit "$FAIL"
