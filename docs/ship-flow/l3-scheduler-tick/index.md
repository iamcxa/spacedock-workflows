---
title: L3 scheduler tick — stateless SD scheduler (Step-3 wedge v0)
status: plan
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
