---
name: verify-reviewer-panel
description: "Built-in ship-flow verify reviewer panel fallback. Use inside ship-verify when PR-review toolkit personas are unavailable, or as the contract wrapper around general external reviewer, silent failure reviewer, and domain expert reviewer lenses. Read-only, findings-only, file:line cited output."
user-invocable: false
---

# ship-flow:verify-reviewer-panel

Use this utility skill from `ship-flow:ship-verify`. It is not a stage skill and must not advance workflow state by itself.

`pr-review-toolkit` is optional. When `pr-review-toolkit:code-reviewer` and `pr-review-toolkit:silent-failure-hunter` are installed, ship-verify may delegate to them for the concrete reviewer persona work. When they are absent, this skill is the ship-flow-owned fallback contract.

## Inputs

Every reviewer lens receives the same immutable input bundle:

- repo path
- branch
- base/head diff range
- changed files
- entity id and entity folder
- plan/design/execute hand-off snippets relevant to the lens
- required skills and knowledge modules for the lens, when derived from domain registry, `skills_needed`, adopter file signals, or touched files

Reviewers are **read-only** and findings-only. The prompt must say: do not edit files, do not stage files, do not commit, and do not rewrite the plan.

## Self-Check

Before reviewing, each lens must echo its self-check:

```yaml
self_check:
  repo_path: <absolute path>
  branch: <branch>
  base_head: <base>..<head>
  changed_files_count: <number>
  status: pass|fail
```

If repo path, branch, base/head, or changed files do not match the verifier's bundle, discard the output. If findings do not cite `file:line`, discard the finding. In structured YAML, use the key `file_line` and put the citation in `<path:line>` format.

## Lenses

### general-external-reviewer

Purpose: review the execute diff as an independent external reviewer, not the author.

Questions:
- Does the implementation match `plan.md`, `design.md`, and execute hand-off?
- Are there unplanned changed files or missed tasks?
- Are tests and verification commands aligned with changed behavior?
- Are there obvious behavior, security, data-loss, or maintainability risks?

### silent-failure-reviewer

Purpose: find places where the flow could pass while behavior is broken or unverified.

Questions:
- Did execute silently skip any Done Criteria, UAT step, or failing command?
- Are failures attributed to baseline without per-file/per-line proof?
- Are UI, API, migration, cache, routing, or data sync effects asserted only by typecheck or compile success?
- Are `WARNING` or `NIT` findings actually blocking because they hide a broken user journey?

### domain-expert-reviewer

Purpose: specialize the review by domain lens. Ship-verify derives these lenses from domain registry, `skills_needed`, adopter file signals, and touched files.

Examples:
- `project-db`: migrations, RLS, seed/validation, rollback and generated types
- `fmodel`: aggregate boundaries, commands/events, decider/view/saga contracts
- `refine-expert`: ProCRUD usage, refine hooks, cache invalidation, URL/drawer state
- `api-design`: route contracts, error semantics, auth, pagination

Domain reviewers must load the required skills or knowledge modules named by the verifier bundle, then review only through that lens.

## Output Matrix

Return YAML or a markdown table that can be pasted under `### Review Findings`:

```yaml
reviewer_output_matrix:
  - lens: general-external-reviewer
    verdict: PASS|BLOCKING|WARNING|NIT
    finding: <short finding>
    file_line: <path:line>
    route_to: execute|plan|design|follow-up|none
    evidence: <command/snippet/reference>
```

Verifier owns final aggregation. Critical and Important domain findings map to `BLOCKING` unless the verifier records a concrete deferral reason. Minor findings map to `NIT` or `WARNING` depending on user impact.
