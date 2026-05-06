#!/usr/bin/env bash
# test-pr-metadata-backfill.sh - PR metadata persistence contract

set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" &> /dev/null && pwd)"
PLUGIN_ROOT="$(cd -- "${SCRIPT_DIR}/../.." &> /dev/null && pwd)"
HELPER="${PLUGIN_ROOT}/lib/persist-pr-metadata.sh"
SHIP_SKILL="${PLUGIN_ROOT}/skills/ship/SKILL.md"

PASS=0
FAIL=0
ERRORS=()
REQUESTED_CASES=()
HELPER_RC=0

record_pass() { echo "  PASS: $1"; PASS=$((PASS + 1)); }
record_fail() { echo "  FAIL: $1"; FAIL=$((FAIL + 1)); ERRORS+=("$1"); }

assert_exit() {
  local desc="$1" expected="$2" actual="$3"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"; else record_fail "$desc (expected exit ${expected}, got ${actual})"; fi
}

assert_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then record_pass "$desc"; else record_fail "$desc (missing pattern: ${pattern})"; fi
}

assert_not_contains() {
  local desc="$1" pattern="$2" file="$3"
  if grep -qE "$pattern" "$file"; then record_fail "$desc (unexpected pattern: ${pattern})"; else record_pass "$desc"; fi
}

assert_frontmatter_equals() {
  local desc="$1" file="$2" field="$3" expected="$4" actual
  actual="$(frontmatter_field "$file" "$field")"
  if [ "$actual" = "$expected" ]; then record_pass "$desc"; else record_fail "$desc (expected ${field}=${expected}, got ${actual})"; fi
}

assert_pr_line_exact() {
  local desc="$1" file="$2" expected="$3"
  if grep -qE "^pr: \"#${expected}\"$" "$file"; then record_pass "$desc"; else record_fail "$desc (missing exact quoted pr line #${expected})"; fi
}

frontmatter_field() {
  local file="$1" field="$2"
  awk -v field="$field" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = field ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^["'\''"]|["'\''"]$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    shasum -a 256 "$1" | awk '{print $1}'
  fi
}

write_entity() {
  local path="$1" slug="$2" pr_line="${3:-pr:}"
  mkdir -p "$(dirname "$path")"
  cat > "$path" <<EOF
---
title: Fixture entity
status: ship
slug: ${slug}
${pr_line}
---

## Body
EOF
}

write_pr_output() {
  local path="$1" body="$2"
  printf '%s\n' "$body" > "$path"
}

write_gh_view_fixture() {
  local path="$1" number="${2:-136}"
  cat > "$path" <<EOF
{"number":${number},"url":"https://github.com/acme/repo/pull/${number}","headRefName":"feature","headRefOid":"abc123","state":"OPEN"}
EOF
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

case_success_writes_active_and_mirror() {
  local tmp active mirror pr_out gh_json out hash
  tmp="$(mktemp -d)"
  active="${tmp}/worktree/docs/ship-flow/ship-pr-metadata-backfill/index.md"
  mirror="${tmp}/main/docs/ship-flow/ship-pr-metadata-backfill/index.md"
  pr_out="${tmp}/pr.out"
  gh_json="${tmp}/gh.json"
  out="${tmp}/helper.out"
  write_entity "$active" "ship-pr-metadata-backfill"
  write_entity "$mirror" "ship-pr-metadata-backfill"
  write_pr_output "$pr_out" "https://github.com/acme/repo/pull/136"
  write_gh_view_fixture "$gh_json" 136
  hash="$(sha256_of "$active")"

  run_helper_capture "$out" --entity "$active" --pr-create-output "$pr_out" --if-hash "$hash" --mirror-entity "$mirror" --gh-view-json-fixture "$gh_json"
  local rc="$HELPER_RC"

  assert_exit "success helper exits zero" 0 "$rc"
  assert_contains "success report verdict" '^verdict=OK$' "$out"
  assert_contains "success report pr" '^pr=#136$' "$out"
  assert_frontmatter_equals "active normalized pr readable" "$active" pr "#136"
  assert_frontmatter_equals "mirror normalized pr readable" "$mirror" pr "#136"
  assert_pr_line_exact "active stores exact quoted pr" "$active" 136
  assert_pr_line_exact "mirror stores exact quoted pr" "$mirror" 136
}

case_missing_pr_number_refuses() {
  local tmp active pr_out gh_json out hash before after
  tmp="$(mktemp -d)"
  active="${tmp}/index.md"
  pr_out="${tmp}/pr.out"
  gh_json="${tmp}/gh.json"
  out="${tmp}/helper.out"
  write_entity "$active" "ship-pr-metadata-backfill"
  write_pr_output "$pr_out" "PR created but URL missing"
  write_gh_view_fixture "$gh_json" 136
  hash="$(sha256_of "$active")"
  before="$(sha256_of "$active")"

  run_helper_capture "$out" --entity "$active" --pr-create-output "$pr_out" --if-hash "$hash" --gh-view-json-fixture "$gh_json"
  local rc="$HELPER_RC"
  after="$(sha256_of "$active")"

  assert_exit "missing PR number exits one" 1 "$rc"
  assert_contains "missing PR number reason" '^reason=missing-pr-number$' "$out"
  assert_not_contains "missing PR number does not write pr" '^pr: "#136"$' "$active"
  if [ "$before" = "$after" ]; then record_pass "missing PR number leaves entity unchanged"; else record_fail "missing PR number mutated entity"; fi
}

case_stale_hash_refuses() {
  local tmp active pr_out gh_json out hash
  tmp="$(mktemp -d)"
  active="${tmp}/index.md"
  pr_out="${tmp}/pr.out"
  gh_json="${tmp}/gh.json"
  out="${tmp}/helper.out"
  write_entity "$active" "ship-pr-metadata-backfill"
  write_pr_output "$pr_out" "https://github.com/acme/repo/pull/136"
  write_gh_view_fixture "$gh_json" 136
  hash="$(sha256_of "$active")"
  printf '\nconcurrent edit\n' >> "$active"

  run_helper_capture "$out" --entity "$active" --pr-create-output "$pr_out" --if-hash "$hash" --gh-view-json-fixture "$gh_json"
  local rc="$HELPER_RC"

  assert_exit "stale hash exits one" 1 "$rc"
  assert_contains "stale hash reason" '^reason=stale-entity-hash$' "$out"
  assert_not_contains "stale hash does not write pr" '^pr: "#136"$' "$active"
}

case_idempotent_same_pr() {
  local tmp active pr_out gh_json out hash before after
  tmp="$(mktemp -d)"
  active="${tmp}/index.md"
  pr_out="${tmp}/pr.out"
  gh_json="${tmp}/gh.json"
  out="${tmp}/helper.out"
  write_entity "$active" "ship-pr-metadata-backfill" 'pr: "#136"'
  write_pr_output "$pr_out" "https://github.com/acme/repo/pull/136"
  write_gh_view_fixture "$gh_json" 136
  hash="$(sha256_of "$active")"
  before="$(sha256_of "$active")"

  run_helper_capture "$out" --entity "$active" --pr-create-output "$pr_out" --if-hash "$hash" --gh-view-json-fixture "$gh_json"
  local rc="$HELPER_RC"
  after="$(sha256_of "$active")"

  assert_exit "idempotent same PR exits zero" 0 "$rc"
  assert_contains "idempotent report" '^reason=already-present$' "$out"
  assert_pr_line_exact "idempotent keeps exact quoted pr" "$active" 136
  if [ "$before" = "$after" ]; then record_pass "idempotent same PR leaves entity unchanged"; else record_fail "idempotent same PR rewrote entity"; fi
}

case_conflicting_pr_refuses() {
  local tmp active pr_out gh_json out hash
  tmp="$(mktemp -d)"
  active="${tmp}/index.md"
  pr_out="${tmp}/pr.out"
  gh_json="${tmp}/gh.json"
  out="${tmp}/helper.out"
  write_entity "$active" "ship-pr-metadata-backfill" 'pr: "#135"'
  write_pr_output "$pr_out" "https://github.com/acme/repo/pull/136"
  write_gh_view_fixture "$gh_json" 136
  hash="$(sha256_of "$active")"

  run_helper_capture "$out" --entity "$active" --pr-create-output "$pr_out" --if-hash "$hash" --gh-view-json-fixture "$gh_json"
  local rc="$HELPER_RC"

  assert_exit "conflicting PR exits one" 1 "$rc"
  assert_contains "conflicting PR reason" '^reason=conflicting-pr$' "$out"
  assert_pr_line_exact "conflicting PR preserves old value" "$active" 135
  assert_not_contains "conflicting PR does not write new value" '^pr: "#136"$' "$active"
}

case_mirror_conflict_preserves_main() {
  local tmp active mirror pr_out gh_json out hash
  tmp="$(mktemp -d)"
  active="${tmp}/worktree/docs/ship-flow/ship-pr-metadata-backfill/index.md"
  mirror="${tmp}/main/docs/ship-flow/ship-pr-metadata-backfill/index.md"
  pr_out="${tmp}/pr.out"
  gh_json="${tmp}/gh.json"
  out="${tmp}/helper.out"
  write_entity "$active" "ship-pr-metadata-backfill"
  write_entity "$mirror" "ship-pr-metadata-backfill" 'pr: "#135"'
  write_pr_output "$pr_out" "https://github.com/acme/repo/pull/136"
  write_gh_view_fixture "$gh_json" 136
  hash="$(sha256_of "$active")"

  run_helper_capture "$out" --entity "$active" --pr-create-output "$pr_out" --if-hash "$hash" --mirror-entity "$mirror" --gh-view-json-fixture "$gh_json"
  local rc="$HELPER_RC"

  assert_exit "mirror conflict still exits zero for active write" 0 "$rc"
  assert_contains "mirror conflict report" '^reason=mirror-conflict$' "$out"
  assert_pr_line_exact "active writes new PR despite mirror conflict" "$active" 136
  assert_pr_line_exact "mirror conflict preserves main value" "$mirror" 135
}

case_ship_skill_ordering() {
  assert_contains "ship skill references metadata helper" 'persist-pr-metadata\.sh' "$SHIP_SKILL"
  assert_contains "ship skill captures PR create output" 'pr-create-output' "$SHIP_SKILL"
  assert_contains "ship skill names no branch/title fallback" 'branch or title' "$SHIP_SKILL"

  local helper_line merge_line
  helper_line="$(grep -n 'persist-pr-metadata\.sh' "$SHIP_SKILL" | head -1 | cut -d: -f1)"
  merge_line="$(grep -n 'mergeStateStatus' "$SHIP_SKILL" | head -1 | cut -d: -f1)"
  if [ -n "$helper_line" ] && [ -n "$merge_line" ] && [ "$helper_line" -lt "$merge_line" ]; then
    record_pass "metadata helper appears before mergeStateStatus"
  else
    record_fail "metadata helper is missing or appears after mergeStateStatus"
  fi
}

run_case() {
  local case_name="$1"
  echo "=== ${case_name} ==="
  case "$case_name" in
    success-writes-active-and-mirror) case_success_writes_active_and_mirror ;;
    missing-pr-number-refuses) case_missing_pr_number_refuses ;;
    stale-hash-refuses) case_stale_hash_refuses ;;
    idempotent-same-pr) case_idempotent_same_pr ;;
    conflicting-pr-refuses) case_conflicting_pr_refuses ;;
    mirror-conflict-preserves-main) case_mirror_conflict_preserves_main ;;
    ship-skill-ordering) case_ship_skill_ordering ;;
    *) record_fail "unknown case: ${case_name}" ;;
  esac
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --case) REQUESTED_CASES+=("$2"); shift 2 ;;
    -h|--help) echo "Usage: bash test-pr-metadata-backfill.sh [--case <name>]..."; exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

if [ "${#REQUESTED_CASES[@]}" -eq 0 ]; then
  REQUESTED_CASES=(
    success-writes-active-and-mirror
    missing-pr-number-refuses
    stale-hash-refuses
    idempotent-same-pr
    conflicting-pr-refuses
    mirror-conflict-preserves-main
    ship-skill-ordering
  )
fi

for case_name in "${REQUESTED_CASES[@]}"; do
  run_case "$case_name"
done

echo "=== Summary: ${PASS} passed, ${FAIL} failed ==="
if [ "$FAIL" -ne 0 ]; then
  printf 'Failures:\n'
  printf '  - %s\n' "${ERRORS[@]}"
  exit 1
fi
