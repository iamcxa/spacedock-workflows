<!--
Snapshot from gstack design-html (2026-05-12)
Source: design-html/SKILL.md:906-1100
Purpose: ship-flow design-officer production HTML/CSS generation
Extracted into ship-flow plugin at lib/design-methodology/html-generation.md

Adaptations from source:
- ~/.gstack/projects/$SLUG/{ceo-plans,designs}/ paths → <entity>/design-explore/ + design.md
- approved.json + variant-*.png → variant-<letter>.md text specs
- Pretext-specific routing preserved as ONE valid output style (when project uses Pretext), but framework detection routes to project's actual framework
- $D image binary references stripped
-->

# Production HTML/CSS Generation

When ship-design worker (or captain via Shift+Down) asks design-officer to produce **working HTML/CSS** from an approved variant or DESIGN.md, follow this flow.

This typically happens AFTER `shotgun.md` (variant selected) or `consultation.md` (design system approved). For a one-shot design without prior variant work, route through Phase 1 of `consultation.md` first to establish design tokens.

## Step 0: Input Detection

design-officer detects what design context exists for this entity:

```bash
ENTITY_DIR=<entity-folder-path>
test -f "$ENTITY_DIR/design.md"        && echo "DESIGN_MD: $ENTITY_DIR/design.md"
test -d "$ENTITY_DIR/design-explore"   && ls "$ENTITY_DIR/design-explore/" 2>/dev/null
test -f "$(git rev-parse --show-toplevel)/DESIGN.md" && echo "REPO_DESIGN_MD: exists"
```

Route based on what's found:

### Case A: `<entity>/design.md` exists with full spec

This is the canonical artifact. Read it. It should contain typography, color, layout, spacing tokens (either inline or by reference to repo `DESIGN.md`).

If captain previously approved a variant via `shotgun.md`, design.md will already reflect that selection.

Proceed to Step 1 with design.md as the source of truth.

### Case B: design-explore/ has variants but design.md is empty

Variants exist but captain hasn't selected. SendMessage captain:

```
I see <N> variants in design-explore/ but no selection committed to
design.md yet. Want to select first?

A) Select <letter> — I'll commit it to design.md
B) I'm still deciding — Shift+Down to talk through them
C) Skip variant flow — produce HTML from <repo>/DESIGN.md instead
```

Don't produce HTML without a selection. The variant flow exists for a reason — pre-empting it loses the captain's intentional direction.

### Case C: design.md missing, no variants, repo DESIGN.md exists

Use repo DESIGN.md as source of truth. SendMessage captain:

```
No entity-level design.md, but repo DESIGN.md has system tokens. I'll
produce HTML using the system. Confirm a screen name for the output?
(e.g., "dashboard", "landing", "settings")
```

### Case D: Nothing found (clean slate)

Reroute:

```
No design context for this entity. Options:

A) Run consultation.md flow first — propose complete design system (slower
   but produces canonical DESIGN.md for the whole project)
B) Run shotgun.md flow first — explore variants for THIS screen only
C) Just describe it — tell me what you want and I'll design + HTML live
```

Wait for captain decision. Do NOT silently freeform.

### Context summary

After routing, write to working memory:
- **Mode**: design-committed | repo-system | freeform
- **Source of truth**: path to design.md / DESIGN.md / inline freeform spec
- **Screen name**: from entity slug, captain-provided, or inferred

## Step 1: Design Analysis

Read the source of truth (design.md / DESIGN.md / freeform spec) and extract an **implementation spec**:

- **Colors**: hex values, CSS variable names
- **Typography**: font families (with @import or local source), weights, sizes per role
- **Spacing**: base unit (4px or 8px), scale (e.g., 4, 8, 12, 16, 24, 32, 48, 64)
- **Component inventory**: header, hero, card, button, form, table, modal, etc.
- **Layout type**: single-column, grid-disciplined, creative-editorial, hybrid
- **Motion**: which transitions, which durations

Output the spec inline in a `## Implementation Spec` section of working notes (don't commit yet). This is your blueprint.

If the source has gaps (e.g., design.md specifies fonts but no spacing scale), fill them in using `consultation.md`'s design knowledge — pick coherent defaults. Note the inferences explicitly: "Spacing scale inferred as 8px-based (not specified in design.md)".

## Step 2: Framework Detection

Detect the project's frontend framework:

```bash
[ -f package.json ] && cat package.json | grep -oE '"(react|svelte|vue|@angular/core|solid-js|preact|astro|next|remix|nuxt|sveltekit)"' | head -1 || echo "NONE"
```

Routing:

| Detected | Default output |
|---|---|
| react / next / remix | `.tsx` component (or `.jsx` if no TS) |
| svelte / sveltekit | `.svelte` component |
| vue / nuxt | `.vue` component |
| solid-js | `.tsx` component |
| astro | `.astro` component |
| none | self-contained `.html` |

If a framework is detected, SendMessage captain:

```
Detected <framework>. Output format?

A) Framework component (.tsx / .svelte / .vue) — production-fit, slots into
   your codebase
B) Self-contained .html — fast preview, single file, no framework deps
C) Both — preview .html first, then component when approved
```

Default to A for production work, B for "I just want to see what it looks like" exploration.

If framework=none: default to self-contained HTML.

## Step 3: Generate HTML/CSS

### Conventions (all output)

- **Semantic HTML**: `<header>`, `<nav>`, `<main>`, `<section>`, `<article>`, `<footer>`. No `<div>` soup.
- **Accessible by default**:
  - All interactive elements keyboard-reachable
  - `:focus-visible` styled (never `outline: none` without replacement)
  - Color contrast ≥ AA (4.5:1 body, 3:1 large text)
  - ARIA labels on icon-only buttons
  - Touch targets ≥ 44px on mobile
- **Real content, not lorem ipsum**: Generate plausible content based on the entity's product context. If captain is building a CRM, write CRM-realistic content (real-sounding contact names, deal stages, dates) — not "Lorem ipsum dolor sit amet."
- **Tokens as CSS variables**: Even in framework output, use `:root { --color-bg: ...; --space-md: ...; }` for tokens. Hardcoded values are forbidden except for one-off layout.
- **No `!important`**: Specificity escape hatches indicate confused CSS. Fix the cascade properly.
- **Mobile-first**: write base styles for narrow viewport, add `@media (min-width: ...)` for larger.

### Style depending on aesthetic

Match the aesthetic from design.md / DESIGN.md:

- **Brutally Minimal**: Type + whitespace. No box-shadow. No border-radius. No animations beyond functional fades.
- **Brutalist/Raw**: Exposed grid (visible borders OK), system or mono fonts, no polish.
- **Editorial/Magazine**: Asymmetric grids (CSS Grid with `grid-template-columns: 1fr 2fr 1fr`), pull quotes, large display type.
- **Playful/Toy-like**: Rounded corners (uniform, this is the ONE place uniform border-radius is on-brand), bold primaries, slight scale on hover.
- **Luxury/Refined**: Serif headlines, generous spacing, gold/copper accents (sparingly), high contrast.
- **Retro-Futuristic**: Mono fonts, CRT-glow shadows on focus states, pixel-grid borders.

NEVER apply AI slop anti-patterns (see `consultation.md` §AI slop anti-patterns).

### Pretext routing (only if project uses Pretext)

If the project has Pretext in dependencies (`@chenglou/pretext`), route layout to Pretext APIs:

| Design type | Pretext APIs |
|---|---|
| Simple layout (landing, marketing) | `prepare()` + `layout()` |
| Card/grid (dashboard, listing) | `prepare()` + `layout()` |
| Chat/messaging UI | `prepareWithSegments()` + `walkLineRanges()` |
| Content-heavy (editorial, blog) | `prepareWithSegments()` + `layoutNextLine()` |
| Complex editorial | Full engine + `layoutWithLines()` |

State the chosen tier and why in a comment at the top of the output file.

If the project does NOT use Pretext: use plain CSS Grid / Flexbox. Don't introduce Pretext unless captain asks.

## Step 4: Output

### Self-contained HTML

Write to `<entity>/design-explore/<screen-name>.html`. Single file, all CSS inline in `<style>`, no external dependencies (or CDN imports if absolutely needed — note them as comments).

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title><Entity> — <Screen></title>
  <style>
    :root {
      --color-bg: #fafaf7;
      --color-text: #1a1a1a;
      /* ... tokens from design.md */
    }
    /* ... styles per implementation spec */
  </style>
</head>
<body>
  <!-- semantic HTML per layout type -->
</body>
</html>
```

### Framework component

Write to the project's component path (ask captain if unsure; common conventions: `src/components/` for React, `src/lib/components/` for Svelte). Output uses project's existing token system if one exists (Tailwind config, CSS variable file, etc.) — don't duplicate tokens locally.

After writing, SendMessage captain:

```
HTML/CSS produced at <path>:
- Mode: <framework | self-contained>
- Tokens: <inline | inherits from repo design tokens>
- Lines: <count>
- Notes: <any inferences / gaps from design.md>

Open <path> in browser to preview. Reply:
A) Ships — commit to design.md or PR
B) Adjust [section]
C) Regenerate with different approach
```

## Step 5: Iteration

If captain says "adjust X":
- Make the specific change
- Re-output (or use Edit tool on the existing file if change is small)
- Re-send the preview message

Max 5 iteration rounds before stepping back: "We've iterated 5 times. Want to step back to design.md and re-think the underlying spec?"

## Failure modes to avoid

- **Lorem ipsum content** — always real content from context
- **`<div>` everywhere** — semantic tags exist for a reason
- **`outline: none`** without replacement — kills keyboard accessibility
- **Inferring framework without asking** — if Next vs Remix matters for routing patterns, ask
- **Hardcoded colors instead of tokens** — even for one-off, use CSS variable
- **AI slop visual patterns** — purple gradients, 3-icon-circle grids, uniform 16px+ border-radius on everything, "Built for X" copy. Auto-reject in self-check.
- **Producing HTML without spec** — if no design.md / DESIGN.md / freeform spec, route back to Case D (clean slate). Never freeform-improvise.
