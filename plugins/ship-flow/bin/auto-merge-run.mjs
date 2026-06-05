#!/usr/bin/env node
import { execFile } from "node:child_process";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import { runAutoMergeReadinessCollect } from "./auto-merge-readiness-collect.mjs";

const execFileAsync = promisify(execFile);

const PR_QUERY = `query($owner: String!, $name: String!, $number: Int!) {
  repository(owner: $owner, name: $name) {
    pullRequest(number: $number) {
      id
      number
      state
      isDraft
      mergeable
      mergeStateStatus
      headRefOid
      autoMergeRequest { enabledAt mergeMethod enabledBy { login } }
    }
  }
}`;

const ENABLE_AUTO_MERGE_MUTATION = `mutation($pullRequestId: ID!, $expectedHeadOid: GitObjectID!, $mergeMethod: PullRequestMergeMethod!) {
  enablePullRequestAutoMerge(input: { pullRequestId: $pullRequestId, expectedHeadOid: $expectedHeadOid, mergeMethod: $mergeMethod }) {
    pullRequest {
      number
      state
      autoMergeRequest { enabledAt mergeMethod enabledBy { login } }
    }
  }
}`;

const MERGE_MUTATION = `mutation($pullRequestId: ID!, $expectedHeadOid: GitObjectID!, $mergeMethod: PullRequestMergeMethod!) {
  mergePullRequest(input: { pullRequestId: $pullRequestId, expectedHeadOid: $expectedHeadOid, mergeMethod: $mergeMethod }) {
    pullRequest {
      number
      state
      merged
      mergedAt
      mergeCommit { oid }
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
  if (!owner || !name) throw new Error("--repo must be in owner/name format");
  return { owner, name };
}

function parseJson(stdout, description) {
  try {
    return JSON.parse(stdout);
  } catch (error) {
    throw new Error(`${description} did not return valid JSON: ${error.message}`);
  }
}

async function runGhJson(ghRunner, args, { cwd, description }) {
  return parseJson(await ghRunner(args, { cwd }), description);
}

function graphQlArgs(query, values) {
  const args = ["api", "graphql", "-f", `query=${query}`];
  for (const [key, value] of Object.entries(values)) {
    const flag = typeof value === "number" ? "-F" : "-f";
    args.push(flag, `${key}=${value}`);
  }
  return args;
}

function errorText(error) {
  return [error.message, error.stderr, error.stdout]
    .filter((value) => typeof value === "string" && value.length > 0)
    .join("\n");
}

function canDirectMergeFromAutoMergeError(error, { allowDirectMergeUnstable }) {
  const text = errorText(error);
  if (text.includes("clean status")) {
    return { ok: true, reason: "clean_status" };
  }
  if (text.includes("unstable status")) {
    return allowDirectMergeUnstable
      ? { ok: true, reason: "unstable_status_policy_opt_in" }
      : { ok: false, reason: "unstable_status_requires_policy_opt_in" };
  }
  return { ok: false, reason: "native_auto_merge_failed" };
}

async function lookupPullRequest({ cwd, repo, prNumber, ghRunner }) {
  const { owner, name } = parseRepo(repo);
  const payload = await runGhJson(
    ghRunner,
    graphQlArgs(PR_QUERY, { owner, name, number: Number(prNumber) }),
    { cwd, description: "PR lookup" },
  );
  const pullRequest = payload?.data?.repository?.pullRequest;
  if (!pullRequest?.id || !pullRequest?.headRefOid) {
    throw new Error("PR lookup response did not include id and headRefOid");
  }
  return pullRequest;
}

async function enableNativeAutoMerge({ cwd, ghRunner, pullRequestId, expectedHeadOid, mergeMethod }) {
  return await runGhJson(
    ghRunner,
    graphQlArgs(ENABLE_AUTO_MERGE_MUTATION, {
      pullRequestId,
      expectedHeadOid,
      mergeMethod,
    }),
    { cwd, description: "enable auto-merge" },
  );
}

async function directMerge({ cwd, ghRunner, pullRequestId, expectedHeadOid, mergeMethod }) {
  return await runGhJson(
    ghRunner,
    graphQlArgs(MERGE_MUTATION, {
      pullRequestId,
      expectedHeadOid,
      mergeMethod,
    }),
    { cwd, description: "direct merge" },
  );
}

export async function runAutoMerge(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  const prNumber = Number(options.prNumber);
  if (!Number.isInteger(prNumber) || prNumber <= 0) throw new Error("--pr must be a positive integer");
  const repo = options.repo;
  parseRepo(repo);

  const mergeMethod = options.mergeMethod ?? "SQUASH";
  const ghRunner = options.ghRunner ?? defaultGhRunner;
  const collect = options.collect ?? runAutoMergeReadinessCollect;
  if (options.mode === "off") {
    throw new Error("auto-merge-run requires semantic review mode required or auto");
  }
  const readiness = await collect({
    cwd,
    prNumber,
    repo,
    outDir: options.outDir,
    requiredChecks: options.requiredChecks,
    requiredIndependentApprovals: options.requiredIndependentApprovals,
    mode: options.mode,
    policyPath: options.policyPath,
  });

  if (readiness.ready !== true) {
    return {
      status: readiness.status ?? "blocked",
      mutated: false,
      nextAction: readiness.nextAction,
      readiness,
    };
  }

  const pullRequest = await lookupPullRequest({ cwd, repo, prNumber, ghRunner });
  const expectedHeadOid = pullRequest.headRefOid;
  if (readiness.headSha && readiness.headSha !== expectedHeadOid) {
    return {
      status: "blocked",
      mutated: false,
      nextAction: "recollect_readiness_for_current_head",
      readiness,
      headSha: expectedHeadOid,
    };
  }

  try {
    const result = await enableNativeAutoMerge({
      cwd,
      ghRunner,
      pullRequestId: pullRequest.id,
      expectedHeadOid,
      mergeMethod,
    });
    return {
      status: "auto_merge_enabled",
      mutated: true,
      prNumber,
      repo,
      headSha: expectedHeadOid,
      readiness,
      result: result?.data?.enablePullRequestAutoMerge?.pullRequest,
    };
  } catch (error) {
    const decision = canDirectMergeFromAutoMergeError(error, {
      allowDirectMergeUnstable: options.allowDirectMergeUnstable === true,
    });
    if (!decision.ok) {
      return {
        status: "blocked",
        mutated: false,
        prNumber,
        repo,
        headSha: expectedHeadOid,
        readiness,
        nextAction:
          decision.reason === "unstable_status_requires_policy_opt_in"
            ? "wait_for_github_merge_state_or_allow_unstable_direct_merge"
            : "inspect_native_auto_merge_error",
        error: error.message,
      };
    }

    const result = await directMerge({
      cwd,
      ghRunner,
      pullRequestId: pullRequest.id,
      expectedHeadOid,
      mergeMethod,
    });
    return {
      status: "merged",
      mutated: true,
      prNumber,
      repo,
      headSha: expectedHeadOid,
      readiness,
      directMergeReason: decision.reason,
      result: result?.data?.mergePullRequest?.pullRequest,
    };
  }
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

export function parseAutoMergeRunArgs(argv) {
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
    } else if (arg === "--merge-method") {
      args.mergeMethod = cliValue(argv, index, arg).toUpperCase();
      index += 1;
    } else if (arg === "--required-check") {
      args.requiredChecks.push(cliValue(argv, index, arg));
      index += 1;
    } else if (arg === "--required-independent-approvals") {
      args.requiredIndependentApprovals = cliIntegerValue(argv, index, arg);
      index += 1;
    } else if (arg === "--allow-direct-merge-unstable") {
      args.allowDirectMergeUnstable = true;
    }
  }
  return args;
}

async function main() {
  const result = await runAutoMerge(parseAutoMergeRunArgs(process.argv.slice(2)));
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== "auto_merge_enabled" && result.status !== "merged") {
    process.exitCode = 1;
  }
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
  main().catch((error) => {
    console.error(
      JSON.stringify(
        {
          status: "unknown",
          mutated: false,
          nextAction: "inspect_auto_merge_run_runtime_error",
          error: error.message,
        },
        null,
        2,
      ),
    );
    process.exitCode = 1;
  });
}
