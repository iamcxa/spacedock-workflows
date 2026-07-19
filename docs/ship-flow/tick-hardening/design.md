# Tick hardening — delegation marker, launcher spawn, time-budget, blocked-backoff — Design

### Summary

Seam-hardening design (EXISTS_BROKEN, no greenfield). Fixes the six ACs against the REAL
`origin/main` files: `plugins/ship-flow/lib/scheduler-runner-adapter.sh`,
`plugins/ship-flow/bin/ship-flow-scheduler.sh`,
`plugins/ship-flow/references/launchd/com.spacedock.ship-flow-scheduler.tick.plist`, and the
events schema in `docs/ship-flow/l3-scheduler-tick/design.md` §2/§6. Every delta is bounded to its
seam; no new canonical store (Rule 3), no retry (Rule 4), the tick stays a dumb invoker (Rule 10).
This file is the authoritative delta; l3 `design.md` §2/§6 get a one-line cross-ref pointer at
execute (no prose duplication — avoids the drift the shape flagged).

**Line refs below are `origin/main` at the design HEAD** (`scheduler-runner-adapter.sh` 93 lines,
`ship-flow-scheduler.sh` 760 lines).

---

### AC-1 — Mechanical delegation marker

**Problem:** tick-spawned `claude -p "/ship <entity>"` (`scheduler-runner-adapter.sh:64`) is
byte-identical to a forbidden manual hand-dispatch; the spawned `/ship` run cannot mechanically
prove tick-delegation. v0 workaround = a 30-min-receipt heuristic clause in the blocked entity's
`decisions.md`.

**Delta:**
- `scheduler-runner-adapter.sh`: add an OPTIONAL `--tick-id <id>` arg (absent → fall back to the
  adapter's own `STAMP` at :49, so existing callers/tests that omit it keep working). When present:
  1. append `SHIP_FLOW_SCHEDULER_TICK_ID=<id>` to `ENV_PAIRS` (the `env "${ENV_PAIRS[@]}"` wrapper
     at :54-58 then sets it on the spawned child — the machine-readable marker, present in BOTH the
     real-`claude` branch AND the hermetic `SHIP_FLOW_SCHEDULER_RUNNER_CMD` branch);
  2. build `SHIP_PROMPT` = `/ship <entity>` + a newline + a delegation line naming the tick id and
     receipt basename, e.g.
     `[ship-flow-scheduler tick delegation — tick_id=<id> receipt=<basename>; autonomous per Rule 1/10, not a manual hand-dispatch]`;
     the production spawn (:64, rewritten in AC-2) passes `"$SHIP_PROMPT"`.
- `ship-flow-scheduler.sh`: thread the existing `tick_id` (`:322-323`) into `run_dispatch_action`
  (new trailing param) and pass `--tick-id "$tick_id"` on the adapter call (`:420`). The tick learns
  no launcher/claude specifics — DC-1 held (it passes an opaque id string only).
- **Consumer / retire the workaround:** the spawned `/ship` FO reads `SHIP_FLOW_SCHEDULER_TICK_ID`
  (env) / the delegation prompt line and stamps it into its stage-entry receipt — the mechanical
  chain that replaces the 30-min heuristic. The heuristic clause lives in an entity `decisions.md`
  on `iamcxa/muscat-v1` (not in this origin/main worktree); its physical removal is a doc edit
  parked to that entity — this design only ships the producer + names the retirement in the RUNBOOK.

**Test surface:** `plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh` (extend).
(a) Marker: the success stub-runner echoes `$SHIP_FLOW_SCHEDULER_TICK_ID` into the receipt; assert
the passed id appears (proves env reaches the child). (b) Prompt line: add a hermetic
`--print-spawn` adapter mode (below) and assert the printed spawn contains `/ship <entity>` + the
delegation line + `tick_id=<id>`. Existing assertion `'"sentinel":"SHIP_FLOW_TERMINAL'` (:50)
unaffected.

---

### AC-2 — Launcher spawn (probe-gated → launcher)

**Problem:** adapter spawns raw `claude -p` (`scheduler-runner-adapter.sh:64`), bypassing the
launcher that owns plugin/env wiring + session metadata. Shape probe PASSED.

**Delta — `scheduler-runner-adapter.sh:64`, rewrite the production branch to:**

```
( cd "$WORKDIR" && run_cmd timeout "$TIMEOUT" \
    "${SPACEDOCK_BIN:-spacedock}" claude "$SHIP_PROMPT" \
    --plugin-dir "$WORKDIR/plugins/ship-flow" \
    -- -p --output-format text ) > "$RECEIPT" 2>&1
```

- `${SPACEDOCK_BIN:-spacedock}` per the launcher-command invariant; the tick plist already exports
  `SPACEDOCK_BIN` (`…tick.plist:32-33`).
- **Version-gate resolution (shape residual a — now decided, not deferred):** use `--plugin-dir`,
  NOT `--skip-compat-check`. `spacedock claude --help` (v0.25.0, verified this session) states
  `--plugin-dir` "relaxes the version gate … does not require a prior spacedock install" AND loads
  the local checkout — so the spawned run uses the controller-worktree's OWN plugin code (the code
  the tick is running), avoiding both the version-skew block and running stale installed plugins.
  `--skip-compat-check` (shape-probe-proven) is the documented fallback if `--plugin-dir` misbehaves.
- **Open (execute-time, non-blocking):** exact `--plugin-dir` level. `--help` example is
  `./checkout`; this is a multi-plugin repo. A one-line execute probe confirms `$WORKDIR` vs
  `$WORKDIR/plugins/ship-flow`. Not a captain decision — parked to execute.
- **Raw fallback (AC-2 requirement, never silent):** the raw `claude -p "/ship <entity>"
  --output-format text` form stays documented as a code comment on the spawn line + a RUNBOOK note;
  it is the contingency if the launcher path fails verify. No runtime mode-switch shipped (parked).
- **Preflight guard:** `ship-flow-scheduler.sh:318-320` currently requires `command -v claude`. With
  the launcher, also accept `command -v "${SPACEDOCK_BIN:-spacedock}"`; keep the
  `SHIP_FLOW_SCHEDULER_RUNNER_CMD`-set bypass (:318) so CI without either binary still runs hermetic.

**Test surface:** the `--print-spawn` mode (AC-1) asserts the resolved argv contains the launcher,
`--plugin-dir`, and the `-- -p --output-format text` passthrough — hermetically, no real spawn.
Recorded probe evidence already in `shape.md` "AC-2 probe".

---

### AC-3 — Appetite-scaled timeout + resumable checkpoint

**Problem:** flat `--timeout` (template default `timeout_sec=900` at `ship-flow-scheduler.sh:288`;
the plist passes no `--timeout`) is far below a full design→ship run; a timeout kill (`:428-435`
`blocked source=run-timeout`) records no resume target.

**Delta — `ship-flow-scheduler.sh`:**
- Add `derive_timeout_sec <entity-path> <default>`: reads optional frontmatter `time_budget`
  (via the existing generic `read_frontmatter_field`, :72) and parses `<N>h<M>m` / `<N>h` / `<M>m`
  → seconds (small inline parser; no reusable one exists). Absent/unparseable → generous default.
  **Default = 5400s** (matches the prior flat value; tunable, documented). Entities opt into longer
  runs by declaring `time_budget:` in their `index.md` frontmatter (canonical entity state, Rule-3
  clean). This entity declares 2h30m → 9000s.
- Call it in `run_dispatch_action` per dispatched entity (it has `$path`), overriding the incoming
  `timeout_sec` for the adapter call (`:420`). Reconcile timeout (`:467`) keeps the tick's own
  `--timeout` (lease-bound, unchanged — F2 fix intact).
- **Checkpoint (DC-4 resolved — extend `blocked` detail, NOT a new event value):** in the
  `exit_class=timeout` branch (`:428-435`) read the entity's current `status`
  (`read_frontmatter_field "$path" status`) and add a `checkpoint` object to the blocked event
  detail: `{"source":"run-timeout","receipt":…,"checkpoint":{"resume_stage":"<status>"}}`. Rationale:
  the tick contract is exactly-one-event-per-tick (l3 §2/§4); a separate `checkpoint` event would
  break that and the rollup's `blocked`-counts-as-failure parser (l3 §8). Keeping `event:"blocked"`
  + `source:"run-timeout"` preserves both; resume reads the latest `run-timeout` event's
  `detail.checkpoint.resume_stage` and re-enters that stage (derived from events, no new store).

**Test surface:** `test-scheduler-runner-adapter.sh` `run_tick_surfaces_timeout_as_blocked_case`
(:69-85, extend) — the existing `'"event":"blocked"'` + `'"source":"run-timeout"'` asserts stay;
add `'"checkpoint"'` + `'"resume_stage"'` asserts, with the fixture entity's frontmatter `status`
set so the resume stage is named. A tiny-budget unit assert on `derive_timeout_sec` (2h30m→9000,
absent→5400) in the same file.

---

### AC-4 — Blocked-backoff (no head-block)

**Problem:** precedence-1 reconcile returns on the FIRST non-OPEN-PR entity
(`ship-flow-scheduler.sh:355-357` `run_reconcile_action … ; return 0`). A perpetually-failing
reconcile (entity-7 `reconciler-error`) consumes the tick's single action every cycle; nothing
behind it is ever reached.

**Delta — `ship-flow-scheduler.sh`:**
- Add `entity_in_backoff <slug> <events-log> <window-sec>`: tails `EVENTS_LOG`, finds the most
  recent event for `<slug>`, returns 0 (in backoff) iff it is `event:"blocked"` AND its `ts` is
  within `<window-sec>` of now. Reuses `scheduler_lease_epoch` (scheduler-lease.sh) for `ts`→epoch.
  Reads events.jsonl only — DC-2 held (no new store); events.jsonl already carries `ts`+`entity`.
- Precedence-1 loop (`:340-359`): before `run_reconcile_action`, if `entity_in_backoff "$slug"
  "$EVENTS_LOG" "$BACKOFF_WINDOW"` → `continue` (skip past; do NOT `return 0`). The loop keeps
  scanning for a genuinely-reconcilable entity; if none, falls through to precedence-2.
- Precedence-2 dispatch loop (`:363-382`): treat an in-backoff entity as not-eligible (skip/
  `continue`), so a recently `run-error`/`run-timeout` entity doesn't re-consume the action either.
- **Backoff window default = 3600s** (documented, tunable; > the 300s tick interval so a blocked
  entity is skipped for several ticks). DC-3 held: skip-past ≠ retry — the tick spends its one
  action on the NEXT eligible action; it never re-dispatches the blocked entity within the window.
  A generous window is effectively terminal-until-captain while staying purely event-derived.

**Test surface:** NEW `plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-backoff.sh`. Seed an
`--events-log` with a recent `blocked` record for entity A + a clean eligible entity B; run one
tick; assert B is dispatched (`'"event":"dispatch"'` + `'"entity":"B"'`) and A is NOT acted on.
Second case: A's blocked `ts` older than the window → A is eligible again (window expiry). Mirrors
the reconcile-test fixture shape (`test-ship-flow-scheduler-reconcile.sh`) for the precedence-1 seed.

---

### AC-5 — Carrier PATH pinned

**Problem:** tick plist PATH is `/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin`
(`…tick.plist:30-31`); `claude` lives at `~/.local/bin/claude`, absent from the template → silent
"claude CLI not available" recur.

**Delta — `com.spacedock.ship-flow-scheduler.tick.plist:31`:** prepend a `@USER_LOCAL_BIN@`
placeholder →
`<string>@USER_LOCAL_BIN@:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>`.
launchd does NOT expand `$HOME` in `EnvironmentVariables`, so a literal `$HOME/.local/bin` would be
a broken path — DC-5 requires an install-time substitution. The RUNBOOK install step substitutes
`@USER_LOCAL_BIN@` → `$HOME/.local/bin` (e.g. `sed "s|@USER_LOCAL_BIN@|$HOME/.local/bin|g"`),
never a hardcoded `/Users/kent`. Applies to the tick plist (spawns claude); the rollup plist is pure
bash (no claude) and is left unchanged.

**Test surface:** `plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-plist.sh`. (a) Add
`@USER_LOCAL_BIN@` to the `substitution_smoke` sed list (:45-47) so the "no unsubstituted
placeholder remains" guard passes. (b) New assert: tick plist PATH contains `.local/bin`. RUNBOOK
updated with the substitution step.

---

### AC-6 — Suite green both envs

**Delta:** none of its own — a verify-stage obligation. The design keeps every change behind the
existing hermetic seams so the full `for t in plugins/ship-flow/lib/__tests__/test-*.sh; do
CI=true timeout 90 bash "$t"` loop (`.github/workflows/ship-flow-invariants.yml:110-114`) stays
green with no `claude`/`spacedock` binary and no git identity.

**Test surface (name the three CI-sensitive):**
1. `test-scheduler-runner-adapter.sh` — the AC-1/AC-2/AC-3 edits; must stay behind
   `SHIP_FLOW_SCHEDULER_RUNNER_CMD` + `--print-spawn` (no real launcher/claude).
2. `test-ship-flow-scheduler-backoff.sh` (new, AC-4) and the tick-spawning cases in
   `test-scheduler-runner-adapter.sh` — must not trip the `--runner gh` preflight (:318 bypass
   under `SHIP_FLOW_SCHEDULER_RUNNER_CMD`).
3. `test-ship-flow-scheduler-reconcile.sh` / `-fullcycle.sh` — git-identity-sensitive (they commit
   fixtures); verify runs them under a no-`user.name`/`user.email` env (per the CI git-identity
   fixture-bug pattern). Verify cites the dual-env run output.

---

### DC resolution table

| DC | Resolution |
| --- | --- |
| DC-1 structural (adapter = only transport seam) | HELD. AC-1/AC-2 edits live in `scheduler-runner-adapter.sh`; the tick passes only an opaque `--tick-id` string + reads status. |
| DC-2 behavioral (backoff from events, no store) | HELD. `entity_in_backoff` reads `events.jsonl` only. |
| DC-3 behavioral (skip-past ≠ retry, Rule 4) | HELD. Backoff `continue`s to the next action; blocked entity never re-dispatched within window. |
| DC-4 interface (checkpoint event vs blocked detail) | DECIDED: extend `blocked` detail with `checkpoint.resume_stage` (keeps one-event-per-tick + rollup forward-compat). |
| DC-5 structural (portable PATH, no hardcode) | HELD. `@USER_LOCAL_BIN@` placeholder + install-time substitution. |

### Canonical-doc impact

- **l3 `design.md`** — §2 events schema: add `checkpoint:{resume_stage}` as an optional `blocked`
  detail field (one-line, cross-ref this file). §6 adapter seam: add optional `--tick-id`,
  launcher spawn note (one-line, cross-ref). No prose duplication.
- **l3 `RUNBOOK.md`** — AC-5 `@USER_LOCAL_BIN@` install substitution step; AC-3 resume-from-checkpoint
  note; AC-1 delegation-marker note (retires the 30-min heuristic).
- **ROADMAP.md** — Now-row add + fold two Later rows (per shape); doc-impact block at execute.
- **ARCHITECTURE.md / INVARIANTS.md** — no change (per shape; INVARIANTS candidate parked).

### Parked residuals (no new captain decisions)

- Exact `--plugin-dir` level → one-line execute probe.
- `time_budget` default (5400s) + backoff window (3600s) values → tunable, execute may adjust.
- Physical removal of the `decisions.md` 30-min clause → lives on `iamcxa/muscat-v1`, done in that
  entity.
- Runtime spawn mode-switch (launcher↔raw) → not shipped; raw form documented as fallback only.
