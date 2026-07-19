# Tick hardening — delegation marker, launcher spawn, time-budget, blocked-backoff — Shape

### Summary

Harden the L3 scheduler tick's spawn seam and scheduling loop so an unattended daemon survives
the four failure classes that surfaced live during tonight's Wave-0 bring-up. This is a
**seam-hardening** entity, not greenfield: every abstraction the six ACs touch already exists
(`scheduler-runner-adapter.sh` spawn + `--env` plumbing, the tick precedence loop, the plist PATH
key, the `events.jsonl` blocked-record). The work is fixing/wiring EXISTS_BROKEN seams, adding no
new canonical store. Time budget is **2h30m for the WHOLE entity** (shape→ship); this shape sizes
plan accordingly and runs the AC-2 probe now to de-risk design.

### Captain Articulation — already given, NOT re-asked

- **hackathon-2 contract GO** (Wave 1): this entity is committed work, not a fresh pitch.
- **Bulk attestation**「原則上是都核准」(2026-07-20): the delegation-marker + launcher-spawn fold
  is captain-directed (see `docs/ship-flow/todos/scheduler-tick-delegation-marker.md` "Captain
  direction (2026-07-20)": fold the runner-spawn upgrade into the same wedge, launcher IF headless
  is *verified* — probe first).

This shape does not re-run the Musk audit or re-open the shaping loop; it freezes the agreed
contract so plan/execute/verify have one durable authority.

### Problem — the seam is proven-broken (reverse-recovery layer-trace)

The L3 tick shipped (PR #70 + hotfix #72) and ran live under launchd tonight. Four EXISTS_BROKEN
seams, each with a real Wave-0 incident:

| Seam | State | Live incident (cited evidence) |
| --- | --- | --- |
| Spawn delegation marker | EXISTS_BROKEN | Tick-spawned `claude -p "/ship <entity>"` cannot mechanically prove tick-delegation vs forbidden hand-dispatch. Live proof blocked on this ambiguity: `.scheduler-events.jsonl:1` (rra-dangling-path `blocked` `run-error` 2026-07-19T11:15:47Z, receipt `20260719T110743Z`). v0 workaround = a decisions.md 30-min-receipt clause. |
| Spawn front-door | EXISTS_BROKEN | Adapter spawns raw `claude -p` (`scheduler-runner-adapter.sh:64`), bypassing the spacedock launcher that owns plugin/env wiring + version gate + session metadata. |
| Timeout budget + resume | EXISTS_BROKEN | Flat `--timeout` (5400s) < a full design→…→ship run; the live proof was killed between execute and verify with no resumable checkpoint: `.scheduler-events.jsonl:2` (`blocked` `run-timeout` 2026-07-19T12:47:15Z). |
| Blocked-backoff (no head-block) | EXISTS_BROKEN | A blocked entity head-blocks the queue: `7-review-surface-shape-not-plan` blocked `reconciler-error` (`closeout-ship-missing`): `.ship-flow-scheduler-events.jsonl:1` (2026-07-19T15:51:24Z). Precedence-1 reconcile returns on the first non-OPEN-PR entity (`ship-flow-scheduler.sh:358 return 0`), so this entity consumes the tick's single action every cycle; no eligible entity behind it is ever reached. |
| Carrier PATH | EXISTS_BROKEN | launchd plist PATH is `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`, but `claude` lives at `~/.local/bin/claude` (→ `~/.local/share/claude/versions/...`). The user-local bin is NOT in the template PATH → silent recur: `.ship-flow-scheduler-tick.err.log:1` "claude CLI not available for --runner gh". |

None are MISSING → no greenfield, no new canonical store. Fix scope is bounded to each seam.

### AC-2 probe — RUN during shape (design decision hangs on it)

**Result: PASS.** The spacedock launcher supports headless `-p` passthrough with a parseable exit.

    $ timeout 180 spacedock claude "Output exactly the token PROBE_OK_7A9D and then stop. \
        Do not use any tools." --skip-compat-check -- -p --output-format text
    spacedock 0.25.0 · launching claude as your first officer
    Workflows: docs/ship-flow …
    Sandbox: available, not enabled (no .safehouse profile)
    claude is your first officer — ask it for the queue and next steps.
    PROBE_OK_7A9D
    === PROBE EXIT CODE: 0 ===          # ran ~3s (15:55:46Z → 15:55:49Z)

Tokens after `--` forward verbatim to `claude` (`spacedock claude --help`), so `-- -p
--output-format text` reaches claude headless. stdout carries a launcher banner (3 preamble lines)
BEFORE the agent output; the adapter's sentinel grep is line-anchored (`^SHIP_FLOW_TERMINAL `,
`scheduler-runner-adapter.sh:74`) so preamble cannot false-match.

**Design decision (AC-2): take the launcher path.** Replace `scheduler-runner-adapter.sh:64`
`claude -p "/ship ${ENTITY}" --output-format text` with `spacedock claude "/ship ${ENTITY}" --
-p --output-format text`. Two design-stage residuals (not shape blockers): (a) version-gate mode
in production — `--skip-compat-check` vs a real installed-plugin gate vs `--plugin-dir`; the probe
used `--skip-compat-check` to isolate transport; (b) launchd PATH must reach `spacedock` AND
`claude` (ties to AC-5). Fallback documented per AC: if the launcher path fails design/verify, raw
`claude -p` stays with the PATH/env requirement pinned by test — never silent.

### Acceptance criteria (absorbed from index.md — mechanism paired to the value it protects)

Each AC's "prevents" is the value measure: the specific Wave-0 incident that cannot silently recur.

- **AC-1 Delegation marker.** Adapter injects `SHIP_FLOW_SCHEDULER_TICK_ID` (env; `--env` plumbing
  already exists `scheduler-runner-adapter.sh:40,54-58`) + a prompt line naming tick id/receipt;
  spawned `/ship` distinguishes tick-delegation mechanically; decisions.md-clause workaround
  retired. *Prevents:* `.scheduler-events.jsonl:1` delegation-ambiguity block. Verified by adapter
  fixture asserting marker presence + delegation-aware prompt line.
- **AC-2 Launcher spawn (probe-gated → launcher).** Probe PASSED, so adapter spawns via
  `spacedock claude … -- -p`; launcher owns wiring + version gate. *Prevents:* env/plugin skew on
  spawn. Verified by recorded probe (above) + adapter test for the launcher path.
- **AC-3 Appetite-scaled timeout + checkpoint.** Timeout derives from the entity's declared time
  budget (generous default when absent); a timeout kill emits a `checkpoint` event naming the last
  completed stage so resume targets the remainder. *Prevents:* `.scheduler-events.jsonl:2`
  unresumable timeout kill. Verified by tiny-budget fixture → timeout → checkpoint names completed
  stage.
- **AC-4 Blocked-backoff (no head-block).** The tick skips recently-blocked entities (backoff state
  derived from existing `events.jsonl` blocked-records — ts+entity already present — no new store)
  and proceeds to the next action. *Prevents:* `.ship-flow-scheduler-events.jsonl:1` entity-7 head-
  block. Verified by fixture: one blocked + one eligible → eligible gets dispatched.
- **AC-5 Carrier PATH pinned.** Plist template PATH includes the user-local bin (`~/.local/bin`)
  where `claude`/`spacedock` resolve (or the requirement is mechanically checked at install).
  *Prevents:* `.ship-flow-scheduler-tick.err.log:1` "claude CLI not available". Verified by plist
  fixture test asserting PATH + RUNBOOK updated.
- **AC-6 Suite green both envs.** Full local gate + the three CI-sensitive tests green in normal AND
  CI-simulated (no identity, no `claude` on PATH). *Value:* the hardening does not itself regress the
  suite. Verified by dual-env run output cited.

### Size, appetite, out-of-scope

- **Size:** M (seam-hardening across one file + tick loop + plist + tests; no new abstraction).
- **time_budget:** 2h30m for the WHOLE entity (shape→design→plan→execute→verify→review→ship).
  Sizing implication: design is trivial-pass (probe already resolved the one open decision); plan
  is one wave of ~5 tightly-coupled edits + tests; no cross-domain fan-out.
- **Out of scope (deferred without loss):** crewdock / ACP integration; helm adapter; upstream
  spacedock **binary** changes (incl. `nested-controller-worktree-support` — the `dispatch build`
  nested-path refusal is a core-binary concern, stays in ROADMAP Later); any third-party dependency.

### Design constraints (typed — hand-off to design; affects_ui: false)

- **DC-1 (structural)** — the runner adapter stays the ONLY seam that knows the spawn transport
  (design.md §6 carrier-swap boundary); AC-1/AC-2 edits live in `scheduler-runner-adapter.sh`, the
  tick (`ship-flow-scheduler.sh`) never learns launcher/`claude` specifics. Rationale: preserves
  the crewdock carrier-swap contract.
- **DC-2 (behavioral)** — AC-4 backoff derives purely from `events.jsonl` (+ receipts); NO new
  canonical state store. Rationale: Rule 3 (daemon owns no state of record) + AC-4 verbatim.
- **DC-3 (behavioral)** — AC-4 must not violate Rule 4 (no retry): skip-past ≠ retry the blocked
  entity; the tick spends its one action on the NEXT eligible action. Rationale: reconcile design.md
  line 61 "blocked is a *successful* tick".
- **DC-4 (interface)** — AC-3 `checkpoint` is a new `event` value in the `events.jsonl`
  schema (`ship-flow-scheduler/v0`); design decides whether it extends the existing `blocked`
  detail or is a distinct event, and how resume reads it. Rationale: keep the rollup/report parsers
  (`ship-flow-scheduler.sh:~700`) forward-compatible.
- **DC-5 (structural)** — AC-5 PATH value must not hardcode `/Users/kent`; use `$HOME/.local/bin`
  (or an install-time mechanical check) so the template stays portable. Rationale: no hidden
  machine dependency.

### ROADMAP `now` row intent

- Add to **Now**: `| tick-hardening | Tick hardening — delegation marker, launcher spawn,
  time-budget, blocked-backoff | shape |` (committed hackathon-2 Wave 1).
- **Fold** two Later rows into this entity: `scheduler-tick-delegation-marker` (AC-1/AC-2) +
  `pipeline-timeout-checkpoint-event` (AC-3). Mark them folded, do not double-ship.
- **Keep in Later:** `nested-controller-worktree-support` (out-of-scope, upstream binary).

### Canonical-doc impact

- **ROADMAP.md** — Now-row add + fold two Later rows (above). Doc-impact block required.
- **RUNBOOK** (`docs/ship-flow/l3-scheduler-tick/RUNBOOK.md`) — AC-5 install step (user-local bin
  PATH / mechanical check) + AC-3 resume-from-checkpoint note.
- **Scheduler design authority** (`docs/ship-flow/l3-scheduler-tick/design.md` §6 + events schema)
  — AC-1 delegation marker on the spawn contract; AC-2 launcher spawn; AC-3 `checkpoint` event;
  AC-4 backoff-skip precedence. DESIGN decides in-place update of the shipped design.md vs carrying
  the delta in `tick-hardening/design.md` with a cross-ref (avoid prose duplication drift).
- **ARCHITECTURE.md** — no scheduler section exists today; this entity does NOT add one (design
  authority stays in entity design docs + tests, per ROADMAP "Not Doing" anti-duplication rule).
- **INVARIANTS.md** — design may add one invariant: the carrier-swap seam MUST stamp the delegation
  marker. Deferred to design as a candidate, not a shape commitment.
