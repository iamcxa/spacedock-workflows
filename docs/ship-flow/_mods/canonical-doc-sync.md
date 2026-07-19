# Canonical Doc Sync — timing + umbrella closeout

Canonical context docs: `ARCHITECTURE.md`, `PRODUCT.md`, `ROADMAP.md`. This mod defines when
ship-review patches each doc, and the umbrella-closeout rule for parent pitch/epic entities.

## Update timing

- ARCHITECTURE.md updates only on an `architecture-impact` block or another durable architecture change (new component, contract, or decision).
- Internal-only diffs never trigger it alone: prompt text changes and workflow reports are explicitly out of scope.
- PRODUCT.md updates when the entity changes a capability the product surfaces.
- ROADMAP.md updates when the entity's row moves stage (e.g. Now to Shipped).
- Every skip records an explicit skip-rationale row in review.md. Silent omission of a canonical doc update is a review-blocking defect.

## Hook: umbrella-closeout

Required when the entity is a `shaped-child`, `pitch`, `epic`, or carries `children:`, and it is the last open child of its parent umbrella.

- ROADMAP.md: the parent umbrella row moves Now/Next to Shipped exactly once for the parent umbrella; the last child to close performs the move, earlier children skip it.
- PRODUCT.md updates exactly once for the parent umbrella when a capability changed, on the same last-open-child trigger.
- If the last child merges before the closeout patch lands, a follow-up PR completes the umbrella closeout instead of blocking the merge.
