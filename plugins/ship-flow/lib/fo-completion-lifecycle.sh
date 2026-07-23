#!/usr/bin/env bash

_FO_COMPLETION_LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091 # sibling library is resolved from this helper's location
source "${_FO_COMPLETION_LIFECYCLE_DIR}/completion-v1.sh"
_FO_STAGE_ATTEMPT_HELPER="${_FO_COMPLETION_LIFECYCLE_DIR}/fo-stage-attempt.sh"

fo_plan_attempt_sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then sha256sum | awk '{print $1}'
  else shasum -a 256 | awk '{print $1}'
  fi
}

fo_plan_attempt_hex() {
  LC_ALL=C od -An -v -t x1 | tr -d ' \n'
}

fo_plan_attempt_release_failed_begin_lease() {
  local lease_dir record releasing
  lease_dir="$FO_COMPLETION_GITDIR/completion-v1.lease"
  record="$lease_dir/record"
  completion_lease_matches "$record" delegated "$FO_COMPLETION_TOKEN" "$FO_COMPLETION_ENTITY" plan \
    "$FO_COMPLETION_WORKER" "$FO_COMPLETION_REF" "$FO_COMPLETION_BEFORE" || return 5
  releasing="$lease_dir/releasing.$$.$RANDOM"
  mv "$record" "$releasing" || return 8
  if ! completion_lease_matches "$releasing" delegated "$FO_COMPLETION_TOKEN" "$FO_COMPLETION_ENTITY" plan \
    "$FO_COMPLETION_WORKER" "$FO_COMPLETION_REF" "$FO_COMPLETION_BEFORE"; then
    [ -e "$record" ] || mv "$releasing" "$record" || true
    return 5
  fi
  rm -f "$releasing" || return 8
  rmdir "$lease_dir" || return 8
}

fo_completion_begin() {
  FO_COMPLETION_ENTITY="$1"; FO_COMPLETION_STATUS="$2"; FO_COMPLETION_STAGE="$3"; FO_COMPLETION_FILE="$4"; FO_COMPLETION_WORKER="$5"
  completion_path_ok "$FO_COMPLETION_ENTITY" || return 10
  FO_COMPLETION_REF="$(git symbolic-ref -q HEAD)" || return 5; FO_COMPLETION_BEFORE="$(git rev-parse "$FO_COMPLETION_REF")" || return 5; FO_COMPLETION_BEFORE_TREE="$(git rev-parse "$FO_COMPLETION_BEFORE^{tree}")" || return 5; FO_COMPLETION_GITDIR="$(git rev-parse --absolute-git-dir)" || return 5
  FO_COMPLETION_TOKEN="$(printf '%s\n' "$FO_COMPLETION_ENTITY:$FO_COMPLETION_STAGE:$FO_COMPLETION_WORKER:$FO_COMPLETION_REF:$FO_COMPLETION_BEFORE:$$:$RANDOM" | shasum -a 256 | awk '{print $1}')"
  FO_COMPLETION_ACQUIRE="$(bash "${_FO_COMPLETION_LIFECYCLE_DIR}/fo-completion-lease.sh" acquire --entity="$FO_COMPLETION_ENTITY" --stage="$FO_COMPLETION_STAGE" --worker="$FO_COMPLETION_WORKER" --token="$FO_COMPLETION_TOKEN" --ref="$FO_COMPLETION_REF" --before="$FO_COMPLETION_BEFORE")" || return
  SHIP_FLOW_COMPLETION_LEASE_FILE="$FO_COMPLETION_GITDIR/completion-v1.lease/record"
  SHIP_FLOW_COMPLETION_LEASE_TOKEN="$FO_COMPLETION_TOKEN"
  SHIP_FLOW_COMPLETION_WORKER_ID="$FO_COMPLETION_WORKER"
  export SHIP_FLOW_COMPLETION_LEASE_FILE SHIP_FLOW_COMPLETION_LEASE_TOKEN SHIP_FLOW_COMPLETION_WORKER_ID
  [ "$FO_COMPLETION_ACQUIRE" = "completion-v1-lease disposition=acquired record=$SHIP_FLOW_COMPLETION_LEASE_FILE entity=$FO_COMPLETION_ENTITY stage=$FO_COMPLETION_STAGE worker=$FO_COMPLETION_WORKER ref=$FO_COMPLETION_REF before=$FO_COMPLETION_BEFORE" ] || return 5
  # shellcheck disable=SC2034 # sourced callers prepend this generated block to worker assignments
  printf -v FO_COMPLETION_ENV_BLOCK 'export SHIP_FLOW_COMPLETION_LEASE_FILE=%q SHIP_FLOW_COMPLETION_LEASE_TOKEN=%q SHIP_FLOW_COMPLETION_WORKER_ID=%q' "$SHIP_FLOW_COMPLETION_LEASE_FILE" "$SHIP_FLOW_COMPLETION_LEASE_TOKEN" "$SHIP_FLOW_COMPLETION_WORKER_ID"
}

fo_completion_checkpoint() {
  local receipt="$1" tag disposition ref before completion entity stage artifact extra
  IFS=' ' read -r tag disposition ref before completion entity stage artifact extra <<< "$receipt"; [ "$tag" = completion-v1 ] && [ -z "$extra" ] || return 5
  disposition="${disposition#disposition=}"; ref="${ref#ref=}"; before="${before#before=}"; completion="${completion#completion=}"; entity="${entity#entity=}"; stage="${stage#stage=}"; artifact="${artifact#artifact=}"
  case "$disposition" in published|already-registered) ;; *) return 5 ;; esac; [ "$receipt" = "completion-v1 disposition=$disposition ref=$ref before=$before completion=$completion entity=$entity stage=$stage artifact=$artifact" ] || return 5
  [ "$ref" = "$FO_COMPLETION_REF" ] && [ "$before" = "$FO_COMPLETION_BEFORE" ] && [ "$entity" = "$FO_COMPLETION_ENTITY" ] && [ "$stage" = "$FO_COMPLETION_STAGE" ] && [ "$artifact" = "$FO_COMPLETION_FILE" ] || return 5
  bash "${_FO_COMPLETION_LIFECYCLE_DIR}/fo-completion-lease.sh" reclaim --entity="$entity" --stage="$stage" --worker="$FO_COMPLETION_WORKER" --token="$FO_COMPLETION_TOKEN" --ref="$ref" --before="$before" >/dev/null || return
  FO_COMPLETION_CHECKPOINT="$(bash "${_FO_COMPLETION_LIFECYCLE_DIR}/fo-reconcile-completion.sh" --disposition="$disposition" --entity="$entity" --new-status="$FO_COMPLETION_STATUS" --stage-name="$stage" --stage-file="$artifact" --ref="$ref" --before="$before" --completion="$completion" --before-tree="$FO_COMPLETION_BEFORE_TREE" --lease-file="$FO_COMPLETION_GITDIR/completion-v1.lease/returned" --lease-token="$FO_COMPLETION_TOKEN" --worker-id="$FO_COMPLETION_WORKER")" || return
  case "$FO_COMPLETION_CHECKPOINT" in completion-v1-reconcile\ disposition=ready\ *) FO_CHECKPOINT_DISPOSITION=ready ;; completion-v1-reconcile\ disposition=reconciled\ *) FO_CHECKPOINT_DISPOSITION=reconciled ;; *) return 5 ;; esac
  case "$FO_CHECKPOINT_DISPOSITION" in ready|reconciled) printf '%s\n' "$FO_COMPLETION_CHECKPOINT" ;; esac
}

fo_plan_attempt_begin() {
  local entity="$1" worker="$2" started_at="$3" begin tag disposition attempt_id budget extra common_dir begin_rc rollback_rc
  fo_completion_begin "$entity" plan plan plan.md "$worker" || return
  FO_PLAN_ATTEMPT_STAGE_RUN_ID="$FO_COMPLETION_BEFORE"
  FO_PLAN_ATTEMPT_STARTED_AT="$started_at"
  begin="$(bash "$_FO_STAGE_ATTEMPT_HELPER" begin \
    --entity="$entity" --stage=plan --stage-run-id="$FO_PLAN_ATTEMPT_STAGE_RUN_ID" \
    --ref="$FO_COMPLETION_REF" --attempt-before="$FO_COMPLETION_BEFORE" \
    --worker-id="$worker" --lease-token="$FO_COMPLETION_TOKEN" \
    --attempt-ordinal=0 --fresh-continuations-used=0 --attempt-started-at="$started_at")"
  begin_rc=$?
  if [ "$begin_rc" -ne 0 ]; then
    fo_plan_attempt_release_failed_begin_lease
    rollback_rc=$?
    [ "$rollback_rc" = 0 ] || return "$rollback_rc"
    return "$begin_rc"
  fi
  IFS=' ' read -r tag disposition attempt_id budget extra <<< "$begin"
  disposition="${disposition#disposition=}"; attempt_id="${attempt_id#attempt_id=}"; budget="${budget#budget_seconds=}"
  [ "$tag" = stage-attempt-v1 ] && [ "$disposition" = open ] && [ "$budget" = 1200 ] && [ -z "$extra" ] || return 5
  LC_ALL=C printf '%s' "$attempt_id" | grep -Eq '^sa1-[0-9a-f]{64}$' || return 5
  FO_PLAN_ATTEMPT_ID="$attempt_id"
  FO_PLAN_ATTEMPT_BUDGET="$budget"
  FO_PLAN_ATTEMPT_KEY="$(printf 'stage-attempt-v1-key\0%s\0plan' "$entity" | fo_plan_attempt_sha256_stream)" || return
  common_dir="$(git rev-parse --git-common-dir)" || return 5
  case "$common_dir" in /*) ;; *) common_dir="$(pwd)/$common_dir" ;; esac
  FO_PLAN_ATTEMPT_STORE="$common_dir/spacedock-stage-attempt-v1"
  FO_PLAN_ATTEMPT_WAL="$FO_PLAN_ATTEMPT_STORE/$FO_PLAN_ATTEMPT_KEY.wal"
  [ -f "$FO_PLAN_ATTEMPT_WAL" ] && [ ! -L "$FO_PLAN_ATTEMPT_WAL" ] || return 5
  # shellcheck disable=SC2034 # sourced callers prepend this generated block to plan assignments
  printf -v FO_PLAN_ATTEMPT_ENV_BLOCK '%s; export SHIP_FLOW_STAGE_ATTEMPT_ID=%q SHIP_FLOW_STAGE_RUN_ID=%q SHIP_FLOW_STAGE_ATTEMPT_BEFORE=%q SHIP_FLOW_STAGE_ATTEMPT_STARTED_AT=%q SHIP_FLOW_STAGE_ATTEMPT_BUDGET_SECONDS=%q SHIP_FLOW_STAGE_ATTEMPT_ORDINAL=0 SHIP_FLOW_STAGE_ATTEMPT_FRESH_CONTINUATIONS_USED=0' \
    "$FO_COMPLETION_ENV_BLOCK" "$FO_PLAN_ATTEMPT_ID" "$FO_PLAN_ATTEMPT_STAGE_RUN_ID" \
    "$FO_COMPLETION_BEFORE" "$FO_PLAN_ATTEMPT_STARTED_AT" "$FO_PLAN_ATTEMPT_BUDGET"
  printf '%s\n' "$begin"
}

fo_plan_attempt_checkpoint() {
  local receipt="$1" finished_at="$2" tag disposition ref before completion entity stage artifact extra
  local elapsed_line elapsed expired artifact_repo artifact_oid completion_sha lease_sha worker_hex entity_hex ref_hex terminal_id
  local bundle accept terminal wal_line completion_returned_lease lease_token helper_rc
  IFS=' ' read -r tag disposition ref before completion entity stage artifact extra <<< "$receipt"
  [ "$tag" = completion-v1 ] && [ -z "$extra" ] || return 5
  disposition="${disposition#disposition=}"; ref="${ref#ref=}"; before="${before#before=}"; completion="${completion#completion=}"
  entity="${entity#entity=}"; stage="${stage#stage=}"; artifact="${artifact#artifact=}"
  case "$disposition" in published|already-registered) ;; *) return 5 ;; esac
  [ "$receipt" = "completion-v1 disposition=$disposition ref=$ref before=$before completion=$completion entity=$entity stage=$stage artifact=$artifact" ] || return 5
  [ "$ref" = "$FO_COMPLETION_REF" ] && [ "$before" = "$FO_COMPLETION_BEFORE" ] &&
    [ "$entity" = "$FO_COMPLETION_ENTITY" ] && [ "$stage" = plan ] && [ "$artifact" = plan.md ] || return 5
  [ "$(git rev-parse --verify "$ref^{commit}" 2>/dev/null)" = "$completion" ] || return 5
  artifact_repo="${entity%/index.md}/$artifact"
  artifact_oid="$(git rev-parse --verify "$completion:$artifact_repo" 2>/dev/null)" || return 5
  elapsed_line="$(bash "$_FO_STAGE_ATTEMPT_HELPER" elapsed --entity="$entity" --stage=plan)" || return
  case "$elapsed_line" in 'stage-attempt-v1 elapsed_seconds='*' expired=no') ;; *) return 5 ;; esac
  elapsed="${elapsed_line#stage-attempt-v1 elapsed_seconds=}"; expired="${elapsed#* expired=}"; elapsed="${elapsed%% expired=*}"
  [ "$expired" = no ] && LC_ALL=C printf '%s' "$elapsed" | grep -Eq '^(0|[1-9][0-9]*)$' || return 5
  wal_line="$(sed -n '1p' "$FO_PLAN_ATTEMPT_WAL")" || return 5
  case "$wal_line" in
    "stage-attempt-wal-v1 entity_stage_key=$FO_PLAN_ATTEMPT_KEY "*" stage=plan stage_run_id=$FO_PLAN_ATTEMPT_STAGE_RUN_ID "*" attempt_before_oid=$FO_COMPLETION_BEFORE "*" attempt_id=$FO_PLAN_ATTEMPT_ID attempt_ordinal=0 attempt_started_at=$FO_PLAN_ATTEMPT_STARTED_AT "*" budget_seconds=1200 state=open fresh_continuations_used=0 returned_bundle_sha256=none") ;;
    *) return 5 ;;
  esac
  completion_sha="$(printf '%s\n' "$receipt" | fo_plan_attempt_sha256_stream)" || return
  lease_sha="$(printf '%s' "$FO_COMPLETION_TOKEN" | fo_plan_attempt_sha256_stream)" || return
  worker_hex="$(printf '%s' "$FO_COMPLETION_WORKER" | fo_plan_attempt_hex)"
  entity_hex="$(printf '%s' "$entity" | fo_plan_attempt_hex)"
  ref_hex="$(printf '%s' "$ref" | fo_plan_attempt_hex)"
  terminal_id="sev1-$(printf 'stage-attempt-v1-terminal\0%s\0%s\0%s' "$FO_PLAN_ATTEMPT_KEY" "$FO_PLAN_ATTEMPT_STAGE_RUN_ID" "$FO_PLAN_ATTEMPT_ID" | fo_plan_attempt_sha256_stream)"
  bundle="$(mktemp "$FO_PLAN_ATTEMPT_STORE/$FO_PLAN_ATTEMPT_KEY.caller.XXXXXX")" || return 1
  chmod 600 "$bundle" || { rm -f "$bundle"; return 1; }
  printf 'stage-attempt-v1 entity_stage_key=%s entity_path_hex=%s stage=plan stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_completion_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=0 attempt_started_at=%s budget_seconds=1200 attempt_elapsed_seconds=%s fresh_continuations_used=0 outcome=passed artifact_path_hex=%s artifact_oid=%s completion_receipt_sha256=%s terminal_event_id=%s\ncompletion-v1-begin\n%s\ncompletion-v1-end\n' \
    "$FO_PLAN_ATTEMPT_KEY" "$entity_hex" "$FO_PLAN_ATTEMPT_STAGE_RUN_ID" "$ref_hex" "$FO_COMPLETION_BEFORE" \
    "$completion" "$worker_hex" "$lease_sha" "$FO_PLAN_ATTEMPT_ID" "$FO_PLAN_ATTEMPT_STARTED_AT" "$elapsed" \
    "$(printf '%s' "$artifact" | fo_plan_attempt_hex)" "$artifact_oid" "$completion_sha" "$terminal_id" "$receipt" > "$bundle" || {
      rm -f "$bundle"; return 1
    }
  accept="$(bash "$_FO_STAGE_ATTEMPT_HELPER" accept-return --entity="$entity" --stage=plan \
    --lease-token="$FO_COMPLETION_TOKEN" --bundle="$bundle")"
  helper_rc=$?
  if [ "$helper_rc" -ne 0 ]; then
    rm -f "$bundle" || return 8
    return "$helper_rc"
  fi
  case "$accept" in 'stage-attempt-v1 disposition=returned returned_bundle_sha256='*) ;; *) rm -f "$bundle"; return 5 ;; esac
  completion_returned_lease="$FO_COMPLETION_GITDIR/completion-v1.lease/returned"
  lease_token="$FO_COMPLETION_TOKEN"
  terminal="$(FO_COMPLETION_LIFECYCLE_ACTION=plan-attempt-checkpoint \
    FO_PLAN_ATTEMPT_COMPLETION_RECEIPT="$receipt" \
    FO_COMPLETION_ENTITY="$FO_COMPLETION_ENTITY" FO_COMPLETION_STATUS="$FO_COMPLETION_STATUS" \
    FO_COMPLETION_STAGE="$FO_COMPLETION_STAGE" FO_COMPLETION_FILE="$FO_COMPLETION_FILE" \
    FO_COMPLETION_WORKER="$FO_COMPLETION_WORKER" FO_COMPLETION_REF="$FO_COMPLETION_REF" \
    FO_COMPLETION_BEFORE="$FO_COMPLETION_BEFORE" FO_COMPLETION_BEFORE_TREE="$FO_COMPLETION_BEFORE_TREE" \
    FO_COMPLETION_GITDIR="$FO_COMPLETION_GITDIR" FO_COMPLETION_TOKEN="$FO_COMPLETION_TOKEN" \
    SHIP_FLOW_COMPLETION_LEASE_FILE="$SHIP_FLOW_COMPLETION_LEASE_FILE" \
    SHIP_FLOW_COMPLETION_LEASE_TOKEN="$SHIP_FLOW_COMPLETION_LEASE_TOKEN" \
    SHIP_FLOW_COMPLETION_WORKER_ID="$SHIP_FLOW_COMPLETION_WORKER_ID" \
    STAGE_ATTEMPT_COMPLETION_CHECKPOINT_CMD="$_FO_COMPLETION_LIFECYCLE_DIR/fo-completion-lifecycle.sh" \
    STAGE_ATTEMPT_COMPLETION_LEASE="$completion_returned_lease" \
    bash "$_FO_STAGE_ATTEMPT_HELPER" terminal --entity="$entity" --stage=plan \
      --lease-token="$lease_token" --finished-at="$finished_at")"
  helper_rc=$?
  if [ "$helper_rc" -ne 0 ]; then
    rm -f "$bundle" || return 8
    return "$helper_rc"
  fi
  rm -f "$bundle"
  printf '%s\n%s\n' "$accept" "$terminal"
}

if [ "${BASH_SOURCE[0]}" = "$0" ] && [ "${FO_COMPLETION_LIFECYCLE_ACTION:-}" = plan-attempt-checkpoint ]; then
  [ -n "${FO_PLAN_ATTEMPT_COMPLETION_RECEIPT:-}" ] || exit 5
  fo_completion_checkpoint "$FO_PLAN_ATTEMPT_COMPLETION_RECEIPT"
fi
