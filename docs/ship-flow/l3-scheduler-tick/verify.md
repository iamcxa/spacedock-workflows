# L3 scheduler tick — Verify (cycle 3, final)

Cycle 2: re-review of the feedback-cycle-1 fixes (F1-F4) to my cycle-1 VETO
(verify.md@07b726c; routing a6601b0), fix diff `a6601b0..575e81c` (+556/-44).
FO rebase note: execute.md prose cites pre-rebase SHAs; this doc cites
current-branch SHAs: F1 bc195e6→d1d148d, F2 ac52c16→e849754, F4
4612d85→31b4db1, F3 e2d3752→84525b2 (+ de661a3/55ecd88/a1263ed). Cycle 3
(round cap reached — scoped confirmation, not a new round): execute fixed
exactly W1+W2 (RED f655f34 → GREEN eafa77b; docs f0b878b), confirmed below;
nothing new beyond W1/W2 scope — no PROMPT_CAPTAIN needed.

## Independent Quality Gate Re-Run (cycle 2)

All re-run fresh in this worktree: 9 scheduler tests (8 original + new
`test-scheduler-lease.sh`) 9/9 files, 111/111 assertions PASS. Full shell suite
119 files: 118 PASS, 1 FAIL — `test-archived-corpus-invariants.sh`, failing
solely on THIS file's pre-rewrite C11/C12/C15 state; flips green with this
rewrite (re-run receipt in the Verdict section). Node 79/79. check-no-dangling
PASS. check-version-triple PASS. check-invariants: C14 now OK post-rebase;
C11/C12/C15 resolved by this rewrite. `git diff --check`: one blank-line-at-EOF
NIT on index.md from a1263ed — auto-resolved by this stage's report append
(NIT-class auto-fix, permitted).

## Per-AC Evidence

- **AC-1 (idempotent tick) — VERIFIED.** Fix d1d148d closes the cycle-1
  crash-window: dedup now checks the live worktree dir + a live gh PR lookup by
  conventional branch, not frontmatter alone. First-hand probes (not just the
  suite): `worktree-live-only-entity` and `pr-live-only-entity` (both with
  EMPTY frontmatter) → `refusal reason=worktree-exists|pr-exists`; replay on
  `already-dispatched-entity` → same refusal twice, never a dispatch.
  Eligibility 28/28, idempotence 11/11. Residual edges W1/W2 below.
- **AC-2 (fail-closed dual-key) — VERIFIED.** Unchanged from cycle 1 (22/22
  within the 28); `is_shaped` whitelist intact at d1d148d.
- **AC-3 (bounded adapter) — VERIFIED.** Unchanged; 13/13; real spawn receipt
  on disk (cycle-1 citation stands).
- **AC-4 (read-only gate projection) — VERIFIED.** Re-grepped post-fix: zero
  mutation verbs in `cmd_report`, zero merge-capable calls in all three
  scheduler files.
- **AC-5 (post-merge continuation) — VERIFIED.** The cycle-1 gap is closed
  fixture-honestly: leg 3 (84525b2) runs a real third tick after the parent
  archives, promotes the child via the modeled captain shape-pass, and asserts
  an actual `"event":"dispatch"` for `fullcycle-child-entity` — fullcycle 8/8.
  PROMPT_CAPTAIN→blocked re-confirmed at bin/ship-flow-scheduler.sh:456-467.
- **AC-6 (carrier+rollup+runbook) — VERIFIED.** Unchanged (rollup 8/8, plist
  10/10); RUNBOOK.md Unlock section updated to match the new lease semantics.

## Review Findings

### F1-F4 fix verification (RED independently re-proven)

Each RED commit re-run in a detached worktree at its own SHA — all four
genuinely fail there and pass at HEAD. F2 additionally probed first-hand:
alive-but-ancient holder never reclaimed; wrong-token release refused (record
survives); right-token release succeeds; dead-pid reclaim works. F4 probed
first-hand: UNKNOWN PR state → `no-op reason=gh-state-unknown`, no mutation.

### Cycle-2 cross-model challenge (codex, scoped to the fix diff)

Host-opposite dimension: codex-cli 0.144.1 / gpt-5.6-sol, locked prompt
hash-verified (d8894c2a002c), read-only, against `a6601b0..HEAD`. NOT degraded.
5 findings (4 P1 + 1 P2), 100% citation-accurate. Verifier disposition — all
are strictly narrower residuals of the fixed classes, none falsifies an AC at
realistic probability (rationale per finding in the collapsed block):

| # | Finding (file:line) | Codex | Verifier | route_to |
| --- | --- | --- | --- | --- |
| W1 | gh-present-but-erroring → `NONE` fail-open in `pr_exists_for_slug` (:160) — contradicts its own fail-closed comment; confirmed empirically with a stub gh | P1 | WARNING | **FIXED cycle 3** (f655f34→eafa77b) |
| W2 | live-PR dedup case omits `CLOSED` (:262) — crash-window entity with a closed-unmerged PR redispatches, bypassing PROMPT_CAPTAIN authority | P1 | WARNING | **FIXED cycle 3** (f655f34→eafa77b) |
| W3 | torn/dead-lease recovery race (lease.sh:72,86) — two simultaneous ticks can both reclaim; mkdir-atomicity covers fresh acquire only | P1 | WARNING | follow-up |
| W4 | `timeout` can kill the reconciler mid-mutation (:450) — raises probability of a crash class the composed reconciler already owns | P1 | WARNING | follow-up |
| W5 | token release falls through when record absent/token-less (lease.sh:108) — documented back-compat fallback, ms-window race | P2 | advisory | follow-up |

<details>
<summary>Codex verbatim findings + per-finding severity rationale</summary>

Codex output, compact: (1) `:160` `|| true` masks failed `gh pr list`, empty
stdout → NONE → fail-open duplicate-dispatch during auth/network/rate-limit
failure; fix: separate exit status, UNKNOWN on failure. (2) `:262` CLOSED not
in dedup case → crash-window redispatch; fix: any returned PR state =
pr-exists. (3) lease recovery TOCTOU → serialize takeover via atomic CAS
(rmdir+mkdir). (4) timeout mid-archival → make reconcile resumable or scope
the bound. (5) `:108` guard falls through → require exact match for
token-bearing callers.

Severity rationale (verifier-owned): W1/W2 sit BEHIND the live worktree-dir
check, which is filesystem-local (no failure mode) and covers the entire
realistic crash window — a /ship run's worktree exists from before PR-create
until post-merge cleanup, and cleanup happens only long after `pr:` is
recorded. Exploiting W1 needs crash + externally-deleted worktree + transient
gh failure at rescan; W2 the same minus the gh failure but plus a
captain-closed PR. Both are one-line mechanical fixes (mirror `gh_pr_state`'s
`|| printf UNKNOWN`; add CLOSED to the case). W3/W5 need two ticks racing
within milliseconds on an already-dead lease — vs cycle-1 F2's deterministic
age-steal under any slow reconcile (that was BLOCKING; this is not). W4: any
process can already die mid-reconcile (machine crash); the composed reconciler
owns that crash story — the bound raises exposure, doesn't create the class.
Codex-vs-verifier severity disagreement (P1 vs WARNING ×4) is recorded here
per the severity-disagreement rule; the FO/captain can overrule cheaply.

</details>

## Runtime UAT

`runtime_uat`: fixture-level runtime — fullcycle 8/8 (now including the real
leg-3 dispatch) + the real `claude -p` adapter spawn receipt on disk at
`.worktrees/ship-flow-scheduler-controller/.ship-flow-scheduler-receipts/20260719T031741Z-35536-ship-flow-scheduler-t3-sentinel-check.txt`.
The LIVE #69 proof (`reverse-recovery-audit-dangling-path` →
`awaiting_merge`) remains **deferred — FO-owned live proof at H7** (declared,
never silent; precondition: that entity is still `status: draft`).

<details>
<summary>DC-keyed UAT table (plan.md T0-T7, cycle-2 results)</summary>

| DC | Cycle-2 result |
| --- | --- |
| T0 | Operational precondition; controller worktree present (unchanged) |
| T1 | RED suite: all four cycle-2 RED commits ALSO independently re-proven red at their own SHAs |
| T2 | idempotence 11/11 + eligibility 28/28 (grew +6 for F1) |
| T3 DC-1/DC-2 | adapter 13/13; real spawn receipt confirmed on disk |
| T4 | report 10/10; independent mutation-grep 0 matches |
| T5 | reconcile 16/16 (grew +5 for F4); composed primitives still untouched |
| T6 | rollup 8/8, plist 10/10, RUNBOOK updated for F2 lease semantics |
| T7 DC-1 | fullcycle 8/8 — dispatch → merged → reconcile → advance → REAL leg-3 dispatch |
| T7 DC-2 | Deferred — FO-owned live proof at H7 (explicit, unchanged) |

New tests this cycle: `test-scheduler-lease.sh` 7/7 (liveness-only reclaim,
token release, dead-pid reclaim, fresh acquire).

</details>

## Verdict

**PASS (PROCEED) — cycle 3, final.** All four cycle-1 findings genuinely fixed
(independently re-proven RED-before-fix + first-hand probes, cycle 2). The FO
took the surfaced option: W1+W2 fixed in feedback cycle 2 and confirmed here
independently — diffs match my finding sites exactly (`pr_exists_for_slug`
:157-165 now splits gh exit-failure→UNKNOWN from success-empty→NONE; dedup
case-arm :268-272 now includes CLOSED); eligibility 34/34 re-run (30/34 at RED
f655f34, exactly the four W1/W2 assertions, re-proven in a detached worktree);
first-hand stub-gh probe → UNKNOWN on gh error, and the CLOSED crash-window
fixture → `refusal reason=pr-exists`. design.md §3/§4 wording updated to "no
open/merged/closed PR". Cycle-3 gate: check-invariants exit 0 (0 FAILs), all 9
scheduler files green (117 assertions), node 79/79, no-dangling/version-triple
PASS, `git diff --check` clean. Nothing new surfaced beyond W1/W2 scope, so no
PROMPT_CAPTAIN. Remaining follow-ups (W3/W4/W5 + carryovers) stand below.

## Panel Coverage

`panel_coverage: minimal` — single verifier (this ensign) + host-opposite
cross-model challenge; no multi-specialist panel was dispatched (the cycle-2
dispatch scoped exactly: independent gate re-run + AC-1/AC-5 re-verify +
scoped codex re-challenge + invariant conformance). `cross_model: true` both
review cycles (full-diff challenge at cycle 1, fix-diff challenge at cycle 2),
NOT degraded either time; cycle 3 is a scoped W1/W2 confirmation inside the
round cap, no new codex run by design. Specialist lenses
(security/perf/api-contract) not separately run — bash CLI surface, no
API/UI/schema change.

## Deferred to TODO

- W3+W5: lease recovery/release races — atomic takeover (rmdir+mkdir CAS) for
  torn/dead-lease reclaim; strict token match when the caller supplies one.
- W4: document/verify reconciler crash-resumability under the new `timeout`
  bound (composed-primitive contract, coordinate with reconciler owner).
- Cycle-1 carryovers (unchanged): rollup cost field n/a; launchd installer
  manual; global multi-epic advance scan absent (plan.md cut-list).
