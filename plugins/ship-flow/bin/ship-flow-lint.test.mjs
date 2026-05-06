import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { runShipFlowLint } from "./ship-flow-lint.mjs";

async function withFixture(files, fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-lint-plugin-"));
  try {
    for (const [relativePath, contents] of Object.entries(files)) {
      const absolutePath = path.join(root, relativePath);
      await mkdir(path.dirname(absolutePath), { recursive: true });
      await writeFile(absolutePath, contents);
    }
    return await fn(root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

const config = JSON.stringify(
  {
    markdown: {
      forbiddenPatterns: [
        { id: "local-path", pattern: "/Users/[^\\s)`]+", files: ["docs/ship-flow/_mods/*.md"] },
      ],
    },
    modContract: {
      files: ["docs/ship-flow/_mods/*.md"],
      forbiddenPatterns: [
        { id: "skip-review-loop", pattern: "\\b(can|may|should|will|explicitly)\\s+skip[^\\n]*pr-review-loop" },
      ],
    },
    workflow: {
      requiredFiles: [
        "docs/ship-flow/README.md",
        "docs/ship-flow/spacebridge.yaml",
        "docs/ship-flow/_mods/ship-flow-lint.md",
      ],
    },
  },
  null,
  2,
);

test("blocks repeatable markdown, mod-contract, and missing workflow-surface mistakes", async () => {
  await withFixture(
    {
      "docs/ship-flow/ship-flow-lint.config.json": config,
      "docs/ship-flow/README.md": "# Ship Flow\n",
      "docs/ship-flow/_mods/pr-merge.md": [
        "# PR Merge",
        "",
        "This path may skip pr-review-loop for tiny docs changes.",
        "Local note: /Users/example/private.md",
        "",
      ].join("\n"),
      "docs/ship-flow/example.md": "|| bad table\n",
    },
    async (cwd) => {
      const result = await runShipFlowLint({ cwd, workflowDir: "docs/ship-flow" });
      assert.equal(result.ok, false);
      assert.deepEqual(
        result.issues.map((issue) => issue.ruleId).sort(),
        [
          "markdown.double-pipe-table-prefix",
          "markdown.local-path",
          "mod-contract.skip-review-loop",
          "workflow.missing-required-file",
          "workflow.missing-required-file",
        ],
      );
    },
  );
});

test("passes a clean workflow with config-driven project surfaces", async () => {
  await withFixture(
    {
      "docs/ship-flow/ship-flow-lint.config.json": config,
      "docs/ship-flow/README.md": "# Ship Flow\n",
      "docs/ship-flow/spacebridge.yaml": "schema_version: 1\nproject:\n  - stage\n",
      "docs/ship-flow/_mods/ship-flow-lint.md": "# Ship Flow Lint\n",
      "docs/ship-flow/_mods/pr-merge.md": [
        "# PR Merge",
        "",
        "Do not skip pr-review-loop for docs changes.",
        "",
      ].join("\n"),
      "docs/ship-flow/example.md": "| ok |\n",
    },
    async (cwd) => {
      const result = await runShipFlowLint({ cwd, workflowDir: "docs/ship-flow" });
      assert.equal(result.ok, true);
      assert.deepEqual(result.issues, []);
    },
  );
});
