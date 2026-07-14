# spacedock-workflows

A Claude marketplace repo for spacedock workflow plugins. The first — and currently only — plugin is **ship-flow**.

## What is ship-flow?

See [PRODUCT.md](PRODUCT.md) for canonical product positioning and current capabilities. For installation, adoption, and operating guidance, see the [ship-flow plugin documentation](plugins/ship-flow/).

## Install

```
/plugin marketplace add iamcxa/spacedock-workflows
/plugin install ship-flow
```

## Compatibility

> **The entry bridge supports Claude Code, Codex, and Pi; full ship-flow pipeline execution under Codex remains unverified.**

The `/ship` entry point delegates to `spacedock:first-officer`, whose entry bridge supports all three platforms. Ship-flow's stage-dispatch skills still use Claude Code-specific primitives such as hooks, slash commands, agent messaging, and worktrees, and have not been verified end-to-end under Codex. Full pipeline execution under Codex is therefore unverified, not unsupported by design. See [PRODUCT.md](PRODUCT.md) for canonical product positioning and current capabilities.

## Adoption requirements

> **Installing the plugin alone does not commission a working pipeline.**

Ship-flow assumes a commissioned workflow directory, a Spacedock orchestration layer, and optionally the spacebridge UI. Installing it into an empty repository does not create that surrounding scaffold. See the [ship-flow onboarding guidance](plugins/ship-flow/skills/ship-onboard/) for adoption prerequisites.

## Release

Maintainers: see `scripts/plugin-release.sh` for the transactional version bump (gate + triple-site update across `plugins/ship-flow/.claude-plugin/plugin.json`, `.claude-plugin/marketplace.json`, and `plugins/ship-flow/README.md`).

## License

See the [machine-readable plugin metadata](plugins/ship-flow/.claude-plugin/plugin.json) for licensing terms.
