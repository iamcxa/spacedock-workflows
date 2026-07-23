# Plan attempt recovery — Shape

## Delegated Autonomous Reshape

This child preserves Epic 006's approved agent-native end value while moving
only after `006-plan-attempt-vertical` proves a real plan caller. It adopts the
earlier crash-safe history/replay intent, but measures success at the caller:
one recovered terminal contribution and no second worker.

The evidence is the prior recovery failure mode: disconnects, partial returns,
and replay could leave lifecycle authority in prose, while broad helper and
regression work made duplicate-dispatch risk hard to falsify. Recovery is
therefore its own vertical child rather than part of the initial seam.

## Outcome and Scope

After an injected plan crash at a return/terminal boundary, FO recovery reuses
the same authoritative attempt evidence, contributes exactly one terminal
event and duration, and dispatches zero duplicate workers. Conflicting or
incomplete evidence fails closed without mutating the authoritative state.

Out: fresh plan seam design, execute adoption, exhaustion policy changes,
#21 UAT, dispatcher repair, generic scheduling, unrelated test repair, and any
XFAIL or future-RED registry.

## Acceptance Criteria

1. Focused crash-boundary tests yield one terminal event and one cumulative
   duration contribution for the recovered plan attempt.
2. Recovery and replay keep worker/envelope dispatch counters at zero,
   including replay after the terminal commit.
3. Attempt identity, clock, lease, ref, and returned bytes remain stable;
   mismatched evidence fails closed with no authoritative mutation.

## Timebox and Return Contract

Child cap: **4h**. Every dispatch is estimated at 60m, makes an explicit
finish-versus-return decision at 90m, and hard-stops at 120m with a durable
HEAD, owned paths, checks, and next command. Crossing 4h routes back to
shape/plan; verification is not compressed to fit.

## Hand-off to Design

Start from the landed plan vertical and design only the recovery/replay path
through that proven seam. Pin crash boundaries and dispatch counters before
implementation; return to shape if correctness requires a second lifecycle
implementation, execute changes, #21 changes, dispatcher repair, or unrelated
suite ownership.
