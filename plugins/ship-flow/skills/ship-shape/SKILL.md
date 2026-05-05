---
name: ship-shape
description: "Use when shaping vague, complex, or ambiguous ship-flow requests into a Shape Up pitch, including `/shape`, discussion, or skill-authoring work."
user-invocable: true
argument-hint: "[--discuss] [directive-text | todo-tid | entity-id]"
---

# Ship-Shape — SHAPE Stage (2.0)

You run SHAPE. Output: `docs/<wf>/<id>-<slug>/shape.md`. Captain has ONE gate per run: confirm / refine / reject.

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
| Entity id | matches `docs/<wf>/<id>-<slug>.md` OR `docs/<wf>/<id>-<slug>/index.md` | read entity; use title + body |

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

### Canonical context preflight

Before composing the final proposal, read the repo-root control-plane docs:

- `ROADMAP.md` — Now/Next/Later/Shipped context, dependencies, related work,
  and follow-up pressure.
- `PRODUCT.md` — product promise, capabilities, user stories, constraints,
  "Who It Serves", and "Why It Exists".
- `ARCHITECTURE.md` — only the relevant sections when the pitch touches
  schema/API/domain/data-flow/component boundaries/storage/runtime contracts, or
  when L0/debrief-read surfaces architecture drift.

Record the result in the shape output as canonical intent:

- emit architecture-impact when the pitch changes durable system structure,
  data flow, domain boundary, API/storage contract, or ADR-worthy constraint;
- emit product-impact when the pitch changes durable product capability, user
  story, or constraint;
- otherwise record a short skip rationale for `PRODUCT.md` and
  `ARCHITECTURE.md` so downstream stages know the omission was deliberate.

Do not patch canonical docs during shape. Shape owns intent and captain approval;
ship-review owns atomic writes after verify PASS.

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

#### Layer 1 — Outcome Card (captain-facing, ≤150 words)

The captain's gate surface. Structure (present in this order after section-order randomization — see below):

**`### Will get`** — JTBD-form bullets only. Each bullet MUST use `When [situation], [actor] can [verb] [object]` form. Each bullet MUST carry a `(Check: ...)` annotation referencing the paired `**W<n>**:` line in Layer 2 `### Will-get dogfood checks`. No output descriptions ("X surfaces") — those are not outcomes. **C6 enforcement**: every `**W<n>**:` bullet in `### Will get` must have a matching `**W<n>**:` line in Layer 2 `### Will-get dogfood checks` or gate hard-blocks.

**`### Won't get`** — explicit no-gos: things a rational captain might assume we'd do but won't. Author judgment, no grep enforcement. At least 1 item on non-trivial pitches.

**`### Why this scope`** — one trade-off line naming the rejected alternative and why. Emit only when appetite/surface divergence is non-trivial. Trivial pitches (escape-hatch threshold) omit this line.

**`### Captain Bet (mandatory before approve)`** — captain-authored substance commitment. Template:
`Bet: when this ships, captain expects [observable outcome] within [time window]. If not, this pitch was wrong about [Layer 1 line].`
Agent MUST NOT draft and present a filled-in Bet for captain to rubber-stamp. Agent presents the template; captain fills it in. Bet line is always last in Layer 1 (not shuffled). **C7 enforcement**: Layer 1 MUST NOT contain `rubric`, `7-factor`, or `score` tokens or gate hard-blocks.

**Section-order randomization**: at compose time, shuffle the order of `### Will get`, `### Won't get`, `### Why this scope` using a per-gate seed (e.g., sha256 of entity-id + gate-timestamp, take last 4 hex digits mod 6 for permutation index). `### Captain Bet` is always last — not shuffled. Purpose: defeats agent-pattern-match templating across gates, where agent learns "Will get always first → approve on structure".

#### Layer 2 — Detail (drill-down on captain `expand <section>` request)

Not auto-expanded. Captain must explicitly type `expand <section>` to receive it. Includes: pre-mortem, cross-review rubric score, PM artifacts, `### Will-get dogfood checks` (paired W<n> checks), problem evidence, assumptions, rejected alternatives, open questions. Agent presents Layer 1 only at gate; Layer 2 is available on request.

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

#### ASCII DAG for chat presentation (captain UX)

When presenting the captain gate proposal IN CHAT, render the DAG as an **ASCII art diagram** (boxes + arrows), NOT mermaid. Mermaid renders only in artifacts (`shape.md`, plan.md), not in the captain's terminal. Captain UX preference (codified 2026-04-29 during pitch-108 shape session): "ASCII for chat, mermaid for files."

Pattern:
```
┌──────────────────────┐         ┌──────────────────────┐
│ <id>.1               │ ──────▶ │ <id>.2               │
│ <slug>               │ depends │ <slug>               │
│ ~<estimate>d         │   on    │ ~<estimate>d         │
│                      │         │                      │
│ • bullet 1           │         │ • bullet 1           │
│ • bullet 2           │         │ • bullet 2           │
│                      │         │                      │
│ DC: <one-liner>      │         │ DC: <one-liner>      │
└──────────────────────┘         └──────────────────────┘
   Wave 1 (foundation)              Wave 2 (verifier)
```

For 3+ children with branches, use:
```
                 ┌──────────┐
              ┌─▶│ <id>.2   │
              │  └──────────┘
┌──────────┐  │
│ <id>.1   │──┤
└──────────┘  │
              │  ┌──────────┐
              └─▶│ <id>.3   │
                 └──────────┘
```

The artifact (`shape.md` / plan.md / index.md) ALWAYS uses mermaid — `shape-confirm.sh` parses mermaid and `dag_mermaid` field in proposal JSON requires mermaid syntax. ASCII is a chat-only render.

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
   `--layout=folder` (default for new pitches) writes `docs/<wf>/<id>-<slug>/index.md` + `shape.md`.

3. **Report**: 1 pitch (folder) + N shaped-children + M rabbit-hole todos + ROADMAP.md rows, ONE commit SHA.

4. **Captain Bet capture** (mandatory on non-trivial pitches before presenting Layer 1):

   Before presenting Layer 1 to captain, verify `### Captain Bet` template line is present in the Layer 1 draft. Gate refuses to advance if Bet line still contains unfilled template placeholders (`[observable outcome]`, `[time window]`, `[Layer 1 line]` verbatim) — those are signals that agent drafted it and captain hasn't committed.

   After captain approves and fills in the Bet line, copy the captain-authored Bet verbatim into the entity body under `## Captain Bet (gate approval <YYYY-MM-DD>)` block. Captain MAY edit any agent-drafted Layer 1 bullet inline, but the Bet line MUST be captain-authored — agent cannot draft a filled-in Bet and then captain rubber-stamp it.

   **Retro prompt** (re-read at ship + 2 weeks): "Did the Bet match outcome? YES / NO / PARTIAL. If NO: which Layer 1 line was wrong?" Track match rate across pitches — 3 consecutive Bet ≠ Outcome retros trigger the kill criterion (freeze format rollout, re-shape entity 109's successor).

   Skip when: escape-hatch (directive <80 chars AND fix/typo/rename/bump/patch/bugfix/hotfix). Otherwise mandatory.

### Refine / Reject

**Refine** — re-run research + decompose with refinement appended (lean re-run; don't diff-patch). Max 2 rounds; then ask: refine / save draft / reject. **Reject** — do NOT invoke shape-confirm.sh; verify `git status --short` clean; emit `Pitch rejected. No files written.` and EXIT.

---

## Named-teammate spawn (Principle 6 Rule A)

On **first** `/shape` of a new pitch, spawn team so `/ship` / `/verify` reuse hot context. **Default**: `planner` (opus) + `executer` (sonnet) + `verifier` (opus or sonnet by pitch size). **When pitch trigger fires `affects_ui:true OR domain: OR design_required:true OR contract_decision_required:true OR file globs *.tsx|*.css|*.html OR explicit --design flag`, also spawn `designer` (opus) — gates the conditional `design` stage between shape and plan.**

```
# Default spawn (all pitches) — every named teammate is a spacedock:ensign unit (canonical worker primitive):
TeamCreate(team_name: "pitch-<id>", members: ["planner", "executer", "verifier"])
Agent(subagent_type: "spacedock:ensign", team_name: "pitch-<id>", name: "planner", model: "opus", task: "Planner for pitch-<id>. Resolve the shape artifact with plugins/ship-flow/lib/resolve-shape-artifact.sh; read canonical shape.md or legacy shape.md fallback.")
Agent(subagent_type: "spacedock:ensign", team_name: "pitch-<id>", name: "executer", model: "sonnet", task: "Executer for pitch-<id>. Atomic commits, DC-first.")
# Conditional spawn — when design-trigger fires (affects_ui:true OR domain: OR design_required:true OR contract_decision_required:true OR *.tsx|*.css|*.html glob OR --design flag):
Agent(subagent_type: "spacedock:ensign", team_name: "pitch-<id>", name: "designer", model: "opus", task: "Designer for pitch-<id>. Resolve the shape artifact with plugins/ship-flow/lib/resolve-shape-artifact.sh; route Category 0/A/B/C/D and registered domain lanes; emit design.md plus the narrow artifact bundle required by the selected design-dispatch-manifest.")
SendMessage(to: "planner", body: "Proceed to /plan for pitch-<id>. Resolve the shape artifact with plugins/ship-flow/lib/resolve-shape-artifact.sh; output plan.md.")
```

**Conditional design-stage trigger** (FO check, runs after shape-confirm.sh):
- `affects_ui:true` field set in entity frontmatter (sharp-stage-set; default false), OR
- `domain:` field set in entity frontmatter (sharp-stage-set via registry-classify; default unset), OR
- `design_required:true` field set in entity frontmatter for schema/API/domain/architecture contract impact, OR
- `contract_decision_required:true` field set in entity frontmatter because `open_contract_decisions[]` is non-empty, OR
- any `Files modified` or `architecture-impact` block citing path matching glob `*.tsx | *.css | *.html`, OR
- captain explicit `--design` flag on `/shape` invocation.

When ANY trigger fires, FO advances entity to `design` stage (skill: `ship-flow:ship-design`); otherwise auto-skip to `plan` per `skip-when: "!affects_ui && !domain && !design_required && !contract_decision_required"` README.md state declaration. Run `## Phase 8.5 — Domain Registry Validation` before evaluating this condition so non-UI domains are not skipped because `domain:` was never recorded.

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
- `open_contract_decisions[]`: unresolved non-UI contract/interface choices from spec or issue text. Emit this whenever there are 2+ viable semantics and planner must not choose silently. Examples: selector grammar (`find role <r> --name "<v>"` vs CSS attributes vs `{role,name}` object), API vocabulary, tool protocol, DSL syntax, schema/message format, mapper→native boundary contract.
- `pm_framing_output`: reference to problem-framing-canvas or press-release artifact path if run in shape

If `open_contract_decisions[]` is non-empty, set `contract_decision_required: true` in entity frontmatter and advance to design even when `affects_ui: false` and no domain registry exists. The design stage owns the trade-off table and captain decision; plan must not self-select the canonical grammar/protocol/schema/API vocabulary.

If `affects_ui: false` in entity frontmatter → omit `ui_surfaces` and `framework_detected`; set `open_design_questions: []` unless the entity has non-UI contract/interface ambiguity, in which case emit `open_contract_decisions[]`.

**Design-skipped passthrough** (G14 amended by contract-design gate): skip only when `affects_ui: false` AND `domain:` unset AND `design_required: false` AND `contract_decision_required: false`. If any is set, emit standard `### Hand-off to Design` and advance to design stage.

When `affects_ui: false` AND `domain:` is unset AND `design_required: false` AND `contract_decision_required: false` → omit `ui_surfaces` and `framework_detected`; set `open_design_questions: []`; set `open_contract_decisions: []`; emit stub `### Hand-off to Plan` with `design-skipped: true` (single field). Rationale: plan Step 1.6 reads `### Hand-off to Plan` to decide whether to import design DCs. Absence of the block is ambiguous (design halted? design errored? affects_ui=false?). Explicit `design-skipped: true` lets plan distinguish "design intentionally bypassed" from "block missing — error". Validated by `check-invariants.sh --check plan-imported-design-dcs-emitted`.

## Phase 8.5 — Domain Registry Validation

After spec is composed (or post-shape-confirm if pre-existing spec), run or instruct the shape worker to run domain classification once whenever the pitch may touch non-UI domains such as schema, saga, RBAC, permissions, data model, migrations, storage, API contract, or workflow runtime:

Before classification, check whether adopter routing exists:

```bash
test -f .claude/ship-flow/domains.yaml
test -f .claude/ship-flow/skill-routing.yaml
```

If `.claude/ship-flow/skill-routing.yaml` is missing, run:

```bash
bash plugins/ship-flow/lib/discover-adopter-skills.sh --root=.
```

Present the discovered routing draft to the captain and record it in
`### Project Skills` when accepted. Missing routing is not a hard block for
small fixes, but non-trivial multi-surface pitches MUST surface the gap before
plan so planner does not collapse adopter-specific skills into generic
`project-db` / `fmodel` defaults.

```bash
bash plugins/ship-flow/lib/registry-resolve.sh --classify <spec-or-entity-file>
```

Branch on output:
- `status=ok` + non-empty `matched=<domain>` → set `domain: <name>` in entity frontmatter at shape stage (single-domain match). Advance entity to design stage via standard Hand-off to Design path.
- `status=partial_coverage` + `matched=<dom-list>` + `missing=<dom-list>` → set `domain: <name>` to the first matched domain at shape stage; emit `## Domain Classification Report` block listing partial coverage (ship-design router will surface partial-coverage annotation).
- `status=ok` + empty `matched=` → no domain match; do NOT set `domain:` (UI-only or no-trigger path proceeds as before).
- `status=parse_error` / `invalid_trigger_config` (M4 exit 20 / M5 exit 21) → fail loud per INVARIANTS Principle 9; BLOCK shape. Do not proceed to design or plan.

If captain/shape explicitly specifies a `domain:` value before or during shape, validate that value before the shape gate:

```bash
bash plugins/ship-flow/lib/registry-resolve.sh --validate --domain=<domain>
```

Branch on validation output:
- `status=ok` → preserve `domain: <name>` in entity frontmatter and continue to design hand-off.
- `status=specialist_missing` (M1), `status=knowledge_module_missing` (M2), `status=parse_error` (M4), or `status=invalid_trigger_config` (M5) → BLOCK at shape gate with `HALT-with-options`; do not push ambiguity downstream to design.

Shape output/frontmatter evidence MUST include a grep-friendly `Domain Registry Validation` block:

```text
## Domain Registry Validation
- classify: bash plugins/ship-flow/lib/registry-resolve.sh --classify <spec-or-entity-file>
- validate: bash plugins/ship-flow/lib/registry-resolve.sh --validate --domain=<domain>
- domain: <name>
- result: proceed | HALT-with-options
```

For blocked validation, `HALT-with-options` must name the registry status and offer the same captain-visible choices design uses as second-line defense: `skip`, `generalist-marker`, or `file-specialist-first`. Preserve ship-design HALT behavior; shape-time validation catches the problem earlier, design remains the second line of defense.

If a later rerun or downstream design-stage validation supersedes a stale shape HALT (for example, `knowledge_module_missing` from an old plugin cache, then current registry validation returns `status=ok`), do not delete the original evidence. The downstream artifact MUST add a grep-friendly resolution block:

```text
### Registry Validation Resolution
- prior_result: <shape status/result>
- current_result: ok
- resolution: superseded_by_design_stage_validation
- reason: <specialist/knowledge module now present, or adopter config corrected>
```

Plan stage consumes the latest resolved registry result only when this resolution block is present; otherwise a shape `HALT-with-options` remains blocking evidence.

Multi-domain match disambiguation v1: pick `matched[0]` (first registered domain name). v2 multi-domain dispatch is out of 113.1 scope.
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
