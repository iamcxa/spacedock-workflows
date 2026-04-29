# Ship-flow INVARIANTS

> Codified harness-diet principles with grep-enforceable checks.
> **Current source of truth** for the 6 cut principles.
> Supersedes (but does not delete) `memory/ship-flow-harness-diagnosis.md` (2026-04-20 historical snapshot).

## Revision History

- **2026-04-21** — **v1 initial** (entity #067, slot 046e). Principle #5 reformulated in-session from "bounded entity file" to "structured docs are section-tagged + script-mediated + direct-Read warn" after captain push-back — the re-read cost assumption was obsoleted by #049 (extract-section.sh) + #053 (write-section.sh) script primitives. Preserves other 5 principles from 2026-04-20 diagnosis verbatim.

## How enforcement works

Three layers, each catching a different failure mode:

1. **CI grep** (`bin/check-invariants.sh`): runs on every PR touching `plugins/ship-flow/**` or `docs/ship-flow/**`. Fails on structural regressions (preamble regrowth, skill count > 7, unwrapped H2/H3, fan-out reviewer bloat, etc.). Green = repo passes its own rules.
2. **Runtime warn-hooks**:
   - `hooks/warn-direct-read.js`: PreToolUse hook on `Read`/`Edit` tool calls. Fires `systemMessage` warning when an agent attempts direct full-file Read on `docs/ship-flow/*.md` entity files (active, non-archived). **Warn-not-block** — operation still proceeds, but the agent sees the nudge to use `lib/extract-section.sh` instead.
   - `hooks/warn-state-drift.sh`: SessionStart hook. Scans active entities for the `status: ship` + `pr: #N MERGED` drift pattern observed 4× the week of 2026-04-20 (catch-up commits `f6029c4c`, `f7a8cacb`, plus #030+#037 hanging at session-start 2026-04-22). Injects `additionalContext` listing drifted entities so FO runs the Step 3c `done + archive` sequence before new execute work. Requires `gh`; graceful no-op otherwise.
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

**Split counting** (updated 2026-04-23 via entity #085 Wave 5b, commit `d51620e4`): stage-skills and utility-skills are counted SEPARATELY. Stage-skills have a hard cap ≤ 7; utility-skills are uncapped. Current inventory under the split rule:

- **Stage-skills (≤7 cap)**: `ship-shape`, `ship`, `ship-plan`, `ship-execute`, `ship-verify`, `ship-review` — 6 total (under cap).
- **Utility-skills (uncapped)**: `add-todos`, `ship-onboard`, `ship-runtime-detect` — 3 total.

The pre-2026-04-23 "temp cap = 10" rule is superseded: `check-invariants.sh --check skill-count` now runs split-counted assertions. Rationale: stage-skills define the workflow's shape and must stay cognitively manageable; utility-skills are on-demand helpers that don't add pipeline surface area.

**Failure modes**:
1. Stage-skill count exceeds **7** (workflow's shape no longer cognitively graspable)
2. A stage SKILL.md wraps ≤ 20 LOC of actual logic (cargo-cult container)
3. A utility-skill attempting to re-implement a stage-orchestration path (classification error — folds into the parent stage skill instead)

**Grep check** (DC-6 skill-count): `check-invariants.sh --check skill-count` uses the split taxonomy from `check-invariants.sh` (introduced in commit `d51620e4`): fails if stage-skills > 7.

**Precedent**: 047 ship-capture removal (244 → 60 LOC bash), 064 pr-feedback-fold (253 → folded into ship-execute Mode B with `<!-- section:pr-feedback-mode -->` tag), #085 Wave 5b T4 ship-sharp removal (commit `0b3fcc1a`, deprecated alias). See entity archives for fold pattern.

**Source**: `memory/ship-flow-harness-diagnosis.md:46` (Feynman perspective — naming-only skill detection). Split counting rule sourced from entity #085 design decision 4.

---

### Principle 3: Fan-out → conditional reviewer

**Rule**: Review-stage agent dispatch should default to 1–2 high-value reviewers (code-reviewer + silent-failure-hunter per 056 empirical data). Additional reviewers are opt-in via entity tag, not size-triggered default.

**Failure mode**: `ship-verify/SKILL.md` dispatches > 2 unconditional `Agent(...)` calls without `# opt-in:` comment marker. On small diffs (especially non-source diffs), additional haiku reviewers produce 50–100% hallucination rate — a negative-value operation.

**Grep check** (DC-11 fan-out-reviewer): `check-invariants.sh --check fan-out-reviewer` greps ship-verify SKILL.md for unconditional `Agent(` invocations and fails if > 2 without `# opt-in:` comment.

**Source**: `memory/ship-flow-harness-diagnosis.md:17,19` + entity 056 haiku-roster-collapse (shipped 2026-04-20).


**Severity-disagreement aggregation (101.3)**: when ship-verify dispatches the default haiku pair, aggregate verdicts via FAIL > WARN > PASS rule; codified at `ship-verify/SKILL.md → ### Severity-disagreement aggregation`. This is NOT a fan-out cap change; pair count remains 2 unconditional (Principle 3 budget). Future opt-in 3rd reviewer would still need `# opt-in:` annotation.

**Related D1 evidence** (2026-04-21, from entity 064): "Haiku reviewer fertility by diff domain — shell-primitive diffs (420-line bash) → 3-of-3 spot-check match (100%); prompt-text diffs (SKILL.md) → 50–100% hallucination rate because haiku anchors to pre-execute line numbers that no longer exist post-restructure." Keep default 2 haiku for source-file diffs; skip entirely for non-source-only diffs.

---

### Principle 4: Boolean gate, not enum gate

**Rule**: All captain-interrupt decisions ("does this need captain review?", "should plan pause here?") must be computable as `True`/`False` from entity frontmatter + Done Criteria types, not requiring a runtime enum lookup or prose judgment call.

**Failure mode**: A skill uses enum-string gate values (e.g., `prompt_captain: "ask"|"skip"|"auto"`) where the decision logic is not expressible as a boolean predicate. Agents have to guess "is this an 'ask' case?" without the compute path being deterministic.

**Grep check — Tier A spike** (DC-12): `check-invariants.sh --check boolean-gate` attempts grep for enum-string patterns in `plugins/ship-flow/skills/*/SKILL.md` (e.g., `(prompt_captain|interrupt_captain|captain_gate)\s*[:=]\s*["']?(ask|skip|auto|yes|no)`). If false-positive rate on current repo ≤ 25%, runs as hard check. If > 50%, degrades to Tier B (design-review-only, no automated check).

**Captain-Gate Checklist (Tier B fallback)** — see below.

**Stub-ack boolean extension** (#106 T6.2): `pre-acked-stubs: true|false` in entity frontmatter is a Principle 4 boolean gate — not an enum. If `pre-acked-stubs: true`, ship-plan Step 4 dim 10 auto-clears all stub flags found in task bodies. If `pre-acked-stubs: false` (default), each stub task requires an explicit Stub Flag entry in `## Plan Report` with captain rationale before cross-review PROCEED. This is deterministically computable from frontmatter — no prose judgment call required.

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

**5d · Indirection-sweep mandatory** (#106 T6.1): When `ship-runtime-detect Step R5` produces `theme_indirection: tailwind-v4` (or any non-empty value), `ship-plan` MUST auto-emit a Wave 0 task: `T0.X: Audit @theme inline indirection layer — verify design tokens align with CSS custom properties, no hardcoded hex values in component files`. Plan cross-review BLOCKS if `theme_indirection != ""` and this task is absent. Rationale: Tailwind v4 `@theme inline` indirection silently breaks token alignment when components use hardcoded values — plan-time sweep is the earliest catch. Tier A enforcement: `check-invariants.sh --check indirection-sweep-emitted` (fixture-based).

---

### Principle 6: Context Continuity + Layered Skill Architecture

**Rule A (Context Continuity)**:
Stage transitions within a pitch should prefer SendMessage to a named teammate over dispatching fresh-context subagent. Default team = planner (opus) + executer (sonnet) per pitch.

Fresh-subagent reserved for: (a) adversarial review across teammates; (b) clearly separate domain; (c) explicit captain request; (d) cross-review gate between stages (structured review prompt, ~5min).

**Rule A Fallback (when TeamCreate / SendMessage fails)**:

TeamCreate and SendMessage are experimental primitives — Kent's MEMORY `agent-teams-experimental-gotchas.md` documents three known failure modes (tmux silent fail, phantom teams, dead SendMessage). Fresh-Agent dispatches can also stall on the 600s stream watchdog (pitch 086 live evidence: 2 of 3 subagents stalled).

Stage skills MUST codify a fallback path for teammate-unavailable OR subagent-stall conditions:

**When to fall back** (any of):
- `TeamCreate` returns error OR team-listing shows phantom (empty / stale).
- `SendMessage` times out or returns no teammate response within the stage's expected window (~10× dispatch; see per-stage SKILL.md for specific timeouts).
- Fresh-Agent subagent stalls on stream watchdog (no progress for 600s).

**How to fall back** (preserve context continuity as much as possible):
- **Teammate-unavailable** → dispatch fresh-`Agent(subagent_type: ...)` with captured stage context packed into the prompt (entity files to read, stage intent, critical assumptions). This is the "fresh subagent + briefing" path.
- **Single-stage inline** → when fallback also fails or the stage work is bounded (≤ small-batch), main agent executes the stage inline with explicit pathspec commits. Not preferred but valid when circumstances warrant; annotate commit message with "inline after teammate/subagent failure".

**Stall-recovery sub-pattern** (subagent stalled post-edit, pre/post-commit):
1. Check `git log --oneline -3 -- <target-file>` — did the subagent land a commit before stalling?
2. If yes → inspect the commit content, verify it matches intent; no redo needed. Stall is not failure — it's dispatch infrastructure noise.
3. If no → redo the stage work (inline or via new fresh-Agent with same prompt). The `git stash` state may hold uncommitted subagent edits; inspect and salvage via `git stash show` + explicit pathspec commit if the edits are correct.
4. Capture recurrence: 3+ stall events in successive sessions → escalate to rabbit-hole `auto-recover-stalled-subagent-commits` (automated git introspection pattern).

**Team-spawn-retry discipline** (`team-spawn-retry-discipline`): When a newly-spawned teammate receives a SendMessage that races its first-turn idle transition, the message queues but is only read on next wake — resulting in apparent non-response. Reliable mitigation: re-send the same nudge SendMessage after the first `idle_notification` fires (cost ~1 extra turn). Observed 4× in pitch-092/093 session; fix works 100%. Apply this discipline before escalating to full Rule A Fallback. See MEMORY `agent-teams-spawn-proceed-race` for field evidence.

**Failure to codify fallback** → Tier B (design-review gate) violation. Stage SKILLs MUST contain at least one of the tokens `fresh subagent`, `fresh Agent`, `team unavailable`, `phantom`, `fallback`, OR an explicit comment `<!-- no TeamCreate — pure inline orchestration -->` annotation.

**FO Ask-Fallback (missing context escalation)** (#106 T3.3):

When a stage agent's Boot Self-Check detects missing context that it cannot resolve autonomously (unset `$WORKFLOW_DIR`, unknown framework detected, missing canonical dir, missing Hand-off block), it MUST escalate via `SendMessage(FO)` with a structured prompt — NOT guess or silently proceed.

Standard ask-fallback prompt structure:
```
SendMessage(to: "FO", body: """
Boot Self-Check blocked on: <stage-skill> for entity <entity-id>
Missing context: <what is missing>
Expected: <what the stage needs to proceed>
Action needed: <what FO should provide or confirm>
Fallback if FO unreachable: <safe default or halt>
""")
```

Enforcement: `bash plugins/ship-flow/bin/check-invariants.sh --check ask-fallback-coverage` greps each stage SKILL for `SendMessage.*FO|SendMessage\(FO\)` — FAIL if any stage SKILL lacks this pattern. Tier A.

**Rule B (3-Layer Skill Architecture)**:
Stage skills SHOULD delegate to Layer A superpowers atomic skill for core logic.

EXCEPTION: When Layer A's design philosophy fundamentally conflicts with stage requirement (e.g., ship-shape Mode A autonomous proposer vs superpowers:brainstorming Q-loop), stage skill may own the orchestration flow. Each such exception MUST be documented with rationale in the stage skill's SKILL.md.

Stage skills composed via 3 layers:
- Layer A: superpowers atomic skill (core brainstorm/plan/execute logic)
- Layer B: ship-flow research + peer review + discipline (Musk/Shape Up, Context7/firecrawl/exa, cross-agent review, goal-backward DC)
- Layer C: ship-flow canonical primitives (patch-map / extract-section / check-invariants / entity body schema)

Stage skills SHOULD augment with Layer B when superpowers atomic skill has scope gap (research depth, self-review). Stage skills MUST integrate via Layer C for canonical state.

**Rule C (Cross-Review Gate)**:
Each stage transition has a cross-review gate. Primary author's teammate counterpart reviews output with structured prompt covering 7 factors: (1) feasibility, (2) executable, (3) quality, (4) DC adequacy, (5) canonical sync, (6) coaching hygiene (ABC clause), (7) render fidelity / captain-ack audit trail (UI entities). FO decides final gate: veto / proceed / prompt captain.

**Rule C — Always Be Coaching (ABC) clause** (#106 T4.2):
Every cross-review finding, VETO, or PROMPT_CAPTAIN verdict MUST include a one-sentence coaching note naming: (a) which Principle / Failure Mode / INVARIANT the finding enforces, and (b) what past failure or future harm the rule prevents. This is not optional verbosity — it is the mechanism by which the captain builds model across sessions. Enforcement: ship-verify Step 4.6 spot-check audit includes "did the cross-review gate include coaching notes?" as a boolean DC. Finding severity NIT may omit coaching note (mechanical fix, no model-building value).


**Verdict-flip whitelist (density-aware autonomy, pitch 101)**:
When a cross-review emits PROMPT_CAPTAIN on a high-density entity, FO MAY flip to PROCEED if and only if:
- Gate input: `bash density-classify.sh --is-high --entity=<path>` exits 0 (Principle 4 boolean-gate; 4-tier enum NOT exposed here)
- Transition: PROMPT_CAPTAIN → PROCEED only; VETO is never flipped
- WHITELIST (4 boolean predicates, each evaluates true/false on a reason vector):
  - `reason_matches_skill_precedent` — finding cites a skill preset rule the repo already enforces
  - `reason_matches_canonical_constraint` — finding traces to PRODUCT.md / ARCHITECTURE.md hard constraint already documented
  - `reason_matches_precedent_count_ge_2` — finding pattern has ≥2 prior shipped precedents in `_archive/done/`
  - `reason_is_NIT_class` — severity classification = NIT (per ship-verify Step 4.6 mechanical auto-fix rule)
- Each flip MUST append a decisions.md row (see `docs/ship-flow/_mods/decisions-log.md`)
- Principle 4 cross-reference: the 4-row whitelist is itself 4 boolean predicates evaluable without runtime enum lookup

**Reviewer-unresponsive circuit breaker**: if the cross-review teammate is unresponsive (phantom team / SendMessage timeout / fresh-Agent stall), fall back per Rule A Fallback above — fresh sonnet by default, fresh opus when `appetite: big-batch`. Do not block stage advancement on an unresponsive reviewer. Each stage SKILL cross-review subsection MUST reference this fallback (pitch 091 grep-enforces this cross-reference; see `check_cross_review_gate` / `check_team_fallback_documented`).

**Verifier-side inline-fix bound** (codified 2026-04-29 via pitch-109 dogfood):
When verify-stage cross-review surfaces a BLOCKING that is (a) in entity scope, (b) ≤30 LOC, AND (c) mirrors design canon (no invented values), verifier MAY apply the fix inline + commit + continue verify round 2 instead of bouncing back to executer for a feedback round. Trade-off: saves ~1 feedback round (~$0.5-1 cost) at the cost of role-boundary blur. Audit trail: verifier MUST add a "Verifier-applied fixes" section in verify.md naming the deviation + commit SHAs + the in-scope/≤30-LOC justification. Prior precedent: pitch-109 verifier fixed `.wr-tr` token consumption (1-line CSS, mirrored design canon `war-room.html:443`) + DC selector parity (1-line YAML) when D1 BLOCKING surfaced.

**Captain-smoke round-cap concrete-fix exception** (codified 2026-04-29 via pitch-109 dogfood):
The "max 2 consecutive captain-smoke rounds without PROMPT_CAPTAIN" cap (per ship.md Step 7) refers to **iterative scope-ambiguity** rounds, NOT concrete-bug-with-known-fix rounds. Round 3+ is permitted when the finding is: (a) a concrete single-step bug with explicit captain-given diagnostic (e.g. "press \\ doesn't open HUD because anchor breaks at scrolled wr-shell bottom"), and (b) the fix is a single mechanical change (1-line CSS, single export, single attribute) NOT a re-design or scope re-decomposition. Iterative-ambiguity rounds (captain feedback that surfaces new scope branches each iteration) still cap at 2 → PROMPT_CAPTAIN. Prior precedent: pitch-109 round 3 (`position: absolute → fixed`) was concrete single-line fix from captain's specific diagnostic — sailed past 2-cap cleanly.

**Layer A delegation table** (examples from ship-flow 2.0, #085):

| Stage skill | Layer A delegate | Scope | Exception? |
|---|---|---|---|
| ship-shape (Mode A) | — | autonomous proposer owns flow | Yes — documented in SKILL.md (brainstorming's HARD-GATE Q-loop conflicts with autonomous contract) |
| ship-shape (Mode A — PM framing) | `problem-framing-canvas` | problem space mapping (who, what, why now, evidence) → feeds Problem: block | No — PM framing is Layer A delegation within Mode A compose phase (#106 T4.1) |
| ship-shape (Mode A — scope guidance) | `opportunity-solution-tree` | solution branch decomposition → feeds Children: + Rejected alternatives: | No — OST delegation within Mode A compose phase (#106 T4.1) |
| ship-shape (Mode A — acceptance framing) | `press-release` | user-observable outcome from captain's perspective → feeds Acceptance Outcome: | No — press-release delegation within Mode A compose phase (#106 T4.1) |
| ship-shape (Mode B) | `superpowers:brainstorming` | HARD-GATE Q-loop for ambiguous intake | No — clean delegation, Shape Up framing wraps brainstorm output |
| ship-shape (Mode C) | `superpowers:writing-skills` | skill design + claude 4.7 knowledge + RED/GREEN/REFACTOR | No — Shape Up framing wraps skill design |
| ship-design (Phase 1.5) | `storyboard` | 6-frame user-flow narrative — frames feed Phase 2 contradiction-detect + Phase 8 hand-off-to-plan `storyboard_frames`; verifier uses as render-fidelity contract (#106 post-merge polish) | No — Layer B wraps with 6-frame structure validation; fallback inline 6-bullet list if plugin absent |
| ship-design (Phase 3) | `design-flow` | contradiction-resolution Q-loop + design distillation (#106 T5.2) | No — Layer B wraps with 5-category classifier + per-app design-system.md; fallback `superpowers:brainstorming` if plugin absent |
| ship-design (Phase 9 adversarial) | `design-review` | independent visual review (designer/verifier separation invariant per DC-5.4) | No — same fallback as Phase 3 when plugin absent |
| ship | — | pure orchestration (5-stage dispatch) | N/A — no logic to delegate |
| ship-plan | `superpowers:writing-plans` | TDD order, wave safety, placeholder-free prose, task atomicity | No — Layer B wraps with scope anchoring + runtime detection + plan-checker |
| ship-execute | `superpowers:subagent-driven-development` | task = subagent, status protocol, review loop | No — Layer B wraps with wave graph + escalation ladder + pathspec-lock + Mode B re-entry |
| ship-verify | `worktree-dev-server` (project skill) + `e2e-pipeline:e2e-test` / `e2e-pipeline:e2e-walkthrough` / `ui-verify` | runtime preflight (dev server up gate) + agent-browser E2E verification for UI-typed DCs | No — Layer B wraps with ROI-aware scoped gate + spot-check UAT + runtime mandate (post-2026-04-26 carlove SEC-10/15 retro: no artifact-only PASS) |
| ship-review | `pr-review-toolkit:review-pr` (optional for big-batch) | multi-persona PR review (code-reviewer / silent-failure-hunter / security-reviewer) | No — Layer B wraps with ARCHITECTURE.md / ROADMAP / PRODUCT canonical doc sync |

**Cross-review gate 6-factor rubric** (base 5 + 1 stage-specific extension per #106 T1.3; adapted per stage — see each stage SKILL.md for full text):

| Factor | ship-plan | ship-execute | ship-verify | ship-review |
|---|---|---|---|---|
| **Feasibility** | tasks achievable single-dispatch? | wave plan executed cleanly (no terminal BLOCKs)? | gate scope correct (scoped vs full)? | PR size reasonable? |
| **Executable scope** | tasks atomic 1:1 with waves? | commits 1:1 with tasks (preserves bisect)? | verdict supported by evidence? | review scope matches actual diff? |
| **Quality** | Verification Spec covers every DC (≥1 structural-parity for UI)? | atomic pathspec, T1+T2 passed per task? | ≥1 critical assumption verified at runtime (Step 4.0 dev server up; per-DC runtime command captured)? | no silent failures; arch commits BEFORE PR body cites? |
| **DC adequacy** | observable (no "works correctly")? | AC procedures ran; output captured? | spot-checks critical DCs? | PR body DC+Verification table reproducible copy-paste? |
| **Canonical sync** | ARCHITECTURE.md touches planned? | architecture-impact blocks updated post-execute? | canonical docs consistent post-execute? | ROADMAP + PRODUCT updated; Architecture Changes cited? |
| **Reverse-audit previous stage** | Does the plan's scope expose a gap in the preceding design stage's hand-off block? | Does execute evidence expose a gap in the plan's wave ordering or stub-flag coverage? | Does verify's DC results expose a gap in execute's commit coverage? | Does review's canonical-sync check expose a gap in verify's render-fidelity assessment? |

**Rubric extension table** (stage-specific factors MAY be appended beyond base 6 with explicit namespacing):

| Extension factor | Stage | Namespacing | When required |
|---|---|---|---|
| `Render Fidelity` | ship-review (T6.4) | Appended as 7th factor | When `affects_ui: true` AND `render_fidelity_status` present in hand-off to review |

All stages use the same reviewer fallback pattern (Q1 from Wave 2 captain answers): cross-teammate counterpart → fresh sonnet default → fresh opus when `appetite: big-batch`. Verdict set: **PROCEED** / **VETO** (max 2 loops) / **PROMPT_CAPTAIN**.

**Failure modes**:
1. Agent dispatches fresh-context subagent for within-pitch stage transition without justifying one of the exceptions in Rule A.
2. Stage skill reinvents Layer A logic (e.g., rewrites brainstorming procedure) instead of invoking the superpowers atomic skill — OR creates an undocumented Layer A exception.
3. Stage transition lacks cross-review gate.
4. Cross-review rubric MUST keep base 5 factor names verbatim (feasibility / executable scope / quality / DC adequacy / canonical sync) — factor renaming or reordering breaks cross-stage review-pattern recognition. Additional stage-specific factors MAY be appended with explicit namespacing (e.g., `Reverse-audit`, `Render Fidelity`) and MUST be documented in the rubric extension table above. The base-5 → base-6 extension (adding `Reverse-audit`) shipped with #106 T1.3 is the canonical precedent for this extension mechanism.

**Enforcement** (two-tier, refined 2026-04-24 by #097):

- **Tier A — mechanical structural parity** (grep-enforced by `check_layer_a_table_parity` in `plugins/ship-flow/bin/check-invariants.sh`). Every stage SKILL.md that the master table (lines 157-168) assigns a concrete Layer A delegate MUST carry the canonical `## Layer A delegation (Principle 6 Rule B)` H2 heading AND a `description:` frontmatter `Layer A delegation: ...` prefix. Multi-mode stages (ship-shape) may substitute a documented `Layer A exception` annotation. Pure-orchestration stages (ship) are exempt (master-table cell `—`). Also see sibling mechanical checks: `check_layer_a_delegation` (invocation presence) and `check_team_fallback_documented` + `check_cross_review_gate` (Principle 6 Rule A + C).
- **Tier B — design-review / Captain-Gate Checklist**. Context-dependent dispatch choices remain Tier B: whether a documented Mode-A-style exception is *justified* in the current spec, whether a delegate's scope boundary respects Layer B augmentation boundaries, whether cross-plugin invocations preserve attribution. Grep cannot see this — design-review owns it.

Tier A covers master-table-to-SKILL presence; Tier B covers dispatch-choice appropriateness. The two are complementary, not overlapping.

**Rationale**:
- Opus 4.7 + 1M context + prompt cache make "fresh subagent per stage" (4.6-era defence) obsolete.
- Superpowers skills are atomic, not workflow — ship-flow's value is the Layer B/C augmentation.
- Cross-review catches author bias; superpowers doesn't self-review.
- Documented Layer A exceptions (like ship-shape Mode A) preserve stage design autonomy when atomic skill philosophy conflicts with stage contract.

**Source**: Session 2026-04-23 opus 4.7 self-reflection + captain direction. Supersedes implicit "always dispatch fresh" pattern from 4.6-era design. Preserves Principle 2 (skill count ≤ 7).

---

### Principle 7: Metadata-driven portability

**Rule**: Runtime/VCS/test-framework detection should happen in ONE helper, referenced by skills on demand. Not copied eagerly into each skill's preamble.

**Failure mode**: The "Runtime Detection Preamble" (13-ecosystem detection table) appears verbatim in multiple SKILL.md files. When ecosystems/commands update, drift risks.

**Grep check**: same as Principle #1 (`check-invariants.sh --check preamble-regrowth`). Consolidation target: 046f preamble-extraction.

**Portability constraint preserved**: ship-flow is template-grafted to other repos via `/spacedock:commission`. The single detection helper must remain portable (no host-project hard dependencies).

**Source**: `memory/ship-flow-harness-diagnosis.md:53-61` (portability constraint section).

---

### Principle 8: Artifact verbosity discipline

**Rule**: Stage report `.md` files MUST budget body content. Verbose evidence (raw command output, full DC tables, multi-section trace) goes inside `<details>` blocks or links to commits/PR; main body holds 1-paragraph TL;DR + structured findings table only.

**Per-stage line caps** (body content; frontmatter + section markers excluded):

| Stage artifact | Cap | Rationale |
|---|---|---|
| plan.md | ≤200 lines | Plan structure (waves + tasks + DCs) is essentially tabular; verbose research goes in `<details>` |
| execute.md | ≤150 lines | Per-task DC results table is the consumable; raw command output → `<details>` |
| verify.md | ≤120 lines | A4 gate table + render fidelity table are the consumables; everything else → link |
| review.md | ≤100 lines | Self-review verdict + canonical-sync result; PR draft is its OWN consumable |
| ship.md | ≤60 lines | Customer-visible summary + PR URL + ROI table; no procedural trace |

**Failure mode**: Stage artifacts that read like running session logs (e.g. pitch-107's execute.md @ 315 lines, verify.md @ 258 lines for a 160-LOC code change). The PR body + ship.md are what humans actually consume; intermediate stage trace is internal-only and accumulates as drift bait.

**Pattern enforcement**:
1. **TL;DR first** — 1-paragraph plain-prose summary at the top of each stage report.
2. **Structured findings table** — BLOCKING/WARN/NIT classification with file:line citations.
3. **Link out, don't re-cite** — reference INVARIANTS / MEMORY / commit SHAs instead of inlining.
4. **`<details>` for raw evidence** — full command output, full DC re-runs, full diff dumps go inside collapsible blocks.

**Grep check (proposed, not yet wired)**: `wc -l <stage>.md` should be ≤ cap when section markers + frontmatter excluded. Future `check-invariants.sh --check artifact-verbosity` candidate.

**Source**: pitch-107 dogfood observation (2026-04-28). Stage artifacts totaled ~840 lines for 160 LOC code change; consumable artifacts (PR body + ship.md) = ~270 lines; remainder was internal trace nobody reads. 60-70% reduction achievable without losing audit value if discipline is enforced upfront.

**Adopter discipline note**: each stage SKILL.md Output section should reference this principle with a 1-line callout (`Verbosity budget: see INVARIANTS Principle 8 — N-line target`). Initial commit lands canonical rule; per-SKILL pointers propagated in follow-up.

---

## Captain-Gate Checklist

Used for design-review of any skill/plan/entity change that may create a captain-interrupt decision point (Principle #4 Tier B fallback + manual reviewer checklist).

1. **Is the decision expressible as a boolean predicate over entity frontmatter + DC types?** If the answer is "depends on judgment" or requires a runtime enum lookup → reformulate until it is.
2. **Does this skill/stage add a new point where the captain is prompted/asked?** If yes: is the prompt framed as a boolean (`continue?: y/n`) or an enum (`mode?: ask|skip|auto`)? Reject enums without a boolean-decomposition rationale.
3. **If this is a gate between stages, who moves the entity forward on PASS?** Automated status flip or captain manual action? Automated gates must be deterministic; captain gates must be at shape only (or an explicit "captain smoke test" flagged in entity frontmatter).
4. **If the skill re-implements dispatch or orchestration logic similar to another skill**, can it fold via `source:` tag pattern (Principle #2) instead of living as a separate skill?
5. **If a new captain-prompt adds an enum with ≥ 3 values**, decompose into N boolean predicates OR provide a deterministic decision tree. No "ask me depending on the vibe" gates.
6. **Principle 6 (Context Continuity + Layered Skill Architecture)**: design-review each stage transition for named-teammate-default (Rule A), Layer A delegation compliance or documented exception (Rule B), and cross-review gate presence (Rule C). Tier B.
7. **If this commit adds or substantially modifies a persistent strategic doc** (adoption audit, design draft, SKILL.md semantic change, canonical `PRODUCT.md` / `ARCHITECTURE.md` / `ROADMAP.md` / `CONTRACT.md` entries), was a fresh-context verification subagent dispatched to verify low-confidence claims (non-trivial counts, `file:line` citations, consumer-list completeness, enforcement-strength assertions) before commit? Trigger threshold: ≥ 5 claims with less than HIGH confidence, or reorganization of architectural decisions. Verification dispatch is findings-only (no synthesis delegation — the author retains judgment on corrections). **Precedent**: `docs/ship-flow/adoption-readiness-audit.md` (2026-04-21) — sonnet subagent verified 9 claim groups, corrected 14→29 opinion inventory, surfaced 6 unexpected findings. Pattern aligned with dispatch-discipline counter-entry (MEMORY tail 2026-04-21 post-#075).

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

## FO Discipline

Rules for the orchestrator (first-officer role) during pipeline execution. These are behavioral, not structural — they govern **when FO pauses for captain** vs **dispatches autonomously**.

### Autonomous continuation between stages

**Rule**: Workflow template declares captain gates via `manual: true` on stage states (`docs/ship-flow/README.md` frontmatter). Only `shape` has `manual: true`. All other stage transitions (plan → execute → verify → ship → done) are autonomous — FO dispatches the next stage ensign directly without captain re-confirmation.

**Captain is in the loop at**:
- **Shape stage** — the ONE captain-interactive gate (defines problem + scope)
- **Verify findings with BLOCKING severity** or feedback-to-execute (NOT for PASSED)
- **PR merge** — captain's web-side action, post-ship
- **Explicit captain interrupt** ("stop", "wait", "not yet", etc.)

**NOT captain gates** (FO continues autonomously):
- Between plan → execute
- Between execute → verify
- Between verify PASSED → ship
- Post-ship status transitions (ship → done on merge)
- Auto-fix eligible NIT findings (ship-verify Step 4.6)
- Knowledge captures matching inline-to-skill rule (ship-verify Step 4.6)

**Violation patterns** (codify and catch):
- "Ready to proceed to plan?" — shape already passed scoring gate, next dispatch is implicit
- "Dispatch ship ensign now?" — verify PASSED, ship is the declared next stage
- "Next is ship, confirm?" — pipeline contract already answered by template
- "Fix NITs or skip?" — Step 4.6 disposition rule answers this mechanically

**Pre-action narration** (per CLAUDE.md Autonomous Action Boundaries) still applies for commits / pushes / PR creation. **Narration ≠ permission request.** FO states the action in DOING form and proceeds; captain interrupts if needed.

**Precedent**: entity #078 pipeline — FO paused 4+ times asking "proceed to next stage?" despite workflow template declaring all post-shape stages autonomous. Captain direction 2026-04-22: "這整個流程順序不夠順暢，應該自動做完你能做的". Rule codified this commit.

---

### Principle 9: Domain Registry — read-as-context, M1-M5 graceful-degradation surface

**Rule**: Cross-stage specialist dispatch (design-stage designer, plan-stage architecture-lens,
verify-stage intent-match-verifier) MUST consult `plugins/ship-flow/registry/defaults.yaml`
(with adopter override at project `.claude/ship-flow/domains.yaml`) via
`bash plugins/ship-flow/lib/registry-resolve.sh`. Direct hardcoded domain → specialist
mappings in stage SKILL.md prose are forbidden.

**M1-M5 surface** (the registry's contract with consumers):

- M1 specialist_missing — domain matched, specialist anchor empty → exit 10. Consumer renders HALT-with-options (skip / generalist-marker / file-specialist-first).
- M2 knowledge_module_missing — domain matched, knowledge module .md absent → exit 11. Same options as M1.
- M3 partial_coverage — multi-domain spec, some matched / some missing → exit 0, status=partial_coverage. Consumer proceeds with covered specialists, surfaces missing list.
- M4 parse_error — defaults.yaml malformed → exit 20. Consumer fails loud, blocks all dispatch.
- M5 invalid_trigger_config — domain entry has empty trigger_patterns AND empty spec_keywords → exit 21. Same as M4.

**Failure modes**:
1. Stage SKILL.md hardcodes a domain → specialist anchor (bypasses registry) — silent generalist fallback returns
2. Consumer ignores M1/M2 exit codes (treats them as ok) — exact failure mode #111 diagnoses
3. Adopter project YAML override silently merged into plugin defaults at runtime without lookup precedence

**Grep check** (Tier B / design-review):
- `grep -rE 'designer_section_anchor.*=|domain.*specialist' plugins/ship-flow/skills/*/SKILL.md` should return zero hits OUTSIDE the `domain-registry` SKILL.md itself.
- Tier A automated check deferred until 113.1 / 113.3 land (consumers needed for end-to-end test).

**Source**: pitch-113 (design-stage generalize) parent spec.md + 113.2 first-knowledge-module ship.

---

## Related Files

- `plugins/ship-flow/bin/check-invariants.sh` — CI grep implementation
- `plugins/ship-flow/hooks/warn-direct-read.js` — PreToolUse runtime warn hook (direct entity Read/Edit)
- `plugins/ship-flow/hooks/warn-state-drift.sh` — SessionStart runtime warn hook (FO state drift: merged PR still `status: ship`)
- `plugins/ship-flow/hooks/hooks.json` — hook wiring
- `plugins/ship-flow/lib/__tests__/test-check-invariants.sh` — test runner
- `.github/workflows/ship-flow-invariants.yml` — CI trigger
- `docs/ship-flow/_archive/ship-flow-invariants.md` — authoring history (post-archive)
- `memory/ship-flow-harness-diagnosis.md` — 2026-04-20 diagnosis snapshot (historical; see errata header)
