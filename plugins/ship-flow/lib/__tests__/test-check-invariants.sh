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

# ========== DC-6: split counting — stage ≤ 7, utility uncapped, orphan fails ==========

# DC-6a: 6 stage skills (current post-wave5b count) → pass
dc6a_stage_count_6_pass() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  for sk in ship-shape ship ship-plan ship-execute ship-verify ship-review; do
    mkdir -p "$d/plugins/ship-flow/skills/$sk"
    echo "# $sk" > "$d/plugins/ship-flow/skills/$sk/SKILL.md"
  done
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check skill-count >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if dc6a_stage_count_6_pass 2>/dev/null; then echo "OK DC-6a stage=6 passes"
else echo "FAIL DC-6a stage=6 passes"; FAIL=1; fi

# DC-6b: 8 stage skills → fail (exceeds cap of 7)
dc6b_stage_count_8_fail() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  for sk in ship-shape ship ship-plan ship-execute ship-verify ship-review ship-alpha ship-beta; do
    mkdir -p "$d/plugins/ship-flow/skills/$sk"
    echo "# $sk" > "$d/plugins/ship-flow/skills/$sk/SKILL.md"
  done
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check skill-count >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if dc6b_stage_count_8_fail 2>/dev/null; then echo "OK DC-6b stage=8 fails (cap 7)"
else echo "FAIL DC-6b stage=8 fails (cap 7)"; FAIL=1; fi

# DC-6c: 3 utility skills (all known) alongside 6 stage → pass (utility uncapped)
dc6c_utility_uncapped_pass() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  for sk in ship-shape ship ship-plan ship-execute ship-verify ship-review; do
    mkdir -p "$d/plugins/ship-flow/skills/$sk"
    echo "# $sk" > "$d/plugins/ship-flow/skills/$sk/SKILL.md"
  done
  for sk in add-todos ship-onboard ship-runtime-detect; do
    mkdir -p "$d/plugins/ship-flow/skills/$sk"
    echo "# $sk" > "$d/plugins/ship-flow/skills/$sk/SKILL.md"
  done
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check skill-count >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if dc6c_utility_uncapped_pass 2>/dev/null; then echo "OK DC-6c utility skills uncapped (6 stage + 3 utility = pass)"
else echo "FAIL DC-6c utility skills uncapped"; FAIL=1; fi

# DC-6d: orphan skill (not in either allowlist) → fail
dc6d_orphan_skill_fail() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  for sk in ship-shape ship ship-plan ship-execute ship-verify ship-review; do
    mkdir -p "$d/plugins/ship-flow/skills/$sk"
    echo "# $sk" > "$d/plugins/ship-flow/skills/$sk/SKILL.md"
  done
  # Add an unclassified skill
  mkdir -p "$d/plugins/ship-flow/skills/ship-mystery"
  echo "# mystery" > "$d/plugins/ship-flow/skills/ship-mystery/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check skill-count >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if dc6d_orphan_skill_fail 2>/dev/null; then echo "OK DC-6d orphan skill fails"
else echo "FAIL DC-6d orphan skill fails"; FAIL=1; fi

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

# ========== DC-8b: Stage Report whitelist — spacedock-protocol H2 + nested H3 NOT flagged ==========
# Post-#078 CI-fail harvest (2026-04-22): spacedock ensign-shared-core:46-51 instructs ensigns to
# append untagged "## Stage Report: {stage}" + "### Summary" at entity-file end. Ship-flow's
# check-invariants must whitelist this plugin-agnostic protocol header, not flag it as orphan.
dc8b_stage_report_whitelist() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  cat > "$d/docs/ship-flow/stage-report-entity.md" <<'EOF'
---
id: "998"
title: stage-report whitelist fixture
---

<!-- section:sharp-output -->
## Sharp Output
Wrapped content.
<!-- /section:sharp-output -->

## Stage Report: execute

- DONE: task 1
- DONE: task 2

### Summary

Narrative summary paragraph from spacedock ensign protocol.

## Stage Report: verify

- DONE: quality gate

### Summary

Another narrative summary.
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check section-tag-coverage >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  # Exit 0 = pass (no orphan ERRORs). Whitelist working correctly.
  [ "$rc" = "0" ]
}
if dc8b_stage_report_whitelist 2>/dev/null; then echo "OK DC-8b Stage Report whitelist (spacedock protocol)"
else echo "FAIL DC-8b Stage Report whitelist (spacedock protocol)"; FAIL=1; fi

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

# ========== DC-10: check_pitch_assumptions — warns on pitch with zero critical assumptions ==========
dc10_pitch_assumptions() {
  local fixdir
  fixdir="$(mktemp -d)"
  mkdir -p "$fixdir/docs/fake-workflow"
  # Good pitch — has critical assumption
  cat > "$fixdir/docs/fake-workflow/pitch-good.md" <<'EOF'
---
id: "pitch-good"
title: "Pitch with critical assumption"
status: sharp
pattern: pitch
stated_assumptions:
  - id: "A1"
    claim: "Good claim"
    verified_by: codebase-grep
    verification: "true"
    confidence_at_shape: 90
    criticality: critical
---
body
EOF
  # Bad pitch — no critical assumption
  cat > "$fixdir/docs/fake-workflow/pitch-bad.md" <<'EOF'
---
id: "pitch-bad"
title: "Pitch with no critical assumption"
status: sharp
pattern: pitch
stated_assumptions: []
---
body
EOF
  # Non-pitch entity — should be ignored
  cat > "$fixdir/docs/fake-workflow/single-entity.md" <<'EOF'
---
id: "single"
title: "Regular single entity"
status: draft
---
body
EOF

  # Run check against fixture
  local warn_out
  warn_out="$(bash "$CHECK_SCRIPT" --test-fixture "$fixdir" --check pitch-assumptions 2>&1 1>/dev/null)"
  rm -rf "$fixdir"
  # Assertions
  if echo "$warn_out" | grep -q 'pitch-bad.md'; then
    echo "OK DC-10a warning fired on pitch-bad"
  else
    echo "FAIL DC-10a warning not fired on pitch-bad"; FAIL=1
  fi
  if echo "$warn_out" | grep -q 'pitch-good.md'; then
    echo "FAIL DC-10b false warning on pitch-good"; FAIL=1
  else
    echo "OK DC-10b no false warning on pitch-good"
  fi
  if echo "$warn_out" | grep -q 'single-entity.md'; then
    echo "FAIL DC-10c false warning on non-pitch entity"; FAIL=1
  else
    echo "OK DC-10c non-pitch entity ignored"
  fi
  return 0
}
dc10_pitch_assumptions

# ========== stage-artifact-path: SKILL references its artifact filename ==========

# Pass: SKILL mentions its artifact
stage_artifact_pass() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nWrites plan.md to entity folder.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check stage-artifact-path >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if stage_artifact_pass 2>/dev/null; then echo "OK stage-artifact-path: plan.md present → pass"
else echo "FAIL stage-artifact-path: plan.md present → pass"; FAIL=1; fi

# Fail: SKILL missing artifact reference
stage_artifact_fail() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nNo mention of the artifact here.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check stage-artifact-path >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if stage_artifact_fail 2>/dev/null; then echo "OK stage-artifact-path: missing plan.md → fail"
else echo "FAIL stage-artifact-path: missing plan.md → fail"; FAIL=1; fi

# ========== layer-a-delegation: SKILL has invocation OR explicit escape ==========

# Pass: SKILL has a plugin-qualified Skill invocation (markdown backtick form)
layer_a_pass_invocation_backtick() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nInvoke `Skill: superpowers:writing-plans` for plan authoring.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-delegation >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if layer_a_pass_invocation_backtick 2>/dev/null; then echo "OK layer-a-delegation: backtick Skill invocation → pass"
else echo "FAIL layer-a-delegation: backtick Skill invocation → pass"; FAIL=1; fi

# Pass: SKILL has a function-style invocation `Skill(plugin:name)`
layer_a_pass_invocation_funccall() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nThe flow dispatches Skill(superpowers:writing-plans) inline.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-delegation >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if layer_a_pass_invocation_funccall 2>/dev/null; then echo "OK layer-a-delegation: Skill() call → pass"
else echo "FAIL layer-a-delegation: Skill() call → pass"; FAIL=1; fi

# Pass: SKILL has explicit "pure orchestration" escape annotation
layer_a_pass_escape() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nno Layer A — pure orchestration (autonomous proposer owns flow).\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-delegation >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if layer_a_pass_escape 2>/dev/null; then echo "OK layer-a-delegation: escape annotation → pass"
else echo "FAIL layer-a-delegation: escape annotation → pass"; FAIL=1; fi

# Fail: SKILL mentions "Layer A" in prose but has NO invocation and NO escape — the cargo-cult case
layer_a_fail_cargo_cult() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nLayer A is important. We should dispatch the planner subagent sometimes.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-delegation >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if layer_a_fail_cargo_cult 2>/dev/null; then echo "OK layer-a-delegation: cargo-cult prose (no invocation, no escape) → fail"
else echo "FAIL layer-a-delegation: cargo-cult prose (no invocation, no escape) → fail"; FAIL=1; fi

# Fail: SKILL completely silent
layer_a_fail_silent() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nNo delegation info here.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-delegation >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if layer_a_fail_silent 2>/dev/null; then echo "OK layer-a-delegation: silent SKILL → fail"
else echo "FAIL layer-a-delegation: silent SKILL → fail"; FAIL=1; fi

# ========== layer-a-table-parity: SKILL has canonical H2 + description-prefix ==========

# Pass: SKILL has both canonical `## Layer A delegation (Principle 6 Rule B)` H2
# AND description-frontmatter `Layer A delegation:` prefix.
layer_a_parity_pass_baseline() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  cat > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md" <<'EOF'
---
name: ship-plan
description: "Use when writing a plan. Layer A delegation: superpowers:writing-plans owns authoring."
---

# ship-plan

## Layer A delegation (Principle 6 Rule B)

`superpowers:writing-plans` owns plan authoring.
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-table-parity >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if layer_a_parity_pass_baseline 2>/dev/null; then echo "OK layer-a-table-parity: canonical H2 + description-prefix → pass"
else echo "FAIL layer-a-table-parity: canonical H2 + description-prefix → pass"; FAIL=1; fi

# Fail: SKILL has description-prefix but missing `## Layer A delegation` H2
layer_a_parity_fail_missing_heading() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  cat > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md" <<'EOF'
---
name: ship-plan
description: "Use when writing a plan. Layer A delegation: superpowers:writing-plans owns authoring."
---

# ship-plan

Skill: superpowers:writing-plans is invoked but no canonical H2 section.
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-table-parity >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if layer_a_parity_fail_missing_heading 2>/dev/null; then echo "OK layer-a-table-parity: missing H2 heading → fail"
else echo "FAIL layer-a-table-parity: missing H2 heading → fail"; FAIL=1; fi

# Fail: SKILL has H2 but description-frontmatter lacks `Layer A delegation:` prefix
layer_a_parity_fail_missing_description_prefix() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  cat > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md" <<'EOF'
---
name: ship-plan
description: "Use when writing a plan. No prefix here."
---

# ship-plan

## Layer A delegation (Principle 6 Rule B)

`superpowers:writing-plans` owns plan authoring.
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-table-parity >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if layer_a_parity_fail_missing_description_prefix 2>/dev/null; then echo "OK layer-a-table-parity: missing description-prefix → fail"
else echo "FAIL layer-a-table-parity: missing description-prefix → fail"; FAIL=1; fi

# Pass: multi-mode stage (ship-shape) with documented `Layer A exception` in place of H2
# — mirrors ship-shape Mode A autonomous-proposer pattern.
layer_a_parity_pass_mode_a_exception() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-shape"
  cat > "$d/plugins/ship-flow/skills/ship-shape/SKILL.md" <<'EOF'
---
name: ship-shape
description: "Use when shaping. Mode A: autonomous proposer (Layer A exception — documented in SKILL.md)."
---

# ship-shape

## Mode B — Interactive Q-loop (Layer A exception)

Delegates to `superpowers:brainstorming` when captain selects interactive.

## Mode C — Skill-authoring (Layer A exception)

Delegates to `superpowers:writing-skills` for skill design.
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check layer-a-table-parity >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if layer_a_parity_pass_mode_a_exception 2>/dev/null; then echo "OK layer-a-table-parity: ship-shape multi-mode exception → pass"
else echo "FAIL layer-a-table-parity: ship-shape multi-mode exception → pass"; FAIL=1; fi

# ========== team-fallback-documented: SKILL references TeamCreate/SendMessage fallback ==========

# Pass: SKILL has "fresh subagent" reference
team_fallback_pass() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nWhen SendMessage fails, use fresh subagent with captured context.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check team-fallback-documented >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if team_fallback_pass 2>/dev/null; then echo "OK team-fallback-documented: fresh subagent present → pass"
else echo "FAIL team-fallback-documented: fresh subagent present → pass"; FAIL=1; fi

# Pass: SKILL has explicit "no TeamCreate" annotation
team_fallback_pass_explicit() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\n<!-- no TeamCreate — pure inline orchestration -->\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check team-fallback-documented >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if team_fallback_pass_explicit 2>/dev/null; then echo "OK team-fallback-documented: explicit no-TeamCreate annotation → pass"
else echo "FAIL team-fallback-documented: explicit no-TeamCreate annotation → pass"; FAIL=1; fi

# Fail: SKILL silent on fallback
team_fallback_fail() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nLayer A: dispatches planner subagent. No word on infrastructure failure.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check team-fallback-documented >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if team_fallback_fail 2>/dev/null; then echo "OK team-fallback-documented: no fallback prose → fail"
else echo "FAIL team-fallback-documented: no fallback prose → fail"; FAIL=1; fi

# ========== cross-review-gate: SKILL has 5-factor rubric ==========

# Pass: SKILL has cross-review gate + 5-factor rubric + Feasibility
cross_review_pass() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  cat > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md" <<'EOF'
# ship-plan

### Cross-review gate (Principle 6 Rule C)

5-factor rubric adapted for plan stage:
1. Feasibility — tasks achievable?
2. Executable scope — atomic commits?
3. Quality — DCs runnable?
4. DC adequacy — observable checks?
5. Canonical sync — ARCHITECTURE.md touched?

Verdict: PROCEED / VETO / PROMPT_CAPTAIN.
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check cross-review-gate >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if cross_review_pass 2>/dev/null; then echo "OK cross-review-gate: full rubric present → pass"
else echo "FAIL cross-review-gate: full rubric present → pass"; FAIL=1; fi

# Fail: SKILL missing 5-factor rubric
cross_review_fail() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  mkdir -p "$d/plugins/ship-flow/skills/ship-plan"
  printf '# ship-plan\n\nNo gate here.\n' > "$d/plugins/ship-flow/skills/ship-plan/SKILL.md"
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check cross-review-gate >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if cross_review_fail 2>/dev/null; then echo "OK cross-review-gate: no rubric → fail"
else echo "FAIL cross-review-gate: no rubric → fail"; FAIL=1; fi

# ========== structural-parity-dc: UI entity must have parity signal ==========

# Pass: UI entity with parity signal
structural_parity_pass() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  cat > "$d/docs/ship-flow/ui-entity.md" <<'EOF'
---
id: "999"
type: ui
title: "UI entity with parity"
---

## Design Reference

DC-1: column count matches design (3 columns in grid).
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check structural-parity-dc >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "0" ]
}
if structural_parity_pass 2>/dev/null; then echo "OK structural-parity-dc: parity signal present → pass"
else echo "FAIL structural-parity-dc: parity signal present → pass"; FAIL=1; fi

# Fail: UI entity without parity signal
structural_parity_fail() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  cat > "$d/docs/ship-flow/ui-no-checks.md" <<'EOF'
---
id: "998"
type: ui
title: "UI entity without coverage"
---

## Design Reference

DC-1: renders correctly.
EOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check structural-parity-dc >/dev/null 2>&1; rc=$?
  rm -rf "$d"
  [ "$rc" = "1" ]
}
if structural_parity_fail 2>/dev/null; then echo "OK structural-parity-dc: no parity signal → fail"
else echo "FAIL structural-parity-dc: no parity signal → fail"; FAIL=1; fi

# Grandfather: pre-#048 allowlisted entities skip even without parity signal
structural_parity_grandfather() {
  local d; d="$(create_mock_plugin_dir)" || return 1
  # Use one of the 3 grandfathered slugs — no parity signal, should SKIP not ERROR
  cat > "$d/docs/ship-flow/design-stage-integration.md" <<'EOF'
---
id: "042"
title: "Design stage integration"
---

## Design Reference

DC-1: renders correctly.
EOF
  local rc stderr_out
  stderr_out="$(bash "$CHECK_SCRIPT" --test-fixture "$d" --check structural-parity-dc 2>&1 >/dev/null)"
  rc=$?
  rm -rf "$d"
  # Must pass (rc=0) AND emit SKIP line
  [ "$rc" = "0" ] && echo "$stderr_out" | grep -q "grandfathered"
}
if structural_parity_grandfather 2>/dev/null; then echo "OK structural-parity-dc: grandfather allowlist skips pre-#048 entity"
else echo "FAIL structural-parity-dc: grandfather allowlist skips pre-#048 entity"; FAIL=1; fi


# ── DC-17: verdict-flip-whitelist invariant check (pitch-101 T13) ────────────

echo "--- DC-17: verdict-flip-whitelist check ---"

# Case (a): current repo with T10+T12 verdict-flip block → check exits 0
if bash "$CHECK_SCRIPT" --check verdict-flip-whitelist >/dev/null 2>&1; then
  echo "OK DC-17a: verdict-flip-whitelist check exits 0 on current repo"
else
  echo "FAIL DC-17a: verdict-flip-whitelist check failed on current repo"; FAIL=1
fi

# Case (b): fixture with enum-string gate → check exits non-zero with ERROR
verdict_flip_fixture_bad() {
  local d
  d="$(mktemp -d)"
  mkdir -p "$d/plugins/ship-flow/skills/ship"
  cat > "$d/plugins/ship-flow/skills/ship/SKILL.md" << 'SKILLEOF'
---
description: "ship skill"
---
## Step 5 — Cross-review gate
**Verdict-flip transformation (density-aware autonomy, pitch 101)**:

**WHITELIST**:
- `reason_matches_skill_precedent`

verdict_mode: "ask"
SKILLEOF
  local rc stderr_out
  stderr_out="$(bash "$CHECK_SCRIPT" --test-fixture "$d" --check verdict-flip-whitelist 2>&1 >/dev/null)"
  rc=$?
  rm -rf "$d"
  [ "$rc" != "0" ] && echo "$stderr_out" | grep -qiE 'ERROR|enum.string'
}
if verdict_flip_fixture_bad 2>/dev/null; then
  echo "OK DC-17b: verdict-flip-whitelist check fails on enum-string gate fixture"
else
  echo "FAIL DC-17b: verdict-flip-whitelist check should fail on enum-string gate fixture"; FAIL=1
fi

# Case (c): fixture missing verdict-flip block entirely → check exits non-zero
verdict_flip_fixture_missing() {
  local d
  d="$(mktemp -d)"
  mkdir -p "$d/plugins/ship-flow/skills/ship"
  cat > "$d/plugins/ship-flow/skills/ship/SKILL.md" << 'SKILLEOF'
---
description: "ship skill"
---
## Step 5 — Cross-review gate
No verdict-flip here.
SKILLEOF
  local rc
  bash "$CHECK_SCRIPT" --test-fixture "$d" --check verdict-flip-whitelist >/dev/null 2>&1
  rc=$?
  rm -rf "$d"
  [ "$rc" != "0" ]
}
if verdict_flip_fixture_missing 2>/dev/null; then
  echo "OK DC-17c: verdict-flip-whitelist check fails when block absent"
else
  echo "FAIL DC-17c: verdict-flip-whitelist check should fail when block absent"; FAIL=1
fi

# ========== C9: principle-numbering — duplicate Principle N triggers fail ==========
# Pitch-113.2 incident: T3.1 added "Principle 7: Domain Registry" while file
# already had "Principle 7: Metadata-driven portability". This DC asserts
# uniqueness via `sort | uniq -d` over the N column in `^### Principle N:` lines.
TMP_INV="$(mktemp -t test-check-invariants-c9.XXXXXX)"

# C9-pass: live INVARIANTS.md (real file) — must pass at HEAD.
assert_exit "0" \
  "FIXTURE_INVARIANTS='${PLUGIN_DIR}/INVARIANTS.md' bash '$CHECK_SCRIPT' --check principle-numbering 2>/dev/null" \
  "C9 principle-numbering: live INVARIANTS.md has unique Principle Ns"

# C9-fail: synthetic fixture with duplicate "Principle 7" → exit 1 + stderr cite.
cat > "$TMP_INV" <<'EOF'
# INVARIANTS

### Principle 1: foo
text

### Principle 7: bar
text

### Principle 7: baz (DUPLICATE — should fail)
text
EOF
assert_exit "1" \
  "FIXTURE_INVARIANTS='$TMP_INV' bash '$CHECK_SCRIPT' --check principle-numbering 2>/dev/null" \
  "C9 principle-numbering: synthetic fixture with duplicate N=7 fails"

assert_stderr_contains "duplicate '### Principle 7:'" \
  "FIXTURE_INVARIANTS='$TMP_INV' bash '$CHECK_SCRIPT' --check principle-numbering" \
  "C9 principle-numbering: error message names the duplicate N"

rm -f "$TMP_INV"

exit $FAIL
