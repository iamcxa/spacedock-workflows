---
title: Design-taste learning loop — captain UAT verdicts to ratified per-repo canon
status: shape
source: hackathon-2 Wave 3 (todo design-taste-learning-loop; captain distill-not-depend constraint)
started: 2026-07-19T17:31:46Z
completed:
verdict:
score:
worktree:
issue: "#78"
pr:
---

Time budget: 1h30m for shape + design tonight; execute is an EXPLICIT cut candidate (defers to
next session at the 100% brake). Make captain 審美/UX 判斷 accumulate instead of evaporate:
structured UAT-verdict capture riding feedback-cycle records → periodic harvest clustering into
CANDIDATE canon rules → captain batch-ratification (model proposes, never self-mutates canon) →
per-repo design-canon.md consulted by ship-design pre-generation → mechanizable rules graduate to
ui-verify code gates. Challenge clause against taste ossification. Metric: UAT reject rate per
shipped UI entity trends down.

HARD CONSTRAINT (captain): cold-start rubrics are DISTILLED into ship-flow-owned assets — study
third-party design-review methodologies as references, then author our own rubric files in-repo.
NO runtime dependency, invocation, or wrapping of third-party plugins.

## Acceptance criteria

**AC-1 — Capture contract.** A structured captain-UAT-verdict record format (accept/reject +
one-line reason + artifact ref) defined riding the existing feedback-cycle record family, written
at verify-stage UAT and PR-preview review points.
Verified by: schema/fixture + a worked example record.

**AC-2 — Harvest + ratify loop.** A harvest procedure clusters recurring reject reasons into
candidate canon rules presented for captain batch accept/defer/reject; ratified rules land in a
per-repo design-canon.md; the model NEVER mutates canon without ratification (invariant-pinned).
Verified by: procedure doc + a dry-run harvest on synthetic records + the invariant check.

**AC-3 — Consumption seams.** ship-design consults design-canon.md pre-generation when present
(with the challenge-clause escape); a documented graduation path for mechanizable rules into
ui-verify checks.
Verified by: SKILL seam text + one worked mechanizable example.

**AC-4 — Distilled cold-start rubrics.** Ship-flow-owned rubric asset(s) authored in-repo
(references studied, zero third-party runtime dependency — greppable proof of no external
invocation).
Verified by: rubric files exist + grep proves no third-party plugin references in runtime paths.

## Stage Report: shape

- DONE: Shape the LOOP as a contract, not an implementation dream: the four ACs are the value spine — verify each against what actually exists today and cite file:line for every claimed seam; classify each seam WORKING/EXISTS_BROKEN/MISSING per reverse-recovery.
  `shape.md` reverse-recovery layer-trace table: AC-1 MISSING (rides EXISTS_BROKEN `### Feedback Cycles`, `INVARIANTS.md:571` + `check-invariants.sh:1546-1601,1578`; verify UAT `ship-verify/SKILL.md:704`), AC-2 STUB (harvest→ratify→ledger LIVE `harvest-decide/SKILL.md:68-71,75-88` + `INVARIANTS.md:607-621,615`, no `design-canon.md`), AC-3a/b MISSING w/ reusable blocks (`ship-design/SKILL.md:26-31,764,770`; `ui-verify/SKILL.md:43-67`; `generate-ui-verify-spec.sh`), AC-4 MISSING but distill precedent LIVE (`lib/design-methodology/INDEX.md:3,11` + `shotgun.md:2-3`). Every AC = known pattern + new payload → no greenfield.
- DONE: The captain's distill-not-depend HARD CONSTRAINT is non-negotiable — shape must define what "distilled rubric asset" means concretely and the greppable no-dependency proof.
  `shape.md` §Distill-not-depend: "distilled rubric asset" = in-repo file authored by studying methodologies with a `Source:` provenance line (the shipped `lib/design-methodology/*.md` discipline); zero runtime tokens. Proof `grep -rniE "Skill: design-(review|shotgun|consultation|html)|npx +design-|gstack-|\$D\b"` over loop-introduced files returns empty — baseline validated clean over `rubrics/` today. Scoping note: pre-existing `ship-design:661` `design-review` dispatch is out of scope.
- DONE: Appetite honesty: 1h30m covers shape + design ONLY tonight; shape must slice the ACs so execute is separable (a next-session S/M entity or two), and record the cut-line explicitly. Captain articulation already given — do NOT re-ask.
  `shape.md` §Execute slicing: Slice-1 (S) = AC-1 + AC-4 (author-an-asset, no wiring); Slice-2 (M) = AC-2 + AC-3 (integration, depends on Slice-1 schema). Cut-line recorded: shape+design tonight → Slice-1 → Slice-2. Captain articulation (hackathon-2 Wave 3 GO +「原則上是都核准」+ distill directive) recorded in §Captain Articulation, NOT re-asked.

### Summary

Shaped as a brownfield recovery, not greenfield: the reverse-recovery audit classifies all four ACs (AC-1 MISSING-on-broken-host, AC-2 STUB, AC-3a/b MISSING, AC-4 MISSING) and shows every one is a shipped ship-flow pattern pointed at a new payload — the harvest→ratify→ledger→never-self-mutate loop, the awk-enforced record family, the pre-gen consult slot, the target→ui-verify generator, and the `lib/design-methodology/` distill-with-provenance discipline all already exist. The captain's distill-not-depend constraint is pinned to a concrete definition (in-repo asset + `Source:` line + zero runtime tokens) with a scoped greppable proof. Execute is honestly cut to two separable next-session entities (S: capture+rubric; M: harvest+consume), with typed DCs, ROADMAP Later→Now intent, and canonical-doc impact handed to design.
