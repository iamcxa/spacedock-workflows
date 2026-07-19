---
title: Guard qualifier precision — W1-W5 robustness follow-ups
status: shape
source: hackathon-2 Wave 2a (todo no-dangling-guard-qualifier-precision; #71 verify Deferred to TODO)
started: 2026-07-19T16:04:46Z
completed:
verdict:
score:
worktree:
issue: "#75"
pr:
---

Time budget: 1h15m. Harden the mislocated-canonical-mod resolver shipped in #71 against future
content: W1 bare `override` qualifier over-broad; W2 logical-unit scan stops at self-contained
list-item starts; W3 broaden qualifier allowlist (if present / falls back to / defaults to the
plugin copy); W4 `|| true` on grep -c at check-no-dangling.sh:300; W5 fixture cases 6/7 named
for what they exercise. THIS ENTITY IS TICK-DISPATCHED (hackathon-2 live proof of the hardened tick).

## Acceptance criteria

**AC-1 — Precision.** W1+W2+W3 fixed: the qualifier match is scoped/proximity-bound, the unit scan
respects list-item boundaries, the allowlist covers the three named phrasings; each with a RED
fixture that previously mis-fired.
Verified by: extended test-check-no-dangling.sh red-then-green per case.

**AC-2 — Robustness.** W4+W5 fixed (pipefail-safe grep -c; fixtures renamed to match behavior).
Verified by: suite run + fixture names greppable.

**AC-3 — No regressions.** Full local gate green (both envs).
Verified by: dual-env run output.

## Shape verification (lean) — 2026-07-20

**Size:** S. **Time budget:** 1h15m (from body). **Captain articulation:** hackathon-2 GO +
bulk attestation 「原則上是都核准」(2026-07-20) — accepted, not re-asked.

**Source of truth = `origin/main`.** The mislocated-canonical-mod resolver (all W1–W5 targets)
shipped in #71 (`39e36d3`) and lives ONLY on `origin/main`:
- `scripts/check-no-dangling.sh` (312 lines; resolver at 135–250)
- `plugins/ship-flow/lib/__tests__/test-check-no-dangling.sh` (223 lines; 9 fixture cases)

The muscat state branch `iamcxa/muscat-v1` is 233 commits behind origin/main; `39e36d3` is NOT in
its ancestry; its working-tree `scripts/check-no-dangling.sh` is the pre-#71 177-line copy (resolver
absent) and the test file is untracked. **EXECUTION PREREQUISITE: design/plan/execute MUST base the
code worktree on `origin/main`, not on `iamcxa/muscat-v1`.** All file:line citations below are
against origin/main.

**Per-W verification (all 5 CONFIRMED real):**

- **W1 — bare `override` over-broad → FALSE NEGATIVE. CONFIRMED.**
  `check-no-dangling.sh:236` — the qualifier allowlist ends with a bare, unanchored `|override`
  alternative (grep -E substring). Any logical unit containing "override" anywhere (incl.
  "overridden"/"overrides"/an unrelated sentence) suppresses the violation → a genuinely-dangling
  twin-only ref goes unflagged. Fix: keep only specific legitimate phrases. No existing GREEN fixture
  relies solely on bare `override` (case 2 = "adopter override"+"when present"; 3/4 = "if a workflow
  override exists"; 6 = "if the repo has"), so removal is regression-safe.

- **W2 — logical-unit scan drops the list-item marker line → FALSE POSITIVE. CONFIRMED.**
  `_mislocated_mod_logical_unit` backward scan (`check-no-dangling.sh:157–164`) breaks when the
  *previous* line is a list-item/numbered start (`:160–161`), leaving `s` at the line AFTER the
  marker — the marker line is excluded from the unit. When the ref is on a continuation line and the
  adopter-optional qualifier is on the marker line, the qualifier is unseen → a legitimately-optional
  ref is wrongly flagged. Fix: extend the unit up to and INCLUDING its owning list-item marker line.

- **W3 — allowlist misses three real phrasings → FALSE POSITIVE. CONFIRMED.**
  `check-no-dangling.sh:236` covers "when present / if a workflow override exists / if the repo has /
  otherwise the plugin copy / adopter override". Missing: **"if present"** (only "when present"),
  **"falls back to"**, **"defaults to the plugin copy"** (only "otherwise the plugin copy"). Fix: add
  these three, coordinated with W1 scoping (a curated phrase list, no bare-substring terms).

- **W4 — `grep -c` missing `|| true` under pipefail → LATENT, not active. CONFIRMED-latent.**
  `check-no-dangling.sh:300` `mislocated_count=$(printf … | grep -c …)` has no `|| true`; under
  `set -euo pipefail` (`:23`) a zero-match grep -c exits 1 → pipefail → set -e aborts. Currently
  unreachable: the line runs only when `mislocated_status -ne 0` (`:299`), which by construction
  (`:246` returns 1 iff ≥1 echoed VIOLATION at `:242`) guarantees ≥1 match. So it never fires today —
  a real latent trap against output-prefix drift/refactor, NOT an active bug (matches AC-2
  "Robustness" framing). Sibling `test-check-no-dangling.sh:144` already has `|| true` on the
  identical grep — fix = make `:300` consistent.

- **W5 — fixture cases 6/7 mis-named. CONFIRMED.**
  `test-check-no-dangling.sh`: case 6 `build_case6_agents_override`/"GREEN-agents-override"
  (`:86–93`, `:189`) actually exercises the **"if the repo has"** qualifier — "agents" appears
  nowhere in the fixture. Case 7 `build_case7_json_noise`/"GREEN-json-noise" (`:95–108`, `:190`)
  actually exercises **constraint (a): backtick-fenced-only** — a double-quoted JSON path is never
  matched by the `` `docs/…` `` grep. Fix: rename both to their load-bearing behavior.

**AC ↔ RED-fixture mapping** (AC-1 "each with a RED fixture that previously mis-fired"):
- W1 → new RED: unit with bare "override" but a mandatory (non-optional) twin-only ref → current code
  GREEN (wrong), must become a violation.
- W2 → new RED: multi-line list item, ref on continuation line + qualifier on the marker line →
  current code exit 1 (wrong), must become exit 0.
- W3 → new RED ×3: refs qualified by "if present" / "falls back to" / "defaults to the plugin copy" →
  current code exit 1 (wrong), must become exit 0.
- Existing cases 1–9 stay green (regression guard). Keep the uniform assertion-count invariant (test
  header: identical count RED-skip vs GREEN — only PASS/FAIL flips).

**AC-3 "both envs":** the resolver is POSIX-ERE / no-`-P` by design (`:189–190`) for BSD/macOS +
GNU/Linux grep parity, and W4 is a pipefail/CI-only failure class — so "both envs" = run the suite +
gate under both grep flavors / shells the repo targets (exact enumeration → plan's runtime-detect).

**Out of scope:** anything beyond W1–W5; the upstream spacedock binary; third-party deps; the
branch-divergence topology itself (surfaced here only as the origin/main worktree-base prerequisite).

## Stage Report: shape

- DONE: absorb + verify each typed AC claim against the REAL current files on origin/main, cite file:line
  W1–W5 all CONFIRMED against origin/main `scripts/check-no-dangling.sh` + `test-check-no-dangling.sh`; citations in "Shape verification" section (W1/W3 :236, W2 :157–164, W4 :299–300, W5 test :86–108/:189–190).
- DONE: captain articulation already given — do NOT re-ask
  hackathon-2 GO + bulk attestation 「原則上是都核准」recorded; not re-asked.
- DONE: record the entity's time_budget from the body
  1h15m recorded in Shape verification.
- DONE: out-of-scope declared
  Beyond W1–W5; upstream spacedock binary; third-party deps; branch topology.
- DONE: disproof where an AC diverges from reality (disproof beats compliance)
  W4 reclassified CONFIRMED-latent — guarded at `:299`, never fires today; kept in-scope per AC-2 "Robustness" (fragility, not active bug). W1–W3, W5 are active mis-fires.

### Summary
Lean S-shape: all five hardening claims (W1 over-broad `override`, W2 list-item marker drop, W3 missing "if present"/"falls back to"/"defaults to" phrasings, W4 pipefail-fragile `grep -c`, W5 mis-named fixtures 6/7) verified real against origin/main with file:line citations. Key load-bearing finding: the resolver under audit exists ONLY on origin/main (shipped #71 `39e36d3`), and the muscat branch `iamcxa/muscat-v1` is 233 commits behind and lacks it — design/plan/execute MUST base the code worktree on origin/main. Added an AC↔RED-fixture map (W1/W2 one red each, W3 three) preserving the uniform assertion-count invariant. Only nuance: W4 is a latent trap (guarded), not an active bug — hardening still warranted.
