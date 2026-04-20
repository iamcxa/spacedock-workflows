---
name: ship-verify
description: "Use when execute tasks are complete and the entity needs verification before shipping. Agent-autonomous gate: 5-check quality, themed review classification, done criteria UAT. Feedback-to execute on failure."
user-invocable: false
argument-hint: "[entity-slug]"
---

# Ship-Verify — Quality Gate, Review, and UAT

You are running the VERIFY stage of ship-flow. No captain interaction — run full-project quality checks, review the diff, verify done criteria. This stage is a gate: PASS advances to ship, FAIL feeds back to execute.

**You are NOT the author of this code.** You are a fresh agent reviewing work done by a different execute-stage ensign. Review the diff as an independent reviewer — do not assume correctness.

This stage combines three verification concerns:
- **Quality** — mechanical full-project verification (5 checks)
- **Review** — judgment-bearing code review classification (debate-driven)
- **UAT** — done criteria verification against captain's acceptance

## Entity Body Contract

**Schema:** `references/entity-body-schema.yaml` → `stages.verify`

**Reads:** `## Execute Output` (all subsections), `## Plan Output` → Verification Spec, `## Sharp Output` → Done Criteria, `PRODUCT.md` → Constraints
**Writes:** single `## Verify` section with 5 subsections (post-2026-04-19 D1 consolidation):
- `### Quality Gate` — 5-check full-project verification
- `### Review Findings` — classified haiku + pre-scan output
- `### Knowledge Captures` — D1/D2 tags
- `### UAT` — evidence review + spot-check (mode line + results table)
- `### Verdict` — authoritative status / cost / blocking issues / timestamps (FO grep-reads `status:` line)

> Pre-2026-04-19 layout used 3 H2 sections (`## Verify Output`, `## Verify Report`, `## Verify UAT`). Ship-review and ship-pr-feedback accept both layouts; no migration of archived entities needed.

---

## Step 1: Read Execution Results

**Section extraction:** When reading a specific section from an entity file, prefer tag-based extraction over H2 boundary grep:
```bash
bash plugins/ship-flow/lib/extract-section.sh {entity-file} {section-tag}
```
Falls back to H2 boundary regex automatically for legacy (untagged) entities.

Record the current time as the stage start timestamp (ISO 8601 format).

Read the entity file. Extract:
- `## Sharp Output → ### Done Criteria` — what must be true
- `## Execute Output → ### Execution Log` — what was done, commit SHAs
- `## Execute Output → ### Issues Found` — any auto-created entities
- `## Sharp Output → ### Size Assessment` — determines review depth
- `## Plan Output → ### Plan` — for `files_modified` cross-check
- `PRODUCT.md` — constraints to verify against (if exists)

**Pre-check**: if > 50% of tasks failed in execute → do NOT proceed. **Write `## Verify` with `### Quality Gate` showing the pre-check failure, and `### Verdict` with `status: blocked`, `verdict: BLOCKED`** to the entity file, then notify captain. The FO output-validation gate requires the `## Verify` section with `### Verdict` subsection to exist (or legacy `## Verify Report` for older entities). Never exit without writing them.

Capture execute base SHA from `## Execute Output → ### Execution Log` (first task's parent commit).

---

## Runtime Detection Preamble

Before running any quality check, resolve the runtime tool by reading the project context:

### Step R1: Detect Stacks

Scan for config files in the project root (check ALL — project may be polyglot):

```bash
detected_stacks=()

# JS/TS ecosystem
ls bun.lock bun.lockb 2>/dev/null && detected_stacks+=("bun")
ls pnpm-lock.yaml 2>/dev/null && detected_stacks+=("pnpm")
ls yarn.lock 2>/dev/null && detected_stacks+=("yarn")
ls package-lock.json 2>/dev/null && detected_stacks+=("npm")

# Systems languages
ls Cargo.toml 2>/dev/null && detected_stacks+=("cargo")
ls go.mod 2>/dev/null && detected_stacks+=("go")

# Python ecosystem
ls pyproject.toml requirements.txt Pipfile 2>/dev/null | head -1 | grep -q . && detected_stacks+=("python")

# Ruby
ls Gemfile 2>/dev/null && detected_stacks+=("ruby")

# Elixir
ls mix.exs 2>/dev/null && detected_stacks+=("elixir")

# Java/Kotlin
ls build.gradle build.gradle.kts pom.xml 2>/dev/null | head -1 | grep -q . && detected_stacks+=("jvm")

# Make-based
ls Makefile GNUmakefile makefile 2>/dev/null | head -1 | grep -q . && detected_stacks+=("make")

# Shell scripts (use shellcheck)
ls *.sh 2>/dev/null | head -1 | grep -q . && detected_stacks+=("shell")

# Dart/Flutter
ls pubspec.yaml 2>/dev/null && detected_stacks+=("dart")

echo "detected_stacks: ${detected_stacks[@]}"
[ ${#detected_stacks[@]} -eq 0 ] && echo "runner=unknown"
```

**Monorepo hint** (check after stack detection):
```bash
ls pnpm-workspace.yaml turbo.json lerna.json nx.json 2>/dev/null | head -1 | grep -q . && \
  echo "monorepo detected — scope commands to relevant workspace"
```

### Step R2: Check README Frontmatter Override

Read the workflow README at `docs/{workflow}/README.md`. If the frontmatter contains a `commands:` block, those values override auto-detection:
```yaml
commands:
  test: "npm test"           # overrides auto-detected test command
  build: "npm run build"     # overrides auto-detected build command
  typecheck: "npx tsc --noEmit"
  lint: "npm run lint"
  dev: "npm run dev"
```

### Step R3: Resolve Commands Per Stack

If `detected_stacks` contains exactly one entry → single-runner mode (backward-compatible):

| Variable | bun | pnpm | yarn | npm | cargo | go | python | ruby | elixir | jvm | make | shell | dart |
|----------|-----|------|------|-----|-------|----|--------|------|--------|-----|------|-------|------|
| `{commands.test}` | `bun test` | `pnpm test` | `yarn test` | `npm test` | `cargo test` | `go test ./...` | `pytest` | `bundle exec rspec` | `mix test` | `./gradlew test` or `mvn test` | `make test` | `shellcheck *.sh` | `dart test` |
| `{commands.build}` | `bun build` | `pnpm run build` | `yarn run build` | `npm run build` | `cargo build` | `go build ./...` | `python -m build` | `gem build` | `mix compile` | `./gradlew build` or `mvn package` | `make build` | N/A | `dart compile` |
| `{commands.typecheck}` | `bunx tsc --noEmit` | `pnpm exec tsc --noEmit` | `yarn dlx tsc --noEmit` | `npx tsc --noEmit` | `cargo check` | `go vet ./...` | `mypy .` | N/A | `mix dialyzer` | N/A | N/A | N/A | `dart analyze` |
| `{commands.lint}` | `bun lint` | `pnpm run lint` | `yarn run lint` | `npm run lint` | `cargo clippy` | `go vet ./...` | `ruff check .` | `rubocop` | `mix credo` | `./gradlew lint` | `make lint` | `shellcheck *.sh` | `dart analyze` |
| `{commands.prettier}` | `bunx prettier` | `pnpm exec prettier` | `yarn dlx prettier` | `npx prettier` | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A | N/A |

If `detected_stacks` contains **multiple entries** (polyglot project):
- List ALL detected stacks and their commands in the response
- Do NOT pick one — list all:
  ```
  Detected stacks: python, make, bun
  - python: test=pytest, lint=ruff check ., typecheck=mypy .
  - make: test=make test, lint=make lint, build=make build
  - bun: test=bun test, lint=bun lint, build=bun build
  ```
- Agent selects the relevant stack(s) based on which files the entity touches
- If entity touches Python files → use python commands; if it touches Makefile → use make commands; etc.

If `detected_stacks` is empty → go to **Step R4: Tier 2 Fallback** (see below).

README frontmatter `commands:` takes precedence over the table above for any variable it defines.

### Step R4: Tier 2 LLM Fallback (when Tier 1 = unknown)

When `detected_stacks` is empty after Step R1:

1. **Scan file extensions** to infer language:
   ```bash
   find . -maxdepth 3 -not -path '*/node_modules/*' -not -path '*/.git/*' \
     \( -name "*.py" -o -name "*.rb" -o -name "*.ex" -o -name "*.java" \
        -o -name "*.kt" -o -name "*.sh" -o -name "*.bash" \) \
     | sed 's/.*\.//' | sort | uniq -c | sort -rn | head -10
   ```
2. **Check CI configs** as hints (not authoritative):
   ```bash
   ls .github/workflows/*.yml .circleci/config.yml .travis.yml 2>/dev/null | head -3
   ```
   If found, read the first workflow file and extract `run:` commands involving test/build/lint keywords.
3. **Check import patterns** in the largest non-test file:
   ```bash
   head -20 $(find . -maxdepth 2 -name "*.py" -o -name "*.rb" -o -name "*.ex" 2>/dev/null | head -1)
   ```
4. **Produce stack profile** and ask captain to confirm before proceeding:
   ```
   Tier 2 detection result:
   - Dominant extensions: {list from step 1}
   - CI hints: {commands found, or "none"}
   - Inferred stack: {your best guess with confidence}
   - Proposed commands: test={X}, lint={Y}, build={Z}

   Please confirm or provide correct commands via docs/{workflow}/README.md frontmatter under `commands:`.
   ```

---

## Step 2: Quality Gate — 5-Check Full-Project Verification

Run ALL 5 checks against the full project. **No scope narrowing** — even if execute only touched one file, quality checks the entire project. Binary pass/fail per check, no judgment.

### Check 1: Tests
```bash
{commands.test} 2>&1
```
Verdict: exit code 0 and no failing tests → PASS. Otherwise → FAIL.

### Check 2: Lint
```bash
{commands.lint} 2>&1
```
Verdict: exit code 0 → PASS. Warnings-only → PASS. Errors → FAIL.

### Check 3: Type Check
```bash
{commands.typecheck} 2>&1
```
Verdict: exit code 0 and no `error TS` lines → PASS. Otherwise → FAIL.

### Check 4: Build
```bash
{commands.build} 2>&1
```
Verdict: exit code 0 → PASS. Otherwise → FAIL.

### Check 5: Format (if formatter configured)
```bash
{commands.prettier} --check "src/**/*.{ts,tsx}" 2>&1 || echo "no formatter configured"
```
(Note: For cargo/go projects where {commands.prettier} is N/A, skip Check 5 entirely — it is advisory only.)
Verdict: exit code 0 or no formatter → PASS. Otherwise → FAIL (advisory, not blocking).

**Capture last 40 lines of each check's output as evidence.**

**Any of checks 1-4 FAIL → feedback to execute.** Do NOT proceed to review. Max 2 feedback rounds, then escalate to captain.

```markdown
### Quality Gate
- tests: PASS (142 pass, 0 fail)
- lint: PASS
- typecheck: PASS
- build: PASS
- format: PASS (advisory)
```

---

## Step 3: Code Review — Haiku Agents + Sonnet Integration

The verify stage uses `dispatch: debate-driven`. FO dispatches haiku review agents (cheap, specialized) BEFORE dispatching you (sonnet, integration). You read their raw findings and classify.

**Architecture:**
```
FO dispatches (selected by pre-scan):
  ├── haiku agents: pr-review-toolkit + trailofbits skills
  │   ↓ all write raw findings to entity ## Haiku Review
  └── YOU (sonnet): pre-scan → read findings → spot-check → classify → verdict
```

### Step 3.1: Pre-Scan + Reviewer Selection (Inline — You Do This Yourself)

Before reading haiku findings, run these mechanical checks AND determine which reviewers FO should have dispatched:

**Mechanical pre-scan:**

1. **Stale references**: For every symbol removed by the diff, grep for remaining references. Hit outside the diff = stale reference finding.
2. **Plan consistency**: Cross-check `git diff --stat` file list against `## Plan Output → ### Plan` `files_modified`. Files changed but not in plan = unplanned change finding. Files in plan but unchanged = missed task finding.
3. **Constraint check**: If `PRODUCT.md` has `## Constraints`, verify changes don't violate any.
4. **CLAUDE.md rule walk**: For each changed file in the diff, walk dirname upward from the file to the repo root, collecting every `CLAUDE.md` encountered. Read each collected CLAUDE.md. For every rule it defines, check whether the diff violates it.

   ```
   Example: changed file is src/domain/session/watcher.ts
   Walk: src/domain/session/CLAUDE.md → src/domain/CLAUDE.md → src/CLAUDE.md → CLAUDE.md
   Each CLAUDE.md may define rules like "no direct DB access from domain layer",
   "always use Zod for external input validation", etc.
   ```

   Any violation = pre-scan finding with: the CLAUDE.md path, the rule text, the violating file:line from the diff. Severity: BLOCKING (rule uses "must"/"never"/"always") or WARNING (rule uses "prefer"/"should"/"consider").

   **Dedup**: if multiple changed files share the same parent CLAUDE.md, read it once. Cache CLAUDE.md contents during the walk.

**Reviewer selection matrix (FO uses this to decide which haiku agents to dispatch):**

Read `## Sharp Output → ### Size Assessment` from entity and diff content:

```bash
DIFF_FILES=$(git diff {execute_base}..HEAD --name-only)
DIFF_CONTENT=$(git diff {execute_base}..HEAD)
```

#### Hard skip — non-source-only diffs (no haiku at all):

If the diff contains **only** non-source-code files, skip the entire haiku dispatch and run inline review (Step 3.2 fallback path):

```bash
SOURCE_FILES=$(echo "$DIFF_FILES" | grep -E '\.(ts|tsx|js|jsx|mjs|cjs|py|rb|go|rs|java|kt|swift|c|cc|cpp|h|hpp|cs|php|ex|exs|sh)$')
if [ -z "$SOURCE_FILES" ]; then
  echo "Diff is non-source-only (docs/config/SKILL.md/etc.) — skip haiku dispatch, sonnet inline review only"
fi
```

> **Why** (2026-04 D1 measurement, n=2 SKILL.md entities): haiku reviewers hallucinated 50-100% of citations on prompt-text diffs because they anchor findings to pre-execute line numbers that no longer exist after restructure. Net surviving findings: 0. Inline sonnet review on the diff is strictly better here. Captain has already implicitly skipped haiku for `vercel-ci-auto-deploy` and `workflow-skill-routing` without ill effect — formalizing.

#### Always dispatch (when source files present):

| Agent | Skill | What it checks |
|-------|-------|---------------|
| `code-reviewer` | `pr-review-toolkit:code-reviewer` | Diff correctness, match to plan, regressions |

#### Dispatch for M/L (when source files present):

| Agent | Skill | What it checks |
|-------|-------|---------------|
| `silent-failure-hunter` | `pr-review-toolkit:silent-failure-hunter` | Empty catch blocks, swallowed errors, fallbacks that hide failures |

> **Removed from M/L mandatory** (2026-04 D1 measurement): `pr-test-analyzer` contributed 6 raw findings → 1 NIT in entity-detail-redesign (collapsed by sonnet into a single coverage-gap line). Net actionable surviving findings across n=4 sample: 0. Demoted to opt-in trigger (see Content-triggered below). `comment-analyzer` and `code-simplifier` never appeared in measured sample — also demoted to explicit opt-in pending evidence.

#### Dispatch based on diff content (any size):

| Agent | Skill | Trigger condition | Detection |
|-------|-------|------------------|-----------|
| `insecure-defaults` | `trailofbits:insecure-defaults` | Auth/config/env/secret changes in production code | `echo "$DIFF_FILES" \| grep -iE 'auth\|config\|env\|secret\|middleware\|cors\|csp' \| grep -v -E '\.test\.\|/tests?/\|\.md$'` |
| `sharp-edges` | `trailofbits:sharp-edges` | API/route/handler changes in production code | `echo "$DIFF_FILES" \| grep -iE 'route\|api\|handler\|endpoint\|server' \| grep -v -E '\.test\.\|/tests?/\|\.md$'` |
| `variant-analysis` | `trailofbits:variant-analysis` | Entity is a bug fix | `grep -i 'source:.*bug\|source:.*fix\|bugfix\|hotfix' {entity_frontmatter}` |
| `pr-test-analyzer` | `pr-review-toolkit:pr-test-analyzer` | New test files added or removed (not just modified) | `git diff {execute_base}..HEAD --name-status \| grep -E '^[AD].*\.test\.'` |
| `type-design-analyzer` | `pr-review-toolkit:type-design-analyzer` | 3+ new exported types/interfaces | `echo "$DIFF_CONTENT" \| grep -cE '^\+export (type \|interface \|enum )' \| awk '$1 >= 3'` |
| `comment-analyzer` | `pr-review-toolkit:comment-analyzer` | OPT-IN — captain explicitly requests | grep entity body for `haiku-opt-in: comment-analyzer` |
| `code-simplifier` | `pr-review-toolkit:code-simplifier` | OPT-IN — captain explicitly requests | grep entity body for `haiku-opt-in: code-simplifier` |
| `differential-review` | `trailofbits:differential-review` | Files with prior changes in last 30 days | `git log --since="30 days ago" --name-only --pretty=format: -- $DIFF_FILES \| sort -u \| wc -l > 0` |

#### Summary by diff content (post-D1 measurement):

| Diff content | Mandatory | Content-triggered (likely range) | Total range |
|---|---|---|---|
| Non-source only (docs/SKILL.md/config) | (none — sonnet inline review) | (none) | **0 agents** |
| S source (≤3 files) | code-reviewer (1) | 0-2 based on content | 1-3 agents |
| M source (4-15 files) | code-reviewer + silent-failure-hunter (2) | 0-3 based on content | 2-5 agents |
| L source (>15 files) | code-reviewer + silent-failure-hunter (2) | 0-3 based on content | 2-5 agents |

**Cost estimate:** haiku ~$0.05/agent → 0: $0, S: $0.05-0.15, M: $0.10-0.25, L: $0.10-0.25 (down from $0.25-0.45 pre-D1).

**Re-evaluate at next D1 sample (current + 5 entities):** if any cut/demoted agent would have caught a missed bug found in PR review or production, calibrate back. Default stance: keep cuts, append evidence to MEMORY.md.

**Haiku agent prompt template (FO uses this for each dispatched reviewer):**

Each haiku agent receives:
```
You are a specialized code reviewer. Load Skill("{skill-name}") and apply it to this diff.

## Diff
git diff {execute_base}..HEAD

## Rules
- Report raw findings only — no severity, no fix recommendations
- Each finding must include: file:line, exact code snippet (copy-paste, not paraphrased), check name
- Do NOT assign severity — the sonnet verify ensign classifies
- Return empty array [] if no checks trigger
- A false finding is worse than no finding — you will be spot-checked
```

### Step 3.2: Read Haiku Review Findings

Read `## Haiku Review` from the entity file (written by FO-dispatched haiku agents).

Expected finding format from each haiku agent:
```
### {agent-name} ({skill-name})
- file:line — `{exact code snippet}` — {check that triggered}
- file:line — `{exact code snippet}` — {check that triggered}
```

If `## Haiku Review` is missing (FO skipped dispatch, or bare mode):
- Run a single inline review yourself using the diff:
  ```bash
  git diff {execute_base}..HEAD
  ```
  Check: (1) changes match plan, (2) security, (3) dead code, (4) error handling, (5) stale refs.

### Step 3.3: Spot-Check Haiku Citations (Hallucination Guard)

**Before classifying ANY haiku finding, spot-check 2-3 citations:**

1. Pick 2-3 findings at random from haiku output
2. Read the cited file:line
3. Does the code snippet match what's actually in the file?

| Result | Action |
|--------|--------|
| All spot-checks match | Proceed to classification |
| 1 mismatch | Drop that finding, mark `⚠️ hallucination dropped`, check 2 more from same agent |
| > 50% mismatches from one agent | **Discard ALL findings from that agent**, log as Learning: `"haiku {agent-name} hallucinated > 50% — all findings dropped"` |

### Step 3.4: Classify Findings

For each surviving finding (from haiku agents, pre-scan, or inline review), YOU assign severity:

| Severity | Routing |
|----------|---------|
| **BLOCKING** — security hole, broken functionality, data loss risk | NEEDS_FIX → report to FO |
| **WARNING** — potential bug, missing edge case, weak error handling | Log, proceed if no BLOCKING |
| **NIT** — style, naming, minor improvement | Log as non-blocking, auto-create draft entity if warranted |

**If BLOCKING findings exist:**
- Write classification to `### Review Findings`
- Report NEEDS_FIX to FO with specific blocking issues
- FO dispatches fix agent → re-dispatches haiku reviewers → you re-classify
- Max 2 rounds, then escalate to captain

```markdown
### Review Findings
Scope: {N} files, {M} haiku reviewers dispatched (or "inline review — bare mode")

### Pre-scan
- Stale references: {none | list}
- Plan consistency: {all files match | discrepancies}
- Constraint check: {all constraints respected | violations}

### Haiku review (spot-checked)
Spot-check: {N}/{M} citations verified — {all match | N hallucinations dropped}

| Severity | File:Line | Description | Source |
|----------|-----------|-------------|--------|
| BLOCKING | src/api.ts:42 | Silent swallow of 4xx | silent-failure-hunter |
| WARNING | src/types.ts:10 | Loose union type | type-design-analyzer |

Verdict: {SHIP IT | NEEDS_FIX round N | escalated}
```

---

## Step 4: Done Criteria UAT (Evidence Review + Spot-Check)

**Default: read execute's evidence and spot-check ≤2 critical DCs.** Full re-run is the fallback when evidence is unreliable, not the default.

> **Why changed (2026-04 D1 measurement, n=31 DCs across 4 entities):** independent second-pass changed 0/31 verdicts. Re-running every DC procedure burned ~30% of verify wallclock without ever flipping a verdict. Spot-check + evidence review preserves the Bayesian update (catches execute self-deception or stale evidence) at a fraction of the cost. Full re-run remains available as fallback.

### Step 4.1: Read Execute Evidence

Read `## Execute UAT` (or `## Execute Output → ### Done Criteria Verification` for older entities). Verify each row has:
- The procedure from `## Plan Output → ### Verification Spec`
- Concrete evidence (command output excerpt, file:line citation, screenshot path) — not just "✅"

**Degrade to full re-run (Step 4.3) if any of:**
- Evidence column missing or contains only "ok" / "pass" / "✅" with no substance
- Procedure differs from Verification Spec
- ≥1 DC has `FAIL` or `degraded` status without explanation

### Step 4.2: Spot-Check Critical DCs

Pick up to 2 DCs to re-run yourself:
1. **Highest-risk DC** — typically `e2e` > `api` > `ui` > `cli` > `skill`. If multiple at the top tier, pick the one with the most complex assertion (e.g., expects multiple grep matches, or asserts on response body shape).
2. **One sampled at random** from the remaining DCs.

Re-run their procedures via Bash/curl/Skill per type:

| Type | How to run |
|------|-----------|
| `cli` | Bash: run command, check exit code + output |
| `api` | Bash: run curl command, check status + response |
| `ui` | Bash: curl route + grep content. If e2e flow exists → `Skill("e2e-pipeline:e2e-test")` |
| `skill` | `Skill("{skill-name}")` with probe prompt, check output shape |
| `e2e` | `Skill("e2e-pipeline:e2e-test")` if available, otherwise degrade to `ui` + warn |

Compare your spot-check result against execute's claim for those DCs:

| Spot-check outcome | Action |
|---|---|
| Both DCs match execute | Trust the remaining DCs based on evidence review; proceed to output |
| 1 mismatch | Re-run the mismatched DC's neighbors (same type or same code area). If neighbor also mismatches → Step 4.3 |
| Both mismatch | Degrade to Step 4.3 — execute's evidence is unreliable across the board |

### Step 4.3: Fallback — Full Re-Run

Triggered only by Step 4.1 evidence gap or Step 4.2 spot-check mismatch.

Re-run every DC procedure as the previous "Independent Second-Pass" mandated. Use the same type dispatch table as 4.2.

### Failure classification (applies to spot-check or full re-run)

- **Infra-fail** — command not found, server not running, binary missing, e2e infra unavailable → feedback to execute (automated, no captain)
- **Assertion-fail** — command ran but output doesn't match expected → specific failure logged with evidence

### Output

Append `### UAT` subsection to the entity's `## Verify` section:

```markdown
### UAT

Mode: {spot-check | full-rerun (fallback: <reason>)}

| DC | Type | Assertion | Verify Procedure | Execute 1st | Verify | Evidence |
|----|------|-----------|-----------------|-------------|--------|----------|
| DC-1 | ui | Detail page with panel | `curl ... \| grep` | ✅ | ✅ spot-checked | "comment-panel" found |
| DC-2 | ui | Input + submit button | `curl ... \| grep` | ✅ | ✅ trust (evidence: log line 47) | execute log line 47 |
| DC-3 | api | POST returns 201 | `curl -s -w "%{http_code}" ...` | ✅ | ✅ spot-checked | 201, {"id":"abc"} |
| DC-4 | e2e | Comment appears (SSE) | `e2e-test flows/comment-sse.yaml` | ⚠️ degraded to ui | ⚠️ degraded to ui | curl check only |
| DC-5 | cli | Notification test | `bun test tests/notification.test.ts` | ✅ | ✅ trust | exit 0 in execute log |
```

The `Verify` column states the verification mode for each DC: `spot-checked`, `trust (evidence: <ref>)`, or `re-run (fallback)`.

If any Done Criterion fails → feedback to execute with: DC number, type, procedure, expected vs actual. Max 2 rounds.

---

## Step 4.1: Visual Verification (UI-type DCs)

After all DC verification procedures pass, check if any DC has type `ui`:

If yes AND `e2e-pipeline` is available (check: `claude plugins list 2>/dev/null | grep e2e-pipeline`):
1. Dispatch `e2e-pipeline:e2e-walkthrough` in background (non-blocking) to screenshot the affected pages
2. If entity has `## Design Reference` with screenshot paths → compare rendered screenshot against the design reference image
3. If no `## Design Reference` → compare screenshot against DC assertions (does the rendered UI show what the DCs describe?)
4. Report under `## Verify → ### Verdict` (or legacy `## Verify Report`): visual verification PASS/FAIL with screenshot evidence

If `e2e-pipeline` is not available:
- Flag in report: "⚠ Visual verification skipped — e2e-pipeline not installed. Install via marketplace for UI verification."
- Do NOT block the pipeline — proceed with code-level verification result

---

## Step 4.5: Knowledge Capture (Conditional)

Scan all findings from quality gate, review, and UAT. Classify findings that **generalize beyond this entity**:

**D1 — Skill-Level Pattern** (auto-write):
Tag `[D1]` in `### Knowledge Captures`. Examples:
- "Haiku agent `type-design-analyzer` hallucinated 60% — prefer `code-reviewer` for type checks"
- "Quality gate: `bun lint` requires `--fix` run before commit in this project"

**D2 — Project-Level Candidate** (staged for captain):
Tag `[D2-candidate]` in `### Knowledge Captures`. Examples:
- "All new API routes need rate limiting middleware — entity X shipped without it"
- "Frontend routes must handle SSR — `window` access broke quality gate"

Ship-review stage surfaces `[D2-candidate]` items to captain.

**Skip when**: All findings are entity-specific. Log: `Knowledge capture: skipped — no findings met D1/D2 threshold`

---

## Step 5: Write Verdict

**Section tagging (mandatory):** The entire ## Verify section and each subsection must be wrapped. Example:

```markdown
<!-- section:verify -->
## Verify

<!-- section:quality-gate -->
### Quality Gate
{content}
<!-- /section:quality-gate -->

<!-- section:review-findings -->
### Review Findings
{content}
<!-- /section:review-findings -->

<!-- section:verify-knowledge-captures -->
### Knowledge Captures
{content}
<!-- /section:verify-knowledge-captures -->

<!-- section:uat -->
### UAT
{table}
<!-- /section:uat -->

<!-- section:verify-verdict -->
### Verdict
{fields}
<!-- /section:verify-verdict -->

<!-- /section:verify -->
```

Tag list: `verify` (impl), `quality-gate` (impl), `review-findings` (impl), `verify-knowledge-captures` (impl), `uat` (impl), `verify-verdict` (impl)

Append `### Verdict` subsection to the entity's `## Verify` section. This replaces legacy top-level `## Verify Report`.

```markdown
### Verdict
status: {passed | failed}
Verdict: {PASS | FAIL}
Quality: {5/5 pass}
Review: {verdict from Step 3}
UAT: {all done criteria pass | N failed} (mode: {spot-check | full-rerun})
Blocking issues: {none | list}
Knowledge capture: {D1: N written, D2: M candidates | skipped}
stage_cost: ${verify_cost} ({N} dispatches: {breakdown by model})
started_at: "{ISO 8601 timestamp}"
completed_at: "{ISO 8601 timestamp}"
duration_minutes: {number}
```

FO reads `status:` line (grep pattern `^status:`) for the authoritative gate and `stage_cost:` line for `token_actual` accumulation. The `Verdict:` line is a human-facing summary; `status:` is the machine-readable gate.

Calculate duration from the recorded start timestamp to now. Write started_at, completed_at, and duration_minutes.

If status `passed` → FO advances to ship.
If status `failed` → FO routes feedback-to execute with the entire `## Verify` section as context.

> Backward compat: pre-2026-04-19 entities used `## Verify Report` as a top-level H2. Both layouts are accepted by ship-review and ship-pr-feedback. New entities should use `## Verify → ### Verdict`.

## Circuit Breakers

- Quality gate fail → execute feedback: max 2 rounds
- Review NEEDS_FIX → fix + re-review: max 2 rounds
- Done criteria fail → execute feedback: max 2 rounds
- After all max retries exhausted → escalate to captain
- Infra-fail vs assertion-fail: infra routes to execute automatically, assertion requires specific evidence
