import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { runReviewThreadGateValidation } from "./review-thread-gate.mjs";

const headSha = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";
const staleSha = "bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb";

async function withFixture(files, fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-review-thread-gate-"));
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

function comment(overrides = {}) {
  return {
    id: "PRRC_1",
    path: "plugins/ship-flow/bin/review-thread-gate.mjs",
    line: 42,
    body: "Please fix this before merge.",
    url: "https://github.example/comment/1",
    author: { login: "copilot-pull-request-reviewer" },
    commit: { oid: headSha },
    ...overrides,
  };
}

function thread(overrides = {}) {
  const { comments = [comment()], ...rest } = overrides;
  return {
    id: "PRRT_1",
    isResolved: false,
    isOutdated: false,
    comments: { nodes: comments },
    ...rest,
  };
}

function payload(overrides = {}) {
  return {
    data: {
      repository: {
        pullRequest: {
          headRefOid: headSha,
          reviewThreads: { nodes: [] },
          ...overrides.pullRequest,
        },
      },
    },
  };
}

async function validate(payloadBody, options = {}) {
  return await withFixture(
    {
      "threads.json": JSON.stringify(payloadBody, null, 2),
    },
    async (root) =>
      await runReviewThreadGateValidation({
        cwd: root,
        payloadPath: "threads.json",
        expectedHead: options.expectedHead ?? headSha,
      }),
  );
}

test("passes when no review threads exist for the current head", async () => {
  const result = await validate(payload());

  assert.equal(result.ok, true);
  assert.deepEqual(result.issues, []);
  assert.equal(result.metadata.unresolvedCurrentHeadThreadCount, 0);
});

test("fails when an unresolved non-outdated thread targets the current head", async () => {
  const result = await validate(
    payload({
      pullRequest: {
        reviewThreads: { nodes: [thread()] },
      },
    }),
  );

  assert.equal(result.ok, false);
  assert.match(
    result.issues.map((issue) => issue.ruleId).join("\n"),
    /review-thread-gate\.unresolved-current-head-thread/,
  );
  assert.equal(result.metadata.unresolvedCurrentHeadThreadCount, 1);
});

test("unresolved AI review threads direct FO to SO/EM adjudication instead of author self-approval", async () => {
  const result = await validate(
    payload({
      pullRequest: {
        reviewThreads: {
          nodes: [
            thread({
              comments: [
                comment({
                  author: { login: "copilot-pull-request-reviewer" },
                  body: "This looks unsafe.",
                }),
              ],
            }),
          ],
        },
      },
    }),
  );

  assert.equal(result.ok, false);
  assert.match(result.issues[0].message, /SO\/EM adjudication/);
  assert.match(result.issues[0].message, /fixed/);
  assert.match(result.issues[0].message, /push-back: false positive/);
  assert.match(result.issues[0].message, /needs captain decision/);
  assert.match(result.issues[0].message, /gh api/);
  assert.match(result.issues[0].message, /re-trigger the AI reviewer gate/);
  assert.doesNotMatch(result.issues[0].message, /resolve\/dismiss/);
  assert.match(result.issues[0].message, /Do not rely on author self-approval/i);
});

test("passes when unresolved threads are outdated or resolved", async () => {
  const result = await validate(
    payload({
      pullRequest: {
        reviewThreads: {
          nodes: [thread({ isOutdated: true }), thread({ isResolved: true })],
        },
      },
    }),
  );

  assert.equal(result.ok, true);
  assert.equal(result.metadata.unresolvedCurrentHeadThreadCount, 0);
});

test("passes when an AI reviewer false positive has an EM evidence reply and the thread is resolved", async () => {
  const result = await validate(
    payload({
      pullRequest: {
        reviewThreads: {
          nodes: [
            thread({
              isResolved: true,
              comments: [
                comment({
                  author: { login: "copilot-pull-request-reviewer" },
                  body: "This change appears to remove validation.",
                }),
                comment({
                  id: "PRRC_2",
                  author: { login: "science-officer-em" },
                  body: "push-back: false positive\nEvidence: validation remains covered by node --test plugins/ship-flow/bin/review-thread-gate.test.mjs.",
                  commit: { oid: headSha },
                }),
              ],
            }),
          ],
        },
      },
    }),
  );

  assert.equal(result.ok, true);
  assert.equal(result.metadata.unresolvedCurrentHeadThreadCount, 0);
});

test("fails stale unresolved threads unless GitHub marks them outdated", async () => {
  const result = await validate(
    payload({
      pullRequest: {
        reviewThreads: {
          nodes: [thread({ comments: [comment({ commit: { oid: staleSha } })] })],
        },
      },
    }),
  );

  assert.equal(result.ok, false);
  assert.match(
    result.issues.map((issue) => issue.ruleId).join("\n"),
    /review-thread-gate\.unresolved-thread-without-current-head-comment/,
  );
});

test("rejects payloads whose PR head does not match expected head", async () => {
  const result = await validate(payload({ pullRequest: { headRefOid: staleSha } }));

  assert.equal(result.ok, false);
  assert.match(
    result.issues.map((issue) => issue.ruleId).join("\n"),
    /review-thread-gate\.stale-payload-head/,
  );
});
