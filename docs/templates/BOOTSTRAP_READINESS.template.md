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

## 3. Role Readiness

| Role | State | Entry Point | Notes |
|------|-------|-------------|-------|
| System Architect | <!-- ready/partial/not_started --> | `docs/agents/system/` | <!-- e.g., "4 core artifacts active" --> |
| Module Architect | <!-- ready/partial/not_started --> | `docs/agents/modules/` | <!-- e.g., "1 pilot module active" --> |
| Debug Agent | <!-- ready/partial/not_started --> | `docs/agents/debug/` | <!-- e.g., "scaffold ready, case template active" --> |
| Implementation | <!-- ready/partial/not_started --> | `docs/agents/implementation/` | <!-- --> |
| Verification | <!-- ready/partial/not_started --> | `docs/agents/verification/` | <!-- --> |
| Frontend Specialist | <!-- ready/partial/not_started --> | `docs/agents/frontend/` | <!-- --> |

## 4. Task Startup Prerequisites

### Feature tasks
- [ ] System Goal Pack: active
- [ ] Relevant Module Contract: active
- [ ] Task Execution Pack: assembled

### Bug/debug tasks
- [ ] System Goal Pack: active
- [ ] System Scenario Map Index: active (at least 1 scenario)
- [ ] Relevant Module Canonical Maps: active
- [ ] Debug Case Template: active
- [ ] DEBUG_CASE created before implementation begins
