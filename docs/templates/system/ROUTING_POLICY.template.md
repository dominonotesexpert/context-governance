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

`PROJECT_BASELINE.md` is the highest-authority input to all routing decisions. The System Architect loads it directly; all other roles consume the baseline constraints extracted by the System Architect.

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
- `PROJECT_BASELINE.md` — **Tier 0 root document (only System Architect loads this directly)**
- `BASELINE_INTERPRETATION_LOG.md` — **Tier 0.5 user-confirmed semantic clarifications**
- `SYSTEM_GOAL_PACK.md` — product vision and obligations (derived from BASELINE)
- `SYSTEM_AUTHORITY_MAP.md` — which documents are authoritative
- `SYSTEM_INVARIANTS.md` — hard rules that cannot be violated (derived from BASELINE §4)

### Module Architect
- Baseline constraints extracted by System Architect (passed downstream, NOT the original BASELINE)
- The target module's `MODULE_CONTRACT.md`
- `SYSTEM_INVARIANTS.md` (for cross-reference)

### Debug Agent
- Baseline constraints extracted by System Architect (passed downstream)
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

### 5.1 Business-Semantic Confirmation Boundary

User confirmation is required ONLY for unresolved business semantics:
- Business ambiguity (a core capability can be interpreted multiple ways)
- Business conflict (two business rules appear to contradict)
- Scope ambiguity (unclear whether something is in or out of scope)
- Success-semantics ambiguity (unclear what "success" means for a criterion)
- Business-impacting branch decisions (a technical choice that would change business meaning)

Normal technical design — module decomposition, interface shape, implementation patterns, testing strategy — MUST NOT be blocked on user confirmation. Agents derive these autonomously.

When a technical decision would alter the business promise, scope boundary, meaning of success, or meaning of failure handling, it is no longer purely technical and must be escalated as a business-semantics question. The confirmed answer is recorded in BASELINE_INTERPRETATION_LOG, not in downstream artifacts directly.

### 5.2 General Confidence Rules

1. If the agent's confidence in task classification is **low** (ambiguous user request, overlapping categories), confirm the classification with the user before routing to Implementation or Debug.
2. If a Debug Agent cannot identify a root cause with evidence, it MUST NOT hand off to Implementation. Instead, escalate to the user with findings so far.
3. If an Implementation Agent encounters a gap in the module contract, it MUST escalate to Module Architect rather than making assumptions.
4. For design / architecture / protocol / contract authoring tasks, the agent MUST default to a complete draft, not a section-by-section approval loop.
5. During design tasks, user questions are allowed only for business ambiguity, business conflict, unresolved authority conflict, or high-impact branch decisions that materially affect correctness.
6. When such design questions are needed, the agent MUST consolidate them into a minimal blocking-question list instead of interrupting after each section.

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
