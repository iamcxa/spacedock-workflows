# Tick hardening — delegation marker, launcher spawn, time-budget, blocked-backoff — Plan

### Summary

Nine atomic, serially-committed TDD tasks against the REAL `origin/main` files design.md names,
plus a canonical-doc task and a dual-env verify handoff. Every code task is RED-before-GREEN with
an exact-command DC. Budget: ~50m spent shape+design; this plan sizes to ~60m execute (9 tasks ×
~6-7m) + ~40m verify/ship = within the 2h30m entity budget. Two items are named to the cut-list
rather than silently included. Full task-by-task RED/GREEN mechanics are in the collapsed sections
below (Principle 8: plan structure is the tabular consumable; verbose research collapses).

---

### Regression risk found + resolved (AC-3 timeout derivation)

**Found while grounding this plan against the live test suite:** design.md's literal reading of
`derive_timeout_sec` would have broken the existing `run_tick_surfaces_timeout_as_blocked_case`
(silently overriding an explicit `--timeout 1` test assertion). **Resolved:** the entity's
`time_budget` overrides ONLY when present; the CLI-supplied `timeout_sec` is the unconditional
fallback default; `cmd_tick`'s own compiled default (only used when `--timeout` is omitted
entirely) is separately bumped 900s→5400s.

<details>
<summary>Full risk analysis + resolution (verbatim)</summary>

**Risk:** design.md AC-3 says `derive_timeout_sec` "override[s] the incoming `timeout_sec` for the
adapter call." Read literally (a hardcoded 5400s default baked into the call site, ignoring
whatever `--timeout` the CLI passed), this breaks the EXISTING
`run_tick_surfaces_timeout_as_blocked_case` (`test-scheduler-runner-adapter.sh:69-86`), which relies
on `--timeout 1` flowing all the way to the adapter so `stub-runner-timeout.sh`'s `sleep 30` is
genuinely killed at 1s (exit 124). If `derive_timeout_sec` ignored that flag (entity fixture
`eligible-entity` has no `time_budget`), the run would instead sleep the full 30s, exit 0, fail the
sentinel check, and come back as `exit_class=error` — flipping `source` from `run-timeout` to
`run-error` and silently breaking that test's `"source":"run-timeout"` assertion.

**Resolution:** `derive_timeout_sec <path> <default>` returns `<default>` UNCHANGED when
`time_budget` is absent/unparseable — it does not invent its own number. The call site passes
`$timeout_sec` (the value already flowing from the CLI `--timeout` flag) as `<default>`, so any
test/operator that passes an explicit `--timeout` keeps that exact value when the entity has no
`time_budget`. Separately, `cmd_tick`'s own compiled-in default (`ship-flow-scheduler.sh:288`,
currently `local timeout_sec=900`) is bumped to `5400` — this is where design.md's "Default =
5400s" actually lands: it only changes behavior for invocations that omit `--timeout` entirely
(the production launchd plist's case, since its `ProgramArguments` never passes `--timeout` —
confirmed by reading `com.spacedock.ship-flow-scheduler.tick.plist:13-25`). No existing test
asserts the literal `900` (grepped: the only `"timeout_sec":900` in the repo is a static rollup
fixture line consumed by `cmd_rollup`, never a live tick run), so the bump is safe. Net: entity
`time_budget` overrides everything; explicit `--timeout` is preserved when no `time_budget`;
omitted `--timeout` now defaults to 5400s instead of 900s.

</details>

---

## Task 1 — AC-1a: adapter `--tick-id` arg + env propagation

**Files:** `plugins/ship-flow/lib/scheduler-runner-adapter.sh`,
`plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh`, NEW
`.../fixtures/ship-flow-scheduler/runner/stub-runner-echo-tick-id.sh`.

An optional `--tick-id` arg appends `SHIP_FLOW_SCHEDULER_TICK_ID=<id>` to the adapter's `ENV_PAIRS`
so it reaches the spawned child identically in both the hermetic and production branches.

<details>
<summary>RED / GREEN mechanics</summary>

**RED:** new stub script echoes `TICK_ID_SEEN=${SHIP_FLOW_SCHEDULER_TICK_ID:-}` + the existing
`SHIP_FLOW_TERMINAL` sentinel line. New test case `run_tick_id_marker_case`: invoke the adapter with
`--tick-id T-42`, extract the `receipt` path from the JSON output, `cat` it, assert it contains
`TICK_ID_SEEN=T-42`. Run against current adapter (no `--tick-id` support) → fails with usage error
(exit 2, unrecognized arg).

**GREEN:** add `--tick-id) TICK_ID="${2:-}"; shift 2 ;;` to the adapter's arg-parsing loop
(`scheduler-runner-adapter.sh:35-43`); when `TICK_ID` is non-empty, append
`SHIP_FLOW_SCHEDULER_TICK_ID=${TICK_ID}` to `ENV_PAIRS` (existing array at `:34`, consumed by
`run_cmd`'s `env "${ENV_PAIRS[@]}"` wrapper at `:53-59`) BEFORE the `if
[SHIP_FLOW_SCHEDULER_RUNNER_CMD]` branch at `:61`, so the env var reaches the child in BOTH the
hermetic and production branches identically.

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh`

---

## Task 2 — AC-1b: `SHIP_PROMPT` + delegation line + `--print-spawn` hermetic mode

**Files:** same adapter + test file as Task 1.

Builds `SHIP_PROMPT` (`/ship <entity>` + a delegation line when `--tick-id` present) and a
single-source-of-truth `SPAWN_LINE` string, plus a hermetic `--print-spawn` mode reused by both the
inspection path and the real exec branch.

<details>
<summary>RED / GREEN mechanics</summary>

**RED:** new test case `run_print_spawn_prompt_case`: invoke `"$HELPER" run --entity fixture-x
--workdir "$WORKDIR" --timeout 30 --print-spawn` (no `--tick-id`) → assert `"prompt":"/ship
fixture-x"` present, exit 0, and no receipt file created (print-spawn never execs). Second case
`run_print_spawn_delegation_case`: same + `--tick-id T-9` → assert the printed output contains
`tick_id=T-9` and the literal delegation text `ship-flow-scheduler tick delegation`. Run against
current adapter (no `--print-spawn`) → fails (usage error).

**GREEN:** build `SHIP_PROMPT="/ship ${ENTITY}"`; when `TICK_ID` non-empty, append the verbatim
design.md AC-1 delegation line naming `tick_id`/receipt basename. Build `SPAWN_LINE` as a single
source-of-truth string reused by both `--print-spawn` and the real exec branch (Task 4 rewrites
what it contains, not two code paths). Add `--print-spawn`; before the
`SHIP_FLOW_SCHEDULER_RUNNER_CMD` branch, print `{"prompt":...,"spawn":...}` and exit 0 — folding
embedded newlines to spaces via `tr '\n' ' '` first, since `json_str_or_null` only escapes
backslash/quote (a real pre-existing gap the GREEN accounts for).

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh`

---

## Task 3 — AC-1c: thread tick_id from the tick into the adapter call

**Files:** `plugins/ship-flow/bin/ship-flow-scheduler.sh`, `test-scheduler-runner-adapter.sh`.

`run_dispatch_action` takes a trailing `tick_id` param; `cmd_tick` passes its own computed
`tick_id` at the call site; the real-adapter branch forwards it as `--tick-id`.

<details>
<summary>RED / GREEN mechanics</summary>

**RED:** new test case `run_tick_threads_tick_id_case`: one-entity workflow (copy
`eligible-entity`), `--runner gh` + `SHIP_FLOW_SCHEDULER_RUNNER_CMD=bash
.../stub-runner-echo-tick-id.sh`, run `ship-flow-scheduler.sh tick`, extract the dispatch event's
`receipt` path, `cat` it, assert `TICK_ID_SEEN=` is present and non-empty, shaped like
`[0-9]{8}T[0-9]{6}Z` (the `date -u +%Y%m%dT%H%M%SZ` format `cmd_tick` already computes at `:322-323`
for its own `tick_id` local). Run against current code (adapter never receives `--tick-id` from the
tick) → `TICK_ID_SEEN=` is empty, assertion fails.

**GREEN:** add a trailing `tick_id` param to `run_dispatch_action` (`:401`, param `$8`); at the
call site (`:367`) append `"$tick_id"` (already in scope in `cmd_tick`, computed at `:322-323`); in
the real-adapter branch (`:419`, `else`), add `--tick-id "$tick_id"` to the invocation. The
`--runner fixture` branch (`:410-414`) ignores the new param (fixture mode never calls the adapter).

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh`

---

## Task 4 — AC-2: launcher spawn rewrite + preflight widen

**Files:** `scheduler-runner-adapter.sh`, `ship-flow-scheduler.sh`, `test-scheduler-runner-adapter.sh`.

Rewrites the adapter's production branch to spawn via the spacedock launcher and widens the
`--runner gh` preflight to accept `spacedock` on PATH (not just `claude`).

<details>
<summary>RED / GREEN mechanics</summary>

**RED (a):** extend Task 2's print-spawn assertions: add checks for `--plugin-dir`, `-- -p
--output-format text`, and `${SPACEDOCK_BIN:-spacedock}`/literal `spacedock` in the `spawn` field.
Fails against Task 2's bare-`claude` `SPAWN_LINE`.

**RED (b):** new test case `run_tick_preflight_accepts_spacedock_bin_case`: build a scratch
`FAKE_BIN_DIR="$(mktemp -d)"` with an executable `spacedock` stub (`#!/usr/bin/env bash\nexit 0`,
never actually invoked — only `command -v` needs to find it); run `ship-flow-scheduler.sh tick`
with `PATH="${FAKE_BIN_DIR}:/usr/bin:/bin"` (deliberately excludes `/opt/homebrew/bin`,
`/usr/local/bin`, `~/.local/bin` where a real `claude`/`spacedock` might live on a dev machine — a
genuinely hermetic PATH restriction, not just "unset one var"), `--runner gh`, no
`SHIP_FLOW_SCHEDULER_RUNNER_CMD`, and an EMPTY workflow-dir (no entities at all, so the tick never
tries a real spawn — this isolates the preflight check itself). Assert exit 0 (falls through to
`no-op`/`nothing-eligible`), not exit 3. Fails today (`command -v claude` only check at
`ship-flow-scheduler.sh:318` → exit 3 "claude CLI not available").

**GREEN:** rewrite the adapter's production branch (`scheduler-runner-adapter.sh:64`) to build
`SPAWN_LINE="${SPACEDOCK_BIN:-spacedock} claude \"${SHIP_PROMPT}\" --plugin-dir
\"${WORKDIR}/plugins/ship-flow\" -- -p --output-format text"` and exec via that resolved form (not a
second hand-written command); widen the preflight at `:318` to also accept
`command -v "${SPACEDOCK_BIN:-spacedock}"` (both binaries absent = fail-closed).

**Execute-time non-blocking probe (per design.md, not a captain decision):** confirm
`--plugin-dir "$WORKDIR/plugins/ship-flow"` (vs bare `$WORKDIR`) is the correct level with one
`spacedock claude --help` read + a real one-shot manual run before trusting the hermetic test
alone — the hermetic test only proves the STRING is right, not that the launcher accepts it.

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh`

---

## Task 5 — AC-3a: `derive_timeout_sec`

**Files:** `ship-flow-scheduler.sh`, `test-scheduler-runner-adapter.sh`, NEW fixture entity
`plugins/ship-flow/lib/__tests__/fixtures/ship-flow-scheduler/workflow/time-budget-entity/{index.md,shape.md}`.

Parses frontmatter `time_budget` (`<N>h<M>m`/`<N>h`/`<M>m`) → seconds, falling back to the passed
default unchanged when absent/unparseable — see the regression-risk resolution above for why the
fallback (not an invented number) matters.

<details>
<summary>RED / GREEN mechanics</summary>

**RED:** new fixture entity = a copy of `eligible-entity`'s shape (status: shape, sd:approved OPEN
issue, no worktree/pr) + `time_budget: 2h30m` in frontmatter + matching
`gh/issue-time-budget-entity.env` (`state=OPEN`, `labels=sd:approved`). Two new test cases, both
`--runner fixture --runner-fixture dispatch-success.json` (hermetic, no real spawn needed — the
`detail.runner.timeout_sec` field is set by `run_dispatch_action` regardless of runner mode):
`run_tick_derives_timeout_from_time_budget_case` asserts `"timeout_sec":9000` for `time-budget-entity`;
`run_tick_defaults_timeout_without_time_budget_case` asserts `"timeout_sec":5400` for
`eligible-entity` with NO `--timeout` flag passed. Both fail today (no derivation exists;
`eligible-entity` case actually already emits `900` pre-fix, `time-budget-entity` doesn't exist
pre-fix either).

**GREEN:** add `derive_timeout_sec <path> <default>` near `read_frontmatter_field` — parses
`time_budget` (`<N>h<M>m`/`<N>h`/`<M>m`) to seconds, returning `<default>` unchanged when
absent/unparseable (implemented as committed — see `ship-flow-scheduler.sh`). In
`run_dispatch_action`, compute `dispatch_timeout_sec="$(derive_timeout_sec "$path" "$timeout_sec")"`
and use it (not `$timeout_sec`) for both the real adapter's `--timeout` arg and the
`detail.runner.timeout_sec` JSON field. Bump `cmd_tick`'s compiled default at `:288` from `local
timeout_sec=900` to `local timeout_sec=5400` (regression-risk resolution above — does NOT touch the
reconcile bound at `:467`, lease-bound per the F2 fix, unchanged).

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh`

---

## Task 6 — AC-3b: checkpoint on timeout-blocked detail

**Files:** `ship-flow-scheduler.sh`, `test-scheduler-runner-adapter.sh` (extend existing case).

The `timeout` branch of `run_dispatch_action`'s failure path reads the entity's current status and
adds a `checkpoint` object to the existing `blocked` event's detail (DC-4: not a new event value).

<details>
<summary>RED / GREEN mechanics</summary>

**RED:** extend `run_tick_surfaces_timeout_as_blocked_case` (`:69-86`) with two new assertions:
`'"checkpoint"'` and `'"resume_stage":"shape"'` present in `$OUT` (fixture `eligible-entity` has
`status: shape`). Fails today (no `checkpoint` key emitted).

**GREEN:** in `run_dispatch_action`'s failure branch (`:427-434`), scope the new field to the
`timeout` case only (matches design.md's explicit scoping — `run-error` stays unchanged): read
`resume_stage="$(read_frontmatter_field "$path" status)"` and build
`detail="$(printf '{"source":"%s","receipt":%s,"checkpoint":{"resume_stage":%s}}' ...)"` for the
`timeout` case (replaces the single shared `emit_event` detail line at `:433` with a `case`-scoped
`detail` var, then one `emit_event blocked "$slug" blocked "$source" "$detail"` call); the `*`
(run-error) case keeps the original 2-field detail unchanged.

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh`

---

## Task 7 — AC-4: `entity_in_backoff` + precedence-1/2 skip-continue

**Files:** `ship-flow-scheduler.sh`, NEW
`plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-backoff.sh`. No new fixtures needed (both
cases reuse `prompt-captain-entity` + `eligible-entity` verbatim, mirroring
`test-ship-flow-scheduler-reconcile.sh`'s fixture shape).

`entity_in_backoff` derives "blocked within the last N seconds" purely from `--events-log`; both
precedence loops `continue` past an in-backoff entity instead of ending the tick there.

<details>
<summary>RED / GREEN mechanics</summary>

**RED — case 1 (head-block, the cited Wave-0 incident):** new `two_entity_workflow` helper (copies
BOTH `prompt-captain-entity` and `eligible-entity` into one tmp dir, `git init -q`, mirrors
`one_entity_workflow` in the reconcile test). Pre-seed a fresh `--events-log` file with one line: a
`blocked`/`reconciler-prompt-captain` event for `prompt-captain-entity`, `ts` = right now (`date -u
+%Y-%m-%dT%H:%M:%SZ`, computed inline). Run `ship-flow-scheduler.sh tick --workflow-dir ...
--gh-provider fixture --gh-fixture-dir .../gh --pr-fixture
.../merged-pr-closeout-reconciler/pr-closed.env --runner fixture --runner-fixture
dispatch-success.json --events-log <seeded file>`. Assert exit 0, `"event":"dispatch"` +
`"entity":"eligible-entity"` present, and `"reconciler-prompt-captain"` NOT present in `$OUT` (this
tick's own emitted event, not the seeded history). Fails today: precedence-1 has no backoff check,
so it hits `prompt-captain-entity` (the only pr-bearing entity), calls `run_reconcile_action` for
real, gets `PROMPT_CAPTAIN`, emits `blocked` + `return 0` — the tick ends there, `eligible-entity`
is never reached, both assertions fail.

**RED — case 2 (window expiry):** single-entity workflow = `prompt-captain-entity` only (mirrors
`run_prompt_captain_case` exactly). Pre-seed events-log with the SAME kind of line but `ts =
"2020-01-01T00:00:00Z"` (unambiguously outside any real window — no clock-mocking needed). Same
tick invocation. Assert exit 0, `"event":"blocked"`, `"source":"reconciler-prompt-captain"` present
— i.e. A gets acted on again once its backoff window has passed. This case passes even
pre-fix (there's no regression to prove here yet) — its job is to prove the fix doesn't
OVER-suppress once the window elapses; write it RED-relative-to-a-strawman-always-skip
implementation, not RED-relative-to-today's-code.

**GREEN:** add `entity_in_backoff <slug> <events-log> <window>` near `read_frontmatter_field` —
tails the log for `<slug>`'s most recent event, returns true iff it's `blocked` and within
`<window>`s of now (reuses `scheduler_lease_epoch` from the already-sourced `scheduler-lease.sh`,
per DC-2/Rule 3 — no new store; implemented as committed — see `ship-flow-scheduler.sh`). In
`cmd_tick`, add `local BACKOFF_WINDOW_SEC=3600`. In precedence-1's loop (`:340`), right after
computing `slug`, add the `entity_in_backoff` guard (`continue` if true) before the `pr_val` read.
In precedence-2's loop (`:363`), add a `slug="$(entity_slug_from_path "$path")"` line at the top
and the same backoff-continue guard before `evaluate_entity`.

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-backoff.sh`

---

## Task 8 — AC-5: plist PATH placeholder + substitution smoke + RUNBOOK

**Files:** `com.spacedock.ship-flow-scheduler.tick.plist`, `test-ship-flow-scheduler-plist.sh`,
`docs/ship-flow/l3-scheduler-tick/RUNBOOK.md`.

Adds an `@USER_LOCAL_BIN@` placeholder to the tick plist's PATH, an install-time substitution step
in RUNBOOK.md, and the matching test coverage.

<details>
<summary>RED / GREEN mechanics</summary>

**RED:** add `assert_contains "tick plist: has @USER_LOCAL_BIN@ placeholder" '@USER_LOCAL_BIN@'
"$TICK_PLIST"` (mirrors the existing `@CONTROLLER_WORKTREE@` assertion at `:77`). Add
`-e 's|@USER_LOCAL_BIN@|/Users/testuser/.local/bin|g'` to `substitution_smoke`'s sed args (`:45-47`)
so BOTH plists' "no unsubstituted placeholder" check (`:49-53`) stays valid after the tick plist
gains a token the rollup plist doesn't have. Fails today: placeholder absent from the plist.

**GREEN:** edit `com.spacedock.ship-flow-scheduler.tick.plist:31` from
`<string>/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>` to
`<string>@USER_LOCAL_BIN@:/opt/homebrew/bin:/usr/local/bin:/usr/bin:/bin</string>`. Add to
RUNBOOK.md's install-step sed block (`RUNBOOK.md:73-76`) a fourth `-e` line:
`-e "s|@USER_LOCAL_BIN@|$HOME/.local/bin|g"` (never a hardcoded `/Users/kent` — DC-5), plus one
sentence noting `claude`/`spacedock` must resolve on this PATH for `--runner gh` to work
(cross-refs AC-5's Wave-0 incident).

</details>

**DC:** `bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-plist.sh`

---

## Task 9 — Canonical Doc Actions

| Doc | Action | Rationale |
| --- | --- | --- |
| `docs/ship-flow/l3-scheduler-tick/design.md` §2 | UPDATE (one line) | `blocked` detail-fields table row gains optional `checkpoint:{resume_stage}` — cross-ref `../tick-hardening/design.md` AC-3, no prose duplication |
| same, §6 | UPDATE (one line) | note optional `--tick-id` + launcher-spawn form on the adapter interface, cross-ref AC-1/AC-2 |
| `docs/ship-flow/l3-scheduler-tick/RUNBOOK.md` | UPDATE | Task 8's substitution step; one-line note on AC-3 resume-from-checkpoint (`tail` the latest `run-timeout` event's `detail.checkpoint.resume_stage`); one-line note that the AC-1 delegation marker retires the old 30-min-receipt `decisions.md` heuristic |
| `ROADMAP.md` (this worktree's copy) | UPDATE (Now-row only) | add the tick-hardening row to the Now section — this entity is committed, active work |
| `ROADMAP.md` — fold of `scheduler-tick-delegation-marker` / `pipeline-timeout-checkpoint-event` Later rows | **SKIP here** | Those two rows exist ONLY on the separate `iamcxa/muscat-v1` branch's `ROADMAP.md` (confirmed: grepped this worktree's `ROADMAP.md`, zero matches for either todo name). Cross-branch action — see Cut-list. |
| `ARCHITECTURE.md` | SKIP | existing `l3-scheduler-tick` row invariants (carrier-swap boundary, no state of record, concurrency=1 lease, reverse-recovery reuse) all stay true after this hardening |
| `INVARIANTS.md` | SKIP | shape.md parked a candidate invariant without committing to it; design.md confirms no change |
| `PRODUCT.md` | SKIP | scheduler value proposition unchanged — this hardens reliability of an already-stated capability |
| `README.md` (root) | SKIP | grepped: zero scheduler/launchd mentions; not a documented end-user surface |

**DC:** `git diff` on the touched doc files shows only the additions named above (no unrelated
edits); `bash scripts/check-no-dangling.sh` and `bash scripts/check-version-triple.sh` both still
pass.

---

## Cut-list (named, not silently dropped)

- **AC-4 precedence-2 dispatch-repeat protection — implemented, not independently tested this
  round.** Task 7's GREEN wires `entity_in_backoff` into BOTH precedence-1 and precedence-2 per
  design.md, but the two RED cases only exercise precedence-1 (the actual cited Wave-0 incident). A
  dedicated precedence-2 case is deferred as a follow-up test-only task — no cited live incident
  makes it non-blocking for this entity's appetite.
- **Exact `--plugin-dir` level** — design.md's own residual; Task 4 carries a one-line execute-time
  probe, not a plan-time decision.
- **`decisions.md` 30-min-receipt clause physical removal** — lives on `iamcxa/muscat-v1`, a
  different branch this worktree cannot commit to. FO-owned cleanup after this PR merges and AC-1
  ships.
- **ROADMAP.md Later-row fold** (`scheduler-tick-delegation-marker`,
  `pipeline-timeout-checkpoint-event`) — same cross-branch reason as above; FO marks them folded on
  `iamcxa/muscat-v1` directly once this PR's AC-1/AC-3 land.

---

## Terminal DCs (verify-stage, not execute tasks)

Dual-env green for the three CI-sensitive tests (per design.md AC-6) + the new backoff test:

```
for t in test-scheduler-runner-adapter.sh test-ship-flow-scheduler-backoff.sh \
         test-ship-flow-scheduler-reconcile.sh test-ship-flow-scheduler-fullcycle.sh; do
  bash "plugins/ship-flow/lib/__tests__/$t"
done
```
Normal env, then repeat identically under CI-sim:
```
env -i PATH=/usr/bin:/bin HOME="$HOME" \
  CI=true bash plugins/ship-flow/lib/__tests__/<each test>.sh
```
(no git identity, no `claude`/`spacedock` on PATH — matches the CI workflow's `CI=true timeout 90
bash "$t"` invocation shape at `.github/workflows/ship-flow-invariants.yml:110-118`). Full suite
(`for t in plugins/ship-flow/lib/__tests__/test-*.sh; do CI=true timeout 90 bash "$t"; done`) once
more at the end as the regression sweep for the other ~15 test files this plan doesn't touch.

## Post-merge FO handoff (LIVE proof — not a plan/execute/verify task)

Per the dispatch checklist: the live proof that the hardened tick actually dispatches under
launchd with the delegation marker present is FO-owned, post-merge. Suggested target: the queued
`no-dangling-guard-qualifier-precision` idea (`ROADMAP.md` Later, base branch) — let the next real
tick cycle pick it up once shaped, and confirm its receipt shows `SHIP_FLOW_SCHEDULER_TICK_ID` /
the delegation prompt line for real, not just in the hermetic fixtures above.
