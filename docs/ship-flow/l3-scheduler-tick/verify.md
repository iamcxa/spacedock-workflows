# L3 scheduler tick — Verify

Scope: independent re-run of execute's quality gate (not a relay of execute.md's
numbers), per-AC evidence citations, a DC-keyed UAT table, the ship-verify
host-opposite cross-model challenge (codex vs Claude-authored execute), and
mechanical hard-rule spot-checks on the diff. Diff under review:
`e3665bfa1bfe9a260ca1b0534a1ace16e64edc84..a33b0c4` (execute-stage scope, 53
files, +2554/-1) inside `plugins/ship-flow/{bin,lib,references}` +
`docs/ship-flow/l3-scheduler-tick/`.

## Independent Quality Gate Re-Run

All commands re-run fresh in this worktree (not copied from execute.md):

| Check | Command | Result |
| --- | --- | --- |
| 8 scheduler fixture tests (individually) | `CI=true timeout 90 bash <each test-*.sh>` | 8/8 files exit 0; 101/101 assertions PASS, 0 FAIL |
| Full shell suite | `for t in plugins/ship-flow/lib/__tests__/test-*.sh; do CI=true timeout 90 bash "$t"; done` | 118/118 files exit 0, TOTAL=118 FAILED=0 |
| Node bin tests | `node --test plugins/ship-flow/bin/*.test.mjs` | 79/79 pass, 0 fail |
| Lightweight invariants gate | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` | exit 0 — 18 OK, 2 pre-existing grandfathered WARNs (`c14-feedback-stage-receipt.md`, `2.1-manual-fail-closed-adopter-routing/index.md`) — both unrelated to this entity's diff |
| No-dangling references | `bash scripts/check-no-dangling.sh` | PASS (8 patterns checked) |
| Version-triple consistency | `bash scripts/check-version-triple.sh` | PASS (0.9.0 match, repo clean) |
| Diff whitespace | `git diff --check e3665bf..HEAD` | exit 0, clean |

Independent re-run matches execute.md's claimed counts exactly (118/118, 79/79,
18 OK + 2 grandfathered WARN). No drift found between claimed and observed.

## TDD Evidence Audit

RED-before-GREEN verified structurally, not by re-reading execute.md's prose:
`git cat-file -e 354fb88:plugins/ship-flow/bin/ship-flow-scheduler.sh` (and the
two lib files) all report "exists on disk, but not in 354fb88" — the RED commit
genuinely predates the implementation files it tested against. Combined with
the fresh green re-run above (same tests, same files, now passing), RED→GREEN
ordering is proven, not asserted.

## Per-AC Evidence (independently produced)

#### Verification Claim: AC-1 — Idempotent tick, replay never double-dispatches

| Field | Value |
|---|---|
| claim_source | `quality-gate:test-ship-flow-scheduler-idempotence.sh` + mechanical code read |
| condition | tick replay after crash, and concurrent invocation while lease held |
| metric_or_observable | fixture test 11/11 PASS; lease-acquire logic at `scheduler-lease.sh:60-74` |
| threshold | no second dispatch event on replay; `no-op reason=lease-held` under concurrency |
| smallest_disproving_surface | Codex Gate Finding 1 and 3 below — both undermine this claim in specific windows |
| baseline | design.md §4/§5 stated contract (concurrency=1, dedup via frontmatter absence) |
| treatment | current implementation: dedup reads only frontmatter `worktree`/`pr` fields (never live git/gh state); lease reclaim is age-based only, ignores live-holder check for the reclaim path, and release has no ownership token |
| comparison | fixture-level tests all green (they only exercise the "frontmatter already populated" and "process actually dead" cases) — they do NOT exercise the crash-before-frontmatter-write window or the live-but-slow-holder-past-timeout window that Codex Gate Finding 1/3 identify |
| verdict | `NOT VERIFIED` |
| route_to | `execute` |

#### Verification Claim: AC-2 — Fail-closed dual-key eligibility

| Field | Value |
|---|---|
| claim_source | `quality-gate:test-ship-flow-scheduler-eligibility.sh` + first-hand manual re-run |
| condition | entity not shaped, or shaped but issue lacks `sd:approved` |
| metric_or_observable | fixture test 22/22 PASS; manual re-run of `not-shaped-entity` fixture outside the test harness |
| threshold | `refusal` event with matching reason code, zero adapter/dispatch invocation |
| smallest_disproving_surface | manual command: `ship-flow-scheduler.sh tick --workflow-dir <fixture-wf-with-not-shaped-entity> ...` |
| baseline | design.md §2/§3 dual-key + DoR fail-closed whitelist (`is_shaped` in `bin/ship-flow-scheduler.sh:170-175`) |
| treatment | manually re-ran outside the test file — output: `{"event":"refusal","entity":"not-shaped-entity","outcome":"refused","reason":"not-shaped","detail":{"keys":{"shaped":false,"issue_open":false,"sd_approved":false,"dor":false}}}`, exit 0 |
| comparison | matches expected refusal shape; source-read of `cmd_tick` confirms case `1\|2` in the dispatch-scan loop never calls `run_dispatch_action` (zero-token proof is structural, not just observational) |
| verdict | `VERIFIED` |
| route_to | `proceed` |

#### Verification Claim: AC-3 — Bounded runner adapter

| Field | Value |
|---|---|
| claim_source | `quality-gate:test-scheduler-runner-adapter.sh` + real spawn receipt on disk |
| condition | runner spawn success / timeout / error; failure/timeout must not retry |
| metric_or_observable | fixture test 13/13 PASS; real receipt file `.worktrees/ship-flow-scheduler-controller/.ship-flow-scheduler-receipts/20260719T031741Z-35536-ship-flow-scheduler-t3-sentinel-check.txt` |
| threshold | terminal `blocked` event on timeout/error, no daemon-level retry, receipt exists on disk |
| smallest_disproving_surface | `ls -la` on the receipt path above — file exists, 0 bytes (consistent with the timeout `exit_class` execute.md reports; no output was captured before the bound) |
| baseline | design.md §6 adapter contract (single JSON line, exit-class mapping 0/124/1) |
| treatment | receipt file independently confirmed present at the exact path cited in execute.md's T3 DC-2; `run_dispatch_action` in `bin/ship-flow-scheduler.sh:360-368` maps any non-success `exit_class` straight to a `blocked` event and `return 0` — no loop, no re-invocation anywhere in the file |
| comparison | matches AC-3 exactly; "no fresh-team substitution" also holds — grep across all three scheduler files finds no code path that re-spawns a runner after a blocked outcome |
| verdict | `VERIFIED` |
| route_to | `proceed` |

#### Verification Claim: AC-4 — Derived gate projection, no writable ledger, no auto-merge

| Field | Value |
|---|---|
| claim_source | `quality-gate:test-ship-flow-scheduler-report.sh` + independent grep gate |
| condition | `report` subcommand must never write state; no auto-merge path may exist anywhere in the tick |
| metric_or_observable | fixture test 10/10 PASS; independent grep: `grep -nE "pr merge\|gh pr merge\|--merge\|git merge\|auto-merge\|automerge" <all 3 scheduler files>` → 0 matches; `grep` inside `cmd_report`'s own line range for write redirection/mutation verbs → 0 matches |
| threshold | zero write-capable calls, zero merge-capable calls |
| smallest_disproving_surface | the two independent greps above (re-run by verify, not copied from execute.md) |
| baseline | design.md §7 (read-only, non-terminal-only report rows) |
| treatment | `cmd_report` (`bin/ship-flow-scheduler.sh:518-578`) only reads frontmatter + calls `gh_pr_state`/`pr_head_sha` (both read-only `gh ... --json` calls) and prints to stdout; the only `STATUS_BIN`/mutation-capable call in the entire file is inside `run_reconcile_action` delegating to the pre-existing, unmodified reconciler — not on the report path |
| comparison | matches AC-4's "no writable gate ledger" and "no auto-merge path" exactly; `gh_checks`/`cross_model` columns are `n/a` (execute.md deviation #10, a named v0 narrowing, not a correctness gap) |
| verdict | `VERIFIED` |
| route_to | `proceed` |

#### Verification Claim: AC-5 — Post-merge reconcile + advance, PROMPT_CAPTAIN → terminal blocked

| Field | Value |
|---|---|
| claim_source | `quality-gate:test-ship-flow-scheduler-reconcile.sh` + `test-ship-flow-scheduler-fullcycle.sh` + mechanical code read |
| condition | reconciler PROMPT_CAPTAIN (or any non-PROCEED/crash) → terminal blocked; the NEXT tick dispatches the next-ready entity |
| metric_or_observable | reconcile fixture test 11/11 PASS; fullcycle fixture test 6/6 PASS |
| threshold | `blocked` event with `source=reconciler-prompt-captain` on PROMPT_CAPTAIN (verified); a literal subsequent tick invocation actually dispatching the named next-ready entity (NOT verified) |
| smallest_disproving_surface | `run_reconcile_action` (`bin/ship-flow-scheduler.sh:397-401`) source read — PROMPT_CAPTAIN/exit-1 branch confirmed; `test-ship-flow-scheduler-fullcycle.sh` fixture for `fullcycle-child-entity` (`lib/__tests__/fixtures/ship-flow-scheduler/fullcycle/fullcycle-child-entity/index.md`) is `status: draft` — the SAME status that fails `is_shaped()` — and the fullcycle test stops after leg 2 ("advance names the next-ready child"), never running a leg 3 that would actually attempt to dispatch that child |
| baseline | AC-5 acceptance wording: "the NEXT tick dispatches the next entity" |
| treatment | `run_advance_action` only emits an `advance` audit event naming a DAG-ready id; it does not itself change the child's eligibility, and the fixture used to "prove" this AC has a child fixture that would fail `is_shaped()` if a real third tick were run against it |
| comparison | the PROMPT_CAPTAIN → blocked half of AC-5 is proven; the "NEXT tick dispatches" half is asserted by execute.md/plan.md's DC-1 description but not actually exercised by any test — Codex Gate Finding 4 (below) independently surfaced the same gap |
| verdict | `NOT VERIFIED` (partial — reconcile half VERIFIED, advance-then-dispatch half NOT VERIFIED) |
| route_to | `execute` |

#### Verification Claim: AC-6 — Carrier + rollup + runbook

| Field | Value |
|---|---|
| claim_source | `quality-gate:test-ship-flow-scheduler-rollup.sh` + `test-ship-flow-scheduler-plist.sh` + independent lint |
| condition | plist templates well-formed; rollup deterministic; runbook documents inspect/unlock/rerun; daemon owns no canonical state |
| metric_or_observable | rollup fixture test 8/8 PASS; plist fixture test 10/10 PASS; independent `plutil -lint` on both templates |
| threshold | both plists lint OK; rollup byte-identical across repeat runs on the same input; `RUNBOOK.md` present with all four sections |
| smallest_disproving_surface | `plutil -lint plugins/ship-flow/references/launchd/*.plist` (re-run independently, not copied) → both `OK`; `grep -n "^##" RUNBOOK.md` → Inspect/Unlock/Rerun/launchd install-uninstall/Daily rollup all present |
| baseline | design.md §8 |
| treatment | independent lint output matches; independent grep for `SKILL\.md\|budget\|policy\|routing` mutation across all 3 scheduler files → 0 matches, confirming "never mutates prompts, routing, budgets, or policy" |
| comparison | matches AC-6 fully |
| verdict | `VERIFIED` |
| route_to | `proceed` |

## Mechanical Hard-Rule Spot-Checks (independent, on the diff)

| # | Rule | Check | Result |
|---|---|---|---|
| 1 | Gate report is a read-only projection (no state writes on the report path) | `sed -n '518,578p' bin/ship-flow-scheduler.sh \| grep -nE '>[^&]\|>>\|mkdir\|touch \|git (add\|commit\|push)\|sed -i'` | 0 matches — no write redirection or mutation verb inside `cmd_report` |
| 2 | Dual-key eligibility fails closed | source read of `evaluate_entity`/`is_shaped` (`bin/ship-flow-scheduler.sh:170-229`) + manual re-run of `not-shaped-entity` fixture | whitelist-only `is_shaped` (unknown/draft/done/empty all fail closed); every unmet key returns 1/2 before reaching dispatch; manual re-run confirms |
| 3 | Reconciler PROMPT_CAPTAIN maps to terminal blocked | source read of `run_reconcile_action` (`bin/ship-flow-scheduler.sh:397-401`) | `verdict = PROMPT_CAPTAIN` OR `reconciler_exit = 1` → `emit_event blocked ... reconciler-prompt-captain`; non-PROCEED/non-zero-exit (REJECT/crash) also fails closed to `blocked` (`reconciler-error`) |
| 4 | No auto-merge path exists anywhere in the tick code | `grep -nE "pr merge\|gh pr merge\|--merge\|git merge\|auto-merge\|automerge" bin/ship-flow-scheduler.sh lib/scheduler-lease.sh lib/scheduler-runner-adapter.sh` | 0 matches across all three files |

All four hard-rule spot-checks hold on the diff as written. (Note: check 3's
underlying safety property is separately weakened by Codex Gate Finding 3 —
mapping PROMPT_CAPTAIN to `blocked` is correct, but the lease that should
prevent a *second* tick from concurrently mutating the same entity while a
reconcile is in flight can be reclaimed out from under a live holder — see
below.)

## Cross-Model Challenge (`cross_model_challenge` dimension)

Claude drove execute; codex challenges the diff (host-opposite). Codex CLI
available (`codex-cli 0.144.1`, model `gpt-5.6-sol`), prompt hash verified
against `codex-gate` SKILL.md's locked `prompt-sha256` before invocation (match:
`d8894c2a...`). Invoked via `codex exec` at `read-only` sandbox, `reasoning
effort=high`, against `git diff e3665bf..HEAD` (2554 LOC, under the 5000 LOC
cap). NOT degraded — ran to completion, exit 0.

**Citation spot-check (100% of cited file:line refs, per ship-verify's own
rule)** — all four findings' cited lines read and confirmed to match content
within ±3 lines. No hallucination detected; no discard.

### Codex Gate Findings

```
[P1] plugins/ship-flow/bin/ship-flow-scheduler.sh:224 checks only recorded
frontmatter, so a crash after creating a live worktree or PR but before
persisting those fields leaves the entity eligible for duplicate dispatch.
Derive both dedup keys from live Git and GitHub state, failing closed when
either lookup is unavailable.

[P1] plugins/ship-flow/bin/ship-flow-scheduler.sh:160 converts GitHub failures
into UNKNOWN, while plugins/ship-flow/bin/ship-flow-scheduler.sh:287 treats
every state except OPEN as reconcileable; a transient auth, network, or
rate-limit failure can therefore send an actually open PR into repeated
PROMPT_CAPTAIN/blocked reconciliation. Preserve provider errors separately and
reconcile only explicit MERGED or CLOSED states, surfacing lookup failures as
environment faults.

[P1] plugins/ship-flow/lib/scheduler-lease.sh:60 permits reclaiming a lease
whose PID is still alive once its age exceeds the timeout, although the
reconciler invoked at plugins/ship-flow/bin/ship-flow-scheduler.sh:391 has no
timeout; a slow reconcile can therefore overlap a second mutating tick, and the
original holder later unconditionally deletes the successor's lease at
plugins/ship-flow/lib/scheduler-lease.sh:74. Never steal from a live owner
without first terminating and reaping its bounded action, and make release
compare an ownership token before removing the record.

[P1] plugins/ship-flow/bin/ship-flow-scheduler.sh:482 labels a ready child as
dispatched but only writes an audit event; because draft children remain
ineligible at plugins/ship-flow/bin/ship-flow-scheduler.sh:171 and the event
log is never a decision input, subsequent ticks repeatedly refuse the child and
automatic continuation stops. Make advance perform a durable handoff or
canonical eligibility transition, then extend the full-cycle test with a third
tick proving the child is actually dispatched exactly once.
```

GATE: FAIL   prompt-sha256: d8894c2a002c   diff-LOC: 2554   codex-version: 0.144.1   [P1]:4  [P2]:0

### Verifier disposition of codex findings (verifier-owned, per ship-verify's ownership contract)

Codex tagged all four `[P1]`. Verifier reclassifies by actual blast radius
against this entity's stated ACs and Rule 9 (concurrency=1):

| # | Codex severity | Verifier severity | Route | Reasoning |
|---|---|---|---|---|
| 1 (frontmatter-only dedup) | P1 | **BLOCKING** | `execute` | Directly falsifies AC-1's stated guarantee ("replaying after a crash never double-dispatches") in the crash-before-frontmatter-write window; not a named v0 cut anywhere in shape/design/plan |
| 2 (UNKNOWN→reconcile) | P1 | **WARNING** | `execute` | Fail-safe direction (over-escalates to PROMPT_CAPTAIN rather than silently proceeding) — degrades operability (false alarms on transient GH flake) but does not itself cause data loss or double-dispatch; downgraded from codex's P1 |
| 3 (lease reclaim ignores live holder; unconditional release) | P1 | **BLOCKING** | `execute` | Directly falsifies Rule 9 (concurrency=1) and contradicts RUNBOOK.md's own stated operator invariant ("Never remove a live holder's lease") — the automatic code path does exactly what the runbook forbids a human from doing manually |
| 4 (advance doesn't prove dispatch; fullcycle fixture is draft) | P1 | **BLOCKING** | `execute` | AC-5's "the NEXT tick dispatches the next entity" is an unverified claim — the only test that could prove it uses a fixture (`status: draft`) that would itself fail eligibility on a real third tick |

No AUTO-FIX-class findings (all four require judgment about dedup-key design,
lease-token design, or advance/dispatch coupling — not mechanical one-liners).
Per ensign discipline, none are inline-fixed here; all four route to `execute`
via this verify.md.

## Runtime UAT (`runtime_uat` dimension)

- **Fixture-level runtime**: `test-ship-flow-scheduler-fullcycle.sh` exercises
  dispatch → merged → reconcile → advance end-to-end against fixtures (6/6
  PASS, independently re-run above). This counts as fixture-level `runtime_uat`
  per this stage's checklist.
- **Real adapter spawn receipt**: independently confirmed on disk at
  `.worktrees/ship-flow-scheduler-controller/.ship-flow-scheduler-receipts/20260719T031741Z-35536-ship-flow-scheduler-t3-sentinel-check.txt`
  (0 bytes, consistent with the timeout `exit_class` execute.md reports for
  this real `claude -p` spawn). This also counts as fixture-level `runtime_uat`
  per this stage's checklist (AC-3's "one real sentinel spawn log").
- **LIVE proof on issue #69 (`reverse-recovery-audit-dangling-path`)**:
  explicitly **deferred — FO-owned live proof at H7**, per plan.md T7 DC-2 and
  this stage's own checklist. Not run from inside verify. Precondition
  (`reverse-recovery-audit-dangling-path` currently `status: draft`, needs a
  shape-confirm pass) is unchanged since plan — still outside this stage's
  scope. This is declared here explicitly, not silently omitted.

## DC-Keyed UAT Table (from plan.md)

| DC | Task | Command | Expected | Verify-stage result |
|---|---|---|---|---|
| T0 DC | T0 (precondition) | `gh auth status && spacedock --version && command -v claude && command -v codex` | all exit 0 | Not re-run (operational precondition already satisfied per execute.md; controller worktree confirmed present at `.worktrees/ship-flow-scheduler-controller`) |
| T1 DC | T1 (RED suite) | RED loop over 8 test files | all exit 1, "missing helper" | Structurally re-verified: implementation files absent at commit `354fb88` (git cat-file -e) |
| T2 DC | T2 (tick core) | idempotence + eligibility tests | both exit 0, all PASS | Independently re-run: 11/11 + 22/22 PASS |
| T3 DC-1 | T3 (adapter, fixture) | `test-scheduler-runner-adapter.sh` | exit 0, all PASS | Independently re-run: 13/13 PASS |
| T3 DC-2 | T3 (adapter, real spawn) | real `claude -p` spawn via adapter | one JSON line, receipt exists on disk | Independently confirmed: receipt file exists at the cited path |
| T4 DC | T4 (report) | grep no-write gate + `report` + `git status --porcelain` | grep empty; porcelain empty | Independently re-run: 10/10 PASS; independent grep re-confirms 0 matches |
| T5 DC | T5 (reconcile+advance) | `test-ship-flow-scheduler-reconcile.sh` | exit 0, all PASS | Independently re-run: 11/11 PASS — but see AC-5 claim above: PROCEED→advance naming is proven, dispatch-on-next-tick is NOT |
| T6 DC | T6 (launchd+rollup+runbook) | rollup determinism, plist lint, `test -f RUNBOOK.md` | byte-identical rollup; lint OK; file exists | Independently re-run: rollup 8/8 + plist 10/10 PASS; independent `plutil -lint` OK on both; RUNBOOK.md confirmed present with all 4 sections |
| T7 DC-1 | T7 (fixture full-cycle) | `test-ship-flow-scheduler-fullcycle.sh` | exit 0, all PASS | Independently re-run: 6/6 PASS — see AC-5 caveat: proves legs 1-2 only, not a 3rd-tick dispatch |
| T7 DC-2 | T7 (LIVE proof, issue #69) | real tick against `reverse-recovery-audit-dangling-path` to `awaiting_merge` | frontmatter `pr:` set, PR OPEN + `verdict: PASSED` | **Deferred — FO-owned live proof at H7** (declared explicitly per checklist; precondition `status: draft` unresolved) |

## Verdict

**Verdict: NOT VERIFIED (VETO) — route_to: execute.**

Rationale: the independent quality-gate re-run is 100% green (118/118 shell,
79/79 node, all 8 scheduler fixtures, invariants/no-dangling/version-triple all
clean) and 4 of 6 ACs (AC-2, AC-3, AC-4, AC-6) are cleanly `VERIFIED`. However,
the cross-model challenge — run specifically because Claude drove execute and
could not adversarially review its own diff — surfaced three BLOCKING findings
that a green test suite does not catch because the test suite itself doesn't
exercise the failure windows in question: (1) dedup keyed on frontmatter alone
can double-dispatch across a crash-before-write window, (2) the controller
lease can be reclaimed out from under a still-alive holder (violates Rule 9
concurrency=1, contradicts RUNBOOK.md's own operator invariant), and (3) the
fullcycle test's own "next-ready" fixture is itself ineligible for real
dispatch, so AC-5's "NEXT tick dispatches" half is asserted, not proven. These
three findings directly undermine the two acceptance criteria (AC-1, AC-5)
that name the tick's core safety property (idempotent, crash-safe,
concurrency=1) — this is not follow-up-todo material, it is BLOCKING per this
stage's own hard-rule framing.

One WARNING (UNKNOWN GH-state handling) is advisory — track but does not by
itself block.

No BLOCKING/WARNING finding is inline-fixed here (ensign rule: findings route
back via verify.md, never FO-inline-fixed). `feedback-to: execute` per the four
findings tabulated above.

Panel coverage note: this verify pass is a single-ensign scoped verify (the
stage checklist named exactly independent-gate-re-run + cross-model-challenge +
mechanical-spot-checks) — not a full FO-orchestrated multi-specialist panel.
`panel_coverage: minimal` (cross-model only); `cross_model: true`.
