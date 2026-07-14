# Contributing to Ship Flow

Ship Flow treats a declared implementation/schema surface and its contract documentation as one contribution surface. The generic mechanism lives here; each adopter owns its domain-specific paths and prose.

## Coupling map

`bin/doc-impact-gate.sh` reads `.claude/ship-flow/doc-coupling.yaml` when an adopter supplies it, otherwise `references/doc-coupling-map.yaml`. Version 1.1 rows use inline arrays:

```yaml
schema_version: "1.1"
couplings:
  - name: ledger-boundary
    srcGlobs: ["src/contracts/*.schema.json"]
    docPaths: ["docs/contracts/ledger.md"]
    directions: ["source-to-doc", "doc-to-source"]
    exemptGlobs: ["src/contracts/generated/**"]
    rationale: "Schema and consumer guidance are reviewed together."
```

- `source-to-doc` requires at least one `docPaths` entry when a non-exempt `srcGlobs` path changes.
- `doc-to-source` requires a matching source, code, or schema path when a contract doc changes.
- Legacy rows with no `directions` remain `source-to-doc` only. Inverse edges are never guessed.
- `exemptGlobs` is scoped to its row. Use it only for a path class whose coupling is mechanically irrelevant, such as generated output.
- `name` is an unquoted safe slug containing only letters, numbers, dot, underscore, and hyphen; scoped declarations bind to it exactly.

Supported schema versions are `1.0` and `1.1`. Version `1.0` preserves the legacy source-to-doc row shape. Version `1.0` rejects `directions` and `exemptGlobs`; upgrade the map to `1.1` before adding either field. `schema_version` is a required, unique, quoted top-level key. A missing, duplicate, malformed, or unknown version fails closed with exit 2 before any row is enforced.

Only inline arrays are supported. Row names and row keys must be unique. Brace-expanded globs such as `src/{one,two}/**` are unsupported; list each glob separately so comma parsing remains unambiguous. Unknown directions, duplicate rows/keys, block arrays, missing keys, and other malformed entries fail closed with exit 2.

## Install the adopter bundle

The durable adopter contract is the self-contained `.claude/ship-flow/` bundle, not the YAML file alone. Install the canonical checker beside the map; the copied checker includes fallback helpers and must run without a `plugins/ship-flow/` source tree:

```bash
mkdir -p .claude/ship-flow
cp "${CLAUDE_PLUGIN_ROOT:-plugins/ship-flow}/bin/doc-impact-gate.sh" \
  .claude/ship-flow/doc-impact-gate.sh
chmod +x .claude/ship-flow/doc-impact-gate.sh
```

Re-copy the checker and `references/ship-flow-doc-impact-workflow.yml` when upgrading Ship Flow, review their diffs together with map-schema changes, and keep the map, checker, and installed workflow in version control. When the adopter map exists, CI requires `.claude/ship-flow/doc-impact-gate.sh` unconditionally; a plugin source tree never substitutes for a missing or deleted adjacent checker. Only when no adopter map exists may the Ship Flow source repository fall back to `plugins/ship-flow/bin/doc-impact-gate.sh` and its bundled default map. CI never downloads or inlines a competing implementation.

## Exceptions

The old source-to-doc waiver remains available as a standalone PR line:

```text
doc-impact: none — concrete reason of at least twelve characters
```

An inverse waiver must identify the exact row and direction:

```text
contribution-impact: none [<row>:doc-to-source] — concrete reason of at least twelve characters
```

Weakening the effective map between the pull-request merge base and HEAD—removing a row, direction, or source/doc glob, or adding/broadening an exemption—requires a literal row-scoped migration declaration. The declaration must be its own line, start at column one, and use the em dash separator exactly:

```text
contract-migration: <row> — concrete reason of at least twelve characters
```

CI and FO both pass the effective base map to the checker. Removing the adopter map is treated as removing every base row, not as disabling the gate. Removing an exemption strengthens enforcement and does not require a migration declaration.

A waiver for another row or direction does not apply. Prefer a paired change. Use a scoped declaration only when the contract wording truly does not change implementation/schema obligations, and copy the same standalone line into execution evidence and the PR body so FO pre-review and CI evaluate the same claim.

## Deletes and renames

For a bidirectional row, a changed protected path that does not exist in the checkout is treated as a delete or rename and fails closed. Update the coupling row in the same change when a path moves. For an intentional deletion with no replacement, add a narrow `exemptGlobs` entry and explain the boundary change in review evidence; never use a broad repository-level exemption.

## Local check

From the repository root:

```bash
git diff --no-renames --name-only <base>...HEAD > .context/ship-flow-changed-files.txt
bash .claude/ship-flow/doc-impact-gate.sh \
  --changed=.context/ship-flow-changed-files.txt \
  --declaration="$(cat <entity-folder>/execute.md)"
```

Run `bash plugins/ship-flow/lib/__tests__/test-doc-impact-gate.sh` after gate or map changes. Run `bash plugins/ship-flow/lib/__tests__/test-contribution-contract.sh` after contributor, mod, doc-sync, or review-stage guidance changes.

## Ownership boundary

Ship Flow owns the generic map schema, canonical self-contained checker, CI invocation, and FO review contract. An adopter owns its `.claude/ship-flow/` bundle, domain schema, boundary docs, and contribution decisions. Do not copy adopter-specific architecture into this plugin; add a fixture that proves the reusable behavior instead.
