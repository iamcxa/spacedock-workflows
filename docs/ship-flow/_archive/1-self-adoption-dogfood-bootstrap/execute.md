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

`.github/workflows/ship-flow-invariants.yml:79`'s `doc-impact-gate` step evaluated on `push` too (where `github.event.pull_request.body` is structurally absent), letting a legitimately-waived PR go green pre-merge then RED on `main` post-merge. RED: `test-ship-flow-ci-scope.sh` 7/8 (new assertion requiring `github.event_name == 'pull_request'` on the `if:` line) against the unfixed workflow. Fix: added that condition; scope-detection step (`ship_flow_scope`) untouched. GREEN: 8/8. Commit: `004456c`.

#### P1-2 — unanchored `none` match accepted non-waiver prose

`extract_doc_impact_reason()` matched `doc-impact:\s*none` with no required separator — prose like `doc-impact: none of these docs are affected by my change I promise` (the FO's live repro) was accepted as a waiver. RED: Block 4b added (FO repro + `nonetheless` case) → 23/26 (3 FAIL) against the unfixed matcher. Fix: detection now requires an explicit separator (`doc-rationale.sh`'s `-—:|` chars) immediately after `none`; extraction stays permissive so multi-char separators still strip in full once matched. GREEN: 26/26 — FO repro now exits 1, legitimate separator variants unaffected. Commit: `961223a`.

#### P1-3 — coupling-map parser silently skipped unparsed rows (fail-open)

The coupling-map reader matched rows via literal-prefix `case` patterns tied to one exact 4-space-indent double-quoted layout; any other rendering of the same D1 flat schema (single quotes, different indentation) or a genuinely unsupported layout (YAML block sequences) parsed to an empty `srcGlobs`/`docPaths` and was silently skipped, zero protection. RED: Blocks 9-11 + 3 new fixtures (single-quote, indent-variant, block-array) → 26/32 (6 FAIL) against the unfixed parser. Fix: regex-based line matching (`NAME_RE`/`SRC_RE`/`DOCS_RE`) tolerates quote/indent variance within the declared schema; `validate_and_process_row()` hard-errors exit 2 on any named row still empty after parsing. GREEN: 32/32 — variant maps parse/block correctly, block-array hard-errors naming the row; real `references/doc-coupling-map.yaml` sanity-checked unchanged. Commit: `f030145`.

### Full local gate re-run (post-fix, this session)

`test-doc-impact-gate.sh` 32/32, `test-ship-flow-ci-scope.sh` 8/8, shell suite 101/103 (2 pre-existing fails, identical to base `fb59795`), node 79/79, `check-no-dangling.sh`/`check-version-triple.sh` PASS, `git diff --check fb59795 HEAD` clean. Deviation (pre-existing, resolved by verify cycle-2 — index.md `Stage Report: verify (cycle 2)`): `check-invariants.sh` showed 3 extra FAILs (`C11`/`C12`/`C15`) on verify.md beyond the 2 known `C14` lines, independently confirmed to predate this cycle's 7 touched files (verify.md untouched here). No other deviations; no scope growth beyond the 3 named P1 fixes (7 files: `.github/workflows/ship-flow-invariants.yml`, `bin/doc-impact-gate.sh`, `lib/__tests__/test-doc-impact-gate.sh`, `test-ship-flow-ci-scope.sh`, 3 new fixtures).

</details>

## Cycle-3 Fixes (codex-gate round-2 residual P1s)

Codex-gate round 2 found 2 residual P1s in the cycle-2 fixes — point-patch
gaps in the same bug classes, not new bugs. Full finding text: index.md
`Feedback from prior review` (`6d338e4`) / verify.md `codex-gate-findings`
Round-2. FO instruction: kill the class. Fixed one commit each, RED→GREEN,
re-run independently this session — evidence in `<details>` below.
Summary: P1-2 residual `2de8b87` (`test-doc-impact-gate.sh` 32/32→37/37),
P1-3 residual `670df77` (37/37→43/43). Full local gate re-run clean apart
from the 2 known pre-existing shell fails and 1 pre-existing verify.md
`C15` (predates this cycle).

<details>
<summary>Full per-P1 RED/GREEN evidence + gate re-run table + deviation note</summary>

#### P1-2 residual — marker not line-anchored

Cycle-2's fix anchored the separator after `none` but not the marker itself to the line — `grep -im1` matched `doc-impact: none — ...` anywhere inside a line, so same-line prefix text (a PR-template example, a quoted aside) still counted as a real waiver. RED (pre-fix, live): FO repro `Example only: doc-impact: none — this is documentation` → `PASS ... accepted`, exit 0 (should be 1). Fix: both `grep` detection and `sed` extraction now anchor `^[[:space:]]*` before `doc-impact:` — only leading whitespace tolerated. GREEN (post-fix, live): same repro → `BLOCKER`, exit 1; `test-doc-impact-gate.sh` 32/32→**37/37** (Block 4c: template-prefixed, quoted-context, leading-whitespace-control). Commit: `2de8b87`.

#### P1-3 residual — parser silent on zero-parsed-row maps

Cycle-2's `validate_and_process_row` fail-closed check only fires for a row the matcher recognized; a `couplings:` layout it never triggers on at all (flow-style `[{...}]`, or empty `[]`) parsed to zero rows and the whole gate went dark: exit 0, zero enforcement. RED (pre-fix, live): flow-style map, changed file matching a would-be coupling, no declaration → silent exit 0. Fix: (a) count parsed rows in the `couplings:` block, zero rows with the key present → hard error naming the map; (b) any non-blank non-comment line inside the block matching none of the recognized keys → hard error naming the line. GREEN (post-fix, live): same repro → `ERROR: ... zero rows parsed.`, exit 2; `test-doc-impact-gate.sh` 37/37→**43/43** (Blocks 12-14: flow-style, `couplings: []`, stray-unrecognized-key). Commit: `670df77`.

### Full local gate re-run (post-fix, this session)

`test-doc-impact-gate.sh` 43/43, `test-ship-flow-ci-scope.sh` 8/8 (unchanged), shell suite 101/103 (2 pre-existing fails, identical to base `6d338e4`), node 79/79, `check-no-dangling.sh`/`check-version-triple.sh` PASS, `git diff --check 6d338e4 HEAD` clean. Deviation (pre-existing, resolved by verify cycle-3 — index.md `Stage Report: verify (cycle 3)`): `check-invariants.sh` showed 1 extra `C15` FAIL on verify.md beyond the 2 known `C14` lines, independently confirmed to predate this cycle's 5 touched files (verify.md untouched here). No scope growth beyond the 2 named residual fixes.

</details>

## Cycle-4 Fix (codex-gate round-3 P1 — coupling-map key guard)

Codex-gate round 3: the zero-rows fail-closed guard only fired once
`couplings_key_seen=1` — a missing/misspelled `couplings:` key (FO repro:
`coupling:` singular) never entered the block, so the whole gate went dark
with silent exit 0. Full finding: verify.md `codex-gate-findings` Round 3.
Captain-authorized bounded cycle-4 ("cycle-4 go"), scope locked to this
one finding.

- RED (pre-fix, live): Block 15 added to `test-doc-impact-gate.sh`
  (missing-key + misspelled-key fixtures) → 43 passed, 4 failed against
  the unfixed parser; FO's exact repro confirmed exit 0, zero enforcement.
- Fix: `bin/doc-impact-gate.sh` requires exactly one recognized
  `couplings:` key before the existing zero-rows check runs; hard-errors
  exit 2 naming the map otherwise.
- GREEN (post-fix, live): same repro → exit 2, `ERROR: ... does not
  declare a recognized top-level 'couplings:' key.`
  `test-doc-impact-gate.sh` 43/43→**47/47**.
- Full local gate re-run: `test-ship-flow-ci-scope.sh` 8/8,
  shell suite 101/103 (2 pre-existing fails, unchanged), `node --test`
  79/79, `CI=true check-invariants.sh` only 2 known `C14` lines,
  `check-no-dangling.sh` PASS, `check-version-triple.sh` PASS,
  `git diff --check` clean.
- Commit: `76d486e`.

No scope growth beyond the 1 named fix (4 files: `bin/doc-impact-gate.sh`,
`lib/__tests__/test-doc-impact-gate.sh`, 2 new fixtures under
`lib/__tests__/fixtures/doc-impact-gate/`). verify.md and index.md
frontmatter not touched.

## Cycle-5 Fix (PR-CI feedback — C14 exemption-helper SIGPIPE robustness)

PR #14 CI red on `ubuntu-latest`: `_entity_bodytable_no_stage_outputs`'s `printf | grep -q` / `printf | awk | grep -q y` pipes SIGPIPE under `set -o pipefail` on content exceeding the kernel pipe-buffer size with an early match — losing legitimate exemptions (commits `90f4706`/`f9a7e4a`) or, via a sibling reverse bug, wrongly granting one to a `stage_outputs`-carrying entity; FO-diagnosed, rerun-confirmed deterministic on Linux, never reproduced in 4 local macOS pre-flights at the smaller fixture sizes previously exercised. Full finding: index.md Feedback Cycles row 4. Captain-authorized bounded cycle-5 ("c5 go"), scope locked to this one helper. Fixed by rewriting both checks pipe-free — a pure-shell `case "$content" in *marker*)` for the marker check, and the `stage_outputs` awk fed via here-string with output captured by command substitution instead of piped into another early-exiting reader; RED-first Cases 12-13 added to `test-enforce-advance-stage.sh` (see `<details>` below) failed both directions against the unfixed helper, GREEN post-fix, all 11 prior cases unchanged; full local gate re-run clean. Commit: `8b66a79`.
<details>
<summary>RED/GREEN evidence + full local gate re-run</summary>

- Case 12 (>100KB body-table entity, marker near top): exercises the marker-check pipe (bug direction 1 — loses a legitimate exemption). RED (pre-fix, live, 3/3 runs): expected exit 0, got exit 1. GREEN (post-fix, live, 3/3 runs): exit 0.
- Case 13 (~380KB `stage_outputs` entity, marker pushed near the end to isolate this pipe's race from Case 12's): exercises the `stage_outputs`-check pipe (bug direction 2 — wrongly grants an exemption). RED (pre-fix, live, 3/3 runs): expected exit 1, got exit 0. GREEN (post-fix, live, 3/3 runs): exit 1.
- `test-enforce-advance-stage.sh` 11/11→**13/13** (2 new cases), all prior 11 unchanged.
- Full local gate re-run (this session, against commit `8b66a79`): shell suite 102/103 — 1 pre-existing unrelated failure (`test-merged-pr-closeout-reconciler.sh`, an unrelated doc-string assertion). Note: `test-archived-corpus-invariants.sh`, flagged as one of "2 pre-existing fails" in every prior cycle since cycle-2, now PASSES — this fix incidentally also resolved it (it exercises `check-invariants.sh` over historical commits subject to the same SIGPIPE race). `node --test bin/*.test.mjs` 79/79. `CI=true check-invariants.sh` exit 0, 0 `FAIL` lines, 0 `WARN [Principle 5b]` lines, `OK C14 entity-status-via-advance-stage-only`, `OK C15 artifact-verbosity` (the 2 previously-known historical `C14` lines on `90f4706`/`f9a7e4a` now evaluate correctly exempt). `check-no-dangling.sh` PASS. `check-version-triple.sh` PASS. `git diff --check 175b32b HEAD` clean. `shellcheck` clean on both changed files.
- Deviation: none. No scope growth beyond the 1 named helper (2 files: `bin/check-invariants.sh`, `lib/__tests__/test-enforce-advance-stage.sh`).

</details>

Feedback Cycles row 4 resolution is left `pending` — CI-confirmed closure on PR #14 itself is verify-owned (this cycle's evidence is local repro + full local gate only, per the established cycle-2/3/4 division of labor). index.md frontmatter and verify.md not touched.
