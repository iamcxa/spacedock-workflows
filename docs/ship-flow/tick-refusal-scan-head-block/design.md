# Fix tick refusal scanning head-block — Design

Design authority for this entity. Resolves the two blocking contract decisions
the FO takeover amendment left open (shape.md §"FO takeover amendment") and
names every existing shell-test assertion that moves. Scope is unchanged:
`plugins/ship-flow/bin/ship-flow-scheduler.sh` only (DC-1); no reconciler,
rollup, adapter, schema, or upstream-binary change.

Verdict: **PROCEED** — both contract decisions resolvable inside the file with
zero existing scheduler-test assertion left contradicting the chosen contract;
one behavior-widening (each dispatch/no-op beat now also emits batched
`refusal` observability records) is compatible with every existing
substring-based assertion and gains new multi-entity fixtures.

## §1 — Contract Decision 1: event cardinality vs one-event-per-tick

**Decision: option (a)** — revise the contract to *"one tick performs exactly
ONE bounded ACTION (reconcile > dispatch > advance > no-op) and emits one
primary event per action taken; a successful reconcile may chain an advance in
the same tick (two action events — existing behavior); a Precedence-2
dispatch-scan beat additionally emits zero-or-more `refusal` observability
records — one per non-eligible, non-deduped entity — BEFORE the beat's primary
event."* Refusal is reclassified from *"a dispatch-scan sub-outcome / one of
the beat's events"* to *"an observability record that is not the beat's
action."*

**The literal "exactly one JSON Lines event" text is already false today
(revision cycle 1):** `run_reconcile_action` emits `reconcile`
(`ship-flow-scheduler.sh:591`) then chains `run_advance_action` (`:593-594`),
which emits `advance` (`:660`) — two events in one tick — and
`test-ship-flow-scheduler-fullcycle.sh:167-169` REQUIRES both in leg 2. The
revised wording above is therefore both the refusal-batching accommodation AND
the first header text true of the shipped reconcile→advance behavior. AC-1/
AC-2/AC-3 are all Precedence-2 dispatch-scan beats with no reconcile leg, so
their fixture assertions below stand unchanged under this rewording.

Rejected (b) aggregate-into-single-event-detail and (c) log-only-batch. Both
would force rewriting AC-1/AC-3 fixture assertions AND break existing tests
(see §4). The decisive constraints:

- **The shape's own AC-1/AC-3 fixtures already presuppose (a).** AC-1 demands
  *"3 distinct `refusal` events (one per entity)"*; (b) aggregation emits ONE
  event carrying a `refusals[]` array — a direct contradiction of "3 distinct
  events." (a) is the only option under which the shape-authored fixtures stand
  as written.
- **(c) log-only breaks the eligibility suite.** `test-ship-flow-scheduler-eligibility.sh`
  captures the tick via `OUT="$("$@" 2>&1)"` (stdout) and asserts
  `"event":"refusal"` is present in `OUT` (L64). `emit_event` writes each line
  to BOTH stdout and `--events-log`. Under (c) refusals go to `--events-log`
  only and stdout keeps the single primary event, so every `run_refusal_case`
  refusal/`outcome=refused` assertion on `OUT` fails. (a) keeps refusals on
  stdout → those assertions stay green.

### Contract-text delta (execute-stage edits, all sites named)

Site 1 — `ship-flow-scheduler.sh` header lines **6–8**:

- L6–8 today: *"One `tick` invocation performs exactly ONE bounded action
  (reconcile > dispatch > advance > no-op, with refusal as a dispatch-scan
  sub-outcome) and emits exactly one JSON Lines event to stdout + --events-log."*
- Revised: *"One `tick` invocation performs exactly ONE bounded ACTION
  (reconcile > dispatch > advance > no-op) and emits one primary event per
  action taken to stdout + --events-log (a successful reconcile may chain an
  advance in the same tick). A Precedence-2 dispatch-scan beat additionally
  emits zero-or-more `refusal` observability records (one per non-eligible,
  non-deduped entity) BEFORE the beat's primary event; refusals are records,
  not the beat's action."*

Site 2 — `ship-flow-scheduler.sh` lines **522–525** (revision cycle 1): the
AC-3b checkpoint comment's rationale cites *"the tick's exactly-one-event-
per-tick contract"*. The DECISION it justifies (ride `blocked` detail, NOT a
new event value) remains correct under the revised contract — checkpoint data
is action detail, not a sanctioned observability record — but the cited
contract name must be updated to the revised wording (e.g. *"the tick's
one-primary-event-per-action contract"*); the rollup-parser half of the
rationale is untouched.

Historical repeats of the old contract text in prior entities'
design.md/index.md are NOT edited — see §5 (historical references).

No schema change: `refusal` and `no-op reason=refusal-deduped` are existing/
additive event+reason strings under `schema: ship-flow-scheduler/v0` (DC-1).

### AC-1 / AC-3 fixture assertions under (a)

- **AC-1** — 3 refusing + 0 eligible → tick emits 3 `refusal` events (one per
  entity, scan order) THEN one `no-op nothing-eligible` (the primary action).
  Assertions: three `"event":"refusal"` lines with the three distinct
  `entity`/`reason` values, one trailing `"event":"no-op".*"reason":"nothing-eligible"`,
  exit 0.
- **AC-3** — 2 refusing + 1 eligible → tick emits 2 `refusal` events THEN one
  `"event":"dispatch"` for the eligible entity (the primary action), in that
  order, one beat. Exit 0.
- **AC-2** — 1 refusing entity, 3 sequential ticks sharing one `--events-log`
  within the window → tick 1 emits `"event":"refusal"`; ticks 2 and 3 emit
  `"event":"no-op"` with dedup marker `"reason":"refusal-deduped"` and NO
  re-emitted `"event":"refusal"` for that entity. A reason CHANGE between ticks
  (e.g. `not-shaped` → `not-sd-approved`) re-emits a `refusal` (real state
  change, DC-4).

## §2 — Contract Decision 2: rollup `interventions` semantics

`cmd_rollup` counts `interventions` per JSONL line: `blocked` +1 and `refusal`
+1 (L817–818), rendered `interventions (blocked + refusal): N` (L835). Batching
multiplies `refusal` lines per beat, so the metric's meaning shifts from
*paused-beats* toward *entity-refusal observations*.

**Decision: pin the current per-line count as intended; its meaning is
"distinct entity-refusal observations," NOT "paused beats." No rollup-code
touch (DC-1 holds semantically, not just mechanically).**

Rationale (why per-line beats count-distinct-`tick_id`):

- The interventions signal answers *"how many entities needed operator
  attention / were not ready."* Pre-fix, only the alphabetically-first entity's
  refusal was ever emitted (66/119 duplicate `not-shaped` beats masked every
  other entity — the finale bug). Per-line counting post-fix makes the metric
  MORE accurate: each distinct entity-refusal is counted, not just the head.
- **Count-distinct-`tick_id` would REGRESS the fix's core value.** Collapsing
  "3 different entities refused this beat" into "1 intervention" re-hides exactly
  the multi-entity visibility the batching fix restores.
- The AC-2 dedup window bounds inflation: a persistently-refusing entity
  contributes ~1 refusal per window (not per 5-min beat), so per-line counting
  does not re-introduce the spam it removed.

### Named pin assertion (Decision 2)

New case in `test-ship-flow-scheduler-rollup.sh`:
`run_multi_refusal_beat_intervention_count_case` — a fixture events log with two
`refusal` lines sharing ONE `tick_id` (plus one `blocked` line) fed to
`rollup`, asserting `- interventions (blocked + refusal): 3`. This pins per-line
(entity-refusal) counting: two same-beat refusals count as 2, disproving the
per-`tick_id` reading (which would render 2). This is the assertion that pins
Decision 2.

## §3 — Mechanism (design-level; implementation contract for plan/execute)

Precedence-2 becomes **two-phase collect-then-act** (AC-3, DC-5):

- **Phase 1 (collect, no side effects):** iterate `list_entities`; keep the
  existing pre-eval `entity_in_backoff` skip for BLOCKED entities (L442,
  unchanged); `evaluate_entity` each survivor. Record the FIRST case-0 path as
  `first_eligible_path` (do NOT dispatch yet, do NOT `return`). For each
  case-1|2 (refusal), apply refusal-dedup (below); if not deduped, append
  `(slug, reason, keys)` to a refusals-to-emit list; if deduped, set a
  `deduped=yes` flag.
- **Phase 2 (act):** emit every collected `refusal` record in scan order. Then
  the single primary action: if `first_eligible_path` set → `run_dispatch_action`;
  else if advance applies → `run_advance_action`; else → `no-op`, with
  `reason=refusal-deduped` when `deduped=yes` and no refusals were emitted, else
  `reason=nothing-eligible`. The lease EXIT-trap (L400) is untouched — one
  `return 0` path preserves the F1/F2 crash-window discipline (DC-5).

**Refusal dedup is POST-eval, reason-scoped, case-1|2-only — NEVER a pre-eval
slug skip.** `entity_in_backoff` broadens to an optional signature
`entity_in_backoff <slug> <events-log> <window> [<match-event> [<match-reason>]]`:
default `match-event=blocked`, no reason → today's exact behavior (backward
compatible; backoff test unchanged). The refusal-dedup call passes
`refusal "$EVAL_REASON"` and returns 0 (deduped) iff the slug's most-recent
event is `refusal` with the SAME reason inside the window. Reads
`--events-log` only (Rule 3, no new store); reuses `BACKOFF_WINDOW_SEC` (3600s),
single window (DC-3 recommendation accepted); keys on `(slug, reason)`, stops at
`reason` (DC-4 recommendation accepted — no `keys` caching).

**Why pre-eval slug-scoped refusal skip is forbidden (disproof-backed):** the
naive reading of AC-2 ("extend `entity_in_backoff` to match `event=refusal`" as
a loop-top slug skip) breaks `test-ship-flow-scheduler-fullcycle.sh`. Trace: in
**leg 1** the child refuses (case-1, `not-shaped` — child fixture is
`status: draft`) while the parent dispatches — under batching, leg 1 now writes a child `refusal` line to
the shared `events_log`. In **leg 3** the child is made eligible (case-0) and
must DISPATCH. A pre-eval slug-scoped refusal skip would see the child's leg-1
refusal still inside the 3600s window and `continue` past it → leg-3's
`assert_contains "leg 3: dispatch event for the child"` fails. Post-eval +
case-1|2-only dedup never touches a case-0 entity, so the child dispatches.
This is the design's load-bearing constraint; the plan MUST honor it.

## §4 — Test surface delta (every moving/compatible assertion named)

**Existing scheduler-test assertions verified compatible (no edit; substring/
regex matches survive the added `refusal` records + trailing primary event):**

- `test-ship-flow-scheduler-eligibility.sh`
  - `run_refusal_case` L63–66 (not-shaped / issue-closed / not-sd-approved):
    each single-entity beat still emits its one `refusal` on stdout, so
    `"event":"refusal"`, `"reason":<code>`, `"outcome":"refused"` stay green.
    **Behavior note:** the terminal event for these beats changes from `refusal`
    (today's final event) to a trailing `no-op nothing-eligible`; no existing
    assertion asserts refusal is the ONLY/terminal event, so none contradicts.
  - `run_dedup_case` L78–80, `run_live_worktree_dedup_case` L97–99,
    `run_live_pr_dedup_case` L115–117, `run_gh_error_fail_closed_case`
    L161–163, `run_closed_pr_live_dedup_case` L179–181: all assert
    `'"event":"(refusal|no-op)"'` + a `reason` — the case-2 refusal record still
    carries `worktree-exists`/`pr-exists`; green.
  - `run_eligible_case` L192–194: single eligible entity, no refusals; dispatch
    unchanged; green.
- `test-ship-flow-scheduler-backoff.sh` — `entity_in_backoff` default (blocked)
  path unchanged; `run_head_block_skip_past_case` L163–166 and
  `run_window_expiry_case` L190–192 green.
- `test-ship-flow-scheduler-fullcycle.sh` — leg-1 L144–145 (parent dispatch,
  now preceded by a child `refusal` line — substring green), leg-2 L167–169,
  leg-3 L195–196 (child dispatch — green ONLY because dedup is post-eval +
  case-1|2-only per §3). This file is the canary for the pre-eval-skip
  regression; the plan must run it.
- `test-ship-flow-scheduler-idempotence.sh` — lease-held `no-op` and
  replay-idempotence unrelated to refusal cardinality; unchanged.
- `test-ship-flow-scheduler-reconcile.sh` — reconcile/blocked/advance/no-op
  assertions (L156–272) on non-refusal beats; unchanged.
- `test-ship-flow-scheduler-rollup.sh` — `run_determinism_case` L46–48 asserts
  presence of `dispatch`/`blocked` + byte-identical; no interventions COUNT
  assertion, so the existing fixture (`events-2026-07-19.jsonl`, one refusal
  line) does not contradict Decision 2.

**No existing scheduler-test assertion pins "exactly one event per tick" as a
line count** (verified: no `wc -l`/`grep -c`/`-eq 1` over events.jsonl in any
`test-ship-flow-scheduler-*.sh`). The one-event contract is prose-only (script
header + archived l3 design), so Decision 1 moves prose, not a test assertion.

**New test surfaces the plan authors:**

- New file `test-ship-flow-scheduler-refusal-batch.sh` (or extend the backoff
  file) with a `three_entity_workflow` helper mirroring `two_entity_workflow`
  (L123–130 of the backoff test):
  - AC-1 case: reuse fixtures `not-shaped-entity` + `issue-closed-entity` +
    `not-approved-entity` → assert 3 `refusal` + 1 `no-op nothing-eligible`,
    ordered, exit 0.
  - AC-3 case: reuse `not-shaped-entity` + `not-approved-entity` +
    `eligible-entity` → assert 2 `refusal` + 1 `dispatch`, ordered, exit 0.
  - AC-2 case: one entity (`not-shaped-entity`), 3 sequential ticks sharing one
    `--events-log` → tick1 `refusal`, ticks2/3 `no-op reason=refusal-deduped`,
    no refusal re-emit; plus a reason-change sub-case (mutate frontmatter so the
    reason changes) asserting a fresh `refusal`.
  - Fixtures are the EXISTING eligibility fixtures reused; no new fixture-entity
    authoring required beyond the multi-entity workflow helper.
- New rollup case `run_multi_refusal_beat_intervention_count_case` (§2) + its
  two-same-tick_id-refusal fixture log.

## §5 — Shape DC reconciliation & canonical-doc impact

- **DC-1 (structural):** honored — all edits inside `ship-flow-scheduler.sh`;
  no schema/reconciler/adapter/rollup-code change. `refusal-deduped` is a new
  `no-op` reason string, not a schema field.
- **DC-2 (no retry):** honored — dedup is skip-emit (observability suppression),
  the beat still spends its one action on the primary event; reason-change
  re-emits (new info, not retry).
- **DC-3 (single window):** accepted single `BACKOFF_WINDOW_SEC`.
- **DC-4 (`(slug, reason)` key, stop at reason):** accepted.
- **DC-5 (two-phase preserves lease/EXIT trap):** honored — single `return 0`
  in Phase 2, EXIT trap unchanged.
- **Contract supersession recorded (revision cycle 1) — "events log is
  audit-only, never read to decide":** the l3 design authority states the
  events log is *"never a decision input"* (`docs/ship-flow/l3-scheduler-tick/design.md:73-76`)
  and *"audit-only and is never read to decide"* (`:139-150`). §3's refusal
  dedup reads the log as a decision input, which contradicts that text — but
  the contract was FIRST superseded by tick-hardening AC-4 (shipped, PR #81):
  `entity_in_backoff` already reads `events.jsonl` to decide skip-past
  (tick-hardening design.md DC-2 "backoff from events, no store" — HELD). This
  design extends that same already-superseded reading to `refusal` events; the
  narrowed surviving contract is *"the events log is the tick's only derived
  cache; it is read solely for skip-past/dedup windows (never to compute
  eligibility or mutate canonical state), and remains the rollup's only
  input."* Recorded here as the design revision note; also folded into the
  INVARIANTS candidate below. Not a mechanism change.
- **Historical references (NOT edited — snapshots per repo precedent):** the
  superseded one-event/audit-only contract text repeats in
  `docs/ship-flow/l3-scheduler-tick/design.md:73-76,139-150`,
  `docs/ship-flow/tick-hardening/design.md:108-115,203`, and
  `docs/ship-flow/tick-hardening/index.md:70-83`; all are superseded by this
  revision and stay as-is.
- **INVARIANTS.md:** propose adding one invariant candidate — *"refusal is a
  scan-time observability record, not the tick's bounded action; a beat's ONE
  action is reconcile|dispatch|advance|no-op; the events log is read only for
  skip-past/dedup windows, never to compute eligibility."* Recommended
  (freezes Decision 1 + the supersession above against future drift); deferred
  to ship if the captain prefers design-doc-only.
- **ARCHITECTURE.md / PRODUCT.md / RUNBOOK:** no change (dedup transparent,
  schema stable). Canonical-doc delta is NOT zero, however: this design.md
  carries two durable contract revisions (one-event-per-tick rewording §1;
  audit-only supersession above) as the live scheduler design authority's
  revision notes.
- **ROADMAP.md:** Now-row add + Later-row remove per shape (ship-stage).
