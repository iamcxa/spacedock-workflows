---
name: ship-flow-lint
description: "Mechanical ship-flow lint gate for Markdown, workflow mod contracts, and adopter-declared guardrail surfaces"
version: 0.1.0
---

# Ship Flow Lint

Runs cheap deterministic checks before expensive reviewer loops. The generic
plugin owns the runner and default structural checks. Each adopter owns its
repo-specific config and project checks.

## Hook: pre-review-spend

Before requesting Copilot, Kilo, Claude, or project-specific PR reviewers, run:

```bash
node plugins/ship-flow/bin/ship-flow-lint.mjs --workflow-dir docs/ship-flow
```

If an adopter provides a package script such as `pnpm ship-flow:lint`, use the
package script so repo-local Node/package manager conventions are respected.

## Artifact Split

| Layer | Owner | Example |
| --- | --- | --- |
| Generic runner | ship-flow plugin | `plugins/ship-flow/bin/ship-flow-lint.mjs` |
| Generic rules | ship-flow plugin | Markdown `||` table row detection; config shape; required-surface presence. |
| Workflow hook | ship-flow plugin + adopter override | `_mods/ship-flow-lint.md`, `_mods/pr-review-loop.md`, or PR-finalization mod. |
| Project config | adopter repo | `docs/ship-flow/ship-flow-lint.config.json` |
| Project checker | adopter repo | `pnpm seed:check-static-sql`, migration parity, local env preflight. |

## Config

Adopters can create `docs/ship-flow/ship-flow-lint.config.json`:

```json
{
  "markdown": {
    "forbiddenPatterns": [
      {
        "id": "local-path",
        "pattern": "/Users/[^\\s)`]+",
        "files": ["docs/ship-flow/_mods/*.md"]
      }
    ]
  },
  "modContract": {
    "files": ["docs/ship-flow/_mods/*.md"],
    "forbiddenPatterns": [
      {
        "id": "positive-skip-review-loop",
        "pattern": "\\b(can|may|should|will|explicitly)\\s+skip[^\\n]*pr-review-loop"
      }
    ]
  },
  "workflow": {
    "requiredFiles": [
      "docs/ship-flow/README.md",
      "docs/ship-flow/spacebridge.yaml",
      "docs/ship-flow/_mods/ship-flow-lint.md"
    ]
  }
}
```

## Rules

- Prefer deterministic checks over reviewer prompts for repeatable mistakes.
- Keep project/domain knowledge out of the generic plugin. Use config-triggered
  project commands for seed, migration, env, and generated artifact parity.
- A lint gate is not complete unless the workflow SOT names when it runs.
- Do not use Spacebridge manifest fields as hidden mod registry fields unless
  Spacebridge schema explicitly supports them.
