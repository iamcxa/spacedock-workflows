---
title: Align C14 with First Officer stage-entry transitions
status: done
source: blocker discovered while starting issue #20
started: 2026-07-14T08:07:52Z
completed: 2026-07-16T16:56:47Z
verdict: PASSED
score:
worktree: /Users/kent/conductor/workspaces/spacedock-workflows/yangon/.worktrees/c14-frontmatter-authority-integration
issue: "#30"
pr: "#47"
archived: 2026-07-16T16:56:47Z
---

The First Officer owns stage entry and currently records it with `dispatch: <feature> entering <stage>`, while C14 recognizes only the completion-side `advance-stage.sh` commit signature. The mismatch makes a legitimate FO `draft -> shape` transition fail the invariant and shell-suite baseline before feature work starts.

## Acceptance criteria

**AC-1 — Legitimate FO stage entry is mechanically recognized.**
Verified by: a RED-first fixture covering `draft -> shape` through the canonical FO dispatch path passes after the fix.

**AC-2 — Manual status bypass remains blocked.**
Verified by: arbitrary or lookalike commit messages that hand-edit frontmatter status without a sanctioned transition receipt continue to fail C14.

**AC-3 — Entry and completion contracts are aligned.**
Verified by: the workflow/FO-facing process contract names the stage-entry receipt, C14 recognizes it narrowly, and completion-side `advance-stage.sh` enforcement remains intact.

**AC-4 — Dogfood baseline is restored without allowlists.**
Verified by: the current branch passes invariants, the shell suite, and Node tests without commit-hash grandfathering or a forged `advance-stage.sh` signature.

## Historical Execute Report: broad evidence branch

- DONE: RED-first regression covers a legitimate FO draft-to-shape dispatch and preserves a failing arbitrary manual mutation case
  Case 14 failed before implementation (expected 0, got 1); final targeted suite passes 18/18, including manual, malformed, wrong-stage, and whitespace-only-summary rejection cases.
- DONE: A narrow sanctioned stage-entry receipt is aligned across implementation, invariant documentation, and FO-facing workflow process without hash allowlists or forged advance-stage signatures
  Commit `f8fc638` accepts subject-only `dispatch|advance: <non-empty summary> entering <stage>` receipts only when every mutated entity after-status matches; completion-side `: advance status to ` remains unchanged.
- DONE: Targeted C14 tests plus the full invariant, shell, and Node suites are run and reported with exact results
  C14 targeted 18/18; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103 exit 0; Node 79/79 exit 0; shellcheck and `git diff --check` clean.

### Summary

C14 now recognizes the First Officer's fresh-dispatch and same-worker-reuse stage-entry receipts while binding the named stage to the actual entity after-state. The repair keeps arbitrary status edits and receipt lookalikes blocked, preserves completion-side `advance-stage.sh` enforcement, and restores the dogfood invariant baseline without commit allowlists.

## RoboRev Shadow Follow-up

RoboRev job 4 found that a canonical-looking subject could still authorize a skipped or undeclared backward transition. RED-first Cases 19 and 20 reproduced both bypasses: `draft -> plan` and `shape -> draft` returned exit 0 before the repair when exit 1 was required. A second RED-first Case 22 proved the legacy body-table signature exemption also skipped graph validation. C14 now resolves the owning workflow README at the commit parent and accepts only the next declared state or the current state's declared `feedback-to` edge, including for exempt body-table entities. Targeted coverage is 22 cases, including a positive `verify -> execute` feedback route.

RoboRev job 7 then found two second-order gaps. A completion-looking signature could still authorize an illegal body-table or mixed-path transition because graph validation happened inside receipt/exemption branches, and CRLF/trailing-space README values failed to match. RED-first Cases 23–25 reproduced all three paths. Graph validation now runs for every mutated path before every receipt kind or exemption, and parsed stage/feedback values are normalized.

Fresh job-7 follow-up verification: C14 targeted 25/25; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean. One unrelated UI timing assertion failed once under full-suite load, then passed 28/28 alone and the complete 103-suite rerun passed.

RoboRev job 10 found that the workflow parser could continue into a later root-level list and that C14's flat-file pathspec excluded single-word slugs. RED-first Cases 26 and 28 reproduced both bypasses; the parser now stops at the next root key and the pathspec covers all flat Markdown entities while excluding workflow READMEs. Case 27 could not reproduce the proposed CRLF commit-subject failure — Git's `%s` path already normalized it — so no speculative `tr` fix was added. Targeted coverage is now 28/28.

Fresh job-10 follow-up verification: `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 13 found that a nested decoy `stages:` key could still be mistaken for the root workflow graph. RED-first Case 29 reproduced the bypass. The parser now requires an unindented root `stages:` key and reads names only from its canonical `states:` child. Targeted coverage is 29/29.

Fresh job-13 follow-up verification: `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 16 found that nested stage metadata could still satisfy the graph parser. RED-first Cases 30 and 31 reproduced nested `name` and `feedback-to` bypasses; canonical indentation is now enforced. The same review claimed deletions and layout migrations were blocked, but Cases 32 and 33 showed both already passed. Case 34 instead exposed the real migration risk: flat-to-folder absorption could hide a simultaneous status jump. C14 now pairs layout paths by stable identity and routes only status-changing migrations through graph/receipt validation. Targeted coverage is 34/34.

Fresh job-16 follow-up verification: `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 19 found three remaining history-shape boundaries. RED-first Case 35 proved a slug or numbered-folder rename could evade path-derived migration pairing even when frontmatter carried the same durable `id`. Case 36 proved merge-resolution mutations were hidden by `diff-tree`'s default merge handling. Case 37 proved a legitimate legacy body-table flat-to-folder transition was checked at the new, nonexistent parent path and falsely lost its receipt exemption. C14 now enumerates every branch commit, diffs each commit explicitly against its first parent with rename folding disabled, correlates migrations by workflow-local frontmatter `id` (falling back to layout identity), and retains each mutation's original path for parent-state exemption checks.

Fresh job-19 follow-up verification: C14 targeted 37/37; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 22 found a legacy identity-upgrade gap: a no-`id` flat entity and an ID-bearing folder replacement used different migration identities, so a simultaneous status jump could look like an exempt deletion plus addition. RED-first Case 38 reproduced the bypass. Migration correlation now uses equal workflow-local IDs when both sides have them, but falls back to equal flat/folder layout identity when either side lacks an ID; arbitrary no-ID renames remain unpaired rather than guessed.

Fresh job-22 follow-up verification: C14 targeted 38/38; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 25 found that an empty parsed status was still conflated with an absent file. RED-first Cases 39 and 40 independently reproduced both halves of a remove-then-restore bypass: removing `status:` from an existing entity and restoring an arbitrary stage on an existing status-less entity each passed as a supposed file deletion/addition. C14 now checks blob existence at both revisions; only genuine path deletion/addition enters migration exemptions, while status-field removal or restoration on an existing entity is rejected by transition-graph validation.

Fresh job-25 follow-up verification: C14 targeted 40/40; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 28 extended the same path/status distinction to moves: a migration that removed status recorded only its deletion side, while a migration that restored status recorded only its addition side, so neither could be paired. RED-first Cases 41 and 42 reproduced both bypasses. Changed paths are now classified exclusively by blob existence before status comparison; both migration sides are retained even when one status is empty, and any paired empty-to-stage or stage-to-empty change is rejected by graph validation.

Fresh job-28 follow-up verification: C14 targeted 42/42; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 31 found that AWK's missing feedback entry compared equal to an empty after-status and that changing an ID during a same-layout migration defeated ID-first pairing. It also showed Case 39's missing receipt had masked the graph error. Case 39 now carries a completion-looking receipt and RED-first Case 43 covers an ID change plus skipped stage; both bypasses reproduced before the repair. Graph validation now rejects empty endpoints and requires actual feedback-map membership, while migration correlation treats equal layout identity as decisive before using equal durable IDs for true renames.

Fresh job-31 follow-up verification: C14 targeted 43/43; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 34 found that first-parent-only merge diffs re-required a receipt for a transition already owned by an unchanged second-parent commit. RED-first Case 44 reproduced the false positive with an ordinary no-conflict merge, complementing Case 36's merge-resolution mutation failure. C14 now ignores a merge path whose resulting existence and status exactly match any other parent, while continuing to validate resolution-only states that differ from every parent. The review's bare-return robustness concern was also removed with explicit comparison returns.

Fresh job-34 follow-up verification: C14 targeted 44/44; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

RoboRev job 37 found that a migration changing layout identity and frontmatter ID simultaneously escaped both semantic correlation rules. RED-first Case 45 reproduced the bypass with a skipped transition. C14 now also records Git's low-threshold content-similarity rename mapping as correlation evidence; the hint only pairs old/new paths, while status comparison, workflow graph validation, and receipt checks remain authoritative.

Fresh job-37 follow-up verification: C14 targeted 45/45; `CI=true check-invariants.sh` exit 0 with C14 OK; canonical top-level shell loop 103/103; Node 79/79; `bash -n`, shellcheck, and `git diff --check` clean.

Receipt provenance remains an explicit cross-repository boundary: the current Spacedock First Officer contract emits only a canonical commit subject, so Ship-Flow can validate its structure and transition semantics but cannot authenticate its author. Tool-owned or signed provenance requires a coordinated Spacedock receipt-contract change rather than a self-attested Ship-Flow field.

## Stage Report: shape

- DONE: Recover the original problem from GitHub #30 and preserve the captain ownership trail verbatim: the proposal came from another FO; do not invent captain framing.
  Evidence: `c14-fo-dispatch-contract/shape.md` records GitHub #30 provenance and both captain quotes verbatim.
- DONE: Shape Safe NARROW as a small-batch Cases 14–31 receipt+graph+parser slice; explicitly defer migration/rename #36, merge semantics #37, and tool-owned provenance #38.
  Evidence: `c14-fo-dispatch-contract/shape.md` splits Cases 14–25 and 26–31 within a 2.2-day appetite and names all three deferrals.
- DONE: Produce the canonical shape artifact/report with appetite-fit, critical assumption, registry/canonical-doc impact, independent cross-review, and a commit in the existing C14 worktree; stop for the captain gate.
  Evidence: `c14-fo-dispatch-contract/shape.md` carries the full artifact and the same reviewer returned seven-factor PASS / PROCEED to captain gate.

### Summary

The canonical shape artifact now preserves the prior ledger while constraining #30 to Safe NARROW Cases 14–31 in two appetite-fitting children. Migration/rename, merge, and authenticated-provenance semantics remain deferred to #36–#38, and the cross-review verdict is PROCEED; no stage advancement was performed.

## Captain Bet (gate approval 2026-07-14)

把「stage-entry dispatch」和「completion advancement」定義成兩個各自獨立、可機器驗證的合法 contract，能讓 Ship-Flow 的自動化流程在不犧牲安全性的前提下，順暢承載 First Officer 主導的 dogfood 工作流。

一做好後下一次 ship 就應該立即生效，甚至是修復好當下同一個 entity 就可以生效

## Stage Report: design

- DONE: Define stage-entry dispatch and completion advancement as independent legal contracts, with every load-bearing skill, helper, invariant, architecture, workflow-schema, and deliberate no-delta surface named.
  Evidence: `c14-fo-dispatch-contract/design.md` separates FO subject/graph receipts from helper-owned completion and types five planning constraints with D1/D2 backreferences.
- DONE: Inventory shell, exact string-assertion, helper, stage-wiring, current-entity, next-ship, and repository-gate evidence.
  Evidence: the design binds Cases 1–31, the real `8b9488c` `shape -> design` receipt, compatible-folder completion, legacy-flat fallback, and the final clean-range audit.
- DONE: Preserve manual-bypass detection and Safe NARROW while resolving independent review findings without importing Cases 32–45.
  Evidence: local design validators and targeted C14 pass; second-loop independent cross-review returned PROCEED, and FO-owned range narrowing remains a machine-readable pre-ship constraint.

### Summary

Design is plan-ready with two independent machine-verifiable transition contracts, explicit current-entity and next-ship activation paths, and a tested flat-ledger safety boundary. The plan must add missing design-stage completion wiring and exact contract assertions, then the First Officer must prepare a clean Cases 14–31 ship range before review or merge; no stage advancement was performed.

## Stage Report: plan

- DONE: Produce small TDD tasks mapping C14.1 Cases 14–25 and C14.2 Cases 26–31 to exact implementation/test paths with runnable RED, expected failure, GREEN, refactor, wave, dependency, and owned-path contracts.
  Evidence: `c14-fo-dispatch-contract/plan.md` defines T1–T3 and the persisted five-record `tdd-ledger.jsonl`; validation returns `status=pass records=5`.
- DONE: Plan both independent contracts and immediate activation, including compatible-folder design completion, the prose-only legacy-flat fallback, literal receipt/triple assertions, real same-feature receipts, and a disposable next-ship sequence with negative cases.
  Evidence: T1 and T4 pin the exact grammars and full FO-entry → C14 → helper-completion → separate-next-entry fixture while distinguishing flat safe refusal from routing enforcement.
- DONE: Record Canonical Doc Actions and an FO-owned, machine-verifiable clean-range strategy excluding Cases 32–45 and unrelated harvest before execute, review, or ship.
  Evidence: the plan recommends a new worktree from `origin/main`, carries exact source/hunk provenance, checks every T1–T4 path is initially clean, and gives T5 a final allowlist/forbidden-anchor assertion.

### Summary

The plan is execution-ready after the First Officer supplies the clean ref: five bounded tasks, four runnable verification rows, exact Safe NARROW provenance, and a persisted RED/GREEN ledger. Research second pass returned APPROVED and plan cross-review loop 2 returned PROCEED with `skill-coverage: PASS`; no stage advancement was performed.

## Stage Report: execute

- DONE: Execute plan tasks T1–T5 wave-by-wave from the clean ref with ledger-backed RED-before-GREEN evidence and no import of deferred Cases 32–45.
  Evidence: `c14-fo-dispatch-contract/execute.md` records every RED/GREEN cycle, review fix, scoped commit, and the five-record ledger validation.
- DONE: Land the independent First Officer stage-entry and stage-worker completion contracts with immediate-activation proof while preserving graph-first manual-bypass safety.
  Evidence: C14 Cases 1–31, routing 16/16, helper Cases 1–24, and the stage-wiring fixture prove FO design entry → idempotent design completion → separate FO plan entry; #36–#38 remain deferred.
- DONE: Run the named focused and repository gates, record deviations, and complete independent execute cross-review without advancing stage state.
  Evidence: invariants, 103 shell test files, Node 79/79, exact shellcheck, no-dangling, version triple 0.9.0, artifact-aware range, and diff checks pass; cross-review round 2 returned PROCEED after fixing round 1 truthfulness findings.

### Summary

Safe NARROW now supplies two machine-verifiable owner-bearing automation contracts and immediate same-entity/next-ship activation. The graph-gated shape-confirm-era manual compatibility exception is explicitly outside automated eligibility and remains bounded by Cases 8/22/23 until its retirement trigger; migration/rename, merge semantics, and authenticated provenance remain in #36–#38. The entity remains at `status: execute` for First Officer review and stage advancement.

## Stage Report: verify

- DONE: Independently rerun AC-1–AC-4 and DC-1–DC-4, including the real same-entity entry, a quiescent 103-file shell suite, and adversarial disposable Git fixtures.
  Evidence: `c14-fo-dispatch-contract/verify.md` records 2 VERIFIED and 4 NOT VERIFIED required parent claims; current `execute -> verify` activation and the narrowed repository gates pass.
- DONE: Run general, silent-failure, testing, maintainability, security, schema, and red-team review with 100% citation checking and explicit cross-model degradation.
  Evidence: reviewers found eight reproducible contract/safety blockers; `agy` quota and Claude auth failures are recorded rather than treated as evidence.
- DONE: Classify the round truthfully as failed/VETO, preserve Safe NARROW and #36–#38 boundaries, and emit bounded execute bounce tasks without advancing state.
  Evidence: verify hand-off blocks review, retains `status: verify`, and writes no completion or next-stage receipt.

### Summary

Verify confirms that Contract 1 works immediately on this entity, but rejects the claimed two-contract/default-next-ship safety: completion can impersonate entry, the ownerless exception can absorb FO-looking automation, default shape output is graph/schema-incompatible and loses prior links, and helper/C14 false-success paths remain. The First Officer should return the bounded fixes to execute; Cases 32–45 and provenance #38 stay deferred.

## Stage Report: execute

- DONE: Make canonical frontmatter the sole machine authority under a closed canonical top-level grammar while preserving structurally valid opaque bytes.
  Evidence: exotic top-level key syntax remains structurally parseable and byte-preserved but is Contract-2-ineligible until offline normalization.
- DONE: Keep completion advancement independent from stage entry, with cooperative lease ownership, ref-only CAS, no status jump, and twelve partition-covering advance integrations.
  Evidence: positive cases reach the missing-lease boundary; container and lexical failures reject pre-lease without ref, index, worktree, or receipt mutation.
- DONE: Stratify exhaustive lexical proof from bounded Git integration proof without weakening coverage.
  Evidence: production seams close exactly 128 masks, 896 target decisions, and 448 render closures; the classifier covers 265 direct cases and wiring covers exactly 12 real advances.
- DONE: Freeze the bounded implementation and final evidence on one reviewed fingerprint.
  Evidence: focused `cd457460a65ec4c6d2148c822084cff2adbed270c0eedeae67842953e29deacd`; production `a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10`; Slice A `+590/-193`, manifest `d5f89b85a59698d621fea007f5f140b5c9df9e40a121b75363851e4475dee075`; Slice B manifest `156dd2f026a4a037749adae759ad2d541bba9a813a8cd18760399576888c2191`, churn 370. Cold/warm runs were 17.93/16.39/24.56/22.59 seconds; shell was 105/105 in 392.86 seconds; Node was 79/79; raw ShellCheck, `bash -n`, diff, and no-dangling were clean. FINAL SPEC PROCEED and FINAL QUALITY PROCEED were RECONFIRMED.
- DONE: Preserve the flat-current compatibility boundary and explicit Safe NARROW deferrals.
  Evidence: current flat C14 remains Contract-1-only; migration/rename #36, merge semantics #37, and authenticated provenance #38 remain deferred.

### Summary

Implementation commit `51129c2` is ready for fresh verify. Current flat C14 remains Contract-1-only, while the next compatible folder ship receives the full Contract-2 path immediately. This report claims neither merge nor ship.

## Stage Report: verify (cycle 2)

- DONE: Independently verify every C14 acceptance criterion and the previously bounced blockers against exact committed HEAD f1b5b73 (implementation 51129c2, execute report bdf1d20); do not edit implementation code or tests.
  AC-1 through AC-4 pass their fresh behavioral checks; the prior completion-impersonation, ownerless-exception, producer-loss, Git-enumeration, rollback, lease, and dirty-state blockers have executable negatives.
- FAILED: Run the required focused, invariant, static, and range checks in the active absolute worktree; reconcile exact counters, hashes, runtime evidence, and the legacy-flat current-entity boundary while preserving deferrals #36-#38.
  Functional gates and fingerprints pass, but Slice B's reported churn 370 cannot fit its hard `+210/-150` envelope (maximum 360), and no directional numstat/source baseline is present to prove either bound.
- DONE: Write the durable Stage Report: verify with per-AC evidence, runtime_uat marked not-applicable or deferred with reason, explicit PASS or VETO, and no merge/ship claim; report all changed paths and verification commands.
  This cycle records `VETO`; changed path is only `docs/ship-flow/c14-fo-dispatch-contract.md`.

### Acceptance evidence

- AC-1 PASS: `f1b5b73` is `dispatch: c14-fo-dispatch-contract entering verify`, changes `execute -> verify`, and targeted C14 plus both live C14 invariant checks pass.
- AC-2 PASS: targeted C14 is 37/37 and stage wiring 62/62; arbitrary manual entry, FO-shaped lookalikes, completion impersonation, skipped edges, and Git enumeration/subject faults fail closed.
- AC-3 PASS: completion helper 103/103, lifecycle review 6/6, shape producer 71/71, and project instantiation 68/68 prove status-idempotent completion, canonical producer registries, lease/CAS separation, and rollback.
- AC-4 PASS: focused proof reports 128 subsets, 896 decisions, 448 closures, 265 lexical cases, and 12 integration partitions; isolated cold/warm runs are 31.25/33.79/42.34/29.51 seconds.
- AC-4 PASS: canonical shell loop is 105/105 in 462 seconds; Node is 79/79; invariants, plan-exact and recovery-core ShellCheck, `bash -n`, no-dangling, version triple 0.9.0, and diff checks pass.

### Range, runtime, and disposition

- Focused SHA-256 `cd457460a65ec4c6d2148c822084cff2adbed270c0eedeae67842953e29deacd` and production SHA-256 `a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10` match.
- Current-content manifest reconstruction matches Slice A `d5f89b85a59698d621fea007f5f140b5c9df9e40a121b75363851e4475dee075` and Slice B `156dd2f026a4a037749adae759ad2d541bba9a813a8cd18760399576888c2191`; the ignored saved Slice-A list is stale for two files but sums to `+590/-193` after current-hash reconciliation.
- Current flat `docs/ship-flow/c14-fo-dispatch-contract.md` is executably Contract-1-only; forbidden Cases 32-45/migration/merge symbols remain absent, preserving #36-#38.
- runtime_uat: not-applicable — this is a non-UI shell/Git contract; disposable Git fixtures and the real `f1b5b73` transition are the runtime evidence.
- Dispatch metadata degraded: generated branch `spacedock-ensign/c14-fo-dispatch-contract` is stale; verification stayed on authoritative `spacedock-ensign/c14-frontmatter-authority` without switching or renaming.
- Verdict: VETO — return only the missing/over-budget Slice-B directional proof or a bounded correction to execute; no merge or ship claim is made.

### Verification commands

`CI=true timeout 90 bash test-completion-v1-frontmatter.sh` x4; targeted C14/helper/wiring/lifecycle/producer tests; `CI=true bash check-invariants.sh`; canonical 105-file shell loop; `node --test`; exact ShellCheck; `bash -n`; no-dangling; version-triple; SHA-256/numstat/range/legacy-flat/forbidden-symbol checks; `git diff --check`.

### Summary

Fresh verification confirms the recovery implementation closes the prior behavioral blockers and keeps current flat C14 plus #36-#38 boundaries intact. The stage remains VETO because the recorded Slice-B churn is mathematically outside its hard directional envelope and lacks durable directional proof; only this report changed, with no implementation, test, merge, ship, or state-advance mutation.

### Feedback Cycles

| cycle | date | reviewer verdict | routed to | findings | resolution |
|---|---|---|---|---|---|
| 1 | 2026-07-16 | verify cycle 2 VETO, captain rejected gate | execute (fresh cycle-1 dispatch) | Slice B reports churn 370 against the independent hard `+210/-150` envelope (maximum 360), with no durable directional numstat/source baseline; functional ACs remain passed | **RESOLVED** — reconstructed the frozen-source baseline and exact `+184/-186` numstat; confirmed the captain-approved drift-control amendment (`additions <=210`, churn `<=370`) superseded the stale deletion ceiling; audit found only intentional obsolete-parser removal, no scope/capability drift, and no product/test change was required (`29cf79f`) |

## Stage Report: execute (feedback cycle 1)

- DONE: Reconstruct and durably record Slice B's authoritative source baseline, exact owned-path list, directional numstat, and manifest at committed HEAD 930b4bb; reconcile the verify-cycle-2 finding that churn 370 cannot fit the independent hard +210/-150 envelope.
  Evidence: the frozen dirty source tree at `a14afb9` has manifest `2e0b41f3f328f991177bcc24a8cd29a8f510dc4f74ba8291c99d76142bbe6adf`; committed target `930b4bb` has manifest `156dd2f026a4a037749adae759ad2d541bba9a813a8cd18760399576888c2191` and exact `+184/-186` numstat.
- SKIPPED: Using RED-first/TDD discipline, make only a legitimate minimal Slice B correction that preserves all green behavior while reaching additions <=210 and deletions <=150; do not borrow Slice A budget, reset either envelope, weaken tests, add filler, relabel paths, or grow scope, and BLOCK with evidence if this cannot be done honestly.
  Rationale: FO-routed EM provenance confirmed the captain's final amendment treats the budget as a drift detector/control limit and supersedes the stale directional deletion ceiling with additions `<=210` plus total churn `<=370`; the 10-line variance from the stale maximum-360 reading is solely intentional obsolete body-parser removal, so restoring bytes would lower quality and product/test edits were prohibited.
- DONE: Run the affected focused/range/static checks first and only the broader gates required by the execute contract after bytes change; append a durable Stage Report: execute (feedback cycle 1) with exact baseline, numstat, commands, hashes, changed paths, and READY or BLOCKED, without changing frontmatter, Feedback Cycles, merge, ship, or GitHub issues.
  Evidence: no implementation bytes changed; lightweight manifest, approved-budget, `git diff --quiet 930b4bb`, `bash -n`, and `git diff --check` proofs passed, with no full-suite rerun authorized.

### Baseline, range, and provenance

- Source: frozen `spacedock-ensign/c14-completion-v1-narrow-rebuild` filesystem at `a14afb9c93277b8feb3e35796f1c430bb9c6b163`; source-dirty Slice B paths were `INVARIANTS.md`, `check-invariants.sh`, `test-stage-wiring.sh`, and `ship-design/SKILL.md`.
- Owned paths and numstat: `INVARIANTS.md +6/-6`; `README.md +3/-3`; `check-invariants.sh +49/-69`; `test-check-invariants.sh +24/-0`; `test-enforce-advance-stage.sh +6/-6`; `test-render-stage-links.sh +50/-39`; `test-stage-wiring.sh +18/-7`; `render-stage-links.sh +15/-44`; `entity-body-schema.yaml +10/-9`; `ship-design/SKILL.md +3/-3`.
- Total: `+184/-186`, churn `370`; approved final controls are additions `<=210` and churn `<=370`. The 10-line variance from the stale directional maximum of 360 is explained by removing obsolete body-parser authorization code.
- Drift audit: all 10 paths remain inside Slice B, no capability or file-scope expanded, no budget was borrowed/reset, and no filler, weakened test, or relabeling was introduced. Budget variance triggers explicit engineering review rather than mechanical padding or rejection; restoring obsolete bytes would reduce quality per token.
- Approval provenance: First Officer-routed Engineering Manager confirmation on 2026-07-16 of the captain's final Slice B amendment and drift-control interpretation; the earlier `+210/-150` wording in the execute ledger was stale.

### Verification commands and disposition

- `git diff --no-index --numstat` across the ordered 10-path frozen-source/current pair; recomputed both ordered `sha256sum` manifests.
- Approved budget assertion: additions `184 <= 210`, churn `184 + 186 = 370 <= 370`; PASS.
- `git diff --quiet 930b4bb -- <10 Slice B paths>`; PASS, proving no product/test-byte correction.
- `bash -n` on all six Slice B shell/test paths and `git diff --check`; PASS.
- Changed path: `docs/ship-flow/c14-fo-dispatch-contract.md` only. No frontmatter, Feedback Cycles, implementation, test, merge, ship, or GitHub issue mutation.
- Disposition: **READY** for fresh verify under the captain-approved final budget amendment.

### Summary

The cycle reconstructed Slice B from the authoritative frozen filesystem and proved the committed recovery is `+184/-186`, exactly 370 lines of churn. The verify VETO came from stale directional-budget wording; explicit drift review traced the variance only to higher-quality removal of obsolete body-parser code, found no unintended scope, and leaves the unchanged implementation READY for fresh verify.

## Stage Report: verify (cycle 3)

- DONE: Independently review feedback-cycle-1 resolution at exact HEAD `7c975b3` against the frozen Slice B baseline and the captain-approved drift controls.
  Evidence: the durable frozen-source record is `a14afb9` dirty filesystem manifest `2e0b41f3f328f991177bcc24a8cd29a8f510dc4f74ba8291c99d76142bbe6adf`; the ordered 10-path target manifest independently recomputes at HEAD to `156dd2f026a4a037749adae759ad2d541bba9a813a8cd18760399576888c2191`, identical to `930b4bb`, with the recorded exact `+184/-186` numstat. The approved controls `184 <= 210` additions and `184 + 186 = 370 <= 370` churn pass.
- DONE: Prove product/test bytes and frozen functional fingerprints are unchanged from the fully verified implementation without redundantly rerunning unchanged full suites.
  Evidence: `git diff --quiet 930b4bb -- <10 Slice B paths>` exits 0; `930b4bb..7c975b3` changes only this entity report. Focused test SHA-256 remains `cd457460a65ec4c6d2148c822084cff2adbed270c0eedeae67842953e29deacd`, and production SHA-256 remains `a2d15b8281995e9bad82a472030b18ba0b427a29194d41f1729603ceb6f64f10`. Therefore the fresh cycle-2 `105/105` shell and `79/79` Node evidence applies to identical product/test bytes; no full-suite rerun was warranted.
- DONE: Recheck lightweight syntax, invariant, scope, and drift evidence and issue an engineering-quality verdict without treating byte minimization as the product objective.
  Evidence: `bash -n` passes all six Slice B shell/test paths; `CI=true bash plugins/ship-flow/bin/check-invariants.sh` passes both C14 checks; deferred Cases 32-45/migration/merge anchors remain absent; `git diff --check` passes. Semantic diff review confirms the deletion variance removes the ownerless body-table parser/authorization branch and makes historical body tables opaque while retaining frontmatter-only derived rendering; no capability, file-scope, test, or maintainability drift is present.

### Acceptance evidence

- AC-1 PASS: exact commit `7c975b3` is `dispatch: c14-fo-dispatch-contract entering verify`, changes only the entity `execute -> verify`, and the live C14 invariant passes; the targeted C14 checker/test bytes are identical to the prior verified fingerprint.
- AC-2 PASS: the Slice B manifest pins unchanged manual-bypass, FO-lookalike, completion-impersonation, graph-edge, and Git-enumeration negatives; forbidden deferred Case/symbol anchors remain absent, so the prior fresh 37/37 evidence applies without scope expansion.
- AC-3 PASS: focused test and production hashes match exactly, preserving the prior fresh completion-helper, lifecycle, producer, lease/CAS, rollback, and status-idempotence evidence with no product/test-byte delta.
- AC-4 PASS: exact 10-path manifest, approved range controls, six-file syntax check, live invariant gate, forbidden-symbol audit, and diff check all pass. The already-fresh `105/105` shell and `79/79` Node results remain applicable because all product/test bytes are unchanged.

### Range, runtime, and disposition

- Frozen Slice B source/target: source manifest `2e0b41f3f328f991177bcc24a8cd29a8f510dc4f74ba8291c99d76142bbe6adf`; target/current manifest `156dd2f026a4a037749adae759ad2d541bba9a813a8cd18760399576888c2191`; exact directional total `+184/-186`, churn `370` across the recorded 10 owned paths.
- Drift judgment: additions remain below `210`; churn exactly meets `370`. The extra ten deletions over the stale maximum-360 interpretation remove obsolete body-derived authorization and mutation machinery. Restoring it would reduce enforceability and maintainability, so the variance is intentional quality-preserving removal rather than scope or capability drift.
- runtime_uat: not-applicable — this is a non-UI shell/Git contract; the real `7c975b3` transition, live invariant execution, unchanged disposable-fixture fingerprints, and prior fresh behavioral suites are the runtime evidence.
- Dispatch metadata degraded: the generated branch `spacedock-ensign/c14-fo-dispatch-contract` is stale; verification remained on authoritative `spacedock-ensign/c14-frontmatter-authority` without switching or renaming.
- Changed path: `docs/ship-flow/c14-fo-dispatch-contract.md` only. No implementation, test, frontmatter, Feedback Cycles, merge, ship, or GitHub mutation occurred.
- Verdict: **PASS** — feedback-cycle-1 resolves the cycle-2 VETO with durable directional proof and an approved drift-control amendment; engineering scope, maintainability, quality evidence, and value per changed line remain sound. This is not a merge or ship claim.

### Verification commands

Ordered 10-path `shasum -a 256` manifest reconstruction at HEAD and `930b4bb`; `git diff --quiet 930b4bb -- <10 Slice B paths>`; focused/production `shasum -a 256`; `bash -n` on the six Slice B shell/test paths; `CI=true bash plugins/ship-flow/bin/check-invariants.sh`; forbidden Case/symbol `rg`; approved-budget arithmetic assertions; `git diff --check`; exact branch/HEAD/status and commit-scope checks.

### Summary

Cycle 3 confirms the frozen Slice B recovery is the intended `+184/-186` change under the captain-approved additions/churn controls, with obsolete body-parser authority removed and no product/test drift after `930b4bb`. Exact fingerprints preserve the fresh full-suite evidence, lightweight live gates are green, and the verify verdict is PASS with no implementation or workflow-state mutation.

## Stage Report: ship

- DONE: Resolve the canonical entity before consuming ship evidence and apply the authorized legacy-flat adapter.
  Evidence: pinned Spacedock resolution selects `docs/ship-flow/c14-fo-dispatch-contract.md`; its latest inline `Stage Report: verify (cycle 3)` PASS is authoritative. The stale same-stem folder and its failed `verify.md` were explicitly ignored and left untouched.
- DONE: Confirm the exact live-main integration range and PR readiness without weakening the two transition contracts or importing deferred work.
  Evidence: focused C14 Cases 1-31, the local full invariant gate, contribution-contract rows, and diff checks pass; integration evidence records the full shell suite at 109/109 and Node at 79/79. PR-creation readiness verdict: **GO**; merge readiness remains blocked pending live CI.
- DONE: Materialize the approved pull request reference and release disposition without merging or terminalizing the entity.
  Evidence: PR [#47](https://github.com/iamcxa/spacedock-workflows/pull/47) tracks the exact branch; this backward-compatible workflow repair is a patch-release candidate with no version bump in this PR.

### Follow-up boundary

Native flat `ship-review` support and same-stem shadowing regression coverage are tracked in [issue #48](https://github.com/iamcxa/spacedock-workflows/issues/48) and remain nonblocking for C14.

### Live CI status

GitHub `doc_impact` passed. The invariants job failed only in `test-advance-stage.sh`, whose fixture set Git identity on the initial commit alone, so later `git commit --amend` calls failed on the identity-less CI runner (Cases 3, 7, 8). Fixed by setting repo-local `user.email`/`user.name` immediately after `git init`, matching the suite convention (`test-allocate-id.sh`), so every fixture commit is hermetic; verified by reproducing the identity-less runner locally (`GIT_CONFIG_GLOBAL=/dev/null` + `user.useConfigOnly=true`) — 103/103 cases pass. GitGuardian incident `34883744` flagged the disposable fixture literal `--token=foreign` (a false-positive non-matching lease token in a cooperative-lease negative test); it is now routed through `FOREIGN_LEASE_FIXTURE_TOKEN`, confirmed scanner-clean by `ggshield`. Because that literal still exists in the in-range commit `10ce627`, clearing the remote GitGuardian check requires resolving incident `34883744` on the dashboard as a false positive or rewriting that commit — a forward-only file fix may not clear a full-range PR scan.

### Summary

C14 is in ship with canonical flat evidence, verified transition safety, local readiness gates, and PR #47 recorded. It is not merge-ready while GitGuardian and remaining live CI are unresolved. The same-stem legacy folder remains byte-untouched and non-authoritative; merge, release, terminal advancement, and follow-up issue creation remain outside this report.
