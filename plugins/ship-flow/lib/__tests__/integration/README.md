# Integration Test Tier

Tests in this directory require a live adopted workflow instance (a host project
that has commissioned ship-flow). They are **NOT** run by the standalone CI gate
(`scripts/bump-version.sh` or `bin/check-invariants.sh`).

## When these run

These tests run only in the dogfood host (spacedock-ui monorepo) where:
- `docs/ship-flow/README.md` exists (the adopted workflow SOT)
- `docs/ship-flow/_mods/` contains operator mods (pr-merge.md, science-officer-em.md, etc.)
- `.claude/settings.json` is present (host machine settings)
- `ARCHITECTURE.md`, `ROADMAP.md`, `PRODUCT.md` exist at repo root
- Specific entity dirs under `docs/ship-flow/` are present

## Running in the dogfood host

```bash
# From the spacedock-ui monorepo root:
cd plugins/ship-flow
for t in lib/__tests__/integration/test-*.sh; do
  CI=true bash "$t" && echo "PASS: $t" || echo "FAIL: $t"
done
```

## Why separated

The standalone CI gate runs `lib/__tests__/test-*.sh` (default tier only).
Integration tests are excluded by not being in the default tier directory.
Adding a test to `integration/` does NOT add it to the standalone gate.

Each file in this directory carries a header comment naming the host artifact
it needs and why it cannot run standalone.
