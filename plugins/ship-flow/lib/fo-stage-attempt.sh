#!/usr/bin/env bash

stage_attempt_error() {
  printf 'stage-attempt-v1[%s]: %s\n' "$1" "$2" >&2
  return "$1"
}

stage_attempt_sha256_stream() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum | awk '{print $1}'
  else
    shasum -a 256 | awk '{print $1}'
  fi
}

stage_attempt_sha256_file() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

stage_attempt_hex() {
  LC_ALL=C od -An -v -t x1 | tr -d ' \n'
}

stage_attempt_unhex() {
  node -e 'process.stdout.write(Buffer.from(process.argv[1], "hex"))' "$1"
}

stage_attempt_uint_ok() {
  LC_ALL=C printf '%s' "$1" | grep -Eq '^(0|[1-9][0-9]*)$'
}

stage_attempt_hex_ok() {
  [ -n "$1" ] && [ $((${#1} % 2)) -eq 0 ] &&
    LC_ALL=C printf '%s' "$1" | grep -Eq '^[0-9a-f]+$'
}

stage_attempt_hex64_ok() {
  LC_ALL=C printf '%s' "$1" | grep -Eq '^[0-9a-f]{64}$'
}

stage_attempt_oid_ok() {
  case "$STAGE_ATTEMPT_OBJECT_FORMAT" in
    sha1) LC_ALL=C printf '%s' "$1" | grep -Eq '^[0-9a-f]{40}$' ;;
    sha256) LC_ALL=C printf '%s' "$1" | grep -Eq '^[0-9a-f]{64}$' ;;
    *) return 1 ;;
  esac
}

stage_attempt_timestamp_ok() {
  LC_ALL=C printf '%s' "$1" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}T[0-9]{2}:[0-9]{2}:[0-9]{2}Z$'
}

stage_attempt_boot_uuid_ok() {
  LC_ALL=C printf '%s' "$1" | grep -Eq '^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$'
}

stage_attempt_boot_identity() {
  local source raw normalized
  STAGE_ATTEMPT_BOOT_VALUE=''
  STAGE_ATTEMPT_CLOCK_REASON='clock-identity-loss'
  if [ "${STAGE_ATTEMPT_BOOT_ID_SOURCE+x}" = x ]; then
    source="$STAGE_ATTEMPT_BOOT_ID_SOURCE"
    [ -n "$source" ] && [ -f "$source" ] && [ ! -L "$source" ] || return 1
    raw="$(sed -n '1p' "$source")"
    STAGE_ATTEMPT_CLOCK_REASON='clock-identity-unparseable'
    stage_attempt_boot_uuid_ok "$raw" || return 1
    normalized="$(LC_ALL=C printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  elif [ -r /proc/sys/kernel/random/boot_id ]; then
    raw="$(sed -n '1p' /proc/sys/kernel/random/boot_id)"
    STAGE_ATTEMPT_CLOCK_REASON='clock-identity-unparseable'
    stage_attempt_boot_uuid_ok "$raw" || return 1
    normalized="$(LC_ALL=C printf '%s' "$raw" | tr '[:upper:]' '[:lower:]')"
  elif command -v sysctl >/dev/null 2>&1; then
    raw="$(sysctl -n kern.boottime 2>/dev/null)" || return 1
    normalized="$(LC_ALL=C printf '%s\n' "$raw" |
      sed -n 's/.*{ sec = \([0-9][0-9]*\), usec = \([0-9][0-9]*\) }.*/kern.boottime:sec=\1,usec=\2/p')"
    STAGE_ATTEMPT_CLOCK_REASON='clock-identity-unparseable'
    [ -n "$normalized" ] || return 1
  else
    return 1
  fi
  STAGE_ATTEMPT_BOOT_VALUE="$normalized"
}

stage_attempt_monotonic_now() {
  STAGE_ATTEMPT_NOW_NS=''
  if [ "${STAGE_ATTEMPT_MONOTONIC_NS+x}" = x ]; then
    STAGE_ATTEMPT_NOW_NS="$STAGE_ATTEMPT_MONOTONIC_NS"
  else
    STAGE_ATTEMPT_NOW_NS="$(node -e 'process.stdout.write(process.hrtime.bigint().toString())' 2>/dev/null)" || return 1
  fi
  stage_attempt_uint_ok "$STAGE_ATTEMPT_NOW_NS"
}

stage_attempt_monotonic_eval() {
  local now="$1" started="$2" budget="${3:-}" result elapsed expired
  result="$(node -e '
    const now = BigInt(process.argv[1]);
    const started = BigInt(process.argv[2]);
    const budget = process.argv[3];
    if (now < started) {
      process.stdout.write("regression");
    } else if (budget === "") {
      process.stdout.write("continuous");
    } else {
      const elapsed = (now - started) / 1000000000n;
      const expired = elapsed > BigInt(budget) ? "yes" : "no";
      process.stdout.write("elapsed_seconds=" + elapsed.toString() + " expired=" + expired);
    }
  ' "$now" "$started" "$budget" 2>/dev/null)" || return 1
  case "$result" in
    continuous|regression) ;;
    'elapsed_seconds='*' expired='*)
      elapsed="${result#elapsed_seconds=}"
      expired="${elapsed#* expired=}"
      elapsed="${elapsed%% expired=*}"
      stage_attempt_uint_ok "$elapsed" || return 1
      case "$expired" in yes|no) ;; *) return 1 ;; esac
      ;;
    *) return 1 ;;
  esac
  STAGE_ATTEMPT_CLOCK_EVAL="$result"
}

stage_attempt_uint_gt() {
  local left="$1" right="$2" result
  result="$(node -e '
    const left = BigInt(process.argv[1]);
    const right = BigInt(process.argv[2]);
    process.stdout.write(left > right ? "yes" : "no");
  ' "$left" "$right" 2>/dev/null)" || return 1
  case "$result" in yes|no) ;; *) return 1 ;; esac
  STAGE_ATTEMPT_UINT_GT="$result"
}

stage_attempt_resume_refused() {
  printf 'stage-attempt-v1 disposition=resume-refused reason=%s\n' "$1"
  return 5
}

stage_attempt_field() {
  local token="$1" name="$2"
  case "$token" in
    "$name"=*) printf '%s' "${token#*=}" ;;
    *) return 1 ;;
  esac
}

stage_attempt_repo_context() {
  local common
  STAGE_ATTEMPT_OBJECT_FORMAT="$(git rev-parse --show-object-format 2>/dev/null || printf 'sha1')"
  case "$STAGE_ATTEMPT_OBJECT_FORMAT" in sha1|sha256) ;; *) return 1 ;; esac
  common="$(git rev-parse --git-common-dir 2>/dev/null)" || return 1
  case "$common" in
    /*) STAGE_ATTEMPT_COMMON_DIR="$common" ;;
    *) STAGE_ATTEMPT_COMMON_DIR="$(pwd)/$common" ;;
  esac
}

stage_attempt_parse_options() {
  STAGE_ATTEMPT_ENTITY=''
  STAGE_ATTEMPT_STAGE=''
  STAGE_ATTEMPT_STAGE_RUN_ID=''
  STAGE_ATTEMPT_REF=''
  STAGE_ATTEMPT_BEFORE=''
  STAGE_ATTEMPT_WORKER=''
  STAGE_ATTEMPT_LEASE_TOKEN=''
  STAGE_ATTEMPT_ORDINAL=''
  STAGE_ATTEMPT_FRESH=''
  STAGE_ATTEMPT_STARTED_AT=''
  STAGE_ATTEMPT_FINISHED_AT=''
  STAGE_ATTEMPT_BUNDLE=''
  while [ "$#" -gt 0 ]; do
    case "$1" in
      --entity=*) STAGE_ATTEMPT_ENTITY="${1#*=}" ;;
      --stage=*) STAGE_ATTEMPT_STAGE="${1#*=}" ;;
      --stage-run-id=*) STAGE_ATTEMPT_STAGE_RUN_ID="${1#*=}" ;;
      --ref=*) STAGE_ATTEMPT_REF="${1#*=}" ;;
      --attempt-before=*) STAGE_ATTEMPT_BEFORE="${1#*=}" ;;
      --worker-id=*) STAGE_ATTEMPT_WORKER="${1#*=}" ;;
      --lease-token=*) STAGE_ATTEMPT_LEASE_TOKEN="${1#*=}" ;;
      --attempt-ordinal=*) STAGE_ATTEMPT_ORDINAL="${1#*=}" ;;
      --fresh-continuations-used=*) STAGE_ATTEMPT_FRESH="${1#*=}" ;;
      --attempt-started-at=*) STAGE_ATTEMPT_STARTED_AT="${1#*=}" ;;
      --finished-at=*) STAGE_ATTEMPT_FINISHED_AT="${1#*=}" ;;
      --bundle=*) STAGE_ATTEMPT_BUNDLE="${1#*=}" ;;
      *) stage_attempt_error 2 "unknown option: $1"; return 2 ;;
    esac
    shift
  done
}

stage_attempt_stage_ok() {
  case "$1" in plan|execute) return 0 ;; *) return 1 ;; esac
}

stage_attempt_entity_ok() {
  case "$1" in ''|/*|*\\*|*//*|./*|*/./*|*/.|../*|*/../*|*/..|.) return 1 ;; *) return 0 ;; esac
}

stage_attempt_ref_ok() {
  case "$1" in refs/heads/*) git check-ref-format "$1" >/dev/null 2>&1 ;; *) return 1 ;; esac
}

stage_attempt_paths() {
  STAGE_ATTEMPT_KEY="$(printf 'stage-attempt-v1-key\0%s\0%s' "$STAGE_ATTEMPT_ENTITY" "$STAGE_ATTEMPT_STAGE" | stage_attempt_sha256_stream)"
  STAGE_ATTEMPT_STORE="$STAGE_ATTEMPT_COMMON_DIR/spacedock-stage-attempt-v1"
  STAGE_ATTEMPT_LOCK="$STAGE_ATTEMPT_STORE/$STAGE_ATTEMPT_KEY.lock"
  STAGE_ATTEMPT_WAL="$STAGE_ATTEMPT_STORE/$STAGE_ATTEMPT_KEY.wal"
  STAGE_ATTEMPT_RETURNED="$STAGE_ATTEMPT_STORE/$STAGE_ATTEMPT_KEY.returned"
}

stage_attempt_cleanup() {
  if [ -n "${STAGE_ATTEMPT_SNAPSHOT:-}" ]; then
    rm -f "$STAGE_ATTEMPT_SNAPSHOT"
    STAGE_ATTEMPT_SNAPSHOT=''
  fi
  if [ -n "${STAGE_ATTEMPT_LOCK_HELD:-}" ]; then
    rmdir "$STAGE_ATTEMPT_LOCK_HELD" 2>/dev/null || true
    STAGE_ATTEMPT_LOCK_HELD=''
  fi
}

stage_attempt_on_exit() {
  local rc=$?
  stage_attempt_cleanup
  trap - EXIT
  exit "$rc"
}

stage_attempt_lock_acquire() {
  mkdir "$STAGE_ATTEMPT_LOCK" 2>/dev/null || { stage_attempt_error 2 'attempt transition locked'; return 2; }
  STAGE_ATTEMPT_LOCK_HELD="$STAGE_ATTEMPT_LOCK"
  trap stage_attempt_on_exit EXIT
  trap 'exit 129' HUP
  trap 'exit 130' INT
  trap 'exit 143' TERM
}

stage_attempt_snapshot_bundle() {
  local source="$1"
  STAGE_ATTEMPT_SNAPSHOT="$(mktemp "$STAGE_ATTEMPT_STORE/$STAGE_ATTEMPT_KEY.bundle.XXXXXX")" || return 1
  if ! cp -- "$source" "$STAGE_ATTEMPT_SNAPSHOT"; then
    rm -f "$STAGE_ATTEMPT_SNAPSHOT"
    STAGE_ATTEMPT_SNAPSHOT=''
    return 1
  fi
  chmod 400 "$STAGE_ATTEMPT_SNAPSHOT" || return 1
}

stage_attempt_write_wal() {
  local target="$1" state="$2" returned_sha="$3" tmp
  tmp="$target.tmp.$$"
  umask 077
  printf 'stage-attempt-wal-v1 entity_stage_key=%s entity_path_hex=%s stage=%s stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=%s attempt_started_at=%s boot_id_sha256=%s monotonic_started_ns=%s budget_seconds=%s state=%s fresh_continuations_used=%s returned_bundle_sha256=%s\n' \
    "$WAL_KEY" "$WAL_ENTITY_HEX" "$WAL_STAGE" "$WAL_STAGE_RUN_ID" "$WAL_REF_HEX" \
    "$WAL_BEFORE" "$WAL_WORKER_HEX" "$WAL_LEASE_SHA" "$WAL_ATTEMPT_ID" "$WAL_ORDINAL" \
    "$WAL_STARTED_AT" "$WAL_BOOT_SHA" "$WAL_MONOTONIC_NS" "$WAL_BUDGET" "$state" \
    "$WAL_FRESH" "$returned_sha" > "$tmp" || return 1
  mv "$tmp" "$target"
}

stage_attempt_begin() {
  local boot_value budget attempt_hash
  stage_attempt_parse_options "$@" || return $?
  stage_attempt_repo_context || { stage_attempt_error 2 'not a supported Git repository'; return 2; }
  stage_attempt_stage_ok "$STAGE_ATTEMPT_STAGE" || { stage_attempt_error 2 'stage must be plan or execute'; return 2; }
  stage_attempt_entity_ok "$STAGE_ATTEMPT_ENTITY" || { stage_attempt_error 2 'invalid entity path'; return 2; }
  if ! { stage_attempt_oid_ok "$STAGE_ATTEMPT_STAGE_RUN_ID" && stage_attempt_oid_ok "$STAGE_ATTEMPT_BEFORE"; }; then
    stage_attempt_error 2 'invalid Git OID'; return 2
  fi
  stage_attempt_ref_ok "$STAGE_ATTEMPT_REF" || { stage_attempt_error 2 'invalid ref'; return 2; }
  [ -n "$STAGE_ATTEMPT_WORKER" ] && [ -n "$STAGE_ATTEMPT_LEASE_TOKEN" ] || { stage_attempt_error 2 'worker and lease are required'; return 2; }
  if ! { stage_attempt_uint_ok "$STAGE_ATTEMPT_ORDINAL" &&
    case "$STAGE_ATTEMPT_FRESH" in 0|1) true ;; *) false ;; esac &&
    stage_attempt_timestamp_ok "$STAGE_ATTEMPT_STARTED_AT"; }; then
    stage_attempt_error 2 'invalid attempt metadata'; return 2
  fi
  stage_attempt_boot_identity || { stage_attempt_error 2 'boot identity unavailable or unparseable'; return 2; }
  boot_value="$STAGE_ATTEMPT_BOOT_VALUE"
  stage_attempt_monotonic_now || { stage_attempt_error 2 'monotonic start unavailable'; return 2; }

  stage_attempt_paths
  mkdir -p "$STAGE_ATTEMPT_STORE" || return 1
  stage_attempt_lock_acquire || return $?
  [ ! -e "$STAGE_ATTEMPT_WAL" ] || { stage_attempt_error 2 'attempt already active'; return 2; }
  case "$STAGE_ATTEMPT_STAGE" in plan) budget=1200 ;; execute) budget=1800 ;; esac

  WAL_KEY="$STAGE_ATTEMPT_KEY"
  WAL_ENTITY_HEX="$(printf '%s' "$STAGE_ATTEMPT_ENTITY" | stage_attempt_hex)"
  WAL_STAGE="$STAGE_ATTEMPT_STAGE"
  WAL_STAGE_RUN_ID="$STAGE_ATTEMPT_STAGE_RUN_ID"
  WAL_REF_HEX="$(printf '%s' "$STAGE_ATTEMPT_REF" | stage_attempt_hex)"
  WAL_BEFORE="$STAGE_ATTEMPT_BEFORE"
  WAL_WORKER_HEX="$(printf '%s' "$STAGE_ATTEMPT_WORKER" | stage_attempt_hex)"
  WAL_LEASE_SHA="$(printf '%s' "$STAGE_ATTEMPT_LEASE_TOKEN" | stage_attempt_sha256_stream)"
  attempt_hash="$(printf 'stage-attempt-v1-attempt\0%s\0%s\0%s\0%s\0%s\0%s' \
    "$WAL_KEY" "$WAL_STAGE_RUN_ID" "$STAGE_ATTEMPT_REF" "$WAL_BEFORE" "$STAGE_ATTEMPT_ORDINAL" "$STAGE_ATTEMPT_LEASE_TOKEN" | stage_attempt_sha256_stream)"
  WAL_ATTEMPT_ID="sa1-$attempt_hash"
  WAL_ORDINAL="$STAGE_ATTEMPT_ORDINAL"
  WAL_STARTED_AT="$STAGE_ATTEMPT_STARTED_AT"
  WAL_BOOT_SHA="$(printf '%s' "$boot_value" | stage_attempt_sha256_stream)"
  WAL_MONOTONIC_NS="$STAGE_ATTEMPT_NOW_NS"
  WAL_BUDGET="$budget"
  WAL_FRESH="$STAGE_ATTEMPT_FRESH"
  stage_attempt_write_wal "$STAGE_ATTEMPT_WAL" open none || return 1
  printf 'stage-attempt-v1 disposition=open attempt_id=%s budget_seconds=%s\n' "$WAL_ATTEMPT_ID" "$WAL_BUDGET"
}

stage_attempt_load_wal() {
  local require_lease="${1:-yes}" final_byte line canonical_line bound_ref expected_attempt_hash
  local -a fields
  [ -f "$STAGE_ATTEMPT_WAL" ] && [ ! -L "$STAGE_ATTEMPT_WAL" ] || { stage_attempt_error 2 'attempt WAL unavailable'; return 2; }
  [ "$(awk 'END { print NR + 0 }' "$STAGE_ATTEMPT_WAL")" = 1 ] || { stage_attempt_error 2 'invalid attempt WAL'; return 2; }
  final_byte="$(LC_ALL=C tail -c 1 "$STAGE_ATTEMPT_WAL" | od -An -t u1 | tr -d ' ')"
  [ "$final_byte" = 10 ] || { stage_attempt_error 2 'invalid attempt WAL'; return 2; }
  IFS= read -r line < "$STAGE_ATTEMPT_WAL"
  IFS=' ' read -r -a fields <<< "$line"
  [ "${#fields[@]}" = 18 ] && [ "${fields[0]}" = stage-attempt-wal-v1 ] || { stage_attempt_error 2 'invalid attempt WAL'; return 2; }
  if ! { WAL_KEY="$(stage_attempt_field "${fields[1]}" entity_stage_key)" &&
    WAL_ENTITY_HEX="$(stage_attempt_field "${fields[2]}" entity_path_hex)" &&
    WAL_STAGE="$(stage_attempt_field "${fields[3]}" stage)" &&
    WAL_STAGE_RUN_ID="$(stage_attempt_field "${fields[4]}" stage_run_id)" &&
    WAL_REF_HEX="$(stage_attempt_field "${fields[5]}" ref_hex)" &&
    WAL_BEFORE="$(stage_attempt_field "${fields[6]}" attempt_before_oid)" &&
    WAL_WORKER_HEX="$(stage_attempt_field "${fields[7]}" worker_id_hex)" &&
    WAL_LEASE_SHA="$(stage_attempt_field "${fields[8]}" lease_sha256)" &&
    WAL_ATTEMPT_ID="$(stage_attempt_field "${fields[9]}" attempt_id)" &&
    WAL_ORDINAL="$(stage_attempt_field "${fields[10]}" attempt_ordinal)" &&
    WAL_STARTED_AT="$(stage_attempt_field "${fields[11]}" attempt_started_at)" &&
    WAL_BOOT_SHA="$(stage_attempt_field "${fields[12]}" boot_id_sha256)" &&
    WAL_MONOTONIC_NS="$(stage_attempt_field "${fields[13]}" monotonic_started_ns)" &&
    WAL_BUDGET="$(stage_attempt_field "${fields[14]}" budget_seconds)" &&
    WAL_STATE="$(stage_attempt_field "${fields[15]}" state)" &&
    WAL_FRESH="$(stage_attempt_field "${fields[16]}" fresh_continuations_used)" &&
    WAL_RETURNED_SHA="$(stage_attempt_field "${fields[17]}" returned_bundle_sha256)"; }; then
    stage_attempt_error 2 'invalid attempt WAL'; return 2
  fi
  if ! { [ "$WAL_KEY" = "$STAGE_ATTEMPT_KEY" ] &&
    [ "$WAL_ENTITY_HEX" = "$(printf '%s' "$STAGE_ATTEMPT_ENTITY" | stage_attempt_hex)" ] &&
    [ "$WAL_STAGE" = "$STAGE_ATTEMPT_STAGE" ] &&
    stage_attempt_hex64_ok "$WAL_KEY" && stage_attempt_hex_ok "$WAL_ENTITY_HEX" &&
    stage_attempt_oid_ok "$WAL_STAGE_RUN_ID" && stage_attempt_hex_ok "$WAL_REF_HEX" &&
    stage_attempt_oid_ok "$WAL_BEFORE" && stage_attempt_hex_ok "$WAL_WORKER_HEX" &&
    stage_attempt_hex64_ok "$WAL_LEASE_SHA" &&
    LC_ALL=C printf '%s' "$WAL_ATTEMPT_ID" | grep -Eq '^sa1-[0-9a-f]{64}$' &&
    stage_attempt_uint_ok "$WAL_ORDINAL" && stage_attempt_timestamp_ok "$WAL_STARTED_AT" &&
    stage_attempt_hex64_ok "$WAL_BOOT_SHA" && stage_attempt_uint_ok "$WAL_MONOTONIC_NS" &&
    case "$WAL_STAGE/$WAL_BUDGET" in plan/1200|execute/1800) true ;; *) false ;; esac &&
    case "$WAL_FRESH" in 0|1) true ;; *) false ;; esac; }; then
    stage_attempt_error 2 'invalid attempt WAL'; return 2
  fi
  printf -v canonical_line 'stage-attempt-wal-v1 entity_stage_key=%s entity_path_hex=%s stage=%s stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=%s attempt_started_at=%s boot_id_sha256=%s monotonic_started_ns=%s budget_seconds=%s state=%s fresh_continuations_used=%s returned_bundle_sha256=%s' \
    "$WAL_KEY" "$WAL_ENTITY_HEX" "$WAL_STAGE" "$WAL_STAGE_RUN_ID" "$WAL_REF_HEX" \
    "$WAL_BEFORE" "$WAL_WORKER_HEX" "$WAL_LEASE_SHA" "$WAL_ATTEMPT_ID" "$WAL_ORDINAL" \
    "$WAL_STARTED_AT" "$WAL_BOOT_SHA" "$WAL_MONOTONIC_NS" "$WAL_BUDGET" "$WAL_STATE" \
    "$WAL_FRESH" "$WAL_RETURNED_SHA"
  [ "$line" = "$canonical_line" ] || { stage_attempt_error 2 'invalid attempt WAL'; return 2; }
  if [ "$require_lease" = yes ]; then
    bound_ref="$(stage_attempt_unhex "$WAL_REF_HEX")" || { stage_attempt_error 2 'invalid attempt WAL'; return 2; }
    if ! { [ "$(printf '%s' "$bound_ref" | stage_attempt_hex)" = "$WAL_REF_HEX" ] &&
      stage_attempt_ref_ok "$bound_ref"; }; then
      stage_attempt_error 2 'invalid attempt WAL'; return 2
    fi
    expected_attempt_hash="$(printf 'stage-attempt-v1-attempt\0%s\0%s\0%s\0%s\0%s\0%s' \
      "$WAL_KEY" "$WAL_STAGE_RUN_ID" "$bound_ref" "$WAL_BEFORE" "$WAL_ORDINAL" \
      "$STAGE_ATTEMPT_LEASE_TOKEN" | stage_attempt_sha256_stream)"
    [ "$WAL_ATTEMPT_ID" = "sa1-$expected_attempt_hash" ] || { stage_attempt_error 2 'invalid attempt WAL'; return 2; }
  fi
  case "$WAL_STATE/$WAL_RETURNED_SHA" in
    open/none|suspended/none)
      [ ! -e "$STAGE_ATTEMPT_RETURNED" ] || { stage_attempt_error 2 'invalid returned state: unexpected-sidecar'; return 2; }
      ;;
    returned/*)
      stage_attempt_hex64_ok "$WAL_RETURNED_SHA" || { stage_attempt_error 2 'invalid attempt WAL'; return 2; }
      if ! { [ -f "$STAGE_ATTEMPT_RETURNED" ] && [ ! -L "$STAGE_ATTEMPT_RETURNED" ] &&
        [ "$(stage_attempt_sha256_file "$STAGE_ATTEMPT_RETURNED")" = "$WAL_RETURNED_SHA" ]; }; then
        stage_attempt_error 2 'invalid returned state: sidecar-digest'; return 2
      fi
      ;;
    *) stage_attempt_error 2 'invalid attempt WAL'; return 2 ;;
  esac
  if [ "$require_lease" = yes ]; then
    [ "$(printf '%s' "$STAGE_ATTEMPT_LEASE_TOKEN" | stage_attempt_sha256_stream)" = "$WAL_LEASE_SHA" ] || { stage_attempt_error 2 'foreign lease token'; return 2; }
  fi
}

stage_attempt_elapsed() {
  local boot_sha
  stage_attempt_parse_options "$@" || return $?
  stage_attempt_repo_context || { stage_attempt_error 2 'not a supported Git repository'; return 2; }
  if ! { stage_attempt_stage_ok "$STAGE_ATTEMPT_STAGE" && stage_attempt_entity_ok "$STAGE_ATTEMPT_ENTITY"; }; then
    stage_attempt_error 2 'invalid elapsed request'; return 2
  fi
  stage_attempt_paths
  stage_attempt_lock_acquire || return $?
  stage_attempt_load_wal no || return $?
  stage_attempt_boot_identity || { stage_attempt_error 5 "$STAGE_ATTEMPT_CLOCK_REASON"; return 5; }
  boot_sha="$(printf '%s' "$STAGE_ATTEMPT_BOOT_VALUE" | stage_attempt_sha256_stream)"
  [ "$boot_sha" = "$WAL_BOOT_SHA" ] || { stage_attempt_error 5 'boot-identity-mismatch'; return 5; }
  stage_attempt_monotonic_now || { stage_attempt_error 5 'monotonic-clock-unavailable'; return 5; }
  stage_attempt_monotonic_eval "$STAGE_ATTEMPT_NOW_NS" "$WAL_MONOTONIC_NS" "$WAL_BUDGET" || { stage_attempt_error 5 'monotonic-clock-unavailable'; return 5; }
  [ "$STAGE_ATTEMPT_CLOCK_EVAL" != regression ] || { stage_attempt_error 5 'monotonic-regression'; return 5; }
  printf 'stage-attempt-v1 %s\n' "$STAGE_ATTEMPT_CLOCK_EVAL"
}

stage_attempt_suspend() {
  stage_attempt_parse_options "$@" || return $?
  stage_attempt_repo_context || { stage_attempt_error 2 'not a supported Git repository'; return 2; }
  if ! { stage_attempt_stage_ok "$STAGE_ATTEMPT_STAGE" && stage_attempt_entity_ok "$STAGE_ATTEMPT_ENTITY" &&
    [ -n "$STAGE_ATTEMPT_LEASE_TOKEN" ]; }; then
    stage_attempt_error 2 'invalid suspend request'; return 2
  fi
  stage_attempt_paths
  stage_attempt_lock_acquire || return $?
  stage_attempt_load_wal || return $?
  [ "$WAL_STATE" = open ] || { stage_attempt_error 2 'attempt is not open'; return 2; }
  stage_attempt_write_wal "$STAGE_ATTEMPT_WAL" suspended none
}

stage_attempt_resume() {
  local boot_sha
  stage_attempt_parse_options "$@" || return $?
  stage_attempt_repo_context || { stage_attempt_error 2 'not a supported Git repository'; return 2; }
  if ! { stage_attempt_stage_ok "$STAGE_ATTEMPT_STAGE" && stage_attempt_entity_ok "$STAGE_ATTEMPT_ENTITY" &&
    [ -n "$STAGE_ATTEMPT_LEASE_TOKEN" ]; }; then
    stage_attempt_error 2 'invalid resume request'; return 2
  fi
  stage_attempt_paths
  stage_attempt_lock_acquire || return $?
  stage_attempt_load_wal || return $?
  [ "$WAL_STATE" = suspended ] || { stage_attempt_error 2 'attempt is not suspended'; return 2; }
  stage_attempt_boot_identity || { stage_attempt_resume_refused "$STAGE_ATTEMPT_CLOCK_REASON"; return $?; }
  boot_sha="$(printf '%s' "$STAGE_ATTEMPT_BOOT_VALUE" | stage_attempt_sha256_stream)"
  [ "$boot_sha" = "$WAL_BOOT_SHA" ] || { stage_attempt_resume_refused boot-identity-mismatch; return $?; }
  stage_attempt_monotonic_now || { stage_attempt_resume_refused monotonic-clock-unavailable; return $?; }
  stage_attempt_monotonic_eval "$STAGE_ATTEMPT_NOW_NS" "$WAL_MONOTONIC_NS" || { stage_attempt_resume_refused monotonic-clock-unavailable; return $?; }
  [ "$STAGE_ATTEMPT_CLOCK_EVAL" = continuous ] || { stage_attempt_resume_refused monotonic-regression; return $?; }
  stage_attempt_write_wal "$STAGE_ATTEMPT_WAL" open none
}

stage_attempt_completion_line_ok() {
  local line="$1" canonical
  local -a fields
  IFS=' ' read -r -a fields <<< "$line"
  [ "${#fields[@]}" = 8 ] && [ "${fields[0]}" = completion-v1 ] || return 1
  case "${fields[1]}" in disposition=published|disposition=already-registered) ;; *) return 1 ;; esac
  case "${fields[2]}" in ref=refs/heads/*) ;; *) return 1 ;; esac
  case "${fields[3]}" in before=*) stage_attempt_oid_ok "${fields[3]#*=}" || return 1 ;; *) return 1 ;; esac
  case "${fields[4]}" in completion=*) stage_attempt_oid_ok "${fields[4]#*=}" || return 1 ;; *) return 1 ;; esac
  case "${fields[5]}" in entity=?*) ;; *) return 1 ;; esac
  case "${fields[6]}" in stage=plan|stage=execute) ;; *) return 1 ;; esac
  case "${fields[7]}" in artifact=?*) ;; *) return 1 ;; esac
  printf -v canonical '%s %s %s %s %s %s %s %s' \
    "${fields[0]}" "${fields[1]}" "${fields[2]}" "${fields[3]}" \
    "${fields[4]}" "${fields[5]}" "${fields[6]}" "${fields[7]}"
  [ "$line" = "$canonical" ] || return 1
  STAGE_ATTEMPT_COMPLETION_REF="${fields[2]#*=}"
  STAGE_ATTEMPT_COMPLETION_BEFORE="${fields[3]#*=}"
  STAGE_ATTEMPT_COMPLETION_OID="${fields[4]#*=}"
  STAGE_ATTEMPT_COMPLETION_ENTITY="${fields[5]#*=}"
  STAGE_ATTEMPT_COMPLETION_STAGE="${fields[6]#*=}"
  STAGE_ATTEMPT_COMPLETION_ARTIFACT="${fields[7]#*=}"
}

stage_attempt_validate_bundle() {
  local final_byte first_line line_count expected_line frame_begin completion_line frame_end actual_sha bound_ref observed_completion expected_terminal_id artifact_path artifact_repo_path expected_artifact_path expected_artifact_oid fo_elapsed fo_expired
  local -a fields
  final_byte="$(LC_ALL=C tail -c 1 "$STAGE_ATTEMPT_BUNDLE" | od -An -t u1 | tr -d ' ')"
  [ "$final_byte" = 10 ] || { stage_attempt_error 2 'invalid returned bundle: grammar'; return 2; }
  if LC_ALL=C od -An -v -t u1 "$STAGE_ATTEMPT_BUNDLE" | awk '{ for (i=1; i<=NF; i++) if ($i==9 || $i==13 || ($i<32 && $i!=10) || $i>=127) exit 1 }'; then
    true
  else
    stage_attempt_error 2 'invalid returned bundle: ascii-grammar'; return 2
  fi
  first_line="$(sed -n '1p' "$STAGE_ATTEMPT_BUNDLE")"
  line_count="$(awk 'END { print NR + 0 }' "$STAGE_ATTEMPT_BUNDLE")"
  IFS=' ' read -r -a fields <<< "$first_line"
  [ "${#fields[@]}" = 21 ] && [ "${fields[0]}" = stage-attempt-v1 ] || { stage_attempt_error 2 'invalid returned bundle: grammar'; return 2; }
  if ! { RECEIPT_KEY="$(stage_attempt_field "${fields[1]}" entity_stage_key)" &&
    RECEIPT_ENTITY_HEX="$(stage_attempt_field "${fields[2]}" entity_path_hex)" &&
    RECEIPT_STAGE="$(stage_attempt_field "${fields[3]}" stage)" &&
    RECEIPT_STAGE_RUN_ID="$(stage_attempt_field "${fields[4]}" stage_run_id)" &&
    RECEIPT_REF_HEX="$(stage_attempt_field "${fields[5]}" ref_hex)" &&
    RECEIPT_BEFORE="$(stage_attempt_field "${fields[6]}" attempt_before_oid)" &&
    RECEIPT_COMPLETION="$(stage_attempt_field "${fields[7]}" worker_completion_oid)" &&
    RECEIPT_WORKER_HEX="$(stage_attempt_field "${fields[8]}" worker_id_hex)" &&
    RECEIPT_LEASE_SHA="$(stage_attempt_field "${fields[9]}" lease_sha256)" &&
    RECEIPT_ATTEMPT_ID="$(stage_attempt_field "${fields[10]}" attempt_id)" &&
    RECEIPT_ORDINAL="$(stage_attempt_field "${fields[11]}" attempt_ordinal)" &&
    RECEIPT_STARTED_AT="$(stage_attempt_field "${fields[12]}" attempt_started_at)" &&
    RECEIPT_BUDGET="$(stage_attempt_field "${fields[13]}" budget_seconds)" &&
    RECEIPT_ELAPSED="$(stage_attempt_field "${fields[14]}" attempt_elapsed_seconds)" &&
    RECEIPT_FRESH="$(stage_attempt_field "${fields[15]}" fresh_continuations_used)" &&
    RECEIPT_OUTCOME="$(stage_attempt_field "${fields[16]}" outcome)" &&
    RECEIPT_ARTIFACT_HEX="$(stage_attempt_field "${fields[17]}" artifact_path_hex)" &&
    RECEIPT_ARTIFACT_OID="$(stage_attempt_field "${fields[18]}" artifact_oid)" &&
    RECEIPT_COMPLETION_SHA="$(stage_attempt_field "${fields[19]}" completion_receipt_sha256)" &&
    RECEIPT_TERMINAL_ID="$(stage_attempt_field "${fields[20]}" terminal_event_id)"; }; then
    stage_attempt_error 2 'invalid returned bundle: grammar'; return 2
  fi
  if ! { stage_attempt_hex64_ok "$RECEIPT_KEY" && stage_attempt_hex_ok "$RECEIPT_ENTITY_HEX" &&
    stage_attempt_stage_ok "$RECEIPT_STAGE" && stage_attempt_oid_ok "$RECEIPT_STAGE_RUN_ID" &&
    stage_attempt_hex_ok "$RECEIPT_REF_HEX" && stage_attempt_oid_ok "$RECEIPT_BEFORE" &&
    stage_attempt_oid_ok "$RECEIPT_COMPLETION" && stage_attempt_hex_ok "$RECEIPT_WORKER_HEX" &&
    stage_attempt_hex64_ok "$RECEIPT_LEASE_SHA" &&
    LC_ALL=C printf '%s' "$RECEIPT_ATTEMPT_ID" | grep -Eq '^sa1-[0-9a-f]{64}$' &&
    stage_attempt_uint_ok "$RECEIPT_ORDINAL" && stage_attempt_timestamp_ok "$RECEIPT_STARTED_AT" &&
    case "$RECEIPT_STAGE/$RECEIPT_BUDGET" in plan/1200|execute/1800) true ;; *) false ;; esac &&
    stage_attempt_uint_ok "$RECEIPT_ELAPSED" && case "$RECEIPT_FRESH" in 0|1) true ;; *) false ;; esac &&
    case "$RECEIPT_OUTCOME" in passed|partial|blocked|failed) true ;; *) false ;; esac &&
    stage_attempt_hex_ok "$RECEIPT_ARTIFACT_HEX" && stage_attempt_oid_ok "$RECEIPT_ARTIFACT_OID" &&
    case "$RECEIPT_COMPLETION_SHA" in none) true ;; *) stage_attempt_hex64_ok "$RECEIPT_COMPLETION_SHA" ;; esac &&
    LC_ALL=C printf '%s' "$RECEIPT_TERMINAL_ID" | grep -Eq '^sev1-[0-9a-f]{64}$'; }; then
    stage_attempt_error 2 'invalid returned bundle: grammar'; return 2
  fi
  printf -v expected_line 'stage-attempt-v1 entity_stage_key=%s entity_path_hex=%s stage=%s stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_completion_oid=%s worker_id_hex=%s lease_sha256=%s attempt_id=%s attempt_ordinal=%s attempt_started_at=%s budget_seconds=%s attempt_elapsed_seconds=%s fresh_continuations_used=%s outcome=%s artifact_path_hex=%s artifact_oid=%s completion_receipt_sha256=%s terminal_event_id=%s' \
    "$RECEIPT_KEY" "$RECEIPT_ENTITY_HEX" "$RECEIPT_STAGE" "$RECEIPT_STAGE_RUN_ID" "$RECEIPT_REF_HEX" \
    "$RECEIPT_BEFORE" "$RECEIPT_COMPLETION" "$RECEIPT_WORKER_HEX" "$RECEIPT_LEASE_SHA" "$RECEIPT_ATTEMPT_ID" \
    "$RECEIPT_ORDINAL" "$RECEIPT_STARTED_AT" "$RECEIPT_BUDGET" "$RECEIPT_ELAPSED" "$RECEIPT_FRESH" \
    "$RECEIPT_OUTCOME" "$RECEIPT_ARTIFACT_HEX" "$RECEIPT_ARTIFACT_OID" "$RECEIPT_COMPLETION_SHA" "$RECEIPT_TERMINAL_ID"
  [ "$first_line" = "$expected_line" ] || { stage_attempt_error 2 'invalid returned bundle: grammar'; return 2; }
  [ "$RECEIPT_STAGE_RUN_ID" = "$WAL_STAGE_RUN_ID" ] || { stage_attempt_error 2 'invalid returned bundle: foreign-stage-run'; return 2; }
  [ "$RECEIPT_REF_HEX" = "$WAL_REF_HEX" ] || { stage_attempt_error 2 'invalid returned bundle: foreign-ref'; return 2; }
  [ "$RECEIPT_BEFORE" = "$WAL_BEFORE" ] || { stage_attempt_error 2 'invalid returned bundle: foreign-before'; return 2; }
  bound_ref="$(stage_attempt_unhex "$WAL_REF_HEX")" && git check-ref-format "$bound_ref" >/dev/null 2>&1 &&
    observed_completion="$(git rev-parse --verify "${bound_ref}^{commit}" 2>/dev/null)" &&
    [ "$RECEIPT_COMPLETION" = "$observed_completion" ] || { stage_attempt_error 2 'invalid returned bundle: foreign-worker-completion'; return 2; }
  [ "$RECEIPT_WORKER_HEX" = "$WAL_WORKER_HEX" ] || { stage_attempt_error 2 'invalid returned bundle: foreign-worker'; return 2; }
  [ "$RECEIPT_LEASE_SHA" = "$WAL_LEASE_SHA" ] || { stage_attempt_error 2 'invalid returned bundle: foreign-lease'; return 2; }
  [ "$RECEIPT_ATTEMPT_ID" = "$WAL_ATTEMPT_ID" ] || { stage_attempt_error 2 'invalid returned bundle: foreign-attempt'; return 2; }
  expected_terminal_id="sev1-$(printf 'stage-attempt-v1-terminal\0%s\0%s\0%s' \
    "$RECEIPT_KEY" "$RECEIPT_STAGE_RUN_ID" "$RECEIPT_ATTEMPT_ID" | stage_attempt_sha256_stream)"
  [ "$RECEIPT_TERMINAL_ID" = "$expected_terminal_id" ] || { stage_attempt_error 2 'invalid returned bundle: terminal-event-id'; return 2; }
  [ "$RECEIPT_KEY" = "$WAL_KEY" ] && [ "$RECEIPT_ENTITY_HEX" = "$WAL_ENTITY_HEX" ] &&
    [ "$RECEIPT_STAGE" = "$WAL_STAGE" ] && [ "$RECEIPT_ORDINAL" = "$WAL_ORDINAL" ] &&
    [ "$RECEIPT_STARTED_AT" = "$WAL_STARTED_AT" ] && [ "$RECEIPT_BUDGET" = "$WAL_BUDGET" ] &&
    [ "$RECEIPT_FRESH" = "$WAL_FRESH" ] || { stage_attempt_error 2 'invalid returned bundle: attempt metadata'; return 2; }

  artifact_path="$(stage_attempt_unhex "$RECEIPT_ARTIFACT_HEX")" || { stage_attempt_error 2 'invalid returned bundle: artifact-binding'; return 2; }
  [ "$(printf '%s' "$artifact_path" | stage_attempt_hex)" = "$RECEIPT_ARTIFACT_HEX" ] || { stage_attempt_error 2 'invalid returned bundle: artifact-binding'; return 2; }
  case "$STAGE_ATTEMPT_ENTITY" in
    */index.md)
      expected_artifact_path="$RECEIPT_STAGE.md"
      artifact_repo_path="${STAGE_ATTEMPT_ENTITY%/index.md}/$expected_artifact_path"
      ;;
    *.md)
      artifact_repo_path="${STAGE_ATTEMPT_ENTITY%.md}-$RECEIPT_STAGE.md"
      expected_artifact_path="${artifact_repo_path##*/}"
      ;;
    *) stage_attempt_error 2 'invalid returned bundle: artifact-binding'; return 2 ;;
  esac
  [ "$artifact_path" = "$expected_artifact_path" ] || { stage_attempt_error 2 'invalid returned bundle: artifact-binding'; return 2; }
  if ! { expected_artifact_oid="$(git rev-parse --verify "$RECEIPT_COMPLETION:$artifact_repo_path" 2>/dev/null)" &&
    [ "$(git cat-file -t "$expected_artifact_oid" 2>/dev/null)" = blob ] &&
    [ "$RECEIPT_ARTIFACT_OID" = "$expected_artifact_oid" ]; }; then
    stage_attempt_error 2 'invalid returned bundle: artifact-binding'; return 2
  fi

  case "$RECEIPT_OUTCOME/$STAGE_ATTEMPT_ENTITY" in
    passed/*/index.md)
      [ "$RECEIPT_COMPLETION_SHA" != none ] && [ "$line_count" = 4 ] || { stage_attempt_error 2 'invalid returned bundle: completion-frame'; return 2; }
      frame_begin="$(sed -n '2p' "$STAGE_ATTEMPT_BUNDLE")"
      completion_line="$(sed -n '3p' "$STAGE_ATTEMPT_BUNDLE")"
      frame_end="$(sed -n '4p' "$STAGE_ATTEMPT_BUNDLE")"
      if ! { [ "$frame_begin" = completion-v1-begin ] && [ "$frame_end" = completion-v1-end ] &&
        stage_attempt_completion_line_ok "$completion_line"; }; then
        stage_attempt_error 2 'invalid returned bundle: completion-frame'; return 2
      fi
      if ! { [ "$STAGE_ATTEMPT_COMPLETION_REF" = "$bound_ref" ] &&
        [ "$STAGE_ATTEMPT_COMPLETION_BEFORE" = "$RECEIPT_BEFORE" ] &&
        [ "$STAGE_ATTEMPT_COMPLETION_OID" = "$RECEIPT_COMPLETION" ] &&
        [ "$STAGE_ATTEMPT_COMPLETION_ENTITY" = "$STAGE_ATTEMPT_ENTITY" ] &&
        [ "$STAGE_ATTEMPT_COMPLETION_STAGE" = "$RECEIPT_STAGE" ] &&
        [ "$STAGE_ATTEMPT_COMPLETION_ARTIFACT" = "$artifact_path" ]; }; then
        stage_attempt_error 2 'invalid returned bundle: completion-binding'; return 2
      fi
      actual_sha="$(printf '%s\n' "$completion_line" | stage_attempt_sha256_stream)"
      [ "$actual_sha" = "$RECEIPT_COMPLETION_SHA" ] || { stage_attempt_error 2 'invalid returned bundle: completion-hash'; return 2; }
      ;;
    *)
      [ "$RECEIPT_COMPLETION_SHA" = none ] || { stage_attempt_error 2 'invalid returned bundle: forbidden-completion-frame'; return 2; }
      [ "$line_count" = 1 ] || { stage_attempt_error 2 'invalid returned bundle: forbidden-completion-frame'; return 2; }
      ;;
  esac
  if [ "$RECEIPT_OUTCOME" = passed ]; then
    stage_attempt_uint_gt "$RECEIPT_ELAPSED" "$WAL_BUDGET" || { stage_attempt_error 2 'invalid returned bundle: elapsed-budget-evaluation'; return 2; }
    [ "$STAGE_ATTEMPT_UINT_GT" = no ] || { stage_attempt_error 2 'invalid returned bundle: elapsed-budget-exceeded'; return 2; }
  fi
  stage_attempt_boot_identity || { stage_attempt_error 2 "invalid returned bundle: $STAGE_ATTEMPT_CLOCK_REASON"; return 2; }
  actual_sha="$(printf '%s' "$STAGE_ATTEMPT_BOOT_VALUE" | stage_attempt_sha256_stream)"
  [ "$actual_sha" = "$WAL_BOOT_SHA" ] || { stage_attempt_error 2 'invalid returned bundle: boot-identity-mismatch'; return 2; }
  stage_attempt_monotonic_now || { stage_attempt_error 2 'invalid returned bundle: monotonic-clock-unavailable'; return 2; }
  stage_attempt_monotonic_eval "$STAGE_ATTEMPT_NOW_NS" "$WAL_MONOTONIC_NS" "$WAL_BUDGET" || { stage_attempt_error 2 'invalid returned bundle: monotonic-clock-unavailable'; return 2; }
  [ "$STAGE_ATTEMPT_CLOCK_EVAL" != regression ] || { stage_attempt_error 2 'invalid returned bundle: monotonic-regression'; return 2; }
  case "$STAGE_ATTEMPT_CLOCK_EVAL" in
    'elapsed_seconds='*' expired='*)
      fo_elapsed="${STAGE_ATTEMPT_CLOCK_EVAL#elapsed_seconds=}"
      fo_expired="${fo_elapsed#* expired=}"
      fo_elapsed="${fo_elapsed%% expired=*}"
      if [ "$RECEIPT_OUTCOME" = passed ] && [ "$fo_expired" = yes ]; then
        stage_attempt_error 2 'invalid returned bundle: elapsed-budget-exceeded'; return 2
      fi
      [ "$RECEIPT_ELAPSED" = "$fo_elapsed" ] || { stage_attempt_error 2 'invalid returned bundle: elapsed-authority-mismatch'; return 2; }
      ;;
    *) stage_attempt_error 2 'invalid returned bundle: elapsed-budget-evaluation'; return 2 ;;
  esac
}

stage_attempt_return() {
  local mode="$1" caller_bundle returned_sha
  shift
  stage_attempt_parse_options "$@" || return $?
  stage_attempt_repo_context || { stage_attempt_error 2 'not a supported Git repository'; return 2; }
  stage_attempt_stage_ok "$STAGE_ATTEMPT_STAGE" && stage_attempt_entity_ok "$STAGE_ATTEMPT_ENTITY" &&
    [ -n "$STAGE_ATTEMPT_LEASE_TOKEN" ] && [ -f "$STAGE_ATTEMPT_BUNDLE" ] && [ ! -L "$STAGE_ATTEMPT_BUNDLE" ] || { stage_attempt_error 2 'invalid return request'; return 2; }
  stage_attempt_paths
  mkdir -p "$STAGE_ATTEMPT_STORE" || return 1
  stage_attempt_lock_acquire || return $?
  stage_attempt_load_wal || return $?
  caller_bundle="$STAGE_ATTEMPT_BUNDLE"
  stage_attempt_snapshot_bundle "$caller_bundle" || return 1
  STAGE_ATTEMPT_BUNDLE="$STAGE_ATTEMPT_SNAPSHOT"
  returned_sha="$(stage_attempt_sha256_file "$STAGE_ATTEMPT_BUNDLE")"
  if [ "$WAL_STATE" = returned ]; then
    if [ "$returned_sha" = "$WAL_RETURNED_SHA" ] && cmp -s "$STAGE_ATTEMPT_BUNDLE" "$STAGE_ATTEMPT_RETURNED"; then
      printf 'stage-attempt-v1 disposition=already-returned returned_bundle_sha256=%s\n' "$WAL_RETURNED_SHA"
      return 0
    fi
    stage_attempt_error 2 'conflicting returned bundle'; return 2
  fi
  [ "$WAL_STATE" = open ] || { stage_attempt_error 2 'attempt is not open'; return 2; }
  stage_attempt_validate_bundle || return $?
  [ "$mode" = accept-return ] || return 0
  chmod 600 "$STAGE_ATTEMPT_SNAPSHOT" || return 1
  mv "$STAGE_ATTEMPT_SNAPSHOT" "$STAGE_ATTEMPT_RETURNED" || return 1
  STAGE_ATTEMPT_SNAPSHOT=''
  stage_attempt_write_wal "$STAGE_ATTEMPT_WAL" returned "$returned_sha" || return 1
  printf 'stage-attempt-v1 disposition=returned returned_bundle_sha256=%s\n' "$returned_sha"
}

stage_attempt_read_returned_fields() {
  local first_line
  local -a fields
  first_line="$(sed -n '1p' "$STAGE_ATTEMPT_RETURNED")"
  IFS=' ' read -r -a fields <<< "$first_line"
  [ "${#fields[@]}" = 21 ] && [ "${fields[0]}" = stage-attempt-v1 ] || {
    stage_attempt_error 2 'invalid returned state: grammar'; return 2
  }
  RECEIPT_KEY="${fields[1]#entity_stage_key=}"
  RECEIPT_ENTITY_HEX="${fields[2]#entity_path_hex=}"
  RECEIPT_STAGE="${fields[3]#stage=}"
  RECEIPT_STAGE_RUN_ID="${fields[4]#stage_run_id=}"
  RECEIPT_REF_HEX="${fields[5]#ref_hex=}"
  RECEIPT_BEFORE="${fields[6]#attempt_before_oid=}"
  RECEIPT_COMPLETION="${fields[7]#worker_completion_oid=}"
  RECEIPT_ATTEMPT_ID="${fields[10]#attempt_id=}"
  RECEIPT_ORDINAL="${fields[11]#attempt_ordinal=}"
  RECEIPT_STARTED_AT="${fields[12]#attempt_started_at=}"
  RECEIPT_BUDGET="${fields[13]#budget_seconds=}"
  RECEIPT_ELAPSED="${fields[14]#attempt_elapsed_seconds=}"
  RECEIPT_FRESH="${fields[15]#fresh_continuations_used=}"
  RECEIPT_OUTCOME="${fields[16]#outcome=}"
  RECEIPT_COMPLETION_SHA="${fields[19]#completion_receipt_sha256=}"
  RECEIPT_TERMINAL_ID="${fields[20]#terminal_event_id=}"
  if ! { [ "$RECEIPT_KEY" = "$WAL_KEY" ] && [ "$RECEIPT_ENTITY_HEX" = "$WAL_ENTITY_HEX" ] &&
    [ "$RECEIPT_STAGE" = "$WAL_STAGE" ] && [ "$RECEIPT_STAGE_RUN_ID" = "$WAL_STAGE_RUN_ID" ] &&
    [ "$RECEIPT_REF_HEX" = "$WAL_REF_HEX" ] && [ "$RECEIPT_BEFORE" = "$WAL_BEFORE" ] &&
    [ "$RECEIPT_ATTEMPT_ID" = "$WAL_ATTEMPT_ID" ] && [ "$RECEIPT_ORDINAL" = "$WAL_ORDINAL" ] &&
    [ "$RECEIPT_STARTED_AT" = "$WAL_STARTED_AT" ] && [ "$RECEIPT_BUDGET" = "$WAL_BUDGET" ] &&
    [ "$RECEIPT_FRESH" = "$WAL_FRESH" ]; }; then
    stage_attempt_error 2 'invalid returned state: authority-binding'; return 2
  fi
}

stage_attempt_terminal_paths() {
  STAGE_ATTEMPT_HISTORY="${STAGE_ATTEMPT_ENTITY%/index.md}/attempt-history-v1.log"
  STAGE_ATTEMPT_TRACKED_RETURN="${STAGE_ATTEMPT_ENTITY%/index.md}/attempt-return-v1.${RECEIPT_TERMINAL_ID}.receipt"
}

stage_attempt_terminal() {
  local bound_ref observed history_tmp index_file history_blob returned_blob tree terminal_commit history_line changed
  stage_attempt_parse_options "$@" || return $?
  stage_attempt_repo_context || { stage_attempt_error 2 'not a supported Git repository'; return 2; }
  if ! { [ "$STAGE_ATTEMPT_STAGE" = plan ] && stage_attempt_entity_ok "$STAGE_ATTEMPT_ENTITY" &&
    case "$STAGE_ATTEMPT_ENTITY" in */index.md) true ;; *) false ;; esac &&
    [ -n "$STAGE_ATTEMPT_LEASE_TOKEN" ] && stage_attempt_timestamp_ok "$STAGE_ATTEMPT_FINISHED_AT"; }; then
    stage_attempt_error 2 'invalid terminal request'; return 2
  fi
  stage_attempt_paths
  stage_attempt_lock_acquire || return $?
  stage_attempt_load_wal || return $?
  [ "$WAL_STATE" = returned ] || { stage_attempt_error 2 'attempt is not returned'; return 2; }
  stage_attempt_read_returned_fields || return $?
  if ! { [ "$RECEIPT_OUTCOME" = passed ] && [ "$RECEIPT_ORDINAL" = 0 ] && [ "$RECEIPT_FRESH" = 0 ] &&
    stage_attempt_oid_ok "$RECEIPT_COMPLETION" && stage_attempt_uint_ok "$RECEIPT_ELAPSED" &&
    stage_attempt_hex64_ok "$RECEIPT_COMPLETION_SHA"; }; then
    stage_attempt_error 2 'terminal supports only one fresh passed plan attempt'; return 2
  fi
  bound_ref="$(stage_attempt_unhex "$RECEIPT_REF_HEX")" || return 2
  if ! { [ "$(printf '%s' "$bound_ref" | stage_attempt_hex)" = "$RECEIPT_REF_HEX" ] &&
    stage_attempt_ref_ok "$bound_ref"; }; then
    stage_attempt_error 2 'invalid returned state: ref-binding'; return 2
  fi
  if [ -z "${STAGE_ATTEMPT_COMPLETION_CHECKPOINT_CMD:-}" ] ||
     [ ! -x "$STAGE_ATTEMPT_COMPLETION_CHECKPOINT_CMD" ] || [ -L "$STAGE_ATTEMPT_COMPLETION_CHECKPOINT_CMD" ]; then
    stage_attempt_error 2 'completion checkpoint unavailable'; return 2
  fi
  export STAGE_ATTEMPT_WAL STAGE_ATTEMPT_RETURNED STAGE_ATTEMPT_HISTORY
  STAGE_ATTEMPT_BUNDLE="$STAGE_ATTEMPT_RETURNED"
  STAGE_ATTEMPT_REF="$bound_ref"
  STAGE_ATTEMPT_WORKER_COMPLETION="$RECEIPT_COMPLETION"
  export STAGE_ATTEMPT_BUNDLE STAGE_ATTEMPT_REF STAGE_ATTEMPT_WORKER_COMPLETION
  "$STAGE_ATTEMPT_COMPLETION_CHECKPOINT_CMD" || return $?

  observed="$(git rev-parse --verify "$bound_ref^{commit}" 2>/dev/null)" || return 5
  [ "$observed" = "$RECEIPT_COMPLETION" ] || { stage_attempt_error 5 'completion checkpoint ref mismatch'; return 5; }
  stage_attempt_terminal_paths
  if [ -n "$(git status --porcelain=v1 --untracked-files=all -- "$STAGE_ATTEMPT_HISTORY" "$STAGE_ATTEMPT_TRACKED_RETURN")" ]; then
    stage_attempt_error 5 'terminal paths are dirty'; return 5
  fi
  if git cat-file -e "$observed:$STAGE_ATTEMPT_TRACKED_RETURN" 2>/dev/null; then
    stage_attempt_error 5 'terminal contribution already exists'; return 5
  fi
  history_tmp="$(mktemp "$STAGE_ATTEMPT_STORE/$STAGE_ATTEMPT_KEY.history.XXXXXX")" || return 1
  if git cat-file -e "$observed:$STAGE_ATTEMPT_HISTORY" 2>/dev/null; then
    git show "$observed:$STAGE_ATTEMPT_HISTORY" > "$history_tmp" || return 5
    if grep -Fq " terminal_event_id=$RECEIPT_TERMINAL_ID " "$history_tmp"; then
      stage_attempt_error 5 'terminal event already exists'; return 5
    fi
  else
    : > "$history_tmp"
  fi
  printf -v history_line 'stage-attempt-v1 disposition=terminal terminal_event_id=%s entity_stage_key=%s entity_path_hex=%s stage=%s stage_run_id=%s ref_hex=%s attempt_before_oid=%s worker_completion_oid=%s attempt_id=%s attempt_ordinal=%s attempt_started_at=%s attempt_finished_at=%s budget_seconds=%s elapsed_seconds=%s cumulative_elapsed_seconds=%s fresh_continuations_used=%s returned_bundle_sha256=%s completion_receipt_sha256=%s outcome=%s' \
    "$RECEIPT_TERMINAL_ID" "$RECEIPT_KEY" "$RECEIPT_ENTITY_HEX" "$RECEIPT_STAGE" "$RECEIPT_STAGE_RUN_ID" \
    "$RECEIPT_REF_HEX" "$RECEIPT_BEFORE" "$RECEIPT_COMPLETION" "$RECEIPT_ATTEMPT_ID" "$RECEIPT_ORDINAL" \
    "$RECEIPT_STARTED_AT" "$STAGE_ATTEMPT_FINISHED_AT" "$RECEIPT_BUDGET" "$RECEIPT_ELAPSED" \
    "$RECEIPT_ELAPSED" "$RECEIPT_FRESH" "$WAL_RETURNED_SHA" "$RECEIPT_COMPLETION_SHA" "$RECEIPT_OUTCOME"
  printf '%s\n' "$history_line" >> "$history_tmp" || return 1
  history_blob="$(git hash-object -w "$history_tmp")" || return 1
  returned_blob="$(git hash-object -w "$STAGE_ATTEMPT_RETURNED")" || return 1
  index_file="$(mktemp "$STAGE_ATTEMPT_STORE/$STAGE_ATTEMPT_KEY.index.XXXXXX")" || return 1
  rm -f "$index_file"
  GIT_INDEX_FILE="$index_file" git read-tree "$observed" || return 1
  GIT_INDEX_FILE="$index_file" git update-index --add --cacheinfo "100644,$history_blob,$STAGE_ATTEMPT_HISTORY" || return 1
  GIT_INDEX_FILE="$index_file" git update-index --add --cacheinfo "100644,$returned_blob,$STAGE_ATTEMPT_TRACKED_RETURN" || return 1
  tree="$(GIT_INDEX_FILE="$index_file" git write-tree)" || return 1
  terminal_commit="$(printf 'attempt(%s): record passed plan terminal\n' "$RECEIPT_ATTEMPT_ID" |
    git -c user.email="${GIT_AUTHOR_EMAIL:-fo@ship-flow}" -c user.name="${GIT_AUTHOR_NAME:-Ship-flow First Officer}" commit-tree "$tree" -p "$observed")" || return 1
  changed="$(git diff-tree --no-commit-id --name-only -r "$observed" "$terminal_commit" | sort)" || return 1
  [ "$changed" = "$(printf '%s\n%s\n' "$STAGE_ATTEMPT_HISTORY" "$STAGE_ATTEMPT_TRACKED_RETURN" | sort)" ] || {
    stage_attempt_error 5 'terminal commit changed unexpected paths'; return 5
  }
  git update-ref "$bound_ref" "$terminal_commit" "$observed" || { stage_attempt_error 9 'terminal ref CAS lost'; return 9; }
  git restore --source="$terminal_commit" --staged --worktree -- "$STAGE_ATTEMPT_HISTORY" "$STAGE_ATTEMPT_TRACKED_RETURN" || {
    stage_attempt_error 8 'terminal path reconcile failed'; return 8
  }
  cmp -s "$STAGE_ATTEMPT_RETURNED" "$STAGE_ATTEMPT_TRACKED_RETURN" || {
    stage_attempt_error 8 'tracked return reconcile mismatch'; return 8
  }
  rm -f "$STAGE_ATTEMPT_WAL" "$STAGE_ATTEMPT_RETURNED" "$history_tmp" "$index_file" || return 8
  printf 'stage-attempt-v1 disposition=terminal terminal_event_id=%s returned_bundle_sha256=%s elapsed_seconds=%s\n' \
    "$RECEIPT_TERMINAL_ID" "$WAL_RETURNED_SHA" "$RECEIPT_ELAPSED"
}

stage_attempt_main() {
  local command="${1:-}"
  [ "$#" -gt 0 ] && shift
  case "$command" in
    begin) stage_attempt_begin "$@" ;;
    elapsed) stage_attempt_elapsed "$@" ;;
    suspend) stage_attempt_suspend "$@" ;;
    resume) stage_attempt_resume "$@" ;;
    validate-return|accept-return) stage_attempt_return "$command" "$@" ;;
    terminal) stage_attempt_terminal "$@" ;;
    *) stage_attempt_error 2 'command must be begin, elapsed, suspend, resume, validate-return, accept-return, or terminal' ;;
  esac
}

stage_attempt_main "$@"
