"""Upgrade a receipt from schema v1 to schema v2.

v2 introduces:
  - schema_version: 2
  - state enum replacing flat status (status kept as deprecated alias)
  - actor object replacing ambiguous lifecycle.issuer string
  - context_class defaulting to "internal"
  - policy_version defaulting to "unversioned-v1"
  - reserved signature and provenance_ref fields
  - explicit risk-triggered route claims (legacy bugs fail safe to Debug)

The upgrader is pure, idempotent, and fail-loud on malformed input.

Authority: docs/plans/2026-04-23-governance-kernel-v2-design.md §2.5 and
           docs/plans/2026-04-23-governance-kernel-v2-implementation-plan.md Step C.
"""

from __future__ import annotations

V1_STATUS_TO_V2_STATE = {
    "in_progress": "running",
    "completed": "completed",
    "abandoned": "abandoned",
}

VALID_TASK_TYPES = {
    "bug",
    "feature",
    "refactor",
    "design",
    "architecture",
    "protocol",
    "contract_authoring",
    "autoresearch",
    "trivial",
}

# Default context_class by task_type. Mirrors the table in
# TASK_RECEIPT.schema.yaml (Required Claims by Task Type).
DEFAULT_CONTEXT_CLASS = {
    "bug": "internal",
    "feature": "internal",
    "refactor": "internal",
    "design": "internal",
    "architecture": "internal",
    "protocol": "internal",
    "contract_authoring": "internal",
    "autoresearch": "internal",
    "trivial": "public",
}

DEFAULT_POLICY_VERSION = "unversioned-v1"


def upgrade(data: dict) -> dict:
    """Return a new v2-shaped dict derived from a v1 receipt dict.

    The function avoids mutating its input. Missing optional fields are
    filled with defaults documented in the v2 schema. Structural errors
    (missing task_id, unknown task_type) raise MigrationError.
    """
    # Local import to avoid circular dependency at module load time.
    from .engine import MigrationError

    out = dict(data)  # shallow copy; nested dicts re-created below as needed

    # --- required identity fields ---
    task_id = out.get("task_id")
    if not isinstance(task_id, str) or not task_id:
        raise MigrationError(
            "v1 receipt missing required 'task_id'", field_path="task_id"
        )

    task_type = out.get("task_type")
    if task_type not in VALID_TASK_TYPES:
        raise MigrationError(
            f"unknown task_type {task_type!r}; expected one of "
            f"{sorted(VALID_TASK_TYPES)}",
            field_path="task_type",
        )

    # --- schema_version stamp ---
    out["schema_version"] = 2

    # --- state derived from v1 status ---
    v1_status = out.get("status")
    if v1_status is None:
        raise MigrationError(
            "v1 receipt missing required 'status'", field_path="status"
        )
    if v1_status not in V1_STATUS_TO_V2_STATE:
        raise MigrationError(
            f"unknown v1 status {v1_status!r}; expected one of "
            f"{sorted(V1_STATUS_TO_V2_STATE)}",
            field_path="status",
        )
    out["state"] = V1_STATUS_TO_V2_STATE[v1_status]
    # status kept as deprecated alias for one deprecation window.
    out["status"] = v1_status

    # --- context_class default ---
    out.setdefault("context_class", DEFAULT_CONTEXT_CLASS.get(task_type, "internal"))

    # --- policy_version default ---
    out.setdefault("policy_version", DEFAULT_POLICY_VERSION)

    # --- actor derived from lifecycle.issuer ---
    lifecycle = out.get("lifecycle") or {}
    if not isinstance(lifecycle, dict):
        raise MigrationError(
            "lifecycle must be an object", field_path="lifecycle"
        )
    issuer = lifecycle.get("issuer")
    session_ids = lifecycle.get("session_ids") or []
    session_id = session_ids[0] if session_ids else None

    if issuer == "governance-mcp":
        actor_kind = "mcp"
        actor_id = "governance-mcp"
    elif issuer == "manual" or (isinstance(issuer, str) and issuer.startswith("manual")):
        actor_kind = "user"
        actor_id = issuer or "manual"
    elif isinstance(issuer, str) and issuer:
        # Anything else (e.g. "ci", "claude-code") — best-effort classification.
        if issuer == "ci":
            actor_kind = "ci"
        elif ":" in issuer:
            actor_kind = "agent"
        else:
            actor_kind = "user"
        actor_id = issuer
    else:
        raise MigrationError(
            "lifecycle.issuer missing or empty",
            field_path="lifecycle.issuer",
        )

    out["actor"] = {
        "kind": actor_kind,
        "id": actor_id,
        "session_id": session_id,
    }

    # --- risk-triggered route claims ---
    claims = dict(out.get("governance_claims") or {})
    claims.setdefault("debug_required", task_type == "bug")
    claims.setdefault("formal_verification_required", False)
    claims.setdefault("route_reason", "migrated v1 receipt preserves legacy routing")
    out["governance_claims"] = claims

    # --- reserved fields for M4 / provenance ---
    out.setdefault("provenance_ref", None)
    out.setdefault("signature", None)

    # Lifecycle is preserved as-is for backwards compatibility.
    out["lifecycle"] = dict(lifecycle)

    return out
