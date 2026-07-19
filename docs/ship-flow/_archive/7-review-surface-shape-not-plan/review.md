# Ship-flow core: the human review surface is the shape/spec, not plan.md — Review

## Review Report

- verdict: **READY TO SHIP** (pending captain approval to push + open PR).
- PR body: `.context/pr-60-body.md` (doc-impact gate pre-validated, all 3 couplings accepted).

### CI pre-validation (local, mirrors both workflows) — all green
- `check-invariants.sh` full suite (CI=true): exit 0.
- Full `test-*.sh` suite (112 files): 0 failures; `node --test bin/*.test.mjs`: exit 0.
- `shellcheck` (DC-5), `check-version-triple.sh`, `check-no-dangling.sh`: pass.
- `doc-impact-gate.sh`: PASS — stage-skill-readme + checker-source-map (doc-impact: none) + issue-anchor-guard[doc-to-source] (scoped contribution-impact: none).

### Canonical doc-sync (done in-pipeline)
- INVARIANTS.md: Principle 17 + FO Discipline additions + Revision History v1.5.0.
- ARCHITECTURE.md: decisions row (per the repo's self-declared convention; #49 precedent).
- ROADMAP.md: entity moved Next → Now.
- docs/ship-flow/README.md + ship-shape/SKILL.md: Principle 17 cross-references.

## What Worked
- **Dogfooding the pipeline caught a real defect**: running #60 through ship-flow itself surfaced (via C14) that my `shape→plan` design-skip jumped an illegal edge — self-corrected to a `shape→design(trivial-pass)→plan` chain.
- **Cross-vendor 2nd opinion earned its keep**: codex found the AND-semantics test gap (cases A–D would survive an AND→OR regression) that Claude reviewers missed — fixed with Case E. This is exactly the W3 verify-gate posture #60 codifies, proven on #60 itself.

## What Almost Failed
- **Stale `ship-shape` SKILL guidance**: its "Design-skipped passthrough" section contradicts the current INVARIANTS Principle 11 ("design always runs; trivial-pass for mechanical work") and the workflow graph. Following it produced an illegal transition. **Filed as a follow-up finding — separate bug, out of #60 scope.**
- **Account session limit mid-execute**: the executer subagent died with zero commits; execute completed inline in FO break-glass mode. No state loss (clean tree + atomic commits).

## Deferred (filed, not fixed here)
- Stale ship-shape "design-skipped" guidance (methodology-drift bug).
- The "before Intake" doc NIT (pre-existing, noted in the 2026-07-17 debrief).
- codex-gate → mandatory cross-vendor verify-gate pilot (rabbit-hole todo captured at shape).
