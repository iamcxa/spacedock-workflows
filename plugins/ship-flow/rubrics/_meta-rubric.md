# Ship-flow Meta-Rubric (v2)

> The frame that governs every per-skill rubric. A ship-flow skill's gates/checklists/Done-Criteria
> are a **true rubric** (not prose ceremony) only when they pass the six gates below **and** every
> Tier-A criterion satisfies the Tier-A Validity rules (§Tier-A Validity).
>
> Origin: the 19-skill rubric-ification audit (2026-05-30). The audit's adversarial pass found that
> the *first-draft* version of this frame was itself under-hardened in the same way the skills were —
> it conflated "grep-able" with "mechanically true". v2 closes that with §Tier-A Validity (M1 + M2).
> This is the essay-loop ("sameness → demand for difference") biting one level up: the frame had to be
> hardened by the very thing it was built to harden.

## The six gates

A criterion set is a true rubric when ALL hold. Individual criteria may be one-sided; the rubric as a
whole must cover all six.

- **G1 Discriminating** — the criteria can actually FAIL a real output, not pass-everything. A gate that
  nothing ever fails is sameness/ceremony (evidence: 0% shape-gate reject rate = rubber-stamp drift, the
  reason #109 shipped). Test: name a plausible bad output each criterion catches.
- **G2 Anchored** — each dimension has OBSERVABLE level anchors tied to an artifact, not vibes. Not "good
  plan" but "every task carries a runnable verification command + a tdd-ledger RED→GREEN entry".
- **G3 Eval-backed (incl. negative cases)** — concrete should-PASS examples AND should-NOT-pass /
  should-NOT-trigger examples. The negative cases are where the teeth live. **Write them first** (see §Method).
- **G4 Enforcement-tiered** — each criterion declares Tier A (grep/script/process-evidence) or Tier B
  (design-review question). No criterion may be "the reviewer eyeballs it" without being explicitly Tier B
  with a written question. Tier A criteria must additionally pass §Tier-A Validity.
- **G5 Owned + Falsifiable** — names the human framer-decision it protects (what judgment is silently lost
  if it rubber-stamps) AND a kill/iterate trigger that can disconfirm the rubric itself (cf. Captain Bet:
  "3 consecutive Bet ≠ Outcome → freeze"). A true rubric can fire its own off-switch.
- **G6 Compounding** — names the exact durable store where a newly-found failure mode is written back
  (an INVARIANTS principle / an eval-case file / a success-mode-ledger field) so the rubric improves each
  cycle instead of resetting.

Adapt to skill TYPE; do NOT pad. A short utility skill may need only 2–3 dimensions ("what is n right now").

## Tier-A Validity (the v2 frame fix — M1 + M2)

A criterion may be labelled **Tier-A** only if BOTH hold. Otherwise it is Tier-B-with-a-named-artifact, or
it is not a real gate.

### M1 — Provenance, not just structure

A `grep`/script over an artifact the **skill under review wrote itself** proves the *structure* exists; it
cannot prove the *content is honest or real*. When the same agent both produces the artifact and writes the
attestation token into it, no grep distinguishes an honest attestation from a self-issued rubber stamp.

> Audit evidence: ship-shape (Articulation Trail can be structurally perfect and entirely fabricated);
> ship-plan ("self-issued rubber stamps" — planner writes both plan and token); codex-gate (a fabricated
> `GATE` line passes without codex ever being called); distill-reference (hallucinated `path:line`
> citations survive every grep).

**Rule.** A Tier-A grep target MUST be one of:
1. **(a) a file the skill under review does NOT write** (e.g. ship-execute's commits checked against the
   plan it consumed but did not author), OR
2. **(b) the output of a SEPARATELY-DISPATCHED agent** (e.g. the cross-review summary line, emitted by the
   reviewer teammate per Principle 6 Rule C — not by the stage author), OR
3. **(c) process evidence** — temp-file existence + content + size, a tool-call log, a git object — i.e.
   a side effect the skill cannot fabricate by writing prose into its own output.

A check whose core guarantee depends on the provenance of self-written content (not its structure) must be
reclassified **Tier-B-with-provenance-anchor** (a named review question + the artifact to inspect), or given
a machine-checkable provenance anchor (turn_id, tool-call log). Calling an unfalsifiable provenance check
Tier-A manufactures false confidence — it reads as "mechanically enforced" when it is not.

### M2 — Fixture-verified, not just plausible

A Tier-A label is not awarded to a check command that was never run. Several audit drafts labelled a
dimension Tier-A with a grep that was logically sound but mechanically broken: `grep -c` on a list key vs
list length; a reference to a `--stage=execute` interface that does not exist; a non-existent fixture
directory; `grep -P` on macOS (no PCRE).

**Rule.** Every Tier-A criterion MUST ship with its check command **verified to run against a real fixture**
before the rubric is accepted: `bash -n` for syntax, `which <script>` / `ls <fixture>` for referenced
dependencies, and one actual execution against a known-good and a known-bad input. Portable shell only
(BSD/macOS grep — no `grep -P`).

## Worked instance: the cross-review summary-line contract

The audit's highest-leverage single finding (systemic #2): the 7-factor cross-review verdict — repeated
across ship-{shape,design,plan,execute,verify,review} — was recorded as free prose ("7-factor mostly PASS,
one WARN … verdict PROCEED") with no mechanical threshold. An all-WARN review could PROCEED and nothing
caught it.

**Contract.** The cross-review (a separately-dispatched reviewer — M1 case (b)) emits exactly one canonical
summary line in the stage artifact, alongside the existing prose breakdown + coaching note:

```
cross-review: factors=<N> pass=<p> warn=<w> fail=<f> verdict=<PROCEED|PROMPT_CAPTAIN|VETO>
```

**Check.** `plugins/ship-flow/lib/check-cross-review-threshold.sh <stage-artifact.md>` enforces:
verdict↔factor consistency (fail≥1 or warn≥3 ⇒ PROCEED forbidden), count integrity (pass+warn+fail =
factors, catches pass-inflation), and fail-closed on a missing/malformed line. Tier-A-valid: the line is
separately-authored (M1 (b)); the check is fixture-verified and portable (M2). Tests:
`plugins/ship-flow/lib/__tests__/test-check-cross-review-threshold.sh` (10 cases, negative-case-driven).

**M1 residual limit (documented, not hidden):** the check enforces *consistency* mechanically; it cannot
verify a separate agent actually authored the line. That a real independent review happened remains
Principle 6 Rule C dispatch discipline (Tier B). Mechanical consistency is necessary, not sufficient.

## Method: converting a skill into a true rubric (RED-first, iterable)

Mirrors the tdd-ledger discipline — the negative cases are the RED.

```
Step 0  Harden the frame once     This doc (v2). Do NOT mass-produce per-skill rubrics on a flawed Tier-A def.
Step 1  Write negative cases first  Per skill: the should-NOT-pass / should-NOT-trigger list. Cheapest, highest
                                   leverage; 14/19 skills had ZERO negative cases at audit time.
Step 2  Derive dimensions          Each negative case must map to a dimension that catches it; anchor each (G2),
                                   tier each (G4 + §Tier-A Validity).
Step 3  Adversarial stress-test    Try to rubber-stamp slop through it / false-reject a good output / find
                                   unmeasurable "Tier-A" dimensions. (The audit workflow is reusable as Step 3.)
Step 4  Off-switch                 Name the framer-decision protected + a kill/iterate trigger (G5) + write-back store (G6).
Step 5  Dogfood                    Run it on one real entity before rollout (cf. #117).
Iterate When production leaks       Add one negative case → re-run Step 3 → update the skill rubric or this frame.
```

The **negative-eval-case file is the compounding artifact** (G6): it only grows, like success-mode-ledger.yaml.
A rubric's iterability = whether that list grows on real evidence.

## Forward-only rollout rule (do NOT repeat C14)

Any new Tier-A check is **forward-only by construction**: it FAILs artifacts that predate its contract (e.g.
`check-cross-review-threshold.sh` FAILs every entity lacking the summary line). Wiring such a check into
`bin/check-invariants.sh` naively would trap every pre-contract entity — the exact C14 / Principle-15
body-table failure mode. Rollout MUST reuse the established forward-only exemption pattern (a creation-time
stamp + an exempt-check that skips pre-stamp entities, as `check-harvest-exempt.sh` does), or a `started:`
date grace filter (as Principles 13/14 do).

---

## Canon promotion — INVARIANTS Principle 16 (finished, ready to insert)

> **Promoted to `plugins/ship-flow/INVARIANTS.md` Principle 16 (v1.4.0, 2026-05-30)** after #188 merged to
> main. The canonical text lives in INVARIANTS.md; the block below is the source draft, kept for provenance.

```markdown
### Principle 16: Tier-A Validity — mechanical checks target verifiable, non-self-authored evidence

**Rule**: A criterion may be labelled **Tier-A** (grep/script-enforced) only if (1) its check target is a
file the skill under review does NOT write, OR the output of a separately-dispatched agent, OR process
evidence (temp-file/tool-call/git object) the skill cannot fabricate via its own prose — **and** (2) the
check command is fixture-verified to run (`bash -n` + `which`/`ls` deps + one known-good + one known-bad
execution; portable BSD/macOS shell, no `grep -P`). A check whose guarantee depends on the *provenance* of
self-written content (not its structure) is reclassified Tier-B-with-named-artifact or given a
machine-checkable provenance anchor (turn_id, tool-call log).

**Failure mode**: A grep over a self-written artifact proves structure, not honesty. When the same agent
writes both the artifact and its attestation token, no grep distinguishes honest attestation from a
self-issued rubber stamp — manufacturing false confidence that a gate is "mechanically enforced" when it is
not. Variant: a Tier-A label awarded to a check command that was never run and is mechanically broken
(`grep -c` on a list key, a non-existent `--stage` interface, a missing fixture dir, `grep -P` on macOS).

**Grep check** (Tier B / design-review): for each Tier-A criterion a skill declares, the design-review
agent confirms its target is non-self-authored (M1 case a/b/c) and that the check command was fixture-run
(M2). Future Tier A: a `check-invariants.sh --check tier-a-validity` lint that, for each `rubrics/*.rubric.yaml`
dimension marked `tier: A-grep-script`, asserts the `check:` command passes `bash -n` and that its grep
target path is not the artifact the skill writes.

**Source**: 19-skill rubric-ification audit (2026-05-30). Adversarial pass surfaced M1 (provenance ≠
structure) across ~13 skills and M2 (unverified check commands) across ~8. Full frame:
`plugins/ship-flow/rubrics/_meta-rubric.md`. First Tier-A-valid instance:
`lib/check-cross-review-threshold.sh` (cross-review summary line, M1 case b).
```

## Harvest record (success-mode candidate)

```yaml
- pattern: "Tier-A grep on a self-written artifact proves structure, not provenance/honesty"
  trigger: "designing or reviewing any gate where the agent that produces an artifact also writes its own attestation/verdict token into it"
  action: "require the Tier-A target to be (a) a file the skill does not write, (b) a separately-dispatched agent's output, or (c) process evidence; else reclassify Tier-B-with-provenance-anchor. Fixture-verify every Tier-A check command before accepting the label."
  evidence: "rubric-ification audit 2026-05-30 — M1 recurred across ~13 of 19 skills (ship-shape Articulation Trail fabricable, ship-plan self-issued stamp, codex-gate fabricated GATE line, distill-reference hallucinated citations); M2 across ~8 (grep -c on list key, --stage=execute nonexistent, grep -P on macOS)"
  destination: promote-to-INVARIANTS.md   # Principle 16 above
```
