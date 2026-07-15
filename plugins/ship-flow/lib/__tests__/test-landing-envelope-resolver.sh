#!/usr/bin/env bash
# test-landing-envelope-resolver.sh - D1/D5 landing proof contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &>/dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &>/dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/lib/resolve-landing-envelope.sh"
FIXTURE_ROOT="${SCRIPT_DIR}/fixtures/landing-envelope"

# shellcheck source=/dev/null
source "${FIXTURE_ROOT}/expected-reasons.env"

PASS=0
FAIL=0
ERRORS=()
TMP_DIR="$(mktemp -d)"
trap 'rm -rf "$TMP_DIR"' EXIT

record_pass() {
  printf '  PASS: %s\n' "$1"
  PASS=$((PASS + 1))
}

record_fail() {
  printf '  FAIL: %s\n' "$1"
  FAIL=$((FAIL + 1))
  ERRORS+=("$1")
}

field() {
  local key="$1"
  local file="$2"
  awk -F= -v key="$key" '$1 == key { sub(/^[^=]*=/, ""); print; exit }' "$file"
}

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected exit ${expected}, got ${actual})"
  fi
}

assert_field() {
  local desc="$1" file="$2" key="$3" expected="$4" actual
  actual="$(field "$key" "$file")"
  if [ "$actual" = "$expected" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (expected ${key}=${expected}, got ${actual})"
  fi
}

assert_field_nonempty() {
  local desc="$1" file="$2" key="$3" actual
  actual="$(field "$key" "$file")"
  if [ -n "$actual" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (${key} was empty)"
  fi
}

assert_fields_equal() {
  local desc="$1" file="$2" left="$3" right="$4" left_value right_value
  left_value="$(field "$left" "$file")"
  right_value="$(field "$right" "$file")"
  if [ -n "$left_value" ] && [ "$left_value" = "$right_value" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (${left}=${left_value}, ${right}=${right_value})"
  fi
}

assert_not_equal() {
  local desc="$1" left="$2" right="$3"
  if [ "$left" != "$right" ]; then
    record_pass "$desc"
  else
    record_fail "$desc (both were ${left})"
  fi
}

assert_file_contains() {
  local desc="$1" file="$2" pattern="$3"
  if grep -qF "$pattern" "$file"; then
    record_pass "$desc"
  else
    record_fail "$desc (missing literal: ${pattern})"
  fi
}

assert_not_contains() {
  local desc="$1" file="$2" pattern="$3"
  if grep -qE "$pattern" "$file"; then
    record_fail "$desc (unexpected pattern: ${pattern})"
  else
    record_pass "$desc"
  fi
}

commit_file() {
  local repo="$1" path="$2" content="$3" message="$4"
  printf '%s\n' "$content" > "${repo}/${path}"
  git -C "$repo" add -- "$path"
  git -C "$repo" commit -qm "$message"
}

init_repo() {
  local repo="$1"
  git init -q "$repo"
  git -C "$repo" branch -M main
  git -C "$repo" config user.email landing-envelope@example.test
  git -C "$repo" config user.name "Landing Envelope Fixture"
  commit_file "$repo" app.txt "base" "initial"
  INITIAL="$(git -C "$repo" rev-parse HEAD)"
}

build_landing_repo() {
  local repo="$1" topology="$2" count="$3"
  init_repo "$repo"

  git -C "$repo" checkout -qb topic "$INITIAL"
  commit_file "$repo" feature-one.txt "feature one" "source one"
  SRC1="$(git -C "$repo" rev-parse HEAD)"
  SRC2=""
  if [ "$count" -eq 2 ]; then
    commit_file "$repo" feature-two.txt "feature two" "source two"
    SRC2="$(git -C "$repo" rev-parse HEAD)"
  fi
  ORIGINAL_HEAD="$(git -C "$repo" rev-parse HEAD)"

  git -C "$repo" checkout -qb alternate "$INITIAL"
  commit_file "$repo" alternate-one.txt "alternate one" "alternate one"
  ALT1="$(git -C "$repo" rev-parse HEAD)"
  ALT2=""
  if [ "$count" -eq 2 ]; then
    commit_file "$repo" alternate-two.txt "alternate two" "alternate two"
    ALT2="$(git -C "$repo" rev-parse HEAD)"
  fi

  git -C "$repo" checkout -q main
  commit_file "$repo" main-before.txt "concurrent before" "concurrent main before landing"
  BASE_BEFORE="$(git -C "$repo" rev-parse HEAD)"

  case "$topology" in
    rebase)
      git -C "$repo" checkout -qb landed-rebase main
      git -C "$repo" cherry-pick "$SRC1" >/dev/null
      LANDED_FIRST="$(git -C "$repo" rev-parse HEAD)"
      if [ "$count" -eq 2 ]; then
        git -C "$repo" cherry-pick "$SRC2" >/dev/null
      fi
      ANCHOR="$(git -C "$repo" rev-parse HEAD)"
      git -C "$repo" checkout -q main
      git -C "$repo" merge --ff-only -q landed-rebase
      ;;
    squash)
      git -C "$repo" merge --squash -q topic >/dev/null 2>&1
      git -C "$repo" commit -qm "squash landing"
      ANCHOR="$(git -C "$repo" rev-parse HEAD)"
      LANDED_FIRST="$ANCHOR"
      ;;
    merge_commit)
      git -C "$repo" merge --no-ff -q topic -m "merge landing"
      ANCHOR="$(git -C "$repo" rev-parse HEAD)"
      LANDED_FIRST="$SRC1"
      ;;
    *)
      printf 'unknown fixture topology: %s\n' "$topology" >&2
      return 2
      ;;
  esac

  commit_file "$repo" main-after.txt "concurrent after" "concurrent main after landing"
  MAIN_TIP="$(git -C "$repo" rev-parse HEAD)"
  if [ "$count" -eq 2 ]; then
    SOURCE_CSV="${SRC1},${SRC2}"
    ALT_CSV="${ALT1},${ALT2}"
  else
    SOURCE_CSV="$SRC1"
    ALT_CSV="$ALT1"
  fi
}

build_octopus_repo() {
  local repo="$1"
  init_repo "$repo"

  git -C "$repo" checkout -qb topic "$INITIAL"
  commit_file "$repo" feature-one.txt "feature one" "source one"
  SRC1="$(git -C "$repo" rev-parse HEAD)"

  git -C "$repo" checkout -qb participant "$INITIAL"
  commit_file "$repo" participant.txt "participant" "participant"

  git -C "$repo" checkout -q main
  commit_file "$repo" main-before.txt "concurrent before" "concurrent main before landing"
  git -C "$repo" merge --no-ff -q topic participant -m "octopus landing" >/dev/null 2>&1
  ANCHOR="$(git -C "$repo" rev-parse HEAD)"
  commit_file "$repo" main-after.txt "concurrent after" "concurrent main after landing"
  SOURCE_CSV="$SRC1"
}

run_resolver() {
  local repo="$1" output="$2" anchor="$3" sources="$4" count="$5" intent="${6:-}"
  local rc=0
  local args=(
    --repo-dir "$repo"
    --repository example/landing-envelope
    --base-ref main
    --implementation-pr 40
    --provider-merged-at 2026-07-15T00:00:00Z
    --landing-anchor "$anchor"
    --source-commits "$sources"
    --pr-commit-count "$count"
  )
  if [ -n "$intent" ]; then
    args+=(--merge-method-intent "$intent")
  fi
  "$HELPER" "${args[@]}" > "$output" 2>&1 || rc=$?
  printf '%s\n' "$rc"
}

run_resolver_with_pr() {
  local repo="$1" output="$2" anchor="$3" sources="$4" count="$5" implementation_pr="$6"
  local rc=0
  "$HELPER" \
    --repo-dir "$repo" \
    --repository example/landing-envelope \
    --base-ref main \
    --implementation-pr "$implementation_pr" \
    --provider-merged-at 2026-07-15T00:00:00Z \
    --landing-anchor "$anchor" \
    --source-commits "$sources" \
    --pr-commit-count "$count" > "$output" 2>&1 || rc=$?
  printf '%s\n' "$rc"
}

run_resolver_with_time() {
  local repo="$1" output="$2" anchor="$3" sources="$4" count="$5" provider_time="$6"
  local rc=0
  "$HELPER" \
    --repo-dir "$repo" \
    --repository example/landing-envelope \
    --base-ref main \
    --implementation-pr 40 \
    --provider-merged-at "$provider_time" \
    --landing-anchor "$anchor" \
    --source-commits "$sources" \
    --pr-commit-count "$count" > "$output" 2>&1 || rc=$?
  printf '%s\n' "$rc"
}

run_resolver_with_repository() {
  local repo="$1" output="$2" anchor="$3" sources="$4" count="$5" repository_value="$6"
  local rc=0
  "$HELPER" \
    --repo-dir "$repo" \
    --repository "$repository_value" \
    --base-ref main \
    --implementation-pr 40 \
    --provider-merged-at 2026-07-15T00:00:00Z \
    --landing-anchor "$anchor" \
    --source-commits "$sources" \
    --pr-commit-count "$count" > "$output" 2>&1 || rc=$?
  printf '%s\n' "$rc"
}

run_success_case() {
  local topology="$1"
  local repo="$TMP_DIR/${topology}-repo"
  local output="$TMP_DIR/${topology}.out"
  local rc expected_landing
  build_landing_repo "$repo" "$topology" 2
  case "$topology" in
    rebase) expected_landing="${LANDED_FIRST},${ANCHOR}" ;;
    squash) expected_landing="$ANCHOR" ;;
    merge_commit) expected_landing="${SRC1},${SRC2},${ANCHOR}" ;;
  esac
  rc="$(run_resolver "$repo" "$output" "$ANCHOR" "$SOURCE_CSV" 2)"

  assert_exit "${topology} exits success" 0 "$rc"
  assert_field "${topology} schema version" "$output" schema_version 1
  assert_field "${topology} repository identity" "$output" repository example/landing-envelope
  assert_field "${topology} preserves provider merge time" "$output" provider_merged_at 2026-07-15T00:00:00Z
  assert_field "${topology} selects exact strategy" "$output" strategy "$topology"
  assert_field "${topology} uses topology source" "$output" method_source topology
  assert_field "${topology} preserves full anchor" "$output" landing_anchor "$ANCHOR"
  assert_field "${topology} derives base-before" "$output" base_before "$BASE_BEFORE"
  assert_field "${topology} emits exact landing set" "$output" landing_commits "$expected_landing"
  assert_field "${topology} first landing commit" "$output" first_landing_commit "$LANDED_FIRST"
  assert_field "${topology} last landing commit is anchor" "$output" last_landing_commit "$ANCHOR"
  assert_field "${topology} evidence vocabulary" "$output" strategy_evidence topology+ordered-patch-ids+aggregate-patch-digest
  assert_field_nonempty "${topology} source patch identities" "$output" source_commit_patch_ids
  assert_field_nonempty "${topology} landing patch identities" "$output" landing_commit_patch_ids
  assert_fields_equal "${topology} aggregate patch digests agree" "$output" source_patch_digest landing_patch_digest
  assert_not_equal "${topology} does not substitute original PR head" "$ANCHOR" "$ORIGINAL_HEAD"
  assert_not_equal "${topology} does not substitute moving main tip" "$ANCHOR" "$MAIN_TIP"
}

run_rejection_case() {
  local desc="$1" repo="$2" anchor="$3" sources="$4" count="$5" intent="$6" expected_reason="$7"
  local output="$TMP_DIR/reject-${desc// /-}.out"
  local rc
  rc="$(run_resolver "$repo" "$output" "$anchor" "$sources" "$count" "$intent")"
  assert_exit "$desc exits reject" 2 "$rc"
  assert_field "$desc reports stable reason" "$output" reason "$expected_reason"
}

echo "=== test-landing-envelope-resolver.sh ==="
echo ""

if [ ! -x "$HELPER" ]; then
  record_fail "landing envelope resolver exists and is executable (${HELPER})"
else
  record_pass "landing envelope resolver exists and is executable"

  # Exact anchor + fixed first-parent count constructs at most one landing set
  # per strategy. Cross-strategy overlap is method ambiguity, already exercised
  # below. Patch ambiguity is therefore unreachable today; pin the defensive
  # same-strategy branch so a future range enumerator cannot choose silently.
  assert_file_contains "patch ambiguity reason remains pinned" "$HELPER" "$REASON_PATCH_AMBIGUOUS"
  assert_file_contains "patch ambiguity guard documents same-strategy scope" "$HELPER" "same-strategy"

  run_success_case rebase
  run_success_case squash
  run_success_case merge_commit

  contract_repo="$TMP_DIR/contract-fields-repo"
  build_landing_repo "$contract_repo" rebase 2
  implementation_pr_out="$TMP_DIR/implementation-pr.out"
  implementation_pr_rc="$(run_resolver_with_pr "$contract_repo" "$implementation_pr_out" "$ANCHOR" "$SOURCE_CSV" 2 40)"
  assert_exit "required implementation PR exits success" 0 "$implementation_pr_rc"
  assert_field "landing envelope emits implementation PR" "$implementation_pr_out" implementation_pr 40

  invalid_pr_out="$TMP_DIR/invalid-implementation-pr.out"
  invalid_pr_rc="$(run_resolver_with_pr "$contract_repo" "$invalid_pr_out" "$ANCHOR" "$SOURCE_CSV" 2 0)"
  assert_exit "non-positive implementation PR exits reject" 2 "$invalid_pr_rc"
  assert_field "non-positive implementation PR reports stable reason" "$invalid_pr_out" reason "$REASON_IMPLEMENTATION_PR_INVALID"

  malformed_time_out="$TMP_DIR/malformed-provider-time.out"
  malformed_time_rc="$(run_resolver_with_time "$contract_repo" "$malformed_time_out" "$ANCHOR" "$SOURCE_CSV" 2 not-rfc3339)"
  assert_exit "malformed provider time exits reject" 2 "$malformed_time_rc"
  assert_field "malformed provider time reports stable landing reason" "$malformed_time_out" reason "$REASON_PROVIDER_TIME_INVALID"

  newline_repository=$'example/landing-envelope\nstrategy=squash'
  newline_repository_out="$TMP_DIR/newline-repository.out"
  newline_repository_rc="$(run_resolver_with_repository "$contract_repo" "$newline_repository_out" "$ANCHOR" "$SOURCE_CSV" 2 "$newline_repository")"
  assert_exit "newline repository injection exits reject" 2 "$newline_repository_rc"
  assert_field "newline repository injection reports canonical reason" "$newline_repository_out" reason "$REASON_TOPOLOGY_UNSUPPORTED"
  assert_not_contains "newline repository cannot forge an envelope field" "$newline_repository_out" '^strategy=squash$'

  tab_repository=$'example/landing-envelope\tforged=true'
  tab_repository_out="$TMP_DIR/tab-repository.out"
  tab_repository_rc="$(run_resolver_with_repository "$contract_repo" "$tab_repository_out" "$ANCHOR" "$SOURCE_CSV" 2 "$tab_repository")"
  assert_exit "control-character repository injection exits reject" 2 "$tab_repository_rc"
  assert_field "control-character repository reports canonical reason" "$tab_repository_out" reason "$REASON_TOPOLOGY_UNSUPPORTED"

  one_repo="$TMP_DIR/one-commit-repo"
  build_landing_repo "$one_repo" rebase 1
  run_rejection_case "one-commit multi-match" "$one_repo" "$ANCHOR" "$SOURCE_CSV" 1 "" "$REASON_METHOD_AMBIGUOUS"

  one_rebase_out="$TMP_DIR/one-rebase-intent.out"
  one_rebase_rc="$(run_resolver "$one_repo" "$one_rebase_out" "$ANCHOR" "$SOURCE_CSV" 1 rebase)"
  assert_exit "one-commit rebase intent exits success" 0 "$one_rebase_rc"
  assert_field "one-commit rebase intent selects rebase" "$one_rebase_out" strategy rebase
  assert_field "one-commit rebase intent is truthful discriminator" "$one_rebase_out" method_source intent-discriminator

  one_squash_out="$TMP_DIR/one-squash-intent.out"
  one_squash_rc="$(run_resolver "$one_repo" "$one_squash_out" "$ANCHOR" "$SOURCE_CSV" 1 squash)"
  assert_exit "one-commit squash intent exits success" 0 "$one_squash_rc"
  assert_field "one-commit squash intent selects squash" "$one_squash_out" strategy squash
  assert_field "one-commit squash intent is truthful discriminator" "$one_squash_out" method_source intent-discriminator
  run_rejection_case "conflicting merge intent" "$one_repo" "$ANCHOR" "$SOURCE_CSV" 1 merge_commit "$REASON_METHOD_INTENT_MISMATCH"

  rebase_repo="$TMP_DIR/rejection-rebase"
  build_landing_repo "$rebase_repo" rebase 2
  run_rejection_case "unreachable original head" "$rebase_repo" "$ORIGINAL_HEAD" "$SOURCE_CSV" 2 "" "$REASON_ANCHOR_UNREACHABLE"
  run_rejection_case "declared count mismatch" "$rebase_repo" "$ANCHOR" "$SOURCE_CSV" 3 "" "$REASON_COUNT_MISMATCH"
  run_rejection_case "ordered patch mismatch" "$rebase_repo" "$ANCHOR" "${SRC2},${SRC1}" 2 "" "$REASON_PATCH_FAILED"
  run_rejection_case "aggregate patch mismatch" "$rebase_repo" "$ANCHOR" "$ALT_CSV" 2 "" "$REASON_PATCH_FAILED"
  run_rejection_case "missing anchor" "$rebase_repo" "" "$SOURCE_CSV" 2 "" "$REASON_ANCHOR_MISSING"
  run_rejection_case "abbreviated anchor" "$rebase_repo" "${ANCHOR%????????????????????????????????}" "$SOURCE_CSV" 2 "" "$REASON_ANCHOR_MISSING"

  octopus_repo="$TMP_DIR/octopus-repo"
  build_octopus_repo "$octopus_repo"
  run_rejection_case "octopus topology" "$octopus_repo" "$ANCHOR" "$SOURCE_CSV" 1 "" "$REASON_TOPOLOGY_UNSUPPORTED"
fi

echo ""
printf 'Results: %s passed, %s failed\n' "$PASS" "$FAIL"

if [ "$FAIL" -gt 0 ]; then
  echo "Failed assertions:"
  for error in "${ERRORS[@]}"; do
    printf '  - %s\n' "$error"
  done
  exit 1
fi

echo "All assertions passed"
