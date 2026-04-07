---
artifact_type: bootstrap-readiness
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [all-roles]
last_reviewed: 2026-03-20
---

# BOOTSTRAP_READINESS

**Status:** proposed
**Owner:** Task Orchestrator
**Last Updated:** YYYY-MM-DD

---

## 1. Purpose

Tracks which roles and artifact families are ready for consumption. Before starting a task, the orchestrator checks this document to know which capabilities are available.

## 2. Readiness States

| State | Meaning |
|-------|---------|
| `ready` | Role scaffold + core artifacts exist and are status: active |
| `partial` | Some artifacts exist, others pending |
| `not_started` | Role defined in design but no artifacts created yet |
| `blocked` | Prerequisites exist but a hard constraint prevents proceeding |

## 3. Tier 0 — Project Baseline

| Artifact | State | Notes |
|----------|-------|-------|
| PROJECT_BASELINE.md | <!-- ready/not_started --> | <!-- Must be filled before any task can begin --> |

**PROJECT_BASELINE is the prerequisite for everything.** No downstream document can be derived, and no task can be routed, until BASELINE exists and is status: active.

## 3.5. Tier 0.5 — Baseline Interpretation

| Artifact | State | Notes |
|----------|-------|-------|
| BASELINE_INTERPRETATION_LOG.md | <!-- ready/not_started --> | <!-- Structurally present after bootstrap; entries added as business ambiguities are discovered --> |

**BASELINE_INTERPRETATION_LOG is always bootstrapped** but may have no entries initially. Readiness does not block on entries unless the System Architect has identified business-semantic ambiguities requiring user confirmation. When such ambiguities exist, the System Architect is not fully ready until confirmations are recorded.

## 3.5b. Tier 1.5 — Engineering Constraints

| Artifact | State | Notes |
|----------|-------|-------|
| ENGINEERING_CONSTRAINTS.md | <!-- ready/not_started --> | <!-- Always bootstrapped; may have no entries initially --> |

**ENGINEERING_CONSTRAINTS is always bootstrapped but may have no entries initially.** System is ready when the document exists, even if the constraint registry is empty. Constraints are added as engineering reality is discovered during project work.

## 3.8. Tier 0.8 — Architecture Baseline

| Artifact | State | Notes |
|----------|-------|-------|
| PROJECT_ARCHITECTURE_BASELINE.md | <!-- ready/not_started/blocked --> | <!-- User-owned structural truth. Must stay within size limits (≤50 body lines, ≤2 Mermaid blocks). --> |

**PROJECT_ARCHITECTURE_BASELINE is optional but constraining.** If it exists, Tier 2 derivation and downstream module contracts must respect it. If it does not exist, the system operates without an architectural floor (higher derivation instability). If it exceeds size limits, readiness = `blocked`.

## 3.6. Governance Mode Check

| Check | State | Notes |
|-------|-------|-------|
| GOVERNANCE_MODE expiry | <!-- ok/blocked --> | <!-- If mode ≠ steady-state and expired, state = blocked --> |

**If GOVERNANCE_MODE exists and `current_mode ≠ steady-state AND today > expiry_date`**, readiness state = `blocked`. Blocked reason: "Governance mode expired. Renew or revert before proceeding."

## 4. Role Readiness

| Role | State | Entry Point | Notes |
|------|-------|-------------|-------|
| System Architect | <!-- ready/partial/not_started --> | `docs/agents/system/` | <!-- e.g., "BASELINE active, 4 core artifacts derived" --> |
| Module Architect | <!-- ready/partial/not_started --> | `docs/agents/modules/` | <!-- e.g., "1 pilot module active" --> |
| Debug Agent | <!-- ready/partial/not_started --> | `docs/agents/debug/` | <!-- e.g., "scaffold ready, case template active" --> |
| Implementation | <!-- ready/partial/not_started --> | `docs/agents/implementation/` | <!-- --> |
| Verification | <!-- ready/partial/not_started --> | `docs/agents/verification/` | <!-- --> |
| Frontend Specialist | <!-- ready/partial/not_started --> | `docs/agents/frontend/` | <!-- --> |
| Autoresearch | <!-- ready/partial/not_started --> | `docs/agents/optimization/` | <!-- e.g., "seed scenarios present, optimization log ready" --> |

## 5. Task Startup Prerequisites

### All tasks (universal)
- [ ] PROJECT_BASELINE: active (Tier 0 root — everything derives from this)
- [ ] SYSTEM_GOAL_PACK: active (derived from BASELINE)
- [ ] SYSTEM_INVARIANTS: active (derived from BASELINE §4)
- [ ] SYSTEM_AUTHORITY_MAP: active

### Feature tasks
- [ ] All universal prerequisites met
- [ ] Relevant Module Contract: active
- [ ] Task Execution Pack: assembled

### Bug/debug tasks
- [ ] All universal prerequisites met
- [ ] System Scenario Map Index: active (at least 1 scenario)
- [ ] Relevant Module Canonical Maps: active
- [ ] Debug Case Template: active
- [ ] DEBUG_CASE created before implementation begins

### Design/architecture tasks
- [ ] All universal prerequisites met
- [ ] Relevant Module Contract: active (or being created as part of this task)

### Audit tasks
- [ ] PROJECT_BASELINE: active
- [ ] SYSTEM_AUTHORITY_MAP: active
- [ ] SYSTEM_CONFLICT_REGISTER: accessible

### Autoresearch tasks
- [ ] All universal prerequisites met
- [ ] OPTIMIZATION_LOG: accessible
- [ ] Test scenarios: at least seed scenarios present
- [ ] REGRESSION_CASES: accessible

## 6. Optimization & Execution Infrastructure

| Artifact | State | Notes |
|----------|-------|-------|
| FEEDBACK_LOG | <!-- ready/not_started --> | <!-- --> |
| CRITERIA_EVOLUTION | <!-- ready/not_started --> | <!-- --> |
| OPTIMIZATION_LOG | <!-- ready/not_started --> | <!-- --> |
| Test Scenarios | <!-- ready/not_started --> | <!-- e.g., "4 seed scenarios" --> |
| GOVERNANCE_PROGRESS template | <!-- ready/not_started --> | <!-- --> |
| CURRENT_DIRECTION | <!-- ready/not_started --> | <!-- Project-wide phase context --> |
