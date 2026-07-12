# PR (drafted, NOT created)

**Title:** Self-adoption dogfood bootstrap — canonical docs + doc-impact gate

**Branch:** `spacedock-ensign/1-self-adoption-dogfood-bootstrap` → `main`

**HARD BOUNDARY:** this file is a draft only. No push, no `gh pr create`, no
merge happened this stage. The FO presents this package (below) plus a
scaffolding-first merge-order plan for the 2 historical C14 commits
(`695addea`, `0d0ca53e`) to the captain for the final go.

---

## Body

### What

The plugin repo now obeys its own methodology: root `ARCHITECTURE.md` /
`PRODUCT.md` / `ROADMAP.md` exist and are flow-map-schema compliant, a new
`doc-impact-gate` CI checker mechanically fails plugin-touching PRs that skip
a coupled doc without a `doc-impact: none — <reason>` declaration, and this
entity itself is the first to travel shape→design→plan→execute→verify→ship
through this pipeline end-to-end — closing the self-adoption loop.

### AC evidence

- **AC-1** (Principle 5b enforces): `CI=true bash
  plugins/ship-flow/bin/check-invariants.sh` → 0 `WARN [Principle 5b]`
  lines. `e51ed05`.
- **AC-2** (routing policy is a code gate): `bin/doc-impact-gate.sh` +
  `references/doc-coupling-map.yaml`, RED-first
  (`test-doc-impact-gate.sh` 47/47 GREEN, `1b5dba0`..`670df77`); CI wiring
  `22c3c87`; live-equivalent PR-body-declaration path confirmed in verify.md
  Runtime UAT. Self-application (below) is this PR's own live-CI-run leg.
- **AC-3** (canonical-doc sync loop end-to-end): this entity's own
  shape→ship traversal; `review.md` `## Canonical Docs Update` +
  `canonical-doc-sync-checker.sh docs/ship-flow/1-self-adoption-dogfood-bootstrap`
  exit 0 (see review.md).
- **AC-4** (harvest vocabulary decision record): `references/harvest-vocabulary.md`
  (`82a6495`), linked from README further-reading — both `test -f` and
  `grep` assertions true.

### Codex-gate history (4 rounds, verify.md `## Codex Gate Findings`)

Round 1: 3×P1 (CI push-vs-pull_request scoping; unanchored `none` match;
single-layout YAML parse). Round 2: 2×P1 residuals (marker anywhere-in-line;
zero-row silent pass). Round 3: 1×P1 residual (missing/misspelled
`couplings:` key bypasses enforcement). Round 4: **PASS, no novel
findings** — loop closed. All findings fail-closed on ambiguous/malformed
input; each independently re-verified live against HEAD, not carried over
from a prior worker's word (verify.md cycle-2/3/4 re-verification tables).

### Self-application note

This PR's own diff satisfies `doc-impact-gate` — both coupling rows named in
the ship checklist are touched:

```
$ command git diff --name-only origin/main...HEAD > /tmp/changed-files.txt
$ bash plugins/ship-flow/bin/doc-impact-gate.sh --changed=/tmp/changed-files.txt --declaration=""
PASS reference-schema-readme: coupled doc touched
PASS checker-source-map: coupled doc touched
```
Exit 0. `reference-schema-readme` (`references/*.yaml` → README.md):
`references/doc-coupling-map.yaml` changed, `README.md` touched.
`checker-source-map` (`bin/*.sh` → `references/doc-sync-context.md`):
`bin/doc-impact-gate.sh` + `bin/canonical-doc-sync-checker.sh` changed,
`references/doc-sync-context.md` touched (T2.4, `885ea61`).

### Full local gate re-run (this session, HEAD `90f4706`)

- `CI=true bash plugins/ship-flow/bin/check-invariants.sh` → only the 2
  known historical C14 lines (`695addea`, `0d0ca53e`, both pre-date this
  entity's design/plan/execute commits) — no other FAIL/WARN.
- Shell suite (`lib/__tests__/test-*.sh`, from repo root, `CI=true`):
  103 total, 101 pass, 2 fail — `test-archived-corpus-invariants.sh` +
  `test-merged-pr-closeout-reconciler.sh`, both the same 2 pre-existing
  failures independently confirmed identical at base and HEAD in verify.md
  (unrelated stale doc-string assertion; not a regression from this entity).
- Node suite: `node --test plugins/ship-flow/bin/*.test.mjs` → 79/79 pass.
- `bash scripts/check-version-triple.sh` → PASS (0.8.2 triple match).
- `bash scripts/check-no-dangling.sh` → PASS (8 patterns).
- `command git diff --check origin/main...HEAD` → clean.
- `validate-tdd-ledger.py --plan plan.md --require-ledger-jsonl
  tdd-ledger.jsonl` → `status=pass records=7`.

### Release note

New checker + CI gate = **minor**-version candidate (0.8.2 → 0.9.x) for the
NEXT plugin release. Not bumped this PR (see review.md `## Release
Consideration`).
