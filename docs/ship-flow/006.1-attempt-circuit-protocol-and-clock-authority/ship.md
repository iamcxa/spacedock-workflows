<!-- section:ship-report -->
# Attempt circuit protocol and clock authority — Ship

Adds the plan/execute `stage-attempt-v1` authority slice with canonical lease,
Git, artifact, completion, and portable same-boot monotonic clock bindings.

## Todo Closeout Digest

- Captured during this ship: none.
- Deferred follow-up: clarify W10's trusted-FO environment boundary in later
  integration documentation if that trust model changes.
- Existing child entities: 006.2, 006.3, and 006.4 remain `status: plan`; none
  was dispatched, tested, advanced, or promoted during 006.1 closeout.
- Rejected alternatives recorded as todos: none.
- Todo routing: no newly captured todo requires task-manager sync, shaping, or
  ROADMAP placement in this ship.

### Token Summary

Budget: small-batch, 2–3 days
Actual: not recorded by the current FO runtime
Ratio: not available

### Verdict

status: awaiting-pr-create
tasks: 006.1 execute, final verify, canonical sync, and exact-head review complete
verify: PASS — 4 required claims VERIFIED, 0 unresolved
review: PROCEED — exact-head artifact review and PR-readiness gates passed


<!-- /section:ship-report -->
