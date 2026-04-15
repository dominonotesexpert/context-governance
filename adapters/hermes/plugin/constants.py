"""Context Governance constants for Hermes plugin.

Defines tier hierarchy, role names, file-tier patterns, and the authority matrix.
Source of truth: docs/templates/system/SYSTEM_AUTHORITY_MAP.template.md
"""

import re

# ---------------------------------------------------------------------------
# Tier definitions (from SYSTEM_AUTHORITY_MAP tiers 0–7)
# ---------------------------------------------------------------------------

TIER_0 = 0          # PROJECT_BASELINE — user-owned root
TIER_0_5 = 0.5      # BASELINE_INTERPRETATION_LOG — user-confirmed semantics
TIER_0_8 = 0.8      # PROJECT_ARCHITECTURE_BASELINE — user-owned structure
TIER_1 = 1          # SYSTEM_GOAL_PACK — derived goals
TIER_1_5 = 1.5      # ENGINEERING_CONSTRAINTS — engineering reality
TIER_2 = 2          # SYSTEM_ARCHITECTURE — derived architecture
TIER_3 = 3          # SYSTEM_INVARIANTS, SYSTEM_AUTHORITY_MAP, etc.
TIER_4 = 4          # MODULE_CONTRACT — module truth
TIER_5 = 5          # Supporting docs (debug cases, scenarios, acceptance rules)
TIER_7 = 7          # Code — evidence, not truth

# ---------------------------------------------------------------------------
# Role names
# ---------------------------------------------------------------------------

ROLE_SYSTEM_ARCHITECT = "system-architect"
ROLE_MODULE_ARCHITECT = "module-architect"
ROLE_DEBUG = "debug"
ROLE_IMPLEMENTATION = "implementation"
ROLE_VERIFICATION = "verification"
ROLE_FRONTEND_SPECIALIST = "frontend-specialist"
ROLE_AUTORESEARCH = "autoresearch"

ALL_ROLES = [
    ROLE_SYSTEM_ARCHITECT,
    ROLE_MODULE_ARCHITECT,
    ROLE_DEBUG,
    ROLE_IMPLEMENTATION,
    ROLE_VERIFICATION,
    ROLE_FRONTEND_SPECIALIST,
    ROLE_AUTORESEARCH,
]

# ---------------------------------------------------------------------------
# File-to-tier patterns (order matters — first match wins)
# ---------------------------------------------------------------------------

FILE_TIER_PATTERNS: list[tuple[re.Pattern, float]] = [
    # Tier 0: PROJECT_BASELINE
    (re.compile(r"(^|/)PROJECT_BASELINE\.md$"), TIER_0),

    # Tier 0.8: Architecture baseline
    (re.compile(r"(^|/)PROJECT_ARCHITECTURE_BASELINE\.md$"), TIER_0_8),

    # Tier 0.5: Interpretation log
    (re.compile(r"(^|/)BASELINE_INTERPRETATION_LOG\.md$"), TIER_0_5),

    # Tier 1: Derived goals
    (re.compile(r"(^|/)SYSTEM_GOAL_PACK\.md$"), TIER_1),

    # Tier 1.5: Engineering constraints
    (re.compile(r"(^|/)ENGINEERING_CONSTRAINTS\.md$"), TIER_1_5),

    # Tier 2: System architecture
    (re.compile(r"(^|/)SYSTEM_ARCHITECTURE\.md$"), TIER_2),

    # Tier 3: System constraints and authority
    (re.compile(r"(^|/)SYSTEM_INVARIANTS\.md$"), TIER_3),
    (re.compile(r"(^|/)SYSTEM_AUTHORITY_MAP\.md$"), TIER_3),
    (re.compile(r"(^|/)ROUTING_POLICY\.md$"), TIER_3),
    (re.compile(r"(^|/)SYSTEM_CONFLICT_REGISTER\.md$"), TIER_3),
    (re.compile(r"(^|/)SYSTEM_SCENARIO_MAP_INDEX\.md$"), TIER_3),
    (re.compile(r"(^|/)MODULE_TAXONOMY\.md$"), TIER_3),
    (re.compile(r"(^|/)SYSTEM_BOOTSTRAP_PACK\.md$"), TIER_3),

    # Tier 4: Module contracts
    (re.compile(r"(^|/)MODULE_CONTRACT\.md$"), TIER_4),

    # Tier 5: Supporting governance docs
    (re.compile(r"(^|/)docs/agents/"), TIER_5),
    (re.compile(r"(^|/)\.governance/"), TIER_5),

    # Everything else is Tier 7 (code)
]

DEFAULT_TIER = TIER_7

# ---------------------------------------------------------------------------
# Authority matrix: {tier: {operation: [allowed_roles]}}
# ---------------------------------------------------------------------------

AUTHORITY_MATRIX: dict[float, dict[str, list[str]]] = {
    TIER_0: {
        "read": [ROLE_SYSTEM_ARCHITECT],
        "write": [],  # User-owned, no programmatic writes
    },
    TIER_0_5: {
        "read": [ROLE_SYSTEM_ARCHITECT],
        "write": [ROLE_SYSTEM_ARCHITECT],
    },
    TIER_0_8: {
        "read": [ROLE_SYSTEM_ARCHITECT],
        "write": [],  # User-owned
    },
    TIER_1: {
        "read": ALL_ROLES,
        "write": [ROLE_SYSTEM_ARCHITECT],
    },
    TIER_1_5: {
        "read": ALL_ROLES,
        "write": [ROLE_SYSTEM_ARCHITECT],
    },
    TIER_2: {
        "read": ALL_ROLES,
        "write": [ROLE_SYSTEM_ARCHITECT],
    },
    TIER_3: {
        "read": ALL_ROLES,
        "write": [ROLE_SYSTEM_ARCHITECT],
    },
    TIER_4: {
        "read": ALL_ROLES,
        "write": [ROLE_SYSTEM_ARCHITECT, ROLE_MODULE_ARCHITECT],
    },
    TIER_5: {
        "read": ALL_ROLES,
        "write": ALL_ROLES,
    },
    TIER_7: {
        "read": ALL_ROLES,
        "write": [
            ROLE_IMPLEMENTATION,
            ROLE_FRONTEND_SPECIALIST,
            ROLE_DEBUG,
        ],
    },
}

# ---------------------------------------------------------------------------
# Task classification keywords (from ROUTING_POLICY §2)
# ---------------------------------------------------------------------------

TASK_TYPE_BUG = "bug"
TASK_TYPE_FEATURE = "feature"
TASK_TYPE_DESIGN = "design"
TASK_TYPE_AUTHORITY = "authority"

BUG_KEYWORDS = [
    "bug", "regression", "failure", "error", "broken", "crash", "incident",
    "unexpected", "test failure", "deploy failure", "log analysis", "fix",
    "not working", "issue", "defect",
]

FEATURE_KEYWORDS = [
    "feature", "implement", "refactor", "add", "create", "build",
    "code change", "enhance", "update", "migrate", "upgrade",
]

DESIGN_KEYWORDS = [
    "design", "architecture", "protocol", "contract", "spec",
    "proposal", "plan", "define", "draft",
]

AUTHORITY_KEYWORDS = [
    "document review", "authority dispute", "baseline conflict",
    "document conflict", "truth arbitration",
]

FRONTEND_KEYWORDS = [
    "ui", "layout", "accessibility", "a11y", "performance",
    "visual", "interaction", "css", "frontend", "responsive",
    "animation", "component",
]

# ---------------------------------------------------------------------------
# Route definitions (from ROUTING_POLICY §2)
# ---------------------------------------------------------------------------

ROUTES: dict[str, list[str]] = {
    TASK_TYPE_BUG: [
        ROLE_SYSTEM_ARCHITECT,
        ROLE_MODULE_ARCHITECT,
        ROLE_DEBUG,
        ROLE_IMPLEMENTATION,
        ROLE_VERIFICATION,
    ],
    TASK_TYPE_FEATURE: [
        ROLE_SYSTEM_ARCHITECT,
        ROLE_MODULE_ARCHITECT,
        ROLE_IMPLEMENTATION,
        ROLE_VERIFICATION,
    ],
    TASK_TYPE_DESIGN: [
        ROLE_SYSTEM_ARCHITECT,
        ROLE_MODULE_ARCHITECT,
        ROLE_VERIFICATION,
    ],
    TASK_TYPE_AUTHORITY: [
        ROLE_SYSTEM_ARCHITECT,
    ],
}

# ---------------------------------------------------------------------------
# Debug-level re-routing (from ROUTING_POLICY §4)
# ---------------------------------------------------------------------------

DEBUG_LEVEL_ROUTES: dict[str, list[str]] = {
    "code": [ROLE_IMPLEMENTATION, ROLE_VERIFICATION],
    "module": [ROLE_IMPLEMENTATION, ROLE_VERIFICATION],
    "cross-module": [ROLE_MODULE_ARCHITECT, ROLE_IMPLEMENTATION, ROLE_VERIFICATION],
    "engineering-constraint": [
        ROLE_SYSTEM_ARCHITECT, ROLE_MODULE_ARCHITECT,
        ROLE_IMPLEMENTATION, ROLE_VERIFICATION,
    ],
    "architecture": [
        ROLE_SYSTEM_ARCHITECT, ROLE_MODULE_ARCHITECT,
        ROLE_IMPLEMENTATION, ROLE_VERIFICATION,
    ],
    "baseline": [],  # Escalate to user, stop automated routing
}

# ---------------------------------------------------------------------------
# Governance script paths (relative to project root)
# ---------------------------------------------------------------------------

GOVERNANCE_DIR = ".governance"
ATTESTATION_DIR = ".governance/attestations"
INDEX_FILE = ".governance/attestations/index.jsonl"
ESCALATION_FILE = ".governance/escalations.jsonl"
CURRENT_TASK_FILE = ".governance/current-task.json"
AUDIT_DIR = ".governance/audit"
AUDIT_SESSION_FILE = ".governance/audit/session.jsonl"

DOCS_AGENTS_DIR = "docs/agents"
GOVERNANCE_MODE_FILE = "docs/agents/execution/GOVERNANCE_MODE.md"
