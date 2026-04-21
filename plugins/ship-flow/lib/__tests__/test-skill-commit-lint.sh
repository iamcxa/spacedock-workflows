#!/usr/bin/env bash
# test-skill-commit-lint.sh — DC-4 regression guard for #063 explicit-staging-ship-flow
# Pattern: test-map-layer.sh FAIL=0 accumulator
set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$(cd "${SCRIPT_DIR}/../../skills" && pwd)"
FAIL=0

# assert_no_match: checks that $pattern does not appear as an ACTUAL git command
# (lines starting with `git ...` in code blocks), not as documentation/table mentions.
# Excludes lines where the pattern appears inside backtick-quoted text or table cells.
assert_no_match() {
  local pattern="$1" name="$2"
  # Match only lines where the forbidden pattern is used as a bare command (not inside ` ` or | table)
  local hits
  hits=$(grep -rEn "^${pattern}" "$SKILLS_DIR" --include='*.md' 2>/dev/null | head -5)
  if [ -n "$hits" ]; then
    echo "FAIL $name"
    echo "  Forbidden pattern '$pattern' used as bare command:"
    echo "$hits" | sed 's/^/    /'
    FAIL=1
  else
    echo "OK $name"
  fi
}

assert_match() {
  local pattern="$1" file="$2" name="$3" min="${4:-1}"
  local count
  count=$(grep -cE "$pattern" "$file" 2>/dev/null) || count=0
  if [ "$count" -ge "$min" ]; then
    echo "OK $name ($count matches)"
  else
    echo "FAIL $name (expected >=${min}, got ${count})"
    FAIL=1
  fi
}

echo "=== DC-4: Forbidden staging patterns absent from plugins/ship-flow/skills/ ==="
assert_no_match 'git add -A' 'git-add-A forbidden'
assert_no_match 'git add \.' 'git-add-dot forbidden'
assert_no_match 'git commit -am' 'git-commit-am forbidden'
assert_no_match 'git commit -a -m' 'git-commit-a-m forbidden'

echo
echo "=== DC-1/DC-2: Pathspec-lock syntax present in commit examples ==="
assert_match 'git commit.*-m.* -- ' "${SKILLS_DIR}/ship-execute/SKILL.md" 'ship-execute pathspec-lock' 3
assert_match 'git commit.*-m.* -- ' "${SKILLS_DIR}/ship-onboard/SKILL.md" 'ship-onboard pathspec-lock' 3

echo
echo "=== DC-3: Forbidden staging patterns block present ==="
assert_match 'Forbidden staging patterns' "${SKILLS_DIR}/ship-execute/SKILL.md" 'ship-execute Forbidden block'
assert_match 'Forbidden staging patterns' "${SKILLS_DIR}/ship-onboard/SKILL.md" 'ship-onboard Forbidden reference'

echo
echo "=== DC-5: Inline-on-main section present in ship-execute ==="
assert_match 'Inline-on-main' "${SKILLS_DIR}/ship-execute/SKILL.md" 'ship-execute Inline-on-main section'

if [ "$FAIL" = "0" ]; then
  echo
  echo "ALL PASS (#063 DC-1..DC-5 verified)"
fi
exit $FAIL
