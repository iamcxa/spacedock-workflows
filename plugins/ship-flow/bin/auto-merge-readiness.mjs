#!/usr/bin/env node
import { readFile } from "node:fs/promises";
import path from "node:path";
import { fileURLToPath } from "node:url";

function issue(ruleId, file, message, evidence = undefined) {
  return {
    ruleId: `auto-merge-readiness.${ruleId}`,
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
  if (!jsonPath) {
    return {
      ok: false,
      path: "<args>",
      issue: issue(
        "missing-input",
        "<args>",
        `${description} JSON path is required`,
      ),
    };
  }
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
      issue: issue(
        error instanceof SyntaxError ? "invalid-input-json" : "input-read-failed",
        absolutePath,
        `${description} JSON could not be ${error instanceof SyntaxError ? "parsed" : "read"}`,
        error.message,
      ),
    };
  }
}

function checkName(check) {
  return check?.name ?? check?.workflowName ?? check?.context ?? "";
}

function normalizeCheckState(check) {
  const status = String(check?.status ?? "").toUpperCase();
  const conclusion = String(check?.conclusion ?? "").toUpperCase();
  const state = String(check?.state ?? "").toUpperCase();
  if (status && status !== "COMPLETED") return "pending";
  if (conclusion === "SUCCESS" || conclusion === "NEUTRAL" || conclusion === "SKIPPED") {
    return "pass";
  }
  if (conclusion) return "fail";
  if (state === "SUCCESS") return "pass";
  if (state === "PENDING") return "pending";
  if (state) return "fail";
  return "pending";
}

function flattenChecks(value) {
  if (!Array.isArray(value)) return [];
  if (value.every((entry) => Array.isArray(entry))) return value.flat();
  return value;
}

function checkRollupFromPr(pr) {
  return flattenChecks(pr?.statusCheckRollup).filter(isObject);
}

const BLOCKING_MERGE_STATE_STATUSES = new Set(["BEHIND", "BLOCKED", "DIRTY", "DRAFT", "UNKNOWN"]);

function requiredCheckIssues({ pr, requiredChecks, prPath }) {
  const checks = checkRollupFromPr(pr);
  const blockers = [];
  const nextActions = [];
  for (const requiredCheck of requiredChecks) {
    const matches = checks.filter((check) => checkName(check) === requiredCheck);
    if (matches.length === 0) {
      blockers.push(
        issue(
          "required-check-missing",
          prPath,
          `Required check ${requiredCheck} is missing from statusCheckRollup`,
        ),
      );
      nextActions.push(`wait_for_required_check:${requiredCheck}`);
      continue;
    }
    const statusContextMatches = matches.filter(
      (check) => check.__typename === "StatusContext" || check.context,
    );
    const states = (statusContextMatches.length > 0 ? statusContextMatches : matches).map(
      normalizeCheckState,
    );
    if (states.includes("fail")) {
      blockers.push(
        issue(
          "required-check-failed",
          prPath,
          `Required check ${requiredCheck} failed`,
          requiredCheck,
        ),
      );
      nextActions.push(`fix_required_check:${requiredCheck}`);
    } else if (!states.includes("pass")) {
      blockers.push(
        issue(
          "required-check-pending",
          prPath,
          `Required check ${requiredCheck} is pending`,
          requiredCheck,
        ),
      );
      nextActions.push(`wait_for_required_check:${requiredCheck}`);
    }
  }
  return { blockers, nextActions };
}

function prStateIssues(pr, prPath) {
  const blockers = [];
  if (!isObject(pr)) {
    return {
      blockers: [issue("invalid-pr-json", prPath, "PR JSON must be an object")],
      nextAction: "collect_missing_readiness_inputs",
    };
  }
  if (pr.state && pr.state !== "OPEN") {
    blockers.push(
      issue("pr-not-open", prPath, "PR must be open before auto-merge can be enabled", String(pr.state)),
    );
  }
  if (pr.isDraft === true) {
    blockers.push(issue("pr-is-draft", prPath, "Draft PRs are not auto-merge ready"));
  }
  if (pr.mergeable !== "MERGEABLE") {
    blockers.push(
      issue(
        "pr-not-mergeable",
        prPath,
        "PR must be mergeable before auto-merge can be enabled",
        String(pr.mergeable),
      ),
    );
  }
  const mergeStateStatus = String(pr.mergeStateStatus ?? "UNKNOWN").toUpperCase();
  if (BLOCKING_MERGE_STATE_STATUSES.has(mergeStateStatus)) {
    blockers.push(
      issue(
        "pr-merge-state-blocking",
        prPath,
        "PR merge state must not be blocking before auto-merge can be enabled",
        mergeStateStatus,
      ),
    );
  }
  return {
    blockers,
    nextAction:
      blockers.find((blocker) => blocker.ruleId.endsWith("pr-not-open"))
        ? "update_pr_state"
        : blockers.find((blocker) => blocker.ruleId.endsWith("pr-not-mergeable"))
          ? "resolve_mergeability"
          : blockers.find((blocker) => blocker.ruleId.endsWith("pr-merge-state-blocking"))
            ? "wait_for_required_check:mergeStateStatus"
        : blockers.length > 0
          ? "update_pr_state"
          : undefined,
  };
}

function semanticGateIssues(semanticGate, semanticPath) {
  if (!isObject(semanticGate)) {
    return {
      blockers: [issue("invalid-semantic-gate-json", semanticPath, "Semantic gate JSON must be an object")],
      nextAction: "collect_missing_readiness_inputs",
    };
  }
  if (semanticGate.ok === true && semanticGate.required === false && semanticGate.status === "skipped") {
    return { blockers: [], nextAction: undefined };
  }
  if (semanticGate.ok !== true || semanticGate.status !== "valid") {
    return {
      blockers: [
        issue(
          "semantic-review-gate-failed",
          semanticPath,
          "Semantic review gate must be valid before auto-merge can be enabled",
          JSON.stringify({
            ok: semanticGate.ok,
            status: semanticGate.status,
            issues: semanticGate.issues ?? [],
          }),
        ),
      ],
      nextAction: "regenerate_semantic_review_packet",
    };
  }
  return { blockers: [], nextAction: undefined };
}

function threadGateIssues(threadGate, threadPath) {
  if (!isObject(threadGate)) {
    return {
      blockers: [issue("invalid-thread-gate-json", threadPath, "Review thread gate JSON must be an object")],
      nextAction: "collect_missing_readiness_inputs",
    };
  }
  if (threadGate.ok !== true) {
    return {
      blockers: [
        issue(
          "review-thread-gate-failed",
          threadPath,
          "Review thread gate must pass before auto-merge can be enabled; FO must route unresolved threads to SO/EM for in-thread gh api replies marked fixed, push-back: false positive, or needs captain decision, with code/test/SO-EM judgment evidence, then re-trigger the AI reviewer gate.",
          JSON.stringify(threadGate.issues ?? []),
        ),
      ],
      nextAction: "science_officer_em_adjudicate_review_threads",
    };
  }
  return { blockers: [], nextAction: undefined };
}

function loginFromActor(actor) {
  return typeof actor?.login === "string" ? actor.login : "";
}

function normalizeReviewNodes(pr) {
  const reviews = pr?.reviews;
  if (Array.isArray(reviews)) return reviews.filter(isObject);
  if (Array.isArray(reviews?.nodes)) return reviews.nodes.filter(isObject);
  if (Array.isArray(pr?.latestReviews)) return pr.latestReviews.filter(isObject);
  if (Array.isArray(pr?.latestReviews?.nodes)) return pr.latestReviews.nodes.filter(isObject);
  return [];
}

function latestReviewByAuthor(pr) {
  const latest = new Map();
  for (const review of normalizeReviewNodes(pr)) {
    const login = loginFromActor(review.author);
    if (!login) continue;
    const submittedAt = Date.parse(review.submittedAt ?? review.submitted_at ?? "");
    const previous = latest.get(login);
    const previousSubmittedAt = Date.parse(previous?.submittedAt ?? previous?.submitted_at ?? "");
    if (!previous || Number.isNaN(submittedAt) || Number.isNaN(previousSubmittedAt) || submittedAt >= previousSubmittedAt) {
      latest.set(login, review);
    }
  }
  return latest;
}

function reviewDecisionIssues({ pr, prPath, requiredIndependentApprovals }) {
  const requiredApprovals = Number.isInteger(requiredIndependentApprovals)
    ? Math.max(0, requiredIndependentApprovals)
    : 0;
  const prAuthorLogin = loginFromActor(pr?.author);
  const latestReviews = latestReviewByAuthor(pr);
  const activeChangeRequests = [];
  const independentApprovers = new Set();

  for (const [login, review] of latestReviews.entries()) {
    const state = String(review?.state ?? "").toUpperCase();
    if (state === "CHANGES_REQUESTED") {
      activeChangeRequests.push(login);
    } else if (state === "APPROVED" && login !== prAuthorLogin) {
      independentApprovers.add(login);
    }
  }

  const blockers = [];
  if (activeChangeRequests.length > 0) {
    blockers.push(
      issue(
        "review-changes-requested",
        prPath,
        "Active change requests must be adjudicated by SO/EM before auto-merge: answer each AI reviewer finding in-thread as fixed, push-back: false positive, or needs captain decision; include code behavior, test command/result, and SO/EM judgment evidence via gh api; then re-trigger the AI reviewer gate. Do not rely on author self-approval.",
        activeChangeRequests.join(","),
      ),
    );
  }
  if (independentApprovers.size < requiredApprovals) {
    blockers.push(
      issue(
        "independent-approval-missing",
        prPath,
        `Auto-merge requires ${requiredApprovals} independent approval(s); found ${independentApprovers.size}`,
        JSON.stringify({
          prAuthorLogin,
          independentApprovers: [...independentApprovers],
          requiredIndependentApprovals: requiredApprovals,
        }),
      ),
    );
  }

  return {
    blockers,
    nextAction:
      activeChangeRequests.length > 0
        ? "science_officer_em_adjudicate_review_feedback"
        : independentApprovers.size < requiredApprovals
          ? "wait_for_independent_review"
          : undefined,
    independentApproverCount: independentApprovers.size,
  };
}

function firstAction(...actions) {
  return actions.find((action) => typeof action === "string" && action.length > 0);
}

export async function runAutoMergeReadiness(options = {}) {
  const cwd = options.cwd ?? process.cwd();
  const requiredChecks = Array.isArray(options.requiredChecks) ? options.requiredChecks : [];
  const requiredIndependentApprovals = Number.isInteger(options.requiredIndependentApprovals)
    ? Math.max(0, options.requiredIndependentApprovals)
    : 0;
  const prJson = await readJsonFile(cwd, options.prJsonPath, "PR");
  const semanticGateJson = await readJsonFile(cwd, options.semanticGateJsonPath, "semantic gate");
  const threadGateJson = await readJsonFile(cwd, options.threadGateJsonPath, "review thread gate");

  const inputIssues = [prJson, semanticGateJson, threadGateJson]
    .filter((entry) => !entry.ok)
    .map((entry) => entry.issue);
  const metadata = {
    prPath: prJson.path,
    semanticGatePath: semanticGateJson.path,
    threadGatePath: threadGateJson.path,
    requiredChecks,
    requiredIndependentApprovals,
  };
  if (requiredChecks.length === 0) {
    return {
      ready: false,
      status: "unknown",
      blockers: [
        issue(
          "missing-required-checks",
          "<args>",
          "At least one --required-check value is required before auto-merge readiness can be evaluated",
        ),
      ],
      nextAction: "supply_required_checks",
      metadata,
    };
  }
  if (inputIssues.length > 0) {
    return {
      ready: false,
      status: "unknown",
      blockers: inputIssues,
      nextAction: "collect_missing_readiness_inputs",
      metadata,
    };
  }

  const prIssues = prStateIssues(prJson.value, prJson.path);
  const checkIssues = requiredCheckIssues({
    pr: prJson.value,
    requiredChecks,
    prPath: prJson.path,
  });
  const semanticIssues = semanticGateIssues(semanticGateJson.value, semanticGateJson.path);
  const threadIssues = threadGateIssues(threadGateJson.value, threadGateJson.path);
  const reviewIssues = reviewDecisionIssues({
    pr: prJson.value,
    prPath: prJson.path,
    requiredIndependentApprovals,
  });
  const blockers = [
    ...prIssues.blockers,
    ...checkIssues.blockers,
    ...semanticIssues.blockers,
    ...threadIssues.blockers,
    ...reviewIssues.blockers,
  ];

  if (blockers.length > 0) {
    return {
      ready: false,
      status: "blocked",
      blockers,
      nextAction: firstAction(
        prIssues.nextAction,
        checkIssues.nextActions[0],
        semanticIssues.nextAction,
        threadIssues.nextAction,
        reviewIssues.nextAction,
      ),
      metadata: {
        ...metadata,
        checkCount: checkRollupFromPr(prJson.value).length,
        independentApproverCount: reviewIssues.independentApproverCount,
      },
    };
  }

  return {
    ready: true,
    status: "ready",
    blockers: [],
    nextAction: "enable_auto_merge",
    metadata: {
      ...metadata,
      checkCount: checkRollupFromPr(prJson.value).length,
      independentApproverCount: reviewIssues.independentApproverCount,
    },
  };
}

function parseArgs(argv) {
  const args = { requiredChecks: [] };
  for (let index = 0; index < argv.length; index += 1) {
    const arg = argv[index];
    if (arg === "--pr-json") {
      args.prJsonPath = argv[++index];
    } else if (arg === "--semantic-gate-json") {
      args.semanticGateJsonPath = argv[++index];
    } else if (arg === "--thread-gate-json") {
      args.threadGateJsonPath = argv[++index];
    } else if (arg === "--required-check") {
      args.requiredChecks.push(argv[++index]);
    } else if (arg === "--required-independent-approvals") {
      args.requiredIndependentApprovals = Number(argv[++index]);
    }
  }
  return args;
}

async function main() {
  const result = await runAutoMergeReadiness(parseArgs(process.argv.slice(2)));
  console.log(JSON.stringify(result, null, 2));
  if (result.status !== "ready") process.exitCode = 1;
}

const currentFile = fileURLToPath(import.meta.url);
if (process.argv[1] && path.resolve(process.argv[1]) === currentFile) {
  main().catch((error) => {
    console.error(
      JSON.stringify(
        {
          ready: false,
          status: "unknown",
          blockers: [
            {
              ruleId: "auto-merge-readiness.unhandled-error",
              file: "<runtime>",
              line: 1,
              message: error.message,
            },
          ],
          nextAction: "inspect_readiness_runtime_error",
          metadata: {},
        },
        null,
        2,
      ),
    );
    process.exitCode = 1;
  });
}
