# Make stage circuits attempt-scoped and recoverable — Design

affects_ui: false
domain: schema

```yaml
design-dispatch-manifest:
  lanes:
    - lane: domain
      role: domain-designer
      domain: schema
      panel_lane: domain-expert
      required_skills: []
      knowledge_module_path: plugins/ship-flow/references/domain-knowledge/schema.md
      designer_section_anchor: ship-design#schema-designer
      review_contract:
        worktree: /Users/kent/conductor/workspaces/spacedock-workflows/muscat/.worktrees/spacedock-ensign-attempt-scoped-stage-circuits
        base_head: 8d144d5..HEAD
        mode: read-only findings-only
      outputs:
        - attempt event schema and authority layers
        - plan/execute report projection fields
        - migration, recovery, and verification constraints
    - lane: contract-interface
      role: contract/interface-designer
      trigger: open_contract_decisions
      decisions: [CD-1, CD-2, CD-3, CD-4]
      required_skills:
        - ship-flow:ship-design
        - superpowers:brainstorming
      outputs:
        - completion compatibility decision
        - FO issuance and timing contract
        - append-only terminal and replay contract
        - bounded no-dispatch route-out contract
  integration:
    mode: parallel
    owner: ship-design
  visual_verification:
    fragment_level: []
    whole_page: []
registry:
  matched: schema
  validate_status: ok
ui_surfaces: []
```

## Canonical Context

| Doc | Sections Read | Update Intent | Rationale |
| --- | --- | --- | --- |
| `PRODUCT.md` | `Current Capabilities` | skip | Attempt recovery corrects an internal pipeline contract without adding a user-facing product capability (`PRODUCT.md:7-18`). |
| `ARCHITECTURE.md` | `context`, `containers`, `components`, `constraints`, `dependencies`, `decisions` | update at review | The design adds a workflow-control authority and tracked audit sidecar inside the existing stage-skill/lib/entity-state topology; the decision belongs in the existing decisions map (`ARCHITECTURE.md:8-109,119-127`). |

No repository-root `AGENTS.md` or `CLAUDE.md` exists in this worktree. The
session-level instructions supplied by the captain remain in force; fixture-only
guidance files are not applicable to the touched entity path.

## Contract Baseline

- Plan currently enforces an unconditional 20-minute total-stage breaker and
  requires a partial artifact after expiry (`ship-plan/SKILL.md:465-471`).
- Execute independently enforces a 30-minute total-stage breaker with the same
  partial-artifact rule (`ship-execute/SKILL.md:396-401`).
- Plan and execute reports expose cumulative `duration_minutes` and `partial`
  status but no attempt identity, start, budget, or terminal event
  (`entity-body-schema.yaml:715-740,810-832`).
- `fo_completion_begin` binds entity, stage, worker, ref, before-SHA, token, and
  exact completion receipt, while `fo_completion_checkpoint` rejects any extra
  receipt field (`fo-completion-lifecycle.sh:7-31`).
- `completion-v1` compares an exact seven-line lease and emits an exact
  seven-field receipt; `published` and `already-registered` remain the only
  dispositions (`completion-v1.sh:66-73,217-239`).
- #21's preserved branch records truthful 32-minute and 61-minute partial plan
  reports against an unchanged five-record technical ledger
  (`spacedock-ensign/shape-confirm-instance-awareness:docs/ship-flow/shape-confirm-instance-awareness.md:607-664`).

The design therefore wraps the completion seam; it does not add optional fields
to `completion-v1`, reinterpret historical `duration_minutes`, or let a worker
mint attempt or timing authority.

## Options and Trade-offs

| Decision | Option | Trade-off | Call |
| --- | --- | --- | --- |
| CD-1 compatibility | Add optional fields to `completion-v1` | Small diff, but violates its exact parser and turns missing fields into ambiguity. | Reject. |
| CD-1 compatibility | Replace callers with `completion-v2` | Strong typing, but requires all-stage migration and dual-reader rollout beyond the appetite. | Reject this batch. |
| CD-1 compatibility | Keep `completion-v1` byte-exact and add an `attempt-v1` lifecycle envelope whose terminal event hashes the exact receipt | Preserves fail-closed compatibility and scopes change to plan/execute; adds one bounded wrapper and sidecar. | **Select.** |
| CD-2 timing | Worker-issued ID and timestamps | Easy to report, but lets the measured actor reset or forge its budget. | Reject. |
| CD-2 timing | FO wall-clock arithmetic | Auditable, but wall time can jump and cannot be the breaker authority. | Reject as authority; retain only for audit. |
| CD-2 timing | FO-issued ID plus an OS-boot-bound monotonic clock, with wall timestamps as non-authoritative audit fields | Gives enforceable current-attempt time across same-boot FO restart; clock-epoch loss fails closed. | **Select.** |
| CD-3 history | Rewrite one aggregate report after every attempt | Compact, but not append-only and races stage-worker writes. | Reject. |
| CD-3 history | Keep only a Git-directory journal | Crash-recoverable on one worktree, but not durable audit history. | Reject alone. |
| CD-3 history | Common-Git-dir open-attempt WAL plus tracked append-only terminal ledger | Excludes sibling worktrees, preserves crash recovery, and provides portable audit history without rewriting reports. | **Select.** |
| CD-4 bound | Cumulative-duration breaker | Bounds cost, but recreates the livelock because old truthful duration permanently blocks a fresh attempt. | Reject as dispatch gate; retain as metric. |
| CD-4 bound | Attempt count only | Simple and directly prevents infinite dispatch; must be generation-scoped so feedback re-entry is not poisoned. | **Select.** |
| CD-4 bound | Count plus cumulative hard stop | Stronger cost cap, but adds policy tuning and can again block the one promised fresh continuation. | Defer. |

## Design Output

### Captain Decisions

**D1|Captain decision**: Under the captain's explicit delegation to the Science
Officer (EM), preserve `completion-v1` lease and receipt bytes unchanged. Add a
separate exact `stage-attempt-v1` outer receipt for plan and execute only. A
within-budget `passed` result carries the unchanged `completion-v1` receipt as
a separately delimited record and binds its SHA-256; non-passed attempts do not
publish stage completion. Neither parser accepts the other protocol or optional
fields. FO durably retains the exact returned byte bundle independently of its
hash until it is committed as terminal evidence. This resolves CD-1.

**D2|Captain decision**: Under the same delegated technical authority, only the
First Officer may issue `stage_run_id`, `attempt_id`, `attempt_started_at`,
`budget_seconds`, and monotonic elapsed observations. `attempt_id` is `sa1-`
plus 64 lowercase hex derived under the FO lease from the canonical entity,
stage, ref, per-attempt `attempt_before_oid`, ordinal, and lease token. Workers receive these values
read-only and query FO authority for elapsed snapshots. Wall timestamps are
audit fields; the breaker uses an OS-boot-bound monotonic clock. Same-boot FO
restart may resume the exact lease; missing boot identity or monotonic regression
terminalizes `interrupted` instead of reconstructing favorable time. This
resolves CD-2.

**D3|Captain decision**: Under the same delegated technical authority, use two
explicit authority phases. While an attempt is `open`, `suspended`, or
`returned`, an exact,
lock-protected WAL keyed under `git rev-parse --git-common-dir` by canonical
entity plus stage is current authority; `stage_run_id` is bound inside the WAL
but is deliberately absent from the exclusion key. Thus a second run for the
same entity and stage contends even when it proposes a different entry commit,
including from a sibling worktree, without becoming a scheduler. Terminal audit authority is one
append-only ledger resolved as `<folder>/attempt-history-v1.log` for folder
entities or `<flat-base>.attempt-history-v1.log` for flat entities. History
append uses a temporary index/tree plus ref CAS and reconciles only that path,
preserving unrelated dirty state. Identical replay is a no-op; a second or
conflicting terminal fails closed. Each returned receipt bundle is an exact
common-Git-dir sidecar while in flight and an exact tracked sidecar after
terminal CAS, so recovery never reconstructs bytes from a hash. This resolves CD-3.

**D4|Captain decision**: Under the same delegated technical authority, bind each
attempt circuit to the FO stage-entry commit OID (`stage_run_id`) and allow at
most one fresh continuation after a typed or legacy partial/interrupted result.
Initial attempts do not consume it; fresh continuation increments
`fresh_continuations_used` to one; resume/replay never increments it. Plan keeps
1,200 seconds and execute keeps 1,800 seconds, preserving strict
`elapsed > budget` expiry. A second fresh-continuation request appends one
idempotent `route-out` record with
`route=return` and `reason=attempt-count-exhausted`, then exits before completion
lease acquisition or worker dispatch. Cumulative duration remains monotonic and
auditable but never waives or replaces the per-attempt budgets. This resolves
CD-4.

### Authority and Data Flow

| Phase | Authority | Durable evidence | Forbidden behavior |
| --- | --- | --- | --- |
| Stage entry | FO Contract-1 commit | `stage_run_id` is the exact entry commit OID | Worker-selected generation or reuse of an older entry OID |
| Begin/resume | `fo-stage-attempt.sh` under a common-Git-dir key lock derived from canonical entity + stage only | Exact open/suspended/returned attempt WAL, including its bound `stage_run_id`, plus unchanged completion lease when eligible | Starting any run with a nonterminal same-entity/stage attempt, even under a different entry OID or sibling worktree; foreign lease; incrementing continuation count on resume/replay |
| Worker dispatch | FO-rendered envelope | `stage_run_id`, `attempt_id`, per-attempt before OID, start, budget, boot identity, elapsed query, lease hash | Worker mint/reset; raw token in tracked files |
| Worker return | Outer `stage-attempt-v1` receipt plus exact returned-bundle sidecar | Exact attempt/state/artifact/ref-before/ref-after binding; passed folder runs also return a separately delimited exact `completion-v1` receipt | Extra/reordered fields; cross-protocol parsing; over-budget passed publication; reconstructing bytes from a digest |
| Completion checkpoint | Existing `fo_completion_checkpoint`, passed folder entities only | Unchanged `completion-v1` receipt and `ready|reconciled` result | Stage registration for partial/blocked/failed/interrupted; optional receipt fields |
| Terminal history | FO after authoritative return/checkpoint | One canonical line in the layout-resolved tracked terminal ledger | Rewriting prior lines; conflicting terminal; stage-worker append; unrelated dirty-state loss |
| Exhaustion | FO begin guard | One `route-out` line with continuation count, limit, route, and reason | Lease acquisition, attempt creation, envelope construction, or worker dispatch |

For a passed folder entity, ordering is load-bearing: the exact returned receipt
is retained in the `.returned` sidecar bound by the WAL, the existing completion checkpoint runs against the
worker completion OID, and only then may terminal history advance the ref. A
history commit before checkpoint would violate reconcile's exact-ref predicate
(`fo-reconcile-completion.sh:31-58`). Non-passed and flat-entity attempts do not
invoke completion-v1 registration; their outer receipt terminalizes directly.

### `stage-attempt-v1` Record Contract

All protocol records are ASCII, single-space-separated, fixed-order lines with
one trailing LF. There are no optional fields, tabs, CR bytes, duplicate keys,
extra lines, or trailing spaces. Arbitrary strings use lowercase even-length
hex of their UTF-8 bytes (`*_hex`); hashes and event IDs are 64 lowercase hex;
Git OIDs use the repository object-format width; unsigned integers have no sign
or leading zero except the value `0`; timestamps are UTC RFC3339 seconds. The
parser rejects a value outside the closed enum/grammar before comparing the
whole expected line byte-for-byte.

The exclusion lock is
`<git-common-dir>/spacedock-stage-attempt-v1/<entity_stage_key>.lock` and its WAL
is the sibling `<entity_stage_key>.wal`. A returned worker bundle is atomically
written byte-for-byte to sibling `<entity_stage_key>.returned` before the WAL
may enter `returned`; the WAL digest includes the entire bundle. Here
`entity_stage_key = sha256("stage-attempt-v1-key\0" + canonical_entity_path_bytes
+ "\0" + stage)`. The key intentionally omits `stage_run_id`: every proposed run
for the same canonical entity and stage must contend. The exact WAL line is:

```text
stage-attempt-wal-v1 entity_stage_key=<64hex> entity_path_hex=<hex> stage=<plan|execute> stage_run_id=<oid> ref_hex=<hex> attempt_before_oid=<oid> worker_id_hex=<hex> lease_sha256=<64hex> attempt_id=sa1-<64hex> attempt_ordinal=<uint> attempt_started_at=<rfc3339> boot_id_sha256=<64hex> monotonic_started_ns=<uint> budget_seconds=<1200|1800> state=<open|suspended|returned> fresh_continuations_used=<0|1> returned_bundle_sha256=<none|64hex>
```

The worker's outer receipt is exactly:

```text
stage-attempt-v1 entity_stage_key=<64hex> entity_path_hex=<hex> stage=<plan|execute> stage_run_id=<oid> ref_hex=<hex> attempt_before_oid=<oid> worker_completion_oid=<oid> worker_id_hex=<hex> lease_sha256=<64hex> attempt_id=sa1-<64hex> attempt_ordinal=<uint> attempt_started_at=<rfc3339> budget_seconds=<1200|1800> attempt_elapsed_seconds=<uint> fresh_continuations_used=<0|1> outcome=<passed|partial|blocked|failed> artifact_path_hex=<hex> artifact_oid=<oid> completion_receipt_sha256=<none|64hex> terminal_event_id=sev1-<64hex>
```

For a passed folder entity only, that line is followed immediately by the exact
three-part frame `completion-v1-begin\n`, the unchanged one-line
`completion-v1` receipt including its LF, and `completion-v1-end\n`. The SHA-256
of the complete unchanged receipt line, including LF, must equal
`completion_receipt_sha256`. No frame is permitted when the field is `none`;
non-passed results and flat entities require `none`. Any missing, duplicated,
reordered, or additional frame byte rejects the whole return.

Terminal checkpoint commits the exact `.returned` bytes at the same ref-CAS as
the terminal line. Its canonical tracked destination is
`<folder>/attempt-return-v1.<terminal_event_id>.receipt` for folder entities and
`<flat-base>.attempt-return-v1.<terminal_event_id>.receipt` for flat entities.
The ref update is invalid unless the sidecar bytes hash to `returned_bundle_sha256`
and the new tree adds exactly that sidecar plus one terminal-history line. Only
after ref-CAS and path-only reconcile may FO remove `.returned` and its WAL.
Terminal replay reads and byte-compares the tracked sidecar; it never regenerates
the outer receipt or completion frame. FO-only `interrupted` has no worker bundle
and therefore no return sidecar.

Lifecycle is `open -> suspended -> open`, `open -> returned -> terminal`, or
`open|suspended -> terminal` for FO interruption. `returned` requires a
64-hex `returned_bundle_sha256` and an exact matching `.returned` sidecar;
`open|suspended` normally require `none`. The sole permitted intermediate is a
provisional `.returned` sidecar beside an `open|suspended` WAL after the atomic
sidecar write but before the WAL flip described below.
Terminal outcomes are exactly `passed|partial|blocked|failed|interrupted`;
`interrupted` is FO-only and never resumable, while `exhausted` is a circuit
route rather than an attempt state. Tracked records are exact single lines in
one of these fixed orders:

```text
stage-attempt-v1 disposition=terminal terminal_event_id=sev1-<64hex> entity_stage_key=<64hex> entity_path_hex=<hex> stage=<plan|execute> stage_run_id=<oid> ref_hex=<hex> attempt_before_oid=<oid> worker_completion_oid=<none|oid> attempt_id=sa1-<64hex> attempt_ordinal=<uint> attempt_started_at=<rfc3339> attempt_finished_at=<rfc3339> budget_seconds=<1200|1800> elapsed_seconds=<uint> cumulative_elapsed_seconds=<uint> fresh_continuations_used=<0|1> returned_bundle_sha256=<none|64hex> completion_receipt_sha256=<none|64hex> outcome=<passed|partial|blocked|failed|interrupted>
stage-attempt-v1 disposition=legacy-unscoped legacy_event_id=slev1-<64hex> entity_stage_key=<64hex> entity_path_hex=<hex> stage=<plan|execute> stage_run_id=<oid> source_blob_sha256=<64hex> report_receipts_sha256=<64hex> cumulative_elapsed_seconds=<uint> precision=minute-reported observed_at=<rfc3339>
stage-circuit-v1 disposition=route-out route_event_id=srev1-<64hex> entity_stage_key=<64hex> entity_path_hex=<hex> stage=<plan|execute> stage_run_id=<oid> fresh_continuations_used=1 fresh_continuations_limit=1 route=return reason=attempt-count-exhausted observed_at=<rfc3339>
```

Lifecycle/idempotency keys are closed and domain-separated. Their hash inputs
are exact byte concatenations (not the displayed `+` characters):

```text
attempt_id = "sa1-" + sha256("stage-attempt-v1-attempt\0" + entity_stage_key + "\0" + stage_run_id + "\0" + ref_bytes + "\0" + attempt_before_oid + "\0" + attempt_ordinal + "\0" + lease_token_bytes)
terminal_event_id = "sev1-" + sha256("stage-attempt-v1-terminal\0" + entity_stage_key + "\0" + stage_run_id + "\0" + attempt_id)
legacy_event_id = "slev1-" + sha256("stage-attempt-v1-legacy\0" + entity_stage_key + "\0" + stage_run_id + "\0" + source_blob_sha256 + "\0" + report_receipts_sha256)
route_event_id = "srev1-" + sha256("stage-attempt-v1-route\0" + entity_stage_key + "\0" + stage_run_id + "\0attempt-count-exhausted")
```

`attempt_id` keys the WAL and returned receipt, while tracked evidence retains
only `lease_sha256`. One serialized ID may have exactly one canonical byte
string.

Every append proves `new_history = old_history + exactly_one_valid_line` under
ref CAS. Exact replay returns `already-recorded`; the same lifecycle/event key with
different bytes exits nonzero and preserves WAL, history, ref, index, and
worktree bytes.

### Timing and Recovery Semantics

- The FO captures `attempt_started_at` once for audit and
  `monotonic_started_ns` once for authority. A read-only elapsed query returns
  floor((now - start)/1e9); neither the worker nor report prose supplies it.
- The helper stays within the canonical Bash 3.2+/Node 18+ boundary: Node
  `process.hrtime.bigint()` supplies monotonic nanoseconds; Linux hashes
  `/proc/sys/kernel/random/boot_id`, while macOS hashes the normalized
  `sysctl -n kern.boottime` value. An unavailable/unparseable source is clock
  identity loss and fails closed as `interrupted`, never a wall-clock fallback.
- Plan evaluates its existing breaker against 1,200 FO seconds and execute
  against 1,800 FO seconds. Existing `duration_minutes` remains the cumulative
  stage metric; new fields make the current attempt explicit.
- A worker disconnect or same-boot FO restart moves `open -> suspended -> open`
  on the same exact lease and preserves ID, ordinal, start, monotonic origin,
  budget, and continuation count.
- Missing boot identity or monotonic regression cannot prove continuity.
  Recovery terminalizes `interrupted` with the last provable lower bound and
  may issue the one permitted fresh continuation.
- A crash after worker return replays the exact outer receipt. A passed folder
  replay also reuses the persisted exact completion receipt; a crash after
  terminal-history CAS returns `already-recorded` and cleans only the matching
  lease. No recovery path dispatches or adds duration twice.
- Recovery always acquires the entity+stage lock before inspecting a provisional
  `.returned` sidecar. With an `open|suspended` WAL, it parses the full bundle
  and requires byte/field equality for entity key/path, stage, stage run, ref,
  attempt-before OID, worker, lease hash, attempt ID/ordinal/start/budget, and
  terminal event ID, plus the recomputed whole-bundle hash. An exact match flips
  that same WAL to `returned` without dispatch; any mismatch fails closed and
  preserves both files. A `returned` WAL without its matching sidecar, or a
  sidecar with no WAL and no matching tracked terminal event, also fails closed.
  If terminal history and its tracked return sidecar already match, recovery
  returns `already-recorded` and may remove only the matching common-Git-dir
  WAL/sidecar pair.
- A receipt hash mismatch, foreign lease, moved ref, missing artifact, negative
  monotonic delta, or conflicting terminal is fail-closed. No path converts an
  ambiguous attempt into `passed`.

### Bounded Route-out and #21 Compatibility

The policy table is closed for this batch:

| Stage | Per-attempt budget | Fresh-continuation limit per `stage_run_id` | Exhaustion route |
| --- | ---: | ---: | --- |
| plan | 1,200 seconds | 1 | `route=return`, `reason=attempt-count-exhausted` |
| execute | 1,800 seconds | 1 | `route=return`, `reason=attempt-count-exhausted` |

Other stage timers do not call the attempt wrapper. The bound is checked before
lease acquisition, so threshold + 1 proves no lease file, new attempt line,
worker prompt, or stage artifact change.

Only `partial` and `interrupted` permit the one fresh continuation. `blocked`
and `failed` route `return` immediately, and `passed` completes normally; none
of those paths can be overridden by a worker-provided retry flag.

For #21, FO records one `legacy-unscoped` baseline from hashes of the existing
32-minute and 61-minute report blocks, producing a cumulative seed of 5,580
seconds while leaving both source blocks and the five-record plan ledger
byte-identical. Because legacy evidence already ended partial, the first new
typed plan run is the one allowed fresh continuation and sets
`fresh_continuations_used=1`. It may pass under 1,200 seconds even though
cumulative duration remains above the old total-stage breaker; any non-pass
then routes out. No allocator topology, TDD ledger, product diff, or historical
receipt is edited.

## Schema Design Output

### Layers touched

- Application database L1/L2/L3: not applicable; no product data model,
  projection table, or UI response shape.
- Workflow L1 authority: FO-only common-Git-dir WAL while open/suspended/returned and the
  layout-resolved tracked terminal ledger after terminalization.
- Workflow L2 projection: folded current-attempt and cumulative duration state.
- Workflow L3 contract: FO dispatch envelope, exact stage-attempt-v1 receipt,
  and plan/execute report fields.

### Migration safety

- Additive / destructive: additive. `completion-v1` and historical Markdown
  remain byte-exact; entities without attempt history continue unchanged until
  a covered stage begins.
- Backfill required: none. `legacy-unscoped` is explicit, one-time, and used only
  when an existing receipt history must contribute to cumulative duration.
- Event-saga implication: none. This is a local workflow lifecycle log, not an
  application event saga, foreign-key, primary-key, or column change.

### RBAC and tenancy

- tenant_id / ownership columns: not applicable.
- RBAC subject: not applicable. Files remain governed by repository/worktree
  ownership and the existing completion lease.

### Projection / fstore rebuild

- Rebuild strategy: report projections fold the canonical tracked ledger; the
  terminal ledger itself is never reconstructed from prose. Nonterminal
  recovery uses only the matching WAL/lease and, for `returned`, the exact
  common-Git-dir returned-bundle sidecar. Terminal replay uses the exact tracked
  return sidecar committed with the ledger line.
- Stale-read tolerance: none for begin/resume/terminal decisions. FO holds the
  attempt lock and compares canonical last-event state before any append.

### Plan/execute report projection fields

Add the same grep-friendly fields to both report metrics schemas:
`stage_run_id`, `attempt_id`, `attempt_ordinal`, `attempt_started_at`,
`attempt_before_oid`, `worker_completion_oid`, `returned_bundle_sha256`,
`attempt_budget_seconds`, `attempt_elapsed_seconds`,
`cumulative_stage_elapsed_seconds`, `fresh_continuations_used`, `attempt_state`,
`attempt_outcome`, and `terminal_event_id`. The FO WAL/ledger is authoritative;
report values are rebuildable projections and validation rejects a snapshot
that conflicts with its terminal record. Existing `duration_minutes` stays
present for backward compatibility.

## Contract and Test Surface for Plan

| Surface | Required delta | Falsifiable proof |
| --- | --- | --- |
| `plugins/ship-flow/lib/fo-stage-attempt.sh` (new) | Exact begin/suspend/resume/return/terminal/route-out wrapper; canonical-entity+stage common-Git-dir exclusion lock, WAL, and exact returned bundle; temporary-index/ref-CAS terminal append of the ledger line plus tracked returned-bundle sidecar; flat/folder resolver. | New `test-stage-attempt-v1-contract.sh`, `test-stage-attempt-clock.sh`, `test-stage-attempt-history.sh`, and `test-stage-attempt-route.sh` pin byte grammar/framing, attempt before/completion OID binding, restart replay from exact retained bytes, same-entity different-run sibling contention, authority, clock, crash, dirty-state, replay, and no-dispatch behavior. |
| `plugins/ship-flow/lib/fo-completion-lifecycle.sh` | Expose a plan/execute-only wrapper entry while keeping existing functions and exact receipt parser unchanged for every stage. | `test-stage-wiring.sh --completion-lifecycle` proves old receipt bytes still reconcile and only plan/execute receive attempt variables. |
| `plugins/ship-flow/lib/completion-v1.sh` | No production change. Treat exact lease/receipt grammar as a frozen compatibility surface. | `test-completion-v1-review.sh` keeps shared-emitter counts and adds byte comparison before/after attempt wrapper use; extra attempt tokens still fail. |
| `plugins/ship-flow/references/entity-body-schema.yaml` | Add plan/execute attempt projection fields and tracked sidecar semantics; increment schema version/change note additively. | `test-entity-body-schema.sh` parses both stages and rejects missing attempt fields on new typed reports while legacy fixtures remain valid. |
| `plugins/ship-flow/skills/ship-plan/SKILL.md` | Replace only the 20-minute total-stage gate with the FO elapsed query and plan policy; retain partial artifact requirement. | New string/behavior test pins 1,200 seconds, `attempt_id`, cumulative/current distinction, and return-before-dispatch exhaustion. |
| `plugins/ship-flow/skills/ship-execute/SKILL.md` | Replace only the 30-minute total-stage gate with the FO elapsed query and execute policy; retain task/review/PR-feedback breakers. | Same focused test pins 1,800 seconds and proves unrelated execute breakers are unchanged. |
| `plugins/ship-flow/lib/__tests__/test-stage-wiring.sh` | Exercise FO entry OID -> partial/interrupted -> one fresh attempt -> passed registration -> separate next-stage entry, plus crash-before/after publication and foreign lease refusal. | Removing lease/attempt binding, terminal ordering, or no-dispatch guard makes the integration test fail; Linux/macOS boot-ID fixtures pin portable clock behavior. |
| `plugins/ship-flow/lib/__tests__/test-completion-v1-frontmatter.sh` and `test-advance-stage.sh` | Preserve body/authority bytes, completion eligibility, CAS, rollback, and flat/folder distinctions while the outer attempt contract is added. | Any pseudo-folder conversion, body rewrite, permissive authority tail, or completion-helper regression fails existing matrices. |
| Attempt-history fault matrix | Pin crash after `.returned` atomic write but before WAL flip, exact provisional adoption without dispatch, mismatched provisional preservation/refusal, returned-without-sidecar refusal, sidecar-without-WAL refusal, dirty target-ledger refusal, staged and unstaged unrelated paths, live `index.lock`, stale-ref CAS, and post-CAS path-only reconciliation. | Every failure preserves returned evidence, target history, ref, index, and unrelated worktree bytes; exact provisional recovery dispatches zero workers; successful reconcile changes only the resolved ledger and return-sidecar paths. |
| #21 dogfood | Hash the two historical receipt blocks and five ledger records before and after one new typed revalidation. | Any receipt, plan ledger, allocator plan, or preserved product diff byte change fails W4; a fresh attempt over 1,200 seconds remains partial. |

Focused implementation must use TDD and run RED before modifying the helper,
schema, or skill contracts. Plan must name the exact string-assertion tests
above; prose-only edits do not satisfy the stage definition.

## Reverse Audit of Shape

| Shape item | Design resolution |
| --- | --- |
| CD-1 | D1 keeps completion-v1 exact and adds a separately versioned wrapper. |
| CD-2 | D2 makes FO the sole ID/time authority and defines loss-of-clock behavior. |
| CD-3 | D3 defines in-flight and terminal authority, ordering, replay, and conflict refusal. |
| CD-4 | D4 fixes generation, budgets, attempt limit, and no-dispatch route-out. |
| W1 | D2/D4 allow one fresh attempt under its own budget while cumulative time stays monotonic. |
| W2 | D2/D3 preserve start on same-FO resume and close both crash windows idempotently. |
| W3 | D4 routes threshold + 1 before lease or dispatch. |
| W4 | D1/D3 preserve receipt bytes and D4 treats legacy partial evidence as the one allowed fresh-continuation trigger. |

No `open_design_questions` existed, all four `open_contract_decisions` now have
captain-delegated EM decisions, and the design adds no scheduler, unrelated
stage timer, split-root behavior, cross-workflow coordination, #21 redesign,
receipt rewrite, or breaker waiver.

## Design Readiness Review

```yaml
risk_triggers:
  - migration
  - fmodel
  - recent-debrief
reviewers: schema,fmodel
derived_from:
  - domain:schema
  - additive workflow event schema
  - crash-window and lease-steal debrief warning
verdict: PASS
findings:
  - reviewer: schema
    severity: PASS
    route_to: plan
    evidence: "Exact WAL, outer receipt, completion-v1 frame, terminal lines, event IDs, per-attempt before/completion OIDs, and tracked returned-bundle bytes leave no protocol decisions to plan."
  - reviewer: fmodel
    severity: PASS
    route_to: plan
    evidence: "Entity+stage exclusion, provisional-return adoption, restart replay, terminal sidecar promotion, monotonic clock loss, ref CAS, and dirty-state fault paths are closed and fail-safe."
```

## Adversarial Cross-Review

A fresh context-free reviewer initially vetoed the draft, then re-reviewed every
repair. The final verdict is **PASS — PROCEED to plan**.

| Factor | Verdict | Evidence |
| --- | --- | --- |
| Feasibility | PASS | Canonical entity+stage locking prevents different-run sibling authority; provisional exact returns adopt under that lock with zero redispatch. |
| Executable scope | PASS | Byte templates fix WAL, return/frame, terminal history, returned sidecar, and lifecycle event identities before plan. |
| Quality | PASS | Route-out vocabulary, per-attempt ref transition, portable clocks, and crash boundaries are internally consistent. |
| DC adequacy | PASS | D1-D4 resolve CD-1-CD-4 with explicit captain-delegated technical decisions. |
| Canonical sync | PASS | PRODUCT needs no update; ARCHITECTURE receives the named decision only after review. |
| Reverse-audit previous stage | PASS | W1-W4 and all contract decisions map to design resolutions; UI audit is not applicable. |
| Constraint coverage | PASS | Every hand-off constraint references D1-D4 and `open_decisions` is empty. |

The reviewer-required repairs now bind `attempt_before_oid` and
`worker_completion_oid`, retain exact returned bytes through terminal replay,
define the sidecar-before-WAL crash transition, and require injected failure
tests for every affected boundary.

## Design Report

- status: passed
- stage_cost: two read-only design lanes plus four fresh adversarial review passes
- iterations: 4 design/review iterations
- contradictions_resolved: 4 of 4 contract decisions
- captain_decisions: 4 captain-delegated EM technical decisions
- reviewer_verdict: PROCEED
- design-flow: unavailable; used the documented `superpowers:brainstorming` fallback

### Metrics

- status: passed
- duration_minutes: 38
- iteration_count: 4
- captain_decisions_count: 4
- open_decisions_count: 0
- reviewer_verdict: PROCEED

<!-- section:hand-off-to-plan -->
### Hand-off to Plan

```yaml
design-skipped: false
design_constraints:
  - type: contract
    assertion: Keep completion-v1 lease and receipt serialization byte-exact; implement plan/execute identity as a separate exact stage-attempt-v1 outer receipt, and on passed folder runs bind the separately delimited unchanged completion receipt by SHA-256.
    rationale_decision: D1
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: contract
    assertion: Limit attempt-v1 integration to plan and execute; shape, design, verify, review, ship, PR-feedback, task-review, and unrelated circuit breakers retain current behavior.
    rationale_decision: D1
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: schema-contract
    assertion: FO alone issues stage_run_id, attempt_id, ordinal, per-attempt before OID, audit start, per-stage budget, lease binding, and monotonic elapsed values; worker return must bind the same ref and before OID plus its completion OID, and no worker field can reset authority.
    rationale_decision: D2
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: contract
    assertion: Same-boot resume preserves the suspended attempt, ID, ordinal, start, monotonic origin, budget, and continuation count; lost clock identity terminalizes interrupted, while returned-receipt replay never dispatches or adds duration twice.
    rationale_decision: D2
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: data-contract
    assertion: Use a git-common-dir exclusion lock and WAL keyed by canonical entity plus stage only, with stage_run_id bound inside the WAL, so same-entity sibling runs contend even under different entry OIDs; retain exact returned bytes in a common-Git-dir sidecar, then atomically append canonical terminal history plus the exact tracked returned-bundle sidecar using temporary-index ref CAS, and place passed folder history after the unchanged completion checkpoint.
    rationale_decision: D3
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: data-contract
    assertion: Canonical receipt/history replay is idempotent and returns already-recorded; a second or byte-conflicting terminal fails closed without changing WAL, history, ref, index, or worktree bytes.
    rationale_decision: D3
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: contract
    assertion: Bind policy to the FO stage-entry commit OID, preserve plan budget 1200 seconds and execute budget 1800 seconds, and permit at most one fresh continuation after a typed or legacy partial/interrupted result.
    rationale_decision: D4
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: contract
    assertion: A second fresh-continuation request emits one idempotent route-out record with route=return and reason=attempt-count-exhausted before completion lease acquisition, attempt creation, envelope construction, or worker dispatch; blocked/failed route immediately.
    rationale_decision: D4
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: data-contract
    assertion: Preserve duration_minutes as compatibility data and add stage_run_id, attempt identity/timing, before/completion OIDs, returned-bundle digest, fresh_continuations_used, state/outcome, cumulative elapsed, and terminal event projections to plan and execute reports; cumulative duration never gates a fresh continuation.
    rationale_decision: D2
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - type: contract
    assertion: #21 dogfood hashes and preserves the exact 32-minute and 61-minute receipt blocks, five-record plan ledger, allocator plan, and product diff; legacy-unscoped contributes 5580 cumulative seconds and makes the one new typed revalidation consume the sole fresh-continuation allowance.
    rationale_decision: D4
    source_artifact: docs/ship-flow/attempt-scoped-stage-circuits/design.md
open_decisions: []
artifact_paths:
  - path: docs/ship-flow/attempt-scoped-stage-circuits/design.md
  - path: docs/ship-flow/attempt-scoped-stage-circuits/index.md
render_fidelity_targets: []
storyboard_frames: []
```
<!-- /section:hand-off-to-plan -->
