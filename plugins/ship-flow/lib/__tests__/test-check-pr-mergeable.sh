#!/usr/bin/env bash
# test-check-pr-mergeable.sh - post-PR-create mergeability helper contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
REPO_ROOT="$(cd -- "${PLUGIN_ROOT}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/lib/check-pr-mergeable.sh"
SHIP_SKILL="${PLUGIN_ROOT}/skills/ship/SKILL.md"
PR_MERGE_DOC="${REPO_ROOT}/docs/ship-flow/_mods/pr-merge.md"

PASS=0
FAIL=0
ERRORS=()
REQUESTED_CASE="${1:-all}"
HELPER_RC=0

record_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
record_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"; else record_fail "$desc (expected exit ${expected}, got ${actual})"; fi
}

assert_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE -- "$pattern" "$file"; then record_pass "$desc"; else record_fail "$desc (missing pattern: ${pattern})"; fi
}

assert_not_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE -- "$pattern" "$file"; then record_fail "$desc (unexpected pattern: ${pattern})"; else record_pass "$desc"; fi
}

assert_key_order() {
  local desc="$1" file="$2" actual expected
  expected=$'helper\nverdict\nstate_class\npr\nmerge_state_status\nattempts\nelapsed_seconds\nconflict_files\naction\nreason'
  actual="$(grep -E '^[a-z_]+=' "$file" | cut -d= -f1)"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"; else record_fail "$desc (stdout key order mismatch: ${actual//$'\n'/,})"; fi
}

write_json_fixture() {
  local path="$1" status="$2"
  printf '{"mergeStateStatus":"%s"}\n' "$status" > "$path"
}

write_fake_gh() {
  local dir="$1"
  mkdir -p "$dir"
  cat > "${dir}/gh" <<'EOF'
#!/usr/bin/env bash
echo "fixture mode must not invoke gh" >&2
exit 99
EOF
  chmod +x "${dir}/gh"
}

write_recording_gh() {
  local dir="$1" calls="$2"
  mkdir -p "$dir"
  cat > "${dir}/gh" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >> "$calls"
printf 'CLEAN\n'
EOF
  chmod +x "${dir}/gh"
}

run_helper_capture() {
  local out="$1"
  shift
  set +e
  bash "$HELPER" "$@" > "$out" 2>&1
  HELPER_RC=$?
  set -e
  return 0
}

run_helper_capture_no_gh() {
  local out="$1" fakebin="$2"
  shift 2
  set +e
  PATH="${fakebin}:$PATH" bash "$HELPER" "$@" > "$out" 2>&1
  HELPER_RC=$?
  set -e
  return 0
}

case_usage_error() {
  local tmp out fixture seq
  tmp="$(mktemp -d)"
  out="${tmp}/out"
  fixture="${tmp}/gh.json"
  seq="${tmp}/states"
  write_json_fixture "$fixture" "CLEAN"
  printf 'CLEAN\n' > "$seq"

  run_helper_capture "$out"
  local rc="$HELPER_RC"
  assert_exit "missing --pr exits usage error" 2 "$rc"
  assert_key_order "usage error preserves key order" "$out"
  assert_contains "usage error helper key" '^helper=check-pr-mergeable$' "$out"
  assert_contains "usage error verdict" '^verdict=PROMPT_CAPTAIN$' "$out"
  assert_contains "usage error action" '^action=surface-to-captain$' "$out"
  assert_contains "usage error reason" '^reason=usage-error$' "$out"

  run_helper_capture "$out" --pr 9 --interval-seconds
  assert_exit "missing --interval-seconds value exits usage error" 2 "$HELPER_RC"
  assert_contains "missing --interval-seconds state" '^state_class=usage-error$' "$out"
  assert_contains "missing --interval-seconds reason" '^reason=usage-error$' "$out"

  run_helper_capture "$out" --pr 9 --gh-view-json-fixture
  assert_exit "missing --gh-view-json-fixture value exits usage error" 2 "$HELPER_RC"
  assert_contains "missing --gh-view-json-fixture state" '^state_class=usage-error$' "$out"
  assert_contains "missing --gh-view-json-fixture reason" '^reason=usage-error$' "$out"

  run_helper_capture "$out" --pr 9 --state-sequence-fixture
  assert_exit "missing --state-sequence-fixture value exits usage error" 2 "$HELPER_RC"
  assert_contains "missing --state-sequence-fixture state" '^state_class=usage-error$' "$out"
  assert_contains "missing --state-sequence-fixture reason" '^reason=usage-error$' "$out"

  run_helper_capture "$out" --pr 9 --interval-seconds --gh-view-json-fixture "$fixture"
  assert_exit "missing --interval-seconds value before another option exits usage error" 2 "$HELPER_RC"

  run_helper_capture "$out" --pr 9 --gh-view-json-fixture --interval-seconds 0
  assert_exit "missing --gh-view-json-fixture value before another option exits usage error" 2 "$HELPER_RC"

  run_helper_capture "$out" --pr 9 --state-sequence-fixture --interval-seconds 0
  assert_exit "missing --state-sequence-fixture value before another option exits usage error" 2 "$HELPER_RC"
}

case_json_status() {
  local status="$1" expected_rc="$2" expected_class="$3" expected_verdict="$4" expected_action="$5" expected_reason="$6"
  local tmp fixture out fakebin rc
  tmp="$(mktemp -d)"
  fixture="${tmp}/gh.json"
  out="${tmp}/out"
  fakebin="${tmp}/bin"
  write_json_fixture "$fixture" "$status"
  write_fake_gh "$fakebin"

  run_helper_capture_no_gh "$out" "$fakebin" --pr "https://github.com/acme/repo/pull/42" --gh-view-json-fixture "$fixture" --interval-seconds 0
  rc="$HELPER_RC"

  assert_exit "json ${status} exit" "$expected_rc" "$rc"
  assert_key_order "json ${status} key order" "$out"
  assert_contains "json ${status} normalized pr" '^pr=#42$' "$out"
  assert_contains "json ${status} raw status" "^merge_state_status=${status}$" "$out"
  assert_contains "json ${status} state class" "^state_class=${expected_class}$" "$out"
  assert_contains "json ${status} verdict" "^verdict=${expected_verdict}$" "$out"
  assert_contains "json ${status} action" "^action=${expected_action}$" "$out"
  assert_contains "json ${status} reason" "^reason=${expected_reason}$" "$out"
}

case_gh_failure_fixture() {
  local tmp missing malformed out fakebin
  tmp="$(mktemp -d)"
  missing="${tmp}/missing.json"
  malformed="${tmp}/bad.json"
  out="${tmp}/out"
  fakebin="${tmp}/bin"
  write_fake_gh "$fakebin"
  printf '{"mergeStateStatus":' > "$malformed"

  run_helper_capture_no_gh "$out" "$fakebin" --pr 9 --gh-view-json-fixture "$missing"
  assert_exit "unreadable fixture exits gh failure" 30 "$HELPER_RC"
  assert_contains "unreadable fixture reason" '^reason=gh-pr-view-failed$' "$out"

  run_helper_capture_no_gh "$out" "$fakebin" --pr 9 --gh-view-json-fixture "$malformed"
  assert_exit "malformed fixture exits gh failure" 30 "$HELPER_RC"
  assert_contains "malformed fixture state" '^state_class=gh-failure$' "$out"
}

case_live_gh_pr_argument() {
  local tmp out fakebin calls
  tmp="$(mktemp -d)"
  out="${tmp}/out"
  fakebin="${tmp}/bin"
  calls="${tmp}/gh-calls"
  write_recording_gh "$fakebin" "$calls"

  run_helper_capture_no_gh "$out" "$fakebin" --pr '#123' --interval-seconds 0
  assert_exit "live gh fake path exits clean" 0 "$HELPER_RC"
  assert_contains "live gh fake path preserves display pr" '^pr=#123$' "$out"
  assert_contains "live gh fake path queries numeric pr" '^pr view 123 --json mergeStateStatus --jq \.mergeStateStatus$' "$calls"
}

case_sequence_fixture() {
  local tmp seq out fakebin
  tmp="$(mktemp -d)"
  seq="${tmp}/states"
  out="${tmp}/out"
  fakebin="${tmp}/bin"
  write_fake_gh "$fakebin"

  printf 'UNKNOWN\nCLEAN\n' > "$seq"
  run_helper_capture_no_gh "$out" "$fakebin" --pr '#77' --state-sequence-fixture "$seq" --max-attempts 3 --interval-seconds 0
  assert_exit "UNKNOWN then CLEAN exits clean" 0 "$HELPER_RC"
  assert_contains "UNKNOWN then CLEAN attempts" '^attempts=2$' "$out"
  assert_contains "UNKNOWN then CLEAN status" '^merge_state_status=CLEAN$' "$out"

  printf 'UNKNOWN\nUNKNOWN\n' > "$seq"
  run_helper_capture_no_gh "$out" "$fakebin" --pr 77 --state-sequence-fixture "$seq" --max-attempts 2 --interval-seconds 0
  assert_exit "repeated UNKNOWN exits timeout" 20 "$HELPER_RC"
  assert_contains "repeated UNKNOWN timeout" '^state_class=timeout$' "$out"
  assert_contains "repeated UNKNOWN reason" '^reason=merge-state-timeout$' "$out"

  printf '\n' > "$seq"
  run_helper_capture_no_gh "$out" "$fakebin" --pr 77 --state-sequence-fixture "$seq" --max-attempts 1 --interval-seconds 0
  assert_exit "empty-line sequence exits timeout" 20 "$HELPER_RC"
  assert_contains "empty-line sequence keeps empty status" '^merge_state_status=$' "$out"

  printf 'UNKNOWN\nDIRTY\n' > "$seq"
  run_helper_capture_no_gh "$out" "$fakebin" --pr 77 --state-sequence-fixture "$seq" --max-attempts 4 --interval-seconds 0
  assert_exit "short sequence reuses last line and exits dirty" 11 "$HELPER_RC"
  assert_contains "short sequence dirty status" '^merge_state_status=DIRTY$' "$out"
  assert_contains "short sequence attempts" '^attempts=2$' "$out"
}

case_conflict_files() {
  local tmp fixture out
  tmp="$(mktemp -d)"
  fixture="${tmp}/gh.json"
  out="${tmp}/out"
  write_json_fixture "$fixture" "CONFLICTING"
  git -C "$tmp" init -q
  git -C "$tmp" config user.email test@example.com
  git -C "$tmp" config user.name "Ship Flow Test"
  printf 'base\n' > "${tmp}/conflict.txt"
  git -C "$tmp" add conflict.txt
  git -C "$tmp" commit -qm base
  git -C "$tmp" checkout -qb side
  printf 'side\n' > "${tmp}/conflict.txt"
  git -C "$tmp" commit -am side -q
  git -C "$tmp" checkout -q -
  printf 'main\n' > "${tmp}/conflict.txt"
  git -C "$tmp" commit -am main -q
  git -C "$tmp" merge side >/dev/null 2>&1 || true

  set +e
  (cd "$tmp" && bash "$HELPER" --pr 5 --gh-view-json-fixture "$fixture" --interval-seconds 0) > "$out" 2>&1
  HELPER_RC=$?
  set -e
  assert_exit "conflicting with unmerged files exits 10" 10 "$HELPER_RC"
  assert_contains "conflict files reported" '^conflict_files=conflict\.txt$' "$out"
}

case_helper_contracts() {
  case_usage_error
  case_live_gh_pr_argument
  case_json_status CLEAN 0 clean OK continue merge-state-clean
  case_json_status CONFLICTING 10 conflicting BLOCK branch-update-required merge-state-conflicting
  case_json_status DIRTY 11 dirty BLOCK branch-update-required merge-state-dirty
  case_json_status UNSTABLE 12 unknown PROMPT_CAPTAIN surface-to-captain merge-state-unknown
  case_json_status BLOCKED 12 unknown PROMPT_CAPTAIN surface-to-captain merge-state-unknown
  case_json_status SOMETHING_ELSE 12 unknown PROMPT_CAPTAIN surface-to-captain merge-state-unknown
  case_gh_failure_fixture
  case_sequence_fixture
  case_conflict_files
}

first_line() {
  local pattern="$1" file="$2"
  grep -nE -- "$pattern" "$file" | head -1 | cut -d: -f1 || true
}

case_ordering() {
  assert_contains "ship skill references metadata helper" 'persist-pr-metadata\.sh' "$SHIP_SKILL"
  assert_contains "ship skill references mergeability helper" 'check-pr-mergeable\.sh' "$SHIP_SKILL"

  local metadata_line helper_line post_review_line ready_line reviewer_line
  metadata_line="$(first_line 'persist-pr-metadata\.sh' "$SHIP_SKILL")"
  helper_line="$(first_line 'check-pr-mergeable\.sh' "$SHIP_SKILL")"
  post_review_line="$(first_line 'Post-create auto-review' "$SHIP_SKILL")"
  ready_line="$(first_line 'gh pr ready' "$SHIP_SKILL")"
  reviewer_line="$(first_line 'request Copilot review' "$SHIP_SKILL")"

  if [ -n "$metadata_line" ] && [ -n "$helper_line" ] && [ "$metadata_line" -lt "$helper_line" ]; then
    record_pass "metadata persistence appears before mergeability helper"
  else
    record_fail "metadata persistence is missing or appears after mergeability helper"
  fi
  if [ -n "$helper_line" ] && [ -n "$post_review_line" ] && [ "$helper_line" -lt "$post_review_line" ]; then
    record_pass "mergeability helper appears before post-create auto-review"
  else
    record_fail "mergeability helper is missing or appears after post-create auto-review"
  fi
  if [ -n "$helper_line" ] && [ -n "$ready_line" ] && [ "$helper_line" -lt "$ready_line" ]; then
    record_pass "mergeability helper appears before Ready routing"
  else
    record_fail "mergeability helper is missing or appears after Ready routing"
  fi
  if [ -n "$helper_line" ] && [ -n "$reviewer_line" ] && [ "$helper_line" -lt "$reviewer_line" ]; then
    record_pass "mergeability helper appears before reviewer routing"
  else
    record_fail "mergeability helper is missing or appears after reviewer routing"
  fi
}

case_docs() {
  assert_contains "pr-merge doc names helper" 'check-pr-mergeable\.sh' "$PR_MERGE_DOC"
  assert_contains "pr-merge doc calls itself policy mirror" 'policy mirror' "$PR_MERGE_DOC"
  assert_contains "pr-merge doc includes clean mapping" "0[[:space:]]*\\|[[:space:]]*\`?clean\`?" "$PR_MERGE_DOC"
  assert_contains "pr-merge doc includes conflicting mapping" "10[[:space:]]*\\|[[:space:]]*\`?conflicting\`?" "$PR_MERGE_DOC"
  assert_contains "pr-merge doc includes dirty mapping" "11[[:space:]]*\\|[[:space:]]*\`?dirty\`?" "$PR_MERGE_DOC"
  assert_contains "pr-merge doc includes unknown mapping" "12[[:space:]]*\\|[[:space:]]*\`?unknown\`?" "$PR_MERGE_DOC"
  assert_contains "pr-merge doc includes timeout mapping" "20[[:space:]]*\\|[[:space:]]*\`?timeout\`?" "$PR_MERGE_DOC"
  assert_contains "pr-merge doc includes gh-failure mapping" "30[[:space:]]*\\|[[:space:]]*\`?gh-failure\`?" "$PR_MERGE_DOC"
  assert_contains "pr-merge doc includes usage mapping" "2[[:space:]]*\\|[[:space:]]*\`?usage-error\`?" "$PR_MERGE_DOC"
  assert_not_contains "pr-merge doc does not add a GitLab helper path" 'check-pr-mergeable\.sh.*glab|glab.*check-pr-mergeable\.sh|GitLab mergeability helper' "$PR_MERGE_DOC"
}

case "$REQUESTED_CASE" in
  all)
    case_helper_contracts
    case_ordering
    case_docs
    ;;
  --case)
    case "${2:-}" in
      helper) case_helper_contracts ;;
      ordering) case_ordering ;;
      docs) case_docs ;;
      *) record_fail "unknown --case ${2:-}" ;;
    esac
    ;;
  *)
    record_fail "unknown argument ${REQUESTED_CASE}"
    ;;
esac

echo
echo "test-check-pr-mergeable.sh: ${PASS} passed, ${FAIL} failed"
if [ "$FAIL" -ne 0 ]; then
  printf 'Failures:\n'
  printf ' - %s\n' "${ERRORS[@]}"
  exit 1
fi
