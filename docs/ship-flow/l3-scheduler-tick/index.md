---
title: L3 scheduler tick — stateless SD scheduler (Step-3 wedge v0)
status: execute
source: captain hackathon contract (.context/l3-hackathon-contract.md, GO 2026-07-19; converged Claude FO + SO-EM + codex/sol panel)
started: 2026-07-19T02:22:05Z
completed:
verdict:
score:
worktree: .worktrees/spacedock-ensign-l3-scheduler-tick
issue:
pr:
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
