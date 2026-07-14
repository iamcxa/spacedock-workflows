<!-- section:ship-report -->
## Summary

The repository README now gives version-independent compatibility and adoption guidance, defers canonical positioning to `PRODUCT.md`, and fails the release gate when version-shaped literals or README scan errors are introduced.

## Todo Closeout Digest

- Captured during this ship: none.
- Promoted: `root-readme-stale-claims` became issue #22 and this shipped entity.
- Deferred in ROADMAP Later: `shape-confirm-instance-awareness` (#21) and `plugin-readme-model-era-refactor` remain separate follow-ups.
- Rejected/not captured: refreshing README prose to current release numbers, and documenting coupling without a negative-grep guard.

### Token Summary

Budget: small-batch appetite
Actual: not recorded by the current FO runtime
Ratio: not available

### Verdict

status: passed — implementation merged; terminal ship closeout pending
stage_cost: one implementation worker, execute review, one verify remediation loop, two independent verify lenses, and merge-time CI
started_at: 2026-07-14T17:40:11Z
completed_at: 2026-07-14T18:11:04Z
summary: Root README prose is version-independent, canonical positioning points to PRODUCT, and the negative-grep gate fails closed on drift and scan errors.
tasks: issue #22 only; #21 and plugin README model-era cleanup remain separate follow-ups
verify: AC 3/3; focused fixtures 5/5; shell 104/104; Node 79/79; C1-C15, no-dangling, version-triple, and diff-check PASS
merge: landing commit `d6d3ce4195fec956f74d0ede3192d2380746f561`

<!-- /section:ship-report -->
