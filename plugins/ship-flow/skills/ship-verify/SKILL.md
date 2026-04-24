---
name: ship-verify
description: "Use when verifying execute output before ship — standalone via `/verify <entity-id>` or pipeline-dispatched by `/ship`. Agent-autonomous ROI gate: scoped quality checks on touched surfaces, spot-check critical DCs, auto-fix NITs inline, escalate to agent-browser e2e for UI DCs. Output: `docs/<wf>/<id>-<slug>/verify.md`."
user-invocable: true
argument-hint: "<entity-id> [--fast | --full]"
---

# Ship-Verify — VERIFY Stage (2.0)

You run VERIFY. Output: `docs/<wf>/<id>-<slug>/verify.md`. **You are NOT the author of the code** — review as an independent agent. PASS advances to review; FAIL feeds back to execute (max 2 rounds).

**Three concerns, one stage**: Quality (mechanical gate on touched surfaces) + Review (classified findings from dispatched haiku reviewers) + UAT (done-criteria evidence review + spot-check).

## When to use

- **Pipeline** (invoked by `/ship`) — dispatched via SendMessage to `verifier` teammate; cross-review gate mandatory; produces `verify.md`.
- **Standalone** `/verify <entity-id>` — user-invocable. Reuses `pitch-<id>` team if it exists; else creates fresh `verify-<pitch-id>` team with opus verifier.
- **Standalone** `/verify "<requirement>"` — treat as concrete-requirement entry; inverse-escape if vague (see `/ship` pattern).
- `--fast` — skip cross-review gate (captain manual fast-feedback). `--full` — force full re-run of every DC (skip spot-check heuristic).

**Inverse escape:** entity-id with no matching `docs/<wf>/<id>-*/` or `docs/<wf>/<id>-*.md` → announce `entity not found — run /shape <directive>` and EXIT.

---

## Step 1 — Resolve entity + team + TaskCreate

Resolve `WORKFLOW_DIR` from `docs/*/README.md` frontmatter `entry-point:`. Read entity file (flat `.md` or folder `README.md` + prior `.md` stages). Record stage-start ISO timestamp.

**Read** (tag-based via `bash plugins/ship-flow/lib/extract-section.sh <entity> <tag>`):
- `spec.md` (or entity `## Sharp Output`) → `### Done Criteria`, `### Size Assessment`
- `plan.md` → `### Plan` (`files_modified`), `### Verification Spec` (DC procedures)
- `execute.md` → `### Execution Log` (commit SHAs, base SHA), `### Issues Found`, `## Execute UAT`
- `PRODUCT.md` → `## Constraints` (if exists)

Capture **execute base SHA** from first task's parent commit in `execute.md`. Do NOT recompute from `main..HEAD` (MEMORY #25 — parallel-session churn produces reverse-subtraction artifacts).

**Pre-check**: if > 50% of execute tasks failed → write `verify.md` with `status: blocked`, notify captain, EXIT. Never exit without the artifact.

**Team** (Principle 6 Rule A):
- Pipeline invocation → already inside `verifier` teammate context. Inherit parent `/ship` umbrella tasks (no new TaskCreate).
- Standalone — team `pitch-<id>` exists → SendMessage to `verifier`. No team exists → `TeamCreate(team_name: "verify-<pitch-id>", members: ["verifier"])` + spawn opus verifier.
- Standalone — TaskCreate 3 sub-tasks: `scoped-gate` → `spot-check-uat` → `escalation-or-nits`.

---

## Step 2 — Quality gate (scoped, ROI-default)

**Rule**: run quality checks ONLY on runtime surfaces execute wrote commits to. Full-project checks on untouched surfaces are baseline noise (MEMORY #10 generalized). Invoke `ship-flow:ship-runtime-detect` to populate `{commands.test/build/typecheck/lint}`.

**Per-surface commit count**:
```bash
for SURFACE in $SURFACES; do
  N=$(git log {execute_base}..HEAD --oneline -- "$SURFACE" 2>/dev/null | wc -l)
  # N == 0 → scoped PASS (documented baseline), skip
  # N > 0  → run full checks on that surface
done
```

Run checks 1-4 (tests / lint / typecheck / build) on surfaces with `N > 0`. Check 5 (format) advisory only. Capture last 40 lines per check as evidence.

**Any check FAIL → feedback to execute.** Do NOT proceed to review. Max 2 feedback rounds, then PROMPT_CAPTAIN.

### Step 2.1 — Per-error diff-aware attribution (ROI critical)

**Trigger**: any check output contains `file:line` references.

Surface-level scoping says "execute didn't touch surface X → failures are pre-existing". Necessary but not sufficient — a touched surface can mix execute-introduced + pre-existing errors. Attribute **per error**:

1. Parse `file:line`. Run `git diff --name-only {execute_base}..HEAD -- <file>`; empty → pre-existing on this file.
2. File touched → `git blame -L<line>,<line> --show-name HEAD -- <file>`; extract SHA.
3. SHA ∈ `{execute_base}..HEAD`? **Yes** → execute-introduced (real failure: auto-fix per Step 5 or feedback-to-execute). **No** → pre-existing line; note but don't block.

**Forbidden rationalization**: "pattern existed elsewhere before" does NOT justify skip. Attribution is per-file, per-line. Precedent: entity #078 — 2 Principle 5a ERRORs blame-attributed to execute's report commit, mis-classified as "pre-existing pattern", CI failed on PR.

**Record in `### Quality Gate`**: which surfaces were scoped + each pre-existing error suffixed `(pre-existing baseline)`.

---

## Step 3 — Review (haiku reviewer matrix + spot-check)

**Reviewer matrix (Principle 3)**: default 2 haiku for source-file diffs; skip entirely for non-source-only diffs.

```bash
DIFF_FILES=$(git diff {execute_base}..HEAD --name-only)
SOURCE_FILES=$(echo "$DIFF_FILES" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|rb|go|rs|java|kt|swift|c|cc|cpp|h|hpp|cs|php|ex|exs|sh)$')
```

| Diff content | Haiku dispatches | Notes |
|---|---|---|
| Non-source only (docs / SKILL.md / config) | **0** — sonnet inline review on diff | 2026-04 D1: haiku hallucinate 50-100% on prompt-text diffs |
| S/M/L with source | `pr-review-toolkit:code-reviewer` + `pr-review-toolkit:silent-failure-hunter` | Default pair |
| Opt-in via `haiku-opt-in: <name>` | `trailofbits:{insecure-defaults \| sharp-edges \| variant-analysis}`, `pr-review-toolkit:{pr-test-analyzer \| type-design-analyzer \| comment-analyzer \| code-simplifier}` | Explicit tag only |

Cost: ~$0.05/haiku. Default M/L = $0.10.

**Inline pre-scan (always, before haiku findings arrive)**:
1. **Stale references** — for every symbol removed, grep remaining refs outside the diff.
2. **Plan consistency** — cross-check `git diff --stat` vs `plan.md → files_modified`. Unplanned change OR missed task = finding.
3. **Constraint check** — `PRODUCT.md → ## Constraints` respected?
4. **CLAUDE.md walk** — for each changed file, walk dirname to repo root collecting `CLAUDE.md`; check each rule against the diff. Severity: "must/never/always" → BLOCKING; "prefer/should/consider" → WARNING. Dedup + cache during walk.

**Spot-check haiku citations — 100%, not a sample** (MEMORY #078 precedent):
- Read exact file at cited line ±2 lines.
- Content matches → keep. Line shifted but content within ±5 → keep with updated line. Content absent → DROP + log `[D2-candidate] {agent} hallucinated at {file}:{line}` in `### Knowledge Captures`.
- Single agent > 30% hallucination → discard ALL findings from that agent for this review; log as untrusted for this diff class.

**Classify surviving findings**:
- **BLOCKING** (security / broken / data-loss) → feedback to execute (max 2 rounds).
- **WARNING** (potential bug / weak edge case) → log; proceed if no BLOCKING.
- **NIT** (style / minor) → consider auto-fix per Step 5.

---

## Step 4 — UAT (spot-check default, full re-run fallback)

**Default: spot-check ≤2 critical DCs + evidence review.** Full re-run is fallback, not default. Evidence: 2026-04 D1 n=31 DCs changed 0 verdicts on full re-run.

### 4.1 — Evidence review

Read `execute.md → ## Execute UAT` (or `## Execute Output → ### Done Criteria Verification` for legacy). Each row must have:
- Procedure from `plan.md → ### Verification Spec`
- Concrete evidence (command output excerpt / file:line citation / screenshot path) — not just "✅"

**Degrade to 4.3 full re-run if**: evidence missing, only "ok"/"pass"/"✅", procedure differs from Verification Spec, OR ≥1 DC marked FAIL/degraded without explanation.

### 4.2 — Spot-check

Pick 2 DCs: (1) **highest-risk** (priority `e2e > api > ui > cli > skill`; break ties by assertion complexity), (2) **random** from remaining. Re-run per type:

| Type | Primitive |
|---|---|
| `cli` | Bash: command + exit code + output grep |
| `api` | Bash: curl + status + response shape |
| `ui` | Bash: `curl -sfN <route> \| grep <assertion>` (MEMORY turbopack-streaming — `-N` mandatory for Next.js 16). Flow exists → `Skill: e2e-pipeline:e2e-test` |
| `skill` | `Skill("<skill-name>")` with probe prompt, check output shape |
| `e2e` | `Skill: e2e-pipeline:e2e-test` if flow present; else degrade to `ui` + warn |

| Spot-check outcome | Action |
|---|---|
| Both DCs match execute | Trust remaining DCs based on evidence; advance |
| 1 mismatch | Re-run the mismatched DC's neighbors (same type or code area); neighbor mismatch → 4.3 |
| Both mismatch | 4.3 — evidence unreliable |

### 4.3 — Fallback: full re-run

Re-run every DC procedure via 4.2 type-dispatch table. Each result: infra-fail (feedback automated) or assertion-fail (specific evidence logged).

### 4.4 — Captain-smoke pre-automation (UI-type DCs)

Run automated pre-check BEFORE handing to captain for manual visual smoke. Captain's eyeball is the final pass, NOT the first line of defence — automated pre-check catches regressions before captain context switch.

**Primitive triage** (dispatch per DC to the narrowest that fits):

| Primitive | When | Input |
|---|---|---|
| `e2e-pipeline:ui-verify` | Static CSS / tokens / computed-style regression — fixed selectors × expected values | `.claude/e2e/ui-verify/<slug>.yaml` |
| `e2e-pipeline:e2e-test` | Dynamic behavior / DOM assertion / navigation / step-based flow | `.claude/e2e/flows/<slug>.yaml` |
| `e2e-pipeline:e2e-walkthrough` | No declarative artifact; exploratory screenshot + optional video of affected pages | affected route list |
| `agent-browser` CLI (break-glass) | skill wrapper unavailable / mapping missing / skill invocation errors | inline JS via `eval` on live dev server |

**Fallback cascade**: declarative skill → agent-browser CLI → manual captain smoke. At least one tier MUST run on every UI-type DC. `visual verification skipped` log is only acceptable when BOTH (a) entity has zero UI-type DCs AND (b) spec.md explicitly flags captain-smoke not required.

**Artifact requirement**: every automated pre-check MUST produce either (a) a report at `.claude/e2e/reports/<slug>-<stage>-<timestamp>.md` OR (b) an inline report block in `verify.md` `### UAT → visual:` subsection. Include ≥1 screenshot (agent-browser `screenshot <path>` command or skill's own capture) for the primary affected route — audit trail for future session-resume + captain review.

If `## Design Reference` present → compare screenshots against reference images. No reference → verify DC assertions against rendered UI.

Record verdicts under `### UAT → visual:` subsection, including which primitive ran + report path + screenshot path + per-DC pass/fail.

---

## Step 5 — Auto-fix NITs inline (before verdict)

**Apply only when ALL criteria met** (never BLOCKING / WARNING):
- Severity ≤ NIT AND
- Scope ∈ {comment, docstring, header inventory} — no logic, type, behavior change AND
- Single file, ≤ 5 LOC net AND
- Mechanical (no judgment between alternatives)

For each eligible finding: Edit fix → re-run affected quality check → commit with explicit path (`git add <path> && git commit -m "fix(<component>): <summary> (verify NIT-<N>)" -- <path>`).

**Also auto-codify** knowledge captures that match inline-to-skill (captain principle: MEMORY last resort — check if lesson can be inlined into workflow first):

| Capture pattern | Action |
|---|---|
| Lesson applies to specific skill stage at specific step | Inline-edit the skill file (add gate / check). Record commit SHA in capture; downgrade `[D2-candidate]` → `[inlined]`. |
| Lesson is cross-skill / cross-project / behavioral | Leave as `[D2-candidate]` for ship-review → CLAUDE.md candidacy. |
| Entity-specific one-off | Leave as `[D1]`. |

**Anti-pattern**: do NOT auto-fix findings that touch logic, do NOT rewrite core skill procedures (only add gates / strengthen existing rules).

Record fixes in `### Verdict → auto_fixes:` with `{finding-id, commit-sha, before/after summary}`.

---

## Step 6 — Write `verify.md` + cross-review gate

**Atomic write** via Layer C writer — Wave 5 primitive landed at commit `acd73545`; invoke via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=verify --entity=<id>-<slug>`. Writer handles atomic commit with explicit pathspec. No `-a`/`-A` (MEMORY #14/#25/#37).

**Section tagging (mandatory)** — every H2/H3 wrapped in paired `<!-- section:tag -->` ... `<!-- /section:tag -->`. Tag list + field semantics: `plugins/ship-flow/references/entity-body-schema.yaml → stages.verify`. Required subsections:
- `### Quality Gate` — per-surface scoping decisions + check results + pre-existing attributions
- `### Review Findings` — pre-scan + classified haiku table (file:line, severity, source, description)
- `### Knowledge Captures` — `[D1]` / `[D2-candidate]` / `[inlined]` tags
- `### UAT` — mode line + results table with `Verify` column (`spot-checked` / `trust (evidence: <ref>)` / `re-run (fallback)`)
- `### Verdict` — `status:` (grep gate — `passed` | `failed` | `blocked`), `stage_cost:`, `auto_fixes:`, `started_at:` / `completed_at:` / `duration_minutes:`

FO greps `^status:` for the machine-readable gate. `Verdict:` line is human-facing summary.

### Cross-review gate (Principle 6 Rule C) — skipped on `--fast`

Dispatch cross-review to counterpart teammate (`planner` if `verifier` just wrote) after `verify.md` lands. Reviewer model fallback when no team: fresh **sonnet** default; upgrade to fresh **opus** when entity's `appetite: big-batch`.

5-factor rubric adapted for verify:

| Factor | Verify interpretation |
|---|---|
| **Feasibility** | gate scope correct for diff domain (source vs non-source, scoped vs full)? |
| **Executable scope** | verdict supported by evidence, not claim? |
| **Quality** | ≥1 critical assumption verified? pre-scan ran? |
| **DC adequacy** | scoped-gate spot-checks critical DCs? |
| **Canonical sync** | canonical docs consistent post-execute (architecture-impact blocks applied)? |

Verdict: **PROCEED** → TaskUpdate verify=completed, FO advances. **VETO** → feedback-to-execute (max 2 rounds per stage; round 3 → PROMPT_CAPTAIN). **PROMPT_CAPTAIN** → halt, present `verify.md` + reviewer concern.

**Circuit breaker**: if `SendMessage(planner)` is unresponsive (phantom team / timeout / fresh-Agent stall), fall back per INVARIANTS Rule A Fallback — fresh sonnet by default, fresh opus on `big-batch`. Do not block on an unresponsive reviewer.

`--fast` captain mode skips this gate; captain takes responsibility for the bypass.

---

## Invariants + red flags (STOP or escalate if violated)

- Quality gate is scoped to touched surfaces (MEMORY #10); full-project noise ≠ failure.
- Per-error attribution: pattern-in-other-files does NOT excuse execute-introduced line (MEMORY #078).
- Haiku spot-check = 100% of citations, not sample (MEMORY #078 precedent).
- Default haiku pair for source-files; ZERO haiku for non-source-only diffs (Principle 3).
- UAT spot-check default; full re-run is fallback, not default.
- Auto-fix NEVER on BLOCKING/WARNING; never on logic; ≤5 LOC mechanical only.
- `verify.md` must exist with `### Verdict → status:` before exit — even on blocked pre-check.
- Pipeline invocation inherits `/ship` team; standalone may CreateTeam. Fresh-subagent only for Rule A exceptions.
- Cross-review mandatory except `--fast`; VETO feedback capped at 2 rounds per stage.
- Explicit pathspec on every commit (MEMORY #14/#25/#37). No `-a`/`-A`.
- Parallel-session diff: scope review to `files_modified` when `git log <execute_base>..HEAD --oneline | grep -v <this-slug>` non-empty.
- Feedback-to-execute capped at 2 rounds per gate (quality / review-BLOCKING / UAT); round 3 → PROMPT_CAPTAIN. Infra-fail (missing binary / server down) auto-routes; assertion-fail requires specific evidence.

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml → stages.verify`.
- Per-stage writer: `plugins/ship-flow/lib/write-stage-artifact.sh --stage=verify` (landed commit `acd73545`).
- Section/map helpers: `plugins/ship-flow/lib/extract-section.sh`, `extract-map.sh`, `patch-map.sh`.
- Runtime detect: `ship-flow:ship-runtime-detect`.
- Layer A — haiku reviewers: `pr-review-toolkit:code-reviewer`, `pr-review-toolkit:silent-failure-hunter`, `trailofbits:*`, `pr-review-toolkit:{pr-test-analyzer,type-design-analyzer,comment-analyzer,code-simplifier}`.
- Layer A — agent-browser: `e2e-pipeline:e2e-test`, `e2e-pipeline:e2e-walkthrough`, `e2e-pipeline:ui-verify`.
- Layer A — inline review: `superpowers:verification-before-completion` (compatible mental model).
- Upstream: `ship-flow:ship-shape` (team spawn), `ship-flow:ship` (pipeline entry).
- Downstream: `ship-flow:ship-review` (reads `verify.md → status:`).
- Principle 6: `plugins/ship-flow/INVARIANTS.md` (Rule A continuity + Rule B 3-layer + Rule C cross-review).
- MEMORY: #5 (--next-id), #10 (scoped-gate), #14/#25/#37 (pathspec / staging), #30 (verification-dispatch), #35 (dispatch discipline, amended by Principle 6 Rule A), #078 (per-error attribution + 100% spot-check), opus-4.7-naturally-does (2026-04-23 harness diet), nextjs-16-streaming-curl-flag (turbopack `-N` requirement).
