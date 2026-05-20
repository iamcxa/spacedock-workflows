#!/usr/bin/env node
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import { fileURLToPath } from "node:url";

import {
  SEMANTIC_REVIEW_PACKET_MARKER,
  runSemanticReviewPacketValidation,
} from "./semantic-review-packet.mjs";
import { readSemanticReviewPolicy } from "./semantic-review-policy.mjs";

const VALID_MODES = new Set(["auto", "required", "off"]);
export { SEMANTIC_REVIEW_PACKET_MARKER };

function gateIssue(ruleId, file, message, evidence = undefined) {
  return {
    ruleId: `semantic-review-gate.${ruleId}`,
    file,
    line: 1,
    message,
    ...(evidence ? { evidence } : {}),
  };
}

function isObject(value) {
  return Boolean(value) && typeof value === "object" && !Array.isArray(value);
}

async function readJsonFile(cwd, jsonPath, description) {
  const absolutePath = path.resolve(cwd, jsonPath);
  try {
    return {
      ok: true,
      path: absolutePath,
      value: JSON.parse(await readFile(absolutePath, "utf8")),
    };
  } catch (error) {
    return {
      ok: false,
      path: absolutePath,
      issue: gateIssue(
        error instanceof SyntaxError ? `invalid-${description}-json` : `${description}-read-failed`,
        absolutePath,
        `${description} JSON file could not be ${error instanceof SyntaxError ? "parsed" : "read"}`,
        error.message,
      ),
    };
  }
}

function flattenGithubApiArray(value) {
  if (!Array.isArray(value)) return [];
  if (value.every((entry) => Array.isArray(entry))) return value.flat();
  return value;
}

function normalizeLabels(value) {
  const source = isObject(value) && Array.isArray(value.labels) ? value.labels : value;
  return flattenGithubApiArray(source)
    .map((label) => {
      if (typeof label === "string") return label;
      if (isObject(label) && typeof label.name === "string") return label.name;
      return undefined;
    })
    .filter((label) => typeof label === "string" && label.length > 0)
    .sort();
}

function normalizeComments(value) {
  const source = isObject(value) && Array.isArray(value.comments) ? value.comments : value;
  return flattenGithubApiArray(source).filter(isObject);
}

function compareCommentsByNewest(left, right) {
  const leftTime = Date.parse(left.comment.created_at ?? "");
  const rightTime = Date.parse(right.comment.created_at ?? "");
  const leftHasTime = !Number.isNaN(leftTime);
  const rightHasTime = !Number.isNaN(rightTime);

  if (leftHasTime && rightHasTime && leftTime !== rightTime) return leftTime - rightTime;
  if (leftHasTime !== rightHasTime) return leftHasTime ? 1 : -1;
  return left.index - right.index;
}

function findNewestPacketComment(comments) {
  return comments
    .map((comment, index) => ({ comment, index }))
    .filter(
      ({ comment }) =>
        typeof comment.body === "string" &&
        comment.body.includes(SEMANTIC_REVIEW_PACKET_MARKER),
    )
    .sort(compareCommentsByNewest)
    .at(-1);
}

function extractPacketJson(comment, commentsFile) {
  const markerIndex = comment.body.indexOf(SEMANTIC_REVIEW_PACKET_MARKER);
  const afterMarker = comment.body.slice(markerIndex + SEMANTIC_REVIEW_PACKET_MARKER.length);
  const match = afterMarker.match(/```json\s*\n([\s\S]*?)```/i);
  if (!match) {
    return {
      ok: false,
      issue: gateIssue(
        "missing-json-block",
        commentsFile,
        "Marked semantic review packet comment must contain a fenced JSON block after the marker",
      ),
    };
  }

  try {
    return { ok: true, packet: JSON.parse(match[1]) };
  } catch (error) {
    return {
      ok: false,
      issue: gateIssue(
        "invalid-packet-json",
        commentsFile,
        "Marked semantic review packet comment contains malformed JSON",
        error.message,
      ),
    };
  }
}

export async function runSemanticReviewGate(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  const mode = options.mode ?? "auto";
  const policy = await readSemanticReviewPolicy({
    cwd,
    policy: options.policy,
    policyPath: options.policyPath,
  });
  const metadata = {
    mode,
    expectedHead: options.expectedHead,
    requiredLabel: policy.required_label,
  };

  if (!VALID_MODES.has(mode)) {
    return {
      ok: false,
      required: false,
      status: "invalid",
      issues: [gateIssue("invalid-mode", "<args>", "mode must be one of auto, required, or off", mode)],
      metadata,
    };
  }

  if (mode === "off") {
    return {
      ok: true,
      required: false,
      status: "skipped",
      issues: [],
      metadata: { ...metadata, skipReason: "mode-off" },
    };
  }

  if (!options.labelsJsonPath) {
    return {
      ok: false,
      required: mode === "required",
      status: "invalid",
      issues: [
        gateIssue("missing-labels-json", "<args>", "A labels JSON file path is required. Use --labels-json <path>."),
      ],
      metadata,
    };
  }

  const labelsJson = await readJsonFile(cwd, options.labelsJsonPath, "labels");
  if (!labelsJson.ok) {
    return {
      ok: false,
      required: mode === "required",
      status: "invalid",
      issues: [labelsJson.issue],
      metadata: { ...metadata, labelsPath: labelsJson.path },
    };
  }

  const labels = normalizeLabels(labelsJson.value);
  const required = mode === "required" || labels.includes(policy.required_label);
  const withLabelsMetadata = { ...metadata, labels, labelsPath: labelsJson.path };
  if (!required) {
    return {
      ok: true,
      required: false,
      status: "skipped",
      issues: [],
      metadata: { ...withLabelsMetadata, skipReason: "missing-required-label" },
    };
  }

  if (!options.commentsJsonPath) {
    return {
      ok: false,
      required,
      status: "missing",
      issues: [
        gateIssue(
          "missing-comments-json",
          "<args>",
          "A comments JSON file path is required when semantic review is required. Use --comments-json <path>.",
        ),
      ],
      metadata: withLabelsMetadata,
    };
  }

  const commentsJson = await readJsonFile(cwd, options.commentsJsonPath, "comments");
  if (!commentsJson.ok) {
    return {
      ok: false,
      required,
      status: "invalid",
      issues: [commentsJson.issue],
      metadata: { ...withLabelsMetadata, commentsPath: commentsJson.path },
    };
  }

  const comments = normalizeComments(commentsJson.value);
  const newestPacketComment = findNewestPacketComment(comments);
  const withCommentsMetadata = {
    ...withLabelsMetadata,
    commentsPath: commentsJson.path,
    commentCount: comments.length,
    marker: SEMANTIC_REVIEW_PACKET_MARKER,
  };
  if (!newestPacketComment) {
    return {
      ok: false,
      required,
      status: "missing",
      issues: [
        gateIssue(
          "missing-packet-comment",
          commentsJson.path,
          "No PR comment contains the semantic review packet marker",
        ),
      ],
      metadata: withCommentsMetadata,
    };
  }

  const packetCommentMetadata = {
    ...withCommentsMetadata,
    packetCommentId: newestPacketComment.comment.id,
    packetCommentCreatedAt: newestPacketComment.comment.created_at,
    packetCommentIndex: newestPacketComment.index,
  };
  const extracted = extractPacketJson(newestPacketComment.comment, commentsJson.path);
  if (!extracted.ok) {
    return {
      ok: false,
      required,
      status: "invalid",
      issues: [extracted.issue],
      metadata: packetCommentMetadata,
    };
  }

  const tempRoot = await mkdtemp(path.join(tmpdir(), "ship-flow-semantic-review-gate-"));
  try {
    const packetPath = path.join(tempRoot, "packet.json");
    await writeFile(packetPath, JSON.stringify(extracted.packet, null, 2));
    const packetResult = await runSemanticReviewPacketValidation({
      cwd,
      packetPath,
      expectedHead: options.expectedHead,
      policy,
      commandRunner: options.commandRunner,
    });
    return {
      ok: packetResult.ok,
      required,
      status: packetResult.ok ? "valid" : "invalid",
      issues: packetResult.issues,
      metadata: { ...packetCommentMetadata, packet: packetResult.metadata },
    };
  } finally {
    await rm(tempRoot, { recursive: true, force: true });
  }
}

function parseArgs(argv) {
  const args = {};
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--head") {
      args.expectedHead = argv[index + 1];
      index += 1;
    } else if (arg === "--labels-json") {
      args.labelsJsonPath = argv[index + 1];
      index += 1;
    } else if (arg === "--comments-json") {
      args.commentsJsonPath = argv[index + 1];
      index += 1;
    } else if (arg === "--mode") {
      args.mode = argv[index + 1];
      index += 1;
    } else if (arg === "--policy-json") {
      args.policyPath = argv[index + 1];
      index += 1;
    }
  }
  return args;
}

async function main() {
  const result = await runSemanticReviewGate(parseArgs(process.argv.slice(2)));
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
          required: true,
          status: "invalid",
          issues: [
            {
              ruleId: "semantic-review-gate.unhandled-error",
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
