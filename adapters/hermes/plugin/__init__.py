"""Context Governance enforcement plugin for Hermes Agent.

Provides:
- 4 governance tools (classify, load_context, enforce_hardgate, check_authority)
- 4 hooks (on_session_start, pre_llm_call, pre_tool_call, post_tool_call)

Install: cp -r adapters/hermes/plugin/ ~/.hermes/plugins/governance-guard/
"""

from __future__ import annotations

from .audit import (
    classify_operation,
    extract_file_path,
    summarize_args,
    write_audit_entry,
)
from .authority import check_authority, get_role_authority_constraints
from .hardgate import get_missing_hardgate_docs
from .schemas import TOOL_SCHEMAS
from .state import (
    SESSION_STATES,
    GovernanceState,
    find_project_root,
    load_governance_state,
)
from .tools import TOOL_HANDLERS

import json as _json
from datetime import datetime as _dt, timezone as _tz
from pathlib import Path as _Path


def _append_pdr(
    *,
    session_id: str,
    tool_name: str,
    file_path: str,
    operation: str,
    auth_result: dict,
    task_id: str | None,
) -> None:
    """Append a PDR to .governance/decisions.jsonl using the state's project root."""
    state = SESSION_STATES.get(session_id)
    if state is None or not state.governance_active:
        return
    root = getattr(state, "project_root", None) or find_project_root()
    if not root:
        return
    decisions_file = _Path(root) / ".governance" / "decisions.jsonl"
    decisions_file.parent.mkdir(parents=True, exist_ok=True)

    # Derive a PDR id scoped to today, with best-effort uniqueness.
    today = _dt.now(_tz.utc).strftime("%Y%m%d")
    max_seq = 0
    if decisions_file.exists():
        try:
            for line in decisions_file.read_text().splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = _json.loads(line)
                except _json.JSONDecodeError:
                    continue
                pid = entry.get("pdr_id", "")
                if pid.startswith(f"PDR-{today}-"):
                    try:
                        seq = int(pid.rsplit("-", 1)[-1])
                        if seq > max_seq:
                            max_seq = seq
                    except ValueError:
                        pass
        except OSError:
            pass

    pdr = {
        "schema_version": 1,
        "pdr_id": f"PDR-{today}-{max_seq + 1:03d}",
        "task_id": task_id,
        "actor": {
            "kind": "agent",
            "id": f"hermes:{session_id or 'unknown'}",
            "session_id": session_id,
        },
        "subject": {"kind": "file", "id": file_path},
        "action": operation,
        "decision": auth_result.get("decision", "DENY"),
        "reason": auth_result.get("reason", ""),
        "rule_id": auth_result.get("rule_id", "authority"),
        "policy_version": auth_result.get("policy_version", "1.0.0"),
        "context_hash": "",
        "timestamp": _dt.now(_tz.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
        "chain_prev_hash": None,
    }
    try:
        with open(decisions_file, "a") as f:
            f.write(_json.dumps(pdr, separators=(",", ":")) + "\n")
    except OSError:
        pass


def register(ctx):
    """Register the governance-guard plugin with Hermes.

    Called exactly once at plugin startup.
    """
    # Register 4 governance tools in the "governance-guard" toolset
    for schema in TOOL_SCHEMAS:
        ctx.register_tool(
            name=schema["name"],
            toolset="governance-guard",
            schema=schema,
            handler=TOOL_HANDLERS[schema["name"]],
        )

    # Register hooks
    ctx.register_hook("on_session_start", _on_session_start)
    ctx.register_hook("pre_llm_call", _pre_llm_call)
    ctx.register_hook("pre_tool_call", _pre_tool_call)
    ctx.register_hook("post_tool_call", _post_tool_call)


# ---------------------------------------------------------------------------
# Hook: on_session_start
# ---------------------------------------------------------------------------

def _on_session_start(session_id: str, **kwargs):
    """Initialize governance state from .governance/ directory.

    Detects project root, loads current task, pending escalations,
    governance mode, and initializes the audit trail.
    """
    project_root = find_project_root()
    if not project_root:
        SESSION_STATES[session_id] = GovernanceState(governance_active=False)
        return

    state = load_governance_state(project_root)
    SESSION_STATES[session_id] = state


# ---------------------------------------------------------------------------
# Hook: pre_llm_call (only hook where return value matters)
# ---------------------------------------------------------------------------

def _pre_llm_call(
    session_id: str,
    user_message: str,
    conversation_history: list,
    is_first_turn: bool,
    model: str,
    platform: str,
    **kwargs,
):
    """Inject governance state into every LLM turn.

    Returns a dict with 'context' key that Hermes appends to the user message.
    """
    state = SESSION_STATES.get(session_id)
    if not state or not state.governance_active:
        return None

    parts = ["[GOVERNANCE STATE]"]

    # Current role and task
    if state.current_role:
        parts.append(f"Active Role: {state.current_role}")
    if state.current_task:
        tid = state.current_task.get("task_id", "unknown")
        ttype = state.current_task.get("task_type", "unknown")
        parts.append(f"Active Task: {tid} (type: {ttype})")

    # Governance mode
    parts.append(f"Governance Mode: {state.governance_mode}")

    # Pending escalations
    if state.pending_escalations:
        parts.append(
            f"PENDING ESCALATIONS: {len(state.pending_escalations)} unresolved"
        )
        for esc in state.pending_escalations[:3]:
            etype = esc.get("type", "unknown")
            edesc = esc.get("description", "")[:80]
            parts.append(f"  - {etype}: {edesc}")

    # Stale document warnings
    if state.stale_warnings:
        parts.append(f"STALE DOCUMENTS: {', '.join(state.stale_warnings)}")
        parts.append("System Architect must re-derive before consumption.")

    # Authority constraints for current role
    if state.current_role:
        constraints = get_role_authority_constraints(state.current_role)
        parts.append(f"Authority ({state.current_role}):")
        parts.append(f"  Read tiers: {constraints['read_tiers']}")
        parts.append(f"  Write tiers: {constraints['write_tiers']}")
        if constraints.get("blocked_files"):
            parts.append(
                f"  Blocked: {', '.join(constraints['blocked_files'])}"
            )

    # HARD-GATE status
    if state.current_role and not state.hardgate_satisfied:
        missing = get_missing_hardgate_docs(
            state.current_role, state.documents_read
        )
        if missing:
            parts.append(
                f"HARD-GATE NOT SATISFIED: Load before acting: {missing}"
            )

    parts.append("[/GOVERNANCE STATE]")

    return {"context": "\n".join(parts)}


# ---------------------------------------------------------------------------
# Hook: pre_tool_call
# ---------------------------------------------------------------------------
# Under ADAPTER_ENFORCEMENT_CONTRACT v1 (docs/templates/adapter/
# ADAPTER_ENFORCEMENT_CONTRACT.md), this hook returns an abort envelope
# on DENY: {"abort": True, "reason": ..., "pdr": {...}}. Hermes hosts
# implementing contract v1 MUST honor `abort: True` by cancelling the
# tool invocation. Hosts that pre-date the contract silently ignore the
# return value; MCP-side receipt rejection in server.py provides the
# indirect enforcement fallback until host migration completes.

def _pre_tool_call(tool_name: str, args: dict, task_id: str, **kwargs):
    """Evaluate authority / context-class rules before tool execution.

    Returns None on ALLOW (or when governance inactive); returns an
    {"abort": True, ...} envelope on DENY.
    """
    state = SESSION_STATES.get(kwargs.get("session_id", ""))
    if not state or not state.governance_active:
        return None

    # Audit-log intent unconditionally.
    if state.audit_file:
        write_audit_entry(state.audit_file, {
            "event": "tool_call_intent",
            "tool": tool_name,
            "args_summary": summarize_args(args),
            "role": state.current_role,
            "task_id": (
                state.current_task.get("task_id")
                if state.current_task
                else None
            ),
        })

    # Authority check for file-mutating operations.
    file_path = extract_file_path(tool_name, args)
    if not file_path or not state.current_role:
        return None
    operation = classify_operation(tool_name)
    if operation != "write":
        return None

    auth = check_authority(file_path, operation, state.current_role)
    if auth.get("decision") != "DENY":
        return None

    # Persist PDR to decisions.jsonl (best-effort). The absence of this
    # file is acceptable; M4 verifier surfaces gaps instead of erroring.
    _append_pdr(
        session_id=kwargs.get("session_id", ""),
        tool_name=tool_name,
        file_path=file_path,
        operation=operation,
        auth_result=auth,
        task_id=(state.current_task.get("task_id") if state.current_task else None),
    )

    return {
        "abort": True,
        "reason": auth.get("reason", "authority denied"),
        "rule_id": auth.get("rule_id"),
        "policy_version": auth.get("policy_version"),
        "contract_version": auth.get("contract_version", 1),
    }


# ---------------------------------------------------------------------------
# Hook: post_tool_call
# ---------------------------------------------------------------------------

def _post_tool_call(
    tool_name: str,
    args: dict,
    result: str,
    task_id: str,
    **kwargs,
):
    """Audit trail + violation detection + HARD-GATE tracking.

    Records every tool call. For file operations, checks authority
    and tracks document reads for HARD-GATE satisfaction.
    """
    state = SESSION_STATES.get(kwargs.get("session_id", ""))
    if not state or not state.governance_active or not state.audit_file:
        return

    entry = {
        "event": "tool_call_complete",
        "tool": tool_name,
        "args_summary": summarize_args(args),
        "role": state.current_role,
        "task_id": (
            state.current_task.get("task_id")
            if state.current_task
            else None
        ),
    }

    # Detect file operations
    file_path = extract_file_path(tool_name, args)
    if file_path:
        operation = classify_operation(tool_name)
        entry["file_path"] = file_path
        entry["operation"] = operation

        # Check authority violation
        if state.current_role:
            auth_result = check_authority(
                file_path, operation, state.current_role
            )
            entry["authority_check"] = auth_result["decision"]
            if auth_result["decision"] == "DENY":
                entry["violation"] = True
                entry["violation_reason"] = auth_result.get("reason", "")

        # Track document reads for HARD-GATE satisfaction
        if operation == "read":
            normalized = file_path.replace("\\", "/").strip()
            if normalized.startswith("./"):
                normalized = normalized[2:]
            state.documents_read.add(normalized)

            # Re-check hardgate
            from .hardgate import check_hardgate_satisfaction

            if state.current_role:
                state.hardgate_satisfied = check_hardgate_satisfaction(
                    state.current_role, state.documents_read
                )

    write_audit_entry(state.audit_file, entry)
