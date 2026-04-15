"""Tool schemas for Context Governance Hermes plugin.

Defines 4 governance tools in OpenAI function-calling format,
as required by Hermes Agent's tool registration API.
"""

GOVERNANCE_CLASSIFY_TASK = {
    "name": "governance_classify_task",
    "description": (
        "Classify a task description and determine the Context Governance "
        "route (ordered list of roles). Returns task type, route, and "
        "confidence score. Use this before starting any governed task."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "description": {
                "type": "string",
                "description": "Natural language description of the task",
            },
        },
        "required": ["description"],
    },
}

GOVERNANCE_LOAD_ROLE_CONTEXT = {
    "name": "governance_load_role_context",
    "description": (
        "Load all required governance documents and constraints for a "
        "specific role. Returns document contents, applicable constraints, "
        "and HARD-GATE satisfaction status. Call this when activating a role."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "role": {
                "type": "string",
                "enum": [
                    "system-architect",
                    "module-architect",
                    "debug",
                    "implementation",
                    "verification",
                    "frontend-specialist",
                    "autoresearch",
                ],
                "description": "The governance role to load context for",
            },
            "module": {
                "type": "string",
                "description": (
                    "Target module name. Required for module-architect, "
                    "optional for roles that work on a specific module."
                ),
            },
            "baseline_constraints": {
                "type": "string",
                "description": (
                    "Baseline constraints summary from System Architect. "
                    "Required for all roles except system-architect."
                ),
            },
        },
        "required": ["role"],
    },
}

GOVERNANCE_ENFORCE_HARDGATE = {
    "name": "governance_enforce_hardgate",
    "description": (
        "Verify that all required documents for a role's HARD-GATE have "
        "been loaded. Returns PASS if all documents are loaded, FAIL with "
        "a list of missing documents otherwise. Call after loading role context."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "role": {
                "type": "string",
                "enum": [
                    "system-architect",
                    "module-architect",
                    "debug",
                    "implementation",
                    "verification",
                    "frontend-specialist",
                    "autoresearch",
                ],
                "description": "The governance role to check HARD-GATE for",
            },
            "loaded_docs": {
                "type": "array",
                "items": {"type": "string"},
                "description": (
                    "List of document paths that have been loaded in this session"
                ),
            },
            "module": {
                "type": "string",
                "description": "Target module name (for roles that need module context)",
            },
        },
        "required": ["role", "loaded_docs"],
    },
}

GOVERNANCE_CHECK_AUTHORITY = {
    "name": "governance_check_authority",
    "description": (
        "Check whether a file operation (read/write) is allowed for the "
        "current governance role based on SYSTEM_AUTHORITY_MAP tier assignments. "
        "Returns ALLOW or DENY with explanation. Call before any file modification."
    ),
    "parameters": {
        "type": "object",
        "properties": {
            "file_path": {
                "type": "string",
                "description": "Path to the file being accessed (relative to project root)",
            },
            "operation": {
                "type": "string",
                "enum": ["read", "write"],
                "description": "The operation being performed",
            },
            "current_role": {
                "type": "string",
                "enum": [
                    "system-architect",
                    "module-architect",
                    "debug",
                    "implementation",
                    "verification",
                    "frontend-specialist",
                    "autoresearch",
                ],
                "description": "The current governance role",
            },
        },
        "required": ["file_path", "operation", "current_role"],
    },
}

# All tool schemas for registration
TOOL_SCHEMAS = [
    GOVERNANCE_CLASSIFY_TASK,
    GOVERNANCE_LOAD_ROLE_CONTEXT,
    GOVERNANCE_ENFORCE_HARDGATE,
    GOVERNANCE_CHECK_AUTHORITY,
]
