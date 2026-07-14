---
name: contribution-contract
description: "Keeps adopter-declared implementation, schema, and contract-document edges synchronized in both directions"
version: 0.1.0
---

# Contribution Contract

## Hook: pre-review-spend

Before canonical-doc dispatch, cross-review, or external reviewer spend, First Officer runs the same generic mechanism as CI:

```bash
# contribution-contract-resolver:start
ADOPTER_MAP=.claude/ship-flow/doc-coupling.yaml
ADOPTER_CHECKER=.claude/ship-flow/doc-impact-gate.sh
SOURCE_CHECKER_TREE=plugins/ship-flow/bin/doc-impact-gate.sh
SOURCE_CHECKER="${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/bin/doc-impact-gate.sh"
SOURCE_MAP_TREE=plugins/ship-flow/references/doc-coupling-map.yaml
BASE_REF="${BASE_REF:-${PR_BASE_SHA:-}}"
if [ -z "$BASE_REF" ]; then
  echo "BLOCKED: BASE_REF or PR_BASE_SHA must explicitly identify the pull-request base." >&2
  exit 2
fi
if ! git rev-parse --verify "${BASE_REF}^{commit}" >/dev/null 2>&1; then
  echo "BLOCKED: explicit base ref is unavailable: $BASE_REF" >&2
  exit 2
fi
BASE="$(git merge-base "$BASE_REF" HEAD)" || {
  echo "BLOCKED: cannot resolve merge base for $BASE_REF and HEAD." >&2
  exit 2
}

mkdir -p .context/ship-flow
BASE_MAP=.context/ship-flow/base-doc-coupling.yaml
BASE_ADOPTER_EXISTS=false
SOURCE_REPO_OWNS_DEFAULTS=false
MAP_ARGS=()
if git cat-file -e "HEAD:${SOURCE_CHECKER_TREE}" 2>/dev/null &&
   git cat-file -e "HEAD:${SOURCE_MAP_TREE}" 2>/dev/null; then
  SOURCE_REPO_OWNS_DEFAULTS=true
fi
if git cat-file -e "${BASE}:${ADOPTER_MAP}" 2>/dev/null; then
  git show "${BASE}:${ADOPTER_MAP}" > "$BASE_MAP"
  BASE_ADOPTER_EXISTS=true
  MAP_ARGS+=("--base-coupling-map=$BASE_MAP")
elif git cat-file -e "${BASE}:${SOURCE_MAP_TREE}" 2>/dev/null; then
  git show "${BASE}:${SOURCE_MAP_TREE}" > "$BASE_MAP"
  MAP_ARGS+=("--base-coupling-map=$BASE_MAP")
fi

if [ -f "$ADOPTER_MAP" ]; then
  if [ ! -f "$ADOPTER_CHECKER" ]; then
    echo "BLOCKED: adopter map exists but its adjacent adopted checker is absent: $ADOPTER_CHECKER" >&2
    exit 2
  fi
  CHECKER="$ADOPTER_CHECKER"
  MAP_ARGS+=("--coupling-map=$ADOPTER_MAP")
  RESOLVED_MAP="$ADOPTER_MAP"
elif [ "$BASE_ADOPTER_EXISTS" = "true" ]; then
  if [ ! -f "$ADOPTER_CHECKER" ]; then
    echo "BLOCKED: base adopter map was removed but its adjacent adopted checker is absent: $ADOPTER_CHECKER" >&2
    exit 2
  fi
  CHECKER="$ADOPTER_CHECKER"
  MAP_ARGS+=("--head-map-absent")
  RESOLVED_MAP=removed-adopter-map
elif [ "$SOURCE_REPO_OWNS_DEFAULTS" = "true" ] && [ -f "$SOURCE_CHECKER" ]; then
  CHECKER="$SOURCE_CHECKER"
  RESOLVED_MAP=plugin-default
else
  echo "BLOCKED: no adopter contribution bundle and this repository is not the Ship Flow source repo with an owned checker/map." >&2
  exit 2
fi
printf 'Resolved contribution contract: checker=%s map=%s\n' "$CHECKER" "$RESOLVED_MAP"
# contribution-contract-resolver:end

git diff --no-renames --name-only "$BASE"...HEAD > .context/ship-flow/changed-files.txt
bash "$CHECKER" \
  --changed=.context/ship-flow/changed-files.txt \
  --declaration="$(cat <entity-folder>/execute.md)" \
  "${MAP_ARGS[@]}"
```

Exit 1 means a declared edge is incomplete. Return the task to execute for a paired code/schema and contract-doc change, or require the exact scoped waiver from `CONTRIBUTING.md`. Exit 2 means the map or invocation is invalid and is BLOCKED until repaired. Record the command and result in `review.md`; do not replace gate output with worker self-attestation.

When a waiver is used locally, the exact standalone declaration must also appear in the eventual PR body because generic CI reads the PR body. A path deletion or rename remains blocked until the coupling row moves with it or a narrow row-local exemption is reviewed.

## Boundary

Ship Flow owns the generic mechanism, direction vocabulary, and review timing. The adopter owns domain paths, implementation/schema content, contract documentation, and any scoped exemption. This mod never copies adopter-specific guidance into the plugin and never makes Ship Flow the domain contract source of truth.

When `.claude/ship-flow/doc-coupling.yaml` exists, the adopted `.claude/ship-flow/doc-impact-gate.sh` is unconditionally required beside it. It is the exact self-contained copy of Ship Flow's canonical checker, not an adopter reimplementation. The presence of a plugin source tree never substitutes for a missing adopted checker; a missing or deleted checker is BLOCKED until it is re-copied during onboarding or upgrade.

When no adopter map exists, only the Ship Flow source repository may fall back to `${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/bin/doc-impact-gate.sh`; the resolver proves that boundary by requiring both the canonical checker path and default map path in the current repository's `HEAD` tree. An externally installed marketplace plugin does not establish source-repository ownership. The source-repository checker resolves its bundled default map. This is the same boundary CI applies.
