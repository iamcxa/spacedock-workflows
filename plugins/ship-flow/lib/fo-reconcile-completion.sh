#!/usr/bin/env bash
set -uo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/completion-v1.sh"
ENTITY=""; STATUS=""; STAGE=""; FILE=""; REF=""; BEFORE=""; COMPLETION=""; BEFORE_TREE=""; LEASE_FILE=""; LEASE_TOKEN=""; WORKER_ID=""; DISPOSITION=""
repo=""; gitdir=""; format=""; symbolic=""; observed=""; expected_tree=""; index_tree=""; parent=""; head=""
for arg in "$@"; do
  case "$arg" in
    --entity=*) ENTITY="${arg#--entity=}" ;; --new-status=*) STATUS="${arg#--new-status=}" ;;
    --stage-name=*) STAGE="${arg#--stage-name=}" ;; --stage-file=*) FILE="${arg#--stage-file=}" ;;
    --ref=*) REF="${arg#--ref=}" ;; --before=*) BEFORE="${arg#--before=}" ;;
    --completion=*) COMPLETION="${arg#--completion=}" ;; --before-tree=*) BEFORE_TREE="${arg#--before-tree=}" ;;
    --lease-file=*) LEASE_FILE="${arg#--lease-file=}" ;; --lease-token=*) LEASE_TOKEN="${arg#--lease-token=}" ;;
    --worker-id=*) WORKER_ID="${arg#--worker-id=}" ;;
    --disposition=*) DISPOSITION="${arg#--disposition=}" ;;
    *) completion_error 1 "unknown reconcile option: $arg"; exit $? ;;
  esac
done
for required in "$DISPOSITION" "$ENTITY" "$STATUS" "$STAGE" "$FILE" "$REF" "$BEFORE" "$COMPLETION" "$BEFORE_TREE" "$LEASE_FILE" "$LEASE_TOKEN" "$WORKER_ID"; do [ -n "$required" ] || { completion_error 1 "missing reconcile argument"; exit $?; }; done
case "$DISPOSITION" in published|already-registered) ;; *) completion_error 1 "invalid reconcile disposition"; exit $? ;; esac
completion_capture repo git rev-parse --show-toplevel || { completion_error 3 "not a Git repository"; exit $?; }
cd "$repo" || exit 3
completion_capture gitdir git rev-parse --absolute-git-dir || exit 3
completion_capture format git rev-parse --show-object-format || exit 3
completion_path_ok "$ENTITY" || { completion_error 2 "invalid canonical entity path"; exit $?; }
completion_ref_ok "$REF" || { completion_error 2 "invalid branch ref"; exit $?; }
completion_contract_ok "$STATUS" "$STAGE" "$FILE" || { completion_error 2 "invalid completion triple"; exit $?; }
if ! completion_oid_ok "$BEFORE" "$format" || ! completion_oid_ok "$COMPLETION" "$format" || ! completion_oid_ok "$BEFORE_TREE" "$format"; then completion_error 2 "invalid reconcile OID"; exit $?; fi
completion_ascii "$LEASE_TOKEN" || { completion_error 2 "invalid lease token"; exit $?; }
if [ "$LEASE_FILE" != "$gitdir/completion-v1.lease/returned" ] || ! completion_lease_matches "$LEASE_FILE" delegated "$LEASE_TOKEN" "$ENTITY" "$STAGE" "$WORKER_ID" "$REF" "$BEFORE"; then completion_error 5 "missing or foreign returned lease"; exit $?; fi
completion_capture symbolic git symbolic-ref -q HEAD || { completion_error 5 "detached HEAD"; exit $?; }
completion_capture observed git rev-parse "$REF" || { completion_error 5 "cannot observe completion ref"; exit $?; }
if [ "$symbolic" != "$REF" ] || [ "$observed" != "$COMPLETION" ]; then completion_error 5 "completion ref mismatch"; exit $?; fi
[ ! -e "$gitdir/index.lock" ] || { completion_error 5 "live index lock"; exit $?; }
completion_capture status_probe git status --porcelain=v1 --untracked-files=all || { completion_error 5 "cannot observe worktree status"; exit $?; }
completion_capture expected_tree git rev-parse "$BEFORE^{tree}" || { completion_error 5 "cannot observe before tree"; exit $?; }
[ "$expected_tree" = "$BEFORE_TREE" ] || { completion_error 5 "before tree mismatch"; exit $?; }
completion_capture index_tree git write-tree || { completion_error 5 "cannot observe live index tree"; exit $?; }
[ "$index_tree" = "$BEFORE_TREE" ] || { completion_error 5 "live index tree mismatch"; exit $?; }
git diff --quiet || { completion_error 5 "tracked worktree differs from parent index"; exit $?; }
completion_capture untracked git ls-files --others --exclude-standard || { completion_error 5 "cannot observe untracked state"; exit $?; }
[ -z "$untracked" ] || { completion_error 5 "untracked worktree state"; exit $?; }
artifact="$(dirname "$ENTITY")/$FILE"
completion_path_snapshot "$BEFORE" "$ENTITY" >/dev/null || { completion_error 5 "entity parent snapshot mismatch"; exit $?; }
completion_path_snapshot "$BEFORE" "$artifact" >/dev/null || { completion_error 5 "artifact parent snapshot mismatch"; exit $?; }
if [ "$DISPOSITION" = already-registered ]; then
  [ "$BEFORE" = "$COMPLETION" ] && [ -z "$status_probe" ] || { completion_error 5 "already-registered requires exact clean no-lag state"; exit $?; }
  [ "$(completion_parse_entity "$ENTITY" "$STATUS" "$STAGE" "$FILE")" = PRESENT ] || { completion_error 5 "already-registered predicate failed"; exit $?; }
  if ! rm -f "$LEASE_FILE" || ! rmdir "$(dirname "$LEASE_FILE")"; then completion_error 8 "lease release failed"; exit $?; fi
  printf 'completion-v1-reconcile disposition=ready ref=%s before=%s completion=%s entity=%s\n' "$REF" "$BEFORE" "$COMPLETION" "$ENTITY"
  exit 0
fi
completion_capture parent git rev-parse "$COMPLETION^" || { completion_error 5 "cannot observe completion parent"; exit $?; }
[ "$parent" = "$BEFORE" ] || { completion_error 5 "completion parent mismatch"; exit $?; }
completion_verify_commit "$BEFORE" "$COMPLETION" "$ENTITY" "$artifact" "$STATUS" "$STAGE" "$FILE" || { completion_error 5 "completion object verification failed"; exit $?; }
completion_capture observed git rev-parse "$REF" || { completion_error 5 "cannot re-observe completion ref"; exit $?; }
[ "$observed" = "$COMPLETION" ] || { completion_error 5 "ref moved before reconcile"; exit $?; }
git restore --source="$COMPLETION" --staged --worktree -- "$ENTITY" || { completion_error 8 "path-scoped reconcile failed"; exit $?; }
completion_capture head git rev-parse HEAD || { completion_error 8 "cannot observe post-reconcile HEAD"; exit $?; }
completion_capture observed git rev-parse "$REF" || { completion_error 8 "cannot observe post-reconcile ref"; exit $?; }
if [ "$head" != "$COMPLETION" ] || [ "$observed" != "$COMPLETION" ]; then completion_error 8 "post-reconcile ref mismatch"; exit $?; fi
completion_path_snapshot "$COMPLETION" "$ENTITY" >/dev/null || { completion_error 8 "entity reconcile postcondition failed"; exit $?; }
completion_path_snapshot "$COMPLETION" "$artifact" >/dev/null || { completion_error 8 "artifact reconcile postcondition failed"; exit $?; }
completion_capture final_status git status --porcelain=v1 --untracked-files=all || { completion_error 8 "cannot observe post-reconcile status"; exit $?; }
[ -z "$final_status" ] || { completion_error 8 "post-reconcile worktree not clean"; exit $?; }
if ! rm -f "$LEASE_FILE" || ! rmdir "$(dirname "$LEASE_FILE")"; then completion_error 8 "lease release failed"; exit $?; fi
printf 'completion-v1-reconcile disposition=reconciled ref=%s before=%s completion=%s entity=%s\n' "$REF" "$BEFORE" "$COMPLETION" "$ENTITY"
