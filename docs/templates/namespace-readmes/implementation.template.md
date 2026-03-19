---
artifact_type: namespace-readme
status: proposed
owner_role: implementation
scope: task
downstream_consumers: [verification]
last_reviewed: 2026-03-20
---

# Implementation Artifact Namespace

**Status:** active
**Owner:** Implementation Agent
**Purpose:** Store implementation execution templates and task-scoped artifacts

---

## What Goes Here

1. `AGENT_SPEC.md` — Implementation Agent role specification
2. `TASK_EXECUTION_PACK_TEMPLATE.md` — Reusable task execution pack template
3. `AFFECTED_FILES_MAP_TEMPLATE.md` — Reusable affected-files map template
4. `TASK_RISK_CHECKLIST_TEMPLATE.md` — Reusable risk checklist template
5. `tasks/` — Task-scoped execution packs (organized by date-slug)

## Directory Structure

```
docs/agents/implementation/
├── README.md
├── AGENT_SPEC.md
├── TASK_EXECUTION_PACK_TEMPLATE.md
├── AFFECTED_FILES_MAP_TEMPLATE.md
├── TASK_RISK_CHECKLIST_TEMPLATE.md
└── tasks/
    └── YYYY-MM-DD-task-slug/
        ├── TASK_EXECUTION_PACK.md
        ├── AFFECTED_FILES_MAP.md
        └── TASK_RISK_CHECKLIST.md
```

## Core Rule

**No implementation without contract.** If the module contract doesn't cover the task, escalate to Module Architect before writing code.
