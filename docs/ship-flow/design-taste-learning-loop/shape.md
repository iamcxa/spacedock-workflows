# Design-taste learning loop — captain UAT verdicts to ratified per-repo canon — Shape

### Summary

Make captain 審美/UX judgment **accumulate instead of evaporate**. Today taste lives only inside a
live session (the `design-officer` standing teammate, `ship-design/SKILL.md:450-484`) and is lost
across sessions and entirely in bare mode; UAT rejects are captured as ad-hoc prose tables with no
schema, no enforcement, and no consumer — the exact "retrospective sediment" failure the plugin
already names for un-harvested candidates (`INVARIANTS.md:611`). This entity closes the loop:
structured UAT-verdict capture → periodic harvest into CANDIDATE canon → captain batch-ratification
(model proposes, never self-mutates) → per-repo `design-canon.md` consulted by `ship-design`
pre-generation → mechanizable rules graduate to `ui-verify` code gates.

**This is NOT greenfield.** The reverse-recovery audit (below) finds that every one of the four ACs
is a **known, shipped ship-flow pattern pointed at a new payload** — not a new capability. Nothing
is architecturally novel; the work is authoring one record family, one rubric asset, and wiring
four existing seams. That is what shrinks execute to a next-session S + M.

**Appetite: 1h30m for shape + design ONLY tonight. Execute is the explicit cut** (deferred at the
100% brake, sliced below). This shape freezes the contract; design specifies the schema/format
deltas; execute authors them next session.

### Captain Articulation — already given, NOT re-asked

- **hackathon-2 Wave 3 GO** — committed work, not a fresh pitch (`index.md` source line).
- **Bulk attestation「原則上是都核准」(2026-07-20)** — same standing approval that governs the
  sibling tick-hardening entity.
- **Distill-not-depend HARD CONSTRAINT** (captain, `index.md:22-24`) — cold-start rubrics are
  DISTILLED into ship-flow-owned in-repo assets (study third-party design-review methodologies as
  references, author our own files); NO runtime dependency, invocation, or wrapping of third-party
  plugins.

This shape does not re-open the Musk audit or re-ask articulation. It runs the reverse-recovery
audit the ACs demand and slices execute for a separable next session.

### Problem — the taste evaporates (reverse-recovery layer-trace)

Trace the value spine UAT-verdict → durable canon → next design, recording state per seam:

| Seam (AC) | State | Cited evidence — what exists vs. what is absent |
| --- | --- | --- |
| AC-1 Capture contract | **MISSING** (rides an EXISTS_BROKEN host) | The `### Feedback Cycles` record family is real + Tier-A enforced (spec `INVARIANTS.md:571`; awk validator `bin/check-invariants.sh:1546-1601`; fixture `lib/__tests__/test-enforce-advance-stage.sh:932`) but its `captain_decision` is validated against the literal `"fix"` ONLY (`check-invariants.sh:1578`) — it cannot express "accept" and carries no reason/dimension/artifact fields. The verify UAT surface (`ship-verify/SKILL.md:704` Captain UAT Feedback Router, table `:711-718`) is a routing table, not an accept/reject verdict. No structured accept/reject + reason + artifact-ref record exists (grep `verdict\|UAT\|reject-reason\|design-verdict` → only FO-autonomous `reviewer_verdict`, `entity-body-schema.yaml:445`). |
| AC-2 Harvest + ratify | **STUB** | The cluster→propose→captain-batch→append-ledger→**never-self-mutate** loop is LIVE for success-mode candidates: `harvest-decide/SKILL.md` (captain checkpoint `:68-71`, append-only ledger `:75-88`), invariant-pinned (`INVARIANTS.md:607-621`; `:615` "canon mutations require captain approval BEFORE the ledger entry is stamped"). But it is wired to `review.md` success/failure candidates, decides one-at-a-time (clustering explicitly deferred `SKILL.md:33,113`), and **no `design-canon.md` exists anywhere** (`find -iname design-canon.md` → empty). |
| AC-3a ship-design consult + challenge | **MISSING** (reusable blocks present) | The pre-generation per-repo-doc consult slot exists (`ship-design/SKILL.md:26-31` Boot Self-Check step 7 reads PRODUCT/ARCHITECTURE before dispatch) — the natural hook for "read `design-canon.md` if present". `ui-quality-contract.md` is consulted only post-gen (`ship-design/SKILL.md:764`, Phase 9) and is plugin-global, not per-repo. Challenge-clause absent in ship-design; a working analog exists in `harvest-decide/SKILL.md:66` ("Override with rationale when the rubric disagrees"). |
| AC-3b Graduation → ui-verify | **MISSING** (reusable blocks present) | `ui-verify` gates computed CSS / tokens / dimensions via declarative YAML checks (`ui-verify/SKILL.md:43-67`); a design-authored-target → ui-verify-YAML generator already exists (`render_fidelity_targets[]` → `lib/generate-ui-verify-spec.sh`, `ship-design/SKILL.md:770`). No documented path from a prose canon rule → that generator (`grep graduat` → 0 hits). |
| AC-4 Distilled rubric | **MISSING** (the distill-not-depend precedent is LIVE) | `lib/design-methodology/*.md` are ALREADY in-repo prose snapshots of the exact third-party methodologies the captain named — `INDEX.md:3` "Source: gstack design skills {design-shotgun,design-consultation,design-html}", `:11` "cannot invoke at runtime … snapshot the methodology PROSE"; `shotgun.md:2-3` carries the `Source:` provenance line. The `distill-reference` skill embodies the pattern (`SKILL.md:12`, hermeticity `:78-90`). But `rubrics/` holds only `_meta-rubric.md` (a meta-format, not a design rubric); `ui-quality-contract.md` is rubric-shaped (`:19-55`) but has no cited methodology provenance. |

**Classification summary (5-tier):** AC-1 MISSING · AC-2 STUB · AC-3a MISSING · AC-3b MISSING ·
AC-4 MISSING. **None require net-new architecture** — every seam recovers a shipped pattern (record
family + awk enforcement; harvest→ratify→ledger→invariant; pre-gen consult slot; target→ui-verify
generator; distilled-snapshot-with-provenance). The one broken host (Feedback Cycles' `"fix"`-only
`captain_decision`) is scoped to that seam.

**Disproof hooks** (any flips the classification): AC-1 — `check-invariants.sh` validates a
`captain_decision` value other than `"fix"`, or a new block under `### Feedback Cycles`. AC-2 —
`find -iname design-canon.md` returns a real file OR ship-design gains a consult-canon step. AC-3 —
`grep -rn "design-canon" ship-design/SKILL.md` returns a Boot/Phase-0 read step. AC-4 —
`find rubrics -iname '*design*'` returns a provenance-carrying rubric with zero `Skill: design-*`
tokens.

### Distill-not-depend — concrete definition + greppable proof (AC-4, HARD CONSTRAINT)

**"Distilled rubric asset" means**, concretely: an in-repo file (under `plugins/ship-flow/rubrics/`
or `references/`) authored by **studying** third-party design-review methodologies and rewriting the
judgment as ship-flow-owned prose/checks — the identical discipline already shipped in
`lib/design-methodology/*.md`. It MUST carry a `Source:` provenance line naming what was studied
(as `shotgun.md:2-3` and `INDEX.md:3` do), and it MUST be readable/consumable with **zero runtime
invocation** of any third-party plugin (no `Skill: design-*`, no `npx design-*`, no gstack runtime
bin `$D`/`gstack-*`).

**Greppable no-dependency proof** — scoped to the files THIS loop introduces (the distilled design
rubric, `design-canon.md`, and the capture/harvest/consult code paths), the following returns empty:

    grep -rniE "Skill: design-(review|shotgun|consultation|html)|npx +design-|gstack-|\$D\b" <loop-introduced files>

Baseline validated today over `rubrics/` → empty (exit 1, clean). **Scoping note (captain
awareness):** the proof is scoped to loop-introduced files, NOT the whole plugin, because
`ship-design/SKILL.md:661` carries a pre-existing, separately-approved `Skill: design-review`
adversarial-cross-review dispatch **with fallback** (`:663`) — that seam predates this entity and is
out of scope. The distilled asset studies methodology-as-reference (allowed); it never invokes it.

### Acceptance criteria (absorbed from index.md — mechanism paired to the value it protects)

The value measure is one metric: **UAT reject-rate per shipped UI entity trends down** — computable
only once AC-1 captures verdicts, so AC-1 is what turns the loop's value from anecdote into a number.

- **AC-1 Capture contract.** A structured captain-UAT-verdict record (accept/reject + one-line
  reason + artifact ref) authored in the `### Feedback Cycles` record-family PATTERN (heading-block
  + awk enforcement in `check-invariants.sh`), written at the verify UAT point (`ship-verify:704`)
  and the post-PR captain-smoke point (`ship/SKILL.md:454,476`). *Value:* rejects stop evaporating
  into prose; the metric becomes computable. Verified by: schema/fixture + a worked example record.
- **AC-2 Harvest + ratify loop.** A harvest procedure clusters recurring reject reasons into
  CANDIDATE canon rules for captain batch accept/defer/reject; ratified rules land in a per-repo
  `design-canon.md`; the model NEVER mutates canon without ratification (invariant-pinned, mirroring
  `INVARIANTS.md:615`). *Value:* taste graduates from one-off to durable rule, gated by the captain.
  Verified by: procedure doc + dry-run harvest on synthetic records + the invariant check.
- **AC-3 Consumption seams.** `ship-design` consults `design-canon.md` pre-generation when present
  (hooked at the Boot Self-Check step-7 slot `:26-31`) with a challenge-clause escape (analog:
  `harvest-decide:66`); + a documented graduation path for mechanizable rules into `ui-verify`
  checks (via the existing `render_fidelity_targets[]` → `generate-ui-verify-spec.sh` generator).
  *Value:* canon actually changes the next design, and hard rules become code gates not prose.
  Verified by: SKILL seam text + one worked mechanizable example.
- **AC-4 Distilled cold-start rubrics.** Ship-flow-owned rubric asset(s) authored in-repo (methodology
  studied + `Source:` provenance, zero third-party runtime dependency). *Value:* the loop starts warm,
  not from a blank canon. Verified by: rubric file exists + the greppable proof above returns empty.

### Execute slicing + cut-line (EXPLICIT — execute deferred to next session)

Tonight's brake stops after **shape + design**. Design specifies the contract deltas (the AC-1
record schema + awk rule, the `design-canon.md` format, the harvest extension shape, the consult
hook, the graduation doc). Execute is cut and organized as **two separable next-session entities**,
ordered by dependency:

- **Slice-1 (S) — "Capture + cold-start"** = **AC-1 + AC-4**. Both are *author-an-asset* with no
  cross-skill runtime wiring: the verdict record schema/fixture (+ the awk rule) and the distilled
  design rubric (+ provenance + greppable proof). Produces the raw material the loop consumes. Low
  coupling, fixture-testable.
- **Slice-2 (M) — "Harvest → ratify → consume"** = **AC-2 + AC-3**. The integration across
  `harvest-decide` (design-verdict clustering → `design-canon.md`, new invariant), `ship-design`
  (pre-gen consult + challenge clause), and the ui-verify graduation doc. **Depends on Slice-1's
  record schema existing.**

**Cut-line recorded:** shape (this) + design (contract) tonight → Slice-1 (S) next session →
Slice-2 (M) after. If the 1h30m brake bites mid-design, design narrows to the Slice-1 contract and
Slice-2's design defers alongside its execute — never a silent half-design.

### Size, appetite, out-of-scope

- **Size:** M for the whole loop, delivered as **S + M** execute slices (see cut-line). No new
  canonical store beyond `design-canon.md` (per-repo) + the verdict records (ride existing entity
  bodies) + one distilled rubric file.
- **time_budget:** 1h30m for **shape + design tonight**; execute explicitly deferred.
- **Out of scope (deferred without loss):** any runtime invocation/wrapping of third-party design
  plugins (HARD CONSTRAINT); retrofitting the pre-existing `ship-design:661` `design-review`
  dispatch; the success-mode `harvest-decide` conflict-grouping hardening (`SKILL.md:33`) unless
  Slice-2 needs clustering primitives; the debt-tracker hook (`INVARIANTS.md:613`, already deferred);
  cross-repo adopter migration of `design-canon.md`.

### Design constraints (typed — hand-off to design; affects_ui: false)

- **DC-1 (interface) — AC-1 record home fork.** Design decides between (a) additive OPTIONAL fields
  on reject-type `### Feedback Cycles` records (`reject_reason`, `design_dimension`, `artifact_ref`)
  + a light accept record, vs (b) a distinct sibling `### Design Verdicts` block. Constraint: MUST
  NOT destabilize the load-bearing `captain_decision:"fix"` contract (`check-invariants.sh:1578`;
  110+ tests) that route-back depends on. Name every string-assertion test that pins the touched
  awk region before changing it.
- **DC-2 (structural) — AC-2 never-self-mutate invariant.** The design-canon ratify path MUST add an
  invariant structurally mirroring `INVARIANTS.md:615` (canon mutated ONLY after captain approval,
  proposal written to a `.context/`-style staging file first, `harvest-decide/SKILL.md:68-71`
  precedent). The model proposes; it never self-ratifies.
- **DC-3 (behavioral) — AC-3a consult is advisory + challengeable.** The pre-gen `design-canon.md`
  read MUST carry the challenge clause (`harvest-decide:66` analog): the designer MAY deviate from a
  canon rule with recorded rationale. Rationale: the captain's own **taste-ossification guard**
  (`index.md`) — canon must not freeze judgment.
- **DC-4 (structural) — AC-4 hermeticity.** The distilled rubric obeys the `lib/design-methodology/`
  hermeticity policy (`distill-reference/SKILL.md:78-90`): `Source:` provenance line required; zero
  third-party runtime tokens; the greppable proof above is a shell test in the loop's suite.
- **DC-5 (interface) — AC-3b graduation reuses the generator.** A "promoted-mechanizable" canon rule
  graduates by emitting a `render_fidelity_targets[]` entry consumed by the existing
  `generate-ui-verify-spec.sh` — design does NOT build a second ui-verify code path.

### ROADMAP `now` row intent

- **Move** `design-taste-learning-loop` from **Later → Now**: `| design-taste-learning-loop |
  Design-taste learning loop — captain UAT verdicts to ratified per-repo canon | design |`
  (committed hackathon-2 Wave 3). Note execute deferred (cut-line above) — the row parks at `design`
  tonight, not a full pipeline run.
- No Later rows to fold (no sibling taste-loop todos exist).

### Canonical-doc impact

- **ROADMAP.md** — Later→Now move (doc-impact block required at ship). The metric
  (UAT-reject-rate-trending-down) is the row's value claim.
- **INVARIANTS.md** — AC-2 adds one invariant (design-canon never mutated without ratification,
  mirroring `:615`); AC-1 may add a design-verdict record well-formedness invariant. Candidates for
  design, not shape commitments.
- **entity-body-schema.yaml / references** — AC-1's verdict record schema lands here or in
  INVARIANTS prose (design decides the schema home, per DC-1).
- **ARCHITECTURE.md** — no new section (follow the anti-duplication precedent, ROADMAP "Not Doing":
  authority stays in the rubric/canon files + INVARIANTS + tests, not a prose duplicate).
- **PRODUCT.md** — a new capability row ("design-taste learning loop") is a candidate at ship of
  Slice-2, not at shape.
