<!-- section:ship-report -->
## Summary

Ship-flow discovery now prunes fixture trees consistently and surfaces traversal failures instead of accepting partial or misleading routing output. The first and only authorized repository-root acceptance launch completed with rc 0, zero routing errors, and an immutable receipt; replay remains forbidden.

## Todo Closeout Digest

- Captured during this ship: none.
- Promoted: `fixture-pollution-discovery-helpers` became issue #20 and this shipped entity.
- Deferred outside this slice: #21 remains the instance-awareness follow-up; #24 remains the upstream `spacedock status` fixture-scanning tracker.
- Rejected/not captured: replaying repository-root discovery; reopening the frozen source for the nonblocking Bash 3.2 signal-cleanup warning; filing a new signal-hardening todo.

### Token Summary

Budget: not recorded; small-batch appetite (1–2 days)
Actual: not recorded in entity frontmatter
Ratio: not available

### Verdict

status: passed
stage_cost: clean-branch isolation, review/EM closeout, focused fixture tests, lint, and full C1–C15 invariants
started_at: 2026-07-13T10:59:14Z
completed_at: 2026-07-13T11:14:02Z
pr: "#32"
summary: PR #32 carries the isolated fixture-pruning and fail-loud discovery fix; merge remains outside ship-final.
tasks: issue #20 only; #21 and #24 remain related follow-ups
verify: 11/11 required claims; adopter 38/38; density 41/41; invariant matrix, named/full invariants, and lint PASS
acceptance: original frozen commit `1b3871f8`; sole launch rc0/stdout193/stderr0/routes0; no replay
warning: Bash 3.2 INT/TERM cleanup semantics accepted as nonblocking release note

<!-- /section:ship-report -->
