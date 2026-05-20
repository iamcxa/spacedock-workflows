import { readFile } from "node:fs/promises";
import path from "node:path";

export const DEFAULT_SEMANTIC_REVIEW_POLICY = Object.freeze({
  required_reviewers: ["codex_local", "break_point_probe"],
  local_review_key: "structured_review",
  required_dimensions: [
    "security",
    "type_design",
    "test_adequacy",
    "silent_failure",
    "workflow_ci",
    "verify_agent_worker_ownership",
    "cross_model_challenge",
  ],
  required_label: "ship-flow:semantic-review-required",
});

function stringArray(value, fallback) {
  if (!Array.isArray(value)) return [...fallback];
  const normalized = value
    .map((entry) => (typeof entry === "string" ? entry.trim() : ""))
    .filter(Boolean);
  return normalized.length > 0 ? normalized : [...fallback];
}

function extendedStringArray(value, fallback) {
  const normalized = stringArray(value, []);
  return [...new Set([...fallback, ...normalized])];
}

function nonEmptyString(value, fallback) {
  return typeof value === "string" && value.trim().length > 0 ? value.trim() : fallback;
}

export function normalizeSemanticReviewPolicy(policy = {}) {
  return {
    required_reviewers: stringArray(
      policy.required_reviewers,
      DEFAULT_SEMANTIC_REVIEW_POLICY.required_reviewers,
    ),
    local_review_key: nonEmptyString(
      policy.local_review_key,
      DEFAULT_SEMANTIC_REVIEW_POLICY.local_review_key,
    ),
    required_dimensions: extendedStringArray(
      policy.required_dimensions,
      DEFAULT_SEMANTIC_REVIEW_POLICY.required_dimensions,
    ),
    required_label: nonEmptyString(
      policy.required_label,
      DEFAULT_SEMANTIC_REVIEW_POLICY.required_label,
    ),
  };
}

export async function readSemanticReviewPolicy({ cwd = process.cwd(), policy, policyPath } = {}) {
  if (policy) return normalizeSemanticReviewPolicy(policy);
  if (!policyPath) return normalizeSemanticReviewPolicy();
  const absolutePath = path.resolve(cwd, policyPath);
  return normalizeSemanticReviewPolicy(JSON.parse(await readFile(absolutePath, "utf8")));
}
