# Missing canonical mods — author or de-reference (both tiers) — Ship

Fixes #77: `architecture-canon.md` de-referenced (3 bibliographic sites, no
consumer, no test pin) and `canonical-doc-sync.md` authored at the adopter
tier (reverse-recovery EXISTS_BROKEN — recovered token-for-token from the
two integration tests' own assertions). `scripts/check-no-dangling.sh`
gained a `missing-everywhere-canonical-mod` classify-by-twin branch so this
reference class is now mechanically regress-guarded.

PR: https://github.com/iamcxa/spacedock-workflows/pull/79 — body composed
once to a file from shape/verify/execute canonical artifacts, privacy grep
0 hits, pushed, `gh pr view 79` confirmed `MERGEABLE` before `pr: "#79"`
was written to frontmatter via `persist-pr-metadata.sh` (`verdict=OK
reason=written`). Auto-merge lane armed: `gh pr merge 79 --auto --merge`
succeeded, `autoMergeRequest.mergeMethod=MERGE` confirmed; required checks
(`invariants`, `doc_impact`) will execute the merge — not awaited here.

## Todo Closeout Digest

- (follow-up) 9 other `lib/__tests__/integration/*.sh` files share the same
  `REPO_ROOT` off-by-one T2 fixed only in the 2 files this entity's AC-3
  names (verify.md Deferred to TODO #1).
- (follow-up) `docs/ship-flow/README.md` wording gap ("Canonical context
  control-plane" / "ARCHITECTURE.md Update" phrasing absent) causing the 2
  residual `test-canonical-context-lifecycle.sh` failures — unrelated to
  this entity's 3 ACs (verify.md Deferred to TODO #2).
- ROADMAP row cleanup (no existing Now/Next/Later row to move — Shipped row
  add) deferred to FO closeout on the canonical root, not patched in this
  worktree/PR.

## Canonical Docs Update

- PRODUCT.md: skip — extends an already-documented "Mechanical CI gates"
  capability row, no new user-facing capability (plan.md Canonical Doc
  Actions).
- ARCHITECTURE.md: skip — no new component/contract; one additive resolver
  branch, one new mod file, four prose deletions, two test precondition
  fixes.
- ROADMAP.md: no existing row to move; Shipped row add deferred to FO
  closeout on canonical root per this stage's explicit scope.

### Token + Release

Token: not tracked (no `size`/`token_budget` stamped on this entity; no
fabricated figures). Version: no plugin version bump this ship — repo
convention batches bumps into separate `chore(ship-flow): release X.Y.Z`
commits; this S-mechanical fix + additive guard does not warrant one alone.

### Verdict

status: auto-merge-armed
pr: "#79"
tasks: 5/5 (T1-T5, plan.md)
verify: PASS (PROCEED) — verify.md, independent re-run
dependency: none — standalone entity, hackathon-2 Wave 2c (issue #77),
FO-driven (not tick-dispatched)
