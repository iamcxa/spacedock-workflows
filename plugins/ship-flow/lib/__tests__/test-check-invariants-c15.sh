#!/usr/bin/env bash
# test-check-invariants-c15.sh — adversarial fixture tests for C15 artifact-verbosity.
# Pattern: test-check-invariants-c1-c5.sh (fixture mode) + test-enforce-advance-stage.sh
#          (git-history mode for the branch-scope grandfather path).
#
# Entity: 129.2-wire-artifact-verbosity-blocker (child of pitch 129).
# Gate change → MEMORY "gate-change-review-author-blind-spot": adversarial,
# multi-item, raw-vs-body, CRLF, and grandfather-scope coverage is mandatory.
#
# C15 caps (body content; frontmatter + section markers + <details> excluded;
# raw total ALSO capped at 2x the body cap as an anti-bypass backstop):
#   plan.md ≤200  execute.md ≤150  verify.md ≤120  review.md ≤100  ship.md ≤60

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_DIR="${SCRIPT_DIR}/../.."
BIN_DIR="${PLUGIN_DIR}/bin"
CHECK_SCRIPT="${PLUGIN_DIR}/bin/check-invariants.sh"
FAIL=0

assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}

assert_stderr_contains() {
  local needle="$1" cmd="$2" name="$3"
  local err; err="$(eval "$cmd" 2>&1 >/dev/null)"
  if echo "$err" | grep -qF "$needle"; then echo "OK $name"
  else echo "FAIL $name (stderr missing: $needle)"; FAIL=1; fi
}

# ---- fixture-mode helpers (no git; scans $ROOT directly) ----
mk_fixture() {
  local dir; dir=$(mktemp -d)
  mkdir -p "$dir/docs/ship-flow"
  echo "$dir"
}

# Emit a stage artifact whose BODY (non-frontmatter, non-section-marker,
# non-<details>) is exactly $count plain lines.
# Args: file, body_line_count
write_body_lines() {
  local file="$1" count="$2" i
  : > "$file"
  for ((i = 1; i <= count; i++)); do
    printf 'body line %d\n' "$i" >> "$file"
  done
}

echo "=== C15 artifact-verbosity — fixture mode (FIXTURE bypasses git-range gate) ==="

# ---- Case 1: over-cap stage artifact → FAILS (prove a real RED) ----
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/900-over/"
write_body_lines "$f/docs/ship-flow/900-over/verify.md" 121   # cap 120 → over by 1
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.1 over-cap verify.md (121 body > 120) FAILS"
assert_stderr_contains "body content is 121 lines (cap 120 for verify.md)" \
  "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.1b failure message names file/actual/cap"
rm -rf "$f"

# ---- Case 1c: exactly at cap → PASSES (boundary) ----
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/901-atcap/"
write_body_lines "$f/docs/ship-flow/901-atcap/verify.md" 120   # exactly cap
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.1c verify.md exactly at cap (120) PASSES"
rm -rf "$f"

# ---- Case 2: raw-over / body-under → PASSES (parser must not false-red) ----
# Real-world shape: 117/verify.md = 144 raw but body ≤ 120 once frontmatter +
# section markers + <details> are stripped. Build the same shape synthetically:
# 100 body lines + frontmatter + many section markers + a <details> block, so
# raw > 120 but body = 100 ≤ 120, and raw stays under the 240 (2x) backstop.
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/902-rawover/"
{
  printf -- '---\n'
  printf 'id: "902"\n'
  printf 'title: "raw over body under"\n'
  printf -- '---\n'
  for ((i = 1; i <= 100; i++)); do printf 'body line %d\n' "$i"; done   # 100 body
  # Section markers (excluded) — 10 lines
  for ((i = 1; i <= 5; i++)); do printf '<!-- section:s%d -->\n' "$i"; printf '<!-- /section:s%d -->\n' "$i"; done
  # <details> block (excluded) — 20 lines
  printf '<details>\n'
  for ((i = 1; i <= 18; i++)); do printf 'collapsed evidence %d\n' "$i"; done
  printf '</details>\n'
} > "$f/docs/ship-flow/902-rawover/verify.md"
raw_count=$(wc -l < "$f/docs/ship-flow/902-rawover/verify.md")
echo "   (debug C15.2 raw line count = ${raw_count}; body should measure 100)"
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.2 raw>cap but body<=cap (frontmatter+markers+details stripped) PASSES"
rm -rf "$f"

# ---- Case 3: multi-violation — ALL reported, not just first ----
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/903-multi-a/" "$f/docs/ship-flow/903-multi-b/"
write_body_lines "$f/docs/ship-flow/903-multi-a/plan.md"   201   # cap 200 → over
write_body_lines "$f/docs/ship-flow/903-multi-b/review.md" 101   # cap 100 → over
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.3 two over-cap files FAILS"
assert_stderr_contains "903-multi-a/plan.md" \
  "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.3b first violation (plan.md) reported"
assert_stderr_contains "903-multi-b/review.md" \
  "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.3c second violation (review.md) reported — not stopped at first"
rm -rf "$f"

# ---- Case 4: single-giant-<details> bypass attempt → FAILS via 2x backstop ----
# body is tiny but a single <details> dumps a giant log. Body-only count would
# PASS; the 2x raw backstop (cap 120 → raw cap 240) must catch it.
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/904-bypass/"
{
  for ((i = 1; i <= 10; i++)); do printf 'body line %d\n' "$i"; done   # 10 body
  printf '<details>\n'
  for ((i = 1; i <= 500; i++)); do printf 'giant session log line %d\n' "$i"; done
  printf '</details>\n'
} > "$f/docs/ship-flow/904-bypass/verify.md"
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.4 single-giant-<details> (body<cap, raw huge) FAILS via 2x backstop"
assert_stderr_contains "raw total" \
  "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.4b backstop failure names the raw-total cap"
rm -rf "$f"

# ---- Case 5: CRLF line endings counted correctly ----
# Same as Case 1 (121 body lines over a 120 cap) but CRLF terminated. The line
# count must be identical (CR must not merge/split lines).
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/905-crlf/"
{ for ((i = 1; i <= 121; i++)); do printf 'body line %d\r\n' "$i"; done; } > "$f/docs/ship-flow/905-crlf/verify.md"
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.5 CRLF over-cap (121 body) FAILS (CR not mis-counted)"
assert_stderr_contains "body content is 121 lines" \
  "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.5b CRLF body counted as 121 (not 0 / not doubled)"
rm -rf "$f"

# ---- Case 6: absence / empty stage file → no crash, PASS ----
f=$(mk_fixture)   # docs/ship-flow exists but contains no stage artifacts at all
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.6a no stage artifacts → PASS (no crash)"
mkdir -p "$f/docs/ship-flow/906-empty/"
: > "$f/docs/ship-flow/906-empty/ship.md"   # zero-byte
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.6b empty (0-line) ship.md → PASS (no crash)"
rm -rf "$f"

# ---- Case 7: non-stage artifacts NOT capped (shape/design/index) ----
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/907-noncap/"
write_body_lines "$f/docs/ship-flow/907-noncap/shape.md"  500
write_body_lines "$f/docs/ship-flow/907-noncap/design.md" 500
write_body_lines "$f/docs/ship-flow/907-noncap/index.md"  500
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.7 shape/design/index.md NOT capped (Principle 8 omits) → PASS"
rm -rf "$f"

echo
echo "=== C15 cross-review cycle 1: <details> bypass hardening + scope exclusion ==="

# ---- Case 11: UNTERMINATED <details> bypass → must FAIL (caught) ----
# A standalone <details> open with NO matching </details> previously swallowed
# to EOF, smuggling ~2x body budget under the 2x raw backstop. Now the swallowed
# lines must be COUNTED (err toward RED). 10 real body + an unterminated
# <details> holding 200 smuggled lines → body must measure 211 (> 120 cap).
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/911-unterm/"
{
  for ((i = 1; i <= 10; i++)); do printf 'body line %d\n' "$i"; done
  printf '<details>\n'                          # opens, never closed
  for ((i = 1; i <= 200; i++)); do printf 'smuggled line %d\n' "$i"; done
} > "$f/docs/ship-flow/911-unterm/verify.md"
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.11 unterminated <details> over-cap body → FAILS (smuggle caught)"
assert_stderr_contains "body content is 211 lines" \
  "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.11b unterminated <details> lines are COUNTED (10 body + tag + 200 = 211)"
rm -rf "$f"

# ---- Case 12: MID-LINE <details> mention → must NOT enter details-mode ----
# Prose like "see the <details> below" must count as normal body and must NOT
# drop the following lines. 130 body lines (one of which mentions <details>
# mid-line) → body = 130 > 120 cap → FAIL. If mid-line wrongly triggered
# details-mode, the trailing lines would be dropped and it would false-GREEN.
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/912-midline/"
{
  printf 'see the <details> below for raw output\n'   # mid-line mention (body)
  for ((i = 1; i <= 129; i++)); do printf 'body line %d\n' "$i"; done
} > "$f/docs/ship-flow/912-midline/verify.md"
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.12 mid-line <details> mention + over-cap body → FAILS (no accidental drop)"
assert_stderr_contains "body content is 130 lines" \
  "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.12b mid-line <details> counted as body (130, not dropped)"
rm -rf "$f"

# ---- Case 13: BALANCED standalone <details> still EXCLUDED (regression guard) ----
# A properly-balanced standalone <details>…</details> must still be excluded so
# the legitimate escape hatch keeps working: 100 body + a 500-line balanced
# <details> → body = 100 ≤ 120, raw 602 > 240 backstop... so for the body-only
# exclusion to be observable WITHOUT tripping the 2x backstop, keep raw under
# 240: 100 body + a 100-line balanced <details> (raw ~202 < 240) → PASS.
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/913-balanced/"
{
  for ((i = 1; i <= 100; i++)); do printf 'body line %d\n' "$i"; done
  printf '<details>\n'
  for ((i = 1; i <= 98; i++)); do printf 'collapsed evidence %d\n' "$i"; done
  printf '</details>\n'
} > "$f/docs/ship-flow/913-balanced/verify.md"
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.13 balanced standalone <details> still excluded (escape hatch works) → PASS"
rm -rf "$f"

# ---- Case 14: over-cap stage artifacts under _archive/_debriefs/_mods → NOT red ----
# design.md:87 scope table marks these trees NOT capped. Both modes must skip.
f=$(mk_fixture)
mkdir -p "$f/docs/ship-flow/_archive/914-arch/" \
         "$f/docs/ship-flow/_debriefs/914-deb/" \
         "$f/docs/ship-flow/_mods/914-mod/"
write_body_lines "$f/docs/ship-flow/_archive/914-arch/plan.md"  500
write_body_lines "$f/docs/ship-flow/_debriefs/914-deb/verify.md" 500
write_body_lines "$f/docs/ship-flow/_mods/914-mod/review.md"     500
assert_exit 0 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.14 over-cap files under _archive/_debriefs/_mods → NOT scanned (exit 0)"
# And confirm a LIVE over-cap file alongside them DOES still red (exclusion is
# scoped to the terminal trees, not a blanket skip).
mkdir -p "$f/docs/ship-flow/914-live/"
write_body_lines "$f/docs/ship-flow/914-live/plan.md" 500
assert_exit 1 "bash $CHECK_SCRIPT --test-fixture $f --check artifact-verbosity" \
  "C15.14b live over-cap alongside excluded trees → still FAILS"
rm -rf "$f"

echo
echo "=== C15 artifact-verbosity — git branch-scope grandfather (real merge-base..HEAD path) ==="

# Build a real git repo: an over-cap stage artifact committed ON main (the
# grandfathered, pre-existing state), then a branch that touches a DIFFERENT
# file. The pre-existing over-cap file is NOT in merge_base..HEAD → must NOT red.
# A second branch that MODIFIES the over-cap file → must red (any touched
# artifact comes under enforcement).
run_check_in_repo() {
  local repo_dir="$1"
  (
    cd "$repo_dir" || exit 1
    git update-ref refs/remotes/origin/main "$(git rev-parse main)"
    bash "${BIN_DIR}/check-invariants.sh" --check artifact-verbosity
  )
}

setup_git_repo() {
  # $1 = mode: "untouched" | "touched"
  local mode="$1" dir
  dir="$(mktemp -d)"
  (
    cd "$dir" || exit 1
    git init -q -b main
    git config user.email test@test
    git config user.name test

    # Pre-existing OVER-CAP stage artifact committed on main (grandfathered).
    mkdir -p docs/ship-flow/800-legacy
    { for ((i = 1; i <= 250; i++)); do printf 'legacy body %d\n' "$i"; done; } > docs/ship-flow/800-legacy/plan.md
    git add docs/ship-flow/800-legacy/plan.md
    git commit -qm "baseline: pre-existing over-cap legacy plan.md"

    git checkout -q -b feature
    if [ "$mode" = "untouched" ]; then
      # Branch touches a DIFFERENT, under-cap file — legacy file out of diff.
      mkdir -p docs/ship-flow/801-new
      { for ((i = 1; i <= 50; i++)); do printf 'new under-cap body %d\n' "$i"; done; } > docs/ship-flow/801-new/plan.md
      git add docs/ship-flow/801-new/plan.md
      git commit -qm "feat: add under-cap plan.md"
    else
      # Branch MODIFIES the pre-existing over-cap file → now in diff → enforced.
      printf 'one more legacy line\n' >> docs/ship-flow/800-legacy/plan.md
      git add docs/ship-flow/800-legacy/plan.md
      git commit -qm "edit: touch legacy plan.md"
    fi
  )
  echo "$dir"
}

# ---- Case 8: pre-existing over-cap file NOT in branch diff → NOT scanned (no false red) ----
TMP="$(setup_git_repo untouched)"
assert_exit 0 "run_check_in_repo '$TMP'" \
  "C15.8 grandfather: untouched over-cap legacy file NOT scanned (exit 0)"
rm -rf "$TMP"

# ---- Case 9: branch MODIFIES the over-cap file → enforced → FAILS ----
TMP="$(setup_git_repo touched)"
assert_exit 1 "run_check_in_repo '$TMP'" \
  "C15.9 grandfather: touched over-cap file IS enforced (exit 1)"
rm -rf "$TMP"

# ---- Case 10: no origin/main (fresh repo) → PASS with skip (C14 precedent) ----
TMP="$(mktemp -d)"
(
  cd "$TMP" || exit 1
  git init -q -b main
  git config user.email test@test
  git config user.name test
  mkdir -p docs/ship-flow/810-x
  { for ((i = 1; i <= 300; i++)); do printf 'x %d\n' "$i"; done; } > docs/ship-flow/810-x/plan.md
  git add docs/ship-flow/810-x/plan.md
  git commit -qm "init"
)
assert_exit 0 "( cd '$TMP' && bash '${BIN_DIR}/check-invariants.sh' --check artifact-verbosity )" \
  "C15.10 no origin/main → PASS with skip (no false red)"
rm -rf "$TMP"

# ---- Case 15: git-mode — touched over-cap file under _archive/ → NOT scanned ----
# The **/plan.md glob also matches docs/ship-flow/_archive/**; the negative
# pathspecs must drop it. Branch ADDS an over-cap plan.md under _archive/ → must
# NOT red (design.md:87 scope). Mirrors Case 14 for the git path.
TMP="$(mktemp -d)"
(
  cd "$TMP" || exit 1
  git init -q -b main
  git config user.email test@test
  git config user.name test
  mkdir -p docs/ship-flow/820-seed
  printf 'seed\n' > docs/ship-flow/820-seed/index.md
  git add docs/ship-flow/820-seed/index.md
  git commit -qm "baseline"
  git checkout -q -b feature
  mkdir -p docs/ship-flow/_archive/820-old
  { for ((i = 1; i <= 400; i++)); do printf 'archived over-cap %d\n' "$i"; done; } > docs/ship-flow/_archive/820-old/plan.md
  git add docs/ship-flow/_archive/820-old/plan.md
  git commit -qm "archive: move old over-cap plan.md"
)
assert_exit 0 "run_check_in_repo '$TMP'" \
  "C15.15 git-mode: touched over-cap _archive/ plan.md → NOT scanned (exit 0)"
rm -rf "$TMP"

exit $FAIL
