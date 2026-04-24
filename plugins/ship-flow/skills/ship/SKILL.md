---
name: ship
description: "Use when running the ship-flow pipeline on an entity-id or concrete requirement — dispatches plan→execute→verify→review→ship stages via SendMessage to named teammates (spawned at /shape) and produces `plan.md` / `execute.md` / `verify.md` / `review.md` / `ship.md` artifacts inside `docs/<wf>/<id>-<slug>/`. Vague or unmatched arguments route back to `/shape`."
user-invocable: true
argument-hint: "<entity-id | slug | concrete-requirement>"
---

# Ship — Pipeline Entry (2.0)

You run the SHIP pipeline entry. Produce 5 per-stage .md artifacts + final PR per Principle 6 3-layer architecture, dispatching to named teammates via SendMessage where the team was spawned at `/shape`.

**Layer A delegation**: none — `/ship` is pure orchestration. Stage skills (ship-plan / ship-execute / ship-verify / ship-review) own their Layer A delegations.

**Pipeline artifacts** (`<entity-folder>` = `docs/<wf>/<id>-<slug>/`):
- `plan.md` — ship-plan output (task breakdown, verification spec, DCs).
- `execute.md` — ship-execute output (commits, files modified, UAT evidence).
- `verify.md` — ship-verify output (quality gate, review, UAT, verdict).
- `review.md` — ship-review output (code review, captain smoke gate).
- `ship.md` — final stage (PR link, deploy ref, merge status).

## When to use

- `/ship <entity-id>` — entity folder OR flat entity exists → run pipeline.
- `/ship <slug>` — match via `docs/<wf>/<slug>.md` or `docs/<wf>/*-<slug>/`.
- `/ship "<concrete requirement>"` — specifies files, reproducible bug, OR typed acceptance → run pipeline inline (autonomous sharp-claim then pipeline).

**Inverse escape hatch (route to /shape):** raw requirement with NO file paths AND NO reproducible bug AND NO typed acceptance → announce `vague directive — run /shape first` and EXIT. Entity-id/slug with no matching file → announce `entity not found; run /shape <directive> to create` and EXIT.

---

## Step 1 — Classify argument + resolve entity

Resolve `WORKFLOW_DIR` from `docs/*/README.md` frontmatter `entry-point:`. Then:

| Input form | Detection | Action |
|---|---|---|
| Entity id (e.g. `085`) | `docs/<wf>/<id>-*.md` OR `docs/<wf>/<id>-*/README.md` | entity path |
| Slug | `docs/<wf>/*-<slug>.md` OR `docs/<wf>/*-<slug>/README.md` | entity path |
| Concrete requirement | has file paths / reproducible bug / typed acceptance | sharp-claim + entity path |
| Vague directive | none of above | inverse-escape EXIT |

**Concrete-requirement sharp-claim** (before pipeline): allocate ID via `python3 "$SPACEDOCK_PLUGIN_DIR/skills/commission/bin/status" --workflow-dir "$WORKFLOW_DIR" --next-id` (MEMORY #5 — `--next-id` → commit is ONE uninterrupted pair). Minimal body: the captain's directive verbatim + sharp-claim commit. Then fall into entity path.

## Step 2 — TaskCreate umbrella

Create 5 top-level tasks (ship owns the umbrella; each stage skill creates its own sub-phase tasks internally):

`plan` → `execute` → `verify` → `review` → `ship-final`

Mark each `in_progress` before dispatching that stage; `completed` when stage skill returns and cross-review verdict is PROCEED.

## Step 3 — Dispatch per stage (Principle 6 Rule A)

**Team reuse (NOT spawn).** Team `pitch-<id>` was created at `/shape` with `planner` (opus) + `executer` (sonnet) + `verifier` (opus or sonnet by pitch size). `/ship` REUSES via SendMessage — never re-spawns. If no team exists (rare edge: entity created outside `/shape`), create team inline:

```
TeamCreate(team_name: "pitch-<id>", members: ["planner", "executer", "verifier"])
```

Then dispatch each stage to its assigned teammate via SendMessage (hot-context ~10× faster than fresh dispatch):

| Stage | Teammate | Skill invoked by teammate | Artifact |
|---|---|---|---|
| plan | `planner` | `ship-flow:ship-plan` | `<entity-folder>/plan.md` |
| execute | `executer` | `ship-flow:ship-execute` | `<entity-folder>/execute.md` |
| verify | `verifier` | `ship-flow:ship-verify` | `<entity-folder>/verify.md` |
| review | `planner` | `ship-flow:ship-review` | `<entity-folder>/review.md` |
| ship-final | ship (this skill) | inline (no stage skill) | `<entity-folder>/ship.md` |

**Per-stage dispatch template** (SendMessage body — adjust per stage):

```
SendMessage(to: "<teammate>", body: "Run /<stage> for pitch-<id>. Entity folder: docs/<wf>/<id>-<slug>/. Read <prior-stage>.md; output <this-stage>.md via Skill: ship-flow:ship-<stage>. Dispatch cross-review counterpart before returning verdict.")
```

**Fresh-subagent reserved for Rule A exceptions**: (a) adversarial review across teammates; (b) clearly separate domain; (c) explicit captain request; (d) cross-review gate between stages.

## Step 4 — Stage flow

Sequentially advance; do NOT parallelize stages (they have hard ordering).

1. **plan** → `planner` runs `ship-plan`, writes `plan.md`. On return, cross-review gate (see Step 5) → TaskUpdate plan=completed → advance.
2. **execute** → `executer` runs `ship-execute`, writes `execute.md`. Cross-review gate → TaskUpdate → advance.
3. **verify** → `verifier` runs `ship-verify`, writes `verify.md`. Cross-review gate → TaskUpdate → advance.
4. **review** → `planner` runs `ship-review`, writes `review.md`. Cross-review gate → TaskUpdate → advance.
5. **ship-final** → THIS skill writes `ship.md` + creates PR + announces merge status (see Step 6).

**Interrupt handling**: captain may pause between stages. Each stage artifact is self-contained resumable; next `/ship <entity-id>` invocation reads existing artifacts and resumes at first missing .md (or first stage whose cross-review verdict was not PROCEED).

## Step 5 — Cross-review gate per stage (Principle 6 Rule C)

After each stage's .md lands, dispatch cross-review to the counterpart teammate. 5-factor rubric adapted per stage (reuses ship-shape Wave 2 framework):

| Factor | plan | execute | verify | review |
|---|---|---|---|---|
| **Feasibility** | tasks achievable? | wave plan executed cleanly? | gate scope correct? | PR size reasonable? |
| **Executable scope** | tasks are atomic commits? | commits match tasks 1:1? | verdict supported by evidence? | review scope matches diff? |
| **Quality** | plan covers spec children? | atomic commits used explicit pathspec? | ≥1 critical assumption verified? | no silent failures? |
| **DC adequacy** | observable DCs per task? | DCs ran; output captured? | scoped-gate spot-checks critical DCs? | review catches spec drift? |
| **Canonical sync** | ARCHITECTURE.md touches planned? | architecture-impact blocks updated? | canonical docs consistent post-execute? | PR body reflects canonical deltas? |

**Reviewer selection** (reuses ship-shape reviewer-fallback pattern):
- Within team: cross-teammate counterpart (planner ↔ executer; verifier reviews against either).
- No team member available: fresh **sonnet** by default; upgrade to fresh **opus** when entity's `appetite: big-batch`.

**FO verdict**: **PROCEED** → TaskUpdate stage=completed, advance. **VETO** → loop stage back to original teammate with reviewer feedback (max 2 loops; after 2 → `PROMPT_CAPTAIN`). **PROMPT_CAPTAIN** → halt pipeline, present stage artifact + reviewer concern; captain decides continue/abort. **Note**: this cap governs automated planner↔executer VETO only; post-ship captain-smoke feedback uses the separate Step 7 cap.

## Step 6 — Ship-final stage (this skill)

After `review.md` cross-review PROCEED:

1. **Compose `ship.md`** inside entity folder. Content: PR URL, deploy reference (if deployed), merge status, customer-visible summary (1-2 sentences drawn from spec.md + execute.md). Single atomic commit via Layer C writer — Wave 5 primitive landed at commit `acd73545`; invoke via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=ship --entity=<id>-<slug>`.
2. **Create PR** via `gh pr create` with title from entity + body referencing all stage artifacts (plan/execute/verify/review links).
3. **Announce** to captain: entity shipped + PR URL + stage artifact paths.
4. TaskUpdate ship-final=completed.

**Merge decision is captain's.** `/ship` does NOT auto-merge. Captain may comment on PR or run `gh pr merge` manually.

## Step 7 — Captain-smoke feedback loop (post-ship-final)

After `ship.md` lands and captain starts browser smoke-testing the shipped feature:

### Triage incoming findings

Captain smoke findings fall into three buckets:
1. **In-scope fix** — bug introduced by this entity OR explicitly within this entity's design contract. Route to executer via SendMessage with a concrete fix list.
2. **Pre-existing bug** — surfaced by captain's smoke but not caused by this entity's commits. File via `/add-todos` as a rabbit hole immediately. Do NOT bundle into this entity.
3. **New feature request** — genuinely new capability. File via `/add-todos` or `/shape` new entity. Do NOT bundle.

### Round cap (distinct from Step 5 automated VETO loop)

Captain-smoke feedback allows **max 2 consecutive rounds without `PROMPT_CAPTAIN`**. At round 3:
- HALT auto-dispatch.
- Present to captain with explicit prompt: "Round 3 captain-smoke feedback detected. Options: (a) continue — YOU approve each specific fix item individually; (b) ship current state, file remaining findings as follow-up entities; (c) abort — roll back worktree, discard pipeline."
- Do NOT silently continue. Captain's explicit choice is required.

### Why distinct from Step 5 VETO loop

Step 5 is **automated planner↔executer VETO** — max 2 prevents infinite auto-loop between agents. Captain-smoke is **human-in-loop iteration** where captain's sequential discoveries often cascade (fixing A reveals B). Same numeric cap would over-constrain legitimate captain exploration. Both caps are independent and tracked separately per entity.

### Captain smoke is the final gate

After Step 7 resolves (PROCEED or captain-approved ship-current-state):
- Push + `gh pr create` awaits captain's explicit approval per CLAUDE.md autonomous boundary.
- Merge decision remains captain's (`gh pr merge` or dashboard).

---

## Per-stage .md writers

Each stage skill uses Layer C writer `lib/write-stage-artifact.sh --stage=<stage> --entity=<id>-<slug> --content=<path-to-draft>` (Wave 5 primitive landed at commit `acd73545`). The writer handles atomic commit with explicit pathspec; stages MUST NOT inline their own `git add`/`git commit`. Fallback pattern (inline atomic write) is retained for documentation-only reference:

```bash
git add "<entity-folder>/<stage>.md" && \
git commit -m "<stage>(<id>): ..." -- "<entity-folder>/<stage>.md"
```

No `-a`/`-A` staging (MEMORY #14/#25/#37). Sharp-claim → pipeline-start commit is NOT atomically required; only `--next-id` → sharp-claim commit is one uninterrupted pair (MEMORY #5).

---

## Invariants + red flags (STOP or escalate if violated)

- `/ship` NEVER spawns a new team — reuses the team from `/shape` via SendMessage. Spawn only on rare edge case (entity created outside `/shape`).
- 5 stages advance sequentially. Skipping a stage = fake pipeline.
- Each stage emits its .md before cross-review runs. Empty or missing .md → cross-review has nothing to review → STOP.
- Cross-review gate per stage is non-negotiable (Principle 6 Rule C).
- VETO loop capped at 2 rounds per stage; round 3 → PROMPT_CAPTAIN.
- `/ship "<vague>"` without file paths / reproducible bug / typed acceptance → inverse escape EXIT. Do NOT shape inline — user runs `/shape` explicitly.
- Entity-id unresolved → EXIT with `entity not found` hint.
- Within-pitch stage transition via fresh-subagent without (a/b/c/d) exception → Principle 6 Rule A violation.
- TaskCreate umbrella at THIS skill; each stage skill owns its sub-task list (do not duplicate).
- Explicit pathspec on every commit (MEMORY #14/#25/#37): `git add <path> && git commit ... -- <path>`.
- **Worktree-first** (MEMORY #25): at pipeline entry (Step 1 pre-check), `git rev-parse --absolute-git-dir` MUST resolve under `.claude/worktrees/`. On main tip → HALT, prompt captain to spawn worktree (`EnterWorktree` tool) before dispatching any teammate. Stage-artifact commits on main tip contaminate with parallel-session staging per MEMORY #25; worktree isolates completely.
- No auto-merge. Captain owns merge decision after PR created in ship-final.

---

## References

- Entity folder schema: `plugins/ship-flow/references/entity-body-schema.yaml`.
- Per-stage writer: `plugins/ship-flow/lib/write-stage-artifact.sh` (landed commit `acd73545`).
- Atomic writer (shape): `plugins/ship-flow/lib/shape-confirm.sh`.
- Stage skills: `ship-flow:ship-plan`, `ship-flow:ship-execute`, `ship-flow:ship-verify`, `ship-flow:ship-review`.
- Upstream shape skill: `ship-flow:ship-shape` (team spawn happens here).
- Principle 6: `plugins/ship-flow/INVARIANTS.md` (context continuity + 3-layer architecture + cross-review).
- MEMORY: #5 (--next-id atomicity), #14/#25/#37 (explicit pathspec / staging contamination), #30 (verification-dispatch), #35 (dispatch discipline, amended by Principle 6 Rule A), opus-4.7-naturally-does (2026-04-23 harness diet).
