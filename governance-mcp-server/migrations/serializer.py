"""Minimal YAML writer for v2 receipts.

Why custom instead of PyYAML: the existing server.py uses a hand-rolled
YAML parser to avoid adding a runtime dependency. This serializer emits
a compatible shape so the parser round-trips cleanly.

The writer is intentionally non-general: it knows the v2 receipt shape.
If schema v3 introduces structurally novel fields, extend this file.

Output style matches the example block at the foot of
docs/templates/governance/TASK_RECEIPT.schema.yaml.
"""

from __future__ import annotations

from typing import Any, List


def _scalar(v: Any) -> str:
    """Render a Python scalar as a YAML scalar."""
    if v is None:
        return "null"
    if v is True:
        return "true"
    if v is False:
        return "false"
    if isinstance(v, int):
        return str(v)
    return str(v)


def _emit_flow_list(items: List[Any]) -> str:
    return "[" + ", ".join(_scalar(x) for x in items) + "]"


def dump_receipt(data: dict) -> str:
    """Serialize a v2 receipt dict to YAML text.

    The input is expected to be in on-disk shape (i.e. with nested
    `scope`, `actor`, `lifecycle` objects), not the flattened form used
    inside server.py's _write_receipt.
    """
    lines: List[str] = []

    # Top-level scalars, in the canonical order documented in v2 schema.
    lines.append(f"schema_version: {_scalar(data.get('schema_version', 2))}")
    lines.append(f"task_id: {_scalar(data.get('task_id'))}")
    lines.append(f"task_type: {_scalar(data.get('task_type'))}")
    lines.append(f"state: {_scalar(data.get('state'))}")
    if "status" in data:
        lines.append(f"status: {_scalar(data.get('status'))}")
    lines.append(f"context_class: {_scalar(data.get('context_class', 'internal'))}")
    lines.append(
        f"policy_version: {_scalar(data.get('policy_version', 'unversioned-v1'))}"
    )
    lines.append(f"attestation_mode: {_scalar(data.get('attestation_mode', 'mcp'))}")
    lines.append(
        f"manual_fallback_reason: {_scalar(data.get('manual_fallback_reason'))}"
    )

    # Actor.
    actor = data.get("actor") or {}
    lines.append("")
    lines.append("actor:")
    lines.append(f"  kind: {_scalar(actor.get('kind'))}")
    lines.append(f"  id: {_scalar(actor.get('id'))}")
    lines.append(f"  session_id: {_scalar(actor.get('session_id'))}")

    # Scope.
    scope = data.get("scope") or {}
    lines.append("")
    lines.append("scope:")
    affected_modules = scope.get("affected_modules") or []
    lines.append(f"  affected_modules: {_emit_flow_list(affected_modules)}")
    lines.append("  affected_paths:")
    for p in scope.get("affected_paths") or []:
        lines.append(f"    - {p}")

    # Governance claims.
    claims = data.get("governance_claims") or {}
    lines.append("")
    lines.append("governance_claims:" if claims else "governance_claims: {}")
    for key in ("debug_required", "formal_verification_required"):
        if key in claims:
            lines.append(f"  {key}: {_scalar(bool(claims[key]))}")
    for key in ("route_reason", "root_cause_evidence"):
        if key in claims:
            lines.append(f"  {key}: {_scalar(claims[key])}")
    if "debug_case_present" in claims:
        lines.append(
            f"  debug_case_present: {_scalar(bool(claims['debug_case_present']))}"
        )
    if "module_contract_refs" in claims:
        lines.append("  module_contract_refs:")
        for ref in claims["module_contract_refs"]:
            lines.append(f"    - {ref}")
    if "verification_refs" in claims:
        lines.append("  verification_refs:")
        for ref in claims["verification_refs"]:
            lines.append(f"    - {ref}")
    if "engineering_constraint_refs" in claims:
        lines.append("  engineering_constraint_refs:")
        for ref in claims["engineering_constraint_refs"]:
            lines.append(f"    - {ref}")
    if "optimization_log_ref" in claims:
        lines.append(f"  optimization_log_ref: {claims['optimization_log_ref']}")
    if "escalation_upstream" in claims:
        lines.append(
            f"  escalation_upstream: {_scalar(bool(claims['escalation_upstream']))}"
        )

    # Evidence refs.
    lines.append("")
    lines.append("evidence_refs:")
    for ref in data.get("evidence_refs") or []:
        lines.append(f"  - path: {ref.get('path')}")
        lines.append(f"    kind: {ref.get('kind')}")
        lines.append(f"    upstream_hash: {_scalar(ref.get('upstream_hash'))}")

    # Cross-refs.
    lines.append("")
    lines.append(f"provenance_ref: {_scalar(data.get('provenance_ref'))}")
    lines.append(f"signature: {_scalar(data.get('signature'))}")

    # Lifecycle.
    lifecycle = data.get("lifecycle") or {}
    lines.append("")
    lines.append("lifecycle:")
    lines.append(f"  created_at: {_scalar(lifecycle.get('created_at'))}")
    lines.append(f"  updated_at: {_scalar(lifecycle.get('updated_at'))}")
    lines.append(f"  issuer: {_scalar(lifecycle.get('issuer'))}")
    lines.append("  session_ids:")
    for sid in lifecycle.get("session_ids") or []:
        lines.append(f"    - {sid}")

    return "\n".join(lines) + "\n"
