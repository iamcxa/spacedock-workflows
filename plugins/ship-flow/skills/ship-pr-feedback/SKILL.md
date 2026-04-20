---
name: ship-pr-feedback
description: "Use when a PR reviewer requests changes. Reads PR comments, maps to Done Criteria, classifies, rolls back entity to execute/plan for FO re-dispatch."
user-invocable: true
argument-hint: "[entity-slug]"
---

# Ship-PR-Feedback — PR Review Re-Entry

Captain invokes this when a PR reviewer marks "Changes requested." This skill reads the PR review comments, maps them to Done Criteria, writes structured feedback to the entity, and rolls back status so FO can re-dispatch.

**This closes the loop:** sharp → plan → execute → verify → ship → PR → reviewer feedback → **this skill** → execute → verify → ship → new PR.

---

## VCS Detection Preamble

Before running any PR management command, resolve the VCS tool:

### Step V1: Detect VCS Provider

```bash
git remote -v 2>/dev/null | grep -q "github\.com" && echo "vcs=github" || \
git remote -v 2>/dev/null | grep -q "gitlab\.com" && echo "vcs=gitlab" || \
echo "vcs=unknown"
```

### Step V2: Check README Frontmatter Override

Read the workflow README at `docs/{workflow}/README.md`. If the frontmatter contains a `commands:` block with VCS commands, those values override auto-detection:
```yaml
commands:
  pr_create: "gh pr create"   # overrides auto-detected VCS command
  pr_view: "gh pr view"
  pr_comment: "gh pr comment"
  pr_close: "gh pr close"
```

### Step V3: Resolve VCS Command Variables

| Variable | github | gitlab |
|----------|--------|--------|
| `{commands.pr_create}` | `gh pr create` | `glab mr create` |
| `{commands.pr_view}` | `gh pr view` | `glab mr view` |
| `{commands.pr_comment}` | `gh pr comment` | `glab mr comment` |
| `{commands.pr_close}` | `gh pr close` | `glab mr close` |

If vcs is `unknown` → stop and ask captain to add `commands:` VCS block to workflow README frontmatter.

README frontmatter `commands:` takes precedence over the table above.

---

## Step 1: Load Entity and PR

**Section extraction:** When reading a specific section from an entity file, prefer tag-based extraction over H2 boundary grep:
```bash
bash plugins/ship-flow/lib/extract-section.sh {entity-file} {section-tag}
```
Falls back to H2 boundary regex automatically for legacy (untagged) entities.

Read the entity file from slug. Extract:
- `## Ship Output → ### PR Draft` — the PR number
- `## Sharp Output → ### Done Criteria` — the typed DC items
- `## Plan Output → ### Verification Spec` — the procedures (for reviewer to reference)
- `## Verify → ### UAT` (new layout) or `## Verify UAT` (legacy) — what passed last time
- Frontmatter `pr` field

If no `pr` field → ask captain for PR number.

Verify the PR exists and has review comments:

```bash
{commands.pr_view} {pr-number} --json state,reviews,comments
```

If PR state is "MERGED" → refuse: "PR already merged. Open a new entity for follow-up fixes."
If no reviews with "CHANGES_REQUESTED" → warn: "No changes requested on this PR. Continue anyway?"

---

## Step 2: Read PR Review Comments

Fetch all review comments:

```bash
{commands.pr_view} {pr-number} --json reviews --jq '.reviews[] | select(.state == "CHANGES_REQUESTED") | .body'
{commands.pr_view} {pr-number} --json comments --jq '.comments[].body'
# Also inline review comments (file-level — GitHub only):
# For GitHub: gh api repos/{owner}/{repo}/pulls/{pr-number}/comments --jq '.[] | "\(.path):\(.line) — \(.body)"'
# For GitLab: glab api projects/{project}/merge_requests/{mr-iid}/notes --jq '.[] | "\(.position.new_path):\(.position.new_line) — \(.body)"'
# Run the appropriate command based on detected VCS provider from Step V1.
```

Collect all comments into a list with:
- `source`: review body / general comment / inline (file:line)
- `text`: the comment content
- `author`: who wrote it

---

## Step 3: Map Comments to Done Criteria

For each comment, attempt to map to a DC item:

### 3.1: Auto-Mapping

Match comment text against DC assertions:
- Comment mentions "POST" + "201" or "comments endpoint" → DC-3
- Comment mentions a file:line that's in a task's `files_modified` → find which DC that task covers via `## Sharp Output → ### Journey → DC Mapping`
- Comment mentions "test" + specific behavior → find matching DC by assertion text

### 3.2: Unmatched Comments

Comments that don't map to any DC:
- If they describe a NEW requirement → classify as `coverage-gap` (something sharp/plan missed)
- If they're style/naming nits → classify as `nit`
- If they raise architectural concerns → classify as `architecture`

### 3.3: Write Classification Table

**Section tagging (mandatory):** Wrap the PR Review Feedback section with its tag:

```markdown
<!-- section:pr-review-feedback -->
## PR Review Feedback
{content}
<!-- /section:pr-review-feedback -->
```

```markdown
## PR Review Feedback

PR: #{pr-number}
Reviewer: {author}
Date: {ISO 8601}

| # | Comment | DC | Classification | Route to |
|---|---------|----|----|---|
| 1 | "POST /api/comments returns 500 when body is empty" | DC-3 | assertion-fail | execute |
| 2 | "Missing auth middleware on new route" | — | coverage-gap | execute |
| 3 | "Should use event-driven not polling" | — | architecture | plan |
| 4 | "Rename `handleStuff` to `handleComment`" | — | nit | — (log only) |
```

---

## Step 4: Determine Rollback Target

Read the classification table and pick the deepest rollback needed:

| Classification present | Rollback to | Reason |
|---|---|---|
| Only `nit` | No rollback | Log as `### Issues Found` (under `## Execute Output`), close with comment |
| `assertion-fail` or `coverage-gap` | `execute` | Need code changes, then re-verify |
| `architecture` | `plan` | Need to re-plan the approach |
| Mix of types | Deepest one wins | `architecture` > `assertion-fail` > `nit` |

---

## Step 5: Execute Rollback

### 5.1: Update Entity

```yaml
# Frontmatter update
status: {execute | plan}  # rollback target
pr_feedback_round: {N}    # increment from previous, or 1 if first feedback
```

### 5.2: Close Current PR

```bash
{commands.pr_close} {pr-number} --comment "Rolling back to {execute|plan} for fixes based on review feedback. See entity ## PR Review Feedback for details."
```
(Note: For GitLab, `glab mr close` does not support `--comment` flag. If VCS is gitlab, first add a comment via `glab mr comment {pr-number} --message "Rolling back to {execute|plan} for fixes based on review feedback."`, then close with `glab mr close {pr-number}`.)

**Do NOT delete the branch.** The next execute cycle will add commits to the same branch, and ship will open a new PR.

### 5.3: Prepare Execute Context

If rolling back to `execute`, write guidance for the execute stage so it knows what to fix:

**Section tagging:** Also wrap guidance sections with their tags:
```markdown
<!-- section:execute-guidance -->
## Execute Guidance (from PR review)
{content}
<!-- /section:execute-guidance -->
```
Or for plan rollback:
```markdown
<!-- section:plan-guidance -->
## Plan Guidance (from PR review)
{content}
<!-- /section:plan-guidance -->
```

```markdown
## Execute Guidance (from PR review)

Focus on these items — PR reviewer flagged them:
{list of assertion-fail and coverage-gap items with DC references}

Do NOT re-implement tasks that passed. Only fix the flagged items.
Previous passing tasks: {list from ## Execute Output → ### Execution Log where status=done and not flagged}
```

If rolling back to `plan`, write:

```markdown
## Plan Guidance (from PR review)

Architecture concern raised by reviewer:
{architecture comment text}

Re-plan with this constraint. Previous plan is in ## Plan Output → ### Plan (may need partial rewrite).
```

---

## Step 6: Notify and Hand Off

Notify captain:

> **PR feedback processed for {entity title}**
> PR #{pr-number} closed
> Feedback: {N assertion-fail, M coverage-gap, K nit}
> Rolled back to: {execute | plan}
> FO will re-dispatch automatically.
>
> Nits logged (not blocking):
> {list of nit items, if any}

FO sees entity `status: execute` (or `plan`) → normal dispatch cycle resumes.

---

## Circuit Breakers

- `pr_feedback_round` > 3 → escalate to captain: "3 PR review rounds without approval. Manual intervention needed."
- If PR is already merged → refuse rollback, suggest new entity
- If PR has no "Changes requested" reviews → warn and confirm before proceeding
- Nit-only feedback → do NOT roll back. Log and close with comment explaining nits will be addressed in follow-up entity.

---

## Rules

- **NEVER force-push or rebase the branch.** Add fixup commits — reviewer can see what changed.
- **NEVER re-run passing tasks.** Execute Guidance explicitly lists what to fix. Passing tasks are not re-dispatched.
- **NEVER auto-merge after fixes.** The fix cycle goes through full verify → ship → new PR → reviewer sees the diff again.
- **NEVER dismiss PR reviews.** The reviewer's feedback is sovereign — classify and route, don't argue.
