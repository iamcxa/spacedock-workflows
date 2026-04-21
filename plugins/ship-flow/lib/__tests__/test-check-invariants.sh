#!/usr/bin/env bash
# test-check-invariants.sh — DC-3/5/6/7/8/10/11/12/13 runner for #067 ship-flow-invariants
# Pattern: test-map-layer.sh (same dir) — FAIL=0, exit $FAIL
# Tests initially FAIL because plugins/ship-flow/bin/check-invariants.sh doesn't exist yet (T3).
# Tasks T6, T7, T8 progressively replace stubs with live assertions as check functions ship.

set -u
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LIB_DIR="${SCRIPT_DIR}/.."
PLUGIN_DIR="${LIB_DIR}/.."
REPO_ROOT="$(cd "${PLUGIN_DIR}/../.." && pwd)"
CHECK_SCRIPT="${PLUGIN_DIR}/bin/check-invariants.sh"
HOOK_SCRIPT="${PLUGIN_DIR}/hooks/warn-direct-read.js"
FAIL=0

# Load map-helpers for kebab-case validator (reused by check-invariants.sh)
[ -f "${LIB_DIR}/map-helpers.sh" ] && source "${LIB_DIR}/map-helpers.sh"

# ---- Assertion helpers (copied from test-map-layer.sh:13-31) ----
# shellcheck disable=SC2329  # helpers used in later tasks' tests (T6/T7/T8 live assertions)
assert_exit() {
  local expected="$1" cmd="$2" name="$3"
  local got
  eval "$cmd" >/dev/null 2>&1; got=$?
  if [ "$got" = "$expected" ]; then echo "OK $name"
  else echo "FAIL $name (expected exit $expected, got $got)"; FAIL=1; fi
}
# shellcheck disable=SC2329
assert_stdout_matches() {
  local pattern="$1" cmd="$2" name="$3"
  local out; out="$(eval "$cmd" 2>&1)"
  if echo "$out" | grep -qE "$pattern"; then echo "OK $name"
  else echo "FAIL $name (stdout/stderr did not match /$pattern/)"; FAIL=1; fi
}
# shellcheck disable=SC2329
assert_stderr_contains() {
  local needle="$1" cmd="$2" name="$3"
  local err; err="$(eval "$cmd" 2>&1 >/dev/null)"
  if echo "$err" | grep -qF "$needle"; then echo "OK $name"
  else echo "FAIL $name (stderr missing: $needle)"; FAIL=1; fi
}

# Precondition: if check-invariants.sh isn't built yet (T3 not shipped), fail fast
# with a clear marker — tests that pass only due to exit 127 are a false-pass trap.
precondition_check_script_exists() {
  if [ ! -x "$CHECK_SCRIPT" ]; then
    echo "PRECONDITION-FAIL: $CHECK_SCRIPT missing or non-executable (T3 not shipped yet)"
    echo "All DC-3/5/6/7/8/10/11/12/13 tests will FAIL until T3 ships the skeleton."
    return 1
  fi
}
# Precondition: hook script for DC-3
precondition_hook_exists() {
  if [ ! -f "$HOOK_SCRIPT" ]; then
    echo "PRECONDITION-FAIL: $HOOK_SCRIPT missing (T4 not shipped yet)"
    return 1
  fi
}

# ---- Mock plugin-dir helper ----
# Creates minimal {skills,hooks,bin,lib,references,docs/ship-flow}/ structure under mktemp -d.
# Caller adds specific fixtures per test, then passes dir to check-invariants.sh --test-fixture.
create_mock_plugin_dir() {
  local d; d="$(mktemp -d)"
  mkdir -p "$d/plugins/ship-flow/skills" \
           "$d/plugins/ship-flow/hooks" \
           "$d/plugins/ship-flow/bin" \
           "$d/plugins/ship-flow/lib" \
           "$d/plugins/ship-flow/references" \
           "$d/docs/ship-flow"
  echo "$d"
}

cd "$REPO_ROOT" || exit 1

# ========== DC-3: warn-direct-read.js advises on entity-file Read ==========
# Hook reads stdin JSON {tool_name, tool_input: {file_path}, cwd}; outputs
# stdout JSON with `systemMessage` when file_path matches docs/ship-flow/*.md (not _archive).
dc3_hook_warns() {
  local input='{"tool_name":"Read","tool_input":{"file_path":"/abs/proj/docs/ship-flow/foo.md"},"cwd":"/abs/proj"}'
  local out; out="$(echo "$input" | node "$HOOK_SCRIPT" 2>/dev/null)" || return 1
  echo "$out" | grep -q 'systemMessage' && echo "$out" | grep -q 'extract-section.sh'
}
if dc3_hook_warns 2>/dev/null; then echo "OK DC-3 hook warns on entity-file Read"
else echo "FAIL DC-3 hook warns on entity-file Read"; FAIL=1; fi

# DC-3b: hook stays silent on non-entity files
dc3b_hook_silent_on_other() {
  local input='{"tool_name":"Read","tool_input":{"file_path":"/abs/proj/src/index.ts"},"cwd":"/abs/proj"}'
  local out; out="$(echo "$input" | node "$HOOK_SCRIPT" 2>/dev/null)" || return 1
  # Empty output OR no systemMessage = silent pass
  [ -z "$out" ] || ! echo "$out" | grep -q 'systemMessage'
}
if dc3b_hook_silent_on_other 2>/dev/null; then echo "OK DC-3b hook silent on non-entity"
else echo "FAIL DC-3b hook silent on non-entity"; FAIL=1; fi

# DC-3c: hook skips archived entities (read-only history)
dc3c_hook_skip_archive() {
  local input='{"tool_name":"Read","tool_input":{"file_path":"/abs/proj/docs/ship-flow/_archive/foo.md"},"cwd":"/abs/proj"}'
  local out; out="$(echo "$input" | node "$HOOK_SCRIPT" 2>/dev/null)" || return 1
  [ -z "$out" ] || ! echo "$out" | grep -q 'systemMessage'
}
if dc3c_hook_skip_archive 2>/dev/null; then echo "OK DC-3c hook skips _archive"
else echo "FAIL DC-3c hook skips _archive"; FAIL=1; fi

# ========== DC-5: check-invariants.sh is syntactically clean ==========
assert_exit 0 "bash -n '$CHECK_SCRIPT'" 'DC-5 bash -n'
if command -v shellcheck >/dev/null 2>&1; then
  assert_exit 0 "shellcheck '$CHECK_SCRIPT'" 'DC-5 shellcheck'
else echo "SKIP DC-5 shellcheck (not installed)"; fi

# Note: tests below use `[ "$rc" = "1" ]` (exact exit 1) not `!= 0` to avoid
# false-pass when script is missing (exit 127 "command not found" would pass `!= 0`).

# ========== DC-6: skill count > 7 triggers fail (exit 1) ==========
dc6_skill_count() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  # Create 8 stub SKILL.md files → should trigger fail
  for i in 1 2 3 4 5 6 7 8; do
    mkdir -p "$d/plugins/ship-flow/skills/stub-$i"
    echo "# stub $i" > "$d/plugins/ship-flow/skills/stub-$i/SKILL.md"
  done
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check skill-count >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if dc6_skill_count 2>/dev/null; then echo "OK DC-6 skill count guard fails at 8 skills"
else echo "FAIL DC-6 skill count guard fails at 8 skills"; FAIL=1; fi

# ========== DC-7: preamble regrowth (≥ 2 copies, not allowlisted) triggers fail ==========
# Uses `## Verify Stage Preamble` — in check's signatures list but NOT in 046f-deferred
# allowlist, so 2 copies triggers ERROR + exit 1. (The allowlisted signatures "Runtime
# Detection Preamble" and "Step R1: Detect Stacks" emit WARN and don't fail — they're
# baseline pre-046f duplication.)
dc7_preamble_regrowth() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/sk-a" "$d/plugins/ship-flow/skills/sk-b"
  local preamble="## Verify Stage Preamble"
  printf '# skill a\n\n%s\n\nsome content\n' "$preamble" > "$d/plugins/ship-flow/skills/sk-a/SKILL.md"
  printf '# skill b\n\n%s\n\nsome content\n' "$preamble" > "$d/plugins/ship-flow/skills/sk-b/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check preamble-regrowth >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if dc7_preamble_regrowth 2>/dev/null; then echo "OK DC-7 preamble regrowth fails at 2 copies"
else echo "FAIL DC-7 preamble regrowth fails at 2 copies"; FAIL=1; fi

# ========== DC-8: section-tag coverage — mixed-mode entity with orphan H2 triggers fail ==========
# Grandfather rule: entities with ZERO section tags are skipped (pre-049 baseline).
# Violation scenario is "entity has tags (adopted convention) but some H2/H3 is orphan".
dc8_section_tag_coverage() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  cat > "$d/docs/ship-flow/mixed-entity.md" <<'EOF'
---
id: "999"
title: mixed-mode entity
---

<!-- section:sharp-output -->
## Sharp Output
Some wrapped content.
<!-- /section:sharp-output -->

## Unwrapped H2

This header is NOT inside a section tag — should trigger DC-8 failure.

### Also Unwrapped H3
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check section-tag-coverage >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if dc8_section_tag_coverage 2>/dev/null; then echo "OK DC-8 section-tag coverage fails on unwrapped H2"
else echo "FAIL DC-8 section-tag coverage fails on unwrapped H2"; FAIL=1; fi

# ========== DC-10: direct-Read static guard — Read(docs/ship-flow/*.md) unjustified (exit 1) ==========
dc10_direct_read_guard() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/sk-violator"
  cat > "$d/plugins/ship-flow/skills/sk-violator/SKILL.md" <<'EOF'
# Violator skill

Read(docs/ship-flow/entity.md) to inspect state.
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check direct-read-static >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if dc10_direct_read_guard 2>/dev/null; then echo "OK DC-10 direct-Read static fails on unjustified Read"
else echo "FAIL DC-10 direct-Read static fails on unjustified Read"; FAIL=1; fi

# ========== DC-11: fan-out reviewer guard — >2 unconditional Agent dispatches (exit 1) ==========
dc11_fan_out_guard() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-verify"
  cat > "$d/plugins/ship-flow/skills/ship-verify/SKILL.md" <<'EOF'
# ship-verify

Dispatch reviewers:
Agent(model: haiku, prompt: "review 1")
Agent(model: haiku, prompt: "review 2")
Agent(model: haiku, prompt: "review 3")
Agent(model: haiku, prompt: "review 4")
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check fan-out-reviewer >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if dc11_fan_out_guard 2>/dev/null; then echo "OK DC-11 fan-out guard fails at 4 reviewers"
else echo "FAIL DC-11 fan-out guard fails at 4 reviewers"; FAIL=1; fi

# ========== DC-12: boolean-gate — Tier A OR Tier B passes ==========
# Tier A: grep finds no enum-gate values in repo → exit 0
# Tier B: degraded — script echoes "design-review checklist" to stderr, exit 0
dc12_boolean_gate() {
  local out
  out="$(bash "$CHECK_SCRIPT" --check boolean-gate 2>&1)" || return 1
  # Accept either Tier A ("no enum gate found") or Tier B ("design-review checklist")
  echo "$out" | grep -qE "no enum gate found|design-review checklist"
}
if dc12_boolean_gate 2>/dev/null; then echo "OK DC-12 boolean-gate (Tier A or B)"
else echo "FAIL DC-12 boolean-gate (Tier A or B)"; FAIL=1; fi

# ========== DC-13: map-3 R-ID placeholder — intentional skip ==========
dc13_rid_placeholder() {
  local out
  out="$(bash "$CHECK_SCRIPT" --map rid 2>&1)" || return 1
  echo "$out" | grep -q 'intentional'
}
if dc13_rid_placeholder 2>/dev/null; then echo "OK DC-13 R-ID placeholder intentional skip"
else echo "FAIL DC-13 R-ID placeholder intentional skip"; FAIL=1; fi

# ========== DC-14: post-046f hard-enforcement — Runtime Detection Preamble regrowth triggers ERROR ==========
# After 046f (entity #075) empties allowlist_deferred, "## Runtime Detection Preamble" behaves
# like any other non-allowlisted signature: 2 copies → ERROR → rc=1. Inject → assert fail →
# revert to 1 copy → assert pass. Dogfood of the rule 046f installed.
# (NOTE: original plan Task 1 labelled this DC-13, but DC-13 was already taken by the R-ID
# placeholder test above — renumbered to DC-14 during execute per benign-drift auto-proceed.)
dc14_runtime_preamble_hard_enforcement() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/sk-a" "$d/plugins/ship-flow/skills/sk-b"
  local preamble="## Runtime Detection Preamble"
  # Inject: 2 copies → expect rc=1
  printf '# skill a\n\n%s\n\nsome content\n' "$preamble" > "$d/plugins/ship-flow/skills/sk-a/SKILL.md"
  printf '# skill b\n\n%s\n\nsome content\n' "$preamble" > "$d/plugins/ship-flow/skills/sk-b/SKILL.md"
  local rc_inject
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check preamble-regrowth >/dev/null 2>&1; rc_inject=$?
  # Revert: 1 copy (only sk-a keeps preamble) → expect rc=0
  printf '# skill b\n\nno preamble here\n' > "$d/plugins/ship-flow/skills/sk-b/SKILL.md"
  local rc_revert
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check preamble-regrowth >/dev/null 2>&1; rc_revert=$?
  rm -rf "$d"
  [ "$rc_inject" = "1" ] && [ "$rc_revert" = "0" ]
}
if dc14_runtime_preamble_hard_enforcement 2>/dev/null; then echo "OK DC-14 runtime-preamble hard-enforcement (inject=fail, revert=pass)"
else echo "FAIL DC-14 runtime-preamble hard-enforcement (inject=fail, revert=pass)"; FAIL=1; fi

exit $FAIL
