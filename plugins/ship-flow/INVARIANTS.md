# Ship-flow INVARIANTS

> Codified harness-diet principles with grep-enforceable checks.
> **Current source of truth** for the 6 cut principles.
> Supersedes (but does not delete) `memory/ship-flow-harness-diagnosis.md` (2026-04-20 historical snapshot).

## Revision History

- **2026-04-21** — **v1 initial** (entity #067, slot 046e). Principle #5 reformulated in-session from "bounded entity file" to "structured docs are section-tagged + script-mediated + direct-Read warn" after captain push-back — the re-read cost assumption was obsoleted by #049 (extract-section.sh) + #053 (write-section.sh) script primitives. Preserves other 5 principles from 2026-04-20 diagnosis verbatim.

## How enforcement works

Three layers, each catching a different failure mode:

1. **CI grep** (`bin/check-invariants.sh`): runs on every PR touching `plugins/ship-flow/**` or `docs/ship-flow/**`. Fails on structural regressions (preamble regrowth, skill count > 7, unwrapped H2/H3, fan-out reviewer bloat, etc.). Green = repo passes its own rules.
2. **Runtime warn-hook** (`hooks/warn-direct-read.js`): PreToolUse hook on `Read`/`Edit` tool calls. Fires `systemMessage` warning when an agent attempts direct full-file Read on `docs/ship-flow/*.md` entity files (active, non-archived). **Warn-not-block** — operation still proceeds, but the agent sees the nudge to use `lib/extract-section.sh` instead.
3. **Captain-gate checklist** (§Captain-Gate Checklist below): design-review questions used during PR review for decisions that cannot be grep-enforced reliably (e.g., Principle #4 boolean-vs-enum gate — grep has high false-positive rate on prose skill files).

---

## Principles

### Principle 1: Eager-load → lazy-load

**Rule**: Skills should reference shared preambles via on-demand lookup, not eager-load them via copy-paste.

**Failure mode**: A "Runtime Detection Preamble" (or similar 13-ecosystem detection block) appears verbatim in ≥ 2 SKILL.md files. Burns ~25–40% of effective context on branches that don't fire.

**Grep check** (DC-7 preamble-regrowth): `check-invariants.sh --check preamble-regrowth` greps `plugins/ship-flow/skills/*/SKILL.md` for known preamble signatures and counts file occurrences; fails when any signature appears in ≥ 2 files. (Consolidation target: 046f preamble-extraction.)

**Source**: `memory/ship-flow-harness-diagnosis.md:16` (2026-04-20 harness-engine perspective, pain point #1).

---

### Principle 2: Separate-skill-for-small-function → inline-in-parent with tag

**Rule**: Small single-purpose skills that re-implement dispatch/orchestration logic of a parent skill should fold into the parent with a `source:` tag on their content.

**Failure modes**:
1. Total skill count in `plugins/ship-flow/skills/*/SKILL.md` exceeds **7** (empirical soft cap from 2026-04-20 diagnosis and 047/049/064 harness-diet cuts)
2. A SKILL.md wraps ≤ 20 LOC of actual logic (cargo-cult container)

**Grep check** (DC-6 skill-count): `check-invariants.sh --check skill-count` runs `ls plugins/ship-flow/skills/*/SKILL.md | wc -l` and fails if > 7.

**Precedent**: 047 ship-capture removal (244 → 60 LOC bash), 064 pr-feedback-fold (253 → folded into ship-execute Mode B with `<!-- section:pr-feedback-mode -->` tag). See entity archives for fold pattern.

**Source**: `memory/ship-flow-harness-diagnosis.md:46` (Feynman perspective — naming-only skill detection).

---

### Principle 3: Fan-out → conditional reviewer

**Rule**: Review-stage agent dispatch should default to 1–2 high-value reviewers (code-reviewer + silent-failure-hunter per 056 empirical data). Additional reviewers are opt-in via entity tag, not size-triggered default.

**Failure mode**: `ship-verify/SKILL.md` dispatches > 2 unconditional `Agent(...)` calls without `# opt-in:` comment marker. On small diffs (especially non-source diffs), additional haiku reviewers produce 50–100% hallucination rate — a negative-value operation.

**Grep check** (DC-11 fan-out-reviewer): `check-invariants.sh --check fan-out-reviewer` greps ship-verify SKILL.md for unconditional `Agent(` invocations and fails if > 2 without `# opt-in:` comment.

**Source**: `memory/ship-flow-harness-diagnosis.md:17,19` + entity 056 haiku-roster-collapse (shipped 2026-04-20).

**Related D1 evidence** (2026-04-21, from entity 064): "Haiku reviewer fertility by diff domain — shell-primitive diffs (420-line bash) → 3-of-3 spot-check match (100%); prompt-text diffs (SKILL.md) → 50–100% hallucination rate because haiku anchors to pre-execute line numbers that no longer exist post-restructure." Keep default 2 haiku for source-file diffs; skip entirely for non-source-only diffs.

---

### Principle 4: Boolean gate, not enum gate

**Rule**: All captain-interrupt decisions ("does this need captain review?", "should plan pause here?") must be computable as `True`/`False` from entity frontmatter + Done Criteria types, not requiring a runtime enum lookup or prose judgment call.

**Failure mode**: A skill uses enum-string gate values (e.g., `prompt_captain: "ask"|"skip"|"auto"`) where the decision logic is not expressible as a boolean predicate. Agents have to guess "is this an 'ask' case?" without the compute path being deterministic.

**Grep check — Tier A spike** (DC-12): `check-invariants.sh --check boolean-gate` attempts grep for enum-string patterns in `plugins/ship-flow/skills/*/SKILL.md` (e.g., `(prompt_captain|interrupt_captain|captain_gate)\s*[:=]\s*["']?(ask|skip|auto|yes|no)`). If false-positive rate on current repo ≤ 25%, runs as hard check. If > 50%, degrades to Tier B (design-review-only, no automated check).

**Captain-Gate Checklist (Tier B fallback)** — see below.

**Source**: `memory/ship-flow-harness-diagnosis.md:18,51` (captain "execute → verify 應該不用問我才對" complaint 2026-04-18; treated as boolean-vs-enum contract gap).

---

### Principle 5: Structured docs are section-tagged + script-mediated

**REFORMULATED 2026-04-21** (v1, entity #067, slot 046e). Original Principle #5 "bounded entity file" from 2026-04-20 diagnosis was built on a re-read cost assumption that #049 + #053 obsoleted. Size is no longer the axis — **script-mediated access** is.

**Rule (three sub-invariants)**:

- **5a · Entity body section-tagging**: Every `##` and `###` header in `docs/ship-flow/*.md` (excluding `README.md` and `_archive/`) must be wrapped in a paired `<!-- section:tag -->` ... `<!-- /section:tag -->` HTML comment. Nesting is allowed (e.g., `<!-- section:sharp-output -->` wraps `<!-- section:problem -->` wraps `<!-- section:scope -->`). Future Claude + tooling access sections via `bash lib/extract-section.sh <entity> <tag>` and write via `bash lib/write-section.sh`.
- **5b · Canonical doc flow-map tagging**: Every `section_tag:` declared as active in `plugins/ship-flow/references/flow-map-schema.yaml` must resolve to a non-empty section in its declared map file (ARCHITECTURE.md currently; PRODUCT.md + ROADMAP.md deferred stubs). Sections with `requires_diagram: true` must contain a ```` ```mermaid ```` code block. Access via `lib/extract-map.sh` / `lib/patch-map.sh` with read-first CAS.
- **5c · Direct-Read warn-hook**: Agents should prefer `lib/extract-section.sh` / `lib/extract-map.sh` over direct `Read` of entity/canonical files. Direct `Read`/`Edit` on matching paths is **allowed but warned** via PreToolUse hook (`hooks/warn-direct-read.js`, `hooks/hooks.json`). CI additionally greps `SKILL.md` prose for `Read(docs/ship-flow/*.md)` patterns and flags unjustified occurrences (missing adjacent `# justification:` comment).

**Grep checks**:
- DC-8 section-tag-coverage: stack-based awk walker asserts every H2/H3 in active entity files is contained within some `<!-- section:... -->` pair.
- DC-9 flow-map-coverage: iterates `flow-map-schema.yaml` active maps, invokes `extract-map.sh` per section, asserts exit 0 + non-empty; for `requires_diagram: true`, grep for `^```mermaid`.
- DC-10 direct-read-static: grep `plugins/ship-flow/skills/*/SKILL.md` for `Read\s*\(.*docs/.*\.md` without adjacent `# justification:` comment.

**Size cap**: **none** (script-mediated access decouples cost from length). Entities may grow as long as section tags keep them surgically accessible. Observed healthy ceiling: ~1,400 lines (049 at 1,401 shipped cleanly; war-room-visual-polish at 1,266 predates script infra and is the historical trigger for the now-retired cap).

**Source**: `memory/ship-flow-harness-diagnosis.md:20,49` (original) + captain in-session reformulation (2026-04-21). Evidence: #049 entity-section-tagging (shipped 1,401 LOC, no operational pain) + #053 write-section-helper + #059 flow-map-schema-v1.

---

### Principle 6: Metadata-driven portability

**Rule**: Runtime/VCS/test-framework detection should happen in ONE helper, referenced by skills on demand. Not copied eagerly into each skill's preamble.

**Failure mode**: The "Runtime Detection Preamble" (13-ecosystem detection table) appears verbatim in multiple SKILL.md files. When ecosystems/commands update, drift risks.

**Grep check**: same as Principle #1 (`check-invariants.sh --check preamble-regrowth`). Consolidation target: 046f preamble-extraction.

**Portability constraint preserved**: ship-flow is template-grafted to other repos via `/spacedock:commission`. The single detection helper must remain portable (no host-project hard dependencies).

**Source**: `memory/ship-flow-harness-diagnosis.md:53-61` (portability constraint section).

---

## Captain-Gate Checklist

Used for design-review of any skill/plan/entity change that may create a captain-interrupt decision point (Principle #4 Tier B fallback + manual reviewer checklist).

1. **Is the decision expressible as a boolean predicate over entity frontmatter + DC types?** If the answer is "depends on judgment" or requires a runtime enum lookup → reformulate until it is.
2. **Does this skill/stage add a new point where the captain is prompted/asked?** If yes: is the prompt framed as a boolean (`continue?: y/n`) or an enum (`mode?: ask|skip|auto`)? Reject enums without a boolean-decomposition rationale.
3. **If this is a gate between stages, who moves the entity forward on PASS?** Automated status flip or captain manual action? Automated gates must be deterministic; captain gates must be at sharp only (or an explicit "captain smoke test" flagged in entity frontmatter).
4. **If the skill re-implements dispatch or orchestration logic similar to another skill**, can it fold via `source:` tag pattern (Principle #2) instead of living as a separate skill?
5. **If a new captain-prompt adds an enum with ≥ 3 values**, decompose into N boolean predicates OR provide a deterministic decision tree. No "ask me depending on the vibe" gates.

---

## Scoped Quality Gate Rule

**Codified from 062 D2-candidate + 064 MEMORY entry** (2026-04-21).

**Rule**: When execute's diff is 100% non-source (markdown, YAML, bash, JSON config; i.e., file extensions in `{md, yaml, yml, sh, json}` excluding `package.json`/`tsconfig.json`), the full-project quality gate (typecheck + test + build) produces dominantly pre-existing-baseline noise — the execute didn't produce any code that could fix or break it. Run scoped quality gate instead:

- `shellcheck` on any new `.sh` files
- `yamllint` or `yq`-based validity check on any new `.yaml`/`.yml` files
- `jq -e '.'` validity on any new `.json` files
- Markdown structural checks (section-tag coverage if applicable, header exactly-N matches per entity body schema)

**Detection heuristic**: `git diff --diff-filter=M -M <execute_base>..HEAD --name-only | grep -cvE '\.(md|yaml|yml|sh|json)$'` → if 0, apply scoped gate.

**Rationale**: For entities 058 (pure-rename), 062 (CI-infra), 064 (doc fold), and now 067 (this one), the full-project gate ran for ~0 application-code changes and produced 100% baseline failures that execute couldn't act on. Scoped gate saves 90%+ verify time on zero-app-code entities.

**Verify stage hint**: surface this rule to verify; verify can apply scoped gate + explicitly log "pre-existing baseline failures not in scope" for any full-project signals.

**Source**:
- Entity 062 `gh-actions-vercel-deploy.md:590` (D2-candidate original)
- Entity 058 `rename-to-spacebridge.md:763` (D2 candidate 5)
- Entity 064 `pr-feedback-fold.md` (MEMORY entry + inline execute precedent)

---

## Related Files

- `plugins/ship-flow/bin/check-invariants.sh` — CI grep implementation
- `plugins/ship-flow/hooks/warn-direct-read.js` — PreToolUse runtime warn hook
- `plugins/ship-flow/hooks/hooks.json` — hook wiring
- `plugins/ship-flow/lib/__tests__/test-check-invariants.sh` — test runner
- `.github/workflows/ship-flow-invariants.yml` — CI trigger
- `docs/ship-flow/_archive/ship-flow-invariants.md` — authoring history (post-archive)
- `memory/ship-flow-harness-diagnosis.md` — 2026-04-20 diagnosis snapshot (historical; see errata header)
