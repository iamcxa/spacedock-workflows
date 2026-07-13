# Fixture-tree exclusion for discovery helpers — Design

This is the cycle-3 non-UI contract/interface design re-entry after verify
VETO. The Science Officer judged `route=return`, `confidence=high`: the narrow
sourceable pruning primitive remains sound, but every caller must distinguish a
healthy empty traversal from a traversal error before accepting routing or a
density value. D1-D3 preserve the delegated narrow design; D4 records the
delegated fail-loud engineering contract. Exactly one authorization decision
was Captain-owned; the Captain selected AUTH-1 Option A, so the design gate may
proceed under the exact one-run and `costly_no` boundary below.

```yaml
design-dispatch-manifest:
  lanes:
    - lane: contract-interface
      role: contract/interface-designer
      trigger: verify_veto_return
      decisions: [D1, D2, D3, D4]
      required_skills:
        - ship-flow:ship-design
        - superpowers:brainstorming
      outputs:
        - docs/ship-flow/fixture-pollution-discovery-helpers/design.md
        - docs/ship-flow/fixture-pollution-discovery-helpers/index.md
  integration:
    mode: single-designer
    owner: ship-design
  registry_context:
    classified_domain: schema
    validation: ok
    applied_route: contract-interface-only
    rationale: No data-model surface changes; this is a Bash discovery contract.
  visual_verification:
    status: not-applicable-non-ui
```

## Canonical Context

| Doc | Sections Read | Update Intent | Skip Rationale |
| --- | --- | --- | --- |
| `PRODUCT.md` | `Current Capabilities` | skip | This repairs an existing internal capability and adds no durable product promise (`PRODUCT.md:7-18`). |
| `ARCHITECTURE.md` | `containers`, `components`, `constraints`, `dependencies` | skip | The primitive and caller-side capture stay inside the documented `lib/` Bash 3.2 boundary (`ARCHITECTURE.md:30-50`, `ARCHITECTURE.md:54-109`). |

The already-landed `docs/ship-flow/README.md` guard and tracker `#24` remain the
only documentation delta. Absolute linked-worktree dispatch duplication stays
known evidence under `#21`. This cycle does not file, implement, or widen either
issue and does not change PRODUCT, ARCHITECTURE, ROADMAP, status, receipts, or
worktree state.

## Canonical Problem and Verify Return

The shape outcome still requires a real repository-root run with zero
fixture-derived routing and no helper error (`shape.md:48-53`). Verify proved
that the frozen cycle-2 run cannot establish the second half: adopter discovery
suppresses `find` diagnostics at `discover-adopter-skills.sh:64-77` and consumes
nonzero traversal status as an ordinary false route predicate. Density has the
same class of ambiguity: S1 loses the process-substitution producer status at
`density-classify.sh:141-146`; S2 and both S3 branches suppress/fallback a
failed producer into a healthy zero count at `density-classify.sh:152-168`.

The Captain's Bet remains verbatim and is not weakened:

> ship-flow helpers 不再有不正確的運作問題，如果處理完仍有問題則表示用 helper 這條路可能策略不對
>
> 修完後第一次真實執行且零錯誤 routing

The Science Officer's delegated technical judgment is to retain the helper,
make traversal failure observable end to end, and close the invariant/test gaps
before any further real-run authorization. The Captain has now resolved the
risk-authorization choice by selecting AUTH-1 Option A.

## Current Repository-wide Candidate Audit

Cycle-3 static re-entry baseline: branch head `b7f7078`. The cycle-2 one-time
audit remains the deliverable; it is not replaced by a detector or inventory.
Static source reading confirms the complete qualifying set remains exactly the
two consumers below and identifies their current error-observability seams.

| Surface | Actual reach and current seam | Decision |
| --- | --- | --- |
| `lib/discover-adopter-skills.sh:49-77` | Recursively inspects the requested root. Every route probe funnels through `find_pruned`, whose `2>/dev/null` plus boolean call sites collapse error into no match. | Qualifying consumer; retain shared pruning and add explicit match/no-match/error handling. |
| `lib/density-classify.sh:123-169` | Four traversals feed S1, S2, archive, and done. Process substitution or `pipeline || echo 0` hides producer failure. | Qualifying consumer; capture and validate each traversal before deriving a signal or classification. |
| `lib/issues-to-contract.sh:79-96` | Python globbing is fixed to active entities and `_archive` at depth zero/one beneath the requested workflow directory. | Bounded dedup scan; does not consume the helper. |
| `bin/sync-drift-check.mjs:25-44,346,389` | `readdir` lists immediate files only in exact plugin/adopter `_mods` and script directories. | Shallow manifest comparison; does not consume the helper. |
| `bin/ship-flow-lint.mjs:67-83` | Recurses only inside the explicitly selected workflow directory to lint Markdown. | Bounded validator; does not consume the helper. |
| `bin/stale-worktree-cleanup-planner.sh:303-314` | Finds `index.md` at exact depth two inside the selected workflow directory. | Bounded entity scan; does not consume the helper. |
| `bin/debrief-boundary-resolver.sh:88-103` | Finds `index.md` at exact depth two inside the selected workflow directory. | Bounded entity matcher; does not consume the helper. |
| `lib/query-entity-history.sh:230-233` | Finds archived `index.md` at exact depth two in the selected archive directory. | Bounded history query; does not consume the helper. |
| `bin/check-invariants.sh:108-129,290-304,1703-1716` | Recursively validates plugin skill sources; fixture mode deliberately scans the supplied fixture root. | Invariant/explicit-fixture behavior; pruning would change its contract. |
| `bin/ship-capture.sh:9-11` | `grep -r` receives shell-expanded README file arguments, not a repository directory. | Syntactic false positive. |
| `lib/rebase-resolve-additive.sh:48` | `git ls-files -u` reads unmerged index entries only. | Syntactic false positive. |

## Design Output

### Captain Decisions

**D1|Captain decision**: Under the Captain's explicit delegation to the Science
Officer, preserve C1-A: one namespaced, sourceable Bash-only helper at
`plugins/ship-flow/lib/discovery-exclusions.sh`, exposing
`ship_flow_discovery_find <requested-root> <find-expression...>`. Do not add an
executable mode, config loader, non-shell adapter, or generic discovery
framework. The verify return does not invalidate this primitive.

**D2|Captain decision**: Under the same delegation, preserve C2-A: prune only
descendant directory segments named `__tests__` or `test-fixtures`, evaluated
relative to the requested root. Never reject the requested root because of its
own name or an ancestor marker. Do not generically exclude `fixtures`, `test`,
or `tests`, and do not derive policy from `.gitignore`.

**D3|Captain decision**: Under the same delegation, preserve constrained C3-A
and close DC-4 narrowly. The one-time audit and two direct-consumer assertions
remain sufficient. The marker single-definition invariant must inspect only
top-level production `plugins/ship-flow/lib/*.sh` and
`plugins/ship-flow/bin/*.sh`, excluding nested tests/fixtures, and require both
marker definitions to occur exactly once in `discovery-exclusions.sh`. Do not
add a permanent walker detector or checked-in classification inventory.

**D4|Captain decision**: Under the Captain's delegated technical-design
authority, add caller-side bounded capture as the fail-loud contract. The shared
primitive returns raw `find` status and leaves diagnostics visible. Each caller
captures traversal data to a temporary file, checks producer status before
reading that data, normalizes any traversal failure to operational exit 2 with
a contextual stderr diagnostic, and publishes no route envelope or density
classification unless every required traversal succeeded. Healthy empty data
remains distinct from error. Do not use process-substitution producer status,
`pipeline || echo 0`, `grep -q` pipeline status, or a data-stream sentinel.

### Alternatives Considered

| Approach | Trade-off | Judgment |
| --- | --- | --- |
| Caller-local bounded capture, explicit status check, then consume the file | Small Bash 3.2-compatible change; preserves raw diagnostics/status and avoids partial data acceptance. | **Selected by D4.** |
| Recover pipeline/process-substitution status through `PIPESTATUS` or side channels | Brittle across the existing process substitutions, command substitutions, and early-closing `grep -q`; easy to conflate SIGPIPE/no-match/error. | Rejected. |
| Expand the shared helper into an executable, generic capture protocol, or inventory service | Centralizes more mechanics but violates D1/YAGNI and adds an interface no current non-shell consumer needs. | Rejected. |

### Shared Primitive and Capture Boundary

`ship_flow_discovery_find` continues to own only root-relative marker pruning,
safe path quoting, and forwarding of the caller's `find` expression. It must
remain Bash 3.2-compatible and preserve raw `find` stdout, stderr, and status.
It does not decide whether output means a route, count, or density signal.

Each top-level consumer creates one bounded scratch directory with `mktemp -d`,
registers cleanup for normal and signal exits, and uses files inside it for
sequential traversal capture. A capture attempt truncates its target first,
runs the shared primitive with stdout redirected only to that file, and checks
the command status directly. Stderr is not sent to `/dev/null`; on failure the
caller also emits a stable context line naming the consumer and traversal plus
the raw exit code. Partial capture data is discarded and never interpreted.
Scratch creation failure is itself operational exit 2 with a diagnostic.

### Adopter Discovery Contract

The three local probe families (`has_path`, `has_file_name`, and
`has_dependency`) use one tri-state contract:

| Probe result | Meaning | Caller action |
| --- | --- | --- |
| 0 | traversal succeeded and capture is non-empty | predicate matched |
| 1 | traversal succeeded and capture is empty | healthy no match; the next OR alternative may run |
| 2 | traversal or capture setup failed | abort the script immediately; do not evaluate later alternatives |

Route predicates must inspect this status explicitly rather than placing the
probe directly in a boolean `if A || B` chain. Header and route text are built
in a scratch output file and copied to stdout only after all route probes finish
without error. Top-level exit 0 therefore means a complete YAML envelope, while
exit 2 means operational failure, non-empty stderr, and no accepted envelope.
Existing argument/root validation remains exit 2.

### Density Value/Error Contract

Every one of the four density traversals has an explicit value/error boundary:

1. S1 captures NUL-delimited `CLAUDE.md` paths, verifies traversal success, and
   only then feeds the file to the existing Bash 3.2 `read -d ''` loop. No
   process substitution remains.
2. S2 captures matching `SKILL.md` paths, verifies success, then computes the
   count from the capture file. No producer pipeline determines success.
3. S3 archive and S3 done each capture and count independently. Neither branch
   may fallback to zero when its walk fails.

Primary density mode prints exactly one of `high|medium|low|vacuum` and exits 0
only after every applicable traversal succeeds. `--is-high` retains 0=high and
1=healthy not-high. Both modes reserve exit 2 for usage, setup, or traversal
error; on exit 2 stderr is non-empty and stdout contains no classification.

### Captain Authorization Resolution

The Captain selected `AUTH-1` Option A:

| Option | Semantics | Consequence |
| --- | --- | --- |
| A — authorize one revised first run (**selected; EM recommendation**) | Treat the old receipt as acceptance-invalid for incomplete code. Only after materially revised implementation passes every focused fail-loud check, permit exactly one new real repository-root adopter-discovery run. | Any route, diagnostic, or nonzero status goes directly to strategy-level `costly_no`; there is no additional patch or run. |
| B — Bet consumed; abandon/reconsider | Treat the old run as consuming the Bet despite its observability gap. | Do not implement or execute another discovery attempt; reconsider the helper strategy at strategy level. |

Option B was not selected. The authorization does not permit a discovery run
during design or plan: execute may consume it only after the materially revised
implementation passes every focused fail-loud check. The authorization is then
consumed by that one run regardless of result.

## Verification Strategy

Implementation begins with focused fixtures only; no test needs repo-root
discovery.

1. Preserve the existing adopter clean/decoy twin and marker-ancestor positive
   cases, including exact successful YAML, exit 0, and empty stderr.
2. Preserve density clean/decoy parity and marker-ancestor positive behavior.
   Split the S3 regression so an archive-only decoy and a done-only decoy each
   independently fail RED before pruning and remain `vacuum` GREEN. A combined
   arrangement is insufficient evidence for either branch.
3. Inject traversal failure with a focused fixture root and a controlled fake
   `find` placed first on `PATH`. The fake delegates to the real `find` except
   when its first root argument equals a test-selected fixture subtree; that
   branch prints a deterministic diagnostic and exits nonzero. No fixture
   derives or discovers the repository root.
4. Adopter failure injection targets its focused fixture root and proves exact
   top-level exit 2, non-empty stderr containing both injected and adopter
   context, and empty stdout/no YAML envelope. This pins the shared tri-state
   path used by all three probe families.
5. Density failure injection targets S1, S2, S3 archive, and S3 done roots in
   separate parameterized cases. Every case proves exact exit 2, non-empty
   contextual stderr, and empty stdout/no classification. At least one case
   also runs `--is-high` to prove traversal error is not misreported as normal
   not-high exit 1.
6. Extend the named invariant fixture with a duplicate marker definition in a
   top-level `bin/*.sh` script and require failure, while the existing
   top-level `lib/*.sh` duplicate also fails and nested fixture copies remain
   excluded from the production count.
7. Run Bash 3.2 syntax, focused adopter, focused density, invariant fixture,
   and named/full invariant checks. Successful positive paths retain exit 0,
   intended stdout, and empty stderr.

The Captain selected AUTH-1 Option A. Only after materially revised
implementation passes every focused fail-loud check may execute perform exactly
one new real repository-root adopter-discovery run. Any route, diagnostic, or
nonzero status routes directly to strategy-level `costly_no`, with no additional
patch or run.

## Frozen Receipt Audit

The cycle-2 receipt is immutable and consumed:

- result: rc 0; routes 0; stdout 193 bytes; stderr 0 bytes;
- stdout SHA-256:
  `b038878f44c05b0e836f1e2c608cda76ab7f3d3890d16c13e7912acff55baa53`;
- stderr SHA-256:
  `e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855`.

It proves only that static envelope. Because the executed caller could suppress
a failed traversal into the same header-only result, it remains
acceptance-invalid. This design cycle and its reviewer may read source and the
frozen record but must not rerun, reconstruct, or emulate repository-root
discovery. AUTH-1 Option A authorizes only one future run of the materially
revised implementation after every focused fail-loud check passes.

### Artifact Bundle Manifest

| Path | Type | Purpose |
| --- | --- | --- |
| `docs/ship-flow/fixture-pollution-discovery-helpers/design.md` | non-UI contract design | D1-D4, fail-loud contracts, focused verification, frozen-receipt audit, and resolved Captain authorization. |
| `docs/ship-flow/fixture-pollution-discovery-helpers/index.md` | design stage report | Cycle-3 completion inventory and PROCEED hand-off without status mutation. |

## Reverse Audit of Prior Stages

- Shape C1 remains resolved by D1 and C2 by D2.
- Shape C3 remains resolved by D3; cycle 3 makes the previously implicit
  production boundary exact: top-level `lib/*.sh` plus `bin/*.sh` only.
- Verify DC-7 is resolved at the design-contract level by D4's observable
  match/no-match/error and value/error contracts; AUTH-1 Option A authorizes one
  post-focused-GREEN acceptance run.
- Verify DC-4 routes to execute through D3's corrected invariant scope.
- The density advisory routes to execute through independent archive and done
  regressions.
- `open_design_questions` remains empty. AUTH-1 was a risk-authorization
  decision caused by the invalid receipt and is now resolved as Option A.
- No UI lane, theme indirection, or render-fidelity target applies.

## Design Readiness Review

```yaml
risk_triggers: []
reviewers: []
derived_from:
  - affects_ui:false
  - single-contract-interface-lane
  - internal-bash-discovery-contract
verdict: PASS
findings:
  - reviewer: routing-preflight
    severity: PASS
    route_to: plan
    evidence: D1-D4 remain internal Bash mechanics with no data-model, public-interface, storage-schema, UI, or multi-domain change.
```

Design Readiness Review: skipped - no risk trigger. The separate fresh
seven-factor non-UI cross-review remains mandatory.

## Adversarial Cross-Review

A fresh context-free reviewer received the design, shape/verify authority, and
static source paths under a read-only, no-tests, no-discovery contract. It
returned no design defect and the following evidence:

| Non-UI factor | Result | Evidence |
| --- | --- | --- |
| Feasibility | PASS | Bash 3.2 caller capture preserves raw status/diagnostics and rejects partial data (`design.md:118-150`), directly addressing adopter and all four density seams. |
| Executable scope | PASS | One sourceable primitive, exactly two consumers, and narrow invariant/test changes are bounded (`design.md:97-126`, `design.md:343-392`). |
| Quality | PASS | Adopter and density each have exact successful, healthy-negative, and operational-error conventions with no output on error (`design.md:152-185`). |
| DC adequacy | PASS | D4 closes verify DC-7; D3 closes DC-4; archive and done regress independently (`verify.md:31-33,112-119`; `design.md:110-126,205-228`). |
| Canonical sync | PASS | PRODUCT/ARCHITECTURE skips match an internal Bash caller-contract repair (`design.md:36-47`; `ARCHITECTURE.md:54-109`). |
| Reverse-audit previous stage | PASS | Shape C1-C3 and every verify-return item map to D1-D4 or execute evidence (`design.md:260-273`; `shape.md:48-53`). |
| Constraint Coverage | PASS | All traversal paths, exact rc/diagnostics, lib+bin scope, independent branches, and receipt immutability are pinned; AUTH-1 was the sole open decision (`design.md:104-126,172-251,346-389`). |

Original verdict: **PROMPT_CAPTAIN**.

The Captain selected AUTH-1 Option A without changing D1-D4. Because all seven
technical factors passed and `open_decisions` is now empty, the resolved design
gate verdict is **PROCEED**.

Coaching note: consume the one-run authorization only after every focused
fail-loud check passes, and route any real-run failure directly to `costly_no`.

## Design Report

- status: passed
- stage_cost: one Codex design worker plus one fresh read-only reviewer
- iterations: 3 (cycle-2 narrow revision plus verify-return cycle)
- contradictions_resolved: 4 technical decisions resolved
- captain_decisions: 4 delegated technical decisions; AUTH-1 Option A resolved
- reviewer_verdict: PROCEED
- Design Readiness Review: skipped - no risk trigger

The installed `design-flow` delegate was unavailable, so this re-entry used the
documented `superpowers:brainstorming` fallback. D4 materially revises the
caller contract without expanding the pruning primitive or introducing a new
framework.

### Metrics

- status: passed
- duration_minutes: 30
- iteration_count: 3
- captain_decisions_count: 4
- open_decisions_count: 0
- reviewer_verdict: PROCEED

<!-- section:hand-off-to-plan -->
### Hand-off to Plan

```yaml
design-skipped: false
design_constraints:
  - type: contract
    assertion: Preserve exactly one Bash 3.2-compatible namespaced sourceable pruning helper at plugins/ship-flow/lib/discovery-exclusions.sh; do not add executable, declarative-loader, non-shell, or generic capture modes.
    rationale_decision: D1
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: filter-contract
    assertion: Prune only descendant directory segments named __tests__ or test-fixtures relative to the requested root; never reject the root because of its own name or ancestors, and do not exclude fixtures, test, or tests generically.
    rationale_decision: D2
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Both discover-adopter-skills.sh and all four density-classify.sh traversals use the shared primitive while retaining consumer-specific expressions and behavior.
    rationale_decision: D3
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: The marker single-definition invariant scans only top-level production plugins/ship-flow/lib/*.sh and plugins/ship-flow/bin/*.sh, rejects duplicates in either directory, excludes nested tests and fixtures, and adds no permanent walker detector or inventory.
    rationale_decision: D3
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Adopter discovery uses bounded temporary capture and explicit 0=match, 1=healthy-no-match, 2=error probes; any traversal failure emits diagnostics, exits 2, aborts remaining route predicates, and publishes no YAML envelope.
    rationale_decision: D4
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Density captures and validates S1, S2, S3 archive, and S3 done producers before consuming values; primary mode emits a class only on exit 0, --is-high keeps 1 for healthy not-high, and every traversal error emits diagnostics with exit 2 and no classification.
    rationale_decision: D4
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: filter-contract
    assertion: Focused tests preserve positive no-match, clean-decoy, and marker-ancestor behavior; archive-only and done-only density decoys regress independently.
    rationale_decision: D2
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Controlled fake-find PATH injection on focused fixture roots proves adopter and each density traversal fail visibly with exact exit 2, non-empty contextual stderr, and no accepted output; no test discovers or runs against the repository root.
    rationale_decision: D4
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - type: contract
    assertion: Preserve the existing docs/ship-flow/README.md workflow-dir guard and local tracker #24; keep dispatch duplication as issue #21 evidence only.
    rationale_decision: D3
    source_artifact: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
open_decisions: []
resolved_decisions:
  - id: AUTH-1
    owner: Captain
    selection: authorize_one_revised_run_then_costly_no_on_failure
    receipt_status: prior_receipt_acceptance_invalid
    precondition: materially revised implementation passes every focused fail-loud check
    authorized_action: exactly one new real repository-root adopter-discovery run
    failure_route: any route, diagnostic, or nonzero status routes directly to strategy-level costly_no
    retry_policy: no additional patch or run
artifact_paths:
  - path: docs/ship-flow/fixture-pollution-discovery-helpers/design.md
  - path: docs/ship-flow/fixture-pollution-discovery-helpers/index.md
```
<!-- /section:hand-off-to-plan -->

## Stage Report: design (cycle 3)

- DONE: Preserve D1-D3 and add D4's Bash 3.2-safe bounded-capture contract so
  adopter probes expose match/no-match/error and density exposes value/error;
  traversal failure is diagnostic, exit 2, and never accepted as YAML or a
  classification.
- DONE: Resolve verify's DC-4 and density-test hand-off gaps by spanning only
  top-level production `lib/*.sh` plus `bin/*.sh`, testing archive and done
  decoys independently, and injecting fake-`find` failures against focused
  fixture roots for adopter and all density traversal labels.
- DONE: Preserve the consumed frozen receipt as immutable envelope-only and
  acceptance-invalid, prohibit design/reviewer discovery execution, and record
  the Captain's AUTH-1 Option A selection: exactly one revised run after every
  focused fail-loud check passes, then direct `costly_no` on any route,
  diagnostic, or nonzero status with no additional patch or run.
- DONE: Handoff schema, D-reference, and readiness validators passed; the fresh
  context-free non-UI reviewer passed all seven factors and returned
  PROMPT_CAPTAIN while AUTH-1 was open; the Captain's Option A selection resolves
  the design gate to PROCEED without changing D1-D4.

### Summary

The revised design keeps the narrow pruning primitive and closes the silent
traversal-failure seams with caller-side capture and explicit exit contracts.
Technical design and AUTH-1 authorization are complete; the gate may proceed.
