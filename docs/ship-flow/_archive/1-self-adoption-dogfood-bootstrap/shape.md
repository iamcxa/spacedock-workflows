# Self-adoption dogfood bootstrap — canonical docs + doc-impact gate — Shape

## Problem

The ship-flow plugin repo does not obey its own methodology: no root ARCHITECTURE/PRODUCT/ROADMAP (check-invariants Principle 5b WARN-skips), plugin development bypasses the pipeline, and prose currency relies on manual audits (PR #6 caught stale version claims; root README still claims 0.7.0/spacedock 0.22.0 today). Adopters are gated by machinery the plugin repo itself skips.

## Acceptance Outcome

A plugin-touching PR that ignores coupled docs gets a red CI check naming the missing doc or declaration; check-invariants runs with zero Principle-5b skip lines; and this entity's own review.md shows the canonical-doc sync loop wrote real doc updates — the repo visibly enforces its own methodology on the very entity that shipped the enforcement.

<!-- section:pm-skill-receipts -->
```yaml
pm_skill_receipts:
  stage: ship-shape
  mode: mode-a
  appetite: small-batch
  compose_guard: passed
  receipts:
    - phase: intake-problem
      delegate: problem-framing-canvas
      required: true
      status: unavailable
      evidence: ""
      fallback: 'inline canvas: gap (repo skips own canonical-doc machinery), who feels it (adopters gated by rules the plugin repo self-exempts; captain doing manual audits), why now (5b WARN-skip live, root README stale claims found 2026-07-11, dogfood workflow just commissioned)'
      rationale: skill not installed in this environment (absent from session skill registry)
    - phase: scope-decompose
      delegate: opportunity-solution-tree
      required: true
      status: unavailable
      evidence: ""
      fallback: 'inline OST: outcome (repo obeys own methodology) -> opportunities (docs missing / gate missing / loop unproven / vocabulary unpinned) -> solutions = children 1.1/1.2/1.3 + pitch-level AC-3'
      rationale: skill not installed in this environment
    - phase: assumption-extract
      delegate: pol-probe-advisor
      required: true
      status: unavailable
      evidence: ""
      fallback: 'inline POL probe: single collapse-point assumption = A1 (native confirm/verify tooling operates in this repo); probed via fresh-context L0 scout reading shape-confirm.sh/allocate-id.sh/canonical-doc-sync-checker.sh with file:line evidence; two preconditions extracted and sequenced into confirm ceremony'
      rationale: skill not installed; POL probe executed inline as fallback (small-batch, so skip would also have been schema-legal, but probe ran)
    - phase: acceptance-outcome
      delegate: press-release
      required: true
      status: unavailable
      evidence: ""
      fallback: 'inline press-release framing: outcome written as captain-observable behaviors (red CI check with actionable message, zero 5b skip lines, review.md citing real sync commits) rather than artifact list'
      rationale: skill not installed in this environment
```
<!-- /section:pm-skill-receipts -->

## Appetite

small-batch

## Children

- 1.1-canonical-docs-bootstrap
- 1.2-doc-impact-gate
- 1.3-harvest-vocabulary-record

## Assumptions

(fill in at shape stage)

## Rabbit Holes

- fixture-pollution-discovery-helpers
- shape-confirm-instance-awareness
- root-readme-stale-claims

## Deletes

(fill in from deleted_from_shape)
