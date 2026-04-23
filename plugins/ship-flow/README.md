# Ship-Flow — Auditable Autonomous Workflow for Claude 4.7

A scaffolding plugin for captain-directed autonomous work across multi-stage pipelines. This README is written from claude 4.7's perspective — explaining **why** the flow is shaped this way, not how to use each skill (SKILL.md files document the how).

> **Canonical project-level operational doc** (how captain uses ship-flow in THIS project): `docs/ship-flow/README.md`.
> **This file**: plugin-level design rationale. Adopters + onboarding + future-me read this first.

---

## What ship-flow solves

I (claude 4.7) have 1M context + prompt cache. I don't need procedural teaching — I know how to research a codebase, decompose a problem via Musk's 5 steps, apply Shape Up appetite discipline, plan vertical E2E slices, execute atomic commits, verify via goal-backward DC, review my own work. The flow provides none of that teaching. It provides **scaffolding for auditable autonomous work** that I can't reliably produce from context alone:

- **Resumability across sessions** — work pauses (context reset, session end) and resumes cleanly via per-stage `.md` artifacts + entity frontmatter state. Without structured artifacts, resume-after-pause is lossy.
- **Delegation across teammates** — a pitch spans planner (opus) + executer (sonnet) + verifier (opus) named teammates. Named-teammate SendMessage preserves hot context (~10× ramp vs fresh subagent per Phase 2 evidence). The flow codifies who-owns-what per stage.
- **Auditability for other agents + humans** — each stage's `.md` artifact + entity body + cross-review gate verdict = reconstructable decision history. Captain (or another agent) can audit my work without reading code.
- **Canonical doc invariants** — ARCHITECTURE / PRODUCT / README / ROADMAP stay consistent with shipped work via atomic patch-map.sh CAS + named-teammate-dispatched updates at ship-review. Without this, canonical docs silently drift from implementation.
- **Principle enforcement** — CI grep checks (Principle 1-7) catch harness regressions (preamble regrowth, skill count bloat, stale line-anchors, etc.) before they decay the flow.

The flow does NOT teach me how to think. It keeps me honest across boundaries where I can't see the whole.

---

## Design principles (opus-4.7-era)

### 1. Opus-naturally-does vs load-bearing harness split

The primary design rule (MEMORY 2026-04-23 `opus-4.7-naturally-does-vs-load-bearing-harness`).

**Cut from harness** — what 4.7 does naturally when given a clean directive:
- Musk 5-step decomposition tables (I apply it when told to)
- Appetite sizing tables (I pick `small-batch | medium-batch | big-batch` from scope)
- L0/L1/L2 research procedure (I layer research naturally — codebase first, library if central, web only if unresolved)
- Self-audit questions (I self-audit goal-backward)
- Step-by-step research prompts for fresh subagents (I compose briefs)

**Keep in harness** — what 4.7 gets wrong without enforcement:
- Atomic commits with explicit pathspec (`-a` / `-A` sneaks in contamination under parallel-session load)
- Hash CAS via `patch-map.sh --if-hash` (prevents race with parallel canonical doc edits)
- Canonical sync timing (4 docs at ship-review, not each stage)
- Named-teammate SendMessage over fresh-subagent dispatch (4.7 defaults to fresh without the reminder)
- Grep-based invariant checks (CI catches drift 4.7 would miss in review)

Evidence: the #085 redesign cut stage-skill LOC from 2076 → 912 (-56%) while preserving behavior. The 1164 lines cut were mostly procedural teaching 4.7 does naturally.

### 2. Three-layer skill architecture (Principle 6 Rule B)

Each stage skill composes three layers:

- **Layer A — superpowers atomic skills**: my reasoning primitives. `superpowers:brainstorming` (Q-loop), `superpowers:writing-plans` (plan authoring discipline), `superpowers:writing-skills` (skill design + 4.7 knowledge), `superpowers:subagent-driven-development` (dispatch philosophy), `superpowers:verification-before-completion` (DC-based review).
- **Layer B — ship-flow augmentation**: Shape Up discipline (Musk ≥1 delete, appetite-not-estimate, ≥1 critical assumption, vertical E2E slices), cross-review gates (5-factor rubric), canonical doc sync timing.
- **Layer C — ship-flow canonical primitives**: `lib/extract-section.sh`, `lib/patch-map.sh`, `lib/write-stage-artifact.sh`, `lib/shape-confirm.sh`, `bin/check-invariants.sh`. Atomic + CAS + cross-platform.

Stage skills SHOULD delegate to Layer A for core logic. Exception clause: when Layer A's philosophy conflicts with stage requirement (e.g., ship-shape Mode A autonomous proposer vs brainstorming's Q-loop), stage owns orchestration and documents the exception inline.

### 3. Named-teammate-per-pitch (Principle 6 Rule A)

Default team per active pitch: `planner` (opus) + `executer` (sonnet) + `verifier` (opus). Stage transitions within a pitch use `SendMessage` to the named teammate. Fresh-subagent dispatch reserved for: adversarial review across teammates, clearly separate domain, explicit captain request, or cross-review gate between stages.

Why this matters: opus 4.7 with hot context ramps to work in ~5 min vs ~5K tokens of briefing for a fresh subagent. Over a pitch's lifecycle (5+ stage dispatches), cost differential is $1-2 per pitch; cumulative across projects is meaningful. More importantly, context continuity catches design intent drift that fresh-subagent-per-stage loses.

### 4. Auditable per-stage `.md` artifacts

Each stage writes its output to `<entity-folder>/{stage}.md` via `lib/write-stage-artifact.sh` (Layer C primitive — atomic commit with explicit pathspec, optional CAS via `--if-hash`). An auditor reads across `spec.md / plan.md / execute.md / verify.md / review.md / ship.md` + entity body to reconstruct decision history.

Entity folder layout (default for new pitches in 2.0):

```
docs/<wf>/<id>-<slug>/
  README.md    # entity metadata + stage-artifact links
  spec.md      # ship-shape — problem / appetite / children / DAG / assumptions / deletes / rabbit-holes
  plan.md      # ship-plan — task breakdown / verification spec / DC
  execute.md   # ship-execute — commits / files modified / UAT evidence
  verify.md    # ship-verify — quality gate / review findings / UAT / verdict
  review.md    # ship-review — PR draft / canonical docs diff citations / token summary
  ship.md      # ship-final — PR link / merge / deploy summary
```

Legacy flat entities (`docs/<wf>/<id>-<slug>.md`) continue to work; no migration required.

---

## The pipeline

```
captain intent (vague / concept / issue)
     │
     ▼
/shape → docs/<wf>/<id>-<slug>/spec.md + ROADMAP.md initial row
     │  (captain gate: confirm / refine / reject)
     ▼
/ship <id> dispatches via SendMessage to named teammates:
     │
     ├── ship-plan  (planner) → plan.md                 [cross-review gate]
     │     │
     ├── ship-execute (executer) → execute.md + commits [cross-review gate]
     │     │
     ├── ship-verify (verifier) → verify.md             [cross-review gate]
     │     │
     ├── ship-review (planner) → review.md              [cross-review gate]
     │       + 4-doc canonical dispatch (ARCH/PRODUCT/README/ROADMAP via planner)
     │     │
     └── ship-final → ship.md + gh pr create
           │
           ▼
     captain merge → pitch done, ROADMAP flip to shipped
```

**Captain-in-loop** only at: `/shape` confirm gate, `/verify` BLOCKING findings, PR merge, explicit captain interrupt. All other transitions are autonomous (FO Discipline in INVARIANTS.md).

**Cross-review gate** at every stage transition (Principle 6 Rule C): counterpart teammate (or fresh sonnet fallback; fresh opus when `appetite: big-batch`) evaluates the stage's output on a 5-factor rubric:

| Factor | Question |
|---|---|
| Feasibility | Is the output implementable within the pitch's appetite? |
| Executable scope | Does the work stay within the declared children / artifact boundaries? |
| Quality | Layer B invariants honored (Musk deletes, critical assumption, atomic commits, vertical slices)? |
| DC adequacy | Done criteria observable, not "works correctly" prose? |
| Canonical sync | ARCHITECTURE/PRODUCT/README/ROADMAP patches aggregated cleanly with CAS integrity? |

Verdict: `PROCEED` | `VETO` (feedback-to-upstream, ≤2 rounds) | `PROMPT_CAPTAIN`.

---

## Skill triggers

| Skill | Trigger pattern | Output artifact | Captain in loop? |
|---|---|---|---|
| `/shape "<directive>"` | vague / concept / issue / todo-tid / entity-id | `spec.md` (+ ROADMAP.md row) | ✅ confirm / refine / reject |
| `/shape --discuss "<text>"` | captain opts into Mode B | same, delegates Q-loop to `superpowers:brainstorming` | ✅ via brainstorming Q-loop |
| `/shape "<skill-auth>"` | keywords `create/build/write/improve a skill` / `SKILL.md` / path `*/skills/*` | same, delegates design to `superpowers:writing-skills` (Mode C auto-detect) | ✅ |
| `/ship <entity-id>` | sharp entity ready | per-stage `.md` + code commits + PR | ❌ (FO Discipline) |
| `/ship "<requirement>"` | free text | routes to `/shape` if vague | ✅ (if routed) |
| `/verify <entity-id>` | pipeline-dispatched OR standalone | `verify.md` | conditional — BLOCKING findings only |
| `/verify --fast` | captain manual fast-feedback | same, skips cross-review gate | ❌ |
| `/verify --full` | force full re-run UAT | same, fuller evidence | ❌ |
| `/add-todos "<text>"` | rabbit hole / unexpected finding capture | todo entry in `docs/<wf>/todos/<slug>.md` | ❌ |

**Escape hatches** built into /shape:
- Directive `<80 chars` + contains `fix|typo|rename|bump|patch|bugfix|hotfix` as whole word → announce "shape unnecessary, run /ship directly" and exit.
- Directive specifies concrete file paths / reproducible bug / typed acceptance → suggest `/ship <requirement>` path.

---

## Use cases

**Big feature (multi-child pitch)**:
```
captain: /shape "add comment threading to War Room"
me (Mode A): L0 research → 3 children vertical slices → pitch
captain: confirm
me: dispatch /ship <child-1>, /ship <child-2>, /ship <child-3> autonomously
```

**Bug fix (escape-hatch)**:
```
captain: /shape "fix null ptr in auth middleware src/auth/middleware.ts:47"
me: escape-hatch trigger — "shape unnecessary, run /ship <entity-id> after creating sharp entity"
(captain creates entity manually or via /add-todos → /ship <tid>)
```

**Skill authoring (Mode C auto-detect)**:
```
captain: /shape "create a skill that audits yaml files for security patterns"
me (Mode C auto): delegate design to superpowers:writing-skills, wrap with Shape Up (appetite = small-batch, 1 child, ≥1 critical assumption about yaml-parse library)
```

**Standalone verify (fast-feedback)**:
```
captain: /verify 078 --fast
me: scoped gate (surfaces execute touched) + spot-check ≤2 critical DCs, skip cross-review → verify.md
captain reviews → directs next action
```

**Todo promotion**:
```
(earlier) /add-todos "filter-chip-multi on dashboard feels sluggish"
(later) captain: /shape filter-chip-multi
me: read todo body as directive → Mode A pitch → children
```

---

## Named-teammate pattern

**Spawn at /shape confirm** (TeamCreate + Agent spawn):
```bash
# captain-side (or ship-shape on confirm):
TeamCreate(team_name: "pitch-<id>", agent_type: "planner")
Agent(name: "planner", team_name: "pitch-<id>", model: "opus", ...)
Agent(name: "executer", team_name: "pitch-<id>", model: "sonnet", ...)
Agent(name: "verifier", team_name: "pitch-<id>", model: "opus", ...)
```

**Reuse across stages via SendMessage** (no re-spawn, no fresh context):
```bash
# /ship dispatches plan stage:
SendMessage(to: "planner", message: "...plan brief...")
# planner continues from same context — hot ramp ~5 min

# /ship dispatches execute stage:
SendMessage(to: "executer", message: "...execute brief with plan.md link...")

# /ship dispatches verify stage:
SendMessage(to: "verifier", message: "...verify brief with execute.md...")
```

**Fresh-subagent dispatch** only when:
(a) adversarial review crossing teammate roles;
(b) clearly separate domain from pitch context;
(c) explicit captain request;
(d) cross-review gate counterpart (structured 5-factor prompt).

**Cross-review reviewer fallback** (Q1-answer codified):
- `sonnet` default.
- `opus` when `appetite: big-batch` — rigor scales with scope.

**Circuit breaker**: VETO loop max 2 rounds per stage → round 3 escalates PROMPT_CAPTAIN.

---

## For adopters

**Commissioning to a new repo**: use `/spacedock:commission` with `ship-flow` as template plugin. The commissioner scaffolds `docs/<wf>/README.md` with `entry-point:` frontmatter + creates initial `ARCHITECTURE.md`, `PRODUCT.md`, `ROADMAP.md` with section tags for `patch-map.sh`.

**Canonical docs section-tagging contract** (required for Layer C primitive compatibility):
```markdown
<!-- section:<tag> -->
## <Heading>
...content...
<!-- /section:<tag> -->
```
Tags declared in `references/flow-map-schema.yaml`. `lib/extract-map.sh` + `lib/patch-map.sh` operate on these atomically with `--if-hash` CAS.

**Layer C primitive inventory** (by responsibility):
| Primitive | Role |
|---|---|
| `lib/shape-confirm.sh` | entity folder initializer — writes spec.md + README.md + ROADMAP row atomically |
| `lib/write-stage-artifact.sh` | per-stage `{stage}.md` writer — wraps content in `<!-- section:<stage>-report -->` + atomic commit |
| `lib/extract-section.sh` | section-tag reader — preferred over direct `Read` on entity files (Principle 5a) |
| `lib/extract-map.sh` | canonical doc section reader (ARCHITECTURE/PRODUCT/ROADMAP) |
| `lib/patch-map.sh` | canonical doc section writer — atomic + `--if-hash` CAS + mermaid whitelist |
| `bin/check-invariants.sh` | CI grep enforcement of Principles 1-7 + stage-artifact-path / layer-a-delegation / cross-review-gate / structural-parity-dc checks |

**Skill count policy** (Principle 2 split): stage skills ≤ 7 cap, utility skills uncapped. Current inventory: 6 stage (`ship-shape`, `ship`, `ship-plan`, `ship-execute`, `ship-verify`, `ship-review`) + 3 utility (`add-todos`, `ship-onboard`, `ship-runtime-detect`). Enforced by `check-invariants.sh --check skill-count`.

**FO Discipline** (when to pause for captain): documented in `INVARIANTS.md § FO Discipline`. Short version: only `/shape` confirm, verify BLOCKING findings, PR merge, and explicit captain interrupt are captain-gates. All other transitions autonomous.

---

## Further reading

- **`INVARIANTS.md`** — Principles 1-7 (hard grep-enforced + captain-gate checklist). Start here to understand WHY each rule exists.
- **`references/entity-body-schema.yaml`** — structured section schema per stage. Source of truth for what sections each `{stage}.md` must contain.
- **`references/flow-map-schema.yaml`** — canonical doc section-tag declarations.
- **`docs/ship-flow/ship-shape-v2-implementation.md`** — #085 entity: full 6-wave redesign journal with rationale, decisions, and evidence. The case study for this flow's design.
- **Individual SKILL.md files** under `skills/*/` — procedural detail per skill. Written concisely (opus-naturally-does applies).

---

## Revision

- **2026-04-23** — Ship-flow 2.0 landed via pitch #085 (merge commit `d8934761`). This README authored post-ship as the canonical plugin-level design doc.

---

*This flow is optimized for claude 4.7 autonomous execution with captain oversight. It may be over-engineered for 4.5-era agents and under-scaffolded for models without 1M context / prompt cache. Adapt the harness-diet principle per your model's strengths.*
