#!/usr/bin/env node
import { execFile } from "node:child_process";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import { runAutoMergeReadiness } from "./auto-merge-readiness.mjs";
import { runReviewThreadGateValidation } from "./review-thread-gate.mjs";
import { runSemanticReviewGate } from "./semantic-review-gate.mjs";

const execFileAsync = promisify(execFile);

const REVIEW_THREADS_QUERY = `query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      headRefOid
      reviewThreads(last: 100) {
        nodes {
          id
          isResolved
          isOutdated
          comments(last: 20) {
            nodes {
              author { login }
              path
              line
              body
              url
              commit { oid }
              originalCommit { oid }
            }
          }
        }
      }
    }
  }
}`;

async function defaultGhRunner(args, { cwd }) {
  const { stdout } = await execFileAsync("gh", args, {
    cwd,
    maxBuffer: 20 * 1024 * 1024,
  });
  return stdout;
}

function parseRepo(repo) {
  const [owner, name] = String(repo ?? "").split("/");
  if (!owner || !name) {
    throw new Error("--repo must be in owner/name format");
  }
  return { owner, name };
}

async function writeJson(filePath, value) {
  await writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

function parseJsonOutput(stdout, description) {
  try {
    return JSON.parse(stdout);
  } catch (error) {
    throw new Error(`${description} command did not return valid JSON: ${error.message}`);
  }
}

async function runGhJson(commandRunner, args, { cwd, description }) {
  return parseJsonOutput(await commandRunner(args, { cwd }), description);
}

export async function runAutoMergeReadinessCollect(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  const prNumber = Number(options.prNumber);
  if (!Number.isInteger(prNumber) || prNumber <= 0) {
    throw new Error("--pr must be a positive integer");
  }

  const repo = options.repo;
  const { owner, name } = parseRepo(repo);
  const outDir = path.resolve(cwd, options.outDir ?? ".context/ship-flow-auto-merge");
  const requiredChecks = Array.isArray(options.requiredChecks) ? options.requiredChecks : [];
  const requiredIndependentApprovals = Number.isInteger(options.requiredIndependentApprovals)
    ? Math.max(0, options.requiredIndependentApprovals)
    : 0;
  const mode = options.mode ?? "required";
  const policyPath = options.policyPath;
  const commandRunner = options.commandRunner ?? defaultGhRunner;

  await mkdir(outDir, { recursive: true });

  const paths = {
    pr: path.join(outDir, `pr-${prNumber}-readiness-pr.json`),
    labels: path.join(outDir, `pr-${prNumber}-labels.json`),
    comments: path.join(outDir, `pr-${prNumber}-comments.json`),
    reviewThreads: path.join(outDir, `pr-${prNumber}-review-threads.json`),
    semanticGate: path.join(outDir, `pr-${prNumber}-semantic-gate-result.json`),
    reviewThreadGate: path.join(outDir, `pr-${prNumber}-review-thread-gate-result.json`),
    readiness: path.join(outDir, `pr-${prNumber}-readiness-result.json`),
  };

  const pr = await runGhJson(
    commandRunner,
    [
      "pr",
      "view",
      String(prNumber),
      "--repo",
      repo,
      "--json",
      "state,isDraft,mergeable,mergeStateStatus,statusCheckRollup,headRefOid,author,reviews,autoMergeRequest",
    ],
    { cwd, description: "PR snapshot" },
  );
  const labels = await runGhJson(
    commandRunner,
    ["pr", "view", String(prNumber), "--repo", repo, "--json", "labels", "--jq", ".labels"],
    { cwd, description: "PR labels" },
  );
  const comments = await runGhJson(
    commandRunner,
    ["api", `repos/${owner}/${name}/issues/${prNumber}/comments`, "--paginate", "--slurp"],
    { cwd, description: "PR comments" },
  );
  const reviewThreads = await runGhJson(
    commandRunner,
    [
      "api",
      "graphql",
      "-f",
      `owner=${owner}`,
      "-f",
      `name=${name}`,
      "-F",
      `number=${prNumber}`,
      "-f",
      `query=${REVIEW_THREADS_QUERY}`,
    ],
    { cwd, description: "PR review threads" },
  );

  await writeJson(paths.pr, pr);
  await writeJson(paths.labels, labels);
  await writeJson(paths.comments, comments);
  await writeJson(paths.reviewThreads, reviewThreads);

  const headSha = pr.headRefOid;
  const semanticGate = await runSemanticReviewGate({
    cwd,
    expectedHead: headSha,
    labelsJsonPath: paths.labels,
    commentsJsonPath: paths.comments,
    mode,
    policyPath,
  });
  await writeJson(paths.semanticGate, semanticGate);

  const reviewThreadGate = await runReviewThreadGateValidation({
    cwd,
    expectedHead: headSha,
    payloadPath: paths.reviewThreads,
  });
  await writeJson(paths.reviewThreadGate, reviewThreadGate);

  const readiness = await runAutoMergeReadiness({
    cwd,
    prJsonPath: paths.pr,
    semanticGateJsonPath: paths.semanticGate,
    threadGateJsonPath: paths.reviewThreadGate,
    requiredChecks,
    requiredIndependentApprovals,
  });
  await writeJson(paths.readiness, readiness);

  return {
    ...readiness,
    prNumber,
    repo,
    headSha,
    paths,
  };
}

function cliValue(argv, index, flag) {
  const value = argv[index + 1];
  if (typeof value !== "string" || value.length === 0 || value.startsWith("--")) {
    throw new Error(`${flag} requires a value`);
  }
  return value;
}

function cliIntegerValue(argv, index, flag) {
  const value = cliValue(argv, index, flag);
  const parsed = Number(value);
  if (!Number.isInteger(parsed) || parsed < 0) {
    throw new Error(`${flag} must be a non-negative integer`);
  }
  return parsed;
}

export function parseAutoMergeReadinessCollectArgs(argv) {
  const args = { requiredChecks: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--pr") {
      args.prNumber = cliValue(argv, index, arg);
      index += 1;
    } else if (arg === "--repo") {
      args.repo = cliValue(argv, index, arg);
      index += 1;
    } else if (arg === "--out-dir") {
      args.outDir = cliValue(argv, index, arg);
      index += 1;
    } else if (arg === "--mode") {
      args.mode = cliValue(argv, index, arg);
      index += 1;
    } else if (arg === "--policy-json") {
      args.policyPath = cliValue(argv, index, arg);
      index += 1;
    } else if (arg === "--required-check") {
      args.requiredChecks.push(cliValue(argv, index, arg));
      index += 1;
    } else if (arg === "--required-independent-approvals") {
      args.requiredIndependentApprovals = cliIntegerValue(argv, index, arg);
      index += 1;
    }
  }
  return args;
}

export function formatUnhandledCollectError(error, options = {}) {
  const stderr = typeof error.stderr === "string" ? error.stderr.trim() : "";
  const stdout = typeof error.stdout === "string" ? error.stdout.trim() : "";
  const evidence = JSON.stringify({
    message: error.message,
    ...(stderr ? { stderr } : {}),
    ...(stdout ? { stdout } : {}),
  });
  return {
    ready: false,
    status: "unknown",
    blockers: [
      {
        ruleId: "auto-merge-readiness-collect.unhandled-error",
        file: "<runtime>",
        line: 1,
        message: error.message,
        evidence,
      },
    ],
    nextAction: "inspect_readiness_collect_runtime_error",
    metadata: {
      prNumber: options.prNumber,
      repo: options.repo,
      outDir: options.outDir,
      exitCode: error.code ?? error.exitCode,
    },
  };
}

async function main() {
  const args = parseAutoMergeReadinessCollectArgs(process.argv.slice(2));
  const result = await runAutoMergeReadinessCollect(args);
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== "ready") process.exitCode = 1;
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
  main().catch((error) => {
    let args = {};
    try {
      args = parseAutoMergeReadinessCollectArgs(process.argv.slice(2));
    } catch {
      args = {};
    }
    console.error(JSON.stringify(formatUnhandledCollectError(error, args), null, 2));
    process.exitCode = 1;
  });
}
