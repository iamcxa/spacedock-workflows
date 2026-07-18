#!/usr/bin/env python3
"""Validate a v1 Ship-Flow closeout receipt without third-party packages."""

from __future__ import annotations

import argparse
import hashlib
import json
import os
import re
import subprocess
import sys
from datetime import datetime
from pathlib import Path, PurePosixPath
from typing import Any, NoReturn

SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
SHA40_RE = re.compile(r"^[0-9a-f]{40}$")
REPOSITORY_RE = re.compile(r"^[^/\s]+/[^/\s]+$")
WORKFLOW_RE = re.compile(r"^docs/[^/]+$")
SLUG_RE = re.compile(r"^[a-z0-9][a-z0-9-]*$")
PHASES = ("prepared", "awaiting_closeout_pr", "applied", "complete")
LANDING_STRATEGIES = ("rebase", "squash", "merge_commit")
STRATEGY_EVIDENCE = "topology+ordered-patch-ids+aggregate-patch-digest"
EMPTY_PATCH_ID = hashlib.sha1(b"ship-flow-empty-patch-v1\n").hexdigest()
RFC3339_RE = re.compile(
    r"^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d+)?(?:Z|[+-]\d{2}:\d{2})$"
)
BASE_REF_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._/-]*$")


def fail(reason: str, detail: str) -> NoReturn:
    print("verdict=STOP")
    print(f"reason={reason}")
    print(f"detail={detail}")
    raise SystemExit(1)


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(
        value, sort_keys=True, separators=(",", ":"), ensure_ascii=False
    ).encode("utf-8")


def sha256_hex(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def require_object(value: Any, label: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail("closeout-sentinel-invalid", f"{label} must be an object")
    return value


def require_exact_keys(value: dict[str, Any], keys: set[str], label: str) -> None:
    missing = sorted(keys - value.keys())
    extra = sorted(value.keys() - keys)
    if missing or extra:
        fail(
            "closeout-sentinel-invalid",
            f"{label} keys mismatch; missing={missing}, extra={extra}",
        )


def require_hash(value: Any, label: str) -> str:
    if not isinstance(value, str) or not SHA256_RE.fullmatch(value):
        fail("closeout-sentinel-invalid", f"{label} must be lowercase sha256")
    return value


def require_full_sha(value: Any, label: str) -> str:
    if not isinstance(value, str) or not SHA40_RE.fullmatch(value):
        fail("closeout-sentinel-invalid", f"{label} must be lowercase full sha")
    return value


def require_full_sha_array(
    value: Any, label: str, *, expected_length: int, unique: bool = False
) -> list[str]:
    if not isinstance(value, list) or len(value) != expected_length:
        fail(
            "closeout-sentinel-invalid",
            f"{label} must contain exactly {expected_length} entries",
        )
    checked = [require_full_sha(item, f"{label} entry") for item in value]
    if unique and len(set(checked)) != len(checked):
        fail("closeout-sentinel-invalid", f"{label} entries must be unique")
    return checked


def validate_landing_proof(
    landing: dict[str, Any], identity: dict[str, Any]
) -> None:
    require_exact_keys(
        landing,
        {
            "schema_version",
            "repository",
            "base_ref",
            "implementation_pr",
            "provider_merged_at",
            "landing_anchor",
            "base_before",
            "strategy",
            "strategy_evidence",
            "pr_commit_count",
            "source_commit_patch_ids",
            "source_patch_digest",
            "landing_commits",
            "landing_commit_patch_ids",
            "landing_patch_digest",
            "first_landing_commit",
            "last_landing_commit",
            "method_source",
        },
        "landing_proof",
    )
    if (
        isinstance(landing["schema_version"], bool)
        or not isinstance(landing["schema_version"], int)
        or landing["schema_version"] != 1
    ):
        fail("closeout-sentinel-invalid", "landing_proof schema_version must be 1")
    if landing["repository"] != identity["repository"]:
        fail("closeout-sentinel-invalid", "landing_proof repository must match identity")
    if landing["implementation_pr"] != identity["implementation_pr"]:
        fail(
            "closeout-sentinel-invalid",
            "landing_proof implementation_pr must match identity",
        )
    base_ref = landing["base_ref"]
    if (
        not isinstance(base_ref, str)
        or not BASE_REF_RE.fullmatch(base_ref)
        or ".." in base_ref
        or "//" in base_ref
        or base_ref.endswith(("/", "."))
    ):
        fail("closeout-sentinel-invalid", "landing_proof base_ref is invalid")
    merged_at = landing["provider_merged_at"]
    if not isinstance(merged_at, str) or not RFC3339_RE.fullmatch(merged_at):
        fail("closeout-sentinel-invalid", "provider_merged_at must be RFC3339")
    try:
        parsed_merged_at = datetime.fromisoformat(merged_at.replace("Z", "+00:00"))
    except ValueError:
        fail("closeout-sentinel-invalid", "provider_merged_at must be RFC3339")
    if parsed_merged_at.tzinfo is None:
        fail("closeout-sentinel-invalid", "provider_merged_at must include timezone")

    anchor = require_full_sha(landing["landing_anchor"], "landing_anchor")
    require_full_sha(landing["base_before"], "base_before")
    strategy = landing["strategy"]
    if strategy not in LANDING_STRATEGIES:
        fail("closeout-sentinel-invalid", "landing strategy is invalid")
    if landing["strategy_evidence"] != STRATEGY_EVIDENCE:
        fail("closeout-sentinel-invalid", "landing strategy_evidence is invalid")
    method_source = landing["method_source"]
    if method_source not in ("topology", "intent-discriminator"):
        fail("closeout-sentinel-invalid", "landing method_source is invalid")
    commit_count = landing["pr_commit_count"]
    if isinstance(commit_count, bool) or not isinstance(commit_count, int) or commit_count < 1:
        fail("closeout-sentinel-invalid", "pr_commit_count must be positive integer")
    require_full_sha_array(
        landing["source_commit_patch_ids"],
        "source_commit_patch_ids",
        expected_length=commit_count,
    )
    source_patch_digest = require_hash(
        landing["source_patch_digest"], "source_patch_digest"
    )

    landing_commit_count = 1 if strategy == "squash" else commit_count
    if strategy == "merge_commit":
        landing_commit_count += 1
    landing_commits = require_full_sha_array(
        landing["landing_commits"],
        "landing_commits",
        expected_length=landing_commit_count,
        unique=True,
    )
    landing_patch_count = 1 if strategy == "squash" else commit_count
    landing_patch_ids = require_full_sha_array(
        landing["landing_commit_patch_ids"],
        "landing_commit_patch_ids",
        expected_length=landing_patch_count,
    )
    landing_patch_digest = require_hash(
        landing["landing_patch_digest"], "landing_patch_digest"
    )
    if source_patch_digest != landing_patch_digest:
        fail(
            "closeout-sentinel-invalid",
            "source and landing aggregate patch digests must match",
        )
    source_patch_ids = landing["source_commit_patch_ids"]
    if strategy in ("rebase", "merge_commit") and source_patch_ids != landing_patch_ids:
        fail(
            "closeout-sentinel-invalid",
            "rebase/merge landing patch IDs must equal ordered source patch IDs",
        )
    first = require_full_sha(landing["first_landing_commit"], "first_landing_commit")
    last = require_full_sha(landing["last_landing_commit"], "last_landing_commit")
    if first != landing_commits[0] or last != landing_commits[-1]:
        fail(
            "closeout-sentinel-invalid",
            "first/last landing commits must match the ordered landing set",
        )
    if anchor != last:
        fail("closeout-sentinel-invalid", "landing_anchor must equal last_landing_commit")


def git_output(
    repo_root: Path, args: list[str], *, input_bytes: bytes | None = None
) -> bytes:
    try:
        result = subprocess.run(
            ["git", "-C", str(repo_root), *args],
            input=input_bytes,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as exc:
        fail("closeout-sentinel-invalid", f"cannot execute Git proof: {exc}")
    if result.returncode != 0:
        detail = result.stderr.decode("utf-8", errors="replace").strip()
        fail(
            "closeout-sentinel-invalid",
            f"Git proof command failed ({' '.join(args)}): {detail}",
        )
    return result.stdout


def patch_id_from_bytes(patch: bytes) -> str:
    if not patch:
        return EMPTY_PATCH_ID
    try:
        result = subprocess.run(
            ["git", "patch-id", "--stable"],
            input=patch,
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as exc:
        fail("closeout-sentinel-invalid", f"cannot execute Git patch proof: {exc}")
    fields = result.stdout.decode("ascii", errors="replace").split()
    if result.returncode != 0 or not fields or not SHA40_RE.fullmatch(fields[0]):
        fail("closeout-sentinel-invalid", "Git patch identity is unavailable")
    return fields[0]


def commit_patch_id(repo_root: Path, commit: str) -> str:
    parent_fields = git_output(
        repo_root, ["rev-list", "--parents", "-n", "1", commit]
    ).decode().split()
    if len(parent_fields) > 2:
        patch = git_output(
            repo_root,
            ["diff", "--no-ext-diff", "--binary", f"{commit}^1", commit],
        )
    else:
        patch = git_output(
            repo_root, ["show", "--format=", "--no-ext-diff", "--binary", commit]
        )
    return patch_id_from_bytes(patch)


def aggregate_patch_digest(repo_root: Path, base_before: str, anchor: str) -> str:
    patch = git_output(
        repo_root, ["diff", "--no-ext-diff", "--binary", base_before, anchor]
    )
    patch_id = patch_id_from_bytes(patch)
    return sha256_hex(f"{patch_id}\n".encode("ascii"))


def validate_landing_proof_against_git(
    receipt: dict[str, Any], repo_root: Path, source_commits_raw: str | None
) -> None:
    landing = receipt["landing_proof"]
    anchor = landing["landing_anchor"]
    base_before = landing["base_before"]
    base_ref = landing["base_ref"]
    for label, commit in (("landing_anchor", anchor), ("base_before", base_before)):
        git_output(repo_root, ["cat-file", "-e", f"{commit}^{{commit}}"])
    git_output(repo_root, ["rev-parse", "--verify", f"{base_ref}^{{commit}}"])
    try:
        reachable = subprocess.run(
            ["git", "-C", str(repo_root), "merge-base", "--is-ancestor", anchor, base_ref],
            stdout=subprocess.PIPE,
            stderr=subprocess.PIPE,
            check=False,
        )
    except OSError as exc:
        fail("closeout-sentinel-invalid", f"cannot execute Git reachability proof: {exc}")
    if reachable.returncode != 0:
        fail(
            "closeout-sentinel-invalid",
            "landing_anchor is not reachable from landing_proof.base_ref",
        )

    parent_fields = git_output(repo_root, ["rev-list", "--parents", "-n", "1", anchor]).decode().split()
    parents = parent_fields[1:]
    strategy = landing["strategy"]
    recorded_commits = landing["landing_commits"]
    if strategy == "rebase":
        if len(parents) != 1:
            fail("closeout-sentinel-invalid", "rebase anchor must have one parent")
        derived_commits = git_output(
            repo_root,
            ["rev-list", "--first-parent", "--reverse", f"{base_before}..{anchor}"],
        ).decode().splitlines()
        patch_commits = derived_commits
    elif strategy == "squash":
        if len(parents) != 1 or parents[0] != base_before:
            fail(
                "closeout-sentinel-invalid",
                "squash anchor parent must equal base_before",
            )
        derived_commits = [anchor]
        patch_commits = derived_commits

        if not source_commits_raw:
            fail(
                "closeout-sentinel-invalid",
                "squash proof requires authoritative --source-commits",
            )
        source_commits = source_commits_raw.split(",")
        if len(source_commits) != landing["pr_commit_count"]:
            fail(
                "closeout-sentinel-invalid",
                "authoritative source commit count does not match pr_commit_count",
            )
        for source_commit in source_commits:
            require_full_sha(source_commit, "authoritative source commit")
            git_output(repo_root, ["cat-file", "-e", f"{source_commit}^{{commit}}"])
        source_parent_fields = git_output(
            repo_root, ["rev-list", "--parents", "-n", "1", source_commits[0]]
        ).decode().split()
        if len(source_parent_fields) < 2:
            fail(
                "closeout-sentinel-invalid",
                "first authoritative source commit has no parent",
            )
        derived_source_patch_ids = [
            commit_patch_id(repo_root, commit) for commit in source_commits
        ]
        if derived_source_patch_ids != landing["source_commit_patch_ids"]:
            fail(
                "closeout-sentinel-invalid",
                "source_commit_patch_ids do not match authoritative source commits",
            )
        if (
            aggregate_patch_digest(
                repo_root, source_parent_fields[1], source_commits[-1]
            )
            != landing["source_patch_digest"]
        ):
            fail(
                "closeout-sentinel-invalid",
                "source_patch_digest does not match authoritative source range",
            )
    else:
        if len(parents) != 2 or parents[0] != base_before:
            fail(
                "closeout-sentinel-invalid",
                "merge_commit anchor first parent must equal base_before",
            )
        topic_commits = git_output(
            repo_root,
            ["rev-list", "--reverse", "--topo-order", f"{base_before}..{parents[1]}"],
        ).decode().splitlines()
        derived_commits = [*topic_commits, anchor]
        patch_commits = topic_commits
    if derived_commits != recorded_commits:
        fail(
            "closeout-sentinel-invalid",
            "landing_commits do not equal the strategy-derived ordered Git set",
        )
    derived_patch_ids = [commit_patch_id(repo_root, commit) for commit in patch_commits]
    if derived_patch_ids != landing["landing_commit_patch_ids"]:
        fail(
            "closeout-sentinel-invalid",
            "landing_commit_patch_ids do not match landed Git commits",
        )
    if aggregate_patch_digest(repo_root, base_before, anchor) != landing["landing_patch_digest"]:
        fail(
            "closeout-sentinel-invalid",
            "landing_patch_digest does not match the landed Git range",
        )


def validate_git_worktree_root(repo_root: Path) -> Path:
    root = Path(os.path.abspath(repo_root))
    if not root.is_dir():
        fail(
            "closeout-sentinel-invalid",
            "landing proof repository root is not a directory",
        )
    top_level = git_output(root, ["rev-parse", "--show-toplevel"])
    try:
        actual_root = Path(top_level.decode("utf-8").strip()).resolve()
        expected_root = root.resolve()
    except (OSError, UnicodeError) as exc:
        fail(
            "closeout-sentinel-invalid",
            f"landing proof repository root cannot be resolved: {exc}",
        )
    if actual_root != expected_root:
        fail(
            "closeout-sentinel-invalid",
            "landing proof repository root must name the Git worktree root",
        )
    return root


def closeout_id(identity: dict[str, Any]) -> str:
    parts = (
        "v1",
        identity["provider"],
        identity["repository"],
        identity["workflow"],
        identity["entity_slug"],
        str(identity["implementation_pr"]),
    )
    return sha256_hex("\0".join(parts).encode("utf-8"))


def load_json(path: Path) -> dict[str, Any]:
    try:
        with path.open("r", encoding="utf-8") as handle:
            value = json.load(handle)
    except (OSError, UnicodeError, json.JSONDecodeError) as exc:
        fail("closeout-sentinel-invalid", f"cannot read canonical JSON: {exc}")
    return require_object(value, "receipt")


def safe_repo_path(repo_root: Path, relative: Any, label: str) -> Path:
    if not isinstance(relative, str) or not relative:
        fail("closeout-sentinel-invalid", f"{label} must be a nonempty repo-relative path")
    logical = PurePosixPath(relative)
    if logical.is_absolute() or any(part in ("", ".", "..") for part in logical.parts):
        fail("closeout-sentinel-invalid", f"{label} contains absolute/traversal components")
    root = Path(os.path.abspath(repo_root))
    candidate = root.joinpath(*logical.parts)
    current = root
    if current.is_symlink():
        fail("closeout-sentinel-invalid", f"{label} repo root is a symlink")
    for part in logical.parts:
        current = current / part
        if current.is_symlink():
            fail("closeout-sentinel-invalid", f"{label} contains a symlink component")
    resolved_root = root.resolve()
    resolved_candidate = candidate.resolve()
    if resolved_candidate != resolved_root and resolved_root not in resolved_candidate.parents:
        fail("closeout-sentinel-invalid", f"{label} escapes repo root")
    return candidate


def validate_supplied_repo_path(repo_root: Path, supplied: Path, label: str) -> Path:
    root = Path(os.path.abspath(repo_root))
    candidate = Path(os.path.abspath(supplied))
    try:
        relative = candidate.relative_to(root)
    except ValueError:
        fail("closeout-sentinel-invalid", f"{label} is lexically outside repo root")
    return safe_repo_path(root, relative.as_posix(), label)


def hash_file(path: Path, label: str) -> str:
    if not path.is_file():
        fail("closeout-stage-artifacts-incoherent", f"missing {label}: {path}")
    try:
        return sha256_hex(path.read_bytes())
    except OSError as exc:
        fail("closeout-stage-artifacts-incoherent", f"cannot read {label}: {exc}")


def verify_output_bytes(receipt: dict[str, Any], repo_root: Path) -> None:
    outputs = receipt["outputs"]
    for key in ("debrief", "ship", "archived_entity"):
        artifact = outputs[key]
        path = safe_repo_path(repo_root, artifact["path"], f"outputs.{key}.path")
        if hash_file(path, f"output {key}") != artifact["sha256"]:
            fail("closeout-sentinel-payload-mismatch", f"landed bytes differ for output {key}")
    roadmap_path = safe_repo_path(repo_root, "ROADMAP.md", "ROADMAP path")
    if not roadmap_path.is_file():
        fail("closeout-stage-artifacts-incoherent", "ROADMAP.md is missing")
    try:
        lines = roadmap_path.read_text(encoding="utf-8").splitlines()
    except (OSError, UnicodeError) as exc:
        fail("closeout-stage-artifacts-incoherent", f"cannot read ROADMAP.md: {exc}")
    opens = [index for index, line in enumerate(lines) if line.strip() == "<!-- section:shipped -->"]
    closes = [index for index, line in enumerate(lines) if line.strip() == "<!-- /section:shipped -->"]
    if len(opens) != 1 or len(closes) != 1 or opens[0] >= closes[0]:
        fail("closeout-stage-artifacts-incoherent", "ROADMAP must contain one bounded Shipped section")
    identity = outputs["roadmap_row"]["identity"]
    matched_rows: list[tuple[str, list[str]]] = []
    for line in lines[opens[0] + 1 : closes[0]]:
        stripped = line.strip()
        if not (stripped.startswith("|") and stripped.endswith("|")):
            continue
        cells = [cell.strip() for cell in stripped[1:-1].split("|")]
        if len(cells) < 2 or all(re.fullmatch(r":?-{3,}:?", cell) for cell in cells):
            continue
        if cells[0] == identity:
            matched_rows.append((line, cells))
    if len(matched_rows) != 1:
        fail("closeout-stage-artifacts-incoherent", "ROADMAP identity must be one exact Shipped table cell")
    matched_line, matched_cells = matched_rows[0]
    merge_date = receipt["landing_proof"]["provider_merged_at"][:10]
    expected_shipped = f"{merge_date} (PR #{receipt['identity']['implementation_pr']})"
    if len(matched_cells) != 3 or matched_cells[2] != expected_shipped:
        fail(
            "closeout-sentinel-payload-mismatch",
            "landed ROADMAP row does not bind provider merge date and implementation PR",
        )
    if sha256_hex(matched_line.encode("utf-8")) != outputs["roadmap_row"]["sha256"]:
        fail("closeout-sentinel-payload-mismatch", "landed ROADMAP row bytes differ")


def verify_source_bytes(receipt: dict[str, Any], repo_root: Path) -> None:
    identity = receipt["identity"]
    base = safe_repo_path(
        repo_root,
        f"{identity['workflow']}/{identity['entity_slug']}",
        "owning entity source path",
    )
    expected = receipt["ownership_proof"]["source_hashes"]
    for key, filename in (("index", "index.md"), ("review", "review.md"), ("ship", "ship.md")):
        actual = hash_file(base / filename, f"source {key}")
        if actual != expected[key]:
            fail("closeout-projection-source-drift", f"source bytes differ for {key}")


def validate(receipt: dict[str, Any], path: Path | None = None) -> None:
    required = {
        "schema_version",
        "kind",
        "closeout_id",
        "identity",
        "ownership_proof",
        "mode",
        "merge_method_intent",
        "deterministic_closeout_head",
        "landing_proof",
        "transaction",
        "outputs",
        "proof_hash",
    }
    missing = sorted(required - receipt.keys())
    if missing:
        fail("closeout-sentinel-invalid", f"missing receipt keys: {missing}")
    if receipt["schema_version"] != 1 or receipt["kind"] != "ship-flow.closeout":
        fail("closeout-sentinel-invalid", "unsupported schema_version or kind")

    identity = require_object(receipt["identity"], "identity")
    require_exact_keys(
        identity,
        {"provider", "repository", "workflow", "entity_slug", "implementation_pr"},
        "identity",
    )
    if identity["provider"] != "github":
        fail("closeout-sentinel-invalid", "provider must be github in schema v1")
    if not isinstance(identity["repository"], str) or not REPOSITORY_RE.fullmatch(identity["repository"]):
        fail("closeout-sentinel-invalid", "repository must be owner/name")
    if not isinstance(identity["workflow"], str) or not WORKFLOW_RE.fullmatch(identity["workflow"]):
        fail("closeout-sentinel-invalid", "workflow must be docs/<workflow>")
    if not isinstance(identity["entity_slug"], str) or not SLUG_RE.fullmatch(identity["entity_slug"]):
        fail("closeout-sentinel-invalid", "entity_slug is invalid")
    pr = identity["implementation_pr"]
    if isinstance(pr, bool) or not isinstance(pr, int) or pr < 1:
        fail("closeout-sentinel-invalid", "implementation_pr must be positive integer")

    expected_id = closeout_id(identity)
    if receipt["closeout_id"] != expected_id:
        fail("closeout-sentinel-identity-mismatch", "closeout_id does not match identity")
    if path is not None and path.name != f"{expected_id}.json":
        fail("closeout-id-path-mismatch", "receipt basename does not match closeout_id")
    if receipt["deterministic_closeout_head"] != f"ship-closeout/{expected_id}":
        fail("closeout-sentinel-identity-mismatch", "deterministic head is not identity-bound")

    ownership = require_object(receipt["ownership_proof"], "ownership_proof")
    require_exact_keys(ownership, {"unique_entity_matches", "participant_entities", "source_hashes"}, "ownership_proof")
    participants = ownership["participant_entities"]
    if not isinstance(participants, list):
        fail("closeout-owner-not-unique", "participant_entities must be an array")
    matches = ownership["unique_entity_matches"]
    if isinstance(matches, bool) or not isinstance(matches, int) or matches != len(participants) + 1:
        fail("closeout-owner-not-unique", "unique_entity_matches must equal owner plus participant count")
    slugs: set[str] = set()
    for slug in participants:
        if not isinstance(slug, str) or not SLUG_RE.fullmatch(slug) or slug in slugs or slug == identity["entity_slug"]:
            fail("closeout-owner-not-unique", "participant slugs must be valid and unique")
        slugs.add(slug)
    hashes = require_object(ownership["source_hashes"], "source_hashes")
    require_exact_keys(hashes, {"index", "review", "ship"}, "source_hashes")
    for key, value in hashes.items():
        require_hash(value, f"source_hashes.{key}")

    if receipt["mode"] not in ("direct", "pull_request"):
        fail("closeout-sentinel-invalid", "mode is invalid")
    if receipt["merge_method_intent"] not in (None, "rebase", "squash", "merge_commit"):
        fail("closeout-sentinel-invalid", "merge_method_intent is invalid")
    landing = require_object(receipt["landing_proof"], "landing_proof")
    validate_landing_proof(landing, identity)
    if landing["method_source"] == "intent-discriminator" and receipt["merge_method_intent"] != landing["strategy"]:
        fail(
            "closeout-sentinel-invalid",
            "intent-discriminator landing must match merge_method_intent",
        )

    transaction = require_object(receipt["transaction"], "transaction")
    transaction_keys = set(transaction)
    base_transaction_keys = {"phase", "generation", "closeout_pr", "main_commit"}
    if transaction_keys not in (
        base_transaction_keys,
        base_transaction_keys | {"publication_endpoint"},
    ):
        fail("closeout-sentinel-invalid", "transaction keys mismatch")
    if transaction["phase"] not in PHASES:
        fail("closeout-sentinel-invalid", "transaction phase is invalid")
    generation = transaction["generation"]
    if isinstance(generation, bool) or not isinstance(generation, int) or generation < 1:
        fail("closeout-sentinel-invalid", "generation must be positive integer")
    closeout_pr = transaction["closeout_pr"]
    if closeout_pr is not None and (isinstance(closeout_pr, bool) or not isinstance(closeout_pr, int) or closeout_pr < 1):
        fail("closeout-sentinel-invalid", "closeout_pr must be null or positive integer")
    main_commit = transaction["main_commit"]
    if main_commit is not None and (not isinstance(main_commit, str) or not SHA40_RE.fullmatch(main_commit)):
        fail("closeout-sentinel-invalid", "main_commit must be null or full sha")
    phase = transaction["phase"]
    mode = receipt["mode"]
    publication_endpoint = transaction.get("publication_endpoint")
    if publication_endpoint is not None and (
        not isinstance(publication_endpoint, str)
        or not publication_endpoint
        or publication_endpoint.startswith("-")
        or any(char in publication_endpoint for char in ("\0", "\r", "\n"))
    ):
        fail("closeout-sentinel-invalid", "publication_endpoint must be a safe nonempty string")
    if phase == "awaiting_closeout_pr" and mode != "pull_request":
        fail("closeout-checkpoint-conflict", "only pull_request mode may await closeout PR")
    if mode == "direct" and closeout_pr is not None:
        fail("closeout-checkpoint-conflict", "direct mode cannot bind closeout_pr")
    if mode == "direct" and publication_endpoint is not None:
        fail("closeout-checkpoint-conflict", "direct mode cannot bind a publication endpoint")
    if phase == "prepared" and (closeout_pr is not None or main_commit is not None):
        fail("closeout-checkpoint-conflict", "prepared phase cannot bind external checkpoints")
    if phase == "awaiting_closeout_pr" and (closeout_pr is None or main_commit is not None):
        fail("closeout-checkpoint-conflict", "awaiting phase requires PR and forbids main commit")
    if phase in ("applied", "complete") and main_commit is None:
        fail("closeout-checkpoint-conflict", "applied/complete phase requires authoritative main commit")
    if phase in ("applied", "complete"):
        landing_anchor = landing.get("landing_anchor")
        if not isinstance(landing_anchor, str) or not SHA40_RE.fullmatch(landing_anchor):
            fail("closeout-sentinel-invalid", "applied/complete landing proof requires a full landing_anchor sha")
        if main_commit != landing_anchor:
            fail(
                "closeout-checkpoint-conflict",
                "main_commit must equal the implementation PR authoritative landing_anchor",
            )
    if mode == "pull_request" and phase in ("applied", "complete") and closeout_pr is None:
        fail("closeout-checkpoint-conflict", "applied PR closeout must retain closeout_pr")

    outputs = require_object(receipt["outputs"], "outputs")
    require_exact_keys(outputs, {"debrief", "ship", "archived_entity", "roadmap_row"}, "outputs")
    for key in ("debrief", "ship", "archived_entity"):
        artifact = require_object(outputs[key], f"outputs.{key}")
        require_exact_keys(artifact, {"path", "sha256"}, f"outputs.{key}")
        if not isinstance(artifact["path"], str) or not artifact["path"]:
            fail("closeout-sentinel-invalid", f"outputs.{key}.path must be nonempty")
        require_hash(artifact["sha256"], f"outputs.{key}.sha256")
    workflow = identity["workflow"]
    entity_slug = identity["entity_slug"]
    debrief_path = PurePosixPath(outputs["debrief"]["path"])
    expected_debrief_parent = PurePosixPath(workflow) / "_debriefs"
    if (
        debrief_path.parent != expected_debrief_parent
        or debrief_path.suffix != ".md"
        or debrief_path.name == ".md"
    ):
        fail(
            "closeout-sentinel-invalid",
            "outputs.debrief.path must be a canonical workflow debrief Markdown file",
        )
    expected_archive = f"{workflow}/_archive/{entity_slug}"
    if outputs["ship"]["path"] != f"{expected_archive}/ship.md":
        fail("closeout-sentinel-invalid", "outputs.ship.path is not canonical")
    if outputs["archived_entity"]["path"] != f"{expected_archive}/index.md":
        fail("closeout-sentinel-invalid", "outputs.archived_entity.path is not canonical")
    artifact_paths = [outputs[key]["path"] for key in ("debrief", "ship", "archived_entity")]
    if len(set(artifact_paths)) != len(artifact_paths):
        fail("closeout-sentinel-invalid", "output artifact role paths must be unique")
    roadmap = require_object(outputs["roadmap_row"], "outputs.roadmap_row")
    require_exact_keys(roadmap, {"identity", "sha256"}, "outputs.roadmap_row")
    if roadmap["identity"] != entity_slug:
        fail(
            "closeout-sentinel-invalid",
            "roadmap identity must equal identity.entity_slug",
        )
    require_hash(roadmap["sha256"], "outputs.roadmap_row.sha256")

    payload = {key: receipt[key] for key in ("identity", "ownership_proof", "landing_proof", "outputs")}
    expected_proof = sha256_hex(canonical_bytes(payload))
    if receipt["proof_hash"] != expected_proof:
        fail("closeout-sentinel-payload-mismatch", "proof_hash does not bind canonical payload")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--receipt", required=True, type=Path)
    parser.add_argument("--previous", type=Path)
    parser.add_argument("--repo-root", type=Path)
    parser.add_argument("--landing-proof-repo-root", type=Path)
    parser.add_argument(
        "--source-commits",
        help="provider-ordered source commit SHAs required for squash proof validation",
    )
    parser.add_argument("--verify-outputs", action="store_true")
    parser.add_argument("--verify-sources", action="store_true")
    parser.add_argument("--allow-any-path", action="store_true")
    args = parser.parse_args()

    if args.repo_root is None and not args.allow_any_path:
        fail("closeout-sentinel-invalid", "--repo-root is required for canonical receipt validation")
    if (args.verify_outputs or args.verify_sources) and args.repo_root is None:
        fail("closeout-sentinel-invalid", "byte verification requires --repo-root")
    if args.repo_root is not None and not args.allow_any_path:
        validate_supplied_repo_path(args.repo_root, args.receipt, "canonical receipt path")
    receipt = load_json(args.receipt)
    validate(receipt, None if args.allow_any_path else args.receipt)
    if args.repo_root is not None and not args.allow_any_path:
        expected_path = safe_repo_path(
            args.repo_root,
            f"{receipt['identity']['workflow']}/_closeouts/{receipt['closeout_id']}.json",
            "canonical receipt path",
        )
        if Path(os.path.abspath(args.receipt)) != expected_path:
            fail("closeout-sentinel-invalid", "receipt is outside canonical _closeouts location")
        proof_root = validate_git_worktree_root(
            args.landing_proof_repo_root or args.repo_root
        )
        validate_landing_proof_against_git(receipt, proof_root, args.source_commits)
    if args.verify_outputs:
        verify_output_bytes(receipt, args.repo_root)
    if args.verify_sources:
        verify_source_bytes(receipt, args.repo_root)
    if args.previous:
        previous = load_json(args.previous)
        validate(previous)
        frozen = ("identity", "mode", "merge_method_intent", "deterministic_closeout_head")
        if any(previous[key] != receipt[key] for key in frozen):
            fail("closeout-checkpoint-conflict", "immutable closeout identity or intent changed")
        if previous["proof_hash"] != receipt["proof_hash"]:
            fail("closeout-proof-hash-mismatch", "payload changed across transaction phase")
        payload_keys = ("identity", "ownership_proof", "landing_proof", "outputs")
        if any(previous[key] != receipt[key] for key in payload_keys):
            fail("closeout-proof-hash-mismatch", "proof payload changed across transaction phase")
        if previous == receipt:
            pass
        else:
            old_tx = previous["transaction"]
            new_tx = receipt["transaction"]
            old_endpoint = old_tx.get("publication_endpoint")
            new_endpoint = new_tx.get("publication_endpoint")
            endpoint_hydration = (
                receipt["mode"] == "pull_request"
                and old_endpoint is None
                and new_endpoint is not None
                and old_tx["phase"] == "prepared"
                and new_tx["phase"] == "prepared"
                and old_tx["generation"] == new_tx["generation"]
                and all(old_tx[key] == new_tx[key] for key in ("closeout_pr", "main_commit"))
            )
            legal = {
                "direct": {("prepared", "applied"), ("applied", "complete")},
                "pull_request": {
                    ("prepared", "awaiting_closeout_pr"),
                    ("awaiting_closeout_pr", "applied"),
                    ("applied", "complete"),
                },
            }
            if not endpoint_hydration and (old_tx["phase"], new_tx["phase"]) not in legal[receipt["mode"]]:
                fail("closeout-checkpoint-conflict", "illegal closeout phase transition")
            if not endpoint_hydration and new_tx["generation"] != old_tx["generation"] + 1:
                fail("closeout-checkpoint-conflict", "generation must increment exactly once")
            if old_endpoint is None and new_endpoint is not None and not endpoint_hydration:
                fail(
                    "closeout-checkpoint-conflict",
                    "publication_endpoint may only bind during legacy prepared checkpoint hydration",
                )
            if old_endpoint is not None and new_endpoint != old_endpoint:
                fail("closeout-checkpoint-conflict", "publication_endpoint changed after binding")
            if old_tx["closeout_pr"] is not None and new_tx["closeout_pr"] != old_tx["closeout_pr"]:
                fail("closeout-checkpoint-conflict", "closeout_pr changed after binding")
            if old_tx["main_commit"] is not None and new_tx["main_commit"] != old_tx["main_commit"]:
                fail("closeout-checkpoint-conflict", "main_commit changed after binding")

    print(f"closeout_id={receipt['closeout_id']}")
    print(f"proof_hash={receipt['proof_hash']}")
    print(f"phase={receipt['transaction']['phase']}")
    print("verdict=OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
