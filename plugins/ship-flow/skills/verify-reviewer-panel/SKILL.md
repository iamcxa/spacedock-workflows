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
- plan task `reviewer_questions` and `domain_acceptance_checklist` rows when present
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

When the input bundle includes `reviewer_questions` or
`domain_acceptance_checklist`, use those concrete prompts instead of the canned
questions above. Preserve these fields in the reviewer output so the verifier
can audit the plan-to-verify handoff:

```yaml
reviewer_question: <question from plan>
affected_path_family: <path family from plan>
required_skills: <skills required by plan/checklist>
evidence_required: <command/snippet/artifact required by plan>
```

Concrete prompts augment domain-expert-reviewer lenses; they do not replace the
baseline reviewer lenses. The general-external-reviewer and silent-failure-reviewer still run their baseline questions even when the input bundle includes reviewer_questions or domain_acceptance_checklist rows.

For each domain_acceptance_checklist row, emit one reviewer_output_matrix item
that preserves the row's concrete lens, reviewer question, affected path family,
required skills, and evidence requirement. Example: a `project-db` row scoped to
`apps/supabase/migrations/**` stays `lens: project-db`; it does not collapse into
the generic `domain-expert-reviewer` label.

Concrete lens names such as `project-db`, `fmodel`, `refine-gotchas`, and
`api-design` are valid domain-expert lenses. Treat them as
`domain-expert-reviewer` kind with the concrete lens preserved in `lens`.

## Output Matrix

Return YAML or a markdown table that can be pasted under `### Review Findings`:

```yaml
reviewer_output_matrix:
  - lens: general-external-reviewer
    reviewer_question: <question from plan, if any>
    affected_path_family: <path family from plan, if any>
    required_skills: <skills required by plan/checklist, if any>
    verdict: PASS|BLOCKING|WARNING|NIT
    finding: <short finding>
    file_line: <path:line>
    route_to: execute|plan|design|follow-up|none
    evidence_required: <command/snippet/artifact required by plan, if any>
    evidence: <command/snippet/reference>
```

Verifier owns final aggregation. Critical and Important domain findings map to `BLOCKING` unless the verifier records a concrete deferral reason. Minor findings map to `NIT` or `WARNING` depending on user impact.
