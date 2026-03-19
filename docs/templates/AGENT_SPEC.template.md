# AGENT_SPEC: [role-name]

**Status:** proposed
**Owner:** [Role Name] Agent
**Last Updated:** YYYY-MM-DD

---

## 1. Mission

<!-- One paragraph: what is this agent's core purpose? -->
<!-- Example: "This agent is the system-level truth arbitrator. It adjudicates what is true." -->

## 2. Mandatory Bootstrap Set

Before any task, this agent MUST read:

1. <!-- doc 1 -->
2. <!-- doc 2 -->
3. <!-- doc 3 -->
<!-- Keep to ≤5 docs. Progressive disclosure: load more only when needed. -->

## 3. On-Demand Evidence Set

Load only when the current task requires it:

1. <!-- Related code paths -->
2. <!-- Related test files -->
3. <!-- Historical docs for dispute resolution -->

## 4. Standard Inputs

Each task activation requires at least:

1. <!-- Input 1: e.g., task description -->
2. <!-- Input 2: e.g., affected module name -->
3. <!-- Input 3: e.g., evidence (logs, screenshots, etc.) -->

## 5. Standard Outputs

This agent must produce:

1. <!-- Output 1 -->
2. <!-- Output 2 -->
3. <!-- Output 3 -->

## 6. Core Judgment Rules

This agent must judge:

1. <!-- Judgment 1: e.g., "Is this within my boundary?" -->
2. <!-- Judgment 2: e.g., "Does this violate an upstream contract?" -->
3. <!-- Judgment 3: e.g., "Should this be escalated?" -->

## 7. Escalation Triggers

STOP and escalate when:

1. <!-- Trigger 1: e.g., "Task requires changing a system invariant" -->
2. <!-- Trigger 2: e.g., "Module contract doesn't cover this case" -->
3. <!-- Trigger 3: e.g., "Code contradicts active baseline" -->

## 8. Boundary Statement

### This Agent Owns
<!-- List what this agent is responsible for -->

### This Agent Does NOT Own
<!-- List what this agent must NOT do — even if convenient -->

## 9. Single-Agent Usage (Claude Code)

When running in a single-agent environment (Claude Code without sub-agents), this role is activated by:

1. Reading this AGENT_SPEC
2. Reading the corresponding BOOTSTRAP_PACK
3. Following the SKILLS.md startup protocol for the task type
