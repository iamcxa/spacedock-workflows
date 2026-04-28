---
name: ship-design
description: "Use when shape detects a UI pitch needs design intent before plan — UI files affected (*.tsx, *.css, *.html), or visual ambiguity, or no design reference exists. Agent-autonomous: 5-category classifier (Category 0 distill / A net-new system / B component breakout / C variation / D one-off — v1 ships Category 0 only, A/B/C/D land via carlove dogfood). Dispatched by /ship to `designer@pitch-XX` teammate (opus). Output: `<entity-folder>/design.md` + `plugins/<app>/design/*` artifact bundle. Layer A delegation: storyboard (Phase 1.5 user-flow narrative) + design-flow (Phase 3 contradiction Q-loop) + design-review (Phase 9 adversarial); fallback superpowers:brainstorming when design plugins absent."
user-invocable: false
argument-hint: "[entity-id | slug]"
---

# ship-design

Design intent capture stage for UI pitches. Runs between shape and plan when trigger fires. Named designer agent produces design artifacts captain can review before plan stage — preventing the 3-cross-review fix loop + captain dogfood failure that pitch-103 required (18 files / 3641 LOC Mega 1.5 spike from misaligned design intent).

**Stage-skill count**: adding ship-design makes **7/7** (ship-shape / ship / ship-plan / ship-execute / ship-verify / ship-review / ship-design = hard cap per Principle 2). No further stage-skills can be added without first folding or extracting an existing one.

---

## Boot Self-Check

Run before any design work. Stop and SendMessage(FO) if any check fails.

1. **Trigger valid**: entity has `affects_ui: true` OR `--design` flag OR files match `*.tsx|*.css|*.html`. If no trigger → skip design stage, SendMessage(planner): "Design trigger absent — routing directly to plan."
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
- `affects_ui: true` in entity frontmatter (set by shape stage when pitch touches frontend)
- `Files modified` or `architecture-impact` cites path matching glob `*.tsx | *.css | *.html`
- Captain explicit `--design` flag on `/shape` invocation

Otherwise: auto-skip to plan per `skip-when: "!affects_ui"` in `docs/ship-flow/README.md` stages.states.

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

## 5-Category classifier (v1 = Category 0 only)

| Category | Trigger | v1 |
|---|---|---|
| 0 — Distill from existing exploration | Shape cites exploratory HTML/markdown at file:line; contains ≥2 conflicting design directions | SHIPS v1 |
| A — Net-new design system | `plugins/<app>/design/` directory absent; first-ever design for this app | DEFERRED (carlove dogfood) |
| B — Component breakout | design-system.md exists; new component specimen needed | DEFERRED |
| C — Variation on existing component | design-system.md exists; variant on component spec | DEFERRED |
| D — One-off visual | Pitch-local mockup only; does NOT touch design-system.md | DEFERRED |

**When Category != 0**: report `"Category {X} deferred to carlove dogfood pitch ship-flow-carlove-sync-abcd-dogfood; halt design stage; route to plan with no design output"` and exit. Do NOT fabricate output.

---

## Flow

### Phase 0 — Route

1. Read entity spec.md. Determine category per classifier table.
2. If Category != 0: emit halt message and exit (no design.md written).
3. Proceed to Phase 1 (Category 0 path).

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
   - `## Design Output / ### Captain Decisions` — list all `D{N}|Captain decision` entries with file:line contradiction cite.
   - `## Design Output / ### Artifact Bundle Manifest` — table (Path / Type / Purpose) of all emitted files.
   - `## Design Output / ### Constraints for Plan Stage` — token / interaction constraints plan stage MUST honor.
   - `## Design Report` — status / stage_cost / iterations / contradictions_resolved / captain_decisions / reviewer_verdict.

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

Emit `### Hand-off to Plan`:
- `design_constraints`: visual / token / interaction constraints plan MUST honor (source: captain_decisions)
- `open_decisions`: any design decisions still pending captain input (ideally empty)
- `artifact_paths`: paths to committed design artifacts (tokens.css, specimens, composite mockup)
- `render_fidelity_targets`: specific render fidelity checks plan should encode as DCs — e.g., "var(--primary) used for CTA buttons (not #3b82f6)", "ViewSwitcher is interactive `<button>` not static `<div>`", "sidebar is full-height flex column not floating overlay"
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
