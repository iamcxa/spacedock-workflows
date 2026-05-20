import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import {
  formatUnhandledCollectError,
  parseAutoMergeReadinessCollectArgs,
  runAutoMergeReadinessCollect,
} from "./auto-merge-readiness-collect.mjs";

const marker = "<!-- ship-flow-semantic-review-packet:v1 -->";
const headSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const baseSha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

async function withTempDir(fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-auto-merge-readiness-collect-"));
  try {
    return await fn(root);
  } finally {
    await rm(root, { recursive: true, force: true });
  }
}

function validLocalReview() {
  return validLocalReviewWithKey("structured_review");
}

function validLocalReviewWithKey(localReviewKey) {
  return {
    status: "clean",
    [localReviewKey]: {
      ran: true,
      command: "kc-pr-flow:kc-pr-review --pr 744",
      artifact: "https://github.example/review/744",
      evidence: "Posted structured review with no blocking or high findings.",
      reviewed_head: headSha,
      blocking_findings: 0,
      high_findings: 0,
    },
    dimensions: {
      security: {
        status: "pass",
        evidence: "Reviewed workflow permissions and untrusted PR inputs.",
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
      type_design: {
        status: "pass",
        evidence: "Reviewed PR snapshot and gate JSON schema handling.",
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
      test_adequacy: {
        status: "pass",
        evidence: "Confirmed readiness collector and gate tests cover success path.",
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
      silent_failure: {
        status: "pass",
        evidence: "Reviewed stale head and missing check failure paths.",
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
      workflow_ci: {
        status: "pass",
        evidence: "Reviewed ci-gate and review-thread-gate status requirements.",
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
      verify_agent_worker_ownership: {
        status: "pass",
        evidence: "Reviewed verify pass ownership, primary owners, and coverage verdicts.",
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
      cross_model_challenge: {
        status: "pass",
        evidence: "Reviewed host-aware external reviewer challenge evidence.",
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
    },
  };
}

function validPacket(overrides = {}) {
  const localReviewKey = overrides.localReviewKey ?? "structured_review";
  return {
    schema_version: "ship-flow.semantic-review-packet.v1",
    head_sha: headSha,
    base_ref: "origin/main",
    base_sha: baseSha,
    verdict: "pass",
    rounds: 1,
    reviewers: {
      codex_local: {
        verdict: "pass",
        blockers: [],
        reviewed_head: headSha,
      },
      break_point_probe: {
        verdict: "pass",
        blockers: [],
        reviewed_head: headSha,
      },
    },
    commands: [
      {
        name: "ship-flow auto-merge",
        command: "node --test plugins/ship-flow/bin/auto-merge-readiness.test.mjs",
        exit_code: 0,
      },
    ],
    local_review: validLocalReviewWithKey(localReviewKey),
    changed_files_hash: "sha256:changed-files",
    generated_at: "2026-05-20T00:00:00.000Z",
  };
}

function packetComment(packet = validPacket()) {
  return {
    id: 1,
    created_at: "2026-05-20T00:00:00Z",
    body: `${marker}\n\n\`\`\`json\n${JSON.stringify(packet, null, 2)}\n\`\`\``,
  };
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
      {
        __typename: "StatusContext",
        context: "ci-gate",
        state: "SUCCESS",
      },
      {
        __typename: "StatusContext",
        context: "review-thread-gate",
        state: "SUCCESS",
      },
    ],
  };
}

function reviewThreadsPayload() {
  return {
    data: {
      repository: {
        pullRequest: {
          headRefOid: headSha,
          reviewThreads: {
            nodes: [],
          },
        },
      },
    },
  };
}

test("collects PR evidence, evaluates gates, and writes readiness artifacts", async () => {
  await withTempDir(async (outDir) => {
    const calls = [];
    const commandRunner = async (args) => {
      calls.push(args);
      const command = args.join(" ");
      if (
        command.includes("pr view 744") &&
        command.includes("--json state,isDraft,mergeable,mergeStateStatus,statusCheckRollup,headRefOid,autoMergeRequest")
      ) {
        return JSON.stringify(prSnapshot());
      }
      if (command.includes("pr view 744") && command.includes("--json labels --jq .labels")) {
        return JSON.stringify([]);
      }
      if (command.includes("api repos/duckbase-co/qnow/issues/744/comments --paginate")) {
        return JSON.stringify([packetComment()]);
      }
      if (command.includes("api graphql")) {
        return JSON.stringify(reviewThreadsPayload());
      }
      throw new Error(`Unexpected gh command: ${command}`);
    };

    const result = await runAutoMergeReadinessCollect({
      cwd: outDir,
      prNumber: 744,
      repo: "duckbase-co/qnow",
      outDir,
      requiredChecks: ["ci-gate", "review-thread-gate"],
      mode: "required",
      commandRunner,
    });

    assert.equal(result.ready, true);
    assert.equal(result.status, "ready");
    assert.equal(result.nextAction, "enable_auto_merge");
    assert.equal(result.headSha, headSha);
    assert.match(result.paths.readiness, /pr-744-readiness-result\.json$/);
    assert.equal(calls.length, 4);

    const readinessArtifact = JSON.parse(await readFile(result.paths.readiness, "utf8"));
    assert.equal(readinessArtifact.ready, true);
    assert.equal(readinessArtifact.metadata.requiredChecks.length, 2);
  });
});

test("passes adopter semantic review policy through to the packet gate", async () => {
  await withTempDir(async (outDir) => {
    const policyPath = path.join(outDir, "policy.json");
    await writeFile(
      policyPath,
      `${JSON.stringify(
        {
          required_reviewers: ["codex_local", "break_point_probe"],
          local_review_key: "kc_pr_review",
          required_dimensions: [
            "security",
            "type_design",
            "test_adequacy",
            "silent_failure",
            "workflow_ci",
          ],
        },
        null,
        2,
      )}\n`,
    );
    const commandRunner = async (args) => {
      const command = args.join(" ");
      if (command.includes("pr view 744") && command.includes("--json state,isDraft")) {
        return JSON.stringify(prSnapshot());
      }
      if (command.includes("pr view 744") && command.includes("--json labels --jq .labels")) {
        return JSON.stringify([]);
      }
      if (command.includes("api repos/duckbase-co/qnow/issues/744/comments --paginate")) {
        return JSON.stringify([packetComment(validPacket({ localReviewKey: "kc_pr_review" }))]);
      }
      if (command.includes("api graphql")) {
        return JSON.stringify(reviewThreadsPayload());
      }
      throw new Error(`Unexpected gh command: ${command}`);
    };

    const result = await runAutoMergeReadinessCollect({
      cwd: outDir,
      prNumber: 744,
      repo: "duckbase-co/qnow",
      outDir,
      policyPath,
      requiredChecks: ["ci-gate", "review-thread-gate"],
      commandRunner,
    });

    assert.equal(result.ready, true);
  });
});

test("rejects value-taking CLI flags without a value", () => {
  assert.throws(
    () =>
      parseAutoMergeReadinessCollectArgs([
        "--pr",
        "745",
        "--repo",
        "duckbase-co/qnow",
        "--required-check",
      ]),
    /--required-check requires a value/,
  );
  assert.throws(
    () => parseAutoMergeReadinessCollectArgs(["--pr", "--repo", "duckbase-co/qnow"]),
    /--pr requires a value/,
  );
});

test("formats command failures with stderr stdout and invocation context", () => {
  const error = new Error("Command failed: gh pr view");
  error.stderr = "auth failed\n";
  error.stdout = "partial output\n";
  error.code = 1;

  const result = formatUnhandledCollectError(error, {
    prNumber: 745,
    repo: "duckbase-co/qnow",
    outDir: ".context/ship-flow-auto-merge",
  });

  assert.equal(result.ready, false);
  assert.equal(result.status, "unknown");
  assert.match(result.blockers[0].evidence, /auth failed/);
  assert.match(result.blockers[0].evidence, /partial output/);
  assert.deepEqual(result.metadata, {
    prNumber: 745,
    repo: "duckbase-co/qnow",
    outDir: ".context/ship-flow-auto-merge",
    exitCode: 1,
  });
});
