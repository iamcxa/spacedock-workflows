<!--
Snapshot from gstack design-shotgun (2026-05-12)
Source: design-shotgun/SKILL.md:1034-1162
Purpose: ship-flow design-officer multi-variant ideation discipline
After /spacedock:overhaul: plugins/ship-flow/lib/design-methodology/shotgun.md

Adaptations from source:
- $D image generation binary → text-based markdown variants (mood, palette, layout description, sample HTML snippet)
- Comparison board UI → markdown comparison table in <entity>/design-explore/variants.md
- Parallel Agent dispatch for PNG generation → design-officer can self-dispatch parallel Claude subagents for text variants if scope warrants, OR generate sequentially in single context
- approved.json file → captain commits selection via Shift+Down dialogue
-->

# Multi-Variant Ideation Discipline (Shotgun)

When ship-design worker SendMessages design-officer asking for visual variants (sidebar IA, hero treatment, dashboard layout, etc.), follow this discipline.

## Anti-convergence directive (HARD requirement)

**Each variant MUST use a different font family, color palette, and layout approach.** If two variants look like siblings — same typographic feel, overlapping color temperature, comparable layout rhythm — one of them failed. Regenerate the weaker one with a deliberately different direction.

**Concrete test**: if someone could swap the headline text between two variants without noticing, they're too similar. Variants should feel like they came from three different design teams, not the same team at three different coffee levels.

This applies across SESSION history too: if a prior entity used Geist + dark + editorial, don't propose that combo again for a new entity unless you explicitly say "I'm doubling down because it fits the brief." Convergence across generations is slop.

## Step 1: Concept Generation (text-first, no rendering yet)

Before producing any markdown specs or HTML samples, generate N text concepts describing each variant's design direction. Each concept must be a **distinct creative direction**, not a minor variation.

Present as a lettered list:

```
For Entity <X>'s <design problem>, I'll explore 3 directions:

A) "Editorial Restraint" — Instrument Serif headlines, generous whitespace,
   monochrome with one cyan accent. Reads like a serious magazine.

B) "Brutalist Density" — IBM Plex Mono throughout, no decoration,
   data-first layout, exposed grid. Feels like a power-user tool.

C) "Toy-like Approachability" — General Sans rounded display, playful
   coral + cream palette, bouncy spacing. Reads as friendly and unintimidating.
```

Draw on:
- The entity's shape.md problem framing
- DESIGN.md if it exists in the repo
- Session-accumulated taste memory (see §Taste Memory below)
- Captain's stated audience (power user vs end-user, internal vs external)

## Step 2: Concept Confirmation

SendMessage back to ship-design worker (or wait for captain Shift+Down) with the 3 concepts. **Do not produce full specs yet** — that's expensive. Confirm the directions first.

Phrasing in the message:

```
3 directions sketched for <X>:
[concept list above]

These feel sufficiently differentiated to me (different fonts / palettes /
density). Confirm before I write full specs?

- Reply "go" → I produce full markdown specs for all 3
- Reply "swap B for X" → I replace B with your suggestion
- Reply "add D: Y" → I add a 4th direction
- Reply "drop A" → I produce specs for B and C only
- Captain Shift+Down for live dialogue if direction feels off
```

If captain pushes back on differentiation ("B and C feel similar to me"), regenerate the weaker one with a deliberately different direction. Max 2 rounds of concept-confirmation.

## Step 3: Full Variant Specs (after confirmation)

For each confirmed concept, produce a markdown spec at `<entity>/design-explore/variant-<letter>.md`:

```markdown
# Variant A — "Editorial Restraint"

## Aesthetic thesis
One sentence on mood, material, energy.
e.g., "Serious magazine for serious work. Type does all the work; color is rare and meaningful."

## Typography
- Display: Instrument Serif, weights 400/500
- Body: Instrument Sans, weights 400/500
- Data/code: Geist Mono (tabular-nums for tables)
- Sizes: 14px body, 18px subhead, 32px display, 64px hero
- Line height: 1.6 body, 1.2 display

## Color
- Background: #fafaf7 (warm off-white)
- Surface: #ffffff
- Primary text: #1a1a1a
- Muted text: #6b6b6b
- Accent: #00afff (use sparingly — links, primary CTAs)
- Semantic: avoid until needed

## Layout
- Single-column reading view, max-width 720px
- Sidebar 240px fixed-width (collapsible on <768px)
- 8px spacing scale: 8, 16, 24, 32, 48, 64, 96
- Asymmetric grid for marketing-style sections (1fr 2fr)

## Decoration
Minimal. No icons in colored circles, no gradients, no border-radius >4px.
A single hairline rule (`1px solid #e5e5e5`) separates sections.

## Motion
Functional only. 150ms fade-in on dialogs, no scroll-triggered animations,
no entrance choreography.

## Sample HTML snippet
[Optional: 30-50 lines of HTML/CSS showing the core composition,
inline styles for clarity, no framework boilerplate]

## What this variant gains
- Reads as quality and seriousness
- Hierarchy is unmissable
- Ages well (no trendy patterns to date the design)

## What this variant costs
- Less personality / brand visibility
- Lower contrast than dark themes for some users
- Type-heavy means content quality matters more
```

Repeat for each variant. **Keep specs equally complete** — don't favor one with more detail.

## Step 4: Comparison + captain selection

After all variants are written, create `<entity>/design-explore/variants.md` as a side-by-side comparison:

```markdown
# Variants Comparison for <Entity>

| Dimension | A. Editorial Restraint | B. Brutalist Density | C. Toy-like Approachability |
|---|---|---|---|
| Mood | Serious | Power-user | Friendly |
| Primary font | Instrument Serif | IBM Plex Mono | General Sans |
| Palette | Warm neutrals + cyan | Pure mono + green terminal | Coral + cream + navy |
| Density | Spacious | Dense | Moderate |
| Best for | Reading-heavy | Data-heavy | Onboarding-heavy |
| Worst for | Data tables | Marketing pages | Serious enterprise |

[Then 3 sub-sections, one per variant, with full specs linked]

## Recommendation

[Optional: if one variant fits the entity's shape.md problem framing
significantly better, state it and say why. Otherwise: "All 3 are
viable; the choice depends on which user identity you're prioritizing."]

## Selection mechanism

Captain reads this file, then either:
- Shift+Down to design-officer pane and say "Go with B, but lighten the
  background"
- Comment in chat: "B with A's typography"
- Write selection directly into <entity>/design.md and SendMessage
  design-officer "design.md updated; you can stop tracking variants"
```

SendMessage ship-design worker: `Variants ready at <entity>/design-explore/variants.md. Captain selecting.`

## Step 5: Selection commit

When captain selects (via Shift+Down dialogue or chat):
1. design-officer copies the chosen variant's spec into `<entity>/design.md` (canonical artifact ship-design worker reads)
2. If captain modified during selection ("B but with cream not coral"), update the spec to reflect modifications BEFORE writing to design.md
3. Update session taste memory:
   - Add chosen variant's font/palette/layout to "approved this session"
   - Add rejected variants' choices to "rejected this session"
4. SendMessage ship-design worker: `Selection committed to <entity>/design.md. Modifications: [list]. Proceed.`
5. Leave `<entity>/design-explore/` intact for audit trail.

## Taste Memory (session-scoped, v1)

design-officer accumulates taste signals across multiple entities in one captain session. **No cross-session persistence in v1.** When the session ends, taste resets; next session starts fresh (though design-officer's prompt knowledge is loaded from the mod file).

Track in working memory:
- Approved choices (font / color / layout / aesthetic) per entity
- Rejected choices per entity
- Captain's modifications during selection (these signal stronger preference than approve/reject alone)

When generating concepts for a new entity in the same session, factor these in:

```
"Based on entity X's selection (Editorial Restraint + Geist Mono for data),
this entity Y's variants should:
- Not repeat the exact Editorial+Geist combo (anti-convergence)
- Probably keep some-Mono for data UIs (matches approved pattern)
- Avoid coral/cream (you rejected this for X — note this is per-entity
  taste, may not apply if Y has different audience)
Confirm before I generate?"
```

**Conflict handling**: if captain explicitly requests a direction that contradicts prior session taste ("make this one playful, I know I rejected coral for X"), proceed and note: "Departing from session pattern — confirmed intentional."

**Cross-session persistence (v2)**: deferred. When/if needed, could write to `<workflow-dir>/_taste-profile.md` (workflow-scope, captain owns the file). Decay logic / approved-count tracking deferred too.

## Failure modes to avoid

- **One variant dominates** — if two of three feel like obvious losers, regenerate
- **Same brief, different polish** — concepts must be different DIRECTIONS, not the same direction at different fidelity
- **Hedging in concepts** — "A bit minimal but with some character" is two concepts collapsed; pick one and commit
- **Producing without confirmation** — full specs are expensive; concept confirmation first
- **Selection without modification** — if captain approves variant B verbatim, fine; if captain says "B with [tweaks]", apply tweaks BEFORE writing design.md
- **Forgetting to update design.md** — design-explore/ is exploration; design.md is the canonical ship-design artifact. Always write the selection to design.md.
