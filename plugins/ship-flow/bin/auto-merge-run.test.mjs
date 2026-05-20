import assert from "node:assert/strict";
import { mkdtemp, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { runAutoMerge } from "./auto-merge-run.mjs";

const headSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const pullRequestId = "PR_test";

async function withTempDir(fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-auto-merge-run-"));
  try {
    return await fn(root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

function readyResult(overrides = {}) {
  return {
    ready: true,
    status: "ready",
    blockers: [],
    nextAction: "enable_auto_merge",
    prNumber: 746,
    repo: "duckbase-co/qnow",
    headSha,
    ...overrides,
  };
}

function prLookup(overrides = {}) {
  return {
    data: {
      repository: {
        pullRequest: {
          id: pullRequestId,
          number: 746,
          state: "OPEN",
          isDraft: false,
          mergeable: "MERGEABLE",
          mergeStateStatus: "CLEAN",
          headRefOid: headSha,
          autoMergeRequest: null,
          ...overrides,
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
          number: 746,
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

function merged() {
  return {
    data: {
      mergePullRequest: {
        pullRequest: {
          number: 746,
          state: "MERGED",
          merged: true,
          mergedAt: "2026-05-20T00:00:00Z",
          mergeCommit: { oid: "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb" },
        },
      },
    },
  };
}

test("enables native auto-merge when readiness is clean and GitHub accepts it", async () => {
  await withTempDir(async (cwd) => {
    const calls = [];
    const collect = async () => readyResult();
    const ghRunner = async (args) => {
      calls.push(args);
      const command = args.join(" ");
      if (command.includes("query(")) return JSON.stringify(prLookup());
      if (command.includes("enablePullRequestAutoMerge")) return JSON.stringify(autoMergeEnabled());
      throw new Error(`Unexpected gh command: ${command}`);
    };

    const result = await runAutoMerge({
      cwd,
      prNumber: 746,
      repo: "duckbase-co/qnow",
      requiredChecks: ["ci-gate", "review-thread-gate"],
      collect,
      ghRunner,
    });

    assert.equal(result.status, "auto_merge_enabled");
    assert.equal(result.mutated, true);
    assert.equal(result.headSha, headSha);
    assert.equal(calls.length, 2);
  });
});

test("directly merges with expected head when GitHub says native auto-merge is already clean", async () => {
  await withTempDir(async (cwd) => {
    const calls = [];
    const cleanError = new Error("Pull request Pull request is in clean status");
    cleanError.stdout = JSON.stringify({
      errors: [{ message: "Pull request Pull request is in clean status" }],
    });
    const ghRunner = async (args) => {
      calls.push(args);
      const command = args.join(" ");
      if (command.includes("query(")) return JSON.stringify(prLookup());
      if (command.includes("enablePullRequestAutoMerge")) throw cleanError;
      if (command.includes("mergePullRequest")) return JSON.stringify(merged());
      throw new Error(`Unexpected gh command: ${command}`);
    };

    const result = await runAutoMerge({
      cwd,
      prNumber: 746,
      repo: "duckbase-co/qnow",
      requiredChecks: ["ci-gate", "review-thread-gate"],
      collect: async () => readyResult(),
      ghRunner,
    });

    assert.equal(result.status, "merged");
    assert.equal(result.mutated, true);
    assert.equal(result.directMergeReason, "clean_status");
    assert.equal(calls.length, 3);
  });
});

test("does not direct-merge unstable status unless adopter policy opts in", async () => {
  await withTempDir(async (cwd) => {
    const unstableError = new Error("Pull request Pull request is in unstable status");
    unstableError.stdout = JSON.stringify({
      errors: [{ message: "Pull request Pull request is in unstable status" }],
    });
    const ghRunner = async (args) => {
      const command = args.join(" ");
      if (command.includes("query(")) {
        return JSON.stringify(prLookup({ mergeStateStatus: "UNSTABLE" }));
      }
      if (command.includes("enablePullRequestAutoMerge")) throw unstableError;
      if (command.includes("mergePullRequest")) {
        throw new Error("mergePullRequest should not be called without opt-in");
      }
      throw new Error(`Unexpected gh command: ${command}`);
    };

    const result = await runAutoMerge({
      cwd,
      prNumber: 746,
      repo: "duckbase-co/qnow",
      requiredChecks: ["ci-gate", "review-thread-gate"],
      collect: async () => readyResult(),
      ghRunner,
    });

    assert.equal(result.status, "blocked");
    assert.equal(result.mutated, false);
    assert.equal(result.nextAction, "wait_for_github_merge_state_or_allow_unstable_direct_merge");
  });
});

test("directly merges unstable status when adopter policy explicitly opts in", async () => {
  await withTempDir(async (cwd) => {
    const unstableError = new Error("Pull request Pull request is in unstable status");
    unstableError.stdout = JSON.stringify({
      errors: [{ message: "Pull request Pull request is in unstable status" }],
    });
    const ghRunner = async (args) => {
      const command = args.join(" ");
      if (command.includes("query(")) {
        return JSON.stringify(prLookup({ mergeStateStatus: "UNSTABLE" }));
      }
      if (command.includes("enablePullRequestAutoMerge")) throw unstableError;
      if (command.includes("mergePullRequest")) return JSON.stringify(merged());
      throw new Error(`Unexpected gh command: ${command}`);
    };

    const result = await runAutoMerge({
      cwd,
      prNumber: 746,
      repo: "duckbase-co/qnow",
      requiredChecks: ["ci-gate", "review-thread-gate"],
      allowDirectMergeUnstable: true,
      collect: async () => readyResult(),
      ghRunner,
    });

    assert.equal(result.status, "merged");
    assert.equal(result.directMergeReason, "unstable_status_policy_opt_in");
    assert.equal(result.mutated, true);
  });
});

test("does not mutate GitHub when readiness collector reports blockers", async () => {
  await withTempDir(async (cwd) => {
    const result = await runAutoMerge({
      cwd,
      prNumber: 746,
      repo: "duckbase-co/qnow",
      requiredChecks: ["ci-gate"],
      collect: async () => ({
        ready: false,
        status: "blocked",
        blockers: [{ ruleId: "x", message: "blocked" }],
        nextAction: "fix_required_check:ci-gate",
      }),
      ghRunner: async () => {
        throw new Error("gh should not run when readiness is blocked");
      },
    });

    assert.equal(result.status, "blocked");
    assert.equal(result.mutated, false);
    assert.equal(result.nextAction, "fix_required_check:ci-gate");
  });
});

test("rejects mutating auto-merge when semantic review mode is off", async () => {
  await withTempDir(async (cwd) => {
    await assert.rejects(
      () =>
        runAutoMerge({
          cwd,
          prNumber: 746,
          repo: "duckbase-co/qnow",
          mode: "off",
          collect: async () => {
            throw new Error("collector should not run when semantic review is disabled");
          },
          ghRunner: async () => {
            throw new Error("gh should not run when semantic review is disabled");
          },
        }),
      /auto-merge-run requires semantic review mode/,
    );
  });
});
