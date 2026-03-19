---
artifact_type: namespace-readme
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [all-roles]
last_reviewed: 2026-03-20
---

# System Artifact Namespace

**Status:** active
**Owner:** System Architect Agent
**Purpose:** Store system-level truth artifacts that define what is true at the highest level

---

## What Goes Here

1. `SYSTEM_GOAL_PACK.md` — Product vision, direction, obligations, failure philosophy
2. `SYSTEM_AUTHORITY_MAP.md` — Document hierarchy and status
3. `SYSTEM_INVARIANTS.md` — Hard rules that cannot be violated
4. `SYSTEM_CONFLICT_REGISTER.md` — Resolved design conflicts and decisions
5. `SYSTEM_BOOTSTRAP_PACK.md` — System-level bootstrap entry point
6. `SYSTEM_SCENARIO_MAP_INDEX.md` — Cross-module scenario index
7. `AGENT_SPEC.md` — System Architect Agent role specification
8. `scenarios/` — End-to-end scenario maps

## Consumption Rules

1. System artifacts are read first, before any module or task-level documents
2. When code contradicts system artifacts, the artifacts are authoritative
3. Only the System Architect Agent may modify these artifacts
