#!/usr/bin/env bash
set -u

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HELPER="${HERE}/../fo-stage-attempt.sh"
FAIL=0
CLOCK_CASE="${STAGE_ATTEMPT_CLOCK_CASE:-full}"
ok() { printf 'OK %s\n' "$1"; }
bad() { printf 'FAIL %s\n' "$1"; FAIL=1; }

case "$CLOCK_CASE" in
  full|nonterminal|return-budget) ;;
  *) printf 'FAIL unknown STAGE_ATTEMPT_CLOCK_CASE: %s\n' "$CLOCK_CASE"; exit 1 ;;
esac

if [ ! -f "$HELPER" ]; then
  bad "fo-stage-attempt.sh is missing: FO fresh/resume identity and boot-bound monotonic clock behavior are not implemented"
  exit "$FAIL"
fi
if [ ! -x "$HELPER" ]; then bad "fo-stage-attempt.sh is not executable"; exit "$FAIL"; fi

TMP="$(mktemp -d "${TMPDIR:-/tmp}/stage-attempt-clock.XXXXXX")"
trap 'rm -rf "$TMP"' EXIT

if [ "$CLOCK_CASE" = nonterminal ] || [ "$CLOCK_CASE" = return-budget ]; then
  CASE_REPO=''
  CASE_ENTITY=''
  CASE_BOOT=''
  CASE_HEAD=''
  CASE_COMMON=''
  CASE_WAL=''
  CASE_HISTORY=''
  CASE_RETURNED=''

  prepare_nonterminal_case() {
    local label="$1" stage="$2" monotonic_ns="$3" ordinal="${4:-0}" used="${5:-0}"
    CASE_REPO="$TMP/$label-repo"
    CASE_ENTITY="docs/clock-flow/$label/index.md"
    CASE_BOOT="$TMP/$label.boot"
    mkdir -p "$CASE_REPO/docs/clock-flow/$label"
    printf '%s\n' '---' "id: $label" "status: $stage" 'stage_outputs: {}' '---' > "$CASE_REPO/$CASE_ENTITY"
    (
      cd "$CASE_REPO" || exit 1
      git init -q -b main
      git config user.name test
      git config user.email test@example.invalid
      git add -- docs
      git commit -qm fixture
    )
    CASE_HEAD="$(git -C "$CASE_REPO" rev-parse HEAD)"
    CASE_COMMON="$(git -C "$CASE_REPO" rev-parse --git-common-dir)"
    case "$CASE_COMMON" in /*) ;; *) CASE_COMMON="$CASE_REPO/$CASE_COMMON" ;; esac
    CASE_HISTORY="$CASE_REPO/docs/clock-flow/$label/attempt-history-v1.log"
    printf '%s\n' '22222222-3333-4444-5555-666666666666' > "$CASE_BOOT"
    (
      cd "$CASE_REPO" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$CASE_BOOT" STAGE_ATTEMPT_MONOTONIC_NS="$monotonic_ns" \
        bash "$HELPER" begin --entity="$CASE_ENTITY" --stage="$stage" --stage-run-id="$CASE_HEAD" \
          --ref=refs/heads/main --attempt-before="$CASE_HEAD" --worker-id="$label-worker" \
          --lease-token="$label-token" --attempt-ordinal="$ordinal" --fresh-continuations-used="$used" \
          --attempt-started-at=2026-07-22T03:10:00Z
    ) > "$TMP/$label.begin.out" 2> "$TMP/$label.begin.err"
    local rc=$?
    CASE_WAL="$(find "$CASE_COMMON/spacedock-stage-attempt-v1" -name '*.wal' -type f -print -quit 2>/dev/null || true)"
    CASE_RETURNED="${CASE_WAL%.wal}.returned"
    if [ "$rc" = 0 ] && [ -n "$CASE_WAL" ] && [ -f "$CASE_WAL" ]; then
      return 0
    fi
    bad "$label nonterminal fixture begin (rc=$rc)"
    return 1
  }

  seed_suspended_wal() {
    local target="$1" tmp="$2"
    sed 's/ state=open / state=suspended /' "$target" > "$tmp" && mv "$tmp" "$target"
  }

  sha256_stream() {
    if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
    else shasum -a 256 | awk '{print $1}'
    fi
  }

  hex() { LC_ALL=C od -An -v -t x1 | tr -d ' \n'; }

  if [ "$CLOCK_CASE" = nonterminal ]; then
    for SPEC in 'plan:1200' 'execute:1800'; do
    STAGE="${SPEC%%:*}"
    BUDGET="${SPEC#*:}"
    if prepare_nonterminal_case "$STAGE-budget" "$STAGE" 1000000000; then
      if grep -q " monotonic_started_ns=1000000000 budget_seconds=$BUDGET state=open " "$CASE_WAL" &&
        grep -q ' attempt_started_at=2026-07-22T03:10:00Z ' "$CASE_WAL"; then
        ok "$STAGE separates audit wall time from monotonic authority and receives FO budget $BUDGET"
      else
        bad "$STAGE audit/monotonic authority and budget $BUDGET"
      fi

      (
        cd "$CASE_REPO" || exit 1
        STAGE_ATTEMPT_BOOT_ID_SOURCE="$CASE_BOOT" \
          STAGE_ATTEMPT_MONOTONIC_NS=$((1000000000 + BUDGET * 1000000000)) \
          bash "$HELPER" elapsed --entity="$CASE_ENTITY" --stage="$STAGE"
      ) > "$TMP/$STAGE.boundary" 2>&1
      RC=$?
      if [ "$RC" = 0 ] && grep -qx "stage-attempt-v1 elapsed_seconds=$BUDGET expired=no" "$TMP/$STAGE.boundary"; then
        ok "$STAGE exact budget boundary remains live"
      else
        bad "$STAGE exact budget boundary remains live (rc=$RC)"
      fi

      (
        cd "$CASE_REPO" || exit 1
        STAGE_ATTEMPT_BOOT_ID_SOURCE="$CASE_BOOT" \
          STAGE_ATTEMPT_MONOTONIC_NS=$((1000000000 + (BUDGET + 1) * 1000000000)) \
          bash "$HELPER" elapsed --entity="$CASE_ENTITY" --stage="$STAGE"
      ) > "$TMP/$STAGE.over" 2>&1
      RC=$?
      if [ "$RC" = 0 ] && grep -qx "stage-attempt-v1 elapsed_seconds=$((BUDGET + 1)) expired=yes" "$TMP/$STAGE.over"; then
        ok "$STAGE expires only at threshold plus one"
      else
        bad "$STAGE threshold-plus-one expiry (rc=$RC)"
      fi
    fi
    done

    if prepare_nonterminal_case same-boot plan 9000000000 1 1; then
    EXPECTED_SUSPENDED="$TMP/same-boot.expected-suspended.wal"
    sed 's/ state=open / state=suspended /' "$CASE_WAL" > "$EXPECTED_SUSPENDED"
    (
      cd "$CASE_REPO" || exit 1
      bash "$HELPER" suspend --entity="$CASE_ENTITY" --stage=plan --lease-token=same-boot-token
    ) > "$TMP/same-boot.suspend" 2>&1
    SUSPEND_RC=$?
    if [ "$SUSPEND_RC" = 0 ] && cmp -s "$EXPECTED_SUSPENDED" "$CASE_WAL"; then
      ok "same-boot open to suspended preserves exact authority bytes"
    else
      bad "same-boot open to suspended exact preservation (rc=$SUSPEND_RC)"
    fi

    # Resume has its own exact suspended precondition even during the RED phase,
    # so a missing suspend command cannot mask the independently named resume assertion.
    cp "$EXPECTED_SUSPENDED" "$CASE_WAL"
    EXPECTED_OPEN="$TMP/same-boot.expected-open.wal"
    sed 's/ state=suspended / state=open /' "$CASE_WAL" > "$EXPECTED_OPEN"
    (
      cd "$CASE_REPO" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$CASE_BOOT" STAGE_ATTEMPT_MONOTONIC_NS=11000000000 \
        bash "$HELPER" resume --entity="$CASE_ENTITY" --stage=plan --lease-token=same-boot-token
    ) > "$TMP/same-boot.resume" 2>&1
    RESUME_RC=$?
    if [ "$RESUME_RC" = 0 ] && cmp -s "$EXPECTED_OPEN" "$CASE_WAL" &&
      grep -q 'attempt_ordinal=1 .*monotonic_started_ns=9000000000 budget_seconds=1200 state=open fresh_continuations_used=1 ' "$CASE_WAL"; then
      ok "same-boot suspended to open preserves identity, origin, budget, ordinal, and continuation count"
    else
      bad "same-boot suspended to open exact preservation (rc=$RESUME_RC)"
    fi
    fi

    if prepare_nonterminal_case unsigned-range-resume plan 9223372036854775808; then
    (
      cd "$CASE_REPO" || exit 1
      bash "$HELPER" suspend --entity="$CASE_ENTITY" --stage=plan --lease-token=unsigned-range-resume-token
    ) > "$TMP/unsigned-range-resume.suspend" 2>&1
    SUSPEND_RC=$?
    UNSIGNED_SUSPENDED="$TMP/unsigned-range-resume.suspended.wal"
    cp "$CASE_WAL" "$UNSIGNED_SUSPENDED"
    UNSIGNED_EXPECTED_OPEN="$TMP/unsigned-range-resume.expected-open.wal"
    sed 's/ state=suspended / state=open /' "$CASE_WAL" > "$UNSIGNED_EXPECTED_OPEN"
    UNSIGNED_REF_BEFORE="$(git -C "$CASE_REPO" rev-parse refs/heads/main)"
    UNSIGNED_STATUS_BEFORE="$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)"
    UNSIGNED_ENTITY_BEFORE="$(git -C "$CASE_REPO" hash-object "$CASE_REPO/$CASE_ENTITY")"
    (
      cd "$CASE_REPO" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$CASE_BOOT" STAGE_ATTEMPT_MONOTONIC_NS=9223372036854775809 \
        bash "$HELPER" resume --entity="$CASE_ENTITY" --stage=plan --lease-token=unsigned-range-resume-token
    ) > "$TMP/unsigned-range-resume.out" 2>&1
    RESUME_RC=$?
    if [ "$SUSPEND_RC" = 0 ] && [ "$RESUME_RC" = 0 ] &&
      cmp -s "$UNSIGNED_EXPECTED_OPEN" "$CASE_WAL" &&
      grep -q 'monotonic_started_ns=9223372036854775808 .*state=open fresh_continuations_used=0 ' "$CASE_WAL" &&
      [ ! -e "$CASE_HISTORY" ] && [ ! -e "$CASE_RETURNED" ] &&
      [ "$UNSIGNED_REF_BEFORE" = "$(git -C "$CASE_REPO" rev-parse refs/heads/main)" ] &&
      [ "$UNSIGNED_STATUS_BEFORE" = "$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)" ] &&
      [ "$UNSIGNED_ENTITY_BEFORE" = "$(git -C "$CASE_REPO" hash-object "$CASE_REPO/$CASE_ENTITY")" ]; then
      ok "unsigned-range same-boot monotonic increase resumes without changing identity or nonterminal authority"
    else
      bad "unsigned-range same-boot monotonic increase resumes (suspend=$SUSPEND_RC resume=$RESUME_RC)"
      sed 's/^/  observed: /' "$TMP/unsigned-range-resume.out"
    fi
    if { [ "$RESUME_RC" = 0 ] && cmp -s "$UNSIGNED_EXPECTED_OPEN" "$CASE_WAL"; } ||
      { [ "$RESUME_RC" != 0 ] && cmp -s "$UNSIGNED_SUSPENDED" "$CASE_WAL"; }; then
      UNSIGNED_STATE_PRESERVED=yes
    else
      UNSIGNED_STATE_PRESERVED=no
    fi
    if [ "$UNSIGNED_STATE_PRESERVED" = yes ] &&
      grep -q ' fresh_continuations_used=0 ' "$CASE_WAL" &&
      [ ! -e "$CASE_HISTORY" ] && [ ! -e "$CASE_RETURNED" ] &&
      [ "$UNSIGNED_REF_BEFORE" = "$(git -C "$CASE_REPO" rev-parse refs/heads/main)" ] &&
      [ "$UNSIGNED_STATUS_BEFORE" = "$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)" ] &&
      [ "$UNSIGNED_ENTITY_BEFORE" = "$(git -C "$CASE_REPO" hash-object "$CASE_REPO/$CASE_ENTITY")" ]; then
      ok "unsigned-range resume preserves nonterminal state with no terminal history, continuation, or route mutation"
    else
      bad "unsigned-range resume mutated nonterminal authority"
    fi
    fi

    if prepare_nonterminal_case unsigned-range-elapsed plan 9223372036854775808; then
    UNSIGNED_OPEN="$TMP/unsigned-range-elapsed.open.wal"
    cp "$CASE_WAL" "$UNSIGNED_OPEN"
    UNSIGNED_REF_BEFORE="$(git -C "$CASE_REPO" rev-parse refs/heads/main)"
    UNSIGNED_STATUS_BEFORE="$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)"
    UNSIGNED_ENTITY_BEFORE="$(git -C "$CASE_REPO" hash-object "$CASE_REPO/$CASE_ENTITY")"
    (
      cd "$CASE_REPO" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$CASE_BOOT" STAGE_ATTEMPT_MONOTONIC_NS=9223372038854775809 \
        bash "$HELPER" elapsed --entity="$CASE_ENTITY" --stage=plan
    ) > "$TMP/unsigned-range-elapsed.out" 2>&1
    ELAPSED_RC=$?
    if [ "$ELAPSED_RC" = 0 ] &&
      grep -qx 'stage-attempt-v1 elapsed_seconds=2 expired=no' "$TMP/unsigned-range-elapsed.out"; then
      ok "unsigned-range elapsed uses floor delta above signed boundary"
    else
      bad "unsigned-range elapsed floor delta above signed boundary (rc=$ELAPSED_RC)"
      sed 's/^/  observed: /' "$TMP/unsigned-range-elapsed.out"
    fi
    if cmp -s "$UNSIGNED_OPEN" "$CASE_WAL" &&
      grep -q ' state=open fresh_continuations_used=0 ' "$CASE_WAL" &&
      [ ! -e "$CASE_HISTORY" ] && [ ! -e "$CASE_RETURNED" ] &&
      [ "$UNSIGNED_REF_BEFORE" = "$(git -C "$CASE_REPO" rev-parse refs/heads/main)" ] &&
      [ "$UNSIGNED_STATUS_BEFORE" = "$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)" ] &&
      [ "$UNSIGNED_ENTITY_BEFORE" = "$(git -C "$CASE_REPO" hash-object "$CASE_REPO/$CASE_ENTITY")" ]; then
      ok "unsigned-range elapsed query leaves WAL byte-identical with no terminal history, continuation, or route mutation"
    else
      bad "unsigned-range elapsed query mutated nonterminal authority"
    fi
    fi
  fi

  return_budget_case() {
    local stage="$1" budget="$2" over
    over=$((budget + 1))
    local label="$stage-return-budget" repo="$TMP/$stage-return-budget-repo"
    local entity="docs/clock-flow/$label/index.md" artifact="docs/clock-flow/$label/$stage.md"
    local boot="$TMP/$stage-return-budget.boot" token="$stage-return-budget-token"
    local head common wal returned history open_wal key attempt_id terminal_id
    local entity_hex ref_hex worker_hex lease_sha artifact_oid completion_line completion_sha
    local boundary_bundle over_bundle ref_before status_before boundary_rc over_rc observed_state sidecar_state
    mkdir -p "$repo/docs/clock-flow/$label"
    printf '%s\n' '---' "id: $label" "status: $stage" 'stage_outputs: {}' '---' > "$repo/$entity"
    printf '# %s\n' "$stage" > "$repo/$artifact"
    (
      cd "$repo" || exit 1
      git init -q -b main
      git config user.name test
      git config user.email test@example.invalid
      git add -- docs
      git commit -qm fixture
    )
    head="$(git -C "$repo" rev-parse HEAD)"
    common="$(git -C "$repo" rev-parse --git-common-dir)"
    case "$common" in /*) ;; *) common="$repo/$common" ;; esac
    history="$repo/docs/clock-flow/$label/attempt-history-v1.log"
    printf '%s\n' '77777777-8888-4999-aaaa-bbbbbbbbbbbb' > "$boot"
    (
      cd "$repo" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$boot" STAGE_ATTEMPT_MONOTONIC_NS=1000000000 \
        bash "$HELPER" begin --entity="$entity" --stage="$stage" --stage-run-id="$head" \
          --ref=refs/heads/main --attempt-before="$head" --worker-id=return-budget-worker \
          --lease-token="$token" --attempt-ordinal=0 --fresh-continuations-used=0 \
          --attempt-started-at=2026-07-22T06:00:00Z
    ) > "$TMP/$stage-return-budget.begin" 2>&1 || { bad "$stage return-budget fixture begin"; return; }
    wal="$(find "$common/spacedock-stage-attempt-v1" -name '*.wal' -type f -print -quit 2>/dev/null || true)"
    [ -n "$wal" ] && [ -f "$wal" ] || { bad "$stage return-budget WAL fixture"; return; }
    returned="${wal%.wal}.returned"
    open_wal="$TMP/$stage-return-budget.open.wal"
    cp "$wal" "$open_wal"
    key="$(basename "${wal%.wal}")"
    attempt_id="$(sed -n 's/.* attempt_id=\([^ ]*\) .*/\1/p' "$wal")"
    terminal_id="sev1-$(printf 'stage-attempt-v1-terminal\0%s\0%s\0%s' "$key" "$head" "$attempt_id" | sha256_stream)"
    entity_hex="$(printf '%s' "$entity" | hex)"
    ref_hex="$(printf '%s' refs/heads/main | hex)"
    worker_hex="$(printf '%s' return-budget-worker | hex)"
    lease_sha="$(printf '%s' "$token" | sha256_stream)"
    artifact_oid="$(git -C "$repo" rev-parse "HEAD:$artifact")"
    completion_line="completion-v1 disposition=already-registered ref=refs/heads/main before=$head completion=$head entity=$entity stage=$stage artifact=$stage.md"
    completion_sha="$(printf '%s\n' "$completion_line" | sha256_stream)"
    boundary_bundle="$TMP/$stage-return-budget.boundary.bundle"
    printf 'stage-attempt-v1 entity_stage_key=%s entity_path_hex=%s stage=%s stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_completion_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=0 attempt_started_at=2026-07-22T06:00:00Z budget_seconds=%s attempt_elapsed_seconds=%s fresh_continuations_used=0 outcome=passed artifact_path_hex=%s artifact_oid=%s completion_receipt_sha256=%s terminal_event_id=%s\ncompletion-v1-begin\n%s\ncompletion-v1-end\n' \
      "$key" "$entity_hex" "$stage" "$head" "$ref_hex" "$head" "$head" "$worker_hex" "$lease_sha" "$attempt_id" \
      "$budget" "$budget" "$(printf '%s' "$stage.md" | hex)" "$artifact_oid" "$completion_sha" "$terminal_id" "$completion_line" > "$boundary_bundle"
    ref_before="$(git -C "$repo" rev-parse refs/heads/main)"
    status_before="$(git -C "$repo" status --porcelain=v1 --untracked-files=all)"
    (
      cd "$repo" || exit 1
      bash "$HELPER" accept-return --entity="$entity" --stage="$stage" --lease-token="$token" --bundle="$boundary_bundle"
    ) > "$TMP/$stage-return-budget.boundary.out" 2>&1
    boundary_rc=$?
    if [ "$boundary_rc" = 0 ] && cmp -s "$boundary_bundle" "$returned" &&
      grep -q ' state=returned fresh_continuations_used=0 ' "$wal" &&
      [ ! -e "$history" ] && [ "$ref_before" = "$(git -C "$repo" rev-parse refs/heads/main)" ] &&
      [ "$status_before" = "$(git -C "$repo" status --porcelain=v1 --untracked-files=all)" ]; then
      ok "$stage passed return is accepted at exact budget $budget without terminal history, CAS, or route"
    else
      bad "$stage exact-budget passed return acceptance (rc=$boundary_rc)"
    fi

    cp "$open_wal" "$wal"
    rm -f "$returned"
    over_bundle="$TMP/$stage-return-budget.over.bundle"
    sed "s/attempt_elapsed_seconds=$budget/attempt_elapsed_seconds=$over/" "$boundary_bundle" > "$over_bundle"
    (
      cd "$repo" || exit 1
      bash "$HELPER" accept-return --entity="$entity" --stage="$stage" --lease-token="$token" --bundle="$over_bundle"
    ) > "$TMP/$stage-return-budget.over.out" 2>&1
    over_rc=$?
    observed_state="$(sed -n 's/.* state=\([^ ]*\) .*/\1/p' "$wal")"
    if [ -e "$returned" ]; then sidecar_state=present; else sidecar_state=absent; fi
    if [ "$over_rc" != 0 ] &&
      grep -Fqx 'stage-attempt-v1[2]: invalid returned bundle: elapsed-budget-exceeded' "$TMP/$stage-return-budget.over.out" &&
      cmp -s "$open_wal" "$wal" && [ ! -e "$returned" ]; then
      ok "$stage passed return at threshold plus one $over is typed rejected with open WAL byte-identical and no sidecar"
    else
      bad "$stage threshold-plus-one passed return rejection/preservation (rc=$over_rc state=$observed_state sidecar=$sidecar_state)"
    fi
    if [ ! -e "$history" ] && [ "$ref_before" = "$(git -C "$repo" rev-parse refs/heads/main)" ] &&
      [ "$status_before" = "$(git -C "$repo" status --porcelain=v1 --untracked-files=all)" ]; then
      ok "$stage return-budget cases create no terminal history, CAS, route, continuation, or worktree mutation"
    else
      bad "$stage return-budget cases escaped nonterminal scope"
    fi
  }

  return_budget_case plan 1200
  return_budget_case execute 1800

  clock_fault_refusal() {
    local label="$1" source_mode="$2" resume_ns="$3" reason="$4"
    prepare_nonterminal_case "$label" plan 5000000000 || return
    seed_suspended_wal "$CASE_WAL" "$TMP/$label.suspended.tmp" || { bad "$label suspended WAL fixture"; return; }
    local suspended="$TMP/$label.suspended.wal" ref_before status_before entity_before rc
    cp "$CASE_WAL" "$suspended"
    ref_before="$(git -C "$CASE_REPO" rev-parse refs/heads/main)"
    status_before="$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)"
    entity_before="$(git -C "$CASE_REPO" hash-object "$CASE_REPO/$CASE_ENTITY")"
    case "$source_mode" in
      missing) rm -f "$CASE_BOOT" ;;
      unparseable) printf '%s\n' 'not a boot identity' > "$CASE_BOOT" ;;
      foreign) printf '%s\n' 'ffffffff-eeee-dddd-cccc-bbbbbbbbbbbb' > "$CASE_BOOT" ;;
      same) ;;
    esac
    (
      cd "$CASE_REPO" || exit 1
      STAGE_ATTEMPT_BOOT_ID_SOURCE="$CASE_BOOT" STAGE_ATTEMPT_MONOTONIC_NS="$resume_ns" \
        bash "$HELPER" resume --entity="$CASE_ENTITY" --stage=plan --lease-token="$label-token"
    ) > "$TMP/$label.refusal" 2>&1
    rc=$?
    if [ "$rc" != 0 ] &&
      grep -qx "stage-attempt-v1 disposition=resume-refused reason=$reason" "$TMP/$label.refusal" &&
      ! grep -Eq 'outcome=interrupted|terminalized|disposition=terminal|stage-circuit-v1' "$TMP/$label.refusal"; then
      ok "$label returns typed nonterminal clock refusal without claiming interrupted"
    else
      bad "$label typed nonterminal clock refusal (rc=$rc reason=$reason)"
    fi
    if cmp -s "$suspended" "$CASE_WAL" &&
      grep -q ' state=suspended fresh_continuations_used=0 ' "$CASE_WAL" &&
      [ ! -e "$CASE_HISTORY" ] && [ ! -e "$CASE_RETURNED" ] &&
      [ "$ref_before" = "$(git -C "$CASE_REPO" rev-parse refs/heads/main)" ] &&
      [ "$status_before" = "$(git -C "$CASE_REPO" status --porcelain=v1 --untracked-files=all)" ] &&
      [ "$entity_before" = "$(git -C "$CASE_REPO" hash-object "$CASE_REPO/$CASE_ENTITY")" ]; then
      ok "$label leaves suspended WAL byte-identical with no terminal history, continuation, or route mutation"
    else
      bad "$label mutated suspended WAL, terminal history, continuation, route, ref, or worktree"
    fi
  }

  if [ "$CLOCK_CASE" = nonterminal ]; then
    clock_fault_refusal missing-clock-source missing 6000000000 clock-identity-loss
    clock_fault_refusal unparseable-clock-source unparseable 6000000000 clock-identity-unparseable
    clock_fault_refusal changed-boot-identity foreign 6000000000 boot-identity-mismatch
    clock_fault_refusal monotonic-regression same 4000000000 monotonic-regression
  fi

  exit "$FAIL"
fi

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
