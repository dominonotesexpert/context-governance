---
artifact_type: routing-policy
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [all-roles]
last_reviewed: YYYY-MM-DD
---

# ROUTING_POLICY

**Status:** proposed
**Owner:** System Architect Agent

## 1. Purpose

This is the SINGLE source of truth for task routing. All platform entrypoints (CLAUDE.md, AGENTS.md, GEMINI.md, etc.) MUST reference this document instead of duplicating routing rules.

When this document and a platform entrypoint disagree, this document wins.

## 2. Task Classification Table

| If the task involves... | Route |
|------------------------|-------|
| Bug, regression, test failure, deploy failure, log analysis, unexpected behavior | System -> Module -> Debug -> Implementation -> Verification |
| Feature implementation, code change, refactoring | System -> Module -> Implementation -> Verification |
| Design, architecture, protocol, contract authoring | System -> Module -> Verification (NO implementation unless explicitly requested) |
| UI, interaction, a11y, performance | Add **Frontend Specialist** to the applicable route above |
| Document review, authority dispute, baseline conflict | System Architect only |

## 3. Task-Type Switch Rules

If the task type changes mid-session (e.g., a feature task reveals a bug):

1. Stop current route.
2. Re-classify the task using the table above.
3. Reroute from **System -> Module** using the latest user instruction.
4. Do NOT carry forward assumptions from the previous classification.

The user's most recent instruction is authoritative for classification. If ambiguous, confirm with the user before rerouting.

## 4. Minimum Artifact Loading Per Route Step

Each route step MUST load the listed artifacts before proceeding.

### System Architect
- `SYSTEM_GOAL_PACK.md` — product vision and obligations
- `SYSTEM_AUTHORITY_MAP.md` — which documents are authoritative
- `SYSTEM_INVARIANTS.md` — hard rules that cannot be violated

### Module Architect
- The target module's `MODULE_CONTRACT.md`
- `SYSTEM_INVARIANTS.md` (for cross-reference)

### Debug Agent
- `DEBUG_CASE_TEMPLATE.md` — to create a DEBUG_CASE
- `SYSTEM_SCENARIO_MAP_INDEX.md` — to match the trigger to a known scenario
- The target module's `MODULE_CONTRACT.md` — to understand expected behavior

### Implementation Agent
- All upstream artifacts produced by System, Module, and (if applicable) Debug steps
- The target module's `MODULE_CONTRACT.md`

### Verification Agent
- `ACCEPTANCE_RULES.md`
- The target module's `MODULE_CONTRACT.md`
- All upstream artifacts from the current task

### Frontend Specialist (when added)
- All artifacts from the base route
- Any UI-specific contracts or design specs

## 5. Confidence and Confirmation Rules

1. If the agent's confidence in task classification is **low** (ambiguous user request, overlapping categories), confirm the classification with the user before routing to Implementation or Debug.
2. If a Debug Agent cannot identify a root cause with evidence, it MUST NOT hand off to Implementation. Instead, escalate to the user with findings so far.
3. If an Implementation Agent encounters a gap in the module contract, it MUST escalate to Module Architect rather than making assumptions.

## 6. Platform Entrypoint Contract

### What platform entrypoints (CLAUDE.md, AGENTS.md, GEMINI.md, etc.) MUST do:
- Reference this document as the routing authority
- Load this document at session start
- Apply the routing rules defined here

### What platform entrypoints MUST NOT do:
- Define their own routing tables (creates drift)
- Override routes defined here without updating this document
- Add routing rules inline that are not reflected here

### What this document owns:
- Task classification definitions
- Route sequences
- Artifact loading requirements per step
- Confidence and confirmation rules
- Task-type switch behavior
