#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB="${HERE}/.."
HELPER="${LIB}/fo-stage-attempt.sh"
FAIL=0
CONTRACT_CASE="${STAGE_ATTEMPT_CONTRACT_CASE:-baseline}"
MALFORMED_CASE="${STAGE_ATTEMPT_INVALID_CASE:-all}"
QUALITY_CASE="${STAGE_ATTEMPT_QUALITY_CASE:-all}"
FEEDBACK_CASE="${STAGE_ATTEMPT_FEEDBACK_CASE:-none}"

case "$CONTRACT_CASE" in
  baseline|foreign-stage-run|foreign-ref|foreign-before|foreign-worker-completion|foreign-worker|foreign-lease|foreign-attempt) ;;
  *) printf 'FAIL unknown STAGE_ATTEMPT_CONTRACT_CASE: %s\n' "$CONTRACT_CASE"; exit 1 ;;
esac
case "$MALFORMED_CASE" in
  all|none|extra-field|missing-frame|extra-frame|bad-completion-hash|cr-byte|tab-byte|completion-trailing-space|completion-non-ascii|wrong-terminal-event-id) ;;
  *) printf 'FAIL unknown STAGE_ATTEMPT_INVALID_CASE: %s\n' "$MALFORMED_CASE"; exit 1 ;;
esac
case "$QUALITY_CASE" in
  all|none|exclusion-lock|bundle-snapshot|returned-state) ;;
  *) printf 'FAIL unknown STAGE_ATTEMPT_QUALITY_CASE: %s\n' "$QUALITY_CASE"; exit 1 ;;
esac
case "$FEEDBACK_CASE" in
  none|lifecycle-open|completion-cross-binding|canonical-entity|canonical-wal|artifact-tree-binding|canonical-ref|derived-attempt|artifact-all-outcomes) ;;
  *) printf 'FAIL unknown STAGE_ATTEMPT_FEEDBACK_CASE: %s\n' "$FEEDBACK_CASE"; exit 1 ;;
esac

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
  STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=18000000000 \
    bash "$HELPER" accept-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$BUNDLE" > "$TMP/return.out" 2> "$TMP/return.err"
)
RC=$?
if [ "$RC" = 0 ] && [ -f "$RETURNED" ] && cmp -s "$BUNDLE" "$RETURNED"; then ok "passed folder return persists the exact outer receipt and unchanged completion-v1 frame"; else bad "exact returned bundle persistence (rc=$RC)"; fi
if [ -f "$WAL" ] && grep -q " state=returned fresh_continuations_used=0 returned_bundle_sha256=$(sha256_file "$BUNDLE")$" "$WAL"; then ok "returned WAL binds the whole exact bundle digest"; else bad "returned WAL whole-bundle binding"; fi

reset_folder_open() {
  cp "$EXPECTED_WAL" "$WAL"
  rm -f "$RETURNED"
}

refresh_completion_hash() {
  local bundle="$1" receipt_sha
  receipt_sha="$(sed -n '3p' "$bundle" | sha256_stream)"
  perl -0pi -e "s/completion_receipt_sha256=[0-9a-f]{64}/completion_receipt_sha256=$receipt_sha/" "$bundle"
}

for KIND in extra-field missing-frame extra-frame bad-completion-hash cr-byte tab-byte completion-trailing-space completion-non-ascii wrong-terminal-event-id; do
  [ "$MALFORMED_CASE" = all ] || [ "$MALFORMED_CASE" = "$KIND" ] || continue
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
    completion-trailing-space) perl -0pi -e 's/(completion-v1 disposition=[^\n]+)\ncompletion-v1-end\n/$1 \ncompletion-v1-end\n/' "$CASE"; refresh_completion_hash "$CASE"; REASON=completion-frame ;;
    completion-non-ascii) perl -0pi -e 's/(completion-v1 disposition=[^\n]* artifact=plan)\.md\n/$1\xC3\xA9.md\n/' "$CASE"; refresh_completion_hash "$CASE"; REASON=ascii-grammar ;;
    wrong-terminal-event-id) perl -0pi -e 's/terminal_event_id=sev1-[0-9a-f]{64}/terminal_event_id=sev1-cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc/' "$CASE"; REASON=terminal-event-id ;;
  esac
  (
    cd "$REPO" || exit 1
    bash "$HELPER" validate-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$CASE" > "$TMP/$KIND.out" 2>&1
  )
  RC=$?
  if [ "$RC" != 0 ] && grep -Fq "stage-attempt-v1[2]: invalid returned bundle: $REASON" "$TMP/$KIND.out" && cmp -s "$EXPECTED_WAL" "$WAL" && [ ! -e "$RETURNED" ]; then
    ok "open-WAL return parser rejects $KIND for $REASON and preserves state"
  else bad "return parser fail-closed for $KIND/$REASON (rc=$RC)"; fi
  case "$KIND" in
    completion-trailing-space|completion-non-ascii|wrong-terminal-event-id)
      if cmp -s "$EXPECTED_WAL" "$WAL" && [ ! -e "$RETURNED" ]; then
        ok "$KIND leaves WAL bytes unchanged and creates no returned sidecar"
      else
        bad "$KIND changed WAL or returned state"
      fi
      ;;
  esac
done

reset_folder_open
PARTIAL="$TMP/folder-partial.bundle"
sed -e 's/attempt_elapsed_seconds=17/attempt_elapsed_seconds=18/' \
    -e 's/outcome=passed/outcome=partial/' \
    -e "s/completion_receipt_sha256=$COMPLETION_SHA/completion_receipt_sha256=none/" \
    "$BUNDLE" | sed '/^completion-v1-begin$/,$d' > "$PARTIAL"
(
  cd "$REPO" || exit 1
  STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=19000000000 \
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
  STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=22000000000 \
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

if [ "$CONTRACT_CASE" != baseline ]; then
  reset_folder_open
  FOREIGN_BUNDLE="$TMP/$CONTRACT_CASE.bundle"
  cp "$BUNDLE" "$FOREIGN_BUNDLE"
  FOREIGN_OID="$(printf 'foreign attempt binding\n' | git -C "$REPO" commit-tree "$(git -C "$REPO" rev-parse 'HEAD^{tree}')")"
  case "$CONTRACT_CASE" in
    foreign-stage-run)
      sed "s/ stage_run_id=$HEAD_OID / stage_run_id=$FOREIGN_OID /" "$BUNDLE" > "$FOREIGN_BUNDLE"
      EXPECTED_REASON=foreign-stage-run
      ;;
    foreign-ref)
      FOREIGN_REF_HEX="$(printf '%s' 'refs/heads/foreign' | hex)"
      sed "s/ ref_hex=$REF_HEX / ref_hex=$FOREIGN_REF_HEX /" "$BUNDLE" > "$FOREIGN_BUNDLE"
      EXPECTED_REASON=foreign-ref
      ;;
    foreign-before)
      sed "s/ attempt_before_oid=$HEAD_OID / attempt_before_oid=$FOREIGN_OID /" "$BUNDLE" > "$FOREIGN_BUNDLE"
      EXPECTED_REASON=foreign-before
      ;;
    foreign-worker-completion)
      sed "s/ worker_completion_oid=$HEAD_OID / worker_completion_oid=$FOREIGN_OID /" "$BUNDLE" > "$FOREIGN_BUNDLE"
      EXPECTED_REASON=foreign-worker-completion
      ;;
    foreign-worker)
      FOREIGN_WORKER_HEX="$(printf '%s' foreign-worker | hex)"
      sed "s/ worker_id_hex=$WORKER_HEX / worker_id_hex=$FOREIGN_WORKER_HEX /" "$BUNDLE" > "$FOREIGN_BUNDLE"
      EXPECTED_REASON=foreign-worker
      ;;
    foreign-lease)
      FOREIGN_LEASE_SHA="$(printf '%s' foreign-token | sha256_stream)"
      sed "s/ lease_sha256=$LEASE_SHA / lease_sha256=$FOREIGN_LEASE_SHA /" "$BUNDLE" > "$FOREIGN_BUNDLE"
      EXPECTED_REASON=foreign-lease
      ;;
    foreign-attempt)
      FOREIGN_ATTEMPT_ID="sa1-bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb"
      sed "s/ attempt_id=$ATTEMPT_ID / attempt_id=$FOREIGN_ATTEMPT_ID /" "$BUNDLE" > "$FOREIGN_BUNDLE"
      EXPECTED_REASON=foreign-attempt
      ;;
  esac
  cp "$WAL" "$TMP/$CONTRACT_CASE.before.wal"
  (
    cd "$REPO" || exit 1
    bash "$HELPER" validate-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$FOREIGN_BUNDLE" > "$TMP/$CONTRACT_CASE.out" 2>&1
  )
  RC=$?
  if [ "$RC" != 0 ] && grep -Fq "stage-attempt-v1[2]: invalid returned bundle: $EXPECTED_REASON" "$TMP/$CONTRACT_CASE.out"; then
    ok "$CONTRACT_CASE rejects its foreign binding with the named diagnostic"
  else
    bad "$CONTRACT_CASE expected named foreign-binding rejection (rc=$RC)"
  fi
  if cmp -s "$TMP/$CONTRACT_CASE.before.wal" "$WAL" && [ ! -e "$RETURNED" ]; then
    ok "$CONTRACT_CASE preserves WAL bytes and leaves no returned sidecar"
  else
    bad "$CONTRACT_CASE changed WAL or returned state"
  fi
fi

feedback_validate_rejection() {
  local label="$1" expected="$2" bundle="$3" before out rc
  before="$TMP/$label.before.wal"
  out="$TMP/$label.out"
  cp "$WAL" "$before"
  (
    cd "$REPO" || exit 1
    bash "$HELPER" validate-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$bundle" > "$out" 2>&1
  )
  rc=$?
  if [ "$rc" != 0 ] && grep -Fxq "$expected" "$out"; then
    ok "$label rejects with typed authority diagnostic"
  else
    bad "$label reaches its authority assertion (rc=$rc output=$(tr '\n' ' ' < "$out"))"
  fi
  if cmp -s "$before" "$WAL" && [ ! -e "$RETURNED" ]; then
    ok "$label preserves WAL bytes and leaves no returned sidecar"
  else
    bad "$label changed WAL bytes or created a returned sidecar"
  fi
}

case "$FEEDBACK_CASE" in
  lifecycle-open)
    reset_folder_open
    (
      cd "$REPO" || exit 1
      bash "$HELPER" suspend --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" > "$TMP/lifecycle-suspend.out" 2>&1
    )
    SUSPEND_RC=$?
    if [ "$SUSPEND_RC" = 0 ] && grep -Fq ' state=suspended ' "$WAL"; then
      feedback_validate_rejection lifecycle-open 'stage-attempt-v1[2]: attempt is not open' "$BUNDLE"
    else
      bad "lifecycle-open fixture reaches suspended authority"
    fi
    ;;
  completion-cross-binding)
    FOREIGN_OID="$(printf 'foreign completion binding\n' | git -C "$REPO" commit-tree "$(git -C "$REPO" rev-parse 'HEAD^{tree}')")"
    for FIELD in ref before completion entity stage artifact; do
      reset_folder_open
      CROSS="$TMP/completion-cross-$FIELD.bundle"
      cp "$BUNDLE" "$CROSS"
      case "$FIELD" in
        ref) sed "s| ref=$REF | ref=refs/heads/foreign |" "$BUNDLE" > "$CROSS" ;;
        before) sed "s| before=$HEAD_OID | before=$FOREIGN_OID |" "$BUNDLE" > "$CROSS" ;;
        completion) sed "s| completion=$HEAD_OID | completion=$FOREIGN_OID |" "$BUNDLE" > "$CROSS" ;;
        entity) sed "s| entity=$ENTITY | entity=docs/test-flow/other/index.md |" "$BUNDLE" > "$CROSS" ;;
        stage) sed '/^completion-v1 /s/ stage=plan / stage=execute /' "$BUNDLE" > "$CROSS" ;;
        artifact) sed '/^completion-v1 /s/ artifact=plan.md$/ artifact=other.md/' "$BUNDLE" > "$CROSS" ;;
      esac
      refresh_completion_hash "$CROSS"
      feedback_validate_rejection "completion-cross-binding-$FIELD" 'stage-attempt-v1[2]: invalid returned bundle: completion-binding' "$CROSS"
    done
    ;;
  canonical-entity)
    reset_folder_open
    ALIAS_ENTITY='docs/test-flow/item/./index.md'
    ALIAS_KEY="$(printf 'stage-attempt-v1-key\0%s\0plan' "$ALIAS_ENTITY" | sha256_stream)"
    ALIAS_WAL="$GIT_COMMON/spacedock-stage-attempt-v1/$ALIAS_KEY.wal"
    ALIAS_RETURNED="$GIT_COMMON/spacedock-stage-attempt-v1/$ALIAS_KEY.returned"
    cp "$WAL" "$TMP/canonical-entity.before.wal"
    (
      cd "$REPO" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=5000000000 \
        bash "$HELPER" begin --entity="$ALIAS_ENTITY" --stage=plan --stage-run-id="$HEAD_OID" \
          --ref="$REF" --attempt-before="$HEAD_OID" --worker-id=alias-worker \
          --lease-token=alias-token --attempt-ordinal=0 --fresh-continuations-used=0 \
          --attempt-started-at="$STARTED" > "$TMP/canonical-entity.out" 2>&1
    )
    RC=$?
    if [ "$RC" != 0 ] && grep -Fxq 'stage-attempt-v1[2]: invalid entity path' "$TMP/canonical-entity.out"; then
      ok "canonical-entity rejects a dot-segment alias before deriving a second key"
    else
      bad "canonical-entity alias reaches its same-key authority assertion (rc=$RC output=$(tr '\n' ' ' < "$TMP/canonical-entity.out"))"
    fi
    if cmp -s "$TMP/canonical-entity.before.wal" "$WAL" && [ ! -e "$RETURNED" ] &&
      [ ! -e "$ALIAS_WAL" ] && [ ! -e "$ALIAS_RETURNED" ]; then
      ok "canonical-entity preserves the authoritative WAL and creates no alias state or returned sidecar"
    else
      bad "canonical-entity changed authoritative bytes or created alias state"
    fi
    ;;
  canonical-wal)
    reset_folder_open
    perl -0pi -e 's/ state=open /  state=open /' "$WAL"
    feedback_validate_rejection canonical-wal 'stage-attempt-v1[2]: invalid attempt WAL' "$BUNDLE"
    ;;
  artifact-tree-binding)
    FOREIGN_BLOB="$(printf 'foreign artifact bytes\n' | git -C "$REPO" hash-object -w --stdin)"
    for KIND in path oid encoding; do
      reset_folder_open
      ARTIFACT_BUNDLE="$TMP/artifact-tree-$KIND.bundle"
      cp "$BUNDLE" "$ARTIFACT_BUNDLE"
      case "$KIND" in
        path)
          sed -e "s/ artifact_path_hex=$(printf 'plan.md' | hex) / artifact_path_hex=$(printf 'other.md' | hex) /" \
              -e '/^completion-v1 /s/ artifact=plan.md$/ artifact=other.md/' "$BUNDLE" > "$ARTIFACT_BUNDLE"
          refresh_completion_hash "$ARTIFACT_BUNDLE"
          ;;
        oid) sed "s/ artifact_oid=$(git -C "$REPO" rev-parse HEAD:docs/test-flow/item/plan.md) / artifact_oid=$FOREIGN_BLOB /" "$BUNDLE" > "$ARTIFACT_BUNDLE" ;;
        encoding) sed "s/ artifact_path_hex=$(printf 'plan.md' | hex) / artifact_path_hex=$(printf 'plan.md\n' | hex) /" "$BUNDLE" > "$ARTIFACT_BUNDLE" ;;
      esac
      feedback_validate_rejection "artifact-tree-binding-$KIND" 'stage-attempt-v1[2]: invalid returned bundle: artifact-binding' "$ARTIFACT_BUNDLE"
    done
    ;;
  canonical-ref)
    INVALID_ENTITY='docs/test-flow/ref-item/index.md'
    INVALID_REF='refs/heads/topic..invalid'
    INVALID_KEY="$(printf 'stage-attempt-v1-key\0%s\0plan' "$INVALID_ENTITY" | sha256_stream)"
    INVALID_WAL="$GIT_COMMON/spacedock-stage-attempt-v1/$INVALID_KEY.wal"
    INVALID_RETURNED="$GIT_COMMON/spacedock-stage-attempt-v1/$INVALID_KEY.returned"
    (
      cd "$REPO" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=5000000000 \
        bash "$HELPER" begin --entity="$INVALID_ENTITY" --stage=plan --stage-run-id="$HEAD_OID" \
          --ref="$INVALID_REF" --attempt-before="$HEAD_OID" --worker-id=invalid-ref-worker \
          --lease-token=invalid-ref-token --attempt-ordinal=0 --fresh-continuations-used=0 \
          --attempt-started-at="$STARTED" > "$TMP/canonical-ref.out" 2>&1
    )
    RC=$?
    if [ "$RC" != 0 ] && grep -Fxq 'stage-attempt-v1[2]: invalid ref' "$TMP/canonical-ref.out"; then
      ok "canonical-ref rejects a prefix-shaped Git-invalid branch ref"
    else
      bad "canonical-ref admits a Git-invalid branch ref (rc=$RC output=$(tr '\n' ' ' < "$TMP/canonical-ref.out"))"
    fi
    if [ ! -e "$INVALID_WAL" ] && [ ! -e "$INVALID_RETURNED" ]; then
      ok "canonical-ref creates no WAL or returned sidecar"
    else
      bad "canonical-ref created authority state before Git ref validation"
    fi
    ;;
  derived-attempt)
    reset_folder_open
    FOREIGN_ATTEMPT_ID='sa1-dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd'
    DERIVED_WAL="$TMP/derived-attempt.wal"
    DERIVED_BUNDLE="$TMP/derived-attempt.bundle"
    sed "s/ attempt_id=$ATTEMPT_ID / attempt_id=$FOREIGN_ATTEMPT_ID /" "$WAL" > "$DERIVED_WAL"
    mv "$DERIVED_WAL" "$WAL"
    FOREIGN_TERMINAL_ID="sev1-$(printf 'stage-attempt-v1-terminal\0%s\0%s\0%s' "$KEY" "$HEAD_OID" "$FOREIGN_ATTEMPT_ID" | sha256_stream)"
    sed -e "s/ attempt_id=$ATTEMPT_ID / attempt_id=$FOREIGN_ATTEMPT_ID /" \
        -e "s/ terminal_event_id=$TERMINAL_ID$/ terminal_event_id=$FOREIGN_TERMINAL_ID/" \
        "$BUNDLE" > "$DERIVED_BUNDLE"
    cp "$WAL" "$TMP/derived-attempt.before.wal"
    (
      cd "$REPO" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=18000000000 \
        bash "$HELPER" accept-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" \
          --bundle="$DERIVED_BUNDLE" > "$TMP/derived-attempt.out" 2>&1
    )
    RC=$?
    if [ "$RC" != 0 ] && grep -Fxq 'stage-attempt-v1[2]: invalid attempt WAL' "$TMP/derived-attempt.out"; then
      ok "derived-attempt rejects a coordinated well-formed foreign attempt identity"
    else
      bad "derived-attempt does not re-derive identity from canonical inputs (rc=$RC output=$(tr '\n' ' ' < "$TMP/derived-attempt.out"))"
    fi
    if cmp -s "$TMP/derived-attempt.before.wal" "$WAL" && [ ! -e "$RETURNED" ]; then
      ok "derived-attempt preserves WAL bytes and leaves no returned sidecar"
    else
      bad "derived-attempt admitted coordinated WAL/receipt mutation"
    fi
    ;;
  artifact-all-outcomes)
    FOREIGN_BLOB="$(printf 'foreign all-outcome artifact bytes\n' | git -C "$REPO" hash-object -w --stdin)"
    for KIND in folder-path folder-oid; do
      reset_folder_open
      ARTIFACT_BUNDLE="$TMP/artifact-all-outcomes-$KIND.bundle"
      case "$KIND" in
        folder-path) sed "s/ artifact_path_hex=$(printf 'plan.md' | hex) / artifact_path_hex=$(printf 'other.md' | hex) /" "$PARTIAL" > "$ARTIFACT_BUNDLE" ;;
        folder-oid) sed "s/ artifact_oid=$(git -C "$REPO" rev-parse HEAD:docs/test-flow/item/plan.md) / artifact_oid=$FOREIGN_BLOB /" "$PARTIAL" > "$ARTIFACT_BUNDLE" ;;
      esac
      cp "$WAL" "$TMP/$KIND.before.wal"
      (
        cd "$REPO" || exit 1
        STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=19000000000 \
          bash "$HELPER" accept-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" \
            --bundle="$ARTIFACT_BUNDLE" > "$TMP/$KIND.out" 2>&1
      )
      RC=$?
      if [ "$RC" != 0 ] && grep -Fxq 'stage-attempt-v1[2]: invalid returned bundle: artifact-binding' "$TMP/$KIND.out"; then
        ok "$KIND rejects foreign artifact coordinates"
      else
        bad "$KIND admits foreign artifact coordinates (rc=$RC output=$(tr '\n' ' ' < "$TMP/$KIND.out"))"
      fi
      if cmp -s "$TMP/$KIND.before.wal" "$WAL" && [ ! -e "$RETURNED" ]; then
        ok "$KIND preserves WAL bytes and leaves no returned sidecar"
      else
        bad "$KIND mutated authority state"
      fi
    done
    for KIND in flat-path flat-oid; do
      cp "$FLAT_OPEN" "$FLAT_WAL"
      rm -f "$FLAT_RETURNED"
      ARTIFACT_BUNDLE="$TMP/artifact-all-outcomes-$KIND.bundle"
      case "$KIND" in
        flat-path) sed "s/ artifact_path_hex=$(printf 'flat-plan.md' | hex) / artifact_path_hex=$(printf 'other.md' | hex) /" "$FLAT_BUNDLE" > "$ARTIFACT_BUNDLE" ;;
        flat-oid) sed "s/ artifact_oid=$(git -C "$REPO" rev-parse HEAD:docs/test-flow/flat-plan.md) / artifact_oid=$FOREIGN_BLOB /" "$FLAT_BUNDLE" > "$ARTIFACT_BUNDLE" ;;
      esac
      cp "$FLAT_WAL" "$TMP/$KIND.before.wal"
      (
        cd "$REPO" || exit 1
        STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=22000000000 \
          bash "$HELPER" accept-return --entity="$FLAT_ENTITY" --stage=plan --lease-token=flat-token \
            --bundle="$ARTIFACT_BUNDLE" > "$TMP/$KIND.out" 2>&1
      )
      RC=$?
      if [ "$RC" != 0 ] && grep -Fxq 'stage-attempt-v1[2]: invalid returned bundle: artifact-binding' "$TMP/$KIND.out"; then
        ok "$KIND rejects foreign artifact coordinates"
      else
        bad "$KIND admits foreign artifact coordinates (rc=$RC output=$(tr '\n' ' ' < "$TMP/$KIND.out"))"
      fi
      if cmp -s "$TMP/$KIND.before.wal" "$FLAT_WAL" && [ ! -e "$FLAT_RETURNED" ]; then
        ok "$KIND preserves WAL bytes and leaves no returned sidecar"
      else
        bad "$KIND mutated authority state"
      fi
    done
    ;;
esac

if [ "$QUALITY_CASE" = all ] || [ "$QUALITY_CASE" = exclusion-lock ]; then
  rm -f "$WAL" "$RETURNED" "$GIT_COMMON/spacedock-stage-attempt-v1/$KEY.lock"
  LOCK_HOOK_BIN="$TMP/lock-hook-bin"
  LOCK_BARRIER="$TMP/lock-barrier"
  mkdir -p "$LOCK_HOOK_BIN" "$LOCK_BARRIER"
  REAL_MV="$(command -v mv)"
  cat > "$LOCK_HOOK_BIN/mv" <<EOF
#!/usr/bin/env bash
if [ "\${2:-}" = "$WAL" ]; then
  : > "$LOCK_BARRIER/\$\$"
  hook_wait=0
  while [ "\$(find "$LOCK_BARRIER" -type f | wc -l | tr -d ' ')" -lt 2 ] && [ "\$hook_wait" -lt 30 ]; do
    sleep 0.1
    hook_wait=\$((hook_wait + 1))
  done
fi
exec "$REAL_MV" "\$@"
EOF
  chmod +x "$LOCK_HOOK_BIN/mv"
  for SLOT in a b; do
    (
      cd "$REPO" || exit 1
      PATH="$LOCK_HOOK_BIN:$PATH" STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=4000000000 \
        bash "$HELPER" begin --entity="$ENTITY" --stage=plan --stage-run-id="$HEAD_OID" \
          --ref="$REF" --attempt-before="$HEAD_OID" --worker-id="lock-worker-$SLOT" \
          --lease-token="lock-token-$SLOT" --attempt-ordinal=0 --fresh-continuations-used=0 \
          --attempt-started-at="$STARTED" > "$TMP/lock-$SLOT.out" 2>&1
      printf '%s\n' "$?" > "$TMP/lock-$SLOT.rc"
    ) &
  done
  wait
  LOCK_A_RC="$(sed -n '1p' "$TMP/lock-a.rc")"
  LOCK_B_RC="$(sed -n '1p' "$TMP/lock-b.rc")"
  LOCK_SUCCESS_COUNT=0
  [ "$LOCK_A_RC" = 0 ] && LOCK_SUCCESS_COUNT=$((LOCK_SUCCESS_COUNT + 1))
  [ "$LOCK_B_RC" = 0 ] && LOCK_SUCCESS_COUNT=$((LOCK_SUCCESS_COUNT + 1))
  if [ "$LOCK_SUCCESS_COUNT" = 1 ]; then
    ok "canonical exclusion lock permits exactly one same-key begin"
  else
    bad "canonical exclusion lock admitted $LOCK_SUCCESS_COUNT same-key begins (a=$LOCK_A_RC b=$LOCK_B_RC)"
  fi
  LOCK_A_WORKER_HEX="$(printf '%s' lock-worker-a | hex)"
  LOCK_B_WORKER_HEX="$(printf '%s' lock-worker-b | hex)"
  LOCK_A_LEASE_SHA="$(printf '%s' lock-token-a | sha256_stream)"
  LOCK_B_LEASE_SHA="$(printf '%s' lock-token-b | sha256_stream)"
  if [ -f "$WAL" ] && { grep -Fq "worker_id_hex=$LOCK_A_WORKER_HEX lease_sha256=$LOCK_A_LEASE_SHA " "$WAL" || grep -Fq "worker_id_hex=$LOCK_B_WORKER_HEX lease_sha256=$LOCK_B_LEASE_SHA " "$WAL"; }; then
    ok "exclusion winner leaves one exact authoritative WAL"
  else
    bad "exclusion winner WAL is missing or mixed"
  fi
  if [ ! -e "$GIT_COMMON/spacedock-stage-attempt-v1/$KEY.lock" ] && [ ! -e "$RETURNED" ]; then
    ok "exclusion lock is trap-released and creates no returned sidecar"
  else
    bad "exclusion lock or returned sidecar leaked"
  fi
fi

if [ "$QUALITY_CASE" = all ] || [ "$QUALITY_CASE" = bundle-snapshot ]; then
  reset_folder_open
  SNAPSHOT_BUNDLE="$TMP/snapshot-caller.bundle"
  SNAPSHOT_ORIGINAL="$TMP/snapshot-original.bundle"
  cp "$BUNDLE" "$SNAPSHOT_BUNDLE"
  cp "$BUNDLE" "$SNAPSHOT_ORIGINAL"
  SNAPSHOT_HOOK_BIN="$TMP/snapshot-hook-bin"
  SNAPSHOT_HOOK_MARKER="$TMP/snapshot-hook-fired"
  mkdir -p "$SNAPSHOT_HOOK_BIN"
  REAL_SHASUM="$(command -v shasum)"
  cat > "$SNAPSHOT_HOOK_BIN/sha256sum" <<EOF
#!/usr/bin/env bash
if [ "\$#" = 0 ]; then
  exec "$REAL_SHASUM" -a 256
fi
hook_output="\$("$REAL_SHASUM" -a 256 "\$1")" || exit \$?
if [ ! -e "$SNAPSHOT_HOOK_MARKER" ]; then
  printf 'caller-mutated-after-hash\n' >> "$SNAPSHOT_BUNDLE"
  : > "$SNAPSHOT_HOOK_MARKER"
fi
printf '%s\n' "\$hook_output"
EOF
  chmod +x "$SNAPSHOT_HOOK_BIN/sha256sum"
  (
    cd "$REPO" || exit 1
    PATH="$SNAPSHOT_HOOK_BIN:$PATH" STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=18000000000 \
      bash "$HELPER" accept-return --entity="$ENTITY" --stage=plan \
        --lease-token="$TOKEN" --bundle="$SNAPSHOT_BUNDLE" > "$TMP/snapshot.out" 2>&1
  )
  SNAPSHOT_RC=$?
  if [ -e "$SNAPSHOT_HOOK_MARKER" ] && ! cmp -s "$SNAPSHOT_ORIGINAL" "$SNAPSHOT_BUNDLE"; then
    ok "snapshot fixture mutates caller bytes after the authoritative hash boundary"
  else
    bad "snapshot synchronization hook did not mutate caller bytes"
  fi
  if [ "$SNAPSHOT_RC" = 0 ] && cmp -s "$SNAPSHOT_ORIGINAL" "$RETURNED" &&
    grep -Fq " state=returned fresh_continuations_used=0 returned_bundle_sha256=$(sha256_file "$RETURNED")" "$WAL"; then
    ok "accept-return persists one validated private snapshot with matching WAL digest"
  else
    bad "accept-return reopened caller bundle bytes or persisted a mismatched digest (rc=$SNAPSHOT_RC)"
  fi
fi

if [ "$QUALITY_CASE" = all ] || [ "$QUALITY_CASE" = returned-state ]; then
  reset_folder_open
  (
    cd "$REPO" || exit 1
    STAGE_ATTEMPT_BOOT_ID_SOURCE="$BOOT" STAGE_ATTEMPT_MONOTONIC_NS=18000000000 \
      bash "$HELPER" accept-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$BUNDLE" > "$TMP/returned-initial.out" 2>&1
  )
  RETURNED_INITIAL_RC=$?
  RETURNED_SHA="$(sha256_file "$BUNDLE")"
  cp "$WAL" "$TMP/returned-authoritative.wal"
  cp "$RETURNED" "$TMP/returned-authoritative.sidecar"
  (
    cd "$REPO" || exit 1
    bash "$HELPER" validate-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$BUNDLE" > "$TMP/returned-exact.out" 2>&1
  )
  RETURNED_EXACT_RC=$?
  if [ "$RETURNED_INITIAL_RC" = 0 ] && [ "$RETURNED_EXACT_RC" = 0 ] &&
    grep -Fxq "stage-attempt-v1 disposition=already-returned returned_bundle_sha256=$RETURNED_SHA" "$TMP/returned-exact.out" &&
    cmp -s "$TMP/returned-authoritative.wal" "$WAL" && cmp -s "$TMP/returned-authoritative.sidecar" "$RETURNED"; then
    ok "exact returned-state retry is typed, idempotent, and byte-preserving"
  else
    bad "exact returned-state retry is not typed already-returned (initial=$RETURNED_INITIAL_RC retry=$RETURNED_EXACT_RC)"
  fi
  if cmp -s "$TMP/returned-authoritative.wal" "$WAL" && cmp -s "$TMP/returned-authoritative.sidecar" "$RETURNED"; then
    ok "exact returned-state retry preserves authoritative WAL and sidecar bytes"
  else
    bad "exact returned-state retry changed authoritative bytes"
  fi

  cp "$TMP/returned-authoritative.wal" "$WAL"
  cp "$TMP/returned-authoritative.sidecar" "$RETURNED"
  RETURNED_CONFLICT="$TMP/returned-conflict.bundle"
  sed 's/attempt_elapsed_seconds=17/attempt_elapsed_seconds=18/' "$BUNDLE" > "$RETURNED_CONFLICT"
  (
    cd "$REPO" || exit 1
    bash "$HELPER" accept-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$RETURNED_CONFLICT" > "$TMP/returned-conflict.out" 2>&1
  )
  RETURNED_CONFLICT_RC=$?
  if [ "$RETURNED_CONFLICT_RC" != 0 ] && grep -Fxq 'stage-attempt-v1[2]: conflicting returned bundle' "$TMP/returned-conflict.out" &&
    cmp -s "$TMP/returned-authoritative.wal" "$WAL" && cmp -s "$TMP/returned-authoritative.sidecar" "$RETURNED"; then
    ok "conflicting returned-state retry is typed and preserves authority"
  else
    bad "conflicting returned-state retry is not fail-closed (rc=$RETURNED_CONFLICT_RC)"
  fi
  if cmp -s "$TMP/returned-authoritative.wal" "$WAL" && cmp -s "$TMP/returned-authoritative.sidecar" "$RETURNED"; then
    ok "conflicting returned-state retry preserves authoritative WAL and sidecar bytes"
  else
    bad "conflicting returned-state retry changed authoritative bytes"
  fi

  cp "$TMP/returned-authoritative.wal" "$WAL"
  cp "$TMP/returned-authoritative.sidecar" "$RETURNED"
  printf 'corrupt\n' >> "$RETURNED"
  cp "$RETURNED" "$TMP/returned-corrupt.sidecar"
  (
    cd "$REPO" || exit 1
    bash "$HELPER" validate-return --entity="$ENTITY" --stage=plan --lease-token="$TOKEN" --bundle="$BUNDLE" > "$TMP/returned-malformed.out" 2>&1
  )
  RETURNED_MALFORMED_RC=$?
  if [ "$RETURNED_MALFORMED_RC" != 0 ] && grep -Fxq 'stage-attempt-v1[2]: invalid returned state: sidecar-digest' "$TMP/returned-malformed.out" &&
    cmp -s "$TMP/returned-authoritative.wal" "$WAL" && cmp -s "$TMP/returned-corrupt.sidecar" "$RETURNED"; then
    ok "malformed returned state is typed and preserves observed bytes"
  else
    bad "malformed returned state is not distinguished from conflict (rc=$RETURNED_MALFORMED_RC)"
  fi
  if cmp -s "$TMP/returned-authoritative.wal" "$WAL" && cmp -s "$TMP/returned-corrupt.sidecar" "$RETURNED"; then
    ok "malformed returned-state retry preserves the observed inconsistent bytes"
  else
    bad "malformed returned-state retry changed observed bytes"
  fi
fi

exit "$FAIL"
