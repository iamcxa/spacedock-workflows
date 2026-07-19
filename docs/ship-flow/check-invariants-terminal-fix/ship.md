# check-invariants terminal misclassification fix — Ship

PR #80 (base main, `Closes #76`), body composed once from shape/verify
artifacts incl. the AC-2 corpus-honesty framing (surfacing table +
"CI invariants may go RED by design"). Privacy grep clean. `pr: "#80"`
persisted to `index.md` after `gh pr view 80` confirmed.

## CI result (checked once, per stage-def caveat)

- `doc_impact`: **pass**, after a `doc-impact: none — <reason>` declaration
  was added to the PR body for the `checker-source-map` coupling row
  (`check-invariants.sh` already has a Source-Map row at
  `doc-sync-context.md:40`; this is a predicate correctness fix, not a
  new/removed checker).
- `invariants`: **fail** — but only on the designed AC-2 outcome: `FAIL C1`
  (roborev missing `pre_mortem:`) + `FAIL C15` (this entity's own `plan.md`
  220 lines, pre-existing). Matches execute.md/verify.md's surfacing table
  exactly.
- `GitGuardian`: pass.

**Not arming auto-merge** — invariants reds (by design), and the caveat
says only arm on green. Reporting for FO/captain routing.

### Concurrent-merge race (resolved, not a regression)

Sibling PR #79 (`missing-canonical-mods`) merged to `main` mid-flight.
GitHub's `pull_request.base.sha` stayed pinned to the pre-merge tip across
two synchronize events, so `doc-impact-gate.sh` diffed against a stale
merge-base and misattributed PR #79's files (`SKILL.md`, etc.) to this PR's
changed-file set — spurious `stage-skill-readme`/`issue-anchor-guard`
BLOCKERs. Fixed by merging `origin/main` into this branch (clean,
no conflicts; DC-18 4/4 + full local suite 66/66 re-verified after). Also
observed one transient flake on the first post-merge CI run
(`test-merged-pr-closeout-provider-pagination.sh`, unrelated file, passed
46/46 locally and on job re-run) — not reproducible, not routed further.

## Canonical docs

PRODUCT.md / ARCHITECTURE.md / ROADMAP.md — skip, per plan.md's Canonical
Doc Actions (existing capability row covers this; no roadmap/architecture
item). No new coupled-doc actions beyond the `doc-impact: none` waiver above.

## Todo Closeout Digest

Named candidates for follow-up (none blocking this ship):

1. Fix roborev's un-masked findings (25 orphan-header `ERROR`s, `pre_mortem:`
   missing) — this is the AC-2 surfacing this ticket exists to produce, now
   real work for a separate entity.
2. Anchor `_entity_is_terminal` to frontmatter only (verify informational
   #1) — whole-file scan today, 0 real hits, latent.
3. Guard duplicate `status:` lines (first-match-wins) (verify informational
   #2) — identical to pre-fix behavior, 0 real hits, latent.

## Verdict

status: shipped (PR open, not auto-merged — awaiting FO/captain route
decision on the roborev-red vs merge tradeoff)
