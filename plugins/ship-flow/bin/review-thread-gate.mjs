#!/usr/bin/env node
import { exec } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

const execAsync = promisify(exec);
const SHA_PATTERN = /^[0-9a-f]{7,40}$/i;
const REVIEW_THREAD_ADJUDICATION_MESSAGE =
  "Unresolved review thread targets the current PR head; route to SO/EM adjudication to classify the reviewer finding as accepted, false_positive, or out_of_scope, then use gh api evidence-bearing replies and resolve/dismiss when appropriate. Do not rely on author self-approval.";

function issue(ruleId, file, message, evidence = undefined) {
  return {
    ruleId: `review-thread-gate.${ruleId}`,
    file,
    line: 1,
    message,
    ...(evidence ? { evidence } : {}),
  };
}

function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function isSha(value) {
  return typeof value === "string" && SHA_PATTERN.test(value);
}

async function defaultCommandRunner(command, { cwd }) {
  return await execAsync(command, { cwd });
}

async function resolveExpectedHead({ cwd, expectedHead, commandRunner }) {
  if (expectedHead) return expectedHead;
  const { stdout } = await commandRunner("git rev-parse HEAD", { cwd });
  return stdout.trim();
}

function pullRequestFromPayload(payload) {
  return payload?.data?.repository?.pullRequest;
}

function threadComments(thread) {
  return Array.isArray(thread?.comments?.nodes) ? thread.comments.nodes : [];
}

function commentCommitOid(comment) {
  return comment?.commit?.oid ?? comment?.originalCommit?.oid ?? "";
}

function commentSummary(comment) {
  return [
    comment?.author?.login ?? "unknown",
    comment?.path ?? "unknown-path",
    comment?.line ? `line ${comment.line}` : "unknown-line",
    comment?.url ?? "",
  ]
    .filter(Boolean)
    .join(" ");
}

function unresolvedThreadIssue({ payloadPath, thread, expectedHead }) {
  const comments = threadComments(thread);
  const currentHeadComment = comments.find((comment) => commentCommitOid(comment) === expectedHead);
  if (currentHeadComment) {
    return issue(
      "unresolved-current-head-thread",
      payloadPath,
      REVIEW_THREAD_ADJUDICATION_MESSAGE,
      commentSummary(currentHeadComment),
    );
  }

  const newestComment = comments.at(-1);
  return issue(
    "unresolved-thread-without-current-head-comment",
    payloadPath,
    "Unresolved review thread is not outdated but has no comment bound to the current head; route to SO/EM adjudication to classify the reviewer finding as accepted, false_positive, or out_of_scope, then use gh api evidence-bearing replies and resolve/dismiss when appropriate. Do not rely on author self-approval.",
    newestComment ? commentSummary(newestComment) : String(thread?.id ?? ""),
  );
}

export async function runReviewThreadGateValidation(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  if (!options.payloadPath) {
    return {
      ok: false,
      issues: [
        {
          ruleId: "review-thread-gate.missing-payload",
          file: "<args>",
          line: 1,
          message: "A review thread GraphQL payload path is required. Use --payload <path>.",
        },
      ],
      metadata: {},
    };
  }

  const payloadPath = path.resolve(cwd, options.payloadPath);
  const commandRunner = options.commandRunner ?? defaultCommandRunner;
  let expectedHead;
  try {
    expectedHead = await resolveExpectedHead({
      cwd,
      expectedHead: options.expectedHead,
      commandRunner,
    });
  } catch (error) {
    return {
      ok: false,
      issues: [
        issue(
          "current-head-unavailable",
          payloadPath,
          "Could not resolve current git HEAD; pass --head <sha> or run inside a git checkout",
          error.stderr?.trim() || error.stdout?.trim() || error.message,
        ),
      ],
      metadata: { payloadPath },
    };
  }

  let payload;
  try {
    payload = JSON.parse(await readFile(payloadPath, "utf8"));
  } catch (error) {
    return {
      ok: false,
      issues: [
        issue(
          error instanceof SyntaxError ? "invalid-json" : "payload-read-failed",
          payloadPath,
          error instanceof SyntaxError
            ? "Review thread payload must contain valid JSON"
            : "Review thread payload could not be read",
          error.message,
        ),
      ],
      metadata: { payloadPath, expectedHead },
    };
  }

  const issues = [];
  if (!isSha(expectedHead)) {
    issues.push(issue("invalid-expected-head", payloadPath, "Expected head must be a SHA string", String(expectedHead)));
  }

  const pullRequest = pullRequestFromPayload(payload);
  if (!isObject(pullRequest)) {
    issues.push(
      issue(
        "missing-pull-request",
        payloadPath,
        "GraphQL payload must include data.repository.pullRequest",
      ),
    );
  }

  const prHead = pullRequest?.headRefOid;
  if (pullRequest && !isSha(prHead)) {
    issues.push(issue("invalid-payload-head", payloadPath, "pullRequest.headRefOid must be a SHA string"));
  } else if (pullRequest && prHead !== expectedHead) {
    issues.push(
      issue(
        "stale-payload-head",
        payloadPath,
        "pullRequest.headRefOid must match the expected head",
        `${prHead} != ${expectedHead}`,
      ),
    );
  }

  const threads = pullRequest?.reviewThreads?.nodes;
  if (pullRequest && !Array.isArray(threads)) {
    issues.push(
      issue(
        "invalid-review-threads",
        payloadPath,
        "pullRequest.reviewThreads.nodes must be an array",
      ),
    );
  }

  const unresolvedCurrentHeadIssues = [];
  if (Array.isArray(threads)) {
    for (const thread of threads) {
      if (!isObject(thread)) {
        issues.push(issue("invalid-review-thread", payloadPath, "Review thread must be an object"));
        continue;
      }
      if (thread.isResolved === true || thread.isOutdated === true) continue;
      const threadIssue = unresolvedThreadIssue({ payloadPath, thread, expectedHead });
      unresolvedCurrentHeadIssues.push(threadIssue);
      issues.push(threadIssue);
    }
  }

  return {
    ok: issues.length === 0,
    issues,
    metadata: {
      expectedHead,
      prHead,
      threadCount: Array.isArray(threads) ? threads.length : 0,
      unresolvedCurrentHeadThreadCount: unresolvedCurrentHeadIssues.length,
    },
  };
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--payload") {
      args.payloadPath = argv[index + 1];
      index += 1;
    } else if (arg === "--head") {
      args.expectedHead = argv[index + 1];
      index += 1;
    }
  }
  return args;
}

async function main() {
  const result = await runReviewThreadGateValidation(parseArgs(process.argv.slice(2)));
  console.log(JSON.stringify(result, null, 2));
  if (!result.ok) process.exitCode = 1;
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
  main().catch((error) => {
    console.error(
      JSON.stringify(
        {
          ok: false,
          issues: [
            {
              ruleId: "review-thread-gate.unhandled-error",
              file: "<runtime>",
              line: 1,
              message: error.message,
            },
          ],
          metadata: {},
        },
        null,
        2,
      ),
    );
    process.exitCode = 1;
  });
}
