# Domain Knowledge Modules

Markdown reference docs for ship-flow domain specialists. One file per domain.

## Format: Markdown reference docs | NOT skill files

This directory contains **plain markdown reference documents**, not skill files
and not procedural instructions. Files here are READ as context by three consumers:

1. **ship-design stage** — specialist designer sub-sections read the relevant
   `<domain>.md` to ground schema / design decisions in domain invariants.
2. **plan stage** — architecture-lens reads `<domain>.md` when the domain's
   trigger fires, for context-aware planning guidance.
3. **verify stage** — intent-match-verifier reads `<domain>.md` to understand
   expected design intent when checking execute output.

**Why not a skill file?** Skill files are invokable procedures. Knowledge modules
are pure reference — they inform consumers, they do not drive execution.
The registry (`registry/defaults.yaml`) maps each domain to its knowledge module;
consumers call `lib/registry-resolve.sh` to look up the path.

## Naming convention

`<domain-name>.md` — lowercase, hyphen-separated, matching the domain key in
`registry/defaults.yaml`. Examples: `schema.md`, `saga.md`, `rbac.md`.

## Adding a new domain

1. Create `<domain>.md` in this directory.
2. Add a domain entry in `plugins/ship-flow/registry/defaults.yaml` (or adopter
   project `.claude/ship-flow/domains.yaml`) with:
   - `knowledge_module: plugins/ship-flow/references/domain-knowledge/<domain>.md`
   - `spec_keywords` or `trigger_patterns` for classification
   - `designer_section_anchor` once the specialist sub-section is built
   - optional `required_skills` and `skill_hints` when a matched domain should
     route downstream plan/execute/verify workers to project-level skills

Keep plugin defaults generic. Project-specific skill names, file globs, and
team-local domain terminology belong in the adopter override.

## Structure of each knowledge module

- `# <Domain Name> Domain` — H1 title
- When this domain triggers (keywords, file types)
- Domain model concepts (L1/L2/L3 layers, key invariants)
- Cross-cutting concerns (event-saga implications, contract surface, RBAC subjects)
- How to use this module (3 modes: designer / lens / verifier)
