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
