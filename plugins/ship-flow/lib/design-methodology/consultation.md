<!--
Snapshot from gstack design-consultation (2026-05-12)
Source: design-consultation/SKILL.md:943-1230
Purpose: ship-flow design-officer research-grounded proposal flow
After /spacedock:overhaul: plugins/ship-flow/lib/design-methodology/consultation.md

Adaptations from source:
- AskUserQuestion → SendMessage / Shift+Down dialogue
- ~/.gstack/projects/$SLUG/taste-profile.json → session-scoped memory (see shotgun.md §Taste Memory)
- $B browse daemon → /browse skill (Tier 1) for competitive research
- gstack-slug binary references stripped
- Codex Outside Voice block preserved (Tier A only, runtime detected per §3.6)
-->

# Research-Grounded Design Proposal Flow

When ship-design worker SendMessages design-officer asking for a **complete design system** (not just variants for one screen — full aesthetic/typography/color/spacing/motion proposal), follow this flow.

Trigger: entity has no DESIGN.md AND scope is significant (greenfield, redesign, new product surface). For variants of an existing system, use `shotgun.md` instead.

## Phase 1: Product Context

design-officer needs to understand WHAT the product is, WHO it's for, and WHAT space before proposing.

Read first (don't ask the captain things you can derive from files):
- Entity `shape.md` — problem, appetite, target user, scope boundaries
- Repo `README.md` — product positioning
- Existing `DESIGN.md` if any — current design tokens (treat as constraints unless captain says rewrite)

Then SendMessage captain (or wait for Shift+Down) with a context check:

```
Reading entity X's shape.md + README, I see this is <product type> for
<audience> in the <space> domain. Sound right?

One forcing question before I propose:

**What's the ONE thing you want someone to remember after they see this
product for the first time?**

One sentence answer. Could be a feeling ("this is serious software for
serious work"), a visual ("the blue that's almost black"), a claim
("faster than anything else"), or a posture ("for builders, not managers").

Every subsequent design decision will serve this memorable thing.
Design that tries to be memorable for everything is memorable for nothing.

Also: want me to research what top products in your space are doing
(competitive look)? Yes / No.
```

Write captain's answer to `<entity>/design-explore/memorable-thing.md` — this becomes the touchstone every variant and proposal references.

## Phase 2: Research (only if captain said yes)

### Step 1: Identify the landscape via WebSearch

Use WebSearch (Tier 1) to find 5-10 products in the space:
- "[product category] website design"
- "[product category] best websites 2026"
- "best [industry] web apps"

### Step 2: Visual research via /browse (if Tier 1 browse available)

For each top result, fetch via `/browse`:
- Take a screenshot of homepage and 1-2 deep pages
- Note: fonts actually used, color palette, layout approach, spacing density, aesthetic direction

If a site blocks headless browse or requires login: skip, note why.

If `/browse` not available: rely on WebSearch results + your built-in design knowledge. This is still good — just thinner.

### Step 3: Three-layer synthesis

- **Layer 1 (tried and true)**: What patterns does every product in this category share? Table stakes — users expect them.
- **Layer 2 (new and popular)**: What's trending in current discourse? What new patterns are emerging?
- **Layer 3 (first principles)**: Given what we know about THIS product's users and positioning — is there a reason the conventional design approach is wrong? Where should we deliberately break from category norms?

### Eureka check

If Layer 3 reasoning reveals a genuine design insight — a reason the category's visual language fails THIS product — name it explicitly:

> **EUREKA**: Every [category] product does X because they assume [assumption]. But this product's users [evidence] — so we should do Y instead.

Write the eureka (if any) to `<entity>/design-explore/research.md`.

Summarize the landscape to captain:

```
Landscape for <space>:
- They converge on [patterns]
- Most feel [observation — e.g., interchangeable, polished but generic]
- The opportunity to stand out is [gap]

[Eureka if any]

Here's where I'd play safe and where I'd take risk... [preview of Phase 3]
```

## Phase 2.5: Outside Voices (optional, parallel)

If Tier A (Codex available, see Codex Fallback Ladder §3.6), design-officer can dispatch **outside voices** for cross-perspective:

### Codex design voice (via Bash, Tier A only)

```bash
TMPERR=$(mktemp /tmp/codex-design-XXXXXXXX)
codex exec "Given this product context [paste context summary],
propose a complete design direction:
- Visual thesis: one sentence (mood, material, energy)
- Typography: specific font names (no Inter/Roboto/Arial/system) + hex
- Color system: CSS variables (background, surface, primary, muted, accent)
- Layout: composition-first; first viewport as poster, not document
- Differentiation: 2 deliberate departures from category norms
- Anti-slop: no purple gradients, no 3-column icon grids, no centered
  everything, no decorative blobs

Be opinionated. Be specific. No hedging. This is YOUR direction — own it." \
  -s read-only -c 'model_reasoning_effort="medium"' --enable web_search_cached \
  </dev/null 2>"$TMPERR"
```

Timeout 5 minutes. On any Codex error: continue without Codex voice; tag the final proposal `[single-model]`.

### Claude subagent design voice (always available in Tier A/B)

Dispatch a fresh Claude subagent via Agent tool:

> Prompt: "Given this product context [paste], propose a design direction that would SURPRISE. What would the cool indie studio do that the enterprise UI team wouldn't?
> - Aesthetic direction, typography stack (specific font names), color palette (hex)
> - 2 deliberate departures from category norms
> - What emotional reaction should the user have in the first 3 seconds?
> Be bold. Be specific. No hedging."

Wait for both voices. Synthesize: where do they agree? where do they diverge? Use the divergence to inform Phase 3's SAFE/RISK breakdown.

Outside voices are **non-blocking** — if either fails or times out, proceed with design-officer's own proposal.

## Phase 3: The Complete Proposal

This is the soul of the methodology. Propose EVERYTHING as ONE coherent package.

SendMessage captain with this format:

```
Based on [product context] and [research findings / my design knowledge]:

AESTHETIC: [direction] — [one-line rationale]
DECORATION: [level] — [why this pairs with the aesthetic]
LAYOUT: [approach] — [why this fits the product type]
COLOR: [approach] + proposed palette (hex values) — [rationale]
TYPOGRAPHY: [3 font recommendations with roles] — [why these fonts]
SPACING: [base unit + density] — [rationale]
MOTION: [approach] — [rationale]

This system is coherent because [explain how choices reinforce each other,
referencing the memorable-thing from Phase 1].

SAFE CHOICES (category baseline — your users expect these):
- [2-3 decisions that match category conventions, with rationale for playing safe]

RISKS (where your product gets its own face):
- [2-3 deliberate departures from convention]
- For each risk: what it is, why it works, what you gain, what it costs

The safe choices keep you literate in your category. The risks are where
your product becomes memorable. Which risks appeal? Want different ones?
Adjust anything?

Options to reply:
A) Looks great — write to DESIGN.md
B) Adjust [section]
C) Different risks — show me wilder options
D) Start over with a different direction
```

The SAFE/RISK breakdown is **critical**. Design coherence is table stakes — every product in a category can be coherent and still look identical. The real question is: where do you take creative risks? Always propose at least 2 risks.

Write the proposal to `<entity>/design-explore/proposal.md` so captain can read it in editor too.

## Phase 4: Drill-downs (only if captain wants adjustments)

When captain wants to change a specific section, go deep on that section in dialogue:

- **Fonts**: Present 3-5 specific candidates with rationale, explain what each evokes
- **Colors**: Present 2-3 palette options with hex values, explain color theory reasoning
- **Aesthetic**: Walk through which directions fit and why
- **Layout/Spacing/Motion**: Present approaches with concrete tradeoffs

Each drill-down is one focused message exchange. After captain decides, re-check coherence with the rest of the system.

## Phase 5: Commit to DESIGN.md

When captain approves the proposal (option A or after drill-downs):

1. Write canonical `DESIGN.md` in repo root with:
   - Memorable thing (one sentence)
   - Design tokens (CSS variables format)
   - Typography (font families, sizes, weights, line heights)
   - Color system (background, surface, text, muted, accent, semantic)
   - Spacing scale
   - Layout approach
   - Motion conventions
   - "Do not flag" list (deliberate departures from convention)

2. Write to entity's `design.md` referencing DESIGN.md ("Inherits from repo DESIGN.md").

3. SendMessage ship-design worker: `DESIGN.md committed to repo root. Entity design.md inherits. Proceed.`

## Coherence Validation

When captain overrides one section, check if the rest still coheres. Flag mismatches with a **gentle nudge** — never block:

- Brutalist/Minimal aesthetic + expressive motion → "Heads up: brutalist usually pairs with minimal motion. Your combo is unusual — fine if intentional. Want me to suggest motion that fits, or keep?"
- Expressive color + restrained decoration → "Bold palette with minimal decoration can work, but colors will carry a lot of weight. Want decoration that supports the palette?"
- Creative-editorial layout + data-heavy product → "Editorial layouts are gorgeous but fight data density. Want me to show how a hybrid keeps both?"

Always accept captain's final choice. Never refuse to proceed.

---

## design-officer Design Knowledge (use to inform proposals — DO NOT display as tables)

### Aesthetic directions (pick the one that fits the product)

- **Brutally Minimal** — Type and whitespace only. No decoration. Modernist.
- **Maximalist Chaos** — Dense, layered, pattern-heavy. Y2K meets contemporary.
- **Retro-Futuristic** — Vintage tech nostalgia. CRT glow, pixel grids, warm monospace.
- **Luxury/Refined** — Serifs, high contrast, generous whitespace, precious metals.
- **Playful/Toy-like** — Rounded, bouncy, bold primaries. Approachable and fun.
- **Editorial/Magazine** — Strong typographic hierarchy, asymmetric grids, pull quotes.
- **Brutalist/Raw** — Exposed structure, system fonts, visible grid, no polish.
- **Art Deco** — Geometric precision, metallic accents, symmetry, decorative borders.
- **Organic/Natural** — Earth tones, rounded forms, hand-drawn texture, grain.
- **Industrial/Utilitarian** — Function-first, data-dense, monospace accents, muted palette.

### Decoration levels

- **Minimal** — typography does all the work
- **Intentional** — subtle texture, grain, or background treatment
- **Expressive** — full creative direction, layered depth, patterns

### Layout approaches

- **Grid-disciplined** — strict columns, predictable alignment
- **Creative-editorial** — asymmetry, overlap, grid-breaking
- **Hybrid** — grid for app, creative for marketing

### Color approaches

- **Restrained** — 1 accent + neutrals, color is rare and meaningful
- **Balanced** — primary + secondary, semantic colors for hierarchy
- **Expressive** — color as a primary design tool, bold palettes

### Motion approaches

- **Minimal-functional** — only transitions that aid comprehension
- **Intentional** — subtle entrance animations, meaningful state transitions
- **Expressive** — full choreography, scroll-driven, playful

### Font recommendations by purpose

- **Display/Hero**: Satoshi, General Sans, Instrument Serif, Fraunces, Clash Grotesk, Cabinet Grotesk
- **Body**: Instrument Sans, DM Sans, Source Sans 3, Geist, Plus Jakarta Sans, Outfit
- **Data/Tables**: Geist (tabular-nums), DM Sans (tabular-nums), JetBrains Mono, IBM Plex Mono
- **Code**: JetBrains Mono, Fira Code, Berkeley Mono, Geist Mono

### Font blacklist (never recommend)

Papyrus, Comic Sans, Lobster, Impact, Jokerman, Bleeding Cowboys, Permanent Marker, Bradley Hand, Brush Script, Hobo, Trajan, Raleway, Clash Display, Courier New (for body).

### Overused fonts (never as primary — only if captain asks by name)

Inter, Roboto, Arial, Helvetica, Open Sans, Lato, Montserrat, Poppins, Space Grotesk.

Space Grotesk is on this list because every AI design tool converges on it as "the safe alternative to Inter." That's the convergence trap. Treat it the same as Inter: only use if captain requests it by name.

### AI slop anti-patterns (NEVER include in your recommendations)

- Purple/violet gradients as default accent
- 3-column feature grid with icons in colored circles
- Centered everything with uniform spacing
- Uniform bubbly border-radius on all elements (16px+ on everything)
- Gradient buttons as the primary CTA pattern
- Generic stock-photo-style hero sections
- `system-ui` / `-apple-system` as the primary display or body font (the "I gave up on typography" signal)
- "Built for X" / "Designed for Y" / "Unlock the power of" marketing copy patterns
