# Make spacedock merge guard the single MERGED-to-done closeout authority — Shape

## Problem

Three competing paths turn a merged PR into terminal (done+archive) state: warn-state-drift.sh (SessionStart auto-fix), merged-pr-closeout-reconciler.sh (a second direct set/archive path), and the canonical spacedock merge guard. They diverge in guards, cleanup, and rollback, so closeout depends on which path fires. When C14/PR#47 merged via a direct gh pr merge that bypassed the FO flow, the auto-fix silently did not fire; the captain hand-reconciled (PR#51), which triggered a latent regression (#29).

## Acceptance Outcome

When a ship-flow entity's PR merges, via the FO flow or a direct gh pr merge bypass, it converges to done+archive through exactly one authority (spacedock merge guard), whichever trigger notices; a dirty worktree persists the pr-merge sentinel and a later clean run reconverges without committing on the wrong branch; no compatible driver fails closed with a stable state-driver-unavailable diagnostic; and reaching terminal state surfaces a non-blocking debrief-due signal so the debrief convention is not orphaned.



## Appetite

small-batch (2-3 days)

## Children

- 6.1-closeout-adapter-single-authority

## Assumptions

(fill in at shape stage)

## Rabbit Holes

- helm-canonical-adapter-registration-dogfood

## Deletes

(fill in from deleted_from_shape)
