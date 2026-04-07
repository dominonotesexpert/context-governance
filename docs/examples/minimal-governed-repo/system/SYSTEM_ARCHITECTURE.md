---
artifact_type: system-architecture
status: active
owner_role: system-architect
scope: system
downstream_consumers: [module-architect, implementation, verification, debug, frontend-specialist]
last_reviewed: 2026-03-22
derived_from_baseline_version: "v1.0"
derived_from_architecture_baseline_version: "v1.0"
derivation_context:
  model_id: ""
  context_window: ""
  prompt_version: ""
  derivation_timestamp: ""
  upstream_hash: ""
derived_sections: []
---

# SYSTEM_ARCHITECTURE

**Status:** active
**Owner:** System Architect Agent
**Last Updated:** 2026-03-22
**Derived From:** PROJECT_BASELINE, BASELINE_INTERPRETATION_LOG, PROJECT_ARCHITECTURE_BASELINE, SYSTEM_GOAL_PACK, ENGINEERING_CONSTRAINTS

> Derived document at Tier 2. Expands the Tier 0.8 architectural floor.

---

## 1. Architectural Overview

The Task Manager is a monolithic application (per architecture baseline decision 1) with three internal components: REST API, Background Worker, and PostgreSQL storage. External communication goes through a gateway layer (per boundary 2).

## 2. Component Decomposition

| Component | Responsibility | Module |
|-----------|---------------|--------|
| REST API | HTTP endpoints, request validation, auth | api-service |
| Background Worker | Async task processing, notifications | worker-service |
| Gateway | External service abstraction | gateway |
| Repository Layer | DB access abstraction | shared |

## 3. Integration Patterns

- API → Worker: in-process queue (per decision 4)
- All components → DB: repository pattern (per boundary 3)
- Worker → Email: gateway layer (per boundary 2)

## 4. Traceability

| Section | Upstream Source | Derivation Type |
|---------|---------------|----------------|
| 1 Overview | ARCH_BASELINE 1, 2 | structural |
| 2 Decomposition | ARCH_BASELINE 3, GOAL_PACK 2 | mixed |
| 3 Integration | ARCH_BASELINE 2.4, 3 | structural |
