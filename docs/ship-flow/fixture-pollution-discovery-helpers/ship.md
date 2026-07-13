<!-- section:ship-report -->
## Summary

Ship-flow discovery now prunes fixture trees consistently and surfaces traversal failures instead of accepting partial or misleading routing output. The first and only authorized repository-root launch was the sole `discover-adopter-skills.sh --root=.` command; it completed with rc 0, zero routing errors, and an immutable receipt. A later density no-match bug found by agy was repaired separately at `fc6ef1e`; replay remains forbidden.

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

status: passed — ship artifact complete; merge-time agy/CI gates pending
stage_cost: clean-branch isolation, review/EM closeout, focused fixture tests, lint, and full C1–C15 invariants
started_at: 2026-07-13T10:59:14Z
completed_at: 2026-07-13T11:14:02Z
pr: "#32"
summary: PR #32 carries the isolated fixture-pruning and fail-loud discovery fix; merge remains outside ship-final.
tasks: issue #20 only; #21 and #24 remain related follow-ups
verify: historical 11/11 required claims; adopter 38/38; post-repair density 51/51; invariant matrix, named/full invariants, and lint PASS
acceptance: original frozen commit `1b3871f8`; sole `discover-adopter-skills.sh --root=.` launch rc0/stdout193/stderr0/routes0; helper/adopter closure blobs unchanged at `fc6ef1e`; density repair is separate; no replay
post_acceptance_repair: agy BLOCK at `904599d`; code/test fix `fc6ef1e` closes findings 1-2 per EM; signal trap remains accepted nonblocking
merge_time_gates: final agy review and current-head CI PENDING
warning: Bash 3.2 INT/TERM cleanup semantics accepted as nonblocking release note

<!-- /section:ship-report -->
