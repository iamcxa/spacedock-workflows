---
name: ship-shape
description: "Use when shaping a vague / complex / ambiguous directive into a Shape Up pitch before autonomous pipeline execution. Default Mode A: agent-autonomous proposer (one proposal, captain gates confirm / refine / reject). Mode B: `--discuss` or auto-routed Q-loop via superpowers:brainstorming. Mode C: skill-authoring via superpowers:writing-skills. Output: `docs/<wf>/<id>-<slug>/spec.md` (folder layout default)."
user-invocable: true
argument-hint: "[--discuss] [directive-text | todo-tid | entity-id]"
---

# Ship-Shape — SHAPE Stage (2.0)

You run SHAPE. Output: `docs/<wf>/<id>-<slug>/spec.md`. Captain has ONE gate per run: confirm / refine / reject.

**Shape Up vocabulary** (load-bearing — entity-body schema depends on these names):
- **Pitch** — parent entity. Fields: `problem`, `appetite`, `children[]`, `rabbit_holes[]`, `deleted_from_shape[]`, `stated_assumptions[]`, `dag_mermaid`.
- **Appetite** — time budget (`small-batch` 2-3d / `medium-batch` 1-2w / `big-batch` 6w). Scope fits budget; budget does not flex.
- **Rabbit hole** — follow-up captured to `docs/<wf>/todos/`. **Rejected alternative** — claim considered-then-rejected with reason (populates from brainstorming Q-loop or scope-cut during decompose). **Shaped child** — vertical E2E slice (`pattern: shaped-child`). **DAG** — mermaid child-dependency diagram; feeds FO Pitch Orchestration.

## When to use

`/shape "<free text>"` — Mode A (default). `/shape --discuss "<text>"` — Mode B Q-loop. `/shape <todo-tid>` — promote captured todo. `/shape <entity-id>` — shape existing draft.

**Escape hatch (skip shape):** directive <80 chars AND contains `fix | typo | rename | bump | patch | bugfix | hotfix` as whole word → `shape unnecessary — run /ship directly` and EXIT. Concrete directive (files / reproducible bug / typed acceptance) → suggest `/ship <requirement>` and EXIT.

**Mode auto-routing** (on `/shape "<text>"` without `--discuss`):

1. **Mode C (skill-authoring)** — FIRST. Triggers: keywords `create/build/write/improve/modify a skill`, `SKILL.md`, `add a skill`; target paths `*/skills/*`, `*/SKILL.md`, `.claude/agents/*`; entity frontmatter `type: skill` or `domain: skill-authoring`.
2. **Mode B (ambiguity)** — SECOND. After L0 subagent returns, `open_questions[]` length ≥ 3 → announce switch and run Mode B.
3. **Default** — Mode A.

---

## Mode A — Autonomous Proposer (default)

Main agent runs inline. Use TaskCreate to mark phases on main-agent path (skip if a named teammate owns the pitch end-to-end).

**Phases**: `intake` → `L0-research` → `L1-research` → `L2-research` → `scope-decompose` → `assumption-extract` → `appetite-fit-check` → `compose-proposal` → `cross-review` → `captain-gate`

### Intake

| Form | Detection | Action |
|---|---|---|
| Free text | no tid/entity match | use as directive |
| Todo tid | matches `docs/<wf>/todos/<tid>.md` | read todo body; note tid |
| Entity id | matches `docs/<wf>/<id>-<slug>.md` OR `docs/<wf>/<id>-<slug>/README.md` | read entity; use title + body |

Record stage-start ISO timestamp. Resolve `WORKFLOW_DIR` from `docs/*/README.md` frontmatter `entry-point:`. Run escape-hatch check now.

### Research (L0 → L1 → L2; skip layers that don't apply)

- **L0 codebase** — dispatch **fresh-context subagent** (do NOT grep from orchestrating context). Return: `affected_files`, `existing_patterns`, `constraints`, `prior_entities[≤5]`, `open_questions[]`.
- **L1 library** — inline via trained knowledge / Context7. Subagent only for wide API surface.
- **L2 web** — 1-2 `WebSearch` queries only when L0+L1 leave a load-bearing claim unresolved. Usually skip.

RULE: L0 via fresh subagent is non-negotiable. Opus 4.7 handles the rest naturally — don't over-teach.

### Scope discipline: appetite, decompose, assumptions

**Appetite is a budget (not estimate)**: pick `small-batch` (2-3d, 1-3 children) / `medium-batch` (1-2w, 3-6 children) / `big-batch` (6w classic, 5-10 children). Scope fits budget; budget does not stretch. Exceeds big-batch → flag `[EPIC?]`, recommend sub-pitch.

**Vertical-slice children**: each child ships E2E standalone. "all-API" / "all-UI" / "every-depends-on-every" = fake decomposition → re-cut.

**Rejected alternatives** → `deleted_from_shape[]` (field name retained for shape-confirm.sh compat; semantics = "considered but not in scope"). Populate from: (a) brainstorming Q-loop's considered-then-rejected branches, (b) intake clarification (captain said A → rejected B), (c) scope-cut during decompose (feature trimmed to fit appetite). "Worth doing eventually" → `rabbit_holes[]` instead. Musk 5-step procedure intentionally NOT enforced (opus-4.7-naturally-does, MEMORY 2026-04-23); scope protection comes from the appetite-fit check below, not from a forced-delete ritual.

**Assumptions**: emit `stated_assumption` per load-bearing claim (schema: `plugins/ship-flow/references/entity-body-schema.yaml`). **Mandatory**: ≥1 `criticality: critical`. Run each critical's verification now (30s soft cap); record resolved confidence in `confidence_at_shape`. **Do NOT reproduce verification output in the proposal** — `verified_by` + bumped `confidence_at_shape` is the full trace. Raw grep/read results belong to plan-stage research, not shape-stage proposal.

### Appetite-fit check (before compose) — scope cap enforcement

After decomposition and before composing the proposal, verify children fit the declared appetite:

- **Per-child estimate vs per-child cap**: `small-batch` per child ≤ 2 days; `medium-batch` per child ≤ 3 days; `big-batch` per child ≤ 1 week.
- **Sum of children's estimates** ≤ 80% of appetite budget (20% headroom for cross-review iteration + unforeseen).

If fit check **fails**:
- **Re-cut, don't stretch** — move a child to `rabbit_holes[]`, compress child scope, merge thin children. Do NOT extend appetite.
- **If cut fails** (all children load-bearing + cannot compress) → auto-route to Mode B (captain clarifies which concerns to drop) OR flag `[EPIC?]` and recommend sub-pitch.

**Why this exists**: opus 4.7 default bias = thoroughness (add) not ruthlessness (cut). Without an explicit fit check, children inflate past appetite and "out of scope" proposals ship. Fit check forces the cut decision BEFORE captain sees the proposal.

### Architecture-impact (only when ARCHITECTURE.md moves)

Skip for pure bug / UI polish / docs. Run when L0 surfaces drift OR new decision belongs in ARCHITECTURE.md. Draft `<!-- section:architecture-impact -->` per child; pre-fill `before:` via `bash plugins/ship-flow/lib/extract-map.sh ARCHITECTURE.md <section>`. Uncertain → emit assumption `verified_by: design-contract`. Consumer: ship-review planner dispatch patches ARCHITECTURE.md via `patch-map.sh --if-hash`.

### Product-impact (only when PRODUCT.md moves)

Trigger conditions (any):
- New user-facing capability (adds row to `## Current Capabilities`).
- New user story accepted (JTBD Persona / Action / Outcome).
- Constraint added / relaxed (hard limits section).
- "Who It Serves" / "Why It Exists" shifts.

Skip when: pitch is pure internal refactor / infra / bug fix with no user-facing surface.

Draft `<!-- section:product-impact -->` per affected child:
- `target_section`: e.g. `capabilities`, `user-stories`, `constraints`.
- `before` / `after`: current vs new section content.
- `rationale`: why this product-level change.

Schema: `entity-body-schema.yaml` → `product-impact` block. Consumer: ship-review planner dispatch patches PRODUCT.md via `patch-map.sh --if-hash`.

### Readme-impact (only when README.md user-facing prose moves)

Trigger conditions (any):
- New user-facing command / flag / env var added.
- Install procedure changes.
- Breaking change to existing command (renamed / removed flag).
- Version bump affecting adopter upgrade path.
- Any change to README's Installation / Usage / Commands / Quick Start sections.

Draft one `<!-- section:readme-impact -->` block per affected README section:
- `target_section`: prose heading ("Installation", "Commands", etc.).
- `before` / `after`: current vs new prose.
- `rationale`: why.
- `entry_critical: true` if the change affects first-time adopter success (triggers cross-review enhanced audit at ship-review).

Schema: `entity-body-schema.yaml` → `readme-impact` block. Consumer: ship-review planner dispatch applies via Edit tool + explicit pathspec commit (README is prose-heavy, typically no section tags — DO NOT use patch-map.sh).

Skip when: pitch is pure internal refactor, bug fix, or infrastructure (no user-facing surface change).

### Compose + present proposal

**Fat-marker-sketch rule**: Children are titles, not specs. Stated assumptions are claims + confidence + criticality + `verified_by`, not verification RESULTS. DCs, tool choices, file paths, greppable queries, npm-dep choices, LOC estimates all belong to PLAN. If a child description exceeds one line of vertical-slice intent, or if an assumption reproduces verification output, delete detail and keep the claim.

ONE block — captain's only view until gate:

```
Pitch proposal: <title>

Problem:
<1-3 sentences — gap, who feels it, why now. No solution language.>

Appetite: <small-batch | medium-batch | big-batch> (<concrete time budget>)

Children (N, each vertical E2E that ships standalone):
  <id>.1 — <title> (deps: none)
  <id>.2 — <title> (deps: <parent-slug>)

Rabbit holes (auto-captured to docs/<wf>/todos/ on confirm):
  - <one-line>

Rejected alternatives (NOT captured — rationale for the record):
  - <claim> — <reason>

Stated assumptions:
  A1 (critical, <conf>%): <claim>

DAG:
```mermaid
graph LR
  A[<child-1>] --> B[<child-2>]
```

Confirm / refine: "<text>" / reject ?
```

Mermaid fence MUST start with `graph` (shape-confirm.sh requires it).

### Cross-review gate (before captain gate) — Principle 6 Rule C

Dispatch cross-review to `executer` teammate. **Reviewer model fallback when no team**: fresh **sonnet** by default; upgrade to fresh **opus** when `appetite: big-batch` (scope warrants heavier independent review). Apply the 5-factor rubric (**feasibility** appetite-fit within budget / **executable scope** true E2E vertical / **quality** rejected alternatives ≥1 + critical assumption ≥1 + appetite-fit check ran / **DC adequacy** observable done-checks / **canonical sync** architecture-impact block when ARCHITECTURE.md affected), rating each PASS/WARN/FAIL, then emit verdict: **PROCEED** → present to captain; **VETO** → silently loop to scope-decompose with feedback; **PROMPT_CAPTAIN** → present proposal + reviewer concern together.

**Proposal budget**: the proposal text passed to the cross-reviewer MUST be ≤400 words. Longer = detail creep; trim BEFORE dispatching cross-review, not after.

**Circuit breaker**: if the cross-review teammate is unresponsive (phantom team / SendMessage timeout / fresh-Agent stall), fall back per INVARIANTS Rule A Fallback — fresh sonnet by default, fresh opus when `appetite: big-batch`. Do not block on an unresponsive reviewer.

---

## Mode B — Interactive Q-loop (Layer A exception)

**Trigger**: `/shape --discuss "<text>"` OR auto-routed when L0 returns ≥3 `open_questions`.

**Delegation**: `superpowers:brainstorming` owns the HARD-GATE Q-loop. Do NOT re-teach.

**Flow**: announce mode → `Skill: superpowers:brainstorming` → on completion apply Mode A Layer B wrap on the brainstorm report (appetite + vertical-slice decompose + appetite-fit check + ≥1 critical assumption + DAG + architecture-impact if needed). Rejected-alternatives populate from brainstorming's Q-loop considered-then-dropped branches. → cross-review gate → present proposal → captain gate.

Exception rationale: brainstorming's Q-loop handles discovery; Shape Up framing (appetite/DAG/deletes/assumptions) is Layer B, not in superpowers.

## Mode C — Skill-authoring (Layer A exception)

**Trigger**: keywords / path patterns / frontmatter (see Mode auto-routing §1).

**Delegation**: `superpowers:writing-skills` owns skill design + claude 4.7 knowledge + RED/GREEN/REFACTOR + frontmatter discipline. Do NOT re-teach.

**Flow**: announce mode → `Skill: superpowers:writing-skills` → on completion apply Layer B wrap: appetite (`small-batch` single SKILL.md / `medium-batch` multi-file); **children = 1 per SKILL.md (default)**; decompose into ≥2 children ONLY when (a) design spans **different SKILL.md files** OR (b) supporting **scripts/tests need separate landing** than the skill (e.g., lib script lands before skill references it). Assumptions extracted from writing-skills invariants (frontmatter valid, description matches trigger, etc.), ≥1 critical. Architecture-impact only if new skill reshapes plugin structure. Cross-review gate → present proposal → captain gate.

Exception rationale: skill design + 4.7 knowledge is writing-skills' domain; Shape Up framing is Layer B.

---

## Captain response (all modes)

### Confirm

1. **Allocate IDs** (MEMORY #5 — `--next-id` non-atomic; this → commit = ONE uninterrupted pair):
   ```bash
   python3 "$SPACEDOCK_PLUGIN_DIR/skills/commission/bin/status" --workflow-dir "$WORKFLOW_DIR" --next-id
   ```
   First ID = pitch. Child IDs = `<pitch-id>.N` (dense, no gaps).

2. **Serialize → temp JSON → invoke atomic writer:**
   ```bash
   bash plugins/ship-flow/lib/shape-confirm.sh --proposal="$PROPOSAL_JSON" --layout=folder --workflow-dir="$WORKFLOW_DIR"
   ```
   `--layout=folder` (default for new pitches) writes `docs/<wf>/<id>-<slug>/README.md` + `spec.md`. **Wave 5 dependency of entity #085**: the `--layout=folder` flag lands in Wave 5; until then flat layout is operational fallback.

3. **Report**: 1 pitch (folder) + N shaped-children + M rabbit-hole todos + ROADMAP.md rows, ONE commit SHA.

### Refine / Reject

**Refine** — re-run research + decompose with refinement appended (lean re-run; don't diff-patch). Max 2 rounds; then ask: refine / save draft / reject. **Reject** — do NOT invoke shape-confirm.sh; verify `git status --short` clean; emit `Pitch rejected. No files written.` and EXIT.

---

## Named-teammate spawn (Principle 6 Rule A)

On **first** `/shape` of a new pitch, spawn team so `/ship` / `/verify` reuse hot context. **Default**: `planner` (opus) + `executer` (sonnet) + `verifier` (opus or sonnet by pitch size).

```
TeamCreate(team_name: "pitch-<id>", members: ["planner", "executer", "verifier"])
Agent(team_name: "pitch-<id>", name: "planner", model: "opus", task: "Planner for pitch-<id>. Read docs/<wf>/<id>-<slug>/spec.md.")
Agent(team_name: "pitch-<id>", name: "executer", model: "sonnet", task: "Executer for pitch-<id>. Atomic commits, DC-first.")
SendMessage(to: "planner", body: "Proceed to /plan for pitch-<id>. Read spec.md; output plan.md.")
```

Stage continuation — SendMessage to named teammate (~10× faster than fresh dispatch). **Fresh-subagent reserved for Rule A exceptions**: (a) adversarial review across teammates; (b) clearly separate domain; (c) explicit captain request; (d) cross-review gate between stages.

---

## Proposal JSON schema (machine contract for shape-confirm.sh)

Top-level keys: `pitch` (with `id`, `slug` kebab ≤40, `title`, `problem`, `appetite`, `stated_assumptions[]`, `dag_mermaid` — first line MUST start with `graph`), `children[]` (`id` = `<pitch.id>.<N>` dense no gaps, `slug`, `title`, `vertical_slice`, `depends_on[]` via child **slugs**), `rabbit_holes[]` (`slug`, `claim`, `domain`, `guess_files[]`), `deleted_from_shape[]` (`claim`, `reason` — semantically "rejected alternatives"; SHOULD have ≥1 on non-trivial pitch; empty = captain may have under-shaped, warrants cross-review PROMPT_CAPTAIN). `stated_assumptions[]` item: `id`, `claim`, `verified_by` (`codebase-grep | lib-docs | web-search | design-contract | skill-source-read`), `verification` (bash), `confidence_at_shape` (0-100), `criticality` (`critical | important | nice-to-know`) — MUST have ≥1 `critical`. Full semantics: `plugins/ship-flow/references/entity-body-schema.yaml`.

---

## Invariants + red flags (STOP and rerun if violated)

- Rejected alternative ≥1 on non-trivial pitch; ≥1 critical assumption; appetite is budget not estimate; **appetite-fit check ran before compose** (scope cap enforcement).
- Children = vertical E2E; all-API / all-UI / every-depends-on-every = fake decomposition.
- Mode A: no multi-turn captain Qs before proposal. One intake clarification max → else route to Mode B.
- Atomic writes via `shape-confirm.sh` only; no direct entity/ROADMAP edits; no `-a`/`-A` staging.
- Proposal before L0 subagent returned → stale synthesis.
- Pitch moves ARCHITECTURE.md / PRODUCT.md / README.md without matching impact block (`architecture-impact` / `product-impact` / `readme-impact`) → silent drift at ship-review (planner dispatch has nothing to patch).
- Within-pitch stage transition via fresh-subagent without (a/b/c/d) exception → Rule A violation.
- Mode B/C re-teaches Layer A procedure → Rule B violation.
- `--next-id` → `shape-confirm.sh` commit = ONE uninterrupted pair (MEMORY #5).
- Reject → zero files (verify `git status` clean).
- Explicit pathspec on manual commit (MEMORY #14/#25/#37): `git add <path> && git commit ... -- <path>`.
- **Worktree-first** (MEMORY #25): at `shape-confirm.sh` invocation time, `git rev-parse --absolute-git-dir` MUST resolve under `.claude/worktrees/` (not the repo's main `.git/`). On main tip → HALT, spawn worktree via Claude Code `EnterWorktree` (or `git worktree add .claude/worktrees/shape-<id>-<slug> -b worktree-shape-<id>-<slug>` manually) before running confirm path. Rationale: pathspec-lock is necessary but NOT sufficient under parallel-session contention.
- Child description >20 words → PLAN creep, trim to title + 1-line vertical-slice note.
- Compose proposal >500 words → detail creep, re-read fat-marker-sketch rule and delete detail, not scope.
- Assumption block reproduces raw grep/read output → Gap C violation, move to plan-stage research.

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml`.
- Atomic writer: `plugins/ship-flow/lib/shape-confirm.sh` (`--layout=folder` lands Wave 5 of #085).
- Rabbit-hole capture: `plugins/ship-flow/skills/add-todos/SKILL.md`.
- Architecture-canon mod: `docs/ship-flow/_mods/architecture-canon.md`.
- Layer A: `superpowers:brainstorming` (Mode B), `superpowers:writing-skills` (Mode C).
- Principle 6: `plugins/ship-flow/INVARIANTS.md` (context continuity + 3-layer architecture + cross-review).
- MEMORY: #5, #14, #25, #30, #35 (amended by Principle 6 Rule A), #37, opus-4.7-naturally-does (2026-04-23 harness diet).
