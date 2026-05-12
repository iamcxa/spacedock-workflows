---
name: ship-design
description: "Use when shape finds UI, domain, contract, interface, visual ambiguity, affects_ui, design_required, or no design reference before plan."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# ship-design

Design intent capture stage for UI, domain, and contract/interface pitches. Runs between shape and plan when trigger fires. Named designer agent produces design artifacts or contract decisions captain can review before plan stage — preventing the 3-cross-review fix loop + captain dogfood failure that pitch-103 required (18 files / 3641 LOC Mega 1.5 spike from misaligned design intent).

**Stage-skill count**: adding ship-design makes **7/7** (ship-shape / ship / ship-plan / ship-execute / ship-verify / ship-review / ship-design = hard cap per Principle 2). No further stage-skills can be added without first folding or extracting an existing one.

---

## Boot Self-Check

Run before any design work. Stop and SendMessage(FO) if any check fails.

1. **Trigger valid**: entity has `affects_ui: true` OR `domain:` frontmatter registered in registry OR `design_required: true` OR `contract_decision_required: true` OR `--design` flag OR files match `*.tsx|*.css|*.html`. Design always runs — trivial-pass entities (none of these signals present) walk Phase 0 fast-path per D5 (see Phase 0 §Trivial-pass fast-path). There is no pipeline-level skip.
2. **Entity status**: read entity frontmatter `status:` — must be `sharp`. If `design` → design already ran (check for re-entry signal).
3. **Hand-off to Design present**: entity body contains `### Hand-off to Design` block (from ship-shape Phase 8). If absent → SendMessage(FO): "Missing Hand-off to Design — shape stage did not complete handoff."
4. **Exploration file**: `## Sharp Output → Problem` cites a file:line. Read that file before Phase 1 — if missing → SendMessage(FO): "Exploration file not found: `<path>` — cannot distill design without source."
5. **design-flow available**: check if plugin installed. If not → note fallback to `superpowers:brainstorming` in Design Report; proceed.
6. **Density-aware skill load** (T3.4): read `answers_density` from entity frontmatter. `high` → auto-load framework skills per ship-runtime-detect Step R6; skip FO ask. `low|vacuum` → SendMessage(FO) with proposed skill list; wait for confirmation.
7. **Canonical context preflight**: for contract-bearing design work, read
   repo-root `PRODUCT.md` constraints and relevant `ARCHITECTURE.md` sections
   before dispatching designers. Contract-bearing means any schema/API/domain,
   data-flow, storage, runtime, component-boundary, or architecture-impact
   signal. If either doc is missing, record the missing source in design.md
   rather than inventing constraints.

## Layer A delegation (Principle 6 Rule B)

`design-flow` owns the contradiction-resolution Q-loop and design distillation flow (#106 T5.2). **Do NOT re-teach this procedure.** Invoke it; Layer B below provides the Shape Up framing (5-category classifier, per-app design-system.md targeting, Material/Atlassian Principles tier separation, L2 strictness DCs).

Fallback: if `design-flow` is unavailable (plugin not installed), fall back to `superpowers:brainstorming` for contradiction resolution. Document the fallback in design.md `## Design Report`.

---

## Trigger condition

Design stage fires when ANY of:
- `affects_ui: true` in entity frontmatter (UI trigger path; set by shape stage when pitch touches frontend)
- `domain:` frontmatter set in entity, registered in registry (specialist trigger path; set by ship-shape Phase 8.5 via `registry-resolve.sh --classify`; `domain:` set_at shape)
- `design_required: true` in entity frontmatter (contract-bearing trigger path for
  schema/API/domain/architecture work that is not otherwise UI or registered
  domain)
- `contract_decision_required: true` in entity frontmatter because shape emitted
  `open_contract_decisions[]` for unresolved non-UI contract/interface choices
  such as selector grammar, API vocabulary, tool protocol, DSL syntax, schema or
  message format
- `Files modified` or `architecture-impact` cites path matching glob `*.tsx | *.css | *.html`
- Captain explicit `--design` flag on `/shape` invocation

Otherwise: design always runs — trivial-pass entities walk the fast-path in Phase 0 (see below) instead of being skipped at the pipeline level.

### Lane determination predicate

Boolean predicate for FO and plan stage to determine gate type without runtime-only enum lookups (Principle 4 boolean-gate compliance):

```
UI-lane := (affects_ui == true) OR (Files-modified glob matches *.tsx|*.css|*.html)
non-UI-lane := (domain set) OR (design_required == true) OR (contract_decision_required == true)
trivial-pass := neither UI-lane nor non-UI-lane conditions hold
Mixed (both UI-lane and non-UI-lane signals true) → prefer UI gate (captain-gated; safe-side per shape artifact A3)
```

- **UI-lane** entities are captain-gated at the design→plan boundary (Phase 9 verdict requires captain ack before FO may advance).
- **non-UI-lane** entities are FO-gated: a PROCEED verdict allows FO to advance directly to plan without captain interaction.
- **trivial-pass** entities walk Phase 0 fast-path: emit minimal design.md + unconditional PROCEED; no designer dispatch.
- **Mixed** entities (both UI-lane AND non-UI-lane signals true) prefer the UI gate (captain-gated) as the safe-side tie-break.

> **Note — domain-set-but-unregistered**: If `domain` is set but not registered in the registry (registry-resolve --validate exit 10 / 11), the entity is still **non-UI-lane** for gate purposes (domain-set is sufficient; registry membership is not a gate-classification concern). Phase 0 step 2 handles registry validation separately — emitting `## Design Output → ### Router HALT` block when M1/M2 fires; the lane classification (FO-gated) does not change.

This is the single canonical reference for FO and plan stage lane classification. Cross-reference: INVARIANTS Principle 10 "Design Gate Domain Split".

---

## Dual role — design stage (primary) + verify-stage ui-verifier (secondary)

`designer@pitch-XX` is a named teammate (Principle 6 Rule A). After completing the design stage, the same teammate may be called again at verify stage via `SendMessage` from the verifier agent (ship-verify Step 3.5).

**Secondary role contract** (triggered by ship-verify):
- Input: execute diff (`git diff <execute_base>..HEAD -- <ui_files>`) + path to design artifacts (`design.md` / `plugins/<app>/design/`).
- Task: check that implemented code matches design decisions (captain D1-D6 tags, tokens.css, component specimens).
- Output: findings list classified as `BLOCKING / WARN / NIT` with `file:line` citations. Return via `SendMessage(to: "verifier")`.
- No new Q-loop, no new artifact emission — read-only review of existing design canon vs implementation.

**Why same named agent**: D1-D6 captain decisions are held in this agent's active context from the design stage. A fresh agent would have to re-read the full design artifact bundle and could miss nuanced intent that was resolved interactively during the Q-loop.

---

## Entity body contract

**Reads from**:
- `## Sharp Output → Problem` — exploration file cite (path:line), stated contradictions
- `## Sharp Output → Done Criteria` — UI-typed DCs that design must inform
- `PRODUCT.md` — product constraints and capability promises that constrain
  design decisions
- `ARCHITECTURE.md` — relevant architecture/domain/API/schema sections for
  contract-bearing design work

**Writes to** (`entity-body-schema.yaml → stages.design`):
- `## Design Output / ### Captain Decisions` — `D{N}|Captain decision` tagged per contradiction
- `## Design Output / ### Artifact Bundle Manifest` — table of emitted files
- `## Design Output / ### Constraints for Plan Stage` — token / interaction constraints plan must honor
- `## Design Output / ### Canonical Context` — `canonical_context` rows naming
  the `PRODUCT.md` / `ARCHITECTURE.md` sections read, update intent, and skip
  rationale when no canonical doc change is required
- `## Design Report` — status / cost / iterations / captain_decisions count / reviewer_verdict

**Emits artifact bundle** at `plugins/<app>/design/`:
- `design-system.md` — canonical design foundations + components + patterns (map-layer registered)
- `tokens.css` — CSS custom properties (MUST be byte-equal across re-runs: load-bearing for L2 dogfood DC)
- `design-system.html` — visual gallery of all tokens in context
- `components/<name>.html` — one HTML specimen per component (visual fidelity required for captain ack)
- `war-room.html` (or app-equivalent) — composed mockup showing components in a real screen

---

## 5-Category classifier

All 5 categories below are **UI / visual / IA / aesthetic** work — they route to `design-officer` (standing teammate) in team mode, or to inline worker handling in bare mode. The separate **domain / schema / contract / business-logic** lane (triggered by `domain:` frontmatter) routes to `schema-designer` via the existing `domain-registry` path (Phase 0.5 §Domain path) and is NOT one of these 5 categories. Both paths can fire concurrently for an entity that needs both kinds of design work (e.g., new schema + new UI).

| Category | Trigger | Routing target | Active dispatch path |
|---|---|---|---|
| 0 — Distill from existing exploration | Shape cites exploratory HTML/markdown at file:line; contains ≥2 conflicting design directions | `→ design-officer` (visual) | `ui-designer` distills existing exploration, invokes `storyboard`, `design-flow`, and `design-review` |
| Category A — Net-new design system | `plugins/<app>/design/` directory absent; first-ever design for this app | `→ design-officer` (visual) | `ui-designer` runs full chain: `design-flow` using `design-brief`, `information-architecture`, `design-tokens`, `brief-to-tasks`, then `frontend-design` and `design-review` |
| Category B — Component breakout | `design-system.md` exists; new component specimen needed | `→ design-officer` (visual) | `ui-designer` uses `frontend-design`, `design-tokens` if tokens change, and `design-review`; load `information-architecture` only when component placement/navigation changes |
| Category C — Variation on existing component | `design-system.md` exists; variant on component spec | `→ design-officer` (visual) | `ui-designer` preserves existing design canon, uses `frontend-design`, then `design-review` |
| Category D — One-off visual | Pitch-local mockup only; does NOT touch design-system.md | `→ design-officer` (visual) | `ui-designer` uses `frontend-design`; add `design-review` only for high-risk UI or accessibility-sensitive changes |

Category A-D are active. Do not halt solely because the category is A, B, C, or D.
If required design skills are missing, record the fallback in `Design Report` and
continue with the narrowest viable route.

> **Routing decoupling**: the "Routing target" column names *who owns the visual exploration* (design-officer in team mode, worker inline in bare mode). The "Active dispatch path" column names the *skill chain* the visual work runs through. design-officer (when alive) is the agent that drives the chain in team mode; the chain itself is unchanged. Domain work is never routed here — see Phase 0.5 §Domain path.

## Designer Dispatch Manifest

Before worker dispatch, write a `design-dispatch-manifest` block into
`design.md` or the design-stage draft. This is the contract between ship-design,
plan, and execute:

```yaml
design-dispatch-manifest:
  lanes:
    - lane: ui
      role: ui-designer
      category: Category A|Category B|Category C|Category D|Category 0
      required_skills: []
      adopter_routing:
        files: []
        skills_needed: []
        folder_guidance_files: []
        folder_guidance_skills: []
        codex_context_boundary: "root AGENTS.md/CLAUDE.md intentionally excluded from folder_guidance_files"
      outputs: []
    - lane: domain
      role: domain-designer
      domain: schema
      panel_lane: domain-expert
      required_skills: []
      knowledge_module_path: ""
      designer_section_anchor: ""
      review_contract:
        worktree: "<absolute worktree path>"
        base_head: "<base>..<head>"
        mode: read-only findings-only
      outputs: []
    - lane: contract-interface
      role: contract/interface-designer
      trigger: open_contract_decisions
      decisions: []
      examples: ["selector grammar", "API vocabulary", "tool protocol", "DSL syntax", "schema/message format"]
      outputs: ["captain_decisions", "design_constraints", "open_decisions[] if unresolved"]
  integration:
    mode: single-designer|parallel
    owner: ship-design
  visual_verification:
    fragment_level: render_fidelity_targets[]
    whole_page: whole_page_visual_targets[]
```

Dispatch rules:
- UI-only small Category C/D work may use `single-designer` mode with one
  `ui-designer`.
- Domain-only work may use `single-designer` mode with one `domain-designer`
  routed through the registry specialist.
- Contract/interface-only work may use `single-designer` mode with one
  `contract/interface-designer`. It must present a trade-off table for each
  `open_contract_decisions[]` item and capture a `D{N}|Captain decision`
  before plan. Examples include selector grammar, API vocabulary, tool protocol,
  DSL syntax, schema/message format, and mapper→native boundary contracts.
- UI + domain work uses `parallel` designer dispatch: dispatch `ui-designer` and `domain-designer` concurrently, then run an integration pass in ship-design
  that merges outputs into one `design.md` handoff.
- Multi-domain or Category A + domain work defaults to `parallel`. Collapse to
  `single-designer` only when one lane is trivial and the reason is recorded in
  the manifest.
- Domain expert panel lanes are allowed when domain registry or adopter file
  signals identify risk. They are read-only and findings-only: pass the correct
  worktree, base/head range, domain lens, required skills/knowledge modules, and
  "do not edit files" instruction. Discard outputs from the wrong worktree,
  wrong base/head, or without `file:line` citations.
- domain risk must be explicit in design output. For each domain-expert lane,
  write the risk questions that plan/verify must preserve, such as state
  filters, entity filters, archive/reactivate behavior, URL hydration, cache
  invalidation, seed validation, identity mapping, or framework-specific UI
  component contracts discovered from the loaded skills.
- UI lanes must consume adopter file-signal routing before dispatch. For every
  UI candidate file from shape handoff, spec `Files modified`, exploration
  cites, or obvious UI surface path, run:
  ```bash
  bash plugins/ship-flow/lib/resolve-skill-routing.sh \
    --config=.claude/ship-flow/skill-routing.yaml \
    --files=<comma-separated-ui-candidate-files>
  ```
  Merge `skills_needed=` into the UI lane `required_skills`, preserving the
  Category skill chain first and de-duping in order. Record
  `folder_guidance_files=`, `folder_guidance_skills=`, and
  `codex_context_boundary` under `adopter_routing`.
- If `.claude/ship-flow/skill-routing.yaml` is absent on an adopter project,
  write `adopter_routing.status: missing-config` and bounce to shape/onboard
  for non-trivial UI work. Tiny one-file UI work may continue only with the
  missing-routing warning recorded in `Design Report`.
- The `ui-designer` dispatch prompt must include a `### Folder guidance
  required` block with every `folder_guidance_files` path emitted by the
  resolver. The designer must read those files and return a `Context Read
  Receipt` listing guidance files, routed skills, folder guidance skills, and
  applied constraints. If the resolver emits no `folder_guidance_files`, write
  `none — resolver reported no folder_guidance_files`; do not invent or require
  a CLAUDE.md/AGENTS.md path. Example only: if an adopter's resolver output
  includes `folder_guidance_files=apps/refine-app/CLAUDE.md`, include that path
  plus routed/folder skills such as `refine-expert`, `refine-gotchas`,
  `antd-expert`, `react-patterns`, and `tailwind-expert`.
- Do not duplicate Codex root session instructions. Root `AGENTS.md` and
  `CLAUDE.md` remain runtime/session context; ship-design only enforces
  non-root folder guidance reported by `resolve-skill-routing.sh`.

### Whole-page visual parity targets

Fragment-level ui-verify checks are necessary but not sufficient. They catch
precise token, selector, and computed-style failures, but they can still pass
when the final screen composition diverges from the design reference. For every
`affects_ui: true` lane, ship-design must emit both:

- `render_fidelity_targets[]` — fragment-level ui-verify assertions for
  selectors, tokens, and computed styles.
- `whole_page_visual_targets[]` — full-page screenshot parity targets for the
  primary affected route or surface.

Each `whole_page_visual_targets[]` item names `{route, reference_artifact,
capture, threshold, rationale_decision}`. `reference_artifact` should point to
the composed mockup or reference screenshot, such as
`plugins/<app>/design/<surface>.html` or a committed reference image. `capture`
must say `full-page screenshot` unless the UI is an embedded fixed-size widget.
These targets feed plan-stage verify DCs and ship-verify whole-page visual
parity. Do not claim visual parity from fragment-level ui-verify alone.

### Design Readiness Review

Design Readiness Review is a risk-gated mod inside the design stage, not a
standard stage. Run it after designer lanes merge and before hand-off to plan
when any trigger applies:

- `multi-domain` work, including UI + schema/API/domain changes.
- DB migration, destructive schema change, public API or ts-rest contract.
- fmodel/DDD/saga routing, RBAC, tenancy, or projection rebuild decisions.
- High-risk UI fidelity where the whole-page composition is a core outcome.
- Recent debrief warning matches the current domain or captain explicitly asks.

The mod dispatches low-model specialist reviewers derived mechanically from
domain registry and adopter file-signal routing. Start with these reviewer
derivation rules, then cap to the smallest useful team (normally 1-3 reviewers):

- `affects_ui: true` or `whole_page_visual_targets[]` → reviewer `ui`.
- `domain: schema`, DB migration files, or Supabase schema paths → reviewer
  `schema`.
- public API / ts-rest / API contract signals → reviewer `api`.
- fmodel / DDD / saga signals → reviewer `fmodel`.
- adopter file-signal routing may add surface reviewers such as `refine`,
  `expo`, or `supabase` only when the matched route requires that specialist.

Each reviewer loads the relevant domain knowledge module plus required skills
and returns `PASS`, `WARN`, or `BLOCK` with `route_to: design|plan`. Do not
hardcode a project-specific reviewer set. If no risk trigger applies, write
`Design Readiness Review: skipped - no risk trigger` in `Design Report`. Any
`BLOCK` must be resolved before plan.

---

## Flow

### Phase 0 — Route

**Trivial-pass fast-path** (check BEFORE any other routing — short-circuits if all conditions hold):

If ALL of the following hold:
- `affects_ui`: false (or unset)
- `domain`: unset (or empty string)
- `design_required`: false (or unset)
- `contract_decision_required`: false (or unset)
- `open_contract_decisions[]`: empty or unset

→ **trivial-pass** — do NOT dispatch any designer worker or build `design-dispatch-manifest`:
1. Emit minimal `design.md`:
   ```
   ## Design Report
   status: trivial-pass
   ```
   Plus a `### Hand-off to Plan` block:

   <!-- section:hand-off-to-plan -->
   ```yaml
   design-skipped: true
   design_constraints: []
   open_decisions: []
   artifact_paths: []
   render_fidelity_targets: []
   whole_page_visual_targets: []
   ```
   <!-- /section:hand-off-to-plan -->
2. Phase 9 emits unconditional PROCEED verdict (no cross-review dispatch needed).
3. Advance entity status `design → plan`.
4. SendMessage(planner): "Design trivial-pass for pitch-<id>. design-skipped: true — no constraints to import. Advance directly to plan."

Per DC-8: `design-skipped: true` (not `design-skipped: false` with empty constraints) so plan Step 1.6 G14 semantics short-circuit correctly. Cross-reference: INVARIANTS Principle 11 "Design Stage Required".

---

1. Read entity frontmatter `affects_ui:` and `domain:`. Record both.
2. **If `domain:` is set**: invoke registry-resolve to confirm specialist availability:
   ```bash
   bash plugins/ship-flow/lib/registry-resolve.sh --validate --domain=<domain-name>
   ```
   Branch on exit code:
   - exit 0 → domain registered + specialist available → proceed to Phase 0.5 (specialist dispatch).
   - exit 10 (M1 `specialist_missing`) → emit `## Design Output → ### Router HALT` block with all 3 options (skip / generalist-marker / file-specialist-first). SendMessage(FO): halt notice with domain name + options. **STOP** — captain acks one option in entity body, then re-runs design.
   - exit 11 (M2 `knowledge_module_missing`) → same as M1 path: emit HALT block, SendMessage(FO), **STOP**.
   - exit 20 / 21 (M4 parse_error / M5 invalid_trigger_config) → fail loud per INVARIANTS Principle 9; SendMessage(FO): "registry config error exit $?; blocking design stage". **STOP**.
3. **If `domain:` is unset AND `affects_ui: true`**: proceed to UI category-classifier (Category 0/A/B/C/D logic at Phase 0 step 4).
4. Resolve the shape artifact (`shape.md`, with legacy `spec.md` fallback alias) and determine category per classifier table.
5. Build `design-dispatch-manifest`:
   - `affects_ui: true` → add `ui` lane with the selected Category.
   - for the `ui` lane, resolve adopter file-signal routing with
     `resolve-skill-routing.sh` before dispatch; include `skills_needed`,
     `folder_guidance_files`, `folder_guidance_skills`, and
     `codex_context_boundary` in the manifest.
   - `domain:` set → add `domain` lane with registry `required_skills`,
     `skill_hints.*`, `knowledge_module_path`, and `designer_section_anchor`.
     Mark high-risk domain lanes as `panel_lane: domain-expert` and require
     read-only findings that become constraints for plan.
   - `contract_decision_required: true` or `open_contract_decisions[]` non-empty → add `contract-interface` lane. The lane reads each open contract decision, produces a trade-off table, and converts the captain-selected option into `### Captain Decisions` plus `design_constraints[]`. If the captain does not decide, carry it to `open_decisions[]` so plan blocks.
   - multiple lanes present → `integration.mode: parallel`.
   - one low-risk lane present → `integration.mode: single-designer`.
6. Dispatch the manifest lanes. UI lane follows Phase 1-9. Domain lane follows
   Phase 0.5 and specialist subsection. Contract/interface lane follows the
   trade-off/captain-decision path above. Integration pass merges lane outputs
   before `### Hand-off to Plan`.
7. Before accepting UI lane output, require the `Context Read Receipt`. Missing
   app-folder guidance citation when `folder_guidance_files` is non-empty, or
   missing routed/folder skill such as `refine-gotchas` when emitted by the
   resolver, is BLOCKING feedback to the `ui-designer`; do not defer this
   correction to plan or execute. If `folder_guidance_files` is empty, do not
   block on guidance-file absence.

### Phase 0.5 — Specialist dispatch

Two routing paths that coexist. Both can fire concurrently when an entity has both UI and domain signals (e.g., new feature with new schema + new UI). Domain work is delegated to a deterministic codebase-aware specialist; visual work is delegated to a standing taste-accumulating teammate.

#### Domain path (existing — `schema-designer` via `domain-registry`)

Reached when Phase 0 step 2 returns exit 0 (domain registered + `specialist_missing` = false). Routing target: `schema-designer` (or other domain specialist named in `designer_section_anchor`). **Unchanged by this overhaul.**

1. Resolve specialist anchor and knowledge module:
   ```bash
   bash plugins/ship-flow/lib/registry-resolve.sh --domain=<domain-name>
   ```
   Read `designer_section_anchor`, `knowledge_module_path`, `required_skills`,
   and `skill_hints.*` from the output envelope.
2. Load knowledge module: read `references/domain-knowledge/<domain>.md` before specialist work (domain-specific constraints + anti-patterns + design checklist).
3. Dispatch `domain-designer` to specialist sub-section identified by `designer_section_anchor`
   (e.g., `ship-design#schema-designer` once 113.3 ships). Include any
   `required_skills` and relevant `skill_hints.plan` / `skill_hints.execute`
   in the design handoff so plan stage can preserve them in `skills_needed`.
   Specialist sub-section defines its own typed `## Design Output` block
   (e.g., `## Schema Design Output`).
4. If prior shape evidence contains `## Domain Registry Validation` with `result: HALT-with-options` or a non-ok registry status, but this design-stage validation now returns exit 0, emit `### Registry Validation Resolution` in `design.md`:
   - `prior_result: <status/result from shape>`
   - `current_result: ok`
   - `resolution: superseded_by_design_stage_validation`
   - `reason: <knowledge module/specialist now present, or adopter config corrected>`
   This preserves the stale HALT evidence instead of pretending it was never emitted, and tells plan stage to consume the current design/plan registry result.
5. v1 multi-domain disambiguation: if `domain:` frontmatter contains multiple names (comma-separated), use first match. v2 multi-domain dispatch is out of 113.1 scope.

**Schema specialist active as of 113.3**: `defaults.yaml` now points schema to
`designer_section_anchor: "ship-design#schema-designer"`, so schema-domain
pitches proceed to the specialist path instead of the M1 HALT path. Domains
without an anchor still use the M1 HALT-with-options surface.

#### Visual path (new — `design-officer` via `SendMessage`)

Reached when the entity matches any of the 5-Category classifier rows (UI / IA / aesthetic work). Routing target: `design-officer` — a standing teammate spawned by FO at boot from `_mods/design-officer.md` template (opus, session-scoped, taste accumulates across features within a session).

**Why a separate path**: domain work needs a deterministic specialist with codebase access (schema-designer fits). Visual work needs iterative captain dialogue + cross-feature taste accumulation (design-officer fits). Different cognitive modes, different agents. NOT competing paths — both run if an entity needs both.

**Team-mode protocol** (default when TeamCreate is available and FO is not in Degraded Mode):

1. Worker checks team registry for design-officer. If alive → proceed; if absent → fall through to Bare Mode Degrade below.
2. Worker SendMessages design-officer with the entity context. Template:
   ```
   to: design-officer
   message: |
     Entity {entity_id} ({title}) needs visual design exploration.
     - Type: {variants | IA | tokens | review | full system}  (derived from 5-Category classifier row)
     - Category: {0 | A | B | C | D}
     - Constraints: read shape.md `## Design Constraints` if present
     - Entity folder: <path>
     - Existing design.md: <state>  (absent | partial | full prior draft)
     Produce variants in <entity>/design-explore/ per
     lib/design-methodology/{shotgun|consultation|html-generation}.md as appropriate.
     SendMessage back when ready, or surface to captain for direct Shift+Down dialogue.
   ```
3. Worker waits **non-blocking** for design-officer's reply. Captain may Shift+Down to design-officer mid-flight to steer interactive design dialogue (variant selection, refinement, IA negotiation).
4. When captain selects a variant via Shift+Down dialogue, design-officer writes the selection to `<entity>/design.md`. Worker observes design.md update and resumes structural design work (constraints, lanes, render-fidelity targets, hand-off).
5. The visual path produces the *variant + selection*; the worker still owns Phase 4 (distill design-system.md), Phase 9 (cross-review), and Phase 9-hand-off (`### Hand-off to Plan` machine-readable contract). design-officer is the upstream visual-exploration source, not the hand-off owner.

**Bare Mode Degrade** (when TeamCreate is unavailable OR FO is in Degraded Mode → design-officer is NOT spawned):

1. Worker reads `plugins/ship-flow/lib/design-methodology/` files directly: `ux-principles.md`, plus `shotgun.md` / `consultation.md` / `html-generation.md` as needed per scope.
2. Worker produces markdown variants in `<entity>/design-explore/variant-*.md` from its own context, following `shotgun.md` discipline (3 differentiated concepts, anti-convergence, full specs per variant — no convergent thinking before the comparison step).
3. Captain reviews variants via Read tool in editor; communicates selection via next captain message (no live Shift+Down dialogue available).
4. Worker iterates based on captain's text directive; eventually commits the selected variant to `<entity>/design.md` and continues to Phase 4.

Tradeoffs in bare mode: **LOSE** cross-feature taste accumulation (worker fresh per entity); **LOSE** live Shift+Down dialogue (async text only). **KEEP** per-entity design quality and hermetic policy. Bare-mode degrade is the design stage's safety net — never block on design-officer absence.

**Spawn config source**: `plugins/ship-flow/_mods/design-officer.md` (added by Phase 4 of this overhaul). FO consumes this mod template at boot to spawn the standing teammate.

## Schema Designer Specialist

Anchor: `ship-design#schema-designer`

This subsection is invoked only after Phase 0.5 resolves `domain=schema`,
`registry-resolve.sh --validate --domain=schema` exits 0, and the designer has
loaded `plugins/ship-flow/references/domain-knowledge/schema.md`. The schema
designer is still part of the `ship-design` stage skill; do not add a new stage
skill for this specialist.

### Required output

Emit a typed schema block in `design.md`:

```markdown
## Schema Design Output

### Layers touched
- L1 decider:
- L2 fstore:
- L3 view:

### Migration safety
- Additive / destructive:
- Backfill required:
- Event-saga implication:

### RBAC and tenancy
- tenant_id / ownership columns:
- RBAC subject:

### Projection / fstore rebuild
- Rebuild strategy:
- Stale-read tolerance:

### Hand-off constraints for Plan
- Required plan DCs:
- Verify-time intent checks:
```

### Design checklist

Answer each schema-domain question before handing off to plan:

1. Which layers does the pitch touch: L1 decider, L2 fstore, L3 view, or a
   combination?
2. Does the migration have event-saga implications such as column removal,
   foreign-key changes, primary-key changes, or NOT NULL additions without a
   default?
3. Do new or modified user-owned tables include tenant isolation and RBAC
   subject columns?
4. If an L2 projection shape changes, what is the fstore rebuild strategy?
5. If an L3 view type changes, is the API/contract impact additive or breaking?

### Hand-off to Plan

The specialist's `### Hand-off constraints for Plan` must name concrete DCs the
plan stage can verify. Do not emit `## Intent Match Findings` here; pitch 113.4
owns the verify-stage intent-match verifier. For 113.3, the design stage only
creates typed intent for later comparison.

### Phase 1 — Read exploration

1. Locate exploration file at path:line cited in the resolved shape artifact `## Problem`.
2. List all visual decisions present: palettes, typography, spacing, motion, component mentions.
3. Output: structured `visual_inventory[]` — section / claim / line-range for each decision.

### Phase 1.5 — Storyboard user flow (Layer A delegate)

1. Invoke `Skill: storyboard` to capture 6-frame narrative of the user journey through this UI surface. Frames represent: (1) user encounter, (2) action, (3) system response, (4) state transition, (5) outcome, (6) follow-up state. Skill spec: deanpeters/Product-Manager-Skills `storyboard@pm-skills`.
2. Per frame capture `actor` + `action_or_state` + `expectation`. Frame expectations become contract constraints downstream stages must satisfy (verifier checks rendered output against frames; review stage gates BLOCKING any frame the implementation cannot satisfy).
3. Output: structured `storyboard_frames[]` — feeds Phase 2 contradiction-detect (frame expectation vs visual_inventory mismatch is a contradiction class on top of pure visual conflicts) AND Phase 8 hand-off-to-plan (`render_fidelity_targets` extended with frame-by-frame expectations).
4. Fallback: if `storyboard` plugin unavailable, capture 6 frames inline via numbered bullets in design.md; document as fallback in Design Report.
5. Skip is RARE — ship-design only runs when `affects_ui=true`, so user-flow narrative is in scope by definition. If captain explicitly asserts "pure component refactor, no flow change" → skip with rationale recorded.

### Phase 2 — Contradiction-detect

1. Compare `visual_inventory[]` entries for internal conflicts (different sections asserting different values for same property).
2. For each conflict: record `contradictions[]` item with `claim_a` + `claim_b` + `cite_a` + `cite_b`.
3. Pitch-103 reference: `design-exploration-spatial.html` yielded 6 contradiction pairs (D1-D6). Non-trivial pitches expect ≥2 pairs.
4. If zero contradictions detected: likely missed detection. Re-scan or halt with PROMPT_CAPTAIN before proceeding.

### Phase 3 — Captain Q-loop (Layer A delegate)

1. Invoke `Skill: design-flow` with `contradictions[]` as input for the contradiction-resolution Q-loop. Fallback: `Skill: superpowers:brainstorming` if `design-flow` unavailable — document in Design Report.
2. Per resolution: capture `**D{N}|Captain decision**: {claim}` format at the decision point in design-system.md.
3. ≥6 decisions for non-trivial pitches (≥6 contradictions); ≥1 must be critical (breaking visual change).
4. **BLOCK if Q-loop skipped** (no decisions captured) — this is the fabricated-PASS pattern per debrief `_debriefs/2026-04-27-01.md` Issue 1. Do NOT proceed.

### Phase 4 — Distill design-system.md

1. Write `plugins/<app>/design/design-system.md` with canonical structure:
   - `## 0. Purpose & Status`
   - `## 1. Color System` through `## 6. Motion` (inject `<!-- section:foundations -->` before §1, `<!-- /section:foundations -->` before §7)
   - `## 7. Composition Principles` (inject `<!-- section:components -->` before §7, `<!-- /section:components -->` before §9 or patterns boundary)
   - `## 8+` composition / vocabulary sections (inject `<!-- section:patterns -->` ... `<!-- /section:patterns -->`)
2. Tag each captain decision inline: `**D{N}|Captain decision**: {resolution}` at the exact decision point in prose.
3. tokens.css: emit CSS custom properties as a standalone file. Property names are stable contracts — do NOT rename across iterations (byte-equality is the L2 dogfood DC).

### Phase 5 — Component breakout

1. One HTML specimen per component at `plugins/<app>/design/components/<name>.html`.
2. HTML > markdown for captain ack (visual fidelity required — debrief Observation).
3. Component filename set must be stable across re-runs (filename-set-equality is L2 dogfood DC).

### Phase 6 — Composed mockup

1. Emit `war-room.html` (or app-equivalent composite screen) at `plugins/<app>/design/`.
2. Shows how components compose into a real screen; used for captain final visual review.

### Phase 7 — Captain confirm

1. Present `design-system.md` + key HTML artifacts (tokens visual gallery + war-room mockup) to captain.
2. Captain confirms / refines / rejects. Refine loops back to Phase 3 (targeted Q-loop iteration). Max 2 refine loops; on 3rd fail halt with PROMPT_CAPTAIN.
3. **Captain confirm gate is MANDATORY** — do NOT advance to Phase 8 without explicit captain ack.

### Phase 8 — Emit design.md (entity body)

1. Write `<entity-folder>/design.md` per `entity-body-schema.yaml → stages.design`:
   - `## Design Output / ### Visible UI Design Output` — for every `affects_ui: true` UI lane, include captain-visible layout, zones, states, affordance, and interaction decisions. Category A-D may scale the artifact bundle down, but may not produce an invisible or purely machine-readable handoff.
   - `## Design Output / ### Captain Decisions` — list all `D{N}|Captain decision` entries with file:line contradiction cite. (Captain-readable narrative; rationale source for plan/verify cross-references via `D{N}`.)
   - `## Design Output / ### Artifact Bundle Manifest` — table (Path / Type / Purpose) of all emitted files.
   - `## Design Report` — status / stage_cost / iterations / contradictions_resolved / captain_decisions / reviewer_verdict.

**Single-source-of-truth rule** (G8 dedup, 2026-04-29): `### Hand-off to Plan` (Phase 9 hand-off block) is the **only** structured contract plan stage reads. Do NOT duplicate `design_constraints` / `render_fidelity_targets` here in `## Design Output`. Phase 8 holds captain-readable narrative + audit trail (Decisions, Manifest, Report); Phase 9 holds machine-readable contract (constraints, render-fidelity targets, artifact paths, open decisions). Plan Step 1.6 reads Phase 9 hand-off; cross-references back to Phase 8 Captain Decisions via `D{N}` markers when rationale needed.

### Phase 8.5 — Risk-gated Design Readiness Review

Evaluate the Design Readiness Review triggers above. When triggered, dispatch
the smallest useful low-model expert team from the registry/routing output,
collect findings, and record a `## Design Readiness Review` section in
`design.md`:

```yaml
risk_triggers:
  - multi-domain|migration|api-contract|fmodel|high-risk-ui|recent-debrief|captain-explicit
reviewers: ui, schema
derived_from:
  - affects_ui:true
  - domain:schema
  - whole_page_visual_targets[]
verdict: PASS|WARN|BLOCK
findings:
  - reviewer: schema
    severity: PASS|WARN|BLOCK
    route_to: design|plan
    evidence: "<file:line, design artifact, or contract>"
```

This is a mod, not a standard stage: it never adds a new workflow status and it
must be skipped for trivial/docs-only/single-lane work unless explicitly
requested. It exists to stop bad design contracts before plan decomposes them.

Before marking design complete, run:

```bash
bash plugins/ship-flow/lib/check-design-readiness-review.sh <entity-folder>/design.md
```

The checker derives required reviewers from the design artifact and blocks when
a triggered review is missing, when a required reviewer is absent, or when the
verdict is `BLOCK`. When the checker prints `status=warn`, the design may
proceed, but the warning must remain visible in `Design Report` and downstream
plan notes.

### Phase 9 — Cross-review gate

Dispatch cross-review as a **separate agent** via `Skill: design-review` (#106 T5.2). This is an adversarial review — a fresh agent with no context from the design session evaluates the artifacts independently.

Fallback chain (Principle 6 Rule A): if `design-review` unavailable → dispatch fresh sonnet subagent with structured review prompt → if subagent also stalls → `executer` teammate inline review.

7-factor rubric adapted for design stage — **rubric varies by lane type** (per INVARIANTS Principle 6 Rule C #106 T1.3 + T6.4; lane-type from `design-dispatch-manifest`):

**UI-lane rubric** (applies when `UI-lane == true` per Lane determination predicate):
| Factor | Assert |
|---|---|
| Feasibility | captain Q-loop delivered ≥6 decisions for ≥6 contradictions? |
| Executable scope | design-system.md + components + composite mockup all emitted? |
| Quality | canonical section anchors + decision tags present? |
| DC adequacy | every captain decision has `D{N}\|Captain decision` marker at decision point? |
| Canonical sync | design.md (entity) cites design-system.md (canonical) cite-pair? |
| **Reverse-audit previous stage** | does the design expose a gap in the preceding sharp/shape stage's `### Hand-off to Design` block? Specifically: are all `open_design_questions` resolved in captain_decisions? Does `render_fidelity_targets` include token alignment checks for any Tailwind v4 `theme_indirection` detected? |
| **Render Fidelity + captain-ack audit trail** | (T6.4) does `render_fidelity_targets` in Hand-off to Plan include ≥1 token alignment check per D{N} decision? Are HTML specimens visual-only (not interactive stubs)? Is tokens.css byte-stable (no renamed properties)? |

**non-UI-lane rubric** (applies when `UI-lane == false` per Lane determination predicate; domain / contract-interface lanes):
| Factor | Assert |
|---|---|
| Feasibility | captain Q-loop delivered decisions for all open_contract_decisions[] entries? |
| Executable scope | all captain decisions captured as `design_constraints[]` entries? |
| Quality | canonical section anchors + decision tags present? |
| DC adequacy | every captain decision has `D{N}\|Captain decision` marker at decision point? |
| Canonical sync | design.md (entity) cross-references source INVARIANTS / ARCHITECTURE sections? |
| **Reverse-audit previous stage** | does the design expose a gap in the preceding sharp/shape stage's `### Hand-off to Design` block? Are all `open_contract_decisions` resolved in captain_decisions? |
| **Constraint Coverage** | every captain decision yields ≥1 `design_constraint[]` entry; every `design_constraint[]` carries `rationale_decision: D{N}` backref; `open_decisions[]` is empty or escalated (D4, entity 116). |

> **Pattern (reusable)**: future non-UI lanes (saga, API contract, fmodel event schema, etc.) follow this same structure — define a named 7th-factor replacement per lane type and add it to the Phase 9 verdict switch. New lane = new named factor + grep DC anchor. Constraint Coverage for domain-contract lanes is the reference implementation.

**Verdict-emission predicate** (applies to both lane types):
- If `open_decisions[]` is non-empty → emit **PROMPT_CAPTAIN** (overrides any otherwise-PROCEED finding). Coaching note (D3 + Principle 4 boolean-gate): unresolved decisions cannot be auto-resolved by FO; halt entity and surface to captain.
- Otherwise → verdict per rubric factors above.

**Reverse-audit prompt template** (T3.2 — paste verbatim into reviewer dispatch):
```
Reverse-audit: Read the entity's `### Hand-off to Design` block from the entity body.
(a) List every `open_design_questions` entry — is each resolved by a `D{N}|Captain decision` in design-system.md? (BLOCKING if any unresolved)
(b) Does `render_fidelity_targets` include at least one token alignment check (e.g., CSS var usage, not hardcoded hex) for any Tailwind v4 `theme_indirection` context? (WARNING if theme_indirection=tailwind-v4 but no token check present)
(c) Are all contradiction pairs from Phase 2 represented as `D{N}` decisions? (BLOCKING if contradiction count > captain_decisions count)
Coaching note: unresolved design questions here cascade into plan ambiguity and execute drift — enforces shape→design hand-off integrity.
```

Verdict: **PROCEED** / **VETO** (max 2 loops) / **PROMPT_CAPTAIN**. Each verdict MUST include a one-sentence coaching note per INVARIANTS Principle 6 Rule C ABC clause.

### Phase 10 — Advance to plan

1. Advance entity status `design → plan`.
2. SendMessage to `planner` teammate: `"Design stage complete for pitch-<id>. Read <entity-folder>/design.md §Constraints for Plan Stage before composing plan."`

---

## Invariants + red flags (STOP if violated)

- Category A-D design stage routes must proceed through the dispatch manifest; do not reintroduce a category-only deferral or halt.
- `affects_ui: true` with `design-skipped: true` is invalid unless the entity handoff carries `captain-approved-design-bypass: true` with a one-line rationale.
- Contradiction-detect emits zero pairs → re-scan or PROMPT_CAPTAIN.
- Captain Q-loop skipped → fabricated-PASS; BLOCK.
- Captain confirm gate skipped → fabricated-PASS; BLOCK.
- tokens.css renamed or properties reordered → L2 dogfood DC will fail; fix inline before captain confirm.
- Symbol-overload discipline violated (bare "design" in load-bearing position) → fix inline per spec A5: always "design stage" / "`design.md` (Principles)" / "`design/` directory" / "`ship-design` SKILL".
- Stage-skill count would exceed 7 → fold/extract first per Principle 2 (current count: 7/7 hard cap).
- Layer A re-teaches `superpowers:brainstorming` Q-loop → Principle 6 Rule B violation; delete re-teach.

---

## Circuit breakers

- Q-loop iterations ≤ 8 total (one per contradiction max).
- HTML specimen authoring ≤ 30 min/component wall-clock.
- Total design stage < 60 min wall-clock — exceed → emit partial design.md with `⚠️ INCOMPLETE` markers + Design Report `status: partial`.

<!-- section:hand-off-to-plan -->
## Phase 9 (Hand-off): Emit Hand-off to Plan

Read the incoming `### Hand-off to Design` block from the entity body (written by ship-shape Phase 8). Verify all `open_design_questions` and `open_contract_decisions` are resolved via `captain_decisions` before emitting. If a selector grammar/API vocabulary/protocol/schema choice remains undecided, put it in `open_decisions[]` and BLOCK plan rather than letting planner choose.

Emit `### Hand-off to Plan` (structured fields per `entity-body-schema.yaml → stages.design.hand_off_to_plan`):
- `design_constraints[]` — each item: `{type, assertion, rationale_decision: D{N}, source_artifact}` — `type` enum mandatory. UI design uses `token-binding | layout | interaction`; domain specialist design uses `contract | schema-contract | filter-contract | api-contract | data-contract | domain-contract`. `rationale_decision: D{N}` MUST cross-reference a `**D{N}|Captain decision**` in Phase 8 Captain Decisions (validated by `validate-d-references.sh`).
- `open_decisions[]` — any design decisions still pending captain input (ideally empty; non-empty → plan Step 1.6 BLOCKER).
- `artifact_paths[]` — paths to committed design artifacts (`tokens.css`, specimens, composite mockup).
- `render_fidelity_targets[]` — each item: `{selector, css_property, expected_value, rationale_decision: D{N}}` — feeds ship-verify Step 3.6 ui-verify YAML; `rationale_decision: D{N}` MUST cross-reference Phase 8.
- `whole_page_visual_targets[]` — each item: `{route, reference_artifact, capture, threshold, rationale_decision: D{N}}` — feeds plan visual-parity DCs and ship-verify whole-page screenshot comparison. Use this for whole-screen composition, spacing hierarchy, and whether the implemented page still resembles the design reference after fragments pass.

For `affects_ui: true`, the handoff MUST include non-empty `design_constraints[]`
and `render_fidelity_targets[]`, plus `whole_page_visual_targets[]` for the
primary affected route, plus a captain-visible
`### Visible UI Design Output` section in `design.md`. Category D may use a
single composite mockup or prose-plus-selector target instead of a full
`design/` artifact bundle, but it still emits a visible UI design decision and
machine-readable verification target. For non-UI domain-only design,
`whole_page_visual_targets[]` may be omitted.

**Design-skipped path** (G14): when design stage is skipped (`!affects_ui && !domain && !design_required && !contract_decision_required` route from shape), the entity body MUST still contain `### Hand-off to Plan` with single field `design-skipped: true`. Emitted by ship-shape Phase 8 hand-off only when `affects_ui: false`, `domain:` is unset, `design_required: false`, `contract_decision_required: false`, and `open_contract_decisions[]` is empty. Plan Step 1.6 reads this marker to bypass design-DC import explicitly (vs absence of the block, which is ambiguous).

If `affects_ui: true`, `domain:` is set, `design_required: true`, or
`contract_decision_required: true`, `design-skipped: true` is invalid by
default. The only valid bypass is an explicit captain marker:

```yaml
design-skipped: true
captain-approved-design-bypass: true
bypass_rationale: "..."
```

Without that marker, return BLOCKER to the first officer/planner with reason
`ui design handoff skipped`; do not let plan infer "no UI surface."

**Why D{N} backref enforced per item**: plan Step 1.6 imports each constraint as a DC and carries `rationale_decision: D{N}`; without source-side enforcement, design can emit constraints that have no captain-decision anchor, breaking audit trail. `validate-d-references.sh` (lib) catches missing/dangling D{N} refs at design Phase 9 emit-time.
<!-- /section:hand-off-to-plan -->

---

## References

- `design-flow` — Layer A delegate for contradiction-resolution Q-loop (Phase 3, #106 T5.2); fallback: `superpowers:brainstorming`
- `design-review` — adversarial cross-review agent (Phase 9, #106 T5.2); fallback: fresh sonnet subagent
- `superpowers:brainstorming` — Phase 3 fallback when `design-flow` unavailable
- `superpowers:writing-skills` — for v2 skill expansion (A/B/C/D categories)
- `plugins/ship-flow/references/entity-body-schema.yaml → stages.design` — entity body contract (added pitch-104 T5)
- `plugins/ship-flow/references/flow-map-schema.yaml → maps.plugins/spacebridge/design/design-system.md` — map-layer registration (added pitch-104 T2)
- `docs/ship-flow/_debriefs/2026-04-27-01.md` — D1-D6 captain decision origin; Issues 1 (fabricated PASS) + Observation (HTML > markdown)
- `plugins/ship-flow/lib/__tests__/test-design-dogfood.sh` — L2 strictness dogfood harness (added pitch-104 T6); `--self-test` mode proves assertion engine canonical-vs-canonical (mechanical CI). Real designer-agent dogfood = verify-stage manual invocation on `plugins/spacebridge/design-exploration-spatial.html`.
- `plugins/ship-flow/INVARIANTS.md:110` — Principle 6 Rule A (named teammate), Rule B (Layer A), Rule C (cross-review gate)
