"""Decision dataclass and PDR conversion."""

from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass
class Decision:
    """One policy evaluation outcome.

    A Decision is the engine's internal shape; it becomes a PDR
    (Policy Decision Record) when an actor, task_id, and timestamp are
    layered on for persistence.
    """

    rule_id: str
    policy_version: str
    subject_kind: str
    subject_id: str
    action: str
    decision: str  # ALLOW | DENY | ESCALATE
    reason: str
    context_hash: str
    clause_id: str | None = None
    metadata: dict[str, Any] = field(default_factory=dict)

    def to_pdr(
        self,
        *,
        pdr_id: str,
        actor: dict,
        timestamp: str,
        task_id: str | None = None,
        chain_prev_hash: str | None = None,
    ) -> dict:
        """Convert to a PDR dict matching POLICY_DECISION_RECORD.schema.yaml v1."""
        return {
            "schema_version": 1,
            "pdr_id": pdr_id,
            "task_id": task_id,
            "actor": dict(actor),
            "subject": {"kind": self.subject_kind, "id": self.subject_id},
            "action": self.action,
            "decision": self.decision,
            "reason": self.reason,
            "rule_id": self.rule_id,
            "policy_version": self.policy_version,
            "context_hash": self.context_hash,
            "timestamp": timestamp,
            "chain_prev_hash": chain_prev_hash,
        }
