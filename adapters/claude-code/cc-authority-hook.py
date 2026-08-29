#!/usr/bin/env python3
"""Claude Code PreToolUse authority hook.

Invoked by Claude Code via .claude/settings.local.json `hooks.PreToolUse`.
Evaluates the authority policy against the intended tool call and returns
a non-zero exit code (plus stderr message) when the operation is DENYed.

Environment inputs from Claude Code:
    CLAUDE_TOOL_NAME            : Tool being invoked (Edit / Write / Bash / ...)
    CLAUDE_TOOL_PARAM_file_path : File path for Edit/Write/MultiEdit
    CLAUDE_TOOL_PARAM_command   : Command for Bash
    CG_REPO_ROOT                : Optional override for repo auto-detection
    CG_ACTOR_ROLE               : Optional override for role detection

Exit codes:
    0   Allowed (PDR appended on best-effort basis)
    1   Denied; tool invocation MUST be aborted by Claude Code
    2   Misuse (missing required env vars in a context that requires them)

Contract: docs/templates/adapter/ADAPTER_ENFORCEMENT_CONTRACT.md v1
"""

from __future__ import annotations

import json
import os
import sys
from datetime import datetime, timezone
from pathlib import Path

CONTRACT_VERSION = 1


def _now_iso() -> str:
    return datetime.now(timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ")


def _find_repo_root() -> Path:
    override = os.environ.get("CG_REPO_ROOT")
    if override:
        return Path(override).resolve()
    cwd = Path.cwd().resolve()
    for candidate in [cwd, *cwd.parents]:
        if (candidate / ".governance").is_dir():
            return candidate
    return cwd


def _load_current_task(repo_root: Path) -> dict:
    task_file = repo_root / ".governance" / "current-task.json"
    if not task_file.is_file():
        return {}
    try:
        return json.loads(task_file.read_text())
    except (OSError, json.JSONDecodeError):
        return {}


def _detect_actor_role(repo_root: Path) -> str:
    override = os.environ.get("CG_ACTOR_ROLE")
    if override:
        return override
    task = _load_current_task(repo_root)
    # Convention: current-task.json may carry an "active_role" field written
    # by the governance router skill. Fall back to "implementation" when
    # the field is absent — the most permissive common role for code edits.
    return str(task.get("active_role") or "implementation")


def _detect_context_class(repo_root: Path) -> str:
    task = _load_current_task(repo_root)
    return str(task.get("context_class") or "internal")


def _operation_for_tool(tool: str) -> str | None:
    if tool in ("Edit", "Write", "MultiEdit", "NotebookEdit"):
        return "write"
    if tool in ("Read", "Glob", "Grep"):
        return "read"
    # Bash and other tools are not subject to authority rule in M3; they
    # are gated by context-class-tools rule separately.
    return None


def _append_pdr(repo_root: Path, pdr: dict) -> None:
    path = repo_root / ".governance" / "decisions.jsonl"
    path.parent.mkdir(parents=True, exist_ok=True)
    with open(path, "a") as f:
        f.write(json.dumps(pdr, separators=(",", ":")) + "\n")


def _next_pdr_id(repo_root: Path) -> str:
    path = repo_root / ".governance" / "decisions.jsonl"
    today = datetime.now(timezone.utc).strftime("%Y%m%d")
    max_seq = 0
    if path.exists():
        try:
            for line in path.read_text().splitlines():
                line = line.strip()
                if not line:
                    continue
                try:
                    entry = json.loads(line)
                except json.JSONDecodeError:
                    continue
                pid = entry.get("pdr_id", "")
                if pid.startswith(f"PDR-{today}-"):
                    try:
                        seq = int(pid.rsplit("-", 1)[-1])
                        if seq > max_seq:
                            max_seq = seq
                    except ValueError:
                        continue
        except OSError:
            pass
    return f"PDR-{today}-{max_seq + 1:03d}"


def _evaluate_via_engine(
    repo_root: Path, runtime_call: dict
) -> dict | None:
    """Import policy_engine from the framework install and evaluate both
    authority and context-class-tools rules. Returns a dict summarizing
    the terminal decision, or None if the engine is unavailable.
    """
    mcp_dir = repo_root / "governance-mcp-server"
    if not (mcp_dir / "policy_engine").is_dir():
        return None
    if str(mcp_dir) not in sys.path:
        sys.path.insert(0, str(mcp_dir))
    try:
        from policy_engine import Engine, EvalContext, load_rule
    except Exception:
        return None

    rules_dir = repo_root / "docs" / "templates" / "governance" / "rules"
    ctx = EvalContext(
        repo_root=repo_root,
        runtime_call=runtime_call,
        offline=True,
    )
    engine = Engine()

    # Authority check is skipped when the operation is not file-valued.
    summary: dict | None = None
    if runtime_call.get("operation") in ("read", "write"):
        rule_path = rules_dir / "authority.rule.yaml"
        if rule_path.is_file():
            try:
                rule = load_rule(rule_path)
                decisions = engine.evaluate(rule, ctx)
                if decisions:
                    d = decisions[0]
                    summary = {
                        "rule_id": d.rule_id,
                        "policy_version": d.policy_version,
                        "decision": d.decision,
                        "reason": d.reason,
                        "clause_id": d.clause_id,
                        "context_hash": d.context_hash,
                        "subject_kind": d.subject_kind,
                        "subject_id": d.subject_id,
                        "action": d.action,
                    }
            except Exception:
                summary = None

    # Context-class-tools check applies to any tool invocation.
    ct_path = rules_dir / "context-class-tools.rule.yaml"
    if ct_path.is_file():
        try:
            rule = load_rule(ct_path)
            decisions = engine.evaluate(rule, ctx)
            if decisions:
                d = decisions[0]
                if d.decision == "DENY":
                    # Context-class DENY takes precedence over authority ALLOW.
                    return {
                        "rule_id": d.rule_id,
                        "policy_version": d.policy_version,
                        "decision": d.decision,
                        "reason": d.reason,
                        "clause_id": d.clause_id,
                        "context_hash": d.context_hash,
                        "subject_kind": d.subject_kind,
                        "subject_id": d.subject_id,
                        "action": d.action,
                    }
        except Exception:
            pass

    return summary


def main() -> int:
    tool = os.environ.get("CLAUDE_TOOL_NAME") or ""
    file_path = os.environ.get("CLAUDE_TOOL_PARAM_file_path") or ""
    command = os.environ.get("CLAUDE_TOOL_PARAM_command") or ""

    repo_root = _find_repo_root()
    actor_role = _detect_actor_role(repo_root)
    context_class = _detect_context_class(repo_root)
    operation = _operation_for_tool(tool)

    runtime_call = {
        "actor_role": actor_role,
        "tool_name": tool,
        "tool_args": {"file_path": file_path, "command": command},
        "subject_path": file_path,
        "operation": operation or "invoke",
        "context_class": context_class,
    }
    task = _load_current_task(repo_root)
    task_id = task.get("task_id")

    result = _evaluate_via_engine(repo_root, runtime_call)

    if result is None:
        # Fail-closed fallback contract §3: DENY for writes, ALLOW for reads.
        decision = "DENY" if operation == "write" else "ALLOW"
        reason = "engine-unavailable: fail-closed fallback"
        pdr = {
            "schema_version": 1,
            "pdr_id": _next_pdr_id(repo_root),
            "task_id": task_id,
            "actor": {
                "kind": "agent",
                "id": f"claude-code:{os.environ.get('CLAUDE_SESSION_ID') or 'unknown'}",
                "session_id": os.environ.get("CLAUDE_SESSION_ID"),
            },
            "subject": {
                "kind": "file" if operation in ("read", "write") else "tool",
                "id": file_path or tool,
            },
            "action": operation or "invoke",
            "decision": decision,
            "reason": reason,
            "rule_id": "fallback",
            "policy_version": "unknown",
            "context_hash": "",
            "timestamp": _now_iso(),
            "chain_prev_hash": None,
        }
        _append_pdr(repo_root, pdr)
        if decision == "DENY":
            print(f"BLOCKED ({reason}): {tool} {file_path}", file=sys.stderr)
            return 1
        return 0

    pdr = {
        "schema_version": 1,
        "pdr_id": _next_pdr_id(repo_root),
        "task_id": task_id,
        "actor": {
            "kind": "agent",
            "id": f"claude-code:{os.environ.get('CLAUDE_SESSION_ID') or 'unknown'}",
            "session_id": os.environ.get("CLAUDE_SESSION_ID"),
        },
        "subject": {"kind": result["subject_kind"], "id": result["subject_id"]},
        "action": result["action"],
        "decision": result["decision"],
        "reason": result["reason"],
        "rule_id": result["rule_id"],
        "policy_version": result["policy_version"],
        "context_hash": result["context_hash"],
        "timestamp": _now_iso(),
        "chain_prev_hash": None,
    }
    _append_pdr(repo_root, pdr)

    if result["decision"] == "DENY":
        print(
            f"BLOCKED: {result['reason']} (rule={result['rule_id']}@{result['policy_version']})",
            file=sys.stderr,
        )
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
