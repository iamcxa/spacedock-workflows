# Tick hardening — Verify (cycle 1)

Independent re-verification of execute.md's 9-task diff (`97cb9b5..64ae2f6` +
`9a28831` fix + `9312242`/report commits). Re-ran every gate fresh in this
worktree rather than trusting execute.md's self-report; found real regressions
execute.md's own dual-env-green claim did not surface.

## Independent Quality Gate Re-Run

<details>
<summary>Full re-run detail</summary>

- 9 scheduler files, NORMAL env: adapter 33/33, backoff 8/8, reconcile 16/16,
  fullcycle 8/8, eligibility 34/34, idempotence 11/11, plist 11/11, report
  10/10, rollup 8/8 — 139/139, all exit 0.
- CI-sim (4 CI-sensitive files): plan.md's literal `PATH=/usr/bin:/bin` recipe
  is NOT reproducible on this macOS box — `timeout` (GNU coreutils) lives
  under `/opt/homebrew/bin`, absent from `/usr/bin:/bin`, so the literal
  recipe false-fails 22/33+ across all four files (pre-existing repo-wide
  property, not introduced by this diff — real CI is `ubuntu-latest`, which
  ships `/usr/bin/timeout` natively). Rebuilt a faithful sim: an isolated
  PATH dir holding only a `timeout` symlink + `/usr/bin:/bin`, confirmed
  `claude`/`spacedock` both absent — adapter 33/33, backoff 8/8, reconcile
  16/16, fullcycle 8/8, matching execute.md's claim exactly.
- Full suite: 130/130 files, 129 within the 90s CI cap;
  `test-merged-pr-closeout-reconciler.sh` re-run at 300s → 198/198 (untouched
  by this diff, confirmed via `git diff --stat`). node 79/79.
  `check-invariants.sh` exit 0 (C15 OK post-fix). `check-no-dangling.sh` PASS
  (8 patterns). `check-version-triple.sh` PASS. `shellcheck` 0.11.0 clean on
  all 6 changed `.sh` files + the fixture stub. `git diff --check` clean.
- Deviation #1 (plan.md C15 collapse) spot-checked: Task/DC/exact-command
  heading count identical before/after (19=19) — reformat only, no content
  dropped. Deviation #2 (ROADMAP wording) spot-checked: entity has since
  advanced past `execute` to `verify`, so the row is one stage stale again —
  same staleness pattern `7-review-surface-shape-not-plan`'s row already
  shows; FO-owned hygiene, not this diff's contract.

</details>

## Per-AC Evidence

- **AC-1 — VERIFIED.** `--tick-id` sets `SHIP_FLOW_SCHEDULER_TICK_ID` +
  appends the delegation prompt line (adapter.sh:61-67,79-87); re-run
  `run_tick_id_marker_case`, `run_print_spawn_delegation_case`,
  `run_tick_threads_tick_id_case` — all pass.
- **AC-2 — VERIFIED mechanically, WARNING on safety (see Review Findings
  #1).** Launcher spawn confirmed live: `spacedock claude "<prompt>"
  --plugin-dir <worktree>/plugins/ship-flow -- -p --output-format text` run
  twice, both exit 0 with real FO responses (the actual launcher, not the
  adapter's hermetic path). Probe content was refused by the spawned FO's
  own judgment (unrelated to this diff — see Runtime UAT); the spawn
  mechanism itself is proven live.
- **AC-3 — NOT VERIFIED (BLOCKING, see Review Findings #2/#3).**
  `derive_timeout_sec` (ship-flow-scheduler.sh:97-111) has two reproduced
  boundary bugs untested by Task 5.
- **AC-4 — VERIFIED with a narrower WARNING.** Head-block fix reproduced
  (`run_head_block_skip_past_case`, `run_window_expiry_case` both pass,
  8/8); `entity_in_backoff`'s slug-matching is a WARNING (Review Findings
  #5).
- **AC-5 — VERIFIED.** `@USER_LOCAL_BIN@` placeholder present in the tick
  plist (plist.sh:11/11); RUNBOOK updated.
- **AC-6 — VERIFIED** (with the CI-sim reproducibility caveat above).

## Review Findings

Cross-model challenge (REQUIRED, host-opposite): `codex exec` (codex-cli
0.144.1, gpt-5.6-sol), read-only sandbox, against `97cb9b5..HEAD`. NOT
degraded. General-external-reviewer baseline: `pr-review-toolkit:code-reviewer`
(sonnet), same diff. Both independently found the same two `derive_timeout_sec`
bugs; the reviewer additionally proved #1 with a live PoC. All three below are
**verifier-reproduced firsthand**, not taken on citation alone.

| # | Finding (file:line) | Source | Severity | route_to |
| --- | --- | --- | --- | --- |
| B1 | `SPAWN_LINE` built via string interpolation then re-parsed by `bash -c` (adapter.sh:99,123) — a real regression vs. the prior direct-argv `claude -p "/ship ${ENTITY}"` call. PoC: `--entity 'foo$(touch /tmp/PWNED_VERIFY)'` through the real adapter → file created. `ENTITY` is an unsanitized folder `basename` (ship-flow-scheduler.sh:144-146) | codex + code-reviewer, PoC verifier-reproduced | **BLOCKING** | execute |
| B2 | `derive_timeout_sec`: `time_budget: 08m`/`08h`/`2h09m` (leading-zero component) → bash arithmetic treats it as octal → crash, empty stdout, exit 1 (ship-flow-scheduler.sh:110). Verifier-reproduced: `bash: 08: value too great for base`. Empty result flows into `--timeout ""`, adapter usage-errors, entity blocked with a generic `run-error` — root cause never surfaces | codex + code-reviewer, verifier-reproduced | **BLOCKING** | execute |
| B3 | `derive_timeout_sec`: `time_budget: 0m`/`0h` returns `0`; GNU `timeout 0` **disables** the timeout entirely (verifier-confirmed: `timeout 0 sleep 3` ran to completion). A "zero budget" typo produces an *unbounded* run — the exact opposite of AC-3's intent, and untested | codex + code-reviewer, verifier-reproduced | **BLOCKING** | execute |
| W1 | Preflight (`ship-flow-scheduler.sh:371-374`) accepts `claude` OR `spacedock`, but `SPAWN_LINE` unconditionally uses `spacedock` (no wired fallback despite the comment claiming one). Verifier-reproduced: claude-only PATH passes preflight, then dispatch fails with `spacedock: command not found` misclassified as generic `run-error`. Mitigated in real launchd deployment by AC-5's `$SPACEDOCK_BIN` pin | codex, verifier-reproduced | WARNING | execute |
| W2 | `entity_in_backoff`'s `grep "\"entity\":\"${slug}\""` (ship-flow-scheduler.sh:124) treats slug as a BRE, not literal — a slug with regex metachars could false-match another entity's line. Not currently triggered by any real slug in this repo | code-reviewer | WARNING | follow-up |
| W3 | `timeout` has no `--kill-after` (adapter.sh:123) — pre-existing pattern, but the 900s→5400s bump (Task 5) materially raises the blast radius of a TERM-resistant descendant holding the lease | codex | WARNING | follow-up |
| N1 | Stale comment (ship-flow-scheduler.sh:90-96): "returns default UNCHANGED... never invents its own number" is false on the B2 crash path and misleading for B3's `0m` | code-reviewer | NIT | execute (fix alongside B2/B3) |

## Runtime UAT

`runtime_uat`: fixture-level (139/139 scheduler assertions, both envs, cited
above) + a real launcher probe receipt — `spacedock claude` run twice live
against this worktree's own `--plugin-dir`, both exit 0. Both probes were
declined by the spawned FO on content grounds (my ad-hoc smoke-test prompt
read as injection-shaped); one response referenced an "I love you" framing
and an unresolved `{workflow_dir}` placeholder that were never in my actual
prompt — likely model confabulation, possibly a `spacedock claude` boot-prompt
quirk, but the upstream spacedock binary is explicitly out-of-scope
(shape.md) so this is a NIT observation for the FO, not a tick-hardening
finding. **LIVE proof** (hardened tick dispatches the held guard-precision
entity) remains **deferred — FO-owned post-merge**, unchanged from plan.md's
handoff — not attempted here (would require a real `/ship` on live state).

## Verdict

**NOT PASS (VETO) — route_to: execute.** Three BLOCKING findings,
independently reproduced by both a cross-model challenge and a from-scratch
Claude reviewer, converge on two root causes: Task 5's `derive_timeout_sec`
has zero test coverage for zero-value/leading-zero `time_budget` input
(B2/B3), and Task 4's `SPAWN_LINE` rewrite is a confirmed command-injection
regression (B1). All three are mechanical AUTO-FIX-class fixes: (a) validate
`h`/`m` as non-negative base-10 before arithmetic, reject a zero total back
to default; (b) stop re-parsing unsanitized `ENTITY`/`WORKDIR` via `bash -c`
(argv-array exec or sanitize first). W1/N1 are recommended companion fixes
this round; W2/W3 deferred (not required to unblock).

## Bounce Tasks

1. Fix `derive_timeout_sec` (ship-flow-scheduler.sh:97-111): reject/normalize
   leading-zero and zero-total `time_budget` values; add RED cases for
   `0m`, `0h`, `08m`, `09h`, `2h09m` to `test-scheduler-runner-adapter.sh`
   or a scheduler-tick fixture test; fix the stale comment (N1).
2. Fix `SPAWN_LINE` construction (adapter.sh:83-99,123) to not re-parse
   unsanitized `ENTITY`/`WORKDIR` via `bash -c`; add a RED case with a
   shell-metacharacter-bearing entity slug.
3. Recommended alongside (not separately blocking): tighten the preflight
   check (W1) to require `spacedock`/`$SPACEDOCK_BIN` specifically, since no
   raw-`claude` fallback is actually wired.

## Panel Coverage

- Tier: B (host-opposite cross-model ran via `codex exec` directly — not the
  full ship-verify Phase A-H orchestration; `panel_coverage: reduced` for an
  M-sized hardening entity, deepened past a typical Tier-B scan because the
  verifier directly reproduced every load-bearing finding, not just cited
  reviewer output)
- Pass ownership: verify_agent_worker_ownership PASS; workflow_ci PASS (full
  re-run above); cross_model_challenge PASS (codex, NOT degraded);
  silent_failure PASS (B2/B3 are exactly this class, verifier-reproduced);
  security WARNING (B1, verifier-reproduced PoC); test_adequacy WARNING (no
  RED case for any of B1-B3's inputs); runtime_uat PASS (fixture + live
  probe); type_design NO_FINDINGS; api_contract not_triggered (no API
  surface); ui_design not_triggered (no UI); domain_intent not_triggered

## Deferred to TODO

- W2: `entity_in_backoff` slug-as-BRE fragility — harden to literal-match
  (`grep -F` or anchor+escape) when convenient, not currently triggered.
- W3: `timeout` lacking `--kill-after` — pre-existing pattern across the
  whole adapter, worth a repo-wide follow-up given Task 5's default bump
  raises the blast radius; not scoped to this entity alone.
- Carryover (unchanged from execute.md): AC-4 precedence-2 dispatch-repeat
  test coverage; `decisions.md` 30-min clause physical removal + ROADMAP
  Later-row fold (both `iamcxa/muscat-v1`, cross-branch, FO-owned).
