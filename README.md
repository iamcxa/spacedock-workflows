# spacedock-workflows

A Claude marketplace repo for spacedock workflow plugins. The first — and currently only — plugin is **ship-flow**.

## What is ship-flow?

Ship-flow is a staged feature-delivery pipeline for autonomous Claude Code agents: shape → design → plan → execute → verify → review → ship. See `plugins/ship-flow/` for full documentation.

## Install

```
/plugin marketplace add iamcxa/spacedock-workflows
/plugin install ship-flow
```

## Compatibility

> **Claude Code only today. Codex support is a later milestone.**

ship-flow skills use Claude Code-specific primitives (hooks, slash commands, SendMessage, worktrees). Codex runtime is not supported in this release and will be a separate tracked milestone.

## Adoption gap — 0.7.0 is not self-contained

> **Adoption is not self-contained in 0.7.0 — requires spacebridge or manual scaffold (see `plugins/ship-flow` adoption notes).**

The 0.7.x series assumes a commissioned workflow directory (`docs/ship-flow/`), a spacedock orchestration layer, and optionally the spacebridge UI. A bare `/plugin install ship-flow` into an empty repo will not produce a working pipeline without the surrounding scaffold. See `plugins/ship-flow/skills/ship-onboard/` for the onboarding skill and adoption prerequisites.

## Release

Maintainers: see `scripts/plugin-release.sh` for the transactional version bump (gate + triple-site update across `plugins/ship-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `plugins/ship-flow/README.md`).

## License

Apache-2.0
