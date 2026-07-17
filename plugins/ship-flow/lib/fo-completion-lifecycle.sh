#!/usr/bin/env bash

_FO_COMPLETION_LIFECYCLE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091 # sibling library is resolved from this helper's location
source "${_FO_COMPLETION_LIFECYCLE_DIR}/completion-v1.sh"

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
