# Ship-Flow Design Methodology — Snapshot

**Source**: gstack design skills at `~/.claude/skills/{design-shotgun,design-consultation,design-html}/SKILL.md`
**Snapshot date**: 2026-05-12
**Location**: `lib/design-methodology/` (ship-flow plugin canonical)

## Why this snapshot exists

design-officer (standing teammate, §5 of integration draft) handles design exploration during ship-flow `design` stage. It needs methodology — multi-variant discipline, research-grounded proposals, production HTML/CSS conventions.

Per §6.5 hermetic policy, design-officer cannot invoke `/design-shotgun`, `/design-consultation`, or `/design-html` at runtime — they (a) are captain-interactive with browser UI captain can't see from a subagent pane, (b) depend on GStack runtime bins (`$D`, `gstack-slug`, `gstack-taste-update`). Solution: snapshot the methodology PROSE, design-officer reads its own lib files and runs its own captain dialogue via Shift+Down or SendMessage.

## What was distilled

GStack skill source files are 1300-1500 lines each, most being shared boilerplate (Preamble, Voice, Telemetry, Skill Routing). The methodology core is concentrated in ~300-500 lines per skill. This snapshot extracts only the methodology and adapts it for design-officer's non-interactive subagent context.

| File | Distilled from | Purpose |
|---|---|---|
| `ux-principles.md` | `design-shotgun:797-880` + `design-html:783-866` (identical content) | Three Laws of Usability, Billboard Design, Navigation, Goodwill Reservoir — applied to every design decision |
| `shotgun.md` | `design-shotgun:1034-1162` | Multi-variant ideation discipline — anti-convergence, concept-first generation |
| `consultation.md` | `design-consultation:943-1230` | Research-grounded proposal flow — Memorable-thing question, 3-layer synthesis, Outside Voices, Complete Proposal with SAFE/RISK |
| `html-generation.md` | `design-html:906-1100` | Production HTML/CSS conventions — input detection, framework awareness, Pretext routing (optional) |

## Key adaptations from source

1. **No browser UI dependencies** — `$D` design binary (image generation), `$B` browse daemon comparison board, `~/.gstack/projects/...` paths all stripped. design-officer produces **text variants in markdown** (mood, palette specs, layout descriptions, sample HTML snippets), not PNG images. Captain reads markdown in editor; iterates via Shift+Down dialogue.

2. **AskUserQuestion → SendMessage / Shift+Down** — GStack skills use AskUserQuestion. design-officer is a subagent that talks to captain via SendMessage (when captain types in design-officer's pane) or sends initial proposals via SendMessage and waits for captain Shift+Down response. Same substance, different mechanic.

3. **Session-scoped taste, not cross-session file** — GStack uses `~/.gstack/projects/$SLUG/taste-profile.json` for cross-session taste persistence with decay logic. design-officer v1 uses **session-scoped memory only** — taste accumulates within one captain session, dies on session end. Persistence is v2 nice-to-have.

4. **Per-entity scope, not per-project** — outputs land in `<entity-folder>/design-explore/` not `~/.gstack/projects/$SLUG/designs/`. Multiple entities in one session share design-officer's session memory, but artifacts are entity-isolated.

5. **Pretext API references kept but optional** — `design-html` source is heavily Pretext-centric. Snapshot keeps Pretext as ONE valid output style (when project uses it) but design-officer routes to project's actual framework (React/Vue/Svelte/vanilla) via Step 2.5 detection.

## What was NOT copied

- GStack `SKILL.md` preamble / voice / telemetry / writing-style infrastructure
- Plan Mode / Skill Invocation / AskUserQuestion Format scaffolding (GStack harness)
- Eureka moment logging (`~/.claude/skills/gstack/bin/gstack-learning-log`) — v2
- approved.json / finalized.html / variant-*.png file conventions (replaced with markdown convention)
- Codex integration in design-consultation Outside Voices — preserved conceptually, but design-officer dispatches its own Codex via Bash if Tier A

## File inventory

```
design-methodology/
├── INDEX.md              ← this file
├── ux-principles.md      ← shared UX laws (applied to all design work)
├── shotgun.md            ← multi-variant ideation
├── consultation.md       ← research-grounded proposal
└── html-generation.md    ← production HTML/CSS
```

4 files, ~700 lines combined.
