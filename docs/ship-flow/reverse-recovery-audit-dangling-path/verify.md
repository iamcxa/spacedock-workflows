# Fix dangling reverse-recovery-audit adopter-local mod reference + regress-guard — Verify

Entity was dispatched autonomously by the L3 scheduler tick (delegation
receipt `.worktrees/ship-flow-scheduler-controller/.ship-flow-scheduler-receipts/20260719T111714Z-14688-reverse-recovery-audit-dangling-path.txt`,
content: "Execution error") and timed out between execute and verify. This
session resumes verify fresh — the worktree's execute-stage commits were
intact; nothing below is relayed from execute.md without independent re-proof.

## Independent Quality Gate Re-Run

Fresh in this worktree, from repo root, matching CI invocation exactly: 120/120
shell test files PASS; **node 79/79 PASS** (corrects execute.md's "no node
tests: none" claim — `node --test plugins/ship-flow/bin/*.test.mjs` is real
and wired at `ship-flow-invariants.yml:128`; all pass, zero regression);
`check-no-dangling.sh` real run PASS (8 patterns, exit 0) and `--self-test`
PASS; `check-version-triple.sh` PASS; `check-invariants.sh` PASS (0 FAILs,
pre-verify.md baseline); `shellcheck` clean on both touched shell files;
`git diff --check` (fec9b32..HEAD) clean.

<details>
<summary>Raw command exit codes</summary>

check-no-dangling.sh=0, --self-test=0, check-version-triple.sh=0,
check-invariants.sh=0 (pre-verify.md), 120-file shell suite=120/120,
`node --test *.test.mjs`=79/79, shellcheck×2=0/0, git diff --check=clean.

</details>

## Per-AC Evidence

- **AC-1 — VERIFIED.** `grep -n reverse-recovery-audit.md` on both SKILL
  files: both lead with the plugin-canonical path and contain `when present`.
  Stronger proof: reconstructed the exact pre-fix line text from git
  (`055a7d9^`) into a scratch tree and confirmed the resolver flags it RED —
  the real historical bug, not a synthetic stand-in.
- **AC-2 — VERIFIED.** Fixture suite re-run fresh: 10/10 PASS (case 1
  RED-unqualified exit 1; cases 2-9 GREEN exit 0, incl. case 9 against the
  real `REPO_ROOT`). Beyond relay: (a) built an independent fixture with a
  mod name never used in the ticket's own test file — RED before an adopter
  file exists, GREEN after — rules out name hardcoding; (b) ran the resolver
  directly against the reconstructed original pre-fix SKILL text (see AC-1) —
  RED; (c) ran the resolver against the real fixed repo directly (not just via
  the wrapping script) — 0 violations.
- **AC-3 — VERIFIED.** 120/120 shell + 79/79 node, zero regressions.

## Review Findings

<details>
<summary>Proportionality call + Codex cross-model degraded-attempt narrative (raw evidence; collapsed per Principle 8 / C15)</summary>

**Proportionality call (declared, not silent):** `review-scope.sh` measures
`DIFF_LINES=503` (fec9b32..HEAD) — over the SKILL's `<50` short-circuit — but
`SCOPE_AUTH/BACKEND/FRONTEND/API/MIGRATIONS` are all `false` (pure bash CLI +
doc + test-fixture diff). Given the S/mechanical classification carried from
shape/design/plan and testing-dimension coverage already exceeding typical
specialist depth (fixture suite + real-repo run + git-history bug
reconstruction, all above), the verifier scoped review to a cross-model
attempt + one adversarial pass instead of the full 5-specialist panel. FO/
captain may request the full panel.

**Codex cross-model — degraded (Fallback Ladder Tier B applied).** Codex is
Tier-A by literal detection (`codex exec "echo test" -s read-only` → exit 0).
Two scoped attempts against the actual diff (a broad prompt, then a stricter
"do not explore, analyze only the pasted diff" variant, `--skip-git-repo-check`,
isolated scratch `--cd`) both hit the 180-280s budget without concluding —
trace showed the model grepping unrelated repo fixtures despite instructions
not to. A trivial ping prompt in the same environment returned in <60s,
ruling out pure auth/connectivity failure; the symptom is
task-engagement/exploration behavior. Per the circuit-breaker rule (2
consecutive same-symptom failures → stop, switch strategy), retries stopped;
tagged `cross_model: false`.

</details>

**Claude adversarial (fallback, sonnet, fresh context, scoped to the 4 changed
files only)** — findings, verifier disposition in the last column:

| # | Finding | Sev | Disposition |
|---|---|---|---|
| W1 | Bare `override` qualifier term suppresses a real violation whenever that word appears anywhere in the same logical unit, unrelated to the reference | P2 | WARNING — reproduced independently (single-line fixture, no boundary bug needed) |
| W2 | Upward logical-unit scan doesn't stop when the match line is itself a self-contained list item; unrelated lead-in prose above it can be absorbed | P2 | WARNING — reproduced independently (2-line fixture) |
| W3 | Qualifier allowlist too narrow for plausible legit phrasing ("if present", "falls back to") → future false-positive risk | P3 | advisory, follow-up |
| W4 | `check-no-dangling.sh:300` `grep -c` lacks `\|\| true`; unreachable today (format is internally guaranteed) but fragile if it drifts | P3 | advisory, follow-up |
| W5 | Fixture cases 6/7 give weaker regression coverage than their names imply | P3 | advisory, follow-up |

<details>
<summary>Severity rationale + incidental out-of-scope finding detail (raw evidence; collapsed per Principle 8 / C15)</summary>

Severity rationale: W1/W2 are gaps in the guard's robustness against
*future, hypothetical* content, not defects in the shipped detection of the
*actual* historically-dangling class — which this session independently
proved caught (AC-1/AC-2 git-history reconstruction, above). No AC regresses.
Recommendation from the adversarial pass: PROCEED.

**Incidental, out-of-scope finding (pre-existing, unrelated to this diff,
verified present at `fec9b32^`):** `check-invariants.sh`'s
`_entity_is_terminal()` (Principle 5a, line 61) matches the bare frontmatter
key `completed:` regardless of value, so any entity with an *empty*
`completed:` field — the normal state of every in-flight entity, including
this one — is misclassified "terminal historical" and silently skipped from
section-tag enforcement repo-wide. Not this ticket's scope to fix.

</details>

## Runtime UAT

`runtime_uat: not-applicable — no UI/API/e2e surface; this is a CLI gate
script (bash) + two SKILL.md doc lines. The runtime proof for this class of
change is direct script execution against real files — the Independent
Quality Gate Re-Run and Per-AC Evidence above (real `check-no-dangling.sh`
run, real resolver run against `REPO_ROOT`, git-history-reconstructed
original-bug-text RED proof) — not a separate UAT pass.`

## Verdict

**PASS (PROCEED).** AC-1/AC-2/AC-3 independently verified with evidence
exceeding relay: real pre-fix text reconstructed from git and proven RED,
an independent differently-named synthetic fixture proving no hardcoding,
full 120/120 shell + 79/79 node re-run, gate scripts, shellcheck, and
`git diff --check` all fresh and clean. Two WARNING guard-robustness gaps
found via scoped adversarial review (W1/W2), non-blocking — they do not
regress any AC — deferred to TODO. Proportionality call on panel scope
declared visibly (not silent); codex cross-model degraded after 2 attempts
(circuit-breaker stop), Claude-adversarial fallback applied per Fallback
Ladder Tier B.

## Panel Coverage

`panel_coverage: minimal` — `cross_model: false` (Codex Tier-A-available-but-
non-convergent after 2 scoped attempts within budget, tagged DEGRADED;
Fallback Ladder Tier B applied: one scoped Claude adversarial subagent,
sonnet, fresh context, restricted to the 4 changed files, findings above).
Full 5-specialist panel (testing/maintainability/security/performance/
api-contract) NOT dispatched: `DIFF_LINES=503` exceeds the SKILL's default
`<50` trigger, but zero `SCOPE_*` flags fired (pure bash CLI + doc + test
diff) and the S/mechanical classification was already carried from shape/
design/plan; the testing dimension already exceeds typical specialist depth
via this session's own real-fixture + git-history-reconstruction proof.
Declared visibly per dispatch checklist item 3, not silent.

## Deferred to TODO

- W1 (WARNING): bare `override` qualifier term is over-broad — scope the
  match to the listed phrases only, or require same-sentence proximity.
- W2 (WARNING): upward logical-unit scan should also stop when the match
  line is itself a self-contained list-item start.
- W3 (advisory): broaden qualifier allowlist for plausible legit phrasings
  ("if present", "falls back to", "defaults to the plugin copy").
- W4 (advisory): add `|| true` to the `grep -c` at
  `check-no-dangling.sh:300` for robustness against format drift.
- W5 (advisory): strengthen fixture cases 6/7 in
  `test-check-no-dangling.sh` so their names match what they exercise.
- Incidental, pre-existing, out-of-scope: `check-invariants.sh`
  `_entity_is_terminal()` misclassifies any entity with an empty
  `completed:` field as terminal, repo-wide — separate ticket.
- Carried from shape.md: architecture-canon / canonical-doc-sync
  missing-everywhere mods, broader doc audit, sync-manifest redesign.
