"""HARD-GATE requirement registry for Context Governance.

Defines which documents each role MUST load before acting,
mirroring the <HARD-GATE> blocks in each .claude/skills/{role}/SKILL.md.
"""

from __future__ import annotations

from .constants import (
    ROLE_AUTORESEARCH,
    ROLE_DEBUG,
    ROLE_FRONTEND_SPECIALIST,
    ROLE_IMPLEMENTATION,
    ROLE_MODULE_ARCHITECT,
    ROLE_SYSTEM_ARCHITECT,
    ROLE_VERIFICATION,
)

# ---------------------------------------------------------------------------
# Required documents per role (from SKILL.md <HARD-GATE> blocks)
# ---------------------------------------------------------------------------

# System Architect: loads all Tier 0–2 documents
_SA_REQUIRED = [
    "docs/agents/PROJECT_BASELINE.md",
    "docs/agents/system/BASELINE_INTERPRETATION_LOG.md",
    "docs/agents/PROJECT_ARCHITECTURE_BASELINE.md",
    "docs/agents/system/SYSTEM_GOAL_PACK.md",
    "docs/agents/system/SYSTEM_AUTHORITY_MAP.md",
    "docs/agents/system/SYSTEM_CONFLICT_REGISTER.md",
    "docs/agents/system/SYSTEM_INVARIANTS.md",
    "docs/agents/execution/GOVERNANCE_MODE.md",
    "docs/agents/system/SYSTEM_ARCHITECTURE.md",
]

# Module Architect: baseline constraints (from SA) + module contract + invariants
_MA_REQUIRED_BASE = [
    "docs/agents/system/SYSTEM_GOAL_PACK.md",
    "docs/agents/system/SYSTEM_INVARIANTS.md",
    "docs/agents/system/ENGINEERING_CONSTRAINTS.md",
]

# Debug: baseline constraints + debug templates + module contract
_DEBUG_REQUIRED_BASE = [
    "docs/agents/system/SYSTEM_GOAL_PACK.md",
    "docs/agents/debug/DEBUG_CASE_TEMPLATE.md",
    "docs/agents/system/SYSTEM_SCENARIO_MAP_INDEX.md",
    "docs/agents/system/ENGINEERING_CONSTRAINTS.md",
]

# Implementation: baseline constraints + goal pack + module contract
_IMPL_REQUIRED_BASE = [
    "docs/agents/system/SYSTEM_GOAL_PACK.md",
]

# Verification: baseline constraints + invariants + acceptance rules + module contract
_VERIFY_REQUIRED_BASE = [
    "docs/agents/system/SYSTEM_INVARIANTS.md",
    "docs/agents/verification/ACCEPTANCE_RULES.md",
]

# Frontend Specialist: goal pack + module contract + invariants
_FRONTEND_REQUIRED_BASE = [
    "docs/agents/system/SYSTEM_GOAL_PACK.md",
    "docs/agents/system/SYSTEM_INVARIANTS.md",
]

# Autoresearch: goal pack + invariants + interpretation log + optimization log
_AUTORESEARCH_REQUIRED = [
    "docs/agents/system/SYSTEM_GOAL_PACK.md",
    "docs/agents/system/SYSTEM_INVARIANTS.md",
    "docs/agents/system/BASELINE_INTERPRETATION_LOG.md",
    "docs/agents/optimization/OPTIMIZATION_LOG.md",
]

# ---------------------------------------------------------------------------
# Role → required docs mapping
# ---------------------------------------------------------------------------

HARDGATE_REQUIREMENTS: dict[str, list[str]] = {
    ROLE_SYSTEM_ARCHITECT: _SA_REQUIRED,
    ROLE_MODULE_ARCHITECT: _MA_REQUIRED_BASE,
    ROLE_DEBUG: _DEBUG_REQUIRED_BASE,
    ROLE_IMPLEMENTATION: _IMPL_REQUIRED_BASE,
    ROLE_VERIFICATION: _VERIFY_REQUIRED_BASE,
    ROLE_FRONTEND_SPECIALIST: _FRONTEND_REQUIRED_BASE,
    ROLE_AUTORESEARCH: _AUTORESEARCH_REQUIRED,
}


def get_required_docs_for_role(
    role: str,
    module_name: str | None = None,
) -> list[str]:
    """Get the list of documents required by a role's HARD-GATE.

    For roles that need module context, the module's MODULE_CONTRACT.md
    is appended to the base requirements.
    """
    base = list(HARDGATE_REQUIREMENTS.get(role, []))

    # Roles that need module contract
    module_roles = {
        ROLE_MODULE_ARCHITECT,
        ROLE_DEBUG,
        ROLE_IMPLEMENTATION,
        ROLE_VERIFICATION,
        ROLE_FRONTEND_SPECIALIST,
    }

    if role in module_roles and module_name:
        contract_path = f"docs/agents/modules/{module_name}/MODULE_CONTRACT.md"
        base.append(contract_path)

    return base


def check_hardgate_satisfaction(
    role: str,
    documents_read: set[str],
    module_name: str | None = None,
) -> bool:
    """Check if all HARD-GATE required documents have been loaded.

    Returns True if all required documents for the role have been read.
    """
    required = get_required_docs_for_role(role, module_name)
    normalized_read = {_normalize(p) for p in documents_read}

    for req in required:
        if _normalize(req) not in normalized_read:
            return False

    return True


def get_missing_hardgate_docs(
    role: str,
    documents_read: set[str],
    module_name: str | None = None,
) -> list[str]:
    """Get list of HARD-GATE required documents that have NOT been loaded."""
    required = get_required_docs_for_role(role, module_name)
    normalized_read = {_normalize(p) for p in documents_read}

    return [req for req in required if _normalize(req) not in normalized_read]


def _normalize(path: str) -> str:
    """Normalize a document path for comparison.

    Strips leading ./ and trailing whitespace, normalizes separators.
    """
    p = path.replace("\\", "/").strip()
    if p.startswith("./"):
        p = p[2:]
    return p
