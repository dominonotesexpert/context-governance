#!/usr/bin/env python3
"""Context Governance MCP Attestation Server.

Provides tools for governed task lifecycle management:
- governance_start_task: Create a new governed task with receipt
- governance_update_receipt: Update receipt claims and scope
- governance_record_debug_case: Attach debug case evidence
- governance_record_escalation: Record escalation in escalations.jsonl
- governance_record_verification: Attach verification evidence
- governance_complete_task: Finalize receipt and update index

Authority: docs/plans/2026-03-24-deerflow-inspired-governance-engine-plan.md §5
"""

import json
import os
import subprocess
import sys
from datetime import datetime, timezone
from pathlib import Path

# Ensure migrations package is importable when server.py is run from any CWD.
_SERVER_DIR = Path(__file__).resolve().parent
if str(_SERVER_DIR) not in sys.path:
    sys.path.insert(0, str(_SERVER_DIR))

from migrations import CURRENT_VERSION, upgrade_in_memory  # noqa: E402

try:
    from mcp.server.fastmcp import FastMCP
    mcp = FastMCP("context-governance")
except ImportError:
    # Allow importing utility functions without MCP installed (for tests)
    mcp = None

    class _NoopDecorator:
        """Stub so @mcp.tool() doesn't fail when mcp is None."""
        def tool(self, *args, **kwargs):
            return lambda fn: fn
        def run(self):
            print("MCP library not installed. Install with: pip install mcp", file=sys.stderr)
            sys.exit(1)

    mcp = _NoopDecorator()


# ============================================================
# Schema v2 helpers (see TASK_RECEIPT.schema.yaml v2)
# ============================================================

_STATUS_TO_STATE = {
    "in_progress": "running",
    "completed": "completed",
    "abandoned": "abandoned",
}

_DEFAULT_CONTEXT_CLASS = {
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

_DEFAULT_POLICY_VERSION = "unversioned-v1"


def _derive_state(data: dict) -> str:
    """Return the v2 `state` for the given data, preferring explicit state."""
    if data.get("state"):
        return str(data["state"])
    status = data.get("status") or "in_progress"
    return _STATUS_TO_STATE.get(status, "running")


def _derive_context_class(data: dict) -> str:
    if data.get("context_class"):
        return str(data["context_class"])
    return _DEFAULT_CONTEXT_CLASS.get(data.get("task_type", ""), "internal")


def _derive_actor(data: dict) -> dict:
    """Return a v2 actor object, preferring an explicit `actor` key."""
    actor = data.get("actor")
    if isinstance(actor, dict) and actor.get("kind") and actor.get("id"):
        return {
            "kind": actor["kind"],
            "id": actor["id"],
            "session_id": actor.get("session_id"),
        }
    lifecycle = data.get("lifecycle") or {}
    issuer = lifecycle.get("issuer") or "governance-mcp"
    session_ids = lifecycle.get("session_ids") or []
    session_id = session_ids[0] if session_ids else None
    if issuer == "governance-mcp":
        kind, ident = "mcp", "governance-mcp"
    elif isinstance(issuer, str) and (issuer == "manual" or issuer.startswith("manual")):
        kind, ident = "user", issuer
    elif issuer == "ci":
        kind, ident = "ci", "ci"
    elif isinstance(issuer, str) and ":" in issuer:
        kind, ident = "agent", issuer
    else:
        kind, ident = "user", issuer
    return {"kind": kind, "id": ident, "session_id": session_id}

# Project root detection: walk up from server.py to find .governance/
def find_project_root() -> Path:
    """Find the project root by looking for .governance/ directory."""
    current = Path(__file__).resolve().parent.parent
    # If governance-mcp-server is at project root
    if (current / ".governance").is_dir():
        return current
    # Try parent
    if (current.parent / ".governance").is_dir():
        return current.parent
    # Fallback to cwd
    cwd = Path.cwd()
    if (cwd / ".governance").is_dir():
        return cwd
    return cwd


PROJECT_ROOT = find_project_root()
ATTESTATION_DIR = PROJECT_ROOT / ".governance" / "attestations"
INDEX_FILE = ATTESTATION_DIR / "index.jsonl"


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _next_task_id() -> str:
    """Generate the next task ID for today."""
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    max_seq = 0

    if INDEX_FILE.exists():
        for line in INDEX_FILE.read_text().strip().split("\n"):
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
                tid = entry.get("task_id", "")
                if tid.startswith(f"T-{today}-"):
                    seq = int(tid.split("-")[-1])
                    max_seq = max(max_seq, seq)
            except (json.JSONDecodeError, ValueError):
                continue

    return f"T-{today}-{max_seq + 1:03d}"


def _write_receipt(task_id: str, data: dict) -> Path:
    """Write a receipt YAML file."""
    ATTESTATION_DIR.mkdir(parents=True, exist_ok=True)
    receipt_path = ATTESTATION_DIR / f"{task_id}.receipt.yaml"

    state = _derive_state(data)
    context_class = _derive_context_class(data)
    policy_version = data.get("policy_version") or _DEFAULT_POLICY_VERSION
    actor = _derive_actor(data)

    lines = [
        f"schema_version: {CURRENT_VERSION}",
        f"task_id: {task_id}",
        f"task_type: {data['task_type']}",
        f"state: {state}",
        f"status: {data.get('status', 'in_progress')}",
        f"context_class: {context_class}",
        f"policy_version: {policy_version}",
        f"attestation_mode: {data.get('attestation_mode', 'mcp')}",
        f"manual_fallback_reason: {data.get('manual_fallback_reason', 'null')}",
        "",
        "actor:",
        f"  kind: {actor['kind']}",
        f"  id: {actor['id']}",
        f"  session_id: {actor['session_id'] if actor['session_id'] is not None else 'null'}",
        "",
        "scope:",
        f"  affected_modules: [{', '.join(data.get('affected_modules', []))}]",
        "  affected_paths:",
    ]
    for p in data.get("affected_paths", []):
        lines.append(f"    - {p}")

    claims = dict(data.get("governance_claims") or {})
    claims.setdefault("debug_required", data.get("task_type") == "bug")
    claims.setdefault("formal_verification_required", False)
    claims.setdefault("route_reason", "direct writer uses safe route defaults")
    lines.append("")
    lines.append("governance_claims:" if claims else "governance_claims: {}")
    if "debug_required" in claims:
        lines.append(f"  debug_required: {'true' if claims['debug_required'] else 'false'}")
    if "formal_verification_required" in claims:
        lines.append(
            f"  formal_verification_required: "
            f"{'true' if claims['formal_verification_required'] else 'false'}"
        )
    if "route_reason" in claims:
        lines.append(f"  route_reason: {json.dumps(str(claims['route_reason']))}")
    if "root_cause_evidence" in claims:
        lines.append(f"  root_cause_evidence: {json.dumps(str(claims['root_cause_evidence']))}")
    if "debug_case_present" in claims:
        lines.append(f"  debug_case_present: {'true' if claims['debug_case_present'] else 'false'}")
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
        lines.append(f"  escalation_upstream: {'true' if claims['escalation_upstream'] else 'false'}")

    lines.append("")
    lines.append("evidence_refs:")
    for ref in data.get("evidence_refs", []):
        lines.append(f"  - path: {ref['path']}")
        lines.append(f"    kind: {ref['kind']}")
        lines.append(f"    upstream_hash: {ref.get('upstream_hash', 'null')}")

    # Cross-reference fields reserved for M4 (signing) and provenance.
    lines.append("")
    lines.append(f"provenance_ref: {data.get('provenance_ref') or 'null'}")
    lines.append(f"signature: {data.get('signature') or 'null'}")

    lines.append("")
    lines.append("lifecycle:")
    lifecycle = data.get("lifecycle", {})
    lines.append(f"  created_at: {lifecycle.get('created_at', _now_iso())}")
    lines.append(f"  updated_at: {lifecycle.get('updated_at', _now_iso())}")
    lines.append(f"  issuer: {lifecycle.get('issuer', 'governance-mcp')}")
    lines.append("  session_ids:")
    for sid in lifecycle.get("session_ids", []):
        lines.append(f"    - {sid}")

    receipt_path.write_text("\n".join(lines) + "\n")
    return receipt_path


def _update_index(task_id: str, data: dict):
    """Update or append to the attestation index."""
    ATTESTATION_DIR.mkdir(parents=True, exist_ok=True)
    entry = {
        "task_id": task_id,
        "task_type": data["task_type"],
        "status": data.get("status", "in_progress"),
        "receipt_path": f".governance/attestations/{task_id}.receipt.yaml",
        "created_at": data.get("lifecycle", {}).get("created_at", _now_iso()),
        "updated_at": _now_iso(),
        "attestation_mode": data.get("attestation_mode", "mcp"),
    }

    # Read existing entries, replace if task_id exists
    entries = []
    found = False
    if INDEX_FILE.exists():
        for line in INDEX_FILE.read_text().strip().split("\n"):
            if not line.strip():
                continue
            try:
                existing = json.loads(line)
                if existing.get("task_id") == task_id:
                    entries.append(json.dumps(entry, separators=(",", ":")))
                    found = True
                else:
                    entries.append(line.strip())
            except json.JSONDecodeError:
                entries.append(line.strip())

    if not found:
        entries.append(json.dumps(entry, separators=(",", ":")))

    INDEX_FILE.write_text("\n".join(entries) + "\n")


def _write_current_task(
    task_id: str,
    task_type: str,
    affected_modules: list,
    debug_required: bool | None = None,
    formal_verification_required: bool = False,
    route_reason: str | None = None,
    root_cause_evidence: str | None = None,
):
    """Write .governance/current-task.json for Phase 1.5 script compatibility."""
    current_task = PROJECT_ROOT / ".governance" / "current-task.json"
    current_task.write_text(json.dumps({
        "task_type": task_type,
        "task_id": task_id,
        "affected_modules": affected_modules,
        "debug_required": task_type == "bug" if debug_required is None else debug_required,
        "formal_verification_required": formal_verification_required,
        "route_reason": route_reason,
        "root_cause_evidence": root_cause_evidence,
        "created_by": "governance-mcp",
        "created_at": _now_iso(),
    }, indent=2) + "\n")


def _parse_scalar(v):
    """Parse a YAML scalar value."""
    if not v or v == '~' or v == 'null':
        return None
    if v == 'true':
        return True
    if v == 'false':
        return False
    if v == '{}':
        return {}
    if v == '[]':
        return []
    if v.startswith('"') and v.endswith('"'):
        return v[1:-1]
    if v.startswith("'") and v.endswith("'"):
        return v[1:-1]
    try:
        return int(v)
    except ValueError:
        pass
    return v


def _parse_receipt(receipt_path: Path) -> dict:
    """Parse a receipt YAML file into a dict without upgrading.

    Callers that need raw on-disk shape (e.g. the migrator CLI) should
    use this. Most callers should prefer _read_receipt which transparently
    upgrades legacy (v1) receipts to the current schema shape.
    """
    try:
        text = receipt_path.read_text()
    except Exception:
        return {}

    root = {}
    stack = [(root, -1, None, None)]
    current_list_item = None
    current_list_item_indent = -1

    for line in text.splitlines():
        stripped = line.rstrip()
        if not stripped or stripped.startswith('#') or stripped == '---':
            continue

        indent = len(line) - len(line.lstrip())
        content = stripped.lstrip()

        while len(stack) > 1 and stack[-1][1] >= indent:
            stack.pop()
        parent_container = stack[-1][0]

        if content.startswith('- '):
            item_content = content[2:].strip()
            if isinstance(parent_container, dict):
                owner = None
                for si in range(len(stack) - 1, -1, -1):
                    c = stack[si][0]
                    ci = stack[si][1]
                    if isinstance(c, dict) and ci < indent:
                        for dk in reversed(list(c.keys())):
                            if isinstance(c[dk], dict) and not c[dk]:
                                c[dk] = []
                                owner = c[dk]
                                break
                            elif isinstance(c[dk], list):
                                owner = c[dk]
                                break
                        if owner is not None:
                            break
                if owner is None:
                    owner = []
                if ':' in item_content and not item_content.startswith('"'):
                    k, _, v = item_content.partition(':')
                    obj = {k.strip(): _parse_scalar(v.strip())}
                    owner.append(obj)
                    current_list_item = obj
                    current_list_item_indent = indent
                else:
                    owner.append(_parse_scalar(item_content))
                    current_list_item = None
            elif isinstance(parent_container, list):
                if ':' in item_content and not item_content.startswith('"'):
                    k, _, v = item_content.partition(':')
                    obj = {k.strip(): _parse_scalar(v.strip())}
                    parent_container.append(obj)
                    current_list_item = obj
                    current_list_item_indent = indent
                else:
                    parent_container.append(_parse_scalar(item_content))
                    current_list_item = None
            continue

        if current_list_item is not None and indent > current_list_item_indent and ':' in content:
            k, _, v = content.partition(':')
            v = v.strip()
            # Support flow-style arrays on the same line (e.g., "when_args: [a, b]")
            # inside a list item. Rule files depend on this shape; receipt files
            # do not use it, so this change is additive.
            if v.startswith('[') and v.endswith(']'):
                inner = v[1:-1].strip()
                if inner:
                    current_list_item[k.strip()] = [
                        _parse_scalar(x.strip()) for x in inner.split(',')
                    ]
                else:
                    current_list_item[k.strip()] = []
            else:
                current_list_item[k.strip()] = _parse_scalar(v)
            continue

        if ':' in content:
            current_list_item = None
            k, _, v = content.partition(':')
            k = k.strip()
            v = v.strip()

            while len(stack) > 1 and stack[-1][1] >= indent:
                stack.pop()
            parent_container = stack[-1][0]

            if not isinstance(parent_container, dict):
                continue

            if v == '' or v is None:
                new_obj = {}
                parent_container[k] = new_obj
                stack.append((new_obj, indent, k, parent_container))
            elif v.startswith('[') and v.endswith(']'):
                inner = v[1:-1].strip()
                if inner:
                    parsed = [_parse_scalar(x.strip()) for x in inner.split(',')]
                else:
                    parsed = []
                parent_container[k] = parsed
                stack.append((parsed, indent, k, parent_container))
            elif v == '{}':
                parent_container[k] = {}
            else:
                parent_container[k] = _parse_scalar(v)

    return root


def _read_receipt(receipt_path: Path) -> dict:
    """Parse a receipt and upgrade it to the current schema shape.

    This is the default entry point for server-internal consumers so that
    mixed-version receipts on disk never leak through. The raw (pre-upgrade)
    shape is available via _parse_receipt for tools like the migrator CLI
    that specifically need to see the legacy form.
    """
    root = _parse_receipt(receipt_path)
    if isinstance(root, dict) and root.get("schema_version") is not None:
        try:
            root = upgrade_in_memory(root, target_version=CURRENT_VERSION)
        except Exception:
            # Parser failure on an unexpected shape should not crash the
            # server; surface the raw dict and let validators flag it.
            pass
    return root


def _run_check(script_name: str) -> dict:
    """Run a governance check script and return the result."""
    script = PROJECT_ROOT / "scripts" / script_name
    if not script.exists():
        return {"status": "skipped", "reason": f"{script_name} not found"}

    result = subprocess.run(
        ["bash", str(script), "--target", str(PROJECT_ROOT)],
        capture_output=True, text=True, timeout=30
    )
    return {
        "status": "passed" if result.returncode == 0 else "failed",
        "output": result.stdout.strip(),
        "errors": result.stderr.strip() if result.stderr else None,
    }


# === MCP Tools ===

@mcp.tool()
def governance_start_task(
    task_type: str,
    affected_modules: list[str] | None = None,
    affected_paths: list[str] | None = None,
    session_id: str | None = None,
    debug_required: bool | None = None,
    formal_verification_required: bool = False,
    route_reason: str | None = None,
    root_cause_evidence: str | None = None,
) -> dict:
    """Start a new governed task and create its receipt.

    Args:
        task_type: One of: bug, feature, refactor, design, architecture, protocol, contract_authoring, trivial
        affected_modules: List of module names affected by this task
        affected_paths: List of file paths affected by this task
        session_id: Current agent session ID for tracking
        debug_required: Whether the formal Debug route and DEBUG_CASE are required. Bugs default to true.
        formal_verification_required: Whether the formal Verification role is required.
        route_reason: Why the risk-triggered route was selected.
        root_cause_evidence: Concise evidence reference required when a bug uses the routine path.
    """
    valid_types = ["bug", "feature", "refactor", "design", "architecture",
                   "protocol", "contract_authoring", "autoresearch", "trivial"]
    if task_type not in valid_types:
        return {"error": f"Invalid task_type: {task_type}. Must be one of: {valid_types}"}

    resolved_debug_required = task_type == "bug" if debug_required is None else bool(debug_required)
    if task_type == "bug" and not resolved_debug_required:
        if not route_reason:
            return {
                "error": (
                    "Routine bug route requires route_reason. Root-cause evidence must be "
                    "attached before governed code is staged. Omit debug_required to keep "
                    "the safe default (formal Debug)."
                )
            }
    if formal_verification_required and not route_reason:
        return {"error": "formal_verification_required=true requires route_reason"}

    task_id = _next_task_id()
    now = _now_iso()

    # schema_version is stamped by _write_receipt using CURRENT_VERSION.
    # state/context_class/policy_version/actor are derived from this dict
    # by the v2 helpers at write time.
    data = {
        "task_type": task_type,
        "status": "in_progress",
        "attestation_mode": "mcp",
        "affected_modules": affected_modules or [],
        "affected_paths": affected_paths or [],
        "governance_claims": {
            "debug_required": resolved_debug_required,
            "formal_verification_required": bool(formal_verification_required),
            "route_reason": route_reason or (
                "unclassified bug uses the safe formal-Debug default"
                if task_type == "bug" else "no risk-triggered role extension declared"
            ),
        },
        "evidence_refs": [],
        "lifecycle": {
            "created_at": now,
            "updated_at": now,
            "issuer": "governance-mcp",
            "session_ids": [session_id] if session_id else [],
        },
    }

    # Set default claims by task type
    if task_type == "bug":
        data["governance_claims"]["debug_case_present"] = False
        data["governance_claims"]["module_contract_refs"] = []
        if root_cause_evidence:
            data["governance_claims"]["root_cause_evidence"] = root_cause_evidence
    elif task_type in ("feature", "refactor"):
        data["governance_claims"]["module_contract_refs"] = []
    elif task_type == "autoresearch":
        data["governance_claims"]["optimization_log_ref"] = "docs/agents/optimization/OPTIMIZATION_LOG.md"
        data["governance_claims"]["escalation_upstream"] = True

    receipt_path = _write_receipt(task_id, data)
    _update_index(task_id, data)
    _write_current_task(
        task_id,
        task_type,
        affected_modules or [],
        debug_required=resolved_debug_required,
        formal_verification_required=bool(formal_verification_required),
        route_reason=data["governance_claims"]["route_reason"],
        root_cause_evidence=root_cause_evidence,
    )

    return {
        "task_id": task_id,
        "receipt_path": str(receipt_path.relative_to(PROJECT_ROOT)),
        "status": "in_progress",
        "task_type": task_type,
        "debug_required": resolved_debug_required,
        "formal_verification_required": bool(formal_verification_required),
    }


@mcp.tool()
def governance_update_receipt(
    task_id: str,
    affected_modules: list[str] | None = None,
    affected_paths: list[str] | None = None,
    governance_claims: dict | None = None,
    evidence_refs: list[dict] | None = None,
) -> dict:
    """Update an existing task receipt with new claims or evidence.

    Args:
        task_id: The task ID to update (T-YYYYMMDD-NNN)
        affected_modules: Updated list of affected modules
        affected_paths: Updated list of affected paths
        governance_claims: Updated governance claims (merged with existing)
        evidence_refs: New evidence references to append
    """
    receipt_path = ATTESTATION_DIR / f"{task_id}.receipt.yaml"
    if not receipt_path.exists():
        return {"error": f"Receipt not found: {task_id}"}

    # Read current receipt (simplified — re-parse from index)
    current_data = None
    if INDEX_FILE.exists():
        for line in INDEX_FILE.read_text().strip().split("\n"):
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
                if entry.get("task_id") == task_id:
                    current_data = entry
                    break
            except json.JSONDecodeError:
                continue

    if not current_data:
        return {"error": f"Task {task_id} not found in index"}

    # Read existing receipt content to preserve data
    existing = _read_receipt(receipt_path)

    if not isinstance(existing, dict):
        existing = {}

    # Apply updates
    if affected_modules is not None:
        scope = existing.get("scope", {})
        scope["affected_modules"] = affected_modules
        existing["scope"] = scope

    if affected_paths is not None:
        scope = existing.get("scope", {})
        scope["affected_paths"] = affected_paths
        existing["scope"] = scope

    if governance_claims:
        claims = existing.get("governance_claims", {})
        claims.update(governance_claims)
        existing["governance_claims"] = claims

    if evidence_refs:
        refs = existing.get("evidence_refs", [])
        if not isinstance(refs, list):
            refs = []
        refs.extend(evidence_refs)
        existing["evidence_refs"] = refs

    # Update lifecycle
    lifecycle = existing.get("lifecycle", {})
    lifecycle["updated_at"] = _now_iso()
    existing["lifecycle"] = lifecycle

    # Rewrite receipt. schema_version is stamped by _write_receipt; v2
    # fields (state, context_class, policy_version, actor) are preserved
    # from `existing` so repeated updates don't reset them to defaults.
    data = {
        "task_type": existing.get("task_type", current_data.get("task_type", "feature")),
        "status": existing.get("status", "in_progress"),
        "state": existing.get("state"),
        "context_class": existing.get("context_class"),
        "policy_version": existing.get("policy_version"),
        "actor": existing.get("actor"),
        "attestation_mode": existing.get("attestation_mode", "mcp"),
        "manual_fallback_reason": existing.get("manual_fallback_reason"),
        "affected_modules": existing.get("scope", {}).get("affected_modules", []),
        "affected_paths": existing.get("scope", {}).get("affected_paths", []),
        "governance_claims": existing.get("governance_claims", {}),
        "evidence_refs": existing.get("evidence_refs", []),
        "provenance_ref": existing.get("provenance_ref"),
        "signature": existing.get("signature"),
        "lifecycle": lifecycle,
    }

    _write_receipt(task_id, data)
    _update_index(task_id, data)

    # Keep the lightweight pre-commit marker aligned with route changes.
    current_task_path = PROJECT_ROOT / ".governance" / "current-task.json"
    if governance_claims and current_task_path.exists():
        try:
            current_task = json.loads(current_task_path.read_text())
            if current_task.get("task_id") == task_id:
                for key in (
                    "debug_required",
                    "formal_verification_required",
                    "route_reason",
                    "root_cause_evidence",
                ):
                    if key in governance_claims:
                        current_task[key] = governance_claims[key]
                current_task_path.write_text(json.dumps(current_task, indent=2) + "\n")
        except (json.JSONDecodeError, OSError):
            pass

    return {"task_id": task_id, "status": "updated"}


@mcp.tool()
def governance_record_debug_case(
    task_id: str,
    debug_case_path: str,
    module_name: str,
) -> dict:
    """Record that a DEBUG_CASE has been created for a bug task.

    Args:
        task_id: The task ID (T-YYYYMMDD-NNN)
        debug_case_path: Path to the DEBUG_CASE file
        module_name: Name of the affected module
    """
    receipt_path = ATTESTATION_DIR / f"{task_id}.receipt.yaml"
    if not receipt_path.exists():
        return {"error": f"Receipt not found: {task_id}"}

    # Verify the debug case file exists
    full_path = PROJECT_ROOT / debug_case_path
    if not full_path.exists():
        return {"error": f"DEBUG_CASE file does not exist: {debug_case_path}"}

    # Update receipt
    module_contract_path = f"docs/agents/modules/{module_name}/MODULE_CONTRACT.md"
    return governance_update_receipt(
        task_id=task_id,
        governance_claims={
            "debug_case_present": True,
            "module_contract_refs": [module_contract_path],
        },
        evidence_refs=[
            {"path": debug_case_path, "kind": "debug_case", "upstream_hash": None},
            {"path": module_contract_path, "kind": "module_contract", "upstream_hash": None},
        ],
    )


@mcp.tool()
def governance_record_escalation(
    task_id: str,
    escalation_type: str,
    description: str,
    target_role: str = "system-architect",
) -> dict:
    """Record a governance escalation.

    Args:
        task_id: The task ID (T-YYYYMMDD-NNN)
        escalation_type: Type of escalation (e.g., 'contract_gap', 'authority_conflict', 'baseline_change')
        description: Description of what needs to be escalated
        target_role: Role that should handle this (default: system-architect)
    """
    escalation_file = PROJECT_ROOT / ".governance" / "escalations.jsonl"
    escalation_file.parent.mkdir(parents=True, exist_ok=True)

    entry = {
        "task_id": task_id,
        "type": escalation_type,
        "description": description,
        "target_role": target_role,
        "status": "pending",
        "created_at": _now_iso(),
    }

    with open(escalation_file, "a") as f:
        f.write(json.dumps(entry, separators=(",", ":")) + "\n")

    return {
        "task_id": task_id,
        "escalation_type": escalation_type,
        "status": "pending",
        "message": f"Escalation recorded. Code commits blocked until resolved.",
    }


@mcp.tool()
def governance_record_verification(
    task_id: str,
    acceptance_rules_path: str = "docs/agents/verification/ACCEPTANCE_RULES.md",
    verification_evidence: str | None = None,
) -> dict:
    """Record verification evidence for a task.

    Args:
        task_id: The task ID (T-YYYYMMDD-NNN)
        acceptance_rules_path: Path to ACCEPTANCE_RULES.md
        verification_evidence: Description of verification evidence
    """
    receipt_path = ATTESTATION_DIR / f"{task_id}.receipt.yaml"
    if not receipt_path.exists():
        return {"error": f"Receipt not found: {task_id}"}

    result = governance_update_receipt(
        task_id=task_id,
        governance_claims={
            "verification_refs": [acceptance_rules_path],
        },
        evidence_refs=[
            {"path": acceptance_rules_path, "kind": "acceptance_rules", "upstream_hash": None},
        ],
    )
    if result.get("error"):
        return result

    # Formal Verification closes the evidence gate and moves the receipt
    # into verified state. Routine tasks do not need to call this tool.
    content = receipt_path.read_text()
    content = content.replace("state: running", "state: verified")
    content = content.replace("state: evidence_collected", "state: verified")
    receipt_path.write_text(content)
    return {**result, "state": "verified", "verification_evidence": verification_evidence}


@mcp.tool()
def governance_complete_task(
    task_id: str,
) -> dict:
    """Complete a governed task, finalizing its receipt.

    Runs governance checks before allowing completion.

    Args:
        task_id: The task ID to complete (T-YYYYMMDD-NNN)
    """
    receipt_path = ATTESTATION_DIR / f"{task_id}.receipt.yaml"
    if not receipt_path.exists():
        return {"error": f"Receipt not found: {task_id}"}

    receipt_data = _read_receipt(receipt_path)
    claims = receipt_data.get("governance_claims", {}) if isinstance(receipt_data, dict) else {}
    if claims.get("formal_verification_required") is True:
        if receipt_data.get("state") != "verified" or not claims.get("verification_refs"):
            return {
                "error": (
                    "Formal Verification route is not verified. "
                    "Record acceptance/oracle evidence before completing the task."
                )
            }

    # Run receipt validation
    check_result = _run_check("check-task-receipt.sh")
    if check_result.get("status") == "failed":
        return {
            "error": "Receipt validation failed. Fix issues before completing.",
            "details": check_result.get("output", ""),
        }

    # Read index to get task data
    task_data = None
    if INDEX_FILE.exists():
        for line in INDEX_FILE.read_text().strip().split("\n"):
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
                if entry.get("task_id") == task_id:
                    task_data = entry
                    break
            except json.JSONDecodeError:
                continue

    if not task_data:
        return {"error": f"Task {task_id} not found in index"}

    # Update status to completed
    task_data["status"] = "completed"
    task_data["updated_at"] = _now_iso()

    # Rewrite index with updated status
    entries = []
    if INDEX_FILE.exists():
        for line in INDEX_FILE.read_text().strip().split("\n"):
            if not line.strip():
                continue
            try:
                entry = json.loads(line)
                if entry.get("task_id") == task_id:
                    entry["status"] = "completed"
                    entry["updated_at"] = _now_iso()
                entries.append(json.dumps(entry, separators=(",", ":")))
            except json.JSONDecodeError:
                entries.append(line.strip())
    INDEX_FILE.write_text("\n".join(entries) + "\n")

    # Update receipt: both v1 `status` (deprecated alias) and v2 `state`
    # move to completed. The string-level replace is preserved so that
    # v1 receipts without a `state` line still transition cleanly.
    content = receipt_path.read_text()
    content = content.replace("status: in_progress", "status: completed")
    content = content.replace("state: running", "state: completed")
    content = content.replace("state: evidence_collected", "state: completed")
    content = content.replace("state: verified", "state: completed")
    receipt_path.write_text(content)

    # Clean up current-task.json
    current_task = PROJECT_ROOT / ".governance" / "current-task.json"
    if current_task.exists():
        current_task.unlink()

    return {
        "task_id": task_id,
        "status": "completed",
        "message": "Task completed. Receipt finalized.",
    }


@mcp.tool()
def governance_start_autoresearch(
    session_id: str | None = None,
    target_skill: str | None = None,
) -> dict:
    """Start an autoresearch governance-optimization task.

    Sets up a receipt with autoresearch-specific defaults:
    - optimization_log_ref pointing to OPTIMIZATION_LOG.md
    - escalation_upstream: true (optimization never rewrites downstream truth)

    Args:
        session_id: Current agent session ID for tracking
        target_skill: The SKILL.md being optimized (e.g., '.claude/skills/debug/SKILL.md')
    """
    # Verify prerequisites exist
    opt_log = PROJECT_ROOT / "docs" / "agents" / "optimization" / "OPTIMIZATION_LOG.md"
    scenarios_dir = PROJECT_ROOT / "docs" / "agents" / "optimization" / "test-scenarios"

    warnings = []
    if not opt_log.exists():
        warnings.append("OPTIMIZATION_LOG.md not found — create it before completing task")
    if not scenarios_dir.exists() or not any(scenarios_dir.glob("*.json")):
        warnings.append("No test scenarios found — optimization loop requires scenarios")

    result = governance_start_task(
        task_type="autoresearch",
        affected_modules=[],
        affected_paths=[target_skill] if target_skill else [],
        session_id=session_id,
    )

    if "error" in result:
        return result

    result["warnings"] = warnings
    result["next_steps"] = [
        "1. Load SYSTEM_GOAL_PACK and SYSTEM_INVARIANTS (baseline constraints)",
        "2. Run governance mechanics evaluation (GM-R1..GM-E2)",
        "3. Record optimization evidence with governance_record_optimization",
        "4. Complete with governance_complete_task when done",
    ]
    return result


@mcp.tool()
def governance_record_optimization(
    task_id: str,
    optimization_round: int,
    target_skill_path: str,
    change_description: str,
    result: str,
    backup_path: str | None = None,
) -> dict:
    """Record an optimization round's evidence for an autoresearch task.

    Args:
        task_id: The task ID (T-YYYYMMDD-NNN)
        optimization_round: Round number (1-based)
        target_skill_path: Path to the SKILL.md being optimized
        change_description: What was changed and why
        result: One of: 'improved', 'reverted', 'no_change'
        backup_path: Path to the backup of the original SKILL.md
    """
    receipt_path = ATTESTATION_DIR / f"{task_id}.receipt.yaml"
    if not receipt_path.exists():
        return {"error": f"Receipt not found: {task_id}"}

    valid_results = ["improved", "reverted", "no_change"]
    if result not in valid_results:
        return {"error": f"Invalid result: {result}. Must be one of: {valid_results}"}

    # Build evidence refs
    evidence = [
        {"path": "docs/agents/optimization/OPTIMIZATION_LOG.md",
         "kind": "optimization_artifact", "upstream_hash": None},
    ]
    if backup_path:
        evidence.append(
            {"path": backup_path, "kind": "optimization_artifact", "upstream_hash": None}
        )

    # Record in optimization audit trail
    audit_dir = PROJECT_ROOT / ".governance" / "audit"
    audit_dir.mkdir(parents=True, exist_ok=True)
    audit_file = audit_dir / f"{task_id}-optimization.jsonl"
    with open(audit_file, "a") as f:
        f.write(json.dumps({
            "round": optimization_round,
            "target": target_skill_path,
            "change": change_description,
            "result": result,
            "backup": backup_path,
            "timestamp": _now_iso(),
        }, separators=(",", ":")) + "\n")

    return governance_update_receipt(
        task_id=task_id,
        affected_paths=[target_skill_path],
        governance_claims={
            "optimization_log_ref": "docs/agents/optimization/OPTIMIZATION_LOG.md",
            "escalation_upstream": True,
        },
        evidence_refs=evidence,
    )


@mcp.tool()
def governance_run_checks() -> dict:
    """Evaluate the four core policy-engine rules and return structured PDRs.

    Returns shape:
        {
          "overall": "passed" | "failed",
          "engine_bundle_version": "x.y.z",
          "rules": {
            "<rule-id>": {
              "status": "passed" | "failed",
              "decisions": [PDR-lite dicts]
            }
          },
          "legacy_checks": { ... }   # output of non-migrated shell gates
        }

    Each decision is also appended to .governance/decisions.jsonl.
    """
    from policy_engine import (
        ENGINE_BUNDLE_VERSION,
        Engine,
        EvalContext,
        load_rule,
    )

    rule_ids = [
        "derived-edits",
        "module-contract",
        "bug-evidence",
        "escalation-block",
    ]
    rules_dir = PROJECT_ROOT / "docs" / "templates" / "governance" / "rules"

    engine = Engine()
    ctx = EvalContext.from_repo(PROJECT_ROOT)

    all_decisions: list[dict] = []
    rule_results: dict[str, dict] = {}
    overall_passed = True

    for rid in rule_ids:
        rule_path = rules_dir / f"{rid}.rule.yaml"
        if not rule_path.is_file():
            rule_results[rid] = {"status": "skipped", "reason": "rule file missing"}
            continue
        rule = load_rule(rule_path)
        decisions = engine.evaluate(rule, ctx)
        blocked = [d for d in decisions if d.decision in ("DENY", "ESCALATE")]
        status = "failed" if blocked else "passed"
        if blocked:
            overall_passed = False
        rule_results[rid] = {
            "status": status,
            "policy_version": rule.version,
            "decisions": [
                {
                    "rule_id": d.rule_id,
                    "policy_version": d.policy_version,
                    "subject": {"kind": d.subject_kind, "id": d.subject_id},
                    "action": d.action,
                    "decision": d.decision,
                    "reason": d.reason,
                    "clause_id": d.clause_id,
                    "context_hash": d.context_hash,
                }
                for d in decisions
            ],
        }
        all_decisions.extend(decisions)

    # Persist every decision to .governance/decisions.jsonl (append-only).
    _append_decisions(all_decisions)

    # Run non-migrated shell checks so behavior is not regressed for callers
    # that rely on the aggregate verdict of the full set.
    legacy_results: dict[str, dict] = {}
    for script in ("check-hardgate.sh", "check-staleness.sh", "check-commit-governance.sh"):
        legacy_results[script] = _run_check(script)
    legacy_passed = all(
        r["status"] in ("passed", "skipped") for r in legacy_results.values()
    )
    if not legacy_passed:
        overall_passed = False

    return {
        "overall": "passed" if overall_passed else "failed",
        "engine_bundle_version": ENGINE_BUNDLE_VERSION,
        "rules": rule_results,
        "legacy_checks": legacy_results,
    }


def _append_decisions(decisions) -> None:
    """Append a batch of Decision dataclasses as PDRs to decisions.jsonl."""
    if not decisions:
        return
    decisions_file = PROJECT_ROOT / ".governance" / "decisions.jsonl"
    decisions_file.parent.mkdir(parents=True, exist_ok=True)
    # Minimal actor identity for server-issued decisions.
    actor = {"kind": "mcp", "id": "governance-mcp", "session_id": None}
    now = _now_iso()
    # PDR id sequence within this invocation; file-wide uniqueness is best-effort.
    seq_base = datetime.now(timezone.utc).strftime("%Y%m%d")
    with open(decisions_file, "a") as f:
        for idx, d in enumerate(decisions, start=1):
            pdr = d.to_pdr(
                pdr_id=f"PDR-{seq_base}-{idx:03d}",
                actor=actor,
                timestamp=now,
            )
            f.write(json.dumps(pdr, separators=(",", ":")) + "\n")


def _next_pdr_id() -> str:
    """Return the next PDR id scoped to today, scanning existing file for max."""
    decisions_file = PROJECT_ROOT / ".governance" / "decisions.jsonl"
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    max_seq = 0
    if decisions_file.exists():
        for line in decisions_file.read_text().splitlines():
            line = line.strip()
            if not line:
                continue
            try:
                entry = json.loads(line)
                pid = entry.get("pdr_id", "")
                if pid.startswith(f"PDR-{today}-"):
                    seq = int(pid.rsplit("-", 1)[-1])
                    if seq > max_seq:
                        max_seq = seq
            except (json.JSONDecodeError, ValueError):
                continue
    return f"PDR-{today}-{max_seq + 1:03d}"


def _evaluate_authority(
    actor_role: str,
    subject_path: str,
    operation: str,
    context_class: str = "internal",
    task_id: str | None = None,
) -> dict:
    """Evaluate the authority rule for a given runtime call. Returns a dict:
        {decision, reason, rule_id, policy_version, context_hash, clause_id}
    Falls back to DENY-for-writes / ALLOW-for-reads if the engine is
    unavailable, matching the fail-closed contract.
    """
    try:
        from policy_engine import Engine, EvalContext, load_rule
    except Exception as exc:
        return {
            "decision": "DENY" if operation == "write" else "ALLOW",
            "reason": f"engine-unavailable: fail-closed ({exc})",
            "rule_id": "authority",
            "policy_version": "unknown",
            "context_hash": "",
            "clause_id": None,
        }
    rules_dir = PROJECT_ROOT / "docs" / "templates" / "governance" / "rules"
    rule_path = rules_dir / "authority.rule.yaml"
    if not rule_path.is_file():
        return {
            "decision": "DENY" if operation == "write" else "ALLOW",
            "reason": "engine-unavailable: authority.rule.yaml missing",
            "rule_id": "authority",
            "policy_version": "unknown",
            "context_hash": "",
            "clause_id": None,
        }
    try:
        rule = load_rule(rule_path)
    except Exception as exc:
        return {
            "decision": "DENY" if operation == "write" else "ALLOW",
            "reason": f"engine-unavailable: rule load failed ({exc})",
            "rule_id": "authority",
            "policy_version": "unknown",
            "context_hash": "",
            "clause_id": None,
        }
    ctx = EvalContext(
        repo_root=PROJECT_ROOT,
        runtime_call={
            "actor_role": actor_role,
            "subject_path": subject_path,
            "operation": operation,
            "context_class": context_class,
            "task_id": task_id,
        },
        offline=True,
    )
    decisions = Engine().evaluate(rule, ctx)
    if not decisions:
        return {
            "decision": "DENY" if operation == "write" else "ALLOW",
            "reason": "authority rule produced no decision",
            "rule_id": "authority",
            "policy_version": rule.version,
            "context_hash": "",
            "clause_id": None,
        }
    d = decisions[0]
    return {
        "decision": d.decision,
        "reason": d.reason,
        "rule_id": d.rule_id,
        "policy_version": d.policy_version,
        "context_hash": d.context_hash,
        "clause_id": d.clause_id,
    }


@mcp.tool()
def governance_record_decision(
    actor_role: str,
    actor_kind: str,
    actor_id: str,
    subject_kind: str,
    subject_id: str,
    action: str,
    decision: str,
    reason: str,
    rule_id: str,
    policy_version: str,
    context_hash: str = "",
    task_id: str | None = None,
    clause_id: str | None = None,
    session_id: str | None = None,
) -> dict:
    """Append a Policy Decision Record to .governance/decisions.jsonl.

    Adapters call this tool at every pre-tool-call decision so that M4
    verification has a canonical audit trail. The PDR shape matches
    docs/templates/governance/POLICY_DECISION_RECORD.schema.yaml v1.

    Args:
        actor_role: Governance role of the actor (implementation, debug, ...)
        actor_kind: user | agent | ci | mcp
        actor_id: Stable identifier (e.g., "claude-code:S-001")
        subject_kind: file | tool | receipt | contract | commit | escalation
        subject_id: Path, tool name, task id, etc.
        action: Verb — write, read, invoke, complete, merge, escalate, abort
        decision: ALLOW | DENY | ESCALATE
        reason: Human-readable explanation
        rule_id: Id of the rule that produced the decision
        policy_version: Semver of the rule bundle
        context_hash: sha256 of the canonical inputs (optional but recommended)
        task_id: Task id this decision is scoped to (nullable)
        clause_id: Id of the matched clause within the rule (optional)
        session_id: Session correlator (optional)
    """
    valid_decisions = {"ALLOW", "DENY", "ESCALATE"}
    if decision not in valid_decisions:
        return {"error": f"invalid decision: {decision!r}; expected one of {valid_decisions}"}
    valid_actor_kinds = {"user", "agent", "ci", "mcp"}
    if actor_kind not in valid_actor_kinds:
        return {"error": f"invalid actor_kind: {actor_kind!r}"}

    pdr_id = _next_pdr_id()
    pdr = {
        "schema_version": 1,
        "pdr_id": pdr_id,
        "task_id": task_id,
        "actor": {
            "kind": actor_kind,
            "id": actor_id,
            "session_id": session_id,
        },
        "subject": {"kind": subject_kind, "id": subject_id},
        "action": action,
        "decision": decision,
        "reason": reason,
        "rule_id": rule_id,
        "policy_version": policy_version,
        "context_hash": context_hash,
        "timestamp": _now_iso(),
        "chain_prev_hash": None,
    }

    decisions_file = PROJECT_ROOT / ".governance" / "decisions.jsonl"
    decisions_file.parent.mkdir(parents=True, exist_ok=True)
    with open(decisions_file, "a") as f:
        f.write(json.dumps(pdr, separators=(",", ":")) + "\n")

    return {"pdr_id": pdr_id, "decision": decision, "persisted": True}


if __name__ == "__main__":
    mcp.run()
