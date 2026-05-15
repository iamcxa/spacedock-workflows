# Ship-Flow Strengthening Roadmap (2026-05) — v3 (post-audit D-series pivot)

> Status: codex + claude parallel reframe pressure test (2026-05-14) → #1 pr-feedback-loop archived NOT_DOING
> Captain decision: **D-series replaces #1** — D2 (kc-pr-review-resolve auto-confirm) first, D1 (state-drift SessionStart auto-fix) next; #2 still measurement-gated
> Scope: ship-flow plugin + adjacent kc-pr-flow plugin strengthening — NOT a product roadmap
> Persistence: plan-of-plans, not a ship-flow entity itself

## Changelog

- **v1 (initial)**: 7 entities, adapter + verify_mode schema, post-ship pivot framing
- **v2 (codex feedback)**: dropped adapter/verify_mode terminology → `release.profiles` + carlove-only `preview_before_merge: true` flag; merged #4+#5; inlined #7; deferred #6; added 6 operational contracts to #2; spec'd polling architecture
- **v2 Tier A pivot (2026-05-13)**: #2 deferred to measurement gate. Captain ROI stress-test concluded #2 was architectural-purity-driven, not user-pain-driven — existing "merge + manual 30s URL check" workflow may be cheaper than maintaining 15+ probe scripts across 3 repos. 6 operational contracts extracted as cross-cutting Tier A scaffold (used by #1 already; available to subsequent stages incrementally if needed).
- **v2 Tier A pivot + #5 add (2026-05-13 same-session)**: added Tier 1.5 #5 `design-review-integration` after captain ROI-questioned `/design-review` integration into ship-verify. Architectural decision: place `/design-review` at ship-execute (fix-it-during-audit) not ship-verify (read-only contract) — preserves Layer A delegation boundary.
- **v3 audit pivot (2026-05-14)**: #1 `pr-feedback-loop` ARCHIVED as NOT_DOING after parallel Claude+Codex fresh reframe pressure test. Both reviewers unanimously rejected the "new stage" path; codex picked E (hybrid external runner), claude picked D (extend pr-merge.md). Audit revealed `pr-merge.md` is already a 427-line mod implementing 7-step `Hook: post-create` PR auto-review (Copilot wait + `/kc-pr-review-resolve` dispatch + auto-merge arming + `review_resolve_pending` + `Hook: idle` re-detection). Original framing — "captain manually re-triggers FO to check Copilot" — was a misread; real daily pain is 2-segment: (a) idle-hook trigger gap (captain doesn't run FO between PR-create and unrelated work) + (b) captain-confirm gate inside `/kc-pr-review-resolve`. Replaced by D-series: **D2 first** (remove confirm gate, 0.5d, in kc-pr-flow plugin), **D1 next** (X-mode: SessionStart state-drift auto-fix, ~0.5-1d, in ship-flow). Captain explicitly chose X (session-based FO) primary; Y (always-on daemon) deferred as "DY1: spacebridge daemon FO trigger" follow-up.
- **v3.1 hybrid model declared (2026-05-15)**: Captain explicitly named the observed development model — **GStack ↔ ship-flow hybrid**, two-layer split: strategy-layer (GStack-style plan-of-plans like this doc) + entity-layer (ship-flow pipeline). Tier A #3/#4/#5 are the bridges between layers. Added new `## Hybrid Workflow Model` section codifying the split. Marked as **active model, until found a better approach** — open to revision. Today's working session is itself an instance of strategy-layer GStack-style work (manual `/office-hours` + codex pressure test) → strengthening roadmap doc, while entity-layer Tier A work remains ship-flow-driven.
- **Entity count**: **5** active (#3, #4, #5, **D2, D1**); #1 archived; #2 deferred (was 7 in v1, 5 in v2, 3 in v2-Tier-A-only, 4 in +#5 add)

## Context (unchanged)

Captain's pipeline integration goal: `/office-hours → /autoplan → Linear → ship-flow` as the canonical solo-operator workflow.

Tier A solves the daily pain Kent **explicitly named**:
1. ~~**PR review feedback loop** — captain must manually re-trigger FO to check Copilot review comments~~ (→ #1) **— misread, see v3 audit; replaced by D-series**:
   - (a) idle-hook trigger gap → **D1** (SessionStart auto-fix)
   - (b) captain-confirm gate in kc-pr-review-resolve → **D2** (auto-confirm flag)
2. **Upstream artifact lossy translation** — office-hours/autoplan output in GBrain, shape can't see it (→ #3)
3. **Plan-stage cross-review gap** — `/autoplan` 4-lens stronger than verify-reviewer-panel (→ #4)

## Hybrid Workflow Model (GStack ↔ ship-flow) — active until better approach found

**Captain decision 2026-05-15**: codify the observed dev model. Two layers, two tool ecosystems, with Tier A entities as the bridges. This is the current working model; open to revision if dogfood evidence surfaces a cleaner split.

### Two-layer split

```
┌──────────────────────────────────┐    ┌──────────────────────────────────┐
│ Strategy Layer (GStack-style)    │    │ Entity Layer (ship-flow pipeline)│
├──────────────────────────────────┤    ├──────────────────────────────────┤
│ ideation / framing / scope cut   │    │ shape → design → plan → execute  │
│ multi-lens plan review           │    │   → verify → ship → done         │
│ second opinion / retro / learn   │    │                                  │
│                                  │    │                                  │
│ Tools:                           │    │ Tools:                           │
│   /office-hours                  │    │   ship-flow:ship-shape           │
│   /autoplan (4-lens)             │ ─▶ │   ship-flow:ship-design          │
│   /codex                         │    │   ship-flow:ship-plan            │
│   /design-review (iterative fix) │    │   ship-flow:ship-execute         │
│   /retro / /learn                │    │   ship-flow:ship-verify          │
│                                  │    │   ship-flow:ship-review          │
│ Artifact location:               │    │ Artifact location:               │
│   ~/.gstack/projects/<slug>/     │    │   docs/<workflow>/<id>-<slug>/   │
│   OR _plans/<plan>.md (this doc) │    │                                  │
└──────────────────────────────────┘    └──────────────────────────────────┘
              ↑                                            ↑
              └────── Bridges (Tier A) ────────────────────┘
              S1 #3: ship-shape --from-gbrain / --from-linear / --from-file
              V1 #4: ship-plan --with-autoplan + verify-side dedupe
              D1 #5: /design-review dispatched inside ship-execute (when affects_ui:true)
```

### Recursion boundary (ship-flow self-hosting)

ship-flow's own evolution splits across both layers — and **must** stay split for adopter trust:

| Type of change | Drives via | Why |
|---|---|---|
| **ship-flow plugin code / SKILL.md / lib/** | ship-flow entity (`docs/ship-flow/<id>-<slug>/`) | Self-dogfood is the credibility loop; if maintainer bypasses ship-flow for ship-flow changes, adopters can't trust the discipline |
| **ship-flow strategic direction / roadmap / framework reframing** | GStack-style plan-of-plans (`_plans/*.md` or `~/.gstack/projects/spacedock-ui/`) | Strategy is not entity-shaped; forcing it through 6 stages of ship-flow ceremony adds 0 value and dilutes entity-layer metrics |

This doc (`strengthening-roadmap-2026-05.md`) is itself an instance of the strategy layer — captured via manual `/office-hours`-style discussion + codex 2nd opinion, persisted as markdown, not advanced through any pipeline.

### What's GStack-distilled vs ship-flow-internal

For roadmap entity prioritization purposes:

| Category | Entities |
|---|---|
| **GStack-integrated** (consumes GStack output / dispatches GStack skill) | Tier A **#3** upstream-artifact-bridge, **#4** plan-autoplan-integration, **#5** design-review-integration |
| **Ship-flow internal** (zero GStack coupling) | D2, D1, deferred #2; plus all `todos/ship-shape-*` / `todos/ship-design-*` / `todos/ship-verify-*` / cross-cutting hardening |

Entities in the GStack-integrated bucket only deliver value once captain commits to `/office-hours → ship-flow` as the working pipeline. **Tier A #3/#4/#5 are conditional on that commitment** — defer them if captain pivots away from GStack-front pipeline.

### What does NOT change about ship-flow

The hybrid model does NOT alter ship-flow's load-bearing primitives — they're orthogonal to GStack:

- Entity tracking through 6-7 stages (`shape → ... → done`)
- Canonical doc atomic sync (ROADMAP / INVARIANTS / PRODUCT / ARCHITECTURE via `patch-map.sh --if-hash`)
- INVARIANTS grep checks (`bin/check-invariants.sh` C1-C13)
- Per-stage cross-review gates (sonnet/opus reviewer with PROCEED / VETO / PROMPT_CAPTAIN verdict)
- Per-entity worktree + named-teammate context continuity (planner / executer / designer / verifier)
- FO orchestration via spacedock

These are ship-flow's unique value vs GStack-only; they stay regardless of strategy-layer tooling.

### Revision triggers (when to reconsider)

Replace this hybrid with something else if:
1. **GStack adds entity-stage tracking** → ship-flow becomes redundant; fold into GStack
2. **Ship-flow adds `/office-hours`-equivalent + 4-lens review** → GStack becomes redundant; fold into ship-flow
3. **Captain pivots away from solo-operator workflow** → multi-user constraints may force different model
4. **Tier A #3/#4/#5 dogfood reveals the bridges are brittle** → revisit two-layer assumption

Until any of these fire, keep the hybrid explicit and Tier A bridges as the active integration surface.

## v3 Audit Findings (2026-05-14, post-#1 abort)

Documented for future entity authors so the same misread doesn't recur.

1. **Pre-existing infrastructure check is mandatory before "new capability" framing**: `pr-merge.md` mod was 427 lines and already implementing the bulk of PR auto-review (Copilot wait, kc-pr-review-resolve dispatch, auto-merge arming, idle hook re-detection). Original #1 was framed as "build new automation" but should have been framed as "find why existing mod doesn't trigger reliably". Process learning: shape stage MUST read existing `_mods/*.md` related to the touched lifecycle event before declaring greenfield scope.
2. **Daily pain audit must be tested before pitch**: original framing assumed "captain manually re-triggers FO" but real chain was "FO idle hook doesn't fire when captain isn't actively running FO + kc-pr-review-resolve has confirm gate". The 2-segment finding was only surfaced by parallel reframe test, not by initial shape.
3. **State-drift evidence is REAL not individual**: 3 entities sat at `status: ship + PR merged` for 2-7 days each. Pattern, not edge case. Mod-skepticism was well-calibrated; mod design wasn't wrong, *trigger mechanism* was.
4. **Captain Bet "wrong-if" branches CAN be validated cheaply by parallel reviewer dispatch BEFORE executer cost burns**: Claude+Codex pressure test cost ~$1-2 + 2 turns; would have caught misread before 2-3d executer + $5-10 burn.
5. **Cross-plugin gap awareness**: ship-flow strengthening can require kc-pr-flow changes (D2 lives in kc-pr-flow). Roadmap doc accepts cross-plugin entities when daily-pain-relevant; note adopter plugin in entity catalog.

## Resolved Open Questions (captain decisions, 2026-05-13)

1. **Carlove mobile (Expo iOS/Android)**: only cover Expo web build
2. **Linear sync**: Linear handles GitHub PR status sync itself; ship-flow only reads (`--from-linear`)
3. **Recce-cloud-infra Alembic**: bundled into k8s-api profile (if/when #2 revived)
4. **Recce OSS (PyPI)**: release manually controlled; entity terminal = `merged`
5. **ROADMAP intermediate state visibility**: simple (entity in `Now` regardless of sub-state)

## Cross-Runtime Compatibility Note

Ship-flow's FO supports both Claude Code and Codex runtimes via runtime adapters. Tier A entity design:

| Element | Claude runtime | Codex runtime |
|---|---|---|
| `gh` CLI ops | ✓ | ✓ |
| Entity body state writes | ✓ | ✓ |
| `feedback-to: execute` re-entry | ✓ | ✓ (codex FO adapter handles) |
| **#1 polling — CronCreate** | ✓ (durable, in-session) | ✗ no equivalent tool |
| **#1 polling — sync fallback** | ✓ | ✓ |

**#1 must implement both polling paths**: sync polling as universal default; CronCreate as claude-only opt-in accelerator.

## Tier A Entity Catalog (5 active + 1 archived)

### #1 `ship-flow:pr-feedback-loop` — **ARCHIVED 2026-05-14 (NOT_DOING)**

**Status**: archived at `docs/ship-flow/_archive/115-pr-feedback-loop/` (+ child `_archive/115.1-ship-pr-feedback-impl/`). Audit trail preserved including Captain Bet, plan.md with Y2 semantics + 8-file atomic-commit rationale, 6 rabbit-hole todos. Replaced by **D2 + D1** in this catalog (see below).

**Original design retained below for context — DO NOT execute**:

**Pain**: captain manually re-triggers FO to check Copilot review state.

**Design**: new stage between `reviewed` and `merged` (existing `done` terminal unchanged outside this stage). Polls Copilot review state, auto-fixes blocking comments via `feedback-to: execute`, escalates human reviewers and circular fix loops.

**Polling architecture (cross-runtime)**:
- **Universal default — sync polling**: stage skill runs `gh pr view` in a loop with sleep between iterations. Works in both runtimes. Captain context burden higher but predictable.
- **Claude-only opt-in — CronCreate**: durable cron `*/2 * * * *` (or off-mark), each fire is **stateless single-iteration** (load entity, do 1 iteration, write state, exit). Active window 45 min, quiet hours 18:00-09:00, max 15 iterations.
- Captain opts in via workflow README `release.pr_feedback.poll.scheduler: cron | sync` (default sync).

**Iteration logic**:
```
1. Acquire entity lock (.ship-flow/locks/<entity-id>)
2. Read entity body PR Feedback Loop section → iteration count, last state
3. gh pr view <PR> --json reviews,reviewThreads
4. Decide:
   APPROVED                          → advance to merged
   COMMENTED with nits only          → log nits, advance
   CHANGES_REQUESTED or unresolved   → feedback-to execute / reply / escalate per comment classification
   iteration >= max OR window expired → escalate captain
5. Write next_check_after timestamp + state to entity body
6. Release lock, exit
```

**Mechanizable inputs**:
- `gh pr view <PR> --json reviews -q '.reviews[] | select(.author.login=="github-copilot[bot]") | .state'`
- `gh pr view <PR> --json reviewThreads -q '.reviewThreads[] | select(.isResolved==false)'`
- `gh pr comment <PR> --body "/copilot review"`

**Reviewer config (workflow README)**:
```yaml
pr_feedback:
  reviewers:
    - login: "github-copilot[bot]"
      auto_handle: true
    - login: "*"
      auto_handle: false
      escalate_immediately: true
  poll:
    scheduler: sync                  # default; claude users can set to cron
    interval_minutes: 2
    active_window_minutes: 45
    max_iterations: 15
    quiet_hours: { start: "18:00", end: "09:00" }
```

**FO changes**: none.
**Size**: 1 entity.
**Dependencies**: none.

---

---

### D2 `kc-pr-flow:kc-pr-review-resolve-auto-confirm` — ✅ **SHIPPED 2026-05-14**

**Status**: shipped. PR [iamcxa/kc-claude-plugins#23](https://github.com/iamcxa/kc-claude-plugins/pull/23) (commits `7b26970` D2 + `56245e1` Copilot-review fix). Merged 2026-05-14T09:49:48Z (merge commit `1652d9a`). 3 Copilot inline findings (all docs-precision) addressed in fix commit + replied + resolved. Captain manually merged after CLEAN mergeable state.

**Plugin**: `kc-pr-flow` (NOT ship-flow). Cross-plugin entity in this roadmap because daily-pain-relevant.

**Pain solved**: segment (b) — `/kc-pr-review-resolve` has "User confirms action plan?" gate. Even when FO scan dispatches it, captain must confirm. Daily pain.

**Design**:
- Add `auto_confirm: high_confidence_only` flag to `kc-pr-review-resolve` skill workflow
- When ALL findings are: (i) classified `auto-fix` (mechanical, no judgment), (ii) confidence ≥ 8/10, (iii) `kc-pr-flow:break-point-probe` passes verification → skip confirm gate, proceed to fix dispatch + reply + resolve threads
- Mixed or low-confidence findings → preserve confirm gate (captain judgment required)
- Adopter opts in via project CLAUDE.md skill-routing block or kc-pr-flow workflow README

**Why this scope**:
- Doesn't touch ship-flow at all (zero coupling)
- Doesn't grant skill the authority to push controversial fixes — high-confidence-only preserves human-in-loop for ambiguous cases
- Captain Bet target: when carlove PR gets clean Copilot review → kc-pr-review-resolve nits-only path → auto-confirm → fix → reply → resolve. Zero captain touch.

**Size**: 0.5d
**Dependencies**: none

---

### D1 `ship-flow:state-drift-sessionstart-auto-fix` — **DO SECOND**

**Pain solved**: segment (a) — `Hook: idle` doesn't fire when captain isn't actively running FO. State-drift evidence: 3 entities sat 2-7 days at `status: ship + PR merged`.

**Captain decision**: X-mode (session-based FO) primary. Y-mode (always-on daemon) deferred to follow-up.

**Design**:
- Extend existing `warn-state-drift.sh` (or equivalent ship-flow SessionStart hook) from WARN-only to OPTIONAL AUTO-FIX:
  - On SessionStart, scan PR-pending entities (status:ship + non-empty pr)
  - For each entity where `gh pr view <pr> --json mergedAt` returns non-null: prompt captain "advance N entities to done? (y/n)" — default y if Claude Code config allows
  - On y: invoke same done+archive sequence we ran manually this session (`status --set` + `status --archive` + commit)
- Cleaner output than current warning-only: structured (entity, pr#, merged-at-date, action-proposed)
- No auto-action on complex cases (status:ship + pr empty, or status:ship + PR open) — those still surface as WARN for captain

**Why X-mode not Y-mode**:
- X-mode = session-based: hook fires on SessionStart, captain sees + approves once per session. No daemon process trust boundary. No race against captain's active session.
- Y-mode (DY1 follow-up) = spacebridge daemon trigger periodic FO idle scan. Higher value (zero session-resume wait) but daemon process making git commits is new trust surface.
- Captain reasoned: session-based catches drift on next session start (typically same-day for active dev); good enough for Bet target.

**Size**: 0.5-1d
**Dependencies**: D2 not blocking, but recommended D2 ships first (smaller, validates pivot before tackling FO-trigger gap)

**Follow-up (DY1, deferred)**: spacebridge daemon FO trigger — captures Y-mode if X-mode proves insufficient at 2-week retro.

---

### #3 `ship-flow:upstream-artifact-bridge`

**Pain**: `/office-hours` and `/autoplan` produce artifacts in GBrain (`~/.gstack/projects/<slug>/`); shape stage cannot see them; captain lossy copy-pastes into Linear issue.

**Design**:
- `ship-shape --from-gbrain <slug>` — inline GBrain design doc into sharp output `Upstream context` section
- `ship-shape --from-linear <issue-id>` — pull Linear issue + comments (read-only)
- `ship-shape --from-file <path>` — generic file ingestion
- Shape preamble detects `~/.gbrain/config.json + command -v gbrain` → silent skip if absent

**GBrain dependency**: opt-in only; absent installation is zero-cost (silent skip).
**Linear**: read-only ingestion; no writeback.
**Size**: 1 entity. **Dependencies**: none.

---

### #4 `ship-flow:plan-autoplan-integration`

**Pain**: `/autoplan` provides 4-lens (CEO/Eng/Design/DevEx) plan review stronger than verify-reviewer-panel, but currently must be invoked manually, AND verify-stage will redundantly re-run overlapping lenses if invoked.

**Two-sided design in single entity**:
- **Plan side**: `ship-plan --with-autoplan` flag — after plan.md drafted, automatically run `/autoplan`, write 4-lens verdict into plan.md `External Review` section
- **Verify side**: `verify-reviewer-panel` detects `External Review` section → skips CEO/Design/DevEx overlapping lenses, only runs technical lenses (silent-failure, domain-expert, general-external)

**GStack requirement**: `--with-autoplan` flag requires gstack installed; flag errors loudly if absent (explicit opt-in). Verify-side dedupe always runs (silent skip if no External Review section).

**Size**: 1 entity. **Dependencies**: none.

---

### Tier 1.5 — Visual Polish Integration

### #5 `ship-flow:design-review-integration`

**Pain**: UI entity 寫完 code 後沒有自動 visual polish；captain 必須手動跑 `/design-review`。GStack `/design-review` 提供 designer-eye QA + AI-slop detection + iterative atomic-commit fix-and-recheck — 是 ship-flow `ui-verify`（computed-style fragment probe）/ `whole_page_visual_targets`（pixel-diff）之外缺的「視覺品味審視」層。

**Architectural decision** (captain 2026-05-13): `/design-review` is **fix-it-during-audit** model (modifies code, atomic commits). Conflicts with ship-flow verify's **findings-only contract** (reviewer panel writes findings, doesn't fix). Therefore integrate at **ship-execute** (when `affects_ui: true`), NOT ship-verify. Preserves Layer A delegation boundary.

**Design**:
- ship-execute 加 conditional sub-step「after UI code committed + before hand-off to verify, dispatch `/design-review` if available and `affects_ui: true`」
- INVARIANTS Layer A delegation 條目補上「`/design-review` (GStack) owns visual polish for UI entities during execute stage; ship-flow `ui-verify` owns computed-style fragment verification during verify stage」
- gstack-optional：silent skip when `/design-review` not invokable

**Out-of-scope** (留 future entity):
- `/design-review` 結果寫回 entity body 結構化 record（先用 git log 看）
- Multi-iteration `/design-review`-then-/qa-then-/design-review chaining
- carlove-specific design-system token enforcement

**Size**: 0.5-1d
**Dependencies**: none

---

## Operational Contracts (extracted from deferred #2)

These 6 contracts emerged from codex review of #2. They're **scaffolding patterns** — not a blanket enforcement framework. Apply incrementally where Tier A stages need them.

### C1 — Per-entity lock + concurrency cap

Atomic file lock at `.ship-flow/locks/<entity-id>` (with owner/stage/started_at/expires_at fields) prevents cron+captain race + cross-entity stampede. **Used by #1** (cron polling vs captain manual advance interleave protection).

### C2 — Exit code contract for shell probes

`0=success / 10=not ready / 20=transient / 30=misconfig→escalate`. Caller can implement retry/backoff based on exit code without parsing stderr.

**Used by #1** for `gh pr view` wrapper (rate limit → 20, no PR → 30).

### C3 — Stale-state policy

Successful probe declares evidence valid for N minutes. Within window, transient failures keep prior known-good rather than bouncing entity backward.

**Used by #1** for "Copilot was APPROVED 5 min ago, current `gh pr view` returned transient 502 — keep APPROVED state, don't bounce".

### C4 — Check vs Act phase separation

Mutating commands under `act`; read-only verification under `check`. `check` always re-runnable; `act` runs at most once per stage transition. **Not used by #1** (all probes read-only). Available for future mutating stages.

### C5 — Captain interrupt resume

Stages write loop state before sleeping/exiting (iteration count, last result, next eligible check time). Single-iteration friendly. **Used by #1** mandatorily — both cron and sync modes resume from entity body, never lose iteration count.

### C6 — Config version stamping

Entities only enter new stages if frontmatter `release_config_version >= N` set when first reached. Existing entities pre-stamping remain on legacy terminal. **Not yet used in Tier A** (no schema change pivot). Reserved for #2 if revived.

**Why extract these now**: Even Tier A entities use C1/C2/C3/C5 (#1 needs all four). Documenting them as cross-cutting prevents per-entity reinvention.

## Measurement Gate for Deferred #2

When to revisit `release-lifecycle` (#2 from v2):

**Trigger signals — revisit if any 2+ become true**:
1. Captain manually checks "PR merged → production live" status **multiple times per week**
2. Incident: "thought it was shipped but actually deploy broke" happens **at least once**
3. Captain wishes for a "all in-flight entities + their live status" dashboard
4. Net new repo adopts ship-flow with **different deploy tech** (5th adopter)

**If revisited**: rewrite using v2's `release.profiles` spec as foundation (git history preserves it).
**If not revisited within 12 months**: GC entirely. Existing workflow proved sufficient.

**What does NOT trigger revisit**:
- One-off curiosity ("would be nice to know")
- Single isolated deploy regression (use post-mortem, not architectural response)
- 6th `kubectl rollout status` invocation (that's the existing workflow, not pain)

## Dependency Graph

```
~~#1 pr-feedback-loop~~       ARCHIVED 2026-05-14 (audit pivot)
D2 kc-pr-review-resolve-auto-confirm   (no deps, do first — segment b fix)
D1 state-drift-sessionstart-auto-fix   (no hard deps, do second — segment a fix)
#3 upstream-artifact-bridge   (no deps)
#4 plan-autoplan-integration  (no deps)
#5 design-review-integration  (no deps)
```

All 5 active entities parallel-shapeable. **Recommended order: D2 → D1 → #3/#4/#5**. Captain Bet retro (2026-05-28) measures D2+D1 combined effect against original "5 carlove PR 0 manual touch" target.

## Loss Function (5 active + 1 archived)

| Entity | Cost of not doing | Cost of doing | Ratio |
|---|---|---|---|
| **D2 auto-confirm gate** ✅ SHIPPED | Every kc-pr-review-resolve dispatch waits for captain confirm — daily friction even when fixes are mechanical | 0.5d (shipped 2026-05-14, PR #23 merged) | **extreme** (immediate ROI; no schema change) |
| **D1 SessionStart auto-fix** | State-drift accumulates 2-7d (proven by 3 archived entities this session); idle hook coverage gap not closing on its own | 0.5-1d | high (per-cycle compounding) |
| #3 upstream-artifact-bridge | Every ideation→shape is lossy copy-paste | 1 entity | high (per-entity compounding) |
| #4 plan-autoplan-integration | Important entities miss 4-lens review + pay duplicate cross-review | 1 entity | mid |
| #5 design-review-integration | UI entities ship without visual polish pass; captain manual /design-review | 0.5-1 entity | mid (UI entities only — bounded population) |
| ~~#1 pr-feedback-loop~~ | ~~Daily manual FO re-trigger~~ | ~~1 entity~~ | **ARCHIVED — misread daily pain; D2+D1 are correct decomp** |

**Deferred** | #2 release-lifecycle | "Don't know if feature is actually live" — but captain can manually check in 30s | 2-3 entities + 15+ shell scripts | **measurement gate; not currently worth it** |

**Deferred (Y-mode follow-up)** | DY1 spacebridge daemon FO trigger | Captain Bet 0-touch upper limit (session-based catches drift on next session, daemon catches in real-time) | 1-2d daemon + race-safety work | **measurement-gated on D1 retro 2026-05-28** |

Total active scope: **~3-4 working sessions** across 5 entities. Smaller than v2 (5-6) because D2+D1 are each ~0.5d.

## Cross-Cutting Constraints (Tier A)

1. **Backward compatibility**: ship-flow `done` remains terminal for all existing entities. Tier A adds new `pr-feedback` stage between `reviewed` and current terminal flow, plus new shape flags and plan/verify integrations — no schema-level break.
2. **Gstack-optional**: any GBrain integration (#3 read-side, #4 invocation, future writebacks) silent-skip when absent. Exception: #4's explicit `--with-autoplan` flag errors loudly when gstack missing.
3. **Cross-runtime**: Tier A entities work in both Claude Code and Codex FO runtimes. CronCreate is claude-only opt-in accelerator for #1; sync polling is universal default.
4. **No FO/commission changes**: Tier A is pure ship-flow plugin internal.
5. **Operational contracts (C1-C6)**: extracted as cross-cutting scaffold; apply incrementally per-stage as needed.

## Out-of-Scope

| Item | Rejection reason |
|---|---|
| Ship-flow internalizes `/office-hours` | Different concern (should-we-build vs how-to-build) |
| `ship-shape --with-ceo-review` | Shape has captain in room; cross-review ROI low |
| Ship-flow internal deploy logic | Per-repo knowledge, must never leak in |
| Cross-project canonical doc sync | Single-repo ship-flow only |
| Live writeback to Linear | Linear handles own GitHub sync |
| RemoteTrigger for polling | Cold-bootstrap too expensive |
| GitHub webhooks for PR feedback | Infrastructure premature |
| `release.profiles` schema (#2) | Deferred — see Measurement Gate |
| `verify_mode: pre-merge / post-merge` bifurcation | N=1 (carlove only) — would be schema bloat |
| `done → shipped` terminal rename | Deferred with #2 |
| `landed / live / shipped` stages | Deferred with #2 |

## Open Items

- [ ] Captain sign-off on Tier A pivot
- [ ] **Shape #1 `pr-feedback-loop`** with cross-runtime design: sync default + claude-only CronCreate opt-in
- [ ] FO state-drift cleanup (orthogonal — see below)

## Surfaced (orthogonal to this roadmap)

**FO state-drift detected at session start** (Rule A violation, 3 entities):
- `entity-inspector-drawer` — PR #132 MERGED, entity still `status: ship`
- `A2-rename-shape-output-spec-to-shape-md` — PR #120 MERGED, entity still `status: ship`
- `ship-pr-metadata-backfill` — PR #140 MERGED, entity still `status: ship`

Recommendation: run `done + archive` sequence per `plugins/ship-flow/skills/ship-execute/SKILL.md` for each before shape #1 starts execute work. **Not blocking this plan-doc work, but should clear before next execute dispatch**.

---

**Roadmap document**: `plugins/ship-flow/_plans/strengthening-roadmap-2026-05.md`
**Author**: Claude (opus 4.7) + Captain Kent + codex external review + captain ROI pivot
**Date**: 2026-05-13
**Next action**: captain sign-off → shape #1 (cross-runtime polling architecture)
