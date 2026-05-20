import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, readFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import {
  buildSemanticReviewPacket,
  parseArgs,
  prepareSemanticReviewPacket,
} from "./semantic-review-prepare.mjs";
import { runSemanticReviewPacketValidation } from "./semantic-review-packet.mjs";

async function withFixture(fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-semantic-review-prepare-"));
  try {
    await mkdir(path.join(root, ".context"), { recursive: true });
    return await fn(root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

const headSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const baseSha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const policy = {
  required_reviewers: ["codex_local", "domain_reviewer"],
  local_review_key: "kc_pr_review",
  required_dimensions: ["workflow_ci", "runtime_path"],
};
const dimensionEvidence = {
  workflow_ci: "Reviewed required checks and auto-merge ruleset interaction.",
  runtime_path: "Reviewed runtime path and break-point probe evidence.",
};

function commandRunnerFor(commands) {
  return async (command) => {
    if (!(command in commands)) {
      throw new Error(`Unexpected command: ${command}`);
    }
    return { stdout: commands[command], stderr: "" };
  };
}

function validOptions(overrides = {}) {
  return {
    baseRef: "origin/main",
    rounds: 2,
    policy,
    localReviewCommand: "kc-pr-flow:kc-pr-review --pr 742",
    localReviewArtifact: "https://github.example/review/742",
    localReviewEvidence: "Posted structured review with no blocking/high findings.",
    dimensionEvidence,
    commands: [
      {
        name: "semantic review tests",
        command: "node --test plugins/ship-flow/bin/semantic-review-prepare.test.mjs",
        exit_code: 0,
      },
    ],
    ...overrides,
  };
}

test("builds a validator-compatible semantic review packet from an adopter policy", async () => {
  await withFixture(async (root) => {
    const packet = await buildSemanticReviewPacket({
      cwd: root,
      options: validOptions(),
      generatedAt: "2026-05-20T00:00:00.000Z",
      commandRunner: commandRunnerFor({
        "git rev-parse HEAD": `${headSha}\n`,
        "git merge-base HEAD origin/main": `${baseSha}\n`,
        "git diff --name-only bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "plugins/ship-flow/bin/semantic-review-prepare.mjs\n",
      }),
    });

    assert.equal(packet.rounds, 2);
    assert.deepEqual(Object.keys(packet.reviewers).sort(), ["codex_local", "domain_reviewer"]);
    assert.equal(packet.local_review.kc_pr_review.artifact, validOptions().localReviewArtifact);
    assert.deepEqual(Object.keys(packet.local_review.dimensions).sort(), [
      "runtime_path",
      "workflow_ci",
    ]);
    assert.match(packet.changed_files_hash, /^sha256:[0-9a-f]{64}$/);
  });
});

test("writes packet and marked PR comment body that validate against the current head", async () => {
  await withFixture(async (root) => {
    const result = await prepareSemanticReviewPacket({
      cwd: root,
      options: validOptions({
        packetPath: ".context/packet.json",
        commentPath: ".context/comment.md",
      }),
      generatedAt: "2026-05-20T00:00:00.000Z",
      commandRunner: commandRunnerFor({
        "git rev-parse HEAD": `${headSha}\n`,
        "git merge-base HEAD origin/main": `${baseSha}\n`,
        "git diff --name-only bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "plugins/ship-flow/bin/semantic-review-prepare.mjs\n",
      }),
    });

    assert.equal(result.validation.ok, true);
    const comment = await readFile(path.join(root, ".context/comment.md"), "utf8");
    assert.match(comment, /<!-- ship-flow-semantic-review-packet:v1 -->/);
    assert.match(comment, /```json\n/);

    const validation = await runSemanticReviewPacketValidation({
      cwd: root,
      packetPath: ".context/packet.json",
      expectedHead: headSha,
      policy,
    });
    assert.equal(validation.ok, true);
  });
});

test("rejects preparation when adopter-required dimension evidence is missing", async () => {
  await withFixture(async (root) => {
    await assert.rejects(
      () =>
        buildSemanticReviewPacket({
          cwd: root,
          options: validOptions({
            dimensionEvidence: {
              workflow_ci: "Reviewed CI.",
              runtime_path: "",
            },
          }),
          commandRunner: commandRunnerFor({
            "git rev-parse HEAD": `${headSha}\n`,
            "git merge-base HEAD origin/main": `${baseSha}\n`,
            "git diff --name-only bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "",
          }),
        }),
      /Missing required evidence for local review dimension runtime_path/,
    );
  });
});

test("parses policy and generic local review flags", () => {
  const options = parseArgs([
    "--",
    "--policy-json",
    ".context/policy.json",
    "--local-review-command",
    "kc-pr-flow:kc-pr-review --pr 742",
    "--local-review-artifact",
    "https://github.example/review/742",
    "--local-review-evidence",
    "Structured review passed.",
    "--dimension-evidence",
    "workflow_ci=Reviewed CI gate interaction.",
    "--command-evidence",
    "semantic review tests::node --test semantic-review-prepare.test.mjs::0",
  ]);

  assert.equal(options.policyPath, ".context/policy.json");
  assert.equal(options.localReviewCommand, "kc-pr-flow:kc-pr-review --pr 742");
  assert.equal(options.dimensionEvidence.workflow_ci, "Reviewed CI gate interaction.");
  assert.deepEqual(options.commands, [
    {
      name: "semantic review tests",
      command: "node --test semantic-review-prepare.test.mjs",
      exit_code: 0,
    },
  ]);
});
