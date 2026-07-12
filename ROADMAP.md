# ROADMAP — ship-flow

> Skeleton bootstrapped at shape-confirm of the self-adoption dogfood pitch
> (2026-07-11). Row hygiene and section completion by child
> `canonical-docs-bootstrap`.

## Now (committed, actively working)

<!-- section:now -->
| Entity | Title | Stage |
| --- | --- | --- |
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
| fixture-pollution-discovery-helpers | S | spacedock status --discover and discover-adopter-skills.sh both match plugin test fixtures when run inside the plugin repo, emitting bogus workflow candidates / carlove-shaped routing; helpers need fixture-tree exclusion | pitch 1 |
| shape-confirm-instance-awareness | S | shape-confirm.sh and allocate-id.sh ignore the workflow README id-style declaration, write legacy status sharp (3 sites), and never absorb an existing flat entity — confirm path should be instance-aware | pitch 1 |
| root-readme-stale-claims | S | Root README still claims 0.7.0 adoption gap and spacedock 0.22.0; refresh compatibility/adoption prose once PRODUCT.md carries canonical positioning | pitch 1 |
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
<!-- /section:not-doing -->

## Shipped

<!-- section:shipped -->
| Entity | Title | Shipped |
| --- | --- | --- |
| 1-self-adoption-dogfood-bootstrap | Self-adoption dogfood bootstrap — canonical docs + doc-impact gate | 2026-07-12 (PR #14) |
<!-- /section:shipped -->
