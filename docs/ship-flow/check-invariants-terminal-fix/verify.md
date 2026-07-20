# check-invariants terminal misclassification fix — Verify

Independent re-run (not relay) of DC-18 + the dual-env gate + the AC-2
before/after diff, all foreground this session. Nothing silently fixed:
`git status`/`git diff --check` clean throughout; HEAD unchanged at `8036c32`.

## Independent Quality Gate Re-Run

- DC-18 fixture (4 cases), re-run fresh: 4/4 GREEN — DC-18a/b/c/d all `OK`
  (`plugins/ship-flow/lib/__tests__/test-check-invariants.sh:1321-1360`).
  Full `test-check-invariants.sh`: 66 OK / 0 FAIL, exit 0.
- Env 1 (no CI flag): shell suite 129 files — **128 pass, 1 fail**
  (`test-archived-corpus-invariants.sh`, diagnosed below). `node --test
  bin/*.test.mjs`: 79/79, exit 0. `check-version-triple.sh`: exit 0.
  `check-no-dangling.sh`: exit 0 (8 patterns).
- Env 2 (`CI=true`, per-test `timeout 90`, mirrors
  `.github/workflows/ship-flow-invariants.yml:98-121`): shell suite 129
  files — **127 pass, 2 exceptions**: `test-archived-corpus-invariants.sh`
  (exit 1, same cause) and `test-merged-pr-closeout-reconciler.sh` (exit 124
  — CI's 90s timeout kills it; solo/untimed Env-1 re-run above: **198/198
  pass**, confirming a machine-speed artifact of the local timeout mirror,
  not a regression — 0 references to the terminal predicate in that test).
  `node --test`: 79/79. `CI=true check-invariants.sh`: exit 1 — `FAIL C1`
  (roborev, the designed AC-2 outcome) + `FAIL C15` (pre-existing `plan.md`
  220-line cap breach, unrelated to this predicate).
- `git diff --check`: clean.

## Per-AC Evidence

- **AC-1 — VERIFIED.** `check-invariants.sh:61` reads
  `` grep -qE '^status:[[:space:]]*done[[:space:]]*$' "$f" `` — matches
  design/plan byte-for-byte. DC-18a/b/c (empty-`completed:`, `status: ship`,
  `verdict: PASSED`) all lose the terminal-SKIP line; DC-18d (`status: done`)
  keeps it (over-correction guard holds).
- **AC-2 — VERIFIED, independently re-derived** (not trusted from
  execute.md): reverted `check-invariants.sh` to `5f5ae69^` (fixture
  present, predicate still buggy), ran `CI=true check-invariants.sh`
  before/after, restored (`git status --short` empty after). Diff matches
  execute.md's table exactly: 25× orphan-header `ERROR` on
  `roborev-migration-receipt-merge-semantics` + 1× `FAIL C1` (missing
  `pre_mortem:`) + 2× `WARN` pitch-assumptions (roborev,
  7-review-surface-shape-not-plan) + exactly 5 new grandfather `WARN`s
  (shape-confirm-instance-awareness, 7-review-surface-shape-not-plan,
  check-invariants-terminal-fix, l3-scheduler-tick,
  reverse-recovery-audit-dangling-path — diffed the grandfather-WARN sets
  line-for-line). `:607`/`:842` add 0 lines either run. Exit measured
  **1 → 1** (not 0 → 1): this entity's own `plan.md` already trips `C15` at
  220 lines in both runs, identically — same root cause execute.md named,
  not new. No entity body was touched to produce this diff (only
  `check-invariants.sh` was patched-and-reverted, confirmed clean after).
- **AC-3 — VERIFIED.** See Quality Gate Re-Run above — both envs green
  modulo the two diagnosed, non-predicate exceptions.

## Review Findings

**Scope call (proportional, S-size).** `review-scope.sh` vs `6c36dd1`
(execute base): `DIFF_LINES=136`, all `SCOPE_*` flags false, `STACK=unknown`
(bash+docs repo) — the always-on specialists (testing/maintainability/
security) target app-code idioms not applicable here. Substituted: the
direct behavioral re-run above + a scoped cross-model pass. No Claude
subagent panel dispatched — `panel_coverage: minimal`.

**Cross-model (codex-cli 0.144.1, gpt-5.6-sol), scoped to the diff.** First
two attempts (20s/240s bound) timed out (exit 124) — codex's superpowers-
bootstrap self-directed into running the full test suite instead of a text
review, hitting spurious read-only-sandbox `mkdir` failures. Third attempt
("text-only, no bash") succeeded in 150s (exit 0) — NOT degraded:

| Finding | Codex | Disposition |
| --- | --- | --- |
| Predicate matches `status: done` anywhere in the file, not just frontmatter; first-match-wins on duplicate `status:` lines | FIX | Not a regression — identical to the old predicate's whole-file scan; already surfaced + accepted in design.md's Scoping Note. Re-checked empirically: only this entity's own `index.md` has 2 `status:` hits, and the 2nd is prose (`status:shape entity`, line 93) that doesn't match the exact pattern. 0 real risk today. route_to: none (informational). |
| Case-sensitive; quoted YAML (`status: "done"`) doesn't match | FIX | Matches taxonomy convention (every entity writes unquoted lowercase `done`); grep confirms 0 quoted/indented `status:` lines exist in the corpus. Not a bug. |

Both deferred to TODO below. 0 BLOCKING.

## Verdict

status: passed
stage_cost: 1 ensign session — dual-env gate re-run + AC-2 re-derivation +
  scoped cross-model challenge (3 codex attempts, 1 productive)
quality: DC-18 4/4 GREEN; suite 128-129/129 (Env1), 127-129/129 (Env2), both
  non-green exceptions diagnosed as pre-existing/environmental
review: 0 BLOCKING; 2 informational findings deferred
uat: not-applicable — bash CLI checker, no api/ui/e2e-type DC; dual-env gate
  re-run above is this entity's runtime verification
claim_records: required VERIFIED=3 NOT VERIFIED=0 INCONCLUSIVE=0; advisory
  VERIFIED=0 NOT VERIFIED=0 INCONCLUSIVE=0
blocking_issues: none
knowledge_capture: [D1] codex's bootstrap self-directs into full-repo
  exploration on a loose prompt — lead future calls with "no bash, text-only"
started_at: 2026-07-19T17:30:00Z
completed_at: 2026-07-19T18:20:00Z
duration_minutes: 50

Note for FO: `status: passed` needs Step 6.0's `fo-receipts.md` for C13 —
absent by design (FO-owned, out of stage scope); corpus already exits 1 for
AC-2/C15 reasons regardless.

## Panel Coverage

- Tier: minimal — proportional for an S-size, 1-line-predicate, bash-only
  diff (no `SCOPE_*` hits, no web/app stack). No multi-specialist Claude
  panel dispatched.
- Cross-model: codex-cli 0.144.1 / gpt-5.6-sol, scoped to the diff — YES,
  NOT degraded (3rd attempt succeeded; see Review Findings for the
  attempt-1/2 friction).
- Pass ownership: verify_agent_worker_ownership PASS; workflow_ci PASS;
  type_design NO_FINDINGS; silent_failure NO_FINDINGS; test_adequacy PASS;
  security NO_FINDINGS; cross_model_challenge PASS; runtime_uat
  not-applicable.
- PR Quality Score: 9/10 (0 critical, 2 informational × 0.5).

## Deferred to TODO

This round emitted 2 informational, non-blocking findings to
`ship-flow:add-todos`: (1) anchor `_entity_is_terminal` to frontmatter only
(whole-file scan today; 0 real hits across all 9 entities, but latent); (2)
guard against duplicate `status:` lines picking the wrong one (first-match-
wins today, identical to pre-fix behavior, not new). Escalated to captain
(CRITICAL+confidence≥8): 0.
