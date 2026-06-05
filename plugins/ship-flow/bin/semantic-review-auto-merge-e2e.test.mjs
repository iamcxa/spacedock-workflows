import assert from "node:assert/strict";
import { mkdir, mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import {
  buildSemanticReviewPacket,
  packetCommentBody,
} from "./semantic-review-prepare.mjs";
import { runAutoMergeReadinessCollect } from "./auto-merge-readiness-collect.mjs";
import { runAutoMerge } from "./auto-merge-run.mjs";

const headSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const baseSha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const repo = "duckbase-co/qnow";
const prNumber = 746;
const pullRequestId = "PR_e2e";

async function withTempDir(fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-semantic-auto-merge-e2e-"));
  try {
    await mkdir(path.join(root, ".context"), { recursive: true });
    return await fn(root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

function commandRunnerFor(commands) {
  return async (command) => {
    if (!(command in commands)) {
      throw new Error(`Unexpected command: ${command}`);
    }
    return { stdout: commands[command], stderr: "" };
  };
}

function verifyPanelCoverage() {
  return `## Panel Coverage
- Tier: A (full cross-model)
- Pass ownership: verify_agent_worker_ownership PASS; workflow_ci PASS; type_design PASS; silent_failure PASS; test_adequacy PASS; security PASS; cross_model_challenge PASS
- Semantic packet dimensions: security, type_design, test_adequacy, silent_failure, workflow_ci, verify_agent_worker_ownership, cross_model_challenge
`;
}

function prSnapshot() {
  return {
    state: "OPEN",
    isDraft: false,
    mergeable: "MERGEABLE",
    mergeStateStatus: "CLEAN",
    headRefOid: headSha,
    autoMergeRequest: null,
    statusCheckRollup: [
      { __typename: "StatusContext", context: "ci-gate", state: "SUCCESS" },
      { __typename: "StatusContext", context: "review-thread-gate", state: "SUCCESS" },
    ],
  };
}

function reviewThreadsPayload() {
  return {
    data: {
      repository: {
        pullRequest: {
          headRefOid: headSha,
          reviewThreads: { nodes: [] },
        },
      },
    },
  };
}

function prLookup() {
  return {
    data: {
      repository: {
        pullRequest: {
          id: pullRequestId,
          number: prNumber,
          state: "OPEN",
          isDraft: false,
          mergeable: "MERGEABLE",
          mergeStateStatus: "CLEAN",
          headRefOid: headSha,
          autoMergeRequest: null,
        },
      },
    },
  };
}

function autoMergeEnabled() {
  return {
    data: {
      enablePullRequestAutoMerge: {
        pullRequest: {
          number: prNumber,
          state: "OPEN",
          autoMergeRequest: {
            enabledAt: "2026-05-20T00:00:00Z",
            mergeMethod: "SQUASH",
            enabledBy: { login: "iamcxa" },
          },
        },
      },
    },
  };
}

test("verify Panel Coverage packet can gate readiness and arm auto-merge", async () => {
  await withTempDir(async (cwd) => {
    await writeFile(path.join(cwd, "verify.md"), verifyPanelCoverage());

    const packet = await buildSemanticReviewPacket({
      cwd,
      options: {
        baseRef: "origin/main",
        verifyPath: "verify.md",
        localReviewCommand: "ship-flow semantic review --verify-md verify.md",
        localReviewArtifact: "verify.md#panel-coverage",
        localReviewEvidence: "Structured verify Panel Coverage review completed.",
        commands: [
          {
            name: "ship-flow bin tests",
            command: "node --test plugins/ship-flow/bin/*.test.mjs",
            exit_code: 0,
          },
        ],
      },
      generatedAt: "2026-05-20T00:00:00.000Z",
      commandRunner: commandRunnerFor({
        "git rev-parse HEAD": `${headSha}\n`,
        "git merge-base HEAD origin/main": `${baseSha}\n`,
        "git diff --name-only bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa": "plugins/ship-flow/skills/ship-verify/SKILL.md\n",
      }),
    });
    const packetComment = {
      id: 1001,
      created_at: "2026-05-20T00:00:00Z",
      body: packetCommentBody(packet),
    };

    const collectCommandRunner = async (args) => {
      const command = args.join(" ");
      if (
        command.includes(`pr view ${prNumber}`) &&
        command.includes("--json state,isDraft,mergeable,mergeStateStatus,statusCheckRollup,headRefOid,author,reviews,autoMergeRequest")
      ) {
        return JSON.stringify(prSnapshot());
      }
      if (command.includes(`pr view ${prNumber}`) && command.includes("--json labels --jq .labels")) {
        return JSON.stringify([]);
      }
      if (command.includes(`api repos/duckbase-co/qnow/issues/${prNumber}/comments --paginate --slurp`)) {
        return JSON.stringify([packetComment]);
      }
      if (command.includes("api graphql")) {
        return JSON.stringify(reviewThreadsPayload());
      }
      throw new Error(`Unexpected gh command: ${command}`);
    };

    const ghRunner = async (args) => {
      const command = args.join(" ");
      if (command.includes("query(")) return JSON.stringify(prLookup());
      if (command.includes("enablePullRequestAutoMerge")) return JSON.stringify(autoMergeEnabled());
      throw new Error(`Unexpected gh command: ${command}`);
    };

    const result = await runAutoMerge({
      cwd,
      prNumber,
      repo,
      requiredChecks: ["ci-gate", "review-thread-gate"],
      collect: async (options) =>
        await runAutoMergeReadinessCollect({
          ...options,
          commandRunner: collectCommandRunner,
        }),
      ghRunner,
    });

    assert.equal(result.status, "auto_merge_enabled");
    assert.equal(result.mutated, true);
    assert.equal(result.readiness.status, "ready");

    const semanticGate = JSON.parse(
      await readFile(result.readiness.paths.semanticGate, "utf8"),
    );
    assert.equal(semanticGate.status, "valid");
    assert.deepEqual(semanticGate.metadata.packet.localReviewDimensions, [
      "cross_model_challenge",
      "security",
      "silent_failure",
      "test_adequacy",
      "type_design",
      "verify_agent_worker_ownership",
      "workflow_ci",
    ]);
  });
});
