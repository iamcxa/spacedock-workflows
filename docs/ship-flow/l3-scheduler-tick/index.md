---
title: L3 scheduler tick — stateless SD scheduler (Step-3 wedge v0)
status: shape
source: captain hackathon contract (.context/l3-hackathon-contract.md, GO 2026-07-19; converged Claude FO + SO-EM + codex/sol panel)
started: 2026-07-19T02:22:05Z
completed:
verdict:
score:
worktree:
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
