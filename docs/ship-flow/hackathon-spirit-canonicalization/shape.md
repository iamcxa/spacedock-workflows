# Hackathon spirit canonicalization — Shape

### Summary

Land the hackathon time-box discipline — the one process rule that proved
load-bearing across both hackathon nights — into this repo's durable canon
(plugin INVARIANTS + workflow task template), so any session on any machine
inherits it from the repo instead of from machine-local `.context` contracts
or debrief prose. Size **S**, docs-only; appetite one worker session.
Deliberately chosen as the Mac mini line's first dispatched ticket: its
deliverable IS the "land necessary local memory into repo memory" directive
(captain, 2026-07-20), and a docs ticket carries zero risk to the R2/R1/
roborev critical path running locally in parallel.

### Captain articulation — from standing directives, not re-asked

- 「時間盒紀律 = ship-flow 預設精神:每票帶 time_budget,75% 警告、100% 煞車
  (park + surface,永不壓縮驗證)」 (captain queue directive, 2026-07-20)
- 「stretch:hackathon-spirit 正典化票(時間盒紀律進 INVARIANTS/FO 契約)」
  (captain queue item 6)
- 「批准五張新票,這批都核准」 (captain batch approval, 2026-07-20; issue #86
  sd:approved)
- 「要確保 mini 那邊有本機的必要記憶,或是把本機的必要記憶落到 repo 記憶中」
  (captain mini-line directive, 2026-07-20 — this ticket is the repo-memory
  half of that directive)

### Problem — evidence from two nights

The time-box discipline (per-ticket `time_budget`, 75% in-channel warning,
100% brake = park + surface + cut scope, verification never compressed) fired
correctly twice during hackathon-2 (debrief 2026-07-20-01: "2 time-box
brakes", finale parked with findings instead of compressed verification) and
is cited as a hard rule in `.context/hackathon-2-contract.md` — a
machine-local, gitignored file. A fresh session on this machine after context
loss, or ANY session on the Mac mini, cannot inherit the rule: the mini's
clone carries the repo canon only. The two-night operational record shows the
rule changes outcomes (scope was cut at 100% twice; verification was never
compressed); losing it to machine-locality is a real regression channel.

### Acceptance criteria (mechanism paired to value)

- **AC-1 — The time-box rules are repo-canonical.** The plugin's canonical
  contract surface (`plugins/ship-flow/INVARIANTS.md`, or the FO-contract
  section design designates) states: every entity carries a `time_budget`;
  at 75% consumed the runner warns in-channel; at 100% the brake fires =
  park + surface + cut scope; verification is NEVER compressed to fit a
  budget. *Prevents:* a fresh session (local or mini) re-deriving or
  silently dropping the discipline. **Verified by:** `grep -n
  "time_budget\|75%\|brake" plugins/ship-flow/INVARIANTS.md` hits the rule
  with exact brake semantics; doc review confirms park-not-compress wording.
- **AC-2 — New entities are born with budgets.** The workflow task template
  (`docs/ship-flow/README.md` Feature Template, and the plugin
  workflow-template if design finds it authoritative) carries a
  `time_budget` slot with a one-line semantics pointer. *Prevents:* the rule
  existing in prose while entities keep being filed without budgets.
  **Verified by:** template section diff shows the field + pointer.
- **AC-3 — Hackathon learnings distilled into existing canon, not an orphan
  doc.** The two-night learnings worth keeping (time-box outcomes, brake
  precedents with debrief citations) land as edits to EXISTING canonical
  docs; no new standalone "learnings" file. *Prevents:* canon fragmentation
  (the doc-rot failure mode). **Verified by:** diff touches only existing
  canon files (INVARIANTS/README/PRODUCT-scoped per design); `git status`
  shows no new top-level doc.

### Stated assumptions

- A1 (critical, 85%, verified_by: codebase-grep at plan): INVARIANTS.md is
  the right canonical surface for FO-contract process rules (it already
  carries Principle-numbered process contracts the skills cite). Disproof
  hook: if INVARIANTS turns out to be plugin-internal-only and adopter
  process rules belong in the workflow README, design redirects the target
  file — scope unchanged.
- A2 (important, 90%): docs-only is enough for this slice; a code gate
  (budget field validation / runner warning hook) is a follow-up. Captured
  as rabbit hole below.

### Rejected alternatives

- **Code-gate enforcement in this slice** (budget validation in
  check-invariants, 75% warning in the scheduler) — rejected for THIS ticket:
  S/docs appetite, and the enforcement seam belongs with the scheduler
  hardening line. Filed as rabbit hole `time-budget-code-gate`.
- **New standalone HACKATHON-LEARNINGS.md** — rejected: canon fragmentation;
  AC-3 pins distill-into-existing.

### Pre-mortem (wrong-dcs)

The prose lands and greps pass but no runner or session actually reads the
canonical rule at run time — value depends on sessions loading INVARIANTS,
which the FO contract does; if a future runner skips it, only the code-gate
rabbit hole closes that.

### Design hand-off

- `affects_ui: false`; no domain registry in this repo; no schema change;
  no contract decision — target-file choice (A1) is the only open question
  and it is a placement decision, not a contract grammar. **Design =
  trivial-pass fast-path expected** (Phase 0, minimal design.md + verdict
  PROCEED, per README design stage).
- `open_contract_decisions: []`
- Rabbit hole to file on confirm: `time-budget-code-gate` — enforce
  time_budget presence/warning mechanically (scheduler or check-invariants
  seam).

### Mini-line dispatch note (FO)

This entity's design→plan→execute legs run headless on the Mac mini
(gui-domain launchd one-shot; auth verified 2026-07-20), gates resolved by
the local FO — the captain-directed 「macmini 派工,本機 review」 proving
line. The entity body is self-contained for that purpose: no `.context`
machine-local reads are required by any stage.
