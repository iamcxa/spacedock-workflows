import assert from "node:assert/strict";
import { mkdir, mkdtemp, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import test from "node:test";

import { runAutoMergeReadiness } from "./auto-merge-readiness.mjs";

async function withFixture(files, fn) {
  const root = await mkdtemp(path.join(tmpdir(), "ship-flow-auto-merge-readiness-"));
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

function checkRun(name, status = "COMPLETED", conclusion = "SUCCESS") {
  return {
    __typename: "CheckRun",
    name,
    status,
    conclusion,
    workflowName: name,
  };
}

function prSnapshot(overrides = {}) {
  return {
    state: "OPEN",
    isDraft: false,
    mergeable: "MERGEABLE",
    mergeStateStatus: "CLEAN",
    statusCheckRollup: [
      checkRun("ci-gate"),
      checkRun("review-thread-gate"),
      checkRun("semantic-review-gate"),
    ],
    ...overrides,
  };
}

function semanticGate(overrides = {}) {
  return {
    ok: true,
    required: true,
    status: "valid",
    issues: [],
    ...overrides,
  };
}

function threadGate(overrides = {}) {
  return {
    ok: true,
    issues: [],
    metadata: {
      unresolvedCurrentHeadThreadCount: 0,
    },
    ...overrides,
  };
}

async function runFixture({
  pr = prSnapshot(),
  semantic = semanticGate(),
  thread = threadGate(),
  requiredChecks = ["ci-gate", "review-thread-gate", "semantic-review-gate"],
  requiredIndependentApprovals,
} = {}) {
  return await withFixture(
    {
      "pr.json": JSON.stringify(pr, null, 2),
      "semantic.json": JSON.stringify(semantic, null, 2),
      "thread.json": JSON.stringify(thread, null, 2),
    },
    async (cwd) =>
      await runAutoMergeReadiness({
        cwd,
        prJsonPath: "pr.json",
        semanticGateJsonPath: "semantic.json",
        threadGateJsonPath: "thread.json",
        requiredChecks,
        requiredIndependentApprovals,
      }),
  );
}

test("reports ready when mergeability, required checks, semantic gate, and thread gate are clean", async () => {
  const result = await runFixture();

  assert.equal(result.status, "ready");
  assert.equal(result.ready, true);
  assert.deepEqual(result.blockers, []);
  assert.equal(result.nextAction, "enable_auto_merge");
});

test("accepts required status contexts that expose state instead of check-run conclusion", async () => {
  const result = await runFixture({
    pr: prSnapshot({
      statusCheckRollup: [
        { __typename: "StatusContext", context: "ci-gate", state: "SUCCESS" },
        { __typename: "StatusContext", context: "review-thread-gate", state: "SUCCESS" },
      ],
    }),
    requiredChecks: ["ci-gate", "review-thread-gate"],
  });

  assert.equal(result.status, "ready");
  assert.equal(result.ready, true);
});

test("requires explicit required checks before reporting ready", async () => {
  const result = await runFixture({ requiredChecks: [] });

  assert.equal(result.status, "unknown");
  assert.equal(result.ready, false);
  assert.equal(result.nextAction, "supply_required_checks");
  assert.match(result.blockers.map((blocker) => blocker.ruleId).join("\n"), /missing-required-checks/);
});

test("blocks with a specific next action when a required check is pending", async () => {
  const result = await runFixture({
    pr: prSnapshot({
      statusCheckRollup: [
        checkRun("ci-gate", "IN_PROGRESS", ""),
        checkRun("review-thread-gate"),
        checkRun("semantic-review-gate"),
      ],
    }),
  });

  assert.equal(result.status, "blocked");
  assert.equal(result.ready, false);
  assert.match(result.blockers.map((blocker) => blocker.ruleId).join("\n"), /required-check-pending/);
  assert.equal(result.nextAction, "wait_for_required_check:ci-gate");
});

test("blocks stale or invalid semantic review packets before auto-merge", async () => {
  const result = await runFixture({
    semantic: semanticGate({
      ok: false,
      status: "invalid",
      issues: [{ ruleId: "semantic-review-packet.stale-head", message: "stale" }],
    }),
  });

  assert.equal(result.status, "blocked");
  assert.equal(result.nextAction, "regenerate_semantic_review_packet");
  assert.match(result.blockers.map((blocker) => blocker.ruleId).join("\n"), /semantic-review-gate-failed/);
});

test("does not count the PR author's own approval as independent approval", async () => {
  const result = await runFixture({
    requiredIndependentApprovals: 1,
    pr: prSnapshot({
      author: { login: "iamcxa" },
      reviews: [
        {
          author: { login: "iamcxa" },
          state: "APPROVED",
          submittedAt: "2026-05-20T00:00:00Z",
        },
      ],
    }),
  });

  assert.equal(result.status, "blocked");
  assert.equal(result.ready, false);
  assert.equal(result.nextAction, "wait_for_independent_review");
  assert.match(result.blockers.map((blocker) => blocker.ruleId).join("\n"), /independent-approval-missing/);
});

test("accepts independent approval from a reviewer who is not the PR author", async () => {
  const result = await runFixture({
    requiredIndependentApprovals: 1,
    pr: prSnapshot({
      author: { login: "iamcxa" },
      reviews: [
        {
          author: { login: "ship-flow-reviewer" },
          state: "APPROVED",
          submittedAt: "2026-05-20T00:00:00Z",
        },
      ],
    }),
  });

  assert.equal(result.status, "ready");
  assert.equal(result.ready, true);
});

test("blocks active change requests before auto-merge", async () => {
  const result = await runFixture({
    pr: prSnapshot({
      author: { login: "iamcxa" },
      reviews: [
        {
          author: { login: "ship-flow-reviewer" },
          state: "CHANGES_REQUESTED",
          submittedAt: "2026-05-20T00:00:00Z",
        },
      ],
    }),
  });

  assert.equal(result.status, "blocked");
  assert.equal(result.ready, false);
  assert.equal(result.nextAction, "science_officer_em_adjudicate_review_feedback");
  assert.match(result.blockers.map((blocker) => blocker.ruleId).join("\n"), /review-changes-requested/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /SO\/EM/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /gh api/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /fixed/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /push-back: false positive/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /needs captain decision/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /re-trigger the AI reviewer gate/);
  assert.doesNotMatch(result.blockers.map((blocker) => blocker.message).join("\n"), /resolve\/dismiss/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /Do not rely on author self-approval/i);
});

test("routes unresolved review thread gates to SO/EM adjudication", async () => {
  const result = await runFixture({
    thread: threadGate({
      ok: false,
      issues: [
        {
          ruleId: "review-thread-gate.unresolved-current-head-thread",
          message: "Unresolved review thread targets the current PR head",
        },
      ],
    }),
  });

  assert.equal(result.status, "blocked");
  assert.equal(result.ready, false);
  assert.equal(result.nextAction, "science_officer_em_adjudicate_review_threads");
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /SO\/EM/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /in-thread gh api replies/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /fixed/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /push-back: false positive/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /needs captain decision/);
  assert.match(result.blockers.map((blocker) => blocker.message).join("\n"), /re-trigger the AI reviewer gate/);
  assert.doesNotMatch(result.blockers.map((blocker) => blocker.message).join("\n"), /resolve\/dismiss/);
});

test("blocks non-mergeable PRs before checking auto-merge readiness", async () => {
  const result = await runFixture({
    pr: prSnapshot({ mergeable: "CONFLICTING" }),
  });

  assert.equal(result.status, "blocked");
  assert.equal(result.nextAction, "resolve_mergeability");
  assert.match(result.blockers.map((blocker) => blocker.ruleId).join("\n"), /pr-not-mergeable/);
});

test("reports closed PRs as state updates instead of mergeability repairs", async () => {
  const result = await runFixture({
    pr: prSnapshot({ state: "MERGED", mergeable: "UNKNOWN", mergeStateStatus: "UNKNOWN" }),
  });

  assert.equal(result.status, "blocked");
  assert.equal(result.nextAction, "update_pr_state");
  assert.match(result.blockers.map((blocker) => blocker.ruleId).join("\n"), /pr-not-open/);
});

test("reports unknown instead of ready when required input snapshots are missing", async () => {
  await withFixture(
    {
      "pr.json": JSON.stringify(prSnapshot(), null, 2),
    },
    async (cwd) => {
      const result = await runAutoMergeReadiness({
        cwd,
        prJsonPath: "pr.json",
        semanticGateJsonPath: "missing-semantic.json",
        threadGateJsonPath: "missing-thread.json",
        requiredChecks: ["ci-gate"],
      });

      assert.equal(result.status, "unknown");
      assert.equal(result.ready, false);
      assert.equal(result.nextAction, "collect_missing_readiness_inputs");
      assert.match(result.blockers.map((blocker) => blocker.ruleId).join("\n"), /input-read-failed/);
    },
  );
});
