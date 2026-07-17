<!-- section:plan-report -->
## Research Summary

**A2 is contradicted — the trigger surface is THREE, not two, plus one legitimate out-of-scope exception.** Enumerated by grepping the whole plugin, `hooks.json`, the FO skill references, and every ship-flow SKILL.md for `status=done|--archive|reconciler|merge guard`:

1. **`plugins/ship-flow/hooks/warn-state-drift.sh`** — Claude-Code `SessionStart` hook (`hooks.json:16`). Rule A auto-fix block (lines 224-260) directly calls `status --set status=done verdict=PASSED completed=…` then `status --archive`, then `git add`+`git commit -m "done + archive: …auto-fix from SessionStart hook"`.
2. **`plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh`** — manual CLI (`--workflow-dir --entity [--pr-provider gh|fixture] [--dry-run]`). Calls `run_status --set … status=done … worktree=` then `--archive`. **Never calls `git commit`** — confirmed by full read; no `git add`/`git commit` anywhere in the file. Its output is left uncommitted today (a real, pre-existing gap this plan also closes).
3. **`docs/ship-flow/_mods/pr-merge.md` `## Hook: startup` / `## Hook: idle`** (lines 11-31) — **the previously-unenumerated third path.** This is spacedock-core's own Mod Hook Convention (`first-officer-shared-core.md` — `«hooks.run»(point)`, points `startup|idle|merge`, discovered from `{workflow_dir}/_mods/*.md` `## Hook: {point}` headings). It is PROSE consumed by the *live FO agent itself* at every `«engage»()` cycle boundary — not a shell script. Its body instructs the FO to run `gh pr view`, then the identical raw `status --set status={terminal} … ` + `--archive` two-step, bypassing `merge guard` exactly like paths 1-2. Confirmed via `plugins/ship-flow/references/pr-merge-paths.md`: "the dogfood repo's own merge flow (its repo-local `_mods/pr-merge.md`…) consumes this stack" — i.e. this file IS this workflow's own, and per `sync-drift-check.md`'s own example manifest, `pr-merge` is the canonical example of a `"local-only"` bucket mod (freely editable; no `docs/ship-flow/sync-manifest.json` exists in this repo, so the drift gate is inert — confirmed by absence of that file). This is likely the *most frequently firing* path during normal live FO-driven `/ship` sessions, since it runs on every idle/startup boundary, not just Claude-Code session start.
4. **Out of scope, confirmed legitimate exception**: `plugins/ship-flow/skills/ship-execute/SKILL.md` "Inline-on-main ship pattern" (lines 358-379) — a **no-PR** path for pure ship-flow self-reforming entities. It deliberately uses `--force` to bypass the very guard this plan relies on (see below), by design, because there is no PR to merge-guard against. The shape's problem statement is specifically about *merged-PR* convergence; this pattern never creates a PR. Recommend documenting it explicitly as an intentional non-member of the trigger set (D2), not folding it into the adapter.

No FO-native mechanism beyond the Mod Hook Convention exists — `spacedock:first-officer`'s own `«roster-reconcile»`/`dispatch reconcile` is a *worker-roster* drift sweep, unrelated to PR/entity closeout (confirmed by reading `fo-dispatch-core.md`, `claude-fo-dispatch.md`).

**Empirical pin of `spacedock merge guard` (installed binary 0.25.0, contract 3) — all four probes run against an isolated `mktemp -d` fixture workflow, never a real entity:**

| Probe | Command | Result |
|---|---|---|
| Nonexistent slug | `merge guard bogus --verdict passed --workflow-dir <tmp>` | exit 1, `Error: entity not found: bogus` |
| Bare unmerged PR ref (`pr: "#47"`) | `merge guard <slug> --verdict passed …` | **exit 0**, `blocked: PR #47 is pending — mod-block left intact, never finalize on an open PR. When gh reports it MERGED, record the sentinel (pr=pr-merge:{number}) and re-run …` — non-error, names the exact sentinel contract |
| Valid sentinel (`pr: pr-merge:99`), cold/non-armed | `merge guard <slug> --verdict passed …` | exit 0, `finalized: <slug> -> done (verdict passed), archived.` — **one call**, no pre-arming needed, confirms A1 |
| Replay on already-archived entity | same command again | exit 1, `Error: archived entity is read-only: <slug>` — idempotent-replay must be interpreted by the *caller*, merge guard does not silently no-op |

Also confirmed empirically: `merge guard` never invokes `gh` and never runs `git commit` itself (ran successfully with **no git repository present at all**) — both remain caller/adapter responsibilities, matching A3. A plain sentinel-only field write (`status --set <slug> pr=pr-merge:{N}`, no `status=` change) always succeeds regardless of merge-hook registration — safe write-ahead primitive.

**Safety gap found (motivates unification beyond dedup):** the underlying `status --set status=done`/`--archive` guard that paths 1-2-3 rely on today only checks *"is `pr:` non-empty"* — a bare unmerged ref like `pr: "#47"` satisfies it and lets a raw `--set status=done` through with **zero merged-state verification**, unlike `merge guard` which correctly refuses/blocks on the same bare ref. Verified live: `status --set fake status=done …` with `pr: "#47"` → succeeds (exit 0); `merge guard fake --verdict passed` with the identical fixture → `blocked` (no mutation). Today's three paths only avoid this hole because each does its *own* `gh pr view` MERGED check before calling `--set`. Converging onto `merge guard` closes this hole structurally instead of by convention.

<details>
<summary>Fixture commands used (reproducible, isolated tmp dir, no real entity touched)</summary>

```
TMP=$(mktemp -d); mkdir -p "$TMP/wf/_mods"
# README.md with terminal `done` stage, _mods/pr-merge.md registering `## Hook: merge`
# fixture entities: pr: "" / pr: "#47" / pr: pr-merge:99
spacedock status --workflow-dir "$TMP/wf" --set fake-entity status=done verdict=PASSED  # refused, empty pr
spacedock status --workflow-dir "$TMP/wf" --set fake-entity status=done verdict=PASSED  # (pr="#47") succeeds — the safety gap
spacedock merge guard fake-entity --verdict passed --workflow-dir "$TMP/wf"              # blocked (correct)
spacedock merge guard fake-entity2 --verdict passed --workflow-dir "$TMP/wf"             # finalized (pr=pr-merge:99)
spacedock merge guard fake-entity2 --verdict passed --workflow-dir "$TMP/wf"             # archived entity is read-only (replay)
```
</details>

**Existing debrief surface** (for D3): `warn-state-drift.sh` already emits a captain-facing markdown report (`msg`, via SessionStart `hookSpecificOutput.additionalContext`); `_mods/pr-merge.md` already instructs "Report each auto-advanced entity to the captain"; `merged-pr-closeout-reconciler.sh` already emits structured `key=value` via `emit_report`. No dedicated "debrief-due" tracking exists (`README.md:489`: debrief is manual, `spacedock:debrief` run by convention). Design: the adapter's own `emit_report` gains one new field (`debrief_due=<slug>`) set only on a successful finalize; all three calling surfaces already have a render point to surface it — no new report channel needed.

**Reverse-recovery**: no new domain/abstraction created. This plan renames+extends the existing reconciler CLI (`git mv`, preserves history) and edits 4 existing files (hook, mod, 2 docs). N/A for proof-of-absence.

## Size Re-evaluation

Sharp/shape appetite: small-batch. Actual affected files: `bin/merged-pr-closeout-reconciler.sh`→`bin/closeout-adapter.sh` (+ test), `hooks/warn-state-drift.sh` (+ test), `docs/ship-flow/_mods/pr-merge.md`, `plugins/ship-flow/references/pr-merge-paths.md`, `plugins/ship-flow/README.md` = 7 files. Per Step 2.5 table (4-15 files): **size: M** (confirmed).

## Context Manifest

- **Skills loaded**: ship-flow:ship-plan (self), superpowers:writing-plans (authoring discipline, applied inline — no separate teammate available in solo-ensign dispatch)
- **INVARIANTS sections read**: n/a (no Principle-specific research needed — no UI, no schema)
- **Architecture docs consulted**: `plugins/ship-flow/references/pr-merge-paths.md`, `plugins/ship-flow/README.md` §Layer C primitive inventory + §The pipeline + §Release Notes, `plugins/ship-flow/references/architecture-lens-triggers.yaml` (no match)
- **Domains touched**: none (carlove tag/customer/event-saga domains do not match `bin/**/*.sh`, `_mods/*.md`, or ship-flow-internal file globs/keywords)
- **Lens dispatched**: none (no trigger match)
- **Lens findings integrated**: 0 integrated, 0 deferred, 0 ignored
- **Folder guidance**: files=`plugins/ship-flow/bin/*.sh`,`plugins/ship-flow/hooks/*.sh`,`docs/ship-flow/_mods/*.md` → `folder_guidance_files=` none found (no non-root `AGENTS.md`/`CLAUDE.md` under `plugins/ship-flow/` or `docs/ship-flow/`); `folder_guidance_skills=` none; `codex_context_boundary=root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files`

## Plan Imported Design DCs

design-skipped (no UI surface, no matched domain, no `design_required` signal, no contract decision required — shape.md `### Hand-off to Plan`).

## Verification Spec

| DC | Assertion | Type | Verify Procedure | Expected |
|---|---|---|---|---|
| DC-1 | `closeout-adapter.sh` writes the `pr=pr-merge:{N}` sentinel before any terminal mutation, path-scoped-committed | cli | run adapter against a fixture entity with `pr:"#N"` + stub `gh`→MERGED; `git log -1 --name-only` | commit touches only the entity file; frontmatter `pr:` = `pr-merge:{N}` |
| DC-2 | Adapter delegates terminal mutation to `spacedock merge guard <slug> --verdict passed --workflow-dir <dir>` (via `${SPACEDOCK_BIN:-spacedock}`), never raw `--set status=done`/`--archive` | cli | `grep -c 'merge guard' bin/closeout-adapter.sh` > 0; `grep -c '\-\-set.*status=done' bin/closeout-adapter.sh` == 0 | adapter has zero raw terminal `--set status=done` calls |
| DC-3 | Idempotent replay is a no-op | cli | run adapter twice against an already-archived fixture entity | 2nd run: `verdict=PROCEED state=already_reconciled`, no mutation, exit 0 |
| DC-4 | Dirty-worktree / wrong-branch fails closed, sentinel already persists | cli | write sentinel, dirty the fixture repo, run adapter | exit 0 non-fatal, `state=closeout-deferred-dirty-tree` (or equivalent), sentinel unchanged on disk; re-run after `git stash` converges |
| DC-5 | Missing state driver (merge-guard subcommand unavailable) fails closed with a stable diagnostic | cli | stub `spacedock` binary lacking `merge guard`; run adapter | exit non-zero, stderr contains literal `state-driver unavailable` |
| DC-6 | OPEN / CLOSED / UNKNOWN / gh-unavailable PR states never mutate | cli | run adapter with fixture PR states OPEN, CLOSED, UNKNOWN, and `gh` absent | no `--set`/`--archive`/`merge guard` call in any case; each reports distinctly |
| DC-7 | `_mods/pr-merge.md` Hook: startup/idle delegate to the adapter (prose-level, grep-checkable) | cli | `grep -n 'closeout-adapter.sh' docs/ship-flow/_mods/pr-merge.md`; `grep -c '\-\-archive' docs/ship-flow/_mods/pr-merge.md` | adapter invocation present; raw `--archive` call removed from Hook bodies |
| DC-8 | `warn-state-drift.sh` Section 4b delegates to the adapter per Rule-A entity instead of raw mutation | cli | `bash lib/__tests__/test-warn-state-drift.sh` new case | adapter invoked once per Rule-A record; commit message pattern preserved for backward-compat parsing |
| DC-9 | Successful finalize emits a non-blocking `debrief_due=<slug>` signal; never blocks or rolls back closeout on debrief-signal failure | cli | run adapter through a full successful finalize; `echo $?` | exit 0 regardless of whether the debrief line is consumed downstream; `debrief_due=<slug>` present in `emit_report` stdout |
| DC-10 | `merged-pr-closeout-reconciler.sh` is retired (renamed, no dangling references) | cli | `bash scripts/check-no-dangling.sh`; `grep -rl merged-pr-closeout-reconciler.sh plugins/ plugins/ship-flow/README.md` | no-dangling passes; zero live (non-archived) references to the old filename |
| DC-11 | Full local CI-equivalent suite green | cli | see Runtime Commands below | all 4 commands exit 0 |

## Plan

Wave 0 — pure rename, zero behavior change (baseline for clean diffs downstream)

**T1 — Rename reconciler → adapter (git mv only)**
- Files: `plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh` → `plugins/ship-flow/bin/closeout-adapter.sh`; `plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh` → `plugins/ship-flow/lib/__tests__/test-closeout-adapter.sh` (update internal `HOOK`/script-path variable + header comment only)
- `skills_needed`: `["test", "best-practices"]`
- `parallel_group`: serial · `depends_on`: none · `owned_paths`: the 2 renamed files · `integration_owner`: self
- `TDD`: skip -- pure rename with existing coverage as the RED/GREEN proof (suite must be 100% green identically before and after — that equality IS the test)
- Done: `bash plugins/ship-flow/lib/__tests__/test-closeout-adapter.sh` exits 0, same pass count as the pre-rename baseline run.

Wave 1 — adapter behavior change (RED before GREEN, single file)

**T2 — RED: extend fixture `status_bin` stub + write failing cases; GREEN: rewrite adapter core**
- Files: `plugins/ship-flow/lib/__tests__/test-closeout-adapter.sh`, `plugins/ship-flow/bin/closeout-adapter.sh`
- `skills_needed`: `["test", "tdd", "best-practices"]`
- `parallel_group`: serial · `depends_on`: T1 · `owned_paths`: same 2 files · `integration_owner`: self
- RED: extend `write_fixture_status_bin` to additionally simulate `merge guard <slug> --verdict <v> [--workflow-dir <dir>]` per the 4 empirically-observed outcomes (finalized / blocked / entity-not-found / archived-read-only) and `--set <slug> pr=pr-merge:<N>` (always-succeeds sentinel write). Add new failing cases: `run_sentinel_write_case`, `run_merge_guard_delegate_case`, `run_merge_guard_blocked_case`, `run_idempotent_replay_case`, `run_dirty_worktree_fail_closed_case`, `run_wrong_branch_fail_closed_case`, `run_state_driver_unavailable_case`, `run_debrief_due_signal_case`, `run_no_raw_terminal_set_case` (DC-2, grep-based). Confirm all fail against the T1 (unmodified-behavior) adapter.
- GREEN: on MERGED, write the sentinel (`run_status --set "$entity_slug" pr="pr-merge:${pr_number}"`) and commit it path-scoped BEFORE the dirty/branch gate (write-ahead, DC-1). Then gate: reuse/generalize `preflight_worktree_cleanup`'s dirty-check to the repo root (not only the FO-recorded `worktree` field) plus a branch-context check; dirty/wrong-branch → return non-fatally with the sentinel already committed (DC-4), leaving the *terminal* mutation for a later clean run. If clean: resolve `${SPACEDOCK_BIN:-spacedock}` and invoke `merge guard "$entity_slug" --verdict passed --workflow-dir "$workflow_dir"`; interpret its 4 outcomes exactly as pinned in Research Summary (`finalized`→success+path-scoped-commit-archive-move+`debrief_due=`; `blocked`→non-fatal `await-pr-sentinel-resume`, no mutation; `archived entity is read-only`→idempotent no-op, `verdict=PROCEED state=already_reconciled`; anything else / subcommand missing → `state-driver unavailable`, exit non-zero, sentinel untouched). Remove the raw `run_status --set status=done …` / bare `--archive` calls entirely (DC-2). Preserve existing `--pr-provider gh|fixture`, `--dry-run`, worktree/branch cleanup, and `emit_report` shape (additive `debrief_due=` field only — no removed fields, no caller breakage).
- Done: `bash plugins/ship-flow/lib/__tests__/test-closeout-adapter.sh` exits 0 (old + all new cases green); `grep -c '\-\-set.*status=done' plugins/ship-flow/bin/closeout-adapter.sh` == 0.

Wave 2 — caller rewire (depends on the adapter's contract being locked)

**T3 — RED: warn-state-drift.sh delegates to adapter; GREEN: rewire Section 4b**
- Files: `plugins/ship-flow/hooks/warn-state-drift.sh`, `plugins/ship-flow/lib/__tests__/test-warn-state-drift.sh`
- `skills_needed`: `["test", "best-practices"]`
- `parallel_group`: serial · `depends_on`: T2 · `owned_paths`: the 2 files · `integration_owner`: self
- RED: add `run_delegates_to_adapter_case` — substitute a spy/stub `closeout-adapter.sh` in the test env, assert it is invoked once per Rule-A record with `--workflow-dir --entity --pr-provider gh`; keep existing `run_dirty_tree_case`/`run_execute_merged_case`/`run_reprobe_not_merged_case` passing against the NEW call shape (update their fixtures/assertions, not their intent).
- GREEN: replace Section 4b's raw re-probe+`--set`+`--archive`+`git commit` block (lines ~211-278) with one adapter call per Rule-A record; parse the adapter's `emit_report` stdout to classify into the existing `auto_fixed_lines`/`auto_fix_blocked_lines` buckets, plus a new `debrief_due_lines` bucket surfaced in the SessionStart message when `debrief_due=` is present. Section 3's own Rule-A detection `gh pr view` (the *reporting* scan, independent of auto-fix) is unchanged — it still drives which entities are drift-worthy to list; the adapter's own internal re-probe now covers the detect→exec race the old Section 4b re-probe used to guard.
- Update the two fallback message strings (lines ~304, ~314) that currently point at the manual `ship-execute/SKILL.md` inline-on-main sequence for a PR'd entity — repoint them at `bin/closeout-adapter.sh --dry-run` then a real run. Leave `ship-execute/SKILL.md`'s own inline-on-main text untouched (that remains correct for genuinely no-PR entities).
- Done: `bash plugins/ship-flow/lib/__tests__/test-warn-state-drift.sh` exits 0.

Wave 3 — mod-file + docs convergence (parallel-safe, disjoint files, both depend on the locked adapter contract)

**T4 — Rewire `docs/ship-flow/_mods/pr-merge.md` Hook: startup / Hook: idle**
- Files: `docs/ship-flow/_mods/pr-merge.md`
- `skills_needed`: `["write-docs"]`
- `parallel_group`: waveDocs · `depends_on`: T2 · `owned_paths`: this file · `integration_owner`: self
- Replace the raw two-step `mod-block=` clear + `status={terminal} … verdict=PASSED` + `--archive` prose (lines 11-31) with an instruction to invoke `bash plugins/ship-flow/bin/closeout-adapter.sh --workflow-dir {dir} --entity {slug} --pr-provider gh` (one Bash tool call) after the existing `gh pr view` MERGED check, or let the adapter own that check directly and simplify further. Keep the OPEN/CLOSED/`gh`-unavailable branches unchanged (captain-judgment prose, DC-6). Add: report the adapter's `debrief_due=` line to the captain alongside "each auto-advanced entity."
- `TDD`: skip -- docs-only mod-file prose, no shell harness executes it directly; DC-7 (grep-based) is the verify procedure.
- Done: DC-7 passes.

**T5 — Doc convergence: `pr-merge-paths.md` + `README.md` (D2)**
- Files: `plugins/ship-flow/references/pr-merge-paths.md`, `plugins/ship-flow/README.md`
- `skills_needed`: `["write-docs"]`
- `parallel_group`: waveDocs · `depends_on`: T2, T4 · `owned_paths`: the 2 files · `integration_owner`: self
- `pr-merge-paths.md`: add a new section documenting the post-merge closeout convergence — the 3 triggers (warn-state-drift.sh, `_mods/pr-merge.md` Hook:startup/idle, `closeout-adapter.sh` CLI) all delegate to `spacedock merge guard`; explicitly name the inline-on-main no-PR pattern as an intentional, out-of-scope exception (not a 4th trigger).
- `README.md`: swap the Layer C primitive-inventory row (§~503-525) for `bin/closeout-adapter.sh` (retire the reconciler row); add a dated `## Release Notes` entry describing the consolidation; the `pr-merge-paths.md` one-line description under "Further reading" (§539) gains "+ post-merge closeout convergence."
- `TDD`: skip -- docs-only.
- Done: DC-10's `check-no-dangling.sh` passes; both files render the new content (visual read).

Wave 4 — full local verification gate

**T6 — CI-equivalent local run**
- `skills_needed`: `["test"]`
- `parallel_group`: serial · `depends_on`: T1, T2, T3, T4, T5 · `owned_paths`: none (read-only gate) · `integration_owner`: self
- `TDD`: skip -- verification gate, not code
- Done: DC-11 — all 4 commands below exit 0.

### Runtime Commands (from `.github/workflows/ship-flow-invariants.yml`, read verbatim)

```bash
for t in plugins/ship-flow/lib/__tests__/test-*.sh; do
  CI=true timeout 90 bash "$t" || echo "FAILED: $t"
done
node --test plugins/ship-flow/bin/*.test.mjs
bash scripts/check-version-triple.sh
bash scripts/check-no-dangling.sh
```

## Plan Report

### Metrics
- `status:` gaps-noted
- `duration_minutes:` ~55
- `iteration_count:` 1 (self-review only; see below)
- `task_count:` 6
- `verification_spec_count:` 11
- `model_split:` 1 sonnet dispatch (solo ensign; no separate research/cross-review teammates available in this dispatch context)

### Process deviations (honest disclosure)
This was a solo-ensign dispatch, not a multi-teammate `/ship` pipeline run. Deviations from the full `ship-plan` ceremony:
- **No multi-agent research dispatch** (Step 2) — the FO's assignment itself specified the load-bearing investigation (trigger enumeration + empirical merge-guard pin); I did this directly via grep/read/isolated-fixture probing rather than dispatching S/M/L research subagents. Depth exceeds the M-size research bar (primary-source: binary help text, binary's own Go test fixtures, and live empirical runs against the real installed 0.25.0 binary in an isolated tmp dir).
- **No separate cross-review teammate** (Step 5) — no `executer` teammate exists yet in this dispatch context. I ran the Step 4 self-review 9-12 dimensions myself: requirement coverage ✓ (every DC maps to ≥1 task), task completeness ✓, dependency correctness ✓ (T1→T2→{T3,T4}→T5→T6, no cycles, no same-wave file overlap — T4/T5 share `parallel_group: waveDocs` but touch disjoint files), zero-placeholder scan ✓ (no `TBD`/`similar to Task N`), TDD compliance ✓ (T1/T4/T5/T6 have explicit skip rationale, T2/T3 are RED-before-GREEN), stale-line-anchor — all `file:line` citations in Research Summary were re-read live during this session (not stale), stub-captain-ack scan — no `stub|fake|placeholder` language in task bodies, Context Manifest — all 7 fields populated above.
- **`advisor` tool was unavailable** (returned "temporarily disabled for this conversation") — proceeded on primary-source empirical evidence instead per the escalation mantra (bad news early): flagging this explicitly rather than silently proceeding as if a second opinion had been obtained.

### Residual uncertainty for verify (honest, not closed here)
1. **Dirty-worktree/wrong-branch gate exact semantics (DC-4)** — I designed this from `warn-state-drift.sh`'s existing precedent (global `git status --porcelain` check) generalized with a branch check, but did NOT find an existing branch-context check anywhere in the current scripts to mirror exactly. Execute should treat the branch check as a genuinely new safety addition, not a refactor of existing logic, and verify should confirm it doesn't false-positive inside a legitimate worktree-per-entity setup (where "the entity's own worktree branch" is expected to differ from `main`).
2. **`_mods/pr-merge.md` prose change (T4) has no shell harness** — DC-7 is grep-based (structural), not behavioral; the actual live-FO-agent-following-the-prose path cannot be exercised by an automated test in this repo. Verify should note this is proof of *text*, not proof of *agent compliance*, consistent with `ship-plan`'s own process-vs-output-shape validation discipline.
3. **`merged-pr-closeout-reconciler.sh`'s pre-existing missing-git-commit gap** — confirmed by full read (zero `git commit`/`git add` calls in the file) but I did not find a live incident/test proving this caused a real problem historically; it may be intentional (caller/FO commits per `«state.commit»(slug)`). T2's GREEN folds committing into the adapter regardless, which is strictly safer, but execute should double check no caller currently relies on the reconciler leaving state uncommitted for its OWN follow-up commit (would now double-commit or conflict).
4. The CI shell-test suite fakes the `spacedock` binary entirely (`write_fixture_status_bin`; confirmed no `spacedock`/`brew install`/`go build` step in `ship-flow-invariants.yml`) — my empirical merge-guard pin is against the REAL 0.25.0 binary, but T2's tests only prove fidelity to my *encoding* of that behavior into the fixture stub. A future `spacedock` binary change could silently drift from the stub without CI catching it — this is a pre-existing limitation of the test architecture, not new, but worth naming.

### Hand-off to Execute

- `tdd-ledger`: N/A — plan authored by solo ensign without `validate-tdd-ledger.py` run (script requires the full ship-plan pipeline context); execute should run `python3 plugins/ship-flow/lib/validate-tdd-ledger.py --plan docs/ship-flow/6.1-closeout-adapter-single-authority/plan.md` before starting and treat any validator BLOCKER as a plan gap to fix inline before wave dispatch, not silently proceed.
- `wave_order`: T1 → T2 → T3 → {T4, T5 (T5 depends_on T4)} → T6
- `critical_assumptions`: re-verify at execute boot — (a) `docs/ship-flow/sync-manifest.json` still absent (else `_mods/pr-merge.md` edit may trip a drift gate); (b) `spacedock --version` still reports `0.25.0` (else re-probe `merge guard --help` before trusting this plan's empirical pin); (c) no other file newly references `merged-pr-closeout-reconciler.sh` by name since this plan was written (`git grep -l merged-pr-closeout-reconciler.sh`)
- `architecture_context`: none (no ARCHITECTURE.md/PRODUCT.md touch — pure plugin-internal tooling consolidation); `README.md` + `pr-merge-paths.md` touched per D2 (T5)
- `stub_flags`: none
- `skills_needed_summary`: T1/T2/T3 → `["test","best-practices"]`/`["test","tdd","best-practices"]` (code+test); T4/T5 → `["write-docs"]` (docs-only); ≥2 distinct lists produced across heterogeneous tasks ✓
- `domain_acceptance_checklist`: none (no domain lens matched)
- `context-routing-manifest`: no registry/domain routing matched; skipped per "optional rows may be skipped only with explicit rationale" — rationale: `registry-resolve.sh --classify` not run (no domain files under `plugins/ship-flow/registry/` match `bin/*.sh`/`_mods/*.md`; confirmed via architecture-lens-triggers.yaml read above, same trigger surface)

<!-- /section:plan-report -->
