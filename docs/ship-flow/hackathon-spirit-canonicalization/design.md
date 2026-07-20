# hackathon-spirit-canonicalization — Design

## Verdict

PROCEED — trivial-pass (Phase 0 fast-path, per README `### design`).

Pure prose additions to existing canonical docs. No contract grammar, no
schema, no CLI surface, no SKILL section change. A1 (INVARIANTS is the right
FO-contract surface) is confirmed below; scope unchanged.

## Target Files

- `plugins/ship-flow/INVARIANTS.md` — add the time-box discipline (AC-1) as
  process-contract prose. Placement is a plan decision within this file:
  either a new `### Principle` under `## Principles` (line 26+, current top
  principle is 17) or a subsection under `## FO Discipline` (line 357). The
  latter reads most naturally — time-box brake is an FO/runner discipline,
  not a skill-architecture cut — but either satisfies AC-1. This is a
  placement choice, NOT a contract-grammar change.
- `docs/ship-flow/README.md` — add the `time_budget` slot to the entity
  frontmatter (AC-2). Two coordinated edits: the **Feature Template** block
  (line 249) gains a `time_budget:` line, and the **Field Reference** table
  (line 94) gains a matching row with a one-line semantics pointer.

AC-3 (distill learnings into existing canon, no orphan file) is satisfied
structurally by AC-1/AC-2 landing in these existing files. The debrief
citations ("2 time-box brakes", finale parked not compressed) belong inline
in the INVARIANTS prose as the precedent record — no new standalone doc.

## Contract Delta

None — docs-only additions to existing sections. No SKILL contract changes,
no schema changes (`references/*.yaml` untouched), no helper CLI surface
changes.

## Test Surface

**Load-bearing finding — `time_budget` is already a live field, not new.**
`plugins/ship-flow/lib/scheduler-runner-adapter.sh` (`derive_timeout_sec`)
already reads a frontmatter `time_budget` to set an entity's own dispatch
timeout, and `lib/__tests__/test-scheduler-runner-adapter.sh` pins the
format and derivation:
- `time_budget: 2h30m` → `timeout_sec:9000` (derive-from-budget case)
- no `time_budget` → `5400s` default
- leading-zero / zero-total edge cases (`08m`, `0m`, `2h09m`)

Consequence for this ticket: the AC-2 template slot MUST use the
scheduler's parseable `<N>h<N>m` string format (e.g. `time_budget: 2h30m`),
so a born-with-budget entity's value is actually honored by the runner, not
just documentary. Plan should state this format constraint explicitly.

Tests that pin the *prose being added*: **none.** No shell test asserts the
INVARIANTS.md time-box text or the `docs/ship-flow/README.md` template/field
prose. `check-invariants.sh` enforces the numbered-Principle DCs, the ≤7
stage-skill cap, and section-tagging on *active entities* — none of which
constrain new INVARIANTS prose or the docs-README template.

Doc-coupling: `references/doc-coupling-map.yaml` couples `references/*.yaml`
and `skills/ship-*/SKILL.md` → the *plugin* README, and bin checkers →
doc-sync-context. Neither target here (`INVARIANTS.md`, the *docs* README)
is a coupling `srcGlob`, so `doc-impact-gate.sh` will not fire on these
edits. No coupling row must move with this change.

## Architecture Impact

None — docs additions only. The runtime mechanism (`time_budget` →
timeout derivation) already exists; this ticket documents the discipline and
seeds the field into the template. The 75%-warning / 100%-brake enforcement
seam is explicitly out of scope (rabbit hole `time-budget-code-gate`), so no
code path changes.

## Design Hand-off to Plan

1. Edit `plugins/ship-flow/INVARIANTS.md`: add time-box discipline prose —
   every entity carries a `time_budget`; at 75% consumed the runner warns
   in-channel; at 100% the brake fires = park + surface + cut scope;
   verification is NEVER compressed to fit a budget. Include the two-night
   debrief precedent citations inline (AC-3). Pick placement (FO Discipline
   subsection recommended). If a new `### Principle N` is chosen, follow the
   existing numbered heading convention.
2. Edit `docs/ship-flow/README.md`: add `time_budget:` to the Feature
   Template frontmatter block using the scheduler-parseable `<N>h<N>m`
   format, and a matching Field Reference table row with a one-line
   semantics pointer (75% warn / 100% brake / never-compress).
3. No test updates and no new test vectors needed — no test pins the added
   prose, and the pre-existing `time_budget` scheduler tests already cover
   the field's runtime contract. Plan's Canonical Doc Actions section should
   record: INVARIANTS + docs-README are the touched canon (skip plugin
   README / doc-sync — not coupled).
4. AC-verification greps (from shape) run at verify:
   `grep -n "time_budget\|75%\|brake" plugins/ship-flow/INVARIANTS.md` and
   the docs-README template/field diff.
