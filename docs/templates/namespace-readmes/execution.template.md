---
artifact_type: namespace-readme
status: proposed
owner_role: system-architect
scope: system
downstream_consumers: [implementation, verification]
last_reviewed: 2026-03-20
---

# Execution Artifact Namespace

**Status:** active
**Owner:** System Architect Agent
**Purpose:** Unified namespace for cross-role task-scoped execution documents

---

## What Goes Here

Task-scoped execution artifacts, for example:

1. Task execution packs
2. Affected-files maps
3. Task risk checklists
4. Other approved task-scoped execution documents

## Boundary with Other Directories

1. `docs/plans/agents/` stores agent system design and implementation plans
2. `docs/agents/` other main namespaces store active truth / contracts / oracles
3. This directory stores only task execution documents, not agent system design

## Compatibility

Current implementation task packs in `docs/agents/implementation/tasks/` remain valid.

Until an explicit migration is approved:

1. `docs/agents/implementation/tasks/` remains the current valid location for implementation task packs
2. This directory is reserved for the unified execution namespace and can accept new designs

## Recommended Organization

New task-scoped execution documents should use per-task subdirectories:

```
docs/agents/execution/<task-slug>/
├── TASK_EXECUTION_PACK.md
├── AFFECTED_FILES_MAP.md
└── TASK_RISK_CHECKLIST.md
```
