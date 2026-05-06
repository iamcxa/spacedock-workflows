---
name: ship
description: "Use when `/ship` should run ship-flow for an entity id or concrete requirement; use shape first for vague or unmatched requests."
user-invocable: true
argument-hint: "<entity-id | slug | concrete-requirement>"
---

# Ship — Pipeline Entry (2.0)

You run the SHIP pipeline entry. Produce 5 per-stage .md artifacts + final PR per Principle 6 3-layer architecture, dispatching to named teammates via SendMessage where the team was spawned at `/shape`.

## First-Officer Bootstrap

Before doing pipeline work: before classifying the `/ship` argument, before resolving an entity, and before
dispatching any stage, load `spacedock:first-officer` and follow its startup
procedure. The First Officer is the orchestration authority for workflow
discovery, `status --boot`, `status --resolve`, gate handling, feedback routing,
worktrees, merge hooks, and worker lifecycle.

This bridge applies in both runtimes:
- Claude Code (`CLAUDECODE` env var is set): load `spacedock:first-officer`,
  then follow its Claude Code runtime adapter while running this ship-flow
  pipeline.
- Codex (`CODEX_HOME` env var is set): load `spacedock:first-officer`, then
  follow its Codex runtime adapter while running this ship-flow pipeline.

`ship-flow:ship` remains the pipeline-specific entrypoint, but it must operate
under the First Officer contract. Do not bypass first-officer startup, status
resolution, gate policy, or feedback routing because the input looks like a
simple entity id.

If requirements are vague, route through first-officer-managed workflow state to
`ship-flow:ship-shape`; do not bypass first-officer by inventing a plan or
executing inline.

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
| Entity id (e.g. `085`) | `docs/<workflow>/<id>-*.md` OR `docs/<workflow>/<id>-*/index.md` | entity path |
| Slug | `docs/<workflow>/*-<slug>.md` OR `docs/<workflow>/*-<slug>/index.md` | entity path |
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

### Codex dispatch evidence guard

Codex/FO-dispatched shape, design, and verify workers MUST NOT report completion
until the expected 113 evidence is produced or explicitly cited in the stage
artifact. Missing required evidence is a completion blocker; return BLOCKED or
NEEDS_CONTEXT instead of DONE/PROCEED.

- shape: include `Domain Registry Validation` when domain classification or
  validation is relevant.
- design: include `## Schema Design Output` for `domain: schema` or the
  schema-domain route.
- verify: include `## Intent Match Findings` when schema design output exists
  or schema domain triggers.

Per-stage dispatch bodies MUST include: `Codex dispatch evidence guard:
missing shape/design/verify 113 evidence is a completion blocker; do not report
completion without the required Domain Registry Validation, ## Schema Design
Output, or ## Intent Match Findings block for the triggered stage.`

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

**Verdict-flip transformation (density-aware autonomy, pitch 101)**:

When a cross-review returns PROMPT_CAPTAIN, FO evaluates the density gate BEFORE halting:

```
if PROMPT_CAPTAIN
   AND is_high_density(entity) == true   # bash density-classify.sh --is-high exits 0
   AND reason_predicate in WHITELIST:
     emit PROCEED
     append decisions.md row(stage, original_verdict=PROMPT_CAPTAIN, flipped_to=PROCEED, reason_predicate, source_citation)
     git add docs/<wf>/<entity>/decisions.md && git commit -m "decision: verdict-flip <stage>" -- docs/<wf>/<entity>/decisions.md
else:
     KEEP original verdict (VETO stays VETO; PROMPT_CAPTAIN stays PROMPT_CAPTAIN)
```

**Boolean-gate compliance (Principle 4)**: external input is the SINGLE boolean `is_high_density(entity)`. The 4-tier enum is internal display only — NOT exposed at the gate. Gate logic: `(is_high_density && reason_in_whitelist) ? FLIP : KEEP`.

**WHITELIST** (boolean predicates; each evaluates true/false on a reason vector):
- `reason_matches_skill_precedent` — finding cites a skill preset rule the repo already enforces
- `reason_matches_canonical_constraint` — finding traces to PRODUCT.md / ARCHITECTURE.md hard constraint already documented
- `reason_matches_precedent_count_ge_2` — finding pattern has >=2 prior shipped precedents in `_archive/done/`
- `reason_is_NIT_class` — severity classification = NIT (per ship-verify Step 4.6 mechanical auto-fix rule)

**Applies only to**: PROMPT_CAPTAIN -> PROCEED transitions. VETO is never flipped.

**FO verdict**: **PROCEED** → TaskUpdate stage=completed, advance. **VETO** → loop stage back to original teammate with reviewer feedback (max 2 loops; after 2 → `PROMPT_CAPTAIN`). **PROMPT_CAPTAIN** → halt pipeline, present stage artifact + reviewer concern; captain decides continue/abort. **Note**: this cap governs automated planner↔executer VETO only; post-ship captain-smoke feedback uses the separate Step 7 cap.

## Step 6 — Ship-final stage (this skill)

After `review.md` cross-review PROCEED:

1. **Compose `ship.md`** inside entity folder. Content: PR URL, deploy reference (if deployed), merge status, customer-visible summary (1-2 sentences drawn from the resolved shape artifact + execute.md), and `## Todo Closeout Digest`. Single atomic commit via Layer C writer — Wave 5 primitive landed at commit `acd73545`; invoke via `bash plugins/ship-flow/lib/write-stage-artifact.sh --stage=ship --entity=<id>-<slug>`.

   `## Todo Closeout Digest` MUST summarize:
   - todos captured during this ship, with todo slug and source stage;
   - deferred follow-ups explicitly left in ROADMAP later;
   - rejected alternatives that were recorded but not captured as todos;
   - todos promoted into shaped entities during this run.

   After the digest is written, ask the captain how to handle newly captured
   todos: sync to task management (for example Linear) through an adapter/mod,
   shape the next todo now, or leave in ROADMAP later. This is a routing prompt,
   not a hard dependency on an external tool. Do not hardcode Linear into
   ship-flow core; task-management sync belongs in a project adapter/mod.

   **After `ship.md` lands, advance sibling `index.md` frontmatter atomically:**

       INDEX_MD="<entity-folder>/index.md"
       H="$(sha256sum "$INDEX_MD" | awk '{print $1}')"
       bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/advance-stage.sh" \
         --entity="$INDEX_MD" \
         --new-status=ship \
         --stage-name=ship \
         --stage-file=ship.md \
         --if-hash="$H" \
         --commit-as="ship(<id>): advance status to ship"

   Note: `ship→done` flip on PR-merge is **out of scope** for this step — covered by existing `commission/bin/status --set ... status=done` in inline-on-main path; `warn-state-drift` Rule A flags drift if missed.

   On exit 6 (stale hash): write `## Ship Report status: blocked, reason: index.md stale hash; parallel session contaminated` and return.

2. **Mechanical guardrail lint** — if `plugins/ship-flow/bin/ship-flow-lint.mjs`
   exists, run it before PR creation:

       node plugins/ship-flow/bin/ship-flow-lint.mjs --workflow-dir docs/ship-flow

   If the adopter exposes a package script such as `pnpm ship-flow:lint`, prefer
   the package script. Any failure is a ship-final blocker: fix the deterministic
   issue before spending PR review cycles. Project-specific seed/migration/env
   checks stay in adopter config or package scripts; ship-flow core only owns the
   generic runner.

3. **Create PR and persist PR metadata** via `gh pr create` with title from entity + body referencing all stage artifacts (plan/execute/verify/review links).

   Capture the exact `gh pr create` stdout/stderr stream before any post-create checks, compute the active entity hash before PR creation, then persist metadata immediately after successful PR creation and confirmation:

       INDEX_MD="<entity-folder>/index.md"
       H="$(sha256sum "$INDEX_MD" | awk '{print $1}')"
       PR_CREATE_OUTPUT="$(mktemp)"
       gh pr create ... >"$PR_CREATE_OUTPUT" 2>&1
       bash "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/lib/persist-pr-metadata.sh" \
         --entity "$INDEX_MD" \
         --pr-create-output "$PR_CREATE_OUTPUT" \
         --if-hash "$H" \
         ${MAIN_INDEX_MD:+--mirror-entity "$MAIN_INDEX_MD"}

   The helper is the only PR metadata writer for ship-final. It parses the PR number only from the successful `gh pr create` URL, confirms it with `gh pr view "$number" --json number,url,headRefName,headRefOid,state`, and stores exactly `pr: "#N"` in active frontmatter. Do not discover a PR by branch or title as a fallback.

   Metadata persistence happens before merge-state polling, Ready/reviewer routing, smoke routing, and any post-create auto-review. Refuse and stop ship-final progression on `missing-pr-number`, `pr-view-unconfirmed`, `stale-entity-hash`, `malformed-frontmatter`, `missing-entity`, or `conflicting-pr`; surface the helper report to the captain. An existing identical `pr: "#N"` is idempotent and may proceed.

   The active worktree entity is primary. When a same-slug main/startup copy is known, pass it as `--mirror-entity`; the helper may mirror only the `pr` field and must skip the mirror on conflict without blocking the already-safe active write. This step does not add a captain plan gate, PR merge behavior, dashboards, or multi-entity sweeps.
4. **Post-create merge-state check** — poll `gh pr view {pr} --json mergeStateStatus --jq '.mergeStateStatus'` every 5 seconds for up to 30 seconds, stopping on `CLEAN`, `CONFLICTING`, `DIRTY`, or `UNSTABLE`.

   - `CLEAN` → continue to post-create auto-review.
   - `CONFLICTING` or `DIRTY` → update the branch against main: `git fetch origin main && git rebase origin/main`.
     - If rebase is clean: `git push --force-with-lease`, then re-check `mergeStateStatus`.
     - If the only unmerged path is `ROADMAP.md`: run `bash plugins/ship-flow/lib/rebase-resolve-additive.sh`. The helper may only resolve pure-additive changes inside `ROADMAP.md` append-only sections `later`, `not-doing`, and `shipped`; it stages the resolved file. Then run `GIT_EDITOR=true git rebase --continue`, `git push --force-with-lease`, and re-check `mergeStateStatus`.
     - If any other file is unmerged, or the helper exits non-zero: stop ship-final auto-progression and surface a conflict summary to the captain. Do not guess at structural conflicts.
   - `UNSTABLE` → surface the status and current check summary to the captain; do not treat it as a content conflict.
   - Timeout without one of the terminal statuses → surface the last observed state and continue only with captain direction.

   Additive auto-resolution currently has one known safe surface: `ROADMAP.md` sections `later`, `not-doing`, and `shipped`. Add more surfaces only when repo evidence proves they are append-only and structurally bounded by section markers.
5. **Post-create auto-review** — invoke the workflow's pr-merge mod `Hook: post-create` (`docs/<wf>/_mods/pr-merge.md`). The FO computes a 5-signal confidence score (verify gate / quality gates / outstanding feedback / rebase clean / token spend); on score ≥90 auto-applies the policy steps (mark Ready via `gh pr ready` + request Copilot review with graceful skip if absent); on 80-89 surfaces breakdown to captain and asks; on <80 surfaces concerns and skips. Tagging `@claude review` is intentionally NOT a default step — adopters who have the Claude Code Action wired can extend in a project-scoped override of the mod. Failure of any post-create step is non-blocking — log + surface, never halt ship-final.
6. **Announce** to captain: entity shipped + PR URL + stage artifact paths + post-create auto-review outcome (Ready ✓ / Copilot reviewer id or "skipped" / score breakdown if <90).
7. TaskUpdate ship-final=completed.

**Merge decision is captain's.** `/ship` does NOT auto-merge. Captain may comment on PR or run `gh pr merge` manually.

## Step 6.5 — Verify-stage captain UAT feedback loop

If the captain performs manual UAT while the entity is still in verify, treat it
as **verify-stage captain UAT feedback**, not post-ship captain smoke. Read
`ship-verify → Captain UAT Feedback Router`; the finding stays inside the
current verify loop.

Routing:
- `route_to: execute` → SendMessage to `executer@pitch-XX`.
- `route_to: design` → SendMessage to `designer@pitch-XX`.
- `route_to: plan` → SendMessage to `planner@pitch-XX`.
- `route_to: follow-up` → file via `/add-todos` or `/shape`; do not bundle.

SendMessage to executer/designer/planner is mandatory for routed verify-stage
captain feedback; FO MUST NOT patch inline except for mechanical NITs.

The FO MUST NOT patch inline for BLOCKING, WARNING, semantic UX, logic, routing,
data, or contract findings. Inline repair is limited to verify-stage mechanical
NITs that satisfy the `ship-verify` auto-fix criteria. After owner feedback is
resolved, re-run verify and update `verify.md → ## Captain UAT Feedback` with
the route and outcome.

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
- Push + `gh pr create` proceed **autonomously** — no captain approval needed when all cross-reviews PROCEED. Captain pauses only on: VETO / PROMPT_CAPTAIN verdict, post-PR-create conflict check that fails auto-resolve gate, or BLOCKING captain-smoke finding. Bad-news-early still applies — if anything surfaces during push/PR-create, surface it BEFORE proceeding. Adopter projects wanting stricter default can add a scoped override in their project-level `CLAUDE.md`.
- Merge decision remains captain's (`gh pr merge` or dashboard). `/ship` does NOT auto-merge.

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
