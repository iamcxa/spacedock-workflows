<!-- section:execute-report -->
# Make debrief a native post-merge ship closeout — Execute

started: 2026-07-15T04:49:00Z
completed: 2026-07-16T15:53:40Z
base_commit: d45d176
verified_head: 2c02bae22cd816429c41f4e135e10b08c9a4981e

## Execute Dispatch Manifest

| Task | Group | Depends on | Owned paths | Mode |
| --- | --- | --- | --- | --- |
| T1 | W1 serial | none | landing resolver/tests/fixtures | delegated TDD |
| T2 | W2 serial | T1 | receipt, intent, schemas, skill contract/tests | delegated TDD |
| T3 | W3 serial | T1,T2 | atomic bundle, direct reconciler/tests | delegated TDD |
| T4 | W4 serial | T3 | optional reconciler/mod/dogfood fixtures | delegated TDD |
| T5 | W5 serial | T4 | README and doc-sync context | delegated docs/verification |

### Feedback Dispatch Manifest

Cycle 1 used disjoint F1-F3 delegated TDD lanes, then F4 compatibility and R1 independent review. Cycle 2 used disjoint R2-F1/F2/F3 lanes plus integration/review. Cycles 3-11 split causal test, bounded implementation, and independent spec/quality review lanes; W2/W3/W4 remained deferred, and integration/state advancement stayed with the execute ensign.

## Execution Log

| Task | Wave | Model | Status | Files | Commit |
| --- | --- | --- | --- | --- | --- |
| T1 | W1 | Codex worker | done | landing helper/test/fixtures | `42b9637` |
| T2 | W2 + review reopen after W3 | Codex workers | done | receipt/intent/schema/skill/tests | `1870efb`, `42f8e06` |
| T3 | W3 | Codex workers | done | bundle helper and direct reconciler/tests | `4069946`, `a196da6`, `2424b9d` |
| T4 | W4 | Codex worker + two reviewers | done | reconciler, merge mod, PR40/41 fixtures/tests | `bdbbf96` |
| T5 | W5 | Codex worker + two reviewers | done | operator README and coupling map | `c08c391` |
| F1 | feedback 1 | Codex worker + independent reviewer | done | fail-closed envelope, single owner, ROADMAP parity | `490a294` |
| F2 | feedback 1 | Codex worker + independent reviewer | done | full archive tree and post-commit signal recovery | `3ee8f21` |
| F3 | feedback 1 | Codex workers + independent reviewer | done | D1/D4 receipt semantics and split-root archive proof | `fb6f4aa` |
| F4 | feedback 1 | Codex worker + independent reviewer | done | sanctioned feedback-stage receipt grammar | `b5fa535` |
| R2-F1 | feedback 2 | Codex worker + independent reviewer | done | native-proof gate for active legacy terminal state | `b6cd023` |
| R2-F2 | feedback 2 | Codex worker + independent reviewer | done | authoritative squash proof and first-cell ROADMAP identity | `91402c7` |
| R2-F3 | feedback 2 | Codex worker + independent reviewer | done | young-repository parent guard | `110bc09` |
| R2-I | feedback 2 integration | Codex worker + independent reviewer | done | squash source proof through direct, optional, and replay callers | `85d6dff` |
| R3-B1 | feedback 3 | Codex workers + same independent reviewer | done | bounded authoritative PR-source acquisition and review hardening | `54a4a9a`, `8d1ac64` |
| R4-B1/W1 through R10-B1/B2 | feedback 4-10 | Codex test/audit workers + independent reviewers | done | repo/endpoint authority, retry-safe publication, terminal predecessor recovery | `eba76c1`..`e094f4e` |
| R11-B1/B2/B3 | feedback 11 | Codex worker + independent spec/recovery reviewer | done | mature-main predecessor recovery, provider/local terminal binding, signal-owned validator temps | `2c02bae` |

## TDD Evidence

| Task | RED | GREEN / REFACTOR |
| --- | --- | --- |
| T1 | helper missing; regression rounds reached 77/7 then 84/5 | 89/89 on Bash 5.3 and 3.2; syntax/ShellCheck clean |
| T2 | suites missing; adversarial schema/CAS rounds reached 15/23 and 106/14 | 103/103 across receipt, intent, entity, ship; reopened receipt semantics 43/43; Python/Bash/static checks clean |
| T3 | helper missing; projection/fault/C14/C15 rounds reached 12/25, 40/2, 48/1; direct rounds reached 91/15, 119/19, 155/7 | bundle 51/51 on Bash 5.3 and 3.2; direct 162/162; legacy 85/85; debrief/enforce green |
| T4 | optional 88/4; provider recovery 120/15; quality recovery 136/5 | optional 141/141; default/selected 160/160; recursion-only 86/86; C1-C15/static checks clean |
| T5 | skipped by plan for docs; cold-reader reviews found three wording/actionability gaps | exact DC-7 chain exit 0; cold-reader/spec PASS; example syntax/path/diff checks clean |
| F1 | feedback fixture 5/10; missing-field/cleanup matrix stubs 15/2 | focused 75/75; base 120/120; final default 195/195 |
| F2 | bundle 54/15 including evidence loss and post-commit corruption | 69/69 on Bash 3.2 and 5.3; receipt regression green |
| F3 | receipt 65/74, schema 74/78, split-root receipt 78/81, optional 164/176 | receipt 81/81; optional 176/176; direct 197/197; PR40/41 138/138 |
| F4 | C14 28/29, then impossible-time review case 30/31 | focused 31/31; full C1-C15 exit 0 |
| R2-F1 | focused reconciler 7/6 | focused 13/13; default 198/198; native rerun byte/commit no-op |
| R2-F2/F3/I | receipt 81/3; resolver 89/5; integration 9/12; apply 4/5 | receipt 85/85; resolver 94/94 both shells; integration 23/23; bundle 78/78 both shells; independent APPROVED |
| R3-B1 | main-only acquisition 26/17; review-blocker matrix 31/25 | focused 107/107 both shells; collision and HUP/INT/QUIT/TERM cleanup green; R2 13/13 and 23/23; same reviewer APPROVED |
| R4-B1/W1 through R9-B1/B2 | foreign-CWD 19/10; provider 121/20 then 235/44; atomic race 14/5; two-pushurl 15/4 then 38/12; endpoint drift 26/13; receipt transition 89/3 | R9 59/59, receipt 92/92, R8 50/50, R7 19/19, R6 289/289, R4 29/29, R3 107/107, R2 13/13 + 23/23, default 198/198, all dual-shell; spec/quality APPROVED |
| R10-B1/B2 | frozen `d7be3e2` 7/9; predecessor 27/34; ordering/deep 91/4; stale-main 102/2; off-main guard RED | R10 120/120 both shells; endpoint preflight precedes acquisition, terminal recovery is authoritative-main/bounded/unique, signal cleanup is owned; final spec and quality re-reviews PASS |
| R11-B1/B2/B3 | validator seams 38/12; validator-root creation 62/4; colliding-tag history 9/2; provider/local divergence and unrelated ancestry rejected | R11 91/91 and default 198/198 both shells; R10 120/120 both shells; final independent spec/recovery review PASS |

## Issues Found

- Resolved: clarified `transaction.main_commit` as the implementation landing anchor; optional closeout-PR merge proof remains provider/sentinel-bound (`42f8e06`). This was an ambiguous field clarification, not an acceptance or scope change.
- Resolved: T4 reviews caught invalid zero-diff PR topology, hidden merge conflict, missing provider OID/draft recovery, non-OPEN PR reuse, default-CI omissions, and BSD-only ordering. Tests now cover every repair.
- Resolved: T5 cold-read added runnable mode choice, direct local/no-push authority, location-independent plugin-root resolution, and deployment independence.
- Resolved: first execute reverse-audit VETO corrected the cross-wave T2 schema-repair attribution and disclosed the unused plan-listed writing-skills methodology.
- Resolved: Verify feedback B1-B5 and W1 now fail closed, preserve the tracked entity tree, survive post-commit signals, validate D1/D4 semantics from Git plus exported bytes, and retain one reconciler projection owner; fresh review APPROVED.
- Warning only: final gates retained three expected legacy-v1 debrief warnings plus existing historical invariant skips/grandfather warning.
- Deferred hardening: W2 same-user path-swap TOCTOU and proof-root symlink-alias coverage remain non-acceptance follow-ups.
- Resolved: C14 accepts only bound FO feedback receipts (`b5fa535`); rounds 2-3 add native proof/source recovery; R4-R10 bind provider/endpoint authority, stabilize publication, and recover exactly one durable awaiting predecessor from authoritative bounded main history before accepting a terminal receipt (`eba76c1`..`e094f4e`).
- Resolved: R11 accepts a unique valid predecessor before the bounded-history sentinel, resolves an exact `refs/heads/*` ref under same-name tag collision, binds landed recovery to provider `headRefOid` plus predecessor ancestry, and places every receipt/preflight validator output under signal-owned cleanup (`2c02bae`).

## Knowledge Captures

- A local deterministic terminal ref is insufficient recovery proof; provider head OID and draft state must independently converge before awaiting can no-op.
- Closeout authority and deployment authority are independent after implementation merge; direct closeout commits locally while optional closeout publishes one deterministic review head.

## Execute UAT

| DC | Procedure | Result | Evidence |
| --- | --- | --- | --- |
| DC-1 | landing resolver suite | PASS | 94/94 both shells; rebase, squash, merge-commit, young-root and ambiguity/moving-main cases |
| DC-2/4/5/6 | default reconciler suite | PASS | R11 91/91; R10 120/120; default 198/198; receipt 92/92; R9 59/59; R8 50/50; R7 19/19; R6 289/289; R4 29/29; R3 107/107; R2 13/13 + 23/23, all dual-shell |
| DC-3 | debrief schema + C15 | PASS | schema PASS; C15 through `OK C15.23b` |
| DC-7 | exact seven-command compatibility chain | PASS | todo 5/5, metadata 45/45, mergeable 115/115, feedback C14 31/31, C1..C15 all OK |
| DC-8 | `SHIP_FLOW_CLOSEOUT_CASE=pr40-pr41` | PASS | 141/141; first run terminalizes once, second byte/hash no-op |
| Optional PR | `SHIP_FLOW_CLOSEOUT_CASE=optional-pr` | PASS | 179/179; exported bytes plus authoritative Git/source proof, one PR/bundle |
| Operator setup | syntax-check README example; resolve real root/helper only | PASS | helper present; `network_actions=0`; no reconciler/GitHub action invoked |

Ancillary evidence: TDD ledger `status=pass records=5`; Bash syntax, Python AST parse, ShellCheck, and `git diff --check` all exit 0; non-UI render fidelity is N/A.

## Execute Report

status: passed
stage_cost: five serial delegated waves plus eleven feedback cycles with overlapped execute/review
tasks_summary: T1-T5, F1-F4, R2-F1/R2-F2/R2-F3/R2-I, R3-B1, R4-B1/W1, R5-B1, R6-B1/W1, R7-B1, R8-B1, R9-B1/B2, R10-B1/B2, and R11-B1/B2/B3 done; 0 blocked
cross_review_verdict: APPROVED after all eleven feedback cycles received independent re-review
cross_review_coaching: Keep review-driven reopens attached to their original task and surface methodology substitutions explicitly so Verify inherits the actual execution graph.
science_officer_em_upward_report: {em_judgment: "execute evidence and attribution are verification-ready", recommendation: "finalize execute artifact; FO may route verification", route: proceed, confidence: high}
knowledge_captures: 2

### Metrics

duration_minutes: 2105
iteration_count: 36 implementation/review repair loops
task_count: 22
tasks_done: 22
tasks_blocked: 0
commit_count: 27 implementation/docs/test commits

### Hand-off to Verify

<!-- section:hand-off-to-verify -->
```yaml
commit_list:
  commits: [42b9637, 1870efb, 4069946, a196da6, 2424b9d, 42f8e06, bdbbf96, c08c391, 3ee8f21, 490a294, fb6f4aa, b5fa535, b6cd023, 91402c7, 110bc09, 85d6dff, 54a4a9a, 8d1ac64, eba76c1, 0fdbe25, 743f1af, 0a47e50, e3adebe, 9e8cc8c, 90bd6dd, e094f4e, 2c02bae]
  verified_head: 2c02bae22cd816429c41f4e135e10b08c9a4981e
dc_status:
  - {id: DC-1, status: PASS, evidence: "landing resolver 94/94 both shells"}
  - {id: DC-2/DC-4/DC-5/DC-6, status: PASS, evidence: "R11 91/91; R10 120/120; default 198/198; receipt 92/92; R9 59/59; R8 50/50; R7 19/19; R6 289/289; R4 29/29; R3 107/107; R2 13/13 + 23/23, all dual-shell"}
  - {id: DC-3, status: PASS, evidence: "debrief schema and C15 PASS"}
  - {id: DC-7, status: PASS, evidence: "exact compatibility chain and C1-C15 exit 0; feedback C14 31/31"}
  - {id: DC-8, status: PASS, evidence: "PR40/41 141/141 and two-run no-op"}
deviations:
  - "No task was added, removed, or scope-expanded; primary waves remained W1-W5 serial."
  - "After W3 and before W4, review reopened T2-owned receipt schema paths in 42f8e06 to clarify transaction.main_commit as the implementation landing anchor, never the projection or optional closeout-PR merge SHA."
  - "Review-driven tests and repairs stayed within each task's owned paths and acceptance contract."
  - "T2 did not use plan-listed superpowers:writing-skills; TDD plus independent schema/spec/quality review supplied the contract discipline instead."
  - "Verify feedback cycles added only F1-F4, R2-F1/R2-F2/R2-F3/R2-I, R3-B1, R4-B1/W1, R5-B1, R6-B1/W1, R7-B1, R8-B1, R9-B1/B2, R10-B1/B2, and R11-B1/B2/B3 for bounded blockers through provider-bound terminal recovery and signal-owned validation; W2/W3/W4 remain deferred."
render_fidelity_evidence: "N/A — non-UI entity"
stub_ack_log: []
skills_needed_used:
  T1: [ship-flow:test-driven-development, test, best-practices]
  T2: [ship-flow:test-driven-development, test, best-practices, api-design]
  T3: [ship-flow:test-driven-development, test, best-practices]
  T4: [ship-flow:test-driven-development, test, best-practices, write-docs]
  T5: [write-docs, verify-before-complete]
context_read_receipts:
  all_tasks: "no non-root folder guidance matched; root instructions remained session context"
```
<!-- /section:hand-off-to-verify -->

## Cycle 12 Bounded Fix (R12-B1, R12-B2, R12-W1)

Closed R12-B1 (exact `refs/heads/` deterministic-head resolution, no tag DWIM), R12-B2 (ancestor-of-terminal-first awaiting-predecessor scan with a legacy fallback), and R12-W1 (unconditional fail-closed validator-root guard) in `merged-pr-closeout-reconciler.sh`. RED confirmed via `git stash` against the pre-fix code (5/5 defects reproduced exactly); GREEN 21/21 both shells; full existing suite (R11 91/91, R10 120/120, default 198/198) and C1-C15/no-dangling/version-triple unaffected. Full findings, fixes, and evidence below.

<details>
<summary>Cycle 12 detail: findings, fixes, RED/GREEN evidence</summary>

### R12-B1 — exact deterministic-head resolution (no tag DWIM)

Defect: `scan_closeout_receipts`'s awaiting-phase check, `ensure_initial_closeout_head`,
`resolve_or_create_closeout_pr`'s fixture-registered-PR reuse, and `build_optional_terminal_head`
all read the deterministic closeout head via a bare `git rev-parse "$deterministic_head"` /
`git cat-file -e "${deterministic_head}:..."` / `git show "${deterministic_head}:..."` /
`git archive "$deterministic_head"`. Git's own ref-DWIM prefers `refs/tags/<name>` over
`refs/heads/<name>` for a bare short name, so a same-name tag with a different OID/tree could be
silently selected instead of the branch.

Fix: added `resolve_exact_deterministic_commit()` (accepts a verified 40-hex OID as-is — never
DWIM-ambiguous — or resolves a branch-name-shaped head only through
`refs/heads/<name>^{commit}`), used inside `optional_terminal_head_matches` for its internal
`git show`/`git archive` calls. The four external bare-resolution call sites (`scan_closeout_receipts`
awaiting check, `ensure_initial_closeout_head`, `resolve_or_create_closeout_pr` fixture reuse,
`build_optional_terminal_head`) now resolve via `git rev-parse --verify "refs/heads/${name}^{commit}"`
and `git cat-file -e "refs/heads/${name}:${path}"`, mirroring the pre-existing, already-correct
LANDED-path pattern (`plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh:794-795`).

### R12-B2 — ancestry-bound awaiting-predecessor selection

Defect: `recover_awaiting_closeout_predecessor` scanned bounded main history and bound the
awaiting predecessor to the NEWEST commit carrying byte-identical awaiting bytes, without
checking that commit is an actual ancestor of the provider terminal. Topology A/B/T/M — terminal
T built from real checkpoint A; a later main-only commit B (e.g. concurrent unrelated main
movement) inherits the same unchanged receipt bytes but is not an ancestor of T — picked B, the
caller's separate `merge-base --is-ancestor` check then failed, false-rejecting the legal
recovery via A.

Fix: the scan now tracks two candidates per iteration — the legacy newest-carrier (unchanged, to
preserve existing bounded-failure semantics when NO candidate is an ancestor at all) and the
first (newest) ancestor-of-terminal carrier found via `git merge-base --is-ancestor "$commit"
"$terminal_ref"`. `recover_awaiting_closeout_predecessor` gained a 4th `terminal_ref` parameter
(the call site passes the already-verified `terminal_source` OID). When an ancestor candidate
exists, it wins; otherwise the function falls back to the legacy pick so the caller's existing
ancestry check still fails closed with its established `closeout-checkpoint-conflict` /
"does not descend from its durable awaiting checkpoint" reason for genuinely-ambiguous /
no-valid-ancestor cases (verified via the existing R11 provider-ancestry regression, which
regressed on the first (filter-only) design attempt and was fixed by adding the legacy-fallback
track — see Issues Found below). Legacy hash-mismatch ambiguity detection (two candidates with
genuinely different content) is untouched.

### R12-W1 — explicit fail-closed validator-root propagation

Defect: `ensure_owned_validator_root()` returned 1 on `mkdir` failure via a bare `return 1`. Several
callers reach this function through another function's own `|| return $?` chain (e.g.
`validate_receipt_normal`'s internal call to `prepare_receipt_source_commits`), which disables
`set -e` for the callee's entire dynamic extent — an unpropagated failure could let the resulting
empty `owned_validator_root` flow into `mktemp "$owned_validator_root/validator.XXXXXX"`
(i.e. `mktemp /validator.XXXXXX`) instead of stopping.

Fix: `ensure_owned_validator_root()` now calls `reject_input closeout-checkpoint-conflict
"closeout validator root could not be created"` on `mkdir` failure — an unconditional `exit 2`
with the tool's normal structured REJECT report, independent of any `set -e` suppression in the
calling context. This covers all 6 call sites uniformly without depending on caller discipline.

### RED -> GREEN evidence

New focused dual-shell regressions (`SHIP_FLOW_CLOSEOUT_CASE=feedback-r12-b1-b2-w1`,
`plugins/ship-flow/lib/__tests__/test-merged-pr-closeout-reconciler.sh`):
`run_feedback_r12_b1_tag_dwim_case` (same-name colliding tag with a different OID on the
awaiting/OPEN path), `run_feedback_r12_b2_ancestry_case` (A/B/T/M topology reproduced via one
`--allow-empty` main commit after T is built from A), `run_feedback_r12_w1_validator_root_case`
(PATH-shadowed `mkdir` fails only the `ship-flow-closeout-validator.*` path).

RED (verified against the pre-fix reconciler via `git stash push -- \
plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh`, same test file): 16/21 passed, 5 failed
— `R12-B1 ... resolves the exact branch, not the tag` (expected exit 0, got 1,
`detail=existing terminal closeout head does not extend the durable awaiting predecessor`);
`R12-B2 ... accepts the true ancestor A` and `... converges to terminal no-op` (expected exit 0,
got 1, `detail=landed closeout provider head does not descend from its durable awaiting
checkpoint`); `R12-W1 ... fails closed with the REJECT contract` and `... reports a stable
reason` (expected exit 2, got 1, no `reason=` line at all). All five failures reproduce the exact
defects named above; `git stash pop` restored the fix afterward.

GREEN (fixed reconciler): R12 21/21 on Bash 5.3 and 3.2. Full local gate, both shells: R11
91/91, R10 120/120, default 198/198 (all previously-established suites unaffected). One
regression was caught and corrected mid-cycle: an earlier filter-only R12-B2 design broke `R11
provider terminal bytes outside awaiting ancestry fail closed` (a real no-valid-ancestor case) by
turning its established `prompt_captain`/exit-1 rejection into a different `reject_input`/exit-2
path; the legacy-fallback design above restored it to 91/91 (see Issues Found).

Static/hygiene: `bash -n` on both shells and `shellcheck -s bash` clean for both the reconciler
and the test file; `git diff --check` exit 0. `check-invariants.sh` (C1-C15) exit 0;
`scripts/check-no-dangling.sh` PASS; `scripts/check-version-triple.sh` PASS. TDD ledger unchanged
(`status=pass records=5`) — consistent with prior feedback cycles, which record fixes under the
originating task's ledger entry rather than adding new records per cycle.

### Deferred / out-of-scope observations

- `bind_closeout_push_destination`'s `git send-pack ... "${deterministic_head}:${remote_ref}"`
  (`plugins/ship-flow/bin/merged-pr-closeout-reconciler.sh` `ensure_initial_closeout_head`, non-fixture
  branch) also passes the bare `deterministic_head` as a refspec source, which is technically the
  same DWIM class as R12-B1 but was not cited by Round 12 and touches push-destination code the
  captain marked out-of-scope for this bounded round. Left as-is per the scope boundary; flagging
  for FO triage as a possible future finding.

</details>

<!-- /section:execute-report -->
