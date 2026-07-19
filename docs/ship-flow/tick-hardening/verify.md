# Tick hardening — Verify (cycle 2, final)

Cycle 1 (verify.md@856b4cf) VETO'd on three BLOCKING findings routed to
execute. Feedback cycle 1 landed three atomic fixes (`9f8957c` B2/B3,
`3a29309` B1, `6ee6867` W1) + docs (`379c8b3`/`019e723`). This cycle
independently re-verifies each fix firsthand — RED re-proven against the
pre-fix source, GREEN confirmed, live PoC re-run — not taken on the worker's
self-report. All three BLOCKING findings are genuinely fixed. **Round cap
spent**: no new cycles; anything new beyond bounce scope would go
PROMPT_CAPTAIN (nothing did).

## Independent Re-Verification

<details>
<summary>Firsthand fix re-proof detail</summary>

- **B1 injection PoC re-run** (the cycle-1 catch): `--entity
  'foo$(touch /tmp/PWNED_VERIFY)'` through the real adapter via a stub
  `$SPACEDOCK_BIN` → file NOT created; the metacharacter string reached the
  stub as a single literal argv element (echoed verbatim). Four more vectors
  (`;`, backtick, `&&`, `|`) all neutralized. Root cause gone: `SPAWN_ARGV`
  array exec'd directly (adapter.sh:110,142), `bash -c` only on the
  test-author-controlled `SHIP_FLOW_SCHEDULER_RUNNER_CMD` seam.
- **B2/B3 edge cases re-run firsthand** (default 5400): `0m`→5400, `0h`→5400
  (fallback, no `timeout 0` disable), `08m`→480, `09h`→32400, `2h09m`→7740
  (base-10, no octal crash), regression `2h30m`→9000, absent→5400. Root
  cause gone: `10#` forced base-10 + zero-total falls back to default
  (ship-flow-scheduler.sh:110-118); stale N1 comment corrected.
- **W1 re-run firsthand**: claude-only PATH (no spacedock) now fails the
  `--runner gh` preflight closed (exit 3), matching `SPAWN_ARGV`'s
  spacedock-only exec (ship-flow-scheduler.sh:371-382).
- **RED genuinely red pre-fix**: ran the NEW test file against the cycle-1
  (856b4cf) source → exactly 7 failures (1 injection + 1 preflight + 5
  timeout edges), all green post-fix. Legitimate RED-before-GREEN.
- **Gate re-run**: full scheduler suite 10 files 159/159 (NORMAL); adapter
  46/46 + backoff 8/8 + fullcycle 8/8 green in BOTH normal AND CI-sim
  (isolated-timeout-only PATH, `claude`/`spacedock` confirmed absent).
  check-invariants exit 0 (C11/C12/C15 OK), no-dangling PASS, version-triple
  PASS, shellcheck clean on both changed prod files + the test.

</details>

## Per-AC Evidence

- **AC-1 — VERIFIED** (unchanged): `--tick-id` env + delegation prompt line;
  `--print-spawn` now renders the display string via `%q` (adapter.sh:111),
  its `--plugin-dir`/`-p`/`spacedock` assertions still pass.
- **AC-2 — VERIFIED** (B1 resolved): launcher spawn via `SPAWN_ARGV`
  argv-array exec; the cycle-1 injection regression is fixed and
  re-verified. Live launcher probe from cycle 1 stands (mechanism proven).
- **AC-3 — VERIFIED** (B2/B3 resolved): `derive_timeout_sec` base-10 + zero
  fallback; all five cycle-1 boundary inputs re-run correct firsthand.
- **AC-4 — VERIFIED** (unchanged): head-block fix, backoff 8/8;
  `entity_in_backoff` slug-BRE fragility stays a deferred WARNING (W2, not
  triggered).
- **AC-5 — VERIFIED** (unchanged): `@USER_LOCAL_BIN@` plist pin, RUNBOOK.
- **AC-6 — VERIFIED**: dual-env green (with the documented CI-sim caveat —
  plan.md's literal `/usr/bin:/bin` recipe needs a `timeout` symlink on this
  macOS box; real CI is `ubuntu-latest` with native `/usr/bin/timeout`).

## Review Findings

Cycle 2 is a scoped re-review of the bounce fixes (round cap reached), not a
fresh full panel — no new cross-model run by design (the cycle-1
`codex exec` + `pr-review-toolkit:code-reviewer` challenge produced these
findings; this cycle verifies their fixes). All dispositions below are
**verifier-reproduced firsthand**.

| # | Finding (file:line @cycle1) | Cycle-1 sev | Cycle-2 disposition |
| --- | --- | --- | --- |
| B1 | `SPAWN_LINE`/`bash -c` command injection (adapter.sh:99,123) | BLOCKING | **FIXED** `3a29309` — `SPAWN_ARGV` argv exec (adapter.sh:110,142); PoC + 4 vectors re-run, no file created |
| B2 | `derive_timeout_sec` octal crash `08m`/`09h`/`2h09m` (scheduler.sh:110) | BLOCKING | **FIXED** `9f8957c` — `10#` base-10 (scheduler.sh:116); 480/32400/7740 correct firsthand |
| B3 | `derive_timeout_sec` `0m`/`0h`→`timeout 0` disables enforcement | BLOCKING | **FIXED** `9f8957c` — zero-total falls back to default (scheduler.sh:117); 5400 firsthand |
| W1 | preflight accepts `claude` but exec is spacedock-only | WARNING | **FIXED** `6ee6867` — preflight spacedock-only (scheduler.sh:379); claude-only PATH → exit 3 firsthand |
| N1 | stale `derive_timeout_sec` comment | NIT | **FIXED** `9f8957c` — comment now describes base-10 + zero-fallback |
| W2 | `entity_in_backoff` slug-as-BRE (scheduler.sh:124) | WARNING | deferred (not triggered by any real slug) |
| W3 | `timeout` lacks `--kill-after` (adapter.sh) | WARNING | deferred (pre-existing repo-wide pattern) |

## Runtime UAT

`runtime_uat`: fixture-level (159/159 scheduler assertions both envs, cited
above) + the cycle-1 real launcher probe receipt (`spacedock claude
--plugin-dir` run live, exit 0, mechanism proven — content declined by the
spawned FO on unrelated grounds, an out-of-scope upstream-binary NIT). The
cycle-2 fixes are pure logic/quoting corrections with no new runtime surface
beyond the fixture + PoC evidence above. **LIVE proof** (hardened tick
dispatches the held guard-precision entity under launchd) remains **deferred
— FO-owned post-merge**, unchanged from plan.md's handoff.

## Verdict

**PASS (PROCEED) — cycle 2, final.** All three cycle-1 BLOCKING findings
(B1 injection, B2 octal crash, B3 timeout-disable) plus the W1 companion and
N1 NIT are genuinely fixed and independently re-verified firsthand: the exact
cycle-1 injection PoC no longer creates a file, all five `time_budget`
boundary inputs resolve correctly, the claude-only preflight now fails closed,
and the new test assertions were re-proven RED against the pre-fix source
(7/7). Fix scope was tight (2 prod files + 1 test + 1 fixture stub + docs),
nothing beyond bounce scope, W2/W3/carryovers untouched per boundary. Full
gate green: scheduler suite 159/159 dual-env, check-invariants/no-dangling/
version-triple exit 0, shellcheck clean. Nothing new surfaced; no
PROMPT_CAPTAIN needed. Ready for review/ship.

## Panel Coverage

- Tier: B (cycle-1 host-opposite `codex exec` cross-model challenge, NOT
  degraded, produced the findings now fixed; cycle 2 is a scoped
  fix-verification inside the round cap — no new cross-model run by design).
  `panel_coverage: reduced`, deepened past a typical Tier-B scan: the verifier
  directly reproduced every fix (RED-against-old, PoC re-run, edge-case
  re-run), not just cited the worker's report.
- Pass ownership: verify_agent_worker_ownership PASS; workflow_ci PASS
  (159/159 dual-env + invariant/dangling/version gates); cross_model_challenge
  PASS (cycle-1 codex, findings fixed); silent_failure PASS (B2/B3 were this
  class, now fixed + firsthand re-verified); security PASS (B1 injection
  fixed, PoC + 4 vectors re-run clean); test_adequacy PASS (13 new assertions
  covering exactly B1-B3/W1's inputs, RED-proven); runtime_uat PASS (fixture +
  cycle-1 live probe); type_design NO_FINDINGS; api_contract not_triggered;
  ui_design not_triggered; domain_intent not_triggered

## Deferred to TODO

- W2: `entity_in_backoff` slug-as-BRE — harden to literal-match (`grep -F` or
  anchor+escape); not currently triggered by any real slug.
- W3: `timeout` lacking `--kill-after` — pre-existing repo-wide adapter
  pattern; Task 5's 900→5400s default bump raises the blast radius, worth a
  repo-wide follow-up.
- Carryover (unchanged): AC-4 precedence-2 dispatch-repeat test coverage;
  `decisions.md` 30-min clause removal + ROADMAP Later-row fold (both
  `iamcxa/muscat-v1`, cross-branch, FO-owned).
