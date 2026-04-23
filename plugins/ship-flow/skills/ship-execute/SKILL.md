---
name: ship-execute
description: "Use when executing a plan's tasks via wave-parallel dispatch. Agent-autonomous: wave graph traversal with per-task model hints, implementer→reviewer two-stage loop, BLOCKED escalation ladder (haiku→sonnet→opus), PR-feedback re-entry mode. Dispatched by /ship to `executer` teammate (SendMessage). Output: `<entity-folder>/execute.md`. Layer A delegation: superpowers:subagent-driven-development for dispatch philosophy."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# Ship-Execute — EXECUTE Stage (2.0)

You run EXECUTE. Output: `<entity-folder>/execute.md`. Dispatched by `/ship` to `executer` teammate via SendMessage. No captain gate.

**Pipeline position**: reads `plan.md` → wave-by-wave dispatch + review → commits → produces `execute.md` → cross-review gate → advance to verify.

## Entity body contract (schema-as-prose)

- Reads: `plan.md` (`## Plan`, `## Verification Spec`), sharp `## Done Criteria`, `## PR Review Feedback` (if Mode B).
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
- **Dispatch discipline** — default path: every task gets dispatched via Agent tool per plan's `model:`. "Agent tool not available" is a false claim in ensign context unless probe (`Agent(subagent_type: general-purpose, model: haiku, prompt: "return OK")`) returns runtime error. Inline exception requires ALL THREE: pure file-string replace + verbatim spec + single file <20 LOC; plus recorded verbatim probe error.
- **Parallelism within wave** — tasks with no `files_modified` overlap → dispatch in parallel (multiple Agent calls in one tool-call block). Overlap or `serial: true` → sequential within wave. Never start wave N+1 until wave N fully committed.
- **Self-drive (anti-idle)** — no idle between tasks. After DONE + commit + review, immediately proceed. Entire execute stage = single continuous run.

**Dispatch prompt anatomy** (ship-execute fills in, Layer A teaches why):
- Task text from plan (verbatim).
- Project / entity context.
- `### Architecture context` block with `$ARCH_SNIPPET` when non-empty.
- Status protocol reminder (DONE / DONE_WITH_CONCERNS / NEEDS_CONTEXT / BLOCKED).
- Tiered quality check spec (T1 always, T2 if frontend touched).
- `Do NOT commit — return changed_files and status.` (orchestrator owns commits).

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

### Step 3 — Handle task returns

- **DONE** → schedule commit (Step 3.5) + dispatch review (Step 4).
- **DONE_WITH_CONCERNS** → correctness/scope concerns → re-dispatch with clarification; observation concerns → log in `## Issues Found`, proceed as DONE.
- **NEEDS_CONTEXT** → gather missing info + re-dispatch (same model) with extra context. Cap 2 rounds; round 3 → reclassify as BLOCKED.
- **BLOCKED** → benign-drift pre-check first; else escalation ladder.

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

**Forbidden staging patterns** (parallel-session contamination defense — MEMORY #14/#25/#37):

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

5-factor rubric adapted for execute stage:

1. **Feasibility** — wave plan executed cleanly (no terminal BLOCKs / no forced `--no-verify`)?
2. **Executable scope** — commits match tasks 1:1? one-commit-per-task preserved?
3. **Quality** — atomic commits used explicit pathspec (no `-A` / `-am`)? T1+T2 passed per task?
4. **DC adequacy** — AC verification ran all procedures; failures noted honestly?
5. **Canonical sync** — architecture-impact blocks updated post-execute if ARCHITECTURE.md moved?

Verdict: **PROCEED** / **VETO** (loop to fix) / **PROMPT_CAPTAIN**.

### Step 7 — Emit execute.md

Write via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=execute --entity=<id>-<slug> --content=<draft-path>` (Wave 5 primitive at commit `acd73545`; handles atomic commit + pathspec-lock).

Execute.md sections: `## Execution Log` (per-task table), `## Issues Found`, `## Knowledge Captures` (D1/D2), `## Execute UAT` (first-pass AC), `## Execute Report` (status / stage_cost: Σ dispatches×model / tasks summary / knowledge capture counts / started/completed/duration).

Return to /ship; advance to verify.

---

## Inline-on-main ship pattern (2-commit, no PR)

For **ship-flow self-reforming** entities (S/M, pure ship-flow plugin / docs / lib shell edit, zero application-code diff, no user-facing UX). Precedent: #047 / #049 / #062 / #064 / #067 / #060 / #075.

**When NOT**: user-facing UX / API, application code in `plugins/spacebridge/**`, entities whose verify needs PR-review signal.

2-commit sequence (pathspec-lock throughout):

```bash
git add -- <entity-file> ROADMAP.md PRODUCT.md <other-paths>
git commit -m "ship: <slug> (<NNN>) — <summary>" -- <entity-file> ROADMAP.md PRODUCT.md <other-paths>

python3 <spacedock-plugin>/skills/commission/bin/status --workflow-dir docs/ship-flow/ \
  --set <slug> status=done verdict=PASSED completed="$(date -u +%FT%TZ)" --force
python3 <spacedock-plugin>/skills/commission/bin/status --workflow-dir docs/ship-flow/ \
  --archive <slug> --force

git add -- docs/ship-flow/_archive/<slug>.md
git commit -m "done + archive: #<NNN> <slug> (verdict=PASSED, inline-on-main)" -- docs/ship-flow/_archive/<slug>.md
```

`--force` bypasses `pr: empty` refusal (intentional for no-PR inline). Hazards: parallel-session staging contamination (pathspec-lock is sole defense); MEMORY #14 5069b8ba-class attribution drift (do NOT fall back to `-am`).

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
