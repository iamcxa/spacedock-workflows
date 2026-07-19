# Missing canonical mods — author or de-reference (both tiers) — Design

### Summary

Contract-bearing (NOT trivial-pass): one new mod **content contract**
(`docs/ship-flow/_mods/canonical-doc-sync.md`, 13 grep-pinned tokens), three
SKILL/INVARIANTS/template **prose de-references**, and one **code-gate** delta
(a `missing-everywhere-canonical-mod` branch in the #71 resolver + fixture).
Baseline is origin/main's 312-line resolver — verified present in this seeded
worktree (`scripts/check-no-dangling.sh` = 312 lines, HEAD 0 behind origin/main),
so shape's BLOCKING baseline risk is **resolved by the seed**. Two design findings
change scope vs the shape and are flagged for the gate: (F1) the class guard
mechanically surfaces a **third** missing-everywhere mod, `decisions-log.md`, that
must be de-referenced for repo-green; (F2) the guard must exclude the resolver's
own contract-test fixtures (`foo`/`bar`) or case9 self-reds.

### Design-vs-trivial-pass decision (checklist item 1)

**Full design.** Trivial-pass is rejected: the work adds a new mod content
contract pinned by 14 string assertions across two integration tests, changes
prose that a code gate reads, and extends `run_mislocated_canonical_mods()` with a
new violation class — the stage-def's "contract-bearing → dispatch a designer"
path, not "pure mechanical".

### AC-1 — per-reference decisions + contract deltas (checklist item 2)

Every backtick-fenced `` `docs/ship-flow/_mods/<name>.md` `` ref in
`plugins/ship-flow/` plus the one non-fenced echo, with existence verified
(adopter = `docs/ship-flow/_mods/`, twin = `plugins/ship-flow/_mods/`):

| ref (file:line) | mod | adopter/twin | decision | post-edit resolver state |
|---|---|---|---|---|
| ship-shape/SKILL.md:596 | architecture-canon | N / N | **de-ref** | ref gone |
| ship-plan/SKILL.md:501 | architecture-canon | N / N | **de-ref** | ref gone |
| _mods/migrate-debrief-vN-to-vN+1.md.template:33 | architecture-canon | N / N | **de-ref** (non-fenced, out of pattern reach) | n/a — guard never saw it |
| INVARIANTS.md:199 | **decisions-log** (F1, discovered) | N / N | **de-ref** | ref gone |
| ship-review/SKILL.md:24,29,156,461 | canonical-doc-sync | N→**Y** / N | **author (adopter path)** | Cond 1 skips (adopter now present) |
| references/doc-format.md:3 | canonical-doc-sync | N→**Y** / N | (same author) | Cond 1 skips |

**De-reference** (architecture-canon ×3 + decisions-log ×1): all bibliographic
"References" bullets / `(see …)` pointers — **no live consumer, no test asserts
their content** (grep of `lib/__tests__/` for both names = 0 hits). Execute may
either remove the bullet/parenthetical OR re-point to an existing mod file; the
only constraint is *post-edit no ref points at a nonexistent file*. For
migrate-debrief:33 (a `.md.template` echo `plugins/ship-flow/_mods/architecture-canon.md`)
the ref must resolve to a real file or be dropped — it is **outside** the resolver's
backtick-fenced-adopter-path pattern, so AC-1 owns it, not the guard.

**Author** canonical-doc-sync at the **adopter path** `docs/ship-flow/_mods/canonical-doc-sync.md`
(reverse-recovery EXISTS_BROKEN, single missing seam): ship-review:156 is an
unconditional live instruction and two integration tests hard-assert the file +
its content. Plugin-path authoring is rejected (would make the #71 resolver flag
every adopter-path ref as *mislocated*). Adopter-path authoring resolves all six
refs via Cond 1 and adds no new resolver flag (the adopter file itself is not
scanned).

#### canonical-doc-sync.md content contract (author-minimal — the tests ARE the spec)

The mod must contain, as grep-visible text, exactly these tokens (source =
`test-canonical-doc-sync-mod.sh` unless noted):

1. `ARCHITECTURE.md`, `PRODUCT.md`, `ROADMAP.md`  (Block 1)
2. `architecture-impact` and `durable architecture`  (Block 2)
3. `prompt text` and `workflow reports`  (Block 2, the "skip internal-only" rule)
4. `Hook: umbrella-closeout`  (Block 3 — also the anchor ship-review:156 reads)
5. `last open child`  (Block 3)
6. `exactly once for the parent umbrella`  (Block 3)
7. one **single line** matching `PRODUCT.md.*exactly once for the parent umbrella` (Block 3, `grep -q` regex — PRODUCT closeout on capability change)
8. `follow-up PR`  (Block 3)
9. `Silent omission`  (`test-canonical-context-lifecycle.sh:62`)

Recovery-phrasing prior art: `docs/ship-flow/_archive/1-self-adoption-dogfood-bootstrap`.
Block 4 of `test-canonical-doc-sync-mod.sh` asserts tokens in **other** files
(ship-review `umbrella closeout`, `entity-body-schema.yaml` `umbrella_closeout`,
`doc-format.md` `Umbrella Shipped Row` / `Architecture Patch` / `durable
architecture change`) — **all five verified already present**, so authoring the
mod alone greens the tier. Execute must **not** touch those five surfaces.

### AC-2 — guard extension (the code gate; checklist item 2)

The #71 resolver flags a backtick-fenced adopter-path ref only when the plugin
twin **exists** (`check-no-dangling.sh:229` `[[ ! -f "$plugin_path" ]] && continue`).
Missing-everywhere = adopter absent **and** twin absent → currently skipped. Delta:

**(a) Classify by twin presence instead of `continue`-on-no-twin** (replaces
lines 225-244 logic). After Cond 1 (`adopter present → skip`):

```
if [[ -f "$plugin_path" ]]; then
  label="mislocated-canonical-mod"        # adopter absent, twin present (unchanged class)
else
  # missing-everywhere: adopter absent AND twin absent.
  # Guard (F3): only fire when the adopter tree is present — a plugins-only
  # extraction ships neither file and must stay green (preserves #71 clone-safety).
  [[ ! -d "${root}/docs/ship-flow/_mods" ]] && continue
  label="missing-everywhere-canonical-mod"
fi
# Cond 3 (qualifier) applies to BOTH classes — reuse _mislocated_mod_logical_unit + vocab.
```

**(b) Exclude the resolver's own contract test from the grep** (F2): add
`--exclude-dir=__tests__` to the resolver grep at line 193. The heredoc fixtures
`` `docs/ship-flow/_mods/foo.md` `` / `` bar.md `` live in
`lib/__tests__/test-check-no-dangling.sh`; they are missing-everywhere synthetic
data, not real refs, and would red case9 (the real-repo scan) without this. Safe:
the mislocated class never depended on scanning `__tests__` (those fixtures have no
real twin), and scratch-tree cases have no `__tests__` dir. This is surgical —
added to the resolver grep only, NOT to the shared `EXCLUDE_DIRS` the denylist uses.

**(c) Count the new label in the normal-run aggregator** (line 300):
`grep -c '…\[mislocated-canonical-mod\]'` → `grep -cE '…\[(mislocated|missing-everywhere)-canonical-mod\]'`.

Coverage boundary (verbatim from shape, confirmed): the resolver matches only
backtick-fenced `docs/ship-flow/_mods/<name>.md` (line 193) — the non-fenced
plugin-path echo at migrate-debrief:33 is out of reach and is handled by AC-1.

### AC-3 — real-repo green-set (what the guard must NOT flag, verified by enumeration)

Every backtick-fenced adopter-path mod ref on origin/main, post-AC-1:

| mod | adopter | twin | fires? | why safe |
|---|---|---|---|---|
| canonical-doc-sync | **Y** (authored) | N | no | Cond 1 |
| pr-merge | Y | N | no | Cond 1 |
| contribution-contract | N | Y | no | mislocated class, but twin present + qualifier/N-A — already green today |
| reverse-recovery-audit | N | Y | no | twin present; qualified "when present" |
| science-officer-em | N | Y | no | twin present |
| architecture-canon | N | N | no | **refs removed by AC-1** |
| decisions-log | N | N | no | **ref removed by AC-1 (F1)** |
| foo / bar (test fixtures) | N | N | no | `--exclude-dir=__tests__` (F2) |

Dual-env proof (AC-3): (1) CI full-suite runs `plugins/ship-flow/lib/__tests__/test-*.sh`
+ `bash scripts/check-no-dangling.sh` from repo root against the full tree
(`ship-flow-invariants.yml:110,136`) → GREEN after the above. (2) dogfood
integration tier runs `integration/test-*.sh` → GREEN once the mod is authored
(currently RED **only** because the file is absent — shape proved live).

### Test surfaces that must move (checklist item 3 — string-assertion tests that pin changing text)

- **`lib/__tests__/test-check-no-dangling.sh`** — resolver contract. `assert_case`
  counts only `[mislocated-canonical-mod]` (line 144); generalize it to count both
  labels (or the new case asserts the new label). **Add** a RED missing-everywhere
  fixture (unqualified backtick ref to a mod absent in both tiers → exit 1, 1
  violation) — its builder MUST `mkdir -p docs/ship-flow/_mods` in the scratch tree
  so Guard F3 fires — plus a GREEN qualified-variant. `case9` (real-repo, line 159)
  is the binding **repo-green** assertion and must stay exit 0.
- **`integration/test-canonical-doc-sync-mod.sh`** — 14 checks; Blocks 1-3 (9 checks)
  are the mod content spec above; Block 4 (5 checks) pins pre-existing wiring — do
  not disturb.
- **`integration/test-canonical-context-lifecycle.sh`** — line 62 `grep 'Silent
  omission'` is the only mod assertion; the rest pin existing lifecycle wiring.
- No `test-*.sh` asserts the prose of the four de-referenced bullets (grep of
  `lib/__tests__/` for `architecture-canon` / `decisions-log` = 0 hits) → de-refs
  move no string test.

### Design findings flagged for the gate

- **F1 (scope +1):** the class guard is only honest if class-wide; that surfaces
  `decisions-log.md` (INVARIANTS.md:199), a bibliographic missing-everywhere peer
  the sibling rra design already noted "excluded by cond 2". Folded in as a
  one-line de-ref under AC-1's existing rule. A hardcoded allowlist excluding it
  would be a fake guard (rejected). **Gate may bounce** if the captain wants
  decisions-log deferred — then the guard must instead gain a documented deferral,
  not a silent skip.
- **F2 (correctness, required):** `--exclude-dir=__tests__` on the resolver grep —
  without it the new branch reds case9 on the test's own foo/bar fixtures.
- **F3 (defensive, recommended):** the adopter-tree-present guard preserves #71's
  plugins-only-clone green invariant; it couples to the RED fixture (must scaffold
  `docs/ship-flow/_mods/`). Drop only if the gate decides check-no-dangling is
  explicitly dogfood-host-only.
