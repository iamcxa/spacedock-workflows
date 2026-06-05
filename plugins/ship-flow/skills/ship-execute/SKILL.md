---
name: ship-execute
description: "Use when ship-flow needs execute-stage implementation from an approved plan, including wave tasks, blocked work, or PR feedback re-entry. Layer A delegation: superpowers:subagent-driven-development owns wave dispatch discipline."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# Ship-Execute — EXECUTE Stage (2.0)

You run EXECUTE. Output: `<entity-folder>/execute.md`. Dispatched by `/ship` to `executer` teammate via SendMessage. No captain gate.

**Pipeline position**: reads `plan.md` → wave-by-wave dispatch + review → commits → produces `execute.md` → cross-review gate → advance to verify.

## Boot Self-Check

Run before any execute work. Stop and SendMessage(FO) if any check fails.

1. **Entity status**: read entity frontmatter `status:` — must be `plan`. If `sharp` → plan not done; if `execute` → re-entry (check for `pr_feedback_round` Mode B signal).
2. **plan.md present**: `<entity-folder>/plan.md` exists and has `## Plan` section with tasks. If absent → SendMessage(FO): "plan.md missing for `<entity>` — cannot execute without task list."
3. **Hand-off to Execute present**: entity body contains `### Hand-off to Execute` block. If absent → SendMessage(FO): "Missing Hand-off to Execute — planner did not complete handoff."
4. **Branch check**: confirm current branch matches entity worktree (if worktree pattern). Abort if on main without `--inline-on-main` flag.
5. **Clean working tree**: `git status --porcelain` returns empty. If dirty → surface to FO before first wave dispatch.
6. **Density-aware skill load** (T3.4): read `answers_density` from entity frontmatter. `high` → auto-load framework skills per ship-runtime-detect Step R6; skip FO ask. `low|vacuum` → SendMessage(FO) with proposed skill list; wait for confirmation.

## Entity body contract (schema-as-prose)

- Reads: `plan.md` (`## Plan`, per-task `skills_needed`, `## Verification Spec`), sharp `## Done Criteria`, `## PR Review Feedback` (if Mode B).
- Writes: `<entity-folder>/execute.md` sections — `## Execution Log` (per-task table: status / wave / model / files / verification), `## Issues Found`, `## Knowledge Captures` (D1/D2), `## Execute UAT` (first-pass AC verification, not authoritative), `## Execute Report` (status / stage_cost / tasks summary).
- Full section-tag + field semantics: `plugins/ship-flow/references/entity-body-schema.yaml → stages.execute`.

## Layer A delegation (Principle 6 Rule B)

`superpowers:subagent-driven-development` owns dispatch philosophy (one task = one subagent, status protocol DONE/NEEDS_CONTEXT/BLOCKED, review loop). **Do NOT re-teach.** Ship-execute wraps with Layer B augmentation:

**Rule A Fallback reminder**: when `SendMessage(executer)` is unavailable (phantom team / no response) or a dispatched fresh Agent stalls on stream watchdog, fall back per INVARIANTS Principle 6 Rule A Fallback — fresh `Agent(subagent_type: general-purpose)` with captured task + architecture context in the prompt. Stall-recovery: check `git log -- <task-files>` before redoing (subagent may have committed before stalling). Inline execution is the last resort for small-batch scope.


- Wave graph traversal (strict wave-sequential; parallelism within wave when no `files_modified` overlap).
- Tiered quality check (T1 build/typecheck/test; T2 frontend smoke via curl).
- BLOCKED escalation ladder (haiku → sonnet → opus; never same-tier retry).
- Benign-drift pre-check (anchor-drift / file-renamed / semantic-grep-mismatch auto-resolve before escalation).
- Serial commits per wave with pathspec-lock (parallel-session contamination defense).
- PR-feedback re-entry mode (Mode B).
- Architecture snippet injection into troop prompts.
- Folder guidance receipt enforcement for non-root app-folder `AGENTS.md`/`CLAUDE.md` and project skills resolved from touched files.

---

## Flow

**Phases (TaskCreate sub-tasks — inherit from /ship umbrella when pipeline-dispatched):**
`mode-detect` → `read-plan` → `wave-graph` → `arch-snippet` → `wave-execute` (per wave: `dispatch → review → commit`) → `ac-verify` → `cross-review` → `emit-execute.md`

### Step 0 — Mode detection

Check entity frontmatter `pr_feedback_round`:

- `> 0` AND `pr:` set AND no current `## PR Review Feedback` section → **Mode B** (PR-feedback re-entry). See Step 0B.
- Otherwise → **Mode A** (normal execute). Proceed to Step 1.

### Step 0B — Mode B flow (PR-feedback re-entry)

Fetch PR reviews via VCS CLI (`gh pr view --json reviews,comments` for GitHub; `glab mr view` for GitLab). Classify each comment as BLOCKING (architecture / correctness) / NITS (style / naming) / OBSERVATIONS.

- All NITS → log + close PR comment, no rollback (nits go in separate entity).
- BLOCKING target = execute → write `## Execute Guidance` section (tagged `<!-- section:execute-guidance -->`) with flagged-items list; run `bash plugins/ship-flow/bin/pr-feedback-rollback.sh <entity-file> execute <pr#> <round>`.
- BLOCKING target = plan (architecture concern) → write `## Plan Guidance` section; rollback target=plan.

Exit after rollback. FO re-dispatches ship-execute (or ship-plan) on next status cycle.

**Circuit breakers**: `pr_feedback_round > 3` → escalate captain. PR already merged → refuse rollback. Do NOT force-push / rebase (add fixup commits).

### Step 1 — Read plan + build wave graph

Record stage-start ISO. Extract via `bash plugins/ship-flow/lib/extract-section.sh <entity-file> plan`. Parse tasks: files, steps, verify commands, model hints, wave assignments.

Parse `skills_needed` from each task block. Accepted forms:
- `**Skills needed:** {skills_needed: ["test", "tdd"]}`
- `skills_needed: ["test", "tdd"]`
- `skills_needed: []` only for docs-only/stage-artifact tasks with explicit `TDD: skip -- <reason>`.

TDD exemptions must use the canonical grep-friendly marker `TDD: skip -- <reason>`. Valid exemption classes are docs-only/stage-artifact tasks, pure configuration, migrations validated by existing migration tooling, and pure refactors with existing coverage. Any other task is non-exempt unless plan explicitly records a captain-approved reason.

Parse each task's `tdd_contract` from structured YAML or prose fields:
- `red_command` / `RED command`
- `expected_red_failure` / `Expected RED failure`
- `green_command` / `GREEN command`
- `refactor_check` / `REFACTOR check`

Before dispatching implementation work, consume the plan-time `tdd-ledger.jsonl` from `### Hand-off to Execute`. Re-run `python3 plugins/ship-flow/lib/validate-tdd-ledger.py --plan <entity-folder>/plan.md --require-ledger-jsonl <entity-folder>/tdd-ledger.jsonl` in the execute worktree and treat any missing, stale, or failing ledger as a bounce to plan. Do not rely on prose-only TDD inference when the ledger is missing on a new non-trivial entity; for legacy plans, proceed serially only with an explicit WARNING and generate the ledger with `--emit-jsonl` as best-effort evidence.

For every task without a valid `TDD: skip -- <reason>` exemption, enforce RED-before-GREEN before implementation: run the RED command before production edits, confirm the expected RED failure, then implement the minimal change, run the GREEN command, and only refactor after GREEN while re-running the refactor check. Record command text, exit/pass/fail snippets, and whether the RED failure matched expectation in `execute.md`. If the task lacks `tdd_contract` on a new non-trivial entity, bounce to plan; for a legacy plan, proceed only with a WARNING and a focused test command you can justify.

If `skills_needed` is missing on a legacy plan, fallback to the existing density-aware skill load / default stage skill set and log `skills_needed missing — fallback to density/default skill load` in `## Issues Found`. Do not block legacy plans solely for absence.

For every task with non-empty touched files, re-run adopter routing before dispatch:

```bash
bash plugins/ship-flow/lib/resolve-skill-routing.sh \
  --config=.claude/ship-flow/skill-routing.yaml \
  --files=<task-files>
```

Merge `skills_needed=` and `folder_guidance_skills=` into the task's skill list for dispatch, preserving the plan list first. Record `folder_guidance_files=`, `folder_guidance_skills=`, and the resolver's `codex_context_boundary` in `## Issues Found` or the task row when they add context not already visible in plan. Missing `.claude/ship-flow/skill-routing.yaml` on a legacy plan is a WARNING; for new non-trivial adopter plans, bounce to plan because planner should have emitted `Folder guidance`.

Group by wave (0, 1, 2, ...). Wave dependency sanity: for each task in wave N, every `read_first` path either exists in worktree OR is in `files_modified` of a task in wave <N. Violation → `## Execution Log status: blocked, reason: wave dependency violation` and return. **Never silently reorder waves** — plan stage owns topology.

**Blocker**: plan missing or malformed → `status: blocked` and return.

### Step 1.5 — Architecture snippet (ARCH_SNIPPET for troop context)

```bash
ARCH_SNIPPET="$(bash plugins/ship-flow/lib/extract-map.sh ARCHITECTURE.md constraints 2>/dev/null || true)"
TARGET=$(bash plugins/ship-flow/lib/extract-section.sh "$ENTITY_FILE" architecture-impact 2>/dev/null | awk '/^target_section:/ {print $2; exit}')
if [ -n "$TARGET" ] && [ "$TARGET" != "constraints" ]; then
  ARCH_SNIPPET="${ARCH_SNIPPET}"$'\n\n'"$(bash plugins/ship-flow/lib/extract-map.sh ARCHITECTURE.md \"$TARGET\" 2>/dev/null || true)"
fi
```

Inject `$ARCH_SNIPPET` into every troop prompt under `### Architecture context` block. Skip block if ARCHITECTURE.md absent (`ARCH_SNIPPET=""`). FO uses it for its own context in inline mode too.

### Step 2 — Execute wave-by-wave (delegate dispatch to Layer A)

Invoke `Skill: superpowers:subagent-driven-development` for dispatch philosophy. It owns: task = subagent, status protocol, review loop structure. **Do NOT re-teach.**

**Layer B wrap** (ship-execute owns):

- **Runtime detection** — invoke `ship-flow:ship-runtime-detect` before any quality check to populate `{commands.test/build/typecheck/lint/dev}`.
- **TDD evidence** — invoke `ship-flow:test-driven-development` unconditionally and apply its fallback contract. `superpowers:test-driven-development` is optional local discipline only. Every non-exempt task must emit RED-before-GREEN evidence from `tdd_contract`; missing expected RED failure is BLOCKING feedback to the worker or a bounce to plan if the contract itself is absent.
- **Dispatch discipline** — default path: every task gets dispatched via Agent tool per plan's `model:`. "Agent tool not available" is a false claim in ensign context unless probe (`Agent(subagent_type: general-purpose, model: haiku, prompt: "return OK")`) returns runtime error. Inline exception requires ALL THREE: pure file-string replace + verbatim spec + single file <20 LOC; plus recorded verbatim probe error.
- **Parallelism within wave** — derive an `execute-dispatch-manifest` from plan's `plan-parallelization-manifest` / task metadata. Tasks with satisfied `depends_on` and no `owned_paths` overlap → dispatch in parallel (multiple Agent calls in one tool-call block). Overlap, missing `owned_paths`, missing `integration_owner`, or `parallel_group: serial` → sequential within wave. Never start wave N+1 until wave N fully committed. The executer is the single integrator and writes the final execute artifact.
- **Self-drive (anti-idle)** — no idle between tasks. After DONE + commit + review, immediately proceed. Entire execute stage = single continuous run.
- **`/goal` evidence (when a Claude Code `/goal` is active)** — the FO's turn-ending summary surfaces goal-condition evidence as ACTUAL command output run this turn (quoted test counts / exit codes / `gh` PR-merge state), NEVER a worker's "all green" relay nor confabulated results. The transcript-judged `/goal` evaluator cannot run checks and never sees subagent internals, so it both rejects vague relays (→ wasted turns) and is fooled by fabricated concrete-looking results (→ false completion). See INVARIANTS "Evidence discipline under an active `/goal`".

Before dispatching a wave, write `execute-dispatch-manifest` into `execute.md` draft or the stage working notes with columns: `Task`, `Parallel Group`, `Depends On`, `Owned Paths`, `Integration Owner`, `Dispatch Mode`. A `parallel` dispatch mode is allowed only when dependencies are satisfied and `owned_paths` are disjoint. If the plan lacks this metadata on a new non-trivial entity, bounce to plan; for legacy plans, proceed serially and record the fallback.

**Dispatch prompt anatomy** (ship-execute fills in, Layer A teaches why):
- Task text from plan (verbatim).
- Project / entity context.
- `### Architecture context` block with `$ARCH_SNIPPET` when non-empty.
- `### Skills required` block with this task's `skills_needed` list. Ask the troop to load/use only those skills first; if the list is empty because the task is docs-only/stage-artifact, say `none — docs-only/stage-artifact`.
- `### Folder guidance required` block with every `folder_guidance_files` path and parsed `folder_guidance_skills`. Ask the troop to read those files and return a `Context Read Receipt` listing the guidance files, loaded skills, and applied constraints. The receipt is required because PR-feedback re-entry and fresh workers do not reliably inherit app-folder guidance from Codex's root session context.
- Status protocol reminder (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED).
- Tiered quality check spec (T1 always, T2 if frontend touched).
- `Do NOT commit — return changed_files and status.` (orchestrator owns commits).

**Inject discipline (skill-load validation anti-pattern)** — light skill prime is allowed (`Skill(skill='<name>') — read "<section>"`). What is NOT allowed: requiring workers to log "Skills loaded" in stage report as a GATE input, designing per-dispatch grep validation around inject effectiveness, adding `canary_echo:` attestation fields to entity schema, or authoring `check-skill-canary-receipt.sh`-class verification primitives. The safety net for skill-rule application is verify-stage per-domain DC (output-shape, not process attestation). Read `plugins/ship-flow/references/validation-discipline.md` before adding any validation token, attestation field, or N-dispatch experiment to ship-flow.

### Step 2.5 — Tiered quality check (mandatory per task before DONE)

**T1 (always, ~30s)** — troop runs all three; all must pass (max 3 retry attempts):

```bash
{commands.build} 2>&1
{commands.typecheck} 2>&1
{commands.test} 2>&1
```

**T2 (only if task touched frontend files — `ui/`, `app/`, `components/`, `pages/`, `*.tsx`)**:

```bash
timeout 30 {commands.dev} &
sleep 5
curl -sfN http://localhost:3000 > /dev/null && echo "T2: root OK" || echo "T2: root FAIL"
curl -sfN http://localhost:3000/{affected-route} > /dev/null && echo "T2: route OK" || echo "T2: route FAIL"
kill %1 2>/dev/null
```

T2 failures count toward retries. Note `-sfN` for Next.js 16 Turbopack SSR (MEMORY #073).

**T3 (always — critical-pass lite, in-worker self-discipline)** — troop reads `plugins/ship-flow/lib/review-checklists/critical-pass.md` and applies ONLY Pass 1 CRITICAL categories to its own diff for this task:

- SQL & Data Safety
- Race Conditions & Concurrency
- LLM Output Trust Boundary
- Shell Injection
- Enum & Value Completeness

In-process self-check. **Do NOT dispatch a subagent for T3.** Classify findings:

- **Mechanical / Pass-2 informational** → auto-fix inline within the shared 3-iteration cap.
- **CRITICAL class** → MUST NOT silently fix. Append finding to `execute.md` under `## Critical-Pass Self-Check Findings` as `- [file:line] {category}: {description} → recommended fix`. Worker may apply a fix if confident, but always notes it for verify panel cross-check.

**Shared 3-iteration cap** — T1 + T2 + T3 fixes share the same 3-retry budget. If cumulative T1+T2+T3 cannot converge in 3 iterations, worker stops fixing and appends `## Self-Check Status` with `{check}: NOT CONVERGED after 3 iterations` plus a brief diagnosis. Worker still signals completion as normal; verify panel bounces back if needed.

**Self-Check report block** — every task appends to `execute.md` before returning:

```
## Self-Check
- typecheck: PASS / FAIL [optional inline note]
- lint: PASS / FAIL [optional inline note]
- unit tests: PASS (N/N) / FAIL
- qa-only: PASS / FAIL  (only when T2 fired)
- critical-pass lite: PASS / FAIL  (no SQL/race/LLM/shell/enum issues)
```

Rationale: lets verify panel trust self-check on these classes and focus on substantive failures instead of bouncing on mechanical issues.

### Step 3 — Handle task returns

- **DONE** → schedule commit (Step 3.5) + dispatch review (Step 4).
- **DONE_WITH_CONCERNS** → correctness/scope concerns → re-dispatch with clarification; observation concerns → log in `## Issues Found`, proceed as DONE.
- **NEEDS_CONTEXT** → gather missing info + re-dispatch (same model) with extra context. Cap 2 rounds; round 3 → reclassify as BLOCKED.
- **BLOCKED** → benign-drift pre-check first; else escalation ladder.

Before accepting DONE or DONE_WITH_CONCERNS for any task with folder guidance, validate the task return or execute draft:

```bash
bash plugins/ship-flow/lib/check-guidance-receipt.sh \
  --config=.claude/ship-flow/skill-routing.yaml \
  --files=<task-files> \
  --artifact=<task-return-or-execute-draft>
```

Exit 12 is BLOCKING feedback to the same worker: missing `Context Read Receipt`, missing app-folder guidance file citation, or missing routed/folder skill such as `refine-gotchas`. This is intentionally narrower than Codex built-in behavior: root `AGENTS.md`/`CLAUDE.md` are excluded by `codex_context_boundary`; only file-scoped adopter guidance is enforced here.

### Step 3.1 — Benign-drift pre-check (before escalation)

Substring match on `blocked_reason`:

- **anchor-drift** — contains `line` AND one of: `mismatch | shifted | not found at line | content moved` → auto-DONE + log `scope_observation`.
- **file-renamed** — contains `read_first` AND one of: `not found | ENOENT | does not exist`. Verify `git log --diff-filter=R --follow -- <path>`. Rename confirmed → auto-DONE; else fall through.
- **semantic-grep-mismatch** — contains `grep` AND `count`, searched string appears in plan text itself (circular reference) → auto-DONE + log.

No match → escalation ladder.

### Step 3.2 — BLOCKED escalation ladder

1. First BLOCKED (haiku) → re-dispatch as **sonnet** with `blocked_reason` in prompt.
2. Second BLOCKED (sonnet) → re-dispatch as **opus** with accumulated reasons.
3. Third BLOCKED (opus) → **terminal failure**. Log + create auto-issue entity.

**NOT a retry loop** — each tier is a different reasoning budget. Never skip a tier. Never same-tier retry. Never jump to "replan" on first BLOCKED.

### Step 3.5 — Serial commits after each wave (pathspec-lock)

After all tasks in wave reach terminal state, commit DONE tasks serially — one commit per task (preserves `git bisect` + PR decomposition):

```bash
git add -- {task.files_modified}
git commit -m "feat(execute): {slug} task-{N} — {one-line action}" -- {task.files_modified}
```

**Forbidden staging patterns** (parallel-session contamination defense):

| Forbidden | Reason |
|---|---|
| `git add -A` / `git add .` | Scoops unrelated dirty files |
| `git commit -am` / `git commit -a -m` | `-a` auto-stages every tracked modification |

**Correct pattern**: `git add -- <paths> && git commit ... -- <paths>`. The `-- <paths>` at commit-time locks the index scope even if another session interleaves a `git add -A`. Regression test: `plugins/ship-flow/lib/__tests__/test-skill-commit-lint.sh`.

Pre-commit hook fires per commit. Do NOT override with `--no-verify`. Hook fail → revert + reclassify as BLOCKED.

### Step 4 — Review each task (immediate, haiku)

Dispatch review subagent right after each DONE report (loop = implement → review → fix → re-review → next task). Model = haiku (reviews are mechanical). Prompt reviews: diff matches task? obvious bugs / missing handling / broken imports? tests exist? T1/T2 passed?

Verdict: APPROVED | NEEDS_FIX (BLOCKING only) + Non-Blocking notes.

**Review loop** — NEEDS_FIX → dispatch fix agent (same model as original) with specific issues → fix commits → re-review. Max 3 rounds; round 3 still NEEDS_FIX → log failed + create auto-issue entity.

**Non-blocking findings → auto entity**: `{slug}-improve-task-{N}` with `source: "auto:ship-flow review"`, status: draft.

### Step 5 — Wave completion + AC verification (first-pass)

After all waves complete, run `## Verification Spec` procedures per type (cli / api / ui / skill / e2e). Write to `## Execute UAT` section — **first-pass, not authoritative**; verify stage re-runs independently.

### Step 5.3 — Knowledge capture (conditional)

Log to `## Knowledge Captures`:
- **D1-confirmed** — codebase-grounded insight confirmed by ≥2 tasks (e.g., "extraction ratio 0.60 observed here; widens MEMORY bound").
- **D2-candidate** — one-off insight worth re-validating in next harness-diet (e.g., "dispatch-discipline rationalization precedent").

### Step 6 — Cross-review gate (Principle 6 Rule C)

Dispatch cross-review to `verifier` teammate (pipeline path) or fresh sonnet (no team). Upgrade to fresh **opus** when `appetite: big-batch`.

6-factor rubric adapted for execute stage (per INVARIANTS Principle 6 Rule C #106 T1.3):

1. **Feasibility** — wave plan executed cleanly (no terminal BLOCKs / no forced `--no-verify`)?
2. **Executable scope** — commits match tasks 1:1? one-commit-per-task preserved?
3. **Quality** — atomic commits used explicit pathspec (no `-A` / `-am`)? T1+T2 passed per task?
4. **DC adequacy** — AC verification ran all procedures; failures noted honestly?
5. **Canonical sync** — architecture-impact blocks updated post-execute if ARCHITECTURE.md moved?
6. **Reverse-audit previous stage** — does execute evidence expose a gap in the plan's wave ordering or stub-flag coverage? Specifically: were any `stub_flags` from `### Hand-off to Execute` captain-acked before proceeding? Did any task deviate from plan — and is the deviation captured in `### Hand-off to Verify`?
7. **Render Fidelity + captain-ack audit trail** (T6.4, #106) — for UI entities: does execute commit introduce any hardcoded hex values instead of CSS custom properties? AND are all stub tasks from plan executed with captain-ack recorded in `### Hand-off to Verify → stub_ack_log`?

**Reverse-audit prompt template** (T3.2 — paste verbatim into reviewer dispatch):
```
Reverse-audit: Read the entity's `### Hand-off to Execute` block.
(a) List every `stub_flags` entry — was each captain-acked before wave execution? (BLOCKING if any un-acked stub executed)
(b) Compare plan task list vs Execution Log — any task added, removed, or scope-expanded? (WARNING if yes; BLOCKING if scope-expanded without capture in Hand-off to Verify)
(c) Does `### Hand-off to Verify` capture all deviations from plan? (BLOCKING if deviation present but not documented)
Coaching note: undocumented plan deviations here cause verifier to check wrong behavior — enforces MEMORY #14 attribution discipline.
```

Verdict: **PROCEED** / **VETO** (loop to fix) / **PROMPT_CAPTAIN**. Each verdict MUST include a one-sentence coaching note per INVARIANTS Rule C ABC clause.

**Circuit breaker**: if `SendMessage(verifier)` is unresponsive (phantom team / timeout / fresh-Agent stall), fall back per INVARIANTS Rule A Fallback — fresh sonnet by default, fresh opus on `big-batch`. Do not block on an unresponsive reviewer.

### Step 7 — Emit execute.md

Write via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=execute --entity=<id>-<slug> --content=<draft-path>` (Wave 5 primitive at commit `acd73545`; handles atomic commit + pathspec-lock).

Execute.md sections: `## Execution Log` (per-task table), `## Issues Found`, `## Knowledge Captures` (D1/D2), `## Execute UAT` (first-pass AC), `## Execute Report` (status / stage_cost: Σ dispatches×model / tasks summary / knowledge capture counts / started/completed/duration).

**Verbosity budget (INVARIANTS Principle 8 — execute.md ≤150 body lines; C15 BLOCKER)**: the per-task DC-results table is the consumable; raw evidence is git-reconstructable or collapses:
- `## Execution Log` — the per-task table (Task / Wave / Model / Status / Files / Commit) IS the consumable. Do NOT re-emit per-task RAW command output, full diffs, or a separate per-commit SHA narrative in the body — the `Commit` column + `git log <base>..HEAD` reconstruct it. A bounded excerpt of raw build/test output may go in `<details>` (excluded from the ≤150 BODY cap, but the C15 2× raw-total backstop — raw ≤ 300 — still applies, so excerpt-not-dump). Large output → link a DURABLE artifact (committed-in-repo via explicit pathspec so it rides the PR, OR a durable CI-artifact URL — a bare local path is not audit evidence), don't inline.
- `## Execute UAT` — key rows by **DC-N**; the `Verify Procedure` (operative command actually run, may have deviated — not cheaply reconstructable) STAYS inline, plus `Result` + `Evidence`. Do NOT restate assertion/type — canonical in shape.md `### Done Criteria` (129.1 CD-2).
- `### Hand-off to Verify → commit_list` — this is git-reconstructable; reduce to a pointer (`commits: git log <base>..HEAD`) plus only the SHAs a `dc_status` row actually cites inline. Do NOT bulk-enumerate every commit.

Require a `### Metrics` subsection in `## Execute Report`.
Use grep-friendly `key: value` lines:
- `status:` passed | failed | blocked | partial
- `duration_minutes:` wall-clock minutes for execute
- `iteration_count:` review/fix loop count across tasks
- `task_count:` planned tasks attempted
- `tasks_done:` tasks completed
- `tasks_blocked:` tasks blocked or failed
- `commit_count:` execute commits landed

Return to /ship; advance to verify.

### Step 7.1 — Advance entity status (frontmatter wiring)

After stage artifact lands, advance sibling `index.md` frontmatter atomically:

    INDEX_MD="<entity-folder>/index.md"
    H="$(sha256sum "$INDEX_MD" | awk '{print $1}')"
    bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/advance-stage.sh" \
      --entity="$INDEX_MD" \
      --new-status=execute \
      --stage-name=execute \
      --stage-file=execute.md \
      --if-hash="$H" \
      --commit-as="execute(<id>): advance status to execute"

On exit 6 (stale hash): write `## Execute Report status: blocked, reason: index.md stale hash; parallel session contaminated` and return.

---

## Inline-on-main ship pattern (2-commit, no PR)

For **ship-flow self-reforming** entities (S/M, pure ship-flow plugin / docs / lib shell edit, zero application-code diff, no user-facing UX). Precedent: #047 / #049 / #062 / #064 / #067 / #060 / #075.

**When NOT**: user-facing UX / API, application code in `plugins/spacebridge/**`, entities whose verify needs PR-review signal.

2-commit sequence (pathspec-lock throughout):

```bash
git add -- <entity-file> ROADMAP.md PRODUCT.md <other-paths>
git commit -m "ship: <slug> (<NNN>) — <summary>" -- <entity-file> ROADMAP.md PRODUCT.md <other-paths>

spacedock status --workflow-dir docs/ship-flow/ \
  --set <NNN>-<slug> status=done verdict=PASSED completed="$(date -u +%FT%TZ)" --force
spacedock status --workflow-dir docs/ship-flow/ \
  --archive <NNN>-<slug> --force

git add -- docs/ship-flow/_archive/<slug>.md
git commit -m "done + archive: #<NNN> <slug> (verdict=PASSED, inline-on-main)" -- docs/ship-flow/_archive/<slug>.md
```

The entity key is the basename `<NNN>-<slug>` (the file/folder name), NOT the frontmatter `slug:` field. `spacedock` is the Go binary on PATH (`spacedock status ...`). `--force` bypasses `pr: empty` refusal (intentional for no-PR inline). Hazards: parallel-session staging contamination (pathspec-lock is sole defense); commit attribution drift via implicit `-am` staging (5069b8ba-class — do NOT fall back to `-am`).

---

## Invariants + red flags (STOP if violated)

- Wave graph honored: never start wave N+1 while wave N in flight; never silently reorder waves.
- Dispatch default: Agent tool unless probe returns verbatim runtime error AND narrow-exception criteria all hold.
- `--no-verify` is forbidden. Pre-commit hook fail → revert + reclassify BLOCKED.
- Forbidden staging: `-A` / `-am` / `.` anywhere in this skill's commit path.
- BLOCKED escalation never same-tier retries; each tier = different reasoning budget.
- T1 mandatory per task; T2 mandatory when frontend touched.
- Review loop max 3 rounds per task; round 3 failed → auto-issue entity.
- One-commit-per-task. Batching = violation of PR-decomposition + bisect discipline.
- Cross-review VETO capped at 2 rounds; round 3 → PROMPT_CAPTAIN.
- Layer A delegation (`superpowers:subagent-driven-development`) owns dispatch philosophy — re-teaching = Principle 6 Rule B violation.

## Circuit breakers

- Review loop: max 3 rounds → auto-issue entity.
- BLOCKED ladder: 3 tiers → terminal failure + auto-issue entity.
- PR-feedback: `pr_feedback_round > 3` → escalate captain.
- Total stage >30 min elapsed → write `execute.md` with partial content + `⚠️ INCOMPLETE` markers + Execute Report status=partial. Never exit without emitting execute.md.

<!-- section:hand_off_to_verify -->
## Final Step (Hand-off): Emit Hand-off to Verify + Read Incoming Hand-off

**Read incoming**: at Step 1, read `### Hand-off to Execute` from entity body. Re-verify `critical_assumptions` before wave dispatch. Check `stub_flags` — confirm captain-ack present before proceeding.

**Emit** `### Hand-off to Verify` after execute.md is written:
- `commit_list`: all commits landed (SHA + task ID + 1-line summary)
- `dc_status`: execute-side DC results per DC (PASS/FAIL with evidence command + output)
- `deviations`: any plan deviations with rationale (e.g., "T1.3 split into 2 commits because FM#4 amendment required separate pathspec")
- `render_fidelity_evidence`: for UI-type entities, dev server URL or screenshot path proving rendered output matches design canonical; "N/A" for non-UI entities
- `skills_needed_used`: per-task list copied from plan, or fallback note if missing on a legacy plan
- `context_read_receipts`: per-task list of folder guidance files read, routed skills loaded, folder guidance skills loaded, and applied constraints. If no non-root folder guidance matched, write `none — resolver reported no folder_guidance_files`.
<!-- /section:hand_off_to_verify -->

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml → stages.execute`.
- Stage writer: `plugins/ship-flow/lib/write-stage-artifact.sh`.
- Section extraction: `plugins/ship-flow/lib/extract-section.sh`, `extract-map.sh`.
- Layer A: `superpowers:subagent-driven-development` (dispatch philosophy).
- Utility: `ship-flow:ship-runtime-detect` (13-ecosystem).
- PR-feedback rollback: `plugins/ship-flow/bin/pr-feedback-rollback.sh`.
- Commit-lint test: `plugins/ship-flow/lib/__tests__/test-skill-commit-lint.sh`.
- Principle 6: `plugins/ship-flow/INVARIANTS.md`.
- MEMORY: #5 (--next-id atomicity), #14/#25/#37 (pathspec / staging contamination), #30 (verification-dispatch), #35 (dispatch discipline amended by Principle 6), #073 (Next.js 16 `-sfN`), opus-4.7-naturally-does (2026-04-23 harness diet).
