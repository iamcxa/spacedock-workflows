# Ship-flow core: the human review surface is the shape/spec, not plan.md — Execute

## Execute Report

- status: complete — all 8 DCs pass, full `check-invariants.sh` suite exit 0.
- TDD: RED-before-GREEN honored (T1 test committed failing, then GREEN).

### RED evidence (T1)
`test-check-invariants-c16.sh` authored first and run against the unmodified
checker: all 4 cases fail with exit 2 ("unknown check: review-surface-shape-not-plan")
— the dispatcher had no C16 branch yet. `bash -n` clean, so RED was a genuine
missing-behavior failure, not a fixture/syntax bug. Committed RED before GREEN.

### DC results (all PASS)
- DC-1 `--check review-surface-shape-not-plan` → `OK C16 review-surface-shape-not-plan`, exit 0.
- DC-2 `test-check-invariants-c16.sh` → ALL PASS (live + both-present + neither + heading-only-reworded).
- DC-3 both pinned Principle 17 sentences present verbatim (grep -F).
- DC-4 `direction-confirm` captain-stop + plan.md-offer Violation pattern present in `### Autonomous continuation between stages`.
- DC-5 Revision History `v1.5.0` entry names Principle 17.
- DC-6 README.md + ship-shape/SKILL.md cross-reference Principle 17.
- DC-7 full `check-invariants.sh` (CI=true) exit 0 (no regression; C9 dup-Principle still green); `git diff --check` clean.
- DC-8 entity in ROADMAP `## Now` + ARCHITECTURE `## decisions`.

### Deviations from plan.md
1. **Design stage: NOT skipped — trivial-pass instead.** plan.md (and the shape
   hand-off) assumed a design SKIP. But INVARIANTS Principle 11 + `sync-workflow-sot.sh`
   ("design always runs; no skip-when") mean design ALWAYS runs; C14's transition
   graph has no `shape→plan` edge. The initial `shape→plan` receipt failed C14
   ("undeclared transition"). Corrected: the entity passes `shape→design(trivial-pass
   PROCEED)→plan→execute`; a minimal `design.md` records the trivial-pass. Root cause:
   the ship-shape SKILL's "Design-skipped passthrough" section is STALE vs Principle 11
   — filed as a follow-up finding (out of #60 scope).
2. Executer subagent hit an account session limit mid-run (zero commits); execute was
   completed inline by the FO in break-glass degraded mode, same TDD discipline + atomic commits.

### Scope
Stayed inside plan.md owned_paths + the canonical docs. No science-officer-em
re-wiring, no codex-gate promotion (verify-gate posture codified as descriptive
prose only). Deferred "before Intake" doc NIT untouched.
