#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/completion-v1.sh"
ENTITY=""; NEW_STATUS=""; STAGE_NAME=""; STAGE_FILE=""; IF_HASH=""; COMMIT_MSG=""
LEASE_FILE=""; LEASE_TOKEN=""; WORKER_ID=""
gitdir=""; cleanliness=""
for arg in "$@"; do
  case "$arg" in
    --entity=*) ENTITY="${arg#--entity=}" ;; --new-status=*) NEW_STATUS="${arg#--new-status=}" ;;
    --stage-name=*) STAGE_NAME="${arg#--stage-name=}" ;; --stage-file=*) STAGE_FILE="${arg#--stage-file=}" ;;
    --if-hash=*) IF_HASH="${arg#--if-hash=}" ;; --commit-as=*) COMMIT_MSG="${arg#--commit-as=}" ;;
    --lease-file=*) LEASE_FILE="${arg#--lease-file=}" ;; --lease-token=*) LEASE_TOKEN="${arg#--lease-token=}" ;;
    --worker-id=*) WORKER_ID="${arg#--worker-id=}" ;;
    *) completion_error 1 "unknown option: $arg"; exit $? ;;
  esac
done
if [ -z "$ENTITY" ] || [ -z "$NEW_STATUS" ] || [ -z "$STAGE_NAME" ] || [ -z "$STAGE_FILE" ] || [ -z "$IF_HASH" ] || [ -z "$COMMIT_MSG" ] || [ -z "$LEASE_FILE" ] || [ -z "$LEASE_TOKEN" ] || [ -z "$WORKER_ID" ]; then
  completion_error 1 "usage: advance-stage.sh --entity=<folder/index.md> --new-status=<current> --stage-name=<stage> --stage-file=<file> --if-hash=<sha256> --commit-as=<audit>"
  exit $?
fi
repo="$(git rev-parse --show-toplevel 2>/dev/null)" || { completion_error 3 "not a Git repository"; exit $?; }
cd "$repo" || exit 3
completion_path_ok "$ENTITY" || { completion_error 2 "invalid canonical entity path"; exit $?; }
completion_contract_ok "$NEW_STATUS" "$STAGE_NAME" "$STAGE_FILE" || { completion_error 2 "invalid completion triple"; exit $?; }
artifact="$(dirname "$ENTITY")/$STAGE_FILE"
completion_path_ok "${artifact%/index.md}/index.md" || { completion_error 2 "invalid artifact path"; exit $?; }
ref="$(git symbolic-ref -q HEAD 2>/dev/null)" || { completion_error 4 "detached HEAD"; exit $?; }
completion_ref_ok "$ref" || { completion_error 4 "invalid branch ref"; exit $?; }
format="$(git rev-parse --show-object-format)" || exit 4
before="$(git rev-parse HEAD)" || exit 4
ref_oid="$(git rev-parse "$ref")" || exit 4
completion_oid_ok "$before" "$format" || { completion_error 4 "invalid HEAD OID"; exit $?; }
[ "$before" = "$ref_oid" ] || { completion_error 4 "HEAD/ref mismatch"; exit $?; }
completion_eligible_at_rev "$before" "$ENTITY" "$NEW_STATUS" "$STAGE_NAME" "$STAGE_FILE" || { completion_error 5 "completion ineligible at parent revision"; exit $?; }
completion_capture gitdir git rev-parse --absolute-git-dir || { completion_error 4 "cannot resolve Git directory"; exit $?; }
[ ! -e "$gitdir/index.lock" ] || { completion_error 5 "live index lock"; exit $?; }
if [ "$LEASE_FILE" != "$gitdir/completion-v1.lease/record" ] || \
  ! completion_lease_matches "$LEASE_FILE" delegated "$LEASE_TOKEN" "$ENTITY" "$STAGE_NAME" "$WORKER_ID" "$ref" "$before"; then
  completion_error 5 "missing or foreign cooperative lease"; exit $?
fi
completion_capture cleanliness git status --porcelain=v1 --untracked-files=all || { completion_error 5 "cannot observe worktree status"; exit $?; }
[ -z "$cleanliness" ] || { completion_error 5 "worktree must be globally clean before completion"; exit $?; }
entity_meta="$(completion_path_snapshot "$before" "$ENTITY")" || { completion_error 5 "entity differs across HEAD/index/worktree"; exit $?; }
artifact_meta="$(completion_path_snapshot "$before" "$artifact")" || { completion_error 5 "artifact differs across HEAD/index/worktree"; exit $?; }
actual_hash="$(completion_sha256 "$ENTITY")" || exit 6
[ "$actual_hash" = "$IF_HASH" ] || { completion_error 6 "stale entity hash"; exit $?; }
registry_state="$(completion_parse_entity "$ENTITY" "$NEW_STATUS" "$STAGE_NAME" "$STAGE_FILE")" || { completion_error 10 "malformed or stale canonical registry"; exit $?; }
rendered=""; index_file=""
cleanup() { rm -f "$rendered" "$index_file"; }
trap cleanup EXIT INT TERM
if [ "$registry_state" = PRESENT ]; then
  [ "$(git rev-parse "$ref")" = "$before" ] || { completion_error 9 "ref changed before no-op receipt"; exit $?; }
  completion_path_snapshot "$before" "$ENTITY" >/dev/null || { completion_error 5 "entity changed before no-op receipt"; exit $?; }
  completion_path_snapshot "$before" "$artifact" >/dev/null || { completion_error 5 "artifact changed before no-op receipt"; exit $?; }
  completion_emit_receipt already-registered "$ref" "$before" "$before" "$ENTITY" "$NEW_STATUS" "$STAGE_NAME" "$STAGE_FILE" "$artifact" "$format" || { completion_error 8 "no-op receipt verification failed"; exit $?; }
  exit
fi
rendered="$(mktemp)"; index_file="$(mktemp)"
completion_render "$ENTITY" "$STAGE_NAME" "$STAGE_FILE" "$rendered" || { completion_error 10 "render failed"; exit $?; }
[ "$(completion_parse_entity "$rendered" "$NEW_STATUS" "$STAGE_NAME" "$STAGE_FILE")" = PRESENT ] || { completion_error 10 "render postcondition failed"; exit $?; }
entity_mode="${entity_meta%% *}"
entity_blob="$(git hash-object -w "$rendered")" || { completion_error 8 "blob construction failed"; exit $?; }
GIT_INDEX_FILE="$index_file" git read-tree "$before" || { completion_error 8 "temporary index setup failed"; exit $?; }
GIT_INDEX_FILE="$index_file" git update-index --add --cacheinfo "$entity_mode,$entity_blob,$ENTITY" || { completion_error 8 "temporary index update failed"; exit $?; }
tree="$(GIT_INDEX_FILE="$index_file" git write-tree)" || { completion_error 8 "tree construction failed"; exit $?; }
completion="$(printf '%s\n' "$COMMIT_MSG" | git -c user.email="${GIT_AUTHOR_EMAIL:-worker@ship-flow}" -c user.name="${GIT_AUTHOR_NAME:-Ship-flow worker}" commit-tree "$tree" -p "$before")" || { completion_error 8 "commit construction failed"; exit $?; }
completion_oid_ok "$completion" "$format" || { completion_error 8 "invalid completion OID"; exit $?; }
completion_verify_commit "$before" "$completion" "$ENTITY" "$artifact" "$NEW_STATUS" "$STAGE_NAME" "$STAGE_FILE" || { completion_error 8 "detached commit verification failed"; exit $?; }
[ "$(git rev-parse "$ref")" = "$before" ] || { completion_error 9 "ref changed before CAS"; exit $?; }
[ "$(completion_path_snapshot "$before" "$ENTITY")" = "$entity_meta" ] || { completion_error 5 "entity changed before CAS"; exit $?; }
[ "$(completion_path_snapshot "$before" "$artifact")" = "$artifact_meta" ] || { completion_error 5 "artifact changed before CAS"; exit $?; }
if ! git update-ref "$ref" "$completion" "$before"; then
  observed="$(git rev-parse "$ref" 2>/dev/null || true)"
  [ "$observed" = "$completion" ] || { completion_error 9 "ref CAS lost"; exit $?; }
fi
[ "$(git rev-parse "$ref")" = "$completion" ] || { completion_error 9 "published ref moved"; exit $?; }
completion_verify_commit "$before" "$completion" "$ENTITY" "$artifact" "$NEW_STATUS" "$STAGE_NAME" "$STAGE_FILE" || { completion_error 8 "receipt verification failed"; exit $?; }
completion_emit_receipt published "$ref" "$before" "$completion" "$ENTITY" "$NEW_STATUS" "$STAGE_NAME" "$STAGE_FILE" "$artifact" "$format" || { completion_error 8 "receipt verification failed"; exit $?; }
