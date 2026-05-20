import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { runSemanticReviewPacketValidation } from "./semantic-review-packet.mjs";

async function withFixture(files, fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-semantic-review-packet-"));
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

const headSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const baseSha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

const defaultDimensions = {
  security: reviewDimension("Reviewed auth, permission, and secret handling paths."),
  type_design: reviewDimension("Reviewed schema and API type boundaries."),
  test_adequacy: reviewDimension("Reviewed automated test coverage for changed behavior."),
  silent_failure: reviewDimension("Reviewed failure paths and stale evidence behavior."),
  workflow_ci: reviewDimension("Reviewed CI and auto-merge gate interaction."),
};

function reviewDimension(evidence, overrides = {}) {
  return {
    status: "pass",
    evidence,
    reviewed_head: headSha,
    blocking_findings: 0,
    high_findings: 0,
    ...overrides,
  };
}

function localReview({
  key = "structured_review",
  command = "ship-flow semantic review",
  artifact = "https://github.example/review/1",
  evidence = "Structured local review completed with no blocking or high findings.",
  dimensions = defaultDimensions,
} = {}) {
  return {
    status: "clean",
    [key]: {
      ran: true,
      command,
      artifact,
      evidence,
      reviewed_head: headSha,
      blocking_findings: 0,
      high_findings: 0,
    },
    dimensions,
  };
}

function reviewer(overrides = {}) {
  return {
    verdict: "pass",
    blockers: [],
    reviewed_head: headSha,
    ...overrides,
  };
}

function validPacket(overrides = {}) {
  const packet = {
    schema_version: "ship-flow.semantic-review-packet.v1",
    head_sha: headSha,
    base_ref: "origin/main",
    base_sha: baseSha,
    verdict: "pass",
    rounds: 1,
    reviewers: {
      codex_local: reviewer(),
      break_point_probe: reviewer(),
    },
    local_review: localReview(),
    commands: [
      {
        name: "semantic review tests",
        command: "node --test plugins/ship-flow/bin/semantic-review-packet.test.mjs",
        exit_code: 0,
      },
    ],
    changed_files_hash: "sha256:changed-files",
    generated_at: "2026-05-20T00:00:00.000Z",
    ...overrides,
  };
  if (overrides.reviewers) packet.reviewers = overrides.reviewers;
  if (overrides.local_review) packet.local_review = overrides.local_review;
  return packet;
}

async function validatePacket(packet, options = {}) {
  return await withFixture(
    {
      "packet.json": JSON.stringify(packet, null, 2),
      ...(options.policy ? { "policy.json": JSON.stringify(options.policy, null, 2) } : {}),
    },
    async (root) =>
      await runSemanticReviewPacketValidation({
        cwd: root,
        packetPath: "packet.json",
        expectedHead: headSha,
        policyPath: options.policy ? "policy.json" : undefined,
      }),
  );
}

test("accepts a valid packet using the default Ship-Flow semantic review policy", async () => {
  const result = await validatePacket(validPacket());

  assert.equal(result.ok, true);
  assert.deepEqual(result.issues, []);
  assert.deepEqual(result.metadata.reviewers, ["break_point_probe", "codex_local"]);
  assert.deepEqual(result.metadata.localReviewDimensions, [
    "security",
    "silent_failure",
    "test_adequacy",
    "type_design",
    "workflow_ci",
  ]);
  assert.equal(result.metadata.localReviewKey, "structured_review");
});

test("accepts adopter policy overrides for reviewers, local review key, and dimensions", async () => {
  const policy = {
    required_reviewers: ["codex_local", "domain_reviewer"],
    local_review_key: "kc_pr_review",
    required_dimensions: ["workflow_ci", "runtime_path"],
  };
  const packet = validPacket({
    reviewers: {
      codex_local: reviewer(),
      domain_reviewer: reviewer(),
    },
    local_review: localReview({
      key: "kc_pr_review",
      dimensions: {
        workflow_ci: reviewDimension("Reviewed required checks and rulesets."),
        runtime_path: reviewDimension("Reviewed runtime path and break-point evidence."),
      },
    }),
  });

  const result = await validatePacket(packet, { policy });

  assert.equal(result.ok, true);
  assert.deepEqual(result.issues, []);
  assert.deepEqual(result.metadata.reviewers, ["codex_local", "domain_reviewer"]);
  assert.equal(result.metadata.localReviewKey, "kc_pr_review");
  assert.deepEqual(result.metadata.localReviewDimensions, ["runtime_path", "workflow_ci"]);
});

test("rejects packets missing adopter-required reviewers and dimensions", async () => {
  const result = await validatePacket(validPacket(), {
    policy: {
      required_reviewers: ["codex_local", "domain_reviewer"],
      local_review_key: "kc_pr_review",
      required_dimensions: ["workflow_ci", "runtime_path"],
    },
  });

  assert.equal(result.ok, false);
  assert.match(
    result.issues.map((issue) => issue.ruleId).join("\n"),
    /semantic-review-packet\.missing-reviewer/,
  );
  assert.match(
    result.issues.map((issue) => issue.ruleId).join("\n"),
    /semantic-review-packet\.missing-local-review-evidence/,
  );
  assert.match(
    result.issues.map((issue) => issue.ruleId).join("\n"),
    /semantic-review-packet\.missing-local-review-dimension/,
  );
});

test("does not let empty policy arrays disable default reviewer and dimension requirements", async () => {
  const packet = validPacket({
    reviewers: {},
    local_review: localReview({
      dimensions: {},
    }),
  });
  const result = await validatePacket(packet, {
    policy: {
      required_reviewers: [],
      required_dimensions: [],
    },
  });

  assert.equal(result.ok, false);
  assert.match(
    result.issues.map((issue) => issue.ruleId).join("\n"),
    /semantic-review-packet\.missing-reviewer/,
  );
  assert.match(
    result.issues.map((issue) => issue.ruleId).join("\n"),
    /semantic-review-packet\.missing-local-review-dimension/,
  );
});
