"""Authority enforcement for Context Governance.

Classifies files by tier, checks read/write authority per role,
and provides role-level constraint summaries.
"""

from __future__ import annotations

from .constants import (
    ALL_ROLES,
    AUTHORITY_MATRIX,
    DEFAULT_TIER,
    FILE_TIER_PATTERNS,
)


def classify_file_tier(file_path: str) -> float:
    """Classify a file path into its governance tier.

    Uses pattern matching from FILE_TIER_PATTERNS (first match wins).
    Returns DEFAULT_TIER (7 = code) if no pattern matches.
    """
    # Normalize path separators
    normalized = file_path.replace("\\", "/")

    for pattern, tier in FILE_TIER_PATTERNS:
        if pattern.search(normalized):
            return tier

    return DEFAULT_TIER


def check_authority(
    file_path: str,
    operation: str,
    current_role: str,
) -> dict:
    """Check whether a file operation is allowed for the current role.

    Returns:
        dict with keys:
        - decision: "ALLOW" or "DENY"
        - file_path: the checked path
        - operation: "read" or "write"
        - current_role: the role that attempted the operation
        - file_tier: the tier of the file
        - allowed_roles: roles that can perform this operation on this tier
        - reason: explanation (present when DENY)
        - escalation_target: role to escalate to (present when DENY)
    """
    file_tier = classify_file_tier(file_path)
    rule = AUTHORITY_MATRIX.get(file_tier, AUTHORITY_MATRIX[DEFAULT_TIER])
    allowed_roles = rule.get(operation, [])

    decision = "ALLOW" if current_role in allowed_roles else "DENY"

    result = {
        "file_path": file_path,
        "operation": operation,
        "current_role": current_role,
        "file_tier": file_tier,
        "decision": decision,
        "allowed_roles": allowed_roles,
    }

    if decision == "DENY":
        if not allowed_roles:
            result["reason"] = (
                f"Tier {file_tier} file '{file_path}' cannot be {operation} "
                f"by any role programmatically (user-owned)."
            )
            result["escalation_target"] = "user"
        else:
            result["reason"] = (
                f"Role '{current_role}' cannot {operation} tier {file_tier} "
                f"file '{file_path}'. Allowed roles: {allowed_roles}."
            )
            result["escalation_target"] = _determine_escalation_target(file_tier)

    return result


def get_role_authority_constraints(current_role: str) -> dict:
    """Get a summary of read/write constraints for a role.

    Returns:
        dict with keys:
        - read_tiers: list of tiers this role can read
        - write_tiers: list of tiers this role can write
        - blocked_files: example file patterns the role cannot access
    """
    read_tiers = []
    write_tiers = []
    blocked_examples = []

    for tier, rule in sorted(AUTHORITY_MATRIX.items()):
        if current_role in rule.get("read", []):
            read_tiers.append(tier)
        else:
            blocked_examples.extend(_tier_example_files(tier, "read"))

        if current_role in rule.get("write", []):
            write_tiers.append(tier)

    return {
        "role": current_role,
        "read_tiers": read_tiers,
        "write_tiers": write_tiers,
        "blocked_files": blocked_examples[:5],  # Keep it concise
    }


def _determine_escalation_target(file_tier: float) -> str:
    """Determine which role to escalate to when access is denied."""
    if file_tier <= 0.8:
        return "user"  # Tier 0, 0.5, 0.8 are user-owned or SA-exclusive
    if file_tier <= 3:
        return "system-architect"
    if file_tier <= 4:
        return "module-architect"
    return "system-architect"


def _tier_example_files(tier: float, operation: str) -> list[str]:
    """Return example file names for a tier (for constraint display)."""
    examples = {
        0: ["PROJECT_BASELINE.md"],
        0.5: ["BASELINE_INTERPRETATION_LOG.md"],
        0.8: ["PROJECT_ARCHITECTURE_BASELINE.md"],
        1: ["SYSTEM_GOAL_PACK.md"],
        1.5: ["ENGINEERING_CONSTRAINTS.md"],
        2: ["SYSTEM_ARCHITECTURE.md"],
        3: ["SYSTEM_INVARIANTS.md", "ROUTING_POLICY.md"],
        4: ["MODULE_CONTRACT.md"],
    }
    return examples.get(tier, [])
