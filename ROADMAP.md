# ROADMAP — ship-flow

> Skeleton bootstrapped at shape-confirm of the self-adoption dogfood pitch
> (2026-07-11). Row hygiene and section completion by child
> `canonical-docs-bootstrap`.

## Now (committed, actively working)

<!-- section:now -->
| Entity | Title | Stage |
| --- | --- | --- |
| ship-stage-debrief-closeout | Make debrief a native post-merge ship closeout | shape |
<!-- /section:now -->

## Next (shaped, ready to start when Now clears)

<!-- section:next -->
| Entity | Title | Kind | Appetite |
| --- | --- | --- | --- |
<!-- /section:next -->

## Later (ideas with potential, not yet shaped)

<!-- section:later -->
| Idea | Size | Claim | Source |
| --- | --- | --- | --- |
| shape-confirm-instance-awareness | S | shape-confirm.sh and allocate-id.sh ignore the workflow README id-style declaration, write legacy status sharp (3 sites), and never absorb an existing flat entity — confirm path should be instance-aware | pitch 1 |
| plugin-readme-model-era-refactor | S | Plugin README still model-era-anchored (4.7 voice) + stale | (todo) |
<!-- /section:later -->

## Not Doing (explicitly rejected with reason)

<!-- section:not-doing -->
| Rejected | Reason |
| --- | --- |
| Add root CONTRACT.md as a fourth canonical doc | Contract role is already filled by plugins/ship-flow/INVARIANTS.md + references/*.yaml schemas, pinned by 110+ shell tests; a prose duplicate would drift |
| LLM semantic doc-verification as a required CI check | carlove R3 scar (2026-06-09): self-attested LLM signals are non-rerunnable and quota-bound; LLM judgment belongs in pipeline route-back or advisory surfaces |
| Pre-push hook as the enforcement point | One-flag bypass (--no-verify), offline/quota DX hazards; CI is the authority and worker self-check covers early warning (pre-dispatch mod pattern) |
| Extend shape-confirm.sh to honor id-style slug inside this pitch | Scope cut: numeric-prefixed slug at confirm is zero-code and carlove-congruent; the tooling fix is filed as the shape-confirm-instance-awareness todo instead |
| Patch or retain the repository-scanning discovery helper | The captain rejected the helper strategy after repeated suppressible producer failures. |
| Redesign density classification or upstream spacedock status --discover (#24) | Separate existing issues outside this 2-3 day appetite. |
| Automatically migrate existing adopters or introduce multiple routing manifests | The selected contract keeps legacy configs readable and adds one canonical manual source. |
| Refresh README literals to the current release numbers | New hardcoded values would become stale again and preserve the same failure mode. |
| Record README coupling without a negative grep | A coupling row documents ownership but does not mechanically reject version-shaped drift. |
| Full-replacement deterministic manual adopter routing (pitch 2 → child 2.1) | Parked 2026-07-16. The original driver #20 (discovery scanning test fixtures) is already fixed and closed, so the acute problem is gone. The ambitious tree-scan→manual-manifest replacement never converged (391 commits, 21 Plan EM re-review/repair cycles, shape cycle 25, `max_dispatches` 32→44) while far exceeding its 2-3 day appetite. Revive only via a fresh minimal shape (e.g. just remove the discovery helper's production reachability + stale docs), not this over-shaped line. Sharp entities `2-deterministic-manual-adopter-routing` / `2.1-manual-fail-closed-adopter-routing` stay dormant (not dispatchable); worktree evidence preserved under `.claude/worktrees/issue20-routing-*`. |
<!-- /section:not-doing -->

## Shipped

<!-- section:shipped -->
| Entity | Title | Shipped |
| --- | --- | --- |
| 1-self-adoption-dogfood-bootstrap | Self-adoption dogfood bootstrap — canonical docs + doc-impact gate | 2026-07-12 (PR #14) |
| fixture-pollution-discovery-helpers | Fixture-tree exclusion for discovery helpers | 2026-07-15 (landed via PR #39; runtime-reconciled) |
| 3-root-readme-stale-claims | Refresh root README stale compatibility claims | 2026-07-15 (PR #40) |
| c14-fo-dispatch-contract | Align C14 with First Officer stage-entry transitions | 2026-07-16 (PR #47) |
<!-- /section:shipped -->
