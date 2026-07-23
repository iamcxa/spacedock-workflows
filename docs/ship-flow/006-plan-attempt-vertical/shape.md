# Plan attempt vertical — Shape

## Delegated Autonomous Reshape

The captain's approved end value remains immediate, visibly more agent-native
behavior in the first dogfood after this work ships. This Phase A reshape does
not reopen that direction: it turns the failed W1-W4 helper-first lane into
three minimal vertical outcomes and asks no new shape questions.

Observed evidence fixes the wedge. The earlier plan and execute attempts
crossed their circuits while work continued, PR #93 is blocked, and the first
decomposition let broad regression work obscure whether a real caller could
consume one bounded attempt. This child proves that value at the plan call
site before recovery or execute adoption begins.

## Outcome and Scope

One real plan caller starts one fresh attempt, dispatches one worker, accepts
one authoritative return, and contributes one terminal result within its own
budget. Attempt identity, timing, lease, ref, and terminal authority are typed
at the caller boundary rather than reconstructed from report prose.

Out: crash/replay recovery, execute adoption, #21 UAT, generic scheduling,
dispatcher repair, unrelated test repair, and any XFAIL or future-RED registry.

## Acceptance Criteria

1. A focused real-caller test observes one fresh plan attempt end to end: one
   dispatch, one authoritative return, and one terminal contribution.
2. Resume is distinguishable from fresh creation, and attempt identity,
   budget, lease, ref, and terminal outcome cross the same generic seam.
3. Verification starts with the changed plan/attempt surfaces. An unrelated
   full-suite failure is recorded and deferred, never used to expand scope.

## Timebox and Return Contract

Child cap: **4h**. Every dispatch is estimated at 60m, makes an explicit
finish-versus-return decision at 90m, and hard-stops at 120m with a durable
HEAD, owned paths, checks, and next command. Crossing 4h routes back to
shape/plan; verification is not compressed to fit.

## Hand-off to Design

Design the narrowest real plan-caller seam that proves the outcome above.
Preserve existing exact receipt and authority contracts where they already
work, name the changed-surface tests first, and return to shape if the slice
requires recovery, execute, scheduler, dispatcher, #21, or unrelated-suite
ownership.
