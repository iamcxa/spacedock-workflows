---
title: L3 scheduler tick — stateless SD scheduler (Step-3 wedge v0)
status: ship
source: captain hackathon contract (.context/l3-hackathon-contract.md, GO 2026-07-19; converged Claude FO + SO-EM + codex/sol panel)
started: 2026-07-19T02:22:05Z
completed:
verdict:
score:
worktree: .worktrees/spacedock-ensign-l3-scheduler-tick
issue:
pr: "#70"
---

Land the L3 Step-3 wedge: a stateless, idempotent scheduler tick that removes the human as
persistent scheduler for already-approved work. Dual-key eligibility (shaped entity + linked
open gh issue labeled `sd:approved`), bounded headless dispatch of `/ship <entity>`, derived
gate projection (no auto-merge — real runs stop at awaiting_merge), post-merge reconcile +
DAG auto-advance, launchd carrier, deterministic daily rollup. Full converged contract with
hard rules, refusals, and hour plan: `.context/l3-hackathon-contract.md` (shape must absorb
its content into shape.md as the durable in-repo spec).

## Acceptance criteria

**AC-1 — Idempotent tick.** A deterministic `scheduler tick` command takes exactly ONE bounded
action per invocation (dispatch | advance | reconcile | no-op), emits structured JSON events,
and exits; replaying after a crash never double-dispatches.
Verified by: fixture tests — replay idempotence + duplicate-dispatch refusal — run green.

**AC-2 — Fail-closed dual-key eligibility.** An entity that is not shaped, or whose linked gh
issue lacks `sd:approved`, is marked ineligible with machine-readable reasons and never spawns
an FO (zero worker tokens).
Verified by: fixture test with unlabeled/unshaped entity → tick emits refusal event, no spawn.

**AC-3 — Bounded runner adapter.** The tick spawns headless `claude -p "/ship <entity>"` with
explicit workdir/timeout/env behind a small adapter; failure or timeout → terminal `blocked`
receipt, no daemon-level retry, no fresh-team substitution.
Verified by: adapter fixture test (stub runner) + one real sentinel spawn log.

**AC-4 — Derived gate projection.** A read-only morning report renders entity, exact PR head,
verify verdict, GitHub checks, and cross_model coverage from canonical sources; no writable
gate ledger exists; no auto-merge path exists.
Verified by: generated gate-queue report from fixtures + grep proving no state writes.

**AC-5 — Post-merge continuation.** After captain merge, the tick runs
merged-pr-closeout-reconciler.sh (any PROMPT_CAPTAIN → terminal blocked), recomputes ready set
via dag-waves.sh --ready, and the NEXT tick dispatches the next entity (never recursive inline).
Verified by: fixture full-cycle test dispatch → PR-ready → merged → reconcile → next-ready.

**AC-6 — Carrier + rollup + runbook.** launchd invokes the tick on interval and a 23:55
deterministic daily rollup (dispatches, durations, gate waits, failures, costs, interventions);
a recovery runbook documents inspect/unlock/rerun; the daemon owns no canonical state and
never mutates prompts, routing, budgets, or policy.
Verified by: plist present + rollup generated from fixture events + runbook file + grep
proving tick state is derived-cache only.

## Stage Report: shape

- DONE: shape.md absorbs the full hackathon contract from .context/l3-hackathon-contract.md (GCD, 10 hard rules, refusals list, EM-drive profile, input-quality DoR, hour plan) as the durable in-repo spec — .context is gitignored, so the content must be materialized, not pointed at.
  shape.md materializes all six sections verbatim (GCD, Hard Rules 1-10, Deferred-without-loss refusals, EM-drive profile, input-quality DoR, hour-by-hour); no pointer to the gitignored source.
- DONE: Captain articulation is ALREADY GIVEN (his "1 go" on the converged contract + this session's transcript); preserve his decisions verbatim — do NOT re-ask Q1/Q2/Q3; record the archived-entity #1 Y-mode un-defer as a captain decision with his quote: "如果這是必要的，且可以建立足夠信任邊界，我不在意重開 y-mode".
  shape.md "Captain Articulation and Ownership Trail" records GO (source: frontmatter) + the Y-mode un-defer quote verbatim; no Musk audit re-run, Q1/Q2/Q3 not re-asked.
- DONE: Acceptance outcomes map 1:1 to the entity's AC-1..AC-6, stay mechanically testable (fixture commands), appetite = one night (8h), out-of-scope = the contract's "Deferred without loss" refusals (no auto-merge, no raw intake, no repair-until-pass, no auto codex-gate, no helm dependency, no crewdock integration, no semantic nightly learning).
  shape.md "Acceptance Outcomes" table pairs each AC-1..AC-6 with value+mechanism+fixture proof (1:1, no restatement); Appetite = one night (8h); Out-of-Scope lists all nine refusals.

### Summary

Freeze stage: materialized the converged L3 hackathon contract into a durable, repo-visible shape.md (the .context source is gitignored). Captain articulation was already given (GO + Y-mode un-defer), so no interactive Musk audit — decisions preserved verbatim. AC-1..AC-6 mapped 1:1 to value/mechanism outcomes with reproducible fixture proofs; appetite one night; out-of-scope pinned to the contract's refusals. Hand-off to design flags design_required (contract-bearing CLI/JSON/plist surfaces, non-UI) with four open design questions and zero unresolved contract decisions.

## Stage Report: design

- DONE: design.md fixes the v0 contract deltas concretely: tick CLI surface (command name, flags, exit codes), JSON event schema (event types + required fields), state-projection vocabulary (how eligible/leased/running/awaiting_merge/merged/reconciled/done/blocked derive from entity frontmatter + gh reads — projection, never stored canonically by the tick), derived gate-projection report format, launchd plist + deterministic rollup shape. Resolve shape.md's 4 open design questions WITHIN the 10 hard rules; a question needing a new captain decision is parked in design.md, not decided.
  design.md §1 (CLI/exit codes), §2 (JSON schema + refusal codes), §3 (projection derivation table), §7 (report), §8 (plist templates + deterministic rollup); §9 resolves all 4 open questions within the 10 rules — 0 parks, 0 new captain decisions.
- DONE: Carrier-swap seam explicit: the runner-adapter spawn contract (inputs: entity ref, workdir, timeout, env; outputs: exit class, sentinel, receipt path) documented so crewdock can later replace launchd + claude -p without touching tick internals; the tick never owns transcripts, park/resume, scavenging, or container lifecycle.
  design.md §6 pins `lib/scheduler-runner-adapter.sh run --entity --workdir --timeout --env` → single JSON line {exit_class,sentinel,receipt}; Rule-10 boundary stated verbatim (tick never reads transcripts/parks/scavenges/manages containers).
- DONE: Name the test surfaces that pin each contract: fixture tests for replay idempotence, duplicate-dispatch refusal, ineligible-entity refusal (fail-closed dual-key), PROMPT_CAPTAIN→terminal-blocked, rollup determinism; verify no existing shell-test string assertions break (110+ suite); prefer a code gate over a prose-only rule everywhere.
  design.md §10 names nine `lib/__tests__/test-*.sh` gates (one per AC); no-existing-break verified by proof-of-absence + green baseline exercised now (test-dag-waves ALL PASS, test-merged-pr-closeout-reconciler 82/82).

### Summary

Fixed the v0 contract deltas concretely in design.md and resolved all four of shape's open design questions within the ten hard rules (zero parks, zero new captain decisions). Reverse-recovery classification: the tick is a new additive orchestration atom that COMPOSES WORKING primitives (dag-waves.sh --ready, merged-pr-closeout-reconciler.sh, spacedock status, the fo-completion-lease mkdir-atomic pattern) — rebuilds none; both composed primitives exercised green. Key design call: idempotence (AC-1) is a pure function of canonical state + a controller lease held across the whole run (concurrency=1), so the derived tick cache is the empty set and crash-replay reconstructs from canonical state — no writable ledger (Rule 3). Every contract is pinned by a shell-testable code gate in the existing CI harness, not prose.

## Stage Report: plan

- DONE: plan.md decomposes into atomic-commit tasks mapped to design sections + the nine AC test gates: fixture tests FIRST (TDD red before green), then tick CLI + runner adapter + state projection + gate report + launchd/rollup, each task with an observable DC (exact command + expected output); serial execution inside the single worktree.
  plan.md T0-T7 (8 tasks): T1 = RED fixture suite (8 files pinning design §10's 9 gate rows); T2 tick CLI+lease+state-projection; T3 runner adapter; T4 gate report; T5 reconcile+advance; T6 launchd+rollup+RUNBOOK; T7 two terminal proofs. Every task carries `red_command`/`expected_red_failure`/`green_command`/`refactor_check` plus an exact-command DC. "Serial execution order" section states T0→T7 strict order, no parallel waves.
- DONE: Runtime commands pinned from the repo's existing shell-test harness (how lib/__tests__/test-*.sh actually run in CI and locally); every deliverable stays inside plugins/ship-flow/{bin,lib,references} + templates per design §11 — no SKILL.md edits beyond what design §11 names, no new captain decisions.
  plan.md "Runtime commands" cites the exact `CI=true timeout 90 bash …` per-file and full-suite loop from `.github/workflows/ship-flow-invariants.yml`; "Plugin-surface + no-SKILL.md confirmation" table lists every new file (all under plugins/ship-flow/{bin,lib,references} + one entity-local RUNBOOK.md per design §8's own placement) and confirms 0 SKILL.md edits, 0 changes to existing reconciler/dag-waves output contracts; "Canonical Doc Actions" table records all 4 root docs as skip/defer-to-ship per design §11.
- DONE: Hour-budget realism: the plan is sized to the remaining hackathon window (umbrella tasks 2-6, roughly 5 hours); anything exceeding it is explicitly cut to a named follow-up todo in the plan's cut-list, never silently included; the two H7 proofs (fixture full-cycle + real ticket #69 to awaiting_merge) are the plan's terminal DCs.
  plan.md "Task → design § → AC → hour-bucket map" pins T2-T6 to shape's H1:30-7:00 (~5.5h, "roughly 5 hours"); "Cut-list" names 3 explicit v0-narrowings (global multi-epic advance scan, rollup cost field stays n/a, no launchd installer script) with follow-up todos, none narrowing an AC; T7 names both terminal proofs — fixture fullcycle DC-1, and DC-2 against the confirmed-live gh issue #69 (`reverse-recovery-audit-dangling-path`, OPEN + sd:approved, verified live during this plan) reaching `awaiting_merge`, with the entity's still-`draft` shape-confirm precondition flagged as outside this plan's scope.

### Summary

Wrote plan.md: 8 serial atomic-commit tasks (T0 go/no-go precondition, T1 RED fixture suite covering all 9 AC test gates, T2-T6 implementation umbrellas mapped 1:1 to design §1/§3/§4/§5/§6/§7/§8, T7 the two H7 terminal proofs) each with an explicit TDD contract and an exact-command DC. Verified gh issue #69 (`reverse-recovery-audit-dangling-path`) is live, OPEN, and `sd:approved` — the real-proof target — and flagged its still-`draft` shape-confirm as a precondition outside this plan's own scope. Named 3 explicit cuts (multi-epic advance scan, rollup cost field, launchd installer automation) as follow-up todos, none narrowing an AC. Zero SKILL.md edits, zero new captain decisions, all 4 canonical docs recorded skip/defer-to-ship per design §11.

## Stage Report: execute

- DONE: TDD evidence discipline: T1 RED fixture suite is committed with OBSERVED red output before any implementation commit; every T2-T6 commit cites its green run in execute.md; deviations from plan.md get a one-line rationale, never silent.
  354fb88 = RED-only commit (8 files, observed exit=1 "helper missing" each) before 94f2571/20c6a0b/ef2d837/1cd8b1d/dd8c5f5; execute.md cites each green run + 10 one-line deviations.
- DONE: Full local gate before handoff: shell suite + node tests + check-invariants + check-no-dangling + check-version-triple all green in the worktree, git diff --check clean — the execute stage def's pre-handoff self-check is the handoff blocker.
  Shell suite 118/118 files pass; node 79/79; check-invariants exit 0 (C15 on plan.md fixed via <details> wrap, commit 288827e); check-no-dangling PASS; check-version-triple PASS; git diff --check clean.
- DONE: T7 boundary: the fixture full-cycle proof runs inside execute; the LIVE single-entity proof (tick dispatches the reverse-recovery-audit-dangling-path entity, issue #69) is FO-owned at H7 from the project root — do NOT hand-run /ship on that entity from inside execute.
  DC-1 fixture full-cycle GREEN (test-ship-flow-scheduler-fullcycle.sh 6/6: dispatch -> merged -> reconcile -> next-ready); no /ship run on #69 from this worktree — LIVE proof left to FO at H7.

### Summary

Landed the full T0-T7 wedge: controller worktree + sentinel GO (T0), RED-first 8-file fixture suite (T1), tick CLI with lease/eligibility/dispatch (T2), claude-p runner adapter with real spawn receipt (T3), read-only gate report with dual no-write gates (T4), fail-closed reconcile + advance via unmodified reconciler/dag-waves (T5), launchd templates + deterministic rollup + RUNBOOK (T6), and the fixture full-cycle terminal proof (T7 DC-1). Notable deviations (all one-lined in execute.md): a hermetic --gh-provider fixture seam for CI, advance feeding dag-waves --stdin with archive-aware TSV (its --from-workflow mode cannot see _archive), and an is_shaped whitelist that keeps draft entities ineligible. Ready for verify; the live #69 proof (tick --runner gh from project root) is the FO's H7 step.

## Stage Report: verify

- DONE: Independent re-run, not relay: re-ran the scoped quality gate myself in the worktree (not copied from execute.md).
  8 scheduler fixture tests: 8/8 files, 101/101 assertions PASS. Full shell suite: 118/118 files PASS. Node: 79/79 PASS. check-invariants exit 0 (18 OK, 2 pre-existing grandfathered WARNs). check-no-dangling PASS. check-version-triple PASS. All counts independently reproduced, matching execute.md's claims exactly — see verify.md "Independent Quality Gate Re-Run".
- DONE: verify.md carries per-AC (AC-1..AC-6) evidence citations + the DC-keyed UAT table from plan.md; the runtime_uat claim is explicit.
  verify.md "Per-AC Evidence" (6 Verification Claim records) + "DC-Keyed UAT Table" (T0-T7). runtime_uat: fixture full-cycle (6/6) + real adapter spawn receipt (confirmed on disk at `.worktrees/ship-flow-scheduler-controller/.ship-flow-scheduler-receipts/20260719T031741Z-35536-ship-flow-scheduler-t3-sentinel-check.txt`) both declared as fixture-level runtime; LIVE #69 proof explicitly declared "deferred — FO-owned live proof at H7" (not silent).
- DONE: Cross-model challenge per the ship-verify host-opposite dimension: codex challenged the diff (Claude drove execute).
  Ran `codex exec` (codex-cli 0.144.1, gpt-5.6-sol) against the execute diff via the codex-gate locked prompt (hash-verified). NOT degraded. Codex returned 4 [P1] findings, 100% citation-accurate (spot-checked). Verifier reclassified: 3 BLOCKING (frontmatter-only dedup can double-dispatch across a crash window; lease reclaim ignores a live holder + unconditional release violates concurrency=1; fullcycle test's own "next-ready" fixture is itself ineligible, so AC-5's "NEXT tick dispatches" is unproven), 1 WARNING (UNKNOWN gh-state funnels into reconcile, fail-safe direction). Full findings + disposition table in verify.md "Cross-Model Challenge".
- DONE: Hard-rule mechanical spot-checks on the diff.
  All 4 independently re-run: (1) `cmd_report` grep for write/mutation verbs → 0 matches; (2) dual-key eligibility whitelist + manual not-shaped-entity re-run → fails closed; (3) `run_reconcile_action` source read → PROMPT_CAPTAIN and any non-PROCEED/crash → terminal `blocked`; (4) grep for merge-capable calls across all 3 scheduler files → 0 matches. Findings routed via verify.md `route_to: execute` — none inline-fixed here.

### Summary

Independent re-run confirms execute's quality-gate numbers exactly (118/118 shell, 79/79 node, all gates green) and 4 of 6 ACs (AC-2/AC-3/AC-4/AC-6) are cleanly VERIFIED. The cross-model challenge — the reason this dimension exists, since Claude authored execute and cannot adversarially review its own diff — surfaced 3 BLOCKING findings the green test suite structurally cannot catch: crash-before-frontmatter-write double-dispatch risk, a lease-reclaim path that can steal from a still-alive holder (violates the design's own concurrency=1 rule and the RUNBOOK's stated operator invariant), and a full-cycle test whose own "next-ready" fixture would itself fail eligibility on a real third tick. Verdict: **NOT VERIFIED (VETO) — route_to: execute**, all four codex findings tabulated with verifier-owned severity/routing in verify.md. Bad news early: this is not a clean PASS, and the gap is real, not cosmetic.

### Feedback Cycles

- cycle: 1
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-19T09:05:55Z
  verify_artifact: verify.md@07b726c
- cycle: 2
  rejected_stage: verify
  feedback_to: execute
  captain_decision: fix
  routed_at: 2026-07-19T10:02:05Z
  verify_artifact: verify.md@a5aac90

## Stage Report: execute (cycle 2)

- DONE: TDD evidence discipline: T1 RED fixture suite is committed with OBSERVED red output before any implementation commit; every T2-T6 commit cites its green run in execute.md; deviations from plan.md get a one-line rationale, never silent.
  Each of F1-F4 got its own RED commit (observed failing) before its fix commit: F1 825bf62→11d4ce0, F2 a61cbd8→c8b70e6, F4 22e1145→cf83300, F3 abbe540→b2dbb66 (F3's "fix" was fixture-only — no production code changed, see execute.md). Green runs + shellcheck cleanliness cited in execute.md's "Feedback Cycle 1 fixes" section.
- DONE: Full local gate before handoff: shell suite + node tests + check-invariants + check-no-dangling + check-version-triple all green in the worktree, git diff --check clean — the execute stage def's pre-handoff self-check is the handoff blocker.
  Shell suite 118/119 (full 119-file loop, CI=true timeout 90 bash per file); node 79/79; check-no-dangling PASS; check-version-triple PASS; git diff --check clean. check-invariants exits 1 (C11/C12/C14/C15) — verified byte-identical at commit 0a053ec (the pre-cycle-2 dispatch point, before any F1-F4 work), so pre-existing and out of this stage's scope: C11/C12/C15 need verify.md edits (off-limits per this dispatch's own instructions), C14 flags the FO's own dispatch commit grammar (not authored by this ensign). Surfaced explicitly in execute.md rather than silently claimed green.
- DONE: T7 boundary: the fixture full-cycle proof runs inside execute; the LIVE single-entity proof (tick dispatches the reverse-recovery-audit-dangling-path entity, issue #69) is FO-owned at H7 from the project root — do NOT hand-run /ship on that entity from inside execute.
  Unchanged from cycle 1: no /ship run on #69 from this worktree; LIVE proof remains FO-owned.

### Summary

Fixed all 4 verify findings with RED-before-fix TDD evidence per finding: F1 (dedup now also checks a live worktree directory + a live gh lookup keyed by branch, closing the crash-before-frontmatter-write window), F2 (lease reclaim is now liveness-only — never age alone — plus an ownership token on release, and the previously-unbounded reconciler call is now wrapped in `timeout`), F3 (the fullcycle test's leg 3 now proves a real dispatch event for a genuinely-shaped child, fixture-only — no production code needed since the existing dispatch-precedence scan already handles a truly-eligible entity), F4 (an UNKNOWN gh state now short-circuits to a `no-op reason=gh-state-unknown` warning instead of funneling into the reconciler as a spurious PROMPT_CAPTAIN). design.md and RUNBOOK.md updated where the fixes changed a documented contract (lease semantics, no-op reason vocabulary). Full local gate is green except one pre-existing, out-of-my-scope check-invariants gap (verify.md content + an FO dispatch-commit grammar issue) — verified present before this cycle's work started and reported transparently rather than fixed by crossing an explicit boundary or silently declared clean.

## Stage Report: verify (cycle 2)

- DONE: Independently re-run the quality gate and re-verify AC-1 and AC-5 specifically (the two NOT VERIFIED), plus spot-check F2's liveness/token fixtures.
  9/9 scheduler test files (111/111 assertions), full suite 119 files → 118 + the invariants wrapper flipping green post-rewrite (re-run exit 0), node 79/79, no-dangling/version-triple PASS. All four RED commits re-proven red at their own SHAs in a detached worktree. F2 probed first-hand outside the harness (alive-ancient never stolen; wrong-token refused; dead-pid reclaimed). AC-1 and AC-5 now VERIFIED via first-hand probes (crash-window fixtures refuse; fullcycle leg-3 real dispatch).
- DONE: Bring verify.md into invariant conformance (C11/C12/C15); after the rewrite check-invariants fully green.
  verify.md rewritten as the cycle-2 verdict document: `## Panel Coverage` after Verdict, `## Deferred to TODO` final H2, raw 165 lines (evidence in details blocks). `CI=true bash plugins/ship-flow/bin/check-invariants.sh` → exit 0, C11/C12/C14/C15 all OK.
- DONE: Cross-model dimension: scoped codex re-challenge ONLY on the F1-F4 fix diff.
  codex exec (0.144.1, locked prompt hash-verified) on a6601b0..HEAD — NOT degraded. 5 findings (4 P1 + 1 P2), 100% citation-accurate; verifier dispositioned all as WARNING/advisory residuals (strictly narrower windows than the fixed classes, shielded by the live worktree-dir guard / millisecond races), routed to Deferred to TODO with the P1-vs-WARNING disagreement recorded.
- DONE: Write the final verdict with per-AC evidence citations + DC-keyed UAT table + runtime_uat claim.
  Verdict PASS (PROCEED) in verify.md; AC-1..AC-6 all VERIFIED with current-branch SHA citations; DC table in a details block; runtime_uat = fixture-level (fullcycle 8/8 + real spawn receipt) with the LIVE #69 proof declared "deferred — FO-owned live proof at H7".

### Summary

Re-reviewed the execute worker's F1-F4 fixes, not my own work: every RED commit independently re-proven red at its own SHA, every fix probed first-hand beyond the suite (crash-window refusals, lease liveness/token semantics, UNKNOWN no-op). All six ACs now VERIFIED. The scoped codex re-challenge on the fix diff returned 5 genuine but strictly narrower residuals (fail-open gh-error edge behind the worktree-dir guard, CLOSED-state dedup gap, millisecond lease-recovery races, timeout-mid-reconcile exposure) — dispositioned WARNING/advisory with rationale, routed to Deferred to TODO, and the one-line W1/W2 fixes surfaced as an optional FO round-2 bounce. verify.md rewritten to C11/C12/C15 conformance; check-invariants and the archived-corpus wrapper both green post-rewrite. Verdict: PASS (PROCEED).

## Stage Report: execute (cycle 3)

- DONE: TDD evidence discipline: T1 RED fixture suite is committed with OBSERVED red output before any implementation commit; every T2-T6 commit cites its green run in execute.md; deviations from plan.md get a one-line rationale, never silent.
  RED `f655f34` (both W1 + W2 fixtures/assertions, observed 4/34 eligibility assertions failing: 2 for the gh-error stub case, 2 for the CLOSED-dedup case) committed before the fix. Fix `eafa77b` (both one-liners) GREEN: eligibility 34/34. execute.md "Feedback Cycle 2 fixes" cites both RED→GREEN SHAs plus hand-verified before/after JSON event evidence.
- DONE: Full local gate before handoff: shell suite + node tests + check-invariants + check-no-dangling + check-version-triple all green in the worktree, git diff --check clean — the execute stage def's pre-handoff self-check is the handoff blocker.
  Shell suite 119/119 files pass (`CI=true timeout 90 bash` per file); node 79/79; `check-invariants.sh` exit 0 (18 OK, 2 pre-existing grandfathered WARNs — the cycle-1 addendum's C11/C12/C14/C15 FAILs were already resolved by verify cycle 2's rewrite, prior to this dispatch); check-no-dangling PASS; check-version-triple PASS; git diff --check clean; shellcheck clean on both touched files.
- DONE: T7 boundary: the fixture full-cycle proof runs inside execute; the LIVE single-entity proof (tick dispatches the reverse-recovery-audit-dangling-path entity, issue #69) is FO-owned at H7 from the project root — do NOT hand-run /ship on that entity from inside execute.
  Unchanged from cycles 1-2: no /ship run on #69 from this worktree; fullcycle 8/8 unaffected by this cycle's scoped fixes (untouched files); LIVE proof remains FO-owned.

### Summary

Scoped round-2 bounce, fixed ONLY the two WARNING findings verify.md cycle-2 routed to `## Deferred to TODO` and named for an optional fix: W1 (`pr_exists_for_slug`'s real-gh branch fell open to NONE on a `gh pr list` error instead of failing closed to UNKNOWN — fixed by using the command's own exit status instead of `|| true`, mirroring `gh_pr_state`'s existing pattern) and W2 (the live-PR dedup case-arm omitted `CLOSED`, so a closed-unmerged PR didn't count toward duplicate-dispatch exclusion — fixed by adding `CLOSED` to the case arm). Both got their own RED fixture before the one-line fix, both hand-verified beyond the assertion suite. W2 changed a documented contract (design.md §3/§4's "no open/merged PR" phrasing), so design.md was updated to match; §2's reason-code vocabulary itself was untouched (no new/removed code). No other Deferred-to-TODO item (W3-W5, cycle-1 carryovers) was touched, no refactors, no scope growth beyond the two named fixes plus their required doc sync.
## Stage Report: verify (cycle 3)

- DONE: Confirm the two diffs match your finding sites and are fail-closed as specified.
  eafa77b read line-by-line: `pr_exists_for_slug` (:157-165) now splits gh exit-failure→UNKNOWN (fail-closed) from success-empty→NONE via `if ! out=$(gh ...)` — exactly the prescribed mirror of `gh_pr_state`; dedup case-arm (:268-272) now `OPEN|MERGED|CLOSED|UNKNOWN`. First-hand probes (not relayed): stub gh exiting 1 → UNKNOWN; stub gh success-empty → NONE; `pr-closed-live-only-entity` fixture (empty frontmatter, state=CLOSED) → `refusal reason=pr-exists`, no dispatch. design.md §3/§4 wording sync confirmed ("no open/merged/closed PR").
- DONE: Re-run the eligibility fixture test + check-invariants yourself.
  eligibility 34/34 at HEAD; RED re-proven in a detached worktree at f655f34 (30/34 — exactly the four W1/W2 assertions). check-invariants exit 0, 0 FAILs (C11/C12/C14/C15 all OK, re-run after the verify.md cycle-3 edits). Also re-ran unrequested but cheap: all 9 scheduler files green (117 assertions), node 79/79, no-dangling/version-triple PASS, archived-corpus wrapper exit 0, git diff --check clean.
- DONE: Update verify.md — move W1/W2 out of Deferred to TODO into the fixed table with citations, keep C11/C12/C15 conformance, keep the verdict document as cycle-3 final.
  Title now "Verify (cycle 3, final)"; findings table W1/W2 rows marked "FIXED cycle 3 (f655f34→eafa77b)"; W1/W2 bullets removed from Deferred to TODO (W3+W5, W4, carryovers remain); Verdict rewritten as the cycle-3 final PASS; body re-trimmed under the 120-line C15 cap (raw 167/240).
- DONE: Append the verify (cycle 3) stage report with the final verdict.
  This section; final verdict PASS (PROCEED), nothing new beyond W1/W2 scope, no PROMPT_CAPTAIN required.

### Summary

Round-cap confirmation pass, scope held to W1/W2: both one-line fixes land exactly at my cited finding sites, behave fail-closed under first-hand adversarial probes (gh-error stub, CLOSED crash-window fixture), carry genuine RED-before-fix evidence (30/34→34/34), and sync the design.md contract wording. Full gate independently green: check-invariants 0 FAILs, 9/9 scheduler files, node 79/79, dangling/version-triple clean. verify.md is now the cycle-3 final verdict document — PASS (PROCEED); remaining follow-ups W3/W4/W5 + cycle-1 carryovers stay in Deferred to TODO; the LIVE #69 proof remains FO-owned at H7.

## Stage Report: ship

- DONE: PR discipline — compose the PR body ONCE from canonical artifacts (shape.md problem/journey, verify.md UAT table verbatim, execute.md execution log + current-branch commit SHAs, canonical-doc SHAs) into a body FILE; privacy grep + coherence gate on that file BEFORE `gh pr create --base main --body-file`; frontmatter pr: written only after the PR number AND body are confirmed; NO auto-merge — the entity stops at awaiting_merge for the captain's morning gate.
  PR #70 created (`gh pr create --base main --body-file`); privacy grep 0 hits; PR title validated; coherence self-check passed (sections complete, DC table quoted verbatim from verify.md, all 17 cited SHAs resolve). `persist-pr-metadata.sh --expect-body-file` returned `verdict=OK reason=written pr=#70` (number+body both confirmed) before `pr: "#70"` was written to index.md frontmatter (commit 8dc26de). Post-create `check-pr-mergeable.sh --pr "#70"` returned `state_class=dirty` (exit 11) — attempted `git fetch origin main && git rebase origin/main` per Step 6.7; the ONLY conflict is ROADMAP.md's `<!-- section:now -->` table (both this branch and origin/main independently appended a new row after the same anchor line). This is outside `rebase-resolve-additive.sh`'s documented safe surface (later/not-doing/shipped only, NOT now) and outside my ensign authority to hand-resolve a rebase conflict — aborted the rebase (`git rebase --abort`, clean working tree confirmed) rather than guess. **The entity stops at `awaiting_merge` with PR #70 open but DIRTY** — the captain/FO needs to resolve the one-line ROADMAP Now-section conflict (trivially: keep both new rows) before merge, per the morning gate queue.
- DONE: Todo Closeout Digest in ship.md (≤60 body lines) capturing verify.md's remaining Deferred-to-TODO items (W3+W5, W4, cycle-1 carryovers), the two mods missing in both tiers from rra shaping (architecture-canon.md, canonical-doc-sync.md), and plan.md's three named v0 cuts.
  ship.md `## Todo Closeout Digest` (60 lines total, at cap) lists W3+W5/W4/carryovers verbatim from verify.md, independently re-confirms `_mods/architecture-canon.md` + `_mods/canonical-doc-sync.md` absent from both `plugins/ship-flow/_mods/` and `docs/ship-flow/_mods/`, and cites plan.md's cut-list (multi-epic advance scan, rollup cost field, launchd installer) — commit a603fba.
- DONE: Canonical docs patched per design §11's deferred-to-ship list — ROADMAP Now row, ARCHITECTURE carrier-swap decision, PRODUCT capability row; INVARIANTS untouched; every Canonical Doc Action consumed or given explicit skip rationale; release consideration recorded.
  ROADMAP.md (80c31e1), ARCHITECTURE.md (b95cce3), PRODUCT.md (9c8b67a) patched via `patch-map.sh --if-hash --mode=append`; INVARIANTS.md untouched (recorded skip, matches shape/design/plan). ship.md `### Canonical Doc Actions Consumed` covers all 4 plan.md rows. Release call: no plugin.json version bump this ship (repo convention batches bumps into separate `chore(ship-flow): release X.Y.Z` commits; 0.9.0 unchanged across the last 4 merged PRs). **Flag**: `canonical-doc-sync-checker.sh` emits 8 BLOCKERs on `check_plan_canonical_doc_actions` — pre-existing, not introduced here: plan.md's own Source/Action column phrasing ("design §11", "skip (defer to ship)", "INVARIANTS.md (plugin)") doesn't match the checker's strict enum ({spec,design,plan,touched-files} × {update,skip}, exact root-doc names). Editing plan.md — a frozen, already-verified prior-stage artifact — was out of this stage's scope; the top-level `check_doc` calls for all 3 root docs independently PASS.

### Summary

PR #70 opened against `main` with a coherence-gated, privacy-clean body composed once from shape/verify/execute/canonical-doc sources; frontmatter `pr:` written only after both number and body were independently confirmed by `persist-pr-metadata.sh`. All 3 canonical docs patched via CAS-safe `patch-map.sh`; ship.md's Todo Closeout Digest captures every item this checklist named, at the 60-line cap. Independently re-ran the full local gate before touching anything (119/119 shell, 79/79 node, check-invariants 0 FAIL, no-dangling/version-triple/git-diff-check clean) — matches verify cycle-3's numbers exactly. Two things flagged rather than silently resolved: (1) the branch is 50 commits behind `origin/main` (unrelated churn, incl. 3 pre-existing stray commits this branch carries — an already-merged entity's archive bookkeeping, a debrief note, a `.gitignore` line — none touched by this stage), producing a real ROADMAP.md Now-section rebase conflict that is outside the sanctioned auto-resolve surface, so the entity stops at `awaiting_merge` DIRTY rather than force-pushed through a guessed resolution; (2) `canonical-doc-sync-checker.sh`'s strict plan.md enum validation pre-dates and is unrelated to this stage's work. No auto-merge attempted or implied.

CI-fix addendum (post-merge): PR #70's invariants (3 scheduler tests) + doc_impact CI failures root-caused and fixed on this branch — claude-CLI preflight vs. the hermetic runner seam, an unreachable reconcile-PROCEED fixture (the reconciler's own negative fixture reused as if positive) plus an un-gitignored scheduler lease/receipts dir that fail-closes the reconciler's dirty-tree guard in same-repo topology, and the missing doc-sync-context.md rows — full RED→GREEN evidence in execute.md "## CI-fix addendum".
