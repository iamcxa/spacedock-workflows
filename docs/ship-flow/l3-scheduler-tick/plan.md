# L3 scheduler tick — stateless SD scheduler (Step-3 wedge v0) — Plan

### Summary

Decomposes design.md's contract into eight serial, atomic-commit tasks inside the single
dedicated controller worktree — one go/no-go precondition (T0), one RED-fixture-first task (T1)
covering all nine AC test gates, five implementation umbrellas (T2-T6: tick CLI + state
projection, runner adapter, gate report, reconcile+advance, launchd carrier + rollup), and the
two H7 terminal proofs (T7). Every task cites its design §, the AC(s) it satisfies, and an exact
DC command + expected output. All new files stay inside `plugins/ship-flow/{bin,lib,references}`
plus one entity-local `RUNBOOK.md` (design §8's own placement); zero `SKILL.md` edits; zero new
captain decisions (matches shape/design's `open_contract_decisions: []`). Canonical-doc patches
(ARCHITECTURE/PRODUCT/ROADMAP/INVARIANTS) are recorded as intent-only, deferred to ship, per
design §11. Elapsed time at plan hand-off: ~21 minutes of the 8h appetite (shape+design both
completed inside the H0:00-1:30 window) — ahead of pace; tasks are still sized to shape's own
hour-by-hour buckets, not to the banked slack, so scope stays anchored to the contract rather
than expanding into the extra headroom.

### Runtime commands (pinned from the existing harness)

- **Shell fixture tests** (per-file, from repo root — resolving `plugins/ship-flow/...`
  repo-root-relative matters, per the CI step comment in
  `.github/workflows/ship-flow-invariants.yml`):
  `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-<name>.sh`
- **Full local suite** (what CI's "Run full ship-flow shell test suite" step does):
  `for t in plugins/ship-flow/lib/__tests__/test-*.sh; do CI=true timeout 90 bash "$t" || echo FAILED:$t; done`
- **Node bin tests** (unaffected by this plan — no `.mjs` files added or touched; run as a
  regression smoke only): `node --test plugins/ship-flow/bin/*.test.mjs`
- **Version-triple / no-dangling** (regression smoke, no version bump and no doc links to
  nonexistent files introduced by this plan):
  `bash scripts/check-version-triple.sh` · `bash scripts/check-no-dangling.sh`
- **Lightweight invariants gate**: `CI=true bash plugins/ship-flow/bin/check-invariants.sh`

### Serial execution order (single worktree, no parallel waves)

`T0 → T1 → T2 → T3 → T4 → T5 → T6 → T7`, strictly serial. Later tasks depend on earlier
binaries existing (T3's adapter is wired into T2's dispatch action; T5's reconcile action calls
T3's adapter contract only indirectly via the tick's own event schema, but calls T4's report
data path conceptually for AC-4 cross-checks; T6's rollup consumes the events log T2 starts
appending in T1's fixtures). This is a deliberate departure from ship-flow's normal DAG execute
waves (design is a single new orchestration atom, not a multi-surface feature) — Rule 9's
concurrency=1 controller model makes serial build order the natural fit.

### Task → design § → AC → hour-bucket map

| Task | Deliverable | Design § | AC(s) | Shape hour bucket |
| --- | --- | --- | --- | --- |
| T0 | Go/no-go precondition (operational, not code) | shape.md hour-plan | prereq for AC-3 | H0:00–0:45 |
| T1 | RED fixture suite (8 files, 9 gates) | design §10 | AC-1..AC-6 | H0:45–1:30 (remainder) |
| T2 | Tick CLI core: dispatch + no-op + lease + state projection | design §1,§3,§4,§5 | AC-1, AC-2 | H1:30–3:15 |
| T3 | Runner adapter (carrier-swap seam) | design §6 | AC-3 | H3:15–4:15 |
| T4 | Derived gate-projection report | design §7 | AC-4 | H4:15–5:15 |
| T5 | Reconcile + advance actions (extends T2's switch) | design §4,§2 | AC-5 | H5:15–6:15 |
| T6 | launchd carrier + deterministic rollup + RUNBOOK.md | design §8 | AC-6 | H6:15–7:00 |
| T7 | Two terminal proofs: fixture full-cycle GREEN + real ticket #69 → `awaiting_merge` | design §10 (fullcycle row) | AC-5 terminal, overall v0 | H7:00–8:00 |

`tasks 2-6` ≈ 5.5h (H1:30→H7:00), matching the checklist's "roughly 5 hours" for the umbrella
build; T0/T1 sit inside the already-partly-spent H0:00-1:30 freeze window; T7 is the closing hour.

---

<details>
<summary>Per-task detail — TDD contracts, DC commands, file lists (T0–T7)</summary>

### T0 — Go/no-go precondition (not a commit)

Shape's H0:00-0:45 rule: *"one harmless bounded `claude -p` run returning a parseable terminal
sentinel. Fails → stop daemon work, supervised runner instead."* This gates T3's real-adapter
work, not just a nice-to-have.

- **Check**: `gh auth status && spacedock --version && command -v claude && command -v codex`
  all exit 0.
- **Sentinel proof**: `timeout 60 claude -p "/bye"` (or an equivalent harmless one-shot prompt)
  from the dedicated controller worktree, capturing a non-empty stdout and exit 0/124(timeout
  acceptable if a sentinel line was still emitted before the bound).
- **DC**: exit 0 on the auth/tooling check; a parseable line is present in the sentinel run's
  captured stdout. **Stop condition**: any tool missing or the sentinel run produces no
  parseable output → halt before T3, escalate to FO ("supervised runner, not daemon, for
  tonight").
- **Controller worktree**: created here if not already present —
  `git worktree add <fixed-path> -b ship-flow-scheduler-controller <base>` (path documented in
  T6's RUNBOOK.md `inspect` section). Not a plugin source change.

---

### T1 — RED fixture suite (all nine AC test gates)

**Files** (new): `plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-idempotence.sh`,
`test-ship-flow-scheduler-eligibility.sh`, `test-scheduler-runner-adapter.sh`,
`test-ship-flow-scheduler-reconcile.sh`, `test-ship-flow-scheduler-report.sh`,
`test-ship-flow-scheduler-rollup.sh`, `test-ship-flow-scheduler-fullcycle.sh`,
`test-ship-flow-scheduler-plist.sh` (8 files pinning the 9 rows of design §10 — idempotence file
carries both the replay-idempotence AND duplicate-dispatch-refusal rows, same as design's table).
Fixtures land under `plugins/ship-flow/lib/__tests__/fixtures/ship-flow-scheduler/` (entity
fixtures for eligible/not-shaped/issue-closed/not-approved/worktree-exists/pr-exists, stub
runner JSON for success/timeout/error, a fixed events JSONL for rollup determinism, stale/held
lease dirs). `test-ship-flow-scheduler-reconcile.sh` reuses the EXISTING
`fixtures/merged-pr-closeout-reconciler/*.env` fixtures directly (no duplication — the tick's
reconcile action shells out to the same script with the same `--pr-provider fixture
--pr-fixture` contract).

Each test file follows the existing harness convention (`assert_exit` / `assert_contains` /
`assert_not_contains` / `record_pass` / `record_fail`, `PLUGIN_ROOT`-relative `HELPER=` var) seen
in `test-merged-pr-closeout-reconciler.sh`, and its FIRST assertion is `[ -x "$HELPER" ]` (or the
equivalent for `report`/`rollup`) so the RED failure reason is legible, not a raw crash.

**TDD contract**:
- `red_command`: `for t in plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-*.sh plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh; do CI=true timeout 90 bash "$t"; echo "exit=$? $t"; done`
- `expected_red_failure`: every file reports `exit=1` (or nonzero) with `FAIL: helper exists (missing file: .../bin/ship-flow-scheduler.sh)` (or `.../lib/scheduler-runner-adapter.sh`) as the first failing assertion — none of T2-T6's binaries exist yet.
- `green_command`: same loop.
- `refactor_check`: none at T1 (test authoring only); refactor checks live in T2-T6 where the tests turn green.

**DC**: the RED loop above exits nonzero for all 8 files with the "missing helper" reason
visible in output. This is committed as `test(ship-flow-scheduler): add RED fixture suite for
tick/report/rollup contracts (AC-1..AC-6)`.

---

### T2 — Tick CLI core: dispatch + no-op + lease + state projection

**Files**: `plugins/ship-flow/bin/ship-flow-scheduler.sh` (new — `tick` subcommand only for
now; `report`/`rollup` land in T4/T6), `plugins/ship-flow/lib/scheduler-lease.sh` (new).
Implements design §1 (CLI flags + exit codes 0/2/3/4), §3 (state-projection reads — no writes),
§4 (idempotence: dedup via no-live-worktree/no-open-or-merged-PR eligibility exclusion + fixed
action precedence, `reconcile → dispatch → advance → no-op` — T2 wires `dispatch`/`no-op` only;
`reconcile`/`advance` land in T5 as the same switch's remaining branches), §5 (mkdir-atomic
lease + stale reclaim + `trap … EXIT` release). Dispatch action in T2 runs ONLY against
`--runner fixture --runner-fixture <path>` (the real `claude -p` wiring is T3's job) — this
decouples T2's tests from T3's existence, matching design's own stub-runner fixture contract for
the adapter interface.

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-idempotence.sh; CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-eligibility.sh`
- `expected_red_failure`: both still fail from T1 (helper missing).
- `green_command`: same two commands.
- `refactor_check`: `shellcheck plugins/ship-flow/bin/ship-flow-scheduler.sh plugins/ship-flow/lib/scheduler-lease.sh` (repo already runs shellcheck-clean bash across `bin/`/`lib/`; no new warnings).

**DC**: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-idempotence.sh && CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-eligibility.sh` → both exit 0, all `PASS:` lines, zero `FAIL:`. Manual smoke:
`plugins/ship-flow/bin/ship-flow-scheduler.sh tick --workflow-dir docs/ship-flow --controller-worktree <ctrl> --runner fixture --runner-fixture <fixture> --dry-run` prints one JSON Lines
event on stdout matching the §2 envelope and exits 0.

---

### T3 — Runner adapter (carrier-swap seam)

**Files**: `plugins/ship-flow/lib/scheduler-runner-adapter.sh` (new). Implements design §6
exactly: `run --entity <ref> --workdir <path> --timeout <sec> [--env K=V …]` →
`timeout <sec> claude -p "/ship <entity>"`, single JSON line
`{"exit_class":...,"sentinel":...,"receipt":...}` on stdout, exit-code mapping
`0/124/1 → success/timeout/error`. Then rewires T2's dispatch action to call this adapter when
`--runner gh` (the production path) instead of the fixture stub.

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-scheduler-runner-adapter.sh`
- `expected_red_failure`: FAIL — helper missing (carried from T1).
- `green_command`: same command.
- `refactor_check`: `shellcheck plugins/ship-flow/lib/scheduler-runner-adapter.sh`.

**DC-1 (fixture)**: the RED command above exits 0, all `PASS:` (success/timeout/error stub
cases each produce correct `exit_class`+`sentinel`+`receipt`; timeout case additionally asserts
the tick surfaces it as a `blocked` event with `source=run-timeout`, no retry).
**DC-2 (real sentinel — AC-3's "one real sentinel spawn log")**:
`plugins/ship-flow/lib/scheduler-runner-adapter.sh run --entity <T0's sentinel ref> --workdir <ctrl> --timeout 60` emits exactly one JSON line with `exit_class` ∈ {success,timeout,error} and a `receipt` path that exists on disk — this reuses T0's already-proven harmless spawn rather than a fresh live `/ship` invocation, so it stays within budget.

---

### T4 — Derived gate-projection report

**Files**: extends `plugins/ship-flow/bin/ship-flow-scheduler.sh` with the `report` subcommand
(design §7): read-only markdown table (`entity | state | pr_head | verify_verdict | gh_checks |
cross_model | age`), `--json` variant, rows limited to non-terminal projections. Two no-write
code gates: (1) static grep — the report code path contains no `status --set|--archive`,
`git commit|push`, or tracked-file redirection; (2) runtime — `git status --porcelain` empty
after running `report` against a fixture workflow dir.

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-report.sh`
- `expected_red_failure`: FAIL — helper missing.
- `green_command`: same command.
- `refactor_check`: grep gate itself IS the refactor check — `grep -nE 'status --set|--archive|git (commit|push)' plugins/ship-flow/bin/ship-flow-scheduler.sh` inside the report-subcommand's line range returns nothing.

**DC**: RED command exits 0 all PASS, including: (a) the static grep gate passes, (b)
`plugins/ship-flow/bin/ship-flow-scheduler.sh report --workflow-dir <fixture-dir>` followed by
`git -C <fixture-repo> status --porcelain` prints nothing (empty).

---

### T5 — Reconcile + advance actions (AC-5)

**Files**: extends `plugins/ship-flow/bin/ship-flow-scheduler.sh`'s action-precedence switch
(same file as T2/T4 — no new file) to implement the `reconcile` and `advance` branches of design
§4's fixed precedence (`reconcile → dispatch → advance → no-op`). `reconcile` shells out to the
EXISTING `bin/merged-pr-closeout-reconciler.sh --workflow-dir <dir> --entity <ref> --pr-provider
gh|fixture [--pr-fixture <path>]` unmodified (composed primitive, not reimplemented); any
`PROMPT_CAPTAIN` (exit 1) → tick emits terminal `blocked` (`source=reconciler-prompt-captain`),
no auto-cleanup. `advance` recomputes readiness via the EXISTING `lib/dag-waves.sh --ready
--from-workflow <dir> --epic <id>`, where `<id>` is the just-reconciled entity's own
`parent_pitch` frontmatter field — **scope note**: v0 only recomputes the ready-set for that
one epic (the entity that just merged), not a global multi-epic scan; a merged entity with no
`parent_pitch` makes `advance` a no-op on that tick (the next entity is picked up by T2's plain
`dispatch` eligibility scan on a later tick instead). This narrowing is named explicitly in the
cut-list below.

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-reconcile.sh`
- `expected_red_failure`: FAIL — helper missing.
- `green_command`: same command.
- `refactor_check`: confirm zero changes to `merged-pr-closeout-reconciler.sh` / `dag-waves.sh` output contracts — `git diff --stat plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh plugins/ship-flow/lib/dag-waves.sh` is empty.

**DC**: RED command exits 0 all PASS — a fixture reconciler run returning `PROMPT_CAPTAIN`
produces a `blocked` event (not a retry, not a crash); a fixture returning `PROCEED` produces a
`reconcile` event with `terminal_state=reconciled` followed by an `advance` event naming the
next ready entity from a fixture DAG.

---

### T6 — launchd carrier + deterministic rollup + RUNBOOK.md

**Files**: extends `plugins/ship-flow/bin/ship-flow-scheduler.sh` with the `rollup` subcommand
(design §8: reads a day's JSONL events, emits deterministic markdown — dispatches, durations,
gate waits, failures, costs, interventions — no wall-clock in the body); new
`plugins/ship-flow/references/launchd/com.spacedock.ship-flow-scheduler.tick.plist` and
`...rollup.plist` (templates with `@CONTROLLER_WORKTREE@`/`@SPACEDOCK_BIN@`/`@WORKFLOW_DIR@`
placeholders); new `docs/ship-flow/l3-scheduler-tick/RUNBOOK.md` (entity-local per design §8's
own placement — not a `plugins/ship-flow` source change, so it doesn't violate the
plugin-surface constraint below) documenting inspect (`report`, tail events log, read lease
record) / unlock (remove lease dir ONLY when proven stale) / rerun (`tick` once by hand) /
launchd install (`launchctl load/unload` with the substituted plist).

**TDD contract**:
- `red_command`: `CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-rollup.sh; CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-plist.sh`
- `expected_red_failure`: both FAIL — helper/plist files missing.
- `green_command`: same two commands.
- `refactor_check`: `plutil -lint plugins/ship-flow/references/launchd/*.plist` (macOS; `xmllint --noout` as the portable fallback) — both templates parse after placeholder substitution with dummy values.

**DC**: both RED commands exit 0 all PASS — rollup determinism proven by feeding the same fixed
fixture events log twice and `diff`-ing the two markdown outputs (empty diff, byte-identical);
plist well-formedness proven by lint + a placeholder-substitution smoke
(`sed` the three `@…@` tokens, then `plutil -lint`). `RUNBOOK.md` existence:
`test -f docs/ship-flow/l3-scheduler-tick/RUNBOOK.md`.

---

### T7 — Two terminal proofs (H7:00-8:00)

Not a source-code task — the plan's terminal DCs, per the checklist. No new files beyond the
fullcycle test (already authored RED in T1).

**DC-1 (fixture full-cycle)**:
`CI=true timeout 90 bash plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-fullcycle.sh`
exits 0, all PASS — a fixture-driven dispatch → PR-ready → merged → reconcile →
`dag-waves --ready` next-ready sequence runs end to end using T2/T3/T4/T5's now-landed pieces.

**DC-2 (real proof)**: `reverse-recovery-audit-dangling-path` (gh issue #69, confirmed OPEN +
`sd:approved` — checked live during this plan) is the live single-entity target. **Precondition
outside this plan's scope**: that entity (`docs/ship-flow/reverse-recovery-audit-dangling-path/`)
currently sits at `status: draft` — it needs a shape-confirm pass (separate, smaller dispatch,
not part of this plan's code tasks) before the tick's dual-key eligibility check (shaped AND
`sd:approved`) will pick it up. Once shaped: `plugins/ship-flow/bin/ship-flow-scheduler.sh tick
--workflow-dir docs/ship-flow --controller-worktree <ctrl> --runner gh` run repeatedly (real
interval or manual rerun) until the entity's frontmatter shows `pr:` set and gh PR state is
OPEN with `verdict: PASSED` (the `awaiting_merge` projection, design §3). Captain merge and the
post-merge reconcile/advance are explicitly OUT of tonight's real-proof scope (real runs stop at
`awaiting_merge` per Rule 2 — the post-merge half is proven by T5's fixtures only tonight, per
shape.md's own "Post-merge half proven by fixtures tonight, exercised live after morning merge").

</details>

---

### Cut-list (named, not silent)

- **Global multi-epic `advance` scan** — v0's `advance` only recomputes readiness for the
  just-merged entity's own `parent_pitch` epic (T5), not a workflow-wide ready scan across every
  epic. A standalone (non-epic) `sd:approved` entity is still picked up — just via the next
  tick's plain `dispatch` eligibility scan, not via `advance`. Follow-up todo: epic-enumeration
  wrapper if multi-epic auto-advance proves necessary post-hackathon.
- **Rollup cost field** — `costs` in the daily rollup (design §8) stays `n/a` for every
  dispatch in v0; parsing `claude -p` token/cost telemetry out of the runner receipt is deferred.
  Follow-up todo: wire real cost extraction once the receipt schema is proven stable.
- **launchd install/uninstall automation** — T6 ships plist *templates* + a manual
  `launchctl load/unload` runbook step, not an installer script. Follow-up todo: a thin
  `scheduler-install.sh` wrapper if the manual step proves error-prone across sessions.

None of these narrow an AC — each is an explicitly-scoped-smaller v0 implementation of an AC
that design already left open at the "how much automation" level (design §4/§8 describe the
mechanism, not the exact scan breadth or cost-field fidelity).

---

### Canonical Doc Actions

| Doc | Action | Source | Rationale |
| --- | --- | --- | --- |
| ROADMAP.md | skip (defer to ship) | design §11 | design scopes the `l3-scheduler-tick` → `Now` move and the real-proof-ticket note to ship time; plan records intent only, does not patch canonical docs (shape's own rule: "do not patch canonical docs during shape/plan — record intent, plan owns the patch" — plan is recording, ship executes the write). |
| ARCHITECTURE.md | skip (defer to ship) | design §11 | carrier-swap boundary decision (`ship-flow-scheduler tick` deterministic/idempotent/stateless atom; launchd/crewdock interchangeable carriers; no writable gate ledger) lands as a `<!-- section:decisions -->` row on ship, via section-tag/patch-map per Principle 5 — not freehand, not now. |
| PRODUCT.md | skip (defer to ship) | design §11 | new user-facing capability (unattended approved-work → PR-ready queue, human retains merge authority) recorded on ship. |
| INVARIANTS.md (plugin) | skip | design §11 | no invariant change proposed at v0 — the ten hard rules are v0 contract, not plugin invariants; matches shape's identical call. |

### Plugin-surface + no-SKILL.md confirmation

Every new/modified file this plan introduces:

| Path | New/Modified |
| --- | --- |
| `plugins/ship-flow/bin/ship-flow-scheduler.sh` | new |
| `plugins/ship-flow/lib/scheduler-lease.sh` | new |
| `plugins/ship-flow/lib/scheduler-runner-adapter.sh` | new |
| `plugins/ship-flow/references/launchd/com.spacedock.ship-flow-scheduler.tick.plist` | new |
| `plugins/ship-flow/references/launchd/com.spacedock.ship-flow-scheduler.rollup.plist` | new |
| `plugins/ship-flow/lib/__tests__/test-ship-flow-scheduler-*.sh` (6), `test-scheduler-runner-adapter.sh` | new |
| `plugins/ship-flow/lib/__tests__/fixtures/ship-flow-scheduler/**` | new |
| `docs/ship-flow/l3-scheduler-tick/RUNBOOK.md` | new (entity-local doc, design §8's own placement) |

Zero edits to `plugins/ship-flow/skills/**/SKILL.md` (design §11 names none). Zero edits to
`merged-pr-closeout-reconciler.sh` / `dag-waves.sh` / `fo-completion-lease.sh` output contracts
(reuse-only — T5's `refactor_check` proves this with an empty `git diff --stat`). Every new file
is additive under `plugins/ship-flow/{bin,lib,references}` plus the one entity-local RUNBOOK,
matching the checklist's plugin-surface constraint.

### Plan Report

- status: passed
- task_count: 8 (T0 precondition + T1 fixture-first + T2-T6 implementation umbrellas + T7 terminal proofs)
- verification_spec_count: 9 (AC test gates, design §10, mapped 1:1 to T1's 8 files)
- hour_budget_check: tasks T2-T6 total ≈5.5h against shape's H1:30-7:00 window ("roughly 5 hours" per checklist); T0/T1 inside H0:00-1:30; T7 inside H7:00-8:00; elapsed at plan hand-off ≈21min of 8h appetite (shape+design both completed inside the H0:00-0:45 window with room to spare)
- open_contract_decisions: 0 (matches shape/design)
- cut_list_count: 3 (named above; none narrow an AC)
- canonical_doc_actions: 4/4 skip-defer-to-ship (ROADMAP, ARCHITECTURE, PRODUCT, INVARIANTS)
- skill_md_edits: 0
