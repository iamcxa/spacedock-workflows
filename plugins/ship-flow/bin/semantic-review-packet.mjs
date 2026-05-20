#!/usr/bin/env node
import { exec } from "node:child_process";
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { promisify } from "node:util";

import { readSemanticReviewPolicy } from "./semantic-review-policy.mjs";

const execAsync = promisify(exec);
export const SEMANTIC_REVIEW_PACKET_SCHEMA_VERSION = "ship-flow.semantic-review-packet.v1";
export const SEMANTIC_REVIEW_PACKET_MARKER = "<!-- ship-flow-semantic-review-packet:v1 -->";
const SHA_PATTERN = /^[0-9a-f]{7,40}$/i;
const ISO_TIMESTAMP_PATTERN =
  /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$/;

function issue(ruleId, file, message, evidence = undefined) {
  return {
    ruleId: `semantic-review-packet.${ruleId}`,
    file,
    line: 1,
    message,
    ...(evidence ? { evidence } : {}),
  };
}

function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

function isNonEmptyString(value) {
  return typeof value === "string" && value.trim().length > 0;
}

function isSha(value) {
  return isNonEmptyString(value) && SHA_PATTERN.test(value);
}

function isNonNegativeInteger(value) {
  return Number.isInteger(value) && value >= 0;
}

function isIsoishString(value) {
  return (
    isNonEmptyString(value) &&
    ISO_TIMESTAMP_PATTERN.test(value) &&
    !Number.isNaN(Date.parse(value))
  );
}

async function defaultCommandRunner(command, { cwd }) {
  return await execAsync(command, { cwd });
}

async function resolveExpectedHead({ cwd, expectedHead, commandRunner }) {
  if (expectedHead) return expectedHead;
  const { stdout } = await commandRunner("git rev-parse HEAD", { cwd });
  return stdout.trim();
}

function validateFindingCounts({ issues, packetPath, target, prefix, label }) {
  if (!isNonNegativeInteger(target.blocking_findings)) {
    issues.push(
      issue(
        `${prefix}-invalid-findings`,
        packetPath,
        `${label} blocking_findings must be a non-negative integer`,
      ),
    );
  }
  if (!isNonNegativeInteger(target.high_findings)) {
    issues.push(
      issue(
        `${prefix}-invalid-findings`,
        packetPath,
        `${label} high_findings must be a non-negative integer`,
      ),
    );
  }
  if (
    isNonNegativeInteger(target.blocking_findings) &&
    isNonNegativeInteger(target.high_findings) &&
    (target.blocking_findings > 0 || target.high_findings > 0)
  ) {
    issues.push(
      issue(
        `${prefix}-findings`,
        packetPath,
        `${label} must have zero blocking and high findings`,
        `blocking=${target.blocking_findings}, high=${target.high_findings}`,
      ),
    );
  }
}

function validateReviewedHead({ issues, packetPath, target, prefix, label, packetHead }) {
  if (!isNonEmptyString(target.reviewed_head)) {
    issues.push(issue(`${prefix}-missing-reviewed-head`, packetPath, `${label} must include reviewed_head`));
  } else if (target.reviewed_head !== packetHead) {
    issues.push(
      issue(
        `${prefix}-stale-head`,
        packetPath,
        `${label} reviewed_head must match packet head_sha`,
        `${target.reviewed_head} != ${packetHead}`,
      ),
    );
  }
}

function validateNonEmptyStrings({ issues, packetPath, target, prefix, label, fields }) {
  for (const field of fields) {
    if (!isNonEmptyString(target[field])) {
      issues.push(
        issue(`${prefix}-missing-evidence`, packetPath, `${label}.${field} must be a non-empty string`),
      );
    }
  }
}

function validateLocalReview(packet, packetPath, issues, policy) {
  const localReview = packet.local_review;
  if (!isObject(localReview)) {
    issues.push(
      issue(
        "missing-local-review",
        packetPath,
        "local_review must be present as structured local review evidence",
      ),
    );
    return;
  }

  if (localReview.status !== "clean") {
    issues.push(
      issue("local-review-not-clean", packetPath, "local_review.status must be clean", String(localReview.status)),
    );
  }

  const localReviewEvidence = localReview[policy.local_review_key];
  if (!isObject(localReviewEvidence)) {
    issues.push(
      issue(
        "missing-local-review-evidence",
        packetPath,
        `local_review.${policy.local_review_key} must be present`,
      ),
    );
  } else {
    if (localReviewEvidence.ran !== true) {
      issues.push(
        issue(
          "local-review-evidence-not-run",
          packetPath,
          `local_review.${policy.local_review_key}.ran must be true`,
          String(localReviewEvidence.ran),
        ),
      );
    }
    validateReviewedHead({
      issues,
      packetPath,
      target: localReviewEvidence,
      prefix: "local-review-evidence",
      label: `local_review.${policy.local_review_key}`,
      packetHead: packet.head_sha,
    });
    validateFindingCounts({
      issues,
      packetPath,
      target: localReviewEvidence,
      prefix: "local-review-evidence",
      label: `local_review.${policy.local_review_key}`,
    });
    validateNonEmptyStrings({
      issues,
      packetPath,
      target: localReviewEvidence,
      prefix: "local-review-evidence",
      label: `local_review.${policy.local_review_key}`,
      fields: ["command", "artifact", "evidence"],
    });
  }

  if (!isObject(localReview.dimensions)) {
    issues.push(
      issue("missing-local-review-dimensions", packetPath, "local_review.dimensions must be present"),
    );
    return;
  }

  for (const dimensionName of policy.required_dimensions) {
    const dimension = localReview.dimensions[dimensionName];
    if (!isObject(dimension)) {
      issues.push(
        issue("missing-local-review-dimension", packetPath, `Missing required local review dimension ${dimensionName}`),
      );
      continue;
    }
    if (dimension.status !== "pass") {
      issues.push(
        issue(
          "local-review-dimension-failed",
          packetPath,
          `Local review dimension ${dimensionName} must have status pass`,
          String(dimension.status),
        ),
      );
    }
    validateReviewedHead({
      issues,
      packetPath,
      target: dimension,
      prefix: "local-review-dimension",
      label: `local_review.dimensions.${dimensionName}`,
      packetHead: packet.head_sha,
    });
    validateFindingCounts({
      issues,
      packetPath,
      target: dimension,
      prefix: "local-review-dimension",
      label: `local_review.dimensions.${dimensionName}`,
    });
    validateNonEmptyStrings({
      issues,
      packetPath,
      target: dimension,
      prefix: "local-review-dimension",
      label: `local_review.dimensions.${dimensionName}`,
      fields: ["evidence"],
    });
  }
}

function validateReviewers(packet, packetPath, issues, policy) {
  if (!isObject(packet.reviewers)) {
    issues.push(issue("invalid-reviewers", packetPath, "reviewers must be an object"));
    return;
  }

  for (const reviewerName of policy.required_reviewers) {
    const reviewer = packet.reviewers[reviewerName];
    if (!isObject(reviewer)) {
      issues.push(issue("missing-reviewer", packetPath, `Missing required reviewer ${reviewerName}`));
      continue;
    }
    if (reviewer.verdict !== "pass") {
      issues.push(
        issue("reviewer-failed", packetPath, `Required reviewer ${reviewerName} must have verdict pass`, String(reviewer.verdict)),
      );
    }
    if (!Array.isArray(reviewer.blockers)) {
      issues.push(
        issue("reviewer-blockers", packetPath, `Required reviewer ${reviewerName} blockers must be an array`),
      );
    } else if (reviewer.blockers.length > 0) {
      issues.push(
        issue("reviewer-blockers", packetPath, `Required reviewer ${reviewerName} must have no blockers`, reviewer.blockers.join("; ")),
      );
    }
    validateReviewedHead({
      issues,
      packetPath,
      target: reviewer,
      prefix: "reviewer",
      label: `reviewers.${reviewerName}`,
      packetHead: packet.head_sha,
    });
  }
}

function validateCommands(packet, packetPath, issues) {
  if (!Array.isArray(packet.commands)) {
    issues.push(issue("invalid-commands", packetPath, "commands must be an array"));
  } else if (packet.commands.length === 0) {
    issues.push(issue("empty-commands", packetPath, "commands must include at least one command evidence entry"));
  } else {
    for (const [index, command] of packet.commands.entries()) {
      if (!isObject(command)) {
        issues.push(issue("invalid-command", packetPath, `commands[${index}] must be an object`));
        continue;
      }
      if (!isNonEmptyString(command.name)) {
        issues.push(issue("invalid-command", packetPath, `commands[${index}].name must be non-empty`));
      }
      if (!isNonEmptyString(command.command)) {
        issues.push(issue("invalid-command", packetPath, `commands[${index}].command must be non-empty`));
      }
      if (!Number.isInteger(command.exit_code)) {
        issues.push(issue("invalid-command", packetPath, `commands[${index}].exit_code must be an integer`));
      } else if (command.exit_code !== 0) {
        issues.push(issue("command-failed", packetPath, `Command ${command.name || index} must have exit_code 0`, String(command.exit_code)));
      }
    }
  }
}

export async function runSemanticReviewPacketValidation(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  if (!options.packetPath) {
    return {
      ok: false,
      issues: [
        {
          ruleId: "semantic-review-packet.missing-packet",
          file: "<args>",
          line: 1,
          message: "A packet JSON file path is required. Use --packet <path>.",
        },
      ],
      metadata: {},
    };
  }

  const packetPath = path.resolve(cwd, options.packetPath);
  const commandRunner = options.commandRunner ?? defaultCommandRunner;
  const policy = await readSemanticReviewPolicy({
    cwd,
    policy: options.policy,
    policyPath: options.policyPath,
  });
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
          packetPath,
          "Could not resolve current git HEAD; pass --head <sha> or run inside a git checkout",
          error.stderr?.trim() || error.stdout?.trim() || error.message,
        ),
      ],
      metadata: { packetPath },
    };
  }

  let packet;
  try {
    packet = JSON.parse(await readFile(packetPath, "utf8"));
  } catch (error) {
    return {
      ok: false,
      issues: [
        issue(
          error instanceof SyntaxError ? "invalid-json" : "packet-read-failed",
          packetPath,
          error instanceof SyntaxError ? "Packet file must contain valid JSON" : "Packet file could not be read",
          error.message,
        ),
      ],
      metadata: { packetPath, expectedHead },
    };
  }
  if (!isObject(packet)) {
    return {
      ok: false,
      issues: [issue("invalid-packet", packetPath, "Packet JSON must be a top-level object")],
      metadata: { packetPath, expectedHead },
    };
  }

  const issues = [];
  if (packet.schema_version !== SEMANTIC_REVIEW_PACKET_SCHEMA_VERSION) {
    issues.push(
      issue(
        "invalid-schema-version",
        packetPath,
        `schema_version must be ${SEMANTIC_REVIEW_PACKET_SCHEMA_VERSION}`,
        String(packet.schema_version),
      ),
    );
  }
  if (!isSha(packet.head_sha)) {
    issues.push(issue("invalid-head-sha", packetPath, "head_sha must be a SHA string"));
  }
  if (expectedHead && packet.head_sha !== expectedHead) {
    issues.push(issue("stale-head", packetPath, "head_sha must match the expected head", `${packet.head_sha} != ${expectedHead}`));
  }
  if (!isNonEmptyString(packet.base_ref)) {
    issues.push(issue("invalid-base-ref", packetPath, "base_ref must be a non-empty string"));
  }
  if (!isSha(packet.base_sha)) {
    issues.push(issue("invalid-base-sha", packetPath, "base_sha must be a SHA string"));
  }
  if (packet.verdict !== "pass" && packet.verdict !== "fail") {
    issues.push(issue("invalid-verdict", packetPath, "verdict must be pass or fail"));
  } else if (packet.verdict !== "pass") {
    issues.push(issue("failing-verdict", packetPath, "Only verdict pass is valid for a successful semantic review packet"));
  }
  if (!Number.isInteger(packet.rounds) || packet.rounds < 1) {
    issues.push(issue("invalid-rounds", packetPath, "rounds must be a positive integer"));
  }
  if (!isNonEmptyString(packet.changed_files_hash)) {
    issues.push(issue("invalid-changed-files-hash", packetPath, "changed_files_hash must be a non-empty string"));
  }
  if (!isIsoishString(packet.generated_at)) {
    issues.push(issue("invalid-generated-at", packetPath, "generated_at must be an ISO-ish date string"));
  }

  validateCommands(packet, packetPath, issues);
  validateReviewers(packet, packetPath, issues, policy);
  validateLocalReview(packet, packetPath, issues, policy);

  return {
    ok: issues.length === 0,
    issues,
    metadata: {
      packetPath,
      expectedHead,
      schemaVersion: packet.schema_version,
      headSha: packet.head_sha,
      baseRef: packet.base_ref,
      baseSha: packet.base_sha,
      verdict: packet.verdict,
      rounds: packet.rounds,
      reviewers: isObject(packet.reviewers) ? Object.keys(packet.reviewers).sort() : [],
      localReviewKey: policy.local_review_key,
      localReviewStatus: isObject(packet.local_review) ? packet.local_review.status : undefined,
      localReviewDimensions: isObject(packet.local_review?.dimensions)
        ? Object.keys(packet.local_review.dimensions).sort()
        : [],
      commandCount: Array.isArray(packet.commands) ? packet.commands.length : 0,
    },
  };
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--packet") {
      args.packetPath = argv[index + 1];
      index += 1;
    } else if (arg === "--head") {
      args.expectedHead = argv[index + 1];
      index += 1;
    } else if (arg === "--policy-json") {
      args.policyPath = argv[index + 1];
      index += 1;
    }
  }
  return args;
}

async function main() {
  const result = await runSemanticReviewPacketValidation(parseArgs(process.argv.slice(2)));
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
              ruleId: "semantic-review-packet.unhandled-error",
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
