# L3 scheduler tick — stateless SD scheduler (Step-3 wedge v0) — Design

### Summary

Fixes the v0 contract deltas concretely so plan/execute inherit one authority: the tick CLI
surface, the JSON event schema, the state-projection vocabulary, the derived gate-projection
report, and the launchd plist + rollup shape. All four of shape's open design questions resolve
**within** the ten hard rules — zero parks, zero new captain decisions (matches shape's
`open_contract_decisions: []`). The carrier-swap seam (runner adapter) is pinned so crewdock can
later replace launchd + `claude -p` without touching tick internals. Every contract is pinned by a
shell-testable code gate in the existing `lib/__tests__/test-*.sh` harness, not prose.

### Reverse-recovery reuse map (build ON these; do not rebuild)

Layer-trace of the tick's dependencies. The tick is a **new orchestration atom** (proof-of-absence
confirmed: no existing `scheduler`/`tick`/`launchd`/`rollup` anywhere in `plugins/`, `scripts/`,
`docs/`) that **composes** WORKING primitives — it must reuse them, never reimplement:

| Primitive | State | Contract the tick consumes | Evidence |
| --- | --- | --- | --- |
| `spacedock status` (Go binary) | WORKING | `--workflow-dir --resolve/--set/--read/--archive/--boot/--next-id`; canonical entity frontmatter read/write | on PATH (`/opt/homebrew/bin/spacedock`); used by reconciler |
| `bin/merged-pr-closeout-reconciler.sh` | WORKING | `--workflow-dir --entity --pr-provider gh\|fixture --pr-fixture --dry-run`; emits `key=value`; `verdict=PROMPT_CAPTAIN`→exit 1, `PROCEED`→exit 0, `REJECT`→exit 2 | 82/82 test green |
| `lib/dag-waves.sh --ready --from-workflow <dir> --epic <id>` | WORKING | prints space-joined ready ids; exit 0/2(cycle)/3(closure)/4(dup) fail-closed | test-dag-waves green |
| `lib/fo-completion-lease.sh` (pattern only) | WORKING | mkdir-atomic dir lease (`mkdir "$dir" 2>/dev/null \|\| fail "already held"`); record file names holder | the concurrency=1 precedent |
| `lib/__tests__/test-*.sh` harness + `bin/test-fixtures` | WORKING | CI loops `for t in lib/__tests__/test-*.sh; do CI=true timeout 90 bash "$t"; done`; `assert_exit/contains/not_contains/file_exists` | ship-flow-invariants.yml |

The tick is **additive**: it introduces new files only and changes NO existing SKILL prose,
`references/*.yaml` schema, or the reconciler/dag-waves output contracts — so no existing
string-assertion test can break (verified surface in §10).

---

### §1 — Tick CLI surface

**Vehicle:** a new `bin/` checker-family script `plugins/ship-flow/bin/ship-flow-scheduler.sh`,
POSIX bash 3.2+, no external deps in the hot path (JSON is `printf`-emitted with fixed key order;
`gh --json … --jq` is used only where the reconciler already establishes gh as a dependency). This
matches the `bin/*.sh` checker family + hermetic constraint (ARCHITECTURE Principle 12). The
**CLI + JSON + exit-code contract below is language-independent**; bash is the recommended impl.

Command word is `ship-flow-scheduler` with three subcommands (shape's "the unit is
`ship-flow-scheduler tick`"):

```
ship-flow-scheduler tick    --workflow-dir <dir> --controller-worktree <path>
                            [--epic <id>] [--runner gh|fixture] [--runner-fixture <path>]
                            [--events-log <path>] [--timeout <sec>] [--dry-run]
ship-flow-scheduler report  --workflow-dir <dir> [--json]            # read-only gate queue (§7)
ship-flow-scheduler rollup  --events-log <path> --date <YYYY-MM-DD>  # deterministic (§8)
```

**`tick` exit codes** (daemon health, NOT entity outcome — entity outcomes ride the event, §2):

| Exit | Meaning |
| --- | --- |
| 0 | Clean tick. Any of: dispatch-ok, advance, reconcile, no-op, refusal-recorded, blocked-recorded, lease-held-skip. The daemon is healthy. |
| 2 | Usage error (bad/missing flags). |
| 3 | Environment fault — cannot operate: workflow-dir missing, `spacedock`/`gh` unavailable, controller-worktree missing/unregistered. launchd surfaces this. |
| 4 | Lease subsystem fault — cannot create/inspect the controller lease dir. |

Rationale: a **blocked entity** (run timeout, reconciler PROMPT_CAPTAIN) is a *successful* tick that
correctly recorded a terminal `blocked` — exit 0 (Rule 4: no retry) + a `blocked` event visible in
the morning report. A **refusal** (ineligible entity, Rule 1) is likewise a recorded outcome, exit
0. Reserving nonzero for daemon faults keeps launchd's health signal clean.

`report` / `rollup` exit: 0 rendered · 2 usage · 3 env/no-events. **Neither ever writes tracked
state** (§7, §10).

---

### §2 — JSON event schema (resolves open question #1)

One `tick` invocation performs **exactly one bounded action** (Rule 10) and emits **exactly one
primary event** to stdout as a single JSON Lines object, and appends the same line to
`--events-log` (a derived, crash-replayable audit cache — Rule 3; the rollup's only input, never a
decision input). Emission is `printf` with a **fixed key order** for byte-determinism (no jq for
emit).

**Envelope (every event):**

```json
{"schema":"ship-flow-scheduler/v0","ts":"2026-07-19T04:05:06Z","tick_id":"20260719T040506Z",
 "event":"<dispatch|advance|reconcile|no-op|refusal|blocked>","entity":"<slug|null>",
 "outcome":"<ok|refused|blocked>","reason":"<code|null>","detail":{…}}
```

- `ts`: RFC3339 UTC, second precision. `tick_id`: `ts` compacted (the idempotency correlation key;
  NOT a decision input).
- `event` is the action taken; `outcome`/`reason` classify it; `detail` carries per-event fields.

**Per-event `detail` required fields:**

| event | detail fields |
| --- | --- |
| `dispatch` | `runner:{workdir,timeout_sec,exit_class,sentinel,receipt}`, `pr:"<number\|null>"` |
| `advance` | `ready_set:[…]`, `dispatched:"<slug\|null>"` (the next entity this tick handed off) |
| `reconcile` | `pr`, `reconciler_verdict:"<PROCEED\|PROMPT_CAPTAIN\|REJECT>"`, `terminal_state:"<reconciled\|blocked>"` |
| `no-op` | `reason:"<idle\|lease-held\|nothing-ready\|nothing-eligible>"` |
| `refusal` | `keys:{shaped,issue_open,sd_approved,dor}` (each bool), `reason:"<code>"` |
| `blocked` | `source:"<run-timeout\|run-error\|reconciler-prompt-captain>"`, `receipt` |

**Refusal reason codes (machine-readable — the dual-key + DoR set, Rule 1 + input-quality gate).**
Fail-closed: any single failed key ⇒ `refusal`, zero worker tokens (AC-2):

```
not-shaped · issue-missing · issue-closed · not-sd-approved
dor-untestable-ac · dor-stale-shape · dor-no-appetite · dor-no-risk-lane
worktree-exists · pr-exists            # dedup keys — see §4
```

---

### §3 — State-projection vocabulary (checklist item 1)

The eight states are **derived projections**, NEVER stored canonically by the tick (Rule 3, Rule 8).
Each derives from entity frontmatter + gh reads + the lease record + receipts. The tick reads these
fresh every invocation; there is no writable ledger:

| Projected state | Derivation (all reads, no tick-owned write) |
| --- | --- |
| `eligible` | frontmatter `status` ∈ post-shape/pre-terminal **AND** gh issue OPEN + label `sd:approved` **AND** DoR mechanical pass **AND** no live worktree **AND** no open/merged PR (§4 dedup) |
| `leased` | controller lease record names this entity (pre-run, transient) |
| `running` | lease record names this entity **AND** run child alive / run-receipt open |
| `awaiting_merge` | frontmatter `pr:` set **AND** gh PR state OPEN **AND** frontmatter `verdict: PASSED` |
| `merged` | gh PR state MERGED **AND** frontmatter `status != done` (not yet reconciled) |
| `reconciled` | reconciler ran to terminal (frontmatter `status: done` + archived) — the merged→done transition |
| `done` | frontmatter `status: done`, coherent terminal (reconciler's `coherent_terminal_file` shape) |
| `blocked` (terminal) | blocked receipt present **OR** reconciler `PROMPT_CAPTAIN` **OR** run `exit_class` ∈ {timeout,error} (Rule 8) |

`leased`/`running` are **control-plane** reads of the lease record (which names entity + pid +
start-ts), not entity state-of-record — consistent with Rule 3. This keeps `awaiting_merge`/`merged`
purely a function of `gh pr view` + frontmatter, so the morning report (§7) is trustworthy because
it is derived, not forgeable (AC-4).

---

### §4 — Idempotence + crash-replay contract (resolves open question #2)

**The tick's single-action decision is a pure function of canonical state + the lease — no writable
cache participates.** The events log (§2) is audit-only and is never read to decide.

**One tick invocation:**
1. Acquire the controller lease (§5). If held → emit `no-op reason=lease-held`, exit 0.
2. Read canonical state fresh: scan SD entities (`spacedock status`), read each frontmatter
   `status/pr/verdict/worktree/issue`; for candidates, `gh issue view` (label/open) + `gh pr view`
   (state/head).
3. Compute the ONE bounded action by fixed precedence:
   `reconcile` (a merged PR exists) → `dispatch` (an `eligible` entity exists) →
   `advance` (recompute `dag-waves.sh --ready`, hand off next) → `no-op`.
4. Execute exactly that action; emit its event; release the lease; exit.

**Dispatch idempotence (AC-1) is guaranteed by making dispatch-eligibility exclude any half-run
artifact:** an entity is dispatched **only if** it has **no live worktree** *and* **no open/merged
PR** (the `worktree-exists` / `pr-exists` dedup keys, §2). Consequences:
- A prior run that reached worktree/PR creation flips those keys ⇒ the entity is no longer
  `eligible` ⇒ a replay **cannot** re-dispatch it (no double-ship, no second PR).
- The only replay window is a crash **between spawn and worktree creation**, where the prior
  attempt produced **zero canonical artifacts**. Re-dispatch there is a legitimate retry of a
  no-op'd attempt, not a double-ship — nothing was shipped.
- Two concurrent runs on one entity (the real double-dispatch) are prevented by the controller
  lease being **held across the whole dispatch until the run ends** (§5): only one run is ever in
  flight (concurrency=1, Rule 9).

**Crash-replay reconstruction needs no stored decision:** after a crash the next tick re-derives
step 2 from canonical state. A stale lease (dead pid / age > timeout) is reclaimed (§5). No
`leased`/`running` state was persisted to entity frontmatter, so there is nothing to unwind — the
projection simply recomputes. This is the "derived, crash-replayable cache" of Rule 3 with the cache
being the **empty set**: canonical state IS the cache.

**Dispatch execution model (v0):** the dispatch action spawns the run via the adapter (§6) and
**supervises it to completion, bounded by `--timeout`, holding the lease throughout.** This makes
single-flight the mechanical consequence of the lease. launchd's interval firing during a live run
finds the lease held → immediate `no-op`. The async/detached model (spawn, release, poll later) is
**deferred to the crewdock carrier**, which owns its own single-flight via container lifecycle —
that is precisely the carrier-swap seam (§6), not a v0 concern.

---

### §5 — Controller lease (resolves open question #4)

Reuse the `fo-completion-lease.sh` **pattern** (not the file — its record semantics are
completion-handoff-specific) in a small new `lib/scheduler-lease.sh` sourced by the tick:

- **Acquire:** `mkdir "$CONTROLLER_WORKTREE/.ship-flow-scheduler.lease" 2>/dev/null` — atomic; on
  failure the lease is held → caller emits `no-op reason=lease-held`, exit 0. Record file writes
  `pid=<n> start_ts=<RFC3339> tick_id=<…> entity=<slug|null>`.
- **Concurrency=1 refusal (AC-1 duplicate-dispatch):** a second invocation's `mkdir` fails → it does
  nothing and exits 0. This is the exact "second invocation detects and refuses" mechanism.
- **Stale reclaim (crash-replay):** if the lease exists but `kill -0 $pid` fails **or**
  `now - start_ts > max_run_timeout`, the holder is dead → the new tick reclaims (removes + re-mkdir)
  and proceeds. This bounds a crashed dispatch's lock to the timeout window.
- **Release:** `rmdir` the lease dir in a bash `trap … EXIT` so a killed tick still releases on
  normal signals; the stale-reclaim path covers hard kills.
- Lives in the **dedicated controller worktree** (Rule 9), never a shared Conductor tree; the lease
  dir path is derived from `--controller-worktree`, so the daemon's control plane is isolated.

---

### §6 — Runner-adapter carrier-swap seam (checklist item 2)

A single seam file `lib/scheduler-runner-adapter.sh` is the ONLY place that knows about `claude -p`
+ launchd. crewdock later replaces this file's body (spawn into container, park/resume, scavenging)
while preserving the CLI + JSON contract — the tick never changes.

**Interface (stable across carriers):**

```
scheduler-runner-adapter.sh run --entity <ref> --workdir <path> --timeout <sec> [--env K=V …]
```

- **Inputs:** entity ref, workdir, timeout (sec), env pairs. Nothing else — no transcript path, no
  container handle (those are carrier-internal).
- **Behavior (launchd/v0 impl):** `timeout <sec> claude -p "/ship <entity>"` in `<workdir>` with
  `<env>`; capture stdout + exit.
- **Outputs — a single JSON line on stdout:**
  ```json
  {"exit_class":"<success|timeout|error>","sentinel":"<terminal marker|null>","receipt":"<abs path>"}
  ```
  Exit code maps `0` / `124`(timeout) / `1`(error). `sentinel` = the run's terminal marker line the
  adapter greps from stdout (`SHIP_FLOW_TERMINAL verdict=<…> pr=<…> state=<awaiting_merge|blocked>`);
  absent marker ⇒ `exit_class=error`. `receipt` = abs path to the run's outcome receipt the tick
  cites in its `dispatch`/`blocked` event.
- **Boundary (Rule 10):** the tick calls the adapter through this interface only. The tick NEVER
  reads transcripts, parks/resumes, scavenges, or manages container lifecycle. Failure/timeout ⇒ the
  tick writes a terminal `blocked` receipt and does **not** retry / substitute a fresh team (Rule 4).

---

### §7 — Derived gate-projection report (resolves open question #3, AC-4)

`ship-flow-scheduler report --workflow-dir <dir> [--json]` renders a **read-only** morning queue.
Markdown table (default) with columns, `--json` for machine consumers:

```
| entity | state | pr_head | verify_verdict | gh_checks | cross_model | age |
```

- `pr_head` = exact PR head SHA via `gh pr view --json headRefOid` (not a stored copy — derived,
  AC-4). `verify_verdict` from frontmatter `verdict`. `gh_checks` from `gh pr checks`. `cross_model`
  from the verify artifact's `cross_model_challenge` coverage (Rule 5; `DEGRADED` stays visible).
  `state` from §3. Rows limited to non-terminal projections (`running`/`awaiting_merge`/`merged`/
  `blocked`).
- **No writable gate ledger exists** (Rule 3) — the report holds no state; re-running it re-derives.

**No-write guarantee surface (two code gates, §10):**
1. *Static:* the report code path sources no mutation helper and contains no `status --set`,
   `--archive`, `git commit/push`, or tracked-file redirection — a grep gate mirroring the
   reconciler's existing `helper has no forbidden git/gh mutation commands` assertion.
2. *Runtime:* run `report` against a fixture workflow, assert `git -C <repo> status --porcelain` is
   **empty** afterward (proves zero file writes) + assert no `sd:approved`/status frontmatter changed.

---

### §8 — launchd plist + deterministic rollup (AC-6)

**Carrier plists** — committed as *templates* (paths are machine-specific) under
`plugins/ship-flow/references/launchd/`:
- `com.spacedock.ship-flow-scheduler.tick.plist` — `StartInterval` (default 300s), `RunAtLoad`,
  `WorkingDirectory=@CONTROLLER_WORKTREE@`, `ProgramArguments` = the `tick` invocation,
  `StandardOut/ErrorPath` = a log under the controller worktree. Placeholders
  `@CONTROLLER_WORKTREE@` / `@SPACEDOCK_BIN@` / `@WORKFLOW_DIR@` substituted at install (runbook).
- `com.spacedock.ship-flow-scheduler.rollup.plist` — `StartCalendarInterval` `Hour=23 Minute=55`
  (Rule 7: runs after wake), runs `rollup --date <today>`.

**Deterministic daily rollup** — `rollup --events-log <path> --date <YYYY-MM-DD>` reads that day's
JSONL events and emits markdown with deterministic counts, sorted keys, **no wall-clock in the body**
(only the echoed `--date`): dispatches · durations (per-dispatch from `detail.runner` timing) · gate
waits (time in `awaiting_merge`, from event `ts` deltas) · failures (`blocked`) · costs (from
receipt if present, else `n/a`) · interventions (`blocked` + `refusal` + PROMPT_CAPTAIN counts).
Semantic lessons are NOT synthesized here — deterministic counting only (Rule 7; semantics route
through harvest-decide).

**Determinism gate (§10):** feed a fixed fixture events log twice → `diff` of the two outputs is
empty (byte-identical). This is the rollup-determinism fixture test.

**Recovery runbook** — `docs/ship-flow/l3-scheduler-tick/RUNBOOK.md` (plan/execute authored):
inspect (`report`, tail events log, read lease record) · unlock (remove the lease dir **only** when
proven stale — dead pid or age > timeout) · rerun (`tick` once by hand). The daemon owns no
canonical state and never mutates prompts/routing/budgets/policy (Rule 3, AC-6).

---

### §9 — Open design questions: resolution (all within the ten hard rules)

| Shape open question | Resolution | Park? |
| --- | --- | --- |
| Q1 Exact JSON event schema | §2 — envelope + per-event `detail` + refusal reason codes | No |
| Q2 Tick cache layout + crash-replay | §4 — decision is a pure function of canonical state; cache = ∅; events log is audit-only | No |
| Q3 Gate-projection report shape + no-write surface | §7 — read-only markdown/JSON + two no-write code gates | No |
| Q4 Controller-lease for concurrency=1 | §5 — mkdir-atomic dir lease in the controller worktree + stale reclaim | No |

**Zero parks. Zero new captain decisions.** The ten hard rules fully constrained every choice
(consistent with shape's `open_contract_decisions: []`). No question required reinterpreting an AC,
touching an irreversible lane, or a design-direction (IA/brand) call.

---

### §10 — Test surfaces (checklist item 3 — code gate over prose everywhere)

All new tests are `plugins/ship-flow/lib/__tests__/test-*.sh` (picked up verbatim by the CI loop),
with fixtures under `lib/__tests__/fixtures/ship-flow-scheduler/`. Each contract is pinned by a gate,
not prose:

| Contract (AC) | Pinning test surface | Assertion shape |
| --- | --- | --- |
| Replay idempotence (AC-1) | `test-ship-flow-scheduler-idempotence.sh` | run `tick` twice on a fixture with a worktree/PR already present → second is `no-op`/refusal, **not** a second dispatch event |
| Duplicate-dispatch refusal (AC-1) | same, lease case | invoke while lease held → `no-op reason=lease-held`, exit 0, no dispatch |
| Ineligible-entity refusal / fail-closed dual-key (AC-2) | `test-ship-flow-scheduler-eligibility.sh` | unshaped / issue-closed / no `sd:approved` fixtures → `refusal` event with the matching reason code, zero spawn (stub adapter never called) |
| Bounded runner adapter (AC-3) | `test-scheduler-runner-adapter.sh` | stub runner: success/timeout/error → correct `exit_class`+`sentinel`+`receipt`; timeout → `blocked`, no retry |
| PROMPT_CAPTAIN → terminal blocked (AC-5) | `test-ship-flow-scheduler-reconcile.sh` | reconciler fixture returning `PROMPT_CAPTAIN` (exit 1) → tick emits `blocked` (source=reconciler-prompt-captain), no auto-cleanup |
| Gate report no-write (AC-4) | `test-ship-flow-scheduler-report.sh` | (1) grep gate: no forbidden mutation verbs in the report path; (2) runtime: `git status --porcelain` empty after `report` |
| Rollup determinism (AC-6) | `test-ship-flow-scheduler-rollup.sh` | fixed events log fed twice → `diff` empty (byte-identical) |
| Full-cycle (AC-5) | `test-ship-flow-scheduler-fullcycle.sh` | fixtures: dispatch → PR-ready → merged → reconcile → `dag-waves --ready` next-ready |
| launchd plist well-formedness (AC-6) | `test-ship-flow-scheduler-plist.sh` | `plutil -lint` / xmllint on both templates + placeholder-substitution smoke |

**No existing test breaks (verified):** the tick adds files only and changes NO existing SKILL prose,
`references/*.yaml`, or the reconciler/dag-waves output contracts. Proof-of-absence of the surface
was confirmed (no `scheduler`/`tick`/`launchd` collision); the two composed primitives are green
today (test-dag-waves ALL PASS, test-merged-pr-closeout-reconciler 82/82). Execute must run the full
`lib/__tests__/test-*.sh` loop + `node --test bin/*.test.mjs` and show green as the "breaks nothing"
proof (not a prose claim).

---

### §11 — Canonical / registry impact (for plan)

- **ARCHITECTURE.md `<!-- section:decisions -->`:** on ship, add an `l3-scheduler-tick` row recording
  the carrier-swap boundary — `ship-flow-scheduler tick` is a deterministic, idempotent, stateless
  atom; launchd (now) / crewdock (later) are interchangeable carriers; the daemon owns no state of
  record and the gate index is a derived projection, not a ledger. Mutate via section-tag/patch-map
  (Principle 5), not freehand.
- **PRODUCT.md:** on ship, record the capability — approved shaped work reaches a trustworthy
  PR-ready merge queue unattended, human retained as merge authority (no auto-merge), audit-by-
  exception via the daily rollup.
- **ROADMAP.md:** `l3-scheduler-tick` into `Now`; the `reverse-recovery-audit-dangling-path` `Later`
  row is the real-proof target (needs a shape-confirm + gh issue + `sd:approved` at kickoff).
- **INVARIANTS.md (plugin):** no invariant change proposed — the ten hard rules are v0 contract, not
  plugin invariants (matches shape). Flag none for invariant-level pinning at v0.

### Design Report

- Mode: **contract-design** for a new additive orchestration atom composing WORKING primitives
  (reverse-recovery: reuse dag-waves / reconciler / spacedock status / lease-pattern; rebuild none).
- Contract deltas fixed concretely: tick CLI + exit codes (§1), JSON event schema + refusal codes
  (§2), state-projection derivation table (§3), idempotence/crash-replay contract (§4), controller
  lease (§5), runner-adapter carrier seam (§6), derived gate report + no-write gates (§7), launchd
  plist templates + deterministic rollup (§8).
- Open questions: all four resolved within the ten hard rules; **0 parks, 0 new captain decisions**.
- Test surfaces: nine shell gates named, each pinning one AC; code-gate-over-prose throughout;
  no-existing-break verified by proof-of-absence + green baseline of the two composed primitives.
- status: passed
- verdict: PROCEED
- open_design_questions_remaining: 0
