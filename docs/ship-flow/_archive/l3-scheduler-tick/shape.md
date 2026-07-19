# L3 scheduler tick — stateless SD scheduler (Step-3 wedge v0) — Shape

### Summary

Materialize the converged L3 hackathon contract as the durable in-repo spec. The bet: a
stateless, idempotent scheduler tick removes the human as *persistent scheduler* for
already-approved work, driving one `sd:approved` shaped entity to a trustworthy PR-ready merge
queue unattended — while keeping the human as the *merge authority* (no auto-merge). Appetite is
one night (8h). Captain articulation is already given (GO on the converged contract); this shape
does not re-run the Musk audit or re-ask the shaping questions — it freezes the agreed contract
so plan/execute/verify have a single durable authority (the `.context/` source is gitignored and
would otherwise vanish).

### Captain Articulation and Ownership Trail

Provenance: the converged **L3 Hackathon Contract v0** (`.context/l3-hackathon-contract.md`),
converged 2026-07-19 by a Claude FO + SO-EM + codex/sol panel, then given **GO by the captain**
(`source:` frontmatter — `GO 2026-07-19; converged Claude FO + SO-EM + codex/sol panel`). The
captain's articulation is **ALREADY GIVEN**; this shape preserves his decisions verbatim and does
**not** re-open the shaping question loop (Q1/Q2/Q3 are not re-asked — the converged contract is
the answer).

The one decision this build reopens is the **Y-mode un-defer** (always-on daemon). This
un-defers archived entity `#1 pr-feedback-loop`'s Y-mode, deferred 2026-05-14. The captain
reopened it explicitly, verbatim:

> 如果這是必要的，且可以建立足夠信任邊界，我不在意重開 y-mode

This shape records that un-defer as a captain decision, funded by his GO on this build. The
"sufficient trust boundary" he conditions on is delivered by the ten hard rules below —
especially: no auto-merge (Rule 2), daemon owns no state of record (Rule 3), no repair-until-pass
(Rule 4), and the carrier-swap contract that keeps the daemon a dumb deterministic invoker
(Rule 10).

### GCD (greatest common divisor of the captain's asks)

    approved shaped entity → idempotent scheduler tick → bounded headless `/ship` run
    → derived PR-ready queue (gate projection) → human merge → reconcile → next tick

The tick is the atom: deterministic, idempotent, one bounded action per invocation, structured
JSON out, exit. Everything else (launchd tonight, crewdock later) is a *carrier* that invokes the
same atom.

### Problem

Today the human is the persistent scheduler for work that has *already been approved*: after a
captain says "yes, ship this," someone must still babysit each `/ship` run, watch for the PR to
go green, and hand-carry the next entity in the DAG once the prior one merges. That standing
attention is the cost — not the judgment (which the captain keeps), but the *scheduling loop*
around already-made decisions. The Step-3 wedge removes exactly that loop and nothing more: it
does not decide what is worthy (the `sd:approved` label is the captain's attestation), it does not
merge (the human is the merge trigger), and it does not repair failures (a blocked run stops and
waits for morning).

### Acceptance Outcomes (map 1:1 to entity AC-1..AC-6)

The entity file `index.md` carries the canonical, mechanically-testable AC-1..AC-6 with
`Verified by:` fixture commands. This shape does not restate them verbatim; it pairs each with the
value it measures and confirms the 1:1 mapping. Every mechanism outcome is paired with a
value-measuring property, and every AC is proven by a reproducible fixture command (not by
re-reading prose).

| AC | Value outcome (why) | Mechanism outcome (what) | Proof |
| --- | --- | --- | --- |
| **AC-1** | A crash never costs a double-ship or a corrupted queue — the operator can trust replay. | Deterministic `scheduler tick`: exactly ONE bounded action per invocation (dispatch \| advance \| reconcile \| no-op), structured JSON events, exit. | Fixture: replay idempotence + duplicate-dispatch refusal run green. |
| **AC-2** | Zero worker tokens are ever spent on unworthy/unshaped input — the gate fails closed. | Dual-key eligibility (shaped entity AND linked open gh issue labeled `sd:approved`); ineligible → machine-readable reasons, no FO spawn. | Fixture: unlabeled/unshaped entity → refusal event, no spawn. |
| **AC-3** | A hung or failing run cannot melt the budget or silently retry — failure is terminal and visible. | Bounded runner adapter: headless `claude -p "/ship <entity>"` with explicit workdir/timeout/env; failure/timeout → terminal `blocked` receipt, no daemon retry, no fresh-team substitution. | Adapter fixture (stub runner) + one real sentinel spawn log. |
| **AC-4** | The morning queue is trustworthy *because* it is derived, not a ledger someone can forge or drift. | Read-only gate projection report: entity, exact PR head, verify verdict, GitHub checks, cross_model coverage — from canonical sources; no writable gate ledger; no auto-merge path. | Generated report from fixtures + grep proving no state writes. |
| **AC-5** | The captain's merge is the only thing that advances the DAG — continuation is automatic but never recursive/inline. | Post-merge: `merged-pr-closeout-reconciler.sh` (any `PROMPT_CAPTAIN` → terminal `blocked`), recompute ready set via `dag-waves.sh --ready`, NEXT tick dispatches next entity. | Fixture full-cycle: dispatch → PR-ready → merged → reconcile → next-ready. |
| **AC-6** | The daemon is a carrier, not an owner — it can be swapped (launchd → crewdock) without moving any authority. | launchd carrier on interval + 23:55 deterministic daily rollup (dispatches, durations, gate waits, failures, costs, interventions); recovery runbook; daemon owns no canonical state, never mutates prompts/routing/budgets/policy. | plist present + rollup from fixture events + runbook file + grep proving tick state is derived-cache only. |

### Appetite

**One night (8h).** This is a hackathon wedge (v0), not a multi-week program. The hour-by-hour
plan below fits the vertical primitive → contract freeze → tick → adapter → projection →
reconcile → carrier → two proofs inside the 8h box, with a hard go/no-go at H0:45.

### Hard Rules (v0) — durable contract

Materialized verbatim from the converged contract so plan/execute/verify inherit one authority:

1. **Eligibility (dual-key):** entity must be shaped AND linked to an open gh issue currently
   labeled `sd:approved`. Daemon scans SD entities first; GitHub only validates label/PR state.
   Raw/unlabeled tickets NEVER auto-feed. No entity creation from issues.
2. **No auto-merge.** Real runs stop at `awaiting_merge`; captain merge = the trigger. Post-merge
   half proven by fixtures tonight, exercised live after morning merge.
3. **Daemon owns NO state of record.** SD entity frontmatter + receipts canonical; tick state =
   derived, crash-replayable cache. Gate index = derived projection (entity, PR head, verify
   verdict, checks, cross_model coverage) — NOT a writable ledger.
4. **No repair-until-pass.** Verifier failure → `blocked` receipt → stop. Only ship-flow's
   existing bounded feedback cycle; no daemon-level retries or fresh-FO-team substitution.
5. **codex-gate is NOT auto-fired** (its contract forbids it pending the measurement pilot).
   Cross-vendor = ship-verify's existing host-opposite `cross_model_challenge` dimension;
   source-bearing PRs require that coverage before entering the gate queue; DEGRADED stays visible.
6. **Model seats:** FO=opus (hackathon only, not frozen policy); stage workers follow existing
   workflow routing (design=opus, plan/execute/verify/ship=sonnet); deterministic checks =
   scripts. EM = judgment only (existing science-officer-em contract: opus/xhigh), never approval
   machinery.
7. **Debrief:** per-entity = existing ship debrief + deterministic closeout receipt. Daily 23:55 =
   deterministic rollup (dispatches, durations, gate waits, failures, costs, interventions) via
   launchd StartCalendarInterval (runs after wake). Semantic lessons go through harvest-decide
   captain ratification; the daemon never mutates prompts/routing/policy.
8. **State projection:** eligible → leased → running → awaiting_merge → merged → reconciled →
   done; terminal `blocked`. Reconciler `PROMPT_CAPTAIN` output = terminal blocked, never
   auto-cleanup.
9. **Concurrency = 1.** Dedicated non-interactive controller worktree (not a shared Conductor
   tree).
10. **Carrier-swap contract:** the unit is `ship-flow-scheduler tick` — deterministic, idempotent,
    one bounded action per invocation, structured JSON out, exit. launchd invokes it tonight;
    crewdock invokes the same command later. The tick NEVER owns transcripts, park/resume,
    scavenging, or container lifecycle (else we've cloned crewdock).

### Out of Scope — Deferred without loss (tonight's refusals)

Explicitly NOT built tonight, and losing nothing by deferring (each is either a separate approved
surface or a policy that must not be automated at v0):

- **Raw ticket intake** — only SD-shaped, `sd:approved`-labeled entities feed the tick.
- **Auto-merge** — the human merge stays the trigger (Rule 2).
- **Fresh-FO-teams-until-pass / repair-until-pass** — a blocked run stops (Rule 4).
- **Auto codex-gate** — forbidden by its own contract pending the measurement pilot (Rule 5).
- **Helm dependency** — gate surface is a CLI/markdown projection; it swaps to the helm gate index
  only when DRC-3767 round-trip lands.
- **Linear intake.**
- **Crewdock integration** — the plug socket is kept via the carrier-swap contract (Rule 10),
  but no crewdock wiring is built.
- **Semantic nightly learning** — the daily rollup is deterministic counting only; semantic
  lessons route through harvest-decide captain ratification (Rule 7).
- **Frontend-design classifier** — sidestepped by picking a non-UI real-proof ticket tonight;
  default design policy (design artifact first + automated design review; build-first preview only
  for reversible polish) is unchanged.

### EM-drive profile (dispatch-channel default, not a global flip)

Materialized from the contract — this is how the headless tick-dispatched runs behave:

- Tick-dispatched (headless) runs carry `em_drive: on` **by construction**; interactive Conductor
  sessions keep today's behavior. EM drive is a property of the **dispatch channel**, not a global
  toggle.
- Authority source = the entity's OWN shape (captain articulation: problem/bet/boundary +
  out-of-scope). The EM decides freely **within**: no AC/scope change, reversible-in-worktree,
  within appetite/budget.
- The EM **never** decides: scope/AC reinterpretation; consequence-lane or irreversible actions;
  budget overruns; design-direction ambiguity (IA / design-system / brand).
- Every EM decision → a decision record on the entity (SD-backed) for morning
  audit-by-exception.
- Out-of-boundary question → park with durable `open_question` → gate queue (morning batch) →
  next tick resumes. **Two parks on the same entity → EM routes `return`** (shape defect, back to
  shape).

### Input-quality gate (Definition of Ready for autonomous dispatch)

Materialized from the contract — the pre-dispatch DoR that rejects bad input *before* spending
any FO tokens:

- **Mechanical (script, pre-dispatch — reject BEFORE spawning, zero FO tokens):**
  shaped-and-confirmed · testable AC · issue-anchored (issue-anchor-guard) · fresh (shape date,
  referenced code exists) · appetite declared · risk lane tagged.
- **Semantic residue** = the captain's `sd:approved` label (worthiness attestation) — the one
  judgment the machine does not make.
- **Fail** → entity marked `ineligible` with reasons in the morning report; no dispatch.
- Daily rollup counts ineligible/parks per source → intake-quality feedback → Phase-C telemetry
  decides lane widening. **The EM never widens scope to make a vague ticket workable.**

### Hour-by-hour (sol-revised, FO-endorsed) — execution shape

- **H0:00–0:45 — Prove the vertical primitive (go/no-go):** dedicated controller worktree; verify
  gh/spacedock/claude/codex auth; one harmless bounded `claude -p` run returning a parseable
  terminal sentinel. *Fails → stop daemon work, supervised runner instead.*
- **H0:45–1:30 — Freeze contract** (this shape → repo-visible spec) + fixture-first acceptance
  tests for replay + duplicate-dispatch refusal.
- **H1:30–3:15 — Idempotent scheduler tick** (SD entities first; one controller lease; refuse
  double dispatch; structured JSON events).
- **H3:15–4:15 — Runner adapter:** bounded `claude -p "/ship <entity>"` with explicit workdir,
  timeout, env, captured exit/result. Failure → blocked.
- **H4:15–5:15 — Derived gate projection** + morning report (CLI/markdown; zero helm dependency).
- **H5:15–6:15 — Merge reconciliation + auto-advance:** fixtures for
  `merged-pr-closeout-reconciler.sh`; `PROMPT_CAPTAIN` → blocked; then `dag-waves.sh --ready`;
  next TICK launches next entity (never recursive inline execution).
- **H6:15–7:00 — launchd carrier + daily rollup;** recovery runbook (inspect, unlock only when
  proven stale, rerun tick).
- **H7:00–8:00 — Two proofs:** fixture proof of full cycle; real proof = one small non-UI shaped
  `sd:approved` entity reaches `awaiting_merge`. Morning: captain merges; next tick reconciles +
  advances.

### Precedent note

This build un-defers archived entity `#1 pr-feedback-loop`'s Y-mode (always-on daemon), deferred
2026-05-14. The captain is reopening it explicitly by funding this build — his call to make, and
made (see Captain Articulation above; verbatim GO + Y-mode quote). The trust boundary he
conditioned on is discharged by the ten hard rules.

### Proposed real-proof ticket

`reverse-recovery-audit-dangling-path` (ROADMAP `Later`, S, non-UI, mechanical) — already tracked
in ROADMAP.md. Needs a quick shape-confirm + gh issue + `sd:approved` label at kickoff to serve as
tonight's live single-entity proof.

### Canonical and Registry Impact

- **ROADMAP.md:** on the captain's GO (given), this entity moves into `Now` / active-stage
  tracking; the `reverse-recovery-audit-dangling-path` `Later` row becomes tonight's real-proof
  target on kickoff. Do not patch canonical docs during shape — record intent, plan owns the patch.
- **ARCHITECTURE.md:** on ship, add a decision recording the carrier-swap contract — the
  `ship-flow-scheduler tick` is a deterministic, idempotent, stateless atom; launchd (now) and
  crewdock (later) are interchangeable carriers; the daemon owns no state of record and the gate
  index is a derived projection, not a ledger. This is a durable architecture boundary.
- **PRODUCT.md:** on ship, record the new user-facing capability — approved shaped work can reach a
  trustworthy PR-ready merge queue unattended, with the human retained as merge authority (no
  auto-merge) and audit-by-exception via the daily rollup.
- **INVARIANTS.md (plugin):** no invariant change proposed at shape; the hard rules are v0
  contract, not plugin invariants. Flag for design if any rule needs invariant-level pinning.

### Hand-off to Design

- `design_required: true` — this is contract-bearing work (new `scheduler tick` CLI surface,
  structured JSON event schema, gate-projection report format, state-projection vocabulary,
  launchd plist, receipt/reconciler contracts). Non-UI; no visual/IA/brand surface.
- `ui_surfaces: []`
- `open_design_questions:`
  - Exact structured JSON event schema for the tick (fields for dispatch/advance/reconcile/no-op +
    refusal reasons).
  - State-of-record for the derived tick cache: file layout + crash-replay contract (how replay
    reconstructs the single-action decision without a writable ledger).
  - Gate-projection report shape (CLI vs markdown fields) and its no-write guarantee surface.
  - Controller-lease mechanism for concurrency=1 (how a second invocation detects and refuses).
- `open_contract_decisions: []` — the ten hard rules already fix the v0 contract boundary; no
  unresolved contract choice is delegated to plan.
- `pm_framing_output:` the converged L3 Hackathon Contract v0 + the captain's verbatim GO and
  Y-mode un-defer decision recorded above.

### Shape Report

- Mode: **contract-materialization** — captain articulation ALREADY GIVEN (converged contract +
  GO); no interactive Musk audit re-run, Q1/Q2/Q3 not re-asked (per assignment).
- Source materialized: `.context/l3-hackathon-contract.md` (gitignored) → this repo-visible
  shape.md; GCD, 10 hard rules, refusals, EM-drive profile, input-quality DoR, and hour plan all
  absorbed.
- Acceptance mapping: AC-1..AC-6 in `index.md` mapped 1:1 to value+mechanism outcomes; each proven
  by a reproducible fixture command; appetite = one night (8h); out-of-scope = the contract's
  "Deferred without loss" refusals.
- Captain decisions preserved verbatim: GO (`source:` frontmatter) + Y-mode un-defer quote.
- status: passed
- path: shape+materialize
- open_contract_decisions_count: 0
