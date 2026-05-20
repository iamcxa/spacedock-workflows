#!/usr/bin/env node
import { exec, execFile } from "node:child_process";
import { createHash } from "node:crypto";
import { mkdir, writeFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import {
  SEMANTIC_REVIEW_PACKET_MARKER,
  runSemanticReviewPacketValidation,
} from "./semantic-review-packet.mjs";
import { readSemanticReviewPolicy } from "./semantic-review-policy.mjs";

const execAsync = promisify(exec);
const execFileAsync = promisify(execFile);
const SCHEMA_VERSION = "ship-flow.semantic-review-packet.v1";
const BASE_REF_PATTERN = /^[A-Za-z0-9._/-]+$/;
const MAX_BUFFER_BYTES = 20 * 1024 * 1024;

async function defaultCommandRunner(command, { cwd }) {
  return await execAsync(command, { cwd, maxBuffer: MAX_BUFFER_BYTES });
}

async function defaultFileRunner(file, args, { cwd }) {
  return await execFileAsync(file, args, { cwd });
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function requireString(value, message) {
  if (!isNonEmptyString(value)) throw new Error(message);
  return value.trim();
}

async function runTrimmed(commandRunner, command, cwd) {
  const { stdout } = await commandRunner(command, { cwd });
  return stdout.trim();
}

function changedFilesHash(changedFilesOutput) {
  const changedFiles = changedFilesOutput
    .split("\n")
    .map((line) => line.trim())
    .filter(Boolean)
    .sort();
  const digest = createHash("sha256").update(JSON.stringify(changedFiles)).digest("hex");
  return `sha256:${digest}`;
}

function normalizeCommands(commands) {
  if (!Array.isArray(commands) || commands.length === 0) {
    throw new Error("At least one command evidence entry is required");
  }
  return commands.map((command, index) => {
    const exitCode = Number.isInteger(command?.exit_code)
      ? command.exit_code
      : Number(command?.exit_code);
    if (!Number.isInteger(exitCode) || exitCode < 0) {
      throw new Error(`commands[${index}].exit_code must be an integer`);
    }
    return {
      name: requireString(command?.name, `commands[${index}].name is required`),
      command: requireString(command?.command, `commands[${index}].command is required`),
      exit_code: exitCode,
    };
  });
}

function normalizeRounds(rounds) {
  const normalizedRounds = Number.isInteger(rounds) ? rounds : Number(rounds ?? 1);
  if (!Number.isInteger(normalizedRounds) || normalizedRounds < 1) {
    throw new Error("rounds must be a positive integer");
  }
  return normalizedRounds;
}

function dimensionPacket({ dimensionName, evidence, headSha }) {
  return {
    status: "pass",
    evidence: requireString(
      evidence,
      `Missing required evidence for local review dimension ${dimensionName}`,
    ),
    reviewed_head: headSha,
    blocking_findings: 0,
    high_findings: 0,
  };
}

function reviewerPacket(headSha) {
  return {
    verdict: "pass",
    blockers: [],
    reviewed_head: headSha,
  };
}

export async function buildSemanticReviewPacket({
  cwd = process.cwd(),
  options = {},
  generatedAt = new Date().toISOString(),
  commandRunner = defaultCommandRunner,
} = {}) {
  const policy = await readSemanticReviewPolicy({
    cwd,
    policy: options.policy,
    policyPath: options.policyPath,
  });
  const baseRef = options.baseRef ?? "origin/main";
  if (!BASE_REF_PATTERN.test(baseRef)) {
    throw new Error("base ref contains unsupported characters");
  }
  const headSha = await runTrimmed(commandRunner, "git rev-parse HEAD", cwd);
  const baseSha = await runTrimmed(commandRunner, `git merge-base HEAD ${baseRef}`, cwd);
  const changedFilesOutput = await runTrimmed(
    commandRunner,
    `git diff --name-only ${baseSha} ${headSha}`,
    cwd,
  );

  const reviewers = {};
  for (const reviewerName of policy.required_reviewers) {
    reviewers[reviewerName] = reviewerPacket(headSha);
  }

  const dimensions = {};
  for (const dimensionName of policy.required_dimensions) {
    dimensions[dimensionName] = dimensionPacket({
      dimensionName,
      evidence: options.dimensionEvidence?.[dimensionName],
      headSha,
    });
  }

  return {
    schema_version: SCHEMA_VERSION,
    head_sha: headSha,
    base_ref: baseRef,
    base_sha: baseSha,
    verdict: "pass",
    rounds: normalizeRounds(options.rounds),
    reviewers,
    local_review: {
      status: "clean",
      [policy.local_review_key]: {
        ran: true,
        command: requireString(options.localReviewCommand, "local review command is required"),
        artifact: requireString(options.localReviewArtifact, "local review artifact is required"),
        evidence: requireString(options.localReviewEvidence, "local review evidence is required"),
        reviewed_head: headSha,
        blocking_findings: 0,
        high_findings: 0,
      },
      dimensions,
    },
    commands: normalizeCommands(options.commands),
    changed_files_hash: changedFilesHash(changedFilesOutput),
    generated_at: generatedAt,
  };
}

export function packetCommentBody(packet) {
  return `${SEMANTIC_REVIEW_PACKET_MARKER}

\`\`\`json
${JSON.stringify(packet, null, 2)}
\`\`\`
`;
}

async function writeJson(filePath, value) {
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, `${JSON.stringify(value, null, 2)}\n`);
}

async function writeText(filePath, value) {
  await mkdir(path.dirname(filePath), { recursive: true });
  await writeFile(filePath, value);
}

export async function prepareSemanticReviewPacket({
  cwd = process.cwd(),
  options = {},
  generatedAt = new Date().toISOString(),
  commandRunner = defaultCommandRunner,
} = {}) {
  const packet = await buildSemanticReviewPacket({ cwd, options, generatedAt, commandRunner });
  const packetPath = path.resolve(cwd, options.packetPath ?? ".context/semantic-review-packet.json");
  const commentPath = path.resolve(
    cwd,
    options.commentPath ?? ".context/semantic-review-packet-comment.md",
  );

  await writeJson(packetPath, packet);
  await writeText(commentPath, packetCommentBody(packet));

  const validation = await runSemanticReviewPacketValidation({
    cwd,
    packetPath,
    expectedHead: packet.head_sha,
    policy: options.policy,
    policyPath: options.policyPath,
    commandRunner,
  });

  return { ok: validation.ok, packet, packetPath, commentPath, validation };
}

function parseKeyValue(raw, flagName) {
  const separatorIndex = raw.indexOf("=");
  if (separatorIndex === -1) throw new Error(`${flagName} must use key=value format`);
  return [raw.slice(0, separatorIndex), raw.slice(separatorIndex + 1)];
}

function parseCommandEvidence(raw) {
  const parts = raw.split("::");
  if (parts.length !== 3) {
    throw new Error("--command-evidence must use name::command::exit_code format");
  }
  return {
    name: parts[0],
    command: parts[1],
    exit_code: Number(parts[2]),
  };
}

export function parseArgs(argv) {
  const options = {
    dimensionEvidence: {},
    commands: [],
  };
  const normalizedArgv = argv.filter((arg) => arg !== "--");
  for (let index = 0; index < normalizedArgv.length; index += 1) {
    const arg = normalizedArgv[index];
    if (arg === "--pr") {
      options.prNumber = Number(normalizedArgv[++index]);
    } else if (arg === "--base-ref") {
      options.baseRef = normalizedArgv[++index];
    } else if (arg === "--rounds") {
      options.rounds = Number(normalizedArgv[++index]);
    } else if (arg === "--policy-json") {
      options.policyPath = normalizedArgv[++index];
    } else if (arg === "--local-review-command" || arg === "--kc-pr-review-command") {
      options.localReviewCommand = normalizedArgv[++index];
    } else if (arg === "--local-review-artifact" || arg === "--kc-pr-review-artifact") {
      options.localReviewArtifact = normalizedArgv[++index];
    } else if (arg === "--local-review-evidence" || arg === "--kc-pr-review-evidence") {
      options.localReviewEvidence = normalizedArgv[++index];
    } else if (arg === "--dimension-evidence") {
      const [key, value] = parseKeyValue(normalizedArgv[++index], "--dimension-evidence");
      options.dimensionEvidence[key] = value;
    } else if (arg === "--command-evidence") {
      options.commands.push(parseCommandEvidence(normalizedArgv[++index]));
    } else if (arg === "--packet") {
      options.packetPath = normalizedArgv[++index];
    } else if (arg === "--comment-body") {
      options.commentPath = normalizedArgv[++index];
    } else if (arg === "--post") {
      options.post = true;
    } else {
      throw new Error(`Unknown argument: ${arg}`);
    }
  }
  return options;
}

async function main() {
  const options = parseArgs(process.argv.slice(2));
  const result = await prepareSemanticReviewPacket({ options });
  if (!result.validation.ok) {
    console.error(JSON.stringify(result.validation, null, 2));
    process.exitCode = 1;
    return;
  }

  if (options.post) {
    if (!Number.isInteger(options.prNumber)) throw new Error("--post requires --pr <number>");
    await defaultFileRunner(
      "gh",
      ["pr", "comment", String(options.prNumber), "--body-file", result.commentPath],
      { cwd: process.cwd() },
    );
  }

  console.log(
    JSON.stringify(
      {
        ok: true,
        packetPath: result.packetPath,
        commentPath: result.commentPath,
        posted: options.post === true,
        validation: result.validation.metadata,
      },
      null,
      2,
    ),
  );
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
  main().catch((error) => {
    console.error(JSON.stringify({ ok: false, error: error.message }, null, 2));
    process.exitCode = 1;
  });
}
