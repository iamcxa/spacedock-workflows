import assert from "node:assert/strict";
import { spawn } from "node:child_process";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";
import { fileURLToPath } from "node:url";

import { SEMANTIC_REVIEW_PACKET_MARKER, runSemanticReviewGate } from "./semantic-review-gate.mjs";

const gateCliPath = fileURLToPath(new URL("./semantic-review-gate.mjs", import.meta.url));

async function withFixture(files, fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-semantic-review-gate-"));
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

function runGateCli(args, options = {}) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [gateCliPath, ...args], {
      cwd: options.cwd,
      stdio: ["ignore", "pipe", "pipe"],
    });
    let stdout = "";
    let stderr = "";
    child.stdout.setEncoding("utf8");
    child.stderr.setEncoding("utf8");
    child.stdout.on("data", (chunk) => {
      stdout += chunk;
    });
    child.stderr.on("data", (chunk) => {
      stderr += chunk;
    });
    child.on("error", reject);
    child.on("close", (status) => {
      resolve({ status, stdout, stderr });
    });
  });
}

const headSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const staleHeadSha = "cccccccccccccccccccccccccccccccccccccccc";
const baseSha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";
const policy = {
  required_reviewers: ["codex_local", "domain_reviewer"],
  local_review_key: "kc_pr_review",
  required_dimensions: ["workflow_ci", "runtime_path"],
  required_label: "ship-flow:semantic-review-required",
};

function reviewer(overrides = {}) {
  return {
    verdict: "pass",
    blockers: [],
    reviewed_head: headSha,
    ...overrides,
  };
}

function dimension(evidence, overrides = {}) {
  return {
    status: "pass",
    evidence,
    reviewed_head: headSha,
    blocking_findings: 0,
    high_findings: 0,
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
      domain_reviewer: reviewer(),
    },
    local_review: {
      status: "clean",
      kc_pr_review: {
        ran: true,
        command: "kc-pr-flow:kc-pr-review --pr 742",
        artifact: "https://github.example/review/742",
        evidence: "Structured review completed.",
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
      dimensions: {
        security: dimension("Reviewed auth, permission, and secret handling paths."),
        type_design: dimension("Reviewed schema and API type boundaries."),
        test_adequacy: dimension("Reviewed automated test coverage for changed behavior."),
        silent_failure: dimension("Reviewed failure paths and stale evidence behavior."),
        workflow_ci: dimension("Reviewed CI gate interaction."),
        verify_agent_worker_ownership: dimension("Reviewed verify pass ownership and coverage verdicts."),
        cross_model_challenge: dimension("Reviewed host-aware external reviewer challenge evidence."),
        runtime_path: dimension("Reviewed runtime path."),
      },
    },
    commands: [{ name: "tests", command: "node --test", exit_code: 0 }],
    changed_files_hash: "sha256:changed-files",
    generated_at: "2026-05-20T00:00:00.000Z",
    ...overrides,
  };
  return packet;
}

function comment(body, overrides = {}) {
  return {
    id: overrides.id ?? 1,
    created_at: overrides.created_at ?? "2026-05-20T00:00:00Z",
    body,
    ...overrides,
  };
}

function packetComment(packet, overrides = {}) {
  return comment(
    `${SEMANTIC_REVIEW_PACKET_MARKER}\n\n\`\`\`json\n${JSON.stringify(packet, null, 2)}\n\`\`\``,
    overrides,
  );
}

test("auto mode skips when the required label is absent", async () => {
  await withFixture(
    {
      "labels.json": JSON.stringify([{ name: "ready" }]),
      "comments.json": JSON.stringify([]),
      "policy.json": JSON.stringify(policy),
    },
    async (root) => {
      const result = await runSemanticReviewGate({
        cwd: root,
        expectedHead: headSha,
        labelsJsonPath: "labels.json",
        commentsJsonPath: "comments.json",
        policyPath: "policy.json",
        mode: "auto",
      });

      assert.equal(result.ok, true);
      assert.equal(result.required, false);
      assert.equal(result.status, "skipped");
      assert.deepEqual(result.issues, []);
    },
  );
});

test("required mode accepts a valid newest packet comment under adopter policy", async () => {
  await withFixture(
    {
      "labels.json": JSON.stringify([{ name: policy.required_label }]),
      "comments.json": JSON.stringify([packetComment(validPacket(), { id: 42 })]),
      "policy.json": JSON.stringify(policy),
    },
    async (root) => {
      const result = await runSemanticReviewGate({
        cwd: root,
        expectedHead: headSha,
        labelsJsonPath: "labels.json",
        commentsJsonPath: "comments.json",
        policyPath: "policy.json",
        mode: "required",
      });

      assert.equal(result.ok, true);
      assert.equal(result.required, true);
      assert.equal(result.status, "valid");
      assert.equal(result.metadata.packetCommentId, 42);
      assert.equal(result.metadata.packet.localReviewKey, "kc_pr_review");
    },
  );
});

test("newest marked comment wins and stale packets fail", async () => {
  await withFixture(
    {
      "labels.json": JSON.stringify([{ name: policy.required_label }]),
      "comments.json": JSON.stringify([
        packetComment(validPacket(), { id: 1, created_at: "2026-05-20T00:00:00Z" }),
        packetComment(validPacket({ head_sha: staleHeadSha }), {
          id: 2,
          created_at: "2026-05-20T00:01:00Z",
        }),
      ]),
      "policy.json": JSON.stringify(policy),
    },
    async (root) => {
      const result = await runSemanticReviewGate({
        cwd: root,
        expectedHead: headSha,
        labelsJsonPath: "labels.json",
        commentsJsonPath: "comments.json",
        policyPath: "policy.json",
        mode: "required",
      });

      assert.equal(result.ok, false);
      assert.equal(result.status, "invalid");
      assert.equal(result.metadata.packetCommentId, 2);
      assert.match(
        result.issues.map((issue) => issue.ruleId).join("\n"),
        /semantic-review-packet\.stale-head/,
      );
    },
  );
});

test("CLI exits non-zero for an invalid mode", async () => {
  const result = await runGateCli(["--mode", "bogus"]);

  assert.equal(result.status, 1);
  assert.equal(result.stderr, "");
  const payload = JSON.parse(result.stdout);
  assert.equal(payload.ok, false);
  assert.equal(payload.status, "invalid");
});
