# ROADMAP — ship-flow

> Skeleton bootstrapped at shape-confirm of the self-adoption dogfood pitch
> (2026-07-11). Row hygiene and section completion by child
> `canonical-docs-bootstrap`.

## Now (committed, actively working)

<!-- section:now -->
| Entity | Title | Stage |
| --- | --- | --- |
| 5-issue-anchor-scope-drift-guard | Issue-anchor scope-drift guard (route-back re-anchor) | ship |
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
| issue-anchor-guard-memory-fallback | S | For free-text-origin entities with no tracker issue, best-effort auto-retrieve the originating conversation/journal (episodic-memory + context-lake) as a candidate anchor to surface to the captain — enriches the surface-to-captain exception without faking an authoritative anchor. | pitch 5 |
| issue-anchor-guard-remaining-triggers | S | Extend the guard to the other two trigger points: feedback-rejection-flow cycle-3 escalation (lives in the spacedock core plugin repo, needs a companion change there) and child/prerequisite creation (necessity proof against a named parent AC). | pitch 5 |
| issue-anchor-guard-resolver-shell-parser-robustness | S | Three named shell-parser-robustness residuals in the issue-anchor-guard resolver: emit's tombstone rm -f does not check its own exit status before fetch; validate's top-level scalar reads are a line-oriented awk scan, not structural yq (unlike the per-AC rows); the AC-block parser is not Markdown-aware (fenced code / quoted examples could be mis-parsed as ACs). | pitch 5 |
| scheduler-tick-delegation-marker | S | Tick spawn needs explicit delegation marker (env+prompt) vs hand-dispatch | (todo) |
| pipeline-timeout-checkpoint-event | S | Runner timeout must scale w/ appetite + emit resumable checkpoint | (todo) |
| nested-controller-worktree-support | S | dispatch build refuses nested controller-worktree entity paths | (todo) |
| no-dangling-guard-qualifier-precision | S | W1-W5 guard-robustness follow-ups from #71 verify | (todo) |
| check-invariants-terminal-misclassification | S | _entity_is_terminal treats empty completed: as terminal repo-wide | (todo) |
| missing-canonical-mods-both-tiers | S | architecture-canon + canonical-doc-sync mods resolve in neither tier | (todo) |
| design-taste-learning-loop | M | Captain UAT taste → ratified per-repo design canon (distilled, zero third-party dep) | (todo) |
| reconciler-review-artifact-assumption | S | Reconciler demands review.md this workflow never produces — blocks auto-closeout | (todo) |
| tick-refusal-scan-head-block | S | Refusal consumes the beat + no dedup — scan never reaches eligible entities | (todo) |
| plist-installer-placeholder-validation | S | Installer must validate zero remaining @PLACEHOLDER@ tokens | (todo) |
| check-invariants-ratchet-baseline | S | Ratchet baseline for checker-strengthening PRs (monotonic decrease, owned entries) | (todo) |
| shipflow-docs-and-adoption-report | M | Docs reorg for outsiders + metrics-backed adoption report (draft in .context) | (todo) |
| rollup-plist-spacedock-bin-leak | S | Fix live rollup.plist @SPACEDOCK_BIN@ leak (tick fixed 04:10, | (todo) |
| fo-clock-quota-awareness | S | FO clock-and-quota awareness discipline (13:23 incident) | (todo) |
| worktree-task-slug-resolution | S | spacedock task-by-slug resolution drifts to main checkout | (todo) |
| mini-offload-completion-push-channel | S | mini one-shot legs: add completion push atop durable rendezvous | (todo) |
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
| Mirror reverse-recovery-audit.md as an unenforced prose reference (no Hook, no shell test) | The stated analog is itself dangling and untested; ship this guard wired + pinned by a shell test instead, so its AC is enforced not just asserted. |
| Introduce new SO/EM route values re-anchor and split (per issue #49 text) | The real existing vocabulary is proceed/narrow/return/block/costly_no; adding values would change the science-officer-em.md contract + its tests. Reconcile onto existing vocab (re-anchor maps to return) instead. |
| Implement all three trigger points (route-back, cycle-3, child-creation) this round | small-batch proves the wedge first; cycle-3 lives in a different repo (spacedock core) and child-creation has no single chokepoint. Deferred to rabbit-holes. |
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
| l3-scheduler-tick | L3 scheduler tick — stateless SD scheduler (Step-3 wedge v0) | 2026-07-19 (PR #70 + hotfix PR #72) |
| reverse-recovery-audit-dangling-path | Fix dangling reverse-recovery-audit mod ref + regress-guard (first tick-dispatched entity) | 2026-07-19 (PR #71, issue #69) |
<!-- /section:shipped -->
