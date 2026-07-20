# hackathon-spirit-canonicalization — Verify

## Verdict

PASS

## AC Evidence

### AC-1 — The time-box rules are repo-canonical

**Grep command**: `grep -n "time_budget\|75%\|brake" plugins/ship-flow/INVARIANTS.md`

**Result** (lines 413–438):
- Line 413: `**Rule**: Every entity MUST carry a \`time_budget\` field ...`
- Line 416: `- **75% consumed** — warn in-channel ...`
- Line 418: `- **100% consumed (brake fires)** — park the entity ...`
- Line 420: `NEVER compress or skip verification to fit a budget.`
- Line 422: `**Verification is never optional** ...`

All three terms hit. Brake semantics confirmed: park + surface + cut scope. Park-not-compress wording confirmed at line 420 ("NEVER compress or skip verification to fit a budget"). AC-1: PASS.

### AC-2 — New entities are born with budgets

**Grep command**: `grep -n "time_budget" docs/ship-flow/README.md`

**Result**:
- Line 104: Field Reference table row — `| \`time_budget\` | string | Budget in \`<N>h<N>m\` format (e.g. \`2h30m\`). At 75% consumed the FO warns in-channel; at 100% the brake fires: park + surface + cut scope. ...`
- Line 261: Feature Template frontmatter — `time_budget:` (after `score:`)

Both the Field Reference row (with `<N>h<N>m` format note and semantics pointer) and the Feature Template field are present. AC-2: PASS.

### AC-3 — Hackathon learnings distilled into existing canon, not an orphan doc

**Git diff**: `git diff main --name-only` shows only these canon files modified:
- `docs/ship-flow/README.md`
- `plugins/ship-flow/INVARIANTS.md`
- `docs/ship-flow/hackathon-spirit-canonicalization/` (entity stage files only)

`git status` shows working tree clean. No new standalone doc files created. Gate suite from execute.md: check-invariants.sh (all C1–C17 OK), node suite (79/79 pass), check-version-triple (5/5), check-no-dangling (12/12). 13 pre-existing scheduler-adapter failures confirmed identical on main (zero new regressions). AC-3: PASS.

## runtime_uat

not-applicable — docs-only change; no UI, CLI, or runtime behavior surface changed. The time_budget scheduler derivation is a pre-existing runtime path covered by test-scheduler-runner-adapter.sh's 14 time_budget-specific cases (all PASS per execute.md).

## Gate Suite Summary

| Gate | Result |
|------|--------|
| `check-invariants.sh` | PASS — all C1–C17 OK |
| Node test suite | PASS — 79/79 |
| `test-check-version-triple.sh` | PASS — 5/5 |
| `test-check-no-dangling.sh` | PASS — 12/12 |
| `test-scheduler-runner-adapter.sh` (time_budget cases) | PASS — 14 time_budget-specific cases |

Pre-existing failures: 13 failures in test-scheduler-runner-adapter.sh (exit_class, sentinel, TICK_ID tests) — confirmed identical on unmodified main branch. Zero new regressions.
