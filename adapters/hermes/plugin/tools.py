"""Tool handler implementations for Context Governance Hermes plugin.

Each handler follows the Hermes convention:
- Accept args: dict and **kwargs
- Return a JSON string (never raise exceptions)
"""

from __future__ import annotations

import json
from pathlib import Path

from .authority import check_authority as _check_authority
from .hardgate import get_required_docs_for_role
from .router import classify_task
from .state import find_project_root


def governance_classify_task_handler(args: dict, **kwargs) -> str:
    """Classify a task and return the governance route."""
    try:
        description = args.get("description", "")
        if not description:
            return json.dumps({"error": "description is required"})

        task_type, route, confidence = classify_task(description)

        return json.dumps({
            "task_type": task_type,
            "route": route,
            "confidence": confidence,
            "requires_user_confirmation": confidence < 0.7,
            "routing_authority": "docs/agents/system/ROUTING_POLICY.md",
        })
    except Exception as e:
        return json.dumps({"error": str(e)})


def governance_load_role_context_handler(args: dict, **kwargs) -> str:
    """Load all required governance documents for a role."""
    try:
        role = args.get("role", "")
        module_name = args.get("module")
        baseline_constraints = args.get("baseline_constraints", "")

        if not role:
            return json.dumps({"error": "role is required"})

        project_root = find_project_root()
        if not project_root:
            return json.dumps({
                "error": "Not a governed project (no .governance/ directory found)"
            })

        required_docs = get_required_docs_for_role(role, module_name)

        docs = []
        missing = []
        for doc_path in required_docs:
            full_path = project_root / doc_path
            if full_path.exists():
                try:
                    content = full_path.read_text()
                    docs.append({
                        "path": doc_path,
                        "content": content,
                        "size": len(content),
                    })
                except OSError as e:
                    missing.append({"path": doc_path, "reason": str(e)})
            else:
                missing.append({"path": doc_path, "reason": "file not found"})

        # Warn if non-SA role tries to load PROJECT_BASELINE
        warnings = []
        if role != "system-architect":
            for d in docs:
                if "PROJECT_BASELINE.md" in d["path"]:
                    warnings.append(
                        "WARNING: Only System Architect loads PROJECT_BASELINE directly."
                    )

        # Add baseline constraints for non-SA roles
        constraints = {}
        if role != "system-architect" and baseline_constraints:
            constraints["baseline_summary"] = baseline_constraints

        return json.dumps({
            "role": role,
            "module": module_name,
            "docs_loaded": len(docs),
            "docs": docs,
            "missing_docs": missing,
            "constraints": constraints,
            "warnings": warnings,
            "hardgate_status": "PASS" if not missing else "FAIL",
        })
    except Exception as e:
        return json.dumps({"error": str(e)})


def governance_enforce_hardgate_handler(args: dict, **kwargs) -> str:
    """Verify HARD-GATE document loading for a role."""
    try:
        role = args.get("role", "")
        loaded_docs = args.get("loaded_docs", [])
        module_name = args.get("module")

        if not role:
            return json.dumps({"error": "role is required"})
        if not isinstance(loaded_docs, list):
            return json.dumps({"error": "loaded_docs must be a list"})

        required = get_required_docs_for_role(role, module_name)
        required_normalized = {_normalize_path(p) for p in required}
        loaded_normalized = {_normalize_path(p) for p in loaded_docs}

        missing = sorted(required_normalized - loaded_normalized)

        result = {
            "role": role,
            "status": "PASS" if not missing else "FAIL",
            "required_count": len(required_normalized),
            "loaded_count": len(loaded_normalized & required_normalized),
            "missing_docs": missing,
        }

        if missing:
            result["action_required"] = (
                f"HARD-GATE FAILED for {role}. "
                f"Load these documents before proceeding: {missing}"
            )

        return json.dumps(result)
    except Exception as e:
        return json.dumps({"error": str(e)})


def governance_check_authority_handler(args: dict, **kwargs) -> str:
    """Check file operation authority for a role."""
    try:
        file_path = args.get("file_path", "")
        operation = args.get("operation", "")
        current_role = args.get("current_role", "")

        if not all([file_path, operation, current_role]):
            return json.dumps({
                "error": "file_path, operation, and current_role are all required"
            })

        if operation not in ("read", "write"):
            return json.dumps({"error": "operation must be 'read' or 'write'"})

        result = _check_authority(file_path, operation, current_role)
        return json.dumps(result)
    except Exception as e:
        return json.dumps({"error": str(e)})


# Handler registry for registration
TOOL_HANDLERS = {
    "governance_classify_task": governance_classify_task_handler,
    "governance_load_role_context": governance_load_role_context_handler,
    "governance_enforce_hardgate": governance_enforce_hardgate_handler,
    "governance_check_authority": governance_check_authority_handler,
}


def _normalize_path(path: str) -> str:
    """Normalize a path for comparison."""
    p = path.replace("\\", "/").strip()
    if p.startswith("./"):
        p = p[2:]
    return p
