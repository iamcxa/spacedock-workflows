# Execute — Issue-anchor scope-drift guard (route-back re-anchor)

<details>
<summary>Cycle 1 (T1-T4): Execute Output, TDD Evidence, Issues Found, Knowledge Captures, Execute Report, Execute UAT, Self-Check, Hand-off to Verify — collapsed for Principle 8 (C15 artifact-verbosity); see commits `2315135`/`d2658ac`/`e504a7b`/`f5453e1`</summary>

## Execute Output

### Execution Log

| Task | Wave | Model | Status | Files Changed | Retries | Review | Commit | Est. Cost |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T1 | W1 | sonnet | done | `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` (new) | 0 | self-review (RED confirmed: 25/30 assertions fail on genuine absence, `bash -n` clean) | `2315135` | 1 dispatch |
| T2 | W2 | sonnet | done | `plugins/ship-flow/_mods/issue-anchor-guard.md` (new) | 1 (self-fix: own illustrative prose duplicated the resolver's start/end marker strings, breaking `awk` extraction — rewrote to avoid literal marker text outside the fenced block) | self-review (GREEN: 29/32; remaining 3 are T3-scoped) | `d2658ac` | 1 dispatch |
| T3 | W2 | sonnet | done | `plugins/ship-flow/skills/ship-shape/SKILL.md`, `plugins/ship-flow/references/doc-coupling-map.yaml` | 0 | self-review (GREEN: 32/32; `test-contribution-contract.sh` 24/24 and `test-doc-impact-gate.sh` 112/112 unaffected) | `e504a7b` | 1 dispatch |
| T4 | W3 | sonnet | done | `ROADMAP.md`, `ARCHITECTURE.md` | 0 | self-review (`git diff --check` clean; `check-invariants.sh` clean except the named pre-existing C14 finding) | `f5453e1` | 1 dispatch |

### Execute Dispatch Manifest

| Task | Parallel Group | Depends On | Owned Paths | Integration Owner | Dispatch Mode |
| --- | --- | --- | --- | --- | --- |
| T1 | serial | — | `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | executer@5-issue-anchor-scope-drift-guard | serial |
| T2 | w2-mod | T1 | `plugins/ship-flow/_mods/issue-anchor-guard.md` | executer@5-issue-anchor-scope-drift-guard | serial |
| T3 | w2-skill | T1 | `plugins/ship-flow/skills/ship-shape/SKILL.md`; `plugins/ship-flow/references/doc-coupling-map.yaml` | executer@5-issue-anchor-scope-drift-guard | serial |
| T4 | serial | T2, T3 | `ROADMAP.md`; `ARCHITECTURE.md` | executer@5-issue-anchor-scope-drift-guard | serial |

Deviation from plan: plan's `wave_order` allowed T2 ∥ T3 in W2 (disjoint owned paths). A single ensign session executed them serially (T2 then T3) rather than fanning out to parallel sub-dispatches — same outcome, no file-ownership conflict, just no wall-clock parallelism gained.

### TDD Evidence

| Task | RED Command | Expected RED Failure | GREEN Command | REFACTOR Check | Result |
| --- | --- | --- | --- | --- | --- |
| T1 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | All assertions fail: mod file absent (DC-1/2/3/4/5/7/8a/8b) and SKILL.md has no `<!-- section:issue-anchor-guard -->` block (DC-6) | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | `bash -n plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | RED confirmed 25/30 fail (commit `2315135`); GREEN after T2+T3 land (32/32, commit `e504a7b`) |
| T2 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | DC-1/2/3/4/5/7/8a/8b fail before this task lands; DC-6 stays red until T3 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | `awk '/# issue-anchor-guard-resolver:start/{f=1;next}/# issue-anchor-guard-resolver:end/{exit}f' plugins/ship-flow/_mods/issue-anchor-guard.md \| bash -n` | RED→GREEN: DC-1/2/3/4/5/7/8a/8b all pass after `d2658ac` (29/32 overall; `shellcheck -s bash` on the extracted resolver: clean) |
| T3 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | DC-6 (pinned section + resolver invocation before Intake) fails before this task lands | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh && bash plugins/ship-flow/lib/__tests__/test-contribution-contract.sh` | `bash -n plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | RED→GREEN: DC-6 passes after `e504a7b` (32/32 full suite; `test-contribution-contract.sh` 24/24 and `test-doc-impact-gate.sh` 112/112 unaffected) |
| T4 | TDD: skip — docs-only canonical synchronization (ROADMAP/ARCHITECTURE row updates); existing `check-invariants.sh` section-tag + `patch-map.sh` CAS gates are the alternate validation | N/A | `CI=true bash plugins/ship-flow/bin/check-invariants.sh` | `git diff --check` | PASS — clean except the pre-existing, out-of-scope C14 finding on commit `cef479ff` (design-stage commit-message format issue predating this execute pass) |

### Issues Found

- The resolver's `AC-N:`/`AC-N.` line parser (used to quote acceptance criteria verbatim from `gh issue view`) requires issues to state ACs as explicit enumerated lines. The real, live issue #49 this entity is itself anchored to writes its acceptance criteria as inline prose (e.g. "(AC-1)", "(AC-4)" embedded in narrative paragraphs under "Case study"), not as `AC-N:` lines — running the guard against entity 5's own issue today would find zero matching lines and fail visible (per the non-hollow rule; correct behavior, but means the guard cannot run end-to-end against issue #49 itself until/unless #49's body is reformatted, or a looser parser is designed in a follow-up). Documented as a named residual in the mod's Rationale + References section. No auto-created entity — flagging this as a known constraint is sufficient at this scope; the fix (a more permissive issue-body AC parser, or a documented "state ACs as AC-N: lines" convention for tracker issues that want this guard) is left for the captain/verify stage to decide whether it's in-scope or a follow-up.

### Knowledge Captures

- **[D1]** When a mod's own "Invocation" prose illustrates the extraction mechanism using the literal marker strings (e.g. showing the `awk '/# foo-resolver:start/ .../ ' file` pattern inline as documentation), the extractor's first match lands on the illustrative snippet rather than the real block, silently producing an empty extraction. Contribution-contract.md avoids this by never restating the marker regex in its own prose. Any future wired mod following this pattern should describe the extraction mechanism by reference ("same pattern as X") rather than reproducing the marker literals in surrounding prose.
- skipped: false (one D1 item above; no D2-candidate this pass)

## Execute Report

status: passed
stage_cost: 1 ensign dispatch (solo session, no sub-agent fan-out); 4 tasks executed serially within it
tasks_summary: 4 done, 0 blocked, 0 needs-context-rounds
knowledge_capture: D1: 1, D2: 0

### Metrics

status: passed
duration_minutes: 90
iteration_count: 1 (one T2 self-fix cycle for the marker-extraction bug; no cross-review round)
task_count: 4
tasks_done: 4
tasks_blocked: 0
commit_count: 4

## Execute UAT

| DC | Verify Procedure | Result | Evidence |
| --- | --- | --- | --- |
| DC-1 | `test -f plugins/ship-flow/_mods/issue-anchor-guard.md && grep -q '^## Hook: pre-shape' plugins/ship-flow/_mods/issue-anchor-guard.md` | PASS | `test-issue-anchor-guard.sh` DC-1 rows |
| DC-2 | extract `# issue-anchor-guard-resolver:start`/`:end`, `bash -n` on the extract | PASS | `test-issue-anchor-guard.sh` DC-2 rows; `shellcheck -s bash` also clean |
| DC-3 | fixture `fx-reshape-with-issue` (design.md+plan.md+`issue:"#49"`, stubbed `gh`) → run resolver `emit` | PASS | `.context/ship-flow/source-diff-fx.yaml` carries all 5 CD4 fields; 3/3 canned ACs present with `met_by_existing_capability` |
| DC-4 | fixture `fx-fresh-shape` (`status: sharp`, no design.md) → run resolver `emit` | PASS | `guard_required: false`, no source-diff fields |
| DC-5 | fixture `fx-reshape-no-issue` (design.md present, no `issue:`) → run resolver `emit` | PASS | `no_issue_anchor: true` + `captain_prompt`, no fake diff |
| DC-6 | `grep -q '<!-- section:issue-anchor-guard -->'` + line-order check before `### Intake`; plus `grep` for `name: issue-anchor-guard` + bidirectional `directions:` row in `doc-coupling-map.yaml` (T3's doc-coupling row, same task, not separately DC-numbered in plan's Verification Spec) | PASS | ship-shape/SKILL.md section precedes Intake; References cites the mod path; doc-coupling row present; `test-contribution-contract.sh` and `test-doc-impact-gate.sh` unaffected |
| DC-7 | crafted `verdict: proceed` + `scope_subset_of_issue: false` fixture → resolver `validate` | PASS | non-hollow rule rejects the combo; consistent `proceed` accepted; out-of-enum `verdict` rejected (CD1 lock) |
| DC-8a | fixture `fx-empty-issue` (`issue: ""`) → run resolver `emit` | PASS | treated identically to DC-5 (`no_issue_anchor: true`) |
| DC-8b | fixture with PATH-stubbed failing `gh` → run resolver `emit` | PASS | non-zero exit, captain-visible stderr, no YAML written |
| Full local gate | `test-issue-anchor-guard.sh` + full shell suite (all `lib/__tests__/test-*.sh`, `CI=true`) + `node --test plugins/ship-flow/bin/*.test.mjs` + `check-invariants.sh` + `check-no-dangling.sh` + `check-version-triple.sh` | PASS | see per-suite results below |

## Self-Check

- typecheck: N/A — shell/Markdown slice, no typed source
- lint: PASS — `bash -n` on the test file and the extracted resolver; `shellcheck -s bash` on the extracted resolver clean; `git diff --check` clean
- unit tests: PASS — `test-issue-anchor-guard.sh` 32/32; full shell suite all green (per-suite log below); Node 79/79
- qa-only: N/A — no UI files, no visible surface
- critical-pass lite: PASS — no SQL/data-safety, race/concurrency, LLM trust-boundary, or shell-injection finding; the one honest residual (AC-line parser format expectation) is named above and in the mod's Rationale section, not hidden

### Metrics

status: passed
duration_minutes: 90
iteration_count: 1
task_count: 4

### Hand-off to Verify

<!-- section:hand-off-to-verify -->
- **commit_list**: `2315135` (T1 RED test authoring) · `d2658ac` (T2 GREEN mod+resolver) · `e504a7b` (T3 GREEN SKILL wiring + doc-coupling row) · `f5453e1` (T4 canonical doc sync)
- **dc_status**: DC-1 PASS; DC-2 PASS; DC-3 PASS; DC-4 PASS; DC-5 PASS; DC-6 PASS (includes doc-coupling row); DC-7 PASS; DC-8a PASS; DC-8b PASS.
- **tdd_evidence_summary**: T1 RED-first (25/30 fail on absence, commit `2315135`) → GREEN after T2+T3 (32/32, commit `e504a7b`). T2 RED→GREEN for DC-1/2/3/4/5/7/8a/8b (commit `d2658ac`). T3 RED→GREEN for DC-6 (commit `e504a7b`). T4: `TDD: skip -- docs-only canonical synchronization`, per plan; validated instead by `check-invariants.sh` + `git diff --check`.
- **deviations**: (1) W2's T2/T3 were disjoint-path parallel-eligible per plan but executed serially in one ensign session — no ownership conflict, just no wall-clock parallelism gained. (2) One self-fix cycle during T2: the mod's own illustrative "Invocation" prose duplicated the resolver's literal start/end marker strings, which broke `awk` extraction (matched the illustrative line as the real boundary, yielding an empty extract) — fixed by describing the extraction mechanism by reference instead of restating the marker regex; re-verified GREEN afterward. (3) Named residual (not a deviation from plan, but worth flagging to captain/verify): the AC-line parser expects `AC-N:`/`AC-N.` enumerated lines; issue #49's own real body uses inline prose references instead, so the guard cannot run end-to-end against its own anchoring issue as currently formatted — see Issues Found above.
- **render_fidelity_evidence**: N/A — non-UI entity (`affects_ui: false`).
- **context_read_receipts**: no non-root `AGENTS.md`/`CLAUDE.md` folder guidance applicable (`plugins/ship-flow/{_mods,skills,lib/__tests__,references}/**` and root canonical docs); plan's Context Manifest recorded `folder_guidance_files=[]`/`folder_guidance_skills=[]` and that was re-confirmed at execute boot.
<!-- /section:hand_off_to_verify -->

</details>

## Execute Addendum (cycle 2): T5 — shape-confirm.sh bounded intake-stamping

Route-back from verify: a review found CD5(b) (design.md Reconciliation — bounded
intake-stamping, "future entities are born anchored") was a named, captain-adjudicated
decision with no task, no DC, and no test — a silent-drop doctrine violation. This
addendum adds T5 to close that gap. Bounded scope, per dispatch: intake issue/tracker
stamping ONLY — no change to `issue-anchor-guard.md`, no AC-N parsing, no Linear/
`external_id` handling.

### Execution Log (cycle 2)

| Task | Wave | Model | Status | Files Changed | Retries | Review | Commit | Est. Cost |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| T5 | W4 | sonnet | done | `plugins/ship-flow/lib/__tests__/test-shape-confirm.sh`, `plugins/ship-flow/lib/shape-confirm.sh`, `plugins/ship-flow/skills/ship-shape/SKILL.md` | 1 (self-fix: first fixture draft omitted `pm_skill_receipts`, which folder-layout Mode A requires — DC-5.1-1a/1b failed with `exit 10` instead of the intended RED "field absent"; fixed by adding the same receipts block `proposal_with_pre_mortem` already uses) | self-review (GREEN: DC-5.1-1..3 pass; full `test-shape-confirm.sh`, `test-issue-anchor-guard.sh`, `test-doc-impact-gate.sh`, `test-contribution-contract.sh` unaffected) | `b9598da` (RED) · `b46dc35` (GREEN) | 1 dispatch |

### TDD Evidence (cycle 2)

| Task | RED Command | Expected RED Failure | GREEN Command | REFACTOR Check | Result |
| --- | --- | --- | --- | --- | --- |
| T5 | `bash plugins/ship-flow/lib/__tests__/test-shape-confirm.sh` | DC-5.1-1a/1b (folder `index.md` issue:/tracker:) and DC-5.1-2 (flat `.md` issue:/tracker:) fail — `shape-confirm.sh` has zero issue/tracker handling; DC-5.1-1c/DC-5.1-3 (negative cases) pass trivially since nothing is stamped yet | `bash plugins/ship-flow/lib/__tests__/test-shape-confirm.sh` | `bash -n plugins/ship-flow/lib/shape-confirm.sh && bash -n plugins/ship-flow/lib/__tests__/test-shape-confirm.sh` | RED confirmed (commit `b9598da`) → GREEN after the two-line stamping addition (commit `b46dc35`) |

### Issues Found (cycle 2)

- First fixture draft (`proposal_with_issue_tracker`) omitted `pm_skill_receipts`; folder-layout Mode A rejects that with exit 10 before the pitch entity is even written, so DC-5.1-1a/1b failed for the wrong reason (guard rejection, not "field absent"). Fixed by copying the receipts block from the existing `proposal_with_pre_mortem` fixture. No production-code implication — test-fixture-only fix.

### Execute UAT (cycle 2)

| DC | Verify Procedure | Result | Evidence |
| --- | --- | --- | --- |
| DC-9 | `test-shape-confirm.sh` DC-5.1-1..3: proposal with `pitch.issue`+`pitch.tracker` → `shape-confirm.sh --layout=folder\|flat` | PASS | Pitch `index.md`/`.md` carry `issue: "#49"` + `tracker: gh`; `090.1-child-a/index.md` carries neither (pitch-only scope); proposal without `pitch.issue` (`sample_proposal`) emits neither |

### Self-Check (cycle 2)

- typecheck: N/A — shell/Markdown slice, no typed source
- lint: PASS — `bash -n` on `shape-confirm.sh` and the test file; `shellcheck -s bash` on `shape-confirm.sh` clean (pre-existing SC2329 info-level finding on an unrelated trap function, not introduced by this task); `git diff --check` clean
- unit tests: PASS — `test-shape-confirm.sh` full suite (incl. DC-5.1-1..3); `test-issue-anchor-guard.sh` 32/32; `test-doc-impact-gate.sh` 112/112; `test-contribution-contract.sh` 24/24
- full gate: PASS — `CI=true bash plugins/ship-flow/bin/check-invariants.sh` clean (no FAIL lines); `bash scripts/check-no-dangling.sh` PASS; `bash scripts/check-version-triple.sh` PASS
- critical-pass lite: PASS — no SQL/data-safety, race/concurrency, LLM trust-boundary, or shell-injection finding; bounded scope honored (`git diff --stat` shows no change to `issue-anchor-guard.md`, no AC-N parsing, no Linear/`external_id` handling)

### Hand-off to Verify (cycle 2 addendum)

<!-- section:hand-off-to-verify-cycle-2 -->
- **commit_list (cycle 2)**: `b9598da` (T5 RED — DC-5.1 test authoring) · `b46dc35` (T5 GREEN — shape-confirm.sh stamping + SKILL prose) · `d0668c6` (docs — CD5(b) marked IMPLEMENTED in design.md/plan.md)
- **dc_status (cycle 2)**: DC-9 PASS (folds DC-5.1-1..3).
- **tdd_evidence_summary (cycle 2)**: T5 RED-first (commit `b9598da`) → GREEN (commit `b46dc35`). One test-fixture self-fix cycle (missing `pm_skill_receipts`), no production-code deviation.
- **deviations (cycle 2)**: none from the T5 addendum plan in plan.md.
- **render_fidelity_evidence (cycle 2)**: N/A — non-UI entity.
- **residual (unchanged from cycle 1)**: the AC-line parser's `AC-N:`/`AC-N.` line requirement still cannot run end-to-end against issue #49's own prose-style ACs — orthogonal to T5, tracked in cycle-1's Issues Found.
<!-- /section:hand-off-to-verify-cycle-2 -->

## Execute Addendum (cycle 3): P1-1..P1-4 — resolver fail-closed/derivation fixes

Route-back from verify surfaced four resolver-level gaps in
`issue-anchor-guard.md`, none touched by T1-T5: (P1-1) `validate` trusted the
file's own `goal_still_unmet`/`verdict` scalars instead of deriving them from
`original_issue_acs[]`; (P1-2) the AC-N line grep dropped multiline
continuation text and silently accepted an AC heading with zero criterion
text; (P1-3) `issue:` resolution did not distinguish a same-repo `#N` from a
cross-repo URL/`owner/repo#N` reference, risking a silent fall-through to the
wrong same-number local issue; (P1-4) a later failed `emit` run left an
earlier successful run's `source-diff-<id>.yaml` (and its `verdict: proceed`)
on disk for `validate` to find. Bounded scope per dispatch: edits confined to
`issue-anchor-guard.md` (resolver) + new assertions in
`test-issue-anchor-guard.sh`; `shape-confirm.sh`, `ship-shape/SKILL.md`, and
re-entry detection untouched.

### Execution Log (cycle 3)

| Task | Wave | Model | Status | Files Changed | Retries | Review | Commit | Est. Cost |
| --- | --- | --- | --- | --- | --- | --- | --- | --- |
| P1-1..P1-4 (RED) | W5 | sonnet | done | `plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | 1 (DC-12's first draft used the real `gh` CLI with a placeholder foreign repo — coincidentally "passed" via a real 404 rather than the guard's own logic; rewrote to pair each DC-12 fixture with a `gh` stub that would succeed if invoked, making RED/GREEN depend only on the guard's parsing, not network reachability) | self-review (RED confirmed: 36/53 pass, 17 fail — exactly DC-10/11/12/13, all pre-existing DC-1..8b/T3 assertions still pass) | `8028dcd` | 1 dispatch |
| P1-1..P1-4 (GREEN) | W5 | sonnet | done | `plugins/ship-flow/_mods/issue-anchor-guard.md` | 0 | self-review (GREEN: 53/53) | `23d7e7e` | 1 dispatch |

### TDD Evidence (cycle 3)

| Task | RED Command | Expected RED Failure | GREEN Command | REFACTOR Check | Result |
| --- | --- | --- | --- | --- | --- |
| P1-1 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | DC-10 (both sub-cases) fail: validate accepts a proceed with zero AC rows, and accepts goal_still_unmet=true when every row is met_by_existing_capability=true | same | `bash -n` on extracted resolver; `shellcheck -s bash` | RED (commit `8028dcd`) → GREEN via `iag_ac_met_values()` + derivation-based BLOCK checks (commit `23d7e7e`) |
| P1-2 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | DC-11 (6 assertions) fail: multiline continuation text not captured; empty-heading cases (mid-body and EOF) silently accepted and emit a file instead of failing closed | same | `bash -n`; `shellcheck -s bash` | RED (commit `8028dcd`) → GREEN via `iag_parse_ac_blocks()` awk state machine + `IAG_EMPTY_AC` fail-closed check (commit `23d7e7e`) |
| P1-3 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | DC-12 (7 assertions) fail: cross-repo URL / `owner/repo#N` shorthand / ambiguous ref all pass through to a stubbed `gh` and emit a file instead of BLOCKing | same | `bash -n`; `shellcheck -s bash` | RED (commit `8028dcd`) → GREEN via the owner/repo-qualified-reference BLOCK before any `gh` invocation (commit `23d7e7e`) |
| P1-4 | `bash plugins/ship-flow/lib/__tests__/test-issue-anchor-guard.sh` | DC-13 (2 assertions) fail: a later gh-failure run leaves the earlier successful run's file in place, and `validate` against that stale path PASSes | same | `bash -n`; `shellcheck -s bash` | RED (commit `8028dcd`) → GREEN via `rm -f "$IAG_OUT_FILE"` at the top of `emit`'s working logic (commit `23d7e7e`) |

### Issues Found (cycle 3)

- DC-12's first draft used the real `gh` CLI (no fakebin) against a
  placeholder `other-org/other-repo` URL/shorthand. Without the P1-3 fix,
  that draft still "passed" (exit non-zero) because the real `gh` 404s
  against a nonexistent repo — a network-dependent, non-deterministic
  false green that would not have caught the actual bug (the pre-fix code
  passing the raw URL/shorthand straight through to `gh`). Fixed by pairing
  each DC-12 fixture with a `write_fake_gh_ok` stub that returns
  `CANNED_BODY` if invoked; re-confirmed RED against the unmodified mod
  (emit succeeds via the stub) before implementing the fix.
- Residual (named, not hidden): P1-4's tombstone-on-start is a practical
  fix for the two named failure modes (a later gh-failure, a later
  BLOCK) but is not a file lock — two truly concurrent `emit` invocations
  for the same entity still race last-writer-wins. Out of this round's
  bounded scope (resolver-only, no lock-file infrastructure).

### Execute UAT (cycle 3)

| DC | Verify Procedure | Result | Evidence |
| --- | --- | --- | --- |
| DC-10 | `validate` on a zero-AC-row proceed, an all-met-but-claims-unmet proceed, and a consistent multi-row proceed | PASS | zero-row and all-met cases BLOCK non-zero; consistent multi-row (derived from ANY-false-row, not just row 1) passes |
| DC-11 | `emit` against a multiline-continuation AC body, a mid-body empty-heading body, and an EOF empty-heading body | PASS | continuation text captured verbatim in `original_issue_acs`; both empty-heading cases BLOCK non-zero with no file written |
| DC-12 | `emit` against a cross-repo full URL, an `owner/repo#N` shorthand, and an ambiguous string, each paired with a would-succeed `gh` stub | PASS | all three BLOCK non-zero before invoking `gh`, no file written; the URL/shorthand cases name the foreign owner/repo in the error |
| DC-13 | `emit` (success) → `emit` (gh-failure) on the same entity → `validate` against the now-tombstoned path | PASS | second run still exits non-zero; the first run's file no longer exists; `validate` against the missing path BLOCKs (file not found) |

### Self-Check (cycle 3)

- typecheck: N/A — shell/Markdown slice, no typed source
- lint: PASS — `bash -n` on the extracted resolver and the test file; `shellcheck -s bash` on the extracted resolver clean; `git diff --check` clean on both commits
- unit tests: PASS — `test-issue-anchor-guard.sh` 53/53; `node --test plugins/ship-flow/bin/*.test.mjs` 79/79 unaffected
- full gate: PASS — `CI=true bash plugins/ship-flow/bin/check-invariants.sh` clean (no FAIL lines, C14 both variants OK); `bash scripts/check-no-dangling.sh` PASS; `bash scripts/check-version-triple.sh` PASS
- critical-pass lite: PASS — no SQL/data-safety or shell-injection finding; the P1-4 concurrent-overlap residual is named above, not hidden; bounded scope honored (`git diff --stat` across both commits touches only `issue-anchor-guard.md` and `test-issue-anchor-guard.sh`)

### Hand-off to Verify (cycle 3 addendum)

<!-- section:hand-off-to-verify-cycle-3 -->
- **commit_list (cycle 3)**: `8028dcd` (RED — DC-10..13 test authoring) · `23d7e7e` (GREEN — P1-1..P1-4 resolver fixes + doc updates)
- **dc_status (cycle 3)**: DC-10 PASS; DC-11 PASS; DC-12 PASS; DC-13 PASS. Full suite 53/53 (was 32/32 at end of cycle 2, before DC-10..13 existed).
- **tdd_evidence_summary (cycle 3)**: RED confirmed 36/53 (commit `8028dcd`, exactly the 17 new DC-10..13 assertions failing) → GREEN 53/53 (commit `23d7e7e`).
- **deviations (cycle 3)**: one test-authoring self-fix (DC-12's `gh`-stub redesign, see Issues Found); no production-code deviation from the dispatch's four fix descriptions.
- **render_fidelity_evidence (cycle 3)**: N/A — non-UI entity.
- **residual (new, named)**: P1-4's tombstone is last-writer-wins, not a lock, under true concurrent `emit` overlap (see Issues Found).
- **residual (unchanged from cycle 1)**: the AC-line parser still requires an explicit `AC-N:`/`AC-N.` heading (multiline continuation is now supported, but free-form prose with no heading still yields zero matches and fails visible) — issue #49's own body still cannot run end-to-end against this guard as currently formatted.
<!-- /section:hand-off-to-verify-cycle-3 -->

<details>
<summary>Cycle 4 (P1-A/P1-B/P1-C/P2-D): Execute Addendum, TDD Evidence, Self-Check, Hand-off to Verify — collapsed for Principle 8 (C15 artifact-verbosity); see commits `fd0781f`/`3e6eeda`</summary>

## Execute Addendum (cycle 4): P1-A/P1-B/P1-C/P2-D — structural non-hollow parse, verified same-repo URL, issue+tracker pairing, AC-block indentation boundary

Route-back surfaced four gaps none of T1-T5/P1-1..P1-4 touched: (P1-A)
`validate`'s non-hollow check was a line-oriented text scan that never
checked `text:` for emptiness or `met_by_existing_capability` for a real
boolean, and could be fooled by a `text:` substring resembling that key
(phantom-row miscount); (P1-B) the resolver always cross-repo-BLOCKed a
full GitHub issue URL even for the local repo, breaking SKILL.md's
advertised full-URL intake; (P1-C) `shape-confirm.sh` stamped
`pitch.issue`/`pitch.tracker` independently, allowing a half-anchored or
malformed pair to commit while reporting success; (P2-D) the AC-block
parser absorbed any non-blank line after a heading regardless of
indentation, letting a following section masquerade as AC criteria.

Bounded scope per dispatch: `issue-anchor-guard.md` (resolver,
P1-A/P1-B/P2-D) + `shape-confirm.sh` (P1-C) + `ship-shape/SKILL.md`
(P1-B intake wording only) + new assertions in
`test-issue-anchor-guard.sh` / `test-shape-confirm.sh`. No new
features; re-entry detection and the core emit/validate flow unchanged.

### TDD Evidence (cycle 4)

| Task | Expected RED Failure | GREEN Fix | Result |
| --- | --- | --- | --- |
| P1-A | DC-14 (3): empty text, non-boolean `met_by_existing_capability` ("maybe"), and a text-embedded substring miscounted as a phantom row all pass/misderive | `iag_ac_rows_count()`/`iag_ac_row_met_value()` yq structural parse replaces `iag_ac_met_values()` | RED `fd0781f` → GREEN `3e6eeda`, 66/66 |
| P1-B | DC-15 (2): resolver BLOCKs a full GitHub URL even when owner/repo matches the local git remote | `iag_local_owner_repo()` + same-repo-verified canonicalization to `#N` | RED `fd0781f` → GREEN `3e6eeda` |
| P1-C | DC-5.1-4/5/7 (6): half-anchored pair, bad tracker enum, newline-in-issue all silently accepted and written | all-or-nothing pairing + `gh`/`linear` enum + newline gate right after extraction | RED `fd0781f` → GREEN `3e6eeda`, shape-confirm full suite green |
| P2-D | DC-16 (4): an unindented section absorbed into AC-1's text; a no-text heading + unindented section wrongly accepted with fabricated criteria | `have && /^[^[:space:]]/ { flush(); ... }` indentation-boundary rule in `iag_parse_ac_blocks()` | RED `fd0781f` → GREEN `3e6eeda` |

Issues found: none beyond the four fixes. DC-15's fixture needs
`git init` + a matching `origin` remote (mirrors real invocation);
existing no-git-init DC-12 fixtures still exercise the default BLOCK.
P1-C's newline check is the only YAML-unsafety check needed — embedded
quotes are already neutralized upstream by the existing `tr -d '"'`.

### Self-Check (cycle 4)

PASS across the board: `bash -n` + `shellcheck -s bash` on the extracted
resolver clean; `git diff --check` clean; `test-issue-anchor-guard.sh`
66/66; `test-shape-confirm.sh` full suite; `node --test
plugins/ship-flow/bin/*.test.mjs` 79/79; `test-doc-impact-gate.sh`
112/112; `test-contribution-contract.sh` 24/24; `CI=true
check-invariants.sh` clean (C14 both variants + C15 OK);
`check-no-dangling.sh` / `check-version-triple.sh` PASS. Bounded scope
confirmed via `git diff --stat` (resolver + shape-confirm.sh + SKILL.md
intake paragraph + the two test files only).

<!-- section:hand-off-to-verify-cycle-4 -->
- **commit_list (cycle 4)**: `fd0781f` (RED) · `3e6eeda` (GREEN)
- **dc_status (cycle 4)**: DC-14/15/16 PASS; DC-5.1-4/5/6/7 PASS. `test-issue-anchor-guard.sh` 66/66 (was 53/53); `test-shape-confirm.sh` full suite green (+6 assertions).
- **deviations (cycle 4)**: none — all four fixes match the dispatch's descriptions.
- **render_fidelity_evidence (cycle 4)**: N/A — non-UI entity.
- **residual (unchanged)**: P1-4's tombstone remains last-writer-wins (cycle 3); the AC-line parser still requires an explicit `AC-N:`/`AC-N.` heading (cycle 1); the model-judgment residual in the mod's own Boundary section is named+accepted, not chased.
<!-- /section:hand-off-to-verify-cycle-4 -->

</details>
