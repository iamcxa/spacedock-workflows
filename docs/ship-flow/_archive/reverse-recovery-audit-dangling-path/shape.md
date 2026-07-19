# Fix dangling reverse-recovery-audit adopter-local mod reference + regress-guard — Shape

## Problem

`ship-shape/SKILL.md:597` and `ship-plan/SKILL.md:502` lead with
`docs/ship-flow/_mods/reverse-recovery-audit.md` as the mod's canonical location,
but that file does not exist in this repo. The plugin-canonical copy
`plugins/ship-flow/_mods/reverse-recovery-audit.md` (3.7K) exists. `check-no-dangling.sh`
is a fixed denylist of known-dead literal strings and never resolves referenced
paths, so it cannot catch this class. (Articulation source: todo pitch 5 +
issue #69 + captain 票ok 2026-07-19 — not re-litigated here.)

## Acceptance Outcome

The two SKILL references resolve in the source repo (and adopters); the same
mislocation is mechanically regress-guarded by a fixture-backed CI check that
runs red on a synthetic dangling reference and green on the fixed tree.

## Appetite / Size

S (hours). Non-UI, mechanical. Two 1-line SKILL edits + one new resolver pass
+ one fixture-backed shell test.

## Decision — fix (b): reconcile the two SKILL references to the canonical path

Rewrite both references to lead with the plugin-canonical path (always present in
the source repo) and demote the adopter path to a "when present" override, matching
the established `science-officer-em` / `contribution-contract` two-tier convention:

  Before: `docs/ship-flow/_mods/reverse-recovery-audit.md`; plugin-canonical copy at `plugins/ship-flow/_mods/reverse-recovery-audit.md`.
  After:  `plugins/ship-flow/_mods/reverse-recovery-audit.md` (plugin-canonical); adopter override at `docs/ship-flow/_mods/reverse-recovery-audit.md` when present.

Evidence this is the honest direction:
- The mod header itself (`plugins/ship-flow/_mods/reverse-recovery-audit.md:8-11`)
  states "Plugin-canonical copy. Adopting repos copy this to `docs/ship-flow/_mods/…`."
  This repo ships `plugins/ship-flow/` — it is the **source**, not an adopter — so
  the adopter copy is not expected here; the plugin copy is the live one.
- No `docs/ship-flow/sync-manifest.json` exists; `bin/sync-drift-check.mjs` is opt-in
  and dormant in this repo (adopter `_mods/` holds only the local-only `pr-merge.md`).
  Its `plugin-canonical` bucket treats the plugin tree as source of truth and the
  adopter copy as a hash-checked materialization — so the machinery already "owns"
  the plugin path as canonical.
- Sibling canonical mods already follow this: `science-officer-em/SKILL.md:11-12`
  ("Load plugin path… if a workflow override exists at docs/…, read it") and
  `contribution-contract` ("adopter… when present, otherwise the plugin copy").
  reverse-recovery-audit is the lone anomaly presenting the adopter path as primary.

## Guard spec (AC-2)

**Where `check-no-dangling.sh` misses it:** it is a fixed denylist of 8 known-dead
literal strings (`spacedock:overhaul`, `spacedock-ui`, `/Users/kent`, …) run via
`grep -P`. It performs zero path-existence resolution — it never checks that a
referenced repo-relative `_mods/*.md` exists. Also its `SCAN_ROOT` is
`plugins/ship-flow/` only, while the dangling target lives under `docs/ship-flow/`,
so any resolver must resolve targets against `REPO_ROOT`.

**The guard — mislocated-canonical-mod resolver** (new pass in `check-no-dangling.sh`
or an equivalent wired sibling check). For each backtick-quoted
`docs/ship-flow/_mods/<name>.md` in scanned `plugins/ship-flow/**/*.md`, VIOLATION iff
**all** of:
1. adopter `docs/ship-flow/_mods/<name>.md` does not exist, AND
2. plugin twin `plugins/ship-flow/_mods/<name>.md` DOES exist (mod is real, just
   mislocated in the reference), AND
3. the reference is unconditional — its **full logical unit** carries no adopter-optional
   qualifier (`when present` / `if a workflow override exists` / `otherwise the plugin copy` / `adopter override`).

Condition (2) scopes the guard to the ticket's class ("plugin-canonical copy exists")
and naturally excludes the missing-everywhere mods (see Out-of-scope). Condition (3)
excludes the legitimate two-tier "when present" overrides so they do not false-positive.

**Load-bearing (found by exercising the rule against the real refs):** condition (3)
MUST be evaluated over the reference's full logical unit (the joined list-item /
sentence), NOT a single physical line. `science-officer-em/SKILL.md:11-12` wraps its
legitimate qualifier across two lines ("Load `plugins/…/science-officer-em.md`… **if a**
/ **workflow override exists at** `docs/…`, read it"); a line-scoped grep sees only
"workflow override exists at" on line 12 and false-positives. Unwrap the soft-wrapped
prose within the same list item / sentence before applying the qualifier check.

**Fixture-backed test that pins the fix** (new `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh`, matching the 110+ suite; run by ship-flow-invariants.yml):
- RED: scratch tree with plugin `_mods/foo.md` present, adopter `_mods/foo.md` absent,
  a SKILL line ```docs/ship-flow/_mods/foo.md``` unqualified → resolver exits 1.
- GREEN-fixed: SKILL line leads with ```plugins/ship-flow/_mods/foo.md``` + adopter path
  "when present" → exits 0.
- GREEN-qualified: SKILL line "if a workflow override exists at ```docs/ship-flow/_mods/foo.md```" → exits 0 (no false positive on the science-officer-em pattern).
- GREEN-wrapped-qualifier: the qualifier soft-wrapped across two lines (as science-officer-em:11-12 does) → exits 0 (guards the full-logical-unit refinement above).
- GREEN-no-twin: SKILL line ```docs/ship-flow/_mods/bar.md``` with no plugin twin → exits 0 (out-of-class; guard does not over-reach).
- Plus green on the real repo after the fix (AC-2 "green on the repo").

## Deletes (rejected alternatives)

- **(a) Materialize/sync `docs/ship-flow/_mods/reverse-recovery-audit.md` from the
  plugin copy + register in sync-manifest** — the mod header says only *adopting*
  repos create that copy; this is the source repo. Materializing here creates an
  un-drift-checked duplicate (no `sync-manifest.json` exists → would require standing
  up manifest machinery, out-of-scope) that drifts from the canonical copy the sync
  machinery already owns. More surface, less honest for an S ticket.
- **Naive repo-wide "every `_mods/*.md` path must exist" resolver** — would red on
  the out-of-scope missing-everywhere mods below, breaking AC-3. The twin-exists +
  qualifier-aware rule threads the needle instead.

## Out-of-scope (discovered, not fixed here)

`architecture-canon.md` (`ship-shape:596`, `ship-plan:501`) and some
`canonical-doc-sync.md` references exist in **neither** tier (no plugin twin) — a
**different** class: the mod content exists nowhere, so re-pointing cannot fix them
(needs mod authoring or reference removal). The guard's condition (2) deliberately
does not flag them. Flag for a follow-up todo; not this ticket. Also out-of-scope:
any broader doc-reference audit, sync-manifest redesign, or other dangling paths.
