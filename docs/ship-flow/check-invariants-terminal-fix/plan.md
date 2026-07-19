# check-invariants terminal misclassification fix — Plan

### Summary

Fully-pinned design (verdict-branch drop CONFIRMED at design gate) → 4 serial TDD tasks, no
remaining open questions. Task 1 RED fixture, Task 2 one-line predicate fix (GREEN), Task 3 AC-2
corpus-honesty surfacing (listed, not fixed), Task 4 dual-env full gate. All 4 fixture cases and
the fix's flip behavior were live-verified during planning (patched, ran, reverted — file confirmed
clean, `git status --short` empty) — the table below is not copied from design.md unchecked, it is
re-confirmed against current HEAD.

### Task 1 — RED fixture: 4-case terminal-predicate DC block

**File:** `plugins/ship-flow/lib/__tests__/test-check-invariants.sh` — new block appended after the
last existing DC block (`DC-107b`), immediately before the file's final `exit $FAIL`. Suggested name
`DC-18` (next unused sequential number; existing numbering has gaps/dupes so this is advisory, not a
hard collision constraint).

Zero prior coverage confirmed: `grep _entity_is_terminal plugins/ship-flow/lib/__tests__/*.sh` = 0
hits before this task.

Reuses the existing `create_mock_plugin_dir()` helper and the `--test-fixture` + `--check
section-tag-coverage` invocation pattern already used by DC-8 (lines 241-264 of the same file).
Asserts on `check-invariants.sh:196`'s `SKIP … terminal historical entity` stderr line directly —
this line fires before any tag/grandfather logic, so each fixture needs only frontmatter
(`status:`/`completed:`/`verdict:`), no section tags, no body content beyond one throwaway `## H`.

Reference implementation (execute may adjust minor shell syntax but MUST preserve these 4
assertions' RED/GREEN semantics — each was live-verified this session):

<details>
<summary>Reference implementation — DC-18 fixture block (4 cases, live-verified)</summary>

```bash
# ========== DC-18: _entity_is_terminal predicate — only status: done is terminal ==========
# Zero prior coverage (grep _entity_is_terminal over __tests__/ = 0 hits before this task).
_dc18_check_terminal_skip() {
  # $1 = fixture frontmatter+body (heredoc string), $2 = "present"|"absent" (expected SKIP line)
  local d; d="$(create_mock_plugin_dir)" || return 1
  printf '%s\n' "$1" > "$d/docs/ship-flow/dc18-entity.md"
  local err
  err=$(bash "$CHECK_SCRIPT" --test-fixture "$d" --check section-tag-coverage 2>&1 >/dev/null)
  rm -rf "$d"
  if [ "$2" = "present" ]; then
    echo "$err" | grep -qF "terminal historical entity"
  else
    ! echo "$err" | grep -qF "terminal historical entity"
  fi
}

if _dc18_check_terminal_skip $'---\nstatus: shape\ncompleted:\n---\n\n## H' "absent"; then
  echo "OK DC-18a empty completed: on active entity is NOT terminal"
else
  echo "FAIL DC-18a empty completed: on active entity is NOT terminal"; FAIL=1
fi

if _dc18_check_terminal_skip $'---\nstatus: ship\n---\n\n## H' "absent"; then
  echo "OK DC-18b status: ship is NOT terminal"
else
  echo "FAIL DC-18b status: ship is NOT terminal"; FAIL=1
fi

if _dc18_check_terminal_skip $'---\nstatus: verify\nverdict: PASSED\n---\n\n## H' "absent"; then
  echo "OK DC-18c verdict: PASSED is NOT terminal"
else
  echo "FAIL DC-18c verdict: PASSED is NOT terminal"; FAIL=1
fi

if _dc18_check_terminal_skip $'---\nstatus: done\ncompleted: 2026-01-01T00:00:00Z\n---\n\n## H' "present"; then
  echo "OK DC-18d status: done IS terminal (over-correction guard)"
else
  echo "FAIL DC-18d status: done IS terminal (over-correction guard)"; FAIL=1
fi
```

</details>

| Case | Frontmatter | Assertion | Today (RED) | After Task 2 (GREEN) |
| --- | --- | --- | --- | --- |
| DC-18a empty-completed | `status: shape` + bare `completed:` | SKIP line absent | FAIL — line present (the bug) | OK |
| DC-18b status:ship | `status: ship` | SKIP line absent | FAIL — line present | OK |
| DC-18c verdict:PASSED | `status: verify` + `verdict: PASSED` | SKIP line absent | FAIL — line present | OK |
| DC-18d status:done (control) | `status: done` + `completed: <ts>` | SKIP line present | OK (already correct) | OK (must stay correct — over-correction guard) |

Live-verified this session against current `bin/check-invariants.sh` (patched to the Task-2 text,
run, reverted — `git status --short` confirmed clean afterward): all three RED rows currently print
the SKIP line (bug reproduced); the control already prints it; after the one-line patch, the three
RED rows lose the line and the control keeps it. Table's RED/GREEN columns are measured, not assumed.

**RED-before-GREEN contract:** commit this task's fixture BEFORE Task 2's predicate edit, and run it
immediately to capture the RED evidence in the commit's own CI/local run:

```
bash plugins/ship-flow/lib/__tests__/test-check-invariants.sh 2>&1 | grep -E "^(OK|FAIL) DC-18"
```
Expect `FAIL DC-18a`, `FAIL DC-18b`, `FAIL DC-18c`, `OK DC-18d`. Task 2 must flip all four to `OK`.

### Task 2 — predicate fix commit

**File:** `plugins/ship-flow/bin/check-invariants.sh:61` — single-line replace (already pinned in
design.md; re-confirmed live this session):

- Before: `` grep -qE '^(status:[[:space:]]*(done|ship|shipped)|completed:|shipped:|verdict:[[:space:]]*PASSED)' "$f" 2>/dev/null ``
- After: `` grep -qE '^status:[[:space:]]*done[[:space:]]*$' "$f" 2>/dev/null ``

GREEN proof (must all read `OK`):
```
bash plugins/ship-flow/lib/__tests__/test-check-invariants.sh 2>&1 | grep -E "^(OK|FAIL) DC-18"
```

Commit Task 1 (fixture, RED) and Task 2 (fix, GREEN) as two distinct commits so `git log` itself
shows the RED-before-GREEN sequence — do not squash them.

### Task 3 — AC-2 surfacing (listed, not silently fixed)

**File:** `docs/ship-flow/check-invariants-terminal-fix/execute.md` (new) — a `## AC-2 Surfaced
Findings` section.

Measure the actual before/after on today's HEAD (do not copy design.md's numbers unchecked — they
were pre-measured on a slightly earlier tree; re-derive to confirm they still hold):

```
# "after" = current committed state (post Task-2 fix)
CI=true bash plugins/ship-flow/bin/check-invariants.sh > /tmp/after.log 2>&1
echo "after exit=$?" >> /tmp/after.log

# "before" = same tree, predicate reverted to pre-fix text (uncommitted working-tree edit only)
git show HEAD~1:plugins/ship-flow/bin/check-invariants.sh > plugins/ship-flow/bin/check-invariants.sh
CI=true bash plugins/ship-flow/bin/check-invariants.sh > /tmp/before.log 2>&1
echo "before exit=$?" >> /tmp/before.log

# restore the committed (fixed) file — MUST run before anything else touches this file
git checkout -- plugins/ship-flow/bin/check-invariants.sh
git status --short plugins/ship-flow/bin/check-invariants.sh   # must print nothing

diff /tmp/before.log /tmp/after.log
```

`HEAD~1` here means "one commit before Task 2's fix commit" — i.e. the state right after Task 1's
fixture lands but before the predicate changes, which is the correct "before" baseline (test present,
old buggy predicate).

Write the section with: the exit-code flip (0 → 1), and a table `entity | check | finding |
pre-existing?` built from the diff output. Design.md's pre-measured expectation (re-verify, don't
assume): `roborev-migration-receipt-merge-semantics` → 25× orphan-header `ERROR` (missing `<!--
section: -->` tags) + 1× `FAIL C1` (missing `pre_mortem:` field); `roborev` and
`7-review-surface-shape-not-plan` → 2× `WARN` (zero critical assumptions on a pitch-pattern entity).
5 additional grandfather `WARN`s (zero-tag baseline entities) are non-blocking noise, not new findings.

**Hard constraint:** do NOT add `pre_mortem:`, section tags, or any other content to `roborev` or any
other entity — surfacing only, per captain attestation (`「原則上是都核准」`). The only source edit in
this entire ticket is check-invariants.sh:61; the only new files are the Task-1 fixture and this
execute.md section.

### Task 4 — dual-env full gate

Per stage-def plan Inputs ("CI gates: invariants, node suite, version-triple, no-dangling") — run
the full local gate, not just the new fixture, in both environments.

Env 1 (local, no CI flag):
```
for t in plugins/ship-flow/lib/__tests__/test-*.sh; do bash "$t" || echo "FAILED: $t"; done
node --test plugins/ship-flow/bin/*.test.mjs
bash scripts/check-version-triple.sh
bash scripts/check-no-dangling.sh
```

Env 2 (CI-flag, mirrors `.github/workflows/ship-flow-invariants.yml:98-121`):
```
for t in plugins/ship-flow/lib/__tests__/test-*.sh; do CI=true timeout 90 bash "$t" || echo "FAILED: $t"; done
node --test plugins/ship-flow/bin/*.test.mjs
CI=true bash plugins/ship-flow/bin/check-invariants.sh; echo "corpus exit=$?"
```

**"Green" scope — load-bearing, do not misread as a regression signal.** "Green" means: all
`test-*.sh` (including the new DC-18 block) and the node tests pass, in BOTH envs. It does NOT mean
`check-invariants.sh`'s full-corpus run against the real repo stays exit 0 — that run is EXPECTED to
flip to exit 1 in both envs, driven entirely by the Task-3 un-masked `roborev` findings. A RED corpus
run here is the correct, designed end-state (AC-2 corpus honesty), not a Task-4 failure. Verify/CI
seeing this exit-1 is expected; do not "fix" roborev to make it go away — that would violate Task 3's
surface-only constraint.

Test-impact claim (stage-def "Bad": don't touch bin/lib without naming breakable tests) — reconfirm,
don't re-derive: `grep -iE 'entity_is_terminal|terminal historical' plugins/ship-flow/lib/__tests__/*.sh`
before Task 1 lands = 0 hits outside an unrelated force-push variable name and a git-fixture commit
message in `test-merged-pr-closeout-reconciler.sh`. The 1-line edit breaks 0 of the pre-existing
shell tests; Env 1/2 above is what proves that claim rather than asserting it.

### Canonical Doc Actions

| Doc | Action | Rationale |
| --- | --- | --- |
| PRODUCT.md | skip | Line 17 already lists "check-invariants" as an existing mechanical CI gate row; this fixes an internal predicate bug inside that gate, not a new capability. |
| ARCHITECTURE.md | skip | No new component or contract; the `bin/ checkers` container/component entries (lines 41, 86) are unchanged in shape — only the terminal-classification predicate inside one existing checker changes. |
| ROADMAP.md | skip | Not tracked there today (`grep -iE 'terminal|check-invariants|#76|#71' ROADMAP.md` = 0 hits); S-size, same-worktree shape→ship bugfix, not roadmap-worthy. |

Root canonical docs only (per this stage's scope): PRODUCT.md, ARCHITECTURE.md, ROADMAP.md.
`plugins/ship-flow/INVARIANTS.md` is a plugin-level doc, not root canonical — out of this section's
scope, and unaffected regardless: Principle 5a's documented rule ("terminal entities are skipped")
is unchanged; only the terminal *test* (predicate) changes.

### Self-review (stage-def: size-adaptive, max 3 iterations)

Iteration 1: cross-checked design.md's 4-case table and 5-site diff table are both fully carried into
Tasks 1/3; re-ran all 4 fixture cases live against current HEAD (not trusted from design.md) — RED/
GREEN columns above are measured this session, not copied; checked AC-3's "suite green" wording
against design's own RED reconciliation and made the distinction explicit and unmissable in Task 4;
checked decisions.md — verdict-branch drop already CONFIRMED at the design gate, no open design
questions remain (design.md: `open_design_questions_remaining: 1`, resolved at design gate 2026-07-19
T17:40Z). No 2nd/3rd iteration needed — plan matches the fully-pinned, gate-approved design 1:1.

### Plan Report

- Mode: 4 serial TDD tasks, no research needed (design.md fully pinned + gate-approved).
- Task 1: RED fixture, `DC-18` block in `test-check-invariants.sh`, 4 cases — live-verified RED/GREEN
  behavior this session.
- Task 2: one-line predicate fix at `check-invariants.sh:61` — live-verified flips all 4 fixture
  cases correctly, file restored clean after the sanity patch (`git status --short` empty).
- Task 3: `## AC-2 Surfaced Findings` in new `execute.md`, before/after diff via `HEAD~1` revert
  (not `design.md`'s numbers copied unchecked) — surface only, no entity bodies touched.
- Task 4: dual-env full gate (Env 1 local, Env 2 `CI=true`), plus the explicit "green means the test
  suite, not the corpus run" scope note to prevent a false-regression read at verify/CI.
- Canonical Doc Actions: skip all 3 root docs (rationale table above).
- status: passed
- verdict: PROCEED to execute
