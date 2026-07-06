---
name: sync-drift-check
description: "Mechanical drift gate for adopter _mods copies: canonical vs customized vs local-only classification checked against the plugin's shipped mods"
version: 0.1.0
---

# Sync Drift Check

Adopter repos copy some plugin `_mods/*.md` into `docs/ship-flow/_mods/`
(the adopter override resolves first at dispatch time). Which copies are
byte-identical canonical copies, deliberate customizations, or local-only
mods used to live in prose notes and human memory, so plugin upgrades risked
silently-drifted canonical copies and clobbered customizations. This check
mechanizes the classification: the adopter declares each mod's bucket in a
manifest, and the runner verifies it against the plugin's shipped `_mods/`.

## Hook: post-upgrade + pre-review-spend

Run alongside ship-flow-lint before reviewer loops, and after every plugin
upgrade:

```bash
node plugins/ship-flow/bin/sync-drift-check.mjs --workflow-dir docs/ship-flow
```

Optional flags: `--json` for machine-readable output;
`--accept-upstream <mod-name>` after reviewing upstream movement under a
customized mod (see below).

## Manifest: `docs/ship-flow/sync-manifest.json`

Adopter-owned and opt-in. A missing manifest exits 0 with a one-line notice.
Hashes are sha256 hex over raw file bytes (no git dependency).

```json
{
  "version": 1,
  "mods": {
    "design-officer": { "bucket": "plugin-canonical" },
    "ship-flow-lint": { "bucket": "customized", "upstreamBaseHash": "<sha256 of the plugin copy it forked from>" },
    "pr-merge": { "bucket": "local-only" }
  }
}
```

## Checks

Per mod name in the union of manifest keys and adopter `_mods/*.md` files:

| Bucket | Condition | Verdict |
| --- | --- | --- |
| plugin-canonical | adopter copy not byte-identical to plugin copy | FAIL: re-copy from plugin or reclassify as customized |
| plugin-canonical | plugin does not ship the mod | FAIL: manifest claims a mod the plugin no longer ships |
| customized | current plugin copy hash differs from `upstreamBaseHash` | WARN: upstream moved; review, merge what applies, then `--accept-upstream <name>` |
| customized | `upstreamBaseHash` missing | FAIL: customized entry requires upstreamBaseHash |
| local-only | plugin now ships a same-named mod | WARN: name collision; reclassify or rename |
| local-only | adopter file missing | FAIL: local-only mods must exist in the adopter tree |
| (any) | adopter file with no manifest entry | WARN: unclassified adopter mod; add it to the manifest |
| (non-local-only) | manifest entry with no adopter file | WARN: manifest entry has no adopter file |

A customized adopter copy is free to differ from the plugin copy — that is
the point of the bucket. Exit code is 1 only when a FAIL fires; WARNs print
but do not fail.

## Accepting upstream movement

`--accept-upstream <name>` rewrites the customized entry's `upstreamBaseHash`
to the current plugin copy's hash and saves the manifest (pretty-printed,
stable key order). This is the ONLY write the tool performs — it never
copies, overwrites, or deletes any mod file.

## Artifact Split

| Layer | Owner | Example |
| --- | --- | --- |
| Generic runner | ship-flow plugin | `plugins/ship-flow/bin/sync-drift-check.mjs` |
| Manifest | adopter repo | `docs/ship-flow/sync-manifest.json` (like `ship-flow-lint.config.json`) |
| Workflow hook | ship-flow plugin + adopter override | `_mods/sync-drift-check.md` |

## Rules

- Report-only by design: drift is surfaced, never auto-fixed. Re-copying a
  canonical mod or merging upstream into a customization is a human decision.
- Classify every adopter mod: an unclassified copy is exactly the state that
  made upgrades risky.
- Do not run `--accept-upstream` without reading the upstream diff first; it
  records "reviewed", not "merged".
