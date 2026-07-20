---
title: check-invariants terminal misclassification fix
status: done
source: hackathon-2 Wave 2b (todo check-invariants-terminal-misclassification; #71 verify finding)
started: 2026-07-19T16:04:46Z
completed: 2026-07-20T06:44:06Z
verdict: passed
score:
worktree: .worktrees/spacedock-ensign-check-invariants-terminal-fix
issue: "#76"
pr: pr-merge:80
archived: 2026-07-20T06:44:06Z
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
