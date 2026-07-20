# Fix tick refusal scanning head-block — Plan

### Summary

Five atomic, serially-committed TDD tasks against the REAL `origin/main` files
design.md (4ff843f) names, plus the two execute-stage hard conditions the
design-gate review panel (decisions.md, SO-EM + codex CONVERGED, captain
conditional grant) attached. Core mechanism (Task 1) is a single two-phase
rewrite of Precedence-2 in `ship-flow-scheduler.sh`; Tasks 2-5 are the
rollup pin, prose contract-text sync, and the two canonical-doc obligations.
Shape's own appetite note estimated "3-4 tightly-coupled edits"; this plan
carries 5 because the design gate (post-shape) added two execute-stage hard
conditions (INVARIANTS candidate, RUNBOOK.md wording) neither shape nor the
original design draft priced in — flagged here, not silently absorbed. All
five still fit inside the entity's 45m execute budget: Task 1 is the only
multi-RED task (~15-18m); Tasks 2-5 are each a single small, well-precedented
edit (~5-8m).

Baseline verified before authoring this plan: all 8 `test-ship-flow-scheduler-*.sh`
suites green (2026-07-20), matching design.md's own baseline claim.

---

### Contract semantics preserved (grounding, not new decisions)

- **One primary action per tick, successful reconcile may chain advance —
  UNCHANGED.** Precedence-1 (the reconcile loop, `ship-flow-scheduler.sh:404-434`)
  and `run_reconcile_action`'s internal `parent_pitch` → `run_advance_action`
  chain (`:588-591`) are NOT touched by any task below. Only Precedence-2
  (`:436-470`) changes.
- **Refusals are pre-action observability records, not the action —
  design.md §1/§3.** Task 1 batch-emits every scan-time refusal BEFORE the
  beat's one primary action (dispatch, or fall-through to Precedence-3/no-op).
- **Dedup is POST-eval, reason-scoped, case-1|2-only — NEVER a pre-eval
  slug-only skip (disproof-verified, design.md §3).** A pre-eval slug skip
  breaks `test-ship-flow-scheduler-fullcycle.sh` leg 3 (child refuses
  `not-shaped` in leg 1, must dispatch in leg 3 once made eligible). Task 1's
  GREEN mechanics apply dedup only to case-1|2 outcomes, keyed
  `(slug, EVAL_REASON)`, evaluated AFTER `evaluate_entity` runs — never as a
  loop-top skip. Task 1's DC re-runs fullcycle as the canary.
- **Rollup `interventions` stays per-line (`blocked`+`refusal` count, L817-818,
  L835) — no rollup-code touch (DC-1).** Task 2 adds the pin assertion only.
- **Precedence-3 (`--epic` advance fallback) is dead code in production and
  untested today — grepped: zero callers pass `--epic` in any plist or test.**
  Task 1's rewrite therefore cannot regress a live-exercised advance+refusal
  interaction; not a gap, a fact. Noted so no reviewer re-derives this from
  scratch.

---

## Task 1 — AC-1/AC-2/AC-3: two-phase batch-emit + reason-scoped dedup

**Files:** `plugins/ship-flow/bin/ship-flow-scheduler.sh` (`entity_in_backoff`
`:127-138`; Precedence-2 block `:436-470`), NEW
`plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-refusal-batch.sh`.
No new fixture entities — reuses `not-shaped-entity`, `issue-closed-entity`,
`not-approved-entity`, `eligible-entity` verbatim (design.md §4).

Broadens `entity_in_backoff` to an optional `(match-event, match-reason)`
signature and rewrites Precedence-2 as collect-then-act: Phase 1 scans every
entity, records the first case-0 path (does NOT return early), and for every
case-1|2 applies the broadened dedup before queuing a refusal; Phase 2 emits
the queued refusals in scan order, then runs the single primary action
(dispatch > fall through to Precedence-3/no-op).

<details>
<summary>RED / GREEN mechanics</summary>

**New helper `three_entity_workflow`** — mirrors `two_entity_workflow`
(`test-ship-flow-scheduler-backoff.sh:123-130`). New local `assert_before`
helper compares first-match line numbers of two patterns — needed because
AC-3 pins ORDER (refusals before dispatch), which `assert_contains` alone
cannot express.

**RED case 1 — `run_batch_refusal_no_eligible_case` (AC-1):**
`three_entity_workflow not-shaped-entity issue-closed-entity not-approved-entity`
(0 eligible). Run tick with a fresh `--events-log`. Assert: three distinct
`"event":"refusal"` lines carrying `"reason":"not-shaped"` /
`"reason":"issue-closed"` / `"reason":"not-sd-approved"` respectively, one
trailing `"event":"no-op".*"reason":"nothing-eligible"`, exit 0. **Fails
today:** the current loop captures only the FIRST case-1/2 outcome
(`first_refusal_*`, `:437`) and emits exactly one `refusal` line — 2 of the 3
expected lines are missing.

**RED case 2 — `run_batch_refusal_with_dispatch_case` (AC-3):**
`three_entity_workflow not-shaped-entity not-approved-entity eligible-entity`.
Run tick. Assert: 2 `refusal` lines + 1 `"event":"dispatch".*"entity":"eligible-entity"`,
and `assert_before` proves BOTH refusal lines precede the dispatch line, exit
0. **Fails today, and more sharply than a naive reading suggests:**
`list_entities` sorts alphabetically and `eligible-entity` sorts FIRST
(`e` < `n`), so the CURRENT loop's `return 0` on the first case-0 hit fires
on the very first iteration — today's actual output for this fixture set is
1 `dispatch` line and ZERO `refusal` lines (the two refusing entities are
never even scanned this beat). This is the strongest disproof of the
head-block bug this plan writes.

**RED case 3 — `run_refusal_dedup_window_case` (AC-2):** one-entity workflow
(`not-shaped-entity`), 3 sequential ticks sharing one `--events-log`. Assert:
tick 1 emits `refusal reason=not-shaped`; ticks 2 and 3 emit
`"event":"no-op".*"reason":"refusal-deduped"` with NO re-emitted `refusal`
line. **Fails today:** `entity_in_backoff` only matches `event=blocked`
(`:135`), so every tick re-emits the identical `refusal` — this is the
literal finale spam (66/119 duplicate beats).

**RED case 3b — reason-change re-emit (same case, DC-4):** after tick 1,
mutate the SAME fixture copy's frontmatter `status:` (empty) → `status: shape`
via a local `set_frontmatter_field` (copy the pattern from
`test-ship-flow-scheduler-fullcycle.sh:117-123`). No `issue-not-shaped-entity.env`
gh fixture exists, so `evaluate_entity` now yields `EVAL_REASON=issue-missing`
(was `not-shaped`) — verified against `gh_issue_state` (`:167-185`, MISSING
fallback) and the fixture dir listing (no such file). Tick 4 must emit a
FRESH `refusal reason=issue-missing` (real state change, not spam) —
zero new fixture files needed for this sub-case.

**GREEN — `entity_in_backoff` (`:127-138`):** broaden to an optional
`(match-event, match-reason)` signature, defaults preserving today's exact
3-arg behavior at existing call sites. Landed verbatim; see the Task 1
commit for the actual diff.

**GREEN — Precedence-2 rewrite (`:436-470`):** two-phase collect-then-act —
Phase 1 scans every entity with no side effects, queuing every non-deduped
refusal and remembering the first eligible path; Phase 2 emits all queued
refusals in scan order, then the beat's one primary action; falls through
UNCHANGED into today's Precedence-3 block, and the final no-op branches on
`refusal-deduped` vs `nothing-eligible`. A literal transcription of
design.md §3's Phase-1/Phase-2 mechanism — no new decision, only wiring.
Landed verbatim; see the Task 1 commit for the actual diff (execute.md
Task evidence cites the SHA) rather than duplicating it here.

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-refusal-batch.sh`
AND regression canary
`bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-fullcycle.sh`
(leg 3 must still dispatch the child) AND
`bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-eligibility.sh`
AND `bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-backoff.sh`
all still green.

---

## Task 2 — Decision 2: rollup `interventions` per-line pin

**Files:** `plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-rollup.sh`,
NEW `plugins/ship-flow/lib/__tests__/fixtures/ship-flow-scheduler/rollup/events-multi-refusal-beat.jsonl`.

Pins the current per-line `interventions` count (`blocked`+`refusal`, no
`tick_id` grouping) as the intended reading — per-`tick_id` grouping would
re-hide the multi-entity visibility this fix restores (design.md §2).

<details>
<summary>RED / GREEN mechanics</summary>

**RED — `run_multi_refusal_beat_intervention_count_case`:** new static
fixture log (mirrors the shape of the existing
`events-2026-07-19.jsonl` lines) with exactly 3 lines dated 2026-07-20: two
`refusal` events sharing ONE `tick_id` (different entities/reasons) + one
`blocked` event. Run `"$HELPER" rollup --events-log <fixture> --date 2026-07-20`,
assert `- interventions (blocked + refusal): 3`. **This is a NEW file, not a
regression** — there is no code change in this task (DC-1: rollup awk is
untouched), so "RED" here means the fixture+assertion is authored and
verified to produce `3` against the CURRENT (unmodified) `cmd_rollup`
(`:810-840`), proving the semantics are ALREADY per-line and Task 1 does not
need to touch rollup code — the test exists to pin/freeze this reading
against future drift, not to drive a code change.

**GREEN:** none required (mechanical parity only) — confirm `3` is what the
CURRENT awk (`interventions++` on both `blocked` and `refusal`, `:817-818`,
no `tick_id` keying) already produces; if it does not, that is new
information requiring an FO escalation, not a silent code edit (this task's
DC also serves as a live disproof-hook for design.md's claim).

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-rollup.sh`

---

## Task 3 — Contract-text delta, Note 1 (event cardinality)

**Files:** `plugins/ship-flow/bin/ship-flow-scheduler.sh` (header `:6-8`,
AC-3b comment `:522-525`), `docs/ship-flow/l3-scheduler-tick/RUNBOOK.md`
(`:24-25`).

Prose-only sync of the live script's own contract text + the operator
runbook to the revised contract design.md §1 already recorded. No existing
test pins this text as a line count (design.md §4: verified, no
`wc -l`/`grep -c`/`-eq 1` over events.jsonl anywhere in the suite), so this
task has no RED/GREEN pair — DC is a diff review + full regression sweep.

<details>
<summary>Exact text</summary>

- `ship-flow-scheduler.sh:6-8`, replace with design.md §1's "Contract-text
  delta / Site 1" revised paragraph verbatim (one primary ACTION event per
  action taken; reconcile may chain advance; Precedence-2 additionally emits
  zero-or-more `refusal` observability records before the beat's primary
  event).
- `ship-flow-scheduler.sh:522-525`, the AC-3b comment's rationale clause
  `"the tick's exactly-one-event-per-tick contract"` → design.md §1's
  suggested `"the tick's one-primary-event-per-action contract"`. The
  DECISION the comment justifies (checkpoint rides `blocked` detail, not a
  new event value) is unchanged — only the cited contract name moves.
- `RUNBOOK.md:24-25` — `"one JSON line per tick action"` becomes misleading
  once a beat can emit N `refusal` lines + 1 action line (codex cross-vendor
  finding, decisions.md, execute-stage hard condition (B)). Replace with:
  *"one JSON line per tick action, plus zero or more `refusal` observability
  lines per Precedence-2 beat (batched before the action line, see
  ship-flow-scheduler.sh:6-8)."*

</details>

**DC:** `git diff -- plugins/ship-flow/bin/ship-flow-scheduler.sh docs/ship-flow/l3-scheduler-tick/RUNBOOK.md`
shows only these 3 prose edits; full scheduler suite regression sweep (Terminal
DCs below) still green (proves the prose-only nature — zero behavior change).

---

## Task 4 — INVARIANTS.md Principle 18 (folds Note 2) + check-invariants.sh C18

**Files:** `plugins/ship-flow/INVARIANTS.md` (append after `### Principle 17`,
`:610-618`; bump Revision History `:9`), `plugins/ship-flow/bin/check-invariants.sh`
(new `check_refusal_observability_record`, dispatch entry, full-run wiring).

Execute-stage hard condition from the design-gate review panel
(decisions.md, SO-EM: *"adopt INVARIANTS candidate freezing 'refusal = a
scan-time observability record, not the tick's action'"*). Also folds
contract-revision Note 2 (design.md §5's "events log is audit-only, never
read to decide" supersession — first superseded by tick-hardening AC-4,
extended here to refusal-dedup) into the same principle's rule text, per
design.md §5's own instruction: *"folded into the INVARIANTS candidate."*
Mirrors Principle 17 / check C16's exact structure (Rule / Failure mode /
Grep check / Source) — this is boilerplate given that precedent, not new
design work.

<details>
<summary>RED / GREEN mechanics</summary>

**RED:** `bash plugins/ship-flow/bin/check-invariants.sh --check refusal-observability-record`
→ `ERROR: unknown check: refusal-observability-record` (exit 2) — the check
does not exist yet.

**GREEN — `### Principle 18: Refusal is a scan-time observability record, not
the tick's action`** (append after Principle 17, before `## Success-mode
Harvest Lifecycle`):

- **Rule:** *"A scheduler tick's single bounded action is
  reconcile > dispatch > advance > no-op; a Precedence-2 dispatch-scan beat's
  `refusal` events are scan-time observability records emitted BEFORE the
  beat's action, never the action itself. The events log
  (`.ship-flow-scheduler-events.jsonl`) is read only to derive skip-past /
  dedup windows (blocked-backoff, refusal-dedup); it is never read to compute
  entity eligibility or to mutate canonical state, and it remains the
  rollup's only input."*
- **Failure mode:** a future change re-introducing a `return` on first
  refusal (re-collapsing the beat's action into the first refusal) or routing
  new eligibility logic through the events log would silently reintroduce
  the finale's observability-leak class of bug — only the first-encountered
  refusal ever surfaced in production for 2h25m, masking every other
  entity's true block reason — or would turn the audit-only cache into a
  second source of truth for entity state.
- **Grep check (Tier B — text presence, per Principle 16):**
  `check_refusal_observability_record()` greps `INVARIANTS.md` for the two
  rule sentences above (`grep -qF`, mirrors `check_review_surface_shape_not_plan`
  exactly, `check-invariants.sh:1088-1104`); `FIXTURE_INVARIANTS` override
  supported identically.
- **Source:** entity `tick-refusal-scan-head-block` / issue #82 (2026-07-20).
  design-gate review panel (decisions.md) — SO-EM PROCEED 88 + codex
  cross-vendor SAFE, CONVERGED, captain conditional grant.

**GREEN — `check-invariants.sh` wiring:** `check_refusal_observability_record()`
(pattern-identical to `check_review_surface_shape_not_plan`, `:1088-1104`),
dispatch-table entry, full-run wiring, and the `INVARIANTS.md` Revision
History bump — landed verbatim; see the Task 4 commit for the actual diff
rather than duplicating it here.

</details>

**DC:** `bash plugins/ship-flow/bin/check-invariants.sh --check refusal-observability-record`
exits 0 with `OK C18 ...`; full `bash plugins/ship-flow/bin/check-invariants.sh`
(all checks, C1-C18) still exits 0.

---

## Task 5 — Canonical Doc Actions

| Doc | Action | Rationale |
| --- | --- | --- |
| `ROADMAP.md` (this worktree's copy) | UPDATE | Move `tick-refusal-scan-head-block` row 40 from Later → Now (shape.md "ROADMAP `now` row intent"); committed hackathon-2 R2 work, active |
| `docs/ship-flow/tick-refusal-scan-head-block/design.md` | NO FURTHER ACTION | Already carries both durable contract-revision notes (§1 cardinality rewording, §5 audit-only supersession) as of 4ff843f — this plan's Tasks 3/4 propagate those notes into the LIVE script/RUNBOOK/INVARIANTS, design.md itself needs no edit |
| `plugins/ship-flow/INVARIANTS.md` | UPDATE (Task 4) | Execute-stage hard condition from the design-gate panel (decisions.md) — no longer a "defer to ship" option; folds contract-revision Note 2 |
| `docs/ship-flow/l3-scheduler-tick/RUNBOOK.md` | UPDATE (Task 3) | Execute-stage hard condition (B), codex cross-vendor finding — L24-25 wording is misleading post-batching |
| `docs/ship-flow/l3-scheduler-tick/design.md`, `docs/ship-flow/tick-hardening/design.md`, `docs/ship-flow/tick-hardening/index.md` | SKIP (explicit) | design.md §5: historical snapshots, deliberately NOT amended — the superseded text stays as a dated record, this entity's design.md carries the live revision note |
| `ARCHITECTURE.md` | SKIP | No scheduler section exists; this entity doesn't add one (shape.md, unchanged since shape) |
| `PRODUCT.md` | SKIP | No product-surface change — an internal reliability/observability fix |
| `README.md` (root) | SKIP | Zero scheduler/launchd mentions (grepped); not a documented end-user surface |

**Both contract-revision notes accounted for (nothing dropped):**

<details>
<summary>Note → delta-site mapping table</summary>

| Note (design.md §5) | Delta site(s) |
| --- | --- |
| Note 1 — one-event-per-tick → one-primary-event-per-action (accommodates reconcile→advance double-emit + refusal batching) | Task 3: `ship-flow-scheduler.sh:6-8` header, `:522-525` comment, `RUNBOOK.md:24-25` |
| Note 2 — events log narrowed from "audit-only, never read to decide" to "read only for skip-past/dedup, never eligibility/canonical-state" | Task 4: folded into INVARIANTS.md Principle 18's Rule text (no separate script/RUNBOOK edit — design.md §5 names no other live site for this note) |

</details>

**DC:** `git diff` on touched canonical docs shows only the rows above;
`bash scripts/check-no-dangling.sh` and `bash scripts/check-version-triple.sh`
both still pass.

---

## Verify-gate handoff — worker-drafted gate-brief (explicit deliverable)

The design gate used a two-reviewer panel (SO-EM + codex cross-vendor,
decisions.md); the verify gate gets the same treatment. Per dispatch
instructions, **the brief that panel reviews is a worker deliverable, not
FO-authored** — the FO forwards it verbatim, does not compose it (same
logic as decisions.md's design-gate precedent).

**Deliverable (execute/verify-stage worker, NOT this plan stage):** a
`gate-brief` section in `verify.md` (or a note it links to), for the SO-EM +
codex panel:

- The Task 1 mechanism diff (file:line before/after, two-phase collect-then-act)
- Full test evidence: every DC above green, plus the Terminal DCs full
  regression sweep below (dual-env)
- The two execute-stage hard conditions' resolution: INVARIANTS Principle 18
  text (Task 4) + RUNBOOK.md wording (Task 3), confirming both conditions
  the design gate imposed were actually satisfied, not just claimed
- Any residual risk found during execute

---

## Cut-list (named, not silently dropped)

<details>
<summary>3 cut items</summary>

- **Refusal + advance co-occurring in the same beat.** Task 1's rewrite makes
  this newly reachable in principle (old code's `return 0` on any refusal
  used to make Precedence-3 unreachable that beat; the new code lets
  Precedence-3 run after a refusal batch). No dedicated fixture test this
  round: `--epic` is never passed by any plist or existing test (grepped,
  zero hits) — Precedence-3 is dead code in production today, so this
  combination has zero real-world exercise surface pre- or post-fix.
  Deferred as a follow-up test-only task if `--epic` ever becomes live,
  mirroring tick-hardening Task 7's cut-list precedent for an analogous gap.
- **Broadening `dor_pass()` to accept inline-shape entities** (the ndgqp
  finale block's actual root cause) — shape.md's own out-of-scope boundary;
  already filed as `scheduler-dor-gate-accepts-inline-shape` for the FO.
- **Reconciler `closeout-review-missing` fix** — the R1 sibling entity
  (`reconciler-review-artifact-assumption`), not this one.

</details>

---

## Terminal DCs (verify-stage, not execute tasks)

Full scheduler regression + dual-env, per the l3/tick-hardening precedent
(AC-6).

<details>
<summary>Regression commands (normal + CI-sim)</summary>

```
for t in test-ship-flow-scheduler-backoff.sh test-ship-flow-scheduler-eligibility.sh \
         test-ship-flow-scheduler-fullcycle.sh test-ship-flow-scheduler-idempotence.sh \
         test-ship-flow-scheduler-plist.sh test-ship-flow-scheduler-reconcile.sh \
         test-ship-flow-scheduler-report.sh test-ship-flow-scheduler-rollup.sh \
         test-ship-flow-scheduler-refusal-batch.sh; do
  bash "plugins/ship-flow/lib/__tests__/$t"
done
```
Normal env, then repeat identically under CI-sim (no git identity, no
`claude`/`spacedock` on PATH — matches `.github/workflows/ship-flow-invariants.yml:110-118`):
```
env -i PATH=/usr/bin:/bin HOME="$HOME" CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/<each test>.sh
```
Plus `bash plugins/ship-flow/bin/check-invariants.sh` (full, C1-C18) and the
full `test-*.sh` suite once more as the regression sweep for the ~15 other
test files this plan doesn't touch.

</details>

## Post-merge FO handoff (LIVE proof — not a plan/execute/verify task)

The finale bug this entity fixes was only ever observed live under launchd.
Suggested target once merged: let the next real tick cycle run against
`no-dangling-guard-qualifier-precision` (the finale's parked
`dor-stale-shape` block, shape.md's "Concurrent finding") and confirm the
real `.ship-flow-scheduler-events.jsonl` shows its `dor-stale-shape` refusal
surfacing alongside `2-deterministic-manual-adopter-routing`'s
`not-shaped` refusal in the same beat — the actual multi-entity visibility
this fix exists to restore, proven outside the hermetic fixtures above.
