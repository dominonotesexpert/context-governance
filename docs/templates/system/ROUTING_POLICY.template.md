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
- `PROJECT_ARCHITECTURE_BASELINE.md` — **Tier 0.8 user-owned structural truth**
- `SYSTEM_GOAL_PACK.md` — product vision and obligations (derived from BASELINE)
- `ENGINEERING_CONSTRAINTS.md` — engineering feasibility constraints
- `SYSTEM_AUTHORITY_MAP.md` — which documents are authoritative
- `SYSTEM_INVARIANTS.md` — hard rules that cannot be violated (derived from BASELINE §4)
- `GOVERNANCE_MODE.md` — current governance operating mode
- `SYSTEM_ARCHITECTURE.md` — Tier 2 derived architecture (when present)
- `ROUTING_POLICY.md` — this document

### Module Architect
- Baseline constraints extracted by System Architect (passed downstream, NOT the original BASELINE)
- The target module's `MODULE_CONTRACT.md`
- `SYSTEM_INVARIANTS.md` (for cross-reference)
- `ENGINEERING_CONSTRAINTS.md` — engineering reality that may shape module boundaries

### Debug Agent
- Baseline constraints extracted by System Architect (passed downstream)
- `DEBUG_CASE_TEMPLATE.md` — to create a DEBUG_CASE
- `SYSTEM_SCENARIO_MAP_INDEX.md` — to match the trigger to a known scenario
- `SYSTEM_ARCHITECTURE.md` — for structural drift detection
- The target module's `MODULE_CONTRACT.md` — to understand expected behavior
- `ENGINEERING_CONSTRAINTS.md` — for root-cause context (known defects, capacity limits)

### Debug Agent Level-Based Routing

After root cause confirmation (Step 8A), Debug Agent routes based on root cause level:

| Root Cause Level | Routing Target | User Escalation? | Rationale |
|-----------------|----------------|------------------|-----------|
| `code` | Implementation Agent | No | Single-point fix within one module |
| `module` | Implementation Agent + Module Architect review | No | Fix may affect module contract |
| `cross-module` | Module Architect (both modules) → Implementation | Only if business-semantic | Contract boundary violation |
| `engineering-constraint` | System Architect (EC update) → downstream route | No | Engineering fact, not business semantics |
| `architecture` | System Architect → Module Architect → Implementation | Yes, if Tier 0.8 change or business-semantic | Systemic architectural issue |
| `baseline` | User → System Architect re-derivation → standard route | Always | Upstream truth issue |

Debug Agent MUST NOT hand off directly to Implementation for `cross-module`, `engineering-constraint`, `architecture`, or `baseline` level bugs.

When GOVERNANCE_MODE = `incident`, level-based routing is DEFERRED. Incident mode routing (System → Implementation → post-incident review) takes precedence per §8. Level-based routing becomes mandatory during post-incident review.

### Implementation Agent
- All upstream artifacts produced by System, Module, and (if applicable) Debug steps
- The target module's `MODULE_CONTRACT.md`
- `ENGINEERING_CONSTRAINTS.md` — constraints that shape implementation choices

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

## 7. Derivation Staleness Rules

A derived document (SYSTEM_GOAL_PACK, SYSTEM_INVARIANTS, MODULE_CONTRACT, ACCEPTANCE_RULES, VERIFICATION_ORACLE, SYSTEM_ARCHITECTURE) is **stale** when any of:

1. `upstream_hash` in its `derivation_context` does not match the current git hash of its upstream source documents
2. `derivation_timestamp` is older than the latest modification timestamp of any upstream source
3. `model_id` differs from the current session's model (advisory only — does not block, but flags for review)

### When a derived document is stale:

1. System Architect MUST re-derive the document before any downstream agent consumes it
2. Re-derivation produces a diff against the previous version
3. The diff MUST be reviewed before the new version replaces the old
4. If the diff introduces unexpected semantic changes, escalate to user before accepting
5. After successful re-derivation + verification, update the DERIVATION_REGISTRY

### Staleness is checked at routing time

The System Architect checks `derivation_context.upstream_hash` against current upstream state during the artifact loading phase. This is part of the existing HARD-GATE loading sequence — not a separate optional step.

## 8. Governance Mode Effects

### HARD-GATE: Mode Expiry Check

```
When: System Architect loads GOVERNANCE_MODE at routing start
Check: If current_mode ≠ steady-state AND today > expiry_date
Action: BLOCK all routing until one of:
  (a) User explicitly renews the mode (new expiry_date set)
  (b) System Architect reverts mode to steady-state and logs transition in MODE_TRANSITION_LOG
This is a HARD-GATE, not advisory. No agent may proceed past routing with an expired non-steady-state mode.
```

### Mode-Specific Routing Effects

| Mode | Routing Modification |
|------|---------------------|
| `steady-state` | No modification — full governance chain applies |
| `exploration` | Verification step is advisory (flags issues but does not block). Module contracts are treated as drafts. |
| `migration` | Implementation may deviate from contracts within the declared scope. Deviations outside scope are still blocked. |
| `incident` | Routing is shortened: System → Implementation → post-incident review. Module Architect and Verification steps are deferred. |
| `exception` | Only the declared suspended rules are relaxed. All other governance rules apply normally. |

### System Architect Pre-Routing Checklist

When mode ≠ steady-state, System Architect MUST verify before routing:
1. Mode has not expired (HARD-GATE above)
2. No artifact at Tier 0, 0.5, or 0.8 was modified during the mode window
3. If mode = exploration, no artifact has been promoted to `active` status
4. If mode = exception, renewal count ≤ 2 in MODE_TRANSITION_LOG

## 9. Architecture Conflict Resolution

When an agent encounters a conflict involving `PROJECT_ARCHITECTURE_BASELINE`:

1. If a downstream artifact contradicts Tier 0.8 structural decisions, the agent MUST NOT silently fix it — raise an `ARCHITECTURE_CHANGE_PROPOSAL`
2. If `ENGINEERING_CONSTRAINTS` makes Tier 0.8 infeasible, the agent raises a proposal with evidence
3. If `SYSTEM_ARCHITECTURE` (Tier 2) is stale relative to Tier 0.8, it MUST be re-derived before downstream agents consume it

### Conflict Classification (from design §6.2)

When `BASELINE_INTERPRETATION_LOG` and `PROJECT_ARCHITECTURE_BASELINE` appear to conflict:
- Business-semantic issues (capability meaning, scope, success criteria, failure-handling, degradation semantics) → Tier 0/0.5 wins
- Structural issues (topology, component decomposition, call paths, data paths, structural separation) → Tier 0.8 wins
- Mixed clauses → malformed; must be split by user confirmation, not silently classified by agent
