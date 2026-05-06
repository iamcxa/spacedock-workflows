#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../../../.." && pwd)"

node --test "$ROOT/plugins/ship-flow/bin/ship-flow-lint.test.mjs"

TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/docs/ship-flow/_mods"
cat > "$TMP/docs/ship-flow/README.md" <<'EOF'
# Ship Flow
EOF
cat > "$TMP/docs/ship-flow/spacebridge.yaml" <<'EOF'
schema_version: 1
project:
  - stage
EOF
cat > "$TMP/docs/ship-flow/_mods/ship-flow-lint.md" <<'EOF'
# Ship Flow Lint
EOF
cat > "$TMP/docs/ship-flow/ship-flow-lint.config.json" <<'EOF'
{
  "workflow": {
    "requiredFiles": [
      "docs/ship-flow/README.md",
      "docs/ship-flow/spacebridge.yaml",
      "docs/ship-flow/_mods/ship-flow-lint.md"
    ]
  }
}
EOF
cat > "$TMP/docs/ship-flow/example.md" <<'EOF'
| ok |
EOF

(cd "$TMP" && node "$ROOT/plugins/ship-flow/bin/ship-flow-lint.mjs" --workflow-dir docs/ship-flow)
