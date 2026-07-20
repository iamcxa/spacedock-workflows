# Fix tick refusal scanning head-block — Shape

### Summary

Fix the L3 scheduler tick's Precedence-2 dispatch scan so a beat's refusals do
not consume the beat's single bounded action and do not spam the events log:
**batch-emit refusals as scan-events (no-op dispatch candidates), then still
dispatch the first eligible entity in the same beat, and dedup refusals by a
short window** — mirror of the AC-4 blocked-backoff shape from tick-hardening,
extended to the sibling refusal class. This is a **seam-hardening** entity, not
greenfield: every abstraction the fix touches already exists in
`plugins/ship-flow/bin/ship-flow-scheduler.sh` (`entity_in_backoff` + backoff
window; the Precedence-2 `first_refusal_*` capture; the `emit_event refusal`
shape). The work is fixing/wiring EXISTS_BROKEN seams inside one file.
Size **S**; appetite bounded to one worker session.

### Captain articulation — already given, NOT re-asked

- **Hackathon-2 GO + bulk attestation**「原則上是都核准」(2026-07-20; issue #82 is
  R2 of the batch-approved routing R2→R1→roborev→#75→split-root, per the issue
  body). This is committed work; shape does not re-open the pitch.
- **Root-cause framing captain gave** on issue #82 + entity body: refusals
  should be scan-events (batch-emit) not the beat's action; add a refusal
  dedup window. This shape honors that framing verbatim; the acceptance
  criteria are the three seams the captain named.

### Problem — reproduced live, cited evidence

The live launchd tick ran every ~5 minutes from 2026-07-19T23:36:32Z through
2026-07-20T02:02:18Z (the hackathon-2 finale window) and emitted a monotonous
sequence of `refusal` events on `2-deterministic-manual-adopter-routing` with
reason `not-shaped`, with only two `blocked reconciler-error` events on
`missing-canonical-mods` breaking the pattern (`.ship-flow-scheduler-events.jsonl`
tail, `.worktrees/ship-flow-scheduler-controller/`). Every beat produced
exactly one event and never a `dispatch` — the tick's "single bounded action"
was consumed by re-emitting the same refusal.

Reproduced deterministically in the current worktree with a hermetic run
against the live entity fixtures (2026-07-20T02:09:25Z, run recorded to
`/tmp/test-tick-events2.jsonl`): seeding the events log with a recent
`blocked entity=missing-canonical-mods` (so Precedence-1 skips it via
`entity_in_backoff`) and re-running `ship-flow-scheduler.sh tick ... --dry-run`
emits exactly one event — `refusal entity=2-deterministic-manual-adopter-routing
reason=not-shaped`.

**Layer trace (EXISTS_BROKEN, reverse-recovery):**

| Seam | State | Evidence |
| --- | --- | --- |
| Refusal event shape (`refusal ... reason detail`) | WORKING | `ship-flow-scheduler.sh:465-469` |
| Precedence-2 scan iteration order | WORKING (alphabetical via `list_entities` sort) | `ship-flow-scheduler.sh:144-150` |
| Refusal batching (all-scan-emit vs first-capture-only) | **EXISTS_BROKEN** — only the FIRST refusal is captured and emitted; downstream refusals are silently discarded even for observability | `ship-flow-scheduler.sh:437,456-460,465-470` |
| Refusal dedup / backoff cache | **EXISTS_BROKEN** — `entity_in_backoff` matches ONLY `event=blocked`, not `event=refusal`, so a repeat refusal on the same entity is un-cached and re-emitted every beat | `ship-flow-scheduler.sh:128-140` (line 135: `[ "$event" = "blocked" ] || return 1`) |
| Same-beat first-ready dispatch | WORKING structurally (loop already `return 0`s on case 0) but semantically FRAGILE — refusal and dispatch are ordered by the scan; a scan that "consumed the beat" on the first refusal branch is the observability leak that misled the finale's root-cause reading | `ship-flow-scheduler.sh:438-463` |
| Backoff window seam (`BACKOFF_WINDOW_SEC=3600`) | WORKING (reusable for refusal dedup) | `ship-flow-scheduler.sh:390` |

None are MISSING → no greenfield, no new canonical store, no new schema.
Fix scope is bounded to `ship-flow-scheduler.sh` (Precedence-2 loop body +
`entity_in_backoff`) + one new fixture test per new behavior.

### Concurrent finding — out-of-scope for THIS shape, surfaced for the FO

The finale's ndgqp block was NOT caused by the batching/dedup bug — it was
caused by `evaluate_entity` refusing `no-dangling-guard-qualifier-precision`
with `EVAL_REASON=dor-stale-shape` (verified via `bash -x` trace 2026-07-20T02:10Z:
`EVAL_KEYS={"shaped":true,"issue_open":true,"sd_approved":true,"dor":false}`).

**Root cause:** `dor_pass()` (`ship-flow-scheduler.sh:264-267`) requires a
non-empty `shape.md` sidecar file; ndgqp keeps its shape content in `index.md`'s
body (per this workflow's `status: shape` + body convention), with no `shape.md`
file — so DoR fails and the entity is refused every beat.

**Why it looked like the batching bug in the finale:** with ALL refusal events
suppressed except the alphabetically-first (`2-deterministic-manual-adopter-routing`),
ndgqp's `dor-stale-shape` refusal was silently discarded — the batching fix
alone would have made this visible in the events log the moment ndgqp was
scanned. Fixing batching+dedup restores that visibility even without altering
DoR semantics.

**Recommended follow-up (NOT this entity):** file a todo
`scheduler-dor-gate-accepts-inline-shape` — broaden `dor_pass()` to accept
either a `shape.md` sidecar OR `status: shape|design|plan|execute|verify|review|ship`
(a superset already used by `is_shaped()`) with a non-empty `index.md` body.
Deferred here to preserve the "scheduler.sh fix only; no tick controller
refactor" boundary the FO drew — the DoR contract is a design-authority
question deserving its own shape. **FO decision needed:** proceed with
batching+dedup only (this shape's scope), or expand to also fix DoR in the
same wedge? Recommendation: keep separate — small, sharp, testable.

### AC-2 probe — deferred (no gating decision on it)

Unlike tick-hardening (which needed the AC-2 probe to choose between launcher
spawn vs raw `claude -p`), this entity has no analogous branching decision.
All three ACs below live inside `ship-flow-scheduler.sh` and one existing
`entity_in_backoff` helper; no cross-boundary transport / plugin / plist
question hangs on any probe result. Design is trivial-pass on this axis.

### Acceptance criteria (mechanism paired to the value it protects)

Each AC's *prevents* is the value measure — a specific observed finale symptom
that cannot silently recur.

- **AC-1 — Refusals batch-emit before any dispatch decision.** The
  Precedence-2 scan visits every non-in-backoff entity, calls `evaluate_entity`
  on each, and captures `(path, reason, keys)` for every case-1/case-2 outcome
  (not just the first). All captured refusals emit as `refusal` events BEFORE
  the tick returns — even when a same-beat dispatch is taken. *Prevents:* the
  finale's observability leak, where ndgqp's real `dor-stale-shape` refusal
  was silently discarded because `2-deterministic-manual-adopter-routing` was
  captured first (verified `bash -x` trace 2026-07-20T02:10Z).
  **Verified by:** fixture test — 3 refusing entities + 0 eligible → tick
  emits 3 distinct `refusal` events (one per entity), one
  `no-op nothing-eligible`, in that order.

- **AC-2 — Refusal dedup window (skip-past, never retry).** A refusal is
  cached the same way a blocked event is: subsequent ticks within a bounded
  window skip the entity via `entity_in_backoff` (extended to match both
  `event=blocked` AND `event=refusal`). The window is reason-scoped: if the
  refusal reason CHANGES on the next scan (e.g. `not-shaped` →
  `not-sd-approved`), the entity re-emits (real state change, not spam).
  Dedup key = `(slug, reason)`. *Prevents:*
  `.ship-flow-scheduler-events.jsonl` finale spam (30+ identical `not-shaped`
  refusals for `2-deterministic-manual-adopter-routing` between 23:36 and
  02:02, a beat every 5 min for 2h25m of dead events).
  **Verified by:** fixture test — 1 refusing entity, 3 sequential ticks
  within the window → tick 1 emits `refusal`, ticks 2+3 emit `no-op`
  (dedup-hit) with a machine-readable dedup marker.

- **AC-3 — First-eligible dispatch in the same beat.** Even when refusals
  exist, the tick still dispatches the first case-0 entity encountered in
  the scan (structurally preserved from the current implementation, but now
  provably decoupled from refusal emission — the refusal batch is emitted
  regardless of whether a dispatch happens). Ordering: emit ALL scan-refusals,
  THEN dispatch. Rationale: refusals are observability records, not actions;
  a dispatch is the beat's actual action. The scan's `return 0` on case 0
  is replaced by a two-phase pattern (collect refusals + first eligible path
  in phase 1; emit refusals then run dispatch in phase 2).
  *Prevents:* the beat starvation class if a future entity gets
  `worktree-exists` refused while another is eligible — today the eligible
  one still dispatches, but ONLY because the scan happens to `return 0`
  before observability is emitted; the fix makes the invariant explicit and
  test-pinned.
  **Verified by:** fixture test — 2 refusing entities + 1 eligible → tick
  emits 2 `refusal` events + 1 `dispatch` event, in that order, in one beat.

### Design constraints (typed — hand-off to design; affects_ui: false)

- **DC-1 (structural)** — All three ACs live inside `ship-flow-scheduler.sh`;
  no new file, no schema change to `.ship-flow-scheduler-events.jsonl`
  (`schema: ship-flow-scheduler/v0` unchanged), no new canonical store, no
  change to `merged-pr-closeout-reconciler.sh` or `scheduler-runner-adapter.sh`.
  **Rationale:** Rule 3 (daemon owns no state of record) + FO scope boundary
  ("scheduler.sh fix only; no tick controller refactor or rollup changes").
- **DC-2 (behavioral)** — AC-2 dedup MUST NOT violate Rule 4 (no retry).
  Skip-past on `(slug, reason)` match ≠ retry; the tick spends its one
  action on the NEXT candidate (including refusal-scan of other entities).
  A reason CHANGE re-emits (that is new information, not a retry).
  **Rationale:** the archived design's "blocked is a *successful* tick"
  principle extended to refusal.
- **DC-3 (interface)** — Refusal dedup reuses `BACKOFF_WINDOW_SEC` (3600s)
  and `entity_in_backoff` (broadened match). Design decides: single window
  vs a separate `REFUSAL_DEDUP_WINDOW_SEC` (rationale hint: single window
  keeps the tunable surface at one; separate window lets refusals dedup at
  a shorter cadence than blocked-backoff, useful if refusal reasons are
  correctable in-session). **Recommendation:** single window (KISS); revisit
  if operator feedback shows staleness. **Rationale:** keep the tunable
  surface small.
- **DC-4 (behavioral)** — AC-2 dedup key is `(slug, reason)`, NOT slug alone.
  The events log ALREADY carries `reason` in the top-level `reason` field
  of every `refusal` event; `entity_in_backoff` today reads only `event`.
  The fix reads `reason` too (via the same
  `sed -n 's/.*"reason":"\([^"]*\)".*/…/p'` pattern used for `event`).
  Design decides whether to also cache `keys` (finer-grained diff signal)
  or stop at `reason` (coarser but sufficient). **Recommendation:** stop at
  `reason` — `keys` diffs are captured by the reason transitions already
  (`not-shaped` → `dor-stale-shape` → `not-sd-approved` are distinct reasons
  the classifier emits).
- **DC-5 (structural)** — The two-phase pattern in AC-3 (collect then act)
  MUST preserve the existing lease/EXIT-trap discipline:
  `scheduler_lease_release` runs on EXIT regardless of which branch is
  taken. **Rationale:** crash-window fixes (F1/F2 from tick-hardening
  cycle-1) stay valid; no new crash windows introduced.

### Size, appetite, out-of-scope

- **Size:** S (three narrow edits inside one file + one broadening of
  `entity_in_backoff` + a handful of fixture tests; no new abstraction, no
  new schema).
- **Appetite:** one worker session (shape→design→plan→execute→verify→
  review→ship). Sizing implication: design is trivial-pass on transport /
  plugin / plist axes; plan is one wave of 3-4 tightly-coupled edits +
  fixture tests; no cross-domain fan-out; no upstream binary changes.
- **Out of scope (deferred without loss):**
  - **Broadening `dor_pass()`** to accept inline-shape entities (the ndgqp
    finale block's real root cause). Filed as a follow-up recommendation
    (see "Concurrent finding" above) — deserves its own shape because it
    changes the DoR contract.
  - **Reconciler `closeout-review-missing` fix** — that is the R1 sibling
    entity (`reconciler-review-artifact-assumption`), not this one.
  - **Rollup changes** — FO scope boundary explicitly excludes them; the
    rollup awk in `ship-flow-scheduler.sh:810-840` already counts
    `refusal` events under `interventions` and needs no touch.
  - **Upstream `spacedock` binary changes** — the scheduler is a shell
    script in `plugins/ship-flow/bin/`, NOT a Go command in the `spacedock`
    binary (verified: `strings /opt/homebrew/Caskroom/spacedock/0.25.0/spacedock`
    has no `scheduler` / `tick` / `reconcile` command symbols; the launchd
    plist's `ProgramArguments` invokes `ship-flow-scheduler.sh` directly).
    All fix work lands in this repo.
  - **Events schema changes** — `schema: ship-flow-scheduler/v0` stays; the
    new dedup-hit marker (if design chooses to emit one) can be a new
    `event=no-op` `reason=refusal-deduped` variant, no schema bump.

### ROADMAP `now` row intent

- Add to **Now**: `| tick-refusal-scan-head-block | Fix tick refusal scanning
  head-block | shape |` (committed hackathon-2 R2 per issue #82 batch
  approval).
- **Move from Later to Now:** `tick-refusal-scan-head-block` (row 40) — this
  entity was ROADMAP `Later` at shape start; the batch-approval and
  hackathon-2 finale evidence promote it.
- **Keep in Later:** `reconciler-review-artifact-assumption` (R1, sibling —
  next session's next ticket, per today's debrief What's Next §2).

### Canonical-doc impact

- **ROADMAP.md** — Now-row add + Later-row remove (above). Doc-impact block
  required at ship.
- **Scheduler design authority** (`docs/ship-flow/_archive/l3-scheduler-tick/`
  is archived; the live authority is `ship-flow-scheduler.sh` inline
  comments + shape.md files of the two hardening entities). This entity
  DOES add a design chunk (refusal batching, dedup key semantics, two-phase
  scan) — design stage decides whether to author
  `docs/ship-flow/tick-refusal-scan-head-block/design.md` as the durable
  delta (recommended) vs update the archived l3 design.md in-place (rejected
  — archived design docs are historical snapshots, not amended).
- **INVARIANTS.md** — no invariant change proposed. The existing Rule 3
  (no new canonical store) and Rule 4 (no retry) already constrain the fix;
  no new invariant is needed. Design MAY propose adding one on the
  "refusal is a scan-event, not the beat's action" semantics if it wants
  to freeze that as an invariant vs a design-doc decision; deferred as a
  candidate.
- **ARCHITECTURE.md** — no scheduler section exists today; this entity does
  NOT add one.
- **PRODUCT.md** — no product-surface change.
- **RUNBOOK** — no operator-facing change (dedup is transparent; the
  `.ship-flow-scheduler-events.jsonl` schema does not change; rollup counts
  unaffected).

### FO takeover amendment — 2026-07-20 (session 2, captain-directed)

Captain directive: 「幫我關掉它，你接管」 (2026-07-20, after the parallel-session
collision). This amendment supersedes nothing above — the shape's evidence and
ACs stand (independently cross-checked by a second L0 subagent + fresh-sonnet
cross-review, verdict PROCEED). It ADDS two design-stage obligations the shape
left unresolved:

- **Open contract decision 1 — event-cardinality vs the one-event-per-tick
  contract (BLOCKING for design; do NOT trivial-pass this axis).**
  `ship-flow-scheduler.sh` L1-14 header (live authority) states one tick
  "performs exactly ONE bounded action... and emits exactly one JSON Lines
  event"; the archived l3 design §2/§4 states the same. (Citation
  correction, SO-EM audit 2026-07-20: tick-hardening DC-4 does NOT reaffirm
  it — the real DC-4 (archive tick-hardening/shape.md:115-118) concerns the
  AC-3 checkpoint event value, explicitly leaves extension-vs-distinct-event
  to design, and its rationale is rollup/report parser forward-compatibility.
  An earlier L0 paraphrase fabricated the reaffirming quote and the FO
  propagated it uncorrected; the contract's documented sources are the
  script header and the archived l3 design only.)
  AC-1's fixture (3 refusal events + 1 no-op in one beat) contradicts that
  contract as written. Design must pick and record ONE: (a) revise the
  contract to "exactly one primary ACTION event; refusals are observability
  records" (matches AC-3's rationale; requires updating the script header
  contract text + design.md revision note), or (b) aggregate all refusals
  into the single beat event's `detail` (rejection, if chosen, must rest on
  engineering grounds — e.g. the dedup mechanism's per-entity last-event
  grep and rollup's per-entity signal need one line per refusal — not on a
  precedent claim), or
  (c) batch-write refusal lines to `--events-log` only while stdout keeps the
  single primary event. The choice changes AC-1/AC-3's fixture assertions.
- **Open contract decision 2 — rollup `interventions` semantics under new
  cardinality.** `cmd_rollup` counts `blocked + refusal` per JSONL line with
  no per-tick grouping; batching multiplies refusal lines per beat (before
  dedup shrinks steady-state). "Rollup needs no touch" (Out-of-scope above)
  holds mechanically but silently changes the metric's meaning
  (entity-refusals vs paused-beats). Design must either pin the current
  line-count semantics as intended (record why) or count distinct tick_ids —
  and AC-3's fixture should assert whichever is chosen.

### Reverse-recovery discipline check

- OK Layer trace done (six seams above; three WORKING, three EXISTS_BROKEN,
  zero MISSING).
- OK Proof-of-absence NOT required (no greenfield claim; every seam exists
  in `ship-flow-scheduler.sh`).
- OK Runtime evidence supplied (live events log 2026-07-19T23:36→02:02 +
  deterministic reproduce 2026-07-20T02:09Z).
- OK Disproof hook for each EXISTS_BROKEN classification: refusal-batching
  disprove = `bash -x` trace shows first_refusal captured then subsequent
  case-1s discarded; refusal-dedup disprove = `entity_in_backoff` grep for
  `"event":"refusal"` returns zero; two-phase disprove = the scan's
  `return 0` on case 0 short-circuits the refusal batch emit today.
