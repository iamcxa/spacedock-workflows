# Self-adoption dogfood bootstrap — canonical docs + doc-impact gate — Design

Lane: **Contract Interface Designer** (`domain: schema`, `contract_decision_required: true`,
`affects_ui: false` → non-UI-lane, FO-gated). This design resolves the four
`open_contract_decisions[]` from the entity's `### Hand-off to Design` and names the
contract deltas + the test surfaces that pin them, for all three children of pitch 1.

## Sharp Output → Problem

Exploration source: entity `index.md` (§Problem, §Acceptance criteria AC-1..AC-4) and
[shape.md](shape.md). The repo skips its own doc-currency machinery: Principle 5b WARN-skips
(no root ARCHITECTURE/PRODUCT/ROADMAP), and prose currency relies on manual audits (PR #6
caught a stale `0.7.0 / spacedock 0.22.0` claim). AC-2 is the wedge: a **code gate**, not a
prose rule, that fails a plugin-touching PR which ignores a coupled doc and carries no
declaration. Pre-mortem to defend against (`wrong-dcs`): the declaration becomes a
rubber-stamp default — boilerplate `none` reasons on every PR while prose keeps drifting.

## Reverse-recovery finding (before designing anything new)

A source→doc coupling map **already exists**: `references/doc-sync-context.md` §Source Map,
with two sub-tables — *Skills → Doc Targets* and *Shell Primitives and Checks → Doc Targets*.
Classification for the mechanical-gate use case: **EXISTS_BROKEN**, not MISSING. Right concept,
wrong shape:

- markdown prose with parenthetical annotations (`` `README.md` (skill triggers…) ``) — not
  robustly machine-parseable;
- exact-file-keyed, not glob-keyed;
- consumed by the LLM-driven `ship-flow:doc-sync` skill at **release time**, not per-PR;
- **coarse** — nearly every source maps to `README.md`/`INVARIANTS.md`, so a mechanical gate
  built on it would fire on almost every plugin PR → the pre-mortem rubber-stamp, realized.

Two reusable zero-dep shell primitives also already exist and are test-covered:

- `lib/resolve-skill-routing.sh:64-82` `glob_to_regex` — glob (`**`, `*`, `{a,b}`) → anchored regex.
- `bin/canonical-doc-sync-checker.sh:114-133` `is_weak_skip_rationale` — ≥12-char rationale bar,
  rejects `none|n/a|tbd|todo|skip|…`. This is the declaration reason-quality precedent named in
  the Hand-off.

So this design **recovers and re-shapes** rather than greenfields: a tight machine-readable
coupling subset that reuses the existing primitives and cross-references (does not duplicate)
the existing prose map.

## Design Output → Contract Decisions

### D1 | Coupling-config format and location

| Option | Trade-off |
|---|---|
| **A. Parse `doc-sync-context.md` §Source Map directly** | Single source of truth, zero new file. BUT coarse coupling → gate fires on nearly every PR → declaration rubber-stamp (pre-mortem realized); prose-with-parentheticals not robustly parseable; conflates release-time LLM refresh with per-PR mechanical requirement. |
| **B. New machine-readable YAML `references/doc-coupling-map.yaml` (tight subset) + adopter override `.claude/ship-flow/doc-coupling.yaml`** | Tight high-signal set avoids rubber-stamp; glob-based (reuses `glob_to_regex`); adopter override mirrors the `resolve-skill-routing.sh` `.claude/ship-flow/*.yaml` precedent. BUT one new file + a drift risk vs. `doc-sync-context.md` (mitigated by an explicit cross-ref header). |

**Decision D1 → B (no silent pick; A explicitly rejected because its coarseness is the
pre-mortem failure mode).** Relationship pinned to prevent dual-source-of-truth drift:
`doc-sync-context.md` stays the **exhaustive release-time LLM map**; `doc-coupling-map.yaml`
is a **tight mechanical per-PR gate subset** of it. Schema (deliberately flat — see D4):

```yaml
# doc-coupling-map.yaml — see references/doc-sync-context.md §Source Map for the
# exhaustive release-time map; this file is the tight per-PR mechanical subset.
schema_version: "1.0"
couplings:
  - name: <slug>
    srcGlobs: [ "plugins/ship-flow/skills/ship-*/SKILL.md" ]
    docPaths: [ "plugins/ship-flow/README.md" ]
    rationale: "<why staleness here bites; ≥12 chars>"
```

Resolution order (mirrors skill-routing): adopter `.claude/ship-flow/doc-coupling.yaml` if
present, else plugin default `references/doc-coupling-map.yaml`.

**Tightness is a design constraint, not a suggestion** (pre-mortem guard): the initial curated
set stays small (2-3 couplings where staleness has actually bitten and is NOT already gated
elsewhere). Illustrative starters for plan/execute to finalize — NOT the frozen set:
`ship-*/SKILL.md → plugins/ship-flow/README.md` (pipeline/stage prose); `references/*.yaml →
plugins/ship-flow/README.md`; `bin/*.sh → references/doc-sync-context.md` (a new checker must
register its Source-Map row). Explicitly out: version-claim couplings — already gated by
`scripts/check-version-triple.sh`; adding them here would duplicate an existing gate.

### D2 | Declaration grammar and placement

Grammar: **`doc-impact: none — <reason>`**. Reason quality: **reuse `is_weak_skip_rationale`**
(≥12 chars; rejects `none|n/a|tbd|todo|skip|…`; accepts `—|--|:|-` separators per its existing
regex). No new grammar invented.

| Placement | Trade-off |
|---|---|
| **A. PR body**, extracted by CI and passed to the checker as input | Declaration semantically belongs to the PR (a transient escape hatch, not a permanent repo fact); no repo clutter. BUT CI must read `github.event.pull_request.body` — a NEW CI capability (grep found zero existing PR-body reads); body is mutable/invisible to a `git`-only offline run. |
| **B. Commit-message trailer** in the PR range | git-native, offline-diffable, testable from `git log`. BUT awkward to amend mid-review; multi-commit PRs need a range scan. |
| **C. Repo file marker** | fully diffable/reviewable. BUT a permanent artifact for a transient decision → clutter + stale-marker risk; contradicts escape-hatch semantics. |

**Decision D2 → A (PR body), with the checker accepting the declaration text as an explicit
input (`--declaration=<text>` / env / stdin), NOT fetching it itself.** This is the seam that
keeps the checker **offline-testable** — fixtures pass declaration strings directly — while CI
supplies `${{ github.event.pull_request.body }}`. The mutability/offline weakness of (A) is
bounded to the CI-extraction line; the checker's logic stays pure. This split is also the
**R3-honoring boundary**: the checker does mechanical *presence + grammar + ≥12-char length*
ONLY. Whether a `none` reason is *legitimate* is a semantic judgment — never in required CI;
it routes to advisory (PR review + ship-review canonical-doc route-back).

Actionable failure message (satisfies AC-2 "naming the missing doc or declaration"):
`BLOCKER doc-impact: <coupling-name> — changed <srcGlob> but coupled doc <docPath> not touched
and no 'doc-impact: none — <reason>' declaration found`.

### D3 | Size-threshold semantics

| Option | Trade-off |
|---|---|
| **A. Path-class, coupling-glob-driven (no numeric threshold)** | Deterministic; the coupling `srcGlobs` ARE the configurable trigger surface (tightness lives in D1's map). No arbitrary LOC tuning, no new CI variable. BUT no "trivially small" bypass — any matching change needs doc-touch-or-declaration. |
| **B. Diff-LOC threshold (>N added lines)** | Lets tiny fixes through. BUT LOC is a poor doc-impact proxy — the motivating PR #6 stale-version bite was a *small* diff, so a size floor would have let exactly the target failure through; tuning N is bikeshed; needs a NEW CI size computation. |
| **C. File-count threshold** | Same weakness as B. |

**Decision D3 → A (path-class). B and C explicitly rejected: the motivating failure was a small
diff, so a size floor defeats the gate's purpose.** "Plugin-touching" is defined precisely:
a changed path matches some coupling `srcGlob` AND is not itself the coupled `docPath`. AC-2's
"configured threshold" language is satisfied by the coupling map being the configurable surface
— not a LOC number. The gate consumes the CI's **existing** `CHANGED` list + `plugin_changed`
output; **no new `ship_flow_scope` size variable is added** (reject the size-var so the pre-mortem
"boilerplate on every PR" pressure is minimized to only genuinely-coupled changes).

### D4 | Checker family

| Family | Trade-off |
|---|---|
| **Shell** (`bin/doc-impact-gate.sh` + `lib/__tests__/test-doc-impact-gate.sh`) | Direct sibling of `canonical-doc-sync-checker.sh` — same `emit_pass/emit_blocker` vocabulary, read-only contract, and rationale-quality function. Reuses `glob_to_regex` + `is_weak_skip_rationale`. Test **auto-collects** into the CI `for t in …/test-*.sh` full-suite loop → zero new test-wiring. BUT bash YAML parsing is hand-rolled. |
| **Node** (`bin/doc-impact-gate.mjs` + `*.test.mjs`) | Cleaner control flow; test already globbed by `node --test bin/*.test.mjs`. BUT no built-in YAML (hand-rolled anyway, or a dep → Principle 12 Hermetic friction); forks the checker family away from its closest sibling for no offsetting gain on a deliberately-flat schema. |

**Decision D4 → Shell.** The D1 schema is intentionally flat (string-list `srcGlobs`/`docPaths`),
which sits inside the proven envelope of `resolve-skill-routing.sh`'s line-based YAML parser —
so bash's parsing weakness does not bite, and Node's parsing advantage does not apply. Shell
also reuses two existing zero-dep primitives instead of reimplementing them.

**Primitive-reuse sub-decision (DRY vs. blast radius):** `glob_to_regex` and
`is_weak_skip_rationale` currently live *inside* executable scripts, not sourceable libs.

- **Extract** each into a small sourceable lib (`lib/glob-match.sh`, `lib/doc-rationale.sh`)
  sourced by all consumers. DRY; a second live consumer is the canonical DRY trigger. BUT
  widens the diff to `resolve-skill-routing.sh` + `canonical-doc-sync-checker.sh` and their
  tests must stay green.
- **Copy** the ~12-line functions into `doc-impact-gate.sh` with `# contract-mirror:` pointer
  comments. Narrower diff. BUT reintroduces mirror-drift risk (needs a mirror-assertion test to
  buy back the safety extraction gives for free).

**Recommend extract** (a second live consumer is the DRY trigger, and both functions are already
test-covered so extraction is low-risk) — but this is the one decision where plan may legitimately
pick copy-with-pointer if small-batch appetite argues for the narrower diff. Named here so plan
does not pick silently; the test-surface consequence (existing tests of both source scripts must
stay green under extraction) is called out below.

## Design Output → Contract Deltas & Test Surfaces

Child 1.2 (doc-impact-gate) — the bulk of the contract surface:

| Delta | Kind | Test surface that pins it |
|---|---|---|
| `references/doc-coupling-map.yaml` | NEW schema file | NEW `test-doc-impact-gate.sh` (schema-parse + glob-match fixtures); model on `test-canonical-doc-actions-schema.sh` + `assert-canonical-doc-actions-schema.rb` |
| `bin/doc-impact-gate.sh` | NEW checker | NEW `test-doc-impact-gate.sh` — auto-collected by CI `test-*.sh` loop; assert: coupled-doc-touched → pass, declaration-present → pass, weak-reason → fail, coupled-doc-untouched+no-declaration → fail(exit 1), read-only (fixture hash unchanged, per `test-canonical-doc-sync-checker.sh` `assert_read_only`) |
| New CI step in `.github/workflows/ship-flow-invariants.yml` (gated `if: plugin_changed == 'true'`, passes `CHANGED` + `${{ github.event.pull_request.body }}`) | NEW CI wiring | `test-ship-flow-ci-scope.sh` — ADD a grep assertion for the `doc-impact-gate` step (existing assertions are presence-checks, so no existing assertion breaks) |
| Source-Map row in `references/doc-sync-context.md` (Shell-Primitives sub-table) for the new checker | doc delta | `check-no-dangling.sh` (paths resolve); no dedicated coverage test today |
| (if extract chosen) `lib/glob-match.sh`, `lib/doc-rationale.sh` + `source` lines in `resolve-skill-routing.sh` & `canonical-doc-sync-checker.sh` | refactor | existing `test-adopter-skill-discovery.sh`, `test-canonical-doc-sync-checker.sh` must stay green |

Child 1.1 (canonical docs bootstrap) — data the **existing** checker consumes; no checker code delta:

- `ARCHITECTURE.md` must carry the six `flow-map-schema.yaml` section tags
  (`context/containers/components/constraints/dependencies/decisions`), with a ```` ```mermaid ````
  block in context/containers/components. `PRODUCT.md` (`capabilities` tag), `ROADMAP.md`
  (`now/next/later/not-doing/shipped` tags).
- Pinned by: `check-invariants.sh` `check_flow_map_coverage` (Principle 5b, lines 197-240 —
  hardcoded to ARCHITECTURE.md + 6 sections per its own NOTE at :200-201) and DC-9;
  `test-check-invariants*.sh`, `test-c4-schema-linkage.sh`. AC-1 verifies zero `WARN [Principle 5b]`
  lines. **No checker edit needed** — creating the docs flips the WARN-skip to a real check.

Child 1.3 (harvest vocabulary record) — reference doc, no schema change:

- NEW `references/<harvest-vocabulary>.md` following the `pr-merge-paths.md` decision-record
  pattern, mapping `debrief-guardrail-harvest`'s 6 buckets ↔ `harvest-decide`'s 4 outcomes ↔
  kc-forge D1/D2 layers; linked from the plugin README further-reading list (AC-4).
- Pinned by: `check-no-dangling.sh` (the README link resolves); AC-4 checks file-exists + README link.

## Design Output → DAG rationale

`1.1 → 1.2` (`1.3` parallel), per shape.md. Ordering justification recovered: the
`doc-coupling-map.yaml` `docPaths` reference `ARCHITECTURE.md`/`PRODUCT.md`/`ROADMAP.md`, which
must exist first — otherwise the gate couples to nonexistent docs and `check-no-dangling.sh`
fails. 1.3 is an independent reference doc with no dependency on 1.1/1.2.

## Design Output → Constraints for Plan Stage

- **Coupling set stays tight** (pre-mortem guard). Every coupling row carries a ≥12-char
  `rationale` naming a real staleness bite; broad `**`-only srcGlobs are disallowed by review.
- **R3 boundary is load-bearing**: required CI runs the mechanical presence check ONLY. No LLM,
  no reason-legitimacy judgment in the gate. Semantic checks live in ship-review canonical-doc
  route-back + PR review (advisory). (Honors entity Q4 captain ruling + carlove R3 scar.)
- **Checker is read-only** — reject `--fix/--write` flags exactly as `canonical-doc-sync-checker.sh`
  does (lines 19-24).
- **Declaration text is an input, never fetched by the checker** — preserves offline testability.
- **No new CI size variable** in `ship_flow_scope`.
- **RED-first** (AC-2): `test-doc-impact-gate.sh` written before `doc-impact-gate.sh` passes.
- Plan must decide the D4 primitive-reuse sub-decision (extract vs. copy-with-pointer) explicitly
  and record the choice.

## Design Report

- **Lane**: Contract Interface Designer (non-UI-lane, FO-gated).
- **Contract decisions resolved**: 4/4 (D1 format+location → new tight YAML; D2 grammar+placement
  → PR-body input, reuse rationale bar; D3 threshold → path-class, no size var; D4 family → shell).
  All with trade-off tables; no silent picks; A-options for D1/D3 explicitly rejected against the
  pre-mortem.
- **Reverse-recovery**: coupling abstraction recovered from `doc-sync-context.md` (EXISTS_BROKEN,
  re-shaped as tight subset, not greenfield); two primitives recovered for reuse.
- **Enforcement**: every decision prefers a code gate (the checker) over prose; the R3
  mechanical-only boundary is recorded as a plan constraint.
- **Design Readiness Review**: `domain: schema` triggers the `schema` reviewer. This is a
  config/checker-schema change with **no** DB migration, destructive change, or public-API/ts-rest
  contract — risk is bounded. No reviewer panel was dispatched in this fast-path design; flagged
  for the design gate's cross-review the FO runs. No BLOCK-class open decision remains.
- **Open decisions carried to plan**: only the D4 primitive-reuse sub-decision (extract vs. copy),
  explicitly non-blocking.

### Metrics

- status: passed
- lane: contract-interface
- contract_decisions_resolved: 4
- open_decisions_blocking: 0
- reviewer_verdict: PROCEED

### Hand-off to Plan

- `design_constraints[]`: the seven "Constraints for Plan Stage" bullets above.
- `open_decisions[]`: [D4 primitive-reuse: extract (recommended) vs. copy-with-pointer] — non-blocking.
- Contract deltas + test surfaces: the tables above, keyed by child (1.1 / 1.2 / 1.3).
- DAG: 1.1 → 1.2; 1.3 parallel.

**Verdict: PROCEED.**
