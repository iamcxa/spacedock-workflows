#!/usr/bin/env bash
set -uo pipefail; SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/completion-v1.sh"
ACTION="${1:-}"; [ "$#" -gt 0 ] && shift
ENTITY=""; STAGE=""; WORKER=""; TOKEN=""; REF=""; BEFORE=""; repo=""; gitdir=""; format=""; symbolic=""; observed=""; observed_parent=""
for arg in "$@"; do
  case "$arg" in
    --entity=*) ENTITY="${arg#--entity=}" ;; --stage=*) STAGE="${arg#--stage=}" ;;
    --worker=*) WORKER="${arg#--worker=}" ;; --token=*) TOKEN="${arg#--token=}" ;;
    --ref=*) REF="${arg#--ref=}" ;; --before=*) BEFORE="${arg#--before=}" ;;
    *) completion_error 1 "unknown lease option: $arg"; exit $? ;;
  esac
done
case "$ACTION" in acquire|reclaim) ;; *) completion_error 1 "action must be acquire or reclaim"; exit $? ;; esac
for value in "$ENTITY" "$STAGE" "$WORKER" "$TOKEN" "$REF" "$BEFORE"; do [ -n "$value" ] || { completion_error 1 "missing lease binding"; exit $?; }; done
completion_path_ok "$ENTITY" || { completion_error 2 "invalid lease entity"; exit $?; }
completion_ref_ok "$REF" || { completion_error 2 "invalid lease ref"; exit $?; }
if ! completion_ascii "$STAGE" || ! completion_ascii "$WORKER" || ! completion_ascii "$TOKEN"; then completion_error 2 "invalid lease scalar"; exit $?; fi
case "$STAGE" in design|plan|execute|verify|review|ship) ;; *) completion_error 2 "invalid lease stage"; exit $? ;; esac
completion_capture repo git rev-parse --show-toplevel || { completion_error 3 "cannot resolve repository"; exit $?; }
cd "$repo" || exit 3
completion_capture gitdir git rev-parse --absolute-git-dir || { completion_error 3 "cannot resolve Git directory"; exit $?; }
completion_capture format git rev-parse --show-object-format || { completion_error 3 "cannot resolve object format"; exit $?; }
completion_oid_ok "$BEFORE" "$format" || { completion_error 2 "invalid before OID"; exit $?; }
completion_capture symbolic git symbolic-ref -q HEAD || { completion_error 5 "detached HEAD"; exit $?; }
completion_capture observed git rev-parse "$REF" || { completion_error 5 "cannot observe lease ref"; exit $?; }
[ "$symbolic" = "$REF" ] || { completion_error 5 "lease ref mismatch"; exit $?; }
if [ "$ACTION" = acquire ]; then
  [ "$observed" = "$BEFORE" ] || { completion_error 5 "lease before mismatch"; exit $?; }
elif [ "$observed" != "$BEFORE" ]; then
  completion_capture observed_parent git rev-parse "$observed^" || { completion_error 5 "cannot observe completion parent"; exit $?; }
  [ "$observed_parent" = "$BEFORE" ] || { completion_error 5 "reclaim ref is not bound completion"; exit $?; }
fi
lease_dir="$gitdir/completion-v1.lease"; record="$lease_dir/record"; returned="$lease_dir/returned"
if [ "$ACTION" = acquire ]; then
  umask 077
  mkdir "$lease_dir" 2>/dev/null || { completion_error 9 "completion lease already held"; exit $?; }
  if ! printf 'completion-v1-lease\nstate=delegated\ntoken=%s\nentity=%s\nstage=%s\nworker=%s\nref=%s\nbefore=%s\n' "$TOKEN" "$ENTITY" "$STAGE" "$WORKER" "$REF" "$BEFORE" > "$record"; then
    rm -f "$record"; rmdir "$lease_dir" 2>/dev/null || true
    completion_error 8 "lease record write failed"; exit $?
  fi
  printf 'completion-v1-lease disposition=acquired record=%s entity=%s stage=%s worker=%s ref=%s before=%s\n' "$record" "$ENTITY" "$STAGE" "$WORKER" "$REF" "$BEFORE"
  exit 0
fi
completion_lease_matches "$record" delegated "$TOKEN" "$ENTITY" "$STAGE" "$WORKER" "$REF" "$BEFORE" || { completion_error 5 "foreign or malformed lease"; exit $?; }
[ ! -e "$returned" ] || { completion_error 9 "lease already reclaimed"; exit $?; }
mv "$record" "$returned" || { completion_error 8 "lease reclaim failed"; exit $?; }
printf 'completion-v1-lease disposition=reclaimed record=%s entity=%s stage=%s worker=%s ref=%s before=%s\n' "$returned" "$ENTITY" "$STAGE" "$WORKER" "$REF" "$BEFORE"
