---
name: issue-anchor-guard
description: "Re-anchors a re-shaped entity against its immutable original tracker issue before ship-shape lets the model re-summarize its own drifted artifacts"
version: 0.1.0
---

# Issue-Anchor Guard

Route-back re-shape loops drift from the original issue goal: each local
re-shape reads the entity's own accumulated artifacts (`shape.md` /
`design.md` / `plan.md`) — exactly where the drift has accumulated. This
guard forces a re-read of the *immutable original tracker issue* instead,
and emits a machine-checkable source-diff before the model gets a chance to
rubber-stamp "still on-goal" from its own drifted summary.

## Hook: pre-shape

Ship-shape invokes this mod before Intake, for every `/shape <entity-id>` or
`/shape --discuss <entity-id>` re-entry. Skip only when the entity is a
fresh shape (no later-stage artifacts) — the resolver detects this itself
and no-ops — or when the captain passes the explicit escape hatch
`--skip-issue-anchor-guard` (never the inverse: the default is on, so a
forgotten flag fails safe).

## Invocation

The resolver below is a self-contained shell block extracted from this
file at invocation time by its start/end marker comments (same pattern as
`contribution-contract.md`'s FO resolver), not a separate script file. Once
extracted to a temp script, ship-shape runs it as:

```bash
# Emit (or no-op / halt) a source-diff for the target entity:
bash "$RESOLVER" emit --entity-path=docs/ship-flow/<id>-<slug>
# or, with the escape hatch:
bash "$RESOLVER" emit --entity-path=docs/ship-flow/<id>-<slug> --skip-issue-anchor-guard

# Validate an already-populated source-diff for the non-hollow rule
# (run this after the model has overwritten the judgment fields, before
# presenting the verdict to the captain):
bash "$RESOLVER" validate --file=.context/ship-flow/source-diff-<id>.yaml
```

`--entity-path` accepts either the entity's folder (containing `index.md`)
or a flat-file entity's own `.md` path. Output lands at
`.context/ship-flow/source-diff-<id>.yaml`, relative to the caller's cwd
(repo root).

**Outcomes ship-shape must act on:**

- `guard_required: false` — fresh shape, no later-stage artifacts. Continue
  to Intake normally.
- `no_issue_anchor: true` — entity has no `issue:` (or an empty-string
  `issue:`, treated identically to absent). Halt and SendMessage(captain)
  with the `captain_prompt` text; do not fabricate a diff.
- A populated source-diff with `verdict: narrow` or `verdict: return` —
  SendMessage(captain) with the source-diff summary before continuing.
- A populated source-diff with `verdict: proceed` — continue to Intake, but
  only after the model has itself reviewed `original_issue_acs[]` against
  the current shape/plan and confirmed (or corrected) the mechanical
  scaffold's `scope_subset_of_issue` / `goal_still_unmet` / `verdict` /
  `rationale` fields, then re-run `validate` to confirm the edit is still
  non-hollow-consistent.
- gh failure (rate-limit / offline / auth) — the resolver exits non-zero
  with a captain-visible stderr message and writes no file. Surface the
  error; never proceed as if `verdict: proceed`.

```bash
# issue-anchor-guard-resolver:start
IAG_MODE="${1:-}"
shift || true

IAG_ENTITY_PATH=""
IAG_VALIDATE_FILE=""
IAG_SKIP_GUARD=0

for iag_arg in "$@"; do
  case "$iag_arg" in
    --entity-path=*) IAG_ENTITY_PATH="${iag_arg#--entity-path=}" ;;
    --file=*) IAG_VALIDATE_FILE="${iag_arg#--file=}" ;;
    --skip-issue-anchor-guard) IAG_SKIP_GUARD=1 ;;
    *)
      echo "issue-anchor-guard: unknown argument: $iag_arg" >&2
      exit 1
      ;;
  esac
done

iag_field_from_file() {
  # iag_field_from_file <file> <key> — top-level scalar "key: value" (quotes stripped)
  local file="$1" key="$2"
  awk -v key="$key" '
    {
      prefix = key ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^"|"$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

iag_derive_verdict() {
  # iag_derive_verdict <scope_subset_of_issue> <goal_still_unmet> — prints proceed|narrow|return
  local scope_subset="$1" goal_unmet="$2"
  if [ "$goal_unmet" = "false" ]; then
    printf 'return\n'
  elif [ "$scope_subset" != "true" ]; then
    printf 'narrow\n'
  else
    printf 'proceed\n'
  fi
}

# ---------------------------------------------------------------------------
# validate mode — non-hollow rule + CD1 vocabulary lock on an existing,
# already-populated (possibly model-edited) source-diff YAML.
# ---------------------------------------------------------------------------
if [ "$IAG_MODE" = "validate" ]; then
  if [ -z "$IAG_VALIDATE_FILE" ]; then
    echo "issue-anchor-guard: BLOCKED — validate requires --file=<source-diff.yaml>" >&2
    exit 1
  fi
  if [ ! -f "$IAG_VALIDATE_FILE" ]; then
    echo "issue-anchor-guard: BLOCKED — validate target not found: $IAG_VALIDATE_FILE" >&2
    exit 1
  fi

  IAG_V_VERDICT="$(iag_field_from_file "$IAG_VALIDATE_FILE" verdict)"
  IAG_V_SCOPE_SUBSET="$(iag_field_from_file "$IAG_VALIDATE_FILE" scope_subset_of_issue)"
  IAG_V_GOAL_UNMET="$(iag_field_from_file "$IAG_VALIDATE_FILE" goal_still_unmet)"

  case "$IAG_V_VERDICT" in
    proceed|narrow|return) ;;
    *)
      echo "issue-anchor-guard: BLOCKED — verdict '$IAG_V_VERDICT' is not one of proceed/narrow/return (CD1 vocabulary lock)" >&2
      exit 1
      ;;
  esac

  if [ "$IAG_V_VERDICT" = "proceed" ]; then
    if [ "$IAG_V_SCOPE_SUBSET" != "true" ] || [ "$IAG_V_GOAL_UNMET" != "true" ]; then
      echo "issue-anchor-guard: BLOCKED — non-hollow rule violated: verdict=proceed requires BOTH scope_subset_of_issue=true AND goal_still_unmet=true (got scope_subset_of_issue=$IAG_V_SCOPE_SUBSET, goal_still_unmet=$IAG_V_GOAL_UNMET)" >&2
      exit 1
    fi
  fi

  echo "issue-anchor-guard: validate PASS — verdict=$IAG_V_VERDICT is non-hollow-consistent"
  exit 0
fi

# ---------------------------------------------------------------------------
# emit mode — mechanical detection + fetch + scaffold
# ---------------------------------------------------------------------------
if [ "$IAG_MODE" != "emit" ]; then
  echo "issue-anchor-guard: unknown mode '$IAG_MODE' (expected emit|validate)" >&2
  exit 1
fi

if [ -z "$IAG_ENTITY_PATH" ]; then
  echo "issue-anchor-guard: BLOCKED — emit requires --entity-path=<path>" >&2
  exit 1
fi
if [ ! -e "$IAG_ENTITY_PATH" ]; then
  echo "issue-anchor-guard: BLOCKED — entity path not found: $IAG_ENTITY_PATH" >&2
  exit 1
fi

if [ -d "$IAG_ENTITY_PATH" ]; then
  IAG_ENTITY_DIR="$IAG_ENTITY_PATH"
  IAG_ENTITY_FM_FILE="${IAG_ENTITY_DIR}/index.md"
else
  IAG_ENTITY_DIR="$(dirname "$IAG_ENTITY_PATH")"
  IAG_ENTITY_FM_FILE="$IAG_ENTITY_PATH"
fi
if [ ! -f "$IAG_ENTITY_FM_FILE" ]; then
  echo "issue-anchor-guard: BLOCKED — entity frontmatter file not found: $IAG_ENTITY_FM_FILE" >&2
  exit 1
fi

iag_frontmatter_field() {
  # iag_frontmatter_field <file> <key> — reads a key from the --- fenced frontmatter only
  local file="$1" key="$2"
  awk -v key="$key" '
    /^---[[:space:]]*$/ { fence++; next }
    fence == 1 {
      prefix = key ":"
      if (index($0, prefix) == 1) {
        value = substr($0, length(prefix) + 1)
        sub(/^[[:space:]]*/, "", value)
        sub(/[[:space:]]*$/, "", value)
        gsub(/^"|"$/, "", value)
        gsub(/^'"'"'|'"'"'$/, "", value)
        print value
        exit
      }
    }
  ' "$file"
}

IAG_ENTITY_ID="$(iag_frontmatter_field "$IAG_ENTITY_FM_FILE" id)"
[ -n "$IAG_ENTITY_ID" ] || IAG_ENTITY_ID="$(basename "$IAG_ENTITY_DIR")"
IAG_STATUS="$(iag_frontmatter_field "$IAG_ENTITY_FM_FILE" status)"
IAG_ISSUE="$(iag_frontmatter_field "$IAG_ENTITY_FM_FILE" issue)"
IAG_TRACKER="$(iag_frontmatter_field "$IAG_ENTITY_FM_FILE" tracker)"

mkdir -p .context/ship-flow
IAG_OUT_FILE=".context/ship-flow/source-diff-${IAG_ENTITY_ID}.yaml"

# CD3: re-shape detection — status is PRIMARY (covers flat-file entities with
# no folder to grep); folder artifacts are secondary.
IAG_RESHAPE=0
case "$IAG_STATUS" in
  design|plan|execute|verify|ship|done) IAG_RESHAPE=1 ;;
esac
if [ "$IAG_RESHAPE" = "0" ] && [ -d "$IAG_ENTITY_DIR" ]; then
  for iag_artifact in design.md plan.md execute.md verify.md review.md; do
    if [ -f "${IAG_ENTITY_DIR}/${iag_artifact}" ]; then
      IAG_RESHAPE=1
      break
    fi
  done
fi

if [ "$IAG_SKIP_GUARD" = "1" ]; then
  {
    printf 'schema_version: "1.0"\n'
    printf 'entity_id: "%s"\n' "$IAG_ENTITY_ID"
    printf 'guard_required: false\n'
    printf 'guard_skipped: true\n'
  } > "$IAG_OUT_FILE"
  echo "issue-anchor-guard: SKIPPED — --skip-issue-anchor-guard passed explicitly -> $IAG_OUT_FILE"
  exit 0
fi

if [ "$IAG_RESHAPE" = "0" ]; then
  {
    printf 'schema_version: "1.0"\n'
    printf 'entity_id: "%s"\n' "$IAG_ENTITY_ID"
    printf 'guard_required: false\n'
  } > "$IAG_OUT_FILE"
  echo "issue-anchor-guard: PASS — guard_required=false (fresh shape, no later-stage artifacts) -> $IAG_OUT_FILE"
  exit 0
fi

# CD5: empty-string issue: is treated identically to absent (never truthy).
if [ -z "$IAG_ISSUE" ]; then
  {
    printf 'schema_version: "1.0"\n'
    printf 'entity_id: "%s"\n' "$IAG_ENTITY_ID"
    printf 'no_issue_anchor: true\n'
    printf 'captain_prompt: "Entity has no tracker issue: field. Confirm current scope manually or attach an issue: <ref> to the entity frontmatter and re-run."\n'
  } > "$IAG_OUT_FILE"
  echo "issue-anchor-guard: HALT — no_issue_anchor=true -> $IAG_OUT_FILE (captain confirmation required)"
  exit 0
fi

if [ "$IAG_TRACKER" != "gh" ]; then
  echo "issue-anchor-guard: BLOCKED — tracker '$IAG_TRACKER' is not supported in v1 (gh only; Linear is a named rabbit hole)" >&2
  exit 1
fi

IAG_ISSUE_NUM="${IAG_ISSUE#\#}"
IAG_GH_ERR="$(mktemp)"
set +e
IAG_ISSUE_BODY="$(gh issue view "$IAG_ISSUE_NUM" --json body --jq '.body' 2>"$IAG_GH_ERR")"
IAG_GH_RC=$?
set -e
if [ "$IAG_GH_RC" != "0" ]; then
  echo "issue-anchor-guard: BLOCKED — gh issue view failed for #${IAG_ISSUE_NUM} (exit ${IAG_GH_RC}): $(cat "$IAG_GH_ERR")" >&2
  rm -f "$IAG_GH_ERR"
  exit 1
fi
rm -f "$IAG_GH_ERR"

IAG_AC_LINES="$(printf '%s\n' "$IAG_ISSUE_BODY" | grep -E '^[[:space:]]*-?[[:space:]]*AC-[0-9]+[:.]' || true)"
if [ -z "$IAG_AC_LINES" ]; then
  echo "issue-anchor-guard: BLOCKED — no AC-N lines found in issue #${IAG_ISSUE_NUM} body; cannot build a non-hollow source-diff without quoted acceptance criteria (never emits a fake-empty AC list)" >&2
  exit 1
fi

IAG_FIRST_AC_NUM="$(printf '%s\n' "$IAG_AC_LINES" | head -1 | grep -oE 'AC-[0-9]+' | head -1)"
IAG_FETCHED_AT="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

IAG_AC_ROWS="$(
  while IFS= read -r iag_line; do
    [ -n "$iag_line" ] || continue
    iag_esc="${iag_line//\\/\\\\}"
    iag_esc="${iag_esc//\"/\\\"}"
    printf '  - text: "%s"\n    met_by_existing_capability: false\n' "$iag_esc"
  done <<< "$IAG_AC_LINES"
)"
# Mechanical scaffold default: every AC row starts unmet-by-existing-capability
# (conservative — the model must flip a row to true only after real
# comparison), so goal_still_unmet derives to true until the model overrides it.
IAG_GOAL_UNMET=true
# Mechanical scaffold default: no scope-delta observed textually yet, so
# scope_subset_of_issue defaults true; the model must re-check against the
# current shape.md/plan.md before the captain sees this as final.
IAG_SCOPE_SUBSET=true
IAG_VERDICT="$(iag_derive_verdict "$IAG_SCOPE_SUBSET" "$IAG_GOAL_UNMET")"

{
  printf 'schema_version: "1.0"\n'
  printf 'entity_id: "%s"\n' "$IAG_ENTITY_ID"
  printf 'issue_ref: "%s#%s"\n' "$IAG_TRACKER" "$IAG_ISSUE_NUM"
  printf 'issue_fetched_at: "%s"\n' "$IAG_FETCHED_AT"
  printf 'original_issue_acs:\n'
  printf '%s\n' "$IAG_AC_ROWS"
  printf 'current_scope_delta: []\n'
  printf 'scope_subset_of_issue: %s\n' "$IAG_SCOPE_SUBSET"
  printf 'goal_still_unmet: %s\n' "$IAG_GOAL_UNMET"
  printf 'verdict: %s\n' "$IAG_VERDICT"
  printf 'rationale: "Mechanical scaffold citing %s as the first quoted anchor — the model must compare current shape.md/plan.md against every quoted AC above and overwrite scope_subset_of_issue/goal_still_unmet/verdict/rationale with real per-AC judgment, then re-run validate, before presenting to the captain."\n' "${IAG_FIRST_AC_NUM:-AC-1}"
} > "$IAG_OUT_FILE"

echo "issue-anchor-guard: PASS — source-diff emitted -> $IAG_OUT_FILE"
exit 0
# issue-anchor-guard-resolver:end
```

## Schema (locked)

```yaml
# .context/ship-flow/source-diff-<id>.yaml
schema_version: "1.0"
entity_id: "<id>"
issue_ref: "<gh|linear>#<number>"
issue_fetched_at: "<ISO8601>"
original_issue_acs:                # verbatim-quoted rows from `gh issue view`
  - text: "AC-1: <quoted line>"
    met_by_existing_capability: <true|false>
  - text: "AC-2: <quoted line>"
    met_by_existing_capability: <true|false>
current_scope_delta:               # what current shape/plan is doing beyond the issue
  - "<bullet>"
scope_subset_of_issue: <true|false>
goal_still_unmet: <true|false>      # derived: true when ANY AC row has met_by_existing_capability:false
verdict: <proceed|narrow|return>    # CD1 vocabulary; derived, never independently settable
rationale: "<one paragraph, cites at least one AC by number>"
```

**Non-hollow rule** (mechanically enforced by `validate`): if `verdict:
proceed` then BOTH `scope_subset_of_issue: true` AND `goal_still_unmet:
true` MUST hold; otherwise `verdict` MUST be `narrow` or `return`.
`original_issue_acs[]` MUST be non-empty when `issue:` is present — an
empty list with `issue:` set is treated the same as a gh failure
(fail-visible, never a fake-empty AC list).

**No-issue fallback** (honors "never a fake anchor"):

```yaml
schema_version: "1.0"
entity_id: "<id>"
no_issue_anchor: true
captain_prompt: "Entity has no tracker issue: field. Confirm current scope manually or attach an issue: <ref> to the entity frontmatter and re-run."
```

## Rationale + References

- Route vocabulary authority: `plugins/ship-flow/_mods/science-officer-em.md:110`
  (`route` is one of `proceed`, `narrow`, `return`, `block`, or
  `costly_no`). This guard reuses `proceed`/`narrow`/`return` only; `return`
  is narrowly scoped to "the original goal is already met by existing
  capability — close or defer this entity". No new SO/EM route values are
  introduced.
- `tracker: gh` is the only supported tracker in v1; `tracker: linear` is
  the deferred rabbit hole `issue-anchor-guard-remaining-triggers` (ROADMAP
  Later).
- Known residual (named, not hidden — CD4): the AC-line parser expects
  issue bodies with explicit `AC-N:`/`AC-N.` lines. An issue body written as
  free-form prose (no enumerated `AC-N` lines) yields zero matches and the
  resolver fails visible rather than emitting an empty list — this is
  correct per the non-hollow rule, but means issues must state ACs in this
  format for the guard to run end-to-end against them.
- Known residual (honest, shell-test cannot close it — CD4): a model can
  still overwrite the scaffold's judgment fields with a false
  ⊆-judgment. Per-AC rows plus captain-gate presentation of the immutable
  AC text raise the cost of hollow rubber-stamping but do not eliminate it.

## Boundary

This mod owns the mechanical trigger detection, the tamper-proof fetch +
verbatim quote of the original issue's acceptance criteria, the source-diff
schema, and the non-hollow consistency check. It does not own — and cannot
mechanically verify — whether the model's own `scope_subset_of_issue` /
`goal_still_unmet` judgment is truthful; that residual is named above, not
hidden.
