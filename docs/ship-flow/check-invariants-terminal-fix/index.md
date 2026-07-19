---
title: check-invariants terminal misclassification fix
status: verify
source: hackathon-2 Wave 2b (todo check-invariants-terminal-misclassification; #71 verify finding)
started: 2026-07-19T16:04:46Z
completed:
verdict:
score:
worktree: .worktrees/spacedock-ensign-check-invariants-terminal-fix
issue: "#76"
pr:
---

Time budget: 1h15m. check-invariants.sh's _entity_is_terminal() misclassifies any entity with an
empty completed: field as terminal, repo-wide. Fix the predicate to require a terminal status
value, not an empty-field accident.

## Acceptance criteria

**AC-1 — Correct predicate.** _entity_is_terminal() returns true ONLY for genuinely terminal
entities (status done/terminal per workflow taxonomy); empty completed: on an active entity no
longer classifies as terminal.
Verified by: RED fixture (active entity, empty completed:) then green.

**AC-2 — Corpus honest.** Any checks previously skipped due to misclassification now run;
resulting findings surfaced (not silently fixed) if any appear.
Verified by: check-invariants full run diff before/after documented.

**AC-3 — Suite green both envs.**
Verified by: dual-env run output.

## Shape

Size: S. Time budget: 1h15m (per body). Captain articulation already given (hackathon-2 GO +
bulk attestation 「原則上是都核准」2026-07-20) — not re-asked. Verified against the REAL current
origin/main: branch `iamcxa/muscat-v1` trails origin/main by 233 commits, but `_entity_is_terminal`
is byte-identical on both (plugins/ship-flow/bin/check-invariants.sh:59-62) — the bug is present on
current main verbatim.

### AC verification (all three REAL — none already-satisfied)

**AC-1 — REAL, proven empirically.** check-invariants.sh:61 alternation's `completed:` / `shipped:`
branches match a bare (empty-valued) frontmatter KEY, not a value. Proof: this active entity
(status: shape) classifies terminal solely because its empty `completed:` line (index.md:6) matches
the `completed:` branch — running the exact predicate regex on it returns TRUE (terminal).
Refinement inside AC-1's own "status done/terminal per taxonomy" wording: README.md:54-55 marks
only `done` as `terminal: true`; `ship` (README.md:50-52 = review stage, active) and the undefined
`shipped` are NOT terminal, so a faithful fix also drops them from the status branch (latent today —
no active `status: ship` entity exists, but one would be misflagged). RED fixture is feasible: the
harness supports `--test-fixture <dir>` (test-check-invariants.sh:13,66,129) and there is currently
ZERO test coverage of the terminal predicate (no `terminal`/`completed:` hits in the test file) — the
fixture fills a real gap.

**AC-2 — REAL, sized.** Five checks gate on `_entity_is_terminal` and thus skip misflagged entities:
check_section_tag_coverage (:195), check_structural_parity_dc (:607), check_pitch_assumptions (:662,
WARN-only), check_pre_mortem_emitted (:823), check_pol_probe_invoked (:842). Blast radius: 6 of 9
active entities are misflagged terminal today (this entity; missing-canonical-mods;
no-dangling-guard-qualifier-precision; tick-hardening [design]; roborev-migration-receipt-merge-semantics
[execute]; shape-confirm-instance-awareness). After the fix these checks run on the 6 → likely surfaces
genuine pre-existing violations that were masked. Captain bulk attestation covers surfacing; AC-2's
"surfaced, not silently fixed" discipline holds.

**AC-3 — REAL, two envs evidenced.** Env 1: local runner `bash test-check-invariants.sh` (--test-fixture).
Env 2: CI `CI=true bash plugins/ship-flow/bin/check-invariants.sh` (.github/workflows/ship-flow-invariants.yml:98).
`CI=true` can flip shell boolean/pipefail behavior, so both are required.

### Out of scope
- Anything beyond AC-1/2/3; the upstream spacedock binary; third-party deps.
- Silently fixing the AC-2-surfaced findings (surface only, per captain attestation).
- Branch-staleness remediation (233-behind) — flagged for FO/execute setup, not part of the predicate fix.

### Risk / FO flag
- The fix may turn CI RED with real masked violations — expected (AC-2 corpus honesty), not a regression.
- Because the working branch trails origin/main by 233 commits (suite composition differs — e.g.
  check_review_surface_shape_not_plan exists on main, absent here), a meaningful "suite green" baseline
  (AC-3) needs execute to build on a tree near origin/main, else green-here / red-on-main mismatch.

## Stage Report: shape

- DONE: absorb + verify each AC claim against the REAL current origin/main files (cite file:line)
  All 3 ACs REAL; predicate byte-identical on main (check-invariants.sh:59-62); empirical predicate run confirms AC-1.
- DONE: captain articulation absorbed (hackathon-2 GO + bulk attestation), not re-asked
  「原則上是都核准」2026-07-20 recorded in ## Shape; no re-ask.
- DONE: record the entity's time_budget from the body
  1h15m (body line 14), noted in ## Shape.
- DONE: out-of-scope recorded
  Beyond AC-1/2/3, upstream spacedock binary, third-party deps, silent AC-2 fixes, branch-staleness remediation.
- DONE: disproof check (say so if any AC already-satisfied or wrong)
  None already-satisfied. AC-1 gains a taxonomy refinement: fix must also drop `ship`/`shipped` (only `done` is terminal:true per README.md:54-55).

### Summary
The bug is real and proven by running the exact `_entity_is_terminal` regex against the active
status:shape entity — its empty `completed:` field (index.md:6) makes it classify terminal.
Blast radius: 6 of 9 active entities misflagged, skipped by 5 predicate-gated checks; the fix will
un-mask genuine pre-existing findings (AC-2 by design). Two FO flags: (1) AC-1's own "terminal per
taxonomy" wording implies dropping `ship`/`shipped`, not only fixing the empty-`completed:` accident;
(2) the working branch is 233 commits behind origin/main, so AC-3's "suite green" baseline needs
execute to work on a tree near main.

## Stage Report: design

- DONE: evaluate the trivial-pass fast-path honestly; if contract-bearing, write the minimal design.md
  Contract-bearing (corpus-semantics shift: 6 entities flip terminal→active, CI exit 0→1) → full design.md written at docs/ship-flow/check-invariants-terminal-fix/design.md.
- DONE: name the exact new predicate (only status done; drop empty-completed AND ship/shipped)
  `^status:[[:space:]]*done[[:space:]]*$` (check-invariants.sh:61). Design refinement flagged: also drop `verdict: PASSED` branch (taxonomically forced, zero-hit today) — surfaced for gate veto.
- DONE: name the 5 gated check sites (:195,:607,:662,:823,:842) and expected corpus-honesty diff
  Empirically measured (old vs fixed run, source reverted): 6 flip; roborev drives RED (25 orphan-header ERRORs + 1 C1 FAIL); 5 grandfather WARNs + 2 pitch WARNs non-blocking; :607/:842 add nothing.
- DONE: RED fixture spec (--test-fixture harness, zero current coverage)
  `--check section-tag-coverage` on `--test-fixture`, assert terminal-SKIP presence; 4 cases (empty-completed/ship/verdict:PASSED RED + done-entity GREEN control); 0 prior coverage confirmed (grep _entity_is_terminal over __tests__ = 0 hits).
- DONE: AC-2 surfacing format (findings listed in execute.md, NOT silently fixed)
  `## AC-2 Surfaced Findings` section in execute.md (before/after diff + entity|check|finding table); no entity bodies touched.
- DONE: Work in seeded worktree off origin/main (branch spacedock-ensign/check-invariants-terminal-fix)
  Verified worktree corpus == origin/main baseline (6-flip count matches shape's "6 of 9"); all reads/writes/commit under the worktree.
- DONE: Time budget — design lean
  Single design.md + decisions/stage-report; no code changes (design owes a spec, not the edit).

### Summary
Contract-bearing (not trivial-pass): the 1-line predicate fix shifts corpus semantics — 6 active
entities flip terminal→active and the suite flips green→RED on one real masked entity (roborev). The
before/after diff was measured empirically (patch, run, revert; source uncommitted). Two decisions
carried to the gate: (1) the predicate reduces to `status: done` only, which forces dropping the
`verdict: PASSED` branch beyond shape's literal enumeration — taxonomically required, empirically
zero-hit today, flagged for veto; (2) execute must surface the un-masked roborev findings in
execute.md, not silently fix them (captain attestation covers surfacing).

## Stage Report: plan

- DONE: write plan.md with TDD contracts per code-bearing task (RED-before-GREEN), explicit test files
  docs/ship-flow/check-invariants-terminal-fix/plan.md — Task 1 (DC-18 fixture, 4 cases) → Task 2 (predicate fix) → Task 3 (AC-2 surfacing) → Task 4 (dual-env full gate), exact commands per task.
- DONE: live-verify the 4-case fixture table against current HEAD before committing it to the plan
  Patched check-invariants.sh:61 to the design's exact new text, ran all 4 fixture cases, reverted; `git status --short` confirmed clean. RED/GREEN columns in plan.md Task 1 are measured, not copied from design.md.
- DONE: Canonical Doc Actions section (update/skip + rationale per root canonical doc)
  PRODUCT.md/ARCHITECTURE.md/ROADMAP.md all skip — rationale table in plan.md (existing capability row covers this; no roadmap/architecture item exists for it).
- DONE: name existing tests that could break (stage-def "Bad")
  `grep -iE 'entity_is_terminal|terminal historical' plugins/ship-flow/lib/__tests__/*.sh` = 0 hits outside two unrelated strings (force-push var name, git-fixture commit message) — 0 of ~120 tests pin the changed text.
- DONE: self-review loop (max 3 iterations)
  1 iteration sufficed — design.md fully pinned and gate-approved (verdict-branch drop CONFIRMED), no open design questions remained; plan cross-checked against design's tables and re-verified live rather than re-derived.

### Summary
Plan is 4 serial TDD tasks built directly on the gate-approved design, with zero remaining ambiguity:
RED fixture (DC-18, 4 cases) → one-line predicate fix (GREEN) → AC-2 surfacing in a new execute.md
(roborev findings listed, not fixed) → dual-env full gate. The fixture's RED/GREEN behavior was
live-verified this session (patch/run/revert cycle, working tree confirmed clean afterward) rather
than trusted from design.md. Task 4 carries an explicit scope note that "suite green" means the test
suite, not the real-corpus `check-invariants.sh` run, which is expected to flip RED — this is called
out to prevent execute/verify from misreading the designed AC-2 outcome as a regression.

## Stage Report: execute

- DONE: Execute the 4-task plan exactly: RED fixture committed with observed red BEFORE the predicate fix; the one-line fix; AC-2 surfacing (## AC-2 Surfaced Findings in execute.md — roborov findings LISTED with entity|check|finding table, NOT fixed); dual-env gate with the plan's scope note (real-corpus check-invariants RED is the designed AC-2 outcome, cite it as such)
  Task 1 commit 3ddd2c2 (DC-18a/b/c observed FAIL pre-fix, DC-18d OK); Task 2 commit 5f5ae69 (all 4 OK); Task 3 commit b4e0863 (execute.md table, roborev findings listed, zero entity bodies touched); Task 4 results in execute.md with the scope note cited.
- DONE: Full local gate before handoff; git diff --check clean; atomic commits with explicit pathspec
  Env 1: shell 128/129 + node 79/79 + version-triple 0 + no-dangling 0. Env 2 (CI=true): shell 127/129 + node 79/79 + corpus exit 1 (designed AC-2 RED: C1 roborev + pre-existing C15). Both suite exceptions diagnosed in execute.md (archived-corpus = corpus-RED propagation, pre-existing at pre-fix probe; reconciler = 90s CI-timeout machine-speed artifact, solo 198/198). git diff --check rc=0; all commits path-scoped.
- DONE: Budget: ~25m remaining of the entity's 1h15m — if the gate run exposes anything beyond the roborov surfacing, park it in the report (bad-news-early), do not expand scope
  Parked, not fixed: (1) C15 plan.md 220>200 lines (pre-existing, forces before-exit=1 so corpus measured 1→1 not the designed 0→1); (2) archived-corpus suite test asserts corpus exit 0 and is now RED by design. Budget overrun (gate re-runs after two background-runner failures) reported honestly; scope held to the one-line fix + fixture + surfacing.

### Summary

All 4 plan tasks executed in order with RED-before-GREEN in git history (fixture commit precedes fix
commit). AC-2 findings surfaced in execute.md exactly per design — roborev drives the corpus RED (25
orphan-header ERRORs + C1 pre-mortem FAIL), nothing silently fixed. Two deviations flagged
bad-news-early: corpus exit measured 1→1 (not 0→1) because this entity's own plan.md already trips
C15; and the archived-corpus suite test embeds that corpus run, so it is RED by design — verify
should read both as the documented AC-2 end-state, not regressions.
