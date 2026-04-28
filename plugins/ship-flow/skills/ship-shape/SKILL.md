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

## Boot Self-Check

Run before any shape work. Stop and SendMessage(FO) if any check fails.

1. **Entity intake**: directive is non-empty. If empty → SendMessage(FO): "Empty directive — provide problem statement or todo-tid."
2. **Mode routing**: apply escape hatch rules and Mode C/B/A routing before proceeding to shape flow.
3. **WORKFLOW_DIR**: verify `$WORKFLOW_DIR` resolves to a readable `docs/ship-flow/` (or equivalent). If unset → SendMessage(FO): "WORKFLOW_DIR unset — cannot locate entity folder."
4. **Team spawn**: confirm `planner` and `executer` teammate slots available for this pitch. If TeamCreate fails → note fallback per Principle 6 Rule A Fallback.
5. **Density-aware skill load** (T3.4): read `answers_density` from entity frontmatter. `high` → auto-load framework skills per ship-runtime-detect Step R6; skip FO ask. `low|vacuum` → SendMessage(FO) with proposed skill list; wait for confirmation.

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
- **L0 debrief-read** — read `docs/<wf>/_debriefs/*.md` (most recent 3-5 files) for `recent_warnings[]`: issues from `## Issues — Workflow` / `## Issues — Spacedock`, D2-candidates from `## Filed (backlog)`. Schema: `plugins/ship-flow/references/debrief-schema.yaml`. Surface any warning directly relevant to the current shape's domain into `open_questions[]`.
- **L1 library** — inline via trained knowledge / Context7. Subagent only for wide API surface.
- **L2 web** — 1-2 `WebSearch` queries only when L0+L1 leave a load-bearing claim unresolved. Usually skip.

RULE: L0 via fresh subagent is non-negotiable. Opus 4.7 handles the rest naturally — don't over-teach.

### Scope discipline: appetite, decompose, assumptions

**Appetite is a budget (not estimate)**: pick `small-batch` (2-3d, 1-3 children) / `medium-batch` (1-2w, 3-6 children) / `big-batch` (6w classic, 5-10 children). Scope fits budget; budget does not stretch. Exceeds big-batch → flag `[EPIC?]`, recommend sub-pitch.

**Vertical-slice children**: each child ships E2E standalone. "all-API" / "all-UI" / "every-depends-on-every" = fake decomposition → re-cut.

**Rejected alternatives** → `deleted_from_shape[]` (field name retained for shape-confirm.sh compat; semantics = "considered but not in scope"). Populate from: (a) brainstorming Q-loop's considered-then-rejected branches, (b) intake clarification (captain said A → rejected B), (c) scope-cut during decompose (feature trimmed to fit appetite). "Worth doing eventually" → `rabbit_holes[]` instead. Musk 5-step procedure intentionally NOT enforced (opus-4.7-naturally-does, MEMORY 2026-04-23); scope protection comes from the appetite-fit check below, not from a forced-delete ritual.

**Assumptions**: emit `stated_assumption` per load-bearing claim (schema: `plugins/ship-flow/references/entity-body-schema.yaml`). Surface any `recent_warnings[]` from `_debriefs/` debrief-read as `criticality: moderate` assumptions when they affect the current domain. **Mandatory**: ≥1 `criticality: critical`. Run each critical's verification now (30s soft cap); record resolved confidence in `confidence_at_shape`. **Do NOT reproduce verification output in the proposal** — `verified_by` + bumped `confidence_at_shape` is the full trace. Raw grep/read results belong to plan-stage research, not shape-stage proposal.

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

### Density classification (preflight)

Run before composing the proposal:

```bash
bash plugins/ship-flow/lib/density-classify.sh --entity=<path-to-index.md>
```

Output: `high | medium | low | vacuum`. Include as `answers_density` in the proposal JSON pitch block (see schema below). FO uses this to auto-proceed without captain gate when `high`. Skip when entity index does not yet exist (first-time shape of a directive).

### PM-Skill Framing (Mode A Layer A — per phase)

PM skills delegate framing discipline so shape stage doesn't reinvent. Invoke per phase when directive is non-trivial (>80 chars AND not fix/typo/rename/bump/patch/bugfix/hotfix). Skip individual skills with documented rationale; do NOT skip the table wholesale.

| Shape phase | Primary delegate | Supplement (optional) | Feeds proposal field |
|---|---|---|---|
| Intake — Problem statement | `Skill: problem-framing-canvas` | `Skill: jobs-to-be-done` (when directive lacks user-context — "who hires this for what job") | `Problem:` |
| Scope decompose — vertical-slice cuts | `Skill: opportunity-solution-tree` | `Skill: user-story-splitting` (9 splitting heuristics — workflow steps / business rules / data variations / interface options) | `Children:` + `Rejected alternatives:` |
| Assumption extract — criticality filter | `Skill: pol-probe-advisor` (Point of Leverage — "which assumption, if wrong, collapses the pitch?") | — | `stated_assumptions[]` with `criticality: critical` |
| Acceptance outcome — user-observable | `Skill: press-release` | `Skill: user-story` (As-a/I-want/So-that structural backup) | `Acceptance Outcome:` |

**Why per-phase delegation, not single pre-compose pass**: previously these skills ran once before compose, so `criticality: critical` filtering happened in LLM head (no POL probe), `Children:` cuts used opus 4.7 default heuristics (not splitting-heuristics catalog), and `Problem:` was framed without JTBD's "replaces what" lens. Per-phase delegation forces each framing artifact through a named methodology, not "LLM looked thorough."

**Skip rules** (per skill, document in proposal `## Shape Report`):
- Skill not installed → fallback inline (note `Layer A delegate <name> unavailable`).
- `--fast` flag → skip all PM framing (escape hatch for tiny pitches).
- Directive <80 chars OR matches fix/typo/rename/bump/patch/bugfix/hotfix → escape-hatch path; skip PM framing.

**Mandatory (cannot skip)**: `pol-probe-advisor` for any pitch with `appetite: medium-batch | big-batch`. Critical-assumption misfiltering was pitch-103's 18-file/3641-LOC drift root cause; POL probe is the structural guard against `criticality: critical` decaying into `important`.

### Compose + present proposal

**Fat-marker-sketch rule**: Children are titles, not specs. Stated assumptions are claims + confidence + criticality + `verified_by`, not verification RESULTS. DCs, tool choices, file paths, greppable queries, npm-dep choices, LOC estimates all belong to PLAN. If a child description exceeds one line of vertical-slice intent, or if an assumption reproduces verification output, delete detail and keep the claim. Acceptance outcome MUST be user-observable (what captain receives) — NOT artifact list / infrastructure description / "support for X". One captain-readable claim per pitch.

ONE block — captain's only view until gate:

```
Pitch proposal: <title>

Problem:
<1-3 sentences — gap, who feels it, why now. No solution language.>

Acceptance Outcome (what the captain GETS when this ships — user-observable):
<1-3 sentences. NO internal artifacts. NO "infrastructure for X". Anchor for confirm/refine.>

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

Pre-mortem (1 sentence, ≤30 words; pick exactly one category):
  <category>: <projected failure mode if pitch ships per spec but doesn't deliver value>

DAG:
```mermaid
graph LR
  A[<child-1>] --> B[<child-2>]
```

Confirm / refine: "<text>" / reject ?
```

Mermaid fence MUST start with `graph` (shape-confirm.sh requires it).

### Pre-mortem (mandatory on non-trivial pitch; before cross-review)

After composing the proposal, write **one sentence** answering: "If this pitch ships exactly per spec but post-ship inspection finds it isn't delivering value, what's the single most likely cause?" Append as `pre_mortem` (1 sentence, ≤30 words; pick **exactly one** category):

- **wrong-problem** — acceptance outcome solved, but problem misframed (solving the wrong gap).
- **wrong-dcs** — children pass verify but their aggregate doesn't deliver the acceptance outcome (vanity DCs).
- **wrong-framing-lens** — engineering decomposition applied to a relational / aesthetic / macro problem; Musk-lens mismatch (route to Naval / Buffett / Covey / Feynman / Dalio context next time).
- **hidden-dependency** — load-bearing assumption stayed implicit (never made it to `stated_assumptions[]`).
- **over-conviction** — proposal text contains "一定 / 顯然 / 必須 / clearly / obviously" without Loss Function check; captain bias signal per MEMORY Conviction Calibration.

**Skip-when**: same threshold as escape-hatch (directive <80 chars AND fix/typo/rename/bump/patch/bugfix/hotfix). Otherwise mandatory.

**Why this exists**: Cross-review uses the same 6-factor rubric the proposer used to compose. Both can miss the same blind spot (composing-rubric overlap). Pre-mortem forces a future-failure perspective the composing rubric cannot generate. The `over-conviction` category is the named hook for MEMORY's "一定 / 顯然 / 必須" signal — surfaces captain bias as a structural gate, not a vibe check.

### Cross-review gate (before captain gate) — Principle 6 Rule C

Dispatch cross-review to `executer` teammate. **Reviewer model fallback when no team**: fresh **sonnet** by default; upgrade to fresh **opus** when `appetite: big-batch` (scope warrants heavier independent review). Apply the 7-factor rubric (per INVARIANTS Principle 6 Rule C #106 T1.3 + pre-mortem extension): **feasibility** appetite-fit within budget / **executable scope** true E2E vertical / **quality** rejected alternatives ≥1 + critical assumption ≥1 + appetite-fit check ran / **DC adequacy** observable done-checks / **canonical sync** architecture-impact block when ARCHITECTURE.md affected / **Reverse-audit previous stage** (no prior stage at shape — ask: does the spec expose any design constraint the prior debrief flagged as a gap?) / **pre-mortem credibility** (does the named category match the most plausible failure mode? does the one-sentence projection survive a "wait, isn't X more likely?" challenge? rote-pick of `hidden-dependency` without supporting reasoning = WARN), rating each PASS/WARN/FAIL, then emit verdict: **PROCEED** → present to captain; **VETO** → silently loop to scope-decompose with feedback; **PROMPT_CAPTAIN** → present proposal + reviewer concern together.

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

On **first** `/shape` of a new pitch, spawn team so `/ship` / `/verify` reuse hot context. **Default**: `planner` (opus) + `executer` (sonnet) + `verifier` (opus or sonnet by pitch size). **When pitch trigger fires `affects_ui:true OR file globs *.tsx|*.css|*.html OR explicit --design flag`, also spawn `designer` (opus) — gates the conditional `design` stage between shape and plan.**

```
# Default spawn (all pitches) — every named teammate is a spacedock:ensign unit (canonical worker primitive):
TeamCreate(team_name: "pitch-<id>", members: ["planner", "executer", "verifier"])
Agent(subagent_type: "spacedock:ensign", team_name: "pitch-<id>", name: "planner", model: "opus", task: "Planner for pitch-<id>. Read docs/<wf>/<id>-<slug>/spec.md.")
Agent(subagent_type: "spacedock:ensign", team_name: "pitch-<id>", name: "executer", model: "sonnet", task: "Executer for pitch-<id>. Atomic commits, DC-first.")
# Conditional spawn — only when UI-trigger fires (affects_ui:true OR *.tsx|*.css|*.html glob OR --design flag):
Agent(subagent_type: "spacedock:ensign", team_name: "pitch-<id>", name: "designer", model: "opus", task: "Designer for pitch-<id>. Read spec.md; route Category 0/A/B/C/D; emit design.md + plugins/<app>/design/* on Category 0.")
SendMessage(to: "planner", body: "Proceed to /plan for pitch-<id>. Read spec.md; output plan.md.")
```

**Conditional design-stage trigger** (FO check, runs after shape-confirm.sh):
- `affects_ui:true` field set in entity frontmatter (sharp-stage-set; default false), OR
- any `Files modified` or `architecture-impact` block citing path matching glob `*.tsx | *.css | *.html`, OR
- captain explicit `--design` flag on `/shape` invocation.

When ANY trigger fires, FO advances entity to `design` stage (skill: `ship-flow:ship-design`); otherwise auto-skip to `plan` per `skip-when: "!affects_ui"` README.md state declaration.

Stage continuation — SendMessage to named teammate (~10× faster than fresh dispatch). **Fresh-subagent reserved for Rule A exceptions**: (a) adversarial review across teammates; (b) clearly separate domain; (c) explicit captain request; (d) cross-review gate between stages.

---

## Proposal JSON schema (machine contract for shape-confirm.sh)

Top-level keys: `pitch` (with `id`, `slug` kebab ≤40, `title`, `problem`, `acceptance_outcome` (≥50 chars, user-observable, mandatory), `appetite`, `stated_assumptions[]`, `dag_mermaid` — first line MUST start with `graph`, `pre_mortem` (mandatory on non-trivial pitch; object with `category` enum: `wrong-problem | wrong-dcs | wrong-framing-lens | hidden-dependency | over-conviction` and `one_liner` ≤30 words)), `children[]` (`id` = `<pitch.id>.<N>` dense no gaps, `slug`, `title`, `vertical_slice`, `depends_on[]` via child **slugs**), `rabbit_holes[]` (`slug`, `claim`, `domain`, `guess_files[]`), `deleted_from_shape[]` (`claim`, `reason` — semantically "rejected alternatives"; SHOULD have ≥1 on non-trivial pitch; empty = captain may have under-shaped, warrants cross-review PROMPT_CAPTAIN). `stated_assumptions[]` item: `id`, `claim`, `verified_by` (`codebase-grep | lib-docs | web-search | design-contract | skill-source-read`), `verification` (bash), `confidence_at_shape` (0-100), `criticality` (`critical | important | nice-to-know`) — MUST have ≥1 `critical`. Full semantics: `plugins/ship-flow/references/entity-body-schema.yaml`. `answers_density` (optional, `high | medium | low | vacuum`): emit when pre-classified; omit to defer lazy classification.

---

## Invariants + red flags (STOP and rerun if violated)

- Rejected alternative ≥1 on non-trivial pitch; ≥1 critical assumption; appetite is budget not estimate; **appetite-fit check ran before compose** (scope cap enforcement).
- **Pre-mortem mandatory on non-trivial pitch** (escape-hatch threshold — directive ≥80 chars OR not fix/typo/rename/bump/patch/bugfix/hotfix). Missing `pre_mortem` → cross-review VETO (loops to scope-decompose). Anchor: composing-rubric blind spot — proposer + reviewer share the 6-factor rubric, so pre-mortem provides an orthogonal future-failure axis the composing rubric cannot generate. Conviction Calibration tie-in: `over-conviction` category is the named hook for MEMORY "一定/顯然/必須" signal.
- Pitch missing `acceptance_outcome` OR <50 chars → silent foundation-only-ceremony risk; shape-confirm.sh rejects with exit 10. Source: pitch 096 demo (3 of 4 children would have shipped placeholder files nothing consumed).
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

<!-- section:hand_off_to_design -->
## Phase 8: Emit Hand-off to Design

After captain confirms the spec, write the `### Hand-off to Design` block in the entity body. This is the explicit hand-off consumed by the design stage Boot Self-Check.

Read the incoming hand-off from the prior stage (none for shape — this is stage 1).

Emit `### Hand-off to Design`:
- `ui_surfaces`: list visible UI surfaces inferred from spec (tabs, sidebars, buttons, forms)
- `framework_detected`: run `Skill: ship-flow:ship-runtime-detect` Step R5 → record `framework=X theme_indirection=Y design_canonical_dir=Z`
- `open_design_questions`: unresolved design decisions from spec Scope In (e.g., color tokens, layout choice)
- `pm_framing_output`: reference to problem-framing-canvas or press-release artifact path if run in shape

If `affects_ui: false` in entity frontmatter → omit `ui_surfaces` and `framework_detected`; set `open_design_questions: []`.
<!-- /section:hand_off_to_design -->

---

## References

- Entity schema: `plugins/ship-flow/references/entity-body-schema.yaml`.
- Atomic writer: `plugins/ship-flow/lib/shape-confirm.sh` (`--layout=folder` lands Wave 5 of #085).
- Rabbit-hole capture: `plugins/ship-flow/skills/add-todos/SKILL.md`.
- Architecture-canon mod: `docs/ship-flow/_mods/architecture-canon.md`.
- Layer A: `superpowers:brainstorming` (Mode B), `superpowers:writing-skills` (Mode C).
- Principle 6: `plugins/ship-flow/INVARIANTS.md` (context continuity + 3-layer architecture + cross-review).
- Hand-off schema: `plugins/ship-flow/references/entity-body-schema.yaml → stages.sharp.hand_off_to_design`.
- MEMORY: #5, #14, #25, #30, #35 (amended by Principle 6 Rule A), #37, opus-4.7-naturally-does (2026-04-23 harness diet).
