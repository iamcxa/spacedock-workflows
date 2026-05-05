---
name: domain-registry
description: "Use when ship-design, schema-designer, or intent-match-verifier needs domain registry routing or knowledge-module lookup context."
user-invocable: false
---

# Domain Registry — READ-as-context, NOT INVOKE-as-skill

**READ-as-context only.** Do NOT call `Skill: ship-flow:domain-registry`. This file
is orientation for consumers (ship-design router, architecture-lens, intent-match-verifier).
To perform registry resolution, call `bash plugins/ship-flow/lib/registry-resolve.sh`.

## When to Consult the Registry

Consult the registry when you need to:

1. **Classify a pitch** — determine which domain(s) a spec body belongs to.
2. **Dispatch a specialist** — find the `designer_section_anchor` to route to in `ship-design`.
3. **Load a knowledge module** — get the path to `references/domain-knowledge/<domain>.md`.
4. **Route project skills** — read `required_skills` and stage-specific `skill_hints.*`.
5. **Surface gaps** — detect missing specialists (M1) or missing knowledge modules (M2).

Skip the registry when:
- The pitch is `affects_ui: true` and no domain-specific keyword fires (visual/UX-only work).
- The spec is a pure doc/config change with no code surface.

## How to Read defaults.yaml + Adopter Override

Config files live at:
- **Plugin default**: `plugins/ship-flow/registry/defaults.yaml`
- **Adopter project override**: `.claude/ship-flow/domains.yaml` (created by adopter)

**Precedence (full-replace per domain)**: adopter project YAML wins on key collision.
If both files define `domains.schema`, the adopter entry completely replaces the plugin entry —
no shallow-merge. This is intentional: adopters own their domain-specific trigger globs.

## How to Invoke lib/registry-resolve.sh

```bash
# List all registered domain names
bash plugins/ship-flow/lib/registry-resolve.sh --list

# Classify a spec file against all domains
bash plugins/ship-flow/lib/registry-resolve.sh --classify <spec-file>

# Look up a specific domain entry
bash plugins/ship-flow/lib/registry-resolve.sh --domain=schema

# Validate config + optional per-domain M1/M2 check
bash plugins/ship-flow/lib/registry-resolve.sh --validate [--domain=schema]

# Override config paths (for testing or adopter use)
bash plugins/ship-flow/lib/registry-resolve.sh \
  --config=plugins/ship-flow/registry/defaults.yaml \
  --adopter-config=.claude/ship-flow/domains.yaml \
  --classify <spec-file>
```

**Output envelope** (stdout, key=value lines):

```
status=ok|partial_coverage|specialist_missing|knowledge_module_missing|parse_error|invalid_trigger_config
matched=<domain1>,<domain2>,...
missing=<domain1>,<domain2>,...
knowledge_module_path=<path>
designer_section_anchor=<anchor>
required_skills=<skill1>,<skill2>,...
skill_hints.plan=<skill1>,<skill2>,...
skill_hints.execute=<skill1>,<skill2>,...
skill_hints.verify=<skill1>,<skill2>,...
```

`required_skills` is a hard routing hint: downstream stages should preserve it
when deriving `skills_needed`. `skill_hints.<stage>` is stage-specific and may
be empty. These fields are generic registry metadata; adopter-specific skill
names belong in `.claude/ship-flow/domains.yaml`, not plugin defaults.

**Exit codes**:

| Code | Meaning |
|------|---------|
| 0 | ok or partial_coverage (read `status=` field to distinguish) |
| 2 | usage error |
| 10 | M1: specialist_missing |
| 11 | M2: knowledge_module_missing |
| 20 | M4: parse_error |
| 21 | M5: invalid_trigger_config |
| 1 | generic error |

## M1-M5 Surfaces — What Consumers Should Do

### M1 — specialist_missing (exit 10)

Domain matched, but `designer_section_anchor` is empty in registry. This means the
domain specialist sub-section in `ship-design` has not been built yet.

**Consumer action**: Surface HALT-with-options to captain:
- `skip` — proceed without specialist design (plain generalist fallback, mark in design.md)
- `generalist-marker` — proceed but flag output as "generalist-only, no domain specialist"
- `file-specialist-first` — pause; create a 113.x child to build the specialist first

Never silently proceed as generalist when M1 fires. The explicit HALT is the designed behavior.

### M2 — knowledge_module_missing (exit 11)

Domain matched and anchor exists, but the knowledge module `.md` file is absent on disk.

**Consumer action**: Same options as M1. The knowledge module is needed for grounded design;
proceeding without it risks domain-blind output.

### M3 — partial_coverage (exit 0)

Spec triggers multiple domains; some have specialists, some do not.

**Consumer action**: Proceed with the matched (specialist-having) domains. Annotate design.md
with `partial_coverage: [missing-domain1, missing-domain2]` so verifier knows which domains
were skipped. Do NOT HALT — partial coverage is expected during framework build-out.

### M4 — parse_error (exit 20)

The registry YAML config is malformed and cannot be parsed.

**Consumer action**: FAIL LOUD. Block all dispatch until config is fixed. Do not fall back
to a hardcoded default — the misconfiguration must be surfaced, not silently swallowed.

### M5 — invalid_trigger_config (exit 21)

A domain entry has both `trigger_patterns: []` AND `spec_keywords: []` — no way to match.

**Consumer action**: Same as M4 — fail loud. A domain that can never match is a config bug.

## Adopter Override Pattern

Project teams add domain-specific trigger globs in `.claude/ship-flow/domains.yaml`:

```yaml
schema_version: "1.0"
domains:
  schema:
    trigger_patterns:
      - "*.fmodel.ts"
      - "drizzle/**"
    spec_keywords:
      - schema
      - drizzle
      - fmodel
    knowledge_module: plugins/ship-flow/references/domain-knowledge/schema.md
    designer_section_anchor: "ship-design#schema-designer"
    required_skills:
      - project-db
      - fmodel
    skill_hints:
      plan:
        - project-db
        - fmodel
      execute:
        - fmodel
      verify:
        - project-db
    description: "Schema domain (project-specific trigger globs)"
```

The adopter file fully replaces the plugin entry for `schema`. Other plugin-default domains
(if any) remain active unless the adopter also overrides them.

## Cross-References to Knowledge Modules

Knowledge modules live in `plugins/ship-flow/references/domain-knowledge/`:

| Domain | Knowledge Module |
|--------|-----------------|
| `schema` | `references/domain-knowledge/schema.md` |

See `references/domain-knowledge/README.md` for naming convention and how to add new modules.
