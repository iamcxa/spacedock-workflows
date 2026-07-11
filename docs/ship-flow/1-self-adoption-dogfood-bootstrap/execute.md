# Self-adoption dogfood bootstrap — canonical docs + doc-impact gate — Execute

## Execute Output

### Execution Log

| Task | Wave | Model | Status | Files Changed | Retries | Review | Commit | Est. Cost |
|---|---|---|---|---|---|---|---|---|
| T1.1 | W1 | sonnet | done | ARCHITECTURE.md (new) | 0 | self | `e51ed05` | low |
| T1.2 | W1 | sonnet | done | ROADMAP.md | 0 | self | `1f08020` | low |
| T1.3 | W1 | sonnet | done | references/harvest-vocabulary.md (new), README.md | 0 | self | `82a6495` | low |
| T2.1 | W2-a | sonnet | done | lib/glob-match.sh (new), lib/doc-rationale.sh (new), lib/resolve-skill-routing.sh, bin/canonical-doc-sync-checker.sh | 0 | self | `c32fa52` | low |
| T2.2 | W2-b | sonnet | done | references/doc-coupling-map.yaml (new), bin/doc-impact-gate.sh (new), lib/__tests__/test-doc-impact-gate.sh (new) + fixtures | 0 | self | `1b5dba0` | low |
| T2.3 | W2-c | sonnet | done | .github/workflows/ship-flow-invariants.yml, lib/__tests__/test-ship-flow-ci-scope.sh | 0 | self | `22c3c87` | low |
| T2.4 | W2-c | sonnet | done | references/doc-sync-context.md | 0 | self | `885ea61` | low |

#### Execute-dispatch manifest

| Task | Parallel Group | Depends On | Owned Paths | Integration Owner | Dispatch Mode |
|---|---|---|---|---|---|
| T1.1 | wave1 | — | ARCHITECTURE.md | executer@pitch-1 | solo (single ensign; no sub-dispatch needed) |
| T1.2 | wave1 | — | ROADMAP.md | executer@pitch-1 | solo |
| T1.3 | wave1 | — | references/harvest-vocabulary.md, README.md | executer@pitch-1 | solo |
| T2.1 | wave2-a | T1.1, T1.2 | lib/glob-match.sh, lib/doc-rationale.sh, lib/resolve-skill-routing.sh, bin/canonical-doc-sync-checker.sh | executer@pitch-1 | solo |
| T2.2 | wave2-b | T2.1 | references/doc-coupling-map.yaml, bin/doc-impact-gate.sh, lib/__tests__/test-doc-impact-gate.sh | executer@pitch-1 | solo |
| T2.3 | wave2-c | T2.2 | .github/workflows/ship-flow-invariants.yml, lib/__tests__/test-ship-flow-ci-scope.sh | executer@pitch-1 | solo |
| T2.4 | wave2-c | T2.2 | references/doc-sync-context.md | executer@pitch-1 | solo |

Plan's wave-parallel structure was executed sequentially by one ensign (small-batch appetite; no cross-task file contention that would benefit from concurrent sub-dispatch).

#### TDD evidence

| Task | RED Command | Expected RED Failure | GREEN Command | REFACTOR Check | Result |
|---|---|---|---|---|---|
| T1.1 | N/A | TDD: skip — docs-only, pinned by existing `check_flow_map_coverage` | `CI=true bash plugins/ship-flow/bin/check-invariants.sh --check flow-map-coverage` | same | PASS (exit 0, no output) |
| T1.2 | N/A | TDD: skip — docs-only row move | `grep -A3 '<!-- section:now -->' ROADMAP.md \| grep -q 1-self-adoption-dogfood-bootstrap` | same | PASS |
| T1.3 | N/A | TDD: skip — reference-doc addition | `test -f plugins/ship-flow/references/harvest-vocabulary.md && grep -q harvest-vocabulary.md plugins/ship-flow/README.md` | same | PASS |
| T2.1 | N/A | TDD: skip — pure refactor with existing coverage | `bash .../test-adopter-skill-discovery.sh` (18/18) && `bash .../test-canonical-doc-sync-checker.sh` (62/62) | same | PASS, unchanged counts from pre-extraction baseline |
| T2.2 | `bash plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh` | `bin/doc-impact-gate.sh` absent → exit 127, 15/20 fixture assertions FAIL | same command | same | RED confirmed (127, 15 FAIL) → GREEN confirmed (20/20 PASS) |
| T2.3 | `bash plugins/ship-flow/lib/__tests__/test-ship-flow-ci-scope.sh` | new doc-impact-gate assertion FAILs, 6 existing stay green | same command | same | RED confirmed (6/7) → GREEN confirmed (7/7) |
| T2.4 | N/A | TDD: skip — reference-doc row addition | `bash scripts/check-no-dangling.sh` | same | PASS (exit 0) |

### Issues Found

- none.

### Knowledge Captures

- skipped: no findings met the harvest threshold during this stage (docs-bootstrap + one new mechanical checker, all per-plan; no unplanned friction worth promoting).

## Execute Report

- status: passed
- stage_cost: solo ensign dispatch, no sub-agent research (small-batch; design already resolved D1-D4)
- tasks_summary: 7 done, 0 blocked, 0 needs-context-rounds
- knowledge_capture: skipped

### Metrics

- status: passed
- duration_minutes: (see FO dispatch timing)
- iteration_count: 1 (no rejection cycles)
- task_count: 7
- tasks_done: 7
- tasks_blocked: 0
- commit_count: 7

## Execute UAT

| DC | Verify Procedure | Result | Evidence |
|---|---|---|---|
| AC-1 | `CI=true bash plugins/ship-flow/bin/check-invariants.sh 2>&1 \| grep -c 'WARN \[Principle 5b\]'` | PASS | `0` — confirmed via full `check-invariants.sh` run (see Hand-off to Verify note); ARCHITECTURE.md now real-checked, not WARN-skipped. |
| AC-2 | `bash plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh` | PASS | 20/20, RED observed pre-GREEN (see TDD evidence T2.2). Live-CI-run evidence is explicitly deferred to review per plan.md (this PR's own CI run). |
| AC-3 | `bash ".../canonical-doc-sync-checker.sh" docs/ship-flow/1-self-adoption-dogfood-bootstrap` | N/A at this stage | Per plan.md Verification Spec: "(verify/review stage, out of plan scope)". `review.md`/`ship.md` do not exist yet — checker requires one of them and will run at ship-review. |
| AC-4 | `test -f plugins/ship-flow/references/harvest-vocabulary.md && grep -q harvest-vocabulary.md plugins/ship-flow/README.md` | PASS | both true. |

### Hand-off to Verify

- commit_list: `e51ed05` T1.1 ARCHITECTURE.md · `1f08020` T1.2 ROADMAP now-row · `82a6495` T1.3 harvest-vocabulary.md + README link · `c32fa52` T2.1 extract glob-match.sh/doc-rationale.sh · `1b5dba0` T2.2 doc-impact-gate.sh + coupling map (RED→GREEN) · `22c3c87` T2.3 CI wiring (RED→GREEN) · `885ea61` T2.4 doc-sync-context.md row.
- dc_status: AC-1 PASS, AC-2 PASS, AC-3 N/A (deferred to review per plan), AC-4 PASS.
- tdd_evidence_summary: T1.1/T1.2/T1.3/T2.1/T2.4 declared `TDD: skip` in plan.md (docs-only or pure-refactor-with-existing-coverage) and each `done:` command re-verified green; T2.2 and T2.3 are the two `tdd_contract` tasks and both showed RED before GREEN this session (see TDD evidence table above).
- deviations:
  1. T1.2: ROADMAP Now-row Stage column recorded as `execute` (the pitch's actual current stage), not the literal `plan` string plan.md's task `desc` used — that value was accurate when plan.md was authored but stale by the time execute ran. One-line rationale committed in `1f08020`.
  2. Full local shell suite (`test-*.sh`, 103 files) has 2 pre-existing failures unrelated to this entity's 7 tasks: `test-archived-corpus-invariants.sh` (fails via the same two out-of-scope C14 historical commits `695addea`/`0d0ca53e` from the earlier shape stage — flagged, not fixed, per dispatch note "handled at FO level") and `test-merged-pr-closeout-reconciler.sh` ("pr merge doc scopes v1 provider support" — an unrelated doc-string assertion). Both verified present at base commit `7780b2a` via a scratch `git worktree add --detach` check before any of this entity's commits, so neither is a regression from this stage's work. No fix attempted (would be scope growth beyond T1.1-T2.4).
  No other deviations; no scope growth beyond the 7 planned tasks.
- render_fidelity_evidence: N/A (non-UI entity, `affects_ui: false`).
- context_read_receipts: no `folder_guidance_files`/`folder_guidance_skills` in this session (`.claude/ship-flow/` absent, per plan.md Research Summary — deliberately deferred, not this entity's scope).

## Cycle-2 Fixes (codex-gate P1 route-back)

Feedback cycle 1: verify.md's own PASS (local scope) was overridden by a
parallel Codex 5.6 cross-model review, FO-confirmed 3-for-3 (`[P1]:3`). Full
finding text + FO repro evidence: verify.md `codex-gate-findings` section
(commit `db96d86`). Fixed one commit per finding, RED (observed failing) →
GREEN (observed passing), re-run independently this session:

- P1-1 (CI ran doc-impact-gate on push, no PR body): `test-ship-flow-ci-scope.sh` 7/8→8/8, commit `004456c`.
- P1-2 (unanchored `none` accepted non-waiver prose): `test-doc-impact-gate.sh` 23/26→26/26, FO repro now exits 1, commit `961223a`.
- P1-3 (coupling-map parser fail-open on layout variants): `test-doc-impact-gate.sh` 26/32→32/32, block-array now hard-errors exit 2, commit `f030145`.
- Full local gate re-run: clean apart from the 2 known pre-existing shell fails and 3 pre-existing check-invariants.sh FAILs on verify.md (independently proven to predate this cycle) — see `<details>` below.

<details>
<summary>Full per-P1 RED/GREEN evidence + gate re-run table + deviation note</summary>

#### P1-1 — CI step ran on push events with no PR body

`.github/workflows/ship-flow-invariants.yml:79`'s `doc-impact-gate` step was
gated only on `plugin_changed`, so it also evaluated on `push` (post-merge to
`main`), where `github.event.pull_request.body` is structurally absent — a
legitimately-waived PR would go green pre-merge then RED on `main`
post-merge.

- RED: added a new assertion to `test-ship-flow-ci-scope.sh` requiring the
  step's `if:` line to also gate on `github.event_name == 'pull_request'`.
  `bash plugins/ship-flow/lib/__tests__/test-ship-flow-ci-scope.sh` →
  **7/8** (new assertion FAIL) against the unfixed workflow.
- Fix: `if: steps.ship_flow_scope.outputs.plugin_changed == 'true' &&
  github.event_name == 'pull_request'` — scope-detection step
  (`ship_flow_scope`) untouched.
- GREEN: same command → **8/8**.
- Commit: `004456c`.

#### P1-2 — unanchored `none` match accepted non-waiver prose

`plugins/ship-flow/bin/doc-impact-gate.sh:106`'s
`extract_doc_impact_reason()` matched `doc-impact:\s*none` with no
requirement that a separator follow — prose like `doc-impact: none of these
docs are affected by my change I promise` (the FO's live repro) was accepted
as a waiver (exit 0), indistinguishable from a real declaration.

- RED: added Block 4b to `test-doc-impact-gate.sh` with the exact FO repro
  string + a second unanchored case (`nonetheless`). `bash
  plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh` → **23/26** (3
  FAIL: FO repro string exits 0 instead of 1, missing BLOCKER line,
  `nonetheless` case exits 0) against the unfixed matcher.
- Fix: detection now requires an explicit separator (one of
  `doc-rationale.sh`'s `-—:|` chars, optionally repeated) immediately after
  `none` (optional whitespace) before the marker is recognized at all;
  extraction stays permissive so multi-char separators like `--` still
  strip in full once a match is confirmed.
- GREEN: same command → **26/26** — FO repro string now exits 1 (same as
  no declaration); colon/pipe/double-dash separator variants (also added
  this cycle) continue to pass, proving no regression on legitimate
  declarations.
- Commit: `961223a`.

#### P1-3 — coupling-map parser silently skipped unparsed rows (fail-open)

`plugins/ship-flow/bin/doc-impact-gate.sh:224`'s coupling-map reader matched
coupling rows via literal-prefix `case` patterns tied to one exact
4-space-indent, double-quoted inline-array layout. Any other rendering of
the same D1 "deliberately flat" schema (design.md) — single quotes,
different indentation — or a genuinely unsupported layout (YAML block
sequences) parsed to an empty `srcGlobs`/`docPaths` and the row was skipped
with zero protection, no error.

- RED: added Blocks 9-11 to `test-doc-impact-gate.sh` plus 3 new fixtures
  (`coupling-map-single-quote.yaml`, `coupling-map-indent-variant.yaml`,
  `coupling-map-block-array.yaml`). `bash
  plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh` → **26/32** (6
  FAIL: both variant maps silently exit 0 with the row unprotected instead
  of blocking; the block-array map exits 0 instead of hard-erroring)
  against the unfixed parser.
- Fix: regex-based line matching (`NAME_RE`/`SRC_RE`/`DOCS_RE`) tolerates
  quote-style and indentation variance within the declared flat schema;
  `validate_and_process_row()` hard-errors (exit 2) for any named row that
  still has an empty `srcGlobs` or `docPaths` after parsing, instead of
  silently treating it as "no coupling here."
- GREEN: same command → **32/32** — single-quote and indent-variant maps
  now parse and block correctly; the block-array map now hard-errors
  (exit 2) naming the unparseable row. Sanity-checked the real
  `references/doc-coupling-map.yaml` (canonical layout) still parses and
  blocks/passes correctly post-fix (live fail-path + declaration-path
  re-run, both matched pre-fix behavior).
- Commit: `f030145`.

### Full local gate re-run (post-fix, this session)

| Check | Command | Result |
|---|---|---|
| doc-impact-gate unit tests | `bash plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh` | 32/32 pass |
| CI-scope unit tests | `bash plugins/ship-flow/lib/__tests__/test-ship-flow-ci-scope.sh` | 8/8 pass |
| Shell suite | `for f in plugins/ship-flow/lib/__tests__/test-*.sh; do bash "$f"; done` | 101/103 pass — 2 pre-existing fails (`test-archived-corpus-invariants.sh`, `test-merged-pr-closeout-reconciler.sh`), identical to base `fb59795` |
| Node suite | `node --test plugins/ship-flow/bin/*.test.mjs` | 79/79 pass |
| Invariants | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` | exit 1; zero `WARN [Principle 5b]` lines; 5 FAIL lines — see deviation below |
| No-dangling | `bash scripts/check-no-dangling.sh` | PASS |
| Version triple | `bash scripts/check-version-triple.sh` | PASS |
| Whitespace | `git diff --check fb59795 HEAD` | clean |

**Deviation — check-invariants.sh has 5 FAIL lines, not the expected 2.**
The 2 known `C14` lines (historical shape-stage commits `695addea`,
`0d0ca53e`) are present as expected, plus 3 more: `C11`
panel-coverage-header and `C12` deferred-to-todo-footer (verify.md missing
`## Panel Coverage` / `## Deferred to TODO` sections) and `C15`
artifact-verbosity (verify.md body is 173 lines, cap 120). Independently
verified via a scratch `git worktree add --detach`: all 3 already fire at
the dispatch base `fb59795`, and even at the original verify-stage commit
`553a471` (verify.md at 156 lines, before the codex-gate-findings section
was appended) — pre-existing on verify.md, predating this cycle's work
entirely. `git diff --stat fb59795 HEAD` confirms verify.md is not among
the 7 files this cycle touched. Per this dispatch's explicit "verify.md NOT
touched (re-verify owns it)" instruction, not fixed here — flagged for
FO/re-verify visibility.

No other deviations; no scope growth beyond the 3 named P1 fixes (7 files
total: `.github/workflows/ship-flow-invariants.yml`,
`plugins/ship-flow/bin/doc-impact-gate.sh`,
`plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh`,
`plugins/ship-flow/lib/__tests__/test-ship-flow-ci-scope.sh`, and 3 new
fixture files under `plugins/ship-flow/lib/__tests__/fixtures/doc-impact-gate/`).

</details>
