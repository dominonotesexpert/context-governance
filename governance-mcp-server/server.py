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

try:
    from mcp.server.fastmcp import FastMCP
    mcp = FastMCP("context-governance")
except ImportError:
    # Allow importing utility functions without MCP installed (for tests)
    mcp = None

    class _NoopDecorator:
        """Stub so @mcp.tool() doesn't fail when mcp is None."""
        def tool(self):
            return lambda fn: fn

    if mcp is None:
        mcp = _NoopDecorator()

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

    lines = [
        f"schema_version: {data.get('schema_version', 1)}",
        f"task_id: {task_id}",
        f"task_type: {data['task_type']}",
        f"status: {data.get('status', 'in_progress')}",
        f"attestation_mode: {data.get('attestation_mode', 'mcp')}",
        f"manual_fallback_reason: {data.get('manual_fallback_reason', 'null')}",
        "",
        "scope:",
        f"  affected_modules: [{', '.join(data.get('affected_modules', []))}]",
        "  affected_paths:",
    ]
    for p in data.get("affected_paths", []):
        lines.append(f"    - {p}")

    lines.append("")
    lines.append("governance_claims:")
    claims = data.get("governance_claims", {})
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


def _write_current_task(task_id: str, task_type: str, affected_modules: list):
    """Write .governance/current-task.json for Phase 1.5 script compatibility."""
    current_task = PROJECT_ROOT / ".governance" / "current-task.json"
    current_task.write_text(json.dumps({
        "task_type": task_type,
        "task_id": task_id,
        "affected_modules": affected_modules,
        "created_by": "governance-mcp",
        "created_at": _now_iso(),
    }, indent=2) + "\n")


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
) -> dict:
    """Start a new governed task and create its receipt.

    Args:
        task_type: One of: bug, feature, refactor, design, architecture, protocol, contract_authoring, trivial
        affected_modules: List of module names affected by this task
        affected_paths: List of file paths affected by this task
        session_id: Current agent session ID for tracking
    """
    valid_types = ["bug", "feature", "refactor", "design", "architecture",
                   "protocol", "contract_authoring", "autoresearch", "trivial"]
    if task_type not in valid_types:
        return {"error": f"Invalid task_type: {task_type}. Must be one of: {valid_types}"}

    task_id = _next_task_id()
    now = _now_iso()

    data = {
        "schema_version": 1,
        "task_type": task_type,
        "status": "in_progress",
        "attestation_mode": "mcp",
        "affected_modules": affected_modules or [],
        "affected_paths": affected_paths or [],
        "governance_claims": {},
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
    elif task_type in ("feature", "refactor"):
        data["governance_claims"]["module_contract_refs"] = []
    elif task_type == "autoresearch":
        data["governance_claims"]["optimization_log_ref"] = "docs/agents/optimization/OPTIMIZATION_LOG.md"
        data["governance_claims"]["escalation_upstream"] = True

    receipt_path = _write_receipt(task_id, data)
    _update_index(task_id, data)
    _write_current_task(task_id, task_type, affected_modules or [])

    return {
        "task_id": task_id,
        "receipt_path": str(receipt_path.relative_to(PROJECT_ROOT)),
        "status": "in_progress",
        "task_type": task_type,
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
    # For simplicity, rebuild receipt with updates
    import yaml
    try:
        with open(receipt_path) as f:
            existing = yaml.safe_load(f)
    except Exception:
        existing = {}

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
        refs.extend(evidence_refs)
        existing["evidence_refs"] = refs

    # Update lifecycle
    lifecycle = existing.get("lifecycle", {})
    lifecycle["updated_at"] = _now_iso()
    existing["lifecycle"] = lifecycle

    # Rewrite receipt
    data = {
        "schema_version": existing.get("schema_version", 1),
        "task_type": existing.get("task_type", current_data.get("task_type", "feature")),
        "status": existing.get("status", "in_progress"),
        "attestation_mode": existing.get("attestation_mode", "mcp"),
        "manual_fallback_reason": existing.get("manual_fallback_reason"),
        "affected_modules": existing.get("scope", {}).get("affected_modules", []),
        "affected_paths": existing.get("scope", {}).get("affected_paths", []),
        "governance_claims": existing.get("governance_claims", {}),
        "evidence_refs": existing.get("evidence_refs", []),
        "lifecycle": lifecycle,
    }

    _write_receipt(task_id, data)
    _update_index(task_id, data)

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

    return governance_update_receipt(
        task_id=task_id,
        governance_claims={
            "verification_refs": [acceptance_rules_path],
        },
        evidence_refs=[
            {"path": acceptance_rules_path, "kind": "acceptance_rules", "upstream_hash": None},
        ],
    )


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

    # Update receipt status
    content = receipt_path.read_text()
    content = content.replace("status: in_progress", "status: completed")
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
def governance_run_checks() -> dict:
    """Run all governance check scripts and return results.

    Delegates to existing check scripts rather than duplicating logic.
    """
    checks = [
        "check-hardgate.sh",
        "check-staleness.sh",
        "check-derived-edits.sh",
        "check-commit-governance.sh",
    ]

    results = {}
    for script in checks:
        results[script] = _run_check(script)

    all_passed = all(r["status"] in ("passed", "skipped") for r in results.values())

    return {
        "overall": "passed" if all_passed else "failed",
        "checks": results,
    }


if __name__ == "__main__":
    mcp.run()
