---
name: ship-design
description: "Use when shape detects a UI or domain pitch needs design intent before plan — UI files affected (*.tsx, *.css, *.html), visual ambiguity, no design reference exists, or registered domain frontmatter is present. Agent-autonomous: 5-category classifier (Category 0 distill / A net-new system / B component breakout / C variation / D one-off) plus design-dispatch-manifest routing for ui-designer and domain-designer workers. Output: `<entity-folder>/design.md` + optional `plugins/<app>/design/*` artifact bundle. Layer A delegation: storyboard, design-flow, frontend-design, design-review; fallback superpowers:brainstorming when design plugins absent."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# ship-design

Design intent capture stage for UI pitches. Runs between shape and plan when trigger fires. Named designer agent produces design artifacts captain can review before plan stage — preventing the 3-cross-review fix loop + captain dogfood failure that pitch-103 required (18 files / 3641 LOC Mega 1.5 spike from misaligned design intent).

**Stage-skill count**: adding ship-design makes **7/7** (ship-shape / ship / ship-plan / ship-execute / ship-verify / ship-review / ship-design = hard cap per Principle 2). No further stage-skills can be added without first folding or extracting an existing one.

---

## Boot Self-Check

Run before any design work. Stop and SendMessage(FO) if any check fails.

1. **Trigger valid**: entity has `affects_ui: true` OR `domain:` frontmatter registered in registry OR `--design` flag OR files match `*.tsx|*.css|*.html`. If `skip-when: "!affects_ui && !domain"` matches and no explicit/file trigger is present → skip design stage, SendMessage(planner): "Design trigger absent per `skip-when: \"!affects_ui && !domain\"` — routing directly to plan."
2. **Entity status**: read entity frontmatter `status:` — must be `sharp`. If `design` → design already ran (check for re-entry signal).
3. **Hand-off to Design present**: entity body contains `### Hand-off to Design` block (from ship-shape Phase 8). If absent → SendMessage(FO): "Missing Hand-off to Design — shape stage did not complete handoff."
4. **Exploration file**: `## Sharp Output → Problem` cites a file:line. Read that file before Phase 1 — if missing → SendMessage(FO): "Exploration file not found: `<path>` — cannot distill design without source."
5. **design-flow available**: check if plugin installed. If not → note fallback to `superpowers:brainstorming` in Design Report; proceed.
6. **Density-aware skill load** (T3.4): read `answers_density` from entity frontmatter. `high` → auto-load framework skills per ship-runtime-detect Step R6; skip FO ask. `low|vacuum` → SendMessage(FO) with proposed skill list; wait for confirmation.

## Layer A delegation (Principle 6 Rule B)

`design-flow` owns the contradiction-resolution Q-loop and design distillation flow (#106 T5.2). **Do NOT re-teach this procedure.** Invoke it; Layer B below provides the Shape Up framing (5-category classifier, per-app design-system.md targeting, Material/Atlassian Principles tier separation, L2 strictness DCs).

Fallback: if `design-flow` is unavailable (plugin not installed), fall back to `superpowers:brainstorming` for contradiction resolution. Document the fallback in design.md `## Design Report`.

---

## Trigger condition

Design stage fires when ANY of:
- `affects_ui: true` in entity frontmatter (UI trigger path; set by shape stage when pitch touches frontend)
- `domain:` frontmatter set in entity, registered in registry (specialist trigger path; set by ship-shape Phase 8.5 via `registry-resolve.sh --classify`; `domain:` set_at shape)
- `Files modified` or `architecture-impact` cites path matching glob `*.tsx | *.css | *.html`
- Captain explicit `--design` flag on `/shape` invocation

Otherwise: auto-skip to plan per `skip-when: "!affects_ui && !domain"` in `docs/ship-flow/README.md` stages.states.

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

**Writes to** (`entity-body-schema.yaml → stages.design`):
- `## Design Output / ### Captain Decisions` — `D{N}|Captain decision` tagged per contradiction
- `## Design Output / ### Artifact Bundle Manifest` — table of emitted files
- `## Design Output / ### Constraints for Plan Stage` — token / interaction constraints plan must honor
- `## Design Report` — status / cost / iterations / captain_decisions count / reviewer_verdict

**Emits artifact bundle** at `plugins/<app>/design/`:
- `design-system.md` — canonical design foundations + components + patterns (map-layer registered)
- `tokens.css` — CSS custom properties (MUST be byte-equal across re-runs: load-bearing for L2 dogfood DC)
- `design-system.html` — visual gallery of all tokens in context
- `components/<name>.html` — one HTML specimen per component (visual fidelity required for captain ack)
- `war-room.html` (or app-equivalent) — composed mockup showing components in a real screen

---

## 5-Category classifier

| Category | Trigger | Active dispatch path |
|---|---|---|
| 0 — Distill from existing exploration | Shape cites exploratory HTML/markdown at file:line; contains ≥2 conflicting design directions | `ui-designer` distills existing exploration, invokes `storyboard`, `design-flow`, and `design-review` |
| Category A — Net-new design system | `plugins/<app>/design/` directory absent; first-ever design for this app | `ui-designer` runs full chain: `design-flow` using `design-brief`, `information-architecture`, `design-tokens`, `brief-to-tasks`, then `frontend-design` and `design-review` |
| Category B — Component breakout | `design-system.md` exists; new component specimen needed | `ui-designer` uses `frontend-design`, `design-tokens` if tokens change, and `design-review`; load `information-architecture` only when component placement/navigation changes |
| Category C — Variation on existing component | `design-system.md` exists; variant on component spec | `ui-designer` preserves existing design canon, uses `frontend-design`, then `design-review` |
| Category D — One-off visual | Pitch-local mockup only; does NOT touch design-system.md | `ui-designer` uses `frontend-design`; add `design-review` only for high-risk UI or accessibility-sensitive changes |

Category A-D are active. Do not halt solely because the category is A, B, C, or D.
If required design skills are missing, record the fallback in `Design Report` and
continue with the narrowest viable route.

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
      outputs: []
    - lane: domain
      role: domain-designer
      domain: schema
      required_skills: []
      knowledge_module_path: ""
      designer_section_anchor: ""
      outputs: []
  integration:
    mode: single-designer|parallel
    owner: ship-design
```

Dispatch rules:
- UI-only small Category C/D work may use `single-designer` mode with one
  `ui-designer`.
- Domain-only work may use `single-designer` mode with one `domain-designer`
  routed through the registry specialist.
- UI + domain work uses `parallel` designer dispatch: dispatch `ui-designer` and `domain-designer` concurrently, then run an integration pass in ship-design
  that merges outputs into one `design.md` handoff.
- Multi-domain or Category A + domain work defaults to `parallel`. Collapse to
  `single-designer` only when one lane is trivial and the reason is recorded in
  the manifest.

---

## Flow

### Phase 0 — Route

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
4. Read entity spec.md. Determine category per classifier table.
5. Build `design-dispatch-manifest`:
   - `affects_ui: true` → add `ui` lane with the selected Category.
   - `domain:` set → add `domain` lane with registry `required_skills`,
     `skill_hints.*`, `knowledge_module_path`, and `designer_section_anchor`.
   - both lanes present → `integration.mode: parallel`.
   - one low-risk lane present → `integration.mode: single-designer`.
6. Dispatch the manifest lanes. UI lane follows Phase 1-9. Domain lane follows
   Phase 0.5 and specialist subsection. Integration pass merges lane outputs
   before `## Constraints for Plan Stage`.

### Phase 0.5 — Specialist dispatch (domain path only)

Reached only when Phase 0 step 2 returns exit 0 (domain registered + `specialist_missing` = false).

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
4. v1 multi-domain disambiguation: if `domain:` frontmatter contains multiple names (comma-separated), use first match. v2 multi-domain dispatch is out of 113.1 scope.

**Schema specialist active as of 113.3**: `defaults.yaml` now points schema to
`designer_section_anchor: "ship-design#schema-designer"`, so schema-domain
pitches proceed to the specialist path instead of the M1 HALT path. Domains
without an anchor still use the M1 HALT-with-options surface.

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

1. Locate exploration file at path:line cited in spec.md `## Problem`.
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
   - `## Design Output / ### Captain Decisions` — list all `D{N}|Captain decision` entries with file:line contradiction cite. (Captain-readable narrative; rationale source for plan/verify cross-references via `D{N}`.)
   - `## Design Output / ### Artifact Bundle Manifest` — table (Path / Type / Purpose) of all emitted files.
   - `## Design Report` — status / stage_cost / iterations / contradictions_resolved / captain_decisions / reviewer_verdict.

**Single-source-of-truth rule** (G8 dedup, 2026-04-29): `### Hand-off to Plan` (Phase 9 hand-off block) is the **only** structured contract plan stage reads. Do NOT duplicate `design_constraints` / `render_fidelity_targets` here in `## Design Output`. Phase 8 holds captain-readable narrative + audit trail (Decisions, Manifest, Report); Phase 9 holds machine-readable contract (constraints, render-fidelity targets, artifact paths, open decisions). Plan Step 1.6 reads Phase 9 hand-off; cross-references back to Phase 8 Captain Decisions via `D{N}` markers when rationale needed.

### Phase 9 — Cross-review gate

Dispatch cross-review as a **separate agent** via `Skill: design-review` (#106 T5.2). This is an adversarial review — a fresh agent with no context from the design session evaluates the artifacts independently.

Fallback chain (Principle 6 Rule A): if `design-review` unavailable → dispatch fresh sonnet subagent with structured review prompt → if subagent also stalls → `executer` teammate inline review.

7-factor rubric adapted for design stage (per INVARIANTS Principle 6 Rule C #106 T1.3 + T6.4):
| Factor | Assert |
|---|---|
| Feasibility | captain Q-loop delivered ≥6 decisions for ≥6 contradictions? |
| Executable scope | design-system.md + components + composite mockup all emitted? |
| Quality | canonical section anchors + decision tags present? |
| DC adequacy | every captain decision has `D{N}\|Captain decision` marker at decision point? |
| Canonical sync | design.md (entity) cites design-system.md (canonical) cite-pair? |
| **Reverse-audit previous stage** | does the design expose a gap in the preceding sharp/shape stage's `### Hand-off to Design` block? Specifically: are all `open_design_questions` resolved in captain_decisions? Does `render_fidelity_targets` include token alignment checks for any Tailwind v4 `theme_indirection` detected? |
| **Render Fidelity + captain-ack audit trail** | (T6.4) does `render_fidelity_targets` in Hand-off to Plan include ≥1 token alignment check per D{N} decision? Are HTML specimens visual-only (not interactive stubs)? Is tokens.css byte-stable (no renamed properties)? |

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

- Category != 0 → halt and report deferral (v1 scope).
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

<!-- section:hand_off_to_plan -->
## Phase 9 (Hand-off): Emit Hand-off to Plan

Read the incoming `### Hand-off to Design` block from the entity body (written by ship-shape Phase 8). Verify all `open_design_questions` are resolved via `captain_decisions` before emitting.

Emit `### Hand-off to Plan` (structured fields per `entity-body-schema.yaml → stages.design.hand_off_to_plan`):
- `design_constraints[]` — each item: `{type: token-binding | layout | interaction, assertion, rationale_decision: D{N}, source_artifact}` — `type` enum mandatory; `rationale_decision: D{N}` MUST cross-reference a `**D{N}|Captain decision**` in Phase 8 Captain Decisions (validated by `validate-d-references.sh`).
- `open_decisions[]` — any design decisions still pending captain input (ideally empty; non-empty → plan Step 1.6 BLOCKER).
- `artifact_paths[]` — paths to committed design artifacts (`tokens.css`, specimens, composite mockup).
- `render_fidelity_targets[]` — each item: `{selector, css_property, expected_value, rationale_decision: D{N}}` — feeds ship-verify Step 3.6 ui-verify YAML; `rationale_decision: D{N}` MUST cross-reference Phase 8.

**Design-skipped path** (G14): when design stage is skipped (`!affects_ui` route from shape), the entity body MUST still contain `### Hand-off to Plan` with single field `design-skipped: true`. Emitted by ship-shape Phase 8 hand-off when `affects_ui: false`. Plan Step 1.6 reads this marker to bypass design-DC import explicitly (vs absence of the block, which is ambiguous).

**Why D{N} backref enforced per item**: plan Step 1.6 imports each constraint as a DC and carries `rationale_decision: D{N}`; without source-side enforcement, design can emit constraints that have no captain-decision anchor, breaking audit trail. `validate-d-references.sh` (lib) catches missing/dangling D{N} refs at design Phase 9 emit-time.
<!-- /section:hand_off_to_plan -->

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
